#!/usr/bin/env bash
#
# Downloads the image-generation models into ComfyUI's model dirs.
#
# Defaults to FLUX.1-schnell (Apache-2.0, NO Hugging Face token needed, via the
# Comfy-Org mirror) + SDXL base. FLUX.1-dev is GATED (requires accepting its
# non-commercial license on HF + a token) — it's only fetched if you export
# HF_TOKEN and pass --flux-dev.
#
# Uses the huggingface-cli (hf) downloader. Run as the desktop user.
#
# Usage:
#   ./04-download-image-models.sh [comfyui_dir]              # FLUX.1-schnell + SDXL (no token)
#   HF_TOKEN=hf_xxx ./04-download-image-models.sh [dir] --flux-dev   # also the gated FLUX.1-dev

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi

COMFY_DIR="${1:-$HOME/ComfyUI}"
WANT_FLUX_DEV=false
[ "${2:-}" = "--flux-dev" ] && WANT_FLUX_DEV=true

[ -d "$COMFY_DIR/models" ] || { echo "ComfyUI not found at $COMFY_DIR (run 03-install-comfyui.sh first)." >&2; exit 1; }

# Prefer the venv's hf CLI; install it into the venv if missing.
HF="hf"
if [ -x "$COMFY_DIR/venv/bin/hf" ]; then
    HF="$COMFY_DIR/venv/bin/hf"
elif [ -x "$COMFY_DIR/venv/bin/pip" ]; then
    echo "Installing huggingface_hub[cli] into the ComfyUI venv..."
    "$COMFY_DIR/venv/bin/pip" install -U "huggingface_hub[cli]" >/dev/null
    HF="$COMFY_DIR/venv/bin/hf"
fi
command -v "$HF" >/dev/null 2>&1 || [ -x "$HF" ] || { echo "huggingface CLI not found — pip install -U 'huggingface_hub[cli]'." >&2; exit 1; }

ckpt="$COMFY_DIR/models/checkpoints"
te="$COMFY_DIR/models/text_encoders"
vae="$COMFY_DIR/models/vae"
unet="$COMFY_DIR/models/diffusion_models"

echo -e "\033[36m== SDXL base 1.0 (no token, ~7GB) ==\033[0m"
"$HF" download stabilityai/stable-diffusion-xl-base-1.0 sd_xl_base_1.0.safetensors --local-dir "$ckpt"

echo -e "\033[36m== FLUX text encoders + (schnell) — open repos, no token ==\033[0m"
# Text encoders (shared by FLUX dev + schnell), from the open Comfy repo.
"$HF" download comfyanonymous/flux_text_encoders clip_l.safetensors t5xxl_fp16.safetensors --local-dir "$te"

echo -e "\033[36m== FLUX.1-schnell (Apache-2.0, no token, ~17GB fp8) ==\033[0m"
# Comfy-Org mirror avoids the token prompt entirely. fp8 all-in-one goes in checkpoints.
"$HF" download Comfy-Org/flux1-schnell flux1-schnell-fp8.safetensors --local-dir "$ckpt" \
    || echo "WARNING: flux1-schnell-fp8 download failed — check the repo/file name on HF." >&2

if [ "$WANT_FLUX_DEV" = "true" ]; then
    echo -e "\033[36m== FLUX.1-dev (GATED — needs HF_TOKEN + accepted license, ~24GB) ==\033[0m"
    if [ -z "${HF_TOKEN:-}" ]; then
        echo "HF_TOKEN is not set. FLUX.1-dev is gated: accept the license at" >&2
        echo "https://huggingface.co/black-forest-labs/FLUX.1-dev and export an HF read token:" >&2
        echo "  export HF_TOKEN=hf_xxx ; ./04-download-image-models.sh \"$COMFY_DIR\" --flux-dev" >&2
        exit 1
    fi
    "$HF" download black-forest-labs/FLUX.1-dev flux1-dev.safetensors --local-dir "$unet"
    "$HF" download black-forest-labs/FLUX.1-dev ae.safetensors --local-dir "$vae"
else
    echo "Skipping FLUX.1-dev (gated). To add it later: HF_TOKEN=hf_xxx $(basename "$0") \"$COMFY_DIR\" --flux-dev"
    # schnell needs a VAE too; the dev ae.safetensors is gated, so fetch the
    # repackaged open VAE for the schnell pipeline.
    "$HF" download Comfy-Org/flux1-schnell ae.safetensors --local-dir "$vae" 2>/dev/null \
        || echo "NOTE: grab a FLUX VAE (ae.safetensors) into $vae if schnell needs one." >&2
fi

echo -e "\033[32m\nDone. Start image gen with: distro-ai-image  (ComfyUI web UI on port 8188).\033[0m"
echo "Model files are under $COMFY_DIR/models (gitignored — never commit weights)."
