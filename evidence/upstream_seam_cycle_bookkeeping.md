# Upstream report: what the AOT/interpreter seam does to `cpu->cycles`

Date: 2026-11-08. Framework pin: `773285b8210f2254ae87d0a14113980fb36990ad`
(`framework_pins.txt`, dirty=no). Everything below is either a line of the
pinned framework or a number from a committed artifact under
`evidence/artifacts/`. This is a report, not a patch.

## 0. One paragraph

At a compiled/interpreted seam the two counting accumulators part company.
In the samples where the probe's guest state (direct page, live stack, latch
bytes) is still identical, `master_cycles` moves by at most a few tens of
clocks at a parked frame boundary, while `cpu->cycles` drifts down by `−0.14 k`
at the parity onset to `−2.8 k` on the settled combat route. That is not a
mis-charged opcode — the framework's own directed model diff already closed
that hypothesis (`a7_aot_split_hunt.md` §8.4). It is two structural facts about
the counters: (a) `master_cycles` is
*pinned by the scheduler* at a frame boundary (357,368 clocks/frame), so
equality there is a property of the budget, not of the paths; and (b)
`cpu->cycles` is charged by two different *models* — the interpreter's runtime
opcode result (`interp816_runOpcode`) and the AOT emitter's gen-time constant —
so the only thing it can record across a seam is how much guest work each path
fitted inside the same budget, which is exactly what a seam changes. The
useful cross-tier rulers on this title are guest instructions and WRAM, not
either cycle counter.

## 1. The measurement

Two probes, both on the pinned framework, both comparing a directive-bearing
control against the same tree plus one compiled function (`$80C1C9`; the trace
builds are `build-tr-ctrl` and `build-tr-seed`).

**Parity route, at the onset** (`artifacts/round5_gate_state.txt`,
`tests/latch_state.py --frames 1829,1831,1833,1835,1837`):

| frame | `master_cycles` delta | `cpu_cycles` delta | DP | live stack |
|---|---:|---:|---|---|
| f1830 | −20 | −149 | identical | identical |
| f1832 | +14 | −144 | identical | identical |
| f1834 | −32 | **−1,623** | differs | `$013A 3B→11` |
| f1836 | +0 | −1,623 | differs | identical |
| f1838 | +16 | **−1,840** | differs | `$013A 3B→11` |

The cycle delta jumps by `−1,479` at the same frame the direct page first
differs. The master delta stays inside `−32…+16` across the same samples.

**Combat route, after the run has settled** (`artifacts/round5_latch_state.txt`,
`tests/latch_state.py --frames 14662,14671,14701,16181,16201`):

| frame | `master_cycles` delta | `cpu_cycles` delta |
|---|---:|---:|
| f14663 | −2 | −2,565 |
| f14672 | −8 | −2,571 |
| f14702 | +0 | −2,598 |
| f16182 | +18 | −2,784 |
| f16202 | −12 | −2,788 |

So the drift is present from the first sample, grows in small steps (`−2,565`
to `−2,788` cycles over the 1,539 frames between the first and last sample,
about `−220`), and the master delta never leaves a two-digit window. On the
parity route the drift's jump and the sampled state divergence begin together
at `f1834`; on the combat route the drift is a persistent offset with no
further state effect at those samples.

The value stream at the seam is in `artifacts/round5_latch_split.txt`: at
`f14664` the control's first `$0126` write is `9E` from `interp@$809E00`, the
seeded leg emits one transient `80` from `pc=0x809E39` (a compiled body, no
function name) and then `9E` from `interp@$809E39`. The next write is `9E` on
both legs. The seed's compiled decompressor is one store phase ahead and
resynchronises on the following store.

## 2. The two counters, and where each is charged

Both live in `CpuState` (`runner/src/cpu_state.h:165,177`):

- `uint64_t cycles` — documented as cumulative 65816 CPU (bus) cycles.
- `uint64_t master_cycles` — cumulative 21.47727 MHz master clocks, the
  region-weighted companion.

### 2.1 Interpreter side

One opcode is charged in `runner/src/snes/interp_bridge.c:2727-2730`:

```c
uint64_t _master = s_interp_bus_master + (uint64_t)_internal * 6u;
cpu->cycles        += (uint64_t)_cyc;
cpu->master_cycles += _master;
```

`_cyc` is the value `interp816_runOpcode()` returns — the runtime instruction
cost (`runner/src/snes/interp816.h:84`: "runs one opcode; returns cycles").
`_master` is built from two pieces: `s_interp_bus_master`, the sum of
`cpu_region_speed(addr)` over every real bus transfer of the opcode
(`bridge_timing_bus`, `interp_bridge.c:206-227`), plus
`internal_cycles × 6` for cycles that make no bus access.

Two shortcut paths in the same function also charge `cycles`, and they matter
for cross-tier comparisons:

- the idle-poll replay, which advances the beam by charging a recorded
  per-iteration `(cyc, master)` pair without executing each iteration
  (`interp_bridge.c:2141-2143`);
- the Star Ocean `$00D9` work-wait specialization, which runs the known
  `LDA $00D9 / BEQ` wait with the same timing as the full dispatch but without
  the dispatch (`interp_bridge.c:1800-1883`).

Those charges exist only on the interpreter side. A compiled body has no
idle-poll replay and no `$00D9` specialization.

### 2.2 AOT side

Generated code charges a per-instruction constant inline. An example from the
shipped set's archived generated file (`artifacts/round5_gen_r5pair.tar.gz`,
`gen/bank80_v2.c:253-257`):

```c
if (cpu->D & 0xFF) { cpu->cycles += 1; cpu->master_cycles += ((g_memsel && (cpu->PB & 0x80)) ? 6 : 8); }
cpu->cycles += 4;
cpu->master_cycles += 2 * ((g_memsel && (cpu->PB & 0x80)) ? 6 : 8);
uint16 _v1 = cpu_read_x16(cpu);
cpu_write16_paced(cpu, 0x00, (uint16)(cpu->D + 0x003e), _v1);
```

`cpu->cycles += 4` is the gen-time CPU-cycle constant
(`recompiler/snes_cycles.py::instr_static_cycles`, folded per block by
`block_static_cycles`). The master charge is split: fetch bytes at the code
region's speed in the block, and every data/stack/pointer transfer re-priced
at runtime by `cpu_read8/16_paced` / `cpu_write8/16_paced`
(`runner/src/cpu_state.c:755-816`), each through the same
`cpu_region_speed()` (`cpu_state.c:354-369`). That shared pricer is the
bus-exact work a4 shipped (`a4_bus_pace.md` §1).

A taken branch adds both counters (`cpu->cycles += 1; master += 6`, e.g.
`gen/bank80_v2.c:842` in the same archive), and the RTS emitter charges
`cycles += 6` while popping its return frame through paced reads
(`gen/bank80_v2.c:946-948`). So the AOT block is not missing data-transfer
cycles in the normal case.

### 2.3 The one master-only charge

DRAM refresh is the exception, and it is deliberate. `snes_refresh_charge()`
(`runner/src/common_cpu_infra.c:890-910`) advances `g_cpu.master_cycles` by
`40 × lines` and never touches `cycles`. The same function is called from the
interpreter after each opcode (`interp_bridge.c:2733`) and from
`WatchdogCheck()` before each generated block (`common_cpu_infra.c:933`),
with a watermark (`g_refresh_charged_upto`) so the total tax is a function of
elapsed master time, not of how often it is sampled. A reader might suspect
refresh first; the artifact rules it out as the mover of `cycles`
because it cannot write that field at all, and as a source of `master` drift
because the watermark makes the total path-independent.

## 3. Why only `cycles` can move

`master_cycles` equality at a `run_to_frame` boundary is not a measurement of
the paths. The host pins one frame to 357,368 master clocks, and
`a7_aot_split_hunt.md` §8 (item 1) measured the step at exactly 714,736 per two
frames on both legs. A parked boundary therefore *forces* the same
`master_cycles`; the per-instruction charges can differ inside the frame and
still sum to the budget. a7 says this explicitly: "Identical master at parks
does NOT mean the paths charge the same master per instruction."

`cycles` has no such anchor. It is the sum of what each path says it did, and
the two models are charged at different times:

- the interpreter charges the runtime result of the opcode it actually
  executed;
- the AOT body charges its gen-time constant when the block runs, plus the
  conditional runtime guards (D.l, page cross, taken branch), plus any
  skipped-emit compensation the emitter folded into the static charge.

If the seam moves *which instruction the frame ends on*, the same master
budget contains a different amount of executed guest code on the two paths,
and `cycles` is the counter that shows it. a7 §8 (item 3) called the same
thing "the floor leg fits ~1,170 more CPU cycles (200+ instructions) of work
inside the same master budget" on the full-AOT pair.

Crucially, a7 §8.4 already tested and rejected the natural explanation. It
ran directed opcodes through `interp816` and compared them with the folded
authority model (`runner/src/snes/snes_cycles.h`, generated from
`recompiler/snes_cycles.py`) under the emitter's predicates: every delta was
`+0`, including the `$80:9DE8` body's opcode mix and the page-cross variants.
"The compiled path mis-accounts CPU cycles" is closed. The drift this report
measures is therefore not a per-opcode charge error; it is the accumulated
difference in *how far the two paths got* inside the budget.

The sign is consistent with that reading. At the parity onset the AOT leg is
already `−144` cycles at f1832 and jumps to `−1,623` at f1834, the frame the
direct page first differs. On the combat route the offset is larger (`−2.6 k`
to `−2.8 k`) because the seeded decompressor has run many more times by
f14663.

## 4. What this is not

- **Not a wrong value.** The `$0126` transient in §1 is one store, from a
  different instruction in the compiled body, and the next store writes the
  same value on both legs. `artifacts/round5_latch_state.txt` shows DP, `S`,
  and the live stack identical at every boundary around the combat-route split,
  with only bytes below `S` differing.
- **Not the persistent WRAM split.** On the parity route the gate's first
  checksum difference is `frame_001828` (label-inclusive; see
  `m2_promotion_round5.md` §8), six frames before the probe's first sampled
  direct-page difference at `f1834`. The probe localises the state change but
  does not name the writing body.
- **Not a per-opcode charge error.** Closed by a7 §8.4's directed 22-case
  model diff.
- **Not DRAM refresh.** Refresh writes `master_cycles` only
  (`common_cpu_infra.c:906`), and its watermark makes the total path
  independent.

## 5. What the framework could do with this

These are options in the order I would try them; none is required for the
port, which gates on WRAM and ships the LLE reference.

1. **Label the counters in the ledger.** The port's `execution_share` divides
   `interp816_cycles_total()` by `g_cpu.cycles`
   (`runner/src/snes/interp_bridge.c:4012-4027`). Those are both CPU-cycle
   units, but the denominator is the mixed counter this report is about: its
   AOT part is charged from gen-time constants, so it carries a few thousand
   cycles of seam bookkeeping. That is small against the round-5 total
   (`cpu_cycles 956,096,571`), but a one-line header in the report ("cycles are
   tier-modelled; master is transfer-priced and frame-pinned") would stop a
   reader from taking the ratio as elapsed time. The framework already says the
   master accounting "differs between the interp and compiled models" in the
   co-sim guard's comment (`interp_bridge.c:2738-2742`); the same caveat
   belongs on `cycles`.
2. **If a cross-tier work ruler is wanted, do not use either counter.** Use
   interpreted instruction count (`interp816_insns_total()` /
   `tier2_capture`) or WRAM. This is what the port's promotion gate already
   does, and it is why the round-5 seeds are decided on state, not share.
3. **If `cycles` must become path-invariant**, the change is the same shape
   a4 applied to master: make the AOT constant cover only the non-transfer
   part and charge `cycles` per real transfer in the paced accessors, or
   (cheaper) recompute `cycles` from the same transfer model at block exit.
   The decomposition a4 already tests,
   `instr_static_cycles == length + rd + wr + internal`, is the invariant to
   extend; add a test that sums both counters over a directed block through
   both tiers and asserts equality. Note this changes what `cycles` means; it
   should not be done silently.
4. **The diagnostics already exist at two granularities.**
   `SNESRECOMP_CYC_WATCH="lo-hi"` (`interp_bridge.c:2763-2788`) prints the
   interpreter's per-opcode decomposition (`cyc`, `bus_xfers`, `bus_master`,
   `internal`, `master_delta`) for a PC range.
   `SNESRECOMP_AOTBLK="lo-hi"` (`cpu_trace.c:1233-1250`) prints the AOT side's
   per-block entry (frame, `pc24`, cumulative `master_cycles`) for a frame
   window. §8 runs them together. What is still missing is an
   instruction-level AOT charge log inside a block: AOTBLK logs block entries,
   not instructions.

## 6. Reproduce

The two probe artifacts are produced by the same trace builds and tools the
round-5 record uses:

```sh
SNESRECOMP_ROOT=<pin> \
WT_LEGS=ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/ShadowrunSNESRecomp \
  python3 tests/latch_writer.py --route tests/scripts/bisect_h8.txt \
      --park 16200 --addrs 0x126,0x127
SNESRECOMP_ROOT=<pin> \
WT_LEGS=ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/ShadowrunSNESRecomp \
  python3 tests/latch_state.py --route tests/scripts/bisect_h8.txt \
      --frames 14662,14671,14701,16181,16201
SNESRECOMP_ROOT=<pin> \
WT_LEGS=ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/ShadowrunSNESRecomp \
  python3 tests/latch_state.py --route tests/out/probe_dense.txt \
      --frames 1829,1831,1833,1835,1837
```

`build-tr-ctrl` is the directive-bearing control; `build-tr-seed` is the same
program plus the `$80C1C9` generated body (`GS_80C1C9`). Both are the same two
programs as `build-r5base` / `build-s80C1C9`, built with
`-DSNESRECOMP_ENABLE_TRACE=ON`.

## 7. The open question worth one experiment

The drift and the sampled state split begin on the same frame on the parity
route (f1834), but the drift is already `−144` at f1832, where the probe's
DP / live stack / latch bytes still agree (the gate's label-inclusive WRAM
checksum differs from f1828, so "state matches" here means the probe's sampled
bytes, not the gate). That ordering — cycles first, sampled state two frames
later — is the falsifiable part. With the framework's AOT block log (§5 item 4),
if the control's CYC_WATCH rows and the seeded leg's AOT rows show the same
executed-instruction set up to f1832 while `cycles` differs, then the difference
is purely bookkeeping (the two models price the same instructions differently in
a way the directed test did not cover). If the sets differ at f1832, then the
seam moved work inside the budget before the probe's sampled bytes moved, and
the f1834 split is that work crossing a byte the probe can see. The experiment
distinguishes "the counter is wrong" from "the counter is honest about a
different phase", and only the first would need a framework fix. It is run in
§8: the executed block set changes at f1832, so the counter is honest about a
different phase there; a small sub-block residual at f1830 remains.

## 8. The experiment, run

`tests/seam_phase.py` reads the two framework probes on the parity route
(`tests/out/probe_dense.txt`), run on the round-5 trace pair:

- `build-tr-ctrl` (directive-bearing control, no `$80C1C9` body) with
  `SNESRECOMP_AOTBLK=1820-1834`, and with `SNESRECOMP_CYC_WATCH` over the
  seed's call-graph closure in three ranges;
- `build-tr-seed` (same tree plus `$80C1C9`) with
  `SNESRECOMP_AOTBLK=1760-1840`.

The raw logs are `tests/out/r5seam/*.err`; the generated text is
`artifacts/round5_seam_phase.txt`; the exact commands are in §8.1. The script
runs no leg.

Three results:

1. **The common AOT code does not move.** The two AOT sets share 92 PCs. All
   1,610 common block entries in 1820-1834 have the same frame and PC in both
   logs, and no frame's common-entry count differs. The 6 control-only PCs and
   the 39 seed-only PCs in the narrow window are coverage, not phase: they are
   the nodes the seed's analysis compiles or demotes.
2. **The seed's compiled cluster moves by two entries at f1832.** The seed's
   AOT-only PCs are the `$80C1C9` closure (179 in the wide window; the control
   interprets them). Their per-frame block counts match the control's
   interpreted rows in `$80AB00-$80AE00` exactly, and in
   `$80C300-$80C600` they first differ at f1832 (183 vs 181) and f1833
   (195 vs 187). The f1762/f1763/f1766 differences are the boot/transition
   boundary and lie outside the onset; f1837's 2-entry difference is after the
   state split.
3. **The park probe puts the cycle delta at the same boundary.** f1830 `−149`,
   f1832 `−144` (DP identical), f1834 `−1,623` (DP differs), f1838 `−1,840`
   (`artifacts/round5_gate_state.txt`).

So the experiment selects the second branch of §7: the executed set changes at
f1832, the frame where the counter is already `−144` and the probe's sampled
state still matches. The counter is not pricing identical work two ways at that
boundary; it is recording that the seam moved the frame's work. The f1834 state
split is that work crossing a byte the probe can see.

What it does not settle: the `−149` at f1830 has an identical block set in
every probed range. That residual is below the granularity AOTBLK exposes — a
within-block instruction count or a per-instruction charge — and needs an
instruction-level AOT log. The experiment narrows the question to that residual
rather than closing it.

### 8.1 Reproduce

```sh
. tests/rom.sh; rom=$(sr_rom)
mkdir -p tests/out/r5seam
for leg in ctrl seed; do mkdir -p build-tr-$leg/saves;
  [ -f saves/save.srm ] && cp -p saves/save.srm build-tr-$leg/saves/; done

SNESRECOMP_AOTBLK=1820-1834 build-tr-ctrl/ShadowrunSNESRecomp \
  --no-launcher --rom "$rom" --script tests/out/probe_dense.txt \
  >/dev/null 2>tests/out/r5seam/ctrl.err
SNESRECOMP_AOTBLK=1820-1834 build-tr-seed/ShadowrunSNESRecomp \
  --no-launcher --rom "$rom" --script tests/out/probe_dense.txt \
  >/dev/null 2>tests/out/r5seam/seed.err
SNESRECOMP_AOTBLK=1760-1840 build-tr-seed/ShadowrunSNESRecomp \
  --no-launcher --rom "$rom" --script tests/out/probe_dense.txt \
  >/dev/null 2>tests/out/r5seam/seed_wide.err
for r in 80ab00-80ae00 80c300-80c600 81a900-81aa00; do
  SNESRECOMP_CYC_WATCH=$r build-tr-ctrl/ShadowrunSNESRecomp \
    --no-launcher --rom "$rom" --script tests/out/probe_dense.txt \
    >/dev/null 2>tests/out/r5seam/cw_$r.err
done
python3 tests/seam_phase.py | tee evidence/artifacts/round5_seam_phase.txt
```
