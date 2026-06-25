# Brand assets

Real, version-controlled SVG sources for Crucible OS's logo and Calamares
welcome banner — a crucible-vessel motif (molten glow, twin handles, rising
sparks) on a dark badge, matching the website's dark palette.

- `src/logo.svg` — circular badge, used as both Calamares' `productLogo`
  and `productIcon`
- `src/welcome.svg` — wide banner with wordmark + the 5 mode color chips,
  used as Calamares' `productWelcome`

## Building

```bash
./build.sh
```

Rasterizes both SVGs to PNG and copies them into
`iso/calamares/branding/crucibleos/` (the paths `branding.desc` expects),
plus a square `favicon.png` for the website (`docs/favicon.png`,
`docs/logo.png` — copied in manually, not by this script, since wiring them
into `docs/index.html` is a website-content decision).

Built/verified on macOS using `qlmanage -t` (QuickLook's bundled thumbnail
generator) as the SVG rasterizer, since no CLI SVG tool (`rsvg-convert`,
Inkscape, `cairosvg`) is installed here. `qlmanage` always pads non-square
input to a square canvas — `build.sh` detects and crops that letterboxing
back out automatically based on each SVG's actual aspect ratio, rather than
hand-coded crop offsets that would silently break if a source SVG's
proportions ever change. Verified output dimensions: `logo.png` 512×512,
`welcome.png` 1024×460, `favicon.png` 256×256 — all confirmed via Pillow
after a real run, not just asserted.

**On a real Linux box**, swap to `rsvg-convert -w W -h H src/X.svg -o
out/X.png` instead — it's the standard tool there, doesn't need the
letterbox-crop workaround, and should be considered the long-term path once
this repo is actually built/maintained from Linux rather than this Mac.

## Status

Built and visually reviewed (rendered + read back as images during
this work) — not yet seen rendered inside an actual Calamares run, which
needs the real installer test pass tracked in `iso/calamares/README.md`.
