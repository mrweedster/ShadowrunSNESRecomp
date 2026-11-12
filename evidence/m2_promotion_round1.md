# M2 promotion round 1: the B0 frontier seeds, measured

Action record for round 1 of the standing loop opened by `evidence/m1_hybrid_decision.md`
("the next action is a round of the loop"). Date: 2026-11-06/07. This file is also the
arbiter promised by `tests/README.md` §7.7 for the `horizon_xp.json` f16122-vs-f16125
discrepancy; it resolves it (see §5).

Plain language first, then numbers.

Round 1 added the 23 frontier-block seeds that the B0 read trace named — every 512-byte
ROM block the trace showed the interpreter taking instruction bytes from while sitting
outside any span the analyzer had proven — and re-ran the generator. The headline is
that the **promotion frontier collapsed from 26 blocks (38.9 % of all ROM reads) to
3 blocks (0.0 %)**. The interpreter still runs most of the code, but the code it runs is
now a named, bounded list: every fetched-but-unproven region of consequence became a
proven node, promoted where provable (8 bodies) and deliberately left `lle_only` where
not (28 nodes, with reasons the analyzer states). Execution itself moved little —
combat dispatch coverage 3.73 % → 3.94 % of cycles — because the seeds' own bodies mostly
cannot yet be proven safe to compile; that is round 2's job, and §6 lists the handles.

Nothing about this round changed what the machine executes: all six read traces are
byte-identical to round 0's, and the AOT-vs-LLE state horizon is unmoved. The change is
in what we can *state* about the machine — which is exactly what M1's decision asked for
("a measured list instead of an accident of the seed symbols").

## 1. What changed, statically

`recomp/symbols.toml` gained 23 `[[func]]` seeds (the header block records the rule:
first byte of a fetch-read 512 B block inside no proven span; `$80:8C00`, `$80:D200`
and `$81:A400` were held back at under 1,024 fetch reads each as too small to trust).
Regenerated with the pinned framework analyzer (`tools/regen.sh`, `SNESRECOMP_ROOT` at
the pin). The analyzer run: `222 AOT-eligible, 40 LLE-only`, 32 roots.

| quantity | before (round 0) | after (round 1) |
| --- | ---: | ---: |
| manifest nodes | 226 | 262 |
| aot_eligible / lle_only | 214 / 12 | 222 / 40 |
| roots | 9 | 32 |
| span bytes / span blocks | 19,888 B / 66 | 35,898 B / 89 |
| **promotion frontier (fetched, in no span)** | **26 blocks = 13 KiB, 1,084,397,942 reads = 38.9 %** | **3 blocks = 1 KiB, 1,820 reads = 0.0 %** |
| lle_only blocks (proven, left interpreted) | 7 | 43 |

New AOT bodies — exactly 8, all in M/X mode, none removed any old one:
`$80:AAA9`, `$80:B07F`, `$80:B08A`, `$80:B095`, `$80:B0A0` (five continuations inside
the `$80:B000` stub's neighbourhood), and seeds `$80:B800`, `$80:C800`, `$80:E000`
themselves. Generated-set digest `065f5b30a545c174…` → `27b2fbbd039fe066…`
(17 units, 210 promoted functions, 252 dispatch entries).

Re-derive both sides: `src/gen/program_manifest.json` after; the round-0 manifest and
the two digests are kept at `evidence/artifacts/b0_digest.txt` (round 0, committed) and
`evidence/artifacts/b0_digest_round1.txt` (this round). The frontier table is what
`tests/cart_trace_report.py --digest` joins: fetch footprint × analyzer spans.

## 2. Why only 3 of 23 seeds promoted

Every seed became a node; 20 were refused, with the analyzer's own reasons:

| reason class | seeds | reading |
| --- | --- | --- |
| `brk_at_*` + `structural_poison` (12 seeds) | `$80:00,8600,8800,8A00,9200,AC00,AE00,B200,B400,CA00,D000,F400` | these blocks execute `BRK` — they are reset/dispatch-vector-style stubs or table heads, not ordinary routines |
| `truncated_call_continuation` (8 seeds) | `$80:8200,9000,B000,B600,C600,CE00,DE00,F600` | the block is the tail of a call whose entry the analyzer cannot name; it names the callee anyway (`8186E5`, `807FA9`, `80B07A`, `803230`, `AB2FAB`, `800AAD`, …) |

Those named callees are round 2's seed list — 20 addresses surface in the refusals
(`8001A9 800AAD 803230 807FA9 80961C 809676 80996E 80A0EB 80A113 80A568 80A632 80B07A
80BE2B 80BF0B 80C11F 80C43E 80FA31 8186E5 81B05D AB2FAB`); several already have nodes
(`80A568`, `80BE2B`, `80C43E`, `80FA31` are promoted). The `BRK` stubs should probably
stay LLE: they are cart-level glue, and the frontier no longer pays for them being
unproven (they are spans now, and the three frontier blocks left are `$00:0C00-0DFF`,
`$00:5200-53FF` — 1,820 reads).

## 3. Execution traffic did not move — and that is expected

All six read traces re-collected under the round-1 binary are **byte-identical** to the
committed round-0 inputs (trace sizes and sha256 prefixes match `b0_digest.txt` exactly:
combat `cbb2baa0…`, door `d3e0c1fa…`, menu `803d41c1…`, nav1 `8c8f59f5…`, nav2
`3d2adb6b…`, selfcheck `8ff305aa…`; merged 2,785,987,594 ROM reads, 1,833,786,930
fetch reads, both unchanged to the unit). AOT and LLE take their instruction bytes
through the same instrumented seams, so promotion is invisible to fetch counts — the
frontier metric moves through the *spans* side of the join, not the fetch side, and the
byte-identity is what proves the round perturbed nothing.

The progress metric that does move is dispatch attribution, and it needs binding to a
program, not to a log line: `tests/aot_share.py` now records it with the executable
hash, generated set and framework revision
(`evidence/artifacts/aot_share_round1.json`). Combat, 25,902 frames:

| | AOT share of cycles | interp insns | cpu_cycles | master_cycles |
| --- | ---: | ---: | ---: | ---: |
| pre-round control record (`a6b_control.txt`) | 3.73 % | 257,938,687 | 1,094,544,210 | 9,256,852,870 |
| round 1 (`aot_share_round1.json`) | **3.94 %** | 263,660,881 | 1,108,981,502 | 9,257,210,204 |
| full-LLE control leg | 0.00 % | 265,434,823 | 1,075,171,039 | 9,257,210,226 |

The round-1 master-cycle count lands **22 cycles** off the full-LLE reference across
9.26 G bus cycles — the compiled path now keeps the bus exactly where the interpreter
keeps it (that is the pin's insn-granularity deadline unwind doing its job; the
pre-round AOT build was 357,356 cycles away).

## 4. Fidelity: the horizon is unmoved, and it is now reproducible

Cross-path (`tests/crosspath.sh tests/scripts/combat.txt`, AOT `build-r0` vs full-LLE
control): **PASS, horizon host f16125, 26 B at horizon, 65 healing stretches, longest
5,204, peak 995 B** — identical to the bound baseline `tests/baselines/horizon_xp.json`
(f16125 / 26 B / 65) recorded on the round-0 pair. Promotion neither created nor exposed
a visible-state divergence through the whole 25,902-frame route; the residual mismatch
point predates it and survives it unchanged.

Provenance for the pair, from the run manifests: `run1` `build-r0` **AT THE PIN**
(`773285b8…`, generated set `27b2fbbd…`); `run2` the older full-LLE control binary
(exe `ca875eb9…`, framework `76eda6dd…`, *not* the pin) — allowed as the floor, but it
means the pair cannot re-record the baseline again under the pin rule (§7.7's "never
from a copy build"). Round 2 should rebuild the LLE floor at the pin from an all-forced
`lle` generated set so the pair is fully bound; a plain rebuild of `build-lle` against
today's `src/gen` is *not* that — it inherits the round-1 AOT bodies and runs at 3.94 %,
which was itself a useful finding: the "full-LLE" property lives in the generated set,
not in any build switch.

Separately, the observer question for every trace claim in this file: a pair built from
the pinned tree **with** the cart-trace patch compiled in and a byte-same tree **without**
it (`sr-pin` vs `sr-clean` at `773285b8…`, same generated set) ran 25,902 combat frames
with **zero** bytes of state divergence and byte-identical counters — observation code
compiled but inactive moves nothing; and the traces themselves reproduce byte-for-byte
across rebuilds (§3).

## 5. The §7.7 discrepancy, resolved

The old unbound baseline (kept at `tests/baselines/horizon_xp_prebound.json`) records
f16122 / 59 B / 71 stretches; every pinned-framework measurement — yesterday's bound
re-record and this round's replay — records f16125 / 26 B / 65. Three distinct program
states (pre-round pair, round-0 bound pair, round-1 replay) all reproduce f16125 / 26 B
/ 65; the f16122 record's legs are unbound (no `run_manifest.json` existed then) and
predate the framework revision the pin names. The replay says which to believe:
**f16125 / 26 B / 65 is the reproducible reference point**, the f16122 record is a
different-framework artifact that does not reproduce, and the bound baseline already
carries the right numbers. No action needed beyond this sentence being where §7.7 said
it would appear.

## 6. Round 2, concrete

1. Seed the refusal call targets that have no node yet (`8186E5`, `807FA9`, `803230`,
   `800AAD`, `AB2FAB`, `8001A9`, … from §2); the trace frontier is exhausted, so seeds
   now come from reason strings, not from read traces.
2. Rebuild the full-LLE control at the pin (all-promotable functions forced `lle` →
   regen → build) so horizon pairs are fully provenance-bound; keep the old control's
   exe hash (`ca875eb9…`) in the current baseline's memory until then.
3. Framework-side lever, not project-side: `truncated_call_continuation` is one
   mechanism refusing 8 of 20 seeds by not being able to name an entry; `brk` stubs
   should be declared `lle_by_design` in the manifest rather than looked at again.
4. The three surviving frontier blocks (`$00:0C00-0DFF`, `$00:5200-53FF`, 1,820 reads)
   are small and bank-`$00`-mirrored; check them once, then the frontier line can be
   retired as a seed source.

Round 2 ran items 1 and 2 as written; item 1's yield was 4 bodies that never dispatch and
5 of the 20 callees turn out to be addresses the cart does not map at all. Item 4's
retirement is now written into `tests/README.md` §7 too. The outcome, and the runtime
signal round 3 has to use instead: `evidence/m2_promotion_round2.md`.

## 7. Reproduce

```sh
git diff recomp/symbols.toml                 # the 23 seeds and their rule
SNESRECOMP_ROOT=<pinned framework> ./tools/regen.sh    # 222 AOT / 40 LLE, 32 roots
bash tests/collect_read_traces.sh            # six traces; ring-cap notes expected
python3 tests/cart_trace_report.py tests/out/b0/*.json --port-root . \
        --digest evidence/artifacts/b0_digest_round1.txt
python3 tests/aot_share.py build-r0/ShadowrunSNESRecomp \
        --dump-dir tests/out/xp_aot_r5 --cart-trace tests/out/b0/combat.json
PORT_AOT=./build-r0/ShadowrunSNESRecomp PORT_LLE=./build-llefloor/ShadowrunSNESRecomp \
        XP_TAG=_r5 XP_INPUTS_CHANGED=1 ./tests/crosspath.sh tests/scripts/combat.txt
./tests/make_lle_floor.sh --share tests/out/xp_lle_r5   # re-records the floor's share
```

Traces and build trees are machine state and are not committed; the digests and the
`aot_share_round1.json` record are, and they name the hashes that bind everything:
exe `6d8b8e7f97da2cd9…` (round-1 rebuild; the baseline's recorded `run1` exe
`09b317eb…` carries the same generated set — the bound identity is the generated set,
and both legs' `--inputs-changed` notes are printed rather than hidden),
generated set `27b2fbbd039fe066…`, framework `773285b8210f…`.

As recorded on 6 Nov this pair's "LLE" leg was `build-lle`, which turned out not to
be an LLE floor at all: it inherited round-1's promoted bodies and measured 3.94 %
AOT, and its recorded leg ran on framework `76eda6dd…`, off-pin. The control is now
the tree `./tests/make_lle_floor.sh` builds, proven 0.0 % AOT, and the pair
`xp_aot_r5` / `xp_lle_r5` is what `tests/baselines/horizon_xp.json` is bound to —
same horizon (f16125, 26 B, 65 stretches) with a control that is actually all-LLE.
`evidence/m2_lle_floor.md` records that rebuild and why a build option cannot make
a floor.
