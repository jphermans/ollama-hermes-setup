<div align="center">

# 🦙 Local LLM + 🤖 Hermes Agent Setup

### Cross-platform installer with hardware detection, dual backend support, and **Hermes Agent integration**

**🦙 Ollama** or **🔧 llama.cpp** — you choose at runtime.

**Linux** · **macOS** · **WSL2** — x86_64 · ARM64 · Apple Silicon · Raspberry Pi

</div>

---

## ✨ What This Does

A single Bash script that:

1. 🔍 **Detects your platform** — Linux, macOS, WSL2 (including SBCs like Raspberry Pi)
2. 🧠 **Detects your hardware** — CPU, RAM, swap, disk, NVIDIA GPU, Apple Silicon Metal
3. 📊 **Classifies your machine** into a hardware tier (12 tiers total)
4. 🤖 **Detects Hermes Agent** — installed? running? which model/provider? update available?
5. 🎯 **Recommends models** that fit your available resources
6. 📥 **Installs your chosen backend** — Ollama or llama.cpp
7. ⚙️ **Tunes performance** — threads, parallelism, and max-loaded-models per platform
8. 📦 **Downloads models** appropriate to your hardware and chosen preset
9. 🤖 **Configures Hermes Agent** with one of three presets for model routing
10. 🤗 **Imports models from HuggingFace** as GGUF files
11. 🔌 **Scans MCP servers** and 🧩 **checks Hermes skills** for integration opportunities

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

You'll see a **backend chooser** first:

```
  Choose your local LLM backend:

   1  🦙 Ollama ⭐
     Easiest to use — one command to pull and run models
     Built-in model management, Modelfiles, auto-quantization
     Best for: most users, quick setup

   2  🔧 llama.cpp (llama-server)
     Lightweight C++ server with OpenAI-compatible API
     Manual GGUF model management, more control
     Best for: advanced users, custom builds, lower overhead
```

Then the **main menu**:

```
  Welcome! What would you like to do?

   1  🚀 Full Install + Hermes Hybrid ⭐
   2  ⚙️  Full Install Only
   3  🤖 Configure Hermes Only
   4  📦 Download Models Only
   5  👁️  Dry Run Preview
   6  🗑️  Uninstall
   q  Exit
```

### Option B: Direct Flags

```bash
# Ollama + hybrid preset (default backend)
bash ollama-setup.sh --ollama --hermes-hybrid

# llama.cpp + hybrid preset
bash ollama-setup.sh --llamacpp --hermes-hybrid

# Interactive preset chooser
bash ollama-setup.sh --ollama --hermes
```

### 👀 Dry Run First

```bash
bash ollama-setup.sh --ollama --dry-run --hermes-hybrid
```

---

## 🤖 Hermes Agent Detection

The script automatically detects if Hermes Agent is installed and shows a full status overview:

```
  🤖 Hermes Agent:
     ✓ Installed (Hermes Agent v0.18.0)
     Model: glm-5.2 | Provider: zai
     ✓ Gateway running
     ✓ 10 auxiliary slots using 🦙 Ollama
     📦 Update available! Run: hermes update
```

| Situation | Script behavior |
|---|---|
| ✅ **Installed** | Shows version, model, provider, gateway status, aux slot count |
| ❌ **Not installed** | Shows features, offers interactive install |
| 📦 **Update available** | Offers to update right away |
| ⚙️ **No config** | Still works — configures backend standalone |

---

## 🔍 Hardware & Platform Detection

### Supported Platforms

| Platform | Service Manager | GPU Support | Backend Support |
|---|---|---|---|
| 🐧 **Linux** | systemd | NVIDIA via `nvidia-smi` | Ollama + llama.cpp |
| 🪟 **WSL2** | systemd (if enabled) | NVIDIA via `nvidia-smi` | Ollama + llama.cpp |
| 🍎 **macOS** | launchd / Homebrew | Apple Silicon Metal | Ollama + llama.cpp |

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

> 🍓 **Raspberry Pi 5**: Detected as SBC via `/proc/device-tree/model`. An 8 GB RPi 5 → SBC Mid (llama3.2:3b).

---

## 🎛️ Script Flags

### Backend Selection

| Flag | Description |
|---|---|
| *(none)* | 🎮 Shows backend chooser + main menu |
| `--ollama` | 🦙 Use Ollama as backend |
| `--llamacpp` | 🔧 Use llama.cpp (llama-server) as backend |

### Hermes Presets

| Flag | Description |
|---|---|
| `--hermes` | 🤖 Install + interactive preset chooser |
| `--hermes-hybrid` | ⚡ Install + hybrid preset (recommended) |
| `--hermes-offline` | 🔌 Install + full offline preset |
| `--hermes-aux` | 🎯 Install + auxiliary-only preset |
| `--hermes-reset` | 🔄 Reset Hermes to cloud/auto defaults |

### Other

| Flag | Description |
|---|---|
| `--models-only` | 📦 Skip install, only pull models |
| `--no-models` | ⏭️ Skip model downloads |
| `--hf-model <id>` | 🤗 Import a GGUF model from HuggingFace |
| `--hf-list` | 📋 Show popular HuggingFace GGUF models |
| `--mcp-scan` | 🔌 Scan Hermes MCP servers |
| `--skills-check` | 🧩 Check Hermes skills |
| `--dry-run` | 👀 Show every command without executing |
| `--uninstall` | 🗑️ Remove everything |
| `--help` | ❓ Show help |

### Common Combinations

```bash
# ⭐ Recommended first run (Ollama + hybrid)
bash ollama-setup.sh --ollama --hermes-hybrid

# llama.cpp with hybrid preset
bash ollama-setup.sh --llamacpp --hermes-hybrid

# 👀 Preview everything first
bash ollama-setup.sh --ollama --dry-run --hermes-hybrid

# 🤖 Add Hermes config later (backend already running)
bash ollama-setup.sh --ollama --models-only --hermes-aux

# 🔄 Switch presets
bash ollama-setup.sh --ollama --models-only --hermes-offline

# ↩️ Undo Hermes config
bash ollama-setup.sh --models-only --hermes-reset

# 🗑️ Full uninstall
bash ollama-setup.sh --uninstall
```

---

## 🤗 HuggingFace Model Import

Import any GGUF model from HuggingFace directly into your backend:

```bash
# List popular models
bash ollama-setup.sh --hf-list

# Import with auto-selected Q4_K_M quantization
bash ollama-setup.sh --ollama --hf-model bartowski/Qwen2.5-7B-Instruct-GGUF

# Import a specific file
bash ollama-setup.sh --ollama --hf-model bartowski/Qwen2.5-7B-Instruct-GGUF:Qwen2.5-7B-Instruct-Q5_K_M.gguf
```

Uses `huggingface-cli` if available, falls back to `curl`.

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

> Models are auto-selected based on your hardware tier. Both Ollama and llama.cpp expose the same OpenAI-compatible API, so Hermes works identically with either.

---

## 🦙 vs 🔧 Backend Comparison

| | 🦙 Ollama | 🔧 llama.cpp |
|---|---|---|
| **Install** | One-line script | brew / prebuilt / build from source |
| **Models** | `ollama pull` (auto-managed) | Download .gguf files manually |
| **API port** | 11434 | 8080 |
| **Model mgmt** | Built-in registry + Modelfiles | Manual file placement |
| **Hermes provider** | `ollama` | `llamacpp` |
| **OpenAI API** | ✅ `/v1` compatible | ✅ `/v1` compatible |
| **Best for** | Most users | Advanced users, lower overhead |

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

## 🔌 MCP & 🧩 Skills Integration

### MCP Server Scan

```bash
bash ollama-setup.sh --mcp-scan
```

Scans your Hermes MCP config and identifies servers that can benefit from local models.

### Skills Check

```bash
bash ollama-setup.sh --skills-check
```

Checks installed Hermes skills for integration opportunities.

---

## 🔒 Security

- 🔐 Backend binds to **localhost** — keep it that way
- 🚫 Port 11434 / 8080 should not be open in your firewall
- 🔑 The API key is a dummy — neither backend requires auth
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
Ensure active cooling — the Pi throttles without it.
</details>

<details>
<summary><b>🍎 macOS: GPU not used</b></summary>

Apple Silicon is auto-detected via Metal. Verify with `ollama ps` — should show GPU memory.
Intel Macs have no GPU acceleration.
</details>

<details>
<summary><b>🔧 llama.cpp: Binary not found</b></summary>

```bash
# Check if it's in PATH
which llama-server

# If not, check the install location
ls ~/.local/share/llamacpp/

# Or rebuild from source
cd /tmp && git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp && cmake -B build && cmake --build build
```
</details>

<details>
<summary><b>❌ Service not starting</b></summary>

```bash
# Ollama (Linux)
systemctl status ollama
journalctl -u ollama --no-pager | tail -30

# llama.cpp (Linux)
systemctl status llama-server
journalctl -u llama-server --no-pager | tail -30

# macOS
brew services info ollama    # or: launchctl list | grep llama
```
</details>

<details>
<summary><b>🤖 Hermes: "Unknown provider" error</b></summary>

```bash
# For Ollama:
hermes config set providers.ollama.name Ollama
hermes config set providers.ollama.base_url http://localhost:11434/v1
hermes config set providers.ollama.api_key ollama

# For llama.cpp:
hermes config set providers.llamacpp.name llama.cpp
hermes config set providers.llamacpp.base_url http://localhost:8080/v1
hermes config set providers.llamacpp.api_key ollama
```
</details>

<details>
<summary><b>🤖 Hermes not detected</b></summary>

The script looks for `hermes` in PATH or at `~/.hermes/hermes-agent/venv/bin/hermes`.
Install Hermes: `curl -fsSL https://raw.githubusercontent.com/nousresearch/hermes-agent/main/install.sh | bash`
</details>

---

## 🗑️ Uninstall

```bash
# Interactive menu
bash ollama-setup.sh --uninstall

# Or just reset Hermes config (keep backend)
bash ollama-setup.sh --models-only --hermes-reset
```

---

## 🧩 Tech Stack

| Tool | Description |
|---|---|
| [🦙 Ollama](https://ollama.com) | Local LLM runtime (default backend) |
| [🔧 llama.cpp](https://github.com/ggml-org/llama.cpp) | Lightweight C++ LLM server (alternative backend) |
| [🤖 Hermes Agent](https://hermes-agent.nousresearch.com) | AI assistant by Nous Research |
| [🤗 HuggingFace](https://huggingface.co) | GGUF model source |
| 🐚 Bash | No dependencies beyond standard tools |

---

<div align="center">

**MIT** — See [LICENSE](LICENSE)

</div>
