# The full-LLE control: what the floor actually is, and what it measures

Recorded 2026-11-07. Every number here is bound to framework
`773285b8210f2254ae87d0a14113980fb36990ad` (`framework_pins.txt`) and to the
generated-set digests named beside it. `tests/README.md` §7.2/§7.6 carry the
prose rules; this file is the measurement.

## 0. Why this file exists

Every cross-path verdict compares the promoted program against "the interpreted
floor", but no build switch produces an interpreted program. Promotion happens in
the analyzer, so the LLE-ness of a build is a property of the **generated set**,
and a tree configured "as LLE" but regenerated from the current `recomp/symbols.toml`
inherits the promoted bodies anyway:

```
build-lle  exe cf269653a7…   aot_cycle_pct 3.94   # the old "floor"
```

That is the same share as the promoted build, i.e. `build-lle` was not a floor. Its
counterpart in the recorded baseline was worse than merely AOT-contaminated: the
leg stored in `horizon_xp.json` was exe `ca875eb989454489…`, built on framework
`76eda6dd3ce5…`, off-pin. Both have been retired; the binary is deleted and the
record kept as `tests/baselines/horizon_xp_prebound.json`.

## 1. How the floor is built

`./tests/make_lle_floor.sh` (idempotent; `TREE=` names the tree):

1. splice `tests/forces/all_lle.txt` — 215 `force_lle <pc24>` lines, one per
   promotable function in the round-1 manifest (222 nodes over 215 distinct pcs) —
   into the marked block at the bottom of `recomp/bank00.cfg`;
2. regenerate at the pin: `v2_emit: 24 roots, 0 exact AOT variants, 31 LLE variants`;
3. archive that generated set (`evidence/artifacts/lle_floor_gen.tar.gz`) before the
   restore overwrites the shared `src/gen`;
4. configure + build the tree;
5. prove the floor (§2), then empty the force block and regen back to the working set
   (`27b2fbbd039f…`, 210 promoted) — without rebuilding any tree whose executable a
   committed record cites.

Floor generated set: **`2ecb4697e2e77e66…`**, 5 units, 0 promoted functions, 29
dispatch entries, 7 files. Floor executable: **`179c9c2523704e31…`**, 1,253,488 B
(the promoted build is 3,329,664 B — the size delta is the AOT bodies).

## 2. The floor is proven twice, and the two proofs cover different failures

| proof | instrument | result |
| --- | --- | --- |
| coverage | `nm` against the **archived** set | 21/21 declared wrappers linked, `wrappers_missing_from_binary: []` |
| share | the run's own breadcrumb, 25,902-frame `combat.txt` | `aot_cycle_pct 0.0`, `interp_cycle_pct 100.0` of 1,075,171,039 cpu cycles |

Coverage without the share would be a link-map; share without coverage could mean
"AOT never ran" rather than "AOT does not exist". Bound record:
`evidence/artifacts/aot_share_lle_floor.json`; comparison against the round-1 record:

```
$ python3 tests/aot_share.py --pair evidence/artifacts/aot_share_round1.json \
        evidence/artifacts/aot_share_lle_floor.json
same inputs   : no
share A    : aot 3.9402 % of cycles, 263,660,881 interp insns, exe sha 6d8b8e7f97da2cd9
share B    : aot 0.0 % of cycles, 265,434,823 interp insns, exe sha 179c9c2523704e31   (linked set 2ecb4697e2e77e66, live src/gen was 27b2fbbd039fe066)
```

Round-1 AOT leg for reference: 1,108,981,502 cpu cycles, 263,660,881 interp insns,
96.0598 % interpreted. The floor spends **9,257,210,226** master cycles over the same
route against the promoted build's **9,257,210,204** — 22 cycles apart on 9.26 G,
which is the frame-boundary bookkeeping, not a behavioural difference.

## 3. The floor as the control leg of the horizon gate

Pair `tests/out/xp_aot_r5` (build-r0, exe `6d8b8e7f97da2cd9…`, set
`27b2fbbd039f…`) against `tests/out/xp_lle_r5` (build-llefloor, exe
`179c9c2523704e31…`, set `2ecb4697e2e7…`), both at the pin, judged with
`--inputs-changed`, `XP_UPDATE=1` re-recording the baseline:

```
horizon: host f16125; at the horizon 26 B (31 B including frame labels)
before the horizon: 16,125 frames, 65 stretches out of band, longest 5,204 frames
VERDICT: PASS
```

identical to the previous bound baseline (f16125 / 26 B / 65), so the control that
was actually all-LLE reproduces the same horizon the contaminated control did. The
old pair measured that with an off-pin, partly-AOT leg; the baseline now names two
pinned exes and the difference is only honest labelling (§4).

Determinism check, same binaries, two independent captures: `xp_aot_r4` vs
`xp_aot_r5` and `xp_lle_r4` vs `xp_lle_r5` are byte-identical over all 25,902 frames
apart from `run_manifest.json`.

## 4. `src/gen` is shared, so a digest is not a fact about a binary until it says so

`src/gen` is one directory for every build tree; whoever regenerated last owns it.
That made the round-3 verdict print this for the floor leg:

```
run2  179c9c2523704e31 …  gen 17 units / 210 promoted fns … sha256 27b2fbbd039fe066
      WARN stale build tree: 5 generated .o against 17 generated units in src/gen
```

which reads as a fact about the floor and is a fact about the directory. Three
changes follow, all in the test tooling:

- `tests/provenance.py` records `generated_set.describes_this_binary`, and
  `framedump_diff` prints ` <-- live src/gen, not this binary's set` beside the line;
- `tests/aot_share.py` measures wrapper coverage against an explicit `--gen-root`
  and records which set (`coverage.measured_against.generated_set_sha256`), so the
  21/21 claim is checked against `2ecb4697e2e7…` and not against whatever `src/gen`
  holds; `--pair` now compares linked sets, not live directories — before this it
  said `same inputs : yes` for two binaries built from different sets;
- the floor's set is archived, because a claim that has to outlive the next
  regeneration needs the bytes, not a pointer to a mutable path.

Two traps found while building the archive, both silent: BSD `tar --options
mtime=…` is not an option and yields an empty archive while exiting 0, and the
analyzer's `.snesrecomp-cache.json` **is** part of a generated-set digest — an
archive that excludes it digests differently while every line of code matches.

## 5. Reproduce

```sh
./tests/make_lle_floor.sh                       # ~4 min: splice, regen, archive, build
PORT_AOT=./build-r0/ShadowrunSNESRecomp \
PORT_LLE=./build-llefloor/ShadowrunSNESRecomp \
XP_TAG=_r5 XP_INPUTS_CHANGED=1 XP_UPDATE=1 ./tests/crosspath.sh   # the pair above
./tests/make_lle_floor.sh --share tests/out/xp_lle_r5             # re-bind the share
python3 tests/aot_share.py --pair evidence/artifacts/aot_share_round1.json \
        evidence/artifacts/aot_share_lle_floor.json
```

Committed: `tests/make_lle_floor.sh`, `tests/forces/all_lle.txt`,
`evidence/artifacts/aot_share_lle_floor.json`,
`evidence/artifacts/lle_floor_gen.tar.gz`, `evidence/m2_lle_floor.md`,
re-bound `tests/baselines/horizon_xp.json`. Not committed: the frame dumps behind
this verdict (6.8 GB of machine state, regenerable from the two named binaries).
