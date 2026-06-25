#!/usr/bin/env bash
#
# Builds the ISO via debian-live's `lb` (live-build) tool.
#
# MUST run on a real Debian/Ubuntu Linux machine with live-build installed
# (`sudo apt-get install live-build`) — it uses debootstrap, chroot, and
# bind-mounts that don't exist on macOS, so there is no way to even
# syntax-check this beyond the contents of the scripts it copies in (those
# have already been checked separately with shellcheck). This script has
# NOT been run yet — see README.md status section.
#
# Usage: ./build.sh [strain]   (run from this directory: crucible-os/iso/)
#   strain is one of: workstation (default) | laptop | lowspec | server |
#   handheld | cloud — see iso/strains/*.list.chroot and iso/strains/README.md.

set -euo pipefail

STRAIN="${1:-workstation}"
VALID_STRAINS=(workstation laptop lowspec server handheld cloud)

if [ "$(uname)" != "Linux" ]; then
    echo "live-build only runs on Linux. Run this on the actual Ubuntu build host, not here." >&2
    exit 1
fi

if ! command -v lb >/dev/null 2>&1; then
    echo "live-build not installed. Run: sudo apt-get install live-build" >&2
    exit 1
fi

if [[ ! " ${VALID_STRAINS[*]} " == *" $STRAIN "* ]]; then
    echo "Unknown strain '$STRAIN'. Valid: ${VALID_STRAINS[*]}" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDES="$(dirname "${BASH_SOURCE[0]}")/config/includes.chroot"
PACKAGE_LISTS="$(dirname "${BASH_SOURCE[0]}")/config/package-lists"
STRAIN_FILE="$REPO_ROOT/iso/strains/${STRAIN}.list.chroot"

echo -e "\033[36mStrain: $STRAIN\033[0m"
[ -f "$STRAIN_FILE" ] || { echo "Strain manifest not found: $STRAIN_FILE" >&2; exit 1; }

# Only base.list.chroot (universal CLI tools) plus the ONE selected strain's
# packages go into config/package-lists/ — that directory is what live-build
# actually reads, so any other strain's packages must NOT be present here at
# build time, or every strain would get every strain's packages.
find "$PACKAGE_LISTS" -maxdepth 1 -name "strain-*.list.chroot" -delete
cp "$STRAIN_FILE" "$PACKAGE_LISTS/strain-${STRAIN}.list.chroot"

echo -e "\033[36mCopying repo scripts into the image (opt/distro/, /usr/local/bin)...\033[0m"
# Copied fresh from the repo at build time rather than committed as a
# duplicate in git — there is exactly one copy of these scripts to keep in
# sync, the one under modes/ and drivers/ at the repo root.
mkdir -p "$INCLUDES/opt/distro" "$INCLUDES/usr/local/bin"
rsync -a --delete "$REPO_ROOT/modes" "$REPO_ROOT/drivers" "$INCLUDES/opt/distro/"
# Symlinks, not copies: distro-modectl looks up profiles/ relative to its
# own location (see modes/modectl/distro-modectl's PROFILE_DIR), so it must
# stay next to that directory rather than be flattened into /usr/local/bin.
ln -sf /opt/distro/modes/modectl/distro-modectl "$INCLUDES/usr/local/bin/distro-modectl"
ln -sf /opt/distro/modes/ai/bin/distro-ai-preset "$INCLUDES/usr/local/bin/distro-ai-preset"
find "$INCLUDES/opt/distro" -type f \( -name "*.sh" -o -name "distro-*" \) -exec chmod +x {} +

echo -e "\033[36mConfiguring live-build...\033[0m"
lb config \
    --distribution noble \
    --architectures amd64 \
    --linux-flavours generic-hwe-24.04 \
    --archive-areas "main restricted universe multiverse" \
    --debian-installer none \
    --iso-application "Crucible OS ($STRAIN)" \
    --iso-volume "CRUCIBLEOS"
# --iso-volume deliberately does NOT vary by strain: ISO9660 volume labels
# have an 11-character limit and "CRUCIBLEOS-LOWSPEC" etc. would blow past
# it. --iso-application has no such constraint and is where the strain
# name actually shows up (e.g. in a VM's drive label).

echo -e "\033[36mBuilding ISO (this takes a long time and a lot of disk — run on the build host, not a laptop)...\033[0m"
lb build

OUT="live-image-amd64.hybrid.iso"
RENAMED="crucible-os-${STRAIN}.iso"
if [ -f "$OUT" ]; then
    mv "$OUT" "$RENAMED"
    echo -e "\033[32mDone — $RENAMED\033[0m"
else
    echo -e "\033[33mlb build finished but $OUT wasn't found — check the build log above.\033[0m" >&2
fi
