#!/usr/bin/env bash
#
# Launches llama-server with the "reasoning" SECONDARY preset: gpt-oss-120b (native
# MXFP4). The strongest raw one-shot coder/reasoner that fits this box — NOT the
# agentic default.
#
# WHY IT'S A SECONDARY, NOT THE DEFAULT: its tool-calling depends on OpenAI's
# "Harmony" channel format and is documented-flaky outside its native harness —
# open OpenCode issue (#7185): it emits reasoning but never actually calls tools.
# For day-to-day agentic work in OpenCode, the Qwen3-Coder-Next presets are more
# reliable. Reach for this one for hard one-shot problems / reasoning-heavy tasks.
#
# Requires a RECENT llama.cpp build (b8967+, native Blackwell MXFP4 MMQ) and DDR5
# EXPO/XMP in BIOS (RAM-bandwidth-bound generation).
#
# Usage: ./run-reasoning.sh [cpu_moe] [reasoning_effort] [ctx_size] [port] [model_dir]
#   Defaults: cpu_moe=20 reasoning_effort=high ctx_size=131072 port=8080

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPU_MOE="${1:-20}"
REASONING_EFFORT="${2:-high}"
CTX_SIZE="${3:-131072}"
PORT="${4:-8080}"
MODEL_DIR="${5:-$SCRIPT_DIR/../models/reasoning}"

case "$REASONING_EFFORT" in low|medium|high) ;; *) echo "reasoning_effort must be low|medium|high" >&2; exit 1 ;; esac

SERVER_BIN="$SCRIPT_DIR/../bin/llama.cpp/bin/llama-server"
[ -x "$SERVER_BIN" ] || { echo "llama-server not found at $SERVER_BIN. Run 01-install-llamacpp.sh first." >&2; exit 1; }

MODEL_FILE=$(find "$MODEL_DIR" -name "*00001-of-*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || MODEL_FILE=$(find "$MODEL_DIR" -name "*.gguf" 2>/dev/null | head -n1)
[ -n "$MODEL_FILE" ] || { echo "No GGUF found in $MODEL_DIR. Run 02-download-models.sh reasoning first." >&2; exit 1; }

echo -e "\033[32mModel:     $MODEL_FILE\033[0m"
echo -e "\033[33mReasoning: $REASONING_EFFORT\033[0m"
echo -e "\033[35mNOTE:      Secondary preset. Tool-calling in OpenCode can be flaky (Harmony format, OpenCode #7185).\033[0m"
echo -e "\033[35mREMINDER:  Use a recent llama.cpp build (b8967+) and DDR5 EXPO/XMP in BIOS.\033[0m"

# gpt-oss carries its own chat template / tool parser; --jinja applies it. Sampling per model card (temp 1.0).
exec "$SERVER_BIN" \
    --model "$MODEL_FILE" \
    --host 127.0.0.1 --port "$PORT" \
    -ngl 99 --n-cpu-moe "$CPU_MOE" \
    --ctx-size "$CTX_SIZE" \
    --flash-attn on \
    --jinja \
    --chat-template-kwargs "{\"reasoning_effort\":\"$REASONING_EFFORT\"}" \
    --temp 1.0 --top-p 1.0 --top-k 0 \
    --threads 16 \
    --mlock
