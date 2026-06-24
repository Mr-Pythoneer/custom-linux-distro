#!/usr/bin/env bash
#
# Sanity-checks the Creative mode bundle.

set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo -e "\033[32m[PASS]\033[0m $desc"
        PASS=$((PASS + 1))
    else
        echo -e "\033[31m[FAIL]\033[0m $desc"
        FAIL=$((FAIL + 1))
    fi
}

check "FreeCAD installed (flatpak)" sh -c 'flatpak info org.freecad.FreeCAD || flatpak info org.freecadweb.FreeCAD'
check "Blender installed (flatpak)" flatpak info org.blender.Blender
check "Kdenlive installed (flatpak)" flatpak info org.kde.kdenlive
check "ffmpeg has NVENC" sh -c 'ffmpeg -hide_banner -encoders 2>/dev/null | grep -q nvenc'

if command -v davinci-resolve >/dev/null 2>&1 || [ -d "/opt/resolve" ]; then
    echo -e "\033[32m[PASS]\033[0m DaVinci Resolve installed"
    PASS=$((PASS + 1))
else
    echo -e "\033[33m[SKIP]\033[0m DaVinci Resolve — manual download required, see setup/04-install-davinci-resolve.sh"
fi

echo -e "\n$PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
