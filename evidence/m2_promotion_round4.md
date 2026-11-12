# M1/M2 promotion, round 4: measuring the gap ranking as seeds

Date: 2026-11-08. Branch: `main`. Everything below is a measurement.

A round-3 record says what a lever did to the machine. This record says what the
*seed table* does to the machine when its entries come from the capture's own
transfer-gap ranking instead of from a hand reading, and where that stops
paying. It ships two seeds, rejects eight, and closes with the number that says
why seeding is no longer the lever: 69.25 % of the interpreted residue is
interpreted at PCs that have no node in the program at all.

**What shipped**: `$80C399` and `$80AAB3` as `[[func]]` entries. `269 -> 283`
manifest nodes, `226 -> 240` AOT nodes. Interpreted cycles
`919,307,323 -> 860,839,515`, `-58,467,808` (`-6.36 %`). CPU and master clock
unchanged to the unit (`956,096,571` / `7,878,127,092`). Machine state
identical at every one of 22 tagged checkpoints on the combat route and across
all 4,575 dumped frames of the parity route, at byte level: **0 differing
bytes** in wram, vram, oam, cgram, sram and the host framebuffer, with the same
program run twice as the control.

**What did not ship**: `$80C1C9`, `$80C1B3`, `$80F495`, `$80F362`, `$80F4F9`,
`$80F889` (six seeds that stop the route at an unauthorized dispatch), and
`$80ABBC`, `$80B1DB` (two seeds that finish the route and change guest state).
The rejection close-out is byte-level: `tests/cp_byte_diff.py`,
`tests/rejected_shift.sh`. Its sharpest line is that at the combat checkpoint
`H8` a rejected tree differs from the control in **one** non-label WRAM byte,
`$7E0127: 63 -> A2` for `$80ABBC`, and in nothing else at all.

---

## 1. The question, and the rules it is answered under

Round 3's `§1` left a residue split: 97 % of the interpreted cost is never
sighted at a transfer gap, and only 3 % sits in `(pc, entry_m, entry_x)` rows
that a `[[func]]` entry could intercept. Round 4 is the test of that 3 %.
Measure the top 10 gap-seedable entries as seeds; either bank a couple of
percent, or close the seed-table direction with a measured cost.

A seed is adopted only if the compiled bodies compute the **same machine state**
as the control tree. Cycle-share movement is not a win on its own. Two gates
enforce that, and both are scripted:

- the checkpoint-state matrix, `tests/cpdump_matrix.py`, over the 22 tagged
  checkpoints of `tests/scripts/combat.txt`; a cell is `clean`, `apu-only`, or
  `DIFFERS(surfaces)`;
- byte-level frame parity, `tests/cp_byte_diff.py` and
  `tests/framedump_diff.py`, over the dense parity route
  (`tests/out/probe_dense.txt`, 4,575 per-frame dumps).

`apu-only` is not automatically a pass, so a third script characterises it:
`tests/apu_shift.py` separates a *pure re-stamp* (the same `(frame, event, port,
value, sample)` multiset, `hclock` moved within one frame) from a changed event
stream. A re-stamp is the seam's cycle bookkeeping, already filed upstream in
round 3; a changed stream is a machine that did something else.

## 2. Provenance

Every number here is read out of `evidence/artifacts/round4_*`, and those files
are generated from `tests/out/r4` by one script, `tests/round4_artifacts.sh`
(with one exception, `round4_probe_81b061.txt`, which `tests/round4_probe.py`
writes from the same archived logs and which the artifact script indexes but
does not re-run). That script runs no route leg, no `tools/regen.sh` and no
cmake: it only re-derives text from measurement logs and dumps that already
exist. So every figure below is traceable to an archived artifact, and the
artifact text itself is not hand-typed.

The identity those artifacts bind is in `artifacts/round4_provenance.txt`:

| item | value |
|---|---|
| framework pin | `snesrecomp=773285b8210f2254ae87d0a14113980fb36990ad` (`framework_pins.txt`) |
| control exe (`build-r4base`) | `1341448773c19617` |
| accepted exe (`build-r4pair`) | `2b478e8d26bb27f9` |
| control generated set | `gen_sha256=8374878ada42`, 18 units / 204 functions / 252 dispatch entries |
| accepted generated set | `gen_sha256=785bd064707f`, 18 units / 215 functions / 263 dispatch entries |
| ranking input capture | `artifacts/tier2_capture_round3_combat.json` sha `3ea7fd1e494a15b2`, `program_digest 240af24bb4a71049`, `build_digest 4c1775badab30111`, `generation_digest 4e902f1ff9bdca6f` |
| capture of the accepted tree | `artifacts/tier2_capture_round4_accepted.json` 3,447,609 B, sha `1a4520bdf036667b`, `program_digest eea52f0716ab0f40`, `build_digest 2b478e8d26bb27f9`, `generation_digest 51ebb386698d8d51` |
| pre-round manifest | `artifacts/round4_manifest_pre.json.bz2` sha `914be087adf50b94` |
| accepted manifest | `artifacts/round4_manifest_r4pair.json.bz2` sha `faa60941ced13a00` |

Coverage is measured against the archived generated set of the tree that the
capture belongs to, not against a working tree that may have moved since.

## 3. The control program

`build-r4base`, built from the committed cfg set with the gap-driven seed block
stripped (`tests/out/r4/cfg/symbols_base.toml`, 40 `[[func]]` entries):

| | |
|---|---|
| regen | 47 roots -> 269 variants over 514 edges, 226 AOT-eligible, 43 LLE-only, 0 diagnostics |
| program manifest | sha `240af24bb4a71049`, 269 nodes |
| route | `tests/scripts/combat.txt`, `exit=0`, `script quit after 22044 frames` |
| execution share | interpreted 96.15 %, AOT 3.85 % |
| counters | interp 226,953,466 insns / 919,307,323 cycles, cpu 956,096,571, master 7,878,127,092 |
| unresolved abandons | `total_hits=0` |

That last row matters for `§6`: on the control, and on every tree the round
adopted, the abandon counter is zero.

## 4. What the gap ranking said to seed

`tests/gap_seeds.py` turns a capture into a seed table. It reads the capture's
`(pc, entry_m, entry_x)` rows, keeps the ones whose cost was paid at a transfer
gap (the only part a `[[func]]` entry can intercept), drops the addresses the
program already declares, and emits the `[[func]]` text. Nothing here is typed
by hand: the committed table carries exactly one generated block, headed
`# --- M2 promotion round 4 (gap-driven seeds) ---` and naming its capture
(`tier2_capture_round3_combat.json`), and every variant table in this round was
produced by the same generator, so a variant's baseline is cut with
`gap_seeds.py --baseline-only` rather than by editing a copy.

`artifacts/round4_seed_tables.txt` carries the two tables the round generated:

| table | sha | `[[func]]` entries | generated block |
|---|---|---|---|
| shipped, `recomp/symbols.toml` | `c2e6a99f1e174553` | 42 (40 baseline + 2) | 45 lines, 2 entries, `$80C399 $80AAB3`, block sha `5cbd4e2c1fc12f99` |
| full top-10, not shipped | `5ef76341bf5e65e5` | 50 (40 + 10) | 113 lines, 10 entries |

Entry counting is anchored to a `[[func]]` header on a line of its own. The
table's own header comment says "`Each [[func]] names an address`", and a
substring count reads that sentence as an entry - it reported 41/43 where the
file declares 40/42. That is fixed in both `gap_seeds.py` (`declared_entries`)
and `round4_artifacts.sh` (`n_entries`), and the shipped artifact now agrees
with `grep -c '^\[\[func\]\]'`.

The ranking the seeds came from (`artifacts/round4_seed_ranking.txt`):

```
ranked: 229 entries (4 dropped: the program already has them, or they are under
--min-cycles), --top 10 seeds the first 10: 14,923,151 ranked cyc = 53.05% of
the 28,131,074 cyc seedable slice, 1.62% of the 919,307,323 cyc attributed residue
$80C1C9  M0X0    2,196,990 cyc    366,165 insns   366,165 gap hits  frames 1766..22043
$80C399  M0X0    2,196,990 cyc    366,165 insns   366,165 gap hits  frames 1766..22043
$80C1B3  M0X0    1,927,350 cyc    385,470 insns    19,305 gap hits  frames 1765..22043
$80F495  M0X0    1,783,776 cyc    222,972 insns   222,972 gap hits  frames 1766..22043
$80F362  M0X0    1,509,550 cyc    188,694 insns   188,694 gap hits  frames 1766..22043
$80AAB3  M0X0    1,483,464 cyc    247,244 insns   247,244 gap hits  frames 1765..22043
$80F4F9  M0X0    1,114,860 cyc    222,972 insns   222,972 gap hits  frames 1766..22043
$80ABBC  M0X0      988,976 cyc    247,244 insns   247,244 gap hits  frames 1765..22043
$80B1DB  M0X0      957,845 cyc    191,569 insns   191,569 gap hits  frames 1767..22043
$80F889  M0X0      763,350 cyc    152,670 insns   152,670 gap hits  frames 1766..22043
```

Two facts in that block set up the whole round. `$80C1C9` and `$80C399` carry
the *same* cost and the same gap-hit count, and the ranking says why: each one's
`sites=` entry is the other's address (`$80C399 ... sites=$80C1C9`,
`$80C1C9 ... sites=$80C1B8`) - one call chain read from two adjacent entry
points, so one body covers both rows and seeding both spends two nodes on one
loop. They also land differently: in the audit, `$80C399` is `aot` and
`$80C1C9` is `lle_only` (`unproven_call_at_80C1D8_to_80F342_m0x0`). And the ten
entries together are 53 % of the seedable slice but only **1.62 %** of the
attributed residue, which is the ceiling the round could possibly reach.

One provenance point about the ranking's input, because it is the input to every
seed in this round: the capture is round 3's capture of the checked-out program.
Its `program_digest` is `240af24bb4a71049` - the same manifest digest as the
`build-r4base` control, which is what licenses ranking against that control -
but its `build_digest` is `4c1775badab30111`, not `1341448773c19617`. Same
program, not the same executable. `tests/gap_seed_audit.py` joins on the
manifest, and the manifest digests do match
(`artifacts/round4_gap_seed_audit.txt`: `914be087adf50b94  269 nodes  47 roots`).

`artifacts/round4_symbol_table_key.txt` also lists what the port declares at
the hottest addresses of the capture, joined to the capture's own entry modes.
Its quoted loader rule is the constraint on every seed: one `pc24` carries
exactly one `(emit, entry_m, entry_x)` policy (`tools/sync_symbols.py:90-93`
in the pin), so a second declaration at the same address in another mode is a
hard loader error, not an additional entry. The artifact is generated against
the shipped tree, so the two seed rows show both halves of what a seed becomes:
`GS_80C399 emit=true m=0 x=0` in `recomp/symbols.toml` and the
recompiler-derived `GS_80C399 emit=func m=0 x=0` at `recomp/bank80.cfg:29`. The
rows that predate the round are the interesting ones: `$80B07A` is declared
`CC_80B07A` as M1X1 but the interpreter ran it M0X0 and was sighted at a gap
there 166,857 times, so the declaration never intercepts the row the ranking is
measuring. That is the loader rule read from the other side, and it is why the
ranking emits `(pc, entry_m, entry_x)` and not just a PC.

## 5. The per-seed sweep

`tests/seed_sweep.sh` builds one tree per seed, each against the same baseline
(`symbols_base.toml` with one generated entry added), runs the combat route and
the dense parity route, and lands the verdict in `artifacts/round4_sweep.tsv`:

| seed | route exit | first abandon | AOT share | parity state verdict |
|---|---|---|---|---|
| `$80C1C9` | 3, `script until timed out after 21530 frames` | site `$80F4F9` frame 1766 | 0.39 % | first divergence frame_001766; 2809 of 4575 differ |
| `$80C399` | 0, `script quit after 22044 frames` | - | 5.88 % | identical over 4575 frames |
| `$80C1B3` | 3, timed out at 21530 | site `$80F4F9` frame 1766 | 0.39 % | first divergence frame_001766 |
| `$80F495` | 3, timed out at 21530 | site `$80F4F9` frame 1766 | 0.39 % | first divergence frame_001766 |
| `$80F362` | 3, timed out at 21530 | site `$80F4F9` frame 1766 | 0.39 % | first divergence frame_001766 |
| `$80AAB3` | 0, `script quit after 22044 frames` | - | 7.93 % | identical over 4575 frames |
| `$80F4F9` | 3, timed out at 21530 | site `$80F4F9` frame 1766 | 0.39 % | first divergence frame_001766 |
| `$80ABBC` | 0, `script quit after 22044 frames` | - | 5.48 % | first divergence frame_001828; 2745 differ |
| `$80B1DB` | 0, `script quit after 22044 frames` | - | 26.47 % | first divergence frame_001831; 2744 differ |
| `$80F889` | 3, timed out at 21530 | site `$80F4F9` frame 1766 | 0.39 % | first divergence frame_001766 |

The AOT share column is the trap this round was built to avoid. `$80B1DB` moves
26.47 % of execution into compiled bodies, more than three times what shipped -
and its parity route diverges from frame 1831. Share is not the gate.

A leg that exits 3 measured a different amount of route than a `quit` leg, so
the exit-3 rows are not comparable to the others on any counter; that is why
every wall-clock and cycle table in this record joins legs by their route end
(`exit: script quit after 22044 frames`) before subtracting anything.

## 6. Why six seeds stop the route

The six failures are one mechanism, and the host reports it. Joined in
`artifacts/round4_abandon_wall.txt`, all six builds carry the same accounting:

```
total_hits=5 distinct_sites=1
sites=[{'site': '0x80F4F9', 'hits': 5, 'first_frame': 1766, 'last_frame': 1770, 'last_hrv': 2}]
```

while the control, the accepted tree, and every other build in the round report
`total_hits=0 distinct_sites=0 sites=[]`.

The mechanism lives in the pin: `runner/src/common_cpu_infra.c:254`,
`cpu_unresolved_abandon_balanced()`. Seeding `$80C1C9` (or `$80C1B3`,
`$80F495`, `$80F362`, `$80F4F9`, `$80F889`) makes the indirect dispatch at
`$80F4F9` an unresolved transfer; the abandon path is what keeps the CPU
balanced, and it *skips the handler's side effects*. Five abandons, five frames,
and the game stops responding to the script - hence the timeout at frame 21530
and the state divergence at frame 1766. The whole leg's AOT share is 0.39 %
against the control's 3.85 %: the stalled machine never gets far enough for the
compiled bodies to accumulate share, which is why no exit-3 row's execution
percentage is comparable to a `quit` row's.

So those six entries are not a seeding win that failed; they are an
authorization question. Authorising `$80F4F9` is a cfg `indirect_dispatch`
decision (`recompiler/v2/cfg_loader.py` in the pin, see `§20`), and until that
is done the ranking cannot reach that family of entries at all.

---

## 7. The adoption gate: state at 22 checkpoints

`tests/cpdump_matrix.py` runs the combat route twice (control, then variant) and
compares every tag both runs took: 24 `regs.json` keys, the wram/vram/oam/cgram/
sram images, the host framebuffer, and the apu/ppuw/dma traces. The result, with
the master-clock delta at the first and last checkpoint (the regs column sums
differing keys over the 22 checkpoints of the run, so it can exceed the 24 keys
one dump holds):

| variant | checkpoints | clean | apu-only | guest state differing | regs keys differed | master clock, first / last |
|---|---|---|---|---|---|---|
| `r4pair` (both seeds) | 22 | 0 | 22 | none | 0 | H8 `+0` / A5 `+0` |
| `s80C399` | 22 | 8 | 14 | none | 0 | H8 `+0` / A5 `+0` |
| `s80AAB3` | 22 | 0 | 22 | none | 0 | H8 `+0` / A5 `+0` |
| `r4probe` (`$81B061`, see `§16`) | 22 | 22 | 0 | none | 0 | H8 `+0` / A5 `+0` |
| `r4clean` (the four seeds that run) | 22 | 0 | 0 | all 22 | 46 | H8 `-4` / A5 `+20` |
| `s80ABBC` | 22 | 0 | 0 | all 22 | 33 | H8 `-20` / A5 `+36` |
| `s80B1DB` | 22 | 0 | 0 | all 22 | 41 | H8 `-16` / A5 `+38` |

Two things fall out. First, the shipped pair never moves the guest's clock:
`H8 +0 / A5 +0`. Every rejected tree moves it, and moves it further as the route
goes on. Second, an `apu-only` cell needs its own evidence before it is read as
harmless, which is the next section.

## 8. What an `apu-only` cell actually is

`tests/apu_shift.py` compares the two `apu.tsv` traces at one checkpoint. Header
is `frame scanline hclock event port value sample`; a frame is 262 scanlines x
512 hclocks of stamping space.

For `r4pair`:

| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | hclock shift (min / median / max) | `sample` column identical |
|---|---|---|---|---|---|---|
| A0 | 65536 / 65536 | 4 | yes | 4 of 65536 | 0 / 0 / 1862 | yes |
| A5 | 65536 / 65536 | 6 | yes | 6 of 65536 | -778 / 0 / 1862 | yes |
| H8 | 65536 / 65536 | 26 | yes | 26 of 65536 | -742 / 0 / 794 | yes |
| J1 | 65536 / 65536 | 27 | yes | 27 of 65536 | -742 / 0 / 794 | yes |
| J10 | 65536 / 65536 | 2 | yes | 2 of 65536 | -58 / 0 / 392 | yes |
| L1 | 65536 / 65536 | 3 | yes | 3 of 65536 | -58 / 0 / 1862 | yes |

Same events, same values, same sample counts, only the stamp moved - inside one
frame, never a whole frame. That is the seam's cycle bookkeeping from round 3,
not a machine that did something else. The same holds at every checkpoint of
every accepted tree (`r4pair`, `s80C399`, `s80AAB3`): re-stamps of at most 27
rows, `hclock` moved between -778 and +1862. The two scripts also agree on the
zero rows: the eight checkpoints `§7` calls `clean` for `$80C399` are exactly
the eight where `apu_shift` reports `0 of 65536` re-stamped.

`r4clean`, one of the rejected trees, is a different kind of object entirely:

```
A0 / A5: 63221 rows only in a, 63221 rows only in b
J1:      31564 rows only in one side
H8:       1527 rows only in one side
```

A stream where 63,221 of 65,536 rows on each side have no counterpart is not a
re-stamp. `apu-only` and `changed APU stream` are distinguishable, and the
round reads them apart.

## 9. The same gate at byte level, with a control

Frame dumps compare a 128 KiB WRAM, 64 KiB VRAM, 544 B OAM, 512 B CGRAM and a
229,376 B framebuffer. Comparing two runs of the **same** program against each
other says what the harness itself contributes. `tests/cp_byte_diff.py` labels
each differing byte with `framedump_diff._is_label` - one rule, imported, not
duplicated: the kernel window `$7E01C80-$7E01D40` and the five timer
singletons are labels; everything else is state.

`artifacts/round4_state_bytes.md` compares 132 rows per block - 22 checkpoints
by 6 surfaces (`wram.bin`, `vram.bin`, `oam.bin`, `cgram.bin`, `sram.bin`,
`fb.bgrx`) - and splits each row's differing bytes by the label rule:

| block | rows with any differing byte, of 132 | total differing bytes over the 22 checkpoints | state bytes |
|---|---|---|---|
| same program twice: accepted tree vs its own anchor exe | **0** | 0 | 0 |
| `r4pair` | **0** | 0 | 0 |
| the accepted tree as checked out | **0** | 0 | 0 |
| `s80C399` | **0** | 0 | 0 |
| `s80AAB3` | **0** | 0 | 0 |
| `s80ABBC` | 87 | 387,727 | 387,641 |
| `s80B1DB` | 89 | 482,517 | 482,431 |
| `r4clean` | 76 | 561,501 | 561,411 |

The control row is the one that makes the accepted rows mean something: the
harness is deterministic across wram/vram/oam/cgram/framebuffer at every
checkpoint, 0 bytes. Therefore the `apu-only` cells in `§7` are the seed moving
the seam, not noise.

And the rejected trees start small. At H8 (frame 16188):

| tree | WRAM diff | label bytes | state bytes | the state byte | VRAM / OAM / CGRAM / framebuffer at H8 |
|---|---|---|---|---|---|
| `s80ABBC` | 10 | 9 | **1** | `$7E0127: 63 -> A2` | identical |
| `s80B1DB` | 9 | 8 | **1** | `$7E0127: 63 -> 6D` | identical |
| `r4clean` | 10 | 9 | **1** | `$7E0127: 63 -> 6A` | identical |

The 8-9 label bytes are the `$7E01C94-$7E01D04` window, the kernel's own scratch.
One non-label byte, in a latch, is the whole visible difference at that
checkpoint. It grows: by J1 a rejected tree carries 145-201 WRAM state bytes and
342-497 VRAM bytes; by A5, 528-4,082 WRAM, 222-957 VRAM and 43,493-45,187
framebuffer bytes. Nothing at H8 predicts the A5 row except the byte at H8.

## 10. Is the divergence a phase artifact? No.

The obvious objection to `§9` is that two legs run at slightly different host
speeds, so comparing them at the same host frame compares different guest
moments. `tests/rejected_shift.sh` answers it with five probes, both legs on the
dense parity route, the variant launched from a scratch anchor under
`tests/out/r4/anchor_<variant>/` rather than inside a `build-*/` directory (a
build dir's `last_run_report.json` is the join target for other artifacts, and
a verification leg must not overwrite it). Every leg pair ends
`exit: script quit after 4575 frames`. Output per variant is
`artifacts/round4_state_bytes.md`, one block per variant.

`tick` aligns the two legs on the guest counter, not on host frames:

```
counters: run1=4333 run2=4333 shared=4333 range=0..4332
only in run1: 0  only in run2: 0
phase segments (run1 host frame - run2 host frame, same guest tick):
  k=+0  counters 0..4332  host f0..f4574  (4333 ticks)
steps: none -- phase is constant across the whole run
```

Identical for all three rejected variants: the guest counters pair one-to-one
and the phase offset is `k=+0` from the first counter to the last. So the diff is
not a pairing artifact. Aligning does not remove it either (`shift`, 41 sampled
guest counters, label bytes excluded):

| variant | counters differing at `k=0` | worst row at `k=0` | best `k` found | rows that improve at any `k` | first counter with a diff |
|---|---|---|---|---|---|
| `s80ABBC` | 13 of 41 | 4 at counter 2160 | +0 | none | counter 1728 (host f1970) |
| `s80B1DB` | 26 of 41 | 10 at counter 1728 | -5 | one (that row: 10 -> 8) | counter 1620 (host f1862) |
| `r4clean` | 25 of 41 | 11 at counter 1728 | +10 | one (that row: 11 -> 9) | counter 1620 (host f1862) |

`drift` then asks the opposite question - how far apart do the two WRAM images
get, counted in 1 KiB blocks, frame by frame:

| variant | first frame over 3 differing blocks | worst frame |
|---|---|---|
| `s80ABBC` | never | f1832 with 2 blocks |
| `s80B1DB` | never | f2449 with 3 blocks |
| `r4clean` | never | f2449 with 3 blocks |

Which is exactly why a block-crc view is not enough and a new mode was needed.
`framedump_diff.py state run1 run2 [FROM TO]` names the non-label bytes at one
host frame with their values; the split here is one to two blocks wide, which
`drift` cannot resolve:

| variant | first frame with a state byte | bytes, and which | frames with a state byte | total state bytes |
|---|---|---|---|---|
| `s80ABBC` | f1830 | 1 byte: `$7E00126: 88 -> 85` | 1409 of 4575 | 3,409 |
| `s80B1DB` | f1831, then f1832 with 13 | `$7E00000-006`, `$7E00126: 82 -> 7F`, `$7E00134-137` | 2654 of 4575 | 9,625 |
| `r4clean` | f1831, then f1832 with 13 | same addresses | 2643 of 4575 | 7,435 |

The `byte` probe then says something the checkpoint diff does *not* predict, and
it is recorded rather than smoothed over: `$7E0127`, the single state byte at
combat-route H8, is **identical in all 4,575 frames of the probe route** for all
three variants. It is a latch that only the combat route sets. Conversely
`$7E00126`, the first byte to differ on the probe route, differs in 120 frames
(`s80ABBC`) / 124 (`s80B1DB`) and stays inside one value set:

```
$80ABBC  $7E00126  frames compared=4575 identical=4455 differing=120
$80B1DB  $7E00126  frames compared=4575 identical=4451 differing=124
         same value set in both legs
```

For `r4clean` the same probe does not come back clean, which is why it is not
one defect:

```
$7E00126  frames compared=4575 identical=4329 differing=246
  run1 values: ... 7Fx282  82x506  85x3  88x6 ...
  run2 values: ... 7Fx525  82x263  88x9 ...
  NOT the same values -- run1 only 85
  count moved: 7F 282 -> 525  82 506 -> 263  85 3 -> 0  88 6 -> 9
  timeline (frame: run1/run2), runs where both legs hold steady:
    f1830          88==
    f1831..f1954   82/7F  DIFFERS
    f1955          88==
    f1956..f2074   82/7F  DIFFERS
    f2075..f2202   40== identical
    f2203          88==
    f2204..f2386   7F== identical
    f2387..f2388   85/88  DIFFERS
```

`r4clean` never holds the value `85` at that address while the control does, at
frames 2387-2388 (control `85`, `r4clean` `88`), in a window where both single
seeds are clean. That is a third, seed-interaction effect, and it is why the
four-seed tree is closed separately from its parts.

Where this leaves the rejection: the byte that diverges, its control and variant
values, the exact frame it starts (`f1830` / `f1831`), the fact that alignment
does not remove it (`k=+0`, non-zero diffs at aligned ticks), and the fact that
the guest clock itself moves (`H8 -4 / A5 +20` against the accepted pair's
`+0 / +0`). What is **not** established is which store writes `$7E0127`
differently in a seeded body. Pinning that needs a trace build of the seeded
variant (`SNESRECOMP_ENABLE_TRACE=ON` plus the `tests/wram_trace.py` ring), and
round 4 deliberately did not spend a round on it.

## 11. The parity legs, joined to the counters of the same leg

`artifacts/round4_parity_legs.md` joins each `tests/parity.sh` log to that leg's
own `last_run_report.json`; a row is only printed when the report's frame count
equals the frame count the log says the leg ran (the probe route is archived as
`artifacts/round4_probe_route.txt`, sha `de38c3cf9499f14e`). All 13 rows join,
all end `quit 4575`:

| parity leg | run1 exe | run2 exe | cpu cycles, run2 - run1 | master cycles | verdict |
|---|---|---|---|---|---|
| `r4base` vs `r4pair` | `1341448773c19617` | `2b478e8d26bb27f9` | +0 | +0 | identical over 4575 frames |
| `r4base` vs `s80C399` | `1341448773c19617` | `e841e036e49064de` | +0 | +0 | identical over 4575 frames |
| `r4base` vs `s80AAB3` | `1341448773c19617` | `df29756f8367716a` | +0 | +0 | identical over 4575 frames |
| `r4base` vs `s80ABBC` | `1341448773c19617` | `05f8aefb69d18851` | **-584** | +0 | first divergence frame_001828; 2745 differ |
| `r4base` vs `s80B1DB` | `1341448773c19617` | `d1fb51a5274b3e8d` | **-359,070** | **-12** | first divergence frame_001831; 2744 differ |
| `r4base` vs `s80B1DB` (rerun) | `1341448773c19617` | `d1fb51a5274b3e8d` | -359,070 | -12 | identical to the row above |
| `r4base` vs `r4clean` | `1341448773c19617` | `3e1a68bd32e963cc` | **-359,252** | **-12** | first divergence frame_001831; 2744 differ |
| control vs each of the six exit-3 seeds | `1341448773c19617` | (six) | +31,160,765 | +269,098,180 | first divergence frame_001766; 2809 differ |

The six exit-3 rows are printed but not subtracted anywhere: on the probe route
those builds also run all 4,575 frames, but from frame 1766 they are running a
machine that stopped responding, so their counter deltas measure the stalled
game rather than a cost. The number that transfers is the divergence frame.

The same join on the 22,044-frame combat route, from the variant ledgers
(`tests/seed_variant.sh` legs), is where share and clock part company:

| variant | route end | interp cycles | cpu cycles | master cycles |
|---|---|---|---|---|
| `r4base` | quit after 22044 frames | 919,307,323 | 956,096,571 | 7,878,127,092 |
| `r4pair` | quit after 22044 frames | 860,839,515 | 956,096,571 | 7,878,127,092 |
| `s80C399` | quit after 22044 frames | 899,859,432 | 956,096,571 | 7,878,127,092 |
| `s80AAB3` | quit after 22044 frames | 880,287,406 | 956,096,571 | 7,878,127,092 |
| `s80ABBC` | quit after 22044 frames | 903,700,726 | 956,058,833 | 7,878,127,128 |
| `s80B1DB` | quit after 22044 frames | 701,658,067 | 954,239,118 | 7,878,127,130 |
| `r4clean` | quit after 22044 frames | 626,711,944 | 955,775,558 | 7,878,127,112 |

`$80B1DB` takes 217 million interpreted cycles out of the run and puts 1,857,453
cycles onto the CPU clock and 38 onto the master clock. `r4clean` removes 293
million interpreted cycles - a third of the residue - and moves the clocks by
321,013 and 20. Both are rejected. The three shipped rows move nothing.

`$80ABBC` and `$80B1DB` are not one defect: 584 cycles and no clock movement,
against 359,070 cycles and 12 master cycles.

## 12. What each seed changed in the generated program

`artifacts/round4_generated_sets.md` unpacks the archived generated sets and
compares them; function names are scanned out of `dispatch_v2.c` as
`GS|CC|FR_[0-9A-Fa-f]{6}`. Control: 20 files, 38 dispatch names.

| variant | files that differ | dispatch names | manifest nodes | new nodes: aot / lle |
|---|---|---|---|---|
| control `r4base` | - | 38 | 269 | - |
| `r4pair` (shipped) | 5 | +2 -> 40 | +14 -> 283 | 14 / 0 |
| `s80C399` | 4 | +1 -> 39 | +1 -> 270 | 1 / 0 |
| `s80AAB3` | 5 | +1 -> 39 | +13 -> 282 | 13 / 0 |
| `s80ABBC` | 4 | +1 -> 39 | +1 -> 270 | 1 / 0 |
| `s80B1DB` | 4 | +1 -> 39 | +3 -> 272 | 3 / 0 |
| `r4clean` (the four that run) | 5 | +4 -> 42 | +18 -> 287 | 18 / 0 |
| `r4probe` (`$81B061`) | manifest only | - | +1 -> 270 | 1 / 0 |
| `s80C1C9` | manifest only | - | +79 -> 348 | 10 / **69** |
| `s80C1B3` | manifest only | - | +80 -> 349 | 10 / **70** |
| `s80F362` | manifest only | - | +76 -> 345 | 9 / **67** |
| `s80F495` | manifest only | - | +2 -> 271 | 1 / **1** |
| `s80F4F9` | manifest only | - | +1 -> 270 | 1 / 0 |
| `s80F889` | manifest only | - | +76 -> 345 | 9 / **67** |

The five files for `r4pair` are `.snesrecomp-cache.json`, `bank80_v2.c`,
`bank81_part00_v2.c`, `dispatch_v2.c` and `program_manifest.json`;
`bank80_v2.c` grows `2,039,681 -> 2,615,256 B` and `program_manifest.json`
`228,635 -> 240,553 B`. **0 nodes removed and 0 pre-existing nodes changed**, in
every variant - a seed only ever adds nodes. The 12 nodes beyond the two shipped
seeds are reached from inside them: `$80AAB3` brings
`8080B2 808133 8081B4 808238 8082BC 8185FE 818686 8186E5`, `$80C399` brings
`80C7DC 80C81D 80C8E3 80C9B0`; all keys are `:M0X0`, and the bank-81 bodies are
why `bank81_part00_v2.c` joins the diff.

The exit-3 rows are this round's structural finding about what a seed can do.
Four of the six do not just add a body: they pull 66-70 **`lle_only`** nodes into
the program, 66 of them over the span `$80F353-$80F91C`, plus
`$80F342-$80F91C`, `$80F495-$80F4D0`, `$80C1C9-$80C208`, `$80C1B3-$80C1C8`. A
fifth, `$80F495`, adds one `lle_only` body of its own. Those are bodies the
recompiler *reaches* through the new entry and refuses to compile - and
`$80F4F9` sits inside `$80F353-$80F91C`. Seeding one of those addresses drags
the reachable set into a block the recompiler will not compile, the interpreter
keeps owning it, and the transfer at `$80F4F9` is left unresolved. `$80F4F9`
itself is the exception in the node mix (1 node, `aot_eligible`, 1 insn,
`$80F4F9-$80F4F9`) and still fails the route, which is consistent with `§6`:
what decides it is not how many nodes a seed adds but whether the dispatch at
`$80F4F9` is authorised.

## 13. Did the seeds deliver what the ranking promised?

`tests/gap_seed_audit.py` joins the capture's ranking to the post-seed manifest
and the manifest's ranges back to the capture's cycles. For the shipped pair
(`artifacts/round4_gap_seed_audit.txt`):

```
manifest diff  269 -> 283 nodes, 47 -> 49 roots
               +14 nodes (14 aot_eligible, 0 lle_only), -0 removed, 0 pre-existing node changed
ranking        229 kept entries gate 28,131,074 of 919,307,323 cyc = 3.06 % of the residue
               4 hot-sighted gap entries were not kept (already an entry at that address and mode)
```

The 14 new nodes cover 14 address ranges that merge into 6 spans, and those
spans carry **14,126,932 instructions / 58,467,808 guest cycles = 6.36 %** of the
residue. The measured drop, from `§14`, is `-58,467,808`. The analyzer and the
machine agree exactly, to the cycle, because the cycles moved are the cycles
inside the new bodies and nothing else.

Per seed, from the same block's own audit table:

```
               entry       cyc   %res  hot insns  gap hits  frames        disposition  body  span                 in-span cyc     why
               $80AAB3 M0X0    1,483,464  0.16    247,244   247,244  1765..22043   aot            108  $80AAB3-$80ABBB      34,181,159 (3.72%)
               $80C399 M0X0    2,196,990  0.24    366,165   366,165  1766..22043   aot             26  $80C399-$80C3D0      19,447,891 (2.12%)
```

Those two spans sum to 53,629,050 cycles (5.83 % of the residue) and the two
seeds measured alone drop 19,447,891 and 39,019,917. `$80C399` converts exactly
its own span's cycles (`919,307,323 -> 899,859,432`); `$80AAB3` converts
4,838,758 more than its own entry's span (`-> 880,287,406`) because the 12
bodies it reaches carry cost past the entry. The 14 ranges merge into 6 spans
carrying 58,467,808 cycles = 6.36 %, which is the pair's measured drop to the
cycle. Of the 3,680,454 gated cycles at the two seeds' own gap rows, **100.0 %**
reach a compiled body (the full ten: 60.4 %, below).

The full ten seeds are the same join with a different answer:

```
manifest diff  269 -> 366 nodes, 47 -> 57 roots
               +97 nodes (94 aot_eligible, 3 lle_only), -0 removed, 0 pre-existing node changed
               the 94 nodes they added (7 seeds + 87 bodies reached through them) span 94 ranges
               that merge to 10; ... 378,343,469 cyc over the merged ranges = 41.16 % of the residue
               of the 14,923,151 cyc these entries gate: 9,015,035 cyc (60.4 %) reached a body,
               5,908,116 cyc (39.6 %) stayed lle_only, 0 got no node
```

The ranking promised 1.62 % of the residue; the analyzer, on the same ten
entries, agrees to 0.98 % of the residue on gated cycles alone. The 41.16 % is a
span upper bound, not a measurement, and 39.6 % of the gated cycles never reach
a body at all. Seeding the ranking harder does not scale: it adds 97 nodes, more
than a third of the whole program, and most of its gated cost is unreachable.

The audit also names which three of the ten are the `lle_only` ones, and its
`why` column is the mechanism `§6` measured from the other side:

```
$80C1B3 M0X0  lle_only   truncated_call_continuation,unproven_call_at_80C1B8_to_80C1C9_m0x0,unproven_callee_exit
$80C1C9 M0X0  lle_only   truncated_call_continuation,unproven_call_at_80C1D8_to_80F342_m0x0,unproven_callee_exit
$80F495 M0X0  lle_only   truncated_call_continuation,unproven_call_at_80F4D0_to_80F4F9_m0x0,unproven_callee_exit
```

`$80F4F9` is named in the analyzer's own refusal string as the target of an
unproven call, which is the same site the host abandons at frame 1766. And the
5,908,116 gated cycles that stay `lle_only` are exactly those three seeds' own
gated cycles, `$80C1B3 1,927,350 + $80C1C9 2,196,990 + $80F495 1,783,776`: not
one cycle they gate reaches a body.

## 14. The residue, measured again on the tree that shipped those seeds

`gap_seeds.py --then` compares two captures of two different programs - the
pre-round program and the accepted one - and reports the residue and the
seedable slice under each. `artifacts/round4_residue_after.md`:

```
     capture tier2_capture_round4_accepted.json  program_digest eea52f0716ab0f40  build_digest 2b478e8d26bb27f9
     manifest evidence/artifacts/round4_manifest_r4pair.json.bz2  nodes 283  symbols recomp/symbols.toml  entries 40
attributed          919,307,323 ->      860,839,515   (-   58,467,808,  -6.36%)
seedable             28,131,074 ->       24,086,298   (-    4,044,776, -14.38%)
never sighted      891,176,249 ->      836,753,217   (-   54,423,032,  -6.11%)
     seedable entries: 229 -> 215   (3.06% of attributed -> 2.80%)
```

The control side of the join is the round-3 capture, whose own header says
`attributed 919,307,323 / seedable 28,131,074 = 3.06% over 233 (pc,mx) entries /
never sighted 891,176,249 = 96.94%`.
left the seedable list: 14 entries, 4,044,776 cyc
   $80C399 M0X0  2,196,990   $80AAB3 M0X0  1,483,464   $8185FE M0X0  219,102
   $818686 35,856   $8186E5 30,480   $80C9B0 25,482   $80C81D 18,156   $80C7DC 8,612 ...
entered the seedable list: 0 entries, 0 cyc
still seedable, and its interpreted cost at that PC changed: 0 entries, net +0 cyc
```

(The `entries 40` in that header is `gap_seeds.declared_entries()`: addressable
`[[func]]` rows as manifest-node keys. The file declares 42 headers - 40
baseline + 2 seeds - and the counter leaves out the two vector rows `I_RESET`
(`$00E34C`) and `I_NMI` (`$00C0E2`), which are `bank = 0` and never appear as
manifest nodes, so 42 - 2 = 40. The `40 baseline + 2` count in `§18` is the
anchored header count.)

The arithmetic closes: `-54,423,032` (never-sighted) `+ -4,044,776` (seedable)
`= -58,467,808`, the whole attributed drop. The 14 entries that left the
seedable list are the 14 nodes the manifest gained: the artifact prints ten of
them, `$80C399 2,196,990` `$80AAB3 1,483,464` `$8185FE 219,102` `$818686
35,856` `$8186E5 30,480` `$80C9B0 25,482` `$80C81D 18,156` `$80C7DC 8,612`
`$80C8E3 7,326` `$808238 7,132`, and the other four are the remaining new
addresses in the pre-round ranking, `$8080B2 5,508` `$808133 2,764` `$8081B4
2,008` `$8082BC 1,896`; those fourteen rows sum to exactly `4,044,776`, the
stated drop. And nothing entered the list: two seeds did not push cost into new
gap rows.

`artifacts/round4_seed_ranking.txt` also re-ranks the *same* capture against the
shipped table: 215 entries remain, top 10 = 12,613,024 cycles = 44.84 % of the
28,131,074-cycle control slice, 1.37 % of the 919,307,323-cycle control residue.
Measured on the accepted program's own capture (`accepted_verify.log` `§6`) the
same table leaves 215 ranked entries whose top 10 is the same 12,613,024 cycles:
52.37 % of that program's 24,086,298-cycle seedable slice, 1.47 % of its
860,839,515-cycle residue. Seeding the top ten of the shipped program is worth
about as little as seeding the top ten of the control was.

## 15. Wall clock: three batches, and what each one can say

A counter difference is not a result; a wall-clock difference that survives
its own noise floor is. `tests/charge_wall.py` groups legs by build directory
(every executable in this port is named `ShadowrunSNESRecomp`), takes
same-binary replicates as the floor, and reads an interleaved batch pairwise
against the control leg it ran next to. `artifacts/round4_wall_clock.md` holds
three batches; every leg in all three ends `exit: script quit after 22044
frames`.

| batch | binaries and legs | per-binary reading | paired reading | tool exit |
|---|---|---|---|---|
| `charge_hostcost_run.log` | `r4base` x7 (30.27 / 30.91 / 31.48, sd 0.52), `s80C399` x3 (31.10, sd 0.13), `s80AAB3` x3 (31.00, sd 0.22), `r4probe` x2 (30.50, sd 0.43), `r4pair` x4 (30.07, sd 0.11) | `s80C399` +0.19 s, `s80AAB3` +0.09 s, `r4probe` -0.42 s, `r4pair` **-0.84 s**; every one needs > 1.05 s | not paired (block-run) | **1: 0 resolved, 1 inconclusive** |
| `charge_wallbatch.log` | `r4base` x10 (30.33 / 31.60 / 32.43, sd 0.72), `r4pair` x10 (29.28 / 30.24 / 30.94, sd 0.48) | -1.36 s, needs > 1.43 s | 10 pairs, mean **-1.36 s**, sd 0.53, se 0.17, needs \|mean\| > 0.34 s, signs consistent | 0: resolved |
| `charge_wallbatch2.log` | `r4base` x4 (29.79 / 30.62 / 31.12, sd 0.58), `s80C399` x4 (29.65 / 30.07 / 30.30, sd 0.29), `s80AAB3` x4 (29.74 / 30.02 / 30.34, sd 0.32) | -0.55 s and -0.59 s, both need > 1.15 s | `s80C399` over 4 pairs **-0.55 s** (sd 0.31, se 0.15, needs > 0.31); `s80AAB3` **-0.59 s** (sd 0.41, se 0.20, needs > 0.41) | 0: resolved |

The first batch is the honest one to read first: seven replicates of the same
control binary spread 0.52 s, so the tool refuses all four comparisons in it -
including the accepted tree's -0.84 s. Same-binary spread is the floor, and a
per-binary mean that does not clear it is reported `inconclusive`.

Batches two and three interleave the candidate leg with a control leg in the
same slot, which removes most of the host drift: the same -1.36 s that fails the
per-binary floor (needs > 1.43 s) passes the paired test (needs > 0.34 s) with
ten consistent signs. That is the accepted tree's **about 4.3 % of a 31.6 s
route**, and it is the only wall-clock result in the round; the per-seed numbers
(-0.55 s for `$80C399`, -0.59 s for `$80AAB3`) are each resolved over their own
four pairs.

## 16. Why the rest of the residue does not respond to seeding

Three measurements close the seed-table direction.

**(a) Where the interpreted cost already sits.** `tests/hot_vs_aot.py` takes the
capture's hot rows and asks, for each PC the interpreter paid for, whether a
compiled body in that same M/X mode covers it (`artifacts/round4_hot_vs_aot.md`,
control program, 269 nodes):

| class | hot PCs | interpreted insns | guest cycles | % of residue | of those PCs, sighted at a transfer gap |
|---|---|---|---|---|---|
| exact-aot | 25 | 718,590 | 3,409,819 | 0.37 % | 1 |
| exact-lle | 9 | 41,111 | 161,948 | 0.02 % | 4 |
| span-aot | 2801 | 62,733,369 | 275,979,837 | 30.02 % | 12 |
| span-lle | 326 | 695,427 | 3,161,778 | 0.34 % | 1 |
| no-node | 6402 | 162,764,969 | 636,593,941 | 69.25 % | 237 |
| **total** | 9563 | 226,953,466 | 919,307,323 | 100.00 % | 255 |

30 % of the residue is already inside an `aot_eligible` span and the interpreter
still paid for it - 2801 hot PCs - and only **12** of those PCs are ever sighted
at a gap, which is why seeding them is not an option. The interpreter is paying
for cost inside bodies it already has, at PCs that are not entries. Conversely,
the 3,409,819 cycles that are exactly at a compiled entry are 0.37 % of the
residue and almost none of them are gap-sighted either. And 69.25 % of the
residue is at PCs with no node in the program at all.

**(b) A root at the hottest address does nothing.** `$81B061` is 18.00 % of the
residue on its own (165,447,390 cycles, 27,574,565 instructions) and is covered
by node `81B05D:M0X0`. The capture reports `completed_hits = observed_hits = 0`
at those PCs, so the address never appears in the gap ranking; a `[[func]]`
entry there is a probe, generated with `--force-pc` and marked as one
(`artifacts/round4_probe_81b061.txt`). Adding it makes `269 -> 270` nodes,
`47 -> 48` roots, one new node `81B061:M0X0` with 3 instructions spanning
`$81B061-$81B067`, exe `5429c29978a8d9b0`, gen `1a7ffe32063c`, 18 units / 204
functions / 253 dispatch entries - and the run is unchanged:

```
interp_cycles is identical on every control leg and every probe leg:
919,307,323, 919,307,323, 919,307,323, 919,307,323, 919,307,323
```

Declaring a root at the hottest loop in the game moves zero cycles. The body
exists; the seam does not hand control to it. That is the round-3 upstream item,
now with a number attached.

The probe also demonstrates the loader rule from `§4` on a real address: the
port declares `$81B05D` as `func CC_81B05D b05d entry_mx:1,1` in
`recomp/bank81.cfg`, so that `pc24` is owned by the M1X1 policy, and the hot
caller is M0X0. `gap_seeds.py --force-pc '$81B05D'` emits a second declaration,
and the pin's loader refuses it:

```
loader refused it: probe_81b05d.toml: func #43 (GS_81B05D): conflicting tier/entry modes at $81B05D
```

So an address is seedable in exactly one `(entry_m, entry_x)`, and the mode a
hot row is measured in is the mode it has to be entered in. The ranking's
identical-cost rows (`$80C1C9`/`$80C399`) are a different case: two distinct
addresses on one call chain, which the manifest then resolves differently.

**(c) The floor switch is a null control in this port.** `SNESRECOMP_FORCE_FLOOR`
appears in the sweep as `floor` / `nofloor` legs, and
`artifacts/round4_execution_mode_grep.txt` greps the pin's
`runner/src/execution_mode.{c,h}` plus every round-4 leg log. No leg printed an
execution-mode banner: floor and nofloor legs measure the same program, which
the ledger confirms to the unit (`base_fl` == `base_nf`, `pair_fl` == `pair_nf`,
`b1db_fl` == `b1db_nf`). So no claim in this record depends on a
"floor-disabled AOT" mode, and the mode names in `round4_charge_ledger.md` are
leg provenance, not a lever.

## 17. The cycle ledger, with the host switches pinned per leg

`tests/aot_charge.sh` writes each leg's environment into its own
`<leg>.flags.tsv` beside its log, in `tests/out/charge`; `tests/charge_report.py`
joins those legs so the counters subtract (`artifacts/round4_charge_ledger.md`).
All 11 round-4 legs end `exit: script quit after 22044 frames`, and every one
reports `abandons=0`.

`self_a` and `self_b` are the same control binary run twice more, and both come
back `+0` on all four counters; `base_fl` reproduces `base_nf` exactly. That is
what licenses the delta table:

| leg | binary | d interp insns | d interp cycles | d cpu cycles | d master cycles |
|---|---|---|---|---|---|
| `self_a` / `self_b` | control | +0 | +0 | +0 | +0 |
| `base_fl` | control, floor leg | +0 | +0 | +0 | +0 |
| `pair_nf` / `pair_fl` | accepted | -14,126,932 | **-58,467,808** | **+0** | **+0** |
| `c399_nf` | `$80C399` only | -5,242,977 | -19,447,891 | +0 | +0 |
| `aab3_nf` | `$80AAB3` only | -8,883,955 | -39,019,917 | +0 | +0 |
| `abbc_nf` | `$80ABBC` only | -3,683,633 | -15,606,597 | **-37,738** | **+36** |
| `b1db_nf` / `b1db_fl` | `$80B1DB` only | -60,661,179 | -217,649,256 | **-1,857,453** | **+38** |

A conversion is real when the interpreted drop is large and the cpu/master
columns do not move. The shipped pair is that shape twice, alone and together.
Each rejected tree that runs is a different shape: cost leaves the interpreter
and lands on the clock.

## 18. The tree that shipped, verified end to end

`recomp/symbols.toml` carries the 45-line generated block with the two entries,
and `recomp/bank80.cfg` carries the two generated lines the recompiler derived
from them (`func GS_80AAB3 aab3 entry_mx:0,0` and `func GS_80C399 c399
entry_mx:0,0`). `tests/accepted_verify.sh` re-measures that checkout, running
its legs from a scratch anchor under `tests/out/r4/accepted/` so that no
`build-*/last_run_report.json` used elsewhere is overwritten. Its log ships as
`artifacts/round4_accepted_verify.md`:

- generated set: live `src/gen` is 20 files, manifest `eea52f0716ab0f40`,
  **MATCH** against the archived accepted manifest, and identical to
  `artifacts/round4_gen_r4pair.tar.gz`;
- seed block: shipped block sha `5cbd4e2c1fc12f99`, re-derived from the
  generator **MATCH**, 45 lines, table 42 entries = 40 baseline + 2;
- short leg: `exit=0 wall=1s`, `script quit after 60 frames` - no ROM picker;
- combat route: `exit=0 wall=30s`, 264 files / 22 tagged checkpoints,
  `interp 90.04 % aot 9.96 % interp_insns 212,826,534 interp_cycles 860,839,515
  cpu_cycles 956,096,571 master_cycles 7,878,127,092 frame 22,044`, provenance
  `gen_sha256=785bd064707f gen_units=18 gen_functions=215 gen_dispatch=263
  framework=773285b8210f exe_sha256=2b478e8d26bb`;
- checkpoint gate vs the control run: 22 of 22 cells `apu-only`,
  `H8 +0 / A5 +0`;
- parity leg on the probe route: `rc=0`, identical over 4575 frames;
- capture of the accepted program: ingest `rc=0`, 3,447,609 B, sha
  `1a4520bdf036667b`, identity `program_digest eea52f0716ab0f40`,
  `build_digest 2b478e8d26bb27f9`, `generation_digest 51ebb386698d8d51`.

## 19. Decision record

| decision | why |
|---|---|
| ship `$80C399` + `$80AAB3` | state-identical at all 22 combat checkpoints (byte-level, 0 of 132 rows differ), state-identical over 4,575 parity frames, cpu/master clocks `+0/+0`, and the cycle drop matches the analyzer's span attribution to the cycle (58,467,808 = 6.36 %) |
| reject `$80ABBC` | changes guest state at every checkpoint (one non-label WRAM byte at H8, 387,641 state bytes over the 22 checkpoints), CPU `-37,738` / master `+36` on the combat route, `-584` cpu cycles on the probe route, first differing frame dump at 1828 |
| reject `$80B1DB` | the biggest share move of the round (26.47 % AOT, -217,649,256 interpreted cycles) and a changed machine: 482,431 state bytes over the 22 checkpoints, cpu `-1,857,453`, master `+38`, first differing frame dump at 1831 |
| reject `r4clean` (the four that run) | worse than either part: 561,411 state bytes over the 22 checkpoints, an APU event stream that is not a re-stamp, and at frames 2387-2388 the control holds `$7E00126 = 85` where `r4clean` holds `88` - the one value in the control's set the seeded tree never reaches (`run1 only 85`) |
| do not chase the six exit-3 seeds through the cfg | their failure is the framework's unresolved-abandon path skipping handler side effects; authorising `$80F4F9` is a separate, cfg-level decision |
| close the seed-table direction as a lever | 69.25 % of the residue has no node, 30.02 % is inside spans but sighted at a gap only 12 times in 2801 PCs, and a generated root at the hottest PC moves 0 cycles |

## 20. What the next round should do

1. **Pin the writer of `$7E0127`.** Build a seeded variant with
   `SNESRECOMP_ENABLE_TRACE=ON` and use the `tests/wram_trace.py` ring, so the
   answer is an instruction, not a byte pair. The evidence needed already
   exists to aim it: one byte, one value pair per tree, onset at `f1830/1831` on
   the probe route.
2. **Authorise the `$80F4F9` dispatch** with a cfg `indirect_dispatch` entry
   (`recompiler/v2/cfg_loader.py` in the pin) and re-measure. Until that is
   done, six of the top ten ranking rows are unreachable by construction, and
   the ranking's own 1.62 % ceiling cannot be reached either.
3. **File the seam number upstream.** The replay seam's cycle bookkeeping is the
   round-3 item; round 4 adds the join: 275,979,837 cycles (30.02 %) already
   inside an `aot_eligible` span across 2801 hot PCs of which 12 are gap-sighted,
   plus the `$81B061` root probe that moved nothing. Cite
   `runner/src/snes/interp_bridge.c` and `runner/src/common_cpu_infra.c:880-935`.
4. **Re-rank before re-seeding.** The accepted program's own ranking says its
   top ten is 52.37 % of a 24,086,298-cycle slice, i.e. 1.47 % of its residue.
   `gap_seeds.py --then` is how that number is produced; if a round does not
   clear the wall-clock floor in `§15` terms, it should be reported as
   inconclusive rather than adopted.

## 21. How to reproduce

```
# the artifact set, from archived measurement only (no legs, no regen, no cmake)
SNESRECOMP_ROOT=<pin> ./tests/round4_artifacts.sh           # rc=0
# the seed tables and the before/after residue join
python3 tests/gap_seeds.py evidence/artifacts/tier2_capture_round3_combat.json \
        --top 10 --route combat --list \
        --manifest evidence/artifacts/round4_manifest_pre.json.bz2 \
        --symbols tests/out/r4/cfg/symbols_base.toml
# the accepted tree, end to end (legs run from tests/out/r4/accepted/, not build dirs)
./tests/accepted_verify.sh
# one rejected variant's phase/state close-out
./tests/rejected_shift.sh s80B1DB
```

`tests/round4_artifacts.sh` refuses to join a report to a leg whose route ends at
a different frame count, and it owns the artifact names, so a regenerated set is
comparable to the one indexed in `artifacts/round4_provenance.txt`.
