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
and `show.qml` — **none of these exist yet.** Fabricating placeholder image
files or a slideshow script with syntax I can't verify would be worse than
just saying so: these need to be created by someone with actual brand
assets (once the distro has a name/logo) and, for the slideshow, by someone
who can render and check a QML file actually displays right.

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
