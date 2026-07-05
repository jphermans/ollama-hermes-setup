#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  🦙 Local LLM Installer (Ollama / llama.cpp) with Hermes Agent Integration
#
#  Cross-platform: Linux · macOS · WSL2
#  Backends: Ollama (default) or llama.cpp (llama-server)
#  Auto-detects hardware (CPU, RAM, GPU, platform) and recommends
#  the best model configuration for your machine.
#
#  Usage:  bash ollama-setup.sh              # Interactive menu
#          bash ollama-setup.sh [flags]       # Direct mode
#
#  Flags:
#    --ollama          Use Ollama as backend (default)
#    --llamacpp        Use llama.cpp (llama-server) as backend
#    --no-models       Skip downloading starter models
#    --models-only     Only pull models (already installed)
#    --dry-run         Show what would happen without doing anything
#    --uninstall       Remove completely
#    --hermes          Configure Hermes presets (interactive)
#    --hermes-offline  Configure Hermes for full-offline (non-interactive)
#    --hermes-hybrid   Configure Hermes hybrid: cloud main + local aux
#    --hermes-aux      Configure Hermes: local auxiliary only
#    --hermes-reset    Reset Hermes config back to cloud/auto
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

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
warn()  { echo -e "  ${YEL}⚠${R}  $*"; }
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
    echo -e "  ${BCYN}  / _ \\/ __ \\| |/ / |/ / |/ /${R}"
    echo -e "  ${BCYN} / , _/ /_/ /| / /| / <| / < ${R}"
    echo -e "  ${BCYN}/_/|_|\\____/_|/_/ |_/\\_\\|_/\\_\\\\${R}  ${DIM}Setup Script${R}"
    echo -e "  ${DIM}─────────────────────────────────────────${R}"
    echo -e "  ${BBLU}🦙 Local LLM${R} + ${BMAG}🤖 Hermes Agent${R} ${DIM}| Cross-platform${R}"
    echo
}


# ═══════════════════════════════════════════════════════════════
# BACKEND CHOOSER
# ═══════════════════════════════════════════════════════════════
choose_backend() {
    echo -e "  ${B}Choose your local LLM backend:${R}"
    echo
    echo -e "  ${BG_GRN}${WHT}${B} 1 ${R} ${BGRN}🦙 Ollama${R} ${BGRN}⭐${R}"
    echo -e "     ${DIM}Easiest to use — one command to pull and run models${R}"
    echo -e "     ${DIM}Built-in model management, Modelfiles, auto-quantization${R}"
    echo -e "     ${DIM}Best for: most users, quick setup${R}"
    echo
    echo -e "  ${BG_BLU}${WHT}${B} 2 ${R} ${BBLU}🔧 llama.cpp (llama-server)${R}"
    echo -e "     ${DIM}Lightweight C++ server with OpenAI-compatible API${R}"
    echo -e "     ${DIM}Manual GGUF model management, more control${R}"
    echo -e "     ${DIM}Best for: advanced users, custom builds, lower overhead${R}"
    echo
    echo -e "  ${DIM} q  Exit${R}"
    echo
    read -rp "$(echo -e "  ${BYEL}▶ Select backend [1-2/q]: ${R}")" backend_choice
    case "$backend_choice" in
        1) BACKEND="ollama" ;;
        2) BACKEND="llamacpp" ;;
        q|Q|quit|exit) echo -e "  ${DIM}Bye! 👋${R}"; exit 0 ;;
        *) err "Invalid option: ${BRED}$backend_choice${R}"; exit 2 ;;
    esac
    echo
}

# ═══════════════════════════════════════════════════════════════
# PLATFORM DETECTION
# ═══════════════════════════════════════════════════════════════
detect_platform() {
    PLATFORM="unknown"
    PLATFORM_LABEL="Unknown"
    HAS_SYSTEMD=false
    IS_SBC=false    # Single-board computer (Raspberry Pi, etc.)
    SBC_MODEL=""

    case "$(uname -s)" in
        Linux)
            # Check if running under WSL2
            if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
                PLATFORM="wsl2"
                PLATFORM_LABEL="WSL2"
                # WSL2 may or may not have systemd
                if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
                    HAS_SYSTEMD=true
                fi
            else
                PLATFORM="linux"
                PLATFORM_LABEL="Linux"
                if command -v systemctl &>/dev/null; then
                    HAS_SYSTEMD=true
                fi
            fi

            # SBC detection (Raspberry Pi, Orange Pi, etc.)
            if [[ -f /proc/device-tree/model ]]; then
                SBC_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || true)
                if [[ -n "$SBC_MODEL" ]]; then
                    IS_SBC=true
                fi
            fi
            ;;
        Darwin)
            PLATFORM="macos"
            PLATFORM_LABEL="macOS"
            ;;
        *)
            PLATFORM="unknown"
            PLATFORM_LABEL="$(uname -s)"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# HARDWARE DETECTION (platform-aware)
# ═══════════════════════════════════════════════════════════════
detect_hardware() {
    # ── Architecture ──
    ARCH=$(uname -m)

    # ── Platform-specific RAM/CPU/Disk ──
    case "$PLATFORM" in
        linux|wsl2)
            # RAM
            RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
            # Swap
            SWAP_GB=$(awk '/SwapTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
            # CPU
            CPU_THREADS=$(nproc)
            CPU_CORES=$(awk '/^cpu cores/ {print $4; exit}' /proc/cpuinfo)
            CPU_MODEL=$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo)
            if [[ -z "$CPU_CORES" ]]; then CPU_CORES=$CPU_THREADS; fi
            # Disk
            AVAIL_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
            ;;
        macos)
            # RAM
            RAM_GB=$(($(sysctl -n hw.memsize) / 1073741824))
            SWAP_GB=0
            # CPU
            CPU_CORES=$(sysctl -n hw.physicalcpu)
            CPU_THREADS=$(sysctl -n hw.logicalcpu)
            CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
            # Disk
            AVAIL_GB=$(df -g / | awk 'NR==2 {print $4}')
            ;;
        *)
            # Fallback
            RAM_GB=8
            SWAP_GB=0
            CPU_CORES=2
            CPU_THREADS=4
            CPU_MODEL="Unknown"
            AVAIL_GB=20
            ;;
    esac

    # ── GPU Detection ──
    HAS_GPU=false
    GPU_NAME=""
    GPU_VRAM_MB=0
    IS_APPLE_SILICON=false

    case "$PLATFORM" in
        linux|wsl2)
            if command -v nvidia-smi &>/dev/null; then
                GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)
                GPU_VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
                if [[ -n "$GPU_NAME" && "$GPU_VRAM_MB" =~ ^[0-9]+$ && "$GPU_VRAM_MB" -gt 0 ]]; then
                    HAS_GPU=true
                else
                    GPU_NAME=""
                    GPU_VRAM_MB=0
                fi
            fi
            ;;
        macos)
            # Apple Silicon: unified memory acts as VRAM via Metal
            CPU_ARCH=$(uname -m)
            if [[ "$CPU_ARCH" == "arm64" ]]; then
                IS_APPLE_SILICON=true
                CHIP_NAME=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
                GPU_NAME="$CHIP_NAME (Metal)"
                # Apple Silicon uses unified memory — a portion of RAM is available as VRAM
                # Conservative: assume 70% of RAM available for GPU (OS needs the rest)
                GPU_VRAM_MB=$(( RAM_GB * 1024 * 70 / 100 ))
                HAS_GPU=true
            fi
            ;;
    esac

    # ── Determine hardware tier ──
    # ARM SBCs (Raspberry Pi, etc.) get more conservative tiers
    # because ARM cores are slower per-clock than x86/Apple Silicon
    HW_TIER="cpu-tiny"

    if $IS_SBC; then
        # ── SBC tiers (Raspberry Pi, etc.) — conservative ──
        if (( RAM_GB >= 16 )); then
            HW_TIER="sbc-high"
        elif (( RAM_GB >= 8 )); then
            HW_TIER="sbc-mid"
        elif (( RAM_GB >= 4 )); then
            HW_TIER="sbc-low"
        else
            HW_TIER="sbc-tiny"
        fi
    elif $HAS_GPU; then
        # ── GPU tiers ──
        if $IS_APPLE_SILICON; then
            if (( RAM_GB >= 64 )); then
                HW_TIER="apple-silicon-large"
            elif (( RAM_GB >= 32 )); then
                HW_TIER="apple-silicon-mid"
            else
                HW_TIER="apple-silicon-small"
            fi
        elif (( GPU_VRAM_MB >= 24000 )); then
            HW_TIER="gpu-large"
        elif (( GPU_VRAM_MB >= 12000 )); then
            HW_TIER="gpu-mid"
        elif (( GPU_VRAM_MB >= 6000 )); then
            HW_TIER="gpu-small"
        else
            HW_TIER="gpu-tiny"
        fi
    elif (( RAM_GB >= 32 )); then
        HW_TIER="cpu-high"
    elif (( RAM_GB >= 16 )); then
        HW_TIER="cpu-mid"
    elif (( RAM_GB >= 8 )); then
        HW_TIER="cpu-low"
    else
        HW_TIER="cpu-tiny"
    fi

    # ── Auto-configure models based on tier ──
    case "$HW_TIER" in
        apple-silicon-large)
            # M-series with 64GB+ unified memory — large models via Metal
            HERMES_MAIN="qwen2.5:32b"
            HERMES_DELEGATION="qwen2.5:32b"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="qwen2.5:32b"
            STARTER_MODELS=("qwen2.5:32b" "gemma3:12b" "nomic-embed-text")
            MAX_LOADED=3
            ;;
        apple-silicon-mid)
            # M-series with 32GB unified memory — medium-large models
            HERMES_MAIN="gemma4:latest"
            HERMES_DELEGATION="gemma4:latest"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="gemma4:latest"
            STARTER_MODELS=("gemma4:latest" "gemma3:12b" "nomic-embed-text")
            MAX_LOADED=2
            ;;
        apple-silicon-small)
            # M-series with 16GB unified memory — 7B-12B models
            HERMES_MAIN="gemma4:latest"
            HERMES_DELEGATION="gemma4:latest"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="gemma4:latest"
            STARTER_MODELS=("gemma4:latest" "nomic-embed-text")
            MAX_LOADED=2
            ;;
        gpu-large)
            # 24GB+ VRAM
            HERMES_MAIN="qwen2.5:32b"
            HERMES_DELEGATION="qwen2.5:32b"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="qwen2.5:32b"
            STARTER_MODELS=("qwen2.5:32b" "gemma3:12b" "nomic-embed-text")
            MAX_LOADED=3
            ;;
        gpu-mid)
            # 12-24GB VRAM
            HERMES_MAIN="gemma4:latest"
            HERMES_DELEGATION="gemma4:latest"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="gemma4:latest"
            STARTER_MODELS=("gemma4:latest" "gemma3:12b" "nomic-embed-text")
            MAX_LOADED=2
            ;;
        gpu-small)
            # 6-12GB VRAM
            HERMES_MAIN="gemma4:latest"
            HERMES_DELEGATION="gemma4:latest"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="gemma4:latest"
            STARTER_MODELS=("gemma4:latest" "gemma3:12b" "nomic-embed-text")
            MAX_LOADED=2
            ;;
        gpu-tiny)
            # <6GB VRAM
            HERMES_MAIN="llama3.1:8b"
            HERMES_DELEGATION="llama3.1:8b"
            HERMES_AUX="llama3.1:8b"
            HERMES_KANBAN="llama3.1:8b"
            STARTER_MODELS=("llama3.1:8b" "nomic-embed-text")
            MAX_LOADED=1
            ;;
        cpu-high)
            # 32GB+ RAM, CPU-only x86
            HERMES_MAIN="gemma4:latest"
            HERMES_DELEGATION="gemma4:latest"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="gemma4:latest"
            STARTER_MODELS=("llama3.1:8b" "qwen2.5-coder:7b" "nomic-embed-text")
            MAX_LOADED=2
            ;;
        cpu-mid)
            # 16-32GB RAM, CPU-only x86
            HERMES_MAIN="llama3.1:8b"
            HERMES_DELEGATION="llama3.1:8b"
            HERMES_AUX="gemma3:12b"
            HERMES_KANBAN="llama3.1:8b"
            STARTER_MODELS=("llama3.1:8b" "nomic-embed-text")
            MAX_LOADED=2
            ;;
        cpu-low)
            # 8-16GB RAM, CPU-only x86
            HERMES_MAIN="llama3.2:3b"
            HERMES_DELEGATION="llama3.2:3b"
            HERMES_AUX="llama3.2:3b"
            HERMES_KANBAN="llama3.2:3b"
            STARTER_MODELS=("llama3.2:3b" "nomic-embed-text")
            MAX_LOADED=1
            ;;
        cpu-tiny)
            # <8GB RAM, CPU-only x86
            HERMES_MAIN="llama3.2:1b"
            HERMES_DELEGATION="llama3.2:1b"
            HERMES_AUX="llama3.2:1b"
            HERMES_KANBAN="llama3.2:1b"
            STARTER_MODELS=("llama3.2:1b" "nomic-embed-text")
            MAX_LOADED=1
            ;;
        sbc-high)
            # SBC with 16GB+ RAM (rare, e.g. RPi 5 with 16GB mod)
            HERMES_MAIN="llama3.2:3b"
            HERMES_DELEGATION="llama3.2:3b"
            HERMES_AUX="llama3.2:3b"
            HERMES_KANBAN="llama3.2:3b"
            STARTER_MODELS=("llama3.2:3b" "nomic-embed-text")
            MAX_LOADED=1
            ;;
        sbc-mid)
            # SBC with 8GB RAM (RPi 5 8GB)
            HERMES_MAIN="llama3.2:3b"
            HERMES_DELEGATION="llama3.2:3b"
            HERMES_AUX="llama3.2:1b"
            HERMES_KANBAN="llama3.2:3b"
            STARTER_MODELS=("llama3.2:3b" "nomic-embed-text")
            MAX_LOADED=1
            ;;
        sbc-low)
            # SBC with 4-8GB RAM
            HERMES_MAIN="llama3.2:1b"
            HERMES_DELEGATION="llama3.2:1b"
            HERMES_AUX="llama3.2:1b"
            HERMES_KANBAN="llama3.2:1b"
            STARTER_MODELS=("llama3.2:1b" "nomic-embed-text")
            MAX_LOADED=1
            ;;
        sbc-tiny)
            # SBC with <4GB RAM
            HERMES_MAIN="llama3.2:1b"
            HERMES_DELEGATION="llama3.2:1b"
            HERMES_AUX="llama3.2:1b"
            HERMES_KANBAN="llama3.2:1b"
            STARTER_MODELS=("llama3.2:1b")
            MAX_LOADED=1
            ;;
    esac

    # Threads = physical cores
    DETECTED_THREADS=$CPU_CORES
    if [[ "$DETECTED_THREADS" -lt 1 ]]; then
        DETECTED_THREADS=$CPU_THREADS
    fi
}

# ═══════════════════════════════════════════════════════════════
# DEFAULTS
# ═══════════════════════════════════════════════════════════════
OLLAMA_HOST="127.0.0.1"
OLLAMA_PORT=11434
OLLAMA_KEY="ollama"
THREADS=0
PARALLEL=1
MAX_LOADED=2

HERMES_MAIN=""
HERMES_DELEGATION=""
HERMES_AUX=""
HERMES_KANBAN=""
STARTER_MODELS=()

AUX_CORE_SLOTS=(vision web_extract compression title_generation)
AUX_EXTENDED_SLOTS=(approval triage_specifier session_search curator profile_describer)

# Run detection
detect_platform
detect_hardware
THREADS=$DETECTED_THREADS
OLLAMA_BASE="http://${OLLAMA_HOST}:${OLLAMA_PORT}/v1"

# ─── Flags ──────────────────────────────────────────────────────
DRY_RUN=false
NO_MODELS=false
MODELS_ONLY=false
UNINSTALL=false
HERMES_MODE=""
HF_MODEL=""
HF_LIST=false
MCP_SCAN=false
SKILLS_CHECK=false
BACKEND=""  # Set by flag or interactive chooser

for arg in "$@"; do
    case "$arg" in
        --dry-run)         DRY_RUN=true ;;
        --no-models)       NO_MODELS=true ;;
        --models-only)     MODELS_ONLY=true ;;
        --uninstall)       UNINSTALL=true ;;
        --ollama)          BACKEND="ollama" ;;
        --llamacpp)        BACKEND="llamacpp" ;;
        --hermes)          HERMES_MODE="ask" ;;
        --hermes-offline)  HERMES_MODE="offline" ;;
        --hermes-hybrid)   HERMES_MODE="hybrid" ;;
        --hermes-aux)      HERMES_MODE="aux" ;;
        --hermes-reset)    HERMES_MODE="reset" ;;
        --hf-model)        HF_MODEL="${2:-}"; shift || true ;;
        --hf-list)         HF_LIST=true ;;
        --mcp-scan)        MCP_SCAN=true ;;
        --skills-check)    SKILLS_CHECK=true ;;
        --help|-h)
            echo -e "\n  ${B}🦙 Local LLM + 🤖 Hermes Agent Setup Script${R}\n"
            echo -e "  ${B}Backends:${R} ${CYN}Ollama (default) · llama.cpp${R}"
            echo -e "  ${B}Platforms:${R} ${CYN}Linux · macOS · WSL2${R} ${DIM}(x86_64 + arm64)${R}\n"
            echo -e "  ${B}Usage:${R}"
            echo -e "    ${CYN}bash ollama-setup.sh${R}                 ${DIM}# Interactive menu${R}"
            echo -e "    ${CYN}bash ollama-setup.sh [flags]${R}        ${DIM}# Direct mode${R}\n"
            echo -e "  ${B}Backend:${R}"
            echo -e "    ${CYN}--ollama${R}          ${DIM}Use Ollama as backend (default)${R}"
            echo -e "    ${CYN}--llamacpp${R}        ${DIM}Use llama.cpp (llama-server) as backend${R}\n"
            echo -e "  ${B}Flags:${R}"
            echo -e "    ${CYN}--hermes-hybrid${R}   ${DIM}Install + hybrid preset (recommended)${R}"
            echo -e "    ${CYN}--hermes-offline${R}  ${DIM}Install + full offline preset${R}"
            echo -e "    ${CYN}--hermes-aux${R}      ${DIM}Install + auxiliary-only preset${R}"
            echo -e "    ${CYN}--hermes${R}          ${DIM}Install + interactive preset chooser${R}"
            echo -e "    ${CYN}--hermes-reset${R}    ${DIM}Reset Hermes to cloud/auto defaults${R}"
            echo -e "    ${CYN}--models-only${R}     ${DIM}Skip install, only pull models${R}"
            echo -e "    ${CYN}--no-models${R}       ${DIM}Skip model downloads${R}"
            echo -e "    ${CYN}--hf-model${R} <id>   ${DIM}Import a GGUF model from HuggingFace${R}"
            echo -e "    ${CYN}--hf-list${R}         ${DIM}Show popular HuggingFace GGUF models${R}"
            echo -e "    ${CYN}--mcp-scan${R}        ${DIM}Scan Hermes MCP servers for Ollama-compatible tools${R}"
            echo -e "    ${CYN}--skills-check${R}    ${DIM}Check for Hermes skills that use Ollama${R}"
            echo -e "    ${CYN}--dry-run${R}         ${DIM}Preview without changes${R}"
            echo -e "    ${CYN}--uninstall${R}       ${DIM}Remove Ollama completely${R}"
            echo -e "    ${CYN}--help${R}            ${DIM}Show this help${R}\n"
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

# ═══════════════════════════════════════════════════════════════
# BACKEND SELECTION
# ═══════════════════════════════════════════════════════════════
if [[ -z "$BACKEND" ]]; then
    choose_backend
fi

if [[ "$BACKEND" == "llamacpp" ]]; then
    LLAMACPP_DIR="$HOME/.local/share/llamacpp"
    LLAMACPP_MODELS_DIR="$LLAMACPP_DIR/models"
    LLAMACPP_PORT=8080
    LLAMACPP_HOST="127.0.0.1"
    LLAMACPP_BASE="http://${LLAMACPP_HOST}:${LLAMACPP_PORT}/v1"
    BACKEND_LABEL="🔧 llama.cpp"
else
    BACKEND="ollama"
    BACKEND_LABEL="🦙 Ollama"
fi

# ═══════════════════════════════════════════════════════════════
# INTERACTIVE MAIN MENU
# ═══════════════════════════════════════════════════════════════
if [[ $# -eq 0 ]]; then
    echo -e "  ${B}Welcome! What would you like to do?${R}"
    echo
    echo -e "  ${BG_GRN}${WHT}${B} 1 ${R} ${BGRN}🚀 Full Install + Hermes Hybrid${R} ${BGRN}⭐${R}"
    echo -e "     ${DIM}Install Ollama + tune performance + download models${R}"
    echo -e "     ${DIM}Configure Hermes with the recommended hybrid preset${R}"
    echo -e "     ${DIM}(cloud for chat, local for background tasks)${R}"
    echo
    echo -e "  ${BG_BLU}${WHT}${B} 2 ${R} ${BBLU}⚙️  Full Install Only${R}"
    echo -e "     ${DIM}Install Ollama + tune performance + download starter models${R}"
    echo -e "     ${DIM}No Hermes configuration (standalone Ollama)${R}"
    echo
    echo -e "  ${BG_MAG}${WHT}${B} 3 ${R} ${BMAG}🤖 Configure Hermes Only${R}"
    echo -e "     ${DIM}Ollama is already installed — just set up Hermes presets${R}"
    echo -e "     ${DIM}Shows the preset chooser (offline / hybrid / aux-only)${R}"
    echo
    echo -e "  ${BG_YEL}${WHT}${B} 4 ${R} ${BYEL}📦 Download Models Only${R}"
    echo -e "     ${DIM}Pull specific models without installing or configuring${R}"
    echo
    echo -e "  ${BG_CYN}${WHT}${B} 5 ${R} ${BCYN}👁️  Dry Run Preview${R}"
    echo -e "     ${DIM}See exactly what would happen without changing anything${R}"
    echo
    echo -e "  ${BG_RED}${WHT}${B} 6 ${R} ${BRED}🗑️  Uninstall Ollama${R}"
    echo -e "     ${DIM}Remove Ollama, service, models, and user account${R}"
    echo
    echo -e "  ${DIM} q  Exit${R}"
    echo

    read -rp "$(echo -e "  ${BYEL}▶ Select an option [1-6/q]: ${R}")" menu_choice

    case "$menu_choice" in
        1) HERMES_MODE="hybrid" ;;
        2) ;;
        3) MODELS_ONLY=true; HERMES_MODE="ask" ;;
        4) MODELS_ONLY=true ;;
        5) DRY_RUN=true; HERMES_MODE="hybrid" ;;
        6) UNINSTALL=true ;;
        q|Q|quit|exit)
            echo -e "  ${DIM}Bye! 👋${R}"
            exit 0
            ;;
        *)
            err "Invalid option: ${BRED}$menu_choice${R}"
            echo -e "  ${DIM}Tip: Run ${CYN}bash ollama-setup.sh --help${R} to see all flags.${R}"
            exit 2
            ;;
    esac
    echo
fi

# ═══════════════════════════════════════════════════════════════
# HUGGINGFACE MODEL IMPORT
# ═══════════════════════════════════════════════════════════════
show_hf_models() {
    header "🤗 HuggingFace GGUF Models for Your Hardware"

    # Show detected hardware context
    echo -e "  ${DIM}Detected:${R} ${B}${HW_TIER}${R} ${DIM}| RAM:${R} ${B}${RAM_GB} GB${R} ${DIM}| Disk:${R} ${B}${AVAIL_GB} GB${R}"
    if $HAS_GPU; then
        echo -e "  ${DIM}GPU:${R} ${B}${GPU_NAME}${R}"
    else
        echo -e "  ${DIM}GPU:${R} None (CPU-only)"
    fi
    echo

    # Calculate usable RAM for models (leave 25% for OS)
    USABLE_RAM=$(( RAM_GB * 75 / 100 ))
    # For Apple Silicon, allow more (unified memory)
    if $IS_APPLE_SILICON; then
        USABLE_RAM=$(( RAM_GB * 85 / 100 ))
    fi

    echo -e "  ${B}Format:${R} ${CYN}--hf-model org/repo:filename${R} ${DIM}or${R} ${CYN}--hf-model org/repo${R}"
    echo -e "  ${B}Usable RAM:${R} ~${B}${USABLE_RAM} GB${R} ${DIM}(75% of total, leaving room for OS)${R}"
    echo

    # ── Helper: show a model with fit indicator ──
    # Args: repo, label, size_gb (number only), min_ram_gb (number only)
    print_model() {
        local repo="$1"
        local label="$2"
        local size_gb="$3"
        local min_ram="$4"

        local fit="✅ Smooth"
        local fit_color="$GRN"

        if (( min_ram > USABLE_RAM )); then
            fit="❌ Too large"
            fit_color="$RED"
        elif (( min_ram > USABLE_RAM * 80 / 100 )); then
            fit="⚠️  Tight"
            fit_color="$YEL"
        fi

        # Disk check (convert size to integer for comparison)
        local size_int="${size_gb%.*}"
        if (( size_int > AVAIL_GB )); then
            fit="❌ No disk"
            fit_color="$RED"
        fi

        echo -e "    ${fit_color}${fit}${R}  ${CYN}${repo}${R}"
        echo -e "           ${DIM}${label} | ~${size_gb} GB disk | needs ${min_ram} GB RAM${R}"
    }

    # ── General Purpose ──
    echo -e "  ${B}💬 General Purpose${R}"
    echo
    print_model "bartowski/Llama-3.2-1B-Instruct-GGUF"     "Tiny, fast"            "1.1" 2
    print_model "bartowski/Llama-3.2-3B-Instruct-GGUF"     "Small, balanced"       "2.0" 4
    print_model "bartowski/Qwen2.5-7B-Instruct-GGUF"       "Strong all-rounder"   "4.7" 8
    print_model "bartowski/Llama-3.1-8B-Instruct-GGUF"     "General purpose"       "4.9" 8
    print_model "bartowski/gemma-2-9b-it-GGUF"             "High quality"          "5.5" 10
    print_model "bartowski/Qwen2.5-14B-Instruct-GGUF"      "Strong reasoning"      "9.0" 14
    print_model "bartowski/Qwen2.5-32B-Instruct-GGUF"      "Excellent quality"     "19.5" 28
    echo

    # ── Coding ──
    echo -e "  ${B}💻 Coding${R}"
    echo
    print_model "bartowski/Qwen2.5-Coder-3B-Instruct-GGUF"   "Light coding"          "2.0" 4
    print_model "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF"   "Code generation"       "4.7" 8
    print_model "bartowski/Qwen2.5-Coder-14B-Instruct-GGUF"  "Complex multi-file"    "9.0" 14
    print_model "bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF" "Multi-language"   "9.0" 14
    echo

    # ── Reasoning ──
    echo -e "  ${B}🧠 Reasoning (Chain-of-Thought)${R}"
    echo
    print_model "bartowski/deepseek-r1-Distill-Qwen-1.5B-GGUF" "Tiny reasoning"      "1.1" 2
    print_model "bartowski/deepseek-r1-Distill-Qwen-7B-GGUF"   "Fast reasoning"      "4.7" 8
    print_model "bartowski/deepseek-r1-Distill-Qwen-14B-GGUF"  "Deep reasoning"      "9.0" 14
    print_model "bartowski/deepseek-r1-Distill-Qwen-32B-GGUF"  "Best local reasoning" "19.5" 28
    echo

    # ── Vision / Multimodal ──
    echo -e "  ${B}🖼️ Vision / Multimodal${R}"
    echo
    print_model "bartowski/llama-3.2-11B-Vision-Instruct-GGUF" "Image understanding" "6.5" 12
    print_model "bartowski/gemma-2-27B-it-GGUF"                "Large general purpose" "16.0" 24
    echo

    # ── Embeddings ──
    echo -e "  ${B}🔤 Embeddings (for RAG / Semantic Search)${R}"
    echo
    print_model "nomic-ai/nomic-embed-text-v1.5-GGUF"        "Lightweight, fast"      "0.1" 1
    print_model "mixedbread-ai/mxbai-embed-large-v1-GGUF"    "High quality retrieval" "0.7" 2
    echo

    # ── Summary ──
    echo -e "  ${DIM}──────────────────────────────────────────${R}"
    echo -e "  ${B}Legend:${R}  ${GRN}✅ Smooth${R}  ${YEL}⚠️ Tight${R}  ${RED}❌ Too large${R}"
    echo
    echo -e "  ${DIM}Tip: Omit the filename to auto-pick the Q4_K_M variant.${R}"
    echo -e "  ${DIM}Browse more: https://huggingface.co/models?library=gguf${R}"
    echo
    exit 0
}

import_hf_model() {
    local hf_id="$1"
    header "🤗 Import from HuggingFace"

    # Parse org/repo:filename or org/repo
    local repo=""
    local filename=""

    if [[ "$hf_id" == *":"* ]]; then
        repo="${hf_id%%:*}"
        filename="${hf_id#*:}"
    else
        repo="$hf_id"
    fi

    info "📦 Repo: ${B}$repo${R}"
    [[ -n "$filename" ]] && info "📄 File: ${B}$filename${R}"

    # Check if huggingface-cli is available (preferred)
    if command -v huggingface-cli &>/dev/null; then
        info "Using huggingface-cli to download..."

        # If no filename specified, try to find Q4_K_M
        if [[ -z "$filename" ]]; then
            step "🔍 Finding best quantization (Q4_K_M)..."
            # List files and pick Q4_K_M
            local all_files
            all_files=$(huggingface-cli repo files "$repo" 2>/dev/null || true)
            filename=$(echo "$all_files" | grep -i "Q4_K_M" | head -1 || true)
            if [[ -z "$filename" ]]; then
                # Fallback: pick first .gguf
                filename=$(echo "$all_files" | grep -i '\.gguf$' | head -1 || true)
            fi
            if [[ -z "$filename" ]]; then
                err "No GGUF file found in $repo. Specify explicitly: --hf-model $repo:filename.gguf"
                exit 1
            fi
            info "📄 Auto-selected: ${B}$filename${R}"
        fi

        # Download via huggingface-cli
        local tmp_dir
        tmp_dir=$(mktemp -d)
        step "⬇️  Downloading..."
        if $DRY_RUN; then
            echo -e "    ${DIM}▫ [dry-run]${R} huggingface-cli download $repo $filename --local-dir $tmp_dir"
        else
            huggingface-cli download "$repo" "$filename" --local-dir "$tmp_dir" --local-dir-use-symlinks False
        fi

        # Register with Ollama
        local model_name
        model_name=$(basename "$repo" | tr '[:upper:]' '[:lower:]')
        step "🦙 Registering with Ollama as ${B}$model_name${R}..."
        if ! $DRY_RUN; then
            # Create a Modelfile and import
            cat > "$tmp_dir/Modelfile" <<MEOF
FROM ./$filename
MEOF
            (cd "$tmp_dir" && ollama create "$model_name" -f Modelfile)
            ok "✓ Model ${B}$model_name${R} imported from HuggingFace"
            rm -rf "$tmp_dir"
        fi
    else
        # No huggingface-cli — use curl directly
        warn "huggingface-cli not found. Using direct download."
        info "Install for better experience: ${CYN}pip install huggingface-hub${R}"

        if [[ -z "$filename" ]]; then
            # Try common Q4_K_M pattern
            filename="${repo##*/}-Q4_K_M.gguf"
            warn "Guessing filename: $filename"
            warn "If wrong, specify: --hf-model $repo:exact-file.gguf"
        fi

        local download_url="https://huggingface.co/$repo/resolve/main/$filename"
        local tmp_file="/tmp/$(basename "$filename")"
        local model_name
        model_name=$(basename "$repo" | tr '[:upper:]' '[:lower:]')

        step "⬇️  Downloading $filename..."
        if $DRY_RUN; then
            echo -e "    ${DIM}▫ [dry-run]${R} curl -L $download_url -o $tmp_file"
        else
            curl -L "$download_url" -o "$tmp_file"
        fi

        step "🦙 Registering with Ollama as ${B}$model_name${R}..."
        if ! $DRY_RUN; then
            cat > "/tmp/Modelfile-$model_name" <<MEOF
FROM $tmp_file
MEOF
            ollama create "$model_name" -f "/tmp/Modelfile-$model_name"
            ok "✓ Model ${B}$model_name${R} imported"
            rm -f "$tmp_file" "/tmp/Modelfile-$model_name"
        fi
    fi

    echo
    info "Run with: ${CYN}ollama run ${model_name}${R}"
    exit 0
}

# ═══════════════════════════════════════════════════════════════
# MCP SERVER SCAN
# ═══════════════════════════════════════════════════════════════
scan_mcp_servers() {
    header "🔌 MCP Server Scan"
    info "Scanning Hermes MCP config for Ollama-compatible tools...\n"

    local config_file="$HOME/.hermes/config.yaml"

    if [[ ! -f "$config_file" ]]; then
        warn "No Hermes config found."
        exit 0
    fi

    # Extract MCP server names
    local servers=()
    while IFS= read -r line; do
        local name
        name=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/:.*//')
        [[ -n "$name" ]] && servers+=("$name")
    done < <(grep -A1 "^mcp_servers:" "$config_file" | grep -E "^\s+\w+:" | head -20 || true)

    # Also try Python YAML parse for reliability
    if [[ ${#servers[@]} -eq 0 ]]; then
        servers=$(python3 -c "
import yaml
try:
    c = yaml.safe_load(open('$config_file'))
    mcps = c.get('mcp_servers', {})
    for name in mcps:
        print(name)
except:
    pass
" 2>/dev/null || true)
    fi

    if [[ -z "$servers" ]]; then
        warn "No MCP servers found in config."
        exit 0
    fi

    info "Found ${B}$(echo "$servers" | wc -w)${R} MCP server(s):"
    echo

    local ollama_related=0
    for srv in $servers; do
        # Check if this server might benefit from local Ollama
        local lower_srv
        lower_srv=$(echo "$srv" | tr '[:upper:]' '[:lower:]')
        local relevant=""

        case "$lower_srv" in
            *code*|*runner*)     relevant="💻 Can use Ollama for code execution LLM" ;;
            *fetch*|*extract*)   relevant="🌐 Can use Ollama for web extraction" ;;
            *search*)            relevant="🔍 Can use Ollama embeddings for search" ;;
            *git*|*github*)      relevant="📦 May use Ollama for commit messages" ;;
            *filesystem*)        relevant="📂 May use Ollama for file analysis" ;;
        esac

        if [[ -n "$relevant" ]]; then
            echo -e "    ${GRN}●${R} ${B}$srv${R} ${DIM}$relevant${R}"
            (( ollama_related++ )) || true
        else
            echo -e "    ${DIM}○ $srv${R}"
        fi
    done

    echo
    if (( ollama_related > 0 )); then
        info "💡 ${B}${ollama_related}${R} MCP server(s) can benefit from local Ollama."
        info "   They will automatically use Ollama if configured in Hermes auxiliary slots."
    else
        info "No MCP servers directly benefit from Ollama, but embeddings (nomic-embed-text)"
        info "can still accelerate semantic search features."
    fi
    echo
    exit 0
}

# ═══════════════════════════════════════════════════════════════
# HERMES SKILLS CHECK
# ═══════════════════════════════════════════════════════════════
check_skills() {
    header "🧩 Hermes Skills Check"
    info "Scanning for skills that work with Ollama...\n"

    local skills_dir="$HOME/.hermes/skills"
    local found=0

    if [[ ! -d "$skills_dir" ]]; then
        warn "No skills directory found at $skills_dir"
        exit 0
    fi

    # Find skills that mention ollama
    local ollama_skills=()
    while IFS= read -r file; do
        local skill_name
        skill_name=$(basename "$(dirname "$file")")
        ollama_skills+=("$skill_name")
        (( found++ )) || true
    done < <(grep -rl -i "ollama" "$skills_dir"/*/SKILL.md 2>/dev/null || true)

    if (( found > 0 )); then
        info "Found ${B}${found}${R} skill(s) referencing Ollama:"
        echo
        for skill in "${ollama_skills[@]}"; do
            echo -e "    ${GRN}●${R} ${B}$skill${R}"
        done
        echo
        info "These skills can leverage your local Ollama installation."
    else
        info "No skills currently reference Ollama."
    fi

    # Check for specific known skills
    echo
    info "Checking for key Ollama-related skills..."
    local key_skills=(
        "hermes-local-models:Configure Hermes to use local models via Ollama"
        "serving-llms-vllm:Serve LLMs (alternative to Ollama)"
        "llama-cpp:Run GGUF models directly (Ollama alternative)"
        "ocr-and-documents:Extract text from PDFs (can use Ollama vision)"
        "huggingface-hub:Download models from HuggingFace"
    )

    for entry in "${key_skills[@]}"; do
        local skill_name="${entry%%:*}"
        local desc="${entry#*:}"
        if [[ -f "$skills_dir"/*/SKILL.md ]] && grep -rl -i "$skill_name" "$skills_dir"/*/SKILL.md &>/dev/null 2>&1; then
            echo -e "    ${GRN}✓${R} ${B}$skill_name${R} ${DIM}— installed${R}"
        else
            echo -e "    ${DIM}○ $skill_name${R} ${DIM}— $desc${R}"
        fi
    done

    echo
    info "💡 Skills are automatically discovered by Hermes Agent."
    info "   Install with: ${CYN}hermes skills install <name>${R}"
    echo
    exit 0
}

# Handle standalone flags (--hf-list, --hf-model, --mcp-scan, --skills-check)
$HF_LIST && show_hf_models
[[ -n "$HF_MODEL" ]] && import_hf_model "$HF_MODEL"
$MCP_SCAN && scan_mcp_servers
$SKILLS_CHECK && check_skills

# Dry-run wrapper
run() {
    if $DRY_RUN; then
        echo -e "    ${DIM}▫ [dry-run]${R} $*"
    else
        eval "$@"
    fi
}

# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
# HERMES DETECTION & STATUS
# ═══════════════════════════════════════════════════════════════
HERMES_INSTALLED=false
HERMES_VERSION=""
HERMES_UPDATE_AVAILABLE=false

detect_hermes() {
    HERMES_BIN=""
    HERMES_CONFIG="$HOME/.hermes/config.yaml"
    if command -v hermes &>/dev/null; then
        HERMES_BIN="hermes"
        HERMES_INSTALLED=true
    elif [[ -x "$HOME/.hermes/hermes-agent/venv/bin/hermes" ]]; then
        HERMES_BIN="$HOME/.hermes/hermes-agent/venv/bin/hermes"
        HERMES_INSTALLED=true
    fi
    if $HERMES_INSTALLED; then
        HERMES_VERSION=$($HERMES_BIN --version 2>/dev/null | head -1 || echo "unknown")
        if $HERMES_BIN update --check 2>/dev/null | grep -qi "update available\|behind"; then
            HERMES_UPDATE_AVAILABLE=true
        fi
    fi
}

show_hermes_status() {
    if ! $HERMES_INSTALLED; then
        echo -e "     ${YEL}⚠${R}  Not installed"
        return
    fi
    echo -e "     ${GRN}✓${R} Installed ${DIM}($HERMES_VERSION)${R}"
    local model provider
    model=$(python3 -c "
import yaml
try:
    c = yaml.safe_load(open('$HERMES_CONFIG'))
    print(c.get('model', {}).get('default', 'unknown'))
except: print('unknown')
" 2>/dev/null || echo "unknown")
    provider=$(python3 -c "
import yaml
try:
    c = yaml.safe_load(open('$HERMES_CONFIG'))
    print(c.get('model', {}).get('provider', 'unknown'))
except: print('unknown')
" 2>/dev/null || echo "unknown")
    echo -e "     ${DIM}Model:${R} ${B}$model${R} ${DIM}| Provider:${R} ${B}$provider${R}"
    if systemctl --user is-active hermes-gateway &>/dev/null 2>&1; then
        echo -e "     ${GRN}✓${R} Gateway running"
    else
        echo -e "     ${YEL}⚠${R}  Gateway not running"
    fi
    local aux_count
    aux_count=$(python3 -c "
import yaml
try:
    c = yaml.safe_load(open('$HERMES_CONFIG'))
    aux = c.get('auxiliary', {})
    print(sum(1 for v in aux.values() if v.get('provider') in ('ollama', 'llamacpp')))
except: print(0)
" 2>/dev/null || echo "0")
    if [[ "$aux_count" -gt 0 ]]; then
        echo -e "     ${GRN}✓${R} ${B}$aux_count${R} auxiliary slots using ${BACKEND_LABEL}"
    fi
    if $HERMES_UPDATE_AVAILABLE; then
        echo -e "     ${BYEL}📦 Update available!${R} ${DIM}Run: hermes update${R}"
    fi
}

offer_hermes_install() {
    echo
    echo -e "  ${BYEL}🤖 Hermes Agent is not installed.${R}"
    echo -e "  ${DIM}Hermes is an AI assistant by Nous Research that can use${R}"
    echo -e "  ${DIM}your local ${BACKEND_LABEL} models for background tasks.${R}"
    echo
    echo -e "  ${DIM}Features:${R}"
    echo -e "    ${DIM}• Chat with local or cloud models${R}"
    echo -e "    ${DIM}• Delegate coding tasks to local LLM${R}"
    echo -e "    ${DIM}• Vision, compression, search via ${BACKEND_LABEL}${R}"
    echo -e "    ${DIM}• Telegram, Discord, Slack integration${R}"
    echo -e "    ${DIM}• Scheduled tasks and MCP tools${R}"
    echo
    read -rp "$(echo -e "  ${BYEL}Install Hermes Agent now? [y/N] ${R}")" install_hermes
    if [[ "$install_hermes" =~ ^[Yy]$ ]]; then
        step "⬇️  Installing Hermes Agent..."
        if ! $DRY_RUN; then
            curl -fsSL https://raw.githubusercontent.com/nousresearch/hermes-agent/main/install.sh | bash
            detect_hermes
            if $HERMES_INSTALLED; then
                ok "${BGRN}✓ Hermes Agent installed.${R}"
                info "Run ${CYN}hermes setup${R} to configure your provider and model."
            else
                warn "Installation may have partially succeeded."
                warn "Check: ${CYN}https://hermes-agent.nousresearch.com/docs${R}"
            fi
        else
            echo -e "    ${DIM}▫ [dry-run]${R} curl ... | bash"
        fi
    else
        info "Install later with: ${CYN}hermes-agent.nousresearch.com/docs${R}"
    fi
}

# Run Hermes detection
detect_hermes

# UNINSTALL
# ═══════════════════════════════════════════════════════════════
if $UNINSTALL; then
    header "🗑️  Uninstall ${BACKEND_LABEL}"

    read -rp "$(echo -e "  ${BYEL}⚠  This will remove ${BACKEND_LABEL} and ALL models. Continue? [y/N] ${R}")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "  ${DIM}Aborted.${R}"; exit 0; }

    step "🛑 Stopping service..."

    case "$PLATFORM" in
        linux|wsl2)
            if $HAS_SYSTEMD; then
                run "sudo systemctl stop ollama 2>/dev/null || true"
                run "sudo systemctl disable ollama 2>/dev/null || true"
                run "sudo rm -f /etc/systemd/system/ollama.service"
                run "sudo rm -rf /etc/systemd/system/ollama.service.d"
                run "sudo systemctl daemon-reload"
            else
                run "pkill -f 'ollama serve' 2>/dev/null || true"
            fi
            ;;
        macos)
            run "launchctl unload ~/Library/LaunchAgents/com.ollama.plist 2>/dev/null || true"
            run "rm -f ~/Library/LaunchAgents/com.ollama.plist"
            # Also remove brew service if installed via brew
            run "brew services stop ollama 2>/dev/null || true"
            ;;
    esac

    step "📦 Removing binary..."
    case "$PLATFORM" in
        macos)
            run "rm -f /usr/local/bin/ollama"
            run "rm -rf /Applications/Ollama.app 2>/dev/null || true"
            run "rm -rf ~/.ollama"
            run "brew uninstall ollama 2>/dev/null || true"
            ;;
        *)
            run "sudo rm -f /usr/local/bin/ollama"
            run "sudo rm -rf /usr/share/ollama"
            run "sudo userdel ollama 2>/dev/null || true"
            ;;
    esac

    echo
    ok "${BGRN}${BACKEND_LABEL} has been removed.${R}"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "🔍 Hardware Detection & Pre-flight Checks"

    # Get OS display name
    case "$PLATFORM" in
        linux|wsl2)
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                OS_DISPLAY="${PRETTY_NAME:-Linux}"
            else
                OS_DISPLAY="Linux"
            fi
            if $IS_SBC; then
                OS_DISPLAY="${SBC_MODEL}"
            fi
            [[ "$PLATFORM" == "wsl2" ]] && OS_DISPLAY="WSL2 (${OS_DISPLAY})"
            ;;
        macos)
            OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
            ;;
        *)
            OS_DISPLAY="$PLATFORM_LABEL"
            ;;
    esac

    # Display hardware card
    echo -e "    ${CYN}┌──────────────────────────────────────────────────┐${R}"
    echo -e "    ${CYN}│${R}  ${B}🧠 DETECTED HARDWARE${R}                              ${CYN}│${R}"
    echo -e "    ${CYN}├──────────────────────────────────────────────────┤${R}"

    printf "    ${CYN}│${R}  🖥️  %-13s ${B}%-30s${R} ${CYN}│${R}\n" "Platform" "$PLATFORM_LABEL"
    printf "    ${CYN}│${R}  🏗️  %-13s ${B}%-30s${R} ${CYN}│${R}\n" "OS" "${OS_DISPLAY:0:30}"
    printf "    ${CYN}│${R}  🔩 %-13s ${B}%-30s${R} ${CYN}│${R}\n" "Arch" "$ARCH"

    # CPU
    CPU_DISPLAY="${CPU_CORES}c/${CPU_THREADS}t"
    printf "    ${CYN}│${R}  ⚡ %-13s ${B}%-30s${R} ${CYN}│${R}\n" "CPU" "$CPU_DISPLAY"
    printf "    ${CYN}│${R}  ${DIM}%-17s %-30s${R} ${CYN}│${R}\n" "" "${CPU_MODEL:0:30}"

    # RAM
    RAM_COLOR="$GRN"
    (( RAM_GB < 16 )) && RAM_COLOR="$YEL"
    (( RAM_GB < 8 ))  && RAM_COLOR="$RED"
    printf "    ${CYN}│${R}  💾 %-13s ${RAM_COLOR}${B}%-30s${R} ${CYN}│${R}\n" "RAM" "${RAM_GB} GB"
    [[ "$SWAP_GB" -gt 0 ]] && printf "    ${CYN}│${R}  ${DIM}%-17s %-30s${R} ${CYN}│${R}\n" "" "+ ${SWAP_GB} GB swap"

    # Disk
    DISK_COLOR="$GRN"
    (( AVAIL_GB < 50 )) && DISK_COLOR="$YEL"
    (( AVAIL_GB < 20 )) && DISK_COLOR="$RED"
    printf "    ${CYN}│${R}  💿 %-13s ${DISK_COLOR}${B}%-30s${R} ${CYN}│${R}\n" "Disk" "${AVAIL_GB} GB free"

    # GPU
    if $HAS_GPU; then
        if $IS_APPLE_SILICON; then
            printf "    ${CYN}│${R}  🎮 %-13s ${B}%-30s${R} ${CYN}│${R}\n" "GPU" "${GPU_NAME:0:30}"
            printf "    ${CYN}│${R}  ${DIM}%-17s %-30s${R} ${CYN}│${R}\n" "" "Metal (unified memory)"
        else
            GPU_VRAM_GB=$(awk "BEGIN {printf \"%.0f\", ${GPU_VRAM_MB}/1024}")
            printf "    ${CYN}│${R}  🎮 %-13s ${B}%-30s${R} ${CYN}│${R}\n" "GPU" "${GPU_NAME:0:30}"
            printf "    ${CYN}│${R}  ${DIM}%-17s %-30s${R} ${CYN}│${R}\n" "" "${GPU_VRAM_GB} GB VRAM"
        fi
    else
        printf "    ${CYN}│${R}  🎮 %-13s ${DIM}%-30s${R} ${CYN}│${R}\n" "GPU" "None (CPU-only)"
    fi

    # Service manager
    if $HAS_SYSTEMD; then
        printf "    ${CYN}│${R}  🔧 %-13s ${B}%-30s${R} ${CYN}│${R}\n" "Service" "systemd"
    elif [[ "$PLATFORM" == "macos" ]]; then
        printf "    ${CYN}│${R}  🔧 %-13s ${B}%-30s${R} ${CYN}│${R}\n" "Service" "launchd / brew"
    else
        printf "    ${CYN}│${R}  🔧 %-13s ${BYEL}%-30s${R} ${CYN}│${R}\n" "Service" "manual (no systemd)"
    fi

    # Hardware tier
    TIER_LABEL=""
    TIER_COLOR="$GRN"
    case "$HW_TIER" in
        apple-silicon-large)  TIER_LABEL="🍏 Apple Silicon Large (64GB+)"; TIER_COLOR="$BGRN" ;;
        apple-silicon-mid)    TIER_LABEL="🍏 Apple Silicon Mid (32GB)"; TIER_COLOR="$BGRN" ;;
        apple-silicon-small)  TIER_LABEL="🍏 Apple Silicon Small (16GB)"; TIER_COLOR="$BYEL" ;;
        gpu-large)            TIER_LABEL="🟢 GPU Large (24GB+ VRAM)"; TIER_COLOR="$BGRN" ;;
        gpu-mid)              TIER_LABEL="🟢 GPU Mid (12-24GB VRAM)"; TIER_COLOR="$BGRN" ;;
        gpu-small)            TIER_LABEL="🟡 GPU Small (6-12GB VRAM)"; TIER_COLOR="$BYEL" ;;
        gpu-tiny)             TIER_LABEL="🟠 GPU Tiny (<6GB VRAM)"; TIER_COLOR="$YEL" ;;
        cpu-high)             TIER_LABEL="🔵 CPU High (32GB+ RAM)"; TIER_COLOR="$BCYN" ;;
        cpu-mid)              TIER_LABEL="🟡 CPU Mid (16-32GB RAM)"; TIER_COLOR="$BYEL" ;;
        cpu-low)              TIER_LABEL="🟠 CPU Low (8-16GB RAM)"; TIER_COLOR="$YEL" ;;
        cpu-tiny)             TIER_LABEL="🔴 CPU Tiny (<8GB RAM)"; TIER_COLOR="$RED" ;;
        sbc-high)             TIER_LABEL="🍓 SBC High (16GB+ RAM)"; TIER_COLOR="$BYEL" ;;
        sbc-mid)              TIER_LABEL="🍓 SBC Mid (8GB RAM)"; TIER_COLOR="$YEL" ;;
        sbc-low)              TIER_LABEL="🟠 SBC Low (4-8GB RAM)"; TIER_COLOR="$YEL" ;;
        sbc-tiny)             TIER_LABEL="🔴 SBC Tiny (<4GB RAM)"; TIER_COLOR="$RED" ;;
    esac
    echo -e "    ${CYN}├──────────────────────────────────────────────────┤${R}"
    printf "    ${CYN}│${R}  📊 %-13s ${TIER_COLOR}${B}%-30s${R} ${CYN}│${R}\n" "Tier" "$TIER_LABEL"
    echo -e "    ${CYN}└──────────────────────────────────────────────────┘${R}"
    echo

    # Warnings
    if [[ "$PLATFORM" == "wsl2" ]] && ! $HAS_SYSTEMD; then
        warn "WSL2 without systemd detected. Ollama will need to be started manually."
        info "To enable systemd in WSL2: add 'systemd=true' to /etc/wsl.conf under [boot]"
    fi
    if $IS_SBC && (( RAM_GB < 8 )); then
        warn "SBC with limited RAM — only 1B models will be practical."
    fi
    if ! $HAS_GPU && (( RAM_GB < 8 )); then
        warn "Limited RAM with no GPU — only small models will be practical."
    fi
    if (( AVAIL_GB < 20 )); then
        warn "Less than 20 GB free disk — model storage may be tight."
    fi

    # Show auto-selected models
    info "🎯 Based on your hardware tier, these models are recommended:"
    echo -e "       ${DIM}Main:${R} ${B}${HERMES_MAIN}${R}"
    echo -e "       ${DIM}Aux:${R}  ${B}${HERMES_AUX}${R}"
    echo

    # ── Check Ollama installation status ──
    OLLAMA_INSTALLED=false
    OLLAMA_RUNNING=false
    OLLAMA_VERSION=""

    if command -v ollama &>/dev/null; then
        OLLAMA_INSTALLED=true
        OLLAMA_VERSION=$(ollama --version 2>/dev/null || echo "unknown")
        # Check if the service is running
        if curl -sf "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
            OLLAMA_RUNNING=true
        fi
    fi

    if $OLLAMA_INSTALLED; then
        echo -e "  ${B}🦙 Ollama status:${R}"
        echo -e "     ${GRN}✓${R} Installed ${DIM}(version ${OLLAMA_VERSION})${R}"
        if $OLLAMA_RUNNING; then
            # Show model count
            MODEL_COUNT=$(curl -sf "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('models',[])))" 2>/dev/null || echo "?")
            echo -e "     ${GRN}✓${R} Running ${DIM}(${MODEL_COUNT} models available)${R}"
        else
            echo -e "     ${YEL}⚠${R} Not running"
        fi
        echo

        if ! $OLLAMA_RUNNING; then
            warn "Ollama installed but not running."
            case "$PLATFORM" in
                linux|wsl2)
                    $HAS_SYSTEMD && info "Start with: ${CYN}sudo systemctl start ollama${R}" || info "Start with: ${CYN}ollama serve &${R}"
                    ;;
                macos)
                    info "Start with: ${CYN}brew services start ollama${R}"
                    ;;
            esac
        fi

        read -rp "$(echo -e "  ${BYEL}🔄 Reinstall/upgrade? [y/N] ${R}")" reinstall
        [[ "$reinstall" =~ ^[Yy]$ ]] || { info "Skipping install."; MODELS_ONLY=true; }
    fi

    # Check curl
    if ! command -v curl &>/dev/null; then
        err "curl is required."
        case "$PLATFORM" in
            macos) err "Install with: ${CYN}brew install curl${R}" ;;
            *)     err "Install with: ${CYN}sudo apt install curl${R}" ;;
        esac
        exit 1
    fi

    echo
    ok "${BGRN}✓ Pre-flight checks passed.${R}"

    # ── Hermes Agent status ──
    echo
    echo -e "  ${B}🤖 Hermes Agent:${R}"
    show_hermes_status
    if ! $HERMES_INSTALLED; then
        offer_hermes_install
    fi
    if $HERMES_INSTALLED && $HERMES_UPDATE_AVAILABLE && ! $DRY_RUN; then
        echo
        read -rp "$(echo -e "  ${BYEL}📦 Update Hermes now? [y/N] ${R}")" update_hermes
        if [[ "$update_hermes" =~ ^[Yy]$ ]]; then
            step "📦 Updating Hermes Agent..."
            $HERMES_BIN update --yes 2>/dev/null || warn "Update failed."
            detect_hermes
            ok "Updated to: ${B}$HERMES_VERSION${R}"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# INSTALL
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "📥 Installing ${BACKEND_LABEL}"

    if [[ "$BACKEND" == "llamacpp" ]]; then
        # ══ LLAMA.CPP INSTALL ══
        step "⬇️  Installing llama.cpp..."
        case "$PLATFORM" in
            macos)
                if command -v brew &>/dev/null; then
                    if $DRY_RUN; then
                        echo -e "    ${DIM}▫ [dry-run]${R} brew install llama.cpp"
                    else
                        brew install llama.cpp
                    fi
                else
                    err "Homebrew required. Install: ${CYN}https://brew.sh${R}"
                    exit 1
                fi
                ;;
            linux|wsl2)
                if $DRY_RUN; then
                    echo -e "    ${DIM}▫ [dry-run]${R} Download/build llama-server"
                else
                    LLAMA_URL=$(curl -sf "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
arch = '$(uname -m)'
pat = 'ubuntu-x64' if arch == 'x86_64' else 'ubuntu-arm64'
for a in d.get('assets', []):
    if pat in a['name'].lower():
        print(a['browser_download_url']); break
" 2>/dev/null || true)
                    if [[ -n "$LLAMA_URL" ]]; then
                        info "Downloading prebuilt binary..."
                        curl -L "$LLAMA_URL" -o /tmp/llamacpp.tar.gz
                        mkdir -p "$LLAMACPP_DIR" && tar xzf /tmp/llamacpp.tar.gz -C "$LLAMACPP_DIR" --strip-components=1 2>/dev/null || true
                        rm -f /tmp/llamacpp.tar.gz
                        mkdir -p ~/.local/bin
                        ln -sf "$LLAMACPP_DIR/build/bin/llama-server" ~/.local/bin/llama-server 2>/dev/null || true
                        ln -sf "$LLAMACPP_DIR/bin/llama-server" ~/.local/bin/llama-server 2>/dev/null || true
                    else
                        warn "Building from source..."
                        command -v cmake &>/dev/null || { sudo apt update && sudo apt install -y cmake build-essential git; }
                        git clone --depth 1 https://github.com/ggml-org/llama.cpp.git /tmp/llamacpp-build
                        cd /tmp/llamacpp-build && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release -j "$THREADS"
                        mkdir -p "$LLAMACPP_DIR/bin" && cp build/bin/llama-server "$LLAMACPP_DIR/bin/"
                        mkdir -p ~/.local/bin && ln -sf "$LLAMACPP_DIR/bin/llama-server" ~/.local/bin/llama-server
                        cd - >/dev/null && rm -rf /tmp/llamacpp-build
                    fi
                fi
                ;;
        esac
        if ! $DRY_RUN; then mkdir -p "$LLAMACPP_MODELS_DIR"; fi
        echo
        ok "${BGRN}✓ llama.cpp installed.${R}"
        info "Models dir: ${CYN}$LLAMACPP_MODELS_DIR${R}"
        info "Use ${CYN}--hf-model${R} to download GGUF models."

    else
        # ══ OLLAMA INSTALL ══
        case "$PLATFORM" in
            macos)
                step "⬇️  Downloading Ollama for macOS..."
                if $DRY_RUN; then
                    echo -e "    ${DIM}▫ [dry-run]${R} curl -fsSL https://ollama.com/install.sh | sh"
                else
                    if command -v brew &>/dev/null; then
                        info "Homebrew detected — using brew install..."
                        brew install ollama 2>/dev/null || curl -fsSL https://ollama.com/install.sh | sh
                    else
                        curl -fsSL https://ollama.com/install.sh | sh
                    fi
                fi
                ;;
            *)
                step "⬇️  Downloading and running official installer..."
                if $DRY_RUN; then
                    echo -e "    ${DIM}▫ [dry-run]${R} curl -fsSL https://ollama.com/install.sh | sh"
                else
                    curl -fsSL https://ollama.com/install.sh | sh
                fi
                ;;
        esac
        echo
        ok "${BGRN}✓ Install complete.${R}"
    fi
fi


# ═══════════════════════════════════════════════════════════════
# CONFIGURE SERVICE
# ═══════════════════════════════════════════════════════════════
if ! $MODELS_ONLY; then
    header "⚙️  Configuring ${BACKEND_LABEL} Service"

    step "🎯 Applying performance tuning for your hardware..."
    echo
    echo -e "    ${CYN}┌──────────────────────────────────────────────────┐${R}"
    echo -e "    ${CYN}│${R}  ${B}THREADS${R}                = ${GRN}${THREADS}${R}               ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}PARALLEL${R}               = ${GRN}${PARALLEL}${R}                ${CYN}│${R}"
    if [[ "$BACKEND" == "llamacpp" ]]; then
    echo -e "    ${CYN}│${R}  ${B}HOST${R}                   = ${GRN}${LLAMACPP_HOST}${R}       ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}PORT${R}                   = ${GRN}${LLAMACPP_PORT}${R}             ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}MODELS DIR${R}             = ${GRN}~/.local/share/llamacpp${R}  ${CYN}│${R}"
    else
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_HOST${R}            = ${GRN}${OLLAMA_HOST}${R}       ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_PORT${R}            = ${GRN}${OLLAMA_PORT}${R}             ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_KEEP_ALIVE${R}      = ${GRN}5m${R}                 ${CYN}│${R}"
    echo -e "    ${CYN}│${R}  ${B}OLLAMA_MAX_LOADED${R}      = ${GRN}${MAX_LOADED}${R}                ${CYN}│${R}"
    fi
    if $HAS_GPU; then
        echo -e "    ${CYN}│${R}  ${B}GPU${R}                    = ${GRN}enabled${R}              ${CYN}│${R}"
    else
        echo -e "    ${CYN}│${R}  ${B}GPU${R}                    = ${DIM}disabled (CPU-only)${R}     ${CYN}│${R}"
    fi
    echo -e "    ${CYN}└──────────────────────────────────────────────────┘${R}"
    echo

    if [[ "$BACKEND" == "llamacpp" ]]; then
        # ══ LLAMA.CPP SERVICE ══
        case "$PLATFORM" in
            linux|wsl2)
                if $HAS_SYSTEMD; then
                    DEFAULT_MODEL=$(ls "$LLAMACPP_MODELS_DIR"/*.gguf 2>/dev/null | head -1 || true)
                    if $DRY_RUN; then
                        echo -e "    ${DIM}▫ [dry-run]${R} write /etc/systemd/system/llama-server.service"
                    else
                        sudo tee /etc/systemd/system/llama-server.service > /dev/null <<EOF
[Unit]
Description=llama.cpp Server
After=network.target
[Service]
Type=simple
ExecStart=$(which llama-server 2>/dev/null || echo ~/.local/bin/llama-server) --host ${LLAMACPP_HOST} --port ${LLAMACPP_PORT} -t ${THREADS} -c 4096 -m ${DEFAULT_MODEL:-$LLAMACPP_MODELS_DIR/model.gguf}
Restart=always
RestartSec=5
Environment=HOME=${HOME}
[Install]
WantedBy=multi-user.target
EOF
                    fi
                    step "🔄 Starting service..."
                    run "sudo systemctl daemon-reload"
                    run "sudo systemctl enable llama-server"
                    run "sudo systemctl restart llama-server"
                else
                    warn "No systemd. Start manually:"
                    echo -e "    ${CYN}llama-server --host ${LLAMACPP_HOST} --port ${LLAMACPP_PORT} -t ${THREADS} -c 4096 -m <model.gguf>${R}"
                fi
                ;;
            macos)
                DEFAULT_MODEL=$(ls "$LLAMACPP_MODELS_DIR"/*.gguf 2>/dev/null | head -1 || true)
                if ! $DRY_RUN; then
                    cat > ~/Library/LaunchAgents/com.llamacpp.server.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.llamacpp.server</string>
  <key>ProgramArguments</key><array>
    <string>$(which llama-server 2>/dev/null || echo /opt/homebrew/bin/llama-server)</string>
    <string>--host</string><string>${LLAMACPP_HOST}</string>
    <string>--port</string><string>${LLAMACPP_PORT}</string>
    <string>-t</string><string>${THREADS}</string>
    <string>-c</string><string>4096</string>
    <string>-m</string><string>${DEFAULT_MODEL:-$LLAMACPP_MODELS_DIR/model.gguf}</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
EOF
                    launchctl load ~/Library/LaunchAgents/com.llamacpp.server.plist 2>/dev/null || true
                fi
                ;;
        esac
    else
        # ══ OLLAMA SERVICE ══
        case "$PLATFORM" in
        linux|wsl2)
            if $HAS_SYSTEMD; then
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
Environment="OLLAMA_MAX_LOADED_MODELS=${MAX_LOADED}"
EOF
                fi

                step "🔄 Reloading daemon and restarting service..."
                run "sudo systemctl daemon-reload"
                run "sudo systemctl enable ollama"
                run "sudo systemctl restart ollama"
            else
                # ── No systemd (WSL2 without it, or unusual Linux) ──
                warn "No systemd available. Ollama will run as a background process."
                if ! $DRY_RUN; then
                    info "Setting up ~/.ollama/env with performance settings..."
                    mkdir -p ~/.ollama
                    cat > ~/.ollama/env <<EOF
export OLLAMA_NUM_THREAD=${THREADS}
export OLLAMA_NUM_PARALLEL=${PARALLEL}
export OLLAMA_HOST=${OLLAMA_HOST}:${OLLAMA_PORT}
export OLLAMA_KEEP_ALIVE=5m
export OLLAMA_MAX_LOADED_MODELS=${MAX_LOADED}
EOF
                fi
                echo
                info "To start Ollama:  ${CYN}source ~/.ollama/env && ollama serve &${R}"
            fi
            ;;
        macos)
            # ── macOS: write env vars to ~/.ollama/env ──
            if ! $DRY_RUN; then
                mkdir -p ~/.ollama
                cat > ~/.ollama/env <<EOF
export OLLAMA_NUM_THREAD=${THREADS}
export OLLAMA_NUM_PARALLEL=${PARALLEL}
export OLLAMA_HOST=${OLLAMA_HOST}:${OLLAMA_PORT}
export OLLAMA_KEEP_ALIVE=5m"
export OLLAMA_MAX_LOADED_MODELS=${MAX_LOADED}
EOF
                # If brew installed, start the service
                if command -v brew &>/dev/null; then
                    brew services start ollama 2>/dev/null || true
                fi
            else
                echo -e "    ${DIM}▫ [dry-run]${R} write ~/.ollama/env"
            fi

            step "🔄 Starting Ollama..."
            if command -v brew &>/dev/null; then
                run "brew services start ollama"
            fi
            ;;
        esac
    fi  # end backend service branch

    # Wait for API
    if ! $DRY_RUN; then
        info "⏳ Waiting for API to start..."
        if [[ "$BACKEND" == "llamacpp" ]]; then
            API_URL="http://${LLAMACPP_HOST}:${LLAMACPP_PORT}/health"
            API_PORT="$LLAMACPP_PORT"
        else
            API_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags"
            API_PORT="$OLLAMA_PORT"
        fi
        for i in $(seq 1 10); do
            if curl -sf "$API_URL" >/dev/null 2>&1; then
                ok "${BGRN}✓ ${BACKEND_LABEL} API responding on port ${API_PORT}${R}"
                break
            fi
            echo -ne "    ${DIM}...${R}\r"
            sleep 1
            [[ $i -eq 10 ]] && warn "API not responding yet"
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

    info "📊 Total: ${B}${#STARTER_MODELS[@]}${R} model(s) for ${TIER_COLOR}${B}${HW_TIER}${R} tier"
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
                if [[ "$BACKEND" == "llamacpp" ]]; then
                    echo -e "    ${DIM}▫ [dry-run]${R} Download GGUF for $model to $LLAMACPP_MODELS_DIR"
                else
                    echo -e "    ${DIM}▫ [dry-run]${R} ollama pull $model"
                fi
            else
                if [[ "$BACKEND" == "llamacpp" ]]; then
                    # For llama.cpp, download GGUF from HuggingFace
                    info "Downloading GGUF for $model..."
                    info "Use ${CYN}--hf-model${R} for custom HuggingFace imports."
                    warn "llama.cpp requires manual GGUF management. Skipping auto-pull."
                    warn "Ollama model names won't work directly with llama.cpp."
                else
                    ollama pull "$model"
                    ok "✓ ${B}${model}${R} — done"
                fi
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


# Determine effective provider config based on backend
if [[ "$BACKEND" == "llamacpp" ]]; then
    HERMES_BASE_URL="$LLAMACPP_BASE"
    HERMES_PROVIDER_NAME="llamacpp"
    HERMES_PROVIDER_LABEL="llama.cpp"
else
    HERMES_BASE_URL="$OLLAMA_BASE"
    HERMES_PROVIDER_NAME="ollama"
    HERMES_PROVIDER_LABEL="Ollama"
fi

configure_hermes_aux_slot() {
    local slot="$1"
    local model="$2"
    run "$HERMES_BIN config set auxiliary.${slot}.provider ${HERMES_PROVIDER_NAME}"
    run "$HERMES_BIN config set auxiliary.${slot}.model ${model}"
    run "$HERMES_BIN config set auxiliary.${slot}.base_url ${HERMES_BASE_URL}"
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

            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.name ${HERMES_PROVIDER_LABEL}"
            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.base_url ${HERMES_BASE_URL}"
            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.api_key ${OLLAMA_KEY}"

            run "$HERMES_BIN config set model.default ${HERMES_MAIN}"
            run "$HERMES_BIN config set model.provider ${HERMES_PROVIDER_NAME}"
            run "$HERMES_BIN config set model.base_url ${HERMES_BASE_URL}"
            run "$HERMES_BIN config set model.api_key ${OLLAMA_KEY}"

            run "$HERMES_BIN config set delegation.provider ${HERMES_PROVIDER_NAME}"
            run "$HERMES_BIN config set delegation.model ${HERMES_DELEGATION}"
            run "$HERMES_BIN config set delegation.base_url ${HERMES_BASE_URL}"
            run "$HERMES_BIN config set delegation.api_key ${OLLAMA_KEY}"

            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_KANBAN"

            ok "${BGRN}✓ Full offline preset applied.${R}"

        elif [[ "$HERMES_MODE" == "hybrid" ]]; then
            step "⚡ Applying ${BBLU}HYBRID${R} ${BGRN}⭐${R} preset..."
            echo -e "    ${DIM}Main:${R} ${B}cloud${R} ${DIM}| Delegation:${R} ${B}$HERMES_DELEGATION${R} ${DIM}(local)${R} ${DIM}| Aux:${R} ${B}$HERMES_AUX${R} ${DIM}(local)${R}"

            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.name ${HERMES_PROVIDER_LABEL}"
            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.base_url ${HERMES_BASE_URL}"
            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.api_key ${OLLAMA_KEY}"

            run "$HERMES_BIN config set delegation.provider ${HERMES_PROVIDER_NAME}"
            run "$HERMES_BIN config set delegation.model ${HERMES_DELEGATION}"
            run "$HERMES_BIN config set delegation.base_url ${HERMES_BASE_URL}"
            run "$HERMES_BIN config set delegation.api_key ${OLLAMA_KEY}"

            for slot in "${AUX_CORE_SLOTS[@]}" "${AUX_EXTENDED_SLOTS[@]}"; do
                configure_hermes_aux_slot "$slot" "$HERMES_AUX"
            done
            configure_hermes_aux_slot "kanban_decomposer" "$HERMES_KANBAN"

            ok "${BGRN}✓ Hybrid preset applied.${R} ${DIM}(main stays on cloud)${R}"

        elif [[ "$HERMES_MODE" == "aux" ]]; then
            step "🎯 Applying ${BMAG}AUXILIARY ONLY${R} preset..."
            echo -e "    ${DIM}Main + Delegation:${R} ${B}cloud${R} ${DIM}(unchanged)${R} ${DIM}| Aux:${R} ${B}$HERMES_AUX${R} ${DIM}(local)${R}"

            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.name ${HERMES_PROVIDER_LABEL}"
            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.base_url ${HERMES_BASE_URL}"
            run "$HERMES_BIN config set providers.${HERMES_PROVIDER_NAME}.api_key ${OLLAMA_KEY}"

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
    case "$PLATFORM" in
        linux|wsl2)
            if $HAS_SYSTEMD; then
                if systemctl is-active ollama --no-pager 2>/dev/null | grep -q active; then
                    echo -e "    ${BGRN}● active (running)${R}"
                else
                    echo -e "    ${BRED}● inactive${R}"
                fi
            else
                if pgrep -f "ollama serve" &>/dev/null; then
                    echo -e "    ${BGRN}● running (background)${R}"
                else
                    echo -e "    ${BYEL}● not running — start with: ollama serve &${R}"
                fi
            fi
            ;;
        macos)
            if curl -sf "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
                echo -e "    ${BGRN}● active (running)${R}"
            else
                echo -e "    ${BYEL}● not running — start with: brew services start ollama${R}"
            fi
            ;;
    esac
    echo

    echo -e "  ${B}📌 Version:${R}"
    echo -ne "    "; ollama --version 2>/dev/null || echo "n/a"
    echo

    echo -e "  ${B}📦 Models:${R}"
    ollama list 2>/dev/null | while IFS= read -r line; do echo -e "    $line"; done || echo "    none"
    echo

    echo -e "  ${B}🌐 API:${R}"
    if [[ "$BACKEND" == "llamacpp" ]]; then
        API_CHECK="http://${LLAMACPP_HOST}:${LLAMACPP_PORT}/health"
        API_DISPLAY="http://${LLAMACPP_HOST}:${LLAMACPP_PORT}"
    else
        API_CHECK="http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags"
        API_DISPLAY="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
    fi
    if curl -sf "$API_CHECK" >/dev/null 2>&1; then
        echo -e "    ${BGRN}✓ Responding${R} ${DIM}at ${API_DISPLAY}${R}"
    else
        echo -e "    ${BRED}✗ Not responding${R}"
    fi

    if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
        echo
        echo -e "  ${B}🤖 Hermes preset:${R} ${BMAG}${HERMES_MODE}${R}"
        show_hermes_status
        BACKUP=$(ls -t ${HERMES_CONFIG}.bak.* 2>/dev/null | head -1)
        [[ -n "$BACKUP" ]] && echo -e "    ${DIM}💾 Backup:${R} ${CYN}${BACKUP}${R}"
    elif $HERMES_INSTALLED; then
        echo
        echo -e "  ${B}🤖 Hermes Agent:${R}"
        show_hermes_status
    fi
else
    echo -e "  ${BYEL}⚠ [dry-run] No changes were made.${R}"
fi

echo
echo -e "  ${BG_GRN}${WHT}${B} ┌─────────────────────────────────────────────────┐ ${R}"
echo -e "  ${BG_GRN}${WHT}${B} │          🚀 Ollama is ready! 🦙                 │ ${R}"
echo -e "  ${BG_GRN}${WHT}${B} └─────────────────────────────────────────────────┘ ${R}"
echo
if [[ "$BACKEND" == "llamacpp" ]]; then
echo -e "  ${CYN}💬 Chat${R}        llama-server -m <model.gguf> --port ${LLAMACPP_PORT}"
else
echo -e "  ${CYN}💬 Chat${R}        ollama run ${HERMES_MAIN}"
fi
echo -e "  ${CYN}📋 List${R}        ollama list"
echo -e "  ${CYN}🌐 API${R}         http://${OLLAMA_HOST}:${OLLAMA_PORT}"
if [[ "$PLATFORM" == "macos" ]]; then
echo -e "  ${CYN}📊 Status${R}      brew services info ollama"
else
echo -e "  ${CYN}📊 Status${R}      systemctl status ollama"
echo -e "  ${CYN}📝 Logs${R}        journalctl -u ollama -f"
fi
echo
if [[ -n "$HERMES_MODE" && "$HERMES_MODE" != "ask" ]]; then
echo -e "  ${MAG}🤖 Hermes${R}      ${CYN}systemctl --user restart hermes-gateway${R}"
echo -e "  ${MAG}📋 Preset${R}      ${BMAG}${HERMES_MODE}${R}"
fi
echo
