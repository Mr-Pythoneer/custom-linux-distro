#!/usr/bin/env bash
#
# Repositions Ubuntu's built-in dock to look macOS-style: bottom of screen,
# floating (not full-height), auto-hide, icon-only.
#
# This is NOT installing a new extension — stock Ubuntu already ships
# "Ubuntu Dock", which is a rebrand/fork of the dash-to-dock extension
# running under the org.gnome.shell.extensions.dash-to-dock gsettings
# schema. That schema has been stable across many GNOME releases, so this
# isn't a guess at undocumented internals — it's the same schema dash-to-dock
# itself documents.
#
# Must be run as the logged-in user (needs the session's D-Bus/gsettings
# context), not root.

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not root/sudo." >&2
    exit 1
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    echo "No DBUS_SESSION_BUS_ADDRESS — this needs to run inside a real logged-in graphical session, not a bare SSH/TTY shell." >&2
    exit 1
fi
if ! command -v gsettings >/dev/null 2>&1; then
    echo "gsettings not found — this script is GNOME-specific." >&2
    exit 1
fi

SCHEMA="org.gnome.shell.extensions.dash-to-dock"
if ! gsettings list-schemas | grep -q "^${SCHEMA}$"; then
    echo "Schema $SCHEMA not found — Ubuntu Dock may not be installed/enabled on this system. Skipping." >&2
    exit 1
fi

echo -e "\033[36mRepositioning the dock to bottom, floating, auto-hide...\033[0m"
gsettings set "$SCHEMA" dock-position 'BOTTOM'
gsettings set "$SCHEMA" extend-height false
gsettings set "$SCHEMA" dock-fixed false
gsettings set "$SCHEMA" autohide true
gsettings set "$SCHEMA" intellihide true
gsettings set "$SCHEMA" dash-max-icon-size 48

echo -e "\033[32mDone. Note: this changes dock POSITION/BEHAVIOR via a well-documented stable schema. It does not change dock ICON STYLING beyond size — full visual parity with macOS's dock also depends on the icon theme (see 01-install-whitesur-theme.sh) and hasn't been visually verified, since there's no live GNOME session available to check it against right now.\033[0m"
