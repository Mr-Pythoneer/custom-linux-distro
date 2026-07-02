# Contributing to Refract OS

Refract OS is structured so others can contribute, even though it started
solo. This file codifies the working norms the codebase already follows — the
short version is: **verify, don't fabricate, and say what's unverified.**

## The core principle: honesty over confident-looking output

Most of this repo is built ahead of the hardware that can run it (see
`docs/first-hardware-runbook.md`). That makes it dangerously easy to ship
plausible-but-wrong code. The rule the whole codebase follows:

- **Verify external facts** (package names, Flatpak IDs, release-asset names,
  config schemas, command flags) against primary sources before relying on
  them. The README/commit history is full of cases where a "best guess" was
  wrong (`nvidia-driver-550` for a 5090, `df -lP --output`, a 404 theme repo).
- **Flag what you couldn't verify.** If something needs a GPU, a live desktop,
  or a build host to confirm, say so in a comment and in the relevant README's
  status section — don't present it as done. Grep the repo for "best-effort",
  "unverified", and "(needs hardware)" to see the existing pattern.
- **Don't fabricate** schema keys, dconf paths, winetricks verbs, or commit
  SHAs. A documented gap is better than a confident fiction.

## Before you push

```bash
shellcheck -S warning <changed-scripts>     # CI gate (.github/workflows/shellcheck.yml)
bash -n <changed-scripts>                    # syntax
./tests/run.sh                               # the execution suite (.github/workflows/tests.yml)
./preflight.sh                               # if you touched the build/external-dep surface
```

- All shell scripts use `#!/usr/bin/env bash` (or `#!/bin/sh` for the casper
  hooks) — that shebang is how CI discovers them.
- Scripts that take external/user input or run privileged should be
  **execution-tested against stubs**, not just linted. Add a `tests/test_*.sh`
  for any new pure-logic script (see `tests/README.md`); the suite runs on a
  real Ubuntu runner, which catches GNU-vs-BSD-coreutils issues a macOS dev box
  can't.
- `set -euo pipefail` is the default. Remember `set -e` does **not** trigger on
  a non-last command in an `&&` chain — that bug class has bitten this repo
  repeatedly; prefer sequential statements or explicit `if` checks.

## Concepts to get right

- **Modes vs. strains are orthogonal.** Modes (`modes/modectl/`) are a runtime
  switch on one install; every install gets all 5. Strains (`iso/strains/`) are
  a build-time DE/package profile. A mode's tooling must never be baked into a
  strain (see `iso/README.md`'s `config/archives/` decision).
- **Lean baked image.** Only stock-repo apt packages go in the ISO; anything
  needing a third-party repo/Flatpak/GitHub-release installs post-boot via a
  `modes/*/setup/*.sh` script.
- **Scope is bounded to x86_64** (Tier 1 in `DESIGN.md` §5b). ARM/Apple
  Silicon/RISC-V are deliberately out of scope, not an oversight.

## Adding a Gaming compat-db entry

`modes/gaming/compat-db/apps.json` is validated in CI
(`tests/validate-compat-db.py`). Each entry needs `id`, `name`, `category`,
`status` (`workaround` | `broken` | `native-alternative-recommended`):

- `workaround` → a `winetricks_verbs` **list** of real, current verbs (no
  fabricated verbs — cite a WineHQ AppDB / winetricks / Lutris source in `notes`).
- `broken` → be honest; explain why and point at an alternative.
- `native-alternative-recommended` → a `native_alternative` object with at
  least one of `apt_package` / `flatpak_id`.

Run `python3 tests/validate-compat-db.py` before pushing.

## Commits

Small, focused commits with a clear subject and a body explaining the *why*
(and any verification done). Group related fixes; don't mix a security fix with
a docs reflow. The history is meant to be readable as a record of what was
verified and how.

## What needs hardware (so don't claim to have tested it)

GPU work (driver/NVENC/AI inference), real game launches, live-desktop
theme/extension rendering, and the first real `lb build`/install all need
hardware or a build host. Those checklists live in
`docs/first-hardware-runbook.md` and `docs/blackwell-readiness.md` — add to
them rather than silently marking hardware-gated work "done."
