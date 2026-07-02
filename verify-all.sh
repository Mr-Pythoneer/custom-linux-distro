#!/usr/bin/env bash
#
# Runs every mode's verify-*.sh sanity check plus the driver and mode-switcher
# checks, in one pass, on an INSTALLED Refract OS system (after the relevant
# setup scripts have run). Unlike preflight.sh (which checks a BUILD HOST before
# building), this checks a RUNNING system's installed bundles.
#
# It does not require all modes to be installed — each section reports
# pass/fail/skip and the summary tallies them, so it's useful incrementally as
# you bring modes up. Exit non-zero only if a check that SHOULD pass (its
# tooling is present) actually failed.
#
# Usage: ./verify-all.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
c_green=$'\033[32m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'; c_cyan=$'\033[36m'; c_reset=$'\033[0m'
PASS=0 FAIL=0 SKIP=0

section() { echo; echo "${c_cyan}=== $1 ===${c_reset}"; }

# run_verify <label> <script> <gate-cmd...>
# Runs <script> only if <gate-cmd> succeeds (i.e. the mode looks installed),
# else skips. Counts the script's exit status.
run_verify() {
    local label="$1" script="$2"; shift 2
    if [ ! -x "$script" ]; then echo "${c_yellow}[SKIP]${c_reset} $label (no $script)"; SKIP=$((SKIP+1)); return; fi
    if [ "$#" -gt 0 ] && ! "$@" >/dev/null 2>&1; then
        echo "${c_yellow}[SKIP]${c_reset} $label (not installed on this system)"; SKIP=$((SKIP+1)); return
    fi
    echo "${c_cyan}-- $label --${c_reset}"
    if "$script"; then echo "${c_green}[ OK ]${c_reset} $label"; PASS=$((PASS+1))
    else echo "${c_red}[FAIL]${c_reset} $label"; FAIL=$((FAIL+1)); fi
}

section "Drivers"
run_verify "drivers (nvidia/microcode/secure-boot)" "$REPO_ROOT/drivers/verify-drivers.sh"

section "Mode switcher"
if [ -x "$REPO_ROOT/modes/modectl/distro-modectl" ]; then
    echo "${c_cyan}-- distro-modectl status --${c_reset}"
    if "$REPO_ROOT/modes/modectl/distro-modectl" status; then echo "${c_green}[ OK ]${c_reset} distro-modectl status"; PASS=$((PASS+1))
    else echo "${c_red}[FAIL]${c_reset} distro-modectl status"; FAIL=$((FAIL+1)); fi
else
    echo "${c_yellow}[SKIP]${c_reset} distro-modectl (not present)"; SKIP=$((SKIP+1))
fi

section "Gaming mode"
run_verify "gaming bundle" "$REPO_ROOT/modes/gaming/setup/verify-gaming.sh" command -v steam

section "Server mode"
run_verify "server bundle" "$REPO_ROOT/modes/server/setup/verify-server.sh" command -v sshd

section "Creative mode"
run_verify "creative bundle" "$REPO_ROOT/modes/creative/setup/verify-creative.sh" command -v flatpak

section "Summary"
echo "${c_green}$PASS passed${c_reset}, ${c_red}$FAIL failed${c_reset}, ${c_yellow}$SKIP skipped${c_reset}"
[ "$FAIL" -eq 0 ]
