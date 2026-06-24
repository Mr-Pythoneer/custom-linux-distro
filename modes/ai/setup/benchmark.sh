#!/usr/bin/env bash
#
# Sanity-checks a running llama-server: confirms the GPU is actually being used,
# reports generation speed. Run this AFTER starting one of the run-*.sh scripts
# in another terminal/session.
#
# Usage: ./benchmark.sh [port] [prompt]

set -euo pipefail

PORT="${1:-8080}"
PROMPT="${2:-Write a Python function that returns the nth Fibonacci number using memoization, then explain its time complexity.}"

if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "WARNING: nvidia-smi not found on PATH — GPU utilization won't be shown, but tok/s will still be measured." >&2
fi
command -v jq >/dev/null 2>&1 || { echo "jq is required (sudo apt-get install -y jq)." >&2; exit 1; }

echo -e "\033[36mSending request to http://127.0.0.1:$PORT ...\033[0m"

SAMPLES_FILE=$(mktemp)
if command -v nvidia-smi >/dev/null 2>&1; then
    (
        while true; do
            nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits >> "$SAMPLES_FILE" 2>/dev/null || true
            sleep 0.5
        done
    ) &
    POLL_PID=$!
fi

BODY=$(jq -n --arg prompt "$PROMPT" '{model:"local", messages:[{role:"user", content:$prompt}], stream:false}')

START=$(date +%s.%N)
RESPONSE=$(curl -fsSL -X POST "http://127.0.0.1:$PORT/v1/chat/completions" \
    -H "Content-Type: application/json" -d "$BODY")
END=$(date +%s.%N)

if [ -n "${POLL_PID:-}" ]; then
    kill "$POLL_PID" 2>/dev/null || true
    wait "$POLL_PID" 2>/dev/null || true
fi

COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // "n/a"')
SECONDS_ELAPSED=$(echo "$END - $START" | bc)
if [ "$COMPLETION_TOKENS" != "n/a" ]; then
    TOK_PER_SEC=$(echo "scale=1; $COMPLETION_TOKENS / $SECONDS_ELAPSED" | bc)
else
    TOK_PER_SEC="n/a"
fi

echo -e "\033[32m\n--- Result ---\033[0m"
echo "Completion tokens: $COMPLETION_TOKENS"
printf "Wall time:          %.1fs\n" "$SECONDS_ELAPSED"
echo "Tokens/sec:         $TOK_PER_SEC"

if [ -s "$SAMPLES_FILE" ]; then
    echo -e "\n--- GPU samples during generation (util%, VRAM MiB) ---"
    cat "$SAMPLES_FILE" | sed 's/^/  /'
    MAX_UTIL=$(cut -d',' -f1 "$SAMPLES_FILE" | tr -d ' ' | sort -n | tail -1)
    if [ -n "$MAX_UTIL" ] && [ "$MAX_UTIL" -lt 50 ]; then
        echo "WARNING: peak GPU utilization was only ${MAX_UTIL}% — the model may be undersized for GPU work, or -ngl/--n-cpu-moe need adjusting." >&2
    fi
fi
rm -f "$SAMPLES_FILE"

REPLY=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' | head -c 200)
echo -e "\nReply preview: ${REPLY}..."
