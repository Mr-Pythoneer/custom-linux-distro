# Website download configurator — design note (DEFERRED)

Your idea, recorded so it's not lost. **Not built yet** — the focus right now is
the single 5090/9950X3D/64GB build. This is the plan for the "pick your
hardware → get a tailored build" download flow that comes later.

## The idea

On the website's download page, the user picks:
- **GPU** — every GPU ever made, including integrated graphics, plus a "no GPU"
  option.
- **CPU**, **RAM**, **SSD** (size/speed).

The download is then tailored: it **preloads a set of local AI models sized to
that hardware** (and tunes mode defaults). A 5090 box gets the big models; a
no-GPU laptop gets only tiny CPU-runnable ones.

## How this maps to what already exists

This is a new dimension layered on the existing concepts, not a rewrite:

- **Hardware strains** (`iso/strains/`) already pick the desktop environment /
  base packages per hardware *class* (workstation/laptop/lowspec/…). The
  configurator adds an **AI-model tier** dimension on top — what models to
  preload — keyed primarily on **VRAM** (the binding constraint for local LLMs).
- The model catalog (`modes/ai/config/models.catalog.json`, built now for the
  5090 tier) is the data the configurator would scale. Each model already
  carries an approximate size + VRAM need, so a tier is just "the subset that
  fits in N GB of VRAM (plus CPU-offload candidates up to system RAM)."

## Proposed model tiers (VRAM-keyed) — to flesh out later

| Tier | VRAM | Example preload set |
|---|---|---|
| `cpu-only` | none / iGPU | only the tiny ones: `llama3.2:3b`, `qwen2.5:7b` (CPU inference, slow but works) |
| `entry` | ~6–8 GB | 7–8B models: `qwen2.5-coder:7b`, `llama3.1:8b`, `dolphin-llama3:8b`; SDXL for images |
| `mid` | ~12–16 GB | + 14B (`qwen2.5:14b`), 16B MoE (`deepseek-coder-v2:16b`) |
| `high` | ~24 GB | + 32B (`qwen2.5-coder:32b`, `qwen2.5-vl:32b`), `dolphin-mixtral:8x7b`, FLUX |
| `max` (the 5090 build) | 32 GB+ | everything, incl. `llama3.3:70b` with CPU offload + FLUX.1-dev |

The picker just resolves the user's GPU → its VRAM → the tier (CPU-offload to
system RAM extends what's reachable, so RAM is a secondary input).

## Why it's deferred

- It needs a **GPU→VRAM database** ("every GPU ever made") — a real data-curation
  task (PCI IDs / model names → VRAM), best done once the single build proves the
  model stack actually works on real hardware.
- The per-tier model sets should be **validated on representative hardware**
  before being offered as a one-click download — shipping a "this fits your
  card" promise that doesn't is worse than not offering it.
- The website is currently a static GitHub Pages site; a configurator that emits
  a tailored manifest is a bigger build (it can stay static — emit a per-tier
  install manifest the post-boot setup reads — but still more than a page).

## Smallest first step when we pick this up

Don't build the full GPU database first. Start with a **manual tier selector**
(5 buttons: cpu-only/entry/mid/high/max) that each map to a model-catalog subset,
and have `modes/ai/setup/` accept a `--tier` so the preload pulls only that
subset. The "detect/select your exact GPU" UX is a polish layer on top of that.
