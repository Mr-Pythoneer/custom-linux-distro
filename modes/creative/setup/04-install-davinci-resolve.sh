#!/usr/bin/env bash
#
# Installs DaVinci Resolve from Blackmagic Design's official Linux .zip.
#
# This CANNOT be fully automated: Blackmagic requires an email
# registration/login on their site before the download link is even
# generated, so there's no stable URL this script can curl. Pretending
# otherwise would just be a script that silently fails. Instead: download it
# yourself once, point this script at the .zip, and it handles extraction +
# running BMD's own installer.
#
# Usage: ./04-install-davinci-resolve.sh /path/to/DaVinci_Resolve_*_Linux.zip

set -euo pipefail

ZIP_PATH="${1:-}"

if [ -z "$ZIP_PATH" ] || [ ! -f "$ZIP_PATH" ]; then
    cat <<'EOF'
Usage: ./04-install-davinci-resolve.sh /path/to/DaVinci_Resolve_*_Linux.zip

Get the .zip first (manual step, requires a free Blackmagic Design account):
  1. https://www.blackmagicdesign.com/products/davinciresolve/
  2. Download -> Linux -> fill in the registration form -> download the .zip
  3. Re-run this script pointing at the downloaded file

This is BMD's only distribution method for Linux — there is no apt/Flatpak
package, and no stable unauthenticated download URL to automate around.
EOF
    exit 1
fi

if ! dpkg -s nvidia-driver-* >/dev/null 2>&1 && ! command -v nvidia-smi >/dev/null 2>&1; then
    echo -e "\033[33mWARNING: no Nvidia driver detected. Resolve's Linux build expects an Nvidia GPU + driver (see drivers/install-nvidia.sh) — install that first if you haven't.\033[0m"
fi

WORKDIR=$(mktemp -d)
echo -e "\033[36mExtracting $ZIP_PATH ...\033[0m"
unzip -q "$ZIP_PATH" -d "$WORKDIR"

INSTALLER=$(find "$WORKDIR" -maxdepth 1 -iname "DaVinci_Resolve*.run" | head -n1)
if [ -z "$INSTALLER" ]; then
    echo "Could not find a .run installer inside the zip — BMD may have changed their package layout. Check $WORKDIR manually." >&2
    exit 1
fi

chmod +x "$INSTALLER"
echo -e "\033[36mRunning BMD's own installer (this opens its own prompts)...\033[0m"
sudo "$INSTALLER"

rm -rf "$WORKDIR"
echo -e "\033[32mDone — BMD's installer handles its own desktop entry/menu placement.\033[0m"
