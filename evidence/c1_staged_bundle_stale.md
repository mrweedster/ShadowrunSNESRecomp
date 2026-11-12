# The staged bundle is not the current tree's program

Measured 2026-11-06. Short version: **the
executable at the port root, `./Shadowrun`, cannot be reproduced from the tree
as it stands**, and it disagrees with every build the current tree produces from
the very first frame of scripted play. This does not invalidate the recorded
gates — they were all measured between build trees — but it does mean the
artefact a player runs and the artefact the gates describe are two different
programs.

Plain language first, then numbers.

## What was compared

Four build trees, all configured today from the same `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/src/gen`
(17 translation units, 205 promoted guest functions, 217 dispatch entries) and
the same `Release` flags. Only the framework they compile differs:

| tree | framework base | embed | binary |
| --- | --- | --- | --- |
| `build-ctrl` | the pin `773285b`, pristine sources | off | 3,294,480 B |
| `build-embed-off` | pin + the embed seam (`c5024e74`) | off | 3,294,704 B |
| `build-up` | the port's cycle work **rebased onto current upstream** (`bd9cba8d`, branch `rebase/aot-cycle-onto-origin`, never pushed) | off | 3,367,072 B |
| `build-up-embed` | the same, plus the embed seam cherry-picked onto it (`0ff38c13`) | **on** | 4,423,936 B |

Against those four sits the staged `./Shadowrun` — 5,941,232 B, dated 2026-11-05
13:20, staged by §8 of `tests/README.md`, the binary §4's published transcript
and §7.1's "the promoted build ships" were produced with. Its sha256, recorded
later (see `c1b_run_provenance.md`, which is what made the hash available):
`ebca100c3a01201a949104e46c5bd350da468cb15629aea9c7de6d5879fde46d`. Nothing in
the port names that hash, because nothing about the four trees generates it —
that absence is the finding, not an oversight in the measurement.

## The measurement

`parity.sh` on the title-menu route (`menu.txt`, 1245 frames). "Identical" is
byte-level WRAM crc32 per frame, the §4 standard.

| leg pair | verdict |
| --- | --- |
| `build-ctrl` vs `build-embed-off` | identical over 1245 frames |
| `build-ctrl` vs `build-up` | identical over 1245 frames — **a pin-based framework and a current-upstream framework run this route byte-identically** |
| `./Shadowrun` vs `build-ctrl` | **first divergence at frame 1**, 1219 of 1245 frames differ |
| `./Shadowrun` vs `build-embed-off` | identical verdict to the row above: first divergence frame 1, crc32 `0x609BDB9F` vs `0xA5618AC7`, 1219 of 1245 differ |
| `./Shadowrun` vs `build-up` | same again, byte for byte the same verdict as the two rows above |

`build-up-embed` on its own gates, for completeness: `selfcheck.sh` PASS (exit 0,
the WRAM tick advanced), `headless.sh` 1245 frames with
`rom resolved: <embedded:Shadowrun (USA).sfc>)`.

So the split is not framework-base vs pin-base: all four current trees agree with
each other, and the staged bundle disagrees with all four in exactly the same
way. That single fact rules out a lot of explanations and is why it was worth
measuring before theorising.

How the difference behaves (`framedump_diff.py`, on the dumps that comparison
left in `tests/out`):

- 26 of 1245 frames identical; 11,536 distinct WRAM offsets touched across the run.
- The guest tick counter `$7E1C92` differs in 960 frames; the heaviest other
  addresses are `$7E01C94`, `$7E01CD6` (940 frames each) and the `$7E0012x`
  band — mostly label and timer bytes, §7.2's noise band, but not only.
- `tick` mode: the host-frame phase between the two legs is `k=0` for guest
  counters 0-186, `k=-1` for 187-628, `k=-3` for 630-1111, with one -34 jump at
  counter 629. A **drifting** phase, not the constant one-frame sampling offset
  §7 documents. Two binaries whose AOT promotion charges cycles identically
  cannot drift like that; the guest is being advanced at different rates.

## What is consistent with this, and what is not

Consistent: the staged bundle's AOT promotion is not today's AOT promotion. The
port's own history already says the earlier A0-A3 builds "were produced from
unpushed local states that predate" the pin, and the bus-exact master charging
model (`773285b`, the A4 fix) lives **half in generated code** — `emit_function.py`
charges inside the promoted functions — and half in `runner/src/snes/interp_bridge.c`.
A binary generated before that commit would run the same functions at a
different charge per pass, which is exactly a drifting phase.

Not consistent, and deliberately not claimed: the size difference is **not**
evidence of that. The staged bundle is 1.9 MB of extra `__text` (4,532,524 B vs
2,586,060 B) while carrying the same 205 `bank_*` symbols and the same 217-entry
dispatch table, and its boot banner is byte-identical to the current trees'
(`host_report: Shadowrun dev`, `SNES_GAME_VERSION` in `src/main.c`). Extra code
with identical behaviour is what a link without dead-code elimination looks
like, so the size gap alone proves nothing about which functions ran. Earlier
notes in this repo that inferred provenance from binary size were over-reading
it, and this file replaces them.

## Consequences, and the decision they lead to

1. **The recorded gates stand.** Both baselines were produced by build trees, not
   by the staged bundle: `tests/baselines/horizon_xp.json` names
   `tests/out/xp_aot` / `xp_lle`, `horizon_bs.json` names `bs_aot` / `bs_lle`.
   Those legs are build trees of this repo, so the cross-path horizon (f16122)
   and the bisect pair (f16280) are one regen behind, not orphaned.
2. **§4's published transcript and §7.1's shipped claim describe a program the
   repo can no longer produce.** They are honest as dated measurements, and
   wrong as instructions: someone following §7.1 today gets a binary that
   disagrees with the one the section describes.
3. **Any future comparison must name a build tree, not `./Shadowrun`.** This
   round already demonstrated the failure mode in the other direction: three of
   the kit's scripts could only run `./Shadowrun`, so a "smoke test of the new
   build" silently smoke-tested the stale bundle instead.
4. Not settled here, deliberately, because it is an owner decision: whether to
   re-stage the bundle from the current tree (which makes the shipped artefact
   reproducible but invalidates §4's transcript and means re-deriving the §7.1
   AOT-share numbers) or to keep it as the dated artefact and state plainly in
   §7.1 that the current tree's build is a different program with a measured
   frame-1 difference.

## Reproducing it

```sh
# all four trees exist; the two frameworks are
#   pin:            /private/var/folders/.../snesrecomp-clean
#   rebased:        /private/var/folders/.../sr-up  (branch rebase/aot-cycle-onto-origin)
PORT_BIN=./Shadowrun PORT_BIN2=./build-ctrl/ShadowrunSNESRecomp \
    ./tests/parity.sh tests/scripts/menu.txt
PORT_BIN=./build-ctrl/ShadowrunSNESRecomp PORT_BIN2=./build-up/ShadowrunSNESRecomp \
    ./tests/parity.sh tests/scripts/menu.txt
python3 tests/framedump_diff.py offsets tests/out/run1 tests/out/run2
python3 tests/framedump_diff.py tick    tests/out/run1 tests/out/run2
```

## Corrections since (2026-11-08)

Item 4 above is now settled: the bundle **was** re-staged from the checked-out
tree, so the stale binary is no longer what the kit runs. Measured in
`artifacts/bundle_verify.md` (`tests/bundle_verify.sh`, `tests/README.md §7.18`):

- `./Shadowrun` is now `60067549c3ee8d3b`, 3,103,872 B; the build tree behind it,
  `build-ship`, configured from the pin plus the two documented flags, is
  `a0587ed0a0e34687` — the accepted executable of the promotion rounds. A second
  scratch configure produced the same bytes again, so the accepted executable is
  reproducible from the sources on disk and not a property of one build dir.
- The 96 B difference between those two hashes is the `install_name_tool` dylib
  edit and the re-sign that §8's recipe prescribes; the staged bundle and the
  build tree agree **identically over 1,200 frames** of the parity route, so the
  staging step changes no machine state.
- Against the bundle this report measured, now kept at
  `tests/out/Shadowrun_prev_ebca100c` (`ebca100c3a01201a`), the new bundle
  differs on **1,174 of 1,200 frames**, first at frame 1 (`0xA5618AC7` vs
  `0x609BDB9F`) — the frame-1 break this report found, restated from the other
  side, and the same shape (f0 agrees, then scattered collisions, no agreeing
  prefix).
- Consequence 3 is answered by a runnable check rather than by a note: that log's
  legs name build trees, never `./Shadowrun`, and re-run all three dumps
  themselves. Consequence 2 stands as written — §4's transcript and §7.1's
  shipped claim stay dated measurements of the superseded bundle. The AOT-share
  numbers were re-derived nine times over the promotion rounds afterwards; the
  accepted variant that shipped there (no seed, pair `$80C399,$80AAB3`, exe
  `a0587ed0…`) is what this bundle is.
