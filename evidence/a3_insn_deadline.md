# A3 — instruction-granularity AOT deadline delivery: built, gated, and the deeper root cause

Date: 2026-11-05. Follows `evidence/a2_aot_batch.md` (which chose option 1:
tighten AOT interrupt delivery to instruction granularity).

## 1. What was built

Framework `recompiler/v2/emit_function.py` (uncommitted on `27e95bb`):

- Per-insn deadline unwind sites: the aggregate block cycle charge is split
  into per-insn charges (sum provably identical), and after each
  non-terminating insn's charge a check unwinds to the NEXT un-executed guest
  insn — mirroring the LLE bridge's charge→act→sample order. Skipped-emit
  insns (NLR PLA, trampoline pushes) never become a resume PC.
- Env gate `SNESRECOMP_AOT_INSN_DEADLINE` (default on; `=0` restores the
  legacy aggregate shape for A/B).
- Framework suite: **862 passed, 1 skipped** with the patch (both env
  settings; baseline before the patch was 861+1). One new test pins the
  split-vs-legacy sum invariance and the unwind-site PCs.

A3 scratch batch (`sr-a3`): bundle `7e353a2` + `I_RESET`/`I_NMI` `emit = true`,
regenerated with the patched framework. Same footprint as A2: 9 roots,
**214 AOT variants, 226 exact, 12 LLE-only**; 4,594 new unwind sites emitted
across the bank files; binary 5,957,552 B (A2 was 4,975,664).

## 2. Gate results (AOT vs shipped LLE)

`tests/parity.sh` `parity.txt` (1200 frames, WRAM crc32 per frame):

| Build | identical | differing | worst frame | bursts |
|---|---:|---:|---|---|
| A2 (aggregate charge, block-top polls) | 124 | 1076 | 1,448 B @ f496 | ~2–7, 196–203, 474–478, 496 |
| A3 (per-insn charge + per-insn polls) | 123 | 1077 | 1,448 B @ f496 | 4–7, 197–203, 475–478, 496 |

AOT participation unchanged (wait505: `aot_cycle_pct` 3.5315 vs A2 3.53).

**The patch demonstrably changes runtime** — A2 vs A3 frame dumps differ at
447/1200 frames — **but the AOT↔LLE gap is unchanged in character and size.**
Interrupt-delivery granularity was necessary (timestamps must be sampled at
insn boundaries for any timing match) but is **not sufficient**.

## 3. Root cause: the per-insn master-clock CHARGE differs between paths

The deadline predicate reads `cpu->master_cycles`. The two paths compute it
with structurally different models:

**LLE bridge** (`runner/src/snes/interp_bridge.c:2691-2697`):
```
master_delta = Σ region_speed(every bus transfer) + max(0, cyc − xfers) × 6
```
`bridge_timing_bus` counts ALL bus transfers — opcode+operand **fetches at the
ROM region speed** and data/stack accesses at the **target region's** speed
(6/8/12 per `cpu_region_speed`). Internal cycles are always ×6.

Measured live with `SNESRECOMP_CYC_WATCH=e34c-e380` (I_RESET body, slowROM boot):
```
SEI        cyc=2 xfers=1  bus_master=8  internal=1  master_delta=14   (8+6)
LDA #imm   cyc=2 xfers=2  bus_master=16 internal=0  master_delta=16
STA abs    cyc=4 xfers=4  bus_master=30 internal=0  master_delta=30   (3×8 fetch + 1×6)
LDA dp     cyc=4 xfers=2  bus_master=16 internal=2  master_delta=28   (2×8 + 2×6)
```

**v2 AOT emitter** (`_pi_charge_lines`, Axis-5 shape):
`master += insn_cycles × (code-region speed 6 or 8)`.
Boot `SEI`: AOT 2×8=16 vs LLE 14. `STA abs`: 32 vs 30. Divergence is a few
master cycles **per instruction**, thousands of instructions per frame — the
frame deadline (armed at fixed master clocks) fires at different guest PCs in
the two binaries. NMI/IRQ phase shifts → DMA scratch ($7E4940+) and boot
latches ($7E00DF/…) latch at different points → the burst frames. Frame-total
master agrees (~4 cycles over 1200 frames) because the deadline re-anchors
each frame — only the intra-frame phase differs.

Framework lineage: `docs/validation/accuracy-history.md` names the AOT-side
combiner (`snes_cycles.instr_master_cycles`) a "documented FIRST-CUT" and
calls **bus-cycle-exact attribution the explicit pending refinement**. The
runtime side already exists — `cpu_state.c` "Region-paced AOT bus"
(2026-08-31): `cpu_read8/16_paced`, `cpu_write8/16_paced` charge
`cpu_region_speed` per transfer (16-bit forms charge both bytes) — comment:
*"so the AOT master advance matches the LLE exactly."* **Nothing in
`recompiler/` ever emits them.** Verification tooling exists: LLE-side
`SNESRECOMP_CYC_WATCH` (prints the exact decomposition above) vs AOT-side
`SNESRECOMP_PACELOG`.

## 4. What a bus-exact AOT charge would need (option 1b)

Per insn in v2 codegen:
1. Static charge becomes `cycles += K` (unchanged) +
   `master += insn_len × code_speed_expr + max(0, K − insn_len − emitted_data_bytes) × 6`.
   `emitted_data_bytes` comes from the emitter's own access enumeration, so the
   split is self-consistent with what `_paced` will re-charge at runtime.
2. Every generated memory/stack/pointer access (incl. JSR/JSL return-frame
   pushes, RTL pops) switches to the `_paced` variants.
3. Dynamic guards (D.l≠0 +1, page-cross +1, taken-branch +1) pair
   `master += 6` (they are phantom/internal cycles), emitted only when the
   LLE clamp allows (`K+mods > len+data` — checkable gen-time; at most one
   clamp-affecting guard per (op,mode) in practice).
4. Audit per opcode family that emitted access counts == interp816 shim-call
   counts (RMW r/w/w quirks, pointer-indirect fetches, `8aedfc0` was exactly
   this class of fix on the runtime side). Empirical loop: CYC_WATCH (LLE) vs
   PACELOG (AOT) per PC range, diff `master_delta`.

This is a full-day framework change (emitter + tests + audit), not a patch.

## 5. Decision

- Instruction-granularity unwind sites stay (prerequisite for any timing
  match; no parity regression vs A2; suite green).
- The remaining gap to strict WRAM parity is the master-clock charge model
  (§3), not delivery granularity.

Options:
1. **Bus-exact AOT master charging** (section 4): the principled path to
   strict `parity.sh` identity for AOT batches. Multi-hour framework work.
2. **Widen the Stage 1 gate** (a2 §5 option 2): presentation-identical +
   documented steady-state timer delta, transient scratch-buffer deltas
   allowed, + audio comparison. Accepts that AOT ≠ LLE timing while AOT
   remains tiny (3.5% cycles at boot-vector coverage).
3. **Park AOT at Stage 1**: keep the LLE reference binary shipped, revisit
   promotion when the bus-exact model lands.

Raw logs/dumps: `tests/out/run1|run2` (A3 vs LLE), scratch
`sr-a3/` (fd-a3-parity, fd-a2-parity, a3-wait505/a3-parity2 logs).
