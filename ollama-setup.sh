#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  Ollama Installer for JPHsystems VPS
#  Target: Debian 13 (trixie) · Ryzen 5 3600 · 64 GB RAM · CPU-only
#
#  Usage:  bash ollama-setup.sh
#
#  Flags:
#    --no-models       Skip downloading starter models
#    --models-only     Only pull models (Ollama already installed)
#    --dry-run         Show what would happen without doing anything
#    --uninstall       Remove Ollama completely
#    --hermes          Configure Hermes presets (interactive)
#    --hermes-offline  Configure Hermes for full-offline (non-interactive)
#    --hermes-hybrid   Configure Hermes hybrid: cloud main + local aux
#    --hermes-aux      Configure Hermes: local auxiliary only
#    --hermes-reset    Reset Hermes Ollama config back to cloud/auto
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────
THREADS=6                # Physical cores on Ryzen 5 3600
PARALLEL=1               # One request at a time (CPU-only)
OLLAMA_HOST="127.0.0.1"  # NEVER expose publicly without auth
OLLAMA_PORT=11434
OLLAMA_BASE="http://${OLLAMA_HOST}:${OLLAMA_PORT}/v1"
OLLAMA_KEY="ollama"      # Dummy key — Ollama ignores it, Hermes needs it

# Default starter models (standalone Ollama use)
STARTER_MODELS=(
    "llama3.1:8b"
    "qwen2.5-coder:7b"
    "nomic-embed-text"
)

# Hermes preset model assignments
#   MAIN_MODEL       — primary conversation model
#   DELEGATION_MODEL — coding subagents
#   AUX_MODEL        — vision, compression, titles, etc.
#   KANBAN_MODEL     — kanban task decomposition (needs stronger reasoning)
HERMES_MAIN="gemma4:latest"
HERMES_DELEGATION="gemma4:latest"
HERMES_AUX="gemma3:12b"
HERMES_KANBAN="gemma4:latest"

# Auxiliary slots that can use the AUX model
AUX_CORE_SLOTS=(vision web_extract compression title_generation)
AUX_EXTENDED_SLOTS=(approval triage_specifier session_search curator profile_describer)

# ─── Colors ─────────────────────────────────────────────────────
B='\033[1m'; R='\033[0m'; G='\033[0;32m'; Y='\033[0;33m'
C='\033[0;36m'; RED='\033[0;31m'

info()  { echo -e "${C}[INFO]${R}  $*"; }
ok()    { echo -e "${G}[OK]${R}    $*"; }
warn()  { echo -e "${Y}[WARN]${R}  $*"; }
err()   { echo -e "${RED}[ERR]${R}   $*"; }
header(){ echo -e "\n${B}═══ $* ═══${R}\n"; }

# ─── Flags ──────────────────────────────────────────────────────
DRY_RUN=false
NO_MODELS=false
MODELS_ONLY=false
UNINSTALL=false
HERMES_MODE=""
# Possible values: "" (skip), "ask" (interactive), "offline", "hybrid", "aux", "reset"

for arg in "$@"; do
    case "$arg" in
        --dry-run)         DRY_RUN=true ;;
        --no-models)       NO_MODELS=true ;;
        --models-only)     MODELS_ONLY=true ;;
        --uninstall)       UNINSTALL=true ;;
        --hermes)          HERMES_MODE="ask" ;;
        --hermes-offline)  HERMES_MODE="offline" ;;
        --hermes-hybrid)   HERMES_MODE="hybrid" ;;
        --hermes-aux)      HERMES_MODE="aux" ;;
        --hermes-reset)    HERMES_MODE="reset" ;;
        --help|-h)
            head -20 "$0"
            exit 0
            ;;
        *)
            err "Unknown flag: $arg"
            exit 2
            ;;
    esac
done

# Dry-run wrapper
run() {
    if $DRY_RUN; then
        echo -e "  ${Y}[dry-run]${R} $*"
    else
        eval "$@"
    fi
}

# ═══════════════════════════════════════════════════════════════
# UNINSTALL
# ═══════════════════════════════════════════════════════════════
if $UNINSTALL; then
    header "Uninstalling Ollama"

    read -rp "$(echo -e ${Y}'This will remove Ollama and ALL downloaded models. Continue? [y/N] '${R})" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

    info "Stopping service..."
    run "sudo systemctl stop ollama 2>/dev/null || true"
    run "sudo systemctl disable ollama 2>/dev/null || true"

    info "Removing service file..."
    run "sudo rm -f /etc/systemd/system/ollama.service"
    run "sudo systemctl daemon-reload"

    info "Removing binary..."
    run "sudo rm -f /usr/local/bin/ollama"

    info "Removing user and data..."
    run "sudo rm -rf /usr/share/ollama"
    run "sudo userdel ollama 2>/dev/null || true"

    ok "Ollama removed."
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "Pre-flight Checks"

    # Check OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        info "OS: $PRETTY_NAME"
        if [[ "$ID" != "debian" ]]; then
            warn "This script targets Debian. Your OS: $ID - proceed at your own risk."
        fi
    else
        err "Cannot detect OS. Aborting."
        exit 1
    fi

    # Check architecture
    ARCH=$(uname -m)
    info "Architecture: $ARCH"
    if [[ "$ARCH" != "x86_64" ]]; then
        warn "Expected x86_64. Your arch may not have prebuilt binaries."
    fi

    # Check RAM
    RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
    info "RAM: ${RAM_GB} GB"
    if (( RAM_GB < 8 )); then
        warn "Less than 8 GB RAM - only small models (1-3B) will be practical."
    fi

    # Check disk
    AVAIL_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
    info "Available disk: ${AVAIL_GB} GB"
    if (( AVAIL_GB < 20 )); then
        warn "Less than 20 GB free - model storage may be tight."
    fi

    # Check CPU cores
    CORES=$(nproc)
    PHYSICAL_CORES=$(awk '/^cpu cores/ {print $4; exit}' /proc/cpuinfo)
    info "CPU threads: $CORES  (physical cores: $PHYSICAL_CORES)"
    THREADS=${PHYSICAL_CORES:-$CORES}
    info "Will use $THREADS threads for inference."

    # Check for existing installation
    if command -v ollama &>/dev/null; then
        EXISTING_VER=$(ollama --version 2>/dev/null || echo "unknown")
        warn "Ollama is already installed (version: $EXISTING_VER)"
        read -rp "$(echo -e ${Y}'Reinstall/upgrade? [y/N] '${R})" reinstall
        [[ "$reinstall" =~ ^[Yy]$ ]] || { info "Skipping install."; MODELS_ONLY=true; }
    fi

    # Check curl
    if ! command -v curl &>/dev/null; then
        err "curl is required but not installed. Run: sudo apt install curl"
        exit 1
    fi
    ok "Pre-flight checks passed."
fi

# ═══════════════════════════════════════════════════════════════
# INSTALL
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "Installing Ollama"

    info "Downloading and running official install script..."
    if $DRY_RUN; then
        echo -e "  ${Y}[dry-run]${R} curl -fsSL https://ollama.com/install.sh | sh"
    else
        curl -fsSL https://ollama.com/install.sh | sh
    fi

    ok "Install complete."
fi

# ═══════════════════════════════════════════════════════════════
# CONFIGURE SYSTEMD
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "Configuring systemd service"

    info "Setting performance tuning for CPU-only inference..."
    info "  OLLAMA_NUM_THREAD=$THREADS"
    info "  OLLAMA_NUM_PARALLEL=$PARALLEL"
    info "  OLLAMA_HOST=$OLLAMA_HOST:$OLLAMA_PORT"

    OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
    OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

    if $DRY_RUN; then
        echo -e "  ${Y}[dry-run]${R} sudo mkdir -p $OVERRIDE_DIR"
        echo -e "  ${Y}[dry-run]${R} write $OVERRIDE_FILE"
    else
        sudo mkdir -p "$OVERRIDE_DIR"
        sudo tee "$OVERRIDE_FILE" > /dev/null <<EOF
[Service]
Environment="OLLAMA_NUM_THREAD=${THREADS}"
Environment="OLLAMA_NUM_PARALLEL=${PARALLEL}"
Environment="OLLAMA_HOST=${OLLAMA_HOST}:${OLLAMA_PORT}"
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_MAX_LOADED_MODELS=2"
EOF
    fi

    info "Reloading daemon and restarting service..."
    run "sudo systemctl daemon-reload"
    run "sudo systemctl enable ollama"
    run "sudo systemctl restart ollama"

    # Wait for service to be ready
    if ! $DRY_RUN; then
        info "Waiting for service to start..."
        for i in $(seq 1 10); do
            if curl -sf "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
                ok "Ollama API is responding."
                break
            fi
            sleep 1
            [[ $i -eq 10 ]] && warn "API not responding yet - check: systemctl status ollama"
        done
    fi

    ok "Service configured."
fi

# ═══════════════════════════════════════════════════════════════
# PULL STARTER MODELS
# ═══════════════════════════════════════════════════════════════

# If a Hermes preset is selected, override STARTER_MODELS with the right ones
determine_hermes_models() {
    case "$HERMES_MODE" in
        offline)
            STARTER_MODELS=("$HERMES_MAIN" "$HERMES_AUX" "nomic-embed-text")
            ;;
        hybrid)
            STARTER_MODELS=("$HERMES_AUX" "$HERMES_DELEGATION" "nomic-embed-text")
            ;;
        aux)
            STARTER_MODELS=("$HERMES_AUX" "nomic-embed-text")
            ;;
    esac
}

if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" && "$HERMES_MODE" != "reset" ]]; then
    determine_hermes_models
fi

if ! $NO_MODELS; then
    header "Downloading Models"

    info "The following models will be downloaded:"
    for m in "${STARTER_MODELS[@]}"; do
        echo -e "    ${C}- $m${R}"
    done
    echo

    # Estimate total size
    case "$HERMES_MODE" in
        offline) info "Total download: ~18 GB (gemma4 + gemma3:12b + embeddings)" ;;
        hybrid)  info "Total download: ~18 GB (gemma3:12b + gemma4 + embeddings)" ;;
        aux)     info "Total download: ~8.5 GB (gemma3:12b + embeddings)" ;;
        *)       info "Total download: ~9.5 GB" ;;
    esac
    echo

    if ! $DRY_RUN; then
        read -rp "$(echo -e ${Y}'Download these models now? [Y/n] '${R})" dl
    else
        dl="y"
    fi

    if [[ "$dl" =~ ^[Yy]?$ ]]; then
        for model in "${STARTER_MODELS[@]}"; do
            info "Pulling $model ..."
            if $DRY_RUN; then
                echo -e "  ${Y}[dry-run]${R} ollama pull $model"
            else
                ollama pull "$model"
                ok "Downloaded: $model"
            fi
        done
        ok "All models downloaded."
    else
        info "Skipping model downloads. You can pull them later with:"
        echo -e "  ${C}ollama pull <model-name>${R}"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# CONFIGURE HERMES PRESETS
# ═══════════════════════════════════════════════════════════════

# Locate the hermes CLI
HERMES_BIN=""
if command -v hermes &>/dev/null; then
    HERMES_BIN="hermes"
elif [[ -x "$HOME/.hermes/hermes-agent/venv/bin/hermes" ]]; then
    HERMES_BIN="$HOME/.hermes/hermes-agent/venv/bin/hermes"
fi

# Check if Hermes config exists
HERMES_CONFIG="$HOME/.hermes/config.yaml"

configure_hermes_aux_slot() {
    local slot="$1"
    local model="$2"
    run "$HERMES_BIN config set auxiliary.${slot}.provider ollama"
    run "$HERMES_BIN config set auxiliary.${slot}.model ${model}"
    run "$HERMES_BIN config set auxiliary.${slot}.base_url ${OLLAMA_BASE}"
    run "$HERMES_BIN config set auxiliary.${slot}.api_key ${OLLAMA_KEY}"
}

if [[ -n "$HERMES_MODE" ]]; then
    header "Configuring Hermes Agent"

    if [[ -z "$HERMES_BIN" ]]; then
        warn "Hermes CLI not found. Skipping Hermes configuration."
        warn "Configure manually using 'hermes config set' commands."
        warn "See the PDF guide for instructions."
    elif [[ ! -f "$HERMES_CONFIG" ]]; then
        warn "No Hermes config found at $HERMES_CONFIG"
        warn "Skipping Hermes configuration."
    else
        # ─── Interactive mode ───────────────────────────────────
        if [[ "$HERMES_MODE" == "ask" ]]; then
            echo
            echo -e "${B}Choose a Hermes preset:${R}"
            echo
            echo -e "  ${C}1) Full Offline${R}"
            echo "     Everything runs on local Ollama models."
            echo "     Main: $HERMES_MAIN | Aux: $HERMES_AUX | Delegation: $HERMES_DELEGATION"
            echo "     No cloud API needed after setup."
            echo
            echo -e "  ${C}2) Hybrid (recommended)${R}"
            echo "     Cloud for main conversation (zai/glm-5.2)."
            echo "     Local for auxiliary + delegation."
            echo "     Best of both worlds."
            echo
            echo -e "  ${C}3) Auxiliary Only${R}"
            echo "     Cloud for main + delegation."
            echo "     Local only for background tasks (vision, compression, titles)."
            echo "     Minimal local resource use."
            echo
            echo -e "  ${C}4) Skip${R}"
            echo "     Don't configure Hermes. Just use Ollama standalone."
            echo

            if ! $DRY_RUN; then
                read -rp "$(echo -e ${Y}'Select preset [1-4]: '${R})" choice
            else
                choice=1
                echo "[dry-run] Selected: 1"
            fi

            case "$choice" in
                1) HERMES_MODE="offline" ;;
                2) HERMES_MODE="hybrid" ;;
                3) HERMES_MODE="aux" ;;
                4) HERMES_MODE="" ;;
                *) err "Invalid choice."; HERMES_MODE="" ;;
            esac

            # Re-evaluate models if a preset was chosen
            if [[ -n "$HERMES_MODE" ]]; then
                determine_hermes_models
                info "Preset: $HERMES_MODE"
                info "Make sure the required models are pulled before using Hermes."
            fi
        fi

        # ─── Apply preset ───────────────────────────────────────
        if [[ "$HERMES_MODE" == "reset" ]]; then
            #
            # RESET: restore auxiliary slots to auto, main to zai/glm
            #
            info "Resetting Hermes to cloud/auto defaults..."

            run "$HERMES_BIN config set model.provider zai"
            run "$HERMES_BIN config set model.default glm-5.2"
            run "$HERMES_BIN config set model.base_url https://api.z.ai/api/paas/v4"
            run "$HERMES_BIN config set model.api_key ''"

            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}" kanban_decomposer; do
                run "$HERMES_BIN config set auxiliary.${slot}.provider auto"
                run "$HERMES_BIN config set auxiliary.${slot}.model ''"
                run "$HERMES_BIN config set auxiliary.${slot}.base_url ''"
                run "$HERMES_BIN config set auxiliary.${slot}.api_key ''"
            done

            run "$HERMES_BIN config set delegation.provider ''"
            run "$HERMES_BIN config set delegation.model ''"
            run "$HERMES_BIN config set delegation.base_url ''"
            run "$HERMES_BIN config set delegation.api_key ''"

            ok "Hermes reset to cloud/auto."

        elif [[ "$HERMES_MODE" == "offline" ]]; then
            #
            # FULL OFFLINE: everything local
            #
            info "Applying FULL OFFLINE preset..."
            info "  Main: $HERMES_MAIN | Delegation: $HERMES_DELEGATION | Aux: $HERMES_AUX"

            # Register provider
            run "$HERMES_BIN config set providers.ollama.name Ollama"
            run "$HERMES_BIN config set providers.ollama.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set providers.ollama.api_key ${OLLAMA_KEY}"

            # Main model
            run "$HERMES_BIN config set model.default ${HERMES_MAIN}"
            run "$HERMES_BIN config set model.provider ollama"
            run "$HERMES_BIN config set model.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set model.api_key ${OLLAMA_KEY}"

            # Delegation
            run "$HERMES_BIN config set delegation.provider ollama"
            run "$HERMES_BIN config set delegation.model ${HERMES_DELEGATION}"
            run "$HERMES_BIN config set delegation.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set delegation.api_key ${OLLAMA_KEY}"

            # Auxiliary slots
            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done

            # Kanban decomposer (uses the main/delegation model for stronger reasoning)
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_KANBAN"

            ok "Full offline preset applied."

        elif [[ "$HERMES_MODE" == "hybrid" ]]; then
            #
            # HYBRID: cloud main, local auxiliary + delegation
            #
            info "Applying HYBRID preset..."
            info "  Main: zai/glm-5.2 (cloud) | Delegation: $HERMES_DELEGATION (local) | Aux: $HERMES_AUX (local)"

            # Register provider (idempotent)
            run "$HERMES_BIN config set providers.ollama.name Ollama"
            run "$HERMES_BIN config set providers.ollama.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set providers.ollama.api_key ${OLLAMA_KEY}"

            # Delegation -> local
            run "$HERMES_BIN config set delegation.provider ollama"
            run "$HERMES_BIN config set delegation.model ${HERMES_DELEGATION}"
            run "$HERMES_BIN config set delegation.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set delegation.api_key ${OLLAMA_KEY}"

            # Auxiliary slots -> local
            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_KANBAN"

            # Main model stays on cloud (zai/glm-5.2) - no changes needed
            ok "Hybrid preset applied. Main model stays on cloud."

        elif [[ "$HERMES_MODE" == "aux" ]]; then
            #
            # AUXILIARY ONLY: cloud main + delegation, local aux
            #
            info "Applying AUXILIARY ONLY preset..."
            info "  Main + Delegation: cloud (unchanged) | Aux: $HERMES_AUX (local)"

            # Register provider
            run "$HERMES_BIN config set providers.ollama.name Ollama"
            run "$HERMES_BIN config set providers.ollama.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set providers.ollama.api_key ${OLLAMA_KEY}"

            # Auxiliary slots -> local
            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_AUX"

            ok "Auxiliary-only preset applied."
        fi

        # Restart gateway to apply changes
        if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
            info "Backing up config..."
            if ! $DRY_RUN; then
                cp "$HERMES_CONFIG" "${HERMES_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
            else
                echo -e "  ${Y}[dry-run]${R} cp $HERMES_CONFIG {timestamp}.bak"
            fi

            info "Config changes take effect on next session or gateway restart."
            info "To restart the gateway now:"
            echo -e "  ${C}systemctl --user restart hermes-gateway${R}"
            echo
            info "Or reset any active session with: ${C}/reset${R}"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# VERIFY & SUMMARY
# ═══════════════════════════════════════════════════════════════
header "Installation Summary"

if ! $DRY_RUN; then
    echo -e "${B}Service:${R}"
    systemctl is-active ollama --no-pager 2>/dev/null && echo " (active)" || warn "not active"
    echo

    echo -e "${B}Version:${R}"
    ollama --version 2>/dev/null || echo "n/a"
    echo

    echo -e "${B}Downloaded models:${R}"
    ollama list 2>/dev/null || echo "none"
    echo

    echo -e "${B}API test:${R}"
    if curl -sf "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" | python3 -m json.tool 2>/dev/null; then
        ok "API is working."
    else
        warn "API not responding."
    fi

    if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
        echo
        echo -e "${B}Hermes preset:${R} $HERMES_MODE"
        echo -e "  Backup: ${C}$(ls -t ${HERMES_CONFIG}.bak.* 2>/dev/null | head -1 || echo 'n/a')${R}"
    fi
else
    echo -e "${Y}[dry-run] No changes were made.${R}"
fi

echo
echo -e "${G}${B}═══════════════════════════════════════════════${R}"
echo -e "${G}${B}  Ollama is ready!${R}"
echo -e "${G}${B}═══════════════════════════════════════════════${R}"
echo
echo -e "  Start chatting:   ${C}ollama run llama3.1:8b${R}"
echo -e "  List models:      ${C}ollama list${R}"
echo -e "  API endpoint:     ${C}http://${OLLAMA_HOST}:${OLLAMA_PORT}${R}"
echo -e "  View service:     ${C}systemctl status ollama${R}"
echo -e "  View logs:        ${C}journalctl -u ollama -f${R}"
echo
echo -e "  Config override:  ${C}/etc/systemd/system/ollama.service.d/override.conf${R}"
if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
echo -e "  Hermes config:    ${C}$HERMES_CONFIG${R}"
echo -e "  Hermes preset:    ${C}$HERMES_MODE${R}"
echo -e "  Restart gateway:  ${C}systemctl --user restart hermes-gateway${R}"
fi
echo
