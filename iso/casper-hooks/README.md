# Casper live-session autostart hook

`casper-bottom/25-crucible-install-icon` drops the "Install Crucible OS"
desktop entry (`iso/build.sh`'s `install-crucible-os.desktop`) onto the live
session user's Desktop during boot, for GUI strains only. `iso/build.sh`
copies this file into `config/includes.chroot/usr/share/initramfs-tools/scripts/casper-bottom/`
at build time (it lives here, not directly under `includes.chroot/`, because
`iso/.gitignore` treats `includes.chroot/usr/` as build-generated output —
same reasoning as why `modes/`/`drivers/` are copied in rather than
duplicated there).

## Where this came from

Verified against a real, working implementation rather than guessed:
[maui-linux/calamares-casper](https://github.com/maui-linux/calamares-casper)'s
`usr/share/initramfs-tools/scripts/casper-bottom/25calamares` script, fetched
and read directly. That script is the documented mechanism several real
live-build+Calamares distros use. Casper-bottom scripts under
`/usr/share/initramfs-tools/scripts/casper-bottom/` only ever execute as
part of casper's live-boot initramfs sequence — an installed system never
runs this file at all, so there's no separate "am I running live?" runtime
check needed; the file's location in the initramfs is the check.

`../config/hooks/live/0100-update-initramfs-for-casper-hook.hook.chroot`
forces `update-initramfs -u` inside the chroot at build time. Real .deb
packages get their casper-bottom scripts embedded into the initrd
automatically via dpkg triggers when they install; this file is a plain
copy-in via `includes.chroot`, not a package, so nothing else would
necessarily trigger that rebuild. This hook makes it explicit rather than
assuming live-build's own finalization does it already — confirmed the
`config/hooks/live/*.hook.chroot` convention itself against Debian's
live-manual "customizing-contents" docs, not guessed.

## Status

Execution-tested only at the level of "does `build.sh` copy/clean this file
correctly per strain" (stubbed `lb`, ran `build.sh` across
workstation→server→lowspec, confirmed the casper-bottom file and desktop
entry both appear only for GUI strains and are cleaned up for `server`).
**Not verified against a real live boot** — needs an actual ISO built and
booted to confirm the desktop icon really appears on the live user's
Desktop and that `update-initramfs -u` actually was necessary (vs.
live-build handling it already, in which case the hook is harmless but
redundant). Tracked alongside every other "(needs Linux build host)" item
in `iso/README.md`/`TODO.md`.
