# A7 — The split has an address and a date: f16122, not the street gate

Follows a6 §5's open question ("why run1 never fired the transition"). The
state bisection a6 called for is built and run (`tests/gate_state.py`), and
the answer it gave was not the expected one: **at the street gate the two code
paths agree perfectly**. The real physical split is 5,700 frames earlier and
reproduces in a 5-minute route.

## 1. Instruments added

- `tests/gate_state.py` — machine-state bisection. Runs the frozen route on a
  leg, parks the main thread with the debug server (`run_to_frame`), saves the
  full L3 state (`save_state`, 305,603 B), then replays every state on every
  code path (`load_state` + idle window `scripts/gate_replay.txt`, 1,430
  frames). Dump dirs `tests/out/gs_<leg>`, `gr_<state>__<leg>`, states in
  `tests/out/states/`.
- `tests/l3sn_diff.py` — L3 snapshot diff by section (head/cpu/apu+dma/ppu/
  cart.wram/cart.vram+tail), layout pinned from `snes_saveload` order.
- `framedump_diff.py scene` mode, `tests/bisect_aot.sh` +
  `tests/scripts/bisect_h8.txt` — the fast repro and demotion loop (§5).

Both capture legs run the same script through the gate. The trace-AOT tree is
the a2 promotion (I_RESET/I_NMI roots → 9 roots, 226 nodes, 214 AOT-eligible:
bank $00 5, bank $80 59, bank $81 150). The trace-LLE tree is the pure floor;
its markers are byte-identical to a6's `xp_lle` through the gate window, which
validates the instrument pair.

## 2. At the gate the code is not the variable

2×2 = {`aot_f21701`, `lle_f21701`, `aot_f21837`, `lle_f21837`} × {AOT, LLE},
each replayed 1,430 idle frames from a parked frame boundary:

| state | on AOT | on LLE |
|---|---|---|
| `aot_f21701` | tick 21458→22788 | tick 21458→22788 |
| `lle_f21701` | tick 21458→22788 | tick 21458→22788 |
| `aot_f21837` | tick 21594→22924 | tick 21594→22924 |
| `lle_f21837` | tick 21594→22924 | tick 21594→22924 |

and for each state the AOT-vs-LLE WRAM diff over all 1,430 frames is **≤2
differing 1 KiB blocks (label blocks), at every frame, for every state**.
Same machine state ⇒ same game, bit for bit, both before and at the gate. The
`execution_share` of each replay leg proves the path (1.60% AOT / 0.00%).

So the street-transition "game-mode break" is carried by *state*, not by the
gate code. Which state: see §3.

Section diff of one state pair (`l3sn_diff aot_f21837 lle_f21837`, 305,603 B):
`cpu` 0, `ppu` 2,181, `apu+dma` 36,475, `cart.wram` 4,075 (matching the frame
dump), timing tail 2. The CPU registers — all 22 bytes — are *identical*
between legs at a parked host frame boundary; the divergence lives in WRAM
plus free-running APU/DMA phase.

## 3. The physical onset is f16122

Byte-level WRAM diff of the two capture legs, fine sweep:

| host frame | differing bytes | note |
|---|---:|---|
| ≤f16121 | 1–3 | label/timer noise only |
| **f16122** | **16** | first physical split: $00DF F2→F6, $00E5 61→63, $00E9 DE→E2, $00EB 01→03, $00EF 0E→0C, $00F1 20→50, $00F2 3F→EA |
| f16123 | 26 | same table |
| f16124 | 12 | moves to $1C94/$1CD4 (timer labels), $0123/$0124 |
| f16132 | 37 | $0023/$0026 join |
| f16200–f21800 | ~100–400 steady | object tables $29xx/$2Bxx/$3Dxx/$45xx out of phase |

The same split, same frame, same bytes, appears in a6's old `xp_aot` pair
(64 B at f16122, 424 B at f16132) — so it is not an artifact of the new
promotion set; both AOT generations carry it. a6 read the 4–16-block band of
§3 as "transition/label"; it has a definite onset date and it is AOT-induced.

At f16122 the game is mid-combat in the alley; the differing bytes are
direct-page zero-page variables ($00DF, $00E5–$00F2), a table indexed from
$00DF whose walk goes out of step on the AOT leg. Nothing yet looks like a
transition variable; the street-gate decision at f21812+ is downstream
consequence.

## 4. What a6's headline should now say

Physics is cross-path identical only up to **f16121**. From f16122 the AOT
leg carries a small steady WRAM delta (~10²–10³ B/frame) through the rest of
the route; at the street gate the two legs then make different game
decisions, and only after that do the big scene-mode diffs appear. a6's
guest-aligned gate stays correct as a *gate*, but its "physics identical to
f21800" claim is superseded by this section. (The checkpoint framebuffer md5
table matched at H8 — f16188 — while WRAM differs there by 54 B; the pixel
check is not sensitive to this class of split.)

## 5. Repro and demotion loop

`tests/scripts/bisect_h8.txt` = the gate route cut after `dump H8` (f16188,
66 frames past the split): 16,428 frames, ~5 min per leg, both legs in
parallel. Control (current promotion, no demotion):

```
lle: interp 100.00%  aot  0.00%
aot: interp  96.69%  aot  3.31%
f16120:     3 bytes   $011F $1D00 $1D04
f16122:    16 bytes   $00DF $00E5 $00E9 $00EB $00EF $00F1     <- reproduced
f16188:    54 bytes   ($001A $0023 $0038...)
```

`tests/bisect_aot.sh <forces-file>` splices `force_lle <pc24>` demotions into
the marked block in `recomp/bank00.cfg`, regenerates, rebuilds only
`build-tr-aot`, reruns both legs, and prints the onset numbers. One caveat it
encodes: "first frame that differs at all" is not a usable metric (boot puts
timer label bytes out of step at f2 on every leg), so the verdict keys off the
f16122 onset window and the H8 count.

Demotion ladder (~10 min per step):

| # | demotion | nodes / AOT | f16122 | f16123 | H8 f16188 | verdict |
|---|---|---|---:|---:|---:|---|
| 0 | none (a2 promotion set) | 226 / 214 | 16 B | 26 B | 54 B | SPLIT |
| 1 | `force_lle 80c11f` | 225 / 213 | **16 B, same bytes** | 26 B | 55 B | SPLIT |

Step 1 is informative even as a failure: `$80:C11F` is the vblank dispatcher the
NMI's only call demand resolves to, so the whole bank $80/$81 subtree hangs
below it — yet demoting it changed nothing at the onset, not one byte of the
$00DF table. It also removed exactly one node (226→225, 490 edges in the graph),
so the walk is wide rather than deep: there is no single dispatcher to demote.
Next step is by bank chunk (bank $81 = 150 nodes, bank $80 = 59, bank $00 = 5).

`tests/wram_trace.py` is the instrument that names the writer instead of
guessing: it arms the framework's reverse-debug WRAM-write ring
(`trace_wram`, `wram_writes_at`) over $00DF-$00F2, $011F-$012B and $1C92-$1CD7
on both legs, parks at f16130, and reads back the per-frame write history with
the recompiler's own `func`/`parent` attribution. The ring hooks the bus write
path, so it sees AOT stores as well as interpreted ones — a smoke park at f400
already returns the NMI's `inc abs $1C92` as `interp@$00C0E2`, one entry per
frame, on both trees.

## 6. Open questions this leaves

- The 2×2 shows AOT code did not break *these* states in these windows. AOT
  share in the replay window is 1.60% vs 3.31% on the live route, so the
  suspect functions are scene-dependent; the f16122 window is combat, the
  replay windows are street. A state captured at f16100 replayed on both
  paths (parked capture on the trace-floor leg) would pin the code bug at
  the onset with byte-identical starting state.
- `f301` states (early boot) differ by 21 bytes total — same scene, one APU
  write apart. Boot is effectively deterministic across paths; the timer
  label bytes that a5/a6 excluded are not a boot miscompile.

## 7. The f16122 writer: the same byte stream, labelled one iteration apart

`tests/wram_trace.py` (ports `trace_wram` / `wram_writes_at`) armed the bus
write ring over $00DF-$00F2, $011F-$012B, $1C92-$1CD7 on both trees and parked
at f16131. The ring retains everything from f16122 up. For every tracked
address the recorded **byte-write stream is element-for-element identical
across the two legs** — same bytes, same order, same count — and the *frame
stamp* is what diverges:

| addr | entries (both legs) | byte streams | first stamp split | frame at split |
|---|---:|---|---:|---|
| $00DF | 325 | identical | write #124 | aot **f16123** / lle **f16122** |
| $00E5 | 155 | identical | #56 | f16123 / f16122 |
| $00E9 | 325 | identical | #124 | f16123 / f16122 |
| $00EB | 325 | identical | #124 | f16123 / f16122 |
| $00EF | 2604 | identical | #922 | f16123 / f16122 |
| $00F1 | 2603 | identical | #920 | f16123 / f16122 |
| $00F2 | 2603 | identical | #920 | f16123 / f16122 |

Per-frame counts confirm the boundary itself moved, not the content
($00EF, writes landing in f16122 / f16123 / f16124):

```
aot:  922  1091  591      total 2604
lle:  941  1095  568      total 2604
```

The floor leg absorbs ~20 more loop iterations inside f16122 before the frame
boundary lands. Writer attribution at f16100-31 is the same code on both legs:
the AOT leg shows 2,602/2,604 of the $00EF writes under
`bank_80_9DE8_M0X0` (parent `bank_80_9EF0_M0X0`); the floor leg shows the same
loop as three interpreted PCs — `interp@$809F29` (1,095), `interp@$81B061`
(941), `interp@$809F93` (568) — the three sites inside/around the 25-byte
$80:9DE8 body (which ends in RTS at $9E01). Identical values, identical
writer, different frame label: **the §3 byte-diff is the frame dump sampling
the same loop at a different iteration**, not a computed-value bug.

Instrumentation note (this looked like a guest difference until normalized):
the ring records an AOT 16-bit store as ONE event at the base address
(`w=2`, full 16-bit `val` — e.g. `adr=$000F1 val=0x140C`) while the floor
records two byte events each with its own `adr` (`adr=$000F2 val=0x0014`).
A raw per-address comparison of `val` bytes mismatches at $00F2 for 2,280 of
2,603 entries purely from this rendering. Unfold a wide event as
`val&0xFF` at `adr`, `val>>8` at `adr+1` and every stream above becomes equal.
The store-width hypothesis is an artifact of the trace hook, closed.

## 8. The frame boundary is a pinned budget; the hand-off point moves

`tests/cyc_probe.py` parks each leg at odd frames around the onset and reads
`get_v2_cpu` (`tests/out/cy_{lle,aot}.json`; these were collected before the
tree-collision in the addendum below, on the verified control pair
lle 100.00%/0.00% vs aot 96.71%/3.29%):

| park | cpu lle | cpu aot | Δcpu | master (both legs) | step /2f | resume_pc lle / aot |
|---|---:|---:|---:|---:|---:|---|
| f16117 | 714,749,778 | 714,588,084 | 161,694 | 5,760,006,956 | — | $81B061 / $81B061 |
| f16119 | 714,825,632 | 714,663,938 | 161,694 | 5,760,721,692 | 714,736 | $81B061 / $81B061 |
| f16121 | 714,900,661 | 714,738,958 | 161,703 | 5,761,436,428 | 714,736 | $81B061 / $81B061 |
| **f16123** | 714,989,857 | 714,827,408 | **162,449** | 5,762,151,192 | 714,764 | **$809F29 / $809DEA** |
| f16125 | 715,095,496 | 714,932,623 | 162,873 | 5,762,865,912 | 714,720 | $818DE8 / $818DE8 |
| f16127 | 715,204,680 | 715,041,807 | 162,873 | 5,763,580,638 | 714,726 | $819025 / $819025 |
| f16129 | 715,314,602 | 715,151,750 | 162,852 | 5,764,295,376 | 714,738 | $818E6D / $818F97 |
| f16131 | 715,419,572 | 715,256,723 | 162,849 | 5,765,010,112 | 714,736 | $818CE1 / $818F02 |
| f16133 | 715,524,510 | 715,361,663 | 162,847 | 5,765,724,846 | 714,734 | $818E74 / $818FAC |

Three things fall out:

1. **`master_cycles` at the parked boundaries are identical to the unit**, and
   the step is exactly 714,736 per 2 frames = 357,368/frame
   (`BFD_MASTER_CYCLES_PER_FIELD` / `GFD_MASTER_CYCLES_PER_FRAME`; `snes.c:530`
   — "the host's 'one frame' is a fixed 357368-clock budget"). The frame
   boundary is a pinned schedule, not a measurement. Identical master at parks
   does NOT mean the paths charge the same master per instruction — only that
   the budget is the same. `catchup_cycles` is 4 on both legs.
2. **The hand-off point moves exactly at onset.** `resume_pc` — the PC the
   scheduler would resume at — is $81B061 on both legs through f16121, then at
   f16123 both legs are parked *inside the burst* at different instructions:
   $809F29 (floor) vs $809DEA (AOT, i.e. the $80:9DE8 body entry).
3. **Δcpu is a constant ~161,700 pre-onset, jumps +746 across f16121→f16123,
   +424 more, then flattens at ~162,850.** In the burst frames the floor leg
   fits ~1,170 more CPU cycles (200+ instructions) of work inside the same
   master budget. That is exactly the phase shift §7 measured at the byte
   level.

Mechanism, from the framework source: every generated AOT block polls
`interp_bridge_lle_master_deadline_reached()` between instructions and unwinds
to the interpreter through `interp_bridge_lle_yield_unwind` when it fires —
the emitted $80:9DE8 body has the poll at every block entry
(`src/gen/bank80_v2.c`, `L_9DE8_M0X0` etc.). The deadline is *suppressed*
unless `s_lle_sched_depth > 0 && s_interp_bounce_owner_depth > 0`
(`interp_bridge.c:988-1030`), which is why quiescent loops are not cut and why
the effect appears only in scheduler-driven bursts. AOT advances the master
through the paced bus helpers (`cpu_state.c:757-804`, one speed-weighted
charge per transfer); the floor advances it per opcode
(`interp_bridge.c:2730`); the two are deliberately matched, and §8.4 shows
they agree numerically.

### 8.4 The two cycle models agree per opcode

`tests/cyc_model_diff.c` (binary `tests/out/cyc_model_diff`) executes directed
opcodes through the floor's `interp816` and compares against the folded
authority model (`runner/src/snes/snes_cycles.h`, generated from
`recompiler/snes_cycles.py`) with exactly the predicates the emitter supplies
for an M0X0 block. All 22 cases, D=0, native mode: **every delta is +0** —
including the page-cross variants of `LDA abs,X`, `LDA abs,Y`, `(dp),Y`,
`[dp],Y`, `STA abs,X`, and the full $80:9DE8 opcode mix:

```
DEC $EF 7/7   LDA # 3/3   STA $EF 4/4   LDY $E5 4/4   LDA [$E1],Y 7/7
XBA 3/3   STA $F1 4/4   INY 2/2   STY $E5 4/4   PLA 1/1... 
floor = 118, aot = 118 cycles per body pass
```

The models book the 16-bit-index penalty differently — floor's address-mode
helpers charge `+1` when `!xf` or on a true page cross; the authority folds
`SNES_X_ADD` at gen time and adds `SNES_XCROSS_ADD` only when
`crossed && x != 0`, and the emitter only emits a runtime xcross `+= 1` when
`x_flag != 0` (`instr_runtime_charges`). For M0X0 the netting is identical.
The framework's own cross-check, `tools/cyc_watch/cyc_equiv.c` (builds clean
on macOS), is 22/24 ok; the two DIVERGE cases are RTI-emu/COP-emu overcounts
in LakeSnes — the game runs native, and the harness never exercises
dp-indirect modes anyway. The documented model residuals — `(dp),Y`
page-cross, MVN/MVP per-byte, D.l weighting — are floor-side omissions shared
by both paths (`[dp],Y` has no page-cross model on either side:
`interp816_adrIly` charges nothing and `_XCROSS_MODES` excludes long
indirect). "The compiled path mis-accounts CPU cycles" is closed as a
hypothesis: per-opcode charges match.

### 8.5 Magnitude scales with AOT coverage; kind does not change

| pair | AOT share | f16150-16200 | f16400 (stable) | f17000 (stable) |
|---|---|---|---|---|
| `bs_*` (28 nodes) | tiny | 17-27 B (2 B to f16125) | 53 B (50 stable) | — |
| `xp_*` (214 nodes) | 3.3% | — | 178 B (131 stable) | 206 B (199 stable) |

"Stable" = survives realignment of the frame label by ±1 frame, so it is not
explainable as sampling phase alone. The 28-node pair is even tick-aligned
(+0 host frames across all 16,428) and still shows 50 stable bytes at f16400
at the same address set as the full-AOT pair's H8 diff.

### 8.6 Where this leaves the hunt

The onset is a **frame-phase split**: pinned 357,368-clock budget + per-block
deadline unwinding means the compiled path hands off to the interpreter at a
different instruction inside the $80:9DE8 loop than the floor does on the
frames where the scheduler is active, and the physics table write sequence
gets partitioned across the boundary one iteration apart. From there the
divergence compounds through the object tables (§3), scales with AOT coverage
(§8.5), and eventually flips game decisions at the street gate (a6). What is
NOT the cause: any miscomputed value, any per-opcode cycle mis-charge, any
store-width effect, and any single demotable dispatcher (§5).

Addendum — tree collision found while confirming this. The first
`handoff_probe` run printed byte-identical cycles/resume_pc/ring counts on
both "legs" and a 96.69%/3.31% execution share on *both*: the restore regen
(§5) had rebuilt **both** trace trees from the promoted `symbols.toml`, so
`build-tr-lle` and `build-tr-aot` were md5-identical binaries (209 compiled
functions each). Affected runs: that probe pair and the
`SNESRECOMP_DEADLINE_DIAG` pair (whose 4 fired lines were identical down to
the cycle — boot lines, master ≤ 1,379,030; the print budget of 8 suppressed
/ 4 fired never reaches f16122). Fixed by rebuilding in `tr_build.sh` order:
regen from HEAD symbols (2-entry dispatch, 0 compiled funcs) → build
`build-tr-lle`; promoted regen (217 entries) → rebuild `build-tr-aot` (md5
unchanged). The `cy_*`, `wt_*`, `bs_*`, `xp_*`, `gs_*`, `gr_*` sets all
predate the collision and stand. A clean-tree probe run follows.

### 8.7 Clean-tree probe: both legs cut the burst, at different points

`tests/handoff_probe.py f16118-f16130 step 1` on the rebuilt trees
(control verified: lle 100.00%/0.00%, aot 96.69%/3.31%; `tests/out/ho_{lle,aot}.json`).
The floor leg reproduces the pre-collision `cy_lle` series to the cycle
(f16119 cycles 714,825,632, resume_pc $81B061 / $809F29) — floor
determinism across tree rebuilds confirmed.

Hand-off event kinds inside the newest-512 ring at each park:

| park | floor events | AOT events |
|---|---|---|
| f16119 | quiescent=511, **deadline=1**, burst 0 | quiescent=499, **unwind_arm=6, unwind_consume=6**, burst 0 |
| f16123 | quiescent=510, deadline=2, burst 1 | quiescent=495, **unwind_arm=8, consume=7**, burst 2 |
| f16127 | quiescent=506, deadline=6, burst 3 | quiescent=487, unwind_arm=12, consume=7, burst 5 |
| f16131 | quiescent=502, deadline=10, burst 3 | quiescent=482, unwind_arm=13, consume=7, burst 5 |

The two paths cut the same burst with different machinery: the floor's
auto-quiescent/deadline sites set the resume PC **mid-iteration**
(f16122: `set:$809F29`, f16123: `set:$809F93`); the compiled path arms a
yield-primitive unwind at every block-entry poll and lands **at the loop
entry** (`unwind_arm:$809DEA` + `set:$809DEA` at both frames). So on exactly
the onset frames, the floor resumes *inside* the $80:9DE8 loop where it was
cut, and the AOT leg re-enters the loop from its head — the frame-phase shift
§7 measured at the byte level, now observed at the hand-off records
themselves. No ring entry in the window has either depth guard at 0: the
deadline is never suppressed in this scene.

(The AOT leg's absolute cpu_cycles carry a constant ~76.4k offset vs the old
`cy_aot` series — same binary, different park history: the old run parked at
f16117 first. Constant across parks; the per-frame deltas agree with §8 to
~12 cycles: floor 89,196 vs AOT 88,462 cpu cycles across f16121→f16123.)

## 9. The gate this leaves (2026-11-06): the horizon, and the value streams

Owner ruling on §8.6: the frame-phase hand-off split is **expected framework
behaviour**. No framework code was patched - no `interp_bridge.c` change, no
pin bump. The framework records the ruling under Axis 6 of
`/Users/wee/Documents/work/snesrecomp/docs/validation/accuracy-history.md`,
committed there as `8d9f999` on top of the pinned `773285b`. `framework_pins.txt`
deliberately stays at `773285b`: a pin names the revision the shipped binary was
**built** from, and a docs-only commit changes no header, source, or generated
output. If a future framework change touches code, `./tests/bisect_aot.sh` with
`tests/scripts/bisect_h8.txt` re-checks the onset in about 5 minutes.

What the port's cross-path verdict is now, in two tiers.

### 9.1 Tier 1: where the paths stop describing one game state

```sh
./tests/framedump_diff.py horizon tests/out/xp_aot tests/out/xp_lle tests/baselines/horizon_xp.json
```

- pairing: the same host frame index, `run1[f]` against `run2[f]`;
- the frame-label bytes (`KERNEL_WINDOW` $01C80-$01D40 plus the four timer
  singletons) are excluded, because they are the frame counter's own shadow;
- noise band `NOISE_MAX = 3 B`, measured rather than tolerated: 0 B on the
  shipped pair before the onset, 3 B on the narrower AOT sets (§3, §5);
- the horizon is the frame after the **last** frame inside the band - an onset
  that never heals. On the shipped pair that rule lands on **f16122**, the same
  frame §3 reached from the byte-write stamps with a different instrument.

Two rules fail it: the horizon moves earlier than the recorded baseline (more
than `HORIZON_SLACK = 1` frame), or a state difference stays out of the band
for longer before the onset than the baseline's longest healing stretch (more
than `PRE_RUN_SLACK = 10` frames beyond it). Everything past the horizon is
printed as consequence, never as evidence: 59 B at f16122, 419 B at f16132,
29,652 B at f25901 is phase compounding on its own.

Why healing bursts are not evidence, and why their *duration* is: this route
leaves the band 71 times before f16122 - boot bursts of 1,443 B that are gone a
frame later, menu stretches peaking at 2,897 B and out of step for 1,687 frames
before returning to 0 B. The route is scripted input on the same build, so those
stretches reproduce exactly run to run (a second capture, `xp_aot2`/`xp_lle2`,
gives the same f16122); the only way one lengthens is that the code under test
moved.

The pairing coordinate is measured, not assumed. At the same host frame the legs
are **byte-identical** (0 B outside the labels) across f15900-f16121, while the
tick counter inside those frames sits 3 apart. Paired by that counter instead,
f16000 reads 85 B - and 0 B once the label is shifted back by k=-3. Guest-tick
pairing therefore invents an onset ~120 frames early; `guest`, `shift`, `tick`,
`clock` and `drift` are diagnostics for reading a verdict, not verdicts.

### 9.2 Tier 2: whether a value is actually wrong

A frame dump cannot answer this, so `tests/wram_trace.py --streams` does it on
the trace trees (`build-tr-lle` floor, 0 compiled functions / `build-tr-aot`
promoted, 209, route `tests/scripts/bisect_h8.txt`). Write streams keyed by bus
index, store widths normalised per §7's rendering note, values in order compared
with the frame stamps ignored: **PASS, 7 of 7 tracked addresses identical**, and
it puts a number on §7 that §7 did not have. The stamps split on **42 of 2,604**
writes at $00EF and **43 of 2,603** at $00F1/$00F2 - 139 of 8,940 in total, all
one frame apart, at exactly §7's split points (#124, #56, #922, #920 unchanged).
Negative controls fail correctly: corrupting one AOT byte gives
`FAIL $00EF: value #930 is 195 ... and 5`, and inserting one extra write splits
the count.

### 9.3 Recorded baselines and exit codes

| file | pair | AOT set | horizon | at horizon | healing stretches before it |
|---|---|---|---|---|---|
| `tests/baselines/horizon_xp.json` | `xp_aot` vs `xp_lle`, `combat.txt`, 25,902 frames | 214 nodes | f16122 | 59 B | 71, longest 1,687 frames, peak 2,897 B |
| `tests/baselines/horizon_bs.json` | `bs_aot` vs `bs_lle`, `bisect_h8.txt`, 16,428 frames | 28 nodes | f16280 | 20 B | 63, longest 30 frames, peak 40 B |

Judging the xp pair against the bs baseline fails both rules at once ("horizon
moved earlier: f16122 vs baseline f16280" and "1,687 frames against 30"), which
is expected - different routes, different coverage, §8.5 - and is kept as the
demonstration that the rules actually fire rather than rubber-stamp.

Exit codes for both gates: 0 pass (or 0 measured-only when no baseline is
named at all), 1 fail, 2 no verdict. A scan that starts already out of band, or
ends before the baseline horizon, is not allowed to claim the horizon is gone;
neither is a baseline path that does not exist, which prints `VERDICT: no
baseline` instead of silently recording a new one. `--update` is the only route
that writes a baseline. `./tests/crosspath.sh` prints exactly one VERDICT
from Tier 1 and points at Tier 2; `XP_BASELINE` redirects the baseline,
`XP_ANALYZE=0` runs the legs only, `XP_TAG=2` keeps a second independent sample
on disk.

Same-path determinism is untouched and stays strict: `./tests/parity.sh` on the
shipped binary is 25,902 of 25,902 frames byte-identical.

### 9.4 Replaying the pin onto current upstream: one cycle test breaks, and a census that says the shipped build cannot feel it

Recorded because it decides what a re-pin costs. The pinned framework commit
(`773285b`, §8) was replayed onto `origin/main` `816bc5ac`—106 commits ahead of
the point where this checkout's history diverged—in a scratch worktree, as
branch `rebase/aot-cycle-onto-origin`. Measured rather than assumed for one
reason: the verdict above rests on a fixed per-frame master-clock budget, and
those 106 commits include PPU/APU timing work that can move that budget.

What came out:

- **One merge conflict**: `runner/src/snes/interp_bridge.c` `bridge_bus_read`,
  where upstream's fused-ROM-read fast path (`ca5673cb`) and our
  `bridge_timing_bus(adr, 'R'/'W')` direction argument meet. Keep both; all 5
  call sites already match the 2-argument form, and upstream added none.
- **One new test failure**, and only one. `tests/run_tests.py` cannot run here (no
  `cargo` on `PATH`), so the v2 subset was run directly under pytest from a scratch
  venv, and compared by failure *set*, not count. At the pin: **85 failed / 509
  passed**. Plain `origin/main` on the same machine: **85 failed / 496 passed**,
  the same 85 environmental entries, 0 added and 0 removed. The replayed branch:
  **86 failed / 515 passed**. The single addition is
  `tests/v2/test_folded_branch_cycles.py::test_default_folded_branch_cpu_cycles_match_interpreter`,
  one CPU cycle light on all six statically-proven taken branches (BneTaken /
  BeqTaken / BneZeroTaken / BeqZeroTaken 10 vs 11, WideTaken / IndexTaken 11 vs
  12).
- **That failure is not this port's regression.** Dropping upstream's test file
  onto `503063e4`—the commit immediately before this checkout's four local
  ones—and onto the pin itself reproduces the same numbers. It is green only at
  `origin/main`, because upstream's `a94e0bb6` added the charge there. So the
  accounting gap predates the port; what the replay adds is that this port's pace
  model, stacked on top, neutralises upstream's fix again: the fold charge lives
  at `recompiler/v2/emit_function.py` 139-156 (upstream's code), and the pace
  flush centralises per-insn charging so it takes that charge over without
  re-adding it.
- **The census that settles the shipping question.** `insn.const_z_fold_taken` is
  absent at the pin, but that fact alone proves nothing about the emitted code:
  the fold itself (`const_z_fold_unconditional`) is older, and a folded taken
  branch that owes a cycle and does not pay it is a real undercharge—one CPU
  cycle, 6 master clocks, per fold. So the fold was counted on this ROM instead.
  Wrapping the decoder post-pass `_apply_constant_z_fold` and running the port's
  own generate (`snesrecomp_cli.py generate`, the same arguments `tools/regen.sh`
  passes, out-dir redirected to a scratch directory): the post-pass runs **once per
  AOT variant, 214 graphs, 0 fold records, 0 insns flagged
  `const_z_fold_unconditional`**. Shadowrun's promoted set contains no
  constant-Z-folded branch at all, so there is no fold for any charge model to
  lose. That scratch generate reproduced the shipped `src/gen` **md5 for md5, all
  18 files**, so the census is about the code that ships and not a near-miss
  rebuild. The trigger is narrow: a same-block `LDA/LDX/LDY #imm` whose only
  successor is a BEQ/BNE with exactly one predecessor. Recipe:

  ```python
  from v2 import decoder as dec
  pp = dec._apply_constant_z_fold
  def counted(graph, live=None):
      before = len(graph.const_z_folds)
      pp(graph, live)
      print(len(graph.const_z_folds) - before,
            sum(getattr(d.insn, 'const_z_fold_unconditional', False)
                for d in graph.insns.values()))
  dec._apply_constant_z_fold = counted
  # then runpy.run_path('<snesrecomp>/snesrecomp_cli.py', run_name='__main__')
  # with argv = ['generate', '--rom', ROM, '--cfg-dir', 'recomp',
  #              '--out-dir', SCRATCH, '--funcs-h', 'recomp/funcs.h',
  #              '--project-root', ROOT]
  ```

  Note it writes `recomp/funcs.h` in the project tree as a side effect; the
  content is regenerated identically, and `git status` stays clean.

- **Our own instrument has a blind spot, and it is worth naming.** §8.4's
  `tests/cyc_model_diff.c` compares `interp816` against the folded authority
  header `runner/src/snes/snes_cycles.h`—a tracked file whose blob is identical
  at the pin, at `origin/main` and in the replay—and charges the taken branch at
  the terminator. It therefore never exercises the pace path's per-insn charge.
  §8.4 remains true as written ("per-opcode charges match"), but it was never a
  check on pace, and it could not have caught the fold. The census and upstream's
  test are what close this.
- **The two macOS build fixes still apply and are still needed** at current
  upstream: `tests/run_c_tests.sh` hardcodes the GNU `-Wl,--gc-sections` on two
  link lines (audio delivery, DMA snapshot), and `lib/recomp-net`'s
  `rnet_host_relay.c` still needs `_DARWIN_C_SOURCE` because that script compiles
  it directly with only `-D_POSIX_C_SOURCE` / `-D_DEFAULT_SOURCE`, bypassing the
  CMake target that injects the define on Apple. Verified at upstream's own
  pointer `7a4d330`: compiles with the define, fails without it (`net/route.h`:
  unknown type `u_short`).
- **A gitlink caution for whoever publishes this checkout's framework history**:
  one local commit bumps the `lib/recomp-net` submodule to a commit that has never
  been pushed to `recomp-net`. A gitlink must not point at an object the remote
  lacks, so that submodule fix needs its own PR there first; the replay leaves the
  bump out for exactly this reason.

What this decides, unchanged in substance: the pin stays `773285b`, nothing about
the shipped binary moves, both horizon baselines stand. Before any replay onto
current upstream, reconcile the pace flush with upstream's fold charge (charge the
folded taken cycle inside the flush, or exempt folded insns from pace's takeover)
and keep that test green; then re-capture both cross-path legs and write new
baselines. Re-run the fold census after the pin change too: today it is 0 on this
ROM, so 6 master clocks per fold is invisible here, but that number is a property
of the promoted set, not of the framework, and the moment it is non-zero the
compiled path is light against the floor by 6 master clocks per folded taken
branch per pass—and master clocks decide the frame boundary, so the horizons
move with it. Recorded on the framework side in Axis 2 of
`~/Documents/work/snesrecomp/docs/validation/accuracy-history.md`.
