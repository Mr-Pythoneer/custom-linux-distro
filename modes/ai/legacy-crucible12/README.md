# Legacy: Crucible12 runtime (superseded by LM Studio)

This is the **original** AI-mode runtime — the Linux/systemd port of
[Crucible12](https://github.com/Mr-Pythoneer/Crucible12): `llama-server`
(llama.cpp, CUDA) serving Qwen3-Coder-Next across the RTX 5090 + 9950X3D,
fronted by OpenCode, with the `crucible`/`max`/`fast`/`reasoning` presets.

It was **replaced as AI mode's default by LM Studio + ComfyUI on 2026-06-30**
(user's call — see DESIGN.md §5 and `modes/ai/README.md`). LM Studio is far
more turnkey for a desktop distro (one installer, a model catalog, a built-in
OpenAI server) and supports the broader model menu the user wanted.

**Nothing here is deleted** — it's preserved because it's real, working
(if unverified-on-hardware) infrastructure you may want to fall back to or
reuse. The original Crucible12 project itself is unaffected; this was only the
distro's port of it.

## What's here

- `setup/01-install-llamacpp.sh` — builds llama.cpp with CUDA (sm_120/Blackwell)
- `setup/02-download-models.sh` — pulls the Qwen3-Coder-Next / gpt-oss GGUFs
- `setup/run-{crucible,max,fast,reasoning}.sh` — the preset launchers
- `setup/benchmark.sh` — GPU-utilization check
- `systemd/crucible12@.service` — instantiated per-preset unit
- `bin/distro-ai-preset` — the old preset switcher (replaced by `distro-ai-model`)
- `config/opencode.{crucible,fast,max,reasoning}.json` — the per-preset OpenCode configs

## Using it instead of LM Studio

If you'd rather run the Crucible12 stack: follow these `setup/` scripts as the
original `modes/ai/README.md` described, install `distro-ai-preset` to
`/usr/local/bin`, and point `modes/modectl/profiles/ai.conf` back at it
(`distro-ai-preset switch <preset>`) instead of `distro-ai-model`. The thin
clients (`distro-ai-ask`/overlay/nautilus) hit `localhost:8080` either way, so
they work against `llama-server` too — just run a preset on port 8080.
