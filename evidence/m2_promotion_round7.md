# Round 7: the counter read is necessary but not sufficient

Date: 2026-11-08. Framework pin
`773285b8210f2254ae87d0a14113980fb36990ad` (`dirty=no`). The probe runs on a
clone of that rev with a small instrumentation diff (`artifacts/
round7_latch_phase.txt` §5), never on the pin itself. Every number below is in
`artifacts/round7_latch_phase.txt`, generated files-only by
`tests/latch_phase_report.py`.

## 0. One paragraph

Round 6 §9 said the next lever was tier pricing: make the compiled path charge
the same cycles at `$80C530`'s `LDA $2137` so the counter returns the same
phase on both tiers. This round measures that read instead of assuming it. The
compiled body does latch 24 master clocks (6 dots) later than the interpreter
when both enter the body at the same clock — that is a real convention
difference and it is exactly the `LDA`'s own four bus transfers. But the two
tiers also enter the body at clocks that differ by up to 56 master clocks, so
the latched H still moves by up to 20 dots. Removing the 24-clock convention
term alone (`SNESRECOMP_LATCH_SYNC=1`) does not help: the gate's first state
divergence stays at `f1830` and the differing-frame count grows from 305 to
1,333. Pricing the read is necessary, not sufficient; the guest timeline up to
the read has to be path-invariant first. **Nothing ships in this round and the
round-6 decision stands.**

## 1. The question

Round 6 attributed the `f1828` gate to two compiled bodies, `$80AD9F` and
`$80C530`, and its write trace named the store: `bank_80_C530_M0X0` writes
`$0001=82` at `f1832` where the interpreter writes `08` at `$80C54D`. The
disassembly shows `$80C530` reads `$2137`, `$213C`, `$213D` and mixes them into
DP `$00`/`$01` and `$1D04`, so the standing explanation was a phase difference
at the counter read. Round 6 §9 proposed fixing it at the read. The question
here: **when the same guest `LDA $2137` executes on the two tiers, at what beam
position does each latch, and does equalising that position restore the gate?**

## 2. The probe

Two executables on one framework clone:

| leg | gen set | `$80C530` | exe |
| --- | --- | --- | --- |
| ctrl | `gen_r6pair` (283 nodes, 18 units) | interpreted | `ef5d2102bce8c3ac` |
| seed | `gen_r6pc1c9` (486 nodes, 33 units) | compiled | `79dfda73c2e41980` |

The clone carries two env-gated hooks, both inert unless set:

* `SNESRECOMP_PHASETAP` logs a real function entry into `$80C530` with the
  cumulative `master_cycles` (the trace-off `cpu_trace_func_entry` inline is
  routed through `r7_tap_func_entry`; a `WatchdogCheck` hook was tried first
  and rejected because it also fires on interior blocks of the same function);
* `SNESRECOMP_LATCHLOG` logs the `$2137` read with `master`, the interpreter's
  uncommitted `pending` master, the resulting `sync`, and the latched `H`/`V`.
  `SNESRECOMP_LATCH_SYNC=1` additionally advances the interpreted read by its
  pending master.

A third, deliberately wrong hook is part of the record: the first attempt
coupled the phase tap to `WatchdogCheck` and logged interior blocks as
entries. It was caught because the control (whose `$80C530` is interpreted)
printed `tier=aot` lines after one rebuild picked up the other leg's `src/gen`.
Both lessons are now in the tools: the tap is on function entry, and every
build is anchored to its own gen set before it runs.

## 3. What the read does on each tier

`artifacts/round7_latch_phase.txt` §1, first entry and first `$2137` read per
frame, `tests/out/probe_dense.txt`. `d_*` is seed minus control, in master
clocks (Δ H is printed in counter counts):

| frame | ctrl entry | ctrl latch | seed entry | seed latch | d_entry | d_latch | d_h |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1832 | 655291846 | 655291910 | 655291794 | 655291882 | −52 | −28 | −7 |
| 1833 | 655644780 | 655644844 | 655644740 | 655644828 | −40 | −16 | −4 |
| 1834 | 656009800 | 656009864 | 656009856 | 656009944 | +56 | +80 | +20 |
| 1835 | 656370924 | 656370988 | 656370924 | 656371012 | 0 | +24 | +6 |
| 1836 | 656716844 | 656716908 | 656716844 | 656716932 | 0 | +24 | +6 |

Two facts, both exact on every row:

1. **The in-body charge is constant and tier-dependent.** The latch is 64
   master clocks after entry on the control and 88 on the seed. The 24 is the
   `LDA $2137`'s own transfers: the compiled body charges its three fetch
   cycles before the read and the fourth (the paced data read) inside
   `cpu_read8_paced`, then `ReadRegOpenBus` advances the beam to
   `cpu->master_cycles`; four transfers at six clocks each is 24. The
   interpreter commits `s_interp_bus_master` only after `interp816_runOpcode`
   returns, so at the same read it sits one instruction early.
2. **The latch follows the sample time exactly.** `d_latch == d_entry + 24` on
   every row, and `d_h == d_latch / 4`, because the H counter advances one
   count per four master clocks. The latched value is a direct function of
   `sync`; it is not a bookkeeping residual. The row pair `f1835`/`f1836` is
   the cleanest: same entry clock, compiled latch +24, H +6 dots.

The rows do not share one `d_latch` (−28, −16, +80, +24, +24). The entry
clocks themselves differ by up to 56 master clocks, so the frame reaches the
body at a different point on the two tiers. That is the phase term.

## 4. The fix attempt

`SNESRECOMP_LATCH_SYNC=1` makes the interpreted read advance the beam by its
pending master, removing the 24-clock convention term. It leaves
`d_latch = d_entry`: +24 → 0 on `f1835`/`f1836`, +80 → +56 on `f1834`, but
−28 → −52 and −16 → −40 on `f1832`/`f1833`. On the same binary pair and route
(`artifacts/round7_latch_phase.txt` §3):

| gate | first state diff | frames differing | bytes |
| --- | ---: | ---: | ---: |
| default | f1830 | 305 of 4575 | 895 |
| `LATCH_SYNC=1` | f1830 | 1333 of 4575 | 3031 |

`crc32_wram` still first differs at `f1828` on both. The fix is rejected.

## 5. What this settles

1. **"Price the counter read" is not the lever.** The read convention is a
   real 24-clock difference and worth fixing for its own sake, but it is not
   what moves the gate. The frame reaches `$80C530` 0–56 master clocks apart,
   and that entry phase, not the read, sets the latched H.
2. **The pre-read timeline is the target.** A change that makes the guest
   timeline path-invariant across the seam — the direction the upstream seam
   report (§5 item 3) names — would remove the entry-phase term. That is a
   larger framework change and it changes what `cpu->cycles` means; it should
   not be made silently.
3. **The earliest divergence still is not this latch.** The first non-label
   byte is `$7E00126` at `f1830`; the first `$80C530` entry on both tiers is
   `f1832`. This latch explains the DP `$00`/`$01` cluster that opens at
   `f1832` (the store round 6 traced), not the `f1830` byte.
4. **Decision unchanged.** No seed and no `force_lle` block; the shipped pair
   stays `a0587ed0a0e34687`. The two-body profile remains a measurement.

## 6. Reproduce

The probe is a clone at the pin, not the pin:

```sh
git clone --shared -q "$PIN" sr-r7-latch
git -C sr-r7-latch checkout -q 773285b8210f2254ae87d0a14113980fb36990ad
git -C sr-r7-latch apply "$OLDPWD/evidence/artifacts/round7_probe.diff"
```

Build each leg against its own archived gen set, in this order, and do not
rebuild afterwards (a rebuild re-reads whatever `src/gen` holds):

```sh
rm -rf src/gen && tar xzf tests/out/r4/gen_r6pair.tar.gz -C src
cmake -S . -B build-r7l-ctrl -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r7-latch"
cmake --build build-r7l-ctrl -j8
rm -rf src/gen && tar xzf tests/out/r4/gen_r6pc1c9.tar.gz -C src
cmake -S . -B build-r7l-seed -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r7-latch"
cmake --build build-r7l-seed -j8
```

The probe lines and the two gates:

```sh
. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_PHASETAP=1 SNESRECOMP_LATCHLOG=1 \
  SNESRECOMP_LATCHLOG_FRAMES=1830-1836 \
    build-r7l-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r7/inv_$leg.err
done
PORT_BIN=build-r7l-ctrl/ShadowrunSNESRecomp \
PORT_BIN2=build-r7l-seed/ShadowrunSNESRecomp \
  ./tests/parity.sh tests/out/probe_dense.txt > tests/out/r7/gate_base.parity.log 2>&1
python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 \
  > tests/out/r7/gate_base.txt
SNESRECOMP_LATCH_SYNC=1 PORT_BIN=build-r7l-ctrl/ShadowrunSNESRecomp \
PORT_BIN2=build-r7l-seed/ShadowrunSNESRecomp \
  ./tests/parity.sh tests/out/probe_dense.txt > tests/out/r7/gate_sync.parity.log 2>&1
python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 \
  > tests/out/r7/gate_sync.txt
python3 tests/latch_phase_report.py > evidence/artifacts/round7_latch_phase.txt
```

`tests/out/r7/` is scratch and stays out of git. The probe patch is committed
as `artifacts/round7_probe.diff` and is also inlined in §5 of the artifact. The
artifact generator reads the raw logs and that diff only.

## 7. What the next round should do

* **Measure the entry phase, not the read.** Pick two common guest points in
  the same frame — a frame-kernel entry and `$80C530`'s entry — and find the
  first one at which the two tiers' `master_cycles` differ. The entry deltas
  here are 0, ±40, ±56; they should be locatable to a block or an interrupt
  boundary.
* **Do not retry a read-time-only patch.** `LATCH_SYNC` is measured and
  rejected; a variant that shifts the compiled read earlier by 24 would have
  the same shape with the sign reversed.
* **Keep the two-body regression pair.** `$80AD9F`/`$80C530` compiled is still
  the check any timing change must pass, and it must be checked with a state
  scan, not a cycle share.
