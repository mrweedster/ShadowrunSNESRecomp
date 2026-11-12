# M2 promotion round 2b: the dead seeds come out, and the runtime worklist comes back empty

Action record for the follow-up inside round 2 of the standing loop opened by
`evidence/m1_hybrid_decision.md` (round 1: `evidence/m2_promotion_round1.md`, round 2:
`evidence/m2_promotion_round2.md`). Date: 2026-11-07.

Provenance for everything below: framework pin `773285b8210f2254ae87d0a14113980fb36990ad`
(`framework_pins.txt`, clean tree at `<TMP>/sr-pin`), round-2b generated set
`8374878ada424ce4…` (18 units, 204 promoted functions, 252 dispatch rows, 20 files),
round-2b AOT executable `4c1775badab30111…` in `./build-r2b`, round-2b full-LLE floor
executable `088307497a2dcd78…` in `./build-llefloor-r2b` over the archived set
`b7f71dec62601a5b…` (`evidence/artifacts/lle_floor_gen_r2b.tar.gz`), and the diagnostic
build with the dispatch ring armed, `3371495d84cd916b…` in `./build-dht`. The round-2 pair
(`833f17c50fb80988…` over `53faff9d16de5d9b…`, floor `a14b59a97e7070cf…` over
`9e060b8c1855…`) is the control. Round-1's pair and its trees are untouched.

Plain language first, then numbers.

Round 2b does two things round 2 deferred, and both are seed-source questions.

1. **It takes out the 5 seeds that cannot be code.** All 5 were deleted from
   `recomp/symbols.toml` (45 `[[func]]` entries → 40). Regenerating at the pin removes
   exactly 5 manifest nodes, 5 roots, 5 dispatch rows and 5 generated wrappers, and adds
   nothing back: `269 nodes, 47 roots, 252 rows, 8,156 instructions inside AOT bodies` —
   every count down by exactly the amount the dead seeds were contributing and no more.
   Then the pair is measured again, and both paths are **byte-identical to round 2**: same
   frame-byte digest on the AOT leg (`574e66802bece79d…`), same on the floor
   (`f73f0014ad3618f3…`), same cycles, same interpreted instruction counts. Deleting
   configuration that was inert turns out to be inert, which is the confirmation round 2
   predicted, executed rather than asserted.
2. **It builds round 3's planned instrument early and reads it.** The dispatch ring with
   `-DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON` was built (`./build-dht`, `SNESRECOMP_TRACE=ON`
   so the TCP `dispatch_log_get`/`interp_stats` readouts exist), run over `combat.txt`,
   and the answer is: **`found:0` count is 0 of 574,973 dispatches** over the whole route.
   The promotion worklist the framework's own comment describes is empty. Every indirect
   dispatch the machine asked for found an exact AOT body.

That second number is the round's real finding, because it *decides a question round 2 had
to leave open*. Round 2 §6 offered two mechanisms for "four new bodies, zero movement" —
mode shape (the dispatch table is consulted at those addresses but in a mode whose variant
slot is NULL) or entry shape (the table is never consulted there at all, because the
interpreter reaches those spans by branch/back-edge). Only the first one can produce
`found:0` records — the tally records `fp != NULL`, so a NULL slot *is* a miss — and there
are none, for the whole run, not just the ring's 1,024-entry tail. So the four new bodies'
rows are never looked up: the mechanism is entry shape. And with the dispatch-miss signal
also empty, the seed picture is now closed on all three fronts: read-trace frontier closed
(round 1), refusal callees exhausted and partly impossible (round 2), dispatch misses none
(round 2b). The remaining 96.06 % of cycles on this route is not addressable by naming an
address.

## 1. What changed, statically

`recomp/symbols.toml`: 5 `[[func]]` seeds deleted — `CC_8001A9`, `CC_800AAD`,
`CC_803230`, `CC_807FA9`, `CC_AB2FAB` — so the round-2 seed block goes from 20 `CC_*`
entries to 15 and the file from 45 `[[func]]` entries to 40. The generated views follow
the file: `recomp/bank80.cfg` loses 4 `func CC_*` lines, `recomp/bankab.cfg` loses 1.
Nothing else in `recomp/` moved, and the header of the round-2 block now records the
outcome instead of promising it.

| quantity | round 2 | round 2b |
| --- | ---: | ---: |
| `[[func]]` entries in `recomp/symbols.toml` | 45 | 40 |
| of which `CC_*` round-2 seeds | 20 | 15 |
| manifest nodes | 274 | 269 |
| aot_eligible / lle_only | 226 / 48 | 226 / 43 |
| roots | 52 | 47 |
| instructions inside AOT bodies | 8,156 | 8,156 |
| instructions inside `lle_only` nodes | 1,187 | 1,187 |
| promoted functions in `src/gen` | 204 | 204 |
| dispatch rows | 257 | 252 |
| generated files | 20 | 20 |
| generated-set digest | `53faff9d16de5d9b…` | `8374878ada424ce4…` |
| AOT executable size | 2,937,072 B | 2,936,672 B |
| generated wrappers declared | 250 | 245 |

How each column is read, because the two rounds are not equally well archived. The round-2b
column is measured from the live tree this commit describes: `src/gen/program_manifest.json`
(`240af24bb4a7…`) gives `269 nodes = 226 aot_eligible + 43 lle_only`, `47 roots`,
`8,156` instructions inside AOT bodies and `1,187` inside `lle_only` nodes;
`tests/provenance.py` on `build-r2b/…` gives 18 units / 204 promoted functions / 252
dispatch rows / 20 files / `8374878ada42…`; `nm` gives the wrapper count. The round-2 column
is round 2's own committed table (`evidence/m2_promotion_round2.md` §1) plus one inference
that round 2 already states: the 5 impossible nodes come back `empty_decode` plus
`structural_poison` **at 0 instructions** (§2 there), so deleting them cannot move either
instruction total — which is why the 8,156 row is an equality rather than a coincidence.
Round 2's generated set is not archived as bytes (only its digest is recorded); only the
floor sets are archived, and round 2b now has one of those too.

Every AOT number is unchanged, because the 5 nodes that went away were the 5 `empty_decode`
nodes at 0 instructions. The delta is exactly the dead configuration: 5 rows out of
`src/gen/dispatch_v2.c`, 5 stub wrappers out of `unresolved_stubs_v2.c`, 400 bytes out of
each executable.

**A correction to round 2 §1, found while measuring this.** Round 2's record claims that of
the 20 callees the refusals named, "only 15 became new `[[func]]` entries" and that
`8001A9`, `800AAD`, `803230` "were never entries at all". That is wrong, and the round-2
config in git settles it: `git show HEAD~1:recomp/symbols.toml` — the round-2 commit — has
20 `CC_*` entries, including those three. All 20 named callees became seeds, and the nodes
followed the seeds rather than the analyzer independently following call sites: deleting
those 5 seeds deletes exactly 5 manifest nodes, 5 roots and 5 dispatch rows
(`274 → 269` nodes, `48 → 43` `lle_only`, `52 → 47` roots), and grepping the round-2b
manifest for `8001A9|800AAD|803230|807FA9|AB2FAB` now answers empty. Seed and node are one
lever, which is the simpler story and the one the numbers support — and it makes the config
file the thing worth editing, which is what the loop has been assuming all along.

## 2. Execution did not move, at byte level

Both legs re-measured with `tests/aot_share.py` at the pin, both records committed:

| leg | exe | generated set | AOT % of cycles | cpu cycles | interp insns | frame-byte digest |
| --- | --- | --- | ---: | ---: | ---: | --- |
| round-2 AOT `build-r2` | `833f17c50fb80988…` | `53faff9d16de5d9b…` | 3.9402 | 1,108,981,502 | 263,660,881 | `574e66802bece79d…` |
| round-2b AOT `build-r2b` | `4c1775badab30111…` | `8374878ada424ce4…` | 3.9402 | 1,108,981,502 | 263,660,881 | `574e66802bece79d…` |
| round-2 floor `build-llefloor-r2` | `a14b59a97e7070cf…` | archived `9e060b8c1855…` | 0.0 | 1,075,171,039 | 265,434,823 | `f73f0014ad3618f3…` |
| round-2b floor `build-llefloor-r2b` | `088307497a2dcd78…` | archived `b7f71dec6260…` | 0.0 | 1,075,171,039 | 265,434,823 | `f73f0014ad3618f3…` |

What that digest is, exactly, because "byte-identical" is only worth what the instrument
measures: `tests/aot_share.py` takes every `*.fb.bmp` frame-buffer file in the leg's dump
directory (43 on this route — the screens the harness dumps), hashes each file, and hashes
the concatenation of those hex digests in sorted-filename order. So the claim is **all 43
dumped screens identical, byte for byte**, at the same guest frames, on both legs — not a
statement about every frame of machine state. The per-frame machine-state evidence is the
cross-path comparison in §3, and the two instruments land the same way for the same reason:
the executables differ in code the machine never asks for.

AOT `574e66802bece79d0fc349a1…` and floor `f73f0014ad3618f3126aa82e…` are each reproduced by
a different executable over a different generated set.

Coverage is measured against the archived bytes, not the live tree, and both legs link:

```
round-2b AOT    cov 245/245 generated wrappers present in this binary
round-2b floor  cov  30/30 generated wrappers present in this binary
```

(5 fewer wrappers on each side, matching the 5 deleted seeds. AOT still reports
`describes_this_binary: true`; the floor still reports `false` plus the stale-object
warning, because the shared `src/gen` directory names 18 units while the floor's own set is
the 7-unit archive — the known property recorded in `evidence/m2_lle_floor.md`.)

One caveat in those manifests, stated rather than hidden: both round-2b legs print
`WARN 18 generated file(s) touched after this executable was linked` and report
`sources_newer_than_binary: 18`, because `tools/regen.sh` rewrote `src/gen` after the trees
were configured (round 1's records carry the same warning; round 2's do not). The binaries
were not re-linked after that touch, so the warning is answered directly, at symbol level —
the five dead seeds are absent from both round-2b executables and present in both round-2
ones:

```
nm build-r2/…          | grep -E 'CC_(8001A9|800AAD|803230|807FA9|AB2FAB)'   5 names
nm build-r2b/…         | same                                                 0 names
nm build-llefloor-r2/… | same                                                 5 names
nm build-llefloor-r2b/ | same                                                 0 names
```

and `CC_80A568_M0X0`, a seed round 2b kept, is still in both AOT binaries. That is the
stronger side of "the tree really is the one the record describes": the deleted
configuration is gone from the machine code, not just from the source.

The floor's own set is archived as bytes and re-hashed for the record:
`lle_floor_gen_r2b.tar.gz` is 9 files (`.snesrecomp-cache.json`, `bank00_v2.c`,
`bank80_v2.c`, `bank81_v2.c`, `bankab_v2.c`, `dispatch_v2.c`, `module_v2.c`,
`program_manifest.json`, `unresolved_stubs_v2.c`) = 7 units, 0 promoted functions,
**36 dispatch rows**, digest `b7f71dec62601a5b…`, against round-2's archive at 41 rows and
`9e060b8c1855…`. Same 5 rows gone, same 0 promoted, floor executable 400 B smaller.

## 3. Fidelity: the horizon is still f16125

`PORT_AOT=./build-r2b/… PORT_LLE=./build-llefloor-r2b/… XP_TAG=_r8 XP_INPUTS_CHANGED=1
./tests/crosspath.sh tests/scripts/combat.txt`, judged against
`tests/baselines/horizon_xp.json`; the whole console record is committed as
`evidence/artifacts/crosspath_round2b.txt`.

```
run1  4c1775badab30111  2,936,672 B   gen 18 units / 204 promoted fns / 252 dispatch entries
                                      sha256 8374878ada424ce4   fw 773285b8210f2254…
run2  088307497a2dcd78  1,254,208 B   gen 18 units / 204 promoted fns / 252 dispatch entries
        sha256 8374878ada424ce4   <-- live src/gen, not this binary's set
        WARN stale build tree: 7 generated .o against 18 generated units
note: inputs changed on purpose (both legs: gen_sha256 was 27b2fbbd039fe066… in the
      baseline, 8374878ada424ce4… here; gen_functions 210 -> 204; gen_units 17 -> 18)
paired at the same host frame: 25902 frames (f0..f25901), frame-label bytes ignored
noise band: 3 B outside the frame-label bytes
before the horizon: 16125 frames; 65 stretches left the band and came back on their own
                    (longest 5204 frames, peak 995 B)
horizon: host f16125; the last frame that still matched was f16124
  at the horizon: 26 B outside the frame labels (31 B including them)
  whole-frame realignment at the horizon: k=-3 3,252 B · k=-2 2,867 B · k=-1 2,654 B
    · k=+0 26 B (the pairing) · k=+1 283 B · k=+2 396 B · k=+3 1,128 B
    -> no whole-frame shift removes it: the difference is inside the frame
checkpoint bmps: 10 match, 33 differ, 0 missing
verdict: holds: horizon f16125 vs baseline f16125 (within 1 frame of slack)  => PASS
```

Every one of those numbers is round 2's number, and round 2's number is round 1's: same
horizon, same 65 self-healing stretches, same longest stretch, same 26 B at the horizon,
same realignment table, same checkpoint-bmp split (10 match / 33 differ). `tests/aot_share.py
--pair` agrees on the share side, from the two committed records:

```
same inputs   : no                                  # config really did change
share A    : aot 3.9402 % of cycles, 263,660,881 interp insns, exe sha 833f17c50fb80988
share B    : aot 3.9402 % of cycles, 263,660,881 interp insns, exe sha 4c1775badab30111
```

Round 2 proved the strongest form of this — a whole-tree `diff -rq` over 52,321 dump files
per side, silent apart from `run_manifest.json` (`evidence/m2_promotion_round2.md` §3).
Round 2b's dump trees are the same route at the same tag, so its evidence is the levels named
above: 43 screens, cycle and instruction counts to the unit, and 16,125 frames of per-frame
WRAM inside a 3-byte noise band with an unchanged horizon. The pair moved two config files
and four hundred bytes of executable and the fidelity horizon did not blink.

Both legs are at the pin (`tests/provenance.py pin build-r2b/… build-llefloor-r2b/…`). The
baseline is still not re-bound: it is bound to the round-1 pair, and both round 2 and round
2b reproduce that pair's numbers, so re-binding would only launder a `generated_set` label
through a floor leg that reports `describes_this_binary: false`. Re-bind when a round moves
the horizon — or when the route is fixed, which changes the corpus and must re-derive it
(§6).

## 4. The runtime promotion worklist: empty, and that closes a mechanism

Round 2 §6 named the one instrument that could separate its two hypotheses, in the
framework's own words (`runner/src/cpu_state.c:916-931`): the dispatch ring records
`(pc24, source_pc24, func_name, mx_idx, found, mirror, frame)` per dispatch, and
`found:0` entries are "the promotion worklist". It needs
`-DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON` (`runner/runner.cmake:472`) — our shipped report
answers `{"dispatch_log": {"disabled": true, "total": 0}}` — and the live readout
(`dispatch_log_get`, plus the always-on `found1/found0` tallies that the 1,024-entry ring
cannot give you, `cpu_state.c:858-860`) needs `SNESRECOMP_TRACE=ON` as well, because
without it `debug_server_init` is a stub with no port. So: one diagnostic tree,
`./build-dht`, configured `-DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON
-DSNESRECOMP_ENABLE_TRACE=ON`, built at the pin from this round's generated set, and read
by `tests/dispatch_worklist.py` over the combat route. Its record is
`evidence/artifacts/dispatch_worklist_combat.json`.

```
exe            3371495d84cd916b…  113,173,744 B   (ring + trace build; 38x the shipped binary)
framework      773285b8210f2254… clean; live src/gen 8374878ada424ce4… (252 rows)
share          AOT 3.9402 % / interp 96.0598 % of cycles — same as the shipped AOT build
dispatches     574,973 total
  found:1      574,973        found:0   0        (found0_pct 0.0)
mode mix       m0x0 250,681   m1x0 21,234   m1x1 89
ring           cap 1024, total 574,973, evicted 301,283; live tail sampled 272,004 over TCP
manifest join  269 variants / 251 addresses (src/gen/program_manifest.json, 240af24bb4a7…)
worklist       []
```

Three things follow, and all three are narrow enough to be checked:

* **The whole-run tallies say no dispatch ever missed.** `found` is recorded as
  `fp != NULL` (`cpu_state.c:1174`, `:1254`, `:1279`, `:1325` — the RTS/RTL trampoline and
  the runtime-pointer `JSR (abs,X)`), and the tally line `if (found) g_dispatch_found1++;
  else g_dispatch_found0++;` sits *outside* the `#if SNESRECOMP_DISPATCH_HISTORY` block
  (`:887`), so a lookup against a row whose slot is NULL *is* a `found:0` event and it is
  counted even when the ring itself is compiled out. Over 574,973 dispatches there are
  none. The mode-mix confirms the ring actually saw `m1x0` traffic (21,234 dispatches),
  i.e. index 2 of each row's four variant slots really is requested in this game; it is
  just never requested at an address where the slot is NULL.
* **Therefore round 2's mode-shape mechanism is out, and the entry-shape one is in.** The
  four new bodies sit in rows of shape `{ M0X0, NULL, NULL, M1X1 }`; had the machine asked
  for `m1x0` at any of those addresses, the worklist would name it. It named nothing. The
  interpreter's hot spans — `$81:B061`/`$81:B065` at 156.9 M and 157.0 M fetch reads inside
  span `81B05D-81B067`, which has had an AOT body since round 1 — are entered without
  consulting the dispatch table: branch or back-edge entry, which the table cannot intercept.
* **So `entry_mx_at` is not the lever round 2 hoped it might be.** It would add a missing
  variant slot to a promoted root, and there is no observed request for a missing slot.
  Adding `m1x0` variants to those four roots is measurable, but it is predicted to do nothing,
  and the prediction now has an instrument behind it.

Cost, worth stating: the ring build is 38× the shipped binary and the run is a normal-speed
50 s, so this is a diagnostic tree, not a candidate for the shipped configuration.

## 5. What the loop has left

Three seed sources are now closed, each by a measurement rather than by giving up:

| seed source | closed by | what the number was |
| --- | --- | --- |
| read-trace fetch frontier outside proven spans | round 1 | 3 blocks, 1,820 reads, 0.0 % of 2,785,987,594, all below the 1,024-read floor |
| callees named by `lle_only` refusals | round 2 (+2b cleanup) | 4 new bodies / 45 insns, 0 movement; 5 of 20 seeds not ROM-backed |
| dispatch misses (`found:0`) | round 2b | 0 of 574,973 |

The AOT share is pinned at 3.9402 % of cpu cycles and the interpreted residue at 96.0598 %
across three generated sets. What is *not* yet measured is whether that residue is reachable
by any static lever at all: it lives inside spans that already have AOT bodies, entered by
branch. The honest statement for the decision record is that on this route the residue is
not seed-addressable, and the next lever, if there is one, is about *entry* (how the
interpreter hands a hot span to a compiled body), not about *addresses*. That is a framework
question, and it is the one to take to the framework's owner rather than another `[[func]]`
block.

## 6. The measurement route died halfway; it now ends alive before the scripted kill

One harness finding belongs in this record because every number above rests on it, and one
of its repairs, because that repair changed the corpus the baseline measures. The old
25,902-frame `combat.txt` route spent its second half in the alley prologue and ended with
the party dead: the checkpoint tag `W1` at f22951 was **the title screen**, not gameplay,
so the last ~2,900 frames of the corpus were a dying and then dead party on the LLE leg
(`Jake is dead.` at f20629, `Game Over.` by f21423) while the AOT leg survived to f24870.
The horizon f16125 sits *before* all of that, so the fidelity verdict was unaffected — but
the corpus's tail was not measuring what its tags name, and "which leg is alive at f25,902"
is not a fidelity property: it is position. A checkpoint whose dump is a corpse or a title
screen is a harness defect, and it took a round to notice.

What the probes established, all of it from `--framedump` WRAM readouts (`tests/out/probe/`,
scratch, not committed):

* `$7E01F0`/`$7E01F2` are **screen origins, not the party**. Every rest value is a multiple
  of 256 (alley entry `31744,27904` = 256·124, 256·109; the gun's screen `30720,31488` =
  256·120, 256·123), a full-WRAM delta scan for a matching player coordinate returns only
  these two addresses at ±512/±1536 in any width or byte order, and `forcepoke`ing them does
  not move the party. The party's sub-screen position is not in the 128 KiB WRAM window in a
  form these probes could name.
* The Beretta pickup is real and decoded, on the LLE leg: walk the party into the dead
  courier's radius (screen `30720,31488`), read the proximity label `Beretta Pistol.` at
  `$7E21A0`, `press b` (the ACTION GLOVE menu, `'ckup '`), `press down 2`, `press a 6` →
  label `'Beretta 101T' pistol.` and `Beretta` appears in WRAM at `$7E21A0+8608`. Proven at
  f21,366 with the party intact (`hp = 4,4,4,4,…`) and alive to f21,680.
* Death in the alley is a scripted kill scene on the game's own timer, not a hazard standing
  still avoids. Parked at the safe screen origin `30208,27904` with zero movement input,
  both round-2b probe legs (`tests/out/probe/na`/`nl`) hold `hp = 4,4,4,4,4,4,4` with no
  death marker through **f22,344**; the LLE leg is then wiped — all seven hp bytes 0, `Jake
  is dead.`/`Game Over.` in WRAM — by **f22,644**, while the AOT leg is still intact at
  f22,644 and only damaged by f23,139 and dead by f23,739 on the old-tail legs. The corpse
  column near x≈31744 kills *faster*, inside ~1,000 frames; standing away from it only
  buys time. So "the party is alive at ~f25,900" is not a route skill the game offers: on
  this screen the party is dead well before that on both paths.
* The same script does not put both legs in the same place. AOT and LLE WRAM is byte-identical
  frame-for-frame for thousands of frames on some routes and differs at essentially every
  frame on others (`xa`/`xl`: mismatches begin at f1). So a fixed-input route cannot be
  assumed to converge, and the route fix has to gate on state, not frames.

The repair, now in `tests/scripts/combat.txt`: the alley segment gates on WRAM state —
`until16 1f2 == 6d00` lands the camera on the alley screen, `until16 1f0 == 7600` on its
left clamp — and the route stops at `A5`, 1,200 frames after arrival, inside the window
where both paths are proven alive. The Beretta pickup that used to be this segment's goal
moved to the alley probe, for two measured reasons: the deep approach that reaches the gun
(screen `30720,31488`) leaves the AOT leg 1,792 px from the LLE leg under identical inputs,
so a gun-state tail would compare two different game states; and picking the gun up does
not arm it — **equip is unproven on both paths**, every fight attempt answering `You are not
armed yet!` on 10–12 dumps.

The fixed route ran as a fresh cross-path pair on the round-2b binaries (`tests/out/xp_aot_r9`
/ `xp_lle_r9`, full sweep in `artifacts/crosspath_round2b_r9.txt`): both legs 22,044 frames,
**horizon unchanged at f16125** (1 frame of slack), and `tests/baselines/horizon_xp.json` is
re-bound from that pair — execs `4c1775badab3…`/`088307497a2d…`, gen set `8374878ada42…`, pin
`773285b8210f…`. `tests/route_state.py` (new) reads any leg's tagged dumps and fails when a
checkpoint sits after a death marker; all 44 r9 checkpoints pass it, so a title-screen
checkpoint like the old `W1` cannot come back unnoticed. The instrument has teeth: run
against the *old* corpus pair (`tests/out/xp_aot_r8`/`xp_lle_r8`) it fails — 27 of 86
checkpoints sit after a death, the LLE leg already wiped at `P3` f21,836.

## 7. Reproduce

```sh
git diff HEAD~1 -- recomp/                      # 5 seeds out, bank80/bankab follow the file
git show HEAD~1:recomp/symbols.toml | grep -c '^name = "CC_'   # 20 round-2 seeds
grep -c '^name = "CC_' recomp/symbols.toml      # 15 now
SNESRECOMP_ROOT=<pinned framework> ./tools/regen.sh   # 269 nodes / 47 roots, 226 AOT / 43 LLE
cmake -S . -B build-r2b -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=<pinned framework>
cmake --build build-r2b

# one cross-path pair, and its dump dirs feed both share records:
PORT_AOT=./build-r2b/ShadowrunSNESRecomp PORT_LLE=./build-llefloor-r2b/ShadowrunSNESRecomp \
  XP_TAG=_r7 XP_INPUTS_CHANGED=1 ./tests/crosspath.sh tests/scripts/combat.txt
python3 tests/aot_share.py build-r2b/ShadowrunSNESRecomp --dump-dir tests/out/xp_aot_r7 \
        --json evidence/artifacts/aot_share_round2b.json       # 245/245 wrappers, 3.9402 %
TREE=./build-llefloor-r2b FLOOR_JSON=$PWD/evidence/artifacts/aot_share_lle_floor_r2b.json \
  FLOOR_GEN=$PWD/evidence/artifacts/lle_floor_gen_r2b.tar.gz \
  ./tests/make_lle_floor.sh --share tests/out/xp_lle_r7        # PROVEN 30/30, 0.0 % AOT
# (build the floor first without --share: same TREE=/FLOOR_GEN=/FLOOR_JSON= prefix. The
#  script splices tests/forces/all_lle.txt into recomp/bank00.cfg, regens, archives the
#  floor's set to FLOOR_GEN, builds, then restores the config — so never run it while
#  another tree is mid-build, and do not hand-tar src/gen: the archived bytes are what
#  coverage is measured against.)
python3 tests/provenance.py pin build-r2b/ShadowrunSNESRecomp build-llefloor-r2b/ShadowrunSNESRecomp
nm build-r2/ShadowrunSNESRecomp   | grep -cE 'CC_(8001A9|800AAD|803230|807FA9|AB2FAB)'  # 5
nm build-r2b/ShadowrunSNESRecomp  | grep -cE 'CC_(8001A9|800AAD|803230|807FA9|AB2FAB)'  # 0
# second pair run, this one judged against the committed horizon baseline:
PORT_AOT=./build-r2b/ShadowrunSNESRecomp PORT_LLE=./build-llefloor-r2b/ShadowrunSNESRecomp \
  XP_TAG=_r8 XP_INPUTS_CHANGED=1 ./tests/crosspath.sh tests/scripts/combat.txt \
  | tee evidence/artifacts/crosspath_round2b.txt              # horizon f16125, PASS
# (r7/r8 ran the *old* combat.txt. The route was rewritten afterwards — §6 — so these
#  two pairs are no longer reproducible from today's script; r9 below is the pair on
#  the fixed route.)
PORT_AOT=./build-r2b/ShadowrunSNESRecomp PORT_LLE=./build-llefloor-r2b/ShadowrunSNESRecomp \
  XP_TAG=_r9 ./tests/crosspath.sh tests/scripts/combat.txt \
  | tee evidence/artifacts/crosspath_round2b_r9.txt           # horizon f16125, PASS
python3 tests/route_state.py tests/out/xp_aot_r9 tests/out/xp_lle_r9   # 0 of 44 after death
# (r9's baseline verdict came after re-recording tests/baselines/horizon_xp.json from
#  this pair with --inputs-changed --update, since the corpus changed with the route.)

# the runtime worklist, from the diagnostic tree:
cmake -S . -B build-dht -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=<pinned framework> \
      -DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON -DSNESRECOMP_ENABLE_TRACE=ON
cmake --build build-dht
python3 tests/dispatch_worklist.py --binary ./build-dht/ShadowrunSNESRecomp --tcp \
        --json evidence/artifacts/dispatch_worklist_combat.json   # found0 = 0, worklist []
```

Build trees (`build-r2b`, `build-llefloor-r2b`, `build-dht`) and dump directories are
machine state and are not committed. What carries the claims is committed:
`aot_share_round2b.json`, `aot_share_lle_floor_r2b.json`, `lle_floor_gen_r2b.tar.gz`,
`dispatch_worklist_combat.json`, `crosspath_round2b.txt`, `crosspath_round2b_r9.txt`,
`tests/dispatch_worklist.py` and `tests/route_state.py`.
Round 2's and round 1's records still name their own pair.
