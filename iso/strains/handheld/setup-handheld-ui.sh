#!/usr/bin/env bash
#
# Real handheld-strain UI differentiation, per TODO.md: "touch/gamepad
# tuning (on-screen keyboard, UI scale, Big Picture autostart)" instead of
# being identical to workstation. Same pattern as modes/normal/setup/ --
# this is runtime/session config, not a package-list difference, so it
# lives here rather than in handheld.list.chroot.
#
# Uses only well-documented, stable GNOME schemas:
#   org.gnome.desktop.a11y.applications screen-keyboard-enabled  -- GNOME's
#     built-in on-screen keyboard toggle (Settings > Accessibility > Typing
#     > Screen Keyboard); no extra package needed, it ships with gnome-shell.
#   org.gnome.desktop.interface text-scaling-factor  -- the stable,
#     well-documented readability lever for small/touch screens. Does NOT
#     touch integer HiDPI `scaling-factor` or Mutter's experimental
#     fractional-scaling feature -- those are display-specific and better
#     left to the user/hardware-detection than guessed here.
#
# Big Picture autostart is gated on Steam actually being installed (Gaming
# mode setup is separate/optional) -- skips cleanly with a message instead
# of failing if it isn't.
#
# Run as the desktop user in their session, not via sudo (same constraint
# every gsettings-based script in this repo has).

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not root/sudo." >&2
    exit 1
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    echo "No DBUS_SESSION_BUS_ADDRESS — run this inside a real logged-in graphical session." >&2
    exit 1
fi

TEXT_SCALE="${1:-1.25}"

echo -e "\033[36mEnabling on-screen keyboard...\033[0m"
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true

echo -e "\033[36mScaling UI text for a small/touch screen (factor: $TEXT_SCALE)...\033[0m"
gsettings set org.gnome.desktop.interface text-scaling-factor "$TEXT_SCALE"

AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/refract-steam-bigpicture.desktop"
if command -v steam >/dev/null 2>&1; then
    echo -e "\033[36mEnabling Steam Big Picture autostart...\033[0m"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Name=Steam Big Picture
Exec=steam -bigpicture
X-GNOME-Autostart-enabled=true
EOF
else
    echo "Steam not installed -- skipping Big Picture autostart." >&2
    echo "Run modes/gaming/setup/01-install-steam.sh first, then re-run this script," >&2
    echo "or create $AUTOSTART_FILE manually afterward." >&2
fi

echo -e "\033[32mDone.\033[0m"
