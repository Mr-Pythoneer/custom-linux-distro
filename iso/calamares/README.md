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

Not yet wired into `iso/build.sh` — these configs would need to land under
`/etc/calamares/` in the image (via `includes.chroot`, same mechanism as
`modes/`/`drivers/`) and the `calamares` package added to a package list.
Not done yet because the installer is reasonably the last thing to get
right per DESIGN.md §7's suggested build order — no point polishing the
install screen before the base system + modes actually work.

## Status

Entirely unverified. Needs, in order: a real Calamares package install on
a test VM, this config copied to `/etc/calamares/`, and an actual install
run watched start to finish.
