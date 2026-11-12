# Round 10: the frame-edge phase is bounded quantization, and that closes the seed hunt

Date: 2026-11-08. Framework pin
`773285b8210f2254ae87d0a14113980fb36990ad` (`dirty=no`, working tree clean,
untouched this round). No new instrumentation and no rebuild: the round-9 probe
executables were run again with their frame tap open over the whole route.
Every number below is in `artifacts/round10_frame_edge_phase.txt`, generated
files-only by `tests/round10_frame_phase_report.py`.

## 0. One paragraph

Round 9 ended on one input: the seed's f1832 divergence is a `+14` offset of the
frame edge, which moves a `66`-clock `$4212` busy poll across an auto-joypad
edge both legs agree on. That offset was only ever measured in one window, so
this round measures it everywhere. Over `4,574` frame boundaries it is `0` on
`4,095`, never leaves `−58…+70`, appears in `241` separate runs whose longest is
`16` frames, and both legs cover exactly `1,634,601,236` master clocks across
the route — no leak, no accumulation. The guest cycle counter `cpu->cycles` in
the same runs does run away (`−2,609…+141`, ending at `−1,309`), which is the
distinction `upstream_seam_cycle_bookkeeping.md` draws. The phase split starts
at f1767, `63` frames before the first differing state byte at f1830, so it
cannot be an effect of the divergence. Frame lengths confirm the mechanism: the
mode is exactly the `357,368` deadline on both legs, the means agree to six
decimal places, and the deadline check is only tested between slices in the
pinned `generic_frame_driver.c`. So the offset is a quantum of where that test
first sees the deadline, and it is not a quantity the title can hold at zero.
Four levers exist; all four are closed, and the only one that would work is a
change to the pinned frame driver. Decision unchanged: ship no seed, no
`force_lle` block, keep the round-5 pair `$80C399,$80AAB3` (exe
`a0587ed0a0e34687`), and this line of investigation is at its end.

## 1. Method

Same two legs as round 9, same probe executables, which still exist even though
the probe clone was deleted: control is the 18-unit pair set (`build-r9-ctrl`,
exe `d4e56dadd93b9dcc`), the seed is the 33-unit `$80C1C9` set with `$80C530`
and `$80AD9F` compiled (`build-r9-seed`, exe `355133810fb5efac`). Nothing was
configured or built this round, and `src/gen` was not swapped, so the live tree
is still the shipped set.

The frame tap prints `master_cycles` and `cpu->cycles` where `snes_frame_counter`
advances, i.e. the achieved frame boundary:

```
[frame] f=1827 master=653575616 trunk=63620697
```

One gotcha cost a wasted leg: the tap's on-test is `e[0] && e[0] != '0'`, so
`SNESRECOMP_FRAMETAP=0-4600` prints **nothing**. The range has to start at `1`.

With every tap unset these same binaries reproduce the round-7 and round-8 gate
exactly — first state byte f1830, `305` of `4,575` frames, `895` bytes,
`crc32_wram` first difference f1828 (`B615CF19` vs `C912779D`) — so the
instrumentation is inert and the boundaries below are the shipped ones (§6 of
the artifact). The tap also sits on the edge itself rather than somewhere after
it: `generic_frame_driver.c` mentions `master_cycles` on exactly two lines, the
deadline at `:79` and the test at `:103`, so the PPU draw that runs between the
frame driver and the tap charges nothing.

`d` is seed minus control, the sign convention of rounds 8 and 9.

## 2. Bounded, and it snaps back

```
  d(boundary) range     -58 .. +70
  d == 0                  4095 of 4574 frames
  |d| <= 32               4510 frames        |d| > 32   64 frames
  separated non-zero runs 241, lengths 1x152 2x47 3x16 ... longest 16
  elapsed over 4573 boundaries  control 1634601236 == seed 1634601236
  d at first / last frame   +0 / +0
```

An accumulating charge would show one long run and a growing offset. This shows
`241` short runs that close, a value that never leaves a `128`-clock window, and
both legs covering the same number of clocks end to end. The `+14` at f1832 that
round 9 chased is one sample of that distribution.

## 3. The phase split is older than the state split

The gate's first frame with a differing state byte is f1830. Of the `1,829`
boundaries at or before f1829 — machine state still byte-identical on both legs
— `16` already differ in phase, range `−26…+40`, and the first non-zero boundary
offset is at **f1767**, `63` frames earlier. Phase precedes state, so the phase
is not downstream fallout of the divergence; it is the input.

It also means the phase difference is not rare. It is non-zero on `479` of
`4,574` boundaries route-wide. A flip needs a second condition — a guest read
within one poll pass (`66` clocks) of a hardware edge — and f1832 supplies it.

## 4. Frame lengths: same clock budget, quantized landing

```
  deadline                        357368 master clocks
  mode of achieved length         357368 (control 1110 frames, seed 1113)
  mean achieved length            357446.15 both legs, difference +0.000000
  d(frame length) == 0            3915 of 4573 frames
  non-zero values                 51 distinct, all even, +-2 .. +-80
  deviation from the deadline     -76 .. +76 control, -72 .. +68 seed
  route pauses (f194/195, f475/476, f1316/1317)  identical on both legs to the clock
```

The frame driver computes `frame_end = master_cycles + 357368` from wherever the
previous frame ended, takes the NMI once before its slice loop, services a
pending IRQ after each slice, and tests `master_cycles >= frame_end` only at the
top of a slice (`runner/src/generic_frame_driver.c`,
`snes_generic_frame_driver_run_frame`, lines 78-120). So the achieved boundary is
the first instruction boundary at or after the deadline that the loop gets a
chance to notice, and the overshoot is a whole number of block or interrupt-take
lengths. Compiling a different body changes which block the test first becomes
true inside, which changes the overshoot by one quantum. The route's three
parked waits are the exception that proves the point: there the loop breaks on
`interp_bridge_lle_took_wai()` before the deadline test, and both legs produce
the identical long/short pair.

## 5. The counter that *does* drift is the one that cannot be compared

Same runs, same frames:

```
  d(g_cpu.cycles)   -2609 .. +141, zero on only 1766 of 4574, ends at -1309
  d(master_cycles)    -58 ..  +70, zero on 4095 of 4574, ends at     +0
```

`upstream_seam_cycle_bookkeeping.md` is why: `cpu->cycles` is the guest-side
seam counter, re-based at tier transitions, and it is not comparable across
tiers. Only `master_cycles` is, and only `master_cycles` is bounded. Any future
phase argument has to be made in master clocks.

## 6. The onset window, re-read at route scale

| frame | d(boundary f−1) | d(NMI `$00C0E2`) | d(first `$80C530`) | `$4212` reads | `$80C530` tap sites | `$80C530` tier ctrl/seed |
| --- | --- | --- | --- | --- | --- | --- |
| 1826 | −26 | −26 | — | 0 / 0 | 0 / 0 | — |
| 1827 | +14 | +14 | — | 0 / 0 | 0 / 0 | — |
| 1828 | −4 | −4 | — | 1 / 1 | 0 / 0 | — |
| 1829 | +14 | +14 | — | 1 / 1 | 0 / 0 | — |
| 1830 | −20 | −20 | — | 24 / 24 | 0 / 0 | — |
| 1831 | +14 | +14 | — | 1 / 1 | 0 / 0 | — |
| 1832 | +14 | +14 | −52 | **5 / 4** | 2 / 1 | interp / aot |
| 1833 | +0 | +0 | −40 | 1 / 1 | 5 / 1 | interp / aot |
| 1834 | −32 | −32 | +56 | 1 / 1 | 1 / 1 | interp / aot |
| 1835 | +0 | +0 | +0 | 1 / 1 | 1 / 1 | interp / aot |
| 1836 | +0 | +0 | +0 | 1 / 1 | 1 / 1 | interp / aot |
| 1837 | −6 | −6 | −6 | 0 / 0 | 2 / 1 | interp / aot |

`$00C0E2`, the NMI handler, is interpreted on both legs everywhere; `$80C530` is
interpreted on the control and compiled AOT on the seed, which is the only
difference between the legs. The entry column is a **tap-site** count, not a
call count: the AOT hook fires only where a compiled function's own entry pc is
the anchor, so a pass that enters the seed's root mid-body is invisible to it,
while the interp hook fires at every opcode start. The offset columns compare
the first entry each leg can report at that pc.

The boundary offset equals the NMI entry offset on `12` of `12` frames. That is
the cross-check on the tap's placement: the end of frame f−1 and the NMI that
starts frame f are the same master clock, so the `+14` is the edge itself, not
an artefact of where the line is printed.

The auto-joypad busy window ends at `beam + autoJoyTimer = 655009300` on both
legs in f1832 (and `654294564` in f1830). Round 9's read table holds: control's
fourth read is `6` clocks before the edge and loops, the seed's fourth is `8`
after it and exits. One pass is `66` master clocks on both tiers, and that pass
is the whole `−66`.

## 7. Reproduce

The probe tree is gone; `artifacts/round9_probe.diff` is what rebuilds it (round
9 §6 has the build recipe). Given the two existing executables, this round needs
only:

```sh
. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_FRAMETAP=1-4600 \
    build-r9-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null \
      2>tests/out/r9/frames_$leg.err
done
python3 tests/round10_frame_phase_report.py \
  > evidence/artifacts/round10_frame_edge_phase.txt
```

The report reads only those files plus the round-9 `final2_*` taps, `gate.txt`
and `gate.parity.log`; it runs no leg, no `tools/regen.sh`, no cmake. Two runs
of the generator are byte-identical.

## 8. What this closes

* **Closed: the "is it drift?" question.** It is not. Bounded `−58…+70`, zero on
  `89.5 %` of boundaries, `241` runs that all close, identical end-to-end clock
  count. The `±32` per-frame offsets of round 8 are samples of a quantized
  deadline landing, not a charge that leaks.
* **Closed: the last input to the f1832 flip.** The only remaining input is this
  phase, and the four ways to move it are all shut:
  1. make the seed's block boundaries coincide with the control's at every frame
     — impossible for a different body set (`479` non-zero boundaries);
  2. make the guest's sampling of the edge phase-insensitive — round 7's
     read-time change is the only version of this available to the title and it
     made the gate worse (`305` → `1,333` frames, `895` → `3,031` bytes);
  3. price the seed's bodies so the overshoot matches — tuning the cycle model
     to a one-frame coincidence, with round 8 §9's unnamed `±40` call-boundary
     charge still unnamed (round 9 saw it appear and cancel, so it is not a
     lever either);
  4. move the deadline check to instruction granularity so the overshoot stops
     being quantized — that is `runner/src/generic_frame_driver.c`, the pinned
     framework, and the pin stays clean.
* **Decision:** no seed adopted, no `force_lle` block, shipped pair stays
  `$80C399` + `$80AAB3`, exe `a0587ed0a0e34687`. The gap-seed question is
  answered for this route: with the frame driver as pinned, a demoted body set
  is a coin flip on a hardware edge, and round 6's cycle-share gains were that
  coin landing right.
* **If this is ever revisited**, it belongs upstream: give the frame driver a
  deterministic frame-boundary contract (charge to the deadline exactly, or
  deliver the vblank edge at a fixed master clock) and re-run the seed table.
  Nothing on the title side can substitute for it.
