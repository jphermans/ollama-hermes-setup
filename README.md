<div align="center">

# 🦙 Ollama + 🤖 Hermes Agent Setup

### Cross-platform installer with hardware detection and **Hermes Agent preset integration**

**Linux** · **macOS** · **WSL2** — x86_64 · ARM64 · Apple Silicon · Raspberry Pi

</div>

---

## ✨ What This Does

A single Bash script that:

1. 🔍 **Detects your platform** — Linux, macOS, WSL2 (including SBCs like Raspberry Pi)
2. 🧠 **Detects your hardware** — CPU, RAM, swap, disk, NVIDIA GPU, Apple Silicon Metal
3. 📊 **Classifies your machine** into a hardware tier (12 tiers total)
4. 🎯 **Recommends models** that fit your available resources
5. 📥 **Installs Ollama** via the official installer
6. ⚙️ **Tunes performance** — threads, parallelism, and max-loaded-models per platform
7. 📦 **Downloads models** appropriate to your hardware and chosen preset
8. 🤖 **Configures Hermes Agent** with one of three presets for model routing
9. 🤗 **Imports models from HuggingFace** as GGUF files
10. 🔌 **Scans MCP servers** and 🧩 **checks Hermes skills** for Ollama integration

> No manual configuration needed — the script figures out what will work on your machine.

---

## 🚀 Quick Start

### Option A: Interactive Menu (easiest)

```bash
git clone https://github.com/jphermans/ollama-hermes-setup.git
cd ollama-hermes-setup
chmod +x ollama-setup.sh

# Run with no arguments — interactive menu appears
bash ollama-setup.sh
```

### Option B: Direct Flags

```bash
# Install with interactive preset chooser
bash ollama-setup.sh --hermes

# Go straight to the recommended hybrid preset
bash ollama-setup.sh --hermes-hybrid
```

### 👀 Dry Run First

```bash
bash ollama-setup.sh --dry-run --hermes-hybrid
```

---

## 🔍 Hardware & Platform Detection

### Supported Platforms

| Platform | Service Manager | GPU Support | Notes |
|---|---|---|---|
| 🐧 **Linux** | systemd | NVIDIA via `nvidia-smi` | Full auto-configuration |
| 🪟 **WSL2** | systemd (if enabled) | NVIDIA via `nvidia-smi` | Falls back to manual if no systemd |
| 🍎 **macOS** | launchd / Homebrew | Apple Silicon Metal | Unified memory = VRAM |

### Hardware Tiers (12 total)

| Tier | Condition | Recommended Models | Platform |
|---|---|---|---|
| 🍏 **Apple Silicon Large** | M-series, 64 GB+ RAM | qwen2.5:32b, gemma3:12b | macOS |
| 🍏 **Apple Silicon Mid** | M-series, 32 GB RAM | gemma4, gemma3:12b | macOS |
| 🍏 **Apple Silicon Small** | M-series, 16 GB RAM | gemma4 | macOS |
| 🟢 **GPU Large** | 24 GB+ VRAM | qwen2.5:32b, gemma3:12b | Linux/WSL2 |
| 🟢 **GPU Mid** | 12–24 GB VRAM | gemma4, gemma3:12b | Linux/WSL2 |
| 🟡 **GPU Small** | 6–12 GB VRAM | gemma4, gemma3:12b | Linux/WSL2 |
| 🟠 **GPU Tiny** | <6 GB VRAM | llama3.1:8b | Linux/WSL2 |
| 🔵 **CPU High** | 32 GB+ RAM | gemma4, gemma3:12b | Linux/WSL2 |
| 🟡 **CPU Mid** | 16–32 GB RAM | llama3.1:8b, gemma3:12b | Linux/WSL2 |
| 🟠 **CPU Low** | 8–16 GB RAM | llama3.2:3b | Linux/WSL2 |
| 🔴 **CPU Tiny** | <8 GB RAM | llama3.2:1b | Any |
| 🍓 **SBC** | Raspberry Pi, etc. | llama3.2:1b–3b | Linux ARM |

> 🍓 **Raspberry Pi 5**: Detected as SBC via `/proc/device-tree/model`. Gets conservative tiers because ARM cores are slower per-clock. An 8 GB RPi 5 → SBC Mid (llama3.2:3b). A 4 GB RPi 5 → SBC Low (llama3.2:1b).

---

## 🎛️ Script Flags

| Flag | Description |
|---|---|
| *(none)* | 🎮 Interactive menu |
| `--hermes-hybrid` | ⚡ Install + hybrid preset (recommended) |
| `--hermes-offline` | 🔌 Install + full offline preset |
| `--hermes-aux` | 🎯 Install + auxiliary-only preset |
| `--hermes` | 🤖 Install + interactive preset chooser |
| `--hermes-reset` | 🔄 Reset Hermes to cloud/auto defaults |
| `--models-only` | 📦 Skip install, only pull models |
| `--no-models` | ⏭️ Skip model downloads |
| `--hf-model <id>` | 🤗 Import a GGUF model from HuggingFace |
| `--hf-list` | 📋 Show popular HuggingFace GGUF models |
| `--mcp-scan` | 🔌 Scan Hermes MCP servers for Ollama-compatible tools |
| `--skills-check` | 🧩 Check for Hermes skills that use Ollama |
| `--dry-run` | 👀 Show every command without executing |
| `--uninstall` | 🗑️ Remove Ollama completely |
| `--help` | ❓ Show help |

---

## 🤗 HuggingFace Model Import

Import any GGUF model from HuggingFace directly into Ollama:

```bash
# List popular models
bash ollama-setup.sh --hf-list

# Import with auto-selected Q4_K_M quantization
bash ollama-setup.sh --hf-model bartowski/Qwen2.5-7B-Instruct-GGUF

# Import a specific file
bash ollama-setup.sh --hf-model bartowski/Qwen2.5-7B-Instruct-GGUF:Qwen2.5-7B-Instruct-Q5_K_M.gguf
```

Uses `huggingface-cli` if available (recommended), falls back to `curl`. The model is automatically registered with Ollama and ready to use.

---

## 🤖 Hermes Agent Presets

When using [Hermes Agent](https://hermes-agent.nousresearch.com), this script configures model routing across three task layers.

| | 🔌 Full Offline | ⚡ Hybrid ⭐ | 🎯 Auxiliary Only |
|---|---|---|---|
| **Flag** | `--hermes-offline` | `--hermes-hybrid` | `--hermes-aux` |
| **💬 Main chat** | 🖥️ local | ☁️ cloud | ☁️ cloud |
| **🔀 Delegation** | 🖥️ local | 🖥️ local | ☁️ cloud |
| **🔧 Auxiliary** | 🖥️ local | 🖥️ local | 🖥️ local |
| **💰 Cloud cost** | 🟢 Zero | 🟡 Reduced | 🔴 Same |

> Models are auto-selected based on your hardware tier.

---

## 🔌 MCP & 🧩 Skills Integration

### MCP Server Scan

```bash
bash ollama-setup.sh --mcp-scan
```

Scans your Hermes MCP config and identifies servers that can benefit from local Ollama models (code runners, web extractors, search, git tools).

### Skills Check

```bash
bash ollama-setup.sh --skills-check
```

Checks installed Hermes skills for Ollama integration opportunities.

---

## 📦 Model Catalog

| Model | Size | Hardware Tier |
|---|---|---|
| `llama3.2:1b` | ~1.3 GB | 🔴 CPU Tiny / 🍓 SBC |
| `llama3.2:3b` | ~2.0 GB | 🟠 CPU Low / 🍓 SBC Mid+ |
| `llama3.1:8b` | ~4.7 GB | 🟡 CPU Mid / 🟠 GPU Tiny |
| `gemma3:12b` | ~8.1 GB | 🔵 CPU High / 🟡 GPU Small+ |
| `gemma4:latest` | ~9.6 GB | 🔵 CPU High / 🟢 GPU Mid / 🍏 Apple Silicon |
| `qwen2.5:32b` | ~19 GB | 🟢 GPU Large / 🍏 Apple Silicon Large |

---

## 🔒 Security

- 🔐 Ollama binds to **localhost** — keep it that way
- 🚫 Port 11434 should not be open in your firewall
- 🔑 The API key is a dummy — Ollama doesn't require auth
- 🌐 For remote access, use nginx with basic auth

---

## 🛠️ Troubleshooting

<details>
<summary><b>🪟 WSL2: No systemd</b></summary>

The script detects this and falls back to manual mode. To enable systemd:
```bash
sudo tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF
```
Then restart WSL: `wsl --shutdown` (from PowerShell).
</details>

<details>
<summary><b>🍓 Raspberry Pi: Slow inference</b></summary>

ARM cores are slower than x86. Stick to 1B-3B models. The script auto-selects these for SBCs.
For better performance, ensure you have active cooling — the Pi throttles without it.
</details>

<details>
<summary><b>🍎 macOS: GPU not used</b></summary>

Apple Silicon is auto-detected via Metal. If you're on Intel Mac, there's no GPU acceleration.
Verify Metal is active: `ollama ps` should show GPU memory usage.
</details>

<details>
<summary><b>❌ Service not starting</b></summary>

```bash
# Linux/WSL2 with systemd
systemctl status ollama
journalctl -u ollama --no-pager | tail -30

# macOS
brew services info ollama

# WSL2 without systemd
ollama serve &
```
</details>

<details>
<summary><b>🤖 Hermes: "Unknown provider ollama"</b></summary>

```bash
hermes config set providers.ollama.name Ollama
hermes config set providers.ollama.base_url http://localhost:11434/v1
hermes config set providers.ollama.api_key ollama
```
Use `provider: ollama` (plain key), NOT `custom:ollama`.
</details>

---

## 🗑️ Uninstall

```bash
bash ollama-setup.sh --uninstall
# Or just reset Hermes: bash ollama-setup.sh --models-only --hermes-reset
```

---

## 🧩 Tech Stack

| Tool | Description |
|---|---|
| [🦙 Ollama](https://ollama.com) | Local LLM runtime |
| [🤖 Hermes Agent](https://hermes-agent.nousresearch.com) | AI assistant by Nous Research |
| [🤗 HuggingFace](https://huggingface.co) | GGUF model source |
| 🐚 Bash | No dependencies beyond standard tools |

---

<div align="center">

**MIT** — See [LICENSE](LICENSE)

</div>
