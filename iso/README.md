# ISO build pipeline

live-build (`lb config`/`lb build`) skeleton per DESIGN.md §6.

```bash
./build.sh [workstation|laptop|lowspec|server|handheld|cloud]   # default: workstation
# MUST run on a real Debian/Ubuntu Linux host with live-build installed
```

See `strains/README.md` for what each hardware-class strain actually
includes — strains are a build-time hardware-class profile, separate from
the 5 runtime modes (`modes/modectl/`); every strain still gets all 5 modes.

## Architecture decision: lean baked image, heavy lifting stays post-boot

The ISO's chroot only gets packages that install cleanly from stock Ubuntu
repos (`main`/`restricted`/`universe`/`multiverse`) with no extra apt
sources — see `config/package-lists/*.list.chroot`. Everything that needs
its own repo, a Flatpak, or a GitHub-release fetch (Steam, Lutris,
Wine-staging, Proton-GE, Bottles, Docker, Netdata, FreeCAD, Blender,
Kdenlive, the WhiteSur theme, Crucible12 itself) is **not** baked into the
image — it's installed by the already-built `modes/*/setup/*.sh` scripts,
which `build.sh` copies into the image at `/opt/distro/modes/` so they're
available on first boot, run on demand rather than during the ISO build.

This was a deliberate scope decision, not a shortcut: live-build has a
documented mechanism for adding extra apt repos at build time
(`config/archives/`), but I don't have a live-build host to verify the
exact current syntax against, and shipping a guessed-at config for that
mechanism would be exactly the kind of unverified-but-confident-looking
file this project is trying to avoid (same principle as the `modes/*`
READMEs' "don't fabricate dconf keys" stance). Plain package lists and
file copies (`includes.chroot`) are mechanisms I'm confident about; the
apt-archives mechanism is not, so it's deferred to whoever next has an
actual build host to test against.

## What's in here

- `build.sh` — copies `modes/` and `drivers/` from the repo root into
  `config/includes.chroot/opt/distro/` (symlinking `distro-modectl` and
  `distro-ai-preset` into `/usr/local/bin/` — as symlinks, not copies,
  since `distro-modectl` looks up its `profiles/` directory relative to
  its own location), then runs `lb config` + `lb build`.
- `config/package-lists/base.list.chroot` — universal CLI tools every
  strain needs regardless of DE/headless (curl, jq, git, build-essential,
  cmake, power-profiles-daemon, mokutil, ffmpeg, openssh-server)
- `strains/*.list.chroot` — per-strain DE choice + strain-specific packages
  (see `strains/README.md`); `build.sh` copies the selected one into
  `config/package-lists/strain-<name>.list.chroot` at build time, deleting
  any other strain's leftover copy first
- `config/includes.chroot/` — populated by `build.sh`, gitignored, not
  committed (avoids two copies of the same scripts drifting apart)

## Status

**`lb build` itself has never run — at all.** live-build doesn't run on
macOS (debootstrap, chroot, bind-mounts), so only `lb config`'s arguments
and the file-copy mechanics have had any real execution.

What HAS actually been verified (not just read and assumed): the strain
selection logic itself — `build.sh`'s copy-in/clean-up of
`config/package-lists/strain-*.list.chroot` — by stubbing out `lb` as a
no-op and running `build.sh` for real with `lowspec` then `laptop`,
confirming the prior strain's file gets removed and only the new one is
present before each (fake) `lb config` call. That's the one piece of this
directory that's been execution-tested, not just written and hoped about.

Still unverified:
- [ ] Run `./build.sh` on an actual Ubuntu host, confirm `lb config`'s flags are still valid for the live-build version installed
- [ ] Confirm the resulting ISO boots in a VM at all, for each strain
- [ ] Confirm `lubuntu-desktop`/`ubuntu-desktop-minimal` are still the correct current metapackage names on whatever Ubuntu release is actually targeted
- [ ] Confirm `/opt/distro/modes/` and the `/usr/local/bin` symlinks land correctly and `distro-modectl status` works on first boot
- [ ] Decide whether to invest in the `config/archives/` mechanism later to bake Docker/Steam/etc. in at build time instead of post-boot, once someone can verify it against a real build host
