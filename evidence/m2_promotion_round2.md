# M2 promotion round 2: the refusal-target seeds, measured

Action record for round 2 of the standing loop opened by `evidence/m1_hybrid_decision.md`
(round 1 is `evidence/m2_promotion_round1.md`). Date: 2026-11-07.

Every number below names its program: framework pin `773285b8210f…`
(`framework_pins.txt`), generated set `53faff9d16de5d9b…` (18 units, 204 promoted
functions, 257 dispatch rows), round-2 AOT executable `833f17c50fb80988…`, round-2
full-LLE floor `a14b59a97e7070cf…` whose own generated set is the archived
`9e060b8c185555a3…` (`evidence/artifacts/lle_floor_gen_r2.tar.gz`), not the live
`src/gen`. Round-1's pair is still where it was: exe `6d8b8e7f97da2cd9…` over set
`27b2fbbd039fe066…`, floor exe `179c9c2523704e31…` over set `2ecb4697e2e7…`. Those
two trees are not rebuilt.

Plain language first, then numbers.

Round 2 changed the seed source. Round 1 had closed the read-trace frontier — the
blocks the interpreter fetched instructions from while sitting outside any proven span —
and 20 of its roots came back `lle_only` with reasons of the shape
`unproven_call_at_<site>_to_<callee>_m<m>x<x>`. Round 2 seeded those 20 callees, on the
theory that naming the missing entry would clear the refusal. It named them, and the
answer came back: **4 new AOT bodies and 45 new instructions — and nothing at all
happened when the machine ran.** The round-2 AOT binary reproduces the round-1 AOT
binary byte for byte across the whole 25,902-frame combat route (52,321 dump files), the
round-2 floor reproduces the round-1 floor byte for byte, cycle counts and interpreted
instruction counts match to the unit, and the cross-path horizon is the same frame,
f16125. The frontier metric is unchanged too (3 blocks, 1,820 reads, 0.0 %).

Two findings carry the round, and both are about where seeds come from rather than how
they compile:

1. **5 of the 20 named callees are addresses that are not ROM.** The analyzer resolves
   those calls `lle_exact` — it has already decided they run interpreted — and the cart's
   LoROM mapping has no byte at those addresses, so the only possible answer is
   `empty_decode`. All 5 were marked `DROP` in `recomp/symbols.toml`, and round 2b has
   taken them out and re-measured the pair (`evidence/m2_promotion_round2b.md` §1–§3).
2. **Static signals are exhausted.** The trace frontier closed in round 1; the
   refusal-callee source produced 4 bodies in round 2 that never dispatch. The runtime
   signal the framework itself calls "the promotion worklist" — the dispatch ring's
   `found:0` entries — is compiled out of our builds; round 2b built it anyway, and it
   answers **0 misses in 574,973 dispatches** (`evidence/m2_promotion_round2b.md` §4).

## 1. What changed, statically

`recomp/symbols.toml` gained 20 `[[func]]` seeds (45 total at this round; 40 from round 2b
on, when the 5 dead ones came out), all named
`CC_<bank><addr>`, entry mode taken from the demand that named them: 11 in `m1x1`,
9 in `m0x0`. Two new analysis units appeared, so `recomp/bank81.cfg` and
`recomp/bankab.cfg` are new files. The pinned analyzer at the pin: `52 roots, 226 exact
AOT variants, 48 LLE variants`.

| quantity | round 1 | round 2 |
| --- | ---: | ---: |
| manifest nodes | 262 | 274 |
| aot_eligible / lle_only | 222 / 40 | 226 / 48 |
| roots | 32 | 52 |
| instructions inside AOT bodies | 8,111 | 8,156 |
| promoted functions in `src/gen` | 210 | 204 |
| dispatch rows | 252 | 257 |
| generated-set digest | `27b2fbbd039fe066…` | `53faff9d16de5d9b…` |

The promoted-function count going *down* while AOT variants go up is naming, not lost
coverage: six `bank_80_*` / `bank_81_*` functions became `CC_*` because a seed now owns
the root (`bank_80_A568` → `CC_80A568`, likewise `BE2B`, `C11F`, `C43E`, `FA31`,
`81_B05D`). Diffing variant keys `(pc24, m, x)` between the archived round-1 manifest
and this one gives the real yield — **4 AOT variants added, 0 removed**:

| new AOT body | insns | span |
| --- | ---: | --- |
| `80FA31_m1x1` | 16 | `80FA31-80FA52` |
| `80FA76_m1x1` | 22 | `80FA76-80FAA6` |
| `81AC79_m1x1` | 3 | `81AC79-81AC7E` |
| `81B05D_m1x1` | 4 | `81B05D-81B067` |

All four are *second modes* of roots whose `m0x0` body round 1 already had. Eight
`lle_only` nodes are new (`8001A9`, `800AAD`, `803230`, `807FA9`, `80A568`, `80BE2B`,
`80FE33_m0x1`, `AB2FAB` — 32 instructions between them, none of it in the 5 impossible
addresses, which decode to nothing). Of the 15 legitimate seeds, 4 promote and 11 stay
`lle_only`: all 11 are refused `truncated_call_continuation`, and 7 of those carry
`unproven_call` and `unproven_callee_exit` as well. Two more seeds came back
`aot_eligible` — `80C11F` (1 insn, `has_lle_indirect_edge`) and `80C43E` (28 insns, no
reasons) — but they already had `m0x0` bodies in round 1, which is why the new-body list
is 4 and not 6.

One correction of our own, made while measuring round 2b and wrong as first written. This
record's first draft claimed that of the 20 callees the refusals named, only 15 became
`[[func]]` entries and that `8001A9`, `800AAD`, `803230` "were never entries at all". They
were: `git show HEAD~1:recomp/symbols.toml` — this round's own commit — carries all 20
`CC_*` seeds, 45 entries in the file. And the nodes came from the seeds, not from the
analyzer independently following call sites: deleting those 5 seeds deletes exactly 5
manifest nodes, 5 roots and 5 dispatch rows. Round 2b's §1 has the table
(`evidence/m2_promotion_round2b.md`).

Seed dispositions, all 20 named callees, from `src/gen/program_manifest.json`:

| seed | mode | disposition | insns | analyzer reasons |
| --- | --- | --- | ---: | --- |
| `8001A9` `800AAD` `803230` `807FA9` `AB2FAB` | m1x1 | lle_only | 0 | `empty_decode`, `structural_poison` |
| `80961C` | m0x0 | lle_only | 13 | `truncated_call_continuation`, `unproven_call`, `unproven_callee_exit` |
| `809676` | m0x0 | lle_only | 4 | same three |
| `80996E` | m0x0 | lle_only | 167 | same three |
| `80A0EB` | m0x0 | lle_only | 3 | same three |
| `80A113` | m0x0 | lle_only | 38 | same three |
| `80A632` | m0x0 | lle_only | 154 | same three |
| `80BF0B` | m0x0 | lle_only | 113 | same three |
| `80A568` | m1x1 | lle_only | 14 | `truncated_call_continuation` |
| `80B07A` | m1x1 | lle_only | 34 | `truncated_call_continuation` |
| `80BE2B` | m1x1 | lle_only | 3 | `truncated_call_continuation` |
| `8186E5` | m1x1 | lle_only | 13 | `truncated_call_continuation` |
| `80FA31` `80FA76` `81AC79` `81B05D` | m1x1 | **aot_eligible** | 16 / 22 / 3 / 4 | (none) |

The config text was edited after measurement — the round-2 header now states the
outcome and marks the 5 impossible seeds `DROP` — and the edit is proven inert:
regenerating at the pin reproduces digest `53faff9d16de5d9b…` with the same 18 units /
204 promoted / 257 rows, so the records below still describe the tree that is checked in.

## 2. Five seeds that cannot be code, and the rule that follows

The 5 zero-insn seeds are not bad luck in the analyzer; the addresses are not ROM:

* `CART_LOROM` in the pinned framework maps a read as
  `off = (bank & 0x7f) << 15 | (adr & 0x7fff)` and returns NULL for `adr < 0x8000` when
  `bank & 0x7f < 0x40` (`runner/src/snes/cart.c`). `$80:01A9`, `$80:0AAD`, `$80:3230`,
  `$80:7FA9` are exactly that: a low canonical bank below `$8000`. They are not address
  space, so the decoder has nothing to decode.
* `$AB:2FAB` maps to cart offset `$15AFAB`, which is past the 1,048,576-byte image.
  Shadowrun (USA) is not an SA-1 card, so there is no bank `$AB` window at all.

The manifest agrees from the other side: every demand that names one of these five is
`resolution = lle_exact`, not `aot_exact` — the recompiler already resolved the call to
"run this interpreted" — and the nodes come back with `empty_decode` plus
`structural_poison` at 0 instructions. Seeding them cannot promote them. What the seeds
*do* produce is 5 dispatch rows with all four variant slots NULL
(`{ 0x8001A9u, { NULL, NULL, NULL, NULL } }` in `src/gen/dispatch_v2.c`, likewise
`0xAB2FABu`). That is inert: `_cpu_dispatch_lookup` returns NULL when the variant slot
is NULL (`runner/src/cpu_state.c:1130`), and `cpu_dispatch_has_entry` therefore reports
no entry — but it is dead configuration, and §3 shows nothing on this route ever looked
at those rows.

The rule for the next round, learned the hard way: **read the demand's `resolution`
before seeding it.** `aot_exact` means a seed can convert something; `lle_exact` means
the analyzer has already decided the callee runs interpreted, and a seed only adds a
row.

## 3. Execution did not move, at byte level

The four records, all from `tests/aot_share.py`, all at the pin:

| leg | exe | generated set | AOT % of cycles | cpu cycles | interp insns | frame-byte digest |
| --- | --- | --- | ---: | ---: | ---: | --- |
| round-1 AOT `build-r0` | `6d8b8e7f97da2cd9…` | `27b2fbbd039fe066…` | 3.9402 | 1,108,981,502 | 263,660,881 | `574e66802bece79d…` |
| round-2 AOT `build-r2` | `833f17c50fb80988…` | `53faff9d16de5d9b…` | 3.9402 | 1,108,981,502 | 263,660,881 | `574e66802bece79d…` |
| round-1 floor `build-llefloor` | `179c9c2523704e31…` | `27b2fbbd…` (live) / set archived `2ecb4697…` | 0.0 | 1,075,171,039 | 265,434,823 | `f73f0014ad3618f3…` |
| round-2 floor `build-llefloor-r2` | `a14b59a97e7070cf…` | `53faff9d…` (live) / set archived `9e060b8c…` | 0.0 | 1,075,171,039 | 265,434,823 | `f73f0014ad3618f3…` |

Equal to the unit on both paths. Stronger than the counters, a byte comparison of the
dump trees — `diff -rq -x run_manifest.json` over 52,321 files per side:

```
xp_aot_r5 vs xp_aot_r6   no output, exit 0
xp_lle_r5 vs xp_lle_r6   no output, exit 0
```

(only `run_manifest.json`, which names the exe and the set, differs, by construction).
So 4 new bodies, 45 new instructions, 5 new dispatch rows and 5 new all-NULL rows
changed not one byte of machine state over 25,902 frames. Coverage says the bodies are
linked: 250/250 generated wrappers are symbols in the round-2 binary, and the four new
variant slots are wired (`{ CC_80FA31_M0X0, NULL, NULL, CC_80FA31_M1X1 }`).

The read-trace frontier, re-measured against the round-2 manifest with the round-1
traces (`tests/frontier_seeds.py`): `274 nodes, 52 roots, 9,343 instructions, spans
over 90 blocks`; **frontier 3 blocks, 1,536 B, 1,820 reads = 0.0 % of 2,785,987,594**,
all three below the 1,024-read floor (`$80:8C00`, `$80:D200`, `$81:A400`). Identical to
round 1's post-state: round 2 bought no span coverage either.

## 4. Fidelity: the same horizon, PASS, and the baseline stays put

`XP_TAG=_r6 XP_INPUTS_CHANGED=1 ./tests/crosspath.sh tests/scripts/combat.txt` with
`PORT_AOT=./build-r2/… PORT_LLE=./build-llefloor-r2/…`, judged against
`tests/baselines/horizon_xp.json`:

```
before the horizon: 16,125 frames; 65 stretches left the band and came back on their
                    own (longest 5,204 frames, peak 995 B)
horizon:  host f16125; last frame that still matched f16124; 26 B outside the frame
          labels (31 B including them)
realignment at the horizon: k=-3 3,252 B · k=-2 2,867 B · k=-1 2,654 B · k=+0 26 B
          (the pairing) · k=+1 283 B · k=+2 396 B · k=+3 1,128 B
          -> no whole-frame shift removes it: the difference is inside the frame
verdict: holds — horizon f16125 vs baseline f16125 (within 1 frame of slack) => PASS
checkpoint bmps: 10 match, 33 differ, 0 missing
```

Both legs printed their deliberate input changes rather than hiding them (`gen_sha256
27b2fbbd… → 53faff9d…`, `gen_functions 210 → 204`, `gen_units 17 → 18`,
`gen_dispatch 252 → 257`), and `tests/provenance.py pin build-r2/… build-llefloor-r2/…`
says both are at the pin.

The baseline is **not** re-bound this round. It is already bound to a pinned pair (the
round-1 pair, f16125 / 26 B / 65 stretches) and the round-6 pair reproduces it
byte-for-byte, so re-binding would swap one set of hashes for an equivalent one while
putting a *mislabelled* `generated_set` into the committed file — a cross-path
`run_manifest` reports the live `src/gen`, so the floor leg writes
`describes_this_binary: false` plus `stale build tree: 7 generated .o against 18
generated units`. That label is a known property of the shared `src/gen` directory
(`evidence/m2_lle_floor.md`), and the floor's own set is the archive named in §5. Re-bind
when a round actually moves the horizon.

## 5. The round-2 floor, proven

`TREE=./build-llefloor-r2 FLOOR_GEN=…/lle_floor_gen_r2.tar.gz
FLOOR_JSON=…/aot_share_lle_floor_r2.json ./tests/make_lle_floor.sh --share
tests/out/xp_lle_r6`:

```
exe  a14b59a97e7070cf…  1,254,608 B      fw 773285b8210f…  (clean)
set  9e060b8c1855… archived, 7 units, 0 promoted, 41 dispatch rows, 9 files
     (incl. bank81_v2.c, bankab_v2.c, unresolved_stubs_v2.c, the cache)
cov  35/35 generated wrappers present in this binary
share AOT 0.0 % of cycles, 265,434,823 interp insns by frame 25,902
PROVEN - 35/35 wrappers linked, aot_cycle_pct 0.0 of 1,075,171,039 cpu cycles
```

Running the same script without `TREE=` re-measured the *round-1* floor binary against
the round-2 archive and correctly answered `NOT PROVEN - 21/35 wrappers linked`: the
proof is per-binary, and the wrapper count is the tell. That is also the first round
where `tests/forces/all_lle.txt` (215 `force_lle` lines) did not have to be regenerated —
it still matches the promotable pc set exactly, so the same force list floors both
rounds' generated sets.

## 6. Why nothing moved, and round 3's seed source

The four new bodies are wired and linked and never run. Two mechanisms fit, and this
round's data cannot separate them:

* **Mode shape.** Each new row is `{ M0X0, NULL, NULL, M1X1 }`; the middle slots
  (`m0x1`, `m1x0`) are NULL. `_cpu_dispatch_lookup` picks the slot by
  `(m_flag<<1)|x_flag` and returns NULL if that slot is NULL. If the runtime mode at
  those entry points is `m1x0`, no body on either row can ever be selected.
* **Entry shape.** Dispatch consults the table at RTS/RTL trampolines and at
  runtime-pointer `JSR (abs,X)` (`runner/src/cpu_state.c:820-826` describes the
  trampoline and its table lookup; `runner/src/snes/interp_bridge.c:2838-2872` is the
  bridge's side of it), not at branch targets. The read trace
  puts enormous interpreter-side traffic inside a span that has had an AOT body since
  round 1 — `$81:B061` 156.9 M and `$81:B065` 157.0 M fetch reads, inside span
  `81B05D-81B067` — which is what a hot loop entered somewhere else, or re-entered by a
  back-edge, looks like.

Both predict exactly the zero movement §3 measured. The framework already names the
instrument that distinguishes them, in `runner/src/cpu_state.c:916-931`: the dispatch
ring records `(pc24, source_pc24, func_name, mx_idx, found, mirror, frame)` per
dispatch and its own comment says *"`found:0` entries name targets with no exact AOT
body (known rows run on LLE; unknown continuations unwind) — the promotion worklist"*.
It is compiled out unless `SNESRECOMP_ENABLE_DISPATCH_HISTORY=ON`
(`runner/runner.cmake:472`), and our report says
`"dispatch_log": {"disabled": true, "total": 0}` — so round 3 starts by building a
diagnostic binary with that option and reading the ring, which is a *runtime* frontier:
the (pc, mode) pairs the machine actually asks for and does not find.

Two cautions for that run: the ring is `DISPATCH_LOG_CAP = 1024` entries, a tail sample,
so either run a short route (`tests/scripts/selfcheck.txt`) or read `dispatch_log_get`
over the TCP debug server during a long one. And if the misses turn out to be mode-shaped,
the lever is not a new seed: `entry_mx_at <pc16> <m> <x>`
(`recompiler-rs/src/cfg.rs:306`) adds a variant to a root that is already promoted, and
no `recomp/*.cfg` in this bundle uses it yet.

Round 3, concrete — and round 2b has already executed items 1 and 2, so the list is
rewritten against what came back:

1. ~~Take the 5 `DROP` seeds out of `recomp/symbols.toml`, regen, rebuild, prove the pair
   again.~~ **Done in round 2b**: 45 → 40 seeds, `269 nodes / 47 roots / 252 rows`, and both
   paths byte-identical to this round's dumps (`574e6680…` AOT, `f73f0014…` floor).
2. ~~Build one diagnostic binary with `-DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON` and rank the
   `found:0` entries by (pc, mx).~~ **Done in round 2b** (`./build-dht`, also
   `SNESRECOMP_ENABLE_TRACE=ON` for the live readouts): **0 misses out of 574,973
   dispatches**, so the ranking is empty.
3. ~~Seed from that ranking, and use `entry_mx_at` where the address is already promoted and
   only the mode is missing.~~ **Not available**: a lookup against a NULL variant slot *is*
   a `found:0` event, and there were none, not even for the 21,234 `m1x0` dispatches the ring
   did see. The four new bodies' rows are never looked up, so adding modes to them is
   predicted inert and is not the next lever.
4. ~~Retire the read-trace frontier as a seed source in `tests/README.md` §7 — it has been
   closed since round 1 and 1,820 reads is below any useful floor.~~ **Done**: §7.7 says so
   since round 2, and §7.8 now retires the dispatch worklist beside it.
5. What is left is an *entry* question, not an address question: the interpreted residue sits
   inside spans that already have AOT bodies, reached by branch rather than by a dispatch the
   table can intercept. Round 3 either finds a lever for that in the framework (and asks the
   framework for it) or records that the 96.06 % is not reachable by promotion on this route.

## 7. Reproduce

```sh
git diff recomp/symbols.toml                    # the 20 round-2 seeds, 5 marked DROP
git status --short recomp/                      # bank81.cfg, bankab.cfg are new
SNESRECOMP_ROOT=<pinned framework> ./tools/regen.sh     # 52 roots, 226 AOT / 48 LLE variants
python3 tests/frontier_seeds.py                 # frontier 3 blocks, 1,820 reads, 0.0 %
python3 tests/aot_share.py build-r2/ShadowrunSNESRecomp --dump-dir tests/out/xp_aot_r6 \
        --json evidence/artifacts/aot_share_round2.json
TREE=./build-llefloor-r2 FLOOR_GEN=$PWD/evidence/artifacts/lle_floor_gen_r2.tar.gz \
  FLOOR_JSON=$PWD/evidence/artifacts/aot_share_lle_floor_r2.json \
  ./tests/make_lle_floor.sh                     # builds the floor tree, then restores
PORT_AOT=./build-r2/ShadowrunSNESRecomp PORT_LLE=./build-llefloor-r2/ShadowrunSNESRecomp \
  XP_TAG=_r6 XP_INPUTS_CHANGED=1 ./tests/crosspath.sh tests/scripts/combat.txt
TREE=./build-llefloor-r2 FLOOR_GEN=$PWD/evidence/artifacts/lle_floor_gen_r2.tar.gz \
  FLOOR_JSON=$PWD/evidence/artifacts/aot_share_lle_floor_r2.json \
  ./tests/make_lle_floor.sh --share tests/out/xp_lle_r6     # PROVEN 35/35, 0.0 %
python3 tests/provenance.py pin build-r2/ShadowrunSNESRecomp build-llefloor-r2/ShadowrunSNESRecomp
diff -rq -x run_manifest.json tests/out/xp_aot_r5 tests/out/xp_aot_r6      # silent
```

Build trees and dump directories are machine state and are not committed. The records
that are — `aot_share_round2.json`, `aot_share_lle_floor_r2.json`,
`lle_floor_gen_r2.tar.gz` — name the digests quoted at the top of this file, and the
round-1 records still name their own (`aot_share_round1.json`,
`aot_share_lle_floor.json`, `lle_floor_gen.tar.gz`).
