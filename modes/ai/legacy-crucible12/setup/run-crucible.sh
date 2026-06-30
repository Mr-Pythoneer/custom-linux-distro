#!/usr/bin/env bash
#
# Launches llama-server with the "crucible" preset: Qwen3-Coder-Next (80B/3B-active
# MoE), split across the RTX 5090's 32GB VRAM and the 9950X3D's 64GB system RAM.
#
# -ngl 99 puts every layer the GPU can hold onto the GPU; --n-cpu-moe N then pulls
# the *expert* weights of the first N MoE layers back onto CPU/RAM, while dense,
# attention, and shared-expert weights (plus the remaining experts) stay on the GPU.
#
# CPU_MOE is a starting point, not a measured optimum. Tune on your machine: watch
# `nvidia-smi` VRAM usage and increase CPU_MOE until you stop hitting CUDA
# out-of-memory errors, leaving a few GB of VRAM headroom for the KV cache.
#
# Usage: ./run-crucible.sh [cpu_moe] [ctx_size] [port] [model_dir]
#   Defaults: cpu_moe=16 ctx_size=65536 port=8080

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPU_MOE="${1:-16}"
CTX_SIZE="${2:-65536}"
PORT="${3:-8080}"
MODEL_DIR="${4:-$SCRIPT_DIR/../models/crucible}"

SERVER_BIN="$SCRIPT_DIR/../bin/llama.cpp/bin/llama-server"
[ -x "$SERVER_BIN" ] || { echo "llama-server not found at $SERVER_BIN. Run 01-install-llamacpp.sh first." >&2; exit 1; }

MODEL_FILE=$(find "$MODEL_DIR" -name "*00001-of-*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || MODEL_FILE=$(find "$MODEL_DIR" -name "*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || { echo "No GGUF found in $MODEL_DIR. Run 02-download-models.sh first." >&2; exit 1; }

echo -e "\033[32mModel:     $MODEL_FILE\033[0m"
echo -e "\033[33mn-cpu-moe: $CPU_MOE (raise if VRAM headroom allows, lower if you hit CUDA OOM)\033[0m"

exec "$SERVER_BIN" \
    --model "$MODEL_FILE" \
    --host 127.0.0.1 --port "$PORT" \
    -ngl 99 --n-cpu-moe "$CPU_MOE" \
    --ctx-size "$CTX_SIZE" \
    --flash-attn on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    --jinja \
    --temp 1.0 --top-p 0.95 --min-p 0.01 --top-k 40 \
    --threads 16 \
    --mlock
