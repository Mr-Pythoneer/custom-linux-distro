#!/usr/bin/env bash
#
# Downloads the GGUF model weights for the Crucible12 presets.
# Direct port of 02-download-models.ps1 — same presets, same logic.
#
# Presets (each model runs ONE AT A TIME — they don't coexist in 96GB of memory):
#   crucible  Qwen3-Coder-Next @ Q4_K_XL  (~46GB) — DEFAULT, balanced agentic coder
#   max       Qwen3-Coder-Next @ Q6_K_XL  (~73GB) — higher fidelity, a bit slower
#   fast      Qwen3-Coder-30B-A3B @ Q4    (~18GB) — fully on GPU, lowest latency
#   reasoning gpt-oss-120b native MXFP4   (~60GB) — strong reasoning SECONDARY
#
# Usage: ./02-download-models.sh [crucible|max|fast|reasoning|all] [models_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESET="${1:-crucible}"
MODELS_DIR="${2:-$SCRIPT_DIR/../models}"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required (sudo apt-get install -y jq curl)." >&2
    exit 1
fi

declare -A REPO PATTERN NOTES
REPO[max]="unsloth/Qwen3-Coder-Next-GGUF";          PATTERN[max]="UD-Q6_K_XL";          NOTES[max]="~73GB, near-lossless Q6 — recommended best agentic coder"
REPO[crucible]="unsloth/Qwen3-Coder-Next-GGUF";      PATTERN[crucible]="UD-Q4_K_XL";      NOTES[crucible]="~46GB, split across VRAM+RAM via --n-cpu-moe"
REPO[fast]="unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF"; PATTERN[fast]="UD-Q4_K_XL";       NOTES[fast]="~18-20GB, fits fully in the 5090's 32GB VRAM"
REPO[reasoning]="ggml-org/gpt-oss-120b-GGUF";        PATTERN[reasoning]="mxfp4";          NOTES[reasoning]="~60GB native MXFP4, strong reasoning SECONDARY"

case "$PRESET" in
    crucible|max|fast|reasoning) TARGETS=("$PRESET") ;;
    all) TARGETS=(crucible max fast reasoning) ;;
    *) echo "Unknown preset '$PRESET'. Use crucible|max|fast|reasoning|all." >&2; exit 1 ;;
esac

mkdir -p "$MODELS_DIR"

for name in "${TARGETS[@]}"; do
    repo="${REPO[$name]}"
    pattern="${PATTERN[$name]}"
    echo -e "\033[36m\n=== $name : $repo (${NOTES[$name]}) ===\033[0m"

    dest_dir="$MODELS_DIR/$name"
    mkdir -p "$dest_dir"

    echo "Listing files matching '*${pattern}*.gguf' ..."
    # .siblings[].rfilename lists EVERY file in the repo with its full relative
    # path, including subfolders — so this correctly matches quants that live in
    # a subfolder and/or are split into shards. (e.g. the "max" preset's
    # UD-Q6_K_XL is UD-Q6_K_XL/...-00001-of-00003.gguf etc.; the download URL
    # below preserves the subfolder, and run-max.sh finds the -00001 shard.)
    info_json=$(curl -fsSL -A "Crucible12-Setup" "https://huggingface.co/api/models/$repo")
    mapfile -t files < <(echo "$info_json" | jq -r '.siblings[].rfilename' | grep -i "$pattern" | grep -i '\.gguf$' || true)

    if [ ${#files[@]} -eq 0 ]; then
        echo "WARNING: no files matched '*${pattern}*.gguf' in $repo. Browse https://huggingface.co/$repo/tree/main and adjust the pattern, or edit this script." >&2
        continue
    fi

    for file in "${files[@]}"; do
        out_path="$dest_dir/$(basename "$file")"
        if [ -f "$out_path" ]; then
            echo "Already have $file, skipping."
            continue
        fi
        url="https://huggingface.co/$repo/resolve/main/$file"
        echo "Downloading $file ..."
        curl -fL -A "Crucible12-Setup" -o "$out_path" "$url"
    done

    echo -e "\033[32mDone: $dest_dir\033[0m"
done

echo -e "\nModels saved under $MODELS_DIR (gitignored — never commit these)."
echo "Next: run 03-install-opencode.sh, then a launch script (run-max.sh / run-crucible.sh / run-fast.sh / run-reasoning.sh)."
echo "Reminder: enable DDR5 EXPO/XMP in BIOS for full generation speed on the hybrid presets."
