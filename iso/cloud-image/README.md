# Cloud strain: real qcow2 image delivery

Per DESIGN.md §5b, the `cloud` strain's delivery format should eventually
be a qcow2/raw cloud image rather than an installer ISO/Calamares flow —
`build-cloud-image.sh` is that, separate from `iso/build.sh`'s
live-build/Calamares pipeline entirely (live-build isn't used for this path
at all).

## Pipeline

The standard debootstrap + loop-device + grub-install + qemu-img convert
recipe used across most "build a minimal Debian/Ubuntu cloud image by hand"
references — not invented from scratch:

1. `qemu-img create` a raw disk image
2. Attach it as a loop device, partition with `parted` (single ext4
   partition, BIOS/GRUB legacy boot — no ESP/UEFI partition, see "Known gaps" below)
3. `debootstrap --variant=minbase noble` directly onto the mounted partition
4. Bind-mount `/dev`, `/proc`, `/sys`; `chroot` in to install
   `linux-image-generic`, `grub-pc`, `cloud-init`, `cloud-guest-utils`,
   `openssh-server`, plus `iso/strains/cloud.list.chroot`'s packages
5. `grub-install` targeting the loop device, `update-grub`
6. Unmount, detach the loop device, `qemu-img convert -O qcow2 -c` to the
   final compressed qcow2

```bash
sudo ./build-cloud-image.sh [size_in_GB]   # default 4
```

## Known gaps / unverified

- **Not run end to end anywhere.** Execution-tested only at the control-flow
  level — every external tool (`debootstrap`, `parted`, `losetup`,
  `mkfs.ext4`, `mount`, `chroot`, `grub-install`, `qemu-img`, `blkid`)
  stubbed out, confirming the script's guard checks, argument sequencing,
  and cleanup trap all behave correctly start to finish. The actual
  debootstrap/partition/grub semantics are unverified — needs a real Linux
  host with root and loop-device access.
- **BIOS/GRUB legacy boot only, no UEFI/ESP partition.** Most cloud
  platforms (the eventual target here) boot BIOS-mode images fine, but this
  doesn't cover UEFI-only environments. Adding a FAT32 ESP +
  `grub-install --target=x86_64-efi` is real follow-up work, not done here
  to avoid guessing at a second boot path without a host to test either on.
- **No cloud-init seed/metadata baked in** — the image relies entirely on
  whatever cloud platform boots it to provide a NoCloud seed ISO or its own
  metadata service. Untested against either.
- Needs `debootstrap`, `parted`, `e2fsprogs`, `util-linux`, `grub-pc-bin`,
  `qemu-utils` installed on the build host — the script checks for all of
  them up front and fails clearly if any are missing, rather than failing
  midway through partitioning.

## Status

Designed and execution-tested at the control-flow level only (see above).
First real run needs a Linux host with root + loop-device access — the
same "needs Linux build host" gap as everything else in `iso/`, just for a
qcow2 image instead of an ISO.
