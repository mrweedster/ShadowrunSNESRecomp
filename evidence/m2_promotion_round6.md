# M1/M2 promotion, round 6: the `f1828` cluster, body by body

Date: 2026-11-08. Branch: `main`. Everything below is a measurement.

Round 5 shipped the dispatch directive and no new seed: all six candidate seeds
failed the same state gate, first divergence `frame_001828`, and round 5 §8
localised the split to the direct page and the `$0134-$013A` cluster without
naming the body that writes it. This round
takes the seed round 5 rejected (`$80C1C9`), holds the shipped pair fixed as the
control, and demotes the bodies the seed adds until the divergence disappears.

**What this round found.** Two compiled bodies carry the whole gate divergence:
`$80AD9F` and `$80C530`. Demoting just those two back to the interpreter
restores the shipped pair exactly — crc32 identical and no non-label WRAM byte
differs over all 4,575 frames — and removing either one from that set brings
the divergence back, so the attribution is 1-minimal over that body set.
`artifacts/round6_cluster_hunt.txt` is the measurement; this record reads it.

**What shipped: nothing.** The two-body profile is not adopted: it keeps 3.4 %
of the seed's cycle gain (§6), and the shipped tree still has the round-5 pair
as its control (`a0587ed0a0e34687`, the same executable as round 5). This round
adds tools and an artifact, no configuration and no seed.

## 1. The question, and the rules it is answered under

Round 5 ended with a measured reason to stop seeding and one open attribution:
six different seeds shared one onset, so the failure looked like a property of
a compiled cluster rather than of any one seed. Round 5 §12 asked the next
round to narrow that cluster one body at a time. The question here is exactly
that: **which compiled bodies, added on top of the shipped pair, compute
different machine state from the pair, and what does it cost to keep them
interpreted?**

The design is `pair + body` against `pair`, not `base + seed` against `base`:
the control is the tree that ships, and every demotion is measured against it.
The rules are the round-4/round-5 rules:

* a seed is adopted only if its compiled bodies compute the same machine state
  as the control; cycle-share movement alone is not a win;
* a claimed difference has to clear the same-binary replicate spread;
* no harness leg may reach the ROM file-picker;
* body lists are derived from the generated manifests, never hand-edited;
* identity-sensitive legs run from scratch anchors, never inside `build-*/`;
* every number in this record appears in `evidence/artifacts/`, and the
  artifact generator runs no route leg, no regen and no cmake.

The verdict used for the search is `framedump_diff.py state`, which ignores the
frame-kernel label bytes. The label-inclusive per-frame `crc32_wram` is
recorded beside it, because that is the gate round 5 quoted.

## 2. The control, the candidate, and the passing profile

`artifacts/round6_cluster_hunt.txt` §1 derives all of this from the archived
manifests, not from a log line:

```
                     283 nodes   240 aot    43 lle   49 roots  pair         a0587ed0a0e34687
                     486 nodes   349 aot   137 lle   50 roots  candidate    9739f7432c1c2ff0
                     462 nodes   330 aot   132 lle   50 roots  adopted      5f8a67db612695bd
```

* **pair** is `tests/seed_variant.sh r6pair --only '$80C399,$80AAB3'`. It is
  the shipped round-5 pair, executable `a0587ed0a0e34687`
  (`m2_promotion_round5.md` §11).
* **candidate** is `tests/seed_variant.sh r6pc1c9 --only
  '$80C399,$80AAB3,$80C1C9'`. The seed adds 203 nodes (109 `aot_eligible`, 94
  `lle_only`) over the pair, and leaves all 283 pair nodes in place. It
  reproduces the round-5 sweep verdict exactly, which is the check that this
  tree is the one round 5 rejected: `first divergence at frame_001828;2745 of
  4575 frames differ`.
* **adopted** is the candidate with `force_lle 80AD9F,80C530` spliced into the
  marked blocks at the end of `recomp/bank80.cfg` and `recomp/bank81.cfg`. It
  is a measurement profile, not a candidate for shipping.

The seed address itself is not compiled in the candidate: `$80C1C9:M0X0` is
`lle_only`, with reasons `truncated_call_continuation`,
`unproven_call_at_80C1D8_to_80F342_m0x0`, `unproven_callee_exit`. The
divergence comes from bodies the seed makes reachable, not from a body at the
seed address.

Provenance: framework pin `773285b8210f2254ae87d0a14113980fb36990ad`,
`dirty=no` (artifact header). The two manifests are archived as
`tests/out/r4/manifest_r6pair.json.bz2` and `manifest_r6pc1c9.json.bz2`; the
adopted profile's manifest is copied to `tests/out/r6/manifest_adopted.json`
and its run report to `tests/out/r6/report_adopted_final.json`.

## 3. The method: demote a body, not a root

A seed root pulls its call-graph closure with it, so "pair plus one body" is
not expressible as a seed table: adding a root to get one body also adds every
callee and every node the analysis now sees. The only direction that isolates
a body is the other one: start from the failing candidate and put chosen
bodies back on the interpreter tier.

The lever is the framework's `force_lle <pc24>` directive
(`recompiler/v2/cfg_loader.py`; a body listed there keeps an exact
architectural boundary on the interpreter tier). `tests/cluster_hunt.sh`:

1. regenerates the candidate seed table with `tests/gap_seeds.py
   --baseline-only` plus `--only '$80C399,$80AAB3,$80C1C9'`;
2. splices the force file into a block marked `force_lle (round-6 cluster
   hunt)` at the end of `recomp/bank80.cfg` and `recomp/bank81.cfg`;
3. regenerates `src/gen` at the pin, rebuilds `build-r6hunt`, and runs
   `tests/parity.sh` against `build-r6pair` on `tests/out/probe_dense.txt`;
4. records both verdicts per leg: `crc32_wram` from the parity log and
   `framedump_diff.py state` from the frame dumps.

The 109-body universe is derived by `tests/cluster_ddmin.py` as the difference
between the two archived manifests, restricted to `aot_eligible`. Nothing in
the list is hand-typed.

Two controls anchor the search. Demoting nothing reproduces the candidate
(`f1828`, state `f1830`, `305 of 4575` frames, `895` bytes). Demoting all 109
restores the pair (`identical over 4575 frames`, no non-label byte differs).
The second is the experiment that proves the divergence is in those 109 bodies
and nowhere else: the seed's 94 `lle_only` additions do not move the state.

## 4. Attribution

The search starts from a known-clean set. Demoting the first 52 bodies in PC
order is already clean, which cuts the universe in half before the first
minimisation step; `tests/cluster_ddmin.py --universe 52` then removes chunks
until no single body can be put back. `artifacts/round6_cluster_hunt.txt` §4
is the leg list; the clean and dirty legs read:

```
  dd01          26  clean
  dd02          13  dirty: 1409 frames, 3409 bytes
  dd03          13  dirty: 2485 frames, 5548 bytes
  ...
  dd21           2  clean
  dd22           1  dirty: 1409 frames, 3409 bytes
  dd23           1  dirty: 2485 frames, 5548 bytes
```

The 1-minimal clean set is

```
$80AD9F   73 insns  $80AD9F-$80AE40
$80C530   19 insns  $80C530-$80C55C
```

and the necessity check puts each one back into the compiled set separately:

```
verify_80AD9F   1  dirty: 1409 frames, 3409 bytes
verify_80C530   1  dirty: 2485 frames, 5548 bytes
```

So neither body is redundant. The `verify_80AD9F` leg demotes only `$80C530`,
leaving the `$80AD9F -> $80ABBC` path compiled, and its footprint is exactly
round 4's `s80ABBC` signature — first state byte `$7E00126: 88 -> 85` at
`f1830`, `1409 of 4575` frames, `3,409` bytes (`m2_promotion_round4.md` §10
table). That is the older callee's divergence showing through once the latch
read is interpreted. Demoting `$80AD9F` as well takes `$80ABBC` out of the
compiled path, and the residual disappears.

The frame counts are **not monotone** in the demotion set: 305 frames with
both compiled, 1,409 with only `$80C530` interpreted, 2,485 with only
`$80AD9F` interpreted, 0 with both interpreted. A single wrong value would move
one byte at one point. This pattern is the signature of a read whose result
depends on when it runs, which is what §5's disassembly shows.

The sibling manifests place the same two bodies in the round-5 sweep
(`artifacts/round6_cluster_hunt.txt` §7):

```
  s80AAB3      282 nodes  239 aot  both no
  s80ABBC      270 nodes  227 aot  both no
  s80B1DB      272 nodes  229 aot  both no
  s80C1B3      477 nodes  339 aot  both yes
  s80C1C9      476 nodes  339 aot  both yes
  s80C399      270 nodes  227 aot  both no
  s80F362      476 nodes  339 aot  both yes
  s80F495      476 nodes  406 aot  both yes
  s80F4F9      476 nodes  339 aot  both yes
  s80F889      476 nodes  339 aot  both yes
```

The five siblings of `$80C1C9` all compile both bodies; the pair's own seeds do
not. That is why six different roots shared one onset in round 5 and why fixing
one seed's table would not have moved the gate.

## 5. The two bodies, and the mechanism

`$80C530` is 19 instructions, and it reads the PPU's counters:

```
$80C530  08             PHP
$80C531  E230           SEP #$0030
$80C533  AC041D         LDY 1D04
$80C536  AD3721         LDA 2137
$80C539  B95DC5         LDA C55D,y
$80C53C  4F921C7E       EOR 7E1C92
$80C540  8500           STA 0000
$80C542  4D3C21         EOR 213C
$80C545  A8             TAY
$80C546  B95DC5         LDA C55D,y
$80C549  4F931C7E       EOR 7E1C93
$80C54D  8501           STA 0001
$80C54F  4D3D21         EOR 213D
$80C552  CD041D         CMP 1D04
$80C555  D001           BNE $C558
$80C557  1A             INC A
$80C558  8D041D         STA 1D04
$80C55B  28             PLP
$80C55C  60             RTS
```

It mixes a ROM table (`$80C55D`) with the SNES's own elapsed-time counters —
`$2137` (the H/V latch trigger), `$213C`/`$213D` (H and V counter low bytes) —
plus two bytes the game keeps at `$7E1C92/$7E1C93`, and writes the result into
DP `$00`/`$01` and `$1D04`. The state scan's first differing byte at `f1830`
is `$7E00126: 88 -> 85`; the DP `$7E00000`/`$7E00001` writes open at `f1832`
(`$7E00000: FF -> 2C`, `$7E00001: FF -> 82`). Those are the bytes this mix
produces, and they are the cluster rounds 4 and 5 tracked.

The read is inherently phase-sensitive: `$2137`/`$213C`/`$213D` report the
position within the frame, not a value the program computed, so the same
instruction sequence run on two different instruction timings returns a
different number. That is enough to explain both the persistent DP divergence
and its non-monotone frame count (a different phase aliases to a different
number of frames, not monotonically fewer or more). This is a different sense
of "phase" from round 4 §10: that section rules out a *host-frame pairing*
artifact (both legs' guest counters pair one-to-one at `k=+0`) and is not a
claim that the compiled bodies compute the right value from the counters.

`$80AD9F` is 73 instructions and sits on the same state-machine path; it calls
`$80ABBC` (round 4's rejected seed) and two bank-81 helpers:

```
$80AD9F  BD5C11         LDA 115C,x
$80ADA2  F012           BEQ $ADB6
$80ADA4  20BCAB         JSR ABBC        ; $80ABBC, round 4's rejected seed
$80ADA7  BD5C11         LDA 115C,x
$80ADAA  F02C           BEQ $ADD8
$80ADAC  2210A981       JSL 81A910
$80ADB0  225DB081       JSL 81B05D
$80ADB4  80EE           BRA $ADA4
```

`$80C530` is also one of the 50 targets the round-5 directive authorises, so
the dispatch at `$80F4F9` can transfer to it.

**The trace names the store.** `tests/latch_writer.py` on trace builds of the
same two programs (`build-r6tr-ctrl` / `build-r6tr-seed`,
`-DSNESRECOMP_ENABLE_TRACE=ON`, executables `fc8d53db15348ab9` /
`a6663cee829df765`) reads the WRAM write ring for DP `$00`/`$01` across the
onset (`artifacts/round6_cluster_hunt.txt` §8). At `f1832` the control's
`$0001` write is `08` from `pc=$80C54D`, the interpreter's `STA $01` inside
`$80C530`; the seed's is `82` from `func=bank_80_C530_M0X0`, the compiled
body. `$0000` is `2C` on both legs at that store, because it is computed from
`$1D04` and `$7E1C92` before the `$213C` read; its next value differs because
the write stream has already moved. `$0001` is the first byte downstream of
`$213C`, the H counter — exactly the phase argument above: the compiled body
reaches the read at a different horizontal position. The `f1832` dumps show
`$7E1C92` and `$7E1C93` unchanged, so the input that moved `$0001` is the
counter, not the game's mix bytes.

The stock `latch_writer.py` pc pass arms 400 frames before the split, but the
DP `$00`/`$01` slice of the ring held 3,898 entries and reached only `f1808`,
so it never saw `f1832`. `--pc-arm 1828` arms shortly before the split
instead; the default is unchanged. That is a recording-window limit, not an
attribution one: the paged onset pass had already named
`bank_80_C530_M0X0` at `f1832` before the pc pass ran.

## 6. What the passing profile costs

`artifacts/round6_cluster_hunt.txt` §5, from `execution_share` in each run
report:

```
  leg         interp %    aot %   interp_cycles      saved
  pair         91.3356   8.6644     178,528,177          0
  candidate    89.1809  10.8191     174,315,380  4,212,797
  adopted      91.2620   8.7380     178,384,304    143,873
```

`cpu_cycles 195,463,918` and `master_cycles 1,635,265,512` are identical in all
three: the total budget does not move, only the tier split. The two demoted
bodies carry `4,068,924` of the seed's `4,212,797` saved cycles, so the adopted
profile keeps **3.4 %** of the seed's gain.

The analysis side is not just "two bodies": `force_lle` names two, but the
resulting program has 19 fewer AOT bodies than the candidate (330 against 349)
and 24 fewer nodes (462 against 486) — of the 19, 16 are dropped and 3 change
to `lle_only`, because demoting the roots also removes the bodies only they
reached. What it buys against the pair is 90 AOT bodies, 179 nodes and `+0.074`
points of AOT share (8.6644 → 8.7380) — and what it costs is 4,068,924 of the
seed's 4,212,797 cycles.

The adopted profile is deterministic: three rebuilds (`adopted`,
`adopted_verify`, `adopted_final`) produced the same executable
`5f8a67db612695bd`, each reporting identical crc and no differing state byte.
The 22-checkpoint APU adoption gate was not run because this profile is not a
ship candidate.

## 7. Decision record

1. **Ship no seed and no `force_lle` block.** The shipped pair stays
   `a0587ed0a0e34687`; the tree's config is unchanged by this round. The
   two-body profile is a measurement, and at 3.4 % of the gain it does not
   pay for the analysis complexity it adds.
2. **The `f1828` cluster is named, with its store.** `$80AD9F` and `$80C530`
   are jointly necessary and sufficient over the 52-body clean universe, which
   is itself a subset of the 109 AOT bodies the rejected seed adds. The write
   trace names the compiled store: `bank_80_C530_M0X0` writes `$0001=82`
   against the interpreter's `08` at `$80C54D`. Any future proposal that
   compiles either body must re-run this gate; a seed table change alone will
   not fix it.
3. **A seed is still not a cycle win by itself.** The candidate saved
   4,212,797 interpreted cycles with no total-budget change, but moved guest
   state. The gate, not the share, remains the decision.
4. **The next lever is tier pricing, not another seed.** `$80C530` reads
   hardware counters; the interpreter and the AOT path reach that read with
   different instruction timing. Making the AOT path charge the same cycles at
   that read (so the counter returns the same phase) is the change that would
   let bodies like these compile without moving state. That is a framework
   question, not a Shadowrun seed question.

## 8. How to reproduce

The artifact is files-only and needs only the pin:

```sh
SNESRECOMP_ROOT=/path/to/pin python3 tests/cluster_hunt_report.py \
    > evidence/artifacts/round6_cluster_hunt.txt
```

It reads `tests/out/r6/hunt.tsv`, the per-leg sidecars, the two archived
manifests, the adopted manifest, the three run reports and the writer trace in
`tests/out/r6/gate_writer_r6.txt`; it runs no route leg, no regen and no cmake.

The measurement legs, in order:

```sh
. tests/rom.sh
SNESRECOMP_ROOT=/path/to/pin ./tests/seed_variant.sh r6pair \
    --only '$80C399,$80AAB3'
SNESRECOMP_ROOT=/path/to/pin ./tests/seed_variant.sh r6pc1c9 \
    --only '$80C399,$80AAB3,$80C1C9'
SNESRECOMP_ROOT=/path/to/pin python3 tests/cluster_ddmin.py --universe 52
```

The trace builds reuse the generated sets the two `seed_variant.sh` runs
archived (`tests/out/r4/gen_r6pair.tar.gz`, `gen_r6pc1c9.tar.gz`):

```sh
rm -rf src/gen && tar xzf tests/out/r4/gen_r6pair.tar.gz -C src
cmake -S . -B build-r6tr-ctrl -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT=/path/to/pin -DSNESRECOMP_ENABLE_TRACE=ON
cmake --build build-r6tr-ctrl -j8
rm -rf src/gen && tar xzf tests/out/r4/gen_r6pc1c9.tar.gz -C src
cmake -S . -B build-r6tr-seed -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT=/path/to/pin -DSNESRECOMP_ENABLE_TRACE=ON
cmake --build build-r6tr-seed -j8
SNESRECOMP_ROOT=/path/to/pin bash tools/regen.sh   # restore the live set

WT_LEGS=ctrl=build-r6tr-ctrl/ShadowrunSNESRecomp,seed=build-r6tr-seed/ShadowrunSNESRecomp \
  python3 tests/latch_writer.py --addrs 0x000,0x001 \
      --route tests/out/probe_dense.txt --park 1832 --pc-arm 1828 \
      > tests/out/r6/gate_writer_r6.txt
```

`tests/cluster_hunt.sh <label> <force-file>` is the single leg: it regenerates
at the pin, rebuilds `build-r6hunt`, runs `tests/parity.sh` against
`build-r6pair` on `tests/out/probe_dense.txt`, and records both verdicts.
`tests/out/r6/hunt.tsv` is the leg ledger and `tests/out/r6/forces_*.txt` are
the generated force lists; both are scratch and stay out of git.

## 9. What the next round should do

* Price the counter read. `$80C530`'s `LDA $2137` / `$213C` / `$213D` is the
  measured phase source. The seam report's next step is the same one round 5
  named: an instruction-level AOT charge at the read, so the same guest
  instruction sequence returns the same counter value on both tiers.
* Treat `$80AD9F`/`$80C530` as a regression pair. Any framework change that
  touches AOT timing should be checked by compiling them, not by interpreting
  them: if they stay clean, the phase bug is fixed.
* Keep `$001F0` as its own gate, unchanged from round 5. It is not part of this
  cluster.
