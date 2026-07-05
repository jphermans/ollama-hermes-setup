<div align="center">

# 🦙 Ollama + 🤖 Hermes Agent Setup

### Automated Ollama installer with **Hermes Agent preset integration**
### Tailored for CPU-only VPS environments

</div>

---

<div align="center">

| 🖥️ CPU | 💾 RAM | 💿 Disk | 🎮 GPU | 🐧 OS |
|---|---|---|---|---|
| Ryzen 5 3600 (6C/12T) | 64 GB | 349 GB | ❌ None | Debian 13 |

</div>

---

## 📖 Table of Contents

- [✨ What This Does](#-what-this-does)
- [🚀 Quick Start](#-quick-start)
- [📋 Requirements](#-requirements)
- [🤖 Hermes Agent Presets](#-hermes-agent-presets)
- [🎛️ Script Flags](#️-script-flags)
- [🔧 What the Script Does](#-what-the-script-does)
- [🎯 Hermes Auxiliary Slots](#-hermes-auxiliary-slots)
- [📦 Model Recommendations](#-model-recommendations)
- [🔌 REST API](#-rest-api)
- [🔒 Security](#-security)
- [📂 File Locations](#-file-locations)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [🗑️ Uninstall](#️-uninstall)
- [⌨️ Daily Commands](#️-daily-commands)

---

## ✨ What This Does

A single Bash script that:

1. 📥 **Installs Ollama** on Debian/Ubuntu (via official install script)
2. ⚙️ **Tunes systemd** for CPU-only inference (threads, parallelism, keep-alive)
3. 📦 **Downloads models** appropriate to your chosen preset
4. 🤖 **Configures Hermes Agent** with one of three presets for model routing

> **Designed for servers without a GPU** — all inference runs on CPU.

---

## 🚀 Quick Start

```bash
# 📥 Clone
git clone https://github.com/jphermans/ollama-hermes-setup.git
cd ollama-hermes-setup

# 🔓 Make executable
chmod +x ollama-setup.sh

# 🤖 Install with interactive preset chooser
bash ollama-setup.sh --hermes

# ⚡ Or go straight to the recommended hybrid preset
bash ollama-setup.sh --hermes-hybrid
```

### 👀 Dry Run First

Want to see exactly what happens before committing?

```bash
bash ollama-setup.sh --dry-run --hermes-hybrid
```

---

## 📋 Requirements

| Requirement | Details |
|---|---|
| 🐧 **OS** | Debian 12/13, Ubuntu 22.04+ (other Linux works but unsupported) |
| 🏗️ **Architecture** | x86_64 (arm64 works with Ollama but untested) |
| 💾 **RAM** | 8 GB minimum, 16 GB+ recommended |
| 💿 **Disk** | 20 GB free minimum |
| 📦 **curl** | Required for download |
| 🔑 **sudo** | Required for systemd service installation |
| 🤖 **Hermes Agent** | Optional — only needed for `--hermes-*` flags |

> 💡 **Not using Hermes?** The script works standalone. Skip the `--hermes-*` flags and you get a fully tuned Ollama installation without any Hermes configuration.

---

## 🤖 Hermes Agent Presets

When using [Hermes Agent](https://hermes-agent.nousresearch.com) (by Nous Research), this script configures model routing across three task layers: **main conversation**, **delegation** (coding subagents), and **auxiliary tasks** (vision, compression, titles, etc.).

### Preset Comparison

| | 🔌 Full Offline | ⚡ Hybrid ⭐ | 🎯 Auxiliary Only |
|---|---|---|---|
| **Flag** | `--hermes-offline` | `--hermes-hybrid` | `--hermes-aux` |
| **💬 Main chat** | 🖥️ gemma4 (local) | ☁️ glm-5.2 (cloud) | ☁️ glm-5.2 (cloud) |
| **🔀 Delegation** | 🖥️ gemma4 (local) | 🖥️ gemma4 (local) | ☁️ cloud (unchanged) |
| **🔧 Auxiliary** | 🖥️ gemma3:12b (local) | 🖥️ gemma3:12b (local) | 🖥️ gemma3:12b (local) |
| **💾 Disk needed** | ~18 GB | ~18 GB | ~8.5 GB |
| **🧠 RAM loaded** | ~12 GB | ~12 GB | ~7 GB |
| **💰 Cloud cost** | 🟢 Zero | 🟡 Reduced | 🔴 Same as now |
| **🔒 Privacy** | 🟢 Full | 🟡 Partial | 🟡 Partial |
| **✅ Best for** | Offline / privacy | Daily use | Minimal setup |

### 🤔 Which Preset Should I Pick?

| Preset | When to choose |
|---|---|
| 🔌 **Full Offline** | You want zero cloud dependency. All tasks run locally. Best for privacy or unreliable internet. |
| ⚡ **Hybrid** ⭐ | Cloud quality for main chat, local for everything else. **Best balance of cost and quality.** |
| 🎯 **Auxiliary Only** | Cloud handles all user-facing work. Local only for background tasks. Lowest local footprint. |

### 🎨 Customizing Models

Edit the variables at the top of the script:

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
| *(none)* | 🚀 Full install: pre-flight + install + systemd + starter models |
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

### 1. 🔍 Pre-flight Checks
Verifies OS, architecture, RAM, disk space, and CPU cores. Detects existing Ollama installations. Aborts on missing dependencies.

### 2. 📥 Install Ollama
Runs the official install script from `ollama.com/install.sh`. Creates `/usr/local/bin/ollama` and a systemd service.

### 3. ⚙️ Configure systemd
Writes a performance-tuned systemd override at:
```
/etc/systemd/system/ollama.service.d/override.conf
```

| ⚙️ Setting | 💡 Value | 📝 Why |
|---|---|---|
| `OLLAMA_NUM_THREAD` | Auto-detected (physical cores) | Optimal CPU usage without hyperthread thrashing |
| `OLLAMA_NUM_PARALLEL` | `1` | CPU-only can't handle concurrent inference |
| `OLLAMA_HOST` | `127.0.0.1:11434` | Localhost only — never expose without auth |
| `OLLAMA_KEEP_ALIVE` | `5m` | Models stay in RAM 5 min after last use |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | Allow two models loaded simultaneously |

### 4. 📦 Pull Models
Downloads models appropriate to the selected preset. See [Model Recommendations](#-model-recommendations).

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

## 📦 Model Recommendations

### 🏆 Sweet Spot: 7B–12B Models

| 📦 Model | 💾 Size | 🧠 RAM | ⚡ Speed | 📝 Best For |
|---|---|---|---|---|
| `gemma3:12b` | ~8.1 GB | ~10 GB | 🟡 6-10 tok/s | All Hermes auxiliary slots |
| `llama3.1:8b` | ~4.7 GB | ~6 GB | 🟢 10-15 tok/s | General-purpose chat |
| `qwen2.5:7b` | ~4.7 GB | ~6 GB | 🟢 10-15 tok/s | Multilingual, coding |
| `mistral:7b` | ~4.1 GB | ~5.5 GB | 🟢 10-15 tok/s | Reasoning |

### 💬 Conversation / Delegation

| 📦 Model | 💾 Size | 🧠 RAM | ⚡ Speed | 📝 Best For |
|---|---|---|---|---|
| `gemma4:latest` | ~9.6 GB | ~11 GB | 🟡 8-12 tok/s | Main conversation + delegation |
| `qwen2.5:14b` | ~8.9 GB | ~10 GB | 🟡 6-10 tok/s | Strong reasoning |
| `deepseek-r1:14b` | ~8.9 GB | ~10 GB | 🟡 6-10 tok/s | Chain-of-thought reasoning |

### 🔣 Embeddings

| 📦 Model | 💾 Size | 📝 Best For |
|---|---|---|
| `nomic-embed-text` | ~137 MB | Default embeddings for Hermes |
| `mxbai-embed-large` | ~670 MB | Top-tier retrieval |
| `bge-m3` | ~1.2 GB | Multilingual embeddings |

### 💻 Coding

| 📦 Model | 💾 Size | 📝 Best For |
|---|---|---|
| `qwen2.5-coder:7b` | ~4.7 GB | Code generation & completion |
| `qwen2.5-coder:14b` | ~8.9 GB | Complex multi-file coding |
| `deepseek-coder-v2:16b` | ~8.9 GB | Multi-language coding |

### 🐢 Large Models (Slow on CPU)

| 📦 Model | 💾 Size | ⚡ Speed | ⚠️ Note |
|---|---|---|---|
| `qwen2.5:32b` | ~19 GB | 🔴 3-5 tok/s | Batch processing only |
| `command-r:35b` | ~17 GB | 🔴 2-4 tok/s | RAG & tool use |
| `llama3.1:70b` | ~40 GB | 🔴 1-3 tok/s | Feasible but very slow |

> ⚠️ **70B models will run** (you have the RAM), but CPU-only inference at 1-3 tokens/sec is only practical for background/batch tasks, not real-time chat.

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

This is expected on CPU-only inference. Options:
- Switch to the **hybrid** preset (cloud for main chat)
- Use smaller models (7B instead of 12B)
- Check speed: the response metadata includes tokens/sec
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

---

## 👤 Author

**JPHsystems**

---

*This script was built for a specific VPS (AMD Ryzen 5 3600, 64 GB RAM, Debian 13, CPU-only) but works on any Debian/Ubuntu server. Adjust the model choices and thread count as needed for your hardware.*

</div>
