<div align="center">

# 🦙 Ollama + 🤖 Hermes Agent Setup

### Automated Ollama installer with hardware detection and **Hermes Agent preset integration**

**Works on any Linux server — CPU or GPU, 4 GB or 128 GB RAM.**

</div>

---

## ✨ What This Does

A single Bash script that:

1. 🔍 **Detects your hardware** — CPU cores, RAM, swap, disk, GPU + VRAM
2. 📊 **Classifies your machine** into a hardware tier (tiny → GPU large)
3. 🎯 **Recommends models** that fit your available resources
4. 📥 **Installs Ollama** on Debian/Ubuntu (via official install script)
5. ⚙️ **Tunes systemd** — threads, parallelism, and max-loaded-models auto-configured
6. 📦 **Downloads models** appropriate to your hardware and chosen preset
7. 🤖 **Configures Hermes Agent** with one of three presets for model routing

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

You'll see:

```
  Welcome! What would you like to do?

   1  🚀 Full Install + Hermes Hybrid ⭐
     Install Ollama + tune systemd + download models
     Configure Hermes with the recommended hybrid preset

   2  ⚙️  Full Install Only
     Install Ollama + tune systemd + download starter models
     No Hermes configuration (standalone Ollama)

   3  🤖 Configure Hermes Only
     Ollama is already installed — just set up Hermes presets
     Shows the preset chooser (offline / hybrid / aux-only)

   4  📦 Download Models Only
     Pull specific models without installing or configuring

   5  👁️  Dry Run Preview
     See exactly what would happen without changing anything

   6  🗑️  Uninstall Ollama
     Remove Ollama, service, models, and user account

   q  Exit
```

### Option B: Direct Flags

```bash
# Install with interactive preset chooser
bash ollama-setup.sh --hermes

# Go straight to the recommended hybrid preset
bash ollama-setup.sh --hermes-hybrid
```

### 👀 Dry Run First

Want to see exactly what happens before committing?

```bash
bash ollama-setup.sh --dry-run --hermes-hybrid
```

---

## 🔍 Hardware Detection

The script automatically detects your hardware and picks the right models. Here's how it classifies your machine:

| Tier | Condition | Recommended Models | Speed |
|---|---|---|---|
| 🟢 **GPU Large** | NVIDIA GPU with 24 GB+ VRAM | qwen2.5:32b, gemma3:12b | ⚡ Very fast |
| 🟢 **GPU Mid** | NVIDIA GPU with 12–24 GB VRAM | gemma4, gemma3:12b | ⚡ Fast |
| 🟡 **GPU Small** | NVIDIA GPU with 6–12 GB VRAM | gemma4, gemma3:12b | ⚡ Fast |
| 🟠 **GPU Tiny** | NVIDIA GPU with <6 GB VRAM | llama3.1:8b | 🟡 Moderate |
| 🔵 **CPU High** | 32 GB+ RAM, no GPU | gemma4, gemma3:12b | 🟡 Moderate |
| 🟡 **CPU Mid** | 16–32 GB RAM, no GPU | llama3.1:8b, gemma3:12b | 🟡 Moderate |
| 🟠 **CPU Low** | 8–16 GB RAM, no GPU | llama3.2:3b | 🐢 Slow |
| 🔴 **CPU Tiny** | <8 GB RAM, no GPU | llama3.2:1b | 🐢 Very slow |

### What Gets Auto-Configured

| Setting | How it's determined |
|---|---|
| `OLLAMA_NUM_THREAD` | Set to your physical CPU core count |
| `OLLAMA_MAX_LOADED_MODELS` | 1 on low-RAM, 2–3 on high-RAM/GPU |
| Model sizes | Scaled to fit your RAM/VRAM |
| `OLLAMA_NUM_PARALLEL` | Always 1 (safest for stability) |

### What Gets Detected

```
    ┌──────────────────────────────────────────────┐
    │  🧠 DETECTED HARDWARE                        │
    ├──────────────────────────────────────────────┤
    │  🖥️  OS            Debian GNU/Linux 13       │
    │  🏗️  Arch          x86_64                    │
    │  ⚡ CPU            6c/12t                     │
    │      AMD Ryzen 5 3600 6-Core Processor       │
    │  💾 RAM            63 GB                     │
    │      + 31 GB swap                            │
    │  💿 Disk           349 GB free               │
    │  🎮 GPU            None (CPU-only)           │
    ├──────────────────────────────────────────────┤
    │  📊 Tier           🔵 CPU High (32GB+ RAM)   │
    └──────────────────────────────────────────────┘
```

---

## 📋 Requirements

| Requirement | Details |
|---|---|
| 🐧 **OS** | Debian 12/13, Ubuntu 22.04+ (other Linux works but unsupported) |
| 🏗️ **Architecture** | x86_64 or arm64 |
| 💾 **RAM** | 4 GB minimum (tiny models only) |
| 💿 **Disk** | 10 GB free minimum |
| 📦 **curl** | Required for download |
| 🔑 **sudo** | Required for systemd service installation |
| 🤖 **Hermes Agent** | Optional — only needed for `--hermes-*` flags |
| 🎮 **GPU** | Optional — NVIDIA GPUs auto-detected via `nvidia-smi` |

> 💡 **Not using Hermes?** The script works standalone. Skip the `--hermes-*` flags and you get a fully tuned Ollama installation.

---

## 🤖 Hermes Agent Presets

When using [Hermes Agent](https://hermes-agent.nousresearch.com) (by Nous Research), this script configures model routing across three task layers: **main conversation**, **delegation** (coding subagents), and **auxiliary tasks** (vision, compression, titles, etc.).

### Preset Comparison

| | 🔌 Full Offline | ⚡ Hybrid ⭐ | 🎯 Auxiliary Only |
|---|---|---|---|
| **Flag** | `--hermes-offline` | `--hermes-hybrid` | `--hermes-aux` |
| **💬 Main chat** | 🖥️ local model | ☁️ cloud (unchanged) | ☁️ cloud (unchanged) |
| **🔀 Delegation** | 🖥️ local model | 🖥️ local model | ☁️ cloud (unchanged) |
| **🔧 Auxiliary** | 🖥️ local model | 🖥️ local model | 🖥️ local model |
| **💰 Cloud cost** | 🟢 Zero | 🟡 Reduced | 🔴 Same as now |
| **🔒 Privacy** | 🟢 Full | 🟡 Partial | 🟡 Partial |
| **✅ Best for** | Offline / privacy | Daily use | Minimal setup |

> 💡 **Which models?** The script picks models automatically based on your hardware tier. See [Hardware Detection](#-hardware-detection) above.

### 🎨 Customizing Models

The script auto-selects models, but you can override them by editing the variables at the top:

```bash
HERMES_MAIN="gemma4:latest"       # 💬 Main conversation model
HERMES_DELEGATION="gemma4:latest"  # 🔀 Coding subagent model
HERMES_AUX="gemma3:12b"           # 🔧 Auxiliary task model
HERMES_KANBAN="gemma4:latest"     # 📋 Kanban decomposer (needs reasoning)
```

---

## 🎛️ Script Flags

| Flag | Description |
|---|---|
| *(none)* | 🎮 Interactive menu |
| `--hermes` | 🤖 Full install + interactive preset chooser |
| `--hermes-offline` | 🔌 Full install + full-offline preset (all local) |
| `--hermes-hybrid` | ⚡ Full install + hybrid preset (cloud main, local aux + delegation) |
| `--hermes-aux` | 🎯 Full install + auxiliary-only preset |
| `--hermes-reset` | 🔄 Reset Hermes config back to cloud/auto defaults |
| `--no-models` | ⏭️ Skip all model downloads |
| `--models-only` | 📦 Skip install/systemd, only pull models |
| `--dry-run` | 👀 Show every command without executing anything |
| `--uninstall` | 🗑️ Remove Ollama completely (service, binary, models, user) |

### 💡 Common Combinations

```bash
# ⭐ Recommended first run
bash ollama-setup.sh --hermes-hybrid

# 👀 Preview everything first
bash ollama-setup.sh --dry-run --hermes-hybrid

# 🤖 Add Hermes config later (Ollama already running)
bash ollama-setup.sh --models-only --hermes-aux

# 🔄 Switch presets
bash ollama-setup.sh --models-only --hermes-offline

# ↩️ Undo Hermes config
bash ollama-setup.sh --models-only --hermes-reset

# 🗑️ Full uninstall
bash ollama-setup.sh --uninstall
```

---

## 🔧 What the Script Does

### 1. 🔍 Hardware Detection
Detects CPU model, core count, RAM, swap, disk space, and NVIDIA GPU (if present). Classifies the machine into a tier and selects appropriate models. Shows a formatted hardware summary card.

### 2. 📥 Install Ollama
Runs the official install script from `ollama.com/install.sh`. Creates `/usr/local/bin/ollama` and a systemd service.

### 3. ⚙️ Configure systemd
Writes a performance-tuned systemd override with auto-detected values:

| ⚙️ Setting | 💡 Value | 📝 Why |
|---|---|---|
| `OLLAMA_NUM_THREAD` | Physical CPU cores | Optimal CPU usage without hyperthread thrashing |
| `OLLAMA_NUM_PARALLEL` | `1` | Safest for stability |
| `OLLAMA_HOST` | `127.0.0.1:11434` | Localhost only — never expose without auth |
| `OLLAMA_KEEP_ALIVE` | `5m` | Models stay in RAM 5 min after last use |
| `OLLAMA_MAX_LOADED_MODELS` | 1–3 (by tier) | Scaled to available RAM/VRAM |

### 4. 📦 Pull Models
Downloads models appropriate to your hardware tier and chosen preset.

### 5. 🤖 Configure Hermes
Uses `hermes config set` commands to:
- ✅ Register the Ollama provider (**required first!**)
- 💬 Set the main model (`model.*`)
- 🔀 Set the delegation model (`delegation.*`)
- 🔧 Set all auxiliary slots (`auxiliary.<slot>.*`)

> 💾 **Always creates a timestamped backup** of `~/.hermes/config.yaml` before changes.

### 6. 📊 Verify & Summary
Checks service status, API health, lists downloaded models, and shows the applied Hermes preset.

---

## 🎯 Hermes Auxiliary Slots

The script configures all local-capable auxiliary slots:

| 🎯 Slot | 📝 Purpose | 🖥️ Can Be Local? |
|---|---|---|
| `vision` | 🖼️ Image analysis / OCR | ✅ (needs multimodal model) |
| `web_extract` | 🌐 Web page summarization | ✅ |
| `compression` | 🗜️ Context window compression | ✅ |
| `title_generation` | 🏷️ Session titles | ✅ |
| `approval` | ✅ Smart command approval | ✅ |
| `triage_specifier` | 🔀 Agent triage decisions | ✅ |
| `session_search` | 🔍 Semantic session search | ✅ |
| `curator` | 📚 Skill lifecycle management | ✅ |
| `profile_describer` | 👤 Profile descriptions | ✅ |
| `kanban_decomposer` | 📋 Task decomposition | ✅ (needs stronger model) |
| `skills_hub` | 🌍 Remote skill registry | ❌ needs internet |
| `mcp` | 🔌 MCP server management | ❌ needs internet |

---

## 📦 Model Catalog

The script picks from these models based on your hardware tier:

### 🏆 General Purpose

| Model | Size | Min RAM | Hardware Tier |
|---|---|---|---|
| `llama3.2:1b` | ~1.3 GB | 4 GB | 🔴 CPU Tiny |
| `llama3.2:3b` | ~2.0 GB | 8 GB | 🟠 CPU Low |
| `llama3.1:8b` | ~4.7 GB | 8–16 GB | 🟡 CPU Mid / 🟠 GPU Tiny |
| `gemma3:12b` | ~8.1 GB | 16 GB | 🔵 CPU High / 🟡 GPU Small |
| `gemma4:latest` | ~9.6 GB | 16–32 GB | 🔵 CPU High / 🟢 GPU Mid |
| `qwen2.5:32b` | ~19 GB | 32 GB+ | 🟢 GPU Large |

### 🔣 Embeddings

| Model | Size | Notes |
|---|---|---|
| `nomic-embed-text` | ~137 MB | Default — tiny, loads instantly |

### 💻 Coding

| Model | Size | Notes |
|---|---|---|
| `qwen2.5-coder:7b` | ~4.7 GB | Good for mid-range hardware |
| `qwen2.5-coder:14b` | ~8.9 GB | Needs 16 GB+ RAM |

> 📝 **Want a model not listed?** Just pull it manually: `ollama pull <model-name>`

---

## 🔌 REST API

Ollama exposes a REST API on `127.0.0.1:11434`:

```bash
# 📋 List models
curl http://127.0.0.1:11434/api/tags

# 💬 Chat
curl http://127.0.0.1:11434/api/chat -d '{
  "model": "gemma3:12b",
  "messages": [{"role": "user", "content": "Hello!"}],
  "stream": false
}'

# ⚡ Generate
curl http://127.0.0.1:11434/api/generate -d '{
  "model": "gemma3:12b",
  "prompt": "Write a haiku about servers.",
  "stream": false
}'
```

Ollama also provides an **OpenAI-compatible API** at `/v1` (used by Hermes):
```
base_url: http://localhost:11434/v1
```

---

## 🔒 Security

- 🔐 **Ollama binds to localhost by default** — keep it that way. Do NOT set `OLLAMA_HOST=0.0.0.0` without a reverse proxy with authentication.
- 🚫 **Port 11434 should not be open** in your firewall.
- 🔑 **The API key is a dummy** — Ollama doesn't require auth. Anyone with shell access can use it. This is fine because it's localhost-only.
- 🌐 **For remote access**, use nginx with basic auth:

```nginx
location /ollama/ {
    proxy_pass http://127.0.0.1:11434/;
    auth_basic "Ollama Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd-ollama;
}
```

---

## 📂 File Locations

| 📂 Path | 📝 Purpose |
|---|---|
| `/usr/local/bin/ollama` | 📦 Ollama binary |
| `/etc/systemd/system/ollama.service` | ⚙️ Default systemd unit |
| `/etc/systemd/system/ollama.service.d/override.conf` | 🔧 Performance tuning overrides |
| `/usr/share/ollama/.ollama/` | 🗂️ Model storage (default) |
| `~/.hermes/config.yaml` | 🤖 Hermes Agent configuration |
| `~/.hermes/config.yaml.bak.*` | 💾 Timestamped backups (created by script) |

---

## 🛠️ Troubleshooting

<details>
<summary><b>❌ Ollama service not starting</b></summary>

```bash
systemctl status ollama
journalctl -u ollama --no-pager | tail -30
sudo systemctl restart ollama
```
</details>

<details>
<summary><b>🌐 API not responding</b></summary>

```bash
# Test directly
curl http://127.0.0.1:11434/api/tags

# Check if port is listening
ss -tlnp | grep 11434

# Check override for typos
cat /etc/systemd/system/ollama.service.d/override.conf
```
</details>

<details>
<summary><b>🤖 Hermes: "Unknown provider ollama"</b></summary>

The provider isn't registered. Fix:
```bash
hermes config set providers.ollama.name Ollama
hermes config set providers.ollama.base_url http://localhost:11434/v1
hermes config set providers.ollama.api_key ollama
```
Or re-run: `bash ollama-setup.sh --models-only --hermes-<preset>`

> ⚠️ **Important:** Use `provider: ollama` (plain key), NOT `provider: custom:ollama`.
</details>

<details>
<summary><b>🔄 Hermes: Model changes not taking effect</b></summary>

The main conversation model is **locked at session start**. After config changes:
```bash
systemctl --user restart hermes-gateway
# Then start a new session (/reset or /new)
```
Auxiliary slots update dynamically — no restart needed for those.
</details>

<details>
<summary><b>💥 Out of Memory (OOM)</b></summary>

```bash
ollama ps                              # Check loaded models
ollama stop <model-name>               # Unload unused models
# Edit override: reduce OLLAMA_MAX_LOADED_MODELS to 1
sudo systemctl daemon-reload && sudo systemctl restart ollama
```
</details>

<details>
<summary><b>🐌 Slow responses</b></summary>

CPU-only inference is slower than GPU. Options:
- Switch to the **hybrid** preset (cloud for main chat)
- Use smaller models (7B instead of 12B)
- Check if a GPU is available: `nvidia-smi`
- The script auto-selects models that fit your hardware — trust the tier detection
</details>

<details>
<summary><b>🎮 GPU not detected</b></summary>

The script uses `nvidia-smi` for GPU detection. If you have a GPU but it's not showing:
```bash
# Check if nvidia-smi works
nvidia-smi

# If not, install NVIDIA drivers
sudo apt install nvidia-driver-535  # or latest for your system

# Verify CUDA is available to Ollama
ollama ps  # Should show GPU memory in the output
```
</details>

---

## 🗑️ Uninstall

```bash
# 🗑️ Full uninstall (interactive confirmation)
bash ollama-setup.sh --uninstall

# 🔄 Or just reset Hermes config (keep Ollama)
bash ollama-setup.sh --models-only --hermes-reset
```

---

## ⌨️ Daily Commands

```bash
# 🦙 Ollama
ollama list                    # 📋 List downloaded models
ollama run gemma4:latest       # 💬 Interactive chat
ollama ps                      # 👁️ Show loaded models
ollama stop gemma3:12b         # 🛑 Unload a model
ollama pull <model>            # ⬇️ Download a new model
ollama rm <model>              # 🗑️ Delete a model

# ⚙️ Service
sudo systemctl status ollama           # 📊 Status
sudo systemctl restart ollama          # 🔄 Restart
journalctl -u ollama -f                # 📝 Follow logs

# 🤖 Hermes
systemctl --user restart hermes-gateway   # 🔄 Apply config changes
hermes config show                        # 👁️ View current config
journalctl --user -u hermes-gateway -f   # 📝 Gateway logs
```

---

## 🧩 Tech Stack

| 🔧 Tool | 📝 Description |
|---|---|
| [🦙 Ollama](https://ollama.com) | Local LLM runtime |
| [🤖 Hermes Agent](https://hermes-agent.nousresearch.com) | AI assistant by Nous Research |
| 🐚 Bash | No dependencies beyond standard Linux tools |

---

<div align="center">

## 📄 License

**MIT** — See [LICENSE](LICENSE)

</div>
