# Shadowrun Recomp

A native recompilation of **Shadowrun**, built on
[snesrecomp](https://github.com/RetroPortingToolKit/snesrecomp).

The default tree builds **one executable that runs the USA, German and Swedish
releases**. The three dumps are different programs — the translations moved the
code and put the hand cursor `0x1C` lower in WRAM — so each has its own
generated recompiled tree. They are linked as separate program modules, and the
runtime selects the one whose recorded ROM digest matches the dump the player
supplied. Shadowrun (USA): LoROM, 1 MiB ROM + 8 KiB SRAM, no coprocessor,
header title `SHADOWRUN` v1.0 (North America). This folder is a working port —
it boots to the title screen, takes input, and writes SRAM, natively on macOS,
Linux and Windows.

> **You must legally own a copy of the game.** No ROM data is distributed with
> this project, in the repository or in any release. The recompiled C is
> generated locally from your own copy and is never committed.

## Building from this repository

A fresh checkout contains no game and no generated code. `BUILDING.md` is the
start-to-finish recipe: get and patch the pinned framework, regenerate the three
trees from your own dumps, then configure one platform preset (`linux-x64`,
`windows-x64`, `macos-arm64`, `macos-universal`). The sections below go deeper
on the design and on packaging.

## Status

Boots and plays on macOS arm64: window at 3× with the OpenGL renderer, DualSense
recognised as pad 1, SRAM saved to `saves/save.srm`. Measured at 57–59 fps with
about 0.4–0.5 CPU-seconds per second of emulated time.

The universal executable was built on macOS arm64 and headless-booted against
all three dumps: the USA, German and Swedish runs each selected their own
program module and advanced the edition's frame counter (`selfcheck.txt` for
USA, `selfcheck-intl.txt` for the translations). The same build also refuses a
1 MiB image that matches none of its editions instead of booting it on the
wrong dispatch table.

The same tree was built and booted on Linux arm64 (Ubuntu 24.04 container on
this host) with the `linux-arm64` preset, and cross-compiled to a Windows
x86-64 PE32+ executable with MinGW-w64; `tools/package_desktop.py` packaged
that cross-build as a universal `.zip`. The supported Windows toolchain is
still Visual Studio 2022, and the Windows executable was not run here; see
[Platforms](#platforms) and `evidence/cross_platform.md`.

The port's own code and the mouse mod are plain C11 on SDL3. The framework host
builds with MSVC, clang and gcc; this branch adds the platform-specific pieces
the port owns (see [Platforms](#platforms)). macOS arm64 is the development
host; the Linux build ran in an arm64 container and the Windows executable was
cross-compiled, not run. `evidence/cross_platform.md` records exactly what was
measured and what was not.

The shipped build carries the **promoted batch**: 214 statically recompiled
functions (3 banks) alongside the interpreter, which still carries ~98% of
executed cycles on the scripted routes. Promotion was gated against the LLE
reference build — see [Testing](#testing) and `tests/README.md §7`.

## ROM identity

One executable, three accepted dumps. Each row's digests live in its own
`rom_identity*.txt`, which is the single source of truth for the build, the
regenerator and the release scripts.

| | USA | Germany | Sweden |
|---|---|---|---|
| File | `Shadowrun (USA).sfc` | `Shadowrun (Germany).sfc` | `Shadowrun (Sweden).sfc` |
| Identity | `rom_identity.txt` | `rom_identity.de.txt` | `rom_identity.sv.txt` |
| Region | USA (North America) | Germany | Sweden |
| Mapping | lorom | lorom | lorom |
| Coprocessor | none | none | none |
| CRC32 | `3f34dff0` | `e420e96f` | `30829d8e` |
| SHA-256 | `e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4` | `fda5d1cc6e5202ee311e4777eaa8614ed7361a8f77661aad52c7a1a8cf86a17f` | `4fb9eb8fa4d9c3a0b6c24bac5b0a0b0f079f083f5e6dfa937a161c8f4bcde853` |

`tools/regen.sh` refuses to generate from anything else, and the runtime refuses
to boot a dump that matches none of the linked editions, so a mismatched
revision fails immediately instead of producing subtly wrong output.

## ROM editions (the universal build)

The default executable carries all three releases. They are translations, not
revisions: the inserted text moved the code, so each ROM needs its own
generated C, and their WRAM layout puts the hand cursor `0x1C` lower than the
USA release. Each tree is linked as a program module; at boot the runtime
matches the bytes of the dump the player chose against every module's recorded
SHA-256 and selects the one that owns it.

| edition | ROM | identity file | generated code | module id | symbol prefix | saves | hand cursor |
|---|---|---|---|---|---|---|---|
| USA | `Shadowrun (USA).sfc` | `rom_identity.txt` | `src/gen` | `main` | *(none)* | `saves/` | `$7E01F0/2/4` |
| German | `Shadowrun (Germany).sfc` | `rom_identity.de.txt` | `src/gen-de` | `shadowrun-de` | `shadowrun_de` | `saves/de/` | `$7E01D4/6/8` |
| Swedish | `Shadowrun (Sweden).sfc` | `rom_identity.sv.txt` | `src/gen-sv` | `shadowrun-sv` | `shadowrun_sv` | `saves/sv/` | `$7E01D4/6/8` |

Generate all three trees from your own dumps, then configure and build:

```sh
export SNESRECOMP_ROOT=/path/to/snesrecomp
bash tools/regen-all-editions.sh --rom-dir /path/to/your/dumps
cmake --preset linux-x64          # windows-x64, macos-arm64, macos-universal, ...
cmake --build --preset linux-x64 --parallel 8
```

The resulting binary accepts any of the three dumps: pass `--rom`, or let the
host use its usual resolution order. A dump that matches none of the linked
editions is refused with the list of dumps the build does carry. Saves are kept
apart per edition (`saves/save.srm`, `saves/de/save.srm`, `saves/sv/save.srm`)
because the games' save data is not interchangeable.

A build with a subset of the editions is valid: `-DSHADOWRUN_EDITIONS=us` (or
`us;de`) links only those trees, and the binary then accepts only those ROMs.
The `*-de` and `*-sv` presets are single-edition builds
(`SHADOWRUN_UNIVERSAL=OFF` plus `SHADOWRUN_EDITION`), useful when packaging one
translation; they still work against the universal set's prefixed trees.

To regenerate a single tree without the helper script:

```sh
bash tools/regen.sh --identity rom_identity.de.txt \
                    --out-dir src/gen-de --cfg-dir recomp-lle \
                    --module-id shadowrun-de --module-prefix shadowrun_de
```

`--module-prefix` is what lets two generated trees link into one executable; the
USA tree stays unprefixed because the framework's stock dispatch symbols are
unprefixed. `--module-id` is the name the runtime selects.

`recomp-lle/` carries no `func` seeds on purpose. The addresses in
`recomp/symbols.toml` were measured on the USA ROM; pointed at a translation
they seed blocks the translation never enters, and a German build made that way
went off the rails with an architectural `BRK` a few seconds into the first
scene. Without them the analyzer derives the AOT set from the translation's own
reset/NMI vectors — 9 roots and 213 AOT variants here — and the rest runs on
the interpreter, as most of the USA build does anyway. Both translations share
the same cursor addresses. `evidence/language_roms.md` records the digests,
the byte diffs, the boot and menu runs, and the cursor measurements; those runs
predate the universal executable and describe the three trees individually.

The generated trees are never committed: `src/gen/`, `src/gen-de/` and
`src/gen-sv/` are ignored for the same reason. The embed presets
(`*-embed`, `*-de-embed`, `*-sv-embed`) bake one image into the executable, so
they are single-edition by construction and pass `SHADOWRUN_UNIVERSAL=OFF`.

## Does it still need the original ROM?

Yes. Every launch loads the dump and checks it against that edition's
`rom_identity*.txt`, and the executable is a runtime rather than a standalone
game: recompiled code implements CPU instructions, it does not contain the
cartridge. **All** game data (graphics, maps, scripts, sound, tables) is read
straight out of the loaded ROM, and so is any code that was not proven
reachable.

The shipped build includes the promoted batch (`tests/README.md §7`): the
analyzer proved only 214 functions reachable out of the 1 MiB image — everything
else, including every data table, still runs from the ROM, so effectively the
whole image has to be there either way.

It looks for the dump in this order: `--rom` / a positional path → **the ROM
beside the executable** → `rom.cfg` (a cached absolute path) → the file picker.
A single-edition USA build stages `rom.cfg` for `Shadowrun (USA).sfc`; a
universal build stages none, because it has no single default, and simply takes
whichever of its editions it is handed. A headered (`.smc`) copy of the same
dump is accepted too — a 512-byte copier header is stripped before hashing — and
renaming a file changes nothing.

A different or patched dump is refused at the door rather than mis-executing ten
frames in:

```
[Launcher] ROM not recognized: '/tmp/shadowrun-mangled.sfc'
[Launcher] Its header reads "SHADOWRUN" v1.0 (North America), but its checksum
no longer matches, so it has been patched or is a bad dump. … needs Shadowrun
(USA) (SHA-256 e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4).
```

`saves/save.srm` is that dump's SRAM: it belongs to `3f34dff0` specifically, not
to Shadowrun copies in general. The ROM is gitignored (`*.sfc`, `*.smc`,
`rom.cfg`), so this folder stays shareable without the ROM in it — move the
folder and either move the ROM with it or repoint `rom.cfg`.

## Platforms

The desktop host is the framework's; the port contributes `src/main.c`,
`src/game_rtl.c` and `src/mouse_cursor.c`, all portable C11. What differs on a
platform is the build tool and the file the player receives:

| host | verified here | build | player-facing form |
|---|---|---|---|
| macOS arm64 | yes — built, run, packaged | `cmake --preset macos-arm64` (Ninja) | `.dmg` (`scripts/package_macos_bundle.sh`) |
| macOS universal | compile and link; the x86_64 slice cannot run on this arm64 host | `cmake --preset macos-universal` (Ninja) | `.dmg` |
| Linux arm64 | yes — built and booted all three editions in an Ubuntu 24.04 container | `cmake --preset linux-arm64` (Unix Makefiles) | `.tar.gz` (`tools/package_desktop.py`) |
| Linux x86-64 | Makefiles preset; not run here (x86-64 emulation needs Rosetta, absent on this host) | `cmake --preset linux-x64` | `.tar.gz` (`tools/package_desktop.py`) |
| Windows x86-64 | MinGW-w64 cross-build: PE32+ executable with all three modules linked; the MSVC preset and a real Windows run were not available here | `cmake --preset windows-x64` (Visual Studio 2022) | `.zip` (`tools/package_desktop.py`) |

The presets set `CMAKE_DISABLE_FIND_PACKAGE_SDL3=ON` and let the framework build
its pinned SDL3 statically from source, so a release carries no SDL library
beside it on any of the three. `SNESRECOMP_ROOT` names the framework checkout;
the presets read it from the environment, and the configure step stops with the
exact command if that checkout lacks the port's mouse patch:

```sh
export SNESRECOMP_ROOT=/path/to/snesrecomp
cmake --preset linux-x64          # macos-arm64, macos-universal, windows-x64
cmake --build --preset linux-x64 --parallel 8
```

| preset | generator | player builds it with |
|---|---|---|
| `linux-x64`, `linux-arm64` | Unix Makefiles | `make` (CMake's default on Linux), gcc or clang |
| `windows-x64` | Visual Studio 17 2022, x64 | MSVC from Visual Studio 2022 |
| `macos-arm64`, `macos-universal` | Ninja | `brew install ninja`, Apple clang |
| `*-de`, `*-sv` | the same generator | one translation only (`SHADOWRUN_UNIVERSAL=OFF`) |
| `*-setup` | the same generator | no `src/gen`; CI's form and a setup pack's host |
| `*-embed`, `*-de-embed`, `*-sv-embed` | the same generator | `SHADOWRUN_EMBED_ROM=ON`, personal single-edition build |

Every preset without `-de`/`-sv` is the universal build: it links all three
generated trees and its executable accepts any of the three dumps.
`-DSHADOWRUN_EDITIONS=us;de` narrows that set; `SHADOWRUN_UNIVERSAL=OFF` makes
a single-edition build. The workflow's *Check the linked editions* step fails a
run whose preset silently lost an edition.

The Windows build may be driven from a terminal or by opening this folder in
Visual Studio 2022 (File → Open → Folder), which reads `CMakePresets.json` and
offers `windows-x64` directly.

`.github/workflows/cross-platform.yml` builds the setup host with those same
presets on `ubuntu-24.04`, `windows-2022` and `macos-15`, after applying
`tools/mouse_mod_framework.patch` and
`tools/interp_fused_rom_read_framework.patch` to the framework checkout. It is
manual because `framework_pins.txt` names a local framework commit that the
public checkout cannot serve; point its `snesrecomp_repository` / `snesrecomp_ref`
inputs at a clone that can. A successful run proves the port compiles with each
platform's compiler and that the edition table it deploys is the three-edition
one (the *Check the linked editions* step), and it exercises the Windows/Linux
packager's edition labelling (`tests/package_desktop_editions.sh`); it cannot
produce the playable binary, because CI has no ROM and `src/gen` is generated
locally (see [Build](#build)).

## Build

Three steps on any host: regenerate the generated code from your own dumps,
configure, build. The default build regenerates all three editions and links
them into one executable; the framework checkout must carry the port's three
patches — the mouse accessor and OS-pointer hiding, the MSVC program-module
registration, and the interpreter's fused ROM read are all framework code.

### What to install

| host | tools |
|---|---|
| all | Git, Python 3.11+, CMake 3.21+, Rust through [rustup](https://rustup.rs/) (the analyzer is a Rust binary and is built on the first regeneration) |
| Windows | [Visual Studio 2022](https://visualstudio.microsoft.com/) with **Desktop development with C++** and **C++ CMake tools for Windows**, plus the Windows SDK; Git for Windows, whose Git Bash runs `tools/regen.sh` |
| Linux | `build-essential cmake python3`, Rust, and the SDL/OpenGL development headers: `libgl1-mesa-dev libegl1-mesa-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxss-dev libxtst-dev libxkbcommon-dev libwayland-dev libdecor-0-dev libasound2-dev libpulse-dev libudev-dev libdbus-1-dev` |

Those packages are not SDL itself — the build downloads and compiles its pinned
SDL3 statically — but without them SDL would configure with no X11, Wayland or
audio backend and the game would open no window. A full `apt install` line for
Ubuntu 24.04 is in the workflow; the equivalent package names on Fedora are
`mesa-libGL-devel libX11-devel libXext-devel libXrandr-devel libXcursor-devel
libXi-devel libXfixes-devel libXScrnSaver-devel libXtst-devel libxkbcommon-devel
wayland-devel libdecor-devel alsa-lib-devel pulseaudio-libs-devel
systemd-devel dbus-devel`.

### The framework checkout

```sh
git clone <your-framework-remote> snesrecomp
git -C snesrecomp checkout 773285b8210f2254ae87d0a14113980fb36990ad
git -C snesrecomp apply /path/to/ShadowrunSNESRecomp/tools/mouse_mod_framework.patch
git -C snesrecomp apply /path/to/ShadowrunSNESRecomp/tools/msvc_program_module_framework.patch
git -C snesrecomp apply /path/to/ShadowrunSNESRecomp/tools/interp_fused_rom_read_framework.patch
```

The mouse patch applies to the pin (`773285b8`) and to `32266300` (the pin plus
the macOS writable-state commit the `.dmg` builds use). Its branch form is
`mod/mouse` (`2bfb3a63`) in the framework clone. If the checkout is missing the
accessor, CMake fails before compiling with the `git apply` command that fixes
it.

The second patch is not optional on any host. It makes the generated program
modules' registration survive an MSVC Release link (external `.CRT$XCU` entry
plus `/include:`) and names each tree's registration function after its module
id, which that linkage requires. Without it, everything still builds, Debug
still runs, and an MSVC **Release** universal executable registers no modules
at all: it accepts a ROM in the launcher, then exits before `SnesInit` because
no edition matched. The runtime now says so explicitly:

```
[shadowrun] no program module registered at all: this build linked no
registration constructor (see runner/src/program_module.h).
```

The patch is framework-side (`runner/src/program_module.h`,
`recompiler/v2/program_emit.py` and its test); the port's generated trees are
emitted with the matching constructor names, so a tree generated before the
patch must be regenerated (or its `module_v2.c` renamed, as the release bundle
shipped for the first Windows test was).

The third patch is the interpreter's hottest path. A ROM fetch used to decode
the same mapping twice — once to decide the address is stable, once more inside
`cpu_read8 -> cart_getRomPtr` — and those two lookups plus the dispatch around
them dominate a profile of the shipped build (`cart_getRomPtr` alone measured
15.7%). `interp_fused_rom_read_framework.patch` is upstream `ca5673cb` adapted
to the pin: it adds `cpu_read8_plain_rom()` and claims the immutable plain
LoROM/HiROM case once, leaving devices, SRAM and invalid reads on the reference
classifier. It applies on top of the other two patches; CMake fails with that
`git apply` command if the checkout lacks it, and the port selects
`SNESRECOMP_INTERP_READ_IMPL=FUSED` by default. On the same 600-frame route it
cut the guest stage from ~2.0 ms to ~1.7 ms per frame (13–18% across runs);
measurements are in `evidence/a8_fused_rom_read.md`.
`-DSNESRECOMP_INTERP_READ_IMPL=REFERENCE` restores the old decoder for an A/B.

### Windows (Visual Studio 2022)

Run these in **Developer PowerShell for VS 2022** (Start menu), from this
folder. Git Bash regenerates the code; `cmake` drives MSVC through the preset:

```powershell
$env:SNESRECOMP_ROOT = "D:\SNESDev\snesrecomp"
& 'C:\Program Files\Git\bin\bash.exe' tools/regen-all-editions.sh --rom-dir 'D:/ROMs'
cmake --preset windows-x64
cmake --build --preset windows-x64
```

`--rom-dir` must contain `Shadowrun (USA).sfc`, `Shadowrun (Germany).sfc` and
`Shadowrun (Sweden).sfc`. If you own only one release, regenerate that one with
`tools/regen.sh` and configure with `-DSHADOWRUN_EDITIONS=us` (or `de`/`sv`).

The executable lands in `build-windows-x64\Release\ShadowrunSNESRecomp.exe`
with its `assets\`, `mods\` and settings beside it. `cmake --build` builds the
Release configuration the preset names; to build another configuration from
Visual Studio, pick it there — `VERSION` is only stamped into Release.

Use Release, not only for speed: a Debug MSVC build keeps the program modules'
`.CRT$XCU` registration entries, while a Release build drops unreferenced
static ones unless the framework carries `tools/msvc_program_module_framework.patch`
(see [The framework checkout](#the-framework-checkout)). A Release build of a
universal tree without that patch opens, takes the ROM, and exits before the
guest starts; the console and `last_run_report.json` then name the empty
module registry.

### Linux (make)

```sh
export SNESRECOMP_ROOT="$PWD/snesrecomp"
bash tools/regen-all-editions.sh --rom-dir "/path/to/dumps"
cmake --preset linux-x64
cmake --build --preset linux-x64 --parallel "$(nproc)"
```

The executable lands in `build-linux-x64/ShadowrunSNESRecomp` and accepts any of
the three dumps. Nothing here needs Ninja: the Linux presets use CMake's default
Makefiles generator.

The Linux presets compose the frame with HLE (`SNESRECOMP_FRAME_IMPL=HLE`):
on the reference i7-8559U it measured 52.7 fps against 44.6 fps on the
framework's LLE default. Override with `-DSNESRECOMP_FRAME_IMPL=LLE` if you
want to compare, and keep `AudioSamples` at 512 — raising it only lengthens the
block the guest waits on.

### macOS

```sh
export SNESRECOMP_ROOT="$PWD/snesrecomp"
bash tools/regen-all-editions.sh --rom-dir "/path/to/dumps"
cmake --preset macos-arm64          # or macos-universal
cmake --build --preset macos-arm64 --parallel 8
```

The macOS presets use Ninja (`brew install ninja`); the `.dmg` route is
`scripts/package_macos_bundle.sh`, described under [Packaging](#packaging).

### Regeneration notes

`bash tools/regen-all-editions.sh --rom-dir DIR` is the one-command form: it
verifies each dump against its `rom_identity*.txt`, writes `src/gen` (USA,
stock unprefixed), `src/gen-de` and `src/gen-sv` (prefixed program modules), and
re-syncs the declarations headers. Re-run it whenever anything under `recomp/`
or `recomp-lle/` changes. The first run builds the Rust analyzer, which takes a
few minutes and needs the Rust toolchain on `PATH`.

`bash tools/regen.sh` is the per-tree form. It defaults to the USA identity and
`src/gen`, and resolves the dump from `--rom`, then `SNESRECOMP_ROM`, then
`Shadowrun (USA).sfc` at the repo root, then the path in `rom.cfg`. On Windows,
call it through Git Bash as above; it is a Bash script, and the framework's own
setup guide uses the same route.

For a translation, point it at that edition's identity, output directory, seed
set, module id and prefix — the flags that are not given keep the USA defaults:

```sh
bash tools/regen.sh --identity rom_identity.sv.txt \
                    --out-dir src/gen-sv --cfg-dir recomp-lle \
                    --module-id shadowrun-sv --module-prefix shadowrun_sv
```

`--funcs-h <path>` overrides where the declarations header is written; by
default it lands in the output directory, and the USA run also refreshes
`recomp/funcs.h` for tools that still look there.

If the machine has no network access, the configure step can use a local SDL3
source tree instead of downloading one:

```sh
cmake --preset linux-x64 -DSNESRECOMP_SDL3_SOURCE_DIR=/path/to/SDL3-3.4.10
```

### The same commands without presets

The presets are a spelling of these. Linux/macOS, `make`:

```sh
cmake -S . -B build-linux-x64 -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$SNESRECOMP_ROOT" \
      -DSNESRECOMP_SDL3_FETCH=ON -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON
cmake --build build-linux-x64 --parallel 8
```

Windows, Developer PowerShell:

```powershell
cmake -S . -B build-windows-x64 -G 'Visual Studio 17 2022' -A x64 `
      -DSNESRECOMP_ROOT="$env:SNESRECOMP_ROOT" `
      -DSNESRECOMP_SDL3_FETCH=ON -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON
cmake --build build-windows-x64 --config Release --parallel
```

`-DSNESRECOMP_SDL3_FETCH=ON` with `-DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON` is what
makes the archive self-contained on every host: `runner.cmake` compiles SDL3
statically. Use `-DSNESRECOMP_SDL3_FETCH=OFF` to link a system SDL3 instead; on
macOS that path also needs a GCC-family `CC`/`CXX` for the framework's own C.
Keep Release: an unoptimised build runs about 2× the CPU per frame (1.45 MB vs
2.57 MB of machine code). `tests/README.md §8` has the exact recipe used for
the shipped macOS bundle, including re-staging the self-contained `./Shadowrun`.

The framework is not vendored here: `-DSNESRECOMP_ROOT` points at the snesrecomp
checkout, and `framework_pins.txt` records the exact revision this bundle was
built against (`snesrecomp=773285b8210f2254ae87d0a14113980fb36990ad`). Add the
`snesrecomp/` submodule only once the framework revision it needs is reachable
from the public remote — it is not yet: `773285b` is a local commit of that
checkout, so this bundle rebuilds against a `snesrecomp` clone at the right
revision, not a published one. A pin moves when framework **code** moves, not
when its docs do: the Axis 6 accuracy ruling — the frame-phase hand-off between
the AOT path and the interpreted floor — is framework commit `8d9f999`,
docs-only on top of this pin, so the pin stays. The shipped binary was built
from `773285b`.

## Packaging

`scripts/package_release.sh` builds the framework's player-facing *setup pack*
(a setup host plus this source tree, which recompiles on the player's machine
from their own ROM). It is not runnable in this checkout: it insists on
`snesrecomp/tools/ci/stage_setup_host.sh` and stages the source tree through the
framework submodule, so it needs `snesrecomp/` added at a revision that is
reachable from the public remote. It is not: the pinned revision is a local
commit of that checkout, as are the two macOS build fixes its test suites need.
Re-pin only as a deliberate round of its own — `evidence/a7_aot_split_hunt.md`
§9.4 records that replaying this pin's cycle commit onto current upstream turns
one upstream cycle test red by a single CPU cycle. Nothing shipped is affected,
because that ROM has no branches for the test's fold to fire on, but master
clocks decide the frame boundary here, so a cycle change moves both fidelity
horizons and needs fresh baselines.

A setup host has no generated code, so its Generate & rebuild wizard produces
one edition (the stock tree); it is not a universal player until all three trees
are generated. The universal executable is the normal source build described
above.

`scripts/package_macos_bundle.sh` is the packaging route that *is* runnable in
this checkout. It turns the build tree named on its command line into a
drag-install `Shadowrun.app` inside a `.dmg` and measures what it produced: the
executable inside the bundle is the same bytes in the `.app`, in the mounted
image and in a copy dragged out of it, the packaged bytes dump a frame-for-frame
identical machine against the tree that built them, no ROM ships in any form, and
a copy dragged out of the image into a directory outside this repository runs
from there, writes nothing inside itself, and keeps its saves, settings and ROM
choice under `~/Library/Application Support/Shadowrun/` rather than in the
bundle. The `.app` is arm64 with a macOS 11.0 floor — the bundle claims
`LSMinimumSystemVersion 11.0` and its only Mach-O reads `minos 11.0` — which is a
build record rather than a run on a macOS 11 machine, since this one is newer.
`tests/README.md §7.19` and `§7.22` state the claims,
`evidence/artifacts/macos_package.md` and `macos_deployment_floor.md` are the
transcripts. It signs ad hoc, so a copy that arrives through a browser carries the
download flag and macOS asks before running it: `§7.26` measures the click that
comes up, and `§7.27` the one macOS holds at exec while the prompt waits. A
Developer ID and notarisation are Apple's to sell, not this repository's to
include.

The packager is edition-labelled, not universal: it refuses a tree configured
with `SHADOWRUN_UNIVERSAL=ON` rather than shipping a multi-edition binary under
one language's name. Build the universal executable with the normal presets and
run it from the build tree; package a single edition when a DMG is wanted.

The German and Swedish builds are packaged by the same script with
`EDITION=de` or `EDITION=sv` and the matching **single-edition** build tree
(the `macos-arm64-de` / `macos-arm64-sv` presets; a universal tree is refused
rather than mislabelled):

```sh
EDITION=de scripts/package_macos_bundle.sh build-macos-arm64-de macos-arm64
EDITION=sv scripts/package_macos_bundle.sh build-macos-arm64-sv macos-arm64
```

That selects the bundle name and identifier (`Shadowrun-de.app`,
`…shadowrun.de`), the state directory, the `.dmg` stem
(`shadowrun-de-<version>-<tag>.dmg`), the accept-list
(`rom_identity.de.txt` / `.sv.txt`) and the ROM the run legs hand the app. A
build tree configured for a different edition is refused rather than packaged
under a label that would be wrong. The scripted boots use
`tests/scripts/selfcheck-intl.txt`, because both translations put the game's
per-frame tick counter at `$7E1C76` instead of the USA `$7E1C92`. Frame parity is
measured against the edition's own build tree (section 5); the kit's accepted
reference builds are USA-configured, so a cross-edition frame comparison would
measure the translation rather than the packaging. Transcripts:
`evidence/artifacts/macos_package_de.md` and `macos_package_sv.md`.

The same script has a `PERSONAL=1` mode for the one machine you own. It packages
`build-embed-ship-m11`, where `tools/embed_rom.py` has compiled the image into the
executable, so opening the app goes straight into the game — no file picker, no
`rom.cfg`, nothing to point at. That is a separate artefact with reversed rules,
not the first one with a flag flipped: it writes `Shadowrun-personal.app`,
`shadowrun-embed-<version>-macos-arm64-personal.dmg` and its own log, its scans keep
every absence check and add three presence checks — `nm` finds the array symbol, a byte
scan re-hashes 1,048,576 B found inside the Mach-O —
and it says what it is in three places that travel with the file
(`Contents/Resources/BUILD_INFO.txt`, the bundle's copyright string, and the
`README.txt` at the root of the image). Sending that container to anyone is
sending them a copy of Shadowrun, so it is not a distributable artefact and never
will be; `tests/README.md §7.20` states its claims and
`evidence/artifacts/macos_package_personal.md` is the transcript. It also answers
a fidelity question the shareable package cannot: an executable that carries its
own guest, built from a framework four commits past the pin — the embedded-image
commit, the state fix the shareable package also carries, and two validation
records — dumps a frame-for-frame identical machine against the accepted
ROM-based tree over 1,200 frames.

Windows and Linux use `tools/package_desktop.py`, which stages the built
executable, the shared libraries beside it (none with the static SDL3 the
framework builds), `mods/` and `assets/` when present, and a `README.txt` with
the controls, then seals the folder as a `.zip` (Windows) or `.tar.gz` (Linux)
with a `.sha256` beside it. It takes the build directory, not a configuration
subdirectory: on Windows it finds the Visual Studio build under `Release/`:

```sh
python3 tools/package_desktop.py --build build-linux-x64 --platform linux-x64
python tools/package_desktop.py --build build-windows-x64 --platform windows-x64
python3 tools/package_desktop.py --build build-linux-x64-de --platform linux-x64
python3 tools/package_desktop.py --build build-linux-x64-embed --platform linux-x64 \
        --personal   # built with -DSHADOWRUN_EMBED_ROM=ON; contains the ROM
```

The edition label comes from the build tree's `CMakeCache.txt`, so the first
two commands package the default universal trees: the stem gains `-universal`,
and the README and `BUILD_INFO.txt` list all three dumps with the identity file
each one is checked against. A single-edition tree is labelled with its edition
(`shadowrun-de-…`, `shadowrun-sv-…`). `--edition us|de|sv|universal` may be
passed to assert the edition, and the tool refuses a flag that disagrees with
the tree — `--edition de` on a universal tree, or `--edition universal` on a
single-edition one — so an archive cannot claim a dump its executable would
reject. `--personal` is refused on a universal tree (and on a ROM-free one):
an embedded-ROM executable carries one image and is single-edition by
construction.

The tool is stdlib-only Python, so it runs on all three hosts, and it refuses
to call an archive packaged if the executable inside it is not the one that was
built. It also runs `--help` from the staged folder when the target matches the
host, which catches a missing library before the archive is uploaded.

The ROM does not have to live in the repository — keeping it on your own drive
is the better habit, and `SNESRECOMP_ROM` sets the path once for a shell.
Without either, `tools/regen.sh` finds `Shadowrun (USA).sfc` at the repo root,
then the path recorded in `rom.cfg`; `.gitignore` blocks both from ever being
committed.

`tools/regen.sh` verifies the ROM, generates `src/gen/*.c`, and re-syncs
`recomp/funcs.h`. `tools/regen-all-editions.sh` does that for all three editions
in one command and writes the prefixed `src/gen-de` and `src/gen-sv` trees the
universal build needs. Re-run them whenever you change anything under `recomp/`
or `recomp-lle/`.

## Run

```sh
./Shadowrun                                                 # staged macOS build + its dylibs + ROM beside it
./build/ShadowrunSNESRecomp /path/to/Shadowrun\ \(USA\).sfc # build tree

build-linux-x64/ShadowrunSNESRecomp "Shadowrun (USA).sfc"   # Linux build tree
build-windows-x64\Release\ShadowrunSNESRecomp.exe "Shadowrun (USA).sfc"  # Windows (VS2022)

# language editions: the matching build and dump, e.g.
build-macos-arm64-de/ShadowrunSNESRecomp "Shadowrun (Germany).sfc"
build-macos-arm64-sv/ShadowrunSNESRecomp "Shadowrun (Sweden).sfc"
```

The executable is not self-contained until packaged: keep the `assets/`,
`mods/` and `config.ini` that the build staged beside it. Copy the executable
out of the build tree and it starts without the launcher's fonts and its mod
catalog; use `tools/package_desktop.py` for a folder that travels.

A portable package writes its settings and saves beside the executable, so
extract it somewhere you can write (not `Program Files` or `/usr`). The macOS
`.dmg` is the exception: its state lives in
`~/Library/Application Support/Shadowrun/`.

With no ROM on the command line the build opens the recomp-ui launcher: a ROM
picker with a verification badge, plus display / audio / input settings. Your
choice is cached in `rom.cfg` beside the executable, so the next launch opens
on it and "Skip launcher on boot" makes it immediate. If the launcher is not
built in (`--no-recomp-ui`), the host falls back to a native file picker.

## Mouse mod (branch `mod/mouse`)

This branch plays the game with the mouse: the in-game hand cursor follows
the OS pointer absolutely (no relative d-pad emulation), the directions are
`W`/`A`/`S`/`D`, and the three action buttons are the mouse buttons —

| SNES | input | | SNES | input |
|---|---|---|---|---|
| A | right mouse | | Start | `X` |
| B | left mouse | | Select | `Y` |
| Y | middle mouse | | X | `C` |
| D-pad | `W` `A` `S` `D` | | L / R | `Q` / `E` |

A/B/Y have no keyboard binding on purpose. While the pointer is over the game
image the OS arrow is hidden, so only the hand is visible; it comes back as
soon as the pointer leaves the window or another application takes focus. The
change needs a four-file framework patch (`tools/mouse_mod_framework.patch`,
base `32266300`); the build command, the cursor's WRAM addresses, and the
GUI/headless evidence are in `evidence/mouse_mod.md`.

The cursor addresses are an edition property, not a compile-time USA constant:
`src/edition.c` records each edition's three WRAM words and the mouse mod asks
it which ones to use after the ROM has selected a module. The translations use
`$7E01D4/$7E01D6/$7E01D8`; `evidence/language_roms.md` measures both against the
same scripted route.

The same code is compiled on all three hosts. The framework accessor maps the
pointer through the presenter's viewport, which is the same arithmetic on
Windows, X11 and Cocoa; Wayland, which does not expose a window's desktop
position, uses SDL's cached window-relative point and requires mouse focus.
`evidence/cross_platform.md` records that split and its source evidence.

## Testing

`tests/README.md` is the test guide: how to play it, what the keyboard does, and
the scripted checks that prove the ROM really executes (`selfcheck.sh`), that
runs are deterministic (`parity.sh`), and what the recompiled build costs
(`§7`, evidence in `evidence/`). A self-contained build sits at the repo root as
`./Shadowrun` with its SDL3 in `libs/`, so those tests need no build tree:

```sh
./tests/play.sh        # window, play it
./tests/selfcheck.sh   # ~5 s, exits 0 if the ROM is executing
```

## Layout

| Path | What lives there |
|---|---|
| `Shadowrun`, `libs/` | Staged player-facing build: the executable plus the SDL3 it carries |
| `Shadowrun (USA).sfc` | The dump this build runs (gitignored — players supply their own) |
| `rom.cfg` | Absolute path of the ROM this launch should use (gitignored, machine-local) |
| `rom_identity.txt`, `.de.txt`, `.sv.txt` | ROM digests for the three editions — read by the build, `tools/regen*.sh`, the edition-table generator and CI |
| `recomp/` | USA analysis input: `bank*.cfg`, `symbols.toml`, generated `funcs.h` |
| `recomp-lle/` | Translation analysis input: no USA symbol addresses |
| `src/` | Host code you own: `main.c`, `edition.c`, `game_rtl.c`, `mouse_cursor.c` |
| `src/gen/`, `src/gen-de/`, `src/gen-sv/` | Generated C, one program module per edition. Never committed — regenerate locally |
| `snesrecomp/` | Framework submodule (owns `lib/recomp-net`, `lib/retcomm-rbengine`) — not added here yet |
| `CMakePresets.json` | Release presets: Unix Makefiles on Linux, Visual Studio 2022 on Windows, Ninja on macOS (and their single-edition / setup-host / embedded-ROM variants) |
| `tools/` | `regen.sh` and `regen-all-editions.sh` — the ROM → C pipeline; `gen_editions.py` — the runtime edition table; `package_desktop.py` — Windows/Linux release archive |
| `tests/` | Test kit: play/headless runners, scripted runs, input scripts |
| `evidence/` | Archived per-frame measurements behind `tests/README.md §7` |
| `scripts/` | `package_release.sh` — player-facing setup zip; `package_macos_bundle.sh` — drag-install `.app`/`.dmg` |
| `.github/workflows/cross-platform.yml` | Compiles the setup host with each host's own generator (Make, MSVC, Ninja) |
| `framework_pins.txt` | Exact framework commits this project was scaffolded against |

## Porting from here

1. **Promote code to AOT.** `recomp/symbols.toml` is the symbol map; `emit = true`
   on an entry makes the analyzer compile it ahead-of-time, `emit = false` keeps it
   interpreted. `tools/regen.sh` re-synchronizes the marked blocks in each bank
   cfg and regenerates `src/gen/`. Only proven variants become AOT code; a
   function promoted from the LLE tier with no evidence can be slower than
   interpreting it, so re-measure after each promotion. See `recomp/README.md`
   and `tests/README.md §7`, which is one measured round of this.
2. **Resolve dispatch misses.** After every run, deal with unresolved indirect
   targets before anything else — they are the reason a port diverges, and they
   are cheap to fix early. `e2e_tiny.sh` in the framework runs the whole
   pipeline on a synthetic ROM as a smoke test of the toolchain itself.
3. **Never synthesise a result** to get past uncovered code, and never edit
   `src/gen/` by hand. Fix the config or the framework and regenerate.
4. **Known open item:** the desktop descriptor in `src/main.c` still declares
   `.num_players = 2` from the scaffold. Whether Shadowrun uses port 2 has not
   been established; the scaffold's "Multiplayer" claim below is unverified.

## Multiplayer

Scaffold default: two players, one controller per port. **Not verified for this
title** — see the open item above.

## License

This project's own source is under the license in `LICENSE`. The framework
carries its own terms — see `LICENSE` and `THIRD_PARTY_ATTRIBUTION.md` in the
snesrecomp checkout (`-DSNESRECOMP_ROOT`, or [the
repository](https://github.com/RetroPortingToolKit/snesrecomp) once it is added
as a submodule). Neither covers the game data, which is not distributed here.
