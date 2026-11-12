# Building Shadowrun Recomp

This repository is the game port. It does not contain the game, the recompiler,
or any generated code. Building needs three things:

1. **the framework** — a separate `snesrecomp` checkout, pinned in
   `framework_pins.txt`, with three patches from `tools/` applied;
2. **your own ROMs** — the USA, German and Swedish dumps, named and verified
   by `rom_identity*.txt`;
3. **generated code** — `src/gen`, `src/gen-de`, `src/gen-sv`, produced locally
   from those dumps by `tools/regen-all-editions.sh`. It is derived from
   copyrighted data and is never committed.

The default result is one executable that runs any of the three dumps and picks
the matching program module at boot.

## 0. Prerequisites

| host | tools |
|---|---|
| all | Git, Python 3.11+, CMake 3.21+, [Rust](https://rustup.rs/) (the analyzer is a Rust binary built on first regeneration) |
| Windows | [Visual Studio 2022](https://visualstudio.microsoft.com/) with **Desktop development with C++** and **C++ CMake tools for Windows**, plus the Windows SDK; use **Developer PowerShell for VS 2022**. Git Bash runs the regeneration script. |
| Linux | `build-essential cmake python3`, Rust, and the SDL/OpenGL development headers: `libgl1-mesa-dev libegl1-mesa-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxss-dev libxtst-dev libxkbcommon-dev libwayland-dev libdecor-0-dev libasound2-dev libpulse-dev libudev-dev libdbus-1-dev` |
| macOS | Xcode command line tools, CMake 3.21+, Ninja (`brew install ninja`), Rust |

SDL3 is not a prerequisite: the build downloads and compiles the pinned SDL3
statically unless a package is found.

## 1. Get the framework

```sh
git clone <your snesrecomp remote> snesrecomp
git -C snesrecomp checkout "$(sed -n 's/^snesrecomp=//p' framework_pins.txt)"
git -C snesrecomp apply "$PWD/tools/mouse_mod_framework.patch"
git -C snesrecomp apply "$PWD/tools/msvc_program_module_framework.patch"
git -C snesrecomp apply "$PWD/tools/interp_fused_rom_read_framework.patch"
```

All three patches are required. They add the mouse controls, make the program
modules' registration survive an MSVC Release link, and fuse the interpreter's
duplicate ROM mapping lookup (the port's largest guest-CPU win). CMake stops
before compiling if a patch is missing and prints the exact `git apply` command.

The framework is not vendored here: `framework_pins.txt` names the commit the
port was qualified against, and the patches in `tools/` are what the port adds
to it. Point CMake at the checkout with `SNESRECOMP_ROOT`.

## 2. Regenerate from your ROMs

Put your own dumps anywhere and name the directory:

```sh
export SNESRECOMP_ROOT="$PWD/snesrecomp"
bash tools/regen-all-editions.sh --rom-dir "/path/to/dumps"
```

The directory should contain:

| file | edition |
|---|---|
| `Shadowrun (USA).sfc` | USA, the stock module |
| `Shadowrun (Germany).sfc` | German translation |
| `Shadowrun (Sweden).sfc` | Swedish translation |

Each dump is checked against `rom_identity*.txt` before anything is generated,
so a wrong revision or a bad dump stops with its SHA-256 instead of producing a
broken tree. Only own one release? Generate just that one and narrow the build
(see [Single edition](#single-edition)).

Output: `src/gen`, `src/gen-de`, `src/gen-sv` (all git-ignored), plus
`recomp/funcs.h`.

## 3. Build

```sh
export SNESRECOMP_ROOT="$PWD/snesrecomp"
```

### Linux (GCC or Clang, Makefiles)

```sh
cmake --preset linux-x64
cmake --build --preset linux-x64 --parallel "$(nproc)"
```

Binary: `build-linux-x64/ShadowrunSNESRecomp`.

The Linux presets use HLE frame composition, which measured ~18% faster than
the framework's LLE default on the reference machine. They also default to the
fused interpreter ROM read. Override with
`-DSNESRECOMP_FRAME_IMPL=LLE` or `-DSNESRECOMP_INTERP_READ_IMPL=REFERENCE` for
an A/B.

### Windows (Visual Studio 2022, MSVC)

From **Developer PowerShell for VS 2022**:

```powershell
$env:SNESRECOMP_ROOT = "D:\SNESDev\snesrecomp"
cmake --preset windows-x64
cmake --build --preset windows-x64
```

Binary: `build-windows-x64\Release\ShadowrunSNESRecomp.exe`, with `assets\`,
`mods\` and settings staged beside it.

Use Release. A Debug MSVC build hides the registration problem the second
framework patch fixes; the Release build is the one that ships.

### macOS (Apple clang, Ninja)

```sh
cmake --preset macos-arm64          # Apple Silicon
cmake --preset macos-universal      # arm64 + x86_64
cmake --build --preset macos-arm64 --parallel 8
```

Binary: `build-macos-arm64/ShadowrunSNESRecomp` (or
`build-macos-universal/...`). The universal preset compiles and links both
slices; this host can only run the arm64 one.

### Presets

| preset | generator | result |
|---|---|---|
| `linux-x64`, `linux-arm64` | Unix Makefiles | universal executable |
| `windows-x64` | Visual Studio 2022 | universal executable |
| `macos-arm64`, `macos-universal` | Ninja | universal executable |
| `*-de`, `*-sv` | same | one translation only |
| `*-setup` | same | setup host, no generated code; it regenerates on the player's machine |
| `*-embed`, `*-de-embed`, `*-sv-embed` | same | ROM compiled in, personal use only |

All presets read `SNESRECOMP_ROOT` from the environment. The `*-de`/`*-sv`
presets configure `SHADOWRUN_UNIVERSAL=OFF`, which is also the manual switch:

```sh
cmake -S . -B build-us -DSHADOWRUN_UNIVERSAL=OFF -DSHADOWRUN_EDITION=us
```

## Single edition

```sh
ROM="/path/to/Shadowrun (USA).sfc" bash tools/regen.sh     # writes src/gen only
cmake -S . -B build-us \
  -DSNESRECOMP_ROOT="$SNESRECOMP_ROOT" \
  -DSHADOWRUN_UNIVERSAL=OFF -DSHADOWRUN_EDITION=us
cmake --build build-us --parallel "$(nproc)"
```

`tools/regen.sh --help` covers the per-edition output directories and module
ids if you want to generate a translation by hand.

## 4. Run

```sh
./build-linux-x64/ShadowrunSNESRecomp          # no --rom: the launcher asks once
./build-linux-x64/ShadowrunSNESRecomp --no-launcher --rom "/path/to/dump.sfc"
```

The launcher caches the dump path in the platform's state directory
(`saves/`, `saves/de/`, `saves/sv/` beside the executable for development
builds, `~/Library/Application Support/Shadowrun/` on macOS). A dump that
matches none of the linked editions is refused with its SHA-256 and the
editions the build carries — no silent boot into the wrong program.

## Troubleshooting

| symptom | cause |
|---|---|
| `is missing the mouse framework patch` / `fused interpreter ROM read patch` | step 1 skipped a patch; the message prints the command |
| `src/gen is empty -- run tools/regen.sh` | regenerate first (step 2); the default build needs all three trees |
| `no program module registered at all` (MSVC Release) | framework built without `tools/msvc_program_module_framework.patch`, or the generated trees predate it: regenerate |
| `no module matches image … sha256 …` | the dump is not one of the revisions in `rom_identity*.txt` |
| nothing but a window on first launch | the launcher is asking for a ROM; or pass `--no-launcher --rom <path>` |

`tests/selfcheck.sh`, `tests/parity.sh` and the rest of `tests/README.md` prove
the guest actually executes; `README.md` has the deeper design and evidence
notes.
