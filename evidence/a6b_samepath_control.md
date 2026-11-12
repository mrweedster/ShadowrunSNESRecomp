# A6b control: same path twice is byte-identical for 25,902 frames, so the A6 divergence belongs to the two execution paths

A6 established *where* the AOT and LLE legs of `tests/scripts/combat.txt` part
company (byte onset f21812, then a monotone climb to 70/128 differing 1 KiB
blocks). It did not exclude the two boring explanations: the harness drifting,
or the host clock leaking into the guest. This is the control that excludes
them, and it puts a number on the desync event.

Raw output: `artifacts/a6b_control.txt` (drift + clock for both controls),
`artifacts/a6_control_master.txt` (per-checkpoint master cycles and ticks).

## Control 1 — same binary, two separate processes, whole route

Both pairs re-run `combat.txt` from the same master SRAM seed (`md5
63ec0b4a…`), one dump dir per leg (`tests/out/xp_aot2`, `tests/out/xp_lle2`):

| pair | frames | first frame over 3 differing 1 KiB blocks | worst frame |
| --- | --- | --- | --- |
| `./Shadowrun` vs `./Shadowrun` | 25,902 | **never** | f0, **0 blocks** |
| `build-lle/…` vs `build-lle/…` | 25,902 | **never** | f0, **0 blocks** |

Zero — not "two label blocks", zero. Same executable, same SRAM, same script:
every one of 25,902 WRAM dumps is byte-identical to its partner, label bytes
included, because the two legs are in the same host-frame phase. Guest tick
delta is `+0` across all 25,902 frames with no steps, both paths.

The two AOT legs ran under different host load (one shared the machine with a
cmake build, the other with byte-scan passes over 3.4 GB of dumps) and still
match byte for byte. So host speed, scheduler noise and concurrent processes
do not touch guest state at all. Anything a cross-path run shows therefore has
to come from the guest path, not the machine.

## Control 2 — the two paths agree on the clock until one frame budget appears

Per-checkpoint `master_clock` (both legs are at the **same host frame** — every
tagged dump pair has an identical frame number):

| checkpoint | host f | run1 − run2 master cycles | run1 − run2 guest ticks |
| --- | --- | --- | --- |
| H8 … P3 | 16188 … 21836 | within ±36 | +3 |
| W1 | 22951 | **−357,368** | +37 |
| W2, W3, T0, T1, U1, U5, U9, S1 | 23078 … 24702 | −357,340 … −357,386 | +37 |
| S6 | 25902 | −357,356 | +37 |

357,368 is exactly one host frame of emulated time
(`GFD_MASTER_CYCLES_PER_FRAME`). It appears in one step, between f21836 and
f22951, and every later checkpoint carries the same offset. That is a single
clocking discontinuity in the LLE leg, not an accumulating cycle-rate error —
the two paths execute different instruction counts (257,938,687 interp insns
on the AOT leg vs 265,434,823 on the LLE leg, `interp_cycle_pct` 96.27 / 100.00)
and still land within 36 cycles of each other for the first 21,836 frames.

`framedump_diff.py clock` locates it: the tick offset between the legs is +3
from host f1350 to f22851, steps once per frame for 34 frames (f22852–f22885 —
the LLE leg stops advancing the game's tick counter while the AOT leg keeps
going), then both legs resume and the offset locks at **+37 ticks** for the
remaining ~3,000 frames. The two paths agree on the guest's clock everywhere
except one 34-frame window.

## The divergence has three phases, and the byte onset is earlier than A6's

Scanning the same pair at 1 KiB block granularity (`drift`) and then exactly
(`offs`), the state separation runs in three steps, not one:

| host frames | differing 1 KiB blocks | exact bytes differing (non-label) |
| --- | --- | --- |
| f0 … f16,12x | **1** (the counter page only) | 5–6, all inside the label window |
| f16,130 … f16,160 | spike to 36, then back | transition DMA scratch |
| f16,500 … f21,500 | 8–9, steady | **131 – 376** |
| f21,800 … f22,500 | 29 | 3,759 → 5,809 |
| f23,000 … end | 70 of 128, flat | ~30,700 (23 % of WRAM) |

So the first non-label byte appears at **f16,130**, ~5,700 frames before the
checkpoint onset A6 quotes (f21,812) — A6's number comes from the first frame
whose *byte count* jumps into the thousands, and from the guest-counter
alignment, which hides early differences because the same counter value is
reached with different input history. The residue in the middle phase is
scattered single bytes (at f17,000: 201 bytes in 117 runs, 88 of them
singletons, hot pages `$7E01700`, `$7E03C00`, `$7E00000`, `$7E03D00`), i.e.
many small game-state fields disagreeing, not one table misaligned.

What lines up with that is the clock, not the codegen:

| host frames | run1 − run2 guest ticks |
| --- | --- |
| f0 … f204 | 0 |
| f205 … f496 | +1, back to 0 at f417 |
| f497 … f22,851 | +1 → +2 → **+3 plateau from f1350** |
| f22,852 … f22,885 | one step per frame, reaching +37 |
| f22,886 … end | +37, flat |

The two paths never tick at exactly the same rate: 3 ticks of drift accumulate
over 21,500 frames (0.014 %), and the game sees the scripted button presses at
different ticks in the two legs. A scene transition polled 3 ticks apart
resolves into a slightly different world — which is exactly the phase-2
residue — and the 34-tick step at f22,852 then makes the two runs simply
different playthroughs.

## What this changes about the A6 verdict

* The cross-path byte divergence is a **guest-tick phase** effect, not a
  miscompiled primitive: it appears exactly where the tick offset first gets a
  chance to matter (f16,130, the first transition after the +3 plateau
  starts), and it saturates at a second, larger phase step.
* A cross-path parity claim is therefore **only honest with a bounded
  prefix**. Up to ~f16,120 the legs match to within 5 label bytes
  (`$7E01C80–$7E01D40`, `$7E0012C/12E/12F/132`); past that the route is
  already two playthroughs. The 1,200-frame gate in `tests/README.md` §7 sits
  inside the honest window, which is why it passed and why it does not
  generalise to a 25,902-frame route.
* The thing that *is* now proven end-to-end: a promoted batch running 3.73 %
  of cycles in recomp-verified AOT, and a pure-interpreter build at 100.00 %,
  drive the same game to the same host frame count with the emulated clock
  agreeing to 36 cycles over 21,836 frames and WRAM agreeing to 5 label bytes.
* The actionable framework question is now specific: **why does the tick
  counter advance differently per path at all?** 3 ticks in 21,500 frames is
  0.014 %, and 357,368 cycles appearing in one step at f22,852 means the frame
  service's cycle budget is being spent differently when the floor runs. Until
  that is closed, no long-route cross-path byte gate can pass.

## Caveats

* Wall-clock fps from these legs is not comparable (219/563 fps in pair 2,
  228/323 in pair 1 — host load varied and a second session was running legs
  in the same tree). No speed claim is made here; `evidence/a2_aot_batch.md`
  owns the performance numbers.
* The second pair was produced by `XP_TAG=2 XP_ANALYZE=0 tests/crosspath.sh`,
  which keeps both pairs on disk. Nothing about the divergence depends on that
  flag; `drift`/`clock` are pure post-processing over the dumps.
