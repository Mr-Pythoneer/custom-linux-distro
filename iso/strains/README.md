# Hardware strains

A *strain* is a build-time hardware-class profile: what desktop environment
(if any) ships, and which packages are baked in by default. This is
deliberately separate from the 5 runtime *modes* (`modes/modectl/`) — every
strain still gets all 5 modes; a strain just decides what's a sensible
starting point for that class of machine.

| Strain | DE | Notes |
|---|---|---|
| `workstation` (default) | GNOME (`ubuntu-desktop-minimal`) | Full feature set, no special tuning |
| `laptop` | GNOME | + `tlp`/`tlp-rdw` for battery/power management |
| `lowspec` | LXQt (`lubuntu-desktop`) | Lightest official Ubuntu DE; skips gamemode/mangohud/winetricks by default (added on-demand via `modes/gaming/setup/` if actually needed) |
| `server` | none | Headless; relies on `modes/server/setup/*.sh` post-boot, same lean-image philosophy as the rest of `iso/` |
| `handheld` | GNOME | Same package set as `workstation` for now — touch/gamepad-first UI tuning is NOT built yet, this strain exists so it's selectable, not because it's differentiated |
| `cloud` | none | `cloud-init` only. **Delivery format should eventually differ too** (qcow2/raw image + cloud-init, not an installer ISO/Calamares) — not built, this is the package-selection half only |

## Usage

```bash
./build.sh workstation   # or laptop | lowspec | server | handheld | cloud
```

`build.sh` copies the selected strain's `.list.chroot` into
`config/package-lists/` (deleting any other strain's leftover file first —
verified by actually running the copy/cleanup logic with a stubbed `lb`,
see TODO.md) before calling `lb config`/`lb build`. The strain name also
shows up in the ISO's `--iso-application` string and the output filename
(`crucible-os-<strain>.iso`).

## What's real vs. what's a placeholder here

`workstation`/`laptop`/`lowspec`/`server` are real package-selection
differences. `handheld` and `cloud` are scaffolding — selectable today,
but their actual differentiation (touch/gamepad UI for handheld, a
cloud-image delivery format instead of an ISO for cloud) is unbuilt. Don't
mistake "this strain exists in the list" for "this strain is done."

## Explicitly out of scope for this repo

ARM64 (Raspberry Pi-class), Apple Silicon, RISC-V — different CPU
architecture means a different kernel config, different bootloader
(u-boot, not GRUB), often cross-compilation, and a different image format
entirely. That's not a strain of this project, it's close to a separate
distro effort. Apple Silicon specifically would mean depending on the
Asahi Linux project's out-of-tree kernel work rather than anything live-build
provides. Flagging this so it's a deliberate, visible decision, not a
silent gap — see DESIGN.md.
