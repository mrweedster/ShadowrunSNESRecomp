# A5 cross-path WRAM trace: physics is identical, the tick label is not

Setup: `run1` = `./Shadowrun` (AOT, sha256 `ebca100c…`), `run2` =
`tests/out/ShadowrunLLE`, script `tests/scripts/combat.txt` (boot → morgue →
hallway → street + dialogue → Dark Alley → Beretta → orc combat, 25,902 host
frames both), `turbo on`, SRAM snapshot/restore (parity.sh). Full artifacts:
`tests/out/run1`, `tests/out/run2`.

## Headline

**AOT and LLE execute byte-identical game state when compared at the same
host frame; the entire cross-path WRAM difference lives in the game's tick
counter label domain.** The fixed-index crc comparison (25,779/25,902
frames differ) overstates it: the two paths' game tick counters
(`$7E1C92`, 16-bit LE in the WRAM dump) carry a piecewise-constant label
offset — 0 → +1 → +3 → +37 with three bounded steps — and every "diff" byte
is the tick counter itself or a tick-derived quantity.

## 1. Tick-label delta timeline (run1 − run2 at identical host frames)

| host frames | delta | note |
|---|---|---|
| 0–204 | 0 | identical |
| 205–416 | +1 | boot gain; **reverts** to 0 at f417 |
| 417–496 | 0 | |
| 497–1348 | +1 | second boot gain |
| 1349–1350 | +3 | +2 in two frames, title screen (during `wait` after the second `press a`) |
| 1350–22851 | **+3 constant** | morgue, both door submenu actions, hallway transition, hallway walks — 21,502 frames, no growth |
| 22852–22885 | +4→+37 | one 34-frame burst: run1's label ticks each frame while run2's label **stalls** (combat approach, content already branched post-transition) |
| 22886–25900 | +37 fixed | never grows again |

## 2. Shift-compensated WRAM probe (run1@counter c vs run2@counter c+k)

Exclusions: kernel counter window `$7E01C80–$7E01D40`, documented timer
singletons `$7E0012C/12E/12F/132`. Full table:
`tests/out/shift_combat_aot_lle.txt`.

| counter | k=0 (counter-aligned) | best k | best diff |
|---|---|---|---|
| 15640 | 0 B | — | 0 B |
| 15644–15800 | 64–101 B | **−3** | **0 B, byte-identical** |
| 16000 | 1,014 B | +3 | 217 B (street crossfade in flight; fade progress is tick-label driven) |
| 17000–21000 | ~100–320 B | −3 | ~190–320 B (content branched at the tick-gated street transition) |
| 23000+ | ~30 KB | any | ~30 KB (combat entered at different tick alignment; legitimate content divergence) |

Host-frame bookkeeping: run1@label c sits at host frame c+241; run2@label
c−3 sits at (c−3)+244 = c+241. The k=−3 matches are **same-host-frame**
matches: identical input history, byte-identical state, different label.

## 3. Why the counter-aligned diff "first appears" at c15644

The delta has been +3 since host f1350, but counter-aligned WRAM matched
(k=0) through c15642. Counter alignment is equivalent to host alignment only
while no differential-length input window overlaps: during `wait` windows
both paths advance identical per-tick state. The match breaks at c15644 —
inside `press down+right 120` (host f15859–15978), the first held-movement
window after the label step. With active input, state depends on how many
ticks the press has been held, and the two paths straddle different tick
counts of the same press. The k=−3 (host-frame-aligned) probe stays exact
through c15800+.

## 4. Gate interpretation

- Same-binary determinism (the strict gate): PASS, `identical over 25902
  frames` (fixed-index crc).
- Cross-path guest-aligned WRAM: **physics-identical through the entire
  shared-physics route** (zero bytes outside kernel/timer exclusions).
  The remaining fixed-index residue is the tick-label family — §7's
  "frame counters, constant phase offset" note refined: the offset is
  piecewise-constant (three bounded steps), never grows after f22885, and
  downstream content divergence (transition/dialogue/combat) is a
  consequence of tick-label-gated events firing at different host frames.
- Pixel checkpoints: see §6 (per-landmark md5 after the cross-path rerun).

## 5. Open mechanism

The tick gains (f205 +1, f417 −1, f497 +1, f1349 +2) and the f22852 label
stall are not yet attributed to code. Candidates: the vblank/NMI tick
increment (banks 80/81 are promoted, so AOT vs LLE can differ there) and
host frame-model interaction. Follow-up: trace build
(`-DSNESRECOMP_ENABLE_TRACE=ON`) with a range write-trace on `$7E1C92`,
which `debug_server.c`'s `s_range_trace` already supports.

## 6. Checkpoint frame-buffer md5s (cross-path) — CLOSED, superseded

The clean rerun happened 2026-11-06 with the new `tests/crosspath.sh`
(per-binary save/dump anchoring) against a dedicated LLE tree (`build-lle/`,
proven 100% interp / 0% AOT via `execution_share`). The old plan's
`SNESRECOMP_FORCE_FLOOR=1` move is dead: that knob governs HLE mods and
`snesrecomp_execution_mode()` has no caller in this build — AOT selection is
build-time. Results supersede §4/§6 here:

- Tick timeline and shift probe reproduce §1/§2 **up to host f21800**.
- 9/43 checkpoint BMPs match; the rest split into animation-phase diffs
  (J/K/L/M/P/Q, same scene) and a hard content break: the LLE leg enters
  the street transition at P3 (f21836) and is at the **title screen** from
  ~f22900 on, while the AOT leg never fires the transition and stays
  in-game. The "label stalls at f22852" behaviour is that game-mode switch.
- Full analysis: **`evidence/a6_crosspath_divergence.md`** (raw
  `tick`/`shift`/`drift`/`guest` outputs in `evidence/artifacts/`).

Note for scripted runs: backgrounding `parity.sh` directly can wedge it —
bash blocks writing its own full output pipe once the harness closes the
read end, and the script sits between legs forever. Drive it foreground
(with a long timeout) or via a joiner that holds the pipe open.
