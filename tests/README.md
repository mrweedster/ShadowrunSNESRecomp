# How to test this port

Every command below runs from the port's own directory — the one holding
`Shadowrun` — and each one was run here, so the "expected" output is what this
machine actually printed.

```
Shadowrun          the port (self-contained, arm64 Mach-O)
libs/              libSDL3 it loads through @executable_path
dist/              the .app + .dmg packages of §7.19/§7.20; those executables
                   link SDL3 in, so they carry no libs/ of their own
rom.cfg            tells the port where your .sfc is
saves/             save.srm (SRAM) + save states
recomp/            symbols.toml, bank cfg -- what the recompiler was told
tools/regen.sh     regenerate src/gen from recomp/
scripts/package_macos_bundle.sh  stage, seal and measure a .app in a .dmg (§7.19)
tests/             this kit
  play.sh          open the window and play
  selfcheck.sh     boot/execution proof, no human needed
  package_desktop_editions.sh  the Windows/Linux packager labels a tree by
                   the editions it was configured for, and refuses a wrong flag
  headless.sh      scripted run through the title menu
  parity.sh        per-frame WRAM crc32 compared across two runs
  shots.sh         256x224 BMPs of chosen frames
  find_state_bytes.py   discover WRAM addresses to `until` on
   framedump_diff.py  byte-level dump comparison. `horizon` is the cross-path
                      gate; `byte` is one address's value timeline in both legs;
                      `cpdump` is one tagged checkpoint, every file beside it;
                      the other modes read a verdict, they do not make one
   provenance.py      which program made a dump dir; binds runs to baselines (§7.6)
   wram_trace.py      who writes which WRAM byte, and `--streams`, the
                      value-order gate on the two trace builds
   crosspath.sh       the AOT path against the interpreted floor, one verdict (§7.2)
   bisect_aot.sh      rebuild with a smaller emit set: ~5 min per step (§7.3)
   make_lle_floor.sh  build the true full-LLE control, a 0 % AOT binary, at the pin
   aot_share.py       an AOT/LLE cycle share bound to the program that made it
   handoff_probe.py   where the frame boundary actually cuts a guest loop
   rom.sh             the one ROM answer; every harness sources it (§7.9)
   coverage_gaps.py   which interpreted cost an entry seed could reach (§7.9)
   wait_class.py      interpreted cost grouped by interrupt-wait loop (§7.9)
   wait_cost.py       what one declared PC set costs, per leg (§7.9)
   poll_scan.py       hot interpreted PCs classified by loop shape (§7.9)
   disasm_span.py     65816 decode of a ROM span, through the pin's decoder (§7.9)
   idle_ab.sh         idle-poll cost A/B, one capture per leg (§7.9)
   idle_parity.sh     idle-poll behaviour check, per-frame WRAM crc32 (§7.9)
   idle_f205.sh       the same divergence read at byte level (§7.9)
   idle_artifacts.py  regenerates the three round-3 idle-poll artifacts from the
                      run files, so no committed number is hand-typed (§7.9)
   seam_phase.py      does the seam move the executed block set, or does the
                      cycle counter drift with an identical set? (§7.12)
   bundle_verify.sh   the staged ./Shadowrun against its own build tree and against
                      the previous staged executable (§7.18)
   macos_state_probe.sh  fork host vs pin host: why a bundle can be sealed (§7.21)
   macos_floor_probe.sh  read Mach-O build records for each tree's macOS floor (§7.22)
   macos_floor11_check.sh rebuild the floor-11 recipe in an empty tree, cmp bytes (§7.23)
   macos_framework_commits.sh  the framework commits both packages depend on, as a
                      generated log: subjects, diffstats, patches, SDL3 pins (§7.24)
   macos_user_open_probe.sh  both images opened the way a person opens them: what
                      Gatekeeper does, and where a named folder stops a click (§7.26)
   macos_exec_hold_probe.sh  macOS holding an exec instead of refusing it: what that
                      looks like, how long it lasts, what clears it (§7.27)
   doc_quote_audit.py  every quote, hash and artifact in §7.19 to §8.2 traced back to
                      a witness; the exit code is the count of findings (§7.25)
   run_doc_audit.sh    that check with its own pass kept as a committed log (§7.25)
   doc_probe_sections.py  writes §7.26 and §7.27 so every transcript fence is copied
                      out of the two probe artifacts instead of retyped (§7.25)
   scripts/         input scripts (menu, selfcheck, parity, short, shorter,
                   door, nav1, nav2, combat, bisect_h8, idle_f205, idle_dense)
  out/             scratch space the scripts create
evidence/          archived measurements behind section 7
```

`tests/out/` is scratch and git-ignored, so it gets pruned between rounds. On
2026-11-09 the closed round dirs — `charge/`, `r4/`, `r5seam/`, `run1/`,
`run2/`, `xp_aot_r9/` and `xp_lle_r9/` — were deleted with everything in them:
mostly frame dumps, trace binaries and copies of the executable. What did not go
with them: `tests/out/pkg/`, because its two `.log` files are the sources the
committed §7.19 and §7.20 transcripts are verbatim copies of; the same rule for
`tests/out/floor/`, `tests/out/state_probe/`, `tests/out/bundle/`,
`tests/out/framework/`, `tests/out/openprobe/` and `tests/out/exechold/`, which
hold the §7.22, §7.21, §7.18, §7.24, §7.26 and §7.27 transcripts that the other
committed artifacts are verbatim copies of, `tests/out/doc_audit/`, which holds the
§7.25 transcript, and for `tests/out/m11_build.log` and `tests/out/m11_builds.log`,
the build records §7.22 compares against; and the two generated sets that
§7.13–§7.16 unpack into `src/gen`, now committed as
`evidence/artifacts/round6_gen_r6pair.tar.gz` and
`evidence/artifacts/round6_gen_r6pc1c9.tar.gz`. Reading a round-4 log directly
(`round4_probe.py`, `round4_artifacts.sh`) needs that round's legs re-run first.
The §7.25 check compares every committed artifact against the log it was copied from,
and says plainly when that log is no longer on disk, so pruning one of the
directories above shows up in the next audit run instead of being quiet.

The repository root lost 53 of its 55 CMake build trees the same day. The 55
measured 2.9 GB together (`du -ch`). `evidence/artifacts/build_trees_cleared_2026-11-09.md`
lists all 55 with their pre-deletion sizes. A section that names a deleted tree
records a measurement that was taken; it is not a directory to cd into. Where the
section also carries the configure line, the tree is rebuildable and the section
says so; where it does not, the section says that too.

Twelve build directories are on disk again, 379 MB together (`du -ch build-*/`,
a total over all twelve), and every one of them is a directory that exists rather
than a deleted measurement: the two payload trees of the superseded 2026-11-08
packages — `build-ship` (`a0587ed0a0e34687`, 3,103,776 B, `SNESRECOMP_ROOT` = the
pin `773285b8210f`) and `build-embed-ship` (`5822a85675b2640d`, 4,160,576 B,
`SNESRECOMP_ROOT` = the `sr-embed` clone `c5024e74abef`) — the compatibility
round's five (`build-osx11`, `build-osx11-sdl11`, `build-osx-static`,
`build-osx-universal`, `build-fork-osx`), the three that the shipped packages come
from now (`build-ship-m11`, `build-embed-ship-m11`, `build-osx-universal-m11`),
and the scratch tree §7.23 builds to prove that floor recipe from an empty
directory (`build-ship-m11-check`, 39 MB, nothing is packaged from it). One of the
twelve, `build-osx11-static`, was configured and never built, so it is not in any
section's table. §7.22 prints each tree's `CMakeCache.txt` entries beside its
payload hash, so naming one of them in §7.19 or §7.20 names a buildable
directory; for the three floor-11 trees the exact `cmake` command lines are in
`tests/out/m11_build.log`, and §7.23 builds one of them again in a directory that
did not exist beforehand and gets the same payload bytes.

The ROM comes from `rom.cfg`, which points at
`~/Documents/work/snesrecomp/Shadowrun (USA).sfc`; edit that file, or pass
`--rom <path>`. The executable is self-contained — `libs/libSDL3.0.dylib` loads
through `@executable_path`, so no Homebrew dependency. The `dist/` packages are
self-contained a different way: their executables link SDL3 into themselves, load
no dylib at all, and carry no `libs/` directory (§7.22 measures both shapes).

## 1. Play it

```sh
./tests/play.sh
```

A window opens on the game itself — `play.sh` passes `--no-launcher` and drives
the title menu with `tests/scripts/menu.txt`. Running `./Shadowrun` with no
arguments opens the launcher screen instead. `./Shadowrun` finds its ROM beside
itself (`Shadowrun (USA).sfc`, path also cached in `rom.cfg`), so no build tree
or framework checkout is needed to run anything in this folder.

That staged executable is a dated artefact (2026-11-05), not today's build, and
it is **not** a valid control: it disagrees with a freshly built binary from this
tree from frame 1 of `menu.txt`. Use a build tree's binary when a comparison has
to mean something — `PORT_BIN=./build-ctrl/ShadowrunSNESRecomp`. The measurement
and what it implies: `evidence/c1_staged_bundle_stale.md`.

Keyboard defaults (editable in `keybinds.ini`):

| Action | Key |
| --- | --- |
| D-pad | arrows |
| A / B | `x` / `z` |
| X / Y | `s` / right shift |
| Start / Select | return / `c` |
| Turbo | tab |
| Pause | shift+`p` |
| Reset | ctrl+`r` |
| Fullscreen | option+return |
| Perf overlay / renderer / widescreen | `f` / `r` / option+`w` |
| Load / Save state | F1–F10 / shift+F1–F10 |
| State menu / Rewind | F7→F11 / F8→F12 (macOS remap) |

Hold `fn` for the F-keys on a laptop. Gamepads are picked up automatically.
Save states and the SRAM save go in `saves/` (`save.srm`, kept beside a
`save.srm.bak`).

Host flags, everything else is passed through to the port: `--rom`, `--config`,
`--script`, `--framedump`, `--resume-state`, `--launcher`, `--no-launcher`,
`--paused`, `--coverage-capture=on|off` (the per-instruction journal of §7.9),
`--help`. There is no `--fullscreen` flag.

## 2. Boot test — no human watching

```sh
./tests/selfcheck.sh
```

```
script f=10 until 01C92 ok after 10 frames
script f=276 until 01C93 ok after 266 frames
[host +4.751s] frame service: implementation=LLE seconds=4.686715708 fps=58.890 cpu_seconds=0.481101000
PASS: rom executed, tick counter advanced (exit 0)
```

This waits on the game's own 16-bit tick counter at `$7E01C92` (one increment
per emulated frame) instead of guessing frame counts. If the ROM stalls the host
exits 3 instead of hanging — verified by pointing the same script at a condition
that can never become true:

```
[host +2.067s] exit: script until timed out after 120 frames   -> exit code 3
```

## 3. Scripted play-through of the title menu

```sh
./tests/headless.sh
```

```
[host +0.046s] rom loaded: 1048576 bytes
script: loaded 6 entries from '.../tests/scripts/menu.txt'
script f=1245 quit
[host +21.358s] frame service: implementation=LLE fps=58.465 cpu_seconds=2.274372000
```

That script (`tests/scripts/menu.txt`) skips the narration, reaches
`START NEW GAME / START SAVED GAME / OPTIONS`, moves the cursor down and picks
an item. Pass another file to drive a longer scenario:
`./tests/headless.sh tests/scripts/parity.txt`.

## 4. Determinism

```sh
./tests/parity.sh
```

```
run1   [host +20.562s] frame service: implementation=LLE fps=58.553 cpu_seconds=2.703898000
run2   [host +20.558s] frame service: implementation=LLE fps=58.534 cpu_seconds=2.642834000
identical over 1200 frames
```

Two runs of `tests/scripts/parity.txt`, comparing the crc32 of all 128 KiB of
WRAM for every frame (written as `tests/out/run*/frame_XXXXXX.json`). A
divergence prints the first frame where state splits. Each leg now also writes
`tests/out/run*/run_manifest.json` naming the program that made those frames,
and when `PORT_BIN` and `PORT_BIN2` are different binaries parity.sh prints
whether their inputs match (§7.6).

The failure path is checked too — pointing `PORT_BIN2` at a run of the shorter
`tests/scripts/shorter.txt` (60 frames) against an 180-frame `run1` reports it
instead of passing silently:

```
first problem at frame_000060.json: run2 stopped after 60 frames
120 of 180 frames differ                      -> exit code 1
```

Cross-path comparison (this is how the §7 AOT build was checked): copy the
executable somewhere under `tests/out`, give it a `libs` symlink to travel on,
and name it as `PORT_BIN2`.

```sh
cp -p Shadowrun tests/out/Shadowrun2 && ln -sfn "$PWD/libs" tests/out/libs
PORT_BIN=./Shadowrun PORT_BIN2=tests/out/Shadowrun2 ./tests/parity.sh tests/scripts/short.txt
```

```
run1  ./Shadowrun
       [host +3.106s] frame service: implementation=LLE fps=59.112 cpu_seconds=0.396379000
run2  tests/out/Shadowrun2
       [host +10.904s] frame service: implementation=LLE fps=59.204 cpu_seconds=0.374897000
identical over 180 frames
```

Only the `run1`/`run2` directories are cleaned between runs, so a scratch binary
in `tests/out` survives.

## 5. Screenshots

```sh
./tests/shots.sh tests/out/shots        # START=60 END=1200 STEP=60 by default
END=480 ./tests/shots.sh                # override the range
```

Writes `tests/out/shots/frame_XXXXXX.bmp`, 256x224, one per step. The host will
not create the directory itself, so the script does it. Frames group into a
handful of distinct images because narration and menus are static between
transitions; between frame 60 and frame 300 the diff covers the whole screen
(55,122 of 57,344 pixels). For a rigorous frame-by-frame comparison use the
WRAM crc32 from §4 — the images are for eyeballing.

## 6. The framework's own suites

Run in `~/Documents/work/snesrecomp`. Nothing in the block below is a path in this
repository: `tests/run_c_tests.sh`, `tests/run_tests.py` and `recompiler-rs/` are all
framework-side, and the checkout meant is the one `SNESRECOMP_ROOT` names —
`framework_pins.txt` says which revision that is. On this machine that needs
Homebrew GCC for C and Apple clang for C++ (`libstdc++` from Homebrew does not build
against the macOS SDK), and `rustup` shims on `PATH` for the Python harness:

```sh
CC=/opt/homebrew/opt/gcc/bin/gcc-16 CXX=g++ \
  cmake -S . -B build -DSNESRECOMP_SDL3_FETCH=OFF
cmake --build build -j
bash tests/run_c_tests.sh                                   # 41 sections, all pass
PATH=/opt/homebrew/opt/rustup/bin:$PATH python3 tests/run_tests.py   # 881 passed, 1 skipped
PATH=/opt/homebrew/opt/rustup/bin:$PATH cargo test --manifest-path recompiler-rs/Cargo.toml
PATH=/opt/homebrew/opt/rustup/bin:$PATH cargo clippy --manifest-path recompiler-rs/Cargo.toml --all-targets -- -D warnings
```

`tests/run_tests.py` shells out to cargo, so without cargo on `PATH` it reports
~105 spurious failures ("could not build the native analyzer ... Cargo is not
installed").

## 7. Promotion to native code (the recompiler actually running)

Since 2026-11-05 the executable in this directory **is** the promoted build
(§7.1); the LLE reference it was gated against survives as
`tests/out/ShadowrunLLE`. Before that promotion, the build ran the
LLE/dynamic path. To see the static recompiler emit real C for Shadowrun's banks:

```sh
# 1. flip `emit = true` in recomp/symbols.toml, then regenerate the port sources
SNESRECOMP_ROOT=~/Documents/work/snesrecomp bash tools/regen.sh
# 2. configure + build
CC=/opt/homebrew/opt/gcc/bin/gcc-16 CXX=g++ \
  cmake -S . -B build -DSNESRECOMP_ROOT=~/Documents/work/snesrecomp -DSNESRECOMP_SDL3_FETCH=OFF
cmake --build build -j
# 3. re-check parity against the LLE build. The executable name comes from
#    add_executable() in CMakeLists.txt (here: ShadowrunSNESRecomp).
#    `ls build/` to confirm.
PORT_BIN=./build/ShadowrunSNESRecomp PORT_BIN2=./Shadowrun \
  ./tests/parity.sh tests/scripts/parity.txt
```

Measured on this port: the analyzer promoted `9 roots -> 226 exact variants,
490 edges`, 214 AOT functions against 12 left LLE-only, across 3 banks
(`bank81_v2.c` 3.4 MB, `bank80_v2.c` 1.4 MB, `bank00_v2.c` 27 KB); the
executable grows 2,573,776 -> 4,975,664 bytes. LLE versus AOT over 1200 frames:
frames 0 and 60 byte-identical, and in steady state only 5–7 of 131,072 WRAM
bytes differ (`$7E01C92`, `$7E01C94`, `$7E01CD4`, `$7E01CD6`, `$7E00133`,
`$7E0001C`) — all of them frame counters and timers, explained by a constant
one-frame phase offset that a `k = -1` alignment resolves completely. No growth
over the run, and the BMPs at frames 300/600/900/1200 are md5-identical between
the two paths. Those measurements are archived in `evidence/` — the per-frame
WRAM crc32 records for all four runs (2 × LLE, 2 × AOT) plus the AOT screenshots,
with the commands to re-derive the conclusions from them.

### 7.1 The promoted build ships (2026-11-05)

`./Shadowrun` is now the AOT batch built from framework `773285b8210f2254ae87d0a14113980fb36990ad`
(shasum-256 `ebca100c…`, 5,941,232 bytes; the superseded LLE reference is kept
as `tests/out/ShadowrunLLE`, sha256 `208c2dc7…`). AOT participation on the
shipped binary: 9 roots → 214 functions, `aot_cycle_pct` 5.58 (60-frame boot)
/ 1.88 (1200-frame parity route).

The cross-path gate was **escalated** (rationale in `evidence/a4_bus_pace.md`
§4): fixed host-frame-index WRAM identity cannot pass between two paths while
their host presentation phase differs by one frame — for any AOT build. At
promotion time the replacement was guest-tick alignment, measured that day as
579 of 1101 guest-counter pairs byte-identical with only 11 offsets differing
anywhere in the run — the §7 timer family (`$7E0012C/12E/12F/132`, ±4 counts)
and two boot-latch pairs (`$7E00128/129/12A/12B` at counters 18–19, DMA scratch
parameters) — worst 6 bytes in a 131,072-byte window, never growing. Refined on
the full combat route (25,902 frames): the tick-label offset is
**piecewise-constant** (0 → +1 → +3 → +37, bounded steps, never growing after
f22885), and shift-compensated probing showed state is **byte-identical when
compared at the same host frame** through the shared-physics route
(`evidence/a5_crosspath_tick.md`).

Those are **diagnostics now, not the gate**. The full route runs past the point
where the two paths stop describing the same state, and counter-pairing hides
that (§7.2). Same-binary determinism is unchanged and stays strict: two runs of
`./Shadowrun` must still report `identical over 1200 frames`, and `parity.sh`
exits 1 on any split. The fixed-index count `parity.sh` prints for a cross-path
pair (1077 of 1200 differ on promotion day, first divergence frame 1) remains
expected and advisory — it measures sampling phase, not state.

### 7.2 The cross-path gate: the fidelity horizon (2026-11-06)

Both code paths — the shipped AOT binary and the interpreted floor — stop a long
guest loop at different points of the same frame. The frame boundary is a fixed
master-clock budget (357,368 clocks per frame here) and each path can only check
it where it is able to: the floor at interpreter back-edges, the compiled path
at block entries. So "these two WRAM dumps are byte-equal at frame N" is not a
cross-path test on any route long enough to contain a fight. The owner ruled
that hand-off split expected; the framework records it under Axis 6 of
`/Users/wee/Documents/work/snesrecomp/docs/validation/accuracy-history.md`
(commit `8d9f999`, docs only — so `framework_pins.txt` stays at `773285b`,
because a pin names the revision the shipped binary was *built* from).

What is gated instead. `./tests/crosspath.sh` prints exactly one verdict, and
the same verdict on its own is:

```sh
./tests/crosspath.sh                    # both legs on combat.txt, then the verdict
./tests/framedump_diff.py horizon tests/out/xp_aot tests/out/xp_lle \
        tests/baselines/horizon_xp.json       # just the verdict
```

In plain terms: at the same host frame index, ignoring the frame-label bytes
(`$01C80-$01D40` plus the four timer singletons), find the **last frame where
the two paths' state still matches**, and call the frame after it the *horizon*
— the place where they stop agreeing about the game and never come back. On the
shipped pair that is **host f16122** (59 B out of band). The last matching
frame, f16121, is byte-exact apart from the labels that were ignored: 5 B in
the whole 128 KiB frame, all 5 of them frame-label bytes.

```
== cross-path VERDICT: cross-path fidelity horizon (baseline …/horizon_xp.json) ==
horizon: host f16122; the last frame that still matched was f16121
  holds: horizon f16122 vs baseline f16122 (within 1 frame of slack)
VERDICT: PASS                                              -> exit code 0
```

The rules, in words: the horizon **may not move earlier** than the recorded
baseline (1 frame of slack; later counts as an improvement), and a state
difference **may not stay out of the noise band longer before the horizon** than
the baseline's longest stretch that healed on its own (+10 frames of slack).
Both numbers are measured, not chosen: the band is 3 B because that is the
widest pre-onset band these pairs show, and this route leaves the band **71
times before f16122** — boot bursts of 1,443 B gone a frame later, menu
stretches up to 2,897 B out of step for 1,687 frames — and every one of them
comes back to 0 B. Healing is not evidence; only the one that never heals is.
Exit code 2 means *no verdict*: either this scan does not cover the horizon (a
window that starts already out of band, e.g. `20000 20100`), or there is no
baseline file to judge against. Neither may be read as a pass — a missing
baseline prints `VERDICT: no baseline` rather than quietly recording one.

Everything after the horizon is printed as consequence and is **not** a bug
signal: 59 B at f16122, 419 B at f16132, 29,652 B at f25901 is that same phase
difference compounding by itself.

The pairing coordinate was measured rather than assumed, and it is the whole
reason the gate is f↔f: at the same host frame the legs are **byte-identical
(0 B) across f15900-f16121** even though the guest tick counter inside those
frames sits 3 apart. Paired by that counter instead, the same frames read 85 B —
and 0 B once the label is shifted back by k=-3. So `guest`, `shift`, `tick`,
`clock` and `drift` are how you read *why* a verdict moved; none of them is a
pass/fail rule.

The half a frame dump cannot answer at all is whether a value is actually wrong.
That is a second gate, on the trace builds (`evidence/a7` §5):

```sh
./tests/wram_trace.py --streams
```

Per tracked address: the same values, in the same order, the same number of
times; only which frame a write is stamped with may move. It PASSES 7 of 7, and
puts a number on the split: 42 of 2,604 writes at `$00EF` (139 of 8,940
overall) sit one frame apart. Corrupting one byte of the AOT stream makes it
FAIL and names the offset, so it is a check, not a shrug.

Baselines the verdicts are judged against, both recorded on this machine:

| pair | route | AOT set | horizon | at horizon | healing stretches |
| --- | --- | --- | --- | --- | --- |
| `tests/out/xp_aot_r5` vs `xp_lle_r5`, baseline `tests/baselines/horizon_xp.json` | `combat.txt`, 25,902 frames | 17 units, 210 promoted, 252 entries | f16125 | 26 B | 65, longest 5,204 frames, peak 995 B |
| `tests/out/bs_aot` vs `bs_lle`, baseline `tests/baselines/horizon_bs.json` | `bisect_h8.txt`, 16,428 frames | 28 nodes | f16280 | 20 B | 63, longest 30 frames, peak 40 B |

The first row is recorded on a **provenance-bound** pair (`run1` = `build-r0`,
byte-identical to the committed control; `run2` = `build-llefloor`, the true
full-LLE floor described below; both trees were deleted on 2026-11-09, and the
floor side is exactly what `./tests/make_lle_floor.sh` below recreates), and it
replaced an unbound record that turned out to be unreproducible: the byte-identical
replay of that pair measures f16125 / 26 B / 65 stretches, where the old file said
f16122 / 59 B / 71. The old numbers are kept in
`tests/baselines/horizon_xp_prebound.json` so the discrepancy stays checkable; it is
since resolved in `evidence/m2_promotion_round1.md` §5: f16125 / 26 B / 65 reproduces
under every pinned program state (three distinct pairs), and the f16122 record's legs
are unbound and predate the pinned framework. The promotion round that re-measured it
left the horizon exactly where the bound baseline says.

That baseline has since been re-bound once more, to a pair whose control leg is a binary
proven to be 0 % AOT: the previous control, `build-lle`, had inherited round-1's promoted
bodies (3.94 % AOT) and its recorded leg ran off-pin. Same verdict, same numbers
(f16125, 26 B, 65 stretches) — see `evidence/m2_lle_floor.md`.

Promotion round 2 (`XP_TAG=_r6`, `build-r2` over generated set `53faff9d…` against
`build-llefloor-r2`, its own set archived as `lle_floor_gen_r2.tar.gz`) reproduces that
baseline again — PASS, horizon f16125, 26 B, 65 stretches — and does **not** re-bind it:
the two pairs' frame dumps are byte-identical apart from `run_manifest.json`
(`diff -rq` silent over 52,321 files per side), so re-binding would swap equivalent
hashes and put the floor leg's mislabelled live-`src/gen` digest into the committed
file. Re-bind when a round moves the horizon. The record is
`evidence/m2_promotion_round2.md`, which is also where the round's negative result is
written down: 4 new AOT bodies, 45 instructions, zero bytes of machine state moved.

Different routes, different coverage, so judging one pair against the other's
baseline fails both rules at once — which is the demonstration that the rules
fire. `XP_BASELINE` points the verdict elsewhere, `XP_ANALYZE=0` runs the legs
only, `XP_TAG=2` keeps a second independent capture (`xp_aot2`/`xp_lle2`),
`XP_INPUTS_CHANGED=1` judges a pair whose `src/gen` differs from the baseline's on
purpose (a promotion step), and `XP_UPDATE=1` re-records the baseline — from a
pair that has passed `provenance.py pin`, never from a copy build.

The control leg of that gate is `build-llefloor`, and it is built, not assumed:
`./tests/make_lle_floor.sh` demotes every promotable function (`forces/all_lle.txt`
spliced into `recomp/bank00.cfg`), regenerates at the pin, builds the tree, and
proves two separate things -- `nm` says all 21 wrappers that set declares are
linked, and the run's own breadcrumb says `aot_cycle_pct 0.0` of 1,075,171,039 cpu
cycles (`evidence/artifacts/aot_share_lle_floor.json`, its generated set archived
as `evidence/artifacts/lle_floor_gen.tar.gz`). `./tests/make_lle_floor.sh --share
tests/out/xp_lle_<tag>` re-records that share after a cross-path run. A tree merely
*configured* to be LLE keeps whatever bodies the last regeneration promoted: the
old `build-lle` measured 3.94 % AOT, which is why the floor is a script and not a
build option.

One `src/gen` is shared by every build tree, so whoever regenerated last owns it:
a manifest for a tree linked from an older set labels itself
(`describes_this_binary: false`, printed as "not this binary's set"). Bind a claim
to a set by digest rather than to whatever `src/gen` happens to hold, and archive
the set when the claim has to outlive the next regeneration.

### 7.3 Re-checking a framework change in five minutes

```sh
./tests/bisect_aot.sh                      # current emit set, both trace legs
./tests/bisect_aot.sh forces/80c11f.txt    # demote $80:C11F to LLE first
```

Two facts about what that script actually touches, because both were assumed wrong
here once: it **builds** `build-tr-aot`, it never configures it
(`cmake --build build-tr-aot -j 8`, line 59), so both trace trees have to exist
already — and as of 2026-11-09 neither does (§7.6 has the recreate recipe). And it
exports its own framework, `export SNESRECOMP_ROOT=/Users/wee/Documents/work/snesrecomp`
(line 57), rather than reading `framework_pins.txt`, so "re-check a framework change"
here means changing that line or that checkout.

That regenerates `src/gen`, rebuilds `build-tr-aot`, runs both trace trees over
`tests/scripts/bisect_h8.txt` (the combat route cut just past the H8 dump) and
prints the three-line bisect verdict: pre-onset max over f15900-f16121, then the
byte counts at f16122 / f16123 / H8. That metric is deliberately **not** the
horizon gate — it answers "did demoting this function remove the physical
split", and "first frame that differs at all" is never usable, because boot puts
timer label bytes out of step on every leg. Cost: regen ~1 min, rebuild ~3-5
min, both legs in parallel ~5 min. If a change survives, re-judge the horizon:

```sh
./tests/framedump_diff.py horizon tests/out/bs_aot tests/out/bs_lle tests/baselines/horizon_bs.json
```

One thing to know about that command: each bisect step regenerates `src/gen`
with a different `force_lle` block, so its inputs **differ from the baseline's on
purpose** — the baseline is the reference across those steps, not a snapshot of
one step. Once `horizon_bs.json` is re-recorded with `--update` and therefore
carries a provenance block, a later step is refused as a different program unless
the delta is declared: pass `--inputs-changed` and the diff is printed as notes
and the pair is judged anyway. Re-recording the baseline per step would destroy
the reference, so don't do that. Today the file carries no provenance block, so
bisect steps only get a note.

One caveat that has already burned this port (`evidence/a7` §8.6): every build
tree shares `src/gen`, so a `tools/regen.sh` run can silently make
`build-tr-lle` (floor: 0 compiled functions, 2 dispatch entries) and
`build-tr-aot` (promoted: 209 compiled functions, 217 entries) md5-identical
binaries. Confirm with `grep -c "^    { 0x" src/gen/dispatch_v2.c` and the
M0X0 symbol count in the built binary before trusting a pair of "legs".

The same sharing bites in the other direction: a tree that was not rebuilt after
a regen is a **stale control**, and its output then diverges from a fresh build
of the same sources. Measured on 2026-11-06: `build/` held objects for 4
generated translation units from 11-04 while `src/gen` already carried 17 from
11-06, and that binary disagreed with a freshly configured control at frame 1 of
`short.txt` (2 WRAM bytes, 12 at frame 2, back to identical by frame 10). Check
`ls build/CMakeFiles/ShadowrunSNESRecomp.dir/src/gen/*.o | wc -l` against
`ls src/gen/*.c | wc -l` before using an existing tree as the control leg —
`tests/provenance.py record` writes that check into the leg's dump directory and
warns when the two disagree (§7.6).

Moving the pin itself is a separate job from re-checking a change inside a pin.
Three checks first:

1. `tests/cyc_model_diff.c`, built against the framework tree in question (§4 of
   `evidence/a7`), to confirm the floor's and the folded authority's per-opcode
   charges still agree. Read its scope honestly: it compares `interp816` against
   the generated `snes_cycles.h` and pays the taken-branch cycle at the
   terminator, so it says nothing about the pace path's per-insn charge and
   cannot catch a fold-related undercharge (`evidence/a7` §9.4).
2. The framework's own `tests/v2` subset — it needs pytest, and shows ~85
   pre-existing failures on this machine with no `cargo` on `PATH`, so compare
   failure *sets* rather than counts. The cycle tests worth watching are
   `test_emit_cycle_charge.py` (runtime taken branch) and
   `test_folded_branch_cycles.py` (statically-proven taken branch).
3. The constant-Z fold census on this ROM: wrap the decoder's
   `_apply_constant_z_fold` post-pass while running `snesrecomp_cli.py generate`
   into a scratch out-dir and count fold records. Today it is 0 for Shadowrun's
   214 AOT variants, and a non-zero count is the only case where a per-insn
   charging model can lose 6 master clocks per folded taken branch per pass
   (`evidence/a7` §9.4 has the recipe).

A pin move that changes cycle charges moves the frame boundary, so both horizons
move with it: re-capture both cross-path legs and write a new baseline with
`--update`, and treat the new horizon as the result rather than a regression. A
re-pin onto current upstream is already known to collide with the port's cycle
commit — see `evidence/a7` §9.4.

### 7.4 A ROM-free build (2026-11-06): the image inside the executable

Stage-1 item C0/M3. `SHADOWRUN_EMBED_ROM=ON` compiles the guest image into the
executable itself — `tools/embed_rom.py` writes it after checking it against
`rom_identity.txt`, and the framework host re-hashes those bytes against the same
digests at boot — so the machine code and the image it is playing cannot come
from different revisions. Full record, including the negative controls:
`evidence/c0_rom_free.md`.

**Not promoted.** The framework half sits on branch `feat/embedded-rom`
(commit `c5024e74`, branched from `76eda6dd`), never pushed and untested by the
framework's own suites, and `framework_pins.txt` still names
`773285b8210f2254ae87d0a14113980fb36990ad`. The staged `./Shadowrun` still opens
a file on disk; the ROM-based build remains the parity reference. A ROM-free tree
is measured against it like any other second binary:

```sh
PORT_BIN=./build-ctrl/ShadowrunSNESRecomp \
  PORT_BIN2=./build-embed/ShadowrunSNESRecomp ./tests/parity.sh tests/scripts/menu.txt
PORT_BIN=./build-embed/ShadowrunSNESRecomp ./tests/selfcheck.sh
PORT_BIN=./build-embed/ShadowrunSNESRecomp ./tests/headless.sh
```

Measured: `identical over 1245 frames` against a control configured fresh from
the pristine pin sources, selfcheck PASS, 1245 frames headless. Byte-identical is
the right expectation here, not the phase tolerance of §7.2: both binaries run the
same compiled path, so this is a §4-class same-path comparison. The ROM-free run
also needs nothing in its directory but the executable — no `.sfc`, and no
`rom.cfg`, because there is no file to cache.

`PORT_BIN` now selects the binary in every script in this kit. `headless.sh`,
`shots.sh` and `play.sh` honoured only `./Shadowrun` until this round, which is
how a smoke test of the wrong binary can look like a pass.

### 7.5 The staged bundle is not this tree's program (2026-11-06)

A control has to be a build tree, never `./Shadowrun`. Measured on `menu.txt`
(1245 frames, byte-exact WRAM crc32 per frame):

| comparison | verdict |
| --- | --- |
| pin framework (`build-ctrl`) vs the port's cycle work rebased onto current upstream (`build-up`, branch `rebase/aot-cycle-onto-origin`) | **identical over 1245 frames** — this route cannot tell those two framework bases apart |
| either of those vs the staged `./Shadowrun` (5,941,232 B, 2026-11-05) | **first divergence at frame 1**, 1219 of 1245 frames differ, and the host-frame phase between the legs *drifts* (`tick` mode: k=0 → -1 → -3) rather than sitting at the constant one-frame offset §7 documents |
| the ROM-free build on the upstream-rebased base (`build-up-embed`) vs `build-up` | identical over 1245 frames — §7.4's result holds on a current-upstream base too, the embed seam cherry-picks cleanly onto it |
| `build-up-embed` on its own gates | `selfcheck.sh` PASS, exit 0; `headless.sh` 1245 frames, `rom resolved: <embedded:Shadowrun (USA).sfc>` |

All four trees named in that table are gone: `build-ctrl` (9,6 M), `build-b0`
(132 M), `build-up` (9,8 M) and `build-up-embed` (9,6 M), deleted 2026-11-09 with
every other closed round's tree (`evidence/artifacts/build_trees_cleared_2026-11-09.md`).
`build-ctrl` is rebuildable -- it is §7.10's configure line with `SNESRECOMP_ROOT`
pointed at the pin. `build-up` and `build-up-embed` are not: the branch they were
built from, `rebase/aot-cycle-onto-origin`, is not in this repository and not on the
push mirror, which carries only `main`. Read those two rows as a measurement taken
on 2026-11-06, not as a check that can be re-run today.

A drifting phase means the guest is being advanced at different rates, so the
staged artefact's AOT promotion is not the promotion `src/gen` carries today. Its
1.9 MB of extra `__text` is *not* evidence of that — extra code with identical
behaviour is what an un-eliminated link looks like — the frame-1 divergence and
the phase drift are what say it. Full record: `evidence/c1_staged_bundle_stale.md`.

What this does not touch: the §7.2 baselines. `horizon_xp.json` names
`tests/out/xp_aot`/`xp_lle` and `horizon_bs.json` names `bs_aot`/`bs_lle` — all
build trees of this repo, so the horizons are one regen behind, not orphaned.
What it does touch: §4's transcript and §7.1's shipped claim describe a program
this tree no longer produces.

### 7.6 Every run now says which program made it (2026-11-06)

§7.5 and the stale-`./build` note are the same failure wearing two faces: an
artefact that no longer identifies its inputs. Frame dumps never recorded which
executable wrote them, and both recorded baselines name scratch paths under
`tests/out/` that any later build overwrites, so "is this difference the known
cross-path effect, or a different program?" was archaeology. So the kit now
records the answer next to the frames.

```sh
python3 tests/provenance.py record <binary> <dump-dir>  # write <dump-dir>/run_manifest.json
python3 tests/provenance.py key <dump-dir>              # one-line identity
python3 tests/provenance.py same <leg> <leg>            # same program? 0/1/2
python3 tests/provenance.py same-src <leg> <leg>        # same *inputs* (see below)
python3 tests/provenance.py show <leg>                  # the whole manifest
```

A manifest carries the executable's sha256 and size, the generated set it was
compiled from (sha256 over `src/gen`, plus 17 units / 205 promoted functions /
217 dispatch entries so a delta is readable), the framework root and git
revision, the build type and the `SHADOWRUN_EMBED_ROM` flag, the port's own git
rev, and warnings. `parity.sh`, `crosspath.sh` and `bisect_aot.sh` record every
leg they run, and `framedump_diff.py horizon` prints both manifests before it
prints any number. What `./tests/parity.sh` on its own now ends with:

```
       manifest: .../tests/out/run1/run_manifest.json
         exe    sha256 ebca100c3a01201a  5,941,232 B
         WARN   no CMakeCache.txt beside the executable: this is a staged or
                copied binary, so the framework and generated set behind it are
                unknown from the artefact alone
       manifest: .../tests/out/run2/run_manifest.json
         exe    sha256 ebca100c3a01201a  5,941,232 B
         WARN   no CMakeCache.txt beside the executable: ...
identical over 1200 frames
```

(That WARN is one long line; it is wrapped and abbreviated above only to fit.
The `...` in the paths stands for the port's own directory.)

The staged bundle is deterministic with itself and still cannot be bound to a
build tree — which is the whole point: §7.5's finding now arrives in two lines,
before any frame is compared.

The gate rule, in plain language: **a horizon check refuses to judge a pair
against a baseline that names different inputs**, and it refuses *before* the
scan — no 26,000 frames decoded to produce a meaningless number. It compares
*inputs* (generated set, framework revision, config, embed flag), not the
executable's bytes, so rebuilding the same sources in a fresh tree is not
mistaken for a different program. That is safe because the build was measured to
be reproducible: two trees configured at different times from the same framework
root, the same `src/gen` and the same flags produced sha256-identical
executables (`build-embed` vs `build-embed2`, `7eb8008d…`). A different hash
means a different input, not a different link.

Both directions were checked with the machine, not by reading the code:

| case | what the gate does | exit |
| --- | --- | --- |
| same inputs, baseline carrying provenance | judged | 0 |
| baseline whose framework rev is edited (`deadbeef…`) | `run1: framework was deadbeef… in the baseline, c5024e74… here`, scan not run | 2 |
| baseline whose `gen_sha256` is edited, judged on the real `bs_aot`/`bs_lle` dumps | refused; `grep -c "paired at the same host frame"` over the output is **0**, proving no frames were decoded | 2 |
| same tampered baseline, `--inputs-changed` | the delta printed as notes, then judged normally: `holds: horizon f16280 vs baseline f16280` | 0 |
| baseline with no provenance block (what both shipped baselines look like today) | a note, then judged normally | 0 |
| legs with no `run_manifest.json` beside their dumps | `no run_manifest.json in this leg's directory`, scan not run | 2 |
| no baseline argument at all | measured, `nothing was judged` | 0 |
| baseline path that does not exist | unchanged rule: no verdict | 2 |
| an unknown `--flag` | `unknown horizon flag(s): --nope`, rather than being mistaken for a baseline path | 1 |

Two staleness warnings come along free, and they name the exact §7.5 failure
modes: `stale build tree: 4 generated .o against 17 generated units` (that is
`./build`, when the guard landed, and `./build-lle`) and `N generated file(s)
touched after this executable was linked`. The first automates the `ls … | wc -l`
against `ls src/gen/*.c | wc -l` that §7.3 says to do by hand before trusting an old
tree; the second catches the other direction — a generated file restored or
regenerated after the link, where `cp -p` keeps the older mtime so
`cmake --build` silently declines to recompile it. Both fired on the trace trees as
those trees stood then, and both statements were true of them: `build-tr-aot`
carried 18 generated `.o` against 17 units on disk, and `build-tr-lle` was last
linked before the bisect regen touched 18 generated files. Both trees are deleted (224 M and 222 M,
2026-11-09; `evidence/artifacts/build_trees_cleared_2026-11-09.md`), so that pair is
a rebuild, not a re-run. Nothing in this kit creates either tree — a sentence in
this section used to say `./tests/bisect_aot.sh` recreates `build-tr-aot`, and that
was wrong: the script regenerates `src/gen` (line 58) and then
`cmake --build build-tr-aot -j 8` (line 59), which builds a tree that has to already
exist, and it pins the framework itself at line 57 with
`export SNESRECOMP_ROOT=/Users/wee/Documents/work/snesrecomp`. Recreating the pair
means configuring both by hand — Release plus `-DSNESRECOMP_ENABLE_TRACE=ON`, which
is what let them answer on the debug port and is why their binaries were 222–224 MB
rather than the shipped 3 MB — at the framework that line names,
`76eda6dd`, pin + 2 docs-only commits (`evidence/c1c_framework_copy.md` §"which tree,
which framework"). Then the ordering `evidence/a7` §8.6 records: regen at the floor
set (`tests/forces/all_lle.txt`, the same splice `tests/make_lle_floor.sh` drives) and
build the floor tree, then regen at the promoted set and build the promoted tree.
`tests/tr_build.sh`, which used to do that ordering, is itself gone.

Caveat, stated as a caveat: `tests/baselines/horizon_xp.json` and
`horizon_bs.json` were captured before this existed, so they carry **no**
provenance block and the guard is note-only against them until the next real
gate run re-records them with `--update`. Until then those two gates bind
nothing. A staged or copied executable (`./Shadowrun`, or the `cp -p` control in
§4) gets an executable fingerprint and `unknown` for everything else: it has no
`CMakeCache.txt` beside it, so its provenance genuinely cannot be recovered from
the artefact, and the manifest says so rather than guessing. Full record:
`evidence/c1b_run_provenance.md`.

### 7.7 Which ROM bytes the game reads, and who reads them (2026-11-06)

M1 asks whether guest data can move out of the cart file and into host tables.
That needs a runtime answer, and nothing in the framework's debug server had one:
its ~197 commands cover VRAM, OAM, WRAM and dispatch, and there is no cart-read
hook. The framework branch `feat/cart-read-trace` (commit `48d2d1b7`, one commit
off the pin, **not** on `main` and not in the pin) adds an opt-in observer:

```sh
# the observer is a framework branch, not the pin: check it out somewhere
git -C /Users/wee/Documents/work/snesrecomp worktree add <dir> feat/cart-read-trace
cmake -S . -B build-b0 -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=<dir>

# arm it with one variable; unset and the cost is a single branch
SNESRECOMP_CART_TRACE=/abs/path/trace.json ./build-b0/ShadowrunSNESRecomp \
      --no-launcher --script tests/scripts/menu.txt
```

Unset the variable and the cost is one branch. `framework_pins.txt` stays at
`773285b8…`: a capability that is opt-in and unmerged does not move the pin.

| script | what it answers |
| --- | --- |
| `tests/collect_read_traces.sh` | runs every frozen route under the observer into `tests/out/b0/<route>.json` (SRAM restored per route, same anchor rule as `tests/parity.sh`), then writes the report |
| `tests/cart_trace_report.py` | merges the traces, joins them against the port's promoted-function list, writes `tests/out/b0/report.md`. `--port-root` is the port root (it wants `src/gen` **and** `recomp/`), `--coverage` is optional and only used for a sanity cross-check |
| `tests/cart_trace_neutral.sh` | is the observer inert? `ctrl`/`off`/`on`, three runs from one SRAM snapshot, per-frame WRAM crc32, and a provenance line per leg |

Both scripts check their binaries against `framework_pins.txt` before running
anything, through `tests/provenance.py pin [--exact|--descendant] <binary|build-tree|framework-root>…`:
it reads each build tree's own `CMakeCache.txt` to find its framework root and asks
**git** what revision that root is, not the binary's stamp.

```
AT THE PIN   ./build-pin/ShadowrunSNESRecomp: …/sr-pin @ 773285b8210f…
OFF THE PIN  ./build-b0/ShadowrunSNESRecomp:  …/sr-b0 @ 48d2d1b7…, with 773285b8210f as an ancestor
UNKNOWN      ./build-ctrl/ShadowrunSNESRecomp: …/snesrecomp-clean is not a git checkout …
```

`tests/cart_trace_neutral.sh` requires `--exact` for the control leg (default
`CTRL_BIN=./build-pin/ShadowrunSNESRecomp`) and `--descendant` for the observer leg,
and prints both checks into `tests/out/ct_neutral/verdict.txt`;
`tests/collect_read_traces.sh` requires `--descendant` for the observer build. A
`framework=unknown` stamp is not a substitute for a revision — the check exists
because the previous control was a directory **copy** of the framework that
predated the pin, and a copy is only as current as the day it was copied. Why that
matters, how the copy was caught, and how to build a control that passes
(compilers included): `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c1c_framework_copy.md`.

Three guards in the report, because both of its bugs produced plausible tables:

- it **refuses** a `snesrecomp.cart-trace.v1` file, and refuses a v2 file whose
  `seams` lack `cpu_read8` or whose `cpu_reads` is 0 — a trace from the first,
  blind seam (264,368 reads, **zero** instruction fetches on a route that
  executes tens of millions of them) rather than a thin one;
- it **aborts** if the trace's block keys are not 512-aligned. The join once
  looked up block *numbers* in a table keyed by block *offsets*, every lookup
  missed, and the table printed "206 promoted entry points, none of them ever
  read" — the opposite of the truth;
- it **suppresses** the coverage ratio for a route whose two runs are different
  lengths. The A1 capture predates the longer route scripts (nav1 1,932 frames
  then, 16,188 now), so its frame count is not a denominator.

Read the fetch mark at its real width: `f` means the interpreter took the byte
from the instruction stream, which is one reader (`interp816_readOpcode`) and
covers an instruction's operand bytes as well as its opcode — the right width for
"must stay fetchable", not a per-opcode count. And the reading PC on a pair is
whatever PC the interpreter published last, so recompiled reads carry a stale PC:
the per-PC tables rank the interpreted path, they do not attribute reads to
routines. The honesty fields (`ring_wraps`, `pairs_truncated`, `pair_overflows`,
`tail_reads`, `rom_resets`) say which bounds were hit — on the long routes the
20,000-row pair table is truncated while the block, bank and totals columns stay
complete, which is why every footprint claim is made from those.

Two joins turn those traces into a plan. Against the promoted list in `src/gen`
and `recomp/*.cfg` they say which fetched blocks hold no compiled entry point.
Against `src/gen/program_manifest.json` — the analyzer's own record, one node per
`(PC, M, X)` with a bounding `[min_pc24, max_pc24]` span — they say which fetched
blocks sit inside **no analysis at all**: 26 blocks, 13 KiB, 38.9 % of all the
reads, 98.8 % of it instruction traffic. That is the promotion frontier, and it is
the only extents-like shape this project has; both of its errors (a span is a
bounding box, analysis is seeded by `recomp/symbols.toml`) point the same way, so
the frontier is a floor. Deciding from it: `evidence/m1_hybrid_decision.md`. That
decision's round 1 has since run and closed this frontier — the same join on the
seeded build reads 3 blocks, 1,820 reads, 0.0 % (`evidence/m2_promotion_round1.md`).
Round 2 therefore seeded from a different static signal, the callees named by round 1's
`unproven_call_at_…` refusals, and the frontier metric did not move at all (identical
3 blocks); 4 bodies came out and none of them ever dispatch, and 5 of the 20 seeds named
addresses that are not ROM at all under the cart's LoROM mapping
(`evidence/m2_promotion_round2.md` §2). Treat the read-trace frontier as retired as a
seed source — `tests/frontier_seeds.py` still works and still says 0.0 %, but there is
nothing left in it. The runtime worklist the framework itself points at is the dispatch
ring's `found:0` entries, compiled in with `-DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON`, and
round 2b built it and read it: **0 misses in 574,973 dispatches** (§7.8,
`evidence/m2_promotion_round2b.md` §4). All three seed sources — fetch frontier, refusal
callees, dispatch misses — are now closed.

The traces themselves are build output and stay out of git (`tests/out/` is
ignored), so `--digest` writes the machine-checkable version of the same numbers
to `evidence/artifacts/b0_digest.txt`: every figure plus each trace's sha256, and
the neutrality verdict logs folded in with `--neutral <log>`. That digest is what
gets committed.

Full measurement, including the neutrality verdict on both the 1,245-frame menu
route and the 25,902-frame combat route: `evidence/b0_read_trace.md`.

### 7.8 The runtime promotion worklist, and the route it is measured on (2026-11-07)

The dispatch ring is the framework's own promotion signal: every indirect dispatch
(RTS/RTL trampoline, runtime-pointer `JSR (abs,X)`) records
`(pc24, source_pc24, func_name, mx_idx, found, mirror, frame)`, and `cpu_state.c` labels
the `found:0` entries "the promotion worklist". Two build switches stand between us and
that line of commentary:

```sh
cmake -S . -B build-dht -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON -DSNESRECOMP_ENABLE_TRACE=ON
```

`DISPATCH_HISTORY` is what arms the ring and makes the post-mortem report carry
`dispatch_log` instead of `{"dispatch_log": {"disabled": true, "total": 0}}`. `TRACE` is
what gives the TCP readouts (`dispatch_log_get`, `interp_stats`) — without it
`debug_server_init` is a stub and no port is opened, so a script that never exits would
hang a `--dump`-only read. Both are off in the shipped configuration, and the resulting
binary is 38x the shipped one (113 MB vs 2.9 MB), which is why it is a diagnostic tree
(`./build-dht`) and never a promotion candidate.

`tests/dispatch_worklist.py` reads that build over a script and answers three questions in
one pass: how many dispatches, how many missed, and where the misses live once joined
against `src/gen/program_manifest.json` (`269 variants / 251 addresses`,
`240af24bb4a7…`). It prefers the live TCP ring (`--tcp`) because the ring keeps only the
last 1,024 entries — on the combat route 301,283 of 574,973 records were evicted — and
falls back to the post-mortem JSON only when the script exits on its own, because
`PostMortem_Write` runs from `SDL_Quit` and a timeout-exited script (exit 3) never gets
there. Committed record: `evidence/artifacts/dispatch_worklist_combat.json`.

The answer is that the worklist is empty, and the emptiness is a measurement, not an
absence of one: the always-on `found1/found0` tallies cover the whole run rather than the
ring's tail, so `found:0 == 0` over 574,973 dispatches means the dispatch table is never
consulted at an address it has no body for. Read that with the mode mix (`m0x0` 250,681 /
`m1x0` 21,234 / `m1x1` 89 — index 2 of each row's four variant slots really is requested,
just never at a NULL slot) and it retires `entry_mx_at` as a lever. See
`evidence/m2_promotion_round2b.md` §4.

Route caveat, resolved 2026-11-07. The §7.7/§7.8 numbers above were measured on the *old*
combat.txt, whose alley tail ended with the party dead — the `W1` dump at f22951 was the
**title screen**. That tail is gone (`evidence/m2_promotion_round2b.md` §6): the route now
gates the alley segment on WRAM state (`until16 1f2 == 6d00`, `until16 1f0 == 7600` — the
screen origin at the alley and its left clamp) and stops alive at `A5`. Gate route steps on
WRAM state, never frame counts: an input-fixed route does not put both paths in the same
place (some AOT/LLE route pairs are WRAM-identical for thousands of frames, others differ
from f1). And the alley is a scripted kill scene — parked at the safe screen origin with no
input, the game wipes the party inside ~2,900 frames on both paths — so "end alive in the
alley" is a real constraint, not a difficulty setting.

`tests/route_state.py` is the check that keeps it true: it reads a leg's tagged dumps from a
`--framedump` directory (frame, screen origin, hp bytes, message-window label per
checkpoint), and exits nonzero when any checkpoint sits after a death marker (`Jake is
dead.` / `Game Over.`). Run it on both legs after any route change, before re-binding a
baseline.

### 7.9 Reading what the interpreter is actually doing, and the idle-poll lever (2026-11-07)

Promotion round 3 asked whether the interpreted residue is reachable from the **entry**
side. It is not: 96.94 % of it is never sighted at a transfer gap, so a body seeded at any
address never intercepts it, and what the residue *is* turned out to be interrupt waits —
33.80 % of it self-branching compare-and-branch-back loops, 31.53 % of it two waits on the
game's frame counter `$7E1C92`. The record, with every number bound to its capture, is
`evidence/m2_promotion_round3.md`. The tools that made it are here because they are the only
way to re-measure that claim, and one of them is a lever that measured as **not adopted**.

Measuring the residue. `--coverage-capture=on` writes a per-instruction journal; the pinned
framework's own ingest turns it into the report every tool below reads:

```sh
. tests/rom.sh; rom=$(sr_rom)
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy SNESRECOMP_TIER2_MANIFEST=/abs/leg.json \
  ./build-r2b/ShadowrunSNESRecomp --no-launcher --rom "$rom" --coverage-capture=on \
  --script "$PWD/tests/scripts/combat.txt"                       # 22,044 frames, exit 0
python3 "$PIN"/tools/tier2_ingest.py --json --cfg-dir recomp \
  --program-manifest src/gen/program_manifest.json <export>.json \
  > evidence/artifacts/tier2_capture_round3_combat.json          # committed

python3 tests/coverage_gaps.py evidence/artifacts/tier2_capture_round3_combat.json
#   hot AND sighted at a gap  3.06 %  (28,131,074 cyc, 233 (pc,mx) entries)  seedable
#   never sighted at a gap   96.94 %  (891,176,249 cyc)                      entry-unreachable
SNESRECOMP_ROOT="$PIN" python3 tests/wait_class.py evidence/artifacts/tier2_capture_round3_combat.json 300000
#   13 self-branching waits = 310,681,830 cyc = 33.80 % of the residue
```

`tests/poll_scan.py <ingest.json> [min_cycles]` is the first-pass shape scan — for every hot
PC, the next few ROM instructions and whether the PC heads a self-branching wait, and whether
the polled read is WRAM (replayable) or an IO register (refused by guard 3 whatever is
declared). `wait_class.py` is that join grouped per loop and costed; `wait_cost.py` answers
the narrower question the A/B turns on — what does one specific set of declared PCs cost in
each leg, so the legs that declared nothing are the price of the same waits;
`disasm_span.py <pc24> <count> [m] [x]` prints a linear decode through the **pin's** decoder
(`recompiler/snes65816.py`), which is the only decode in this kit guaranteed to be what the
analyzer saw. The two that decode need `SNESRECOMP_ROOT` pointed at the pinned checkout.
`evidence/artifacts/idle_poll_cost_round3.txt` is that whole table as committed text,
generated from the per-leg `last_run_report.json`, log and ingest it names.

The lever, and why it ships off. `docs/IDLE_POLL.md` names a mechanism that needs no entry:
declare the PC of an interrupt-wait poll and the interpreter bridge replays that wait's cycle
to the frame deadline instead of interpreting it, under eight guards whose stated point is
that a wrong declaration costs speed and never changes behaviour. No framework host fills
that table in, so the title does: `DeclareIdlePolls()` in `src/game_rtl.c`, hung on
`kGameInfo.initialize`, fed by `SNESRECOMP_IDLE_POLLS` (comma-separated hex PCs; unset or
`off` declares nothing). **The default is nothing declared, and it stays that way** — the
cost half works (interpreted share 96.15 % → 55.13 %, the declared waits 31.53 % → 0.98 % of
cpu cycles) and the behaviour half fails at frame 9 of a boot with no input. Three harnesses,
deliberately separate, because cost and behaviour are different questions and the cost legs
cannot see the promise the guards make:

| script | answers | shape of the answer |
| --- | --- | --- |
| `tests/idle_ab.sh` | cost, per leg, with a capture per leg. Legs: bare labels declare nothing, `label:pc,pc` declares those PCs, `on` declares `$IDLE_POLLS` | `off`/`off2` must reproduce the round-2b control byte for byte (919,307,323 interpreted cyc / 956,096,571 cpu / 7,878,127,092 master) before any declared leg means anything |
| `tests/idle_parity.sh` | behaviour: per-frame WRAM crc32 over the whole route against `ip_off`, four legs (`ip_off` `ip_on` `ip_m0x0` `ip_m1x0`); then the same divergence read as bytes, per leg, around its first frame. `LEGS=` picks legs, `TRIM=1` drops the ~2.9 GiB of per-frame dumps once the log holds the reading | exit 1; first divergence f9 (pair), f9 (`$81EE8E` alone), f1733 (`$81B061` alone) |
| `tests/idle_f205.sh` | what the divergence actually is, in bytes, over two short routes (`idle_f205.txt` 210-frame no-input boot, `idle_dense.txt` 14 frames dense input) | f9 is **one** WRAM byte, `$7E0012E` `92`→`8E`, same value multiset in both legs; checkpoints with byte-identical WRAM still differ by −2…+20 master cycles |

The byte reading in the last two rows is `tests/framedump_diff.py` in three modes: `offsets`
(how many bytes per frame, and which addresses, over the whole corpus), `byte ADDR
[FROM TO]` (one address's value in both legs, frame by frame, with a value histogram per leg
— equal value sets with the counts shifted is *phase*, a value one leg never writes is a
state change), and `cpdump TAG…` (one tagged checkpoint read completely: guest frame index,
`master_clock`, `vpos`/`hpos`, every `regs.json` key — which is PPU/HDMA state only, no dump
here carries CPU registers — and every image beside it by hash, so "none" is a byte-level
statement). Phase is the finding that makes the guard failure interesting: the replay did not
write a different value, it spent different cycles — and `cpdump` is what says so, at
checkpoints where every dumped byte matches and only the clock moved.

Nothing in the committed artifacts is hand-typed. `tests/idle_artifacts.py` reads the run
files each artifact cites — the per-leg `last_run_report.json`, log and ingest for the cost
matrix, the `<tag>.info.json` / `<tag>.regs.json` / images beside the parity checkpoints — and
stamps the framework pin and both executables' hashes on top:

```sh
python3 tests/idle_artifacts.py cost         > evidence/artifacts/idle_poll_cost_round3.txt
python3 tests/idle_artifacts.py a0           > evidence/artifacts/idle_poll_a0_round3.txt
python3 tests/idle_artifacts.py checkpoints  > evidence/artifacts/idle_poll_checkpoints_round3.txt
```

`checkpoints` is the one to read first when the question is "did it change anything": every
tagged checkpoint of the committed route and of both probe routes, each leg against the
undeclared control, clock delta and differing images on one row each. It is also the control
group for the trap below — declaring `$81B061` costs 170 M charged cycles on the combat route
and changes *nothing*, every dumped byte equal, over 210 boot frames and 14 dense frames,
because those routes never reach that wait.

Each of those legs gets its own anchor under `tests/out` and a fresh copy of `saves/save.srm`,
for the reason `tests/crosspath.sh` already insists on: `saves/`, `config.ini` and
`last_run_report.json` are anchored to the executable's directory. `idle_f205.sh` names its
artifact directories by **route and declaration** (`idle_f205_p81b061_81ee8e`,
`idle_dense_p81ee8e`, `TAG=` overrides), because a shared `on` directory there once silently
overwrote another leg's dumps and its byte-level evidence survived only in scrollback.

Two measurement traps this round found:

- `execution_share.aot_cycle_pct` counts everything that is *not* interpreted, so declared
  polls inflate it (3.85 % → 44.87 % on an unchanged generated set). Never take a baseline
  with `SNESRECOMP_IDLE_POLLS` set, and never compare an AOT share that was taken with it set
  to one that was not.
- A script `until` timeout does **not** stop the script: it continues to the next entry and
  exits 3 at the end. A leg that exits 3 measured less route than the legs it is compared to
  (the declared pair leg: 21,639 frames where the control runs 22,044).

No leg may stop and ask for the ROM. The host resolves a dump in this order: launcher →
positional / `--rom` → a `.sfc` beside the executable → `rom.cfg` beside the executable → a
GUI file picker. The picker is a hang with a window on someone's screen, and it is reachable
by two harness habits: copying the binary into a fresh scratch anchor (no `rom.cfg` there),
and running a leg whose anchor holds neither a `.sfc` nor a cache. So every script in this kit
sources `tests/rom.sh`: `sr_rom` returns the repo-root dump (validated, because a leg against
the wrong dump measures nothing), and `sr_rom_stage <anchor>` writes a `rom.cfg` beside a
copied binary. Every leg therefore has both an explicit `--rom` and a staged cache; either
alone would be enough, both means a typo in one cannot resurrect the picker. The check:

```sh
grep -l -- '--no-launcher' tests/*.sh | xargs grep -L -- '--rom'      # empty
```

Why that is a rule and not a preference: while `tests/rom.sh` was being written, an ad-hoc
leg sourced it from zsh, where the `BASH_SOURCE`-based root derivation the first version used
does not exist, so it passed an empty `--rom`. The panel answered 77 s later and the run
continued against a duplicate dump in `~/Documents`. That copy had the same sha256 as the
checkout's (`e6bc0a595d5c…`), which is luck, not a contract — the capture's own `rom_sha256`
is what would have caught it. `sr_root()` finds the root by nearest ancestor holding
`framework_pins.txt` instead.

### 7.10 Seeding the gap ranking, and the gate that decides what ships (2026-11-08)

Promotion round 4 asked the only question round 3 left on the entry side: the capture says
3.06 % of the residue is hot *and* sighted at a transfer gap — so seed exactly that, and see
whether it converts. The record is `evidence/m2_promotion_round4.md`; this section is the
kit that produced it and the rules a future round must keep.

Two seeds shipped (`$80C399`, `$80AAB3`), eight were rejected, and the gate that decides is
**machine state, not cycle share**: `$80B1DB` moved 26.47 % of execution into compiled bodies
and was rejected for changing the machine, while `$80C399` moved 5.88 % and shipped.
`$80C399` + `$80AAB3` convert 58,467,808 interpreted cycles (−6.36 %) with cpu and master
clocks unchanged to the unit, and the drop equals the analyzer's merged span for the 14 new
bodies to the cycle.

Generating the seed table. `tests/gap_seeds.py` turns a capture into `[[func]]` text; no
table in this repository is hand-written.

```sh
# what the ranking says, and what a given set would leave behind
python3 tests/gap_seeds.py evidence/artifacts/tier2_capture_round3_combat.json \
    --top 10 --route combat --list \
    --manifest evidence/artifacts/round4_manifest_pre.json.bz2 \
    --symbols recomp/symbols.toml
# the baseline a variant is cut from (never edit a copy by hand)
python3 tests/gap_seeds.py --baseline-only recomp/symbols.toml > tests/out/base.toml
# before/after: the same ranking and residue on the program that shipped the seeds
python3 tests/gap_seeds.py <pre-capture> --route combat --list --symbols <base> \
    --then <post-capture> --then-manifest <post-manifest.json.bz2> \
    --then-symbols recomp/symbols.toml
```

`declared_entries()` and the `--baseline-only` count are anchored to a `[[func]]` header on a
line of its own (`(?m)^\[\[func\]\][ \t]*$`). The table's own header comment says “Each
`[[func]]` names an address”, and a substring count reads that sentence as an entry — it
reported 41/43 where the real numbers are 40 baseline / 42 shipped. The archived leg logs
that printed that 41 are re-derived line by line: `round4_artifacts.sh` and
`round4_probe.py` replace the one `baseline:` line with the current generator's count (and
say so in the artifact header), so no shipped artifact carries the stale number; every
other line of a leg log is shipped byte-for-byte.

One variant per seed, and the sweep:

```sh
SNESRECOMP_ROOT=<pin> ./tests/seed_variant.sh s80C399 --only '$80C399'   # build + route + parity + capture
# the sweep takes the control variant, then bare entry PCs; it appends one row per
# seed to tests/out/r4/sweep_<control>.tsv (remove that file first to re-run)
./tests/seed_sweep.sh r4base 80C399 80AAB3 80ABBC 80B1DB
python3 tests/seed_matrix.py --dir tests/out/r4   # one row per variant: manifest, exit, share, abandon
python3 tests/gap_seed_audit.py \
    --post-manifest tests/out/r4/manifest_r4pair.json.bz2 \
    --capture evidence/artifacts/tier2_capture_round3_combat.json \
    --pre-manifest evidence/artifacts/round4_manifest_pre.json.bz2 \
    --symbols tests/out/r4/variant_r4pair_symbols.toml   # ranking -> manifest -> cycles
```

Each variant is built from the generator's baseline plus exactly one `--only` seed, so a
variant's identity is reproducible from the capture it came from. Seeds never remove or
rewrite nodes (every round-4 variant: 0 removed, 0 changed).

The adoption gate, in the order it is applied:

```sh
python3 tests/cpdump_matrix.py <control-dump-dir> <variant-dump-dir>   # 22 checkpoints
python3 tests/apu_shift.py <control-dump-dir> <variant-dump-dir>       # is apu-only a re-stamp?
python3 tests/cp_byte_diff.py <control-dump-dir> <variant-dump-dir>    # bytes, split by label rule
```

`cpdump_matrix.py` classifies each tagged checkpoint `clean` / `apu-only` / `DIFFERS(...)`.
`apu-only` is not a pass by itself: `apu_shift.py` separates a pure re-stamp (same
`(frame,event,port,value,sample)` multiset, `hclock` moved within one frame) from a changed
event stream — the accepted trees are all re-stamps, `r4clean` is a different stream.
`cp_byte_diff.py` labels each differing byte with `framedump_diff._is_label` (one rule,
imported, not copied), and only counts non-label bytes as state. Run the accepted program
against itself as the control: 0 differing bytes in all 132 rows over wram, vram, oam, cgram,
sram and the framebuffer is what makes an `apu-only` cell attributable to the seed.

`tests/framedump_diff.py` now also has

```sh
python3 tests/framedump_diff.py state <run1> <run2> [FROM TO]   # name the non-label bytes
```

because `drift` counts 1 KiB blocks and a divergence that starts in one byte is narrower than
a block. `byte 0x127 <run1> <run2>` answers a single address across every frame. These are
how the rejected trees were closed at byte level rather than by share.

The phase objection — "two legs at different host speeds compare different guest moments" —
is answered by `tests/rejected_shift.sh <variant>`, which runs both legs on the dense parity
route from a scratch anchor under `tests/out/r4/anchor_<variant>/` (never inside a
`build-*/`, whose `last_run_report.json` is another artifact's join target) and prints five
probes: `tick` (guest-counter pairing and phase offset), `shift` (bytes at the same guest
tick), `drift` (blocks over frames), `state` (first differing byte, with values) and `byte`
(one address). A rejection needs the onset frame, the byte, both values, and `k=+0`-style
evidence that alignment does not remove the diff.

Cost, with the host switches pinned per leg:

```sh
tests/aot_charge.sh pair_nf:build-r4pair/ShadowrunSNESRecomp:nofloor:off:1   # <leg>:<binary>:<floor>:<capture>[:dump]
python3 tests/charge_report.py tests/out/charge base_nf pair_nf <legs...>
python3 tests/charge_wall.py tests/out/r4/charge_wallbatch.log wbase_ wpair_
```

`aot_charge.sh` writes each leg's environment beside its log, in `CHARGE_DIR` (default
`tests/out/charge`); `charge_report.py` joins legs by name and keeps a leg whose route ended
at a different frame count in the table while dropping it from the deltas. `charge_wall.py`
groups legs by **build directory** (every executable is named `ShadowrunSNESRecomp`), takes
same-binary replicates as the noise floor, and reads an interleaved batch pairwise — the
round-4 lesson is that the accepted tree's wall clock gain (−1.36 s) fails the per-binary
floor (1.43 s) and passes the paired test (0.34 s), so both have to be reported.

Two tools answer "why is the rest not seedable", and they are the round's conclusion:

```sh
python3 tests/hot_vs_aot.py evidence/artifacts/tier2_capture_round3_combat.json <manifest.json.bz2>
#   exact-aot 0.37 % | span-aot 30.02 % (2801 hot PCs, 12 gap-sighted) | no-node 69.25 %
SNESRECOMP_ROOT=<pin> python3 tests/round4_probe.py   # a generated root at the hottest PC: 0 cycles moved
python3 tests/symbol_table_key.py evidence/artifacts/tier2_capture_round3_combat.json \
    tests/out/r4/manifest_r4base.json.bz2             # what the loader already owns at an address, and why
```

`round4_probe.py` prints from archived logs and re-runs only the seed generator and the pin's
symbol loader (to show the `conflicting tier/entry modes at $81B05D` refusal); it does not
rebuild. `symbol_table_key.py` is the one to read before seeding an address that already has
a `GS_`/`CC_` declaration.

Finally, the tree that shipped is verified end to end, and the artifact set has one owner:

```sh
./tests/accepted_tree.sh     # src/gen == the archived generated set, manifest, seed block
./tests/accepted_verify.sh   # the legs: short script, combat route, gate, parity, capture
SNESRECOMP_ROOT="$PIN" ./tests/round4_artifacts.sh    # every evidence/artifacts/round4_*
```

`accepted_verify.sh` runs its legs from `tests/out/r4/accepted/anchor_pair` and checks the
live `src/gen`, the manifest digest and the re-derived seed block against the archive before
it measures anything. `round4_artifacts.sh` runs **no** route leg, no `tools/regen.sh` and no
cmake: it only re-derives text from `tests/out/r4`, and it owns the artifact names, so a claim
in the record that does not appear in `evidence/artifacts/round4_*` is wrong. Both of those
inputs are cleared now — `tests/out/r4/` and the four round-4 trees (`build-r4base`,
`build-r4clean`, `build-r4pair`, `build-r4probe`) — so running either script today means
re-running round 4's legs first; the committed `round4_*` artifacts are what carry the claims.

### 7.11 Authorising an indirect dispatch, and re-baselining the shipped pair (2026-11-08)

Promotion round 5 answers the question round 4 left open: the six seeds that stopped at `$80F4F9`
were not being judged as seeds, they were being judged as an unauthorised tail transfer. The
record is `evidence/m2_promotion_round5.md`; the authorisation is the hand-written block at the
end of `recomp/bank80.cfg`, and `tests/round5_artifacts.sh` is the files-only generator for
every `evidence/artifacts/round5_*` claim.

The directive is one line after the generated block:

```
indirect_dispatch f4f9 50 ptrtail targets:808371,808521,...,80E22C
```

The site is `$80F4F9  JMP ($00A2)`; the target list is the capture's own discovery rows at
that site. Three rules the loader enforces, learned the hard way:

* targets are **bare hex**, never `$`-prefixed; the declared count must equal the number of
  targets or `tools/regen.sh` refuses the line;
* `ptrtail` inherits the caller's return context, which is what a hand-written `JMP (ptr)`
  tail transfer does; an unlisted pointer still takes the emitted `default:`,
  `interp_tier_dispatch_tail`, so authorising cannot drop a transfer;
* the pointer-mode targets register as **decode successors**. If the site is compiled, the
  directive can pull ~200 nodes into the program (round 5 saw `269 -> 476` for one seed);
  if the site is not in the program it changes nothing (`r5base` is byte-identical to round
  4's control program, `240af24b`).

Inertness. On the shipped pair the directive changes no instruction body: all `bank*_v2.c`,
`dispatch_v2.c` and `unresolved_stubs_v2.c` are byte-identical to round 4's, and only
`module_v2.c`'s two digests plus the manifest's `exit_modes` (`249 -> 319`, +70) move. The
program digest therefore moves (`eea52f07 -> aa4a6f28`) even though the machine does not;
**do not re-use a pre-directive digest for a rebuild of this tree**. `round5_directive_inert.txt`
prints the file-by-file and node-by-node comparison.

The re-baselined tree and gate:

```sh
./tests/accepted_tree.sh r5pair build-r5pair      # src/gen, manifest, seed block
SNESRECOMP_ROOT=<pin> ./tests/accepted_verify.sh  # PAIR=r5pair BUILD=build-r5pair CONTROL=r5base
```

`accepted_verify.sh` is now parameterised: `PAIR`, `BUILD`, `CONTROL`, `MANIFEST` and `PRE`
select the tree, the control it is measured against, and the archives. Round 4 is still
verifiable with `PAIR=r4pair BUILD=build-r4pair CONTROL=r4base
MANIFEST=evidence/artifacts/round4_manifest_r4pair.json.bz2`. The default
`CONTROL=r5base` is safe because its program is byte-identical to `r4base`.

Reading a rejection when the first named byte is stack scratch. `tests/cp_byte_diff.py` and
`framedump_diff.py state` name the first differing byte, but a byte below the stack pointer
is dead scratch and can differ within one frame and be overwritten before the next boundary.
Two tools separate that from a persistent split, both driven by `WT_LEGS` and `wram_trace.py`:

```sh
SNESRECOMP_ROOT=<pin> \
WT_LEGS=ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/ShadowrunSNESRecomp \
  python3 tests/latch_writer.py --addrs 0x126,0x127 \
      --route tests/out/probe_dense.txt --park 1832
SNESRECOMP_ROOT=<pin> \
WT_LEGS=ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/ShadowrunSNESRecomp \
  python3 tests/latch_state.py --route tests/out/probe_dense.txt \
      --frames 1829,1831,1833,1835,1837
```

`latch_writer.py` pages the full write record (`wram_writes_at`) where the byte changed and
then re-runs with `get_wram_trace` armed around the onset, so a split gets the writing block's
PC. `latch_state.py` samples at frame boundaries and splits the stack page at `max(S)` into
live bytes (`>= S`) and dead scratch (`< S`), and reports DP, `S`, `D`, the latch bytes and
both cycle counters. Round 5's result is the reason both exist: `$0126 88 -> 85` at
`frame_001830` is a within-frame transient (the `$0126/$0127` write sequences are identical;
at the frame boundaries the bytes agree), while the persistent divergence starts at
`frame_001834` in live stack `$013A` and the direct page. A rejection has to cite the
persistent split, not the first raw byte.

Finally, the six seeds became runnable but not adoptable. Five now reach `22044`; all six fail
the state gate at `frame_001828` (`2745 of 4575`). `$80F495` still stops at `until $001F0`
(having the odd manifest shape `406 aot_eligible, 70 lle_only`), which is a route gate and not
a dispatch question. The next sweep should be `pair + seed` against `pair`, not `base + seed`
against `base`: the accepted-program capture in
`evidence/artifacts/tier2_capture_round5_accepted.json` still ranks the six rejected seeds
first, so the seed table will not run out of candidates before the gate runs out of patience.

### 7.12 Asking whether the seam moves the work or the counter (2026-11-08)

The round-5 gate leaves two readings for the `cpu_cycles` delta at the seed's onset: the seam
made the two builds execute different work, or the two tiers price the same work differently.
The framework already carries both probes, so nothing had to be added:

* `SNESRECOMP_AOTBLK="lo-hi"` (`runner/src/cpu_trace.c:1233-1250`) prints one line per AOT
  block entry in a frame window — `[aotblk] f=1820 pc=$80C11F master=650717290`;
* `SNESRECOMP_CYC_WATCH="lo-hi"` (`runner/src/snes/interp_bridge.c:2763-2788`) prints one line
  per interpreted opcode in a PC range, with its cycle decomposition.

`tests/seam_phase.py` reads those logs on the two trace builds and prints the verdict. It runs
no leg and no build; the logs go to scratch under `tests/out/r5seam/` (that dir is
cleared between rounds, so the block below creates it) and the committed text is
`evidence/artifacts/round5_seam_phase.txt`:

```sh
. tests/rom.sh; rom=$(sr_rom); mkdir -p tests/out/r5seam
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

The CYC_WATCH legs write ~270 MB of stderr for the three ranges, so keep them out of git. The
answer (report §8) is the first reading, at the onset: the 92 common AOT PCs are identical over
all 1,610 block entries in `f1820-1834`, and the seeded cluster first moves at `f1832` (2
entries) and `f1833` (8 entries) — the frame the park probe already reports `−144` with DP
identical, two frames before the sampled split at `f1834`. Only the `−149` at `f1830` survives
an identical block set, which is a sub-block charge the block log cannot resolve.

### 7.13 Attributing a gate divergence to compiled bodies (2026-11-08)

Round 5 left one open attribution: six seeds shared the `frame_001828` gate onset, so
the failure was a property of the compiled cluster, not of one seed. Round 6 answers it
body by body on `pair + $80C1C9` against `pair` (`evidence/m2_promotion_round6.md`).
Three tools, all reading generated manifests rather than hand-typed lists:

* `tests/cluster_hunt.sh <label> <force-file>` — one leg. It rebuilds the candidate
  seed table with `tests/gap_seeds.py --baseline-only` plus `--only
  '$80C399,$80AAB3,$80C1C9'`, splices `force_lle <pc24>` lines into a marked block at
  the end of `recomp/bank80.cfg` and `recomp/bank81.cfg`, regenerates at the pin,
  rebuilds `build-r6hunt`, and runs `tests/parity.sh` against `build-r6pair` on
  `tests/out/probe_dense.txt`. It records both the label-inclusive `crc32_wram`
  verdict and `framedump_diff.py state` (label bytes excluded) — the state scan is the
  attribution metric. The live `symbols.toml` and bank cfgs are snapshotted and
  restored on exit.
* `tests/cluster_ddmin.py [--universe 52]` — the driver. It derives the 109 AOT
  bodies from the difference between the archived pair and candidate manifests,
  checks that demoting all of them is clean and demoting none is dirty, then removes
  chunks until the clean set is 1-minimal. The recorded run starts from the first 52
  bodies in PC order (already clean) and leaves `$80AD9F,$80C530`.
* `tests/cluster_hunt_report.py` — the artifact generator. Files-only: it runs no
  route leg, no regen and no cmake. It reads `tests/out/r6/hunt.tsv`, the per-leg
  sidecars, the two archived manifests and the run reports, and writes
  `evidence/artifacts/round6_cluster_hunt.txt`.

```sh
. tests/rom.sh
SNESRECOMP_ROOT=/path/to/pin ./tests/seed_variant.sh r6pair  --only '$80C399,$80AAB3'
SNESRECOMP_ROOT=/path/to/pin ./tests/seed_variant.sh r6pc1c9 --only '$80C399,$80AAB3,$80C1C9'
SNESRECOMP_ROOT=/path/to/pin python3 tests/cluster_ddmin.py --universe 52
SNESRECOMP_ROOT=/path/to/pin python3 tests/cluster_hunt_report.py \
    > evidence/artifacts/round6_cluster_hunt.txt
```

`tests/out/r6/hunt.tsv` (label, body count, executable, crc verdict, state verdict)
and `tests/out/r6/forces_*.txt` are scratch and stay out of git; the manifests and run
reports they come from were archived under `tests/out/r4/` and `tests/out/r6/`, of which
only the `r6/` set is still on disk (see the note at the top of this file). Two
things to know when reading a leg: `tests/parity.sh` always writes its dumps to
`tests/out/run1` and `tests/out/run2` (not under `tests/out/r6/`), and the frame counts
are not monotone in the demotion set — 305 frames with both bodies compiled, 1,409
with one demoted, 2,485 with the other, 0 with both — because `$80C530` reads the PPU
counter latches `$2137`/`$213C`/`$213D`, so the result depends on when the read runs.

The writer leg reuses `tests/latch_writer.py` on trace builds of the two programs. The
trace trees are built from the generated sets the two `seed_variant.sh` runs archived:
extract `evidence/artifacts/round6_gen_r6pair.tar.gz` / `round6_gen_r6pc1c9.tar.gz`
into `src/gen` (both sets are committed here, because the `tests/out/r4/` scratch that
held the working copies is cleared; `diff -r` says the pair set unpacks to exactly the
live `src/gen`, and so does the already-committed `round5_gen_r5pair.tar.gz`),
configure with `-DSNESRECOMP_ENABLE_TRACE=ON`, build `build-r6tr-ctrl` /
`build-r6tr-seed`, then restore the live set with `tools/regen.sh`. The stock pc pass
arms 400 frames before the split; when the ring fills before the split (as the DP
`$00`/`$01` slice does here) `--pc-arm 1828` arms closer. The raw output is
`tests/out/r6/gate_writer_r6.txt` and the report's §8 reads it files-only. It names
`bank_80_C530_M0X0` writing `$0001=82` at `f1832`, against the interpreter's `08` at
`$80C54D` in the control.

### 7.14 Pricing the counter read on the AOT tier (2026-11-08)

Round 6 §9 proposed the next lever as tier pricing at `$80C530`'s `LDA $2137`: make the
compiled path charge the same cycles before the read so the counter latches the same
phase. Round 7 measures that instead of assuming it (`evidence/m2_promotion_round7.md`).
The probe is a clone of the pin `773285b8` (never the pin itself) with an env-gated
diff, committed as `evidence/artifacts/round7_probe.diff`:

* `SNESRECOMP_PHASETAP=1` — logs every real function entry into `$80C530` with the
  cumulative `master_cycles` and an invocation counter. It is routed through the
  trace-off `cpu_trace_func_entry` inline, so it sees entries, not interior blocks. A
  first attempt hooked `WatchdogCheck`, which fires on every block of the function and
  therefore reported interior blocks as entries; that version is not in the patch.
* `SNESRECOMP_LATCHLOG=1` (+ `SNESRECOMP_LATCHLOG_FRAMES=lo-hi`) — logs the `$2137`
  read with `master`, the interpreter's uncommitted `pending` master, the resulting
  `sync`, and the latched `H`/`V`.
* `SNESRECOMP_LATCH_SYNC=1` — the candidate fix: advance the interpreted read by its
  pending master so both tiers sample at the same point. Default off (pin behaviour).

The two legs use the archived round-6 gen sets, each build anchored to its own:

```sh
git clone --shared -q "$PIN" ../sr-r7-latch
git -C ../sr-r7-latch checkout -q 773285b8210f2254ae87d0a14113980fb36990ad
git -C ../sr-r7-latch apply evidence/artifacts/round7_probe.diff

rm -rf src/gen && tar xzf evidence/artifacts/round6_gen_r6pair.tar.gz -C src
cmake -S . -B build-r7l-ctrl -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r7-latch"
cmake --build build-r7l-ctrl -j8
rm -rf src/gen && tar xzf evidence/artifacts/round6_gen_r6pc1c9.tar.gz -C src
cmake -S . -B build-r7l-seed -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r7-latch"
cmake --build build-r7l-seed -j8

. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_PHASETAP=1 SNESRECOMP_LATCHLOG=1 \
  SNESRECOMP_LATCHLOG_FRAMES=1830-1836 \
    build-r7l-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r7/inv_$leg.err
done
```

The build order matters in a way that is easy to get wrong: a rebuild re-reads whatever
`src/gen` currently holds, so building the control after extracting the seed set
silently links the seed's 33 units into it and the control prints `tier=aot` for a body
it is supposed to interpret. Extract that leg's gen, configure, build, then leave the
tree alone. The live set is restored with `tools/regen.sh` afterwards.

The gate is the usual pair, with the same binaries:

```sh
PORT_BIN=build-r7l-ctrl/ShadowrunSNESRecomp \
PORT_BIN2=build-r7l-seed/ShadowrunSNESRecomp \
  ./tests/parity.sh tests/out/probe_dense.txt > tests/out/r7/gate_base.parity.log 2>&1
python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 \
  > tests/out/r7/gate_base.txt
SNESRECOMP_LATCH_SYNC=1 PORT_BIN=build-r7l-ctrl/ShadowrunSNESRecomp \
PORT_BIN2=build-r7l-seed/ShadowrunSNESRecomp \
  ./tests/parity.sh tests/out/probe_dense.txt > tests/out/r7/gate_sync.parity.log 2>&1
python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 \
  > tests/out/r7/gate_sync.txt
```

`tests/latch_phase_report.py` is the artifact generator. It is files-only — no route
leg, no regen, no cmake — and reads `tests/out/r7/{inv_ctrl,inv_seed}.err`,
`tests/out/r7/gate_{base,sync}.txt`, the two `.parity.log` files (for the executable
identity and `crc32_wram` verdict) and `evidence/artifacts/round7_probe.diff`, writing
`evidence/artifacts/round7_latch_phase.txt`.

What it records: the in-body charge is constant and tier-dependent — the latch is 64
master clocks after entry interpreted, 88 compiled — and the 24 is exactly the `LDA`'s
four transfers at six clocks. `d_latch == d_entry + 24` and `d_h == d_latch / 4` on
every row, so the latched value is a direct function of the sample time. The entry
clocks themselves differ by up to 56 master clocks, which is why removing the 24-clock
term cannot fix the gate. `SNESRECOMP_LATCH_SYNC=1` is rejected (305 → 1,333 differing
frames, 895 → 3,031 bytes, first state diff unchanged at `f1830`). `tests/out/r7/` is
scratch and stays out of git.

### 7.15 Locating the pre-read phase across the seam (2026-11-08)

Round 7 ended by asking the next round to measure the *entry* phase rather than the
read. This round adds three anchors to the same probe clone and compares them on the
same two builds (`evidence/m2_promotion_round8.md`):

* `SNESRECOMP_FRAMETAP=lo-hi` — `[frame]` with `master_cycles` and `cycles` at the
  moment the frame counter advances.
* `SNESRECOMP_ENTRYTAP=lo-hi` — `[entry]` at every compiled-function entry, in
  execution order, with the cumulative master clock.
* `SNESRECOMP_ANCHORTAP=a,b,c` (hex pc24) — `[anchor]` at exact guest PCs on either
  tier, so a PC the legs reach compiled on one side and interpreted on the other is
  still a comparable sample point.

The anchors are `$00C0E2` (NMI handler), `$80C530`, and `$80ABBC` (top of the loop in
`$80AD9F`). The NMI handler is the useful one because `run_interrupt` always calls
`interp_bridge_run_interrupt`: it is interpreted on both tiers, so its entry is the
one per-frame sample taken the same way on both sides, and it equals the `[frame]`
value exactly. Both entry taps fire after the previous opcode's full charge is
committed, so `d=0` means the same beam position.

```sh
git clone --shared -q "$PIN" ../sr-r8-phase
git -C ../sr-r8-phase checkout -q 773285b8210f2254ae87d0a14113980fb36990ad
git -C ../sr-r8-phase apply evidence/artifacts/round8_probe.diff

rm -rf src/gen && tar xzf evidence/artifacts/round6_gen_r6pair.tar.gz -C src
cmake -S . -B build-r8-ctrl -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r8-phase"
cmake --build build-r8-ctrl -j8
rm -rf src/gen && tar xzf evidence/artifacts/round6_gen_r6pc1c9.tar.gz -C src
cmake -S . -B build-r8-seed -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r8-phase"
cmake --build build-r8-seed -j8

. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_FRAMETAP=1826-1840 SNESRECOMP_ENTRYTAP=1828-1836 \
  SNESRECOMP_ANCHORTAP=00C0E2,80C530,80ABBC \
    build-r8-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r8/final_$leg.err
done
```

`tests/phase_anchor_report.py` is the artifact generator. Files-only — no route leg,
no regen, no cmake — it reads `tests/out/r8/{final_ctrl,final_seed}.err`,
`tests/out/r8/gate.txt`, `tests/out/r8/gate.parity.log` and
`evidence/artifacts/round8_probe.diff`, and writes
`evidence/artifacts/round8_phase_anchor.txt`.

What it records: the frame edge (`$00C0E2` entry) is in phase on f1833/f1835/f1836
and tens of clocks off on f1832/f1834; inside f1835 46 of 51 shared entries have
`d=0`, and the others are ±40 charges that cancel at the next entry; the `$80AD9F`
loop costs 10,174 master clocks on both tiers on three of five frames; the `$80C530`
entry offset is 0 on two of five frames; and `cpu->cycles` is the counter that
accumulates the drift (−144 to −1,624). With all three tap variables unset the same
binaries reproduce the round-7 gate exactly (f1830, 305 of 4575, 895 bytes, crc
f1828), so the instrumentation is inert. Two build traps to keep in mind: a rebuild
re-reads whatever `src/gen` holds, and `SNESRECOMP_ANCHORTAP` must not treat a
leading zero digit as "off" — `00C0E2` is a valid address, and the first probe build
silently discarded the whole list because of that convention.

### 7.16 Bisecting the f1832 opening with a block and `$4212` tap (2026-11-08)

Round 8 left a `-66` step between `$80C11F` and the first `$80C399` entry. This
round adds two hooks to the same probe clone (`evidence/m2_promotion_round9.md`):

* `SNESRECOMP_BLOCKTAP=lo-hi` / `SNESRECOMP_BLOCKTAP_PC=lo-hi` — `[block]` at
  every AOT basic-block entry and every interpreted opcode start, filtered by
  frame and pc24 range, with the cumulative master clock.
* `SNESRECOMP_JOYTAP=lo-hi` — `[joy]` at every `$4212` read, with the beam
  clock, the remaining auto-joypad busy timer, the beam position, and the byte.

Both legs run the `$809D8E` loop on the interpreter, so its pass cost is a
direct comparison. The ledger shows `d` cycling through the cancelling ±40
call-boundary term and arriving at `$809D8E` at the frame edge's `+14`.
Control then takes five reads of `$4212` and the seed four, at 66 master per
pass. The joy tap makes the cause direct: while busy, `beam+timer` is the same
`655009300` on both legs; control's fourth read is 6 clocks before that edge,
the seed's is 8 after, so the 14-clock phase straddles it. Only f1832 flips in
f1829–f1836; f1830 reads `$4212` 24 times on both legs, the other frames once.

```sh
git clone --shared -q "$PIN" ../sr-r9-blocks
git -C ../sr-r9-blocks checkout -q 773285b8210f2254ae87d0a14113980fb36990ad
git -C ../sr-r9-blocks apply evidence/artifacts/round9_probe.diff

rm -rf src/gen && tar xzf evidence/artifacts/round6_gen_r6pair.tar.gz -C src
cmake -S . -B build-r9-ctrl -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r9-blocks"
cmake --build build-r9-ctrl -j8
rm -rf src/gen && tar xzf evidence/artifacts/round6_gen_r6pc1c9.tar.gz -C src
cmake -S . -B build-r9-seed -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$PWD/../sr-r9-blocks"
cmake --build build-r9-seed -j8

. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_BLOCKTAP=1832-1832 SNESRECOMP_BLOCKTAP_PC=809000-81FFFF \
    build-r9-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r9/blocks3_$leg.err
  SNESRECOMP_JOYTAP=1828-1836 SNESRECOMP_BLOCKTAP=1832-1832 \
  SNESRECOMP_BLOCKTAP_PC=809000-81FFFF SNESRECOMP_FRAMETAP=1827-1836 \
  SNESRECOMP_ANCHORTAP=00C0E2,80C530 \
    build-r9-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null 2>tests/out/r9/final2_$leg.err
done
```

`tests/round9_opening_report.py` is the artefact generator. Files-only — no
route leg, no regen, no cmake — it reads `tests/out/r9/{blocks3_ctrl,
blocks3_seed,final2_ctrl,final2_seed}.err`, `tests/out/r9/gate.txt`,
`tests/out/r9/gate.parity.log` and `evidence/artifacts/round9_probe.diff`, and
writes `evidence/artifacts/round9_opening.txt`. With all four tap variables
unset the same binaries reproduce the round-7/round-8 gate exactly (f1830, 305
of 4575, 895 bytes, crc f1828), so the instrumentation is inert.

### 7.17 The frame-edge phase over the whole route (2026-11-08)

Round 9 traced the divergence to a `+14` offset of the frame edge. That number
had only ever been measured across ten frames, so this round measures it
everywhere, with **no new instrumentation and no rebuild** — the round-9 probe
executables are run again with their frame tap open from f1 to f4,600
(`evidence/m2_promotion_round10.md`).

```sh
. tests/rom.sh; rom=$(sr_rom)
for leg in ctrl seed; do
  SNESRECOMP_FRAMETAP=1-4600 \
    build-r9-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
      --script tests/out/probe_dense.txt >/dev/null \
      2>tests/out/r9/frames_$leg.err
done
python3 tests/round10_frame_phase_report.py \
  > evidence/artifacts/round10_frame_edge_phase.txt
```

Two things to know before spending a leg on this:

* the tap's on-test is `e[0] && e[0] != '0'`, so `SNESRECOMP_FRAMETAP=0-4600`
  prints **nothing**. The range must start at `1`.
* the probe clone is deleted **and** the `build-r9-*` trees were cleared with the
  other scratch trees on 2026-11-09 (`evidence/artifacts/build_trees_cleared_2026-11-09.md`),
  so those legs can be neither run nor rebuilt from what is on disk.
  `evidence/artifacts/round9_probe.diff` (§7.16) is what recreates the tree, and
  the `cmake -S . -B build-r9-…` lines printed above in this section are what
  filled it.

What the route says: the seed-minus-control offset of the achieved frame
boundary is `0` on 4,095 of 4,574 boundaries, never leaves `−58…+70`, appears in
`241` separate runs with longest `16`, and both legs cover exactly
`1,634,601,236` master clocks end to end. Frame lengths have mode exactly
`357,368` on both legs and identical means (`357,446.15`); the three route
pauses (f194/195, f475/476, f1316/1317) are identical to the clock. The counter
that *does* drift is `cpu->cycles` (`−2,609…+141`, ends `−1,309`, zero on only
`1,766` frames). The phase split starts at f1767, `63` frames before the first
differing state byte at f1830. In the onset window the boundary offset equals
the NMI entry offset on `12` of `12` frames, which is the cross-check that the
tap sits on the edge and not somewhere else.

`tests/round10_frame_phase_report.py` is the artefact generator. Files-only — no
route leg, no regen, no cmake — it reads `tests/out/r9/{frames_ctrl,
frames_seed}.err` plus the round-9 `final2_*`, `gate.txt` and
`gate.parity.log`, and writes `evidence/artifacts/round10_frame_edge_phase.txt`;
two runs are byte-identical. The anchor entry-count column needs care: the AOT
hook only fires where a compiled function's own entry pc is the anchor, so
counts are tap-site counts and are not comparable between tiers — the offset
columns are.

### 7.18 The staged bundle, restaged from the accepted tree (2026-11-08)

c1 (consequence 4 of `evidence/c1_staged_bundle_stale.md`) left one item open as
an owner decision: re-stage `./Shadowrun` from the current tree, or keep it as a
dated artefact. The tree has now been re-staged and the decision is recorded
here rather than left open. The superseded bundle is kept at
`tests/out/Shadowrun_prev_ebca100c` (`ebca100c3a01201a`, 5,941,232 B,
2026-11-05) — c1's four-branch comparison and its transcript still need it.

The replacement is `60067549c3ee8d3b`, 3,103,872 B, and it is the accepted
executable: `build-ship` was configured from nothing but the two documented
flags and the pin, built, and produced `a0587ed0a0e34687` — byte-identical to
the round-5 executable the accepted tree was verified against (§7.6). A second
scratch configure, `tests/out/bundle/freshbuild`, produced the same hash again
with 18/18 generated units compiled, so the accepted bytes come out of the
sources plus the pin and are not an accident of one build directory.

```sh
SNESRECOMP_ROOT=/path/to/pin SHIP=build-ship \
  PORT_BIN2=tests/out/Shadowrun_prev_ebca100c bash tests/bundle_verify.sh
# log: tests/out/bundle/bundle_verify.log
#      = evidence/artifacts/bundle_verify.md
```

Six sections, and the two that matter are frame state:

| leg | frames (parity route) | result |
|---|---|---|
| staged bundle vs `build-ship` | 1,200 | **identical** |
| staged bundle vs previous bundle | 1,200 | **1,174 differ**, first at frame 1 (`0xA5618AC7` vs `0x609BDB9F`) |

`tests/out/bundle/bundle_verify.md` numbers are that second row's shape: f0
agrees (the machine before either program has run a single instruction), f1
disagrees, and the 26 frames that do agree afterwards are `0, 8-9, 12, 14-15,
23-26` and `480-495` — scattered, not a prefix, and with a 16-frame agreement
window in the middle of a route that otherwise disagrees every frame. That is
the shape of two unrelated programs colliding occasionally, and exactly the
frame-1 break c1 reported. Boot is separately fine: `exit=0`, `$7E1C92`
advancing, `fps=58.9`.

Why the staged hash differs from the build-tree hash, and why that is not a
second program: the build-tree binary is 96 B smaller, and the difference is
`install_name_tool -change /opt/homebrew/.../libSDL3.0.dylib
@executable_path/libs/libSDL3.0.dylib` plus the re-sign that §8.2's recipe
prescribes — dylib install-name bytes and a Mach-O signature, nothing in the
code. Section 4's identical frame state is what says so; the bundle alone
cannot say it, because no `CMakeCache.txt` sits beside it and
`tests/provenance.py` deliberately reports that as `unknown`. Sections 1–2 are
what replace the unknown: gen set `3f22138eb5d1`, 18 units, 215 promoted
functions, 263 dispatch entries, pin `773285b8210f`, `AT THE PIN`.

One reading trap in that log: the `"dirty": true` line inside a leg's manifest
is provenance.py's **port_git** section — the port repository, dirty at run
time because `tests/bundle_verify.sh` was untracked while it ran. The framework
line above it reads `dirty=False` / `AT THE PIN`, which is the condition a leg
has to meet.

`tests/bundle_verify.sh` is what c1's third consequence asked for — a
comparison that names a build tree instead of `./Shadowrun` — and it re-runs
all three dumps itself rather than trusting an earlier pair. Every leg runs
from an anchor, a copy of the executable in its own directory with the `libs`
symlink and the save snapshot, never in a build dir (whose
`last_run_report.json` is the join target for §7's parity table) and never from
the repo root, which is what `./Shadowrun` itself anchors to: a leg run there
rewrites the bundle's own `config.ini` and save state.

Frame dumps are the ones `tests/parity.sh` uses, `tests/out/run1|2|3`, so
whichever binary was last compared is overwritten. The log carries a generation
timestamp and cannot be re-produced byte for byte; it is a dated measurement,
labelled as such in its own header, and the script that made it is committed.

Note for anyone packaging a release rather than a local run:
`scripts/package_release.sh` ships a setup host and never ships `src/gen`,
`recomp/funcs.h` or a ROM, so it is unaffected by what `./Shadowrun` is. The
staged bundle is the local-run artefact only.

### 7.19 The click-and-install macOS package (2026-11-08, rebuilt at a macOS 11 floor on 2026-11-09)

Everything above stages `./Shadowrun` for a terminal. A person who wants to
double-click the port needs a `.app` inside a `.dmg`, and
`scripts/package_macos_bundle.sh` builds that and measures it:

```sh
scripts/package_macos_bundle.sh build-ship-m11 macos-arm64
# dist/Shadowrun.app, dist/shadowrun-0.1.0-macos-arm64.dmg
# log: tests/out/pkg/macos_package.log
#      = evidence/artifacts/macos_package.md
# VERIFY=0 assembles without the run legs; PKG_INSTALL_DIR moves leg e's copy
```

The build tree is named on the command line rather than assumed, and §0 of the
log prints what that tree is: `build-ship-m11`, executable `092b0e690cab97a1`
(5,970,048 B, arm64, `minos 11.0 sdk 26.5`), `CMAKE_BUILD_TYPE:STRING=Release`,
`SHADOWRUN_EMBED_ROM:BOOL=OFF`, `SNESRECOMP_ENABLE_MODS:BOOL=ON`, and SDL3
fetched and linked **statically** — the log reads that off the Mach-O, not off
the cache flags: "the executable references no SDL3 dylib at all, so SDL3 is
linked in statically and no dylib is vendored". §7.22 is where that shape is
measured against the dylib-vendoring one, and why it is the only way to ship a
floor below 26.0 on this machine.

§0 also refuses to call that tree's framework the pin, printing both readings:

```
NOT THE PIN  build-ship-m11: …/sr-osx @ 32266300d722…, pin is 773285b8210f…
  re-asking as a descendant of the pin:
  OFF THE PIN  build-ship-m11: …/sr-osx @ 32266300d722…, with 773285b8210f as an ancestor -- a branch off the pin, fine for a capability leg
```

That one commit is what keeps the port's writable state out of the bundle, and
the frame leg below is what pays for it rather than provenance.

Ten sections, §0 through §9. What they establish, in the order the script earns it:

| claim | how it is measured | result |
|---|---|---|
| the installed executable is the measured executable | sha256 of the exe inside `.app`, then inside the mounted image, then inside the dragged copy of §5e | **`37d08a86a2a86414`, 5,953,488 B** in all three |
| so §7.18's frame proof transfers, and transfers out of the container too | §5a dumps frames from the packaged bytes and from `build-ship-m11`; §7 runs four legs to 1,200 frames on the kit's menu route and pairs them: the executable read off the read-only mount, `build-ship/ShadowrunSNESRecomp` (at the pin), `build-ship-m11/ShadowrunSNESRecomp` (this package's framework and floor) | both §5a pairs and §7's two pairs (`frames_file` vs `frames_refpin`, `frames_file` vs `frames_ref11`) read **`identical over 1245 frames`** / `no non-label WRAM byte differs in 1245 shared frames` |
| it also runs as an app, not just a binary | §5b scripted boot inside the `.app`, §5c `open` through LaunchServices, §5d the launcher page reading the cached `rom.cfg`, §5e a copy dragged out of the mount | §5b `exit=0 wall=5s`; §5c `open` exit 0, the process it started (`pid 67440`) ran 276 frames and exited by itself, drivers `video=cocoa audio=coreaudio`, `window created: 960x720`; §5e exit 0 from a CWD that is not this repository |
| no ROM, asked of both the container and the file that installs | §2's scans — ROM/patch-shaped files, `nm` for the embed symbols (`_snesrecomp_embedded_rom` / `_g_rom_embedded`), `rom.cfg`, `src/gen` + `recomp/funcs.h`, files naming this repository, files naming this machine's ROM directory, non-system load commands naming Homebrew, `LC_RPATH` entries, files naming `/opt/homebrew` — plus a byte scan of the Mach-O, and §8's four presence scans and carve-out against **two subjects**: the `.dmg` itself and `IMG_EXE`, the executable read off the read-only mount | **all §2 scans read 0**; the byte scan reads `not found: no 1048576-byte region of Shadowrun (5953488 B) matches the digest this build checks at boot` → `MATCH: expected absent, absent`; in §8 both subjects read False on the image bytes, the header string and the carve-out, and `carve-out: no offset -- the span is not in this file` for both |
| the dump's name in the executable is not the dump | §8 prints the printable strings either side of every filename hit | `filename at 0x47ca10`, and the neighbours are `['guard_hex', "missing glyph mapping for '", 'Shadowrun', 'Shadowrun (USA).sfc', 'e6bc0a595d5c7c4b…', '3f34dff0', 'shadowrun-usa', '0.1.0']` — the accepted-dump record, name next to digest, no byte span |
| the bundle is sealed, and stays sealed through a run | §1 `codesign --verify --strict` on the whole bundle, §5f the bundle's own file inventory and tree hash before and after every leg, then the seal asked again | `valid on disk / satisfies its Designated Requirement`; **11 files, tree hash `23e5c5aa4c72e5eb` before and after**; seal still valid |
| an installed copy is self-contained and takes nothing with it | §5e: `ditto` out of the mount into `mktemp` outside the repo, run with that as CWD, payload path lists taken before and after | writes **nothing inside itself**, **0 payload paths disappeared**, creates its state under `~/Library/Application Support/Shadowrun/`, **0 files touched in this repository** |
| it asks nothing of this machine | `otool -L` load names and `LC_RPATH` count on the packaged Mach-O (§5 of the log prints every load name) | 23 load names, **0 non-system, 0 `LC_RPATH`**, 0 files in the payload naming `/opt/homebrew` |
| what macOS will and will not do with it | §9 asks `codesign -dvvv`, `stapler validate`, `spctl -a -vv -t execute` and `xattr` of a scratch copy under `tests/out/pkg/gatekeeper/`, never of `dist/` | `Signature=adhoc`, `TeamIdentifier=not set`, `Sealed Resources version=2 rules=13 files=1`, `does not have a ticket stapled to it`; `rejected` **`[exit=3]`** before and after `com.apple.quarantine` is set; that flag leaves the seal `valid on disk` `[exit=0]`; `com.apple.FinderInfo` on the executable gives `resource fork, Finder information, or similar detritus not allowed` `[exit=1]`, and removing it returns `[exit=0]` |

**The "is damaged" report, and the one commit that fixes it.** The first version
of this section said a resource seal is impossible for this payload —
`codesign --force --sign -` refuses with `code object is not signed at all /
In subcomponent: …/Contents/MacOS/mods/preloaded/README.md` — and treated that
as a property of the port. It was a property of where the host kept its state:
`runner/src/host_paths.c` anchored `config.ini`, `keybinds.ini`, `rom.cfg`,
`saves/` and `mods/` to the executable's own directory, so inside a `.app` those
files landed in `Contents/MacOS/`, where codesign treats everything it finds as
code. §7.21 measures both layouts on one machine. The pinned host's bundle
cannot be sealed at all, and its seal check answers `code has no resources but
signature indicates they must be present` — the assessment macOS renders to a
person as "*Shadowrun* is damaged and can't be opened"; the same bundle with the
state taken outside seals, validates, and comes through a run byte-identical.
§7.21 leg E is the half that lets this package keep inheriting every measurement
made against the pinned executable: over `tests/scripts/parity.txt` the two
hosts are `identical over 1200 frames`, "no non-label WRAM byte differs".

The packager keeps that property under test instead of trusting the framework. §1
puts a copy of the finished bundle through four states and prints codesign's own
words, not the script's summary of them:

1. the copy as shipped → `valid on disk` / `satisfies its Designated Requirement`, exit 0;
2. the same copy with `Contents/_CodeSignature` removed — which is what a bundle that was never sealed looks like to a Mac that expects one → `invalid resource directory (directory or signature have been modified)`, exit 1;
3. that bundle laid out the way the pinned framework lays a bundle out (`rom.cfg`, `keybinds.ini` and the launcher's mod catalog beside the executable), asked to be sealed at all → `code object is not signed at all / In subcomponent: …/Contents/MacOS/mods/preloaded/state.toml`, exit 1;
4. the state taken back out and the same seal put on again → exit 0, then `valid on disk` / `satisfies its Designated Requirement`.

"so a bundle whose executable directory stays free of writable state seals, and a
bundle laid out the way the pinned framework lays one out does not."

§2 generates the counter-case rather than describing it (`tests/out/pkg/seal_attempt/`),
and prints its seal check beside `spctl`'s verdict on the real package:

```
exec:    …/dist/Shadowrun.app: rejected
install: …/dist/Shadowrun.app: rejected
```

Rejected, and a sealed bundle does not change that. §9 is where that is measured
rather than asserted, because three different things can make a Mac refuse a
bundle and only two of them are fixable here. It works on a scratch copy under
`tests/out/pkg/gatekeeper/` — never on `dist/`, whose bytes §4 hashed — and takes
eight lines:

| line | what it asks | what the log gets back |
|---|---|---|
| 1 | what kind of signature this package can make | `Signature=adhoc`, `TeamIdentifier=not set`, `Sealed Resources version=2 rules=13 files=1`, `CodeDirectory v=20400 size=11802 flags=0x2(adhoc) hashes=362+3`, and `Shadowrun.app does not have a ticket stapled to it.` |
| 2 | Gatekeeper's assessment of a copy this machine itself built | `rejected` `[exit=3]` |
| 3 | the same assessment with `com.apple.quarantine` set, the state of a downloaded copy | `rejected` `[exit=3]` — the same answer |
| 4 | the strict seal check with that flag on | `valid on disk` / `satisfies its Designated Requirement` `[exit=0]` |
| 5 | what attached data the shipped executable carries | nothing |
| 6 | the strict seal check after adding `com.apple.FinderInfo` to the executable | `resource fork, Finder information, or similar detritus not allowed`, `file with invalid attached data: Disallowed xattr com.apple.FinderInfo found on …`, `[exit=1]` |
| 7 | and again with it removed | `valid on disk` / `satisfies its Designated Requirement` `[exit=0]` |
| 8 | the third refusal mode, cross-referenced rather than repeated | §1's third seal state: the pinned framework's layout cannot be sealed at all |

So the three ways this bundle can read as damaged are separated by measurement:
the unsealable payload — the shape every earlier round shipped — is gone, and §5
shows the shipped bundle still validating after being copied, mounted, dragged and
run with nothing written inside it; attached Finder metadata is not created by
anything in this build and the drag does not add any, and line 6 exists to show
what would; and the missing developer identity is **not** removed and cannot be,
because line 2 refuses the bundle before any download flag is involved. That last
one is why `README.txt` at the image root tells a person to right-click and choose
Open, or to run `xattr -dr com.apple.quarantine
/Applications/Shadowrun.app`: it is the documented way past a verdict that is
correct about what this build is. A `.dmg` built here carries no quarantine flag,
because nothing downloaded it, and the log records that a Developer ID signature
plus a notarisation ticket — the only thing that would change line 2 — is outside
what this script can do rather than pretending otherwise.

**The frames come out of the container, not out of the build directory.** §7
re-attaches the finished `.dmg` and runs the kit's 1,200-frame menu route against
subjects read straight off the read-only mount (`/Volumes/Shadowrun`), not from
`dist/` and not from a copy made for the run:

| subject | what it is | hash | build record, from its own load commands |
|---|---|---|---|
| a | the executable inside the image, `--rom` naming the dump | `37d08a86a2a86414` 5,953,488 B | `minos 11.0, sdk 26.5`, `no SDL dylib load command -- SDL3 is inside this Mach-O` |
| c | `build-ship/ShadowrunSNESRecomp`, the tree this kit has treated as correct since the re-baselining round | `a0587ed0a0e34687` 3,103,776 B | `minos 26.0, sdk 26.5`, `/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib` |
| d | `build-ship-m11/ShadowrunSNESRecomp`, the tree this package was packaged from | `092b0e690cab97a1` 5,970,048 B | `minos 11.0, sdk 26.5`, no SDL dylib load command |

c is in this set on purpose, and it is the row a reader is most likely to
misread: that tree is the *unpacked* `./Shadowrun` shape — one executable in a
plain directory, its floor 26.0 because it loads Homebrew's `libSDL3.0.dylib` —
and `3,103,776 B` is its build-tree size, not the `3,103,872 B` of the staged
file §7.18 measures. Those two are the same program on either side of the
install-name edit and re-sign: `tests/bundle_verify.sh` prints the two sizes side
by side, and `evidence/README.md` §c1 attributes the 96 B between them to
`install_name_tool`'s dylib install-name edit plus the re-sign. The point of putting it next to a and d is that the frame
comparison below crosses the widest gap available here — a 26.0-floor dylib build
at the pin against an 11.0-floor static build off the pin, running as a sealed
bundle off a read-only mount — and still finds the machine agree.

c's framework reads `AT THE PIN   build-ship: …/sr-pin @ 773285b8210f…` and d's
reads `OFF THE PIN  build-ship-m11: …/sr-osx @ 32266300d722…, with 773285b8210f
as an ancestor` — printed in the log by the same call §0 uses, so the distance
between the pair is visible rather than asserted. All three legs exit 0 with
**1245 WRAM dumps**, and both pairings — `frames_file` vs `frames_refpin`, which
spans framework, floor and SDL3 linkage, and `frames_file` vs `frames_ref11`,
which holds framework and floor constant so that what is left is which copy of the
program ran and from where — read `identical over 1245 frames` and `no non-label
WRAM byte differs in 1245 shared frames`. The embedded-ROM leg is reported as
skipped, with its reason, because this payload has no embedded guest to exercise.
That is the leg a person who downloaded the `.dmg` would ask for: it runs the
bytes as the container holds them.

**Is a payload hash a legitimate identity, or a one-off?** §1 re-seals two copies
of the finished bundle with its own `codesign` command line:

```
copy A, re-sealed unchanged    37d08a86a2a86414
copy B, BUILD_INFO.txt +1 line fcdb7f720227d859
the bundle this run shipped    37d08a86a2a86414
```

A reproduces the shipped payload byte for byte, so the seal is deterministic and
a payload hash is a fair identity for a build. B moves it, because a seal over a
bundle hashes the bundle's resources into the executable's own CodeDirectory
(`hashes=362+3` — the `+3` being the bundle's `CodeResources`, its `Info.plist`
and its requirements). **The payload's hash therefore pins the whole bundle,
`BUILD_INFO.txt` included, not just the Mach-O inside it.** The container is the
other way round: this run's image is `fe2648738fad58a6` (2,221,175 B, `hdiutil
verify` VALID, German output — the host's locale is part of the measurement) and
a second image from the same stage directory is `4ae623649621de47`
(2,221,175 B). `hdiutil` stamps volume dates and UUIDs, so a `.dmg` hash
identifies a run and a payload hash identifies the build. That distinction is
what made it safe to re-run this round at all: the payload hashes hold, only the
container moved.

**§8 asks the ROM question of two subjects, twice over each.** The two subjects are
the `.dmg` itself — the one file a person downloads and sends to someone — and the
executable inside it, read off the read-only mount, which is the file that actually
lands on their disk. Each gets four presence scans (the image's first 256 bytes,
its filename, its SNES header string, its digest as hex text) and then the
carve-out, which is stronger than a scan: find the first 256 bytes, take
`len(image)` bytes at that offset, and compare that span against the ROM file byte
for byte and by hash. For this variant the container reads False on all four scans,
the executable reads False on the first-256 scan and the header string but **True on
the filename and on the digest as hex text**, and the carve-out prints
`carve-out: no offset -- the span is not in this file` for both. That pair of True
lines is the accepted-dump record, not the dump: the build carries the name of the
file it will take from the player and that file's hash, and it carries neither its
bytes nor its header string. The filename appears once, and the log prints the
printable strings either side of it rather than leaving the reader to guess what
"present" meant:

```
  exe in image  5953488 B
      ROM first 256 bytes present:  False
      ROM filename present:         True
      SNES header string present:   False
      ROM sha256 as hex text:       True
        filename at 0x47ca10, and the printable strings around it are:
          ['guard_hex', "missing glyph mapping for '", 'Shadowrun', 'Shadowrun (USA).sfc', 'e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4', '3f34dff0', 'shadowrun-usa', '0.1.0']
      carve-out: no offset -- the span is not in this file
```

The same distinction is what the log draws for the container: `The image's bytes are
absent from both subjects and the carve-out finds no offset in either, so neither the
file a person downloads nor the file that lands on their disk holds the game.`

That is the accepted-dump record — the name sitting next to this dump's own sha256,
which is what a build needs in order to say which file it will take from the
player. **A name and a digest are not the same finding as bytes.** The section also
says why the container scan alone would be a bad witness: `-format UDZO` is zlib,
so a compressed container need not hold any span of its payload verbatim, and a
personal image whose payload *does* carry the guest can still read absent at the
container level. Container-level absence is a report; the load-bearing absence is
the payload's. The scan output is tee'd to `tests/out/pkg/rom_scan.txt`
(`rom_scan_personal.txt`) so a later sentence that quotes one of these offsets can
be checked against a file.

**§3 measures the tree-vs-shipped difference instead of asserting it.** §7.6 and
§7.18 both reported the build-tree binary as 96 B smaller and put that difference
down to the dylib install-name rewrite plus the re-sign, nothing in the code, on
the strength of what the recipe does rather than what the bytes are. The packager
reads `LC_CODE_SIGNATURE` out of both files and runs `cmp` over exactly the part
before the blob:

```
  packaged                 37d08a86a2a86414  5953488 B
  build tree build-ship-m11/ShadowrunSNESRecomp 092b0e690cab97a1  5970048 B
  signature in the tree    CodeDirectory v=20400 size=46412 flags=0x20002(adhoc,linker-signed) hashes=1447+0
  signature when packaged  CodeDirectory v=20400 size=11802 flags=0x2(adhoc) hashes=362+3
  LC_CODE_SIGNATURE, tree  dataoff 5923616, 46432 B
  LC_CODE_SIGNATURE, packaged dataoff 5923616, 29872 B
  …
  Compared up to that offset: 5 byte(s) of 5923616 differ, first at byte
  3074, last at 5550.
```

The blob starts at the same byte in both, so everything before it is the same
length in both, and the whole 16,560 B file difference is the signature blob —
the tree's is the larger, because `ld` scores 4 KiB pages across the whole binary
(`hashes=1447+0`) while `codesign --force --sign -` scores 16 KiB pages on an
executable this large (`hashes=362+3`). The two blobs are not comparable byte for
byte, which is why §5a compares machine state rather than hashing these two
files. The load commands end at `32 + sizeofcmds(5520) = 5552`, so all five
differing bytes are inside the Mach-O header and its load commands and **code
and data are bit-identical** between the build tree and the shipped bytes. The
load commands moved 0 B, and that is the expected shape now: nothing is
rewritten here, because SDL3 is linked in, so the only packaging step on this
Mach-O is the ad-hoc sign.

**Four probes, because one was not enough.** The earlier version of this section
claimed a plain-directory sign reproduces the shipped payload hash. It does not,
and for this bundle it cannot: an ad-hoc sign of a plain file takes its
identifier from the **file name**, while the shipped payload is signed as part of
a bundle and takes its identifier from that bundle's `Info.plist`. §3 now runs
four scratch copies of `build-ship-m11/ShadowrunSNESRecomp`:

| probe | what it is given | hash |
|---|---|---|
| 1 | `codesign --force --sign -` in a plain directory | `949fc447043ca021`, 5,953,472 B, `Identifier=Shadowrun-5555…` — **no match** |
| 2 | the same bytes renamed `other-name`, same step | `f15ea5d43e511fe8`, `Identifier=other-name-5555…` — the name is inside an ad-hoc signature |
| 3 | signed while sitting in a scratch `Probe.app` | `54dd237e7b910c72`, `Identifier=org.example.signprobe`, `hashes=362+3` — the right *shape*, the wrong `Info.plist` |
| 4 | signed in a plain directory, then the whole `Shadowrun.app` sealed with **this bundle's** `Info.plist` | **`37d08a86a2a86414` — MATCH** |

So staging order alone was never the whole story. What reproduces the shipped
bytes is the tree's bytes, plus the sign, plus the whole-bundle seal made over
*this* bundle, and probe four is the only one of the four that gets there; probe
one is a real signature but not the final one, because the bundle seal signs over
it. A payload hash pins one named file built one way, not an abstract build —
which is also why the shareable and personal payload hashes can never meet. The
probe copies stay in `tests/out/pkg/sign_probe/` (personal:
`sign_probe_personal/`), git-ignored scratch every run deletes and rebuilds from
the tree.

`§5c` needed correcting, and the correction is worth more than the claim it
replaced. Its first version said LaunchServices gives the app "the real video and
audio drivers rather than the dummy ones the legs above export". It did not:
`open` relays the calling environment, so the app inherited
`SDL_VIDEODRIVER=dummy`, and its own breadcrumb recorded `SDL init ok:
video=dummy audio=dummy`. The leg now starts the app with `env -u
SDL_VIDEODRIVER -u SDL_AUDIODRIVER` (`CLICK_HEADLESS=1` opts out, and the log then
says it measured less) and reads the drivers out of the breadcrumb stream — the
report's own `sdl` block is no use for this, because the framework writes it after
`SDL_Quit()` (`runner/src/host_report.c:345`) so it reads `"(none)"` for every
run, dummy or real. The current transcript shows `SDL init ok: video=cocoa
audio=coreaudio` plus `window created: 960x720`, which is the claim the leg
always wanted to make. The same leg also learned to tell a hang from an absent
run, after it reported "the LaunchServices leg did not run" about a run it had not
observed (§7.20 lists that and the other results that were wrong in the direction
of a passing log).

Two bugs in the script's first version are worth recording because both made the
artifact *quietly wrong* rather than loudly wrong:

* The file-counting helper ran `tr -d '[:space:]' | wc -l`, which collapses
  every matched path into one line and therefore reports **0 for any number of
  matches** — every "expect 0" in §2 would have passed vacuously. It was caught
  only because the mod catalog is not empty and printed `0 file(s)`; a helper
  that cannot fail is not a test.
* Under `set -euo pipefail`, `grep` exiting 1 — which is the *pass* condition
  for "no ROM in the payload" — killed the script mid-section. Counting needs
  to absorb that exit (`n_of`), and the run legs need `|| rc=$?` so a nonzero
  exit is reported rather than fatal.

**The state, read from both sides of the line.** §5 runs every leg against a copy
of the bundle under `tests/out/pkg/app`, never `dist/`, with a private `$HOME`
under `tests/out/pkg`, and prints the anchor line the app itself reports:

```
[Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home/Library/Application Support/Shadowrun/' (bundle run: state kept outside the .app).
```

Then §5e drags the `.app` out of the mounted image into a `mktemp` directory that
is not this repository, runs it from there, and lists what that first launch
created — `config.ini`, `keybinds.ini`, `last_run_report.json`,
`mods/preloaded/{packages,state.toml}`, `rom.cfg`, `saves/save.srm` — all of it in
the state directory, **nothing written inside the installed bundle**, the bundle's
seal still valid afterwards, and 0 files touched in this checkout. §6 closes on
the trade: no installer and no privileged helper, the app lives anywhere it is
put, and its saves, settings and ROM choice live in `~/Library/Application
Support/Shadowrun/` — so replacing or re-downloading the app keeps them, and a
read-only copy (a mounted image, a translocated run) cannot make a save fail. The
shape this replaced had the other trade: moving the app moved its saves, and the
loose files inside `Contents/MacOS/` made the bundle impossible to seal, which is
the shape a downloaded copy of it would be refused for.

Figures from the 2026-11-08 round that no longer apply to this package, listed so
an old transcript cannot be quoted as current. Each one has a witness. `7f3cce8806caf7cc`
and `366aa2e1df5bfdd2` are the two framework payload hashes `evidence/README.md` §c1
records for signing the same executable inside a bundle versus outside it, and that
section's comparison rests on them. The vendored-dylib figures are in that round's
transcript, which is no longer in the working tree but is still in git history:
`git show 50c7405:evidence/artifacts/macos_package.md` prints
`libs/libSDL3.0.dylib         ffa90591388d57c3  2523936 B`, and the file at that
path today is the floor-11 transcript, which has no dylib in it at all.

| superseded | replaced by |
|---|---|
| payload `60067549c3ee8d3b` plus vendored dylib `ffa90591388d57c3` | `37d08a86a2a86414`, and no dylib at all |
| build-tree payloads `7f3cce8806caf7cc` / `366aa2e1df5bfdd2` | `092b0e690cab97a1` / `190c82eeeddca0db`, measured at the floor in §7.22 |
| 96 B smaller, 212 differing bytes, first at byte 21 | 16,560 B, 5 differing bytes, first at 3,074 |
| one thing deliberately left wrong: an `LC_RPATH` of `/opt/homebrew/lib` | 0 `LC_RPATH` entries, 0 payload files naming `/opt/homebrew` |
| a resource seal impossible for that payload | sealed, verified, and still verified after a run; the pinned layout is now the counter-case |
| staging probes that *matched* the shipped hash, two of them | the four probes above; only probe four matches, and the other three are printed with their hashes |
| floor: minos 26.0, because it linked Homebrew's SDL3 | minos 11.0 (§7.22 measures why the dylib shape could not get there) |

`./Shadowrun` at the repository root is still `60067549c3ee8d3b`, and that is
consistent rather than stale: it is §7.18's terminal-staged bundle, staged by the
`install_name_tool` + re-sign recipe in §8.2, not the package. What changed is that
the package no longer shares that shape.

`evidence/artifacts/macos_package.md` is the current log verbatim — same bytes as
`tests/out/pkg/macos_package.log`, including the German `hdiutil verify` output,
because the host's locale is part of the measurement.

### 7.20 The other picture: `PERSONAL=1`, a package that opens straight into the game (2026-11-09)

§7.19's package asks the player for a dump once. That is the price of the no-ROM
rule holding end to end, not a defect. The question it cannot answer is a
different one, and it is answerable in this repository: what does the same
packager produce when the ROM promise is replaced by an explicit, labelled
exception — and does any machine state change when the guest stops being a file
and becomes bytes in `__DATA`?

```sh
# the tree first, against a framework that can boot an embedded image -- the pin
# cannot, so SNESRECOMP_ROOT points at a descendant of it.  The exact line for the
# tree this package now ships is printed as it runs, in tests/out/m11_build.log:
#   cmake -S . -B build-embed-ship-m11 -DCMAKE_BUILD_TYPE=Release \
#         -DSNESRECOMP_ROOT=/path/to/sr-embed-osx -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
#         -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON \
#         -DFETCHCONTENT_SOURCE_DIR_SDL3=/path/to/SDL3-3.4.10 \
#         -DSNESRECOMP_ENABLE_MODS=ON -DSHADOWRUN_EMBED_ROM=ON
PERSONAL=1 scripts/package_macos_bundle.sh build-embed-ship-m11 macos-arm64
# dist/Shadowrun-personal.app
# dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg
# log: tests/out/pkg/macos_package_personal.log
#      = evidence/artifacts/macos_package_personal.md
# VERIFY=0 assembles without the run legs; SHIP_EXE=... names the accepted
# ROM-based tree §5a compares frames against (default build-ship/ShadowrunSNESRecomp)
```

`PERSONAL=1` builds that second picture. It is a **separate artefact with reversed
rules**, not the first one with a flag flipped, and the script keeps the two apart
by name:

| | shareable (§7.19, `macos_package.md`) | personal (`macos_package_personal.md`) |
|---|---|---|
| build tree | `build-ship-m11`, exe `092b0e690cab97a1` (5,970,048 B) | `build-embed-ship-m11`, exe `594499e83171a0f8` (7,026,848 B) |
| `.app` | `dist/Shadowrun.app` | `dist/Shadowrun-personal.app` |
| `.dmg` | `shadowrun-0.1.0-macos-arm64.dmg` | `shadowrun-embed-0.1.0-macos-arm64-personal.dmg` |
| bundle id | `org.retroportingtoolkit.shadowrun` | `org.retroportingtoolkit.shadowrun.personal` |
| log | `tests/out/pkg/macos_package.log` | `tests/out/pkg/macos_package_personal.log` |
| scratch dirs | `tests/out/pkg/{payload_stage,app,…}` | the same names with `_personal` |
| ROM scans | all expect absent | the same absence scans, **plus** three presence checks: `nm` finds `_snesrecomp_embedded_rom`, a byte scan finds 1,048,576 B inside the Mach-O, and the `BUILD_INFO.txt` / `embedded_rom.c` / `rom_identity.txt` digests must agree |
| run legs | `--rom` passed where a ROM-based host needs it | never `--rom`, never a `rom.cfg` |
| framework | `sr-osx` @ `32266300d722…`, the pin **+ 1** commit (the state fix, §7.21) | `sr-embed-osx` @ `a7fb67e6c9f5…`, the pin **+ 4**: the embed capability commit `c5024e74abef` plus that same state fix |
| payload in the `.app` | `37d08a86a2a86414`, 5,953,488 B | `44a3da74ddca0062`, 7,004,144 B |
| floor (`minos`) | 11.0 (§7.22) | 11.0 |
| first launch | file picker once, then `rom.cfg` in `~/Library/Application Support/Shadowrun/` | no picker: `rom resolved: <embedded:Shadowrun (USA).sfc>`, and **no `rom.cfg` is ever written** |

The two variants cannot collide, because every path the script writes carries the
variant's own name: `dist/Shadowrun-personal.app`,
`shadowrun-embed-<version>-macos-arm64-personal.dmg`,
`tests/out/pkg/macos_package_personal.log`, and `_personal` on each scratch
directory (`payload_stage_personal`, `app_personal`, `dmg_stage_personal`, the dumps,
the probe image, the seal attempt). The shareable names, paths and scans in the script
are what they were before `PERSONAL` existed, and each run wipes only the bundle and
stage directory under its own name. That separation is measurable rather than
promised: the personal run and a fresh shareable run went back to back with the
same script, and the shareable transcript that came out still reports its payload
as `37d08a86a2a86414` — the same bytes §7.19 committed — while only the container
moved (`fe2648738fad58a6` this run, `4ae623649621de47` for a second image built
from the same stage directory). The personal container is
`7edb5fe11827d880`, 2,949,133 B, and its own second image is `abb9408aa64aa47a`,
2,949,123 B. That round has been run twice: the first round's transcript contained
a sentence about its own framework that was no longer true — §5a described it as
one capability commit past the pin when the tree being packaged carried the state
commit of §7.21 as well — so the round was re-run rather than annotated, which is
also why the container hash here is this run's and not the earlier run's.
One slip and its cost are worth recording here rather than hidden: a
mis-invocation left a stray
`dist/shadowrun-embed-0.1.0-macos-arm64-personal-personal.dmg` in `dist/`, which
was deleted and the run re-done, so `dist/` holds exactly two images. The image
name is built as `$PKG_SLUG-$VERSION-$PLATFORM_TAG$DMG_SFX.dmg` with `DMG_SFX`
fixed at `-personal`, so a doubled suffix can only mean the *platform* argument
was wrong — and even that landed under the personal name, never on top of the
shareable package.

The two guard rails that do exist are about build inputs rather than file names, and
both stop a run rather than reporting it: a tree whose `CMakeCache.txt` says
`SHADOWRUN_EMBED_ROM:BOOL=ON` is refused by the shareable variant ("which compiles the
guest image into the executable. That would ship the ROM"), and a personal tree whose
framework defines no `SNESRECOMP_EMBEDDED_ROM` — read out of the framework path that
tree's own cache names — is refused too, because "The image would be in the binary …
nothing would boot it". Neither branch fired in this round's runs, so they are guards
in the script, not measured results; what the personal run did measure about the
framework is in the next two paragraphs.

**Where the image comes from.** `-DSHADOWRUN_EMBED_ROM=ON` makes
`tools/embed_rom.py` generate `embedded_rom.c` in the build tree; its header
record names the source file, `bytes 1048576`, `crc32 3f34dff0`,
`sha256 e6bc0a59…`, read out of `rom_identity.txt` rather than retyped, and the
host declares the array with the same length, so an image that disagrees with it
cannot link. The host half is one framework capability commit, `c5024e74abef…`, whose
own subject line in the framework clone is "runner/desktop: boot an embedded guest
image (`SNESRECOMP_EMBEDDED_ROM`)", and that subject, the insertions count and the
whole patch are in a generated log — `evidence/artifacts/macos_framework_commits.md`
§1, which *finds* the commit by grepping subjects in `pin..HEAD` rather than by a
hash typed into a script (§7.24). It is 112 insertions in a single file,
`runner/src/desktop/host_main.c`, at four kinds of site:

* `HostEmbeddedRomReady()`, which re-hashes the array against the crc32/sha256 this
  build's machine code was generated from, plus the `g_rom_embedded` flag it sets;
* ROM resolution in `snesrecomp_desktop_main()`, which short-circuits to the label
  `<embedded:NAME>` rather than resolving a file — that label is what §5's breadcrumbs
  show, so the legs can tell the two variants apart without being told which is which;
* the load site, which boots `snesrecomp_embedded_rom` instead of
  `ReadWholeFile(argv[0])`, and the mod plan commit, which is handed `NULL` so it
  validates against the digest it was initialised with instead of re-opening a path —
  the comment in that hunk is explicit that this is "the same one, not a weaker one";
* the two relaunch paths (in-game launcher restart, netplay return-to-lobby), which stop
  passing `--rom` when the "path" is a label.

That last group is the part this package never exercises: the commit message marks the
launcher restart of an embed build as an untested edge, and no leg here reaches it
either — every leg exits through `atexit`.
§7.4 is where that seam was built and measured, and §7.4 is also where its caveat
lives: the framework half sits on an unpromoted branch (`feat/embedded-rom`, never
pushed, never run through the framework's own suites), so the port-side frame legs
in §5a are the only evidence this container has that the seam does not move the
machine.

**The framework question, and the choice not to move the pin.** The framework that
tree is built from is a branch off the pin, not the pin, and it carries more than
the capability commit this feature needs: the embed commit, the state commit of
§7.21 (which the shareable package also carries), and two `docs/validation`
records between them. What matters here is what the pin does *not* contain:
`grep -r SNESRECOMP_EMBEDDED_ROM sr-pin` → 0 files anywhere in it, and the pin's
`host_main.c` resolves the dump in the order `tests/rom.sh` states it — "launcher ->
positional/--rom -> a .sfc beside the executable -> rom.cfg" and, failing all of
those, a GUI file picker (`runner/src/desktop/host_main.c:3497`) — with no embedded
candidate. An embed tree configured against the pin would compile the
1 MiB array into the binary and boot nothing from it, which is why §0 of the log
reads the framework from that build tree's own `CMakeCache.txt` and refuses that
combination rather than letting it present as a package. Moving the pin is not free
either: every claim committed in §7.5–§7.19 is a claim about `773285b8210f`. So the
tree was built in a clean clone carrying those commits, and §0 *states* that
difference instead of smoothing it — `tests/provenance.py pin --descendant` prints

```
OFF THE PIN  build-embed-ship-m11: …/sr-embed-osx @ a7fb67e6c9f5644a98ade281b6d157693a31eb52, with 773285b8210f as an ancestor -- a branch off the pin, fine for a capability leg
framework …/sr-embed-osx defines SNESRECOMP_EMBEDDED_ROM in 1 runner/src file(s)
```

and the claim that those commits add no machine state is then measured rather
than assumed: §5a compares the packaged personal app against the accepted
ROM-based tree and gets **identical over 1,200 frames**, "no non-label WRAM byte
differs in 1200 shared frames". That is the only comparison that can mean anything
here: the two executables differ by 1 MiB of guest data, so byte hashes say
nothing about behaviour, and one side logs `rom resolved: <embedded:…>` while the
other names a file.

**The scans invert instead of relaxing.** Nothing that holds for both variants
loses its expect-0 — ROM/patch-shaped files in the payload and in the mounted
image, `rom.cfg`, generated build inputs, files naming this repository or this
machine's ROM directory: all 0 in the personal run too. What changes is what
counts as a pass:

* `nm` must show the array symbol: `embedded-ROM symbols in the executable 1
  (_snesrecomp_embedded_rom)`. A 0 there aborts the run, because the guest being in
  that binary is the personal package's entire premise.
* the image is then looked for *as bytes* inside the Mach-O and what is found is
  re-hashed: `found at offset 0x447d3e (1048576 B), sha256 e6bc0a59… -- matches the
  digest in rom_identity.txt` → `MATCH: expected present, present`. The same scan
  against the shareable executable reads `not found … MATCH: expected absent,
  absent`, so the check is not a tautology and both variants run it.

**The labels are read back, not asserted.** A personal package has to say what it
is, so §1 reads the strings off the finished bundle with `plutil -extract` — the
values a person actually sees in Get Info: `CFBundleName Shadowrun-personal`, a
bundle id ending `.personal`, a copyright string that begins "Personal build …
Contains the guest ROM image … Not for redistribution" — and it compares the
digest record inside `Contents/Resources/BUILD_INFO.txt` against both sources of
truth:

```
    source             bytes      crc32 sha256
    BUILD_INFO.txt   1048576   3f34dff0 e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4
    embedded_rom.c   1048576   3f34dff0 e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4
    rom_identity     1048576   3f34dff0 e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4
      MATCH across all three: bundle label, generator record, rom_identity.txt
```

A label that quotes a digest the build disagrees with is worse than no label, so
the comparison belongs in the log, not in a comment. Three places carry the
notice, and all three travel with the file: `BUILD_INFO.txt` inside the bundle,
`README.txt` at the root of the image, and the copyright string. The read-back is
gated to the variant being measured for the first time: the shareable transcript
was already committed, and adding this block to it would have meant regenerating a
closed round's container hashes for a log line.

**The size delta is measured, not explained away.** An earlier round's script
comment explained the difference before measuring it — the install-name rewrite plus
a re-sign that "grows it by 32 bytes" — and this document's §7.19 repeated that figure
as a finding. That account belongs to the dylib-staged build. Neither shipped shape
contains an install-name rewrite, and both deltas run the other way: the payload in
the bundle is *smaller* than the executable in the tree that built it, by 16,560 B
shareable (5,970,048 B in `build-ship-m11`, 5,953,488 B in `Shadowrun.app`) and
22,704 B personal (7,026,848 B in `build-embed-ship-m11`, 7,004,144 B in
`Shadowrun-personal.app`). In each pair `LC_CODE_SIGNATURE` starts at the same byte in
both files — 5,923,616 shareable, 6,972,224 personal — so everything before it is the
same length in both, and the whole difference is the signature blob: 46,432 B in the
shareable tree against 29,872 B packaged, 54,624 B against 31,920 B personal, the
tree's blob the larger both times. The CodeDirectory inside those two sizes is a
different shape in each place, `flags=0x20002(adhoc,linker-signed)` with `hashes=1447+0`
in the shareable tree and `1703+0` in the personal one against `flags=0x2(adhoc)` with
`hashes=362+3` packaged shareable and `426+3` packaged personal, because `ld` scores
4 KiB pages over the whole binary while `codesign --force --sign -` scores 16 KiB pages
on an executable this large. The two blobs are therefore not comparable byte for byte,
which is why §5a compares machine state instead of hashing these files. What *is*
comparable is everything up to the blob: `cmp` over that common prefix reports **5
differing bytes of 5,923,616** for the shareable pair and **5 of 6,972,224** for the
personal pair, in both cases first at byte 3,074 and last at 5,550, and both files of
both pairs end their load commands at 32 + sizeofcmds(5520) = 5,552. Every difference
is inside the Mach-O header and its load commands and nowhere else — so the code, the
data and, in the variant whose whole point is the image, the 1 MiB guest image are
bit-identical between `build-embed-ship-m11/ShadowrunSNESRecomp` and the bytes the app
runs. The log also says why the file length moves at all: `__LINKEDIT`'s file offset
comes from the segment table, so the padding after the load commands absorbs the sign's
new 16 B command and the length moves only with the blob.

**§3 also proves the staging rule against this tree, not just the shareable one.** The
four-copy probe §7.19 describes runs here too and lands the same way. A scratch copy
of `build-embed-ship-m11/ShadowrunSNESRecomp` given only `codesign --force --sign -`
in a plain directory comes out `b88e847492887cb8` — **no match**, and that is the
bundle seal's doing, not a failed step. The same bytes renamed `other-name` give
`3f9f87c19f395623`: an ad-hoc sign takes its identifier from the file name, which is
also why the two variants' payload hashes can never meet. Signed while sitting inside
a scratch `Probe.app`, the file becomes `2b35ab763ebc4402` with
`Identifier=org.example.signprobe` — the right *shape*, the wrong `Info.plist` — its
CodeDirectory 13,838 B where the shipped one is 13,859 B. All three of those probes
are 7,004,128 B, so their lengths do not tell them apart while their hashes disagree,
and all three are 16 B shorter than the payload in the bundle. What does match is the
fourth copy: staged in a plain directory, signed, copied into the bundle, then the
whole bundle sealed with **this** bundle's own `Info.plist` — `44a3da74ddca0062`,
7,004,144 B, `Identifier=org.retroportingtoolkit.shadowrun.personal`. That order is
the whole of what the packaging does to an executable that carries a guest image. The
probe copies are left under `tests/out/pkg/sign_probe_personal/` (shareable:
`tests/out/pkg/sign_probe/`), git-ignored scratch that every run deletes and rebuilds
from the tree — where to look straight after a run, not a standing directory.

**A personal leg that fails is a hang, so the legs are bounded.** Every personal
leg is denied `--rom`, which is the point; the consequence is that a broken embed
does not exit nonzero, it opens the file picker and waits for a human. So each leg
runs under `run_bounded` (macOS has no `timeout(1)`, and `/bin/bash` is 3.2, so no
arrays either): 240 s for the frame legs, 90 s for the rest, SIGINT then SIGKILL,
and 124 or 125 in the log. A hang has to read as a failed claim, not as "still
running". The frame leg is skipped with a message rather than silently downgraded
if `$SHIP_EXE` or the dump is missing.

**A round is complete when its log ends with the `== DONE` sentinel, and only then.**
The wrapper that runs the two variants back to back reports an exit status, but the
status is not the completeness check: bash reads a script as it executes it, so a
round whose script is edited mid-run resyncs at a stale byte offset and its log stops
early, sometimes after a section that passed. A discarded round of this pair stopped
inside §5 with a shell parse error and never reached §6, §7, §8 or the sentinel, while
the section it did reach still read as a pass. The rule the harness now follows: a
round counts only if its log carries all ten section headers, §0 through §9, *and*
the `== DONE` line, and the script is frozen while a round is in flight. The rule
came out of a discarded round of this pair whose log stopped inside §5 with a shell
parse error after a section that had passed: the exit status said nothing either way.

Six results this round were wrong before they were right, and every one of them
was wrong in the direction of a passing log. The first is §3's size explanation: the
script's own comment asserted where the byte difference came from and no log line
measured it, so §3 now prints the `dataoff`s, both blob sizes and the `cmp` result.
The second is a size delta that *was* committed in this document's §7.19, claimed
as probe three coming out longer than the payload because it bound an `Info.plist`
into the Mach-O's own signature. It does not reproduce, and the figure was dropped
rather than corrected: it came from an earlier shape of the tree, and no measurement
on disk supports it. Measured now, the copy that binds a *different* bundle's
`Info.plist` comes out `54dd237e7b910c72` at 5,953,472 B against the shipped
5,953,488 B — 16 B **shorter**, not 32 B longer — and the personal pair is
`2b35ab763ebc4402` at 7,004,128 B against 7,004,144 B. All three non-matching
probes are the same length as each other and none of them is the payload's length,
so the length is not what tells the four apart; the hash is. The log says what the
16 B is: the sign writes one `LC_CODE_SIGNATURE` command of 16 B plus padding to
8 B, `__LINKEDIT`'s file offset comes from the segment table, and so "The file
length may or may not move, so size alone does not catch it; the hash does".
The other four are about the legs:

* **§5c's failure branch stated a fact the leg had never measured.** The first
  personal run printed `no report after 90 s: the LaunchServices leg did not run`
  and went on to exit 0. What it actually knew was that one file had not appeared
  within a fixed 90-second poll — and the very next leg of that same run booted the
  same bundle, anchor line to window, in well under a second. Every re-run since has
  produced the report in a few seconds from a process the leg can name — the current
  shareable transcript prints `waited 16s wall for it; pid 67440 has exited` and then
  `reason=atexit  host frames=276  at 2026-11-10T05:26:16Z` — so the app had started
  and the leg had described its own blindness as a finding about the payload.
  The same leg has printed a different pid and timestamp in every round since, which
  is what makes the two quoted tokens this round's rather than the leg's. The wait now separates *still alive with
  no report* (a hang — and for this package the only window that can hang it is the
  ROM picker) from *gone without a report* (never started), re-checks liveness with
  `kill -0` before it says anything about a process, prints the report's own
  timestamp beside the wall seconds it measured, and stops a hung process with
  SIGINT then SIGKILL rather than leaving it on the screen. Why that distinction
  matters for *this* variant specifically: every personal leg is denied `--rom`, so
  the failure mode of a broken embed is not a nonzero exit, it is a dialog.
* **§5c also claimed LaunchServices gives the app the real drivers.** It did not:
  `open` relays the packager's exported `SDL_VIDEODRIVER=dummy`, and the app's own
  breadcrumb said `SDL init ok: video=dummy audio=dummy`. That false sentence was
  in the shareable transcript too. The leg now starts with
  `env -u SDL_VIDEODRIVER -u SDL_AUDIODRIVER` (`CLICK_HEADLESS=1` opts out and the
  log then says it measured less), and reads the drivers from the breadcrumb,
  because the report's `sdl` block is no use either way: the framework writes it
  after `SDL_Quit()` (`runner/src/host_report.c:345`), so it reads `"(none)"` for
  every run, dummy or real. Both current transcripts show `SDL init ok:
  video=cocoa audio=coreaudio` and `window created: 960x720` — so this is now the
  one leg that is not headless: it puts a window on this screen for ~5 s and opens
  the audio device, which is exactly what a double-click does.
* **§5e reported "files in this repository touched during that run: 1 (expect 0)"
  with no name attached** — that round's own wording, still readable at `git show
  21c1109:tests/README.md`. The count was right and useless, and identifying the
  entry afterwards by hand — `.DS_Store`, Finder bookkeeping — is itself the
  argument for the fix: a count that hides its subject is not a claim. The leg now
  names every entry it finds, and both clean runs report 0.
* **A no-match `grep` inside `emb="$( … )"` aborts the whole script** under
  `set -euo pipefail` — and "no match" is exactly the expected-failure path of the
  presence scan. Command substitutions that are *asking a question* need an inner
  `{ …; } || true`. The same shape killed §0 once on `sed 's/^/  /'` fed from a
  failing command substitution, because `build-embed-ship` has no run manifest and
  `provenance.py key` has nothing to read; the log now says that absence out loud,
  and what ties the tree to the accepted build is §5a rather than a manifest.

`evidence/artifacts/macos_package_personal.md` is that log verbatim:
`dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg`, 2,949,133 B, sha256
`7edb5fe11827d880`, `hdiutil verify` VALID (German output — the host's locale is
part of the measurement), and a second image from the same stage directory
(`abb9408aa64aa47a`, 2,949,123 B) with a different hash, the same
non-reproducibility §7.19 records. Its payload is `44a3da74ddca0062`, 7,004,144 B,
against the shareable payload's 5,953,488 B: a little over 1 MiB more, for a
1,048,576 B image that also brings its own length field and whatever alignment the
compiler chose for the array.
Legs a–f all exit 0; leg d — opening the app with nothing passed at all and no
`rom.cfg` anywhere — goes from the launcher's anchor line straight to
`rom resolved: <embedded:Shadowrun (USA).sfc>` and a window, which is where the
file picker would have appeared had the image not been in the executable. The
bundle copy under test is inventoried before and after those legs: **11 files,
tree hash `27264ebd30d4708d`** both times, and the install leg reports
`payload paths that disappeared during that run: 0` and
`files in this repository touched during that run: 0`.

**The personal §7 runs the extra leg**, because this payload does have an embedded
guest for it to exercise. Subject a is the executable read off
`/Volumes/Shadowrun-personal` with `--rom` naming the dump; subject b is the same
bytes with `--rom` withheld, which is the path a double-click takes; c and d are
the two *reference* builds, the same pair §7.19's §7 uses —
`build-ship/ShadowrunSNESRecomp` (`a0587ed0a0e34687`, 3,103,776 B, `minos 26.0`,
Homebrew dylib, the unpacked shape whose staged file at the repository root is
96 B larger) and `build-ship-m11/ShadowrunSNESRecomp` (`092b0e690cab97a1`,
5,970,048 B, `minos 11.0`, SDL3 inside the Mach-O). d is *not* the tree these bytes
came from — §0 of the same log prints `build dir  build-embed-ship-m11` — and §7
describes d as "the tree built at this package's floor on a framework that carries
the state fix but not the guest", then declines to claim even that framework is
this package's. What the pairing can show, in the log's own words, "follows from
what they share -- floor, and a framework with the state fix and no guest -- so the
difference between it and a or b is the guest moving from a file into the
executable". Four legs, **all exit 0 with 1245 WRAM dumps**, and all five pairings read
`identical over 1245 frames` / `no non-label WRAM byte differs in 1245 shared
frames`: `frames_file_personal` vs `frames_embed_personal` (one set of bytes, the
guest from a file or from `__DATA`), then each of those two against
`frames_refpin_personal` and against `frames_ref11_personal`.
The host's own lines around the embedded path, in order, under the legs that take it:

```
      [host +0.005s] rom resolved: <embedded:Shadowrun (USA).sfc>
      [host +0.014s] SDL init ok: video=dummy audio=dummy
      [host +0.014s] rom loaded: 1048576 bytes
```

against `rom resolved: …/Shadowrun (USA).sfc` for the leg that names the file. Same
bytes, same 1,048,576 B, one of them not a file on disk.

**§8 inverts, and the inversion is the point.** Both subjects get the four presence
scans and the carve-out; the container reads False on all four and the carve-out
prints `carve-out: no offset -- the span is not in this file` — which is what
`-format UDZO` makes expected, since the container is zlib. The executable inside
it reads True on the first-256 scan, the filename, the header string and the hex
digest, and then the carve-out does the work a presence scan cannot:

```
  exe in image  7004144 B
      ROM first 256 bytes present:  True
      ROM filename present:         True
      SNES header string present:   True
      ROM sha256 as hex text:       True
        filename at 0x57cad0, and the printable strings around it are:
          ['guard_hex', "missing glyph mapping for '", 'Shadowrun', 'Shadowrun (USA).sfc', 'e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4', '3f34dff0', 'shadowrun-usa', '0.1.0']
```

The first-256 hit gives an offset, and taking 1,048,576 bytes from it and comparing
that span against the dump itself is what turns "present" into a measured fact
rather than a coincidence of bytes:

```
      carve-out: found at offset 0x447d3e, carved 1048576 B, 0 byte(s) differ from the
                 ROM file itself; carve hashes e6bc0a595d5c7c4b vs ROM e6bc0a595d5c7c4b -> the same file, identified
```

So this payload holds the game at a known offset in a read-only section, the
container a person would download does not hold it verbatim, and both facts come
from one scan of two subjects. §2's file-level scans still read 0 for ROM/patch
shapes, `rom.cfg`, `src/gen`/`recomp/funcs.h`, files naming this repository and
files naming this machine's ROM directory: the guest entered this payload at
configure time as generated bytes, and nothing about the personal variant weakens
the scans that hold for the shareable one.

**§9 reads the same for both variants**, which is what it should: an ad-hoc
signature, no team, one file sealed, no ticket, `rejected` `[exit=3]` with and
without `com.apple.quarantine`, quarantine leaving the seal
`valid on disk` `[exit=0]`, and attached Finder data breaking it `[exit=1]` and
being removable `[exit=0]`. The personal `CodeDirectory` is
`v=20400 size=13859 flags=0x2(adhoc) hashes=426+3` against the shareable
`v=20400 size=11802 flags=0x2(adhoc) hashes=362+3` — 2,057 B and 64 more file
hashes, which is one seal accounting for a bigger Mach-O, not a different kind of
seal.

**What this package is for, and what it is not.** It is the picture for the one
machine you own, where the point is to stop picking a ROM: open it and the game is
running, no picker, no `rom.cfg`, no `-DSHADOWRUN_EMBED_ROM=ON` to remember. It is
**not** a shareable artefact, and §6 of the log says so in as many words: sending
that container to anyone is sending them a copy of Shadowrun. The shareable
artefact stays what §7.19 measured, and the difference between the two is not a
policy the script bends — it is a file the payload carries.

### 7.21 Why the bundle can be sealed at all: the two-host state probe (2026-11-09)

§7.19 ships a bundle that seals, validates, and survives a run unchanged. That is
not what the pinned host produces, and the difference is one host commit rather
than a packaging trick — so it is measured on one machine with two executables,
rather than asserted by the packager that benefits from it.

```sh
tests/macos_state_probe.sh with FORK=build-fork-osx PIN=build-ship SCRIPT=tests/scripts/short.txt PARITY=tests/scripts/parity.txt
# log: tests/out/state_probe/macos_state_probe.log
#      = evidence/artifacts/macos_state_out_of_bundle.md
# both build trees print their own SNESRECOMP_ROOT from CMakeCache.txt;
# the framework pin comes from framework_pins.txt, not from a remembered hash
```

**§0, the two hosts.** Same checkout, different framework, and each framework read
out of that tree's own cache rather than typed in:

| | fork (the shipping shape) | pin (the shape that made the complaint) |
|---|---|---|
| executable | `092b0e690cab97a1`, 5,970,048 B, `minos 11.0` | `a0587ed0a0e34687`, 3,103,776 B, `minos 26.0` |
| framework | `…/sr-osx` HEAD `32266300d722…`, **dirty 0** | `…/sr-pin` HEAD `773285b8210f…`, **dirty 0** |
| against the pin | `OFF THE PIN … with 773285b8210f as an ancestor -- the pin plus 1 commit(s)` | `AT THE PIN 773285b8210f…` |

That one commit is `runner/macos: keep writable state out of the .app bundle`, and
it is not upstream: like the embed capability commit in §7.20, it lives only in a
local clone of the framework, so every claim that rests on it says so — and
`evidence/artifacts/macos_framework_commits.md` §3 prints what that clone differs
from the shareable one by, which for the state code turns out to be nothing (§7.24).

**§A keeps the development layout alone.** When a binary is *not* inside a
`.app`, both hosts anchor to the binary's own directory and leave the same files
beside it — `config.ini`, `keybinds.ini`, `last_run_report.json`, `rom.cfg`,
`mods/preloaded/{packages,state.toml}`, `saves/save.srm` — and the state
directory under the private `$HOME` is never created, because neither run was in
a bundle. That is a regression leg, not a curiosity: had the fork changed the
non-bundled anchor too, it would have moved the state that ~200 earlier
measurements in this kit read.

**§B is the shipping shape.** A bundle holding only `Info.plist` and the payload
seals first try (`codesign exit=0`), verifies as `valid on disk` / `satisfies its
Designated Requirement`, runs a scripted boot with `exit=0` from inside
`Contents/MacOS/`, and the anchor line says what changed:

```
[Launcher] Config/saves anchored to '…/state_probe/scratch/home/Library/Application Support/Shadowrun/' (bundle run: state kept outside the .app).
```

Its own file inventory is then diffed before and after that run: **`before=4
after=4`**, and the only line that differs is the label line of the two listings.
The payload's hash is identical across the run — and it is the probe bundle's
hash (`4300488f8b02c3e7`), not §7.19's `37d08a86a2a86414`, because the probe
stages its own copy under its own `Info.plist` (bundle id
`org.retroportingtoolkit.shadowrun.probe`); §7.19 §3 is where the *shipped*
payload's identity is pinned. The seal is asked again after the run and still
passes, and `Contents/_CodeSignature/CodeResources` exists.

**§C generates the old shape instead of describing it.** The pinned host is run
*inside* a bundle, so it writes its state where it thinks state goes:
`Contents/MacOS/` fills up with `config.ini`, `keybinds.ini`,
`last_run_report.json`, `rom.cfg`, `saves/save.srm`, `mods/preloaded/state.toml`.
The **same `codesign` command line that succeeded in §B** is then pointed at it:

```
…/state_probe/scratch/pin/Shadowrun.app: code object is not signed at all
In subcomponent: …/state_probe/scratch/pin/Shadowrun.app/Contents/MacOS/mods/preloaded/state.toml
codesign exit=1
```

and the check that follows answers with the sentence that started this:

```
…/state_probe/scratch/pin/Shadowrun.app: code has no resources but signature indicates they must be present
verify exit=1
```

Which loose file gets named in the refusal is whichever one codesign reaches
first, so it is not stable across runs: this transcript names
`Contents/MacOS/mods/preloaded/state.toml`, and the packager's own counter-case —
§1's third seal state, in both package logs — names `Contents/MacOS/keybinds.ini`
for the same failure in a bundle built by the script instead of by the probe. What
is stable is the class of it — a non-Mach-O file in `Contents/MacOS/` — and the
verdict.

That assessment — a signature that promises a resource seal with no seal present —
is what macOS renders to a person as "*Shadowrun* is damaged and can't be opened".
Nothing is corrupt and the program is fine: the run itself exits 0, its inventory
goes 9 files → 10 (`save.srm.bak` appears as the app rotates its own save), and
the payload hash is unchanged across it. Then the leg copies that bundle and asks
the copy, which gets the same verdict — which is exactly why a *download* gets
blamed for a bundle's own shape.

**§D, where the state actually went**, is the flip side: one listing under the
private `$HOME`, under the name the bundle's `CFBundleName` gives it, and a
near-miss name (`Shadowrun.probe`) checked alongside it and reported absent, so
the listing is the bundle's state directory and not whatever a run happened to
leave. The two anchor lines are printed side by side: the fork names a directory
under `~/Library/Application Support/`, the pin names a directory inside its own
`.app`.

**§E is the leg that pays for the fork.** Everything above is about where bytes
are written; none of it says the emulator still behaves. The two executables
cannot answer that by hash — 5,970,048 B against 3,103,776 B, built against
different SDL3 shapes, so ~2.9 MB of difference exists whatever the host change
did. So it is the same comparison every other claim in this kit uses:
`tests/scripts/parity.txt`, per-frame crc32 of all 128 KiB of WRAM, both legs
`exit=0`:

```
identical over 1200 frames (crc32 of all 128 KiB of WRAM per frame)
  no non-label WRAM byte differs in 1200 shared frames
```

That is the sentence that lets §7.19's package keep inheriting every measurement
made against the pinned executable: a different place to keep config, saves and
`rom.cfg`, with the machine state unchanged.

`evidence/artifacts/macos_state_out_of_bundle.md` is that log verbatim, including
the absolute scratch paths, because those paths are what makes each leg's anchor
claim checkable.

### 7.22 The deployment floor: which macOS each payload can run on (2026-11-09)

A floor is a claim about other machines made from this one, so it is read off
Mach-O build records rather than asserted. The number that matters is **not** the
deployment target a build was configured with: dyld loads the executable *plus
every non-system dylib it names*, so a bundle's floor is the highest
minimum-system version among all of those files. This port has built three
shapes, and each is decided by a different file.

```sh
tests/macos_floor_probe.sh with TREES="build-ship build-embed-ship build-osx11 …"
# log: tests/out/floor/macos_deployment_floor.log
#      = evidence/artifacts/macos_deployment_floor.md
# TREES="build-ship build-ship-m11" narrows it. A tree that has been cleared
# prints as absent rather than shortening the log silently, so a shorter log
# always says so; the ten-tree list in §1 is a record of what was measured, not a
# claim that ten directories exist. The default list is also frozen at the
# compatibility round's ten, so a tree created after this probe ran is not in it:
# `build-ship-m11-check` (§7.23) is absent from the table and `build-osx11-static`
# is absent from the script's defaults, and both are accounted for under the table.
# TREES="build-ship build-ship-m11" bash tests/macos_floor_probe.sh
```

The script reads bytes; it never runs the emulator. The pin it measures framework
branches against comes from `framework_pins.txt`, not from a remembered hash.

**§1, ten trees, in the order the compatibility round tried them.** Each entry is
its own `CMakeCache.txt` facts (deployment target, `SNESRECOMP_ROOT`, SDL3 source,
`SHADOWRUN_EMBED_ROM`, `SNESRECOMP_SDL3_FETCH_VERSION`), that framework's status
against the pin with its dirty flag, the payload's hash and size, one
`minos`/`sdk` line per architecture, how many non-system dylibs the Mach-O names,
the `LC_RPATH` entries that resolve an `@rpath/…` load name, that dylib's own
build record, and the one number that binds:

| tree | framework | SDL3 | payload | `minos` | floor a bundle from it needs |
|---|---|---|---|---|---|
| `build-ship` | **at the pin**, dirty 0 | Homebrew dylib | `a0587ed0a0e34687` 3,103,776 B | 26.0 | **macOS 26.0** (the executable itself) |
| `build-embed-ship` | off the pin `c5024e74abef`, dirty 0 | Homebrew dylib | `5822a85675b2640d` 4,160,576 B | 26.0 | **macOS 26.0** |
| `build-osx11` | at the pin | Homebrew dylib | `ec482cf36614c938` 3,111,536 B | 11.0 | **macOS 26.0** — `(highest record: /opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib)` |
| `build-osx11-sdl11` | at the pin | `SDL3_DIR` → a floor-11 build | `c743eb8a0d417d55` 3,111,536 B | 11.0 | macOS 11.0 |
| `build-osx-static` | at the pin | fetched, static | `bdf5117aa9fff69c` 5,969,936 B | 11.0 | macOS 11.0, **0 dylibs, 0 `LC_RPATH`** |
| `build-osx-universal` | at the pin | `SDL3_DIR`, `@rpath` | `9b003463ad4d51df` 6,126,192 B | 11.0 both slices | macOS 11.0 |
| `build-fork-osx` | off the pin `32266300d722` (**pin + 1**), dirty 0 | fetched, static | `092b0e690cab97a1` 5,970,048 B | 11.0 | macOS 11.0 |
| `build-ship-m11` | same framework | fetched, static | `092b0e690cab97a1` 5,970,048 B | 11.0 | macOS 11.0 |
| `build-embed-ship-m11` | off the pin `a7fb67e6c9f5` (**pin + 4**), dirty 0 | fetched, static | `594499e83171a0f8` 7,026,848 B | 11.0 | macOS 11.0 |
| `build-osx-universal-m11` | pin + 1 | fetched, static, fat | `47ef23a1de7eab93` 12,146,816 B | 11.0 both slices | macOS 11.0 |

The two build directories on disk that this table does not cover are accounted for
rather than missing: `build-osx11-static` was configured and never built, so §1 has
no payload to read from it, and `build-ship-m11-check` did not exist when this
probe ran — its payload is compared byte for byte against `build-ship-m11`'s in
§7.23, which is a stronger statement than a second row of the same `minos` number.

The third row is the whole lesson of this section. `-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0`
*was* set, the executable *did* come out at `minos 11.0`, and a bundle from that
tree still cannot run below 26.0, because dyld refuses a dylib built for a newer
system than the caller claims to support. Homebrew's `libSDL3.0.dylib` is
`minos 26.0` (`599c1a000f96797e`, 2,520,544 B, arm64 only), so every shape that
vendors or links against it is pinned to 26.0 however the port is configured.
That is why the shipped package is the static shape.

**That shape has exactly two inputs that matter, and both are in its own cache:**
`CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0` plus
`CMAKE_DISABLE_FIND_PACKAGE_SDL3=ON` and `FETCHCONTENT_SOURCE_DIR_SDL3` pointing at
an SDL3 source tree built at that target. `build-ship-m11/CMakeCache.txt` and
`build-embed-ship-m11/CMakeCache.txt` both name `/usr/bin/cc` and `/usr/bin/c++`,
so no cross-compiler is involved and no dylib is shipped: §3 of the floor probe
counts one Mach-O per bundle, which is why the floor here is one flag rather than a
flag plus a separately built dependency that has to agree with it — the SDL3 in the
link is compiled inside the same tree, at the same `CMAKE_OSX_DEPLOYMENT_TARGET`, and
`-DFETCHCONTENT_SOURCE_DIR_SDL3` is what supplies its sources — `tests/out/m11_build.log`
says "no SDL3 package found; building SDL3 3.4.10 from source" and then compiles
`_deps/sdl3-build/CMakeFiles/SDL3-static.dir/…` in that same tree, which is also what
§4's zero `-Wunguarded-availability` count covers. §7.23 is the
recipe written out from that cache and rebuilt empty; §8.1's first bullet is the
same observation about the `CC=` prefix the older rounds carried.

**§2 measures the two SDL3 builds side by side**: Homebrew's (`599c1a000f96797e`,
arm64, `minos 26.0` → "a bundle vendoring this dylib cannot run below macOS
26.0") and the floor-11 one this round built (`190c82eeeddca0db`, 5,999,648 B,
`x86_64 minos 11.0` + `arm64 minos 11.0` → "cannot run below macOS 11.0"). Then
the third shape: a static link has no dylib to carry, so the only build record in
the bundle is the executable's, and the deployment target given to the port *is*
the whole floor. Both SDL3 sources declare version 3.4.10, which is the version
the framework itself pins for CI (`SNESRECOMP_SDL3_FETCH_VERSION` in
`runner/runner.cmake`, `tools/ci/prefetch_sdl3.sh`), not a version chosen here.

**§3 reads what is shipped.** Each app has exactly one Mach-O in its bundle, at
`minos 11.0 sdk 26.5`, and its `Info.plist` claims 11.0 — the two numbers agree
because the packager writes the `README.txt` inside each image from the
executable's own `LC_BUILD_VERSION`, so the number a person is told and the
number dyld enforces cannot drift apart. Payloads `37d08a86a2a86414` (5,953,488 B)
and `44a3da74ddca0062` (7,004,144 B); images
`shadowrun-0.1.0-macos-arm64.dmg` `fe2648738fad58a6` 2,221,175 B and
`shadowrun-embed-0.1.0-macos-arm64-personal.dmg` `7edb5fe11827d880` 2,949,133 B,
both `hdiutil verify` VALID (in German — the host's locale is part of the
measurement). The section repeats the rule §7.19 §5g earned: a `.dmg` hash pins a
run, not a build, because `hdiutil` stamps volume dates and UUIDs into the
container.

**§4 is the evidence that a floor older than this machine is safe to ship**, and it
is counted rather than trusted: eight build logs plus the three blocks of
`tests/out/m11_build.log`, each reported as *warning lines*,
*`-Wunguarded-availability`*, *`error:` lines*, and *lines containing the string
`error`* — the last two separated because an SDL source file is literally named
`SDL_error.c`, and one confident grep is how a passing build gets invented. The
eighth log is `tests/out/m11_check_build.log`, §7.23's clean-tree build; the
section says so in its own words ("a tree configured and built in a directory that
did not exist when that script started, so its counts are not inherited from
objects already compiled in a tree someone left behind"), and it names, counts the
lines of, and hashes the file each block of numbers was read out of.  Across
all eleven records: `-Wunguarded-availability` **0**, `error:` **0**, warning counts
3–5, and every warning line printed in full rather than summarised — which is also
what exposes the one warning that matters, in `osx11_build.log`:

```
ld: warning: building for macOS-11.0, but linking with dylib '/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib' which was built for newer version 26.0
```

The linker saying that is the same fact §1 measured as that tree's floor being
26.0. The others are `opengl.h:25:65: '/*' within block comment [-Wcomment]`,
`ld: ignoring duplicate libraries: '-lm'` and `ld: reducing alignment of section
__DATA,__common from 0x8000 to 0x4000`, all in files this port does not own.

A floor is also limited by what dyld has to find. The shipped payload names **zero**
non-system libraries, because SDL3 is linked in; of its 23 system load names, two
did not exist at 11.0 release and both are marked **weak** —
`UniformTypeIdentifiers`, `CoreHaptics` — dyld's own mechanism for "this library
may be absent here", where a weak library that cannot be found resolves to nil
instead of failing the load. Everything else is under `/System/Library/Frameworks`
or `/usr/lib`, and the count outside those two places is 0. Both shipped bundles
report the same 23 / 2 / 0.

**§5 says what this machine cannot prove.** It is arm64 (`hw.optional.arm64: 1`,
macOS 26.7.1 / Darwin 25.6.0) and `arch -x86_64 /usr/bin/true` fails with
`arch: posix_spawnp: /usr/bin/true: Bad CPU type in executable`: there is no
Rosetta here, so every `x86_64` record above is compile-and-link evidence and
**nothing in this repository has booted a x86_64 image on a x86_64 machine**.
`arch -arm64` runs, so the arm64 payloads were runnable in principle — and a floor
of 11.0 has still never been *booted* on a macOS 11 machine either. What §4
supplies for that gap is the check that would have caught reaching an API newer
than the floor, plus the two weak frameworks, which are the only libraries an
older system may lack. That is why the shipped package is arm64-only and the
universal tree stays a measured experiment.

**§6 closes the gap §1 itself opened.** Every build log §4 counts begins at the
compile step, so not one of them records a configure command line — a floor nobody
can rebuild is a claim about one afternoon. `tests/out/m11_build.log` is a re-run
of the three floor-11 trees with each `cmake` and `cmake --build` line printed as
it runs (`configure exit=0`, `build exit=0`, all three), and §6 compares three
independent records of each payload:

| tree | earlier record (`m11_builds.log`) | that rebuild (`m11_build.log`) | tree on disk |
|---|---|---|---|
| `build-ship-m11` | `092b0e690cab97a1` 5,970,048 B | `092b0e690cab97a1` 5,970,048 B | `092b0e690cab97a1` 5,970,048 B |
| `build-embed-ship-m11` | `594499e83171a0f8` 7,026,848 B | same | same |
| `build-osx-universal-m11` | absent (that tree came later) | `47ef23a1de7eab93` 12,146,816 B | same |

so the command lines printed there rebuilt the payload bytes that shipped. Then a
second comparison, inside the tree list, rules out the one variable a payload hash
could otherwise hide:

```
  build-fork-osx       092b0e690cab97a1  5970048 B
    SDL3 source dir  …/opencode/sdl3-src
    it declares       project(SDL3 LANGUAGES C VERSION "3.4.10")
  build-ship-m11       092b0e690cab97a1  5970048 B
    SDL3 source dir  …/opencode/SDL3-3.4.10
    it declares       project(SDL3 LANGUAGES C VERSION "3.4.10")
    cmp finds no differing byte between the two, so two trees built apart from each
    other, from two SDL3 source directories that both declare the same version, come
    out at the same payload.
```

What
decides those bytes is the framework commit and the deployment target — not which
checkout of the same SDL3 happened to sit in the build — and that is what makes a
payload hash a usable identity for a build elsewhere in this kit. The universal
tree appears in §6 for a different reason: `-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"`
is the only way an Intel slice exists at this floor at all, because Homebrew's
SDL3 on this machine is arm64-only (§2), and §5 is where what this machine cannot
do with that slice is stated.

`evidence/artifacts/macos_deployment_floor.md` is that log verbatim, German
`hdiutil` output included.

### 7.23 Proving the floor recipe from an empty directory (2026-11-09)

§7.22's §6 printed the `cmake` lines and showed they reach the shipped payload
bytes, but all three of those builds ran inside a directory that already existed —
so `cmake --build` found SDL3's objects and this port's objects already sitting
there. That is evidence the recorded commands agree with the trees; it is not
evidence that the recipe reaches those bytes when nothing is in the way.
`tests/macos_floor11_check.sh` is that leg:

```sh
tests/macos_floor11_check.sh
# the script's own usage line, quoted with its leading '#' removed:
SHIP_TREE=build-ship-m11 tests/macos_floor11_check.sh   # other baseline
# SHIP_TREE names the baseline, i.e. the tree the shipped .app came from
# FRESH_TREE=build-ship-m11-check the scratch tree; always rm -rf'd before it is made
# logs: tests/out/m11_check.log        = evidence/artifacts/macos_floor11_rebuild.md
#       tests/out/m11_check_build.log  = evidence/artifacts/macos_floor11_rebuild_build.md
```

**§0 reads the recipe out of the shipped tree's own `CMakeCache.txt`** so that no
path or option in the rebuild is typed by hand: `CMAKE_BUILD_TYPE:STRING=Release`,
`CMAKE_OSX_DEPLOYMENT_TARGET:UNINITIALIZED=11.0`,
`CMAKE_DISABLE_FIND_PACKAGE_SDL3:UNINITIALIZED=ON`,
`FETCHCONTENT_SOURCE_DIR_SDL3:PATH=…/SDL3-3.4.10`, `SNESRECOMP_ENABLE_MODS:BOOL=ON`
and `SNESRECOMP_ROOT:PATH=…/sr-osx`. It then checks those inputs are what the cache
claims rather than assuming: `sr-osx` is at `32266300d722…`, **dirty 0**, "commits
past the pin: 1" over `framework_pins.txt`'s `773285b8210f…`, its last commit
`runner/macos: keep writable state out of the .app bundle`; the SDL3 directory
declares `project(SDL3 LANGUAGES C VERSION "3.4.10")` and that is the same version
the framework itself pins (`set(SNESRECOMP_SDL3_FETCH_VERSION "3.4.10" CACHE
STRING`). The section is explicit that the baseline's SDL3 source is reused as-is,
because a different checkout would turn §2 into a comparison of SDL3 versions
rather than of recipes.

**§1 is the build itself, with its own command lines echoed as they ran:**

```
  cmake -S . -B build-ship-m11-check -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=…/sr-osx -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DFETCHCONTENT_SOURCE_DIR_SDL3=…/SDL3-3.4.10 -DSNESRECOMP_ENABLE_MODS=ON
  configure exit=0
    configure output, lines:  538
    -- Build files have been written to: …/build-ship-m11-check
  cmake --build build-ship-m11-check -j 12
  build exit=0
    build output, lines:      901  (with configure's, above)
  what that build produced:
    warning lines:             3
    -W unguarded-availability: 0
    'error:' lines:            0
```

Those counts are read out of `tests/out/m11_check_build.log` rather than out of the
summary, which is why the section names that file and hashes it — 901 lines,
60,469 B, `6a843387b653a4a3` — and prints all three warnings in full
(`opengl.h:25:65: '/*' within block comment [-Wcomment]`,
`ld: ignoring duplicate libraries: '-lm'`, `ld: reducing alignment of section
__DATA,__common from 0x8000 to 0x4000`). Committed verbatim as
`evidence/artifacts/macos_floor11_rebuild_build.md`, that file is the raw compiler
output behind §7.22's eighth record, so its counts are re-derivable by hand and
cannot be the packager grading its own homework.

**§2 compares the result against the tree the shipped package was built from:**

```
  shipped tree   092b0e690cab97a1  5970048 B
  clean tree     092b0e690cab97a1  5970048 B
  minimum system version, read off each Mach-O:
    shipped tree:  11.0
    clean tree:    11.0
  dyld asks for (non-system load commands):  shipped 0   clean 0
  architectures:                             shipped 1 slice(s)   clean 1 slice(s)
```

Then the log compares the two trees' configuration key by key, as their own caches
record it — `CMAKE_BUILD_TYPE`, `CMAKE_OSX_DEPLOYMENT_TARGET`,
`CMAKE_DISABLE_FIND_PACKAGE_SDL3`, `FETCHCONTENT_SOURCE_DIR_SDL3`,
`SNESRECOMP_SDL3_FETCH`, `SNESRECOMP_SDL3_FETCH_VERSION`, `SNESRECOMP_ENABLE_MODS`,
`SNESRECOMP_ROOT`, `SHADOWRUN_EMBED_ROM` — every one printed `same`. The script only
forces the keys it passes, so a disagreement there would mean the framework's own
default moved under the recipe. Then the byte comparison, in the log's own words:

```
  cmp finds no differing byte between build-ship-m11-check/ShadowrunSNESRecomp and build-ship-m11/ShadowrunSNESRecomp
  so the recipe in section 0 reaches the shipped bytes from an empty directory:
  a floor that can only be reached inside a tree someone already built would be
  a claim about one afternoon; this one is a property of the recipe.
```

The log ends `== DONE (payload bytes match) ==`.

**The limits are in the log's own words**, not added afterwards: it says nothing
about whether a macOS 11 machine runs the result (§7.22 §5 is where this machine's
reach is measured); the personal variant is not rebuilt here, because its payload
additionally carries a 1 MiB generated array and its framework is a different
clone; and `build-ship-m11-check` is a scratch tree left in place (39 MB) so the
byte comparison can be re-run by hand — nothing is packaged or committed from it,
which is also why it is not a row in §7.22's frozen ten-tree table. And what this
reproduces is the **build tree's** executable `092b0e690cab97a1`, not the shipped
`37d08a86a2a86414`: the difference between those two is the packager's ad-hoc seal,
which lives in `scripts/package_macos_bundle.sh` and is what §7.19 measures.

### 7.24 The framework commits the shipped packages depend on, as a generated artifact (2026-11-09)

Two claims in this kit are not about bytes this repository produced. One: the
personal payload's guest is compiled into the executable by a framework commit
(§7.20). Two: the writable state sits outside the bundle because of one other
framework commit (§7.21). The framework is not vendored here, so until this section
the only witness for either was a `git show` run by hand while reading — which is the
kind of claim this file otherwise refuses to make. `tests/macos_framework_commits.sh`
makes it a log:

```sh
tests/macos_framework_commits.sh
# log: tests/out/framework/framework_commits.log
#      = evidence/artifacts/macos_framework_commits.md
```

**§0 names the checkouts by reading them out of the build trees,** in the log's words
"the directory is whatever SNESRECOMP_ROOT says in the CMakeCache.txt of the build
tree named under it": `pin` from `build-ship`, `shareable` from `build-ship-m11`,
`personal` from `build-embed-ship-m11`. Each prints its HEAD, its dirty count, and
whether the pin is an ancestor and how many commits past it:

| checkout | HEAD | dirty | commits past the pin |
|---|---|---|---|
| pin | `773285b8210f…` | 0 | at the pin |
| shareable | `32266300d722…` | 0 | 1 |
| personal | `a7fb67e6c9f5…` | 0 | 4 |

A clone that has been cleared stops the script at exit 2 rather than letting another
checkout stand in for it, so this artifact ages honestly with the scratch directories
it reads; it is a reading of `…/opencode/sr-*`, not of `~/Documents/work/snesrecomp`,
and §6 is about that other checkout.

**§1 finds the commits by subject rather than hard-coding hashes:** "each commit is
located by grepping the subjects in pin..HEAD" of the checkout that carries them, so a
rewritten branch shows up as "NOT FOUND" in the log instead of quoting an old hash.
Both were found, and the log carries each one's full patch:

| commit | subject | diffstat, from the log |
|---|---|---|
| `c5024e74abef…` | `runner/desktop: boot an embedded guest image (SNESRECOMP_EMBEDDED_ROM)` | `1 file changed, 112 insertions(+), 6 deletions(-)` |
| `32266300d722…` | `runner/macos: keep writable state out of the .app bundle` | `5 files changed, 169 insertions(+), 6 deletions(-)` |

so §7.20's insertions figure and §7.21's commit subject are lines in a generated
artifact now, and every code site §7.20 lists (`HostEmbeddedRomReady()`, the
ROM-resolution short-circuit, the load site, the mod path) is greppable inside the
patch printed under them.

**§2 counts the host-side symbols per checkout,** which turns "the pin has no
embedded-host code at all" into numbers:

| symbol | file | pin | shareable | personal |
|---|---|---|---|---|
| `g_rom_embedded` | `host_main.c` | 0 | 0 | 6 |
| `HostEmbeddedRomReady` | `host_main.c` | 0 | 0 | 3 |
| `snesrecomp_embedded_rom` | `host_main.c` | 0 | 0 | 5 |
| `Application Support` | `host_paths.c` | 0 | 3 | 3 |
| `snesrecomp_state_dir_path` | `host_paths.c` | 0 | 1 | 1 |
| `snesrecomp_anchor_to_exe_dir` | `host_paths.c` | 1 | 1 | 1 |

The last row is the point of the log's own caveat: "which is a different claim, so the
table shows both kinds rather than a curated one" — a symbol that is already nonzero at
the pin is a hook the commit reached for, not a hook it added. The same section prints
the comment §7.20 quotes, with its line number, so the quote is a grep result:

```sh
3768:   * embedded bytes hash to. The check is the same one, not a weaker one. */
```

**§3 is the section §7.20's reference set was missing.** The personal transcript pairs
its payload against two reference builds and calls the difference between them "the
guest moving from a file into the executable"; that used to be an inference about two
checkouts nobody had diffed. The log diffs them. The state fix arrives on the personal
branch as a copy: "the personal branch has it as a cherry-pick", so hashes differ and
content has to be compared, which the log does twice — once by diffing the fix's own
files across the two branches, where "empty output above means those files are
identical on both branches, so the two frameworks do carry the same state code", and
once by hashing the files as each branch holds them: `runner/src/host_paths.c` is
`406bb22d7c05543a` on both branches and `runner/src/keybinds.c` is `188db8281348b28f`
on both. Then the whole-tree diff, "the whole of what separates the two trees":

```
  docs/validation/accuracy-history.md | 113 ++++++++++++++++++++++++++++++++++
  runner/src/desktop/host_main.c      | 118 ++++++++++++++++++++++++++++++++++--
  2 files changed, 225 insertions(+), 6 deletions(-)
```

two documentation commits that touch no code, and one host file — which the log states
as its own conclusion: "the two frameworks this round built from differ by one host
file: the guest." That is the witness §7.20 needed: same floor, same state code, and
the guest is the only difference between the framework behind the shareable payload and
the one behind the personal payload.

**§4 is what makes §8.1's framework citations greppable rather than remembered.** The
log prints each checkout's own `runner/runner.cmake` with line numbers: the
`option(SNESRECOMP_SDL3_FETCH` declaration and its `ON` default at `:90-91`, the
`set(SDL_SHARED OFF CACHE BOOL "" FORCE)` force at `:109`, the
`SNESRECOMP_SDL3_SOURCE_DIR` hook at `:117-121`, the pinned
`SNESRECOMP_SDL3_FETCH_VERSION "3.4.10"` at `:92` and its digest at `:94-95`. Then it
asks whether that file moves at all between the pin and the shipped clones, and
`git diff --stat pin..HEAD -- runner/runner.cmake` prints nothing for either, which is
what makes those line numbers the lines the shipped builds were configured from. The
framework also states the same release in its own `tools/ci/prefetch_sdl3.sh`
(`VERSION`/`SHA256` at `:16-17`, the URL it fetches at `:48`), and the two floor-11
caches state it a third time: `SNESRECOMP_SDL3_FETCH:BOOL=ON`,
`SNESRECOMP_SDL3_FETCH_VERSION:STRING=3.4.10`,
`SNESRECOMP_SDL3_FETCH_SHA256:STRING=12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785`
and `SDL3_SOURCE_DIR:STATIC=…/SDL3-3.4.10`, whose own `project(SDL3 LANGUAGES C VERSION
"3.4.10")` line the log prints beside them. Three kinds of file, one release: a wrong
checkout would read as a mismatch in this section instead of quietly changing payload
bytes.

Two prose quotes that previously had no committed witness — the embed commit's subject
and the `not a weaker one` comment — are in this log now, so the accept-list in
`tests/doc_quote_audit.py` no longer carries them. The limits of this artifact are the
limits of every other round here: it reads scratch checkouts by absolute path, so if
they are cleared the log cannot be re-derived, and "dirty 0" is a statement about the
checkout at run time, not about history.

### 7.25 Re-checking these sections against their witnesses (2026-11-10)

Six sections above, and the two recipes in §8, make their claims in one shape: a number
read out of a log, a transcript line in quotation marks, a fenced block of record. That
shape is only worth something if it gets re-checked, and this file has already shown the
two ways it rots — a figure carried forward after the log that measured it was pruned,
and a digest quoted one character shorter than the digest in the record.
`tests/doc_quote_audit.py` re-checks it mechanically, over §7.19 through §8.2:

* a fenced block that is not marked as a recipe has to reproduce inside the witness set,
  with `…` standing for whatever the record omitted and a machine-local path standing
  for one word;
* a recipe block is checked one command line at a time instead, so a recipe cannot
  invent an invocation that no record shows running;
* a double-quoted span in prose of 25 characters or more has to appear in the witness
  set verbatim. The marks are paired in the order they occur inside a paragraph, so a
  quotation that wraps across lines is checked as one span rather than as two halves
  whose tail nobody reads, and a paragraph carrying an odd number of them is itself a
  finding. Backticks are stripped from both sides, because they mark a code word in
  this file rather than a character the record printed;
* a hex token of 16 digits or more, or a comma-grouped byte count, has to appear there
  as a whole token rather than as a fragment of some longer number — and a byte count
  that is not in the record at all is accepted only as arithmetic on two witnessed
  operands of four digits or more, named in the same paragraph. That is how the 2,057 B
  between the packages' `size=13859` and `size=11802` CodeDirectory values is allowed,
  and it is also why a stray `flags=0x2` in a paragraph cannot pass as an operand;
* every artifact this range cites is compared byte-for-byte against the scratch log it
  was copied from, so editing an artifact after copying it is a finding.

The witness set is the committed evidence plus the scripts that emitted it, with two
tiers of git history above that, because not every round described here still has its
scratch directory on disk: an older *evidence* blob witnesses a quotation outright,
while an older revision of this README witnesses a quotation only where the prose beside
it names that revision — which is why one §7.19 anecdote is accepted with its `git show
21c1109:tests/README.md` citation next to it rather than waved through. Figures may use
either tier, since a measurement does not stop being a measurement when the page that
first printed it moved. The auditor excludes its own script, its own run log, and the
script that writes §7.26 and §7.27 from the witness set: all three contain this file's
text, and any one of them witnessing a quotation would be circular.

Two sections' transcript blocks are not typed here at all. `tests/doc_probe_sections.py`
writes §7.26 and §7.27 out of the two probe artifacts, and every fence in them is an
anchor span — a start line and an end line located in the artifact — so those blocks are
copies rather than retyped records, and an anchor that no longer matches stops the script
instead of leaving a stale block standing. The prose between the fences is this file's
own. Re-running the script against a document it already wrote leaves the file unchanged
byte for byte, which is why running it and reading `git diff` is a check rather than an
edit.

Its exit code is the count of untraceable findings, and its summary lines carry the pair
counts, so the claim that these sections hold needs a record of a run:

```sh
tests/run_doc_audit.sh
# log: tests/out/doc_audit/doc_quote_audit.log
#      = evidence/artifacts/doc_quote_audit.md
```

The wrapper is there because this log is one of the pairs the auditor compares, and a
single pass cannot be self-consistent: the pass that produces the committed copy runs
before that copy exists, so its own counts describe a tree that has just changed. It
iterates, saving each pass as both the log and the artifact, and stops when a pass
reproduces the saved text exactly; if three passes did not reach that point it says so
instead of committing counts that cannot be reproduced. On the tree as committed it
converges, and the pass it settles on leaves this file with nothing untraceable and
every cited artifact matching its log.

What it cannot check is relevance. `…`-elision lets a real-but-different span pass, and
a genuine hash belonging to another round's file witnesses nothing about the sentence it
is quoted in. The sections above keep naming the log and the section each figure is read
out of, and that is what a reader uses to check the relevant-ness part by hand.

### 7.26 Opening the shipped images the way a person opens them (2026-11-10)

§7.19 asks macOS's assessor about a built bundle and reads its exit code, and §7.23 proves the recipe
that builds it.  Neither of them *opens* the thing.  The complaint this packaging exists to answer is a
sentence a person reads on their own screen, and a sentence a person reads comes out of the open path,
not out of an assessor's status.  So `tests/macos_user_open_probe.sh` walks the whole user sequence
against both images in `dist/`: mount the `.dmg` read-only, copy the `.app` out with `ditto`, which is the
copy a drag-and-drop performs, ask whether this machine can exec those bytes at that path at all, open the
copy with the download flag cleared, put the flag back and open it again, and then ask whether the copy
that ran is still the bytes that shipped and still seals.

```sh
tests/macos_user_open_probe.sh
# log: tests/out/openprobe/user_open_probe.log
#      = evidence/artifacts/macos_user_open.md
```

The pass quoted here dates itself `2026-11-10T06:25:09Z`, runs every leg in a scratch directory of its
own, and prints its own finding count at the end of its log, which is also its exit status; that line is
the last fence below.

Two costs are stated in section 0 of its own log before any leg runs, because both of them change the
machine.  The legs go through LaunchServices, so their `$HOME` is whatever `open` relays, and they are
given a private one, and section 7 fingerprints this machine's real `~/Library/Application Support/`
before and after to show the relay held -- "A test has no business rewriting a person's saves."  The other
cost is a window on a person's screen, and the log's own words for that cost, and for the way every open
is read back, are:

```text
  two costs of doing this for real, stated before the legs rather than after:
    * the legs start through LaunchServices, so their $HOME is whatever 'open'
      relays.  They are given a private one, /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/state_home, and section
      6 checks this machine's real ~/Library/Application Support/ before and after
      to show the relay held.  A test has no business rewriting a person's saves.
    * the successful open legs are not headless: a real window and a real audio
      device open for the length of /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/scripts/shorter.txt -- 60 emulated frames, a couple of
      seconds of wall clock per run -- which is what makes them the click path
      rather than another dummy-driver re-run.
```

The waits are three numbers rather than one, because each belongs to a different shape of leg, and the
shortest of them is itself a measurement: "'open -W' never returns when LaunchServices refuses the launch
-- measured, its own wait sits there forever", so a longer cap on a refused launch would buy the same
answer and leave Gatekeeper's sheet on the screen the whole time.

```text
  three waits rather than one, and one of them is a cost paid on the user's screen:
    * 25s with no process at all ends a leg, because
      'open -W' never returns when LaunchServices refuses the launch -- measured, its
      own wait sits there forever -- so waiting out a longer cap would buy the same
      answer and leave Gatekeeper's sheet on the screen the whole time.
    * 30s caps a leg whose point is that it gets refused: measured on this
      machine, syspolicyd logs its own decision for this bundle about nine seconds
      after its prompt, so anything past that is only waiting.
    * 45s is the cap for a leg that started something and would not
      end, which is the shape of a window this harness cannot answer; such a leg is
      stopped by signal and recorded as hung.
```

**The exec is asked about before any leg that has to run the app is believed (§2 of the log).**  A machine
that cannot exec this code signature makes every later leg print a tidy-looking nothing while measuring
nothing, so the probe first starts that copy directly from a shell, with dummy drivers and its own
`$HOME`:

```text
  one question asked first, because a machine that cannot exec this code signature
  makes every leg below print a tidy-looking nothing while measuring nothing:
  is the exec of these bytes being held by macOS right now?
    started directly from a shell, dummy drivers, its own $HOME (/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/preflight_home),
    with the same /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/staged/shorter.txt every other leg runs:
     it ran and finished on its own: 29 line(s) of its own output,
     and its run report is /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/preflight_home/Library/Application Support/Shadowrun/last_run_report.json
     (--rom on this line because the shareable payload carries no image)
    exec is not held, so the legs that have to run the app can tell the difference
    between running, being refused, and being held.
```

That order is not caution for its own sake.  §7.27 measures that stopping a process macOS is holding at
exec leaves *that bundle's own directory* unable to exec at that path, and this probe says so at the head
of its own flag-cleared section:

```text
  this leg runs before the refusal leg on purpose.  A refused launch can leave a
  process held at exec while macOS waits for a sheet nobody in this run answers, and
  on this machine a path that had held one was measured still refusing to exec
  afterwards -- see section 2.shareable above and the end of section 7.  The claim
  that has to be measured here, that the copy a person ends up with after
  right-click -> Open starts, is therefore taken first, while the path is known to
  be able to run it.
```

**Flag cleared, then flag put back (§3 and §4).**  Clearing the download flag is what right-click → Open
leaves on disk, and it is the command the `README.txt` at the image root tells a person to type, so it is
done here rather than guessed; `spctl` still refuses either way, which the log explains rather than
leaves as a surprise:

```text
    Gatekeeper's assessment of the copy with no flag on it:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: rejected
      [exit=3]
    rejected is expected here too: an ad hoc, unnotarised signature never passes an
    assessment.  So the assessment is not what makes the app start for a person --
    their explicit choice, remembered by LaunchServices, is.  Which means the
    double-click below is the measurement, and this line is not.
```

and the double-click brings the app up as pid 77747, at the path the probe put it, with a real window and
a real audio device, 3s of wall clock, and a run report that ends `reason=atexit` with 60 host frames:

```text
     the leg's process was pid 77747, running from:
       /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app/Contents/MacOS/Shadowrun
     this leg took 3s of wall clock
     'open' exit=0
     (the 'open' command printed nothing on stdout or stderr)
     reading the state directories for the run this leg should have written:
     run report written by this leg: Library/Application Support/Shadowrun/last_run_report.json
      reason=atexit host frames=60 at 2026-11-10T06:25:23Z
      drivers: video=cocoa audio=coreaudio
```

With the flag put back on, the same `open` brings the same copy up again, and this time from a path this
probe never wrote:

```text
     the leg's process was pid 77849, running from:
       /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/AppTranslocation/2BAC3B75-A803-47BA-8609-C04F1F4096D9/d/Shadowrun.app/Contents/MacOS/Shadowrun
     this leg took 3s of wall clock
     that path is not where this probe put the copy: macOS applies App Path
     Randomisation (App Translocation) to a bundle that carries the download
     flag, and runs it from a randomised read-only path instead.  So the
     process is not the copy on disk, and asking whether that copy changed
     says nothing about it -- which is why the copy's own payload digest and
     tree hash are re-read in section 5.shareable rather than inferred here.
```

So the flag-on click of this pass was translocated and ran, and the log says so in its own summary --
"shareable (Shadowrun), flag on: the app came up as pid 77849 ('open' exit 0).  After the override: the
app came up as pid 77747 ('open' exit 0)." -- while keeping the two facts apart: an assessment refusal is
not an open refusal.  The word a person would have seen is counted in the system's own lines rather than
eyeballed, once per open leg, beside the number of lines that were looked at:

```text
        [log show exit=0: 71 line(s) from those two processes, 6 matched retroportingtoolkit|shadow|quarantin|gatekeep|xprotect|System Policy|damag|denied, and 0 of those contain the substring 'damag']
```

That line is printed four times in this pass, always with the same tail: "and 0 of those contain the
substring 'damag'".

**The copy that ran, asked what it still is (§5).**

```text
  payload after the open legs  37d08a86a2a86414
  bundle before the legs       11 entries, tree hash 61cd989abe7b934d
  bundle after the legs        11 entries, tree hash 61cd989abe7b934d
    unchanged: the app wrote nothing inside itself, through two open attempts,
    a real window, a scripted boot and a save.  That is the property the
    'is damaged' report says a copy of this port used to fail.
    its seal, asked after the run:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
    the directory holding the executable, after all of that -- every file in it
    other than the binary itself, which is where the pre-fix host wrote config.ini,
    keybinds.ini, rom.cfg and saves/ while running from inside a bundle:
    (expect nothing above: only the executable, which is why the whole-bundle
     seal is possible at all)
```

The personal package goes through the identical walk and gets the same answers: payload
`44a3da74ddca0062`, 11 entries and tree hash `fd40cfe3f6adccc1` before the legs and after them, a run
report at both opens, pids 78125 and 78018.

**Then the section this pass exists for: where a named path sits (§6).**  Every leg above names files
staged in the probe's own scratch directory, and the log is explicit that this is a measurement rather
than tidiness: "an earlier pass of this probe caught a copy started by 'open' with no run report and no
guest, sitting inside the open() of a ROM file that lives in this repository, and this repository sits
under ~/Documents."  The three paths, the three legs, and the pre-check on the fresh copy:

```text
  every leg above names files this probe staged in its own scratch directory, and that
  is a measurement rather than tidiness: an earlier pass of this probe caught a copy
  started by 'open' with no run report and no guest, sitting inside the open() of a ROM
  file that lives in this repository, and this repository sits under ~/Documents.  So
  the folder question is measured here, in the click path rather than from a shell, and
  the same bundle and the same bytes are used in each leg:
    a. the ROM path inside this repository, the script staged;
    b. the same ROM staged in this pass's own directory, the script staged;
    c. the ROM staged, the script inside this repository -- a script the app cannot read
       is a run that never receives its scripted quit, which looks like a hang.
  each leg is given a real window and audio driver, as the click path is, and is stopped
  after 30s whether or not it has finished.  Only leg a and leg c read this
  repository's own ROM file, and nothing here writes to it or to the script: the question
  is where a person's files sit, not what they contain.
  the personal package is not part of this section: its guest is inside the executable
  and no leg gives it a file path it would have to read.

  a fresh copy out of the shareable image, in a directory of this section's own:
    payload 37d08a86a2a86414  5953488 B  cdhash c8c8553aba8d7cfa26d89445d20aad08b6dc5d86
  asked whether that directory can exec it before any leg has stopped anything:
    run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun RAN   28 line(s) of its own output
```

```text
  the three answers, in one place: still there at 30s / run report newer
  than the leg.  A leg that finished on its own and left a report is a run; a leg still
  sitting there with no report is a process waiting on something.
    a. ROM in this repository          still there=0  run report=1
    b. same ROM, staged outside        still there=0  run report=1
    c. script in this repository       still there=0  run report=1
  (1 = yes, 0 = no; the sampler's frames and the lsof lines above name what each
  still-standing process was waiting on, in macOS's own words)
```

All three legs finished on their own inside the 30s cap and left a run report, so no process was still
standing and this pass has no sampler frames to place.  Leg a read the ROM where this repository keeps
it, leg b the same bytes staged outside it, and leg c the staged ROM with the script still inside the
repository; each is a run in the table above.

The sampler says where a standing process is waiting; only macOS's own agents can say why, so the log
dumps their window and prints its own counts first:

```text
    before the excerpt, the counts: 1723 line(s) logged by those four processes in
    that window, 403 of them match retroportingtoolkit|shadow|documents|denied|prompt|container|sandbox|deny once connection chatter is
    filtered out, and 71 of those name a denial or a prompt.
```

and then the service that answers a request to read a folder a person keeps files in, as its own counted
block rather than hoped to fall inside the first 40 time-ordered lines.  That block prints every
`kTCCServiceSystemPolicyAllFiles` line in the window, six of them here, under the script's own reason for
printing them in full rather than as a count -- wording written for the earlier pass that had something
parked, since this one had nothing standing:

```text
  and the 6 of those 403 that name kTCCServiceSystemPolicyAllFiles, the
  service whose answer is a yes or no about reading a folder a person keeps files
  in.  Those lines are the system's own answer to the request the parked open() is
  waiting on, so they are printed here in full rather than as a count: the time-
  ordered excerpt above can stop before they come.
    2026-11-10 07:26:08.396 I  sandboxd[29999:f5b8d0] [com.apple.TCC:access] SEND: 0/7 synchronous to com.apple.tccd.system: request: msgID=29999.657, function=TCCAccessRequest, service=kTCCServiceSystemPolicyAllFiles,
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] Background Session: service kTCCServiceSystemPolicyAllFiles from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}: determinedPlatformBinaryStatus: 1, clientIsApplePlatformBinary: 0, clientHasGraphicsAccess: 1, validRequester: 1
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] Handling access request to kTCCServiceSystemPolicyAllFiles, from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, ReqResult(Auth Right: Denied (Service Policy), promptType: 1,DB Action:None, UpdateVerifierData)
    2026-11-10 07:27:10.854 I  sandboxd[29999:f5bdc1] [com.apple.TCC:access] SEND: 0/7 synchronous to com.apple.tccd.system: request: msgID=29999.659, function=TCCAccessRequest, service=kTCCServiceSystemPolicyAllFiles,
    2026-11-10 07:27:10.864 I  tccd[161:f5b8dc] [com.apple.TCC:access] Background Session: service kTCCServiceSystemPolicyAllFiles from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78329, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}: determinedPlatformBinaryStatus: 1, clientIsApplePlatformBinary: 0, clientHasGraphicsAccess: 1, validRequester: 1
    2026-11-10 07:27:10.864 I  tccd[161:f5b8dc] [com.apple.TCC:access] Handling access request to kTCCServiceSystemPolicyAllFiles, from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78329, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, ReqResult(Auth Right: Denied (Service Policy), promptType: 1,DB Action:None, UpdateVerifierData)
```

The request is named, the answer is `Denied (Service Policy)`, and the code identity behind it fails
`anchor apple` with `status: -67050` and `matches platform requirements: No`.  Those six lines are what
macOS's agents logged around this pass's folder reads; they are the system's record of the requests, not
evidence that a process waited on them, and the legs above nevertheless ran and finished.  That is the
whole of what this pass claims about the folder.

**What the pass left on the machine (§7).**  The private `$HOME` holds exactly the state an opened app
creates -- `config.ini`, `keybinds.ini`, `rom.cfg`, `saves/` and the mod catalog, under both bundle names
-- and that listing is the evidence that the run wrote outside the bundle.  This machine's own state
directory is fingerprinted before and after:

```text
  and the check that the relay held: this machine's own ~/Library/Application
  Support/, fingerprinted before the legs and again now.  A new directory, a
  different file count, or a different fingerprint inside a directory that was
  already here, would all mean the legs wrote into this person's state after all.
    before:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    after:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    identical, which is the condition: the legs wrote inside the private $HOME
    above and a person running this probe loses nothing.
```

Nine reports sit in `~/Library/Logs/DiagnosticReports`, and how far that listing reaches is printed
rather than assumed:

```text
    9 report(s) in that directory, oldest by name: continuation-2026-11-05-122414.ips
   A copy macOS calls 'damaged' never reaches that directory, because the refusal
   happens in LaunchServices before any process exists; so an empty listing for
   these two executables is the shape of 'nothing of mine crashed', and a
   non-empty one is a crash to read.
    none.  No report in that directory, including ones this machine wrote long
    before this run, names Shadowrun or Shadowrun-personal -- so no process from
    either package ever died and wrote one, and the legs above ran both packages to
    a scripted quit with their own window and audio driver.
```

Then the check that only §7.27 makes worth having: the three directories this pass used are asked whether
they can still run their app, because the folder legs stopped processes.  This section offers renaming
the directory as the way out, and §7.27 is the section that measured a rename; this pass never needed it.

```text
  one last witness, and it is about this pass rather than about the payload.  The
  refusal leg stops a process macOS was holding at exec, and that act is measured --
  in tests/macos_exec_hold_probe.sh -- to leave the bundle's own directory unable to
  exec at that path, for as long as watching lasted and for every file inside that
  directory, while the same machine code at any other path runs normally.  So the
  directories this pass used are asked whether they can still run their app, and if
  they cannot, the measured way out is applied: renaming the directory, and then the
  same question asked after the rename and after putting it back.  A person should not
  be left with a directory whose app will not start because a test stopped something.
    shareable:
    run-20261110-072509/shareable/Shadowrun.app/Contents/MacOS/Shadowrun RAN   28 line(s) of its own output
    personal:
    run-20261110-072509/personal/Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal RAN   27 line(s) of its own output
    folder:
    run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun RAN   28 line(s) of its own output
    none of the 3 paths asked about is held: the stops this pass made left
    nothing behind, so the next pass of this probe, or a person dragging these copies
    somewhere else, is not walking into a path that cannot exec.
```

So "none of the 3 paths asked about is held", which is why that section leaves its scratch on disk for
reading rather than deleting it.  Section 8 closes the pass with the two opens per package, and then with
what it counted as unexpected:

```text
  shareable (Shadowrun), flag on: the app came up as pid 77849 ('open' exit 0).  After the override: the app came up as pid 77747 ('open' exit 0).  Through both, the copy kept the same entries and the same tree hash, and its seal afterwards exits 0.  The word 'damag' in macOS's own lines for the two legs: 0 and 0.
  personal (Shadowrun-personal), flag on: the app came up as pid 78125 ('open' exit 0).  After the override: the app came up as pid 78018 ('open' exit 0).  Through both, the copy kept the same entries and the same tree hash, and its seal afterwards exits 0.  The word 'damag' in macOS's own lines for the two legs: 0 and 0.

  nothing unexpected: every copy under test sealed before and after being opened,
  and no copy gained a file inside itself while it ran.  Gatekeeper's refusal of an
  ad hoc signature is the one refusal this machine cannot make go away, and it is
  measured rather than argued about.
```

```text
  what this probe counts as unexpected, and what it therefore returns: 0
  finding(s), and the exit status of this script is that number.  Read that as the
  summary of the sections above rather than as a verdict on its own: a 0 here means
  the things that matter held -- after the override each package came up, each copy
  kept the entries and tree hash it started with, each still sealed, no system line
  used the word 'damaged', no crash report exists for either executable, no process
  of either bundle is left running, and this machine's own state directory is byte
  for byte what it was before.
```

### 7.27 macOS holding an exec instead of refusing it (2026-11-10)

The open-path probe above stops processes in a state neither it nor §7.19's assessment legs can see from
the outside.  On this machine a quarantined copy can be started and then *not allowed to run*, with
nothing on screen saying it is damaged: a process exists, mapped, and never runs, and the path it sat at
can stay that way after the script that made it has exited.  `tests/macos_exec_hold_probe.sh` makes that
condition on purpose, from the shipped image, in a scratch directory of its own per pass, and measures how
long it lasts, how wide it is, and what clears it.

```sh
tests/macos_exec_hold_probe.sh
# log: tests/out/exechold/exec_hold_probe.log
#      = evidence/artifacts/macos_exec_hold.md
```

The pass quoted here dates itself `2026-11-10T05:56:12Z` and prints its own verdict at the end of its log
rather than leaving it to a harness:

```text
  exit status of this script, printed here so the log itself carries it: 0 --
  0 means the sections above agree with each other and the machine is as it was
  found, anything else means one of the checks counted a finding.
```

It also states its own cost up front, because the cost falls on a person: this probe puts Gatekeeper's
sheet on this user's screen three times, "each up for 30s and no longer, because syspolicyd logs its
decision for a bundle about nine seconds after its prompt."

```text
  this script deliberately puts directories of its own on this machine into a state where
  their app cannot start, and then measures what clears that state and what does not,
  removing the copies it made in order to measure.  Both halves are printed
  rather than asserted, because the open-path probe's design rests on them: its
  refusal leg stops a process macOS is holding at exec, so that probe takes a scratch
  directory of its own per pass, takes the leg that has to run the app first, and
  checks the paths it used at the end.
  every start here is direct, with dummy drivers, so no window and no audio device
  opens, and each one gets a private $HOME (/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/home).  The one thing that cannot
  be done quietly is section 2: making the condition needs a quarantined bundle
  opened through LaunchServices, and that puts macOS's own sheet on this user's
  screen.  Section 2 clicks twice and section 5 clicks once more, on a copy of its own,
  so that is three sheets, each up for 30s and no longer, because syspolicyd
  logs its decision for a bundle about nine seconds after its prompt.
```

**§2 makes the condition twice, and its two legs differ in exactly one thing -- whose code macOS is being
asked about.**  The log states that difference before it acts on it.  The first leg, on the bytes that
shipped:

```text
  leg shipped: opening payload/Shadowrun.app
    identifier org.retroportingtoolkit.shadowrun, cdhash c8c8553aba8d7cfa26d89445d20aad08b6dc5d86
    flag now on the bundle: 0081;6af2b20a;Chrome;
    what 'open' said in those 30s:
        (nothing)
    processes of this bundle alive now:
        none -- this launch ended rather than waited, so macOS refused it rather than
        holding it, and this leg leaves no condition to measure.
```

The second leg is those bytes re-signed ad hoc under a new bundle identifier, so its cdhash is one this
machine has never been asked about, which is the position a person is in the first time they open one of
these images.  The log prints the seal, the identifier, the cdhash, the payload digest and the payload
size on both sides of that re-signing, because its own comment says the word 're-signed' should not have
to be taken on trust:

```text
    the copy as it was copied out of the image:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: replacing existing signature
    the same copy after that re-signing:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
  identifier  org.retroportingtoolkit.shadowrun -> org.retroportingtoolkit.holdprobe1794290216
  cdhash      c8c8553aba8d7cfa26d89445d20aad08b6dc5d86 -> b159fec2ef53c0d77c7b59650e9abb048524c01f
  payload     37d08a86a2a86414 (5953488 B) -> 0376e0c30fb9ccec (5953488 B)
```

The two clicks answer differently, and the first one says so: "none -- this launch ended rather than
waited, so macOS refused it rather than holding it, and this leg leaves no condition to measure."  The
second one leaves a process standing:

```text
  leg fresh: opening fresh/Shadowrun.app
    identifier org.retroportingtoolkit.holdprobe1794290216, cdhash b159fec2ef53c0d77c7b59650e9abb048524c01f
    flag now on the bundle: 0081;6af2b228;Chrome;
    what 'open' said in those 30s:
        (nothing)
    processes of this bundle alive now:
        pid 73307 from:
          /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/AppTranslocation/4672ED85-0FE7-4B47-90ED-1B3A5424D977/d/Shadowrun.app/Contents/MacOS/Shadowrun
        2 mapped file(s),  0:00.01 of CPU
        after 31s of waiting.
        no run report newer than this open: nothing this launch started has reached
        the host's exit path, which is what a held exec looks like from the state
        side as well as from the process table.
```

and macOS's own sampler, asked about that process, puts it at dyld's entry point and nowhere else:

```text
        the sampler's own lines for its thread:
            877 Thread_16079907: Main Thread   DispatchQueue_<multiple>
              877 _dyld_start  (in dyld) + 0  [0x1022609c0]
```

"that is dyld's entry point, named in the sampler's own words: the process exists and has not been allowed
to start, and the only 2 file(s) mapped are the executable itself and the dynamic linker.  A held exec."
syspolicyd, which is Gatekeeper's decision-maker, says which kind of answer that click was:

```text
        what macOS's own agents logged for this leg -- syspolicyd is Gatekeeper's
        decision-maker and CoreServicesUIAgent draws the sheet:
        2026-11-10 06:56:56.992 Df CoreServicesUIAgent[59804:f55bef] [com.apple.launchservices:uiagent] GKQuarantineResolver initWithProperties: <private>
        2026-11-10 06:56:56.994 Df CoreServicesUIAgent[59804:f55bef] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareCheckEnded:result:forURL:]: XProtect defer executable analysis: true
        2026-11-10 06:56:56.994 Df CoreServicesUIAgent[59804:f2a4bc] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareChecksFinished]_block_invoke: XProtect suppress first launch warning: true
        2026-11-10 06:56:57.109 E  syspolicyd[231:f55963] [com.apple.syspolicy.exec:default] Error Domain=GatekeeperPolicyScanError Code=-67018 "Code did not match any currently allowed policy" UserInfo={NSURL=<private>, NSLocalizedDescription=Code did not match any currently allowed policy}
        2026-11-10 06:56:57.282 Df syspolicyd[231:f55c29] [com.apple.syspolicy.exec:default] GK evaluateScanResult: 0, PST: (path: cbf44b80f5a3e7f6), (team: (null)), (id: org.retroportingtoolkit.holdprobe1794290216), (bundle_id: org.retroportingtoolkit.holdprobe1794290216), 1, 0, 1, 0, 0, 0, 0
        2026-11-10 06:56:57.283 Df syspolicyd[231:f55c29] [com.apple.syspolicy.exec:default] Prompt shown (6, 0), waiting for response: PST: (path: cbf44b80f5a3e7f6), (team: (null)), (id: org.retroportingtoolkit.holdprobe1794290216), (bundle_id: org.retroportingtoolkit.holdprobe1794290216)
        of those lines, 0 contain 'damag'
```

and the log counts its own headline word in the lines of all three clicks -- "of those lines, 0 contain
'damag'".  A held exec is not momentary either: §3 takes one such process, asks it nothing, and watches it
for two minutes.

```text
    watched rather than assumed: the same pid, asked nothing, for 120s.
      20s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      40s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      60s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      80s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      100s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      120s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
    still the same process, still no output, still those same mappings: the hold did
    not resolve on its own inside 120s.  Stopped to keep watching.
```

"still the same process, still no output, still those same mappings: the hold did not resolve on its own
inside 120s."

That same mapping count is also why these two probes are separate scripts, and the hold log says why: "the
mapping count alone cannot keep those shapes apart: a copy started by a click and told to read a file
under ~/Documents was measured with the same two mapped files and its main thread inside open()."  So
every `held` in this artifact means the sampler named dyld's entry point, and a live process the sampler
cannot place there is printed as `-1` and "reported as neither held nor run" rather than counted as one of
the two.

**What the hold is not keyed to (§4).**  While the held path stays held, the payload is asked at three
other paths, each with its own cdhash printed beside it and compared against the held one rather than
assumed equal:

```text
  three more copies, each with its cdhash printed next to it, each asked the same
  question at a path this run has never stopped a process at.  The cdhashes are
  compared rather than assumed equal, and the image's own payload is called out when it
  is a different code from the held one.
  a) bare Mach-O at a path of its own        0376e0c30fb9ccec  cdhash b159fec2ef53c0d77c7b59650e9abb048524c01f  same-code
    bare-copy: started Shadowrun from run-20261110-065612/Shadowrun
       no process left: it ran and finished on its own, 29 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
  b) a fresh ditto of the whole bundle       0376e0c30fb9ccec  cdhash b159fec2ef53c0d77c7b59650e9abb048524c01f  same-code
    second-bundle: started Shadowrun from run-20261110-065612/copy2/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 28 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
  c) the payload inside the image itself     37d08a86a2a86414  cdhash c8c8553aba8d7cfa26d89445d20aad08b6dc5d86  different-code
    in-image: started Shadowrun from run-20261110-065612/mnt2/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 28 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
      "disk6" ejected.
```

```text
    2 of these three paths carry exactly the held code, and all three of them ran
    while the path section 3 named stayed held.  So at this moment on this machine that
    cdhash was held at one path and let through at 2 others, and a third path -- a
    different code, as its own column says -- ran as well.  The hold at that one path is
    not an effect of those bytes.  What it is keyed to is what section 5 measures, and
    that section prints its answer whichever way it falls.
    (line c is marked different-code: the payload inside the image and the copy this run
```

A hold at one path, for a cdhash that runs at two other paths, is not a verdict about those bytes.

**How wide the held place is, and what clears it (§5).**  A second file name inside the same bundle is
held too, at the same dyld entry point, so what is held is the bundle directory rather than one path
string:

```text
  first, the width: the same bundle, the same directory, a second file name inside it.
  If the hold covers that too, it is the directory rather than the file.
    other-name: started Shadowrun2 from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun2
       pid 73609 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           878 Thread_16082480: Main Thread   DispatchQueue_<multiple>
             878 _dyld_start  (in dyld) + 0  [0x1037e49c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
```

Then four things a user-level process can do are tried against that held path, in order, each followed by
the same direct probe there, and the log states why the order matters before it starts:

```text
  each line is one thing a person or a script could do to the held path, followed by the
  same direct probe there.  The order of these lines is part of what they mean: an
  intervention can only be credited with clearing a path if that path was still held when
  it was asked, so once one of them has made the path able to exec again, every probe
  after it on that same path is measuring a path that was already clear.  The first one
  after which the path ran is printed at the end of this list for that reason.
```

The four are `spctl` asked to assess the bundle again (still `rejected`, `[exit=3]`), `xattr -c -r`,
`lsregister -f`, and `killall -KILL` to this user's own CoreServicesUIAgent.  Only the last one is
followed by a path that runs, and the log prints the pid before and after so that 'restarted' is not a
guess:

```text
    this user's own UI agent sent SIGKILL -- the signal that ends a process rather than
    asking it to stop.  launchd relaunches it on demand; its root-owned decision-maker
    syspolicyd cannot be reached at all without a password, and this script does not
    ask for one.  The pid before and after says whether it actually restarted, and the
    label below says SIGTERM-to-SIGKILL rather than 'restart' for the reason this line
    prints: an earlier attempt here used killall with no signal, which sends SIGTERM, and
    the pid was simply still there afterwards, so that line measured nothing.
      before: 59804
        killall exit=0
        after:  (not running)
    after-uiagent: started Shadowrun from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 28 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
    of these four, the first after which this path ran again was number 4:
    4, the SIGKILL sent to this user's UI agent.
```

The fifth question -- does renaming the directory the bundle sits in move the hold -- is deliberately *not*
in that list, and the log says why: "an earlier pass of this script asked the rename about a path one of
these four had already cleared and read that as the rename's own answer."  The rename gets a hold of its
own instead, made by the same recipe in a fresh directory, with a third bundle identifier and cdhash, and
the log prints the re-signing that made them:

```text
  the rename, on a hold of its own.  A second copy of the payload, a new bundle
  identifier, a fresh ad hoc signature over it, the download flag, one click, the stop:
  the same recipe section 2 used for its leg b, in a directory of this run's that
  nothing else has touched.  Then the directory holding the bundle is renamed aside,
  the app is asked to run from there, the directory is put back, and the app is asked
  to run at the original path again.
    the second copy, before the re-signing:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: replacing existing signature
    the second copy, after it:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
  identifier  org.retroportingtoolkit.shadowrun -> org.retroportingtoolkit.holdprobeb1794290524
  cdhash      c8c8553aba8d7cfa26d89445d20aad08b6dc5d86 -> 666a0c5239660495d6073848689721b371e8bbc0
  payload     37d08a86a2a86414 (5953488 B) -> b158c5eea5e2ca7e (5953488 B)
```

and that new path is confirmed held by the sampler before anything at all is done to it:

```text
    again-second: started Shadowrun from run-20261110-065612/fresh2/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73867 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           877 Thread_16084113: Main Thread   DispatchQueue_<multiple>
             877 _dyld_start  (in dyld) + 0  [0x1024289c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
```

"that path is held, and nothing but the click and the stop has touched it."  Then the directory moves
aside, the app is asked there, the directory goes back, and the app is asked at the original path again:

```text
    that path is held, and nothing but the click and the stop has touched it.  Now the
    directory that holds the bundle moves aside:
        /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2 -> /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2-moved
    rename-on-fresh-hold: started Shadowrun from run-20261110-065612/fresh2-moved/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73899 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           878 Thread_16084274: Main Thread   DispatchQueue_<multiple>
             878 _dyld_start  (in dyld) + 0  [0x1057809c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    and the directory put back the way it was, to ask whether the original path is
    held again:
        /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2-moved -> /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2
    back-at-fresh-path: started Shadowrun from run-20261110-065612/fresh2/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73930 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           880 Thread_16084423: Main Thread   DispatchQueue_<multiple>
             880 _dyld_start  (in dyld) + 0  [0x101cc09c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
```

and then the copy control, asked twice, because a copy tool that keeps extended attributes carries the
download flag across and this run measured that the flag plus a click is what makes the condition at all:
"So a copy that still carries it is a fresh Gatekeeper question rather than a control on these bytes", so
the copy is asked with the flag and then with the flag taken off:

```text
    and that same held bundle copied to a path of its own, so a hold that stayed with
    the file through a rename can be told from a hold on those bytes wherever they sit.
    That copy is asked twice, and the difference between the two questions is printed
    first: the download flag this section wrote on the original for its click is carried
    across by a copy tool that keeps extended attributes, and section 2 measured that
    flag plus a click is enough to make this condition at all.  So a copy that still
    carries it is a fresh Gatekeeper question rather than a control on these bytes, and
    it is asked as one and then asked again with the flag taken off it:
    attached data on the held bundle this copy was made from: [com.apple.quarantine: 0081;6af2b35c;Chrome; ]
    attached data on the copy as it stands:                   [com.apple.quarantine: 0081;6af2b35c;Chrome; ]
  copy at a new path  cdhash 666a0c5239660495d6073848689721b371e8bbc0  same-code-as-the-held-file
    copy-flag-on: started Shadowrun from run-20261110-065612/fresh3/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73979 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           877 Thread_16084605: Main Thread   DispatchQueue_<multiple>
             877 _dyld_start  (in dyld) + 0  [0x10624c9c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    attached data on that same copy now the flag is off it:   []
    copy-flag-off: started Shadowrun from run-20261110-065612/fresh3/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 74013 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           879 Thread_16084770: Main Thread   DispatchQueue_<multiple>
             879 _dyld_start  (in dyld) + 0  [0x1042f49c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
```

and both questions are held.  The log's own answer for the rename, and for the difference between this
cdhash and the one §4 asked about at three paths that ran:

```text
    the rename did not move this hold: the same bundle, the same cdhash, the same
    file, still held at the path its directory was moved to and still held at the
    original path once that directory was put back.  A directory rename is therefore
    not a remedy on this machine, and the hold does not follow the name of the path
    the bundle is asked at.  What it does follow is not measured here.
    and the copy says the same thing about this code from the other side: it was
    held at a path of its own as well, both with the download flag this run had
    written for its click and with that flag then taken off it.  So for this code
    nothing this script can reach from user level moved the hold -- not the path the
    bundle sat at, not the name that path was renamed to, not a copy of the whole
    bundle made at a path this run has never stopped a process at, and not the flag.
    One difference between this code and the code section 4 asked about at three
    paths that ran is worth naming rather than glossed: they are different cdhashes,
    printed in both places above, and between those two sets of answers sits the one
    thing this run did to macOS's own agent -- the SIGKILL that made the first path
    able to exec again.  Which of those two its answer turns on is not measured here.
```

So nothing this script can reach from user level moved that hold, and the log refuses to guess why the two
cdhashes answered differently: "Which of those two its answer turns on is not measured here."

**Two housekeeping claims, because they are what makes the pass safe to run at all.**  The copies section
5 made are taken away by that same section, so a pass cannot leave a held bundle standing on the machine:

```text
    this section made /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2, /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2-moved and /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh3 only to be
    measured, and all three are removed here, so nothing this section may have left
    held stays standing on the machine.
```

and every direct start in the probe runs under a private `$HOME`, with the machine's own state directory
fingerprinted before and after:

```text
  this machine's own ~/Library/Application Support/, fingerprinted before the run and
  now:
    before:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    after:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    identical: the private $HOME relay held, and a person running this loses nothing.
```

Nine crash reports were on this machine, and the log reads their emptiness as part of the finding:

```text
  crash reports: 9 in ~/Library/Logs/DiagnosticReports, oldest by name:
    continuation-2026-11-05-122414.ips
    none of them names Shadowrun or Shadowrun-personal.  That includes the processes
    stopped by SIGKILL above: a process macOS never let start writes no report, which
    is part of why a held exec and a crash are different complaints.
```

and §7's own line for this section is a row of marks rather than a sentence:

```text
  the shapes this run leaves on the page, one line each:
    * a held exec is a live process whose sampler call graph names dyld's entry point
      and nothing else; a refused launch is a process that ends.  tests/macos_user_open_
      probe.sh keeps them apart rather than reading both as 'no run report'.
    * the mapping count alone cannot keep those shapes apart: a copy started by a click
      and told to read a file under ~/Documents was measured with the same two mapped
      files and its main thread inside open().  So every 'held' above rests on the
      sampler naming dyld's entry point, and a live process it cannot place there is
      reported as neither held nor run.
    * which copy carries which cdhash is printed next to each click in section 2, and
      section 4 marks every other path it asks as the same code as the held one or a
      different one, rather than assuming it.
    * the payload execed at its path before the condition was made: 0 (0 = it
      ran).  The two clicks in section 2 left a process standing: shipped copy=0,
      re-signed copy=1 (1 = a process was there to stop, 0 = the launch ended).
      At the paths they used, after those stops: shipped=0,
      re-signed=1, and the path the rest of the run measured is the fresh
      copy: 1 (1 = held).
    * the other paths section 4 asked about: bare copy=0 second bundle=0 inside the image=0 (0 = ran, 1 = held, -1 = alive but not at dyld's entry point, and each one is marked same-code or different-code beside its cdhash).
    * second file name in the same bundle=1, spctl=1, xattr -c=1, lsregister=1, UI agent SIGKILL=0 (1 = still held, 0 = ran).  The first of those four after which this path ran again was number 4 (4, the SIGKILL sent to this user's UI agent); every line before that number was asked of a path that was still held when it was asked, and the list stops at that number.
    * the rename was measured on a hold of its own, in run-20261110-065612/fresh2: that hold formed=1 (1 = it did), the same bundle asked at the moved path=1 and at the original path again=1, and a copy of that held bundle made at a path of its own asked twice -- with the download flag it was copied with=1 and with that flag taken off=1 (1 = still held, 0 = ran, -1 = not asked or alive but not at dyld's entry point).  Those copies are removed at the end of section 5, so this pass leaves no copy of them standing.
    * the machine: state unchanged, no report naming either executable, no process of this bundle left, and the bundle the rename was measured on removed rather than left in a held directory.

  nothing unexpected.
```

What this is for is not a claim that the payload is broken.  It is the reason §7.26 is built the way it is:
its own scratch directory per pass, the leg that has to run the app taken first, and a check of the paths
it used at the end -- because a held exec is a thing that *stays* on the machine after the script that
made it has exited.

## 8. Rebuilding from source (the two shapes this machine has built)

Two recipes live in this section, and which one a claim belongs to matters. §8.1 is
the current one: it is what the shipped packages are built from. §8.2 is the shape
that staged the `./Shadowrun` at the repository root — it predates the floor work
and is kept in full, because §7.5, §7.17, §7.18 and §7.20 measure that file and
because `evidence/c0_rom_free.md` refers to these steps as "§8 of
`tests/README.md`".

### 8.1 The current recipe: what the shipped packages are built from

`tests/out/m11_build.log` prints its own `cmake` and `cmake --build` lines as they
run, and `tests/macos_floor11_check.sh` (§7.23) replays the first of them in a
directory that did not exist when it started — so the recipe is on the record
twice: once as a relink inside trees that already had objects in them, once from an
empty directory.

```sh
# 1. regenerate the port's generated C from the ROM (verifies digests first)
bash tools/regen.sh --rom "/path/to/Shadowrun (USA).sfc"
# 2. configure + build at the deployment floor, SDL3 fetched and linked statically
cmake -S . -B build-ship-m11 -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT=/path/to/the/framework/checkout \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
      -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON \
      -DFETCHCONTENT_SOURCE_DIR_SDL3=/path/to/SDL3-3.4.10 \
      -DSNESRECOMP_ENABLE_MODS=ON
# <tree> stands for the two recorded tree names, build-ship-m11 and
# build-embed-ship-m11, and -j 12 is as those logs write it
cmake --build <tree> -j 12
# 3. seal and package: the .app, its signature and the .dmg all happen here
scripts/package_macos_bundle.sh build-ship-m11 macos-arm64
```

Those are the recorded lines with the two machine-local paths written as
placeholders and the build directory as `<tree>`; the `-j 12` is the flag those logs
write, and `tests/macos_floor11_check.sh` §1 prints its own `cmake` and
`cmake --build` lines unelided, in
`evidence/artifacts/macos_floor11_rebuild_build.md`'s sibling log, and the floor
probe's own header carries the rest of the toolchain as measured:
Darwin 25.6.0 arm64, macOS 26.7.1 (25G241), cmake 4.4.5, Apple clang 21.0.0
(clang-2100.1.1.101), SDK `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`
26.5. The personal variant is step 2 with a different `-DSNESRECOMP_ROOT` plus
`-DSHADOWRUN_EMBED_ROM=ON` (`CMakeLists.txt:118`), whose configure step stops with
a message if the image cannot be found (`CMakeLists.txt:141`).

Four things that recipe does not make obvious:

* **No `CC=` / `CXX=` prefix.** Both the shipped tree and §7.23's clean rebuild
  record `CMAKE_C_COMPILER=/usr/bin/cc` and `CMAKE_CXX_COMPILER=/usr/bin/c++` in
  their caches — Apple clang. The `CC=/opt/homebrew/opt/gcc/bin/gcc-16 CXX=g++`
  prefix this recipe used to carry is what the older rounds built with
  (`evidence/a2_aot_batch.md`, `evidence/c0_rom_free.md`, `evidence/c1c_framework_copy.md`),
  and it is a real input: `evidence/c1c_framework_copy.md` measures the same pin
  tree linking 3,294,704 B under gcc-16 against 2,900,080 B under clang, 394,624
  bytes apart. Do not carry that prefix when reproducing the shipped bytes.
* **`-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON` is the flag that reaches 11.0.** §7.22
  §1 measured `build-osx11` setting the same deployment target and still needing
  macOS 26.0, because `find_package(SDL3)` found Homebrew's dylib (minos 26.0) and
  dyld enforces the highest floor among the files it loads. With the find disabled,
  the framework's own `SNESRECOMP_SDL3_FETCH` (ON by default,
  `runner/runner.cmake:90-91`) builds SDL3 from source and forces
  `set(SDL_SHARED OFF CACHE BOOL "" FORCE)` (`runner/runner.cmake:109`), so the
  executable carries its SDL and the bundle has one Mach-O instead of two. Those
  line numbers are not retyped from the framework:
  `evidence/artifacts/macos_framework_commits.md` §4 greps them out of the same
  checkouts §0 names, and prints `git diff --stat pin..HEAD -- runner/runner.cmake`
  as empty for both shipped clones, so the file cited is the file those builds were
  configured from.
* **`-DFETCHCONTENT_SOURCE_DIR_SDL3` is CMake's own override, and it took.** The
  cache records the result as `SDL3_SOURCE_DIR:STATIC=…/SDL3-3.4.10` and `_deps/`
  holds only `sdl3-build`, so nothing was downloaded. The framework has a second
  hook of its own (`SNESRECOMP_SDL3_SOURCE_DIR`, `runner/runner.cmake:117-121`) and
  pins the release itself: `SNESRECOMP_SDL3_FETCH_VERSION "3.4.10"` at
  `runner/runner.cmake:92`, tarball sha256
  `12b34280415ec8418c864408b93d008a20a6530687ee613d60bfbd20411f2785` at `:94-95`, and
  the same version and digest in its own `tools/ci/prefetch_sdl3.sh:16-17`, which
  fetches the URL that script's `:48` builds. All of it is grep output in
  `evidence/artifacts/macos_framework_commits.md` §4, which also prints that source
  directory's `project(SDL3 LANGUAGES C VERSION "3.4.10")` line beside the
  framework's two constants, so a wrong checkout shows up as a mismatch instead of a
  different payload.
* **`Release` matters** (an unoptimised build costs ~2× the CPU per frame, 1.45 MB
  of machine code vs 2.57 MB) and `-DSNESRECOMP_ENABLE_MODS=ON` matches the shipped
  trees — `CMakeLists.txt:35` already defaults it to ON, so passing it is pinning,
  not enabling.

The framework named by `-DSNESRECOMP_ROOT` is **not** the pin, and that is a
capability requirement rather than a style choice: a bundle staged from the pinned
layout cannot be sealed at all, which §7.21 measures on one machine with two
executables. The shareable package's tree is one commit past
`773285b8210f…` (the state-out-of-the-bundle host fix) and the personal one is that
fix plus the embed work on a separate clone; every section that names one of these
payloads prints its framework from that tree's own `CMakeCache.txt`, and
`tests/provenance.py pin --descendant` reports such a tree as
`OFF THE PIN … a branch off the pin, fine for a capability leg`.

What a run of step 2 and step 3 does and does not reproduce:

| what | bytes | from a build alone? |
|---|---|---|
| `build-ship-m11/ShadowrunSNESRecomp` | `092b0e690cab97a1` 5,970,048 B | **yes** — the recorded relink (§7.22 §6) and an empty directory (§7.23), `cmp` finding no differing byte |
| `dist/Shadowrun.app/Contents/MacOS/Shadowrun` | `37d08a86a2a86414` 5,953,488 B | **no** — only with step 3, because the whole difference is the ad-hoc seal (§7.19 §5a) |
| `dist/shadowrun-0.1.0-macos-arm64.dmg` | `fe2648738fad58a6` 2,221,175 B | **no** — `hdiutil` stamps volume dates and UUIDs, so a `.dmg` hash pins a run (§7.19 §5g) |
| root `./Shadowrun` | `60067549c3ee8d3b` 3,103,872 B | **no** — that is §8.2's shape, and it disagrees with these bytes on purpose |

### 8.2 The dated recipe: what staged `./Shadowrun`

Running the steps below is what produced the 3,103,872 B `60067549c3ee8d3b` at the
repository root: `minos 26.0 sdk 26.5`, and `@executable_path/libs/libSDL3.0.dylib`
among its load names — which is why §7.19 §3 prints it as "differs from
`./Shadowrun`", and why §7.20 calls that consistent rather than stale. §7.18 records
how the tree behind it was configured: `evidence/README.md` says it was "configured
from nothing but the pin and the two documented flags", and
`evidence/c1_staged_bundle_stale.md` says the same in its own words. That tree's
payload is `a0587ed0a0e34687` at 3,103,776 B, 96 B below the staged file, and
`tests/bundle_verify.sh` §1 is where that step is printed on both sides — build-tree
bytes and staged bytes, sizes included — while `evidence/README.md` §c1 and
`evidence/c1_staged_bundle_stale.md` both account for the 96 B as the install-name
edit plus the re-sign.

Unlike §8.1's block, this one is not a command line any transcript records, so it is
kept to the part that is recorded. Step 2's configure is written the way
`evidence/c1c_framework_copy.md` records one of that period's trees — the compiler
flags inside the `cmake` line rather than as a `CC=` prefix, the tree name and the
framework path left as placeholders because both changed per round — and
`make -C <tree> -j8` is that file's build step. The staging step is deliberately
*not* printed as a command line, because the older evidence records it as operations
and writing plausible ones would invent a record. What is on the record:
`evidence/README.md` §c1 gives a scratch copy "given only `install_name_tool -change`
and `codesign --force --sign -`" and accounts for the 96 B between build-tree and
staged bytes as that edit plus the re-sign; `evidence/c1_staged_bundle_stale.md`
records the same 96 B for this tree; and where the pair runs as code today is
`tests/bundle_verify.sh` §1, whose own lines say "install_name_tool rewrites the SDL
reference and codesign re-signs, so the hash differs and the size grows by the link
edit", and `scripts/package_macos_bundle.sh` §3, which performs the same two
operations on its probe copies.

```sh
# 1. regenerate the port's generated C from the ROM (verifies digests first)
bash tools/regen.sh --rom "/path/to/Shadowrun (USA).sfc"
# 2. configure + build against an installed SDL3, the way this port's older rounds
#    configured: gcc-16 for C, Apple clang for C++, and no deployment-target flag,
#    so this shape takes this machine's floor of 26.0, which §7.22 measures.
cmake -S . -B <tree> -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=/opt/homebrew/opt/gcc/bin/gcc-16 -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DSNESRECOMP_ROOT=/path/to/snesrecomp \
    -DSNESRECOMP_ROM="/path/to/Shadowrun (USA).sfc" -DSNESRECOMP_EMBED_ROM=OFF
make -C <tree> -j8
```

**Which flags the tree whose bytes are at the root actually had is read back, not
reconstructed.** `tests/out/floor/macos_deployment_floor.log` §1 prints
`build-ship`'s own cache: `CMAKE_BUILD_TYPE:STRING=Release`, an empty
`CMAKE_OSX_DEPLOYMENT_TARGET:STRING=`, `SDL3_DIR:PATH=/opt/homebrew/lib/cmake/SDL3`,
`SNESRECOMP_SDL3_FETCH:BOOL=ON`, `SHADOWRUN_EMBED_ROM:BOOL=OFF`, and `SNESRECOMP_ROOT`
at the pinned clone with `dirty 0`. That is why the block above carries no
`-DSNESRECOMP_SDL3_FETCH=OFF`: this tree reached Homebrew's dylib through the
framework's own SDL3 route, and it is the dylib's `minos 26.0` — not the port's
compile flags — that puts this shape's floor at 26.0 (§7.22 §1, whose row for
`build-ship` says so in one line).

**The compiler in that block is a real input and it is not the shipped one.**
`evidence/c1c_framework_copy.md` measures the same tree at the same pin linking
`3,294,704` bytes under gcc-16 against `2,900,080` under clang — `394,624` bytes
apart — which is why that file insists a control's `CMakeCache` name the same
compilers as the leg it faces. `build-ship`'s cache is not part of this round's
measurements, so the compiler behind `a0587ed0a0e34687` is not claimed here; what is
claimed is that neither shipped tree nor §7.23's clean rebuild used gcc-16 — their
caches say `/usr/bin/cc` and `/usr/bin/c++` (§8.1's first bullet) — so this section's
sizes are not comparable with §7.19, §7.20 or §7.22 as if they came from one build.

`tools/regen.sh` takes the ROM from `SNESRECOMP_ROM`, else a known filename at the
repo root, else the path in `rom.cfg` — `--no-verify` skips the digest check for a
revision this project has not been pinned to, and `--cfg-roots` seeds analysis from
every func declaration in `recomp/*.cfg`. Generated C is never committed: it is
derived from ROM data, so every developer regenerates it from their own copy, and
`rom_identity.txt` is the single place the digests live. Changing `project()` or
`add_executable()` in `CMakeLists.txt` invalidates the CMake cache — delete the tree
before reconfiguring; the clean-tree check in §7.23 takes the same position by
`rm -rf`-ing its own tree every run rather than reusing one.

What end-to-end verification of these sources plus a framework against the accepted
bytes looks like today is §7.18: `build-ship` reaching `a0587ed0a0e34687` in two
separate trees, and
`SHIP=build-ship PORT_BIN2=tests/out/Shadowrun_prev_ebca100c bash tests/bundle_verify.sh`
agreeing frame for frame with the previously staged bundle
(`evidence/artifacts/bundle_verify.md`). An earlier form of this paragraph cited
`tests/out/Shadowrun_prev` and a pair of `cpu_seconds` readings; that scratch binary
is gone with the 2026-11-09 pruning and no committed log carries those two numbers,
so the claim is recorded only where an artifact backs it.

The framework revision this port is pinned against needs two patches to build on
macOS in the first place (`_DARWIN_C_SOURCE` in `lib/recomp-net/src/nat/rnet_host_relay.c`,
and `$GC_SECTIONS_LINKER` in `tests/run_c_tests.sh` so the C suite stops passing
GNU-only `-Wl,--gc-sections` to `ld64`). Measured on this machine today with
`git merge-base --is-ancestor <commit> origin/main` in the pinned clone: `27e95bb`
(the recomp-net submodule pointer) and `c9de5e9` are both ancestors of the pin
`773285b8210f…`, and **neither is in `origin/main`** — the pin itself is not either.
The pinned clone sits 3 commits past `origin/main` and 106 behind it as of the last
fetch; the working clone at `~/Documents/work/snesrecomp` is 5 past and 106 behind at
`76eda6dd`, the two extra commits being the docs-only rulings `8d9f999` (Axis 6) and
`76eda6d` (Axis 2), which came after the pin. A fetch moves those counts; what does
not move is that none of this rebuilds from upstream `snesrecomp` as published.

## 9. Input script grammar

`--script <file>`, one command per line, `#` starts a comment:

| Command | Meaning |
| --- | --- |
| `wait N` | N frames before the next command |
| `press <buttons> [N]` | hold `a+b+...` for N frames (default 1); P2 buttons get a `p2:` prefix |
| `loadstate N` / `reset` | hotkey equivalents |
| `turbo on\|off` / `renderer toggle` | host-control toggles |
| `poke <addr> <hex>` / `pokefor <addr> <hex> N` / `forcepoke <addr> <hex>` | write WRAM bytes |
| `until <addr> <op> <hex> [timeout]` / `until16 ...` | block until a WRAM byte/word matches; op is `==` or `!=`, timeout in frames (default 36000, exit 3) |
| `dump <tag>` | write the scene state dump into `$SNESRECOMP_DUMP_DIR` |
| `quit` | exit the process |

Buttons: `a b x y l r up down left right start select` (`back` = select), plus
`l3`/`r3`. `until` is what makes a run self-verifying instead of
timing-dependent. To find addresses worth waiting on, dump every frame's WRAM
and look for bytes that step a few times rather than every frame:

```sh
./tests/headless.sh tests/scripts/menu.txt --framedump tests/out/frames
python3 tests/find_state_bytes.py tests/out/frames
```

That is how `$7E01C92` was identified as the game's tick counter in §2.

One measured gotcha with `until`: the address is bare hex into the 128 KiB WRAM
window — `until16 1f2 == 6d00`, not `until $21a0 == 42 400`. A malformed line
is *skipped*, not fatal: the runner prints `script: bad until line: …` and
carries on, so the gates silently vanish and every later `dump` lands at the
wrong moment. Read the `script:` lines at the top of each leg log before
trusting a tail — one probe leg died exactly this way, and only its first
checkpoint was worth reading.

## 9.1 Frozen route scripts (regression corpus)

Four scripts in `tests/scripts/` walk the tested route step by step. Each
re-runs deterministically against the same SRAM snapshot (parity.sh
snapshots/restores `saves/save.srm` before every run):

| script | covers | landmark dumps |
| --- | --- | --- |
| `door.txt` | boot → morgue, open the exit door via the R-cursor submenu | `R1` |
| `nav1.txt` | + hallway transition + hallway walk | `H8` |
| `nav2.txt` | + street, punk dialogue, Dark Alley entry | `J10` |
| `combat.txt` | + alley prologue: screen-transition gates, park on the kill screen, end alive — 22,044 frames | `H8`, `J1`–`J10`, `A0`–`A5` |

`combat.txt` deliberately stops before the assassin's shot: the alley is a
scripted kill scene (see §7.8), so an ending past it measures a corpse. The
Beretta **pickup** is proven but lives in the alley probe, not this route —
the approach that reaches the gun does not put both execution paths in the
same place, and **equip is unproven on both paths**: every fight attempt
answers `You are not armed yet!`.

Game mechanics these scripts depend on (learned from dumped frames; they
explain otherwise-inexplicable input sequences):

- **A = attack/swing, B = interact/menu confirm, R = cursor.** Doors and
  items: press R, aim the cursor at the object with the d-pad, B opens the
  submenu, R confirms.
- After an attack, **hold up ~0.4 s until the target's textbox appears**
  (e.g. "Orc"); the aim then *glues* to the target — release all direction
  keys and mash A.
- **A on an empty submenu resets the menu to the top.** A silently-failed
  pickup looks like "A stopped working" in the start menu; check the pickup
  first (this cost a whole exploration cycle).
- The Beretta pickup needs the cursor at the M2 tile plus a `press right 6`
  nudge before R. From the alley label `Beretta Pistol.`: `press b` →
  `down 2` → `a 6`, then `'Beretta 101T' pistol.` confirms. (Probe-proven on
  the LLE leg only; having the gun in inventory does **not** arm the crosshair
  — an equip step is still missing.)
- Equip path: Weapons → W3 sub-submenu → two downs + A → Start to exit.

Battle RNG looked game-random (variable shots, player can die) but is
**guest-deterministic**: same SRAM + same inputs replayed byte-identically
across two runs of the same binary — `identical over 25902 frames`. A frozen
script is therefore a usable regression gate against the *same* binary; across
execution paths it is only comparable up to the f16125 horizon (§7.2) and
through checkpoints both paths can be proven to share (`tests/route_state.py`).

Cross-path (AOT vs LLE) behaviour of these routes is analysed in three steps:
`evidence/a5_crosspath_tick.md` (the tick-label offsets, and why the physics
matches byte-for-byte while the two paths still share state),
`evidence/a6_crosspath_divergence.md` (where that shared state ends on the
long route), and `evidence/a7_aot_split_hunt.md` (the onset at f16122, its
mechanism, and §9 for the gate that came out of it). The matching physics is
real but bounded: identical through f16121, after which the frame boundary
hands off at a different loop iteration on each path — ruled expected
framework behaviour, not a value bug, and gated the way §7.2 describes.

## Environment variables the host honours

| Variable | Effect |
| --- | --- |
| `SNESRECOMP_FRAMEDUMP_START` / `_END` | limit the `--framedump` frame window |
| `SNESRECOMP_FRAMEDUMP_PIXELS` / `_VIDEO` | include pixel/scene detail in dumps |
| `SNESRECOMP_FRAME_BMP_DIR` / `_START` / `_END` / `_STEP` / `_FRAME` / `_PIXELS` | BMP capture (see §5) |
| `SNESRECOMP_DUMP_DIR` | where `dump <tag>` writes |
| `SNESRECOMP_TIER2_MANIFEST` | absolute path for the `--coverage-capture` journal, so parallel legs do not share one (§7.9) |
| `SNESRECOMP_IDLE_POLLS` | comma-separated hex PCs to declare as idle-poll waits, read by `DeclareIdlePolls()` in `src/game_rtl.c`; unset or `off` declares nothing, which is the shipped default (§7.9) |
| `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy` | headless |
