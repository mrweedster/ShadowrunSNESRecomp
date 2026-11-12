# A4 — bus-exact AOT master charging (option 1b): shipped in the framework, and the gate picture changed

Date: 2026-11-05. Follows `evidence/a3_insn_deadline.md` (which named the
master-clock *charge model* as the residual gap and laid out option 1b).

## 1. What was built (framework, option 1b)

`recompiler/v2` (uncommitted on `27e95bb`), env gate `SNESRECOMP_AOT_PACE`
(default on; `=0` restores the legacy aggregate shape):

- Per-insn master charge split: `master += fetch_bytes × code_speed +
  internal × 6` — exactly the LLE bridge model
  (`master = Σ region_speed + internal × 6`), with the data/stack/pointer
  transfers priced at their own target regions at runtime.
- Every generated bus access routed through the region-paced accessors
  (`cpu_read8/16_paced`, `cpu_write8/16_paced`, `runner/src/cpu_state.c`,
  2026-08-31 seam that had never been wired to v2). The rewrite is central
  at block flush (`emit_function._pace_access_lines`), so no emitter site
  can be missed.
- Per-block paceability gating: any undecomposable insn (BRK/COP/PEI/PER —
  never executed by Shadowrun) keeps BOTH the legacy aggregate charge AND
  unpaced accesses (never split-charge with unpaced accesses).
- Skipped-emit insns (NLR PLA run, trampoline PHK/PEA setup) have their
  stack transfers compensated in the static charge; RTI emits its discarded
  PC/PB pulls as real paced reads; taken-branch penalty under pace is
  `master += 6` (dump-verified internal cycle); MVN repeat byte is
  `3 × code_speed + 12` + paced rd/wr.
- `snes_cycles.py`: new `bus_internal_cycles` / `bus_data_transfers`,
  fitted to the LLE bus dump (`SNESRECOMP_BUS_TRACE`, 464,964 instructions
  explained 100%). Fixed a real bug found by the dump: the length-blind
  blockmove special case claimed MVN internal=3; ground truth ($809EB7:
  `cyc=7 xfers=5 bus_master=34`) is internal=2.
- Framework suite: **881 passed, 1 skipped** (was 862) in all three gate
  configurations (pace+deadline default, `AOT_PACE=0`, deadline=0+pace on).
  New `tests/v2/test_cycles_bus_decomposition.py` pins the invariant
  `instr_static_cycles == length + rd + wr + internal` over the full
  256-opcode table × 4 width states, plus the dump-fitted per-op counts.

## 2. A4 batch

Scratch `sr-a3` regenerated with the patched framework: same 214 AOT
variants / 3 banks; `bank80_v2.c` contains 1,453 `_paced(` call sites and
the split charges; binary 5,957,744 B. AOT participation unchanged:
`aot_cycle_pct` 3.5315 (wait505 boot), 1.8845 (parity 1200f).

## 3. Gate results (A4 vs shipped LLE, `tests/out/ShadowrunA4`)

Behavior gates — all pass:

- `tests/selfcheck.sh` PASS (exit 0); headless runs exit 0.
- BMPs at frames 300/600/900/1200 (menu.txt): md5-identical to LLE
  (`63344932… b6340798… 1364d591… 03a05430…`).
- 1200-frame master totals: A4 429,148,502 vs A2 429,148,510 (Δ8 clocks
  in 429M = 0.0000019%).

WRAM parity, `parity.txt` 1200 frames, three alignments
(`tests/framedump_diff.py`, new):

| alignment | A2 vs LLE | A4 vs LLE |
|---|---|---|
| fixed index (`parity.sh` metric) | 124 identical / 1076 differ, worst 1,448 B @ f496 | 123 / 1077, worst 1,448 B @ f496 |
| host-index k-sweep best (k=−1) | 501 identical, Σdiff 10,384, worst 1,374 B @ f196 | 493 identical, Σdiff 10,382, worst 1,370 B @ f196 |
| **guest-counter aligned** | **588/1101 identical, 5 offsets ever** | **579/1101 identical, 11 offsets ever, worst 6 B @ boot counters 18–19** |

Boot-only window (`wait505`, no input): guest-aligned A2 220 identical /
4 offsets; A4 222 identical / 10 offsets (the extra 6 are two boot-latch
bytes, $7E00128/$7E0012B, in 2–3 counter pairs; values are DMA-scratch
parameters, not gameplay state).

Steady-state residue in both: the timer family `$7E0012C/12E/12F/132`
(`$7E0012C` oscillates by ±4) plus the §7 counters — never growing, never
a burst.

## 4. What this settles

1. **The pacing machinery is live and correct at the model level**: A4's
   timeline differs from A2's (287–340 frames differ A2→A4 at fixed index,
   164 at guest-aligned boot), the charge decomposition is dump-verified
   insn-exact, and every generated access is priced per-transfer.
2. **But the fixed-index gap did not move** — and it could not: measured
   today, the A2/A3/A4 "scratch bursts" are the *same* frames where the
   constant **one-host-frame sampling phase** (§7, k=−1) makes host frame N
   straddle a screen transition at different points in the two binaries.
   Guest-aligned, the bursts vanish completely; what remains is the §7
   steady-state timer delta at exactly the documented magnitude.
3. **A4 ≈ A2 on every accuracy axis** (Σdiff 10,382 vs 10,384; boot
   identical-pairs 222 vs 220; BMPs identical). Option 1b neither regressed
   nor dramatically improved observed behavior — its value is that the two
   paths now share one provably identical charge model, which the earlier
   "tighten until identical" attempts could not converge on by construction.

Consequence: **no AOT build can pass fixed-index identity while host
presentation phase differs by one frame**, and no further charge-model
refinement changes that. The promotion decision is now purely gate policy:

- **(a) Escalate the gate**: define the strict cross-path gate as
  *guest-aligned WRAM parity (documented timer residue only) + BMP
  identity + selfcheck/headless + totals*, per this measurement — then A4
  promotes and ships.
- **(b) Keep fixed-index identity as the gate**: park AOT past Stage 1,
  keep the LLE reference binary shipped; revisit with frame-locked capture.

## 5. Reproduce

```sh
# A4 binary: scratch tree sr-a3 (regen + make with SNESRECOMP_AOT_PACE default),
# staged as tests/out/ShadowrunA4 with tests/out/libs symlink.
PORT_BIN=./Shadowrun PORT_BIN2=./tests/out/ShadowrunA4 ./tests/parity.sh tests/scripts/parity.txt

# dumps for the alignment tables (frame_XXXXXX{_wram.bin,json}):
mkdir -p /tmp/fd-a4-parity && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  ./tests/out/ShadowrunA4 --no-launcher --script tests/scripts/parity.txt --framedump /tmp/fd-a4-parity
python3 tests/framedump_diff.py offsets tests/out/run1 /tmp/fd-a4-parity
python3 tests/framedump_diff.py ksweep  tests/out/run1 /tmp/fd-a4-parity
python3 tests/framedump_diff.py guest   tests/out/run1 /tmp/fd-a4-parity
```

Logs: `/tmp/a4_parity.log`, `/tmp/a4_run.log`, `/tmp/a4-wait505.log`
(scratch host; dumps `/tmp/fd-a{2,4}-parity`, `/tmp/fd-{lle,a2,a4}-wait505`).
Framework: committed as `773285b8210f2254ae87d0a14113980fb36990ad`
("recompiler/v2: insn-granularity deadline unwind + bus-exact master
charging") on `main` atop `27e95bb` — touched `emit_function.py`,
`codegen.py`, `emitter_helpers.py`, `snes_cycles.py`, `interp_bridge.c`,
plus 17 test files and the new decomposition test.
