# Round 9: the f1832 opening is a `$4212` busy poll, priced alike

Date: 2026-11-08. Framework pin
`773285b8210f2254ae87d0a14113980fb36990ad` (`dirty=no`). The probe runs on a
clone of that rev with a small instrumentation diff
(`artifacts/round9_probe.diff`, §7), never on the pin itself. Every number
below is in `artifacts/round9_opening.txt`, generated files-only by
`tests/round9_opening_report.py`.

## 0. One paragraph

Round 8 left the f1832 opening as a `-66` master-clock step between `$80C11F`
and the first `$80C399` entry. This round bisects it with a basic-block tap and
a `$4212` read tap. The step is not a charge convention and not inside
`$81A99D`: from `$81A99D` to the poll entry the two legs are in lockstep apart
from round 8's `±40` call-boundary term, which cancels, and the poll is entered
at exactly the frame edge's `+14`. The `-66` is one extra iteration of the
guest loop at `$809D8E` — `LDA $4212 / AND #1 / BNE` — which spins while the
auto-joypad busy bit is 1. Control takes five reads, the seed four. Each pass
costs `66` master clocks on **both** tiers, because both run this loop on the
interpreter. What differs is the arrival clock: the shared busy window ends at
`655009300`; control's fourth read is `6` clocks before it, the seed's fourth
read is `8` after it. The `14`-clock frame phase straddles a hard edge. No
re-pricing of the compiled path and no seed change removes it; only removing
the frame-edge phase itself would. The shipped pair is unchanged.

## 1. Method

The round-8 probe clone is extended with two hooks:

* `SNESRECOMP_BLOCKTAP=lo-hi` and `SNESRECOMP_BLOCKTAP_PC=lo-hi` — `[block]` at
  every AOT basic-block entry and every interpreted opcode start, with
  `master_cycles`, filtered by frame and pc24 range.
* `SNESRECOMP_JOYTAP=lo-hi` — `[joy]` at every `$4212` read, with the beam
  clock, the remaining auto-joypad busy timer, the beam position, and the byte
  returned.

The two legs are the same pair/demoted gen sets as round 8: the control is the
18-unit pair set (`build-r9-ctrl`, exe `d4e56dad…`), the seed is the 33-unit
`$80C1C9` set with `$80C530`/`$80AD9F` compiled (`build-r9-seed`, exe
`35513381…`). Both exes are probe builds on the clone; they are not the
shipped `a0587ed0a0e34687` pair.

With all taps unset the same binaries reproduce the round-7/round-8 gate
exactly: first state byte `f1830`, `305` of `4,575` frames, `895` bytes,
`crc32_wram` first difference `f1828` (`B615CF19` vs `C912779D`). The
instrumentation is inert (`artifacts/round9_opening.txt` §6).

## 2. The opening is the frame edge's phase

The block ledger starts at the first `$81A99D` entry and stops at the first
`$809D8E` entry. The two sequences share that prefix. `d` is seed minus
control in master clocks:

```
   #  pc       tier     ctrl master   seed master      d
   0  81A99D   aot       655006090     655006144    +54  <-
   2  81AA04   aot       655006234     655006248    +14  <-
  ...
  19  81A914   interp    655008642     655008656    +14
  20  81A917   interp    655008676     655008730    +54  <-
  ...
  27  80C149   interp    655009056     655009070    +14  <-
  28  809D8E   interp    655009096     655009110    +14
```

The `±40` steps are round 8's call-boundary term (one instruction's fetches
landing on the other side of an entry); they appear and cancel at call sites.
At the poll entry `d` is `+14` — exactly the NMI edge's `d` for f1832. So the
opening of the frame is already decided at the frame edge; nothing between the
NMI and the poll adds a net phase.

The `-66` is created inside this stanza:

```
  ctrl: 5 reads at [655009096, 655009162, 655009228, 655009294, 655009360]
        pass costs [66, 66, 66, 66]
  seed: 4 reads at [655009110, 655009176, 655009242, 655009308]
        pass costs [66, 66, 66]

  d at entry: +14
  d at exit:  -52
  change:     -66
```

The guest code (`tests/disasm_span.py 809D8E 16 0 0`):

```
$809D8E  AD1242         LDA 4212
$809D91  290100         AND #$0001
$809D94  D0F8           BNE $9D8E
$809D96  AD1842         LDA 4218
$809D99  8DE601         STA 01E6
$809D9C  60             RTS
```

`$80C149` is `JSR $9D8E`, so this is the whole callee that the round-8 interval
hid. Both tiers run it interpreted, which is why the pass cost is identical.

## 3. The hardware edge is shared; only the sampling straddles it

Every `$4212` read on f1832, from the joy tap:

| leg | beam | timer | beam+timer | val | bit 0 |
| --- | --- | --- | --- | --- | --- |
| ctrl | 655009096 | 204 | 655009300 | `C1` | 1 |
| ctrl | 655009162 | 138 | 655009300 | `C1` | 1 |
| ctrl | 655009228 | 72 | 655009300 | `81` | 1 |
| ctrl | 655009294 | 6 | 655009300 | `81` | 1 |
| ctrl | 655009360 | 0 | — | `80` | 0 |
| seed | 655009110 | 190 | 655009300 | `C1` | 1 |
| seed | 655009176 | 124 | 655009300 | `81` | 1 |
| seed | 655009242 | 58 | 655009300 | `81` | 1 |
| seed | 655009308 | 0 | — | `80` | 0 |

While the timer is non-zero, `beam+timer` is the same `655009300` on both legs:
the auto-joypad busy window is a shared hardware edge (the framework arms a
`4,224`-master-clock timer at `vPos 225, hPos 0`; `runner/src/snes/snes.c`
around L422). Control's last busy read is `6` clocks before the edge; the seed's
fourth read is `8` clocks after it. The `14`-clock phase is larger than the
`6`-clock margin, so control's next read lands past the edge and the loop costs
one more full pass. That is the entire `-66`.

Each `$4212` read advances the beam by `64` master clocks
(`snes_advance_beam(snes, 64, false)` at `snes.c:656`); the loop pass measures
`66` including the other two opcodes. The point is that the number is the same
on both legs: this is not a tier-pricing difference.

## 4. Only f1832 flips in the window

| frame | d at NMI | ctrl reads | seed reads | ctrl first timer | seed first timer | d at `$80C530` |
| --- | --- | --- | --- | --- | --- | --- |
| 1829 | +14 | 1 | 1 | 0 | 0 | — |
| 1830 | −20 | 24 | 24 | 1494 | 1514 | — |
| 1831 | +14 | 1 | 1 | 0 | 0 | — |
| 1832 | +14 | **5** | **4** | 204 | 190 | −52 |
| 1833 | +0 | 1 | 1 | 0 | 0 | −40 |
| 1834 | −32 | 1 | 1 | 0 | 0 | +56 |
| 1835 | +0 | 1 | 1 | 0 | 0 | +0 |
| 1836 | +0 | 1 | 1 | 0 | 0 | +0 |

Only f1832 reads `$4212` a different number of times on the two legs. On f1830
both read it 24 times; on every other frame both read it once. A one-off read
is harmless, and `+14` alone on f1829/f1831 flips nothing, because there the
loop arrives nowhere near the busy window. The flip needs both the phase and a
read position within `66` clocks of the edge.

## 5. What it means for the gate

The first state byte, `$7E00126` at f1830, is dead scratch: round 5 §8 shows
both legs write the same `$0126/$0127` value sequence and the byte sits below
`S`. The readable onset is the f1832 DP cluster, including `$7E00000/$01` —
which `$80C530` derives from the H it latches. The `-52` entry offset at
`$80C530` (frame edge `+14` plus the opening `-66`) moves that latch, and round
7 showed the latch output follows the sample clock exactly.

So the causal chain from the frame edge to the first readable state split is:

```
frame edge (+14)
  -> $809D8E busy poll: +14 entry, 5 reads vs 4, exit -52
  -> $80C530 enters at -52, latches a different H
  -> DP $0000/$0001 differ at the f1832 boundary
```

That is why no read-time patch and no pricing patch is sufficient. Round 7's
`SNESRECOMP_LATCH_SYNC=1` removed the `24`-clock in-body convention term and
made the gate worse (305 → 1,333 frames, 895 → 3,031 bytes): it moves the same
edge. The input to this divergence is the frame's own `±14…32` phase, which
round 8 showed is a small discrete per-frame offset, not accumulating drift.
Removing it means removing that phase, not the poll, the latch, or the seed.

**Decision unchanged:** ship no seed and no `force_lle` block; keep the
round-5 pair `$80C399,$80AAB3` (shipped exe `a0587ed0a0e34687`). Cycle-share
movement alone is not adoption.

## 6. Reproduce

```sh
git clone --shared -q "$PIN" ../sr-r9-blocks
git -C ../sr-r9-blocks checkout -q 773285b8210f2254ae87d0a14113980fb36990ad
git -C ../sr-r9-blocks apply evidence/artifacts/round9_probe.diff

rm -rf src/gen && tar xzf tests/out/r4/gen_r6pair.tar.gz -C src
cmake -S . -B build-r9-ctrl -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r9-blocks"
cmake --build build-r9-ctrl -j8
rm -rf src/gen && tar xzf tests/out/r4/gen_r6pc1c9.tar.gz -C src
cmake -S . -B build-r9-seed -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r9-blocks"
cmake --build build-r9-seed -j8

. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_BLOCKTAP=1832-1832 SNESRECOMP_BLOCKTAP_PC=809000-81FFFF \
    build-r9-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r9/blocks3_$leg.err
  SNESRECOMP_JOYTAP=1828-1836 SNESRECOMP_BLOCKTAP=1832-1832 \
  SNESRECOMP_BLOCKTAP_PC=809000-81FFFF SNESRECOMP_FRAMETAP=1827-1836 \
  SNESRECOMP_ANCHORTAP=00C0E2,80C530 \
    build-r9-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r9/final2_$leg.err
done
PORT_BIN=build-r9-ctrl/ShadowrunSNESRecomp \
PORT_BIN2=build-r9-seed/ShadowrunSNESRecomp \
  ./tests/parity.sh tests/out/probe_dense.txt \
  > tests/out/r9/gate.parity.log 2>&1
python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 \
  > tests/out/r9/gate.txt
python3 tests/round9_opening_report.py > evidence/artifacts/round9_opening.txt
```

Each leg must be built with its own gen set in `src/gen` and not rebuilt
afterwards; a rebuild re-reads whatever is there. Restore the live set with
`tools/regen.sh` when done. `tests/out/r9/` is scratch and stays out of git.

## 7. The framework probe

`artifacts/round9_probe.diff` is the round-8 probe plus the two round-9 hooks;
`artifacts/round9_opening.txt` §7 inlines it. It touches five files:
`runner/src/common_cpu_infra.c` (the block/joy helpers and the anchor set),
`runner/src/cpu_trace.h` (dispatch the block hook), `runner/src/snes.c` (log
`$4212` reads), `runner/src/snes/interp_bridge.c` (the interpreted opcode tap),
and `runner/src/common_rtl.c`.

## 8. What this closes and what it does not

* **Closed:** the f1832 `-66` opening. It is one `$809D8E` busy-poll pass,
  priced `66` on both tiers, triggered by the frame-edge `+14` sampling a
  shared auto-joypad edge. `$81A99D` is exonerated: it is in lockstep apart
  from the cancelling `±40`.
* **Still open:** the `±40` call-boundary term itself (round 8 §9, item 1) is
  still not named; it appears and cancels at several entries in this ledger.
  It has no net effect on the opening, so it is not a gate lever.
* **Still open, but upstream:** the frame-edge `±14…32` phase (round 8). That
  is the only remaining input that can flip this edge, and no seed or pricing
  change removes it.
* The f1830 `$7E00126` byte stays classified as dead scratch (round 5 §8); the
  meaningful onset is the f1832 DP cluster.
