# Drivers

Nvidia GPU + AMD CPU driver bundling, per DESIGN.md §3.

```bash
./install-nvidia.sh              # ubuntu-drivers recommended package
./install-nvidia.sh 580          # or pin a version -> installs nvidia-driver-580-open
./install-amd-microcode.sh
sudo reboot
./verify-drivers.sh
```

## RTX 50-series / Blackwell (e.g. RTX 5090) — read this first

Two hard requirements, verified against Nvidia's docs/forums (mid-2026):

- **Use the OPEN kernel module.** Blackwell is not supported by the closed
  proprietary module at all — `nvidia-smi` reports "No devices were found".
  `install-nvidia.sh` defaults to the `-open` packages for exactly this
  reason (the open module also supports Turing/RTX-20 and newer, so it's the
  right default for this project's target hardware).
- **Driver branch ≥ 570.** The 550 branch and older do not recognize the
  5090. Stock Ubuntu 24.04 may not carry a new enough `-open` driver; if
  `nvidia-smi` shows nothing after reboot, add the graphics-drivers PPA and
  install an explicit recent one:
  ```bash
  sudo add-apt-repository -y ppa:graphics-drivers/ppa
  sudo apt-get update
  ./install-nvidia.sh 580
  ```

CUDA (for AI mode's llama.cpp build) needs **12.8+** for Blackwell's sm_120 —
12.8 is the first toolkit with sm_120 support. CUDA 13.x (current in 2026)
also works; see `modes/ai/legacy-crucible12/setup/01-install-llamacpp.sh` and the
Blackwell-readiness notes in `docs/blackwell-readiness.md`.

## Secure Boot

`install-nvidia.sh` detects Secure Boot state and, if enabled, prints the MOK
enrollment steps instead of doing them silently — enrolling a MOK or
disabling Secure Boot are both meaningful security-posture changes that
should be the user's explicit action, not something a script does for them
without them watching it happen.

## Status

Not yet run on real hardware (see `modes/ai/README.md` for the hardware
timeline — same constraint applies here). Logic is straightforward apt/MOK
flows with no novel risk, but unverified is unverified:

- [ ] `install-nvidia.sh` against a real Nvidia GPU, both Secure-Boot-on and
      Secure-Boot-off paths (and confirm `nvidia-driver-<v>-open` + `nvidia-smi`
      actually bring up the 5090 — the open-module/570+ requirement above is
      web-verified but not yet hardware-confirmed)
- [ ] `install-amd-microcode.sh` microcode-loaded detection across a reboot
- [ ] `verify-drivers.sh` pass/fail output matches reality
