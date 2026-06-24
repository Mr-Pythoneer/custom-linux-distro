#!/usr/bin/env bash
#
# Launches llama-server with the "fast" preset: Qwen3-Coder-30B-A3B-Instruct,
# fully resident on the RTX 5090's 32GB VRAM. No CPU/RAM offload — lower latency,
# leaves system RAM and CPU free (e.g. for gaming alongside it).
#
# Usage: ./run-fast.sh [ctx_size] [port] [model_dir]
#   Defaults: ctx_size=131072 port=8080

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CTX_SIZE="${1:-131072}"
PORT="${2:-8080}"
MODEL_DIR="${3:-$SCRIPT_DIR/../models/fast}"

SERVER_BIN="$SCRIPT_DIR/../bin/llama.cpp/bin/llama-server"
[ -x "$SERVER_BIN" ] || { echo "llama-server not found at $SERVER_BIN. Run 01-install-llamacpp.sh first." >&2; exit 1; }

MODEL_FILE=$(find "$MODEL_DIR" -name "*00001-of-*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || MODEL_FILE=$(find "$MODEL_DIR" -name "*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || { echo "No GGUF found in $MODEL_DIR. Run 02-download-models.sh first." >&2; exit 1; }

echo -e "\033[32mModel: $MODEL_FILE\033[0m"

exec "$SERVER_BIN" \
    --model "$MODEL_FILE" \
    --host 127.0.0.1 --port "$PORT" \
    -ngl 99 \
    --ctx-size "$CTX_SIZE" \
    --flash-attn on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    --jinja \
    --temp 0.7 --top-p 0.8 --top-k 20 --repeat-penalty 1.05 \
    --threads 16
