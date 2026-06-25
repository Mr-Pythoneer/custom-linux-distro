# Calamares installer config

Skeleton per DESIGN.md §6 — Calamares is the standard installer choice
(used by Mint, Manjaro, EndeavourOS, KDE Neon), not something to build from
scratch.

## Confidence level, module by module

Written from documented Calamares schema knowledge, **with zero access to
a running Calamares instance to verify against** — same constraint as
everything hardware-related in this repo, just for "needs a real installer
run" instead of "needs a GPU."

- `settings.conf` — module sequence, fairly standard/stable shape across Calamares versions, moderate-high confidence
- `modules/welcome.conf` — straightforward keys, moderate-high confidence
- `modules/users.conf` — straightforward keys, moderate-high confidence
- `modules/partition.conf` — **lowest confidence of the four.** Partitioning has the most moving parts (EFI/BIOS, encryption, swap strategy) and the most version-to-version schema drift. Treat it as a starting point to diff against Calamares' own `partition/examples/` configs in its source tree on a real build host, not as trustworthy as-is.

## What's missing, not faked

`branding/crucibleos/branding.desc` references `logo.png`, `welcome.png`,
and `show.qml` — **all three now exist.**

- `logo.png`/`welcome.png` — built from real SVG source (`branding/src/`,
  crucible-vessel motif) via `branding/build.sh`; see `branding/README.md`.
- `show.qml` — 6 slides (intro + one per mode), written against Calamares'
  own default slideshow source (`calamares/calamares`
  `src/branding/default/show.qml`) and its `src/branding/README.md`, fetched
  and read directly rather than guessed from memory. Uses `slideshowAPI: 2`
  (now set in `branding.desc`) — async load, `onActivate()`/`onLeave()`
  lifecycle functions — since Calamares' own docs flag the older
  `onCompleted`-based API 1 as headed for deprecation. No local QML
  tooling (`qmlscene`/`qmllint`) exists on this Mac to actually render it,
  so brace/paren balance was checked programmatically but **visual
  rendering is still unverified** — needs a real Calamares run to confirm
  it displays correctly, same as everything else in this directory.

## How this plugs into the ISO

Wired into `iso/build.sh`: for GUI strains (not `server`/`cloud`, which are
headless and use cloud-init/preseed instead), this directory is rsynced
into `includes.chroot/etc/calamares/`, the `calamares` package is added to
the strain's package list, and a manual-launch desktop entry
(`install-crucible-os.desktop`) is created.

**Live-session autostart**: a casper-bottom hook
(`iso/casper-hooks/casper-bottom/25-crucible-install-icon`) drops that
desktop entry onto the live user's Desktop during boot — the documented
mechanism real live-build+Calamares distros use, verified against
[maui-linux/calamares-casper](https://github.com/maui-linux/calamares-casper)'s
own casper-bottom script rather than guessed. See `iso/casper-hooks/README.md`
for the full writeup, including the `config/hooks/live/` hook that forces
`update-initramfs -u` so the dropped-in script actually lands in the live
initrd. Execution-tested at the `build.sh`-wiring level (stubbed `lb`,
confirmed the file appears/disappears correctly per strain) — **not yet
verified against a real live boot.**

## Status

Entirely unverified. Needs, in order: a real Calamares package install on
a test VM, this config copied to `/etc/calamares/`, and an actual install
run watched start to finish.
