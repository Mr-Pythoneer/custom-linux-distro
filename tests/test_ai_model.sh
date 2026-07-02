#!/usr/bin/env bash
# Tests for modes/ai/bin/distro-ai-model (LM Studio model switcher).
# Hermetic: stubs `lms` AND sets a fake HOME so it can NEVER touch a real
# LM Studio install (~/.lmstudio). Also sanity-checks the model catalog.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

AIM="$REPO_ROOT/modes/ai/bin/distro-ai-model"
# Tiered now: the former models.catalog.json is the 'max' tier. Pin the tier so
# resolution is deterministic regardless of any ~/.config on the host.
export REFRACT_AI_TIER=max
CATALOG="$REPO_ROOT/modes/ai/config/models.catalog.max.json"

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
# XDG_CONFIG_HOME="$work" too, so a host XDG_CONFIG_HOME can't leak the real
# ~/.config/refract-ai tier/profile/vram_mib into these hermetic runs.
run_aim() { HOME="$work" XDG_CONFIG_HOME="$work" PATH="$work:$PATH" "$AIM" "$@"; }

# list works without lms (reads catalog only)
out="$(HOME="$work" XDG_CONFIG_HOME="$work" "$AIM" list 2>&1)"; rc=$?
assert_eq "list exits 0" "0" "$rc"
assert_contains "list shows the coding use-case" "$out" "coding"
assert_contains "list shows the image/ComfyUI tag" "$out" "ComfyUI"

# use coding -> loads the right repo with --gpu max via the stub
out="$(run_aim use coding 2>&1)"; rc=$?
assert_eq "use coding exits 0" "0" "$rc"
assert_contains "use coding loads the 32B coder repo" "$out" "bartowski/Qwen2.5-Coder-32B-Instruct-GGUF"
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

# --- ultra tier: VRAM-fit aware resolution + min_vram_gb warning ---
# run at ultra tier, power profile, with an injected effective VRAM.
run_ultra() { HOME="$work" XDG_CONFIG_HOME="$work" PATH="$work:$PATH" REFRACT_AI_TIER=ultra REFRACT_AI_PROFILE=power REFRACT_VRAM_MIB="$1" "$AIM" "${@:2}"; }
# same, but lets the caller pick the profile (for efficiency/balance fallback tests)
run_ultra_prof() { HOME="$work" XDG_CONFIG_HOME="$work" PATH="$work:$PATH" REFRACT_AI_TIER=ultra REFRACT_AI_PROFILE="$1" REFRACT_VRAM_MIB="$2" "$AIM" "${@:3}"; }

# 48GB: 70B (Q4, 42.5GB) fits FULLY -> loaded, no fit-warning (the ultra win over max's offload)
out="$(run_ultra 49140 use know-it-all 2>&1)"
assert_contains "ultra 48GB know-it-all loads 70B" "$out" "Llama-3.3-70B-Instruct-GGUF"
assert_not_contains "ultra 48GB 70B: no fit-warning" "$out" "WARNING"

# 96GB vision: best VL-72B (min 48) fits -> loaded
out="$(run_ultra 98280 use vision 2>&1)"
assert_contains "ultra 96GB vision loads VL-72B" "$out" "Qwen_Qwen2.5-VL-72B-Instruct-GGUF"

# 48GB vision: VL-72B (min 48) too tight for weights+mmproj+KV -> auto-fall back to VL-32B (review fix #2)
out="$(run_ultra 49140 use vision 2>&1)"
assert_contains "ultra 48GB vision falls back to VL-32B" "$out" "Qwen2.5-VL-32B-Instruct-GGUF"

# explicit 'use vision best' still forces VL-72B on 48GB, with a fit warning
out="$(run_ultra 49140 use vision best 2>&1)"
assert_contains "ultra 48GB explicit vision best -> VL-72B" "$out" "Qwen_Qwen2.5-VL-72B-Instruct-GGUF"
assert_contains "ultra 48GB explicit VL-72B warns" "$out" "WARNING"

# explicit heavy variant is honored even when it doesn't fit -> loads it + warns
out="$(run_ultra 49140 use know-it-all xl 2>&1)"
assert_contains "ultra explicit xl loads Mistral-Large" "$out" "Mistral-Large-Instruct-2411-GGUF"
assert_contains "ultra 48GB Mistral-Large warns (wants 80GB)" "$out" "WARNING"

# 96GB: heavy gpt-oss-120b (min 72) fits -> loads, no warning
out="$(run_ultra 98280 use day-to-day heavy 2>&1)"
assert_contains "ultra 96GB heavy loads gpt-oss-120b" "$out" "gpt-oss-120b-GGUF"
assert_not_contains "ultra 96GB gpt-oss-120b: no fit-warning" "$out" "WARNING"

# BACK-COMPAT: unknown VRAM (0) at ultra -> no fit-filtering, best per profile loads, no warning
out="$(run_ultra 0 use know-it-all 2>&1)"
assert_contains "ultra unknown-VRAM know-it-all loads best (70B)" "$out" "Llama-3.3-70B-Instruct-GGUF"
assert_not_contains "ultra unknown-VRAM: no fit-warning" "$out" "WARNING"

# efficiency profile at 40GB: know-it-all fast=qwen2.5-7b (no min) is picked over the 70B
out="$(run_ultra_prof efficiency 40960 use know-it-all 2>&1)"
assert_contains "ultra efficiency 40GB know-it-all -> fast 7B" "$out" "Qwen2.5-7B-Instruct-GGUF"

# balance profile at 40GB: know-it-all balanced=qwen2.5-32b fits (best 70B does not)
out="$(run_ultra_prof balance 40960 use know-it-all 2>&1)"
assert_contains "ultra balance 40GB know-it-all -> balanced 32B" "$out" "Qwen2.5-32B-Instruct-GGUF"

# ultra catalog integrity
if python3 - "$REPO_ROOT/modes/ai/config/models.catalog.ultra.json" <<'PY'
import json, sys
cat = json.load(open(sys.argv[1])); models = set(cat["models"]); bad = []
for uc, d in cat["use_cases"].items():
    for k, v in d.items():
        if k in ("label", "runtime"): continue
        if v not in models: bad.append(f"{uc}.{k}->{v}")
sys.exit(1 if bad else 0)
PY
then pass "ultra catalog: all use-case refs resolve"; else fail "ultra catalog: a use-case references a missing model"; fi

rm -rf "$work"
finish
