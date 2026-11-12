# Round 8: the phase is a discrete offset, not a drift

Date: 2026-11-08. Framework pin
`773285b8210f2254ae87d0a14113980fb36990ad` (`dirty=no`). The probe runs on a
clone of that rev with an env-gated instrumentation diff
(`artifacts/round8_probe.diff`), never on the pin. Every number below is in
`artifacts/round8_phase_anchor.txt`, generated files-only by
`tests/phase_anchor_report.py`.

## 0. One paragraph

Round 7 showed that `$80C530`'s `$2137` read is a real 24-clock convention
difference but that removing it makes the gate worse, and it asked the next
round to find where the pre-read timeline parts company. This round measures
three points per frame — the NMI handler entry (interpreted on both tiers), the
first `$80C530` entry, and the `$80AD9F` loop — plus every compiled-function
entry. The answer is that the timeline barely parts company at all. At the
frame edge the two tiers agree to the clock on f1833, f1835 and f1836; inside a
frame almost every shared function entry has the same master clock, and the
few ±40-clock deviations cancel at the next entry (a call's charge landing on
one side of the entry). The `$80AD9F` loop costs the same 10,174 master clocks
interpreted and compiled on three of five frames. The offset at `$80C530` is a
small per-frame number (0 to ±56), not accumulating drift, and it is zero on
two of the five frames. **Nothing ships; the pair stays `a0587ed0a0e34687`.**

## 1. The question

Round 7 §7: "Pick two common guest points in the same frame — a frame-kernel
entry and `$80C530`'s entry — and find the first one at which the two tiers'
`master_cycles` differ." Its table showed `$80C530` entry deltas of −52, −40,
+56, 0, 0 master clocks over f1832–f1836 and called the non-constant part the
"entry phase". It could not say whether that was drift accumulated through the
frame or a discrete offset created somewhere.

## 2. The probe

Same two executables as round 7, rebuilt from the two archived gen sets against
the round-7 clone plus one instrumentation patch:

| leg | gen set | `$80C530` | `$80AD9F` | exe |
| --- | --- | --- | --- | --- |
| ctrl | `gen_r6pair` (283 nodes, 18 units) | interpreted | interpreted | `81130e256fd7e2b4` |
| seed | `gen_r6pc1c9` (486 nodes, 33 units) | compiled | compiled | `3bcc6bdf2c716484` |

Three env-gated taps, all inert when unset:

* `SNESRECOMP_FRAMETAP=lo-hi` — `[frame]` with `master_cycles` and `cycles` at
  the moment the frame counter advances.
* `SNESRECOMP_ENTRYTAP=lo-hi` — `[entry]` at every compiled-function entry, in
  order, with the cumulative master clock.
* `SNESRECOMP_ANCHORTAP=a,b,c` (hex pc24) — `[anchor]` at exact guest PCs on
  either tier, so a PC the legs reach on different tiers is still comparable.

The anchor PCs are `$00C0E2` (NMI handler), `$80C530`, and `$80ABBC` (top of the
loop inside `$80AD9F`). `run_interrupt` in the pinned frame driver always calls
`interp_bridge_run_interrupt`, so the NMI handler is interpreted on **both**
tiers: its entry is the one per-frame sample taken the same way on both sides,
and it equals the `[frame]` value exactly.

Both entry samples are taken after the previous opcode's full charge is
committed: the interpreter commits `s_interp_bus_master` after
`interp816_runOpcode` returns, so at the next opcode's start `cpu->master_cycles`
is complete. A zero delta therefore means the same beam position, not merely
the same instruction.

One bug in the first probe build is worth recording: the anchor list began with
`00C0E2`, and the usual "leading `0` means off" env convention discarded the
whole list. The parser now treats only an empty string or exactly `"0"` as off.
The failed run is not in the artifact; the fixed parser is in the committed
diff.

## 3. The frame edge and the read entry

`artifacts/round8_phase_anchor.txt` §1. `d = seed − control`, master clocks.

| frame | d at NMI entry | d at `$80C530` entry | in-frame drift |
| ---: | ---: | ---: | ---: |
| 1832 | +14 | −52 | −66 |
| 1833 | 0 | −40 | −40 |
| 1834 | −32 | +56 | +88 |
| 1835 | 0 | 0 | 0 |
| 1836 | 0 | 0 | 0 |

The frame edge is in phase on three of the five frames. The in-frame part is
not monotone (−66, −40, +88, 0, 0) and is zero on two of them, which is not what
accumulating drift looks like.

## 4. Lockstep inside the frame

`artifacts/round8_phase_anchor.txt` §2. Position-by-position comparison of the
compiled-entry sequences:

* f1835: 51 shared entries before the sequences diverge; **46 have `d=0`**.
* f1836: 51 shared entries; **45 have `d=0`**.

The non-zero rows are single instructions whose charge lands on one side of a
call boundary. Example, f1835 entries 2–4:

```
  2: ctrl 818877 656099164   seed 818877 656099164   d=+0
  3: ctrl 818076 656099364   seed 818076 656099324   d=-40
  4: ctrl 809D9D 656099522   seed 809D9D 656099522   d=+0
```

The control spends 200 then 158 clocks across the two intervals; the seed
spends 160 then 198. The interval total is identical; only the split at the
entry differs. That is the same family as round 7's 24-clock `$2137` charge,
but at a call rather than a register read, and it cancels.

## 5. The one body that differs on the path

`artifacts/round8_phase_anchor.txt` §3. `$80AD9F`'s loop is entered 18 times
per frame. Total cost from its first to last `$80ABBC` entry:

| frame | ctrl | seed | seed − ctrl |
| ---: | ---: | ---: | ---: |
| 1832 | 10,174 | 10,174 | 0 |
| 1833 | 10,214 | 10,174 | −40 |
| 1834 | 17,850 | 17,898 | +48 |
| 1835 | 10,174 | 10,174 | 0 |
| 1836 | 10,174 | 10,174 | 0 |

Subtracting the loop delta from the in-frame drift leaves residuals of 0, 0,
+40, −66, 0: the loop explains the whole offset on f1833, f1835 and f1836, half
of it on f1834, and none of it on f1832. On f1832 the −66 is created in the
frame's opening, between `$80C11F` and the first `$80C399`:

```
  0: ctrl 80C11F 655005716   seed 80C11F 655005730   d=+14
  1: ctrl 81A99D 655006090   seed 81A99D 655006144   d=+54
  2: ctrl 80C399 655016180   seed 80C399 655016128   d=-52
```

So the phase at the read has two named shapes: a per-frame opening offset
(f1832), and ±40 at a loop boundary (f1833/f1834). Both are discrete; neither
grows with the work between them.

## 6. The counter that does drift

`artifacts/round8_phase_anchor.txt` §5. The same `[frame]` line carries
`cpu->cycles` (labelled `trunk`):

| frame | d `master_cycles` | d `cpu->cycles` |
| ---: | ---: | ---: |
| 1828 | +14 | −144 |
| 1832 | 0 | −713 |
| 1833 | −32 | −1,623 |
| 1836 | −6 | −1,624 |

`master_cycles` stays inside a few tens of clocks; `cpu->cycles` falls by
hundreds and then stabilises near −1,620. That is the drift the upstream seam
report measured, and it confirms which counter carries it. Round 7's read is
priced in master clocks, so it moved a clock that was already within tens of
clocks of the control; the counter carrying the accumulated difference is not
the one the PPU latch samples.

## 7. What this settles

1. **The seam is not a continuous drift in the beam clock.** The frame edge is
   equal on most frames, and nearly every shared function entry inside a frame
   is equal to the clock. The non-zero samples are discrete, ±40-ish, and
   cancel.
2. **A read-time fix cannot be sufficient.** On f1835/f1836 the tiers enter
   `$80C530` at the same clock, so the only remaining difference there is the
   24-clock in-body convention; on f1832/f1833/f1834 they enter tens of clocks
   apart for reasons already decided before the body runs.
3. **The first byte is still upstream.** The first `$80C530` entry on both
   tiers is f1832; the first non-label state byte is `$7E00126` at f1830. The
   latch cluster this round explains is the DP `$00`/`$01` one round 6 traced,
   not that byte.
4. **Decision unchanged.** No seed and no `force_lle` block; the shipped pair
   stays `a0587ed0a0e34687`. The two-body profile remains a measurement.

## 8. Reproduce

```sh
git clone --shared -q "$PIN" ../sr-r8-phase
git -C ../sr-r8-phase checkout -q 773285b8210f2254ae87d0a14113980fb36990ad
git -C ../sr-r8-phase apply evidence/artifacts/round8_probe.diff

rm -rf src/gen && tar xzf tests/out/r4/gen_r6pair.tar.gz -C src
cmake -S . -B build-r8-ctrl -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r8-phase"
cmake --build build-r8-ctrl -j8
rm -rf src/gen && tar xzf tests/out/r4/gen_r6pc1c9.tar.gz -C src
cmake -S . -B build-r8-seed -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r8-phase"
cmake --build build-r8-seed -j8

. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_FRAMETAP=1826-1840 SNESRECOMP_ENTRYTAP=1828-1836 \
  SNESRECOMP_ANCHORTAP=00C0E2,80C530,80ABBC \
    build-r8-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r8/final_$leg.err
done
PORT_BIN=build-r8-ctrl/ShadowrunSNESRecomp \
PORT_BIN2=build-r8-seed/ShadowrunSNESRecomp \
  ./tests/parity.sh tests/out/probe_dense.txt \
  > tests/out/r8/gate.parity.log 2>&1
python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 \
  > tests/out/r8/gate.txt
python3 tests/phase_anchor_report.py > evidence/artifacts/round8_phase_anchor.txt
```

Each leg must be built with its own gen set in `src/gen` and not rebuilt
afterwards; a rebuild re-reads whatever is there. Restore the live set with
`tools/regen.sh` when done. `tests/out/r8/` is scratch and stays out of git.

## 9. What the next round should do

* **Name the ±40 boundary charge.** It is one instruction's fetches landing on
  the other side of a function entry, the call-site analogue of round 7's
  `$2137` finding. It would be fixed by committing the interpreter's charge
  before entering a callee, but that moves every entry sample and needs its own
  gate; do not fold it into a read-time patch.
* **Anchor the f1832 opening.** The −66 lies between `$80C11F` and the first
  `$80C399`; those two entries are already sampled, so bisect that interval
  with the same anchor hook.
* **Do not chase the latch for the f1830 byte.** This round confirms the latch
  explains the DP `$00`/`$01` cluster, not `$7E00126`; that byte needs the write
  trace, as round 6 used for the later store.
