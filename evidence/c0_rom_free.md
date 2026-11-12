# C0 — a build that needs no ROM file (stage-1 M3)

Measured 2026-11-06 on this machine. The claim being tested is small and
specific: **the executable boots and plays with the guest image inside it**, so
the folder it lives in can be otherwise empty — no `.sfc` beside it, no
`rom.cfg`, no launcher asking for a dump.

Plain language first, then the numbers.

## How it works

Three pieces, one per layer:

- `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tools/embed_rom.py`
  writes one C file holding the exact 1 MiB guest image (plus a small CMake
  fragment next to it carrying the size and the filename). It finds the image by
  the same search `tools/regen.sh` uses and reads the digests through the
  framework's own parser of
  `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/rom_identity.txt` — no
  second copy of either. A 512-byte copier header is stripped only when the
  digest says that copy really is the same dump.
- `SHADOWRUN_EMBED_ROM` in
  `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/CMakeLists.txt`
  (default `OFF`) runs that generator at *configure* time, compiles the result
  in, and passes the host three macros: the array name, its size, its filename.
- On the framework side, `runner/src/desktop/host_main.c` on branch
  `feat/embedded-rom` (commit `c5024e74`, branched from `76eda6dd`) short-circuits
  ROM resolution when `SNESRECOMP_EMBEDDED_ROM` is defined: the boot log reads
  `rom resolved: <embedded:Shadowrun (USA).sfc>` — a label, not a path — and the
  load site boots the array instead of reading a file.

Two failure modes would otherwise look like an unexplainable game bug, because
machine code from one ROM revision running against an image from another behaves
badly in ways that resemble gameplay:
1. the *generator* refuses to write an image that is not the one this build's
   machine code was generated from, so the configure stops;
2. the *host* re-hashes the embedded bytes against this build's own digests at
   boot and exits rather than booting them.

The length is a contract too: the host declares `snesrecomp_embedded_rom` with
its size, so an array of a different length cannot link, and the generated file
asserts the same equality itself.

One consequence worth naming: the short-circuit sits **before** the boot
launcher, so a ROM-free build goes straight into the game instead of opening the
launcher screen — there is no ROM to choose, and `rom.cfg` is never consulted or
written. Settings and Mods remain reachable from the in-game launcher. That is
read off the patch (the `goto` precedes the launcher block), not exercised here:
every run below is headless, where the launcher is skipped on `dummy` video
anyway.

## What was built

All three trees use the same generated sources —
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/src/gen`, 17 translation
units — the same `Release` flags and the same SDL from Homebrew. Only the two
variables named in the left column differ.

| tree | framework it compiled | `SHADOWRUN_EMBED_ROM` | binary |
| --- | --- | --- | --- |
| `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-ctrl` | `/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/snesrecomp-clean` — pristine, `host_main.c` md5 `cdf978d19c975fb88390b45c2a910db9`, the blob the pin `773285b` carries | off (default) | 3,294,480 B |
| `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-embed-off` | `/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed` — the embed patch | off | 3,294,704 B (+224) |
| `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-embed` | same as above | **on** | 4,351,584 B (+1,057,104, of which 1,048,576 is the image) |

`build-embed` is the tree every number below came from. After the CMake plumbing
described in the next section was added, the same gates were re-run against a
second tree, `build-embed2`, configured fresh with the final `CMakeLists.txt` —
same size, same `embedded_rom.c` hash, same verdicts — so the plumbing change is
not carried on the earlier tree's authority.

## Configure plumbing: what regenerates the image, and when

The array is written at configure time, so the question is when configure re-runs.
Checked both directions:

| | result |
| --- | --- |
| `touch rom_identity.txt`, then `cmake --build build-embed2` | CMake re-runs, the generator re-runs, the boot banner line `-- ROM-free: embed_rom.py: ... crc32 3f34dff0` reappears |
| `cmake --build build-embed2` again on a clean tree | no reconfigure, just `Built target` |
| a second tree configured from the same image | `embedded_rom.c` is sha256-identical (`50d70ac4…`) — the generator is idempotent, no timestamp in the output |

One hazard this round produced itself: restoring a file with `cp -p` keeps the
*older* mtime, so `cmake --build` does not recompile it and the binary on disk is
still the tampered one. That is how the first tamper check looked like a pass and
the run after it looked like a parity failure. `touch` the generated file after
replacing it.

## Gates

`short.txt` is 180 frames, `menu.txt` is 1245 (the title-menu route
`tests/headless.sh` drives). "Identical" is the strict reading:
`tests/parity.sh` compares the per-frame crc32 of all 128 KiB of WRAM, and a
scratch comparison below compares the WRAM dumps byte for byte. This is a
**same-path** comparison — both binaries run the compiled AOT path — so it is
held to the same standard as §4 of `tests/README.md`, not the phase-tolerant
cross-path one.

| check | result |
| --- | --- |
| `PORT_BIN=./build-embed/ShadowrunSNESRecomp ./tests/selfcheck.sh` | PASS, exit 0 — WRAM tick `$7E1C92` advanced |
| `PORT_BIN=./build-embed/ShadowrunSNESRecomp ./tests/headless.sh` | 1245 frames, exit 0, fps 58.4 |
| `parity.sh` `build-ctrl` vs `build-embed`, `short.txt` | identical over 180 frames |
| `parity.sh` `build-ctrl` vs `build-embed`, `menu.txt` | identical over 1245 frames |
| `parity.sh` `build-ctrl` vs `build-embed-off`, `short.txt` | identical over 180 frames — the framework patch is inert when the option is off |
| two scratch directories, each holding nothing but the executable (`--framedump` on `menu.txt`) | **1245 WRAM dumps compared, 0 differing** — file-based run vs ROM-free run |
| the same ROM-free binary handed `--rom <file>` instead | 1245 dumps compared, 0 differing — a ROM-free binary can still be used as the control in a comparison run |

Re-run against `build-embed2` (the tree configured with the final
`CMakeLists.txt`): `parity.sh` against `build-ctrl` on `menu.txt` — identical
over 1245 frames; `selfcheck.sh` — PASS; `headless.sh` — 1245 frames, exit 0,
fps 58.4. Same verdicts as the rows above.

A third time on a different framework base, so the result cannot be an artefact
of the pinned revision: `build-up-embed` (the embed seam cherry-picked cleanly
onto the port's cycle work rebased onto current upstream, `0ff38c13`) against
`build-up` — identical over 1245 frames. That pair is also what showed a
pin-based framework and a current-upstream framework run this route
byte-identically. See `evidence/c1_staged_bundle_stale.md`.

What the ROM-free run's directory holds afterwards — only what the game itself
writes:

```
Shadowrun  config.ini  keybinds.ini  last_run_report.json  mods/  saves/  dump/  run.log
```

No `.sfc`, and no `rom.cfg`: the file-based run caches the dump it used in
`rom.cfg` beside the executable, the embedded run has nothing to cache.

## Negative controls

Each one is the failure the design claims to prevent.

| tamper | what happened |
| --- | --- |
| one byte flipped at `0x1000` of the ROM handed to the generator | configure refuses: `crc32 3abb53eb (want 3f34dff0)`, exit 1. No binary is produced. |
| one byte flipped in the generated array after the fact, then rebuilt | boot exits 1, **0 frames drawn**: `embedded ROM: crc32 7232172F, but this build's machine code was generated from 3F34DFF0` |
| compiling the generated file with `SNESRECOMP_EMBEDDED_ROM_SIZE` off by one | `static assertion failed: "SNESRECOMP_EMBEDDED_ROM_SIZE disagrees with the embedded image"` |

The middle row is the one that matters: a ROM-free artefact whose image does not
belong to it cannot play, it stops at the digest check and says which digest it
wanted.

## What this does not settle

- **Nothing is promoted.** `framework_pins.txt` still names `773285b8210f2254ae87d0a14113980fb36990ad`,
  the staged `./Shadowrun` still loads a file, and the framework change sits on
  `feat/embedded-rom` (`c5024e74`), never pushed, with no framework test and no
  framework documentation. Before that patch can be proposed upstream it needs
  a test that boots an embedded image and at least one line in the runner docs;
  the `+224` bytes it costs a non-embed build is measured, but it is still a
  change to code every port compiles.
- **Untested edge:** an in-game launcher restart of an embed build. The label is
  not a path, so the restart path must not hand `--rom <label>` to the next
  process; the guard for that is in the patch, reviewed but not exercised — no
  headless harness reaches the in-game launcher. A player who changes audio or
  renderer settings in an embed build is exactly the case this covers.
- **Product question left open:** should a shipped ROM-free artefact still open the
  launcher at boot, for settings and Mods on a first run? The patch says no. It
  is the simplest reading of "no ROM to choose", and it is the kind of decision
  the player sees, so it is listed rather than settled.
- **MSU-1 titles are out of scope.** Streamed audio tracks sit beside the ROM
  file, so a title with MSU-1 media cannot be embedded. Shadowrun has no MSU-1.
- **"ROM-free" is about the guest image only.** The build-tree binary still
  loads libSDL3 from `/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib`; a shipped
  ROM-free artefact still needs the `libs/` staging, `install_name_tool` and
  `codesign` steps in §8 of `tests/README.md`. Packaging that artefact is
  `scripts/package_release.sh`'s problem, not this gate's.
- **Bundle hygiene, found on the way.** `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build`
  was last compiled 2026-11-04 19:31 and holds objects for 4 generated
  translation units, while `src/gen/` was regenerated 2026-11-06 12:59 with 17 —
  so that tree is not a valid control for today's generated code, which is why
  `build-ctrl` was configured fresh instead of reusing it. The related question —
  whether the shipped `./Shadowrun` (5,941,232 B, 2026-11-05 13:20, §7.1)
  corresponds to today's `src/gen` — was answered the same round, and the answer
  is no: see `evidence/c1_staged_bundle_stale.md`. The §7.2 baselines are not
  affected (they were produced by build trees, `xp_*` and `bs_*`); §4's published
  transcript and §7.1's shipped claim do describe that stale artefact.
- **M5 is untouched.** Putting the game's *machine code* in place of the image
  is a different and much larger claim: AOT covers 1.88–5.58% of guest cycles on
  the shipped binary (§7.1).

## Reproducing it

```sh
# from the port directory. SNESRECOMP_ROOT must be a checkout of the
# feat/embedded-rom branch; the ROM is found by the same search regen.sh uses.
CC=/opt/homebrew/opt/gcc/bin/gcc-16 CXX=g++ cmake -S . -B build-embed \
    -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT=/path/to/snesrecomp \
    -DSNESRECOMP_SDL3_FETCH=OFF -DSHADOWRUN_EMBED_ROM=ON
cmake --build build-embed -j8

# the claim: a directory holding nothing but the executable
mkdir /tmp/romfree && cp build-embed/ShadowrunSNESRecomp /tmp/romfree/Shadowrun
cd /tmp/romfree && ./Shadowrun          # straight into the game; no ROM is asked for
                                        # (this binary still loads SDL from
                                        #  /opt/homebrew until it is staged like §8)
```

To check the generator's refusal instead of the boot check:

```sh
SNESRECOMP_ROOT=/path/to/snesrecomp python3 tools/embed_rom.py \
    --rom /path/to/some/other/dump.sfc --out /tmp/x.c
```
