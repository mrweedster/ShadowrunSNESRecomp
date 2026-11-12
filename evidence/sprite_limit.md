# Sprite-limit lift: what exists, what it costs, what Shadowrun actually hits

Date: 2026-11-05. Investigates the §5 roadmap claim "rendering caps are
easy to lift" (`NoSpriteLimits`).

## 1. The mechanism (framework, already shipped)

- Config key `NoSpriteLimits` (`runner/src/desktop/mmx_config.c:568`) →
  `g_config.no_sprite_limits` → `kPpuRenderFlags_NoSpriteLimits`
  (`host_main.c:3716` at startup, `:712-715` re-synced every `BeginDrawing`).
- Enforcement lives in the SINGLE shared `ppu_evaluateSprites()`
  (`runner/src/snes/ppu.c:2862`), used by both the reference and span
  rasterizers, and models both real S-PPU per-scanline limits:
  >32 sprites found → `rangeOver` (stop scanning), >34 8x8 OBJ tiles →
  `timeOver` (stop drawing tiles for that line). The flag skips both.
- Compiled default (no config key): `g_config` is a static global → false →
  limits ENFORCED. The auto-generated `config.ini` template
  (`DefaultConfigIni`, `host_main.c:5114`) however ships **`NoSpriteLimits = 1`**,
  so every port that has run once with a generated config — including this
  bundle — has been running with the caps LIFTED. (Confirmed: bundle root,
  `tests/out/`, and `tests/out/a2/` config.inis all carry `= 1`.)

## 2. A/B measurement (same binary, only the flag differs)

Scratch pairs `tests/out/spr0/` and `tests/out/spr1/` (bundle binary copy +
own `config.ini` with `NoSpriteLimits = 0/1` + `libs` symlink). Wiring
control: flipping `NewRenderer = 0` in that config visibly changes the
`config parsed:` breadcrumb, so the exe-dir ini genuinely loads.

- **State parity:** `PORT_BIN=.../spr0/ShadowrunL0
  PORT_BIN2=.../spr1/ShadowrunL1 ./tests/parity.sh` → **identical over 1200
  frames**. The flag is purely a render decision; zero emulator-state effect
  (SNES has no sprite overflow interrupt; `rangeOver`/`timeOver` never feed
  back to the CPU bus).
- **Presentation:** full-frame BMP capture, per-frame `cmp`:
  - selfcheck combat route: **276/276 identical**
  - menu route (title→intro→dialogue): **1245/1245 identical**
  → across 2,721 captured frames, Shadowrun **never exceeds 32 sprites or
  34 tiles on any scanline** in these scenes; the limit never fires, so the
  flag changes nothing visible.

Reproduce:
```
cd tests/out && mkdir -p spr0/shots && cd spr0
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
SNESRECOMP_FRAME_BMP_DIR=$PWD/shots SNESRECOMP_FRAME_BMP_START=1 \
SNESRECOMP_FRAME_BMP_END=276 SNESRECOMP_FRAME_BMP_STEP=1 \
./ShadowrunL0 --no-launcher --script ../../../tests/scripts/selfcheck.txt
```
(binary names: `ShadowrunL0`/`ShadowrunL1` in `tests/out/spr0|spr1`.)

## 3. Conclusions

1. The cap lift is genuinely free **as of today**: no cost, no state change —
   but equally no benefit: current routes never hit the hardware limit.
   Shadowrun's engine stays within 32-sprite/34-tile lines in boot, title,
   intro, dialogue and combat scenes covered by existing scripts.
2. It is therefore NOT implicated in any parity or presentation delta
   measured so far (all gates ran with it on, consistently, both sides).
3. Caveat: coverage is limited to scripted routes. Crowded later scenes
   (nightclub, Matrix levels, late-city streets) are unmeasured; the limit
   may fire there. Until measured, "identical to hardware" Stage 1
   presentation technically requires `NoSpriteLimits = 0` — the generated
   `config.ini` currently opts into the lift by framework default.
   Decision flagged: set the shipped/package config to `= 0`, or measure
   longer routes first. Stage 2 can flip it on deliberately.
