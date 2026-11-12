# Cross-platform build: Windows, Linux and macOS from one tree

Date: 2026-11-11. Branch: `mod/mouse`, based on the shipped `main` at `07fd928`.
Scope: make the port's own sources and the mouse mod build on Windows and
Linux as well as macOS, with the generators a builder already has -- Unix
Makefiles on Linux, Visual Studio 2022 on Windows -- and give each host a
player-facing package.

The framework already carries the Windows/MSVC, X11 and Wayland hosts
(`runner/runner.cmake` mirrors its MSVC `.vcxproj` and has explicit `WIN32`,
`MINGW`, `MSVC` branches). This round is about what the port owns: the two
places where it was macOS-only, the pointer source that is not the same on
every host, and the build/package surface around them.

## What was not portable

A grep of `src/`, `recomp/` and the generated tree for POSIX-only headers and
calls found one port-owned hit:

| file | before | why it breaks |
|---|---|---|
| `src/game_rtl.c` | `#include <strings.h>` and `strcasecmp(spec, "off")` | MSVC has no `<strings.h>`; the call is `_stricmp` there |

Nothing else in the port uses `unistd.h`, `sys/*`, `dirent.h`, `pthread`,
`dlopen`, `__attribute__`, `typeof` or `__builtin`. `src/main.c` and
`src/host_contract.c` are standard C + the framework's own headers.
`src/mouse_cursor.c` is SDL and WRAM only. The generated bank files have the
same property (the recompiler emits standard C for the framework's MSVC
target). The fix is local:

```c
/* strcasecmp is POSIX and <strings.h> does not exist under MSVC. The port
 * builds on Windows as well as macOS/Linux, and the only use here compares
 * against "off", so a local ASCII-only comparison is the whole requirement. */
static int AsciiEqualIgnoreCase(const char *a, const char *b)
```

`src/game_rtl.c` now includes `<string.h>` only and calls
`AsciiEqualIgnoreCase(spec, "off")`. The behaviour is the same: the check is
ASCII, and the environment variable is ASCII.

## What MSVC needs beyond portable C

Two compiler differences are not syntax errors but still matter:

| difference | handling |
|---|---|
| MSVC reads source in the system code page unless told otherwise, and these files contain UTF-8 prose | `target_compile_options(... /utf-8)` for `MSVC` in `CMakeLists.txt` |
| the generated translation units use CRT calls MSVC marks deprecated, which would bury real warnings from hand-written code | `_CRT_SECURE_NO_WARNINGS` on the target for `MSVC` |

Both are guarded by `if(MSVC)`, so the clang/gcc builds are unchanged: the
same tree still compiles with no new flags on macOS and Linux. The framework
already supplies the targeting manifest that makes Windows process paths UTF-8
(`runner/runner.cmake` adds `windows/snesrecomp_utf8.manifest` for MSVC).

The port also cannot configure against a framework that predates the mouse
patch: `src/mouse_cursor.c` calls `snesrecomp_desktop_mouse_state()`, which the
patch adds to `runner/src/desktop/host_main.h`. `CMakeLists.txt` now reads that
header at configure time and stops with the `git apply` command when it is
absent, instead of letting the build fail at link:

```
CMake Error at CMakeLists.txt:48 (message):
  .../sr-unpatched is missing the mouse framework patch
  (snesrecomp_desktop_mouse_state).
  Apply tools/mouse_mod_framework.patch to that checkout (base 32266300) ...
```

Measured against a worktree at `32266300` without the patch: exit 1 with that
message. The patch was also checked against the pin itself, which is the
revision a Windows or Linux builder is most likely to have:
`git apply --check` in a detached worktree at `773285b8` succeeds.

## The pointer is not a global coordinate everywhere

The framework accessor added by the mouse mod
(`snesrecomp_desktop_mouse_state`, `runner/src/desktop/host_main.c`) mapped the
pointer as `SDL_GetGlobalMouseState()` minus `SDL_GetWindowPosition()`. That is
correct on Windows, X11 and Cocoa, where both are desktop coordinates, and it
also works before SDL has seen a first motion event.

Wayland is the exception. In the SDL3 source the framework pins (3.4.10),
`Wayland_GetGlobalMouseState()` (`src/video/wayland/SDL_waylandmouse.c`) does
this:

```c
if (mouse->focus) {
    SDL_RelativeToGlobalForWindow(mouse->focus, mouse->focus->x, mouse->focus->y,
                                  &off_x, &off_y);
    *x = mouse->x + off_x;
    *y = mouse->y + off_y;
} else {
    *x = 0.f;
    *y = 0.f;
}
```

A Wayland client is not told where its window is, so `SDL_GetWindowPosition()`
answers 0,0 and the subtraction is a no-op while the pointer is over the
surface. When the pointer leaves, the global query answers 0,0, which is a
valid point inside the window: without a change the hand would jump to the
top-left corner instead of the mod going quiet.

The accessor now reads the driver and takes a different source:

```c
const char *video_driver = SDL_GetCurrentVideoDriver();
const bool wayland = video_driver && strcmp(video_driver, "wayland") == 0;

const int mx = wayland ? (int)cached_x : (int)gx - win_x;
const int my = wayland ? (int)cached_y : (int)gy - win_y;
...
if (!input_focus || !inside_window) return 0;
/* Wayland's cached point is only live while the surface has the pointer. */
if (wayland && !mouse_focus) return 0;
```

`cached_x/cached_y` are SDL's window-relative `SDL_GetMouseState()` values,
which are the correct coordinates on Wayland, and the mouse-focus gate stops a
leave event from reusing the last point seen inside the surface. The debug
line (`SNESRECOMP_MOUSE_DEBUG=1`) names the driver so a report can say which
path ran.

The change is in the framework branch `mod/mouse` (`2bfb3a63`, base
`32266300`) and its embedded-ROM twin `mod/mouse-embed` (`3e5255b4`, base
`a7fb67e6`). `tools/mouse_mod_framework.patch` is now 404 lines; it was
checked against both bases in temporary worktrees:

```
applies to 32266300
applies to a7fb67e6
```

## Generators: make, MSVC and Ninja

`CMakePresets.json` is preset schema version 3 (CMake 3.21 or newer) with one
hidden base per generator, so each host builds the way its users already do:

| preset | generator | architecture |
|---|---|---|
| `linux-x64`, `linux-arm64` | Unix Makefiles | native |
| `windows-x64` | Visual Studio 17 2022 | x64 |
| `macos-arm64`, `macos-universal` | Ninja | arm64; arm64 + x86_64, 11.0 floor |
| `*-setup` | the same generator | `SNESRECOMP_SETUP_HOST=ON`, the no-`src/gen` form |
| `*-embed` | the same generator | `SHADOWRUN_EMBED_ROM=ON` (personal) |

The Windows build presets set `"configuration": "Release"`. That is not
decoration: the Visual Studio generator is multi-config, so without it
`cmake --build --preset windows-x64` builds the generator's default
configuration and the release stamp in `VERSION` never reaches the binary.
Linux and macOS presets set `CMAKE_BUILD_TYPE=Release` instead.

Every preset sets `CMAKE_DISABLE_FIND_PACKAGE_SDL3=ON` and
`SNESRECOMP_SDL3_FETCH=ON`, so the framework builds its pinned SDL3 statically
from source rather than linking a distribution's shared one. That is what
makes a Windows or Linux archive self-contained: `runner.cmake` already forces
`SDL_SHARED=OFF` on the FetchContent path. `SNESRECOMP_ROOT` comes from the
environment; when it is unset or empty, `CMakeLists.txt` falls back to
`<source>/snesrecomp` and the configure error names `-DSNESRECOMP_ROOT` rather
than pointing at a missing submodule.

Measured here (macOS arm64 host):

```
SNESRECOMP_ROOT=<sr-mouse> cmake --preset linux-x64 \
    -DSNESRECOMP_SDL3_SOURCE_DIR=<SDL3-3.4.10>
  CMAKE_GENERATOR:INTERNAL=Unix Makefiles
  CMAKE_BUILD_TYPE:STRING=Release
cmake --build --preset linux-x64 --parallel 8
  [100%] Built target ShadowrunSNESRecomp
  headless: rom resolved, exit: script quit after 120 frames

cmake --preset macos-universal
  -> configured
cmake --build --preset macos-universal
file build-macos-universal/ShadowrunSNESRecomp
  Mach-O universal binary with 2 architectures: [x86_64] [arm64]
lipo -archs build-macos-universal/ShadowrunSNESRecomp
  x86_64 arm64
```

The `linux-x64` run is a configure and build through the Makefiles preset on
the macOS host: it proves the preset wiring and that the Makefile path compiles
this tree, but the binary it produced is a Mach-O executable, not a Linux one.
No Linux compiler, libc or X11/Wayland headers were involved. The same is true
of the Windows preset, which could not even be generated here: there is no
Visual Studio installation, so its schema is checked by `cmake
--list-presets` and nothing more.

The universal embedded build was configured and built the same way with
`-DSHADOWRUN_EMBED_ROM=ON`; `lipo -archs` reports `x86_64 arm64` for it too.
The x86_64 slice is a compile-and-link measurement: this host cannot execute
it (`arch -x86_64 /usr/bin/true` fails with `Bad CPU type in executable`,
recorded in `evidence/README.md`).

All four macOS executables boot headless on the arm64 slice:

| build | sha256 | headless 120-frame run |
|---|---|---|
| `build-mouse` | `20b72fe3…` | ROM resolved, `script quit after 120 frames` |
| `build-macos-universal` | `39408884…` | ROM resolved, `script quit after 120 frames` |
| `build-embed-mouse` | `20d090f4…` | `<embedded:Shadowrun (USA).sfc>`, `script quit after 120 frames` |
| `build-embed-universal` | `764e4027…` | `<embedded:…>`, `script quit after 120 frames` |

## Packaging on Windows and Linux

`tools/package_desktop.py` is the cross-platform packaging sibling of
`scripts/package_macos_bundle.sh`. It is stdlib-only Python 3 and does five
things, each checked in the run:

1. finds the built executable (`ShadowrunSNESRecomp.exe` on Windows) and
   hashes it -- at the build root for Makefiles/Ninja, under `Release/` for a
   Visual Studio build;
2. stages it with any `*.dll` / `*.so*` / `*.dylib` beside it, plus `mods/` and
   `assets/` when the build staged them, `LICENSE`, a controls `README.txt`
   and a `BUILD_INFO.txt` naming version, platform, source commit, framework
   pin and binary hash;
3. writes a deterministic archive (fixed timestamps, sorted entries, pinned
   gzip header) as `.zip` on Windows and `.tar.gz` on Linux;
4. reopens the archive, checks the executable member hashes to the built one,
   and writes `<archive>.sha256`;
5. runs `--help` from the staged folder when the target matches the host
   (`--help` exits before SDL video/audio init).

Measured here against the macOS arm64 build (the run's `BUILD_INFO` stamps the
commit it was made at, so the digest changes with `HEAD`, not with the tree):

```
$ python3 tools/package_desktop.py --build build-mouse --platform macos-arm64
staged  : .../shadowrun-0.1.0-macos-arm64
exe     : build-mouse/ShadowrunSNESRecomp
files   : ShadowrunSNESRecomp, mods/, LICENSE
size    : 2007602 B
sha256  : 43740d053e1df93e7f32cb76997f03864efcdbf73c2aed36b27c2612322bd5a2
members : 5
smoke   : ok (--help exited 0 from the staged folder)

$ python3 tools/package_desktop.py --build build-embed-mouse \
      --platform macos-arm64 --personal --archive zip
size    : 2710279 B
sha256  : f84465a061fe2da07616137811ddfa9b9bac075d3840c359291633ccd4f95fa4
smoke   : ok (--help exited 0 from the staged folder)
```

The `.tar.gz` was produced twice into different directories, two seconds
apart, and the two files were byte-identical (`cmp`); so was the `.zip`. The
first version of the tool did not actually have that property:
`tarfile.open(..., "w:gz")` lets gzip write the current time into its header,
and two runs that happened inside the same second looked deterministic. The
writer now owns the `GzipFile` and pins `mtime=0`, and the check is two
separated runs, not two adjacent ones. The personal README carries the same
`*** PERSONAL BUILD -- CONTAINS THE GAME, DO NOT DISTRIBUTE ***` statement the
macOS personal image does.

The Visual Studio layout is exercised without Visual Studio: a fake build tree
with the executable, `mods/` and the staged files under `Release/` was packaged
as `windows-x64`, and the tool found the exe there, took `mods/` from beside
it, wrote the `.zip` and skipped the on-host `--help` (a Windows binary cannot
run here). A build directory with no executable stops with the list of
locations it searched.

The Windows and Linux archives themselves need a build on those hosts; this
machine has no Windows or Linux toolchain, VM or container. The tool's platform
argument only changes names, the runtime-library glob, the archive format and
the README's OS-specific paragraphs, so the macOS run exercises the same code
path up to the binary it stages.

## Continuous compilation

`.github/workflows/cross-platform.yml` is a manual workflow (no push trigger)
with three runners: `ubuntu-24.04`, `windows-2022`, `macos-15`. It checks out
the framework at the commit in `framework_pins.txt` (or a ref given at dispatch
time), applies `tools/mouse_mod_framework.patch` to it, and then configures and
builds through the same presets a builder uses: `linux-x64-setup` on Linux
(Unix Makefiles), `windows-x64-setup` on Windows (Visual Studio 17 2022) and
`macos-arm64-setup` on macOS (Ninja). A successful run therefore exercises the
documented commands, not a CI-only spelling of them.

It builds the **setup host**, not the game, for the reason the framework's own
release documentation gives: `src/gen/*.c` is recompiler output derived from
ROM bytes, is not committed, and CI has no ROM. The setup host still compiles
every port source file, including `mouse_cursor.c` and `game_rtl.c`, so a
Windows compiler error in the port is caught there. It is also the executable a
setup pack ships. The Linux job installs the X11/Wayland/audio development
packages the README lists, because SDL configures no desktop backend without
them and a green build with a dummy-only SDL would prove less than it appears.

The workflow is manual because `framework_pins.txt` names a local framework
commit and this checkout has no `snesrecomp/` submodule, so a push trigger
would fail before compiling a line until the pin is reachable from the default
checkout or a mirror is supplied. It was not run for this record: no remote is
configured in this checkout and no Windows/Linux host was available.

## What is verified, and what is not

| claim | evidence |
|---|---|
| macOS arm64 builds and runs with the change | `build-mouse` headless run; the four DMG packaging legs in `evidence/mouse_mod.md` |
| macOS universal compiles and links both slices | `lipo -archs` on `build-macos-universal` and `build-embed-universal`; arm64 slice runs |
| the port has no remaining POSIX-only call | grep of `src/`, `recomp/`, generated tree; only `game_rtl.c` hit, now removed |
| the presets parse and the Makefiles path builds | `cmake --list-presets=all`; `linux-x64` configured with `CMAKE_GENERATOR=Unix Makefiles`, `CMAKE_BUILD_TYPE=Release`, built and booted 120 frames on this host |
| a framework without the mouse patch stops at configure | worktree at `32266300`, no patch: CMake exits 1 naming `snesrecomp_desktop_mouse_state` and the `git apply` command |
| the framework patch applies to the pin and the DMG base | `git apply --check` in worktrees at `773285b8`, `32266300` and `a7fb67e6` |
| the packager handles a Visual Studio layout | fake tree with exe + `mods/` under `Release/`: found, staged and zipped as `windows-x64` |
| the packager produces deterministic archives | two `.tar.gz` runs two seconds apart byte-identical; two `.zip` runs byte-identical; `.sha256`; archive member re-hash; `--help` smoke |
| the German and Swedish editions build, boot and render their menus | macOS arm64 builds from `recomp-lle/`; 16,188-frame headless route; localized main menus; `evidence/language_roms.md` |
| the translations keep the hand at the same WRAM words | `$7E01D4/6/8` hold the USA trajectory frame-for-frame; `evidence/language_roms.md` |
| Windows and Linux compile | Linux arm64: full universal build in an Ubuntu 24.04 container (2026-11-11, below); Windows x86-64: MinGW-w64 cross-build of the same tree. MSVC and Linux x86-64 remain unexecuted |
| Windows and Linux run | Linux arm64 boots all three editions headless; no Windows host, VM or container ran the `.exe` |

The table above records this round's original scope. The next section adds the
universal-build measurements on Linux and Windows; Windows execution and the
MSVC path remain unmeasured.

## The universal build on Linux and Windows

Date: 2026-11-11. The tree now links the USA, German and Swedish trees as
separate program modules and selects one from the loaded ROM's digest
(`src/edition.c`; `tools/regen-all-editions.sh` generates the three trees).
The macOS measurements are the sections above; this round took the same
universal tree to the other hosts.

| host | what ran | result |
|---|---|---|
| Linux arm64 | Ubuntu 24.04 container (`container` on this arm64 host), `cmake --preset linux-arm64`, full build from `src/gen`, `src/gen-de`, `src/gen-sv` | clean; `SDL_VIDEODRIVER=dummy` booted USA, German and Swedish, each selecting its own module and passing `selfcheck.txt` / `selfcheck-intl.txt`; a 1 MiB zero image exited 1 |
| Windows x86-64 | MinGW-w64 16.2 cross-build of the same full tree (`x86_64-w64-mingw32-gcc/g++`, Unix Makefiles) | `PE32+ executable (console) x86-64` with all three modules; `tools/package_desktop.py --platform windows-x64` produced `shadowrun-universal-0.1.0-windows-x64.zip`; not executed |

The Linux run used the commands README gives for that host:

```sh
apt-get install build-essential cmake python3 git libgl1-mesa-dev libegl1-mesa-dev \
  libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev \
  libxss-dev libxtst-dev libxkbcommon-dev libwayland-dev libdecor-0-dev \
  libasound2-dev libpulse-dev libudev-dev libdbus-1-dev
export SNESRECOMP_ROOT=/path/to/patched/snesrecomp
cmake --preset linux-arm64
cmake --build --preset linux-arm64 --parallel 8
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy ./build-linux-arm64/ShadowrunSNESRecomp \
  --no-launcher --rom "Shadowrun (Germany).sfc" --script tests/scripts/selfcheck-intl.txt
```

The Windows cross-build is a compile check, not a supported player path: the
`windows-x64` preset names Visual Studio 2022, and no MSVC compiler ran here. A
temporary CMake toolchain file (`CMAKE_SYSTEM_NAME Windows`, the MinGW
compilers) let the same sources and generated modules link as a PE image. That
proves the universal table, `src/edition.c` and the three prefixed trees are
not clang-only; it does not prove the MSVC build, and the `.exe` was not run.

Not verified: Windows x86-64 execution, MSVC compilation, and a Linux x86-64
binary (the container is arm64; x86-64 emulation needs Rosetta, absent on this
host). The workflow is what closes those gaps on real runners.

## MSVC Release registered no program modules (2026-11-11)

The first MSVC run on a real Windows 10 host (Visual Studio 2022, x64) built
Debug first: it ran, but unplayably (unoptimised tree, 28 MB). The Release
build was ~7 MB, as expected, and then **exited immediately after the ROM was
chosen**. Its `last_run_report.json` ended at:

```
config parsed: output=0 new_renderer=1 scale=3 fullscreen=0 audio=1 ...
rom resolved: C:\snesdev\Shadowrun (USA).sfc
SDL init ok: video=windows audio=wasapi
rom loaded: 1048576 bytes
```

with `reason: atexit`, no `SnesInit` breadcrumb and an empty `seh`: the process
left inside `ShadowrunOnRomLoaded`, the only path there that calls `exit(1)`.
A USA dump whose size is exactly the expected 1,048,576 bytes and whose bytes
match `rom_identity.txt` was being refused because
`snes_program_module_count()` was **0**: the generated trees had been compiled
and linked (the image is three editions wide), but their registration
constructors were gone.

Cause: `SNES_PROGRAM_MODULE_CONSTRUCTOR` places a `static` function pointer in
`.CRT$XCU`, which the CRT walks before `main()`. The C compiler cannot see that
walk, and an internal-linkage pointer with a constant initialiser is dead code
under MSVC's whole-program optimisation, so a Release link drops it. Debug
(`/Od`, no `/GL`, `/OPT:NOREF`) keeps it, which is why the same tree booted in
Debug and not in Release. A single-edition build is unaffected because the
framework's default dispatch already points at the stock tree; only a universal
tree needs the registry to choose between modules.

The mechanism reproduces at object level without `cl.exe`, with clang in MSVC
mode:

| form | `.CRT$XCU` in the `.obj` |
|---|---|
| `static void (*p)(void) = f;`, `__declspec(allocate(".CRT$XCU"))` | **absent** — LLVM drops the unused static pointer and `f` |
| `void (*p)(void) = f;` (external) plus `__pragma(comment(linker, "/include:p"))` | present; `.drectve` holds `/include:p` |

The external form is the fix the framework already uses for its interpreter
dump hook (`runner/src/interp_bridge.c`), for the same reason. Because the
symbol is now external, each generated tree needs its own name: `v2_emit` emits
`snes_program_module_register_<module-id>` (`main`, `shadowrun_de`,
`shadowrun_sv`) instead of one shared identifier. The changes are
`runner/src/program_module.h`, `recompiler/v2/program_emit.py` and its test,
carried as `tools/msvc_program_module_framework.patch`.

`src/edition.c` now records the selection attempt in the always-on breadcrumb
ring and prints the image's own SHA-256 on refusal, so a remote failure names
the ROM it got instead of only the digests the build expects. It also says
explicitly when the registry is empty, which distinguishes this build defect
from a genuinely unknown dump. On this host the universal build still selects
USA, German and Swedish (`3 module(s) registered`) and refuses a 1 MiB zero
image with exit 1.

Still unverified here: compilation with `cl.exe`/`link.exe`, and the corrected
Release executable on the Windows host. The patch is mechanical and matches
the framework's own working `/include:` pattern, but the run that proves it is
the user's.

## Language editions

The same tree also builds the German and Swedish translations, as separate
editions selected by `SHADOWRUN_EDITION` (the `-de` and `-sv` presets). Their
inserted text moved the code, so each has its own generated tree (`src/gen-de`,
`src/gen-sv`), generated from `recomp-lle/` without the USA symbol addresses,
and its hand cursor sits `0x1C` lower at `$7E01D4/$7E01D6/$7E01D8`. Both built
on this host, ran the full 16,188-frame scripted route without an architectural
`BRK`, and rendered their own localized main menus. `evidence/language_roms.md`
records the digests, byte diffs, generation counts, menu screenshots and the
WRAM measurement. No MSVC or Linux compile of a translation edition was run
here, and the translations were not driven by a real pointer on this host.
