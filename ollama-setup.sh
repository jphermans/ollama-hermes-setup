#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  🦙 Ollama Installer for JPHsystems VPS
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
HERMES_MAIN="gemma4:latest"
HERMES_DELEGATION="gemma4:latest"
HERMES_AUX="gemma3:12b"
HERMES_KANBAN="gemma4:latest"

# Auxiliary slots
AUX_CORE_SLOTS=(vision web_extract compression title_generation)
AUX_EXTENDED_SLOTS=(approval triage_specifier session_search curator profile_describer)

# ─── Colors ─────────────────────────────────────────────────────
B='\033[1m';    R='\033[0m'
RED='\033[0;31m';    GRN='\033[0;32m';   YEL='\033[0;33m'
BLU='\033[0;34m';    MAG='\033[0;35m';   CYN='\033[0;36m'
WHT='\033[0;37m';    DIM='\033[0;90m'
BRED='\033[1;31m';   BGRN='\033[1;32m';  BYEL='\033[1;33m'
BBLU='\033[1;34m';   BMAG='\033[1;35m';  BCYN='\033[1;36m'
BG_BLU='\033[44m';   BG_GRN='\033[42m';  BG_YEL='\033[43m'
BG_RED='\033[41m';   BG_MAG='\033[45m';  BG_CYN='\033[46m'

# ─── Logging ────────────────────────────────────────────────────
info()  { echo -e "  ${CYN}ℹ${R}  $*"; }
ok()    { echo -e "  ${GRN}✓${R} $*"; }
warn()  { echo -e "  ${YEL}⚠${R} $*"; }
err()   { echo -e "  ${RED}✗${R} $*"; }
step()  { echo -e "\n  ${BMAG}▶ $*${R}"; }

header() {
    echo -e "\n"
    echo -e "  ${BG_BLU}${WHT}${B} ┌─────────────────────────────────────────────┐ ${R}"
    echo -e "  ${BG_BLU}${WHT}${B} │  $* ${R}"
    echo -e "  ${BG_BLU}${WHT}${B} └─────────────────────────────────────────────┘ ${R}"
    echo
}

banner() {
    echo -e "  ${BCYN}   ___  ____  _  ___  ___  ___${R}"
    echo -e "  ${BCYN}  / _ \/ __ \| |/ / |/ / |/ /${R}"
    echo -e "  ${BCYN} / , _/ /_/ /| / /| / <| / < ${R}"
    echo -e "  ${BCYN}/_/|_|\____/_|/_/ |_/\_\|_/\_\\${R}  ${DIM}Setup Script${R}"
    echo -e "  ${DIM}─────────────────────────────────────────${R}"
    echo -e "  ${BBLU}🦙 Ollama${R} + ${BMAG}🤖 Hermes Agent${R} ${DIM}| CPU-only VPS${R}"
    echo
}

# ─── Flags ──────────────────────────────────────────────────────
DRY_RUN=false
NO_MODELS=false
MODELS_ONLY=false
UNINSTALL=false
HERMES_MODE=""

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
            err "Unknown flag: ${BRED}$arg${R}"
            exit 2
            ;;
    esac
done

# Show banner
banner

# Dry-run wrapper
run() {
    if $DRY_RUN; then
        echo -e "    ${DIM}▫ [dry-run]${R} $*"
    else
        eval "$@"
    fi
}

# ═══════════════════════════════════════════════════════════════
# UNINSTALL
# ═══════════════════════════════════════════════════════════════
if $UNINSTALL; then
    header "🗑️  Uninstall Ollama"

    read -rp "$(echo -e "  ${BYEL}⚠  This will remove Ollama and ALL models. Continue? [y/N] ${R}")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "  ${DIM}Aborted.${R}"; exit 0; }

    step "🛑 Stopping service..."
    run "sudo systemctl stop ollama 2>/dev/null || true"
    run "sudo systemctl disable ollama 2>/dev/null || true"

    step "📄 Removing service file..."
    run "sudo rm -f /etc/systemd/system/ollama.service"
    run "sudo systemctl daemon-reload"

    step "📦 Removing binary..."
    run "sudo rm -f /usr/local/bin/ollama"

    step "🗂️ Removing user and data..."
    run "sudo rm -rf /usr/share/ollama"
    run "sudo userdel ollama 2>/dev/null || true"

    echo
    ok "${BGRN}🦙 Ollama has been removed.${R}"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "🔍 Pre-flight Checks"

    # Check OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        info "🖥️   OS: ${B}${PRETTY_NAME}${R}"
        if [[ "$ID" != "debian" ]]; then
            warn "Targets Debian. Your OS: ${YEL}$ID${R} — proceed at your own risk."
        fi
    else
        err "Cannot detect OS. Aborting."
        exit 1
    fi

    # Check architecture
    ARCH=$(uname -m)
    info "🏗️   Architecture: ${B}$ARCH${R}"
    if [[ "$ARCH" != "x86_64" ]]; then
        warn "Expected x86_64. Your arch may not have prebuilt binaries."
    fi

    # Check RAM
    RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
    RAM_COLOR="$GRN"
    (( RAM_GB < 16 )) && RAM_COLOR="$YEL"
    (( RAM_GB < 8 ))  && RAM_COLOR="$RED"
    info "💾 RAM: ${RAM_COLOR}${B}${RAM_GB} GB${R}"
    if (( RAM_GB < 8 )); then
        warn "Less than 8 GB RAM — only small models (1-3B) will be practical."
    fi

    # Check disk
    AVAIL_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
    DISK_COLOR="$GRN"
    (( AVAIL_GB < 50 )) && DISK_COLOR="$YEL"
    (( AVAIL_GB < 20 )) && DISK_COLOR="$RED"
    info "💿 Disk: ${DISK_COLOR}${B}${AVAIL_GB} GB${R} available"
    if (( AVAIL_GB < 20 )); then
        warn "Less than 20 GB free — model storage may be tight."
    fi

    # Check CPU cores
    CORES=$(nproc)
    PHYSICAL_CORES=$(awk '/^cpu cores/ {print $4; exit}' /proc/cpuinfo)
    info "⚡ CPU: ${B}${CORES}${R} threads (${B}${PHYSICAL_CORES}${R} physical cores)"
    THREADS=${PHYSICAL_CORES:-$CORES}
    info "🔧 Will use ${B}${THREADS}${R} threads for inference."

    # Check for existing installation
    if command -v ollama &>/dev/null; then
        EXISTING_VER=$(ollama --version 2>/dev/null || echo "unknown")
        warn "Ollama already installed (${B}${EXISTING_VER}${R})"
        read -rp "$(echo -e "  ${BYEL}🔄 Reinstall/upgrade? [y/N] ${R}")" reinstall
        [[ "$reinstall" =~ ^[Yy]$ ]] || { info "Skipping install."; MODELS_ONLY=true; }
    fi

    # Check curl
    if ! command -v curl &>/dev/null; then
        err "curl is required. Run: ${CYN}sudo apt install curl${R}"
        exit 1
    fi

    echo
    ok "${BGRN}✓ Pre-flight checks passed.${R}"
fi

# ═══════════════════════════════════════════════════════════════
# INSTALL
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "📥 Installing Ollama"

    step "⬇️  Downloading and running official installer..."
    if $DRY_RUN; then
        echo -e "    ${DIM}▫ [dry-run]${R} curl -fsSL https://ollama.com/install.sh | sh"
    else
        curl -fsSL https://ollama.com/install.sh | sh
    fi

    echo
    ok "${BGRN}✓ Install complete.${R}"
fi

# ═══════════════════════════════════════════════════════════════
# CONFIGURE SYSTEMD
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "⚙️  Configuring systemd Service"

    step "🎯 Applying CPU-only performance tuning..."
    echo
    echo -e "    ${CYN}┌──────────────────────────────────────────┐${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_NUM_THREAD${R}      = ${GRN}${THREADS}${R}          ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_NUM_PARALLEL${R}     = ${GRN}${PARALLEL}${R}           ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_HOST${R}            = ${GRN}${OLLAMA_HOST}${R}   ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_PORT${R}            = ${GRN}${OLLAMA_PORT}${R}         ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_KEEP_ALIVE${R}      = ${GRN}5m${R}             ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_MAX_LOADED${R}      = ${GRN}2${R}              ${CYN}│${R}"
    echo -e "    ${CYN}└──────────────────────────────────────────┘${R}"
    echo

    OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
    OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

    if $DRY_RUN; then
        echo -e "    ${DIM}▫ [dry-run]${R} sudo mkdir -p $OVERRIDE_DIR"
        echo -e "    ${DIM}▫ [dry-run]${R} write $OVERRIDE_FILE"
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

    step "🔄 Reloading daemon and restarting service..."
    run "sudo systemctl daemon-reload"
    run "sudo systemctl enable ollama"
    run "sudo systemctl restart ollama"

    # Wait for service to be ready
    if ! $DRY_RUN; then
        info "⏳ Waiting for API to start..."
        for i in $(seq 1 10); do
            if curl -sf "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
                ok "${BGRN}✓ Ollama API responding on port ${OLLAMA_PORT}${R}"
                break
            fi
            echo -ne "    ${DIM}...${R}\r"
            sleep 1
            [[ $i -eq 10 ]] && warn "API not responding yet — check: systemctl status ollama"
        done
    fi

    echo
    ok "${BGRN}✓ Service configured.${R}"
fi

# ═══════════════════════════════════════════════════════════════
# PULL STARTER MODELS
# ═══════════════════════════════════════════════════════════════

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
    header "📦 Downloading Models"

    info "Models to be downloaded:"
    for m in "${STARTER_MODELS[@]}"; do
        echo -e "    ${CYN}●${R} ${B}$m${R}"
    done
    echo

    case "$HERMES_MODE" in
        offline) info "📊 Total: ${B}~18 GB${R} (gemma4 + gemma3:12b + embeddings)" ;;
        hybrid)  info "📊 Total: ${B}~18 GB${R} (gemma3:12b + gemma4 + embeddings)" ;;
        aux)     info "📊 Total: ${B}~8.5 GB${R} (gemma3:12b + embeddings)" ;;
        *)       info "📊 Total: ${B}~9.5 GB${R}" ;;
    esac
    echo

    if ! $DRY_RUN; then
        read -rp "$(echo -e "  ${BYEL}⬇  Download these models now? [Y/n] ${R}")" dl
    else
        dl="y"
    fi

    if [[ "$dl" =~ ^[Yy]?$ ]]; then
        for model in "${STARTER_MODELS[@]}"; do
            step "⬇️  Pulling ${B}${model}${R}..."
            if $DRY_RUN; then
                echo -e "    ${DIM}▫ [dry-run]${R} ollama pull $model"
            else
                ollama pull "$model"
                ok "✓ ${B}${model}${R} — done"
            fi
        done
        echo
        ok "${BGRN}✓ All models downloaded.${R}"
    else
        info "Skipping. Pull later with: ${CYN}ollama pull <model>${R}"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# CONFIGURE HERMES PRESETS
# ═══════════════════════════════════════════════════════════════

HERMES_BIN=""
if command -v hermes &>/dev/null; then
    HERMES_BIN="hermes"
elif [[ -x "$HOME/.hermes/hermes-agent/venv/bin/hermes" ]]; then
    HERMES_BIN="$HOME/.hermes/hermes-agent/venv/bin/hermes"
fi

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
    header "🤖 Configuring Hermes Agent"

    if [[ -z "$HERMES_BIN" ]]; then
        warn "Hermes CLI not found. Skipping Hermes configuration."
        warn "Configure manually using ${CYN}hermes config set${R} commands."
    elif [[ ! -f "$HERMES_CONFIG" ]]; then
        warn "No Hermes config at ${CYN}$HERMES_CONFIG${R}"
    else
        # ─── Interactive preset chooser ─────────────────────────
        if [[ "$HERMES_MODE" == "ask" ]]; then
            echo
            echo -e "  ${B}Choose a Hermes preset:${R}"
            echo
            echo -e "  ${BG_RED}${WHT}${B} 1 ${R} ${BRED}🔌 Full Offline${R}     ${DIM}— zero cloud dependency${R}"
            echo -e "     ${DIM}Main:${R} ${B}$HERMES_MAIN${R} ${DIM}| Aux:${R} ${B}$HERMES_AUX${R}"
            echo -e "     ${GRN}✓${R} No cloud API costs · Full privacy"
            echo
            echo -e "  ${BG_BLU}${WHT}${B} 2 ${R} ${BBLU}⚡ Hybrid ${BGRN}⭐${R}     ${DIM}— best of both worlds${R}"
            echo -e "     ${DIM}Main:${R} ${B}cloud${R} ${DIM}| Delegation + Aux:${R} ${B}local${R}"
            echo -e "     ${GRN}✓${R} Cloud quality chat · Local background tasks"
            echo
            echo -e "  ${BG_MAG}${WHT}${B} 3 ${R} ${BMAG}🎯 Auxiliary Only${R}   ${DIM}— minimal local footprint${R}"
            echo -e "     ${DIM}Main + Delegation:${R} ${B}cloud${R} ${DIM}| Aux:${R} ${B}local${R}"
            echo -e "     ${GRN}✓${R} Lowest resource use · Cloud handles heavy work"
            echo
            echo -e "  ${DIM} 4 Skip — use Ollama standalone${R}"
            echo

            if ! $DRY_RUN; then
                read -rp "$(echo -e "  ${BYEL}▶ Select preset [1-4]: ${R}")" choice
            else
                choice=1
                echo -e "    ${DIM}[dry-run] Selected: 1${R}"
            fi

            case "$choice" in
                1) HERMES_MODE="offline" ;;
                2) HERMES_MODE="hybrid" ;;
                3) HERMES_MODE="aux" ;;
                4) HERMES_MODE="" ;;
                *) err "Invalid choice."; HERMES_MODE="" ;;
            esac

            if [[ -n "$HERMES_MODE" ]]; then
                determine_hermes_models
            fi
        fi

        # ─── Apply presets ──────────────────────────────────────
        if [[ "$HERMES_MODE" == "reset" ]]; then
            step "🔄 Resetting Hermes to cloud/auto defaults..."

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

            ok "${BGRN}✓ Hermes reset to cloud/auto.${R}"

        elif [[ "$HERMES_MODE" == "offline" ]]; then
            step "🔌 Applying ${BRED}FULL OFFLINE${R} preset..."
            echo -e "    ${DIM}Main:${R} ${B}$HERMES_MAIN${R} ${DIM}| Delegation:${R} ${B}$HERMES_DELEGATION${R} ${DIM}| Aux:${R} ${B}$HERMES_AUX${R}"

            run "$HERMES_BIN config set providers.ollama.name Ollama"
            run "$HERMES_BIN config set providers.ollama.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set providers.ollama.api_key ${OLLAMA_KEY}"

            run "$HERMES_BIN config set model.default ${HERMES_MAIN}"
            run "$HERMES_BIN config set model.provider ollama"
            run "$HERMES_BIN config set model.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set model.api_key ${OLLAMA_KEY}"

            run "$HERMES_BIN config set delegation.provider ollama"
            run "$HERMES_BIN config set delegation.model ${HERMES_DELEGATION}"
            run "$HERMES_BIN config set delegation.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set delegation.api_key ${OLLAMA_KEY}"

            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_KANBAN"

            ok "${BGRN}✓ Full offline preset applied.${R}"

        elif [[ "$HERMES_MODE" == "hybrid" ]]; then
            step "⚡ Applying ${BBLU}HYBRID${R} ${BGRN}⭐${R} preset..."
            echo -e "    ${DIM}Main:${R} ${B}zai/glm-5.2${R} ${DIM}(cloud)${R} ${DIM}| Delegation:${R} ${B}$HERMES_DELEGATION${R} ${DIM}(local)${R} ${DIM}| Aux:${R} ${B}$HERMES_AUX${R} ${DIM}(local)${R}"

            run "$HERMES_BIN config set providers.ollama.name Ollama"
            run "$HERMES_BIN config set providers.ollama.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set providers.ollama.api_key ${OLLAMA_KEY}"

            run "$HERMES_BIN config set delegation.provider ollama"
            run "$HERMES_BIN config set delegation.model ${HERMES_DELEGATION}"
            run "$HERMES_BIN config set delegation.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set delegation.api_key ${OLLAMA_KEY}"

            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_KANBAN"

            ok "${BGRN}✓ Hybrid preset applied.${R} ${DIM}(main stays on cloud)${R}"

        elif [[ "$HERMES_MODE" == "aux" ]]; then
            step "🎯 Applying ${BMAG}AUXILIARY ONLY${R} preset..."
            echo -e "    ${DIM}Main + Delegation:${R} ${B}cloud${R} ${DIM}(unchanged)${R} ${DIM}| Aux:${R} ${B}$HERMES_AUX${R} ${DIM}(local)${R}"

            run "$HERMES_BIN config set providers.ollama.name Ollama"
            run "$HERMES_BIN config set providers.ollama.base_url ${OLLAMA_BASE}"
            run "$HERMES_BIN config set providers.ollama.api_key ${OLLAMA_KEY}"

            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_AUX"

            ok "${BGRN}✓ Auxiliary-only preset applied.${R}"
        fi

        # Backup + restart instructions
        if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
            step "💾 Backing up config..."
            if ! $DRY_RUN; then
                cp "$HERMES_CONFIG" "${HERMES_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
                ok "Backup saved."
            else
                echo -e "    ${DIM}▫ [dry-run]${R} cp $HERMES_CONFIG {timestamp}.bak"
            fi

            echo
            info "Changes take effect on next session or gateway restart:"
            echo -e "    ${CYN}systemctl --user restart hermes-gateway${R}"
            echo -e "    ${DIM}or type${R} ${CYN}/reset${R} ${DIM}in an active session${R}"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# VERIFY & SUMMARY
# ═══════════════════════════════════════════════════════════════
header "📊 Installation Summary"

if ! $DRY_RUN; then
    echo -e "  ${B}🔧 Service:${R}"
    if systemctl is-active ollama --no-pager 2>/dev/null | grep -q active; then
        echo -e "    ${BGRN}● active (running)${R}"
    else
        echo -e "    ${BRED}● inactive${R}"
    fi
    echo

    echo -e "  ${B}📌 Version:${R}"
    echo -ne "    "; ollama --version 2>/dev/null || echo "n/a"
    echo

    echo -e "  ${B}📦 Models:${R}"
    ollama list 2>/dev/null | while IFS= read -r line; do echo -e "    $line"; done || echo "    none"
    echo

    echo -e "  ${B}🌐 API:${R}"
    if curl -sf "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
        echo -e "    ${BGRN}✓ Responding${R} ${DIM}at http://${OLLAMA_HOST}:${OLLAMA_PORT}${R}"
    else
        echo -e "    ${BRED}✗ Not responding${R}"
    fi

    if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
        echo
        echo -e "  ${B}🤖 Hermes preset:${R} ${BMAG}${HERMES_MODE}${R}"
        BACKUP=$(ls -t ${HERMES_CONFIG}.bak.* 2>/dev/null | head -1)
        [[ -n "$BACKUP" ]] && echo -e "    ${DIM}💾 Backup:${R} ${CYN}${BACKUP}${R}"
    fi
else
    echo -e "  ${BYEL}⚠ [dry-run] No changes were made.${R}"
fi

echo
echo -e "  ${BG_GRN}${WHT}${B} ┌─────────────────────────────────────────────────┐ ${R}"
echo -e "  ${BG_GRN}${WHT}${B} │          🚀 Ollama is ready! 🦙                 │ ${R}"
echo -e "  ${BG_GRN}${WHT}${B} └─────────────────────────────────────────────────┘ ${R}"
echo
echo -e "  ${CYN}💬 Chat${R}        ollama run llama3.1:8b"
echo -e "  ${CYN}📋 List${R}        ollama list"
echo -e "  ${CYN}🌐 API${R}         http://${OLLAMA_HOST}:${OLLAMA_PORT}"
echo -e "  ${CYN}📊 Status${R}      systemctl status ollama"
echo -e "  ${CYN}📝 Logs${R}        journalctl -u ollama -f"
echo
if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
echo -e "  ${MAG}🤖 Hermes${R}      ${CYN}systemctl --user restart hermes-gateway${R}"
echo -e "  ${MAG}📋 Preset${R}      ${BMAG}${HERMES_MODE}${R}"
fi
echo
