#!/usr/bin/env bash
#
# Launches llama-server with the "max" preset: Qwen3-Coder-Next at UD-Q6_K_XL —
# the most powerful config that's still a fast, reliable agentic coder on this box.
#
# Same model as "crucible" but near-lossless Q6 instead of Q4 (~10-25% speed cost,
# identical tool-calling reliability). Q6 weights are ~23GB larger, so MORE leading
# MoE layers must be offloaded to system RAM: CPU_MOE defaults to 26 here vs 16.
#
# *** REQUIRES DDR5 EXPO/XMP ENABLED IN BIOS. *** Generation is RAM-bandwidth-bound;
# without EXPO, throughput can collapse ~3x.
#
# Usage: ./run-max.sh [cpu_moe] [ctx_size] [port] [model_dir]
#   Defaults: cpu_moe=26 ctx_size=131072 port=8080

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPU_MOE="${1:-26}"
CTX_SIZE="${2:-131072}"
PORT="${3:-8080}"
MODEL_DIR="${4:-$SCRIPT_DIR/../models/max}"

SERVER_BIN="$SCRIPT_DIR/../bin/llama.cpp/bin/llama-server"
[ -x "$SERVER_BIN" ] || { echo "llama-server not found at $SERVER_BIN. Run 01-install-llamacpp.sh first." >&2; exit 1; }

MODEL_FILE=$(find "$MODEL_DIR" -name "*00001-of-*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || MODEL_FILE=$(find "$MODEL_DIR" -name "*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || { echo "No GGUF found in $MODEL_DIR. Run 02-download-models.sh max first." >&2; exit 1; }

echo -e "\033[32mModel:     $MODEL_FILE\033[0m"
echo -e "\033[33mn-cpu-moe: $CPU_MOE (Q6 needs MORE offload than Q4 — lower until VRAM ~30GB, raise on CUDA OOM)\033[0m"
echo -e "\033[35mREMINDER:  DDR5 EXPO/XMP must be ON in BIOS or generation speed drops ~3x.\033[0m"

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
