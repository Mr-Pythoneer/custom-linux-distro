#!/usr/bin/env bash
# Tests for modes/ai/bin/distro-ai-detect-tier (hardware -> AI tier/profile/image)
# and the --from-config path of setup/04-download-image-models.sh.
#
# Fully hermetic: every hardware input is injected via env (CRUCIBLE_VRAM_MIB,
# CRUCIBLE_IS_LAPTOP, CRUCIBLE_RAM_MB) and the GPU probes are neutralised
# (NVIDIA_SMI -> nonexistent, SYS_DRM_ROOT -> empty dir). Config is written into
# a throwaway XDG_CONFIG_HOME, so a real GPU / ~/.config is never touched.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DET="$REPO_ROOT/modes/ai/bin/distro-ai-detect-tier"
DL="$REPO_ROOT/modes/ai/setup/04-download-image-models.sh"

if ! command -v python3 >/dev/null 2>&1; then note "skipping (need python3)"; finish; exit $?; fi

empty="$(new_stubdir)"   # empty SYS_DRM_ROOT (no card*/mem_info_vram_total)

# run detect-tier with neutralised probes; caller sets CRUCIBLE_* + XDG_CONFIG_HOME.
det() { NVIDIA_SMI=/nonexistent-smi SYS_DRM_ROOT="$empty" "$DET" "$@"; }

# --- VRAM -> tier mapping (write to a fresh config dir, read back the tier) ---
check_tier() {  # desc  vram_mib  expected_tier
  local cfg; cfg="$(new_stubdir)"
  XDG_CONFIG_HOME="$cfg" CRUCIBLE_VRAM_MIB="$2" CRUCIBLE_IS_LAPTOP=0 CRUCIBLE_RAM_MB=32768 \
    det --yes >/dev/null 2>&1
  assert_eq "$1" "$3" "$(cat "$cfg/crucible-ai/tier" 2>/dev/null || echo MISSING)"
  rm -rf "$cfg"
}
check_tier "vram 0 -> cpu"          0      cpu
check_tier "vram 4095 -> cpu"       4095   cpu
check_tier "vram 5120 (8GB-ish) -> entry" 5120  entry
check_tier "vram 8192 -> entry"     8192   entry
check_tier "vram 11263 -> entry"    11263  entry
check_tier "vram 11264 -> mid"      11264  mid
check_tier "vram 16384 -> mid"      16384  mid
check_tier "vram 20479 -> mid"      20479  mid
check_tier "vram 20480 (24GB) -> high" 20480 high
check_tier "vram 24564 (RTX4090) -> high" 24564 high
check_tier "vram 30719 -> high"     30719  high
check_tier "vram 30720 -> max"      30720  max
check_tier "vram 32607 (RTX5090) -> max" 32607 max

# --- profile: desktop -> power, laptop -> balance, forced overrides ---
check_profile() {  # desc  is_laptop  expected_profile  [extra det args...]
  local desc="$1" lap="$2" exp="$3"; shift 3
  local cfg; cfg="$(new_stubdir)"
  XDG_CONFIG_HOME="$cfg" CRUCIBLE_VRAM_MIB=24564 CRUCIBLE_IS_LAPTOP="$lap" CRUCIBLE_RAM_MB=32768 \
    det --yes "$@" >/dev/null 2>&1
  assert_eq "$desc" "$exp" "$(cat "$cfg/crucible-ai/profile" 2>/dev/null || echo MISSING)"
  rm -rf "$cfg"
}
check_profile "desktop defaults to power"        0 power
check_profile "laptop defaults to balance"       1 balance
check_profile "laptop --profile efficiency"      1 efficiency --profile efficiency
check_profile "laptop --profile power"           1 power      --profile power
check_profile "desktop --profile balance forced" 0 balance    --profile balance

# --- image default per tier (best -> download token) ---
check_image() {  # desc  vram_mib  expected_image  [extra det args...]
  local desc="$1" vram="$2" exp="$3"; shift 3
  local cfg; cfg="$(new_stubdir)"
  XDG_CONFIG_HOME="$cfg" CRUCIBLE_VRAM_MIB="$vram" CRUCIBLE_IS_LAPTOP=0 CRUCIBLE_RAM_MB=32768 \
    det --yes "$@" >/dev/null 2>&1
  assert_eq "$desc" "$exp" "$(cat "$cfg/crucible-ai/image" 2>/dev/null || echo MISSING)"
  rm -rf "$cfg"
}
check_image "cpu tier -> image none"        0      none
check_image "entry tier -> sdxl"            8192   sdxl
check_image "mid tier -> sdxl (best)"       12288  sdxl
check_image "high tier -> flux-dev (best)"  24564  flux-dev
check_image "max tier -> flux-dev (best)"   32607  flux-dev
check_image "force --image sdxl on max"     32607  sdxl --image sdxl

# --- forced --tier overrides detected VRAM ---
cfg="$(new_stubdir)"
XDG_CONFIG_HOME="$cfg" CRUCIBLE_VRAM_MIB=0 CRUCIBLE_IS_LAPTOP=0 CRUCIBLE_RAM_MB=32768 \
  det --yes --tier high >/dev/null 2>&1
assert_eq "--tier high overrides 0 VRAM" "high" "$(cat "$cfg/crucible-ai/tier" 2>/dev/null || echo MISSING)"
rm -rf "$cfg"

# --- invalid --tier is rejected ---
XDG_CONFIG_HOME="$(new_stubdir)" CRUCIBLE_VRAM_MIB=0 CRUCIBLE_IS_LAPTOP=0 CRUCIBLE_RAM_MB=32768 \
  det --yes --tier bogus >/dev/null 2>&1
assert_eq "invalid --tier exits non-zero" "1" "$?"

# --- --print writes nothing ---
cfg="$(new_stubdir)"
out="$(XDG_CONFIG_HOME="$cfg" CRUCIBLE_VRAM_MIB=32607 CRUCIBLE_IS_LAPTOP=0 CRUCIBLE_RAM_MB=32768 det --print 2>&1)"
assert_eq "--print exits 0" "0" "$?"
assert_contains "--print reports the tier" "$out" "max"
if [ -f "$cfg/crucible-ai/tier" ]; then fail "--print must not write config"; else pass "--print writes no config"; fi
rm -rf "$cfg"

# --- low-RAM warning ---
out="$(XDG_CONFIG_HOME="$(new_stubdir)" CRUCIBLE_VRAM_MIB=0 CRUCIBLE_IS_LAPTOP=0 CRUCIBLE_RAM_MB=2048 det --print 2>&1)"
assert_contains "warns on <4GB RAM" "$out" "WARNING"

# --- 04-download-image-models.sh --from-config honours image=none (no downloads) ---
cfg="$(new_stubdir)"; mkdir -p "$cfg/crucible-ai"; printf 'none\n' > "$cfg/crucible-ai/image"
home="$(new_stubdir)"   # no ComfyUI here; image=none must exit before that check
out="$(XDG_CONFIG_HOME="$cfg" HOME="$home" "$DL" --from-config 2>&1)"; rc=$?
assert_eq "04 --from-config none exits 0" "0" "$rc"
assert_contains "04 --from-config none downloads nothing" "$out" "Nothing to download"
rm -rf "$cfg" "$home"

# --- 04 --from-config flux-dev parses the choice (then fails: no ComfyUI here) ---
cfg="$(new_stubdir)"; mkdir -p "$cfg/crucible-ai"; printf 'flux-dev\n' > "$cfg/crucible-ai/image"
home="$(new_stubdir)"
out="$(XDG_CONFIG_HOME="$cfg" HOME="$home" "$DL" --from-config 2>&1)"; rc=$?
assert_contains "04 reads image=flux-dev from config" "$out" "image=flux-dev"
assert_eq "04 fails cleanly when ComfyUI is absent" "1" "$rc"
rm -rf "$cfg" "$home"

rm -rf "$empty"
finish
