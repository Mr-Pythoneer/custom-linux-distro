#!/usr/bin/env bash
#
# Installs the WhiteSur GTK/icon/shell theme (vinceliuice/WhiteSur-*-theme —
# long-running, well-known macOS-style GNOME theme projects) into the
# invoking user's home directory (~/.themes, ~/.icons) — no sudo/system-wide
# install, which is the safer default for a per-user cosmetic theme.
#
# Must be run as the actual logged-in user, not root.

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not root/sudo — it installs into your home directory." >&2
    exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

for repo in WhiteSur-gtk-theme WhiteSur-icon-theme WhiteSur-gnome-shell-theme; do
    echo -e "\033[36mCloning vinceliuice/$repo ...\033[0m"
    git clone --depth 1 "https://github.com/vinceliuice/${repo}.git" "$WORKDIR/$repo"
done

echo -e "\033[36mInstalling GTK theme...\033[0m"
"$WORKDIR/WhiteSur-gtk-theme/install.sh" -d "$HOME/.themes"

echo -e "\033[36mInstalling icon theme...\033[0m"
"$WORKDIR/WhiteSur-icon-theme/install.sh" -d "$HOME/.icons"

if [ -x "$WORKDIR/WhiteSur-gnome-shell-theme/install.sh" ]; then
    echo -e "\033[36mInstalling shell theme...\033[0m"
    "$WORKDIR/WhiteSur-gnome-shell-theme/install.sh" -d "$HOME/.themes" || echo "NOTE: shell theme install script changed or failed — check $WORKDIR/WhiteSur-gnome-shell-theme manually." >&2
fi

echo -e "\033[32m\nThemes installed under ~/.themes and ~/.icons.\033[0m"
echo "Apply with 02-configure-dock.sh / 03-configure-topbar.sh, or via GNOME Tweaks manually."
