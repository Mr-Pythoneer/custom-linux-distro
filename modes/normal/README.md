# Normal mode

macOS-style polished default look, per DESIGN.md §4. **One-time setup**, not a per-switch toggle — run these once after install, not every time you `distro-modectl switch normal`:

```bash
./setup/01-install-whitesur-theme.sh   # clones vinceliuice/WhiteSur-*-theme, installs to ~/.themes, ~/.icons
./setup/02-configure-dock.sh           # repositions Ubuntu's built-in dock: bottom, floating, autohide
./setup/03-apply-theme.sh [theme-name] # enables GNOME's User Themes extension, applies GTK/icon/shell theme
```

All three must run as your normal logged-in user inside a real graphical session (they need `DBUS_SESSION_BUS_ADDRESS` for `gsettings`) — not over SSH, not as root.

## What's real here, and why it's safe to trust without live testing

- **Dock repositioning** (`02-configure-dock.sh`) doesn't install anything new — stock Ubuntu already ships "Ubuntu Dock," which is a rebrand of the `dash-to-dock` GNOME extension, running under the `org.gnome.shell.extensions.dash-to-dock` schema. That schema has been stable across many GNOME releases and is dash-to-dock's own public, documented API — not an internals guess.
- **Theme installer** (`01-install-whitesur-theme.sh`) just clones and runs vinceliuice's own `install.sh` scripts for WhiteSur-gtk-theme / WhiteSur-icon-theme / WhiteSur-gnome-shell-theme — long-running, well-known community projects. The script doesn't reimplement their install logic, just invokes it.
- **Theme application** (`03-apply-theme.sh`) uses only `org.gnome.desktop.interface` (GTK/icon theme — core GNOME, not extension-dependent) and `org.gnome.shell.extensions.user-theme` (GNOME's own official "User Themes" extension, shipped in the `gnome-shell-extensions` apt package) — no third-party schema guesses.

## What's explicitly NOT attempted, and why

A literal macOS-style **global app menu** in the top bar, and a **Mission-Control-equivalent** overview redesign. GNOME has no stable built-in equivalent to either:
- The closest to a global app menu would mean picking a specific third-party extension and pinning to its exact gsettings schema/UUID — and extension APIs/availability shift often enough that committing to one blind, with no live session to check it actually renders correctly, would be exactly the kind of fabricated-confidence config this project is trying to avoid (see `modes/modectl/README.md`'s same stance).
- GNOME's existing Activities overview is the closest built-in equivalent to Mission Control and is left as-is rather than redesigned.

This is real follow-up work, but it needs someone iterating against an actual running GNOME session to pick and verify the right extension — not something to guess at from a shell with no display attached.

## Known gaps / unverified

- Theme name produced by `WhiteSur-gtk-theme/install.sh` (assumed `WhiteSur-Dark`) — confirm against `~/.themes` after running step 1, pass the actual name to step 3 if it differs.
- Nothing in this directory has been visually verified on a real GNOME desktop — same hardware/session-availability gap as everywhere else in this repo, but specifically here it's "needs a live desktop," not "needs the GPU server."
