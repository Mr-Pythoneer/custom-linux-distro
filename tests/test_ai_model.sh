#!/usr/bin/env bash
# Tests for modes/ai/bin/distro-ai-model (LM Studio model switcher).
# Hermetic: stubs `lms` AND sets a fake HOME so it can NEVER touch a real
# LM Studio install (~/.lmstudio). Also sanity-checks the model catalog.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

AIM="$REPO_ROOT/modes/ai/bin/distro-ai-model"
CATALOG="$REPO_ROOT/modes/ai/config/models.catalog.json"

if ! command -v python3 >/dev/null 2>&1; then note "skipping (need python3)"; finish; exit $?; fi

# --- catalog integrity: every use-case model ref must exist in models ---
if python3 - "$CATALOG" <<'PY'
import json, sys
cat = json.load(open(sys.argv[1]))
models = set(cat["models"])
bad = []
for uc, d in cat["use_cases"].items():
    for k, v in d.items():
        if k in ("label", "runtime"):
            continue
        if v not in models:
            bad.append(f"{uc}.{k} -> {v}")
sys.exit(1 if bad else 0)
PY
then pass "catalog: all use-case model refs resolve"; else fail "catalog: a use-case references a missing model"; fi

# --- hermetic harness: fake HOME (no real lms) + stub lms on PATH ---
work="$(new_stubdir)"
stub "$work" lms '
case "$1 $2" in
  "daemon up") exit 0 ;;
  "server start") echo "server started"; exit 0 ;;
  "server status") echo "The server is running"; exit 0 ;;
  "server stop") echo "stopped"; exit 0 ;;
  "unload --all") exit 0 ;;
esac
case "$1" in
  load) echo "LOAD: ${*:2}"; exit 0 ;;
  ps)   echo "(no models loaded)"; exit 0 ;;
  ls)   echo "(none)"; exit 0 ;;
  *)    echo "STUB-LMS: $*"; exit 0 ;;
esac'
run_aim() { HOME="$work" PATH="$work:$PATH" "$AIM" "$@"; }

# list works without lms (reads catalog only)
out="$(HOME="$work" "$AIM" list 2>&1)"; rc=$?
assert_eq "list exits 0" "0" "$rc"
assert_contains "list shows the coding use-case" "$out" "coding"
assert_contains "list shows the image/ComfyUI tag" "$out" "ComfyUI"

# use coding -> loads the right repo with --gpu max via the stub
out="$(run_aim use coding 2>&1)"; rc=$?
assert_eq "use coding exits 0" "0" "$rc"
assert_contains "use coding loads the 32B coder repo" "$out" "lmstudio-community/Qwen2.5-Coder-32B-Instruct-GGUF"
assert_contains "use coding passes --gpu max" "$out" "--gpu max"
assert_contains "use coding sets the identifier" "$out" "--identifier qwen2.5-coder-32b"

# use day-to-day fast -> the lightweight model
out="$(run_aim use day-to-day fast 2>&1)"
assert_contains "use day-to-day fast loads llama3.2-3b" "$out" "Llama-3.2-3B-Instruct-GGUF"

# use image -> ComfyUI path, must NOT call lms load
out="$(run_aim use image 2>&1)"; rc=$?
assert_eq "use image exits 0" "0" "$rc"
assert_contains "use image routes to ComfyUI" "$out" "ComfyUI"
assert_not_contains "use image does not lms-load" "$out" "LOAD:"

# load a specific id
out="$(run_aim load qwen2.5-vl-7b 2>&1)"
assert_contains "load vision model uses its repo" "$out" "Qwen2.5-VL-7B-Instruct-GGUF"

# unknown use-case errors
run_aim use bogus </dev/null >/dev/null 2>&1; assert_eq "unknown use-case exits non-zero" "2" "$?"

# loading an image model directly is refused (it's a ComfyUI model)
run_aim load flux1-dev >/dev/null 2>&1; assert_eq "load image model via lms is refused" "1" "$?"

rm -rf "$work"
finish
