# C1c: a copy of the framework is not a control

`tests/README.md §7.7`. This one is about the harness, not the game, and it is
here because it silently invalidated a measurement that had already been written
down: the neutrality legs in `evidence/b0_read_trace.md` ran their control leg
against a framework that was not the pinned revision.

## The claim that was doing the work

The B0 gate compares three legs: `ctrl` (framework at the pin, no observer),
`off` (observer build, collector unarmed) and `on` (observer build, collector
armed). `ctrl` is the only leg that can say "adding the seam to the framework
changed nothing a player can see". The control build tree was
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-ctrl`, configured with
`-DSNESRECOMP_ROOT=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/snesrecomp-clean`.
Its provenance printed `framework=unknown`, which was read as "the pin, in a
directory git cannot name" — a limitation of the stamp rather than of the tree.

## What hashing that tree says instead

`…/snesrecomp-clean` is a directory copy, not a checkout: its `.git` is the
one-line file `gitdir: ../.git/modules/snesrecomp`, and that path does not exist,
so `git rev-parse` fails there. That much was visible. The content was not:

| file | copy | pin `773285b8` | framework `main` `76eda6dd` |
|---|---|---|---|
| `runner/src/snes/interp_bridge.c` | `98fb3b690efa…` | `6de65c17849d…` | `6de65c17849d…` |
| `recompiler-rs/src/decoder.rs` | `f6f77e5bf3e0…` | `4c59fb348f0f…` | `4c59fb348f0f…` |

(`git hash-object` on the copies, `git ls-tree -r <rev> -- <path>` for the
revisions.) `98fb3b69` is the blob the **pin commit itself replaced**:
`git log --find-object=98fb3b690efa66defb4532cf13a10bf9a4295f26` names
`773285b8 … insn-granularity deadline unwind + bus-exact master charging` (which
introduced `6de65c17`) and `64a0c871` (Oct 27, which introduced `98fb3b69`). The
copy predates the pin. Its `decoder.rs` blob is not carried by the pin or by
framework `main` either, so the copy is not any nearby commit — it is a
late-October snapshot (its file mtimes say Oct 27 09:20) with an unresolvable
lineage.

Counting instead of arguing: against the pin's tree, the copy differs in **39
tracked source files** (`diff -rq` over `runner/`, `recompiler/`, `recompiler-rs/`,
`tools/`, `tests/`, excluding caches and build artifacts):

| area | files that differ |
|---|---:|
| `recompiler-rs/` | 12 — 8 under `src/` (`decoder.rs`, `insn.rs`, `cfg.rs`, `hirom_cfg.rs`, `rom.rs`, `lib.rs`, `bin/analyze.rs`, `decoder/pointer_recovery.rs`) plus `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `.cargo/config.toml` |
| `tests/v2/` + two other framework tests | 19 |
| `recompiler/` | 4 — `snes_cycles.py`, `v2/codegen.py`, `v2/emit_function.py`, `v2/emitter_helpers.py` |
| `runner/` | 3 — `snes/interp_bridge.c`, `data_pack_io.hpp`, `desktop/mmx23_host_main.inc` |
| `tools/` | 2 |

The analyzer crate is the clearest single number: the framework's own
`source_digest` over `recompiler-rs/src`, `Cargo.toml` and `Cargo.lock` is
`41d94e0e5b37…` for the copy against **`03e1938ea65e…`** for the pin, the branch
and `main`.

So the earlier "identical over 25,902 frames" was measured against a runner from
before the pin, including one missing pin commit that changes
`interp_bridge.c`. That is exactly the kind of input difference the leg was
supposed to exclude.

## The control that can carry the claim

A control must be a checkout at the pin, so one was made:

```sh
git -C /Users/wee/Documents/work/snesrecomp worktree add \
    /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin 773285b8
cmake -S . -B build-pin -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=/opt/homebrew/opt/gcc/bin/gcc-16 -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DSNESRECOMP_ROOT=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin \
    -DSNESRECOMP_ROM="Shadowrun (USA).sfc" -DSNESRECOMP_EMBED_ROM=OFF
make -C build-pin -j8
```

rc 0 (`tests/out/pin-cmake.log`, `tests/out/pin-build.log`), executable
`build-pin/ShadowrunSNESRecomp`, 3,294,704 bytes, sha256 `09b317eba13353e6…`,
provenance `framework=773285b8210f`. Re-running both neutrality legs against it
is in `evidence/b0_read_trace.md` §Is the observer inert; the verdicts did not
move — menu 1,245 frames and combat 25,902 frames, both pairs identical — but now
they mean what they say.

**The compiler is a second input, and it is not free.** The same pin tree, built
by clang with everything else equal, links a 2,900,080-byte executable against
gcc-16's 3,294,704: 394,624 bytes apart (`build-ctrl3`, sha256 `18cc5f15d51454…`).
It was never used as a control. A control's CMakeCache must name the same
compilers as the leg it faces — for this port that is
`CC=/opt/homebrew/opt/gcc/bin/gcc-16`, `CXX=/usr/bin/g++`.

## The gate that came out of it

`tests/provenance.py pin [--exact|--descendant] <binary|build-tree|framework-root>…`
resolves a build tree's framework root out of its own `CMakeCache.txt` and asks
git, not a stamp, what revision it is:

```
AT THE PIN   build-pin/ShadowrunSNESRecomp: …/sr-pin @ 773285b8210f…
OFF THE PIN  build-b0/ShadowrunSNESRecomp: …/sr-b0 @ 48d2d1b7120a…, with 773285b8210f as an ancestor
NOT THE PIN  build-embed/ShadowrunSNESRecomp: …/sr-embed @ c5024e74…, pin is 773285b8…
UNKNOWN      build-ctrl/ShadowrunSNESRecomp: …/snesrecomp-clean is not a git checkout … A copy is not a control
```

Exit 0 when every target passes, 1 when any fails, 2 when `framework_pins.txt`
cannot be read. It reads the pin from `framework_pins.txt`, so it follows a pin
bump instead of arguing with one; a tree at the pin with uncommitted framework
edits is reported `NOT THE PIN`, and `--descendant` accepts only a framework with
the pin as an ancestor — the shape a capability branch like `feat/cart-read-trace`
has to have.

Both B0 gates now apply it before running anything:
`tests/cart_trace_neutral.sh` refuses a control that is not `AT THE PIN` (and
defaults `CTRL_BIN` to `./build-pin/ShadowrunSNESRecomp`), and
`tests/collect_read_traces.sh` refuses an observer build that is not at the pin or
a descendant of it. Measured on the old control, both exit 2 with the message
above.

## Which trees this leaves stale

From each tree's own `CMakeCache.txt`:

| build tree | framework root | verdict |
|---|---|---|
| `build-pin` | `sr-pin` @ `773285b8` | the control |
| `build-b0` | `sr-b0` @ `48d2d1b7` | pin + observer, the observer leg |
| `build-ctrl`, `build-ctrl2`, `build` | `snesrecomp-clean` | pre-pin copy, not a control; `build` is also stale against the current generated set |
| `build-lle`, `build-tr-aot`, `build-tr-lle`, `build-trace` | `/Users/wee/Documents/work/snesrecomp` @ `76eda6dd` | pin + 2 docs-only commits; pin is an ancestor, so cross-path legs are a named step off the pin, not an unknown one |
| `build-embed*` | `sr-embed` @ `c5024e74` | the embedded-ROM branch, `feat/embedded-rom` |
| `build-up`, `build-up-embed` | `sr-up`, `sr-up-embed` | upstream framework, not this pin |

The B0 read traces themselves came from `build-b0`, which is the pin plus the
observer, so the B0 measurements never depended on the bad control. The gate was
the thing that did.

## The pin reproduces `src/gen` byte for byte

With the pin's worktree open, the next question was whether the port's generated C
is the pin's output at all — `src/gen` carries no commit id, only
`sha256 24df45247dc2…` over the tree. Two runs answered it, and the first answer
was wrong in an instructive way.

Run one, the pinned CLI with the prebuilt analyzer named through
`SNESRECOMP_NATIVE_ANALYZER` (`tests/out/gen-pin-check.log`, rc 0, ~16 s):
every generated file byte-identical to `src/gen` **except** `module_v2.c`, and
that file differs on one line — `g_program_module.build_digest`, which is a hash of
the generator's own inputs. The cached `generator_digest` differed too: `0fbd818d…`
on disk against `541ee137…` for that run.

Recomputing `generator_digest` from `v2_emit.py::_tree_digest` for every
combination of CLI tree and analyzer binary on this machine says which generator
made each one:

| CLI tree | analyzer binary named | `generator_digest` | |
|---|---|---|---|
| pin (`sr-pin`) | `…/snesrecomp/recompiler-rs/target/…` | `541ee137aa75…` | run one above |
| pin (`sr-pin`) | the pre-pin copy's analyzer | `c8d8cf32bffa…` | |
| framework `main` | main's analyzer | `0fbd818dec85…` | **= `src/gen` on disk** |
| pre-pin copy | its own analyzer | `a6d408efec25…` | |

`_tree_digest` hashes file *contents* over `recompiler/v2/`, `v2_emit.py`,
`snes65816.py`, four analysis tools, `recompiler-rs/src`, `Cargo.toml`,
`Cargo.lock` — and the analyzer binary, keyed by its path **relative to the tree
the CLI is running from**, or `external/<name>` when it lives outside. So the
difference was not code: it was the identity of the analyzer path. Confirming that,
the hashed file sets of the pin and framework `main` are identical — 41 files, zero
content differences — which is what "main is the pin plus two docs-only commits"
has to mean for the generator.

Run two, then: the same analyzer binary copied into the pin's own worktree
(`<sr-pin>/recompiler-rs/target/release/`, gitignored, stamp
`03e1938e…` matching the pin crate's source digest, so nothing rebuilt), and the
pinned CLI run without `SNESRECOMP_NATIVE_ANALYZER`
(`tests/out/gen-pin-check2.log`, rc 0, **7.9 s**):

```
$ diff -rq src/gen <scratch>
Only in src/gen: .gitkeep
```

Byte-identical — 17 units, `program_manifest.json`, every bank file, and
`module_v2.c` including `build_digest = 62601772b3b1…`, which now matches. The
digest the pin produces is `0fbd818dec85…`, the same one on disk. So **the
committed generated set is exactly the pinned framework's output**, and the earlier
"the stamp is not the pin's" reading was an artifact of naming the analyzer from
outside the tree. `src/gen` is reproducible from the pin in under ten seconds, with
the analyzer the framework can already verify.

The runs also touch the port's own configuration: `generate` writes `recomp/funcs.h`
and syncs `recomp/symbols.toml` in place. Checked both times by hash —
`recomp/funcs.h` and `recomp/symbols.toml` unchanged — so the port's configuration
is already what the pin's analyzer derives from it.
