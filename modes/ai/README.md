# AI mode

Local-first AI, built on **LM Studio** (text + vision LLMs) and **ComfyUI**
(image generation). This replaced the original Crucible12/llama.cpp runtime on
2026-06-30 — that port is preserved in `legacy-crucible12/`. See DESIGN.md §5.

Everything runs **on your own machine** — LM Studio's server is local
(127.0.0.1), no cloud, no API keys (an optional Claude-cloud toggle exists for
when you explicitly want it). LM Studio is free for personal and commercial use.

> **All of this is built against web-verified facts (install method, exact
> model repos/quants, ComfyUI/FLUX) but has NOT been run on the real 5090 yet.**
> This is the 5090/9950X3D/64GB build. See `docs/blackwell-readiness.md` and
> `docs/first-hardware-runbook.md`.

## Install (run on the real GPU box, as your normal user — NOT root)

```bash
# Text + vision LLMs (LM Studio)
./setup/01-install-lmstudio.sh        # headless llmster + lms CLI (curl|bash from lmstudio.ai)
./setup/02-preload-models.sh          # pull the catalog (~150GB — prints a size warning)
./setup/05-install-opencode.sh        # optional: OpenCode coding agent on top of LM Studio

# Image generation (ComfyUI — separate runtime, LM Studio can't do diffusion)
./setup/03-install-comfyui.sh         # ComfyUI + PyTorch cu130 (Blackwell)
./setup/04-download-image-models.sh   # FLUX.1-schnell (no token) + SDXL

# Auto-start the LM Studio server on login (port 8080):
mkdir -p ~/.config/systemd/user
cp systemd/lmstudio.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now lmstudio.service
```

Then load a model and use it:

```bash
distro-ai-model use coding      # loads Qwen2.5-Coder-32B, server on :8080
distro-ai-ask "explain this regex"
distro-ai-image                 # opens ComfyUI for image gen (port 8188)
```

## The model menu (config/models.catalog.json)

The OpenAI-compatible server runs on **port 8080** (`lms server start --port
8080`), so the existing thin clients keep working unchanged. Switch by use-case:

| Use-case | Best | Fast/alt |
|---|---|---|
| `coding` | Qwen2.5-Coder-32B | Qwen2.5-Coder-7B |
| `cad` | Qwen2.5-Coder-32B | DeepSeek-Coder-V2-Lite 16B |
| `day-to-day` | Llama-3.3-70B¹ | Qwen2.5-14B / Llama-3.2-3B |
| `know-it-all` | Llama-3.3-70B¹ | |
| `uncensored` | Dolphin 2.9 Llama-3 8B | Dolphin 2.7 Mixtral 8x7B |
| `assistant` | Llama-3.2-3B | Qwen2.5-7B |
| `vision` | Qwen2.5-VL-32B | Qwen2.5-VL-7B² |
| `image` (ComfyUI) | FLUX.1-dev³ | SDXL |

`distro-ai-model list | use <case> [variant] | load <id> | server start|stop |
status | unload`.

**Verified caveats (the reason this was researched, not guessed):**
- ¹ **Llama-3.3-70B** at Q4_K_M is ~42.5GB — it does NOT fit the 32GB 5090, so
  it loads with partial CPU offload (`--gpu 0.8`) to the 64GB RAM. Realistic
  **~6–12 tok/s** (the often-cited 15–20 needs a smaller quant). Everything else
  fits fully in VRAM.
- ² The requested **`llama3.2-vision:11b` does NOT work in LM Studio** —
  llama.cpp never implemented its `mllama` architecture (loads fail with
  "unknown model architecture: mllama"). The verified substitute is
  **Qwen2.5-VL-7B** (same family, fully supported). `qwen2.5-vl:32b` works but
  needs its `mmproj` vision file alongside (`lms get` pulls it).
- ³ **FLUX.1-dev is gated** (HF license + token). The installer defaults to the
  Apache-2.0 **FLUX.1-schnell** (no token); pass `HF_TOKEN=… --flux-dev` for dev.
- **Image generation runs in ComfyUI, not LM Studio** (LM Studio has no local
  diffusion). It has its own web UI/API on port 8188 — `distro-ai-image` launches it.
- Full preload of everything (LLMs + image models) is **~190–210GB** on disk.

## Thin clients (unchanged — they hit :8080)

- `bin/distro-ai-ask` — shared OpenAI-compatible backend (one curl call).
- `bin/distro-ai-overlay` + `bin/distro-ai-bind-hotkey` — zenity prompt bound to
  `<Super>space`.
- `integrations/nautilus-ask-ai` — "ask AI about this file" Nautilus script.
- These need a model loaded first (`distro-ai-model use <case>`) and a live
  GNOME session to render — execution-tested against a stub server, not a real
  desktop.

## Optional cloud fallback (explicit opt-in)

`bin/distro-ai-cloud-toggle enable` swaps the project's OpenCode config to route
through Claude (cloud) — for when you want a stronger model and have
connectivity. Requires your own `ANTHROPIC_API_KEY`. `config/opencode.lmstudio.json`
is the local (LM Studio :8080) counterpart. Per DESIGN.md §5, cloud is never the
silent default.

## Status — needs the 5090

- [ ] `01-install-lmstudio.sh` actually installs llmster + lms CLI on the box
- [ ] `02-preload-models.sh` pulls the catalog; each model loads with the right
      `--gpu` offload (`--estimate-only` to tune the 70B ratio)
- [ ] `distro-ai-model use <case>` loads + serves on :8080; thin clients answer
- [ ] vision: `qwen2.5-vl:32b` loads its mmproj and accepts an image
- [ ] ComfyUI: PyTorch sees the 5090 (`torch.cuda.is_available()`), FLUX/SDXL render
- [ ] `lmstudio.service` user unit auto-starts the server on login

The `distro-ai-model` switcher + catalog are execution-tested with a **stubbed
`lms`** (15 assertions, `tests/test_ai_model.sh`) — never against a real LM Studio.
