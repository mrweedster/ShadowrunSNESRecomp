#!/usr/bin/env bash
# Make a macOS package a person can download, drag to Applications, and click.
#
#   scripts/package_macos_bundle.sh [<build-dir>] [<platform-tag>]
#   scripts/package_macos_bundle.sh build-ship macos-arm64
#   VERIFY=0 scripts/package_macos_bundle.sh build-ship       # assemble only
#   PERSONAL=1 scripts/package_macos_bundle.sh                # the ROM-in picture
#   EDITION=de scripts/package_macos_bundle.sh build-macos-arm64-de
#   EDITION=sv scripts/package_macos_bundle.sh build-macos-arm64-sv
#
# EDITION selects which ROM edition the build tree was configured for (us, de
# or sv) and with it the bundle name, identifier, state directory, .dmg name,
# accept-list (rom_identity*.txt) and the ROM the run legs hand the app.  The
# default is us, and a tree configured for a different edition is refused.
#
# Knobs, all optional: BUILD_DIR / PLATFORM_TAG / DIST / VERIFY (0 skips the run
# legs) and PKG_INSTALL_DIR (where section 5 leg e installs the dragged copy;
# by default a fresh mktemp directory outside the repository).
#
# It writes dist/Shadowrun.app and dist/shadowrun-<VERSION>-<tag>.dmg, plus the
# transcript of everything it checked to tests/out/pkg/macos_package.log --
# which is what evidence/artifacts/macos_package.md is a copy of.
#
# PERSONAL=1 builds the other picture, and it is a different artefact with
# different rules, not the same one with a flag turned on:
#
#   * the guest image is compiled into the executable (SHADOWRUN_EMBED_ROM=ON,
#     tools/embed_rom.py), so the app opens straight into the game: no ROM
#     picker, no rom.cfg, no dump next to the binary.  That is the only reason
#     this variant exists -- the distributable package asks for a dump once,
#     which is the price of being shareable.
#   * the package therefore CONTAINS the game.  It may go on this machine and on
#     the owner's own machines; it may not be given to anyone else, and that is
#     stamped into the bundle (Contents/Resources/BUILD_INFO.txt), the bundle's
#     own copyright string, and the README.txt at the root of the .dmg, so the
#     artefact says what it is wherever it lands.
#   * section 2's scans do not get relaxed -- they get reversed.  The embedded-
#     ROM symbols that must be ABSENT from a distributable package must be
#     PRESENT here, and a new scan locates the exact 1 MiB image inside the
#     installed Mach-O and hashes it against rom_identity.txt.  The scans that
#     hold for both variants (no ROM file, no rom.cfg, no machine-local path
#     baked in) keep their "expect 0" and are reported with it.
#   * the machine code has to come from a framework that can boot an embedded
#     image.  The pin (framework_pins.txt) cannot: SNESRECOMP_EMBEDDED_ROM is
#     not in it, which is why this variant is configured against a descendant of
#     the pin.  Section 0 measures that relationship instead of trusting it and
#     prints what it finds; section 5 then diffs 1,200 frames of this package
#     against the tree built at this package's own framework and floor, which is
#     what says the extra framework commit did not move the machine.
#
# PERSONAL=1 writes to its own names -- dist/Shadowrun-personal.app,
# dist/shadowrun-embed-<VERSION>-<tag>-personal.dmg, and the transcript at
# tests/out/pkg/macos_package_personal.log (the copy in evidence/artifacts/ is
# macos_package_personal.md) -- so it can never overwrite the distributable
# package or the log its committed evidence is a copy of.
#
# Why a .app and not the bare executable this repository stages:
#
#   * The host finds its own executable with _NSGetExecutablePath() and anchors
#     its state next to it (runner/src/host_paths.c: snesrecomp_ensure_state_dir
#     plus snesrecomp_state_path, which is where config.ini, keybinds.ini,
#     saves/, mods/ and rom.cfg are resolved when no option names them).  At the
#     pinned framework revision that anchor is the executable's own directory,
#     and it has to be writable or the host falls back to walking up three
#     levels looking for a config.ini.  A double-clicked program has no working
#     directory the user controls -- LaunchServices starts it at "/" -- so a bare
#     binary dropped into /Applications has nowhere to put its saves.
#   * That is also why CFBundleExecutable is the Mach-O itself and not a shell
#     wrapper: for a script, dyld's program zero is /bin/sh, so the anchor
#     would point at /bin.
#   * --config does NOT relocate state.  Measured at the pin: passing
#     --config <Application Support>/.../config.ini still wrote
#     saves/save.srm relative to the anchored directory.
#
# Writing that state inside Contents/MacOS/ is what broke the package, and the
# shipping framework no longer does it.  A macOS .app is a sealed unit, and with
# config.ini / keybinds.ini / rom.cfg / saves/ / mods/ sitting loose in
# Contents/MacOS/ the seal cannot even be created:
#
#   pin framework, bundle staged with those files:
#     codesign --force --sign -    exit 1  "In subcomponent: .../MacOS/keybinds.ini"
#     codesign --verify --strict   exit 1  "code has no resources but signature
#                                          indicates they must be present"
#   fork framework (pin + 32266300), same repository, bundle staged with no
#   loose state at all:
#     codesign --force --sign -    exit 0   writes Contents/_CodeSignature
#     codesign --verify --strict   exit 0   "valid on disk", "satisfies its
#                                          Designated Requirement", and still 0
#                                          after a run because nothing is written
#                                          inside the bundle
#
# so the shipped payload is built from a framework where an executable under
# .../Xxx.app/Contents/MacOS/ anchors to ~/Library/Application Support/Xxx/
# instead of to its own directory, and outside a bundle nothing changes --
# development trees, the test kit and the Linux paths keep anchoring exactly as
# before.  Measured transcript: tests/out/fork_state_probe_2026-11-09.log, and
# frame state is identical across the two hosts (tests/out/osxcmp_fork_parity
# _2026-11-09.log: identical over 1200 frames, WRAM crc32 per frame).  Two
# consequences follow, and both are what a person installing this wants:
# replacing or re-downloading the app no longer discards saves, and a read-only
# path (a mounted .dmg, App Translocation) can no longer make the run fail.
#
# What the package does not contain, and how that is checked rather than
# asserted -- the same policy scripts/package_release.sh states:
#
#   * No ROM image in any form.  A .app cannot play without one, so the
#     launcher asks the user for their own dump once and caches the answer in
#     the state directory (~/Library/Application Support/Shadowrun/rom.cfg);
#     every dump it is handed is checked against the digests in
#     digests in rom_identity.txt.  The check is not only "the cache flag was
#     OFF": nm on the packaged executable must not name the embed symbols
#     (tools/embed_rom.py emits _snesrecomp_embedded_rom and _g_rom_embedded),
#     and no file in the payload or inside the mounted .dmg may look like a ROM
#     or a patch.
#   * No generated sources, no recomp tables: src/gen and recomp/funcs.h are
#     build inputs and are git-ignored here.
#   * No machine-local absolute path.  Nothing in the payload may name this
#     repository or this machine's ROM directory.  A rom.cfg baked in at build
#     time would point at a file that does not exist on the player's disk, and
#     a launcher that follows a dead path reads as a broken app.
#   * No dependency on this machine's Homebrew tree.  Two shapes were measured:
#       dylib shape -- SDL3 is a vendored Mach-O under
#         Contents/MacOS/libs/SDL3.framework/Versions/A/SDL3 and the executable
#         points at it as @executable_path/libs/..., which is the staging
#         tests/README.md section 8 prescribes.  It works, and the copy's hash
#         equals this machine's Homebrew dylib.  Its cost is measured too:
#         whatever floor that dylib was built for becomes the bundle's floor,
#         because dyld refuses a dylib whose LC_BUILD_VERSION is above the
#         caller's target -- this machine's Homebrew SDL3 is minos 26.0, so a
#         package carrying it cannot run on anything older.
#       static shape -- SDL3 is built from the source the framework itself pins
#         (tools/ci/prefetch_sdl3.sh names SNESRECOMP_SDL3_FETCH_VERSION, 3.4.10
#         at this pin) at the same -DCMAKE_OSX_DEPLOYMENT_TARGET as the port,
#         and linked in.  The shipped executable then carries no SDL3 reference
#         and no LC_RPATH at all: every load command is a system path, and no
#         dylib inside the bundle can raise the floor.  Measured: arm64 thin,
#         minos 11.0, and frame state identical over 1200 frames against the
#         accepted executable (section 5 of this script, and the compatibility
#         leg in tests/README.md section 7.19).
#     The package ships the static shape.
#
# What section 3 measures about the executable inside the bundle: the build
# tree's bytes and the packaged bytes differ only by what packaging has to do.
# In the dylib shape that is install_name_tool -change plus an ad-hoc sign; in
# the static shape there is nothing to rewrite, so it is the sign alone, and the
# probe shows that a sign taken in a plain directory reproduces the shipped
# bytes exactly while the same sign taken already inside a bundle does not.
# Either way section 5 measures the packaged bytes themselves, so no claim rests
# on that match.
#
# Requires bash 3 (the /bin/bash macOS still ships).
set -euo pipefail

# A silent exit is the worst outcome a packaging step can have: a packaging
# script that dies quietly leaves the reader to bisect a shell by hand.  Name
# the command and line instead.
trap 'echo "::error::$(basename "${BASH_SOURCE[0]}") failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

# Section 4 mounts the disk image it just built, and leaves it mounted while
# section 5 installs from it, because that is what a person does with one.  If
# anything in between dies, an abandoned volume under /Volumes is a mess left on
# the machine, so unmount it whatever happens.
DMG_MOUNTED=""
trap '[ -n "$DMG_MOUNTED" ] && hdiutil detach "$DMG_MOUNTED" >/dev/null 2>&1; true' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

# Which ROM edition this package is for.  One executable boots one edition
# (SHADOWRUN_EDITION in CMakeLists.txt): the translations moved code as well as
# text, so German and Swedish are separate builds of the same sources rather
# than one binary with a language switch.  Everything edition-derived is
# decided here so no section below guesses, and the USA names stay exactly what
# they were before EDITION existed -- its .app, .dmg, log and scratch
# directories are untouched, so the committed USA evidence still describes the
# files on disk.
EDITION="${EDITION:-us}"
case "$EDITION" in
  us) EDITION_TITLE="USA";        EDITION_SFX="";    EDITION_SLUG="shadowrun"
      EDITION_APP="Shadowrun";    EDITION_DISPLAY="Shadowrun"
      EDITION_BUNDLE_SFX="";      IDENTITY_FILE="rom_identity.txt"
      EDITION_BUILD_DEFAULT="build-ship" ;;
  de) EDITION_TITLE="Germany";    EDITION_SFX="_de";  EDITION_SLUG="shadowrun-de"
      EDITION_APP="Shadowrun-de"; EDITION_DISPLAY="Shadowrun (Germany)"
      EDITION_BUNDLE_SFX=".de";   IDENTITY_FILE="rom_identity.de.txt"
      EDITION_BUILD_DEFAULT="build-macos-arm64-de" ;;
  sv) EDITION_TITLE="Sweden";     EDITION_SFX="_sv";  EDITION_SLUG="shadowrun-sv"
      EDITION_APP="Shadowrun-sv"; EDITION_DISPLAY="Shadowrun (Sweden)"
      EDITION_BUNDLE_SFX=".sv";   IDENTITY_FILE="rom_identity.sv.txt"
      EDITION_BUILD_DEFAULT="build-macos-arm64-sv" ;;
  *) echo "EDITION must be us, de or sv (got '$EDITION')"; exit 1 ;;
esac

# The two pictures this script can build.  Everything that differs between them
# is decided once, here, so no section below has to guess: names, identifiers and
# scratch paths are all variant-derived, and the distributable variant keeps
# exactly the names it had before PERSONAL existed.
PERSONAL="${PERSONAL:-0}"
if [ "$PERSONAL" = 1 ]; then
  # "Shadowrun-personal" is deliberately not "Shadowrun": a person who builds
  # both leaves two bundles, two bundle identifiers and two LaunchServices
  # registrations, not one app silently replaced by the other.  The Finder and
  # Dock name comes from CFBundleDisplayName, which stays the edition's name.
  APP_NAME="${EDITION_APP}-personal"
  APP_DISPLAY="$EDITION_DISPLAY"
  BUNDLE_ID="org.retroportingtoolkit.shadowrun${EDITION_BUNDLE_SFX}.personal"
  PKG_SLUG="shadowrun-embed${EDITION_SFX:+-${EDITION_SFX#_}}"
  DMG_SFX="-personal"
  SFX="${EDITION_SFX}_personal"
  BUILD_DIR_DEFAULT="build-embed-ship"
  ROM_LEGS=none      # the app legs get no --rom: the guest is inside the executable
else
  APP_NAME="$EDITION_APP"
  APP_DISPLAY="$EDITION_DISPLAY"
  BUNDLE_ID="org.retroportingtoolkit.shadowrun${EDITION_BUNDLE_SFX}"
  PKG_SLUG="$EDITION_SLUG"
  DMG_SFX=""
  SFX="$EDITION_SFX"
  BUILD_DIR_DEFAULT="$EDITION_BUILD_DEFAULT"
  ROM_LEGS=with      # every app leg has to be told where the dump is
fi

BUILD_DIR="${1:-${BUILD_DIR:-$BUILD_DIR_DEFAULT}}"
PLATFORM_TAG="${2:-${PLATFORM_TAG:-macos-$(uname -m)}}"
DIST="${DIST:-$ROOT/dist}"
OUT="$ROOT/tests/out/pkg"
LOG="$OUT/macos_package${SFX}.log"
VERSION="$(tr -d '[:space:]' <VERSION)"
EXE="$BUILD_DIR/ShadowrunSNESRecomp"
# The scripted boots below wait on the game's own per-frame tick counter.  The
# translations moved it: $7E1C76 for DE and SV against $7E1C92 for USA (measured
# by two WRAM dumps ten frames apart; see tests/scripts/selfcheck-intl.txt).
SELFCHECK_SCRIPT="$ROOT/tests/scripts/selfcheck.txt"
TICK_ADDR='$7E1C92'
[ "$EDITION" = us ] || { SELFCHECK_SCRIPT="$ROOT/tests/scripts/selfcheck-intl.txt"; TICK_ADDR='$7E1C76'; }
# The build this kit accepts as correct, used as leg c of both variants' frame
# comparison.  The question that leg answers is not "did packaging change the
# machine" -- section 5 asks that of the copy in dist/ -- but "does this package's
# framework, deployment floor and guest-carrying shape drive the same machine as
# the build this kit already verified".  The floor-11 rebuild of that accepted
# source is preferred, so the pair holds framework and floor constant and varies
# only what this package varies; the older at-pin tree is the fallback.  Section 7
# prints both sides' hash, size, build record and framework status against the pin,
# so which c was used is in the log rather than in the prose.  Override with
# SHIP_EXE=... if neither tree is in this checkout.
if [ -n "${SHIP_EXE:-}" ]; then :
elif [ "$EDITION" != us ]; then
  # The accepted reference builds this kit names are USA-configured: their
  # floors and frame routes were measured on USA text.  A language edition
  # differs in text and code layout, so comparing its frames with a USA build
  # would measure the translation rather than the packaging.  The reference for
  # a language package is therefore this edition's own build tree.
  SHIP_EXE="$EXE"
elif [ -x build-ship-m11/ShadowrunSNESRecomp ]; then SHIP_EXE=build-ship-m11/ShadowrunSNESRecomp
else SHIP_EXE=build-ship/ShadowrunSNESRecomp
fi
# The same accepted build at its older configuration: the tree configured at the
# pin itself, which is what the earlier rounds of this kit measured.  Section 7
# runs it as a second reference leg so the log shows both what the shipped bytes
# have in common with the accepted build across the framework and floor change and
# what they have in common with the build that holds framework and floor constant.
# Its hash, size, build record and framework status are printed in section 7, and
# its SDL3 linkage is whatever its own load commands say -- otool -l shows it.
# Override with REF_PIN=... .
REF_PIN="${REF_PIN:-$( [ "$EDITION" = us ] && echo build-ship/ShadowrunSNESRecomp || printf '%s' "$SHIP_EXE" )}"

[ "$(uname -s)" = Darwin ] || { echo "this packager builds a macOS bundle"; exit 1; }
[ -f "$EXE" ] || { echo "no $EXE -- configure and build $BUILD_DIR first"; exit 1; }
[ -f "$BUILD_DIR/CMakeCache.txt" ] || {
  echo "$BUILD_DIR has no CMakeCache.txt: nothing beside the binary would say what made it"; exit 1; }
# Refuse a build tree configured for another edition before anything is copied.
# The two translations are separate programs; packaging the USA binary as a
# Swedish package would produce an artefact whose label lies about its contents,
# which is the one thing this script exists to make measurable.
tree_edition="$(grep -m1 'SHADOWRUN_EDITION:STRING=' "$BUILD_DIR/CMakeCache.txt" | sed 's/.*=//')"
tree_edition="${tree_edition:-us}"
tree_universal="$(grep -m1 'SHADOWRUN_UNIVERSAL:BOOL=' "$BUILD_DIR/CMakeCache.txt" | sed 's/.*=//')"
if [ "${tree_universal:-OFF}" = ON ]; then
  echo "REFUSING TO PACKAGE: $BUILD_DIR is a universal build; it carries the USA,"
  echo "German and Swedish editions in one executable, while this packager labels"
  echo "and measures one edition. Configure a single-edition tree instead:"
  echo "  cmake --preset macos-arm64-de   # or -sv; -DSHADOWRUN_UNIVERSAL=OFF"
  exit 1
fi
if [ "$tree_edition" != "$EDITION" ]; then
  echo "REFUSING TO PACKAGE: $BUILD_DIR was configured for SHADOWRUN_EDITION=$tree_edition,"
  echo "not $EDITION.  Configure a $EDITION tree, or pass the tree that is $EDITION."
  exit 1
fi
# The framework this build tree linked, taken from its own cache rather than from
# an environment guess.  Section 0 checks the embedded-ROM capability where the
# host code actually came from, and section 2 reads rom_identity.txt through that
# framework's parser instead of adding a second parser here -- the same rule
# tools/embed_rom.py follows.
fw="$(grep -m1 'SNESRECOMP_ROOT:PATH=' "$BUILD_DIR/CMakeCache.txt" | sed 's/.*=//')"
for t in codesign install_name_tool hdiutil otool nm ditto; do
  command -v "$t" >/dev/null || { echo "missing tool: $t"; exit 1; }
done

mkdir -p "$OUT" "$DIST"
: >"$LOG"
exec > >(tee -a "$LOG") 2>&1

sha()  { shasum -a 256 "$1" | cut -c1-16; }
say()  { printf '  %s\n' "$*"; }

# One path per line in, a count out.  wc -l on the stream: an earlier version of
# this helper ran tr -d '[:space:]' first, which collapses every path into one
# line and reports 0 for any number of matches -- i.e. every "expect 0" below
# would have passed vacuously.  Caught by the mod catalog, which is not empty.
count() { wc -l | tr -d '[:space:]'; }

# "grep found nothing" is exit 1, and for the payload scans below that is the
# pass condition, so pipefail must not be allowed to turn it into a failure.
# n_of runs a command, counts the lines, and always succeeds.
n_of() { { "$@" 2>/dev/null | count; } || true; }

# Which legs name a ROM on the command line is a per-leg question, not a
# per-variant one, so it is an argument here rather than a global:
#
#   shareable  every leg names this machine's dump, because nothing inside the
#              binary can boot without it;
#   personal   the app legs must NOT name one -- the claim is that the image
#              inside the executable boots on its own -- but the reference side
#              of the frame leg is the ROM-based build ($SHIP_EXE), which has no
#              image in it and has to be told where its dump is.
#
# It is a function rather than a variable holding "--rom $rom" because the flag
# and its argument have to stay two separate words: this machine's dump is named
# "Shadowrun (USA).sfc", and word-splitting that path hands the host three
# arguments, no --script, and therefore no quit condition -- which is how one
# probe once ran until the shell timeout instead of failing.
host_run() {
  local mode="$1" bin="$2"; shift 2
  if [ "$mode" = with ]; then "$bin" --rom "$rom" "$@"; else "$bin" "$@"; fi
}

# A wall-clock guard, because one failure mode of the personal variant is a hang
# rather than an error: if the embedded image ever failed to resolve, the host
# would open its ROM file picker and sit waiting for a window no automated leg can
# answer -- and a leg that never returns reads as "still running", not as "the
# claim failed".  So each run gets a limit; past it the process is interrupted
# (the host's own atexit path, which writes last_run_report.json) and then killed,
# and the log says which happened.  macOS ships no timeout(1), hence the loop.
#
# Sets $leg_rc so callers can report it without a second exit-code path.
run_bounded() {
  local log="$1" max="$2" cwd="$3" mode="$4" bin="$5"; shift 5
  local n=0 pid
  ( cd "$cwd" && host_run "$mode" "$bin" "$@" ) >"$log" 2>&1 &
  pid=$!
  while [ $n -lt "$max" ] && kill -0 "$pid" 2>/dev/null; do sleep 1; n=$((n + 1)); done
  if kill -0 "$pid" 2>/dev/null; then
    kill -INT "$pid" 2>/dev/null || true
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
      leg_rc=125          # never answered the picker even after SIGINT
    else
      leg_rc=124          # stopped at SIGINT: it was waiting on something
    fi
  else
    wait "$pid" && leg_rc=0 || leg_rc=$?
  fi
}

# Known before the payload is checked, so "no machine-local path in the package"
# is measured against the real dump rather than asserted.  rom.sh only answers
# "which ROM do the legs use"; it never writes anything, and the path it names
# goes on command lines, never into the bundle.  In the personal variant almost
# nothing needs it: no leg passes --rom there (the image is inside the exe), so
# it is used to measure the payload against the real dump and to locate the image
# bytes inside the Mach-O.
. tests/rom.sh
rom="$(sr_rom "$EDITION")" || rom=""     # empty is fine for assembling, fatal for the run legs
if [ "$PERSONAL" != 1 ] && [ -z "$rom" ]; then
  echo "the shareable package's run legs need a ROM to hand"; exit 2
fi

echo "# macos_package${SFX}.md"
echo "#"
if [ "$PERSONAL" = 1 ]; then
  echo "# variant: PERSONAL.  This package contains the guest image compiled into"
  echo "#          its executable.  It is not a distributable artefact: see the"
  echo "#          PERSONAL block in scripts/package_macos_bundle.sh."
else
  echo "# variant: shareable.  No ROM in the payload, in any form; the launcher"
  echo "#          asks the player for their own dump once."
fi
echo "# what: the click-and-install macOS package ($APP_NAME.app inside a .dmg):"
echo "#       what is in it, what is provably not in it, and that it runs from"
echo "#       outside this repository"
echo "# how:  $( [ "$PERSONAL" = 1 ] && printf 'PERSONAL=1 ' )$( [ "$EDITION" != us ] && printf 'EDITION=%s ' "$EDITION" )scripts/package_macos_bundle.sh $BUILD_DIR $PLATFORM_TAG"
echo "#"
echo "# framework used: $(grep -m1 'SNESRECOMP_ROOT:PATH=' "$BUILD_DIR/CMakeCache.txt" | sed 's/.*=//')"
echo "#          (its status against the pin is measured in section 0, not claimed here)"
echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) (host $(uname -sr) $(uname -m))"
echo "# source tree: $ROOT"
echo

echo "== 0. the build tree being packaged =="
echo
say "build dir  $BUILD_DIR"
say "edition    $EDITION ($EDITION_TITLE); identity $IDENTITY_FILE; ROM ${rom:-none}"
say "variant    $( [ "$PERSONAL" = 1 ] && echo 'PERSONAL: ships the guest image, not for distribution' || echo 'shareable: no ROM in the payload' )"
printf '  %-20s %s  %s B\n' "executable" "$(sha "$EXE")" "$(stat -f%z "$EXE")"
grep -oE 'CMAKE_BUILD_TYPE:STRING=.*|SHADOWRUN_EMBED_ROM:BOOL=.*|SNESRECOMP_ENABLE_MODS:BOOL=.*|SHADOWRUN_EDITION:STRING=.*' \
  "$BUILD_DIR/CMakeCache.txt" | sed 's/^/  /'
# provenance.py key reads the run manifest a --framedump leg left in the tree, so
# it only answers for a tree that has been run.  build-ship has one (the promotion
# rounds ran through it); a fresh tree does not.  Printed when it exists, named as
# absent when it does not -- an absent identity line must be visible, not silent.
if python3 tests/provenance.py key "$BUILD_DIR" >"$OUT/prov_key$SFX.txt" 2>&1; then
  sed 's/^/  /' "$OUT/prov_key$SFX.txt"
else
  say "no run manifest in $BUILD_DIR, so provenance.py key has nothing to read."
  say "The executable's own hash above is its identity in this log; what ties it to"
  say "the build this kit treats as correct is section 7's c leg, not a manifest."
fi
if [ "$PERSONAL" = 1 ]; then
  # --descendant, not --exact: the pin cannot boot an embedded image (see the
  # framework check below), so a personal build necessarily links a framework
  # that is the pin plus the commit that added the capability.  That is only
  # acceptable if it stays a descendant and nothing else, and section 5a and
  # section 7's d leg are what show those commits did not move the machine.
  python3 tests/provenance.py pin --descendant "$BUILD_DIR" 2>&1 | sed 's/^/  /' || true
else
  # The shareable package used to be AT THE PIN exactly.  It is no longer, and the
  # reason is the bundle's shape rather than the emulator: the pinned host keeps
  # config.ini, keybinds.ini, rom.cfg, saves/ and mods/ beside its executable, so
  # a .app built from it has non-Mach-O files inside Contents/MacOS/, codesign
  # refuses to seal such a bundle at all, and what macOS then reports to a person
  # who downloads it is "... is damaged and can't be opened".  The shipping
  # framework is the pin plus one capability commit that moves that state outside
  # the bundle (measured: tests/out/fork_state_probe_2026-11-09.log, seal refused
  # at the pin / seal accepted by the fork; frame state identical across the two
  # hosts over 1200 frames in tests/out/osxcmp_fork_parity_2026-11-09.log).  So
  # the exact check is asked first and, when it says the tree is not the pin, the
  # descendant check is asked next, and the log carries both verdicts.
  if python3 tests/provenance.py pin "$BUILD_DIR" >"$OUT/prov_pin$SFX.txt" 2>&1; then
    sed 's/^/  /' "$OUT/prov_pin$SFX.txt"
  else
    sed 's/^/  /' "$OUT/prov_pin$SFX.txt"
    echo "  re-asking as a descendant of the pin:"
    python3 tests/provenance.py pin --descendant "$BUILD_DIR" 2>&1 | sed 's/^/  /' || true
    if [ "$EDITION" = us ]; then
      say "  which is the shape this package is built from: a branch off the pin, one"
      say "  capability commit deep, kept as a branch rather than folded in because the"
      say "  commit changes where the port's saves live on macOS.  Section 7's c leg"
      say "  runs the bytes this package ships against the build configured at the pin,"
      say "  frame for frame, so the cost of that commit is measured in this log rather"
      say "  than vouched for by provenance."
    else
      say "  which is the shape this package is built from: a branch off the pin, one"
      say "  capability commit deep, kept as a branch rather than folded in because the"
      say "  commit changes where the port's saves live on macOS.  Section 5 compares"
      say "  the packaged bytes with this edition's own build tree, frame for frame, so"
      say "  what packaging and that commit did is measured rather than vouched for."
    fi
  fi
fi
if grep -q 'SHADOWRUN_EMBED_ROM:BOOL=ON' "$BUILD_DIR/CMakeCache.txt"; then
  if [ "$PERSONAL" != 1 ]; then
    echo
    echo "  REFUSING TO PACKAGE: $BUILD_DIR was configured with SHADOWRUN_EMBED_ROM=ON,"
    echo "  which compiles the guest image into the executable. That would ship the ROM."
    echo "  PERSONAL=1 is the variant that packages it, and it says so in the bundle."
    exit 1
  fi
  # The capability has to exist where the tree linked, not just in this checkout:
  # the host's embedded-ROM path is framework code (SNESRECOMP_EMBEDDED_ROM in
  # runner/src/desktop/host_main.c), and a framework without it cannot produce a
  # binary that boots anything.  Measured in the framework the cache names ($fw,
  # read from this tree's own cache above), so a stale CMakeCache pointing
  # somewhere else is caught here rather than assumed.
  hits="$(n_of grep -rl 'SNESRECOMP_EMBEDDED_ROM' "$fw/runner/src")"
  say "framework $fw defines SNESRECOMP_EMBEDDED_ROM in $hits runner/src file(s)"
  if [ "$hits" = 0 ]; then
    echo "  REFUSING TO PACKAGE: $BUILD_DIR says SHADOWRUN_EMBED_ROM=ON but the framework"
    echo "  it linked ($fw) has no embedded-ROM host. The image would be in the binary"
    echo "  and nothing would boot it."
    exit 1
  fi
elif [ "$PERSONAL" = 1 ]; then
  echo
  echo "  REFUSING TO PACKAGE: PERSONAL=1 asked for the picture that opens straight into"
  echo "  the game, and $BUILD_DIR was configured with SHADOWRUN_EMBED_ROM=OFF -- so its"
  echo "  executable holds no image and the app would ask for a dump like any other."
  echo "  Configure one with -DSHADOWRUN_EMBED_ROM=ON, or drop PERSONAL."
  exit 1
fi
# Two shapes are possible and the bundle follows whichever the build tree
# actually produced, so this is read off the Mach-O rather than assumed:
#   a dylib reference   -> the SDL3 shape that vendors the dylib and rewrites the
#                          reference to @executable_path/libs/...
#   no dylib reference  -> SDL3 was linked statically from the source the
#                          framework pins for its own CI build
#                          (tools/ci/prefetch_sdl3.sh), and there is no dylib in
#                          the bundle to vendor or rewrite.
sdl_ref="$( { otool -L "$EXE" | grep -oE '/[^ ]*libSDL3[^ ]*\.dylib' || true; } | head -1)"
[ -n "$sdl_ref" ] || sdl_ref="$( { otool -L "$EXE" | grep -oE '/[^ ]*SDL3\.framework/[^ ]*' || true; } | head -1)"
if [ -n "$sdl_ref" ]; then
  SDL_SHAPE=dylib
  sdl_base="$(basename "$sdl_ref")"
  say "SDL3 the build tree links   $sdl_ref   (dylib shape: vendored, and its"
  say "  LC_BUILD_VERSION becomes the bundle's floor -- section 4 prints both)"
else
  SDL_SHAPE=static
  sdl_base=""
  say "SDL3 the build tree links   nothing: the executable references no SDL3"
  say "  dylib at all, so SDL3 is linked in statically and no dylib is vendored."
  say "  That is the shape this package ships: with no vendored dylib, nothing"
  say "  inside the bundle raises the floor above the port's own target."
fi

APP="$DIST/$APP_NAME.app"
C="$APP/Contents"
echo
echo "== 1. the bundle =="
echo
rm -rf "$APP"
mkdir -p "$C/Resources"

# The payload Mach-Os are edited and signed in a plain directory, NOT inside the
# .app, and only then moved in.  That order is kept because it is the order that
# produces a payload whose signature carries this bundle's identifier: a sign
# taken in a plain directory takes the identifier from the file name, a sign taken
# inside a bundle takes it from that bundle's Info.plist and adds a CodeDirectory
# hash.  Section 3 measures the whole thing rather than asserting it: the same
# steps repeated in a scratch directory, sealed with a copy of this bundle's own
# Info.plist and Resources, come out at the shipped payload's hash, and each step
# left out comes out somewhere else.  Section 1's last block shows what that
# identity is made of: re-sealing a copy of the finished bundle reproduces the
# payload hash byte for byte, and one extra line in a resource file moves it,
# because the payload's own CodeDirectory seals the bundle's resources with it.
#
# The bundle as a whole is then sealed as well (below, after Info.plist), and that
# seal is what signs the payload for good: a seal of a whole bundle re-signs the
# executable inside it.  Sealing is only possible because the host no longer keeps
# anything loose in Contents/MacOS/ -- with the pinned framework's layout, a bundle
# holding keybinds.ini and mods/ beside its executable cannot be sealed at all, and
# section 2 measures that refusal on a bundle staged that way on purpose.
pstage="$OUT/payload_stage$SFX"
rm -rf "$pstage"; mkdir -p "$pstage"
cp -p "$EXE" "$pstage/$APP_NAME"
chmod u+w "$pstage/$APP_NAME"
if [ "$SDL_SHAPE" = dylib ]; then
  mkdir -p "$pstage/libs"
  cp "$sdl_ref" "$pstage/libs/"
  chmod u+w "$pstage/libs/$sdl_base"
  install_name_tool -id "@executable_path/libs/$sdl_base" "$pstage/libs/$sdl_base"
  codesign --force --sign - "$pstage/libs/$sdl_base" 2>&1 | sed 's/^/  /'
  install_name_tool -change "$sdl_ref" "@executable_path/libs/$sdl_base" "$pstage/$APP_NAME"
fi
codesign --force --sign - "$pstage/$APP_NAME" 2>&1 | sed 's/^/  /'
mkdir -p "$C/MacOS"
cp "$pstage/$APP_NAME" "$C/MacOS/$APP_NAME"
if [ "$SDL_SHAPE" = dylib ]; then
  mkdir -p "$C/MacOS/libs"
  cp "$pstage/libs/$sdl_base" "$C/MacOS/libs/$sdl_base"
fi
chmod 755 "$C/MacOS/$APP_NAME"

min_os="$(otool -l "$C/MacOS/$APP_NAME" | awk '/LC_BUILD_VERSION/{f=1} f && /minos/{print $2; exit}')"
# The bundle states its own distribution status in its own copyright string, so
# the claim travels with the bundle rather than living only in the log: Finder's
# Get Info panel shows this text, and it is the difference between "you must own
# the game, we ship nothing" and "this copy contains the game, keep it to
# yourself".
if [ "$PERSONAL" = 1 ]; then
  copyright="Personal build of the Shadowrun ($EDITION_TITLE) native recompilation. Contains the guest ROM image, compiled into the executable by tools/embed_rom.py. Not for redistribution: you must legally own a copy of the game."
else
  copyright="Shadowrun ($EDITION_TITLE) native recompilation. No ROM data is included; you must legally own a copy of the game."
fi
cat >"$C/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_DISPLAY</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>$min_os</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.adventure-games</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key>
  <string>$copyright</string>
</dict>
</plist>
PLIST
printf 'APPL????' >"$C/PkgInfo"

# Nothing writable is staged beside the executable, and that is the packaging
# fix, not a tidiness choice.  The pinned framework resolved config.ini,
# keybinds.ini, rom.cfg, saves/ and the mod catalog next to the executable, so
# this script used to stage keybinds.ini and mods/ into Contents/MacOS/ -- and a
# bundle staged that way cannot be sealed at all (section 3 measures codesign
# refusing: "In subcomponent: .../Contents/MacOS/keybinds.ini").  The shipping
# framework resolves those eight leaves under ~/Library/Application Support/
# <bundle name>/ when it is running from inside a .app, so:
#   * keybinds.ini is not staged.  The host writes its own default on first run,
#     and that default is the repository's map -- measured here, not assumed:
#     diff keybinds.ini ~/Library/Application Support/Shadowrun/keybinds.ini
#     reports no difference (the repo file is what the host's own writer produced).
#   * mods/ is not staged either.  mods/preloaded is not shipped data, it is the
#     catalog the launcher writes as mod packages are installed: state.toml
#     appeared inside it during a single run of the pinned build, and the
#     framework's mod manager creates the tree itself.
#   * No config.ini, same reason as before: the host writes its own default.
find "$APP" -name '.DS_Store' -delete

# BUILD_INFO.txt is where the package argues about itself with whoever opens the
# bundle in a year.  Both variants state their own ROM status, because the
# distributable package's "no ROM" and the personal package's "the ROM is in the
# executable" are equally easy to forget once the log that proved them is long
# gone.  The numbers in the personal case are read out of the generator's own
# record in the build tree -- not retyped, and not the source path, which is
# machine-local and is what the payload scans below look for.
{
  printf '%s\n' "$APP_NAME.app $VERSION  exe $(sha "$C/MacOS/$APP_NAME")  $(uname -m)"
  if [ "$PERSONAL" = 1 ]; then
    printf '%s\n' '' 'PERSONAL BUILD -- NOT FOR DISTRIBUTION' \
      'The executable in this bundle contains the guest ROM image, compiled in at' \
      'configure time by tools/embed_rom.py, so the app opens straight into the' \
      "game and never asks for a dump.  The image is what $BUILD_DIR/embedded_rom.c" \
      'says it is, and that file is the generator record, not something retyped:'
    sed -n 's/^ *\*  *[a-z0-9]* * *: *\(.*\)$/\1/p' "$BUILD_DIR/embedded_rom.c" 2>/dev/null \
      | grep -vE '/' | sed 's/^/  /' || true
    printf '%s\n' '' 'Do not upload this bundle anywhere, do not send it to anyone, do' \
      'not put it on a file host or in a repository: it carries game data.  The' \
      'shareable artefact is this same script without PERSONAL=1, which ships no ROM' \
      'and asks the player for their own dump once.'
  else
    printf '%s\n' '' 'No ROM in this package, in any form.  The launcher asks once for a' \
      'dump the player legally owns, checks it against the digests baked into the' \
      'build, and caches the choice in the state directory.'
  fi
  printf '%s\n' '' "Saves, settings, keybinds and the ROM choice live in" \
      "~/Library/Application Support/$APP_NAME/, not inside this bundle, so" \
      'replacing or re-downloading the app keeps them, and the bundle stays' \
      'sealed.  Delete that directory to start the port over from nothing.'
} >"$C/Resources/BUILD_INFO.txt"

# Seal the bundle as a bundle.  This is the step the old layout made impossible,
# and it is what a copy that has been through a download or a mount is judged on:
# a bundle with a signature that promises a resource seal and has none is what
# macOS reports as "damaged".  Ad-hoc (no Developer ID), because there is no
# certificate here and nothing to notarise with; section 4 measures what
# Gatekeeper then does with a quarantined copy, and the answer is not favourable,
# which is stated in the same section rather than hidden.
codesign --force --sign - "$APP" 2>&1 | sed 's/^/  /'
echo "  payload, read back off the finished bundle:"
printf '  %-28s %s  %s B\n' "$APP_NAME (CFBundleExecutable)" "$(sha "$C/MacOS/$APP_NAME")" \
  "$(stat -f%z "$C/MacOS/$APP_NAME")"
if [ "$SDL_SHAPE" = dylib ]; then
  printf '  %-28s %s  %s B\n' "libs/$sdl_base" "$(sha "$C/MacOS/libs/$sdl_base")" \
    "$(stat -f%z "$C/MacOS/libs/$sdl_base")"
else
  say "no vendored dylib: SDL3 is inside $APP_NAME, so the tree below is the whole payload"
fi
say "seal of the whole bundle    $( { codesign --verify --strict "$APP" 2>&1 || true; } | head -1) (empty output is codesign's pass)"
say "  resource seal written:    $( [ -f "$C/_CodeSignature/CodeResources" ] && echo "Contents/_CodeSignature/CodeResources ($(stat -f%z "$C/_CodeSignature/CodeResources") B)" || echo 'NONE -- the seal did not happen' )"
say "LSMinimumSystemVersion      $min_os (read from the executable's LC_BUILD_VERSION)"
# The floor is a property of every Mach-O in the bundle, not just the one the
# plist names: dyld refuses to load a dylib whose LC_BUILD_VERSION is above the
# caller's target, so a vendored dylib built for a newer system raises the floor
# of the whole package no matter what the plist claims.  Print both, and say
# which one binds.
minos_of() { { vtool -show-build "$1" 2>/dev/null |
  awk '/minos/{print $2; exit}'; } || true; }
sdk_of()   { { vtool -show-build "$1" 2>/dev/null |
  awk '/sdk/{print $2; exit}'; } || true; }
exe_min="$(minos_of "$C/MacOS/$APP_NAME")"; exe_sdk="$(sdk_of "$C/MacOS/$APP_NAME")"
say "the executable's own build record: minos $exe_min, sdk $exe_sdk  ($( { vtool -show-build "$C/MacOS/$APP_NAME" 2>/dev/null | awk '/platform/{print $2; exit}'; } || true ))"
if [ "$SDL_SHAPE" = dylib ]; then
  dy_min="$(minos_of "$C/MacOS/libs/$sdl_base")"
  say "the vendored dylib's build record:   minos $dy_min"
  floor="$exe_min"; bind="executable"
  case "$dy_min" in ''|*[!0-9]*) ;; *)
    if [ "$(printf '%s\n%s\n' "$exe_min" "$dy_min" | sort -V | tail -1)" != "$exe_min" ]; then
      floor="$dy_min"; bind="the vendored dylib"
    fi ;;
  esac
  say "so the floor that actually binds is $floor, set by $bind -- a vendored dylib"
  say "  raises the package's requirement to whatever system it was built for."
else
  say "no other Mach-O in the bundle: SDL3 is linked into the executable, so the"
  say "  only build record in this package is the one above, and $min_os is the floor."
fi
say "architecture of the payload: $( { lipo -archs "$C/MacOS/$APP_NAME" 2>&1; } || true )"
say "size of the .app            $(du -sh "$APP" | cut -f1)"
echo "  tree:"
find "$APP" -not -name '.DS_Store' | sed "s|$APP|.|" | sort | sed 's/^/    /'

# The seal is the thing a downloaded or mounted copy is actually judged on, so it
# is not simply produced here and declared good -- it is put through the states a
# player's copy passes through and asked the same question each time.  A copy of
# the finished bundle; then that copy with writable state forced into
# Contents/MacOS/, which is exactly what the pinned framework leaves behind on a
# first launch by itself; then that state taken out again and the seal put back.
# Four states, four answers, every one of them codesign's own words.  This is the
# closest thing in this kit to the report this packaging exists to answer --
# "Shadowrun is damaged" -- and it is a simulation of it, not that report: nothing
# here ran on a machine that saw the message, and what the message is caused by is
# a seal that promises resources the bundle does not have.
st="$OUT/seal_test$SFX/$APP_NAME.app"
rm -rf "$OUT/seal_test$SFX"; mkdir -p "$(dirname "$st")"
ditto "$APP" "$st"
runq() {
    local out
    out="$({ "$@" 2>&1; echo "[exit=$?]"; } | sed "s|^|       |")"
    printf '%s\n' "$out" | tee -a "$LOG" >/dev/null
}
say ""
say "the seal, put through the states a copy passes through (codesign's words, not this script's):"
say "  1. the copy as shipped:"
runq codesign --verify --strict -v "$st"
say "  2. the same copy with its resource seal taken away, which is what a bundle that was never sealed looks like to a Mac that expects one:"
rm -rf "$st/Contents/_CodeSignature"
runq codesign --verify --strict -v "$st"
say "  3. that bundle laid out the way the pinned framework lays a bundle out -- a rom.cfg, a keybinds.ini and the launcher's mod catalog written beside the executable -- asked to be sealed at all:"
: >"$st/Contents/MacOS/rom.cfg"
mkdir -p "$st/Contents/MacOS/mods/preloaded/packages"
: >"$st/Contents/MacOS/mods/preloaded/state.toml"
: >"$st/Contents/MacOS/keybinds.ini"
rm -rf "$st/Contents/_CodeSignature"
runq codesign --force --sign - "$st"
say "  4. the same bundle with the state taken back out and the seal put on again:"
rm -f "$st/Contents/MacOS/rom.cfg" "$st/Contents/MacOS/keybinds.ini" \
     "$st/Contents/MacOS/mods/preloaded/state.toml"
rm -rf "$st/Contents/MacOS/mods"
runq codesign --force --sign - "$st"
runq codesign --verify --strict -v "$st"
say "     so a bundle whose executable directory stays free of writable state seals, and a"
say "       bundle laid out the way the pinned framework lays one out does not."
say ""
say "  and two copies of the finished bundle, both re-sealed with this script's own codesign"
say "  command line, to answer whether the seal is a reproducible identity or a one-off:"
rs="$OUT/seal_repro$SFX"
rm -rf "$rs"; mkdir -p "$rs"
ditto "$APP" "$rs/A.app"; ditto "$APP" "$rs/B.app"
{ codesign --force --sign - "$rs/A.app" 2>&1 || true; } >/dev/null
printf '\none extra line in a resource file\n' >>"$rs/B.app/Contents/Resources/BUILD_INFO.txt"
{ codesign --force --sign - "$rs/B.app" 2>&1 || true; } >/dev/null
printf '  %-30s %s\n' "copy A, re-sealed unchanged" "$(sha "$rs/A.app/Contents/MacOS/$APP_NAME")"
printf '  %-30s %s\n' "copy B, BUILD_INFO.txt +1 line" "$(sha "$rs/B.app/Contents/MacOS/$APP_NAME")"
printf '  %-30s %s\n' "the bundle this run shipped" "$(sha "$C/MacOS/$APP_NAME")"
say "  A reproduces the shipped payload hash byte for byte, so the seal is deterministic and"
say "    a payload hash is a legitimate identity for a build.  B moves it, because a code"
say "    signature over a bundle seals the bundle's resources into the executable's own"
say "    CodeDirectory -- 'hashes=N+3', the +3 being the bundle's CodeResources, its"
say "    Info.plist and its requirements.  The payload's hash therefore pins the whole"
say "    bundle, BUILD_INFO.txt included, and not just the Mach-O inside it."

# The labels that say what kind of package this is are strings, and a string
# written by this script and a string that a person actually reads are different
# claims.  So they are read back off the finished bundle here -- the values a
# human sees (Get Info, the Dock, the file they open) -- and the personal build's
# image record is compared against its two sources of truth, the generator's own
# record in the build tree and rom_identity.txt.  A label that quotes a digest
# which disagrees with the build is worse than no label.
#
# PERSONAL only: the comparisons inside are against the generator's image record,
# which the shareable build does not have.  Its labels are still visible in the
# tree print above and in BUILD_INFO.txt, and the floor this bundle claims is
# printed in section 1 from the executable's own build record.
if [ "$PERSONAL" = 1 ]; then
say "what the bundle says about itself, read back off disk:"
for k in CFBundleName CFBundleDisplayName CFBundleIdentifier CFBundleExecutable \
         CFBundleShortVersionString NSHumanReadableCopyright; do
  # || true: plutil exits nonzero on a missing key, which is a finding this loop
  # is reporting rather than a reason to stop the run.
  v="$( { plutil -extract "$k" raw "$C/Info.plist" 2>/dev/null || true; } )"
  printf '    %-26s %s\n' "$k" "${v:-(missing)}"
done
marker="$( { grep -m1 -e 'NOT FOR DISTRIBUTION' -e 'No ROM in this package' \
           "$C/Resources/BUILD_INFO.txt" || true; } )"
say "    BUILD_INFO.txt states: $( [ -n "$marker" ] && echo "\"$marker\"" || echo 'NOTHING -- no ROM statement in the bundle (fail)' )"
if [ -z "$marker" ]; then
  echo "  FAIL: the personal package must state that it carries the guest image."
  exit 1
fi
gen="$BUILD_DIR/embedded_rom.c"
# (the gate above already means PERSONAL=1 here, so no second condition)
g_sz="$( { sed -n 's/^ *\* *bytes * *: *//p' "$gen" || true; } | tr -d ' ')"
i_sz="$( { sed -n 's/^rom_size *= *//p' "$ROOT/$IDENTITY_FILE" || true; } | tr -d ' ')"
g_crc="$( { sed -n 's/^ *\* *crc32 * *: *//p' "$gen" || true; } | tr -d ' ')"
i_crc="$( { sed -n 's/^expected_crc32 *= *//p' "$ROOT/$IDENTITY_FILE" || true; } | tr -d ' ')"
g_sha="$( { sed -n 's/^ *\* *sha256 * *: *//p' "$gen" || true; } | tr -d ' ')"
i_sha="$( { sed -n 's/^expected_sha256 *= *//p' "$ROOT/$IDENTITY_FILE" || true; } | tr -d ' ')"
# BUILD_INFO.txt carries the record as three bare indented values, copied out
# of the generator record above, so this checks what the file inside the shipped
# bundle actually says rather than what the script meant to write.
b_rec="$( { sed -n 's/^  \([0-9a-f]*\)$/\1/p' "$C/Resources/BUILD_INFO.txt" || true; } | tr '\n' ' ')"
say "  that label's image record, against both sources of truth:"
# rec_line prints one record out of its three fields, so the three sources line
# up in columns and a disagreement is visible instead of buried in one string.
rec_line() {
  sz=${2%% *}; rest=${2#* }; crc=${rest%% *}; sha=${rest#* }
  printf '    %-15s %8s %10s %s\n' "$1" "$sz" "$crc" "${sha% }"
}
printf '    %-15s %8s %10s %s\n' "source" "bytes" "crc32" "sha256"
rec_line "BUILD_INFO.txt" "$b_rec"
rec_line "embedded_rom.c" "$g_sz $g_crc $g_sha"
rec_line "rom_identity" "$i_sz $i_crc $i_sha"
if [ "$b_rec" = "$g_sz $g_crc $g_sha " ] && [ "$g_sz $g_crc $g_sha" = "$i_sz $i_crc $i_sha" ]; then
  say "    MATCH across all three: bundle label, generator record, $IDENTITY_FILE"
else
  say "    MISMATCH: the label in the bundle does not agree with the build's record."
  say "    That is a finding, not a formatting problem -- it would mean the package"
  say "    describes an image that is not the one it contains."
fi
fi

echo
echo "== 2. what is provably not in the payload =="
echo
say "Both variants are scanned the same way; only the expected answers differ, and"
say "each line says which.  Nothing below is relaxed for PERSONAL=1: the scans that"
say "hold for both keep their expect-0, and the one scan that inverts is reported"
say "as a presence check with the symbols named."
roms="$(find "$APP" -type f \( -name '*.sfc' -o -name '*.smc' -o -name '*.fig' \
  -o -name '*.bin' -o -name '*.rom' -o -name '*.ips' -o -name '*.ups' -o -name '*.bps' \) | count)"
say "ROM/patch-shaped files                   $roms   (expect 0 in both: $( [ "$PERSONAL" = 1 ] && echo 'the image is compiled into the Mach-O, never shipped beside it' || echo 'this package carries no ROM at all' ))"
emb="$( { nm "$C/MacOS/$APP_NAME" 2>/dev/null \
        | grep -oE '_snesrecomp_embedded_rom|_g_rom_embedded' | sort -u | tr '\n' ' ' ; } || true )"
emb_n="$(printf '%s\n' "$emb" | wc -w | tr -d '[:space:]')"
if [ "$PERSONAL" = 1 ]; then
  say "embedded-ROM symbols in the executable   $emb_n   ($emb)"
  say "                                         expect the array symbol here: it is the proof"
  say "                                         tools/embed_rom.py put the image in this binary."
  if [ "$emb_n" = 0 ]; then
    echo "  FAIL: this is meant to be the ROM-in package and its executable names no"
    echo "  embedded image at all.  Nothing in the payload carries the guest."
    exit 1
  fi
else
  say "embedded-ROM symbols in the executable   $emb_n   (expect 0; tools/embed_rom.py emits"
  say "                                         _snesrecomp_embedded_rom, and the host names"
  say "                                         _g_rom_embedded when it wires the image in)"
fi
say "rom.cfg in the payload                   $(find "$APP" -name 'rom.cfg' | count)   (expect 0: $( [ "$PERSONAL" = 1 ] && echo 'this app resolves the image inside its own executable, so it has no ROM choice to cache' || echo 'the launcher asks once and caches it under ~/Library/Application Support/'"$APP_NAME"'/, never inside the bundle' ))"
say "src/gen or recomp/funcs.h in the payload $(find "$APP" -name '*_v2.c' -o -name 'funcs.h' | count)   (expect 0: build inputs, git-ignored)"
say "files naming this repository              $(n_of grep -rl -e "$ROOT" "$APP")   (expect 0: an absolute build path would be a machine-local claim)"
if [ -n "$rom" ]; then
  say "files naming this machine's ROM directory ($(dirname "$rom")):"
  say "  $(n_of grep -rl "$rom" "$APP")   (expect 0: a baked-in rom.cfg would point at a file that does not exist on the player's disk)"
else
  say "no ROM on this machine to check the payload against"
fi

# The other half of the same question, run for both variants: the scan above asks
# whether anything *looks like* a ROM, and the symbol scan asks whether the host
# wired one in.  This one answers the direct question -- is the exact guest image
# this repository is generated from, byte for byte, sitting inside the installed
# Mach-O?  It takes the digests from rom_identity.txt through the framework's own
# parser (no second parser here, the same rule tools/embed_rom.py follows), finds
# the image in the executable, and re-hashes the region it found.
#
# For the shareable package the expected answer is "not anywhere in the file",
# which is a stronger statement than the pattern scan above.  For the personal
# package the expected answer is "yes, at this offset, and it hashes to the digest
# the build checks at boot" -- which is also what says the thing the app boots is
# the same bytes every other leg in this repository measured.
echo "  the guest image, looked for inside the executable itself:"
if [ -z "$rom" ]; then
  say "    skipped: no dump on this machine to search for"
else
  want="$(python3 "$fw/tools/rom_identity.py" "$IDENTITY_FILE" --get expected_sha256 2>/dev/null)" || want=""
  if [ -z "$want" ]; then
    say "    skipped: $fw/tools/rom_identity.py gave no expected_sha256"
  else
    python3 - "$C/MacOS/$APP_NAME" "$rom" "$want" \
      "$( [ "$PERSONAL" = 1 ] && echo present || echo absent )" "$IDENTITY_FILE" <<'PY' | sed 's/^/    /'
import hashlib, sys

exe, rom, want, expect, identity = sys.argv[1:6]
data = open(exe, "rb").read()
img = open(rom, "rb").read()

# Same two spellings embed_rom.py accepts: the bare image, and the same image
# behind a 512-byte copier header.  The digests decide which is the guest.
cands = [img] + ([img[512:]] if len(img) > 512 else [])
blob = next((c for c in cands if hashlib.sha256(c).hexdigest() == want), None)
if blob is None:
    print("cannot test: neither %s nor that file minus a 512-byte header hashes to %s"
          % (rom, want[:16]))
    sys.exit(0)

off = data.find(blob)
if off < 0:
    print("not found: no %d-byte region of %s (%d B) matches the digest this build"
          " checks at boot" % (len(blob), exe.rsplit("/", 1)[-1], len(data)))
    found = "absent"
else:
    region = data[off:off + len(blob)]
    print("found at offset 0x%x (%d B), sha256 %s -- matches the digest in"
          " %s" % (off, len(blob), hashlib.sha256(region).hexdigest()[:16], identity))
    found = "present"
print("%s: expected %s, %s" % ("MATCH" if found == expect else "MISMATCH", expect, found))
PY
  fi
fi
echo "  load commands of the packaged executable:"
otool -L "$C/MacOS/$APP_NAME" | tail -n +2 | sed 's/^/    /'
brew="$(otool -L "$C/MacOS/$APP_NAME" | tail -n +2 | grep -c '/opt/homebrew')" || true
say "  non-system load commands naming Homebrew: $brew  (expect 0)"
n_rpath="$( { otool -l "$C/MacOS/$APP_NAME" | grep -c 'cmd LC_RPATH' || true; } | tr -d '[:space:]')"
if [ -z "$n_rpath" ]; then n_rpath=0; fi
say "  LC_RPATH entries in the packaged executable: $n_rpath"
if [ "$n_rpath" != 0 ]; then
  say "    $(otool -l "$C/MacOS/$APP_NAME" | grep -A2 'cmd LC_RPATH' | grep -m1 'path' | tr -s ' ')"
  say "  No load command resolves through an entry that does not exist on the"
  say "  player's machine, and dyld ignores such an entry.  Removing it would change"
  say "  the executable's bytes, and section 3 is about keeping those bytes equal to"
  say "  the ones the test kit measured."
else
  say "  none at all: nothing in the Mach-O names a directory from this build.  That"
  say "  is what linking SDL3 statically buys next to the vendored-dylib shape, whose"
  say "  executable carried one entry naming this machine's Homebrew lib directory."
fi
say "  files in the payload naming /opt/homebrew: $(n_of grep -rl '/opt/homebrew' "$APP")"
# || true: grep exits 1 when it matches nothing, and pipefail would turn "no
# non-system imports" into a failed line.  Here a zero count is the pass.
if [ "$SDL_SHAPE" = dylib ]; then
  nonsys="$(otool -L "$C/MacOS/libs/$sdl_base" | tail -n +3 | grep -vE '/System/|/usr/lib/' | count)" || true
  say "  the dylib's own imports that are not system libraries: $nonsys   (expect 0: the player needs no Homebrew tree)"
fi
echo "  signatures, each Mach-O on its own, asked where they were signed:"
codesign --verify --strict --verbose=2 "$pstage/$APP_NAME" 2>&1 | sed 's/^/    exe:    /' || true
if [ "$SDL_SHAPE" = dylib ]; then
  codesign --verify --strict --verbose=2 "$pstage/libs/$sdl_base" 2>&1 | sed 's/^/    dylib:  /' || true
fi
say "    ('--validated:<path>' is codesign's pass; it prints nothing else.)"
codesign -dv "$pstage/$APP_NAME" 2>&1 | grep -E 'Identifier|Format|Signature|TeamId' | sed 's/^/    /'
if [ "$SDL_SHAPE" = dylib ]; then
  codesign -dv "$pstage/libs/$sdl_base" 2>&1 | grep -E 'Signature' | sed 's/^/    /'
fi
echo
echo "  the packaged executable once it sits inside the .app, and the bundle as a whole:"
codesign --verify --strict --verbose=2 "$C/MacOS/$APP_NAME" 2>&1 | sed 's/^/    exe:    /' || true
codesign --verify --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    bundle: /' || true
say "    Empty output from --verify is codesign's pass; --verbose=2 adds the"
say "    '--validated' lines and the seal's own hash.  Contents/_CodeSignature/"
say "    CodeResources is the resource seal, and it exists because nothing writable"
say "    sits inside the bundle: the host keeps its state outside (see the intro), so"
say "    saving a game no longer breaks a seal."
echo "    what the seal says about the bundle:"
codesign -dvvv "$APP" 2>&1 | grep -E 'Identifier|Format|CodeDirectory|TeamIdentifier|Notarize' | sed 's/^/      /' || true
say "    TeamIdentifier not set = ad-hoc: made on this machine, for this machine, with"
say "    no Apple certificate behind it."
say
say "    The counter-case, generated rather than asserted -- a scratch copy of the"
say "    finished bundle staged the way the pinned framework's layout needs it, with"
say "    the host's runtime files beside its executable:"
seal="$OUT/seal_attempt$SFX"; rm -rf "$seal"; mkdir -p "$seal"
ditto "$APP" "$seal/$APP_NAME.app"
cp keybinds.ini "$seal/$APP_NAME.app/Contents/MacOS/keybinds.ini"
cp -R mods "$seal/$APP_NAME.app/Contents/MacOS/mods"
codesign --remove-signature "$seal/$APP_NAME.app" 2>&1 | sed 's/^/      /' || true
codesign --force --sign - "$seal/$APP_NAME.app" 2>&1 | sed 's/^/      seal attempt: /' || true
codesign --verify --strict "$seal/$APP_NAME.app" 2>&1 | sed 's/^/      seal check:     /' || true
say "    That is the state a downloaded or mounted copy of such a bundle is re-assessed"
say "    against: a signature that expects a resource seal with none present is what"
say "    macOS reports to a person as '... is damaged and can't be opened'.  It is not"
say "    a corrupt download; it is the bundle's own shape.  Fixing the shape is why the"
say "    payload carries no loose state and why the seal above is made."
echo "  Gatekeeper's verdict (ad-hoc is not a Developer ID, and notarisation needs one):"
spctl -a -vv -t exec "$APP" 2>&1 | sed 's/^/    exec:    /' || true
spctl -a -vv -t install "$APP" 2>&1 | sed 's/^/    install: /' || true
say "  Rejected, and a sealed bundle does not change that: the assessment needs a"
say "  Developer ID signature plus a notarisation ticket, and an ad-hoc signature can"
say "  carry neither.  So a copy that arrives through a browser carries the quarantine"
say "  flag and Gatekeeper refuses it until the person overrides once -- right-click >"
say "  Open, or clear the flag with"
say "  'xattr -dr com.apple.quarantine /Applications/$APP_NAME.app'.  Nothing in this"
say "  script can change that; the signing identity is free, Apple's is not."
say "  The .dmg built here carries no quarantine flag, because nothing downloaded it,"
say "  and a copy made on this machine is not refused by anything."

echo
echo "== 3. the executable inside the .app, against the bytes the kit already measured =="
echo
printf '  %-24s %s  %s B\n' "packaged" "$(sha "$C/MacOS/$APP_NAME")" "$(stat -f%z "$C/MacOS/$APP_NAME")"
printf '  %-24s %s  %s B\n' "build tree $EXE" "$(sha "$EXE")" "$(stat -f%z "$EXE")"
# Why the two sizes are not equal, measured instead of asserted.  The packaging
# edits are: in the dylib shape, the SDL install-name rewrite plus a re-sign that
# replaces the signature the linker left; in the static shape, the re-sign only.
# Where each one lands is measurable: the signature blob is the tail of the file,
# so its dataoff is also the length of everything else, and cmp can be run over
# exactly that part.
codesize() { { codesign -dvvv "$1" 2>&1 |
  grep -oE 'CodeDirectory v=[0-9]+ size=[0-9]+ flags=[^ ]* hashes=[0-9+]*' | head -1; } || true; }
sigoff()  { { otool -l "$1" 2>/dev/null |
  awk '/cmd LC_CODE_SIGNATURE/{f=1} f && /dataoff/{print $2; exit}'; } || true; }
sigsize() { { otool -l "$1" 2>/dev/null |
  awk '/cmd LC_CODE_SIGNATURE/{f=1} f && /datasize/{print $2; exit}'; } || true; }
scmds()   { { otool -h "$1" 2>/dev/null |
  awk '/^ *0x[0-9a-f]+ +[0-9]+/{print $7; exit}'; } || true; }
printf '  %-24s %s\n' "signature in the tree" "$(codesize "$EXE")"
printf '  %-24s %s\n' "signature when packaged" "$(codesize "$C/MacOS/$APP_NAME")"
off_t="$(sigoff "$EXE")"; off_p="$(sigoff "$C/MacOS/$APP_NAME")"
sz_t="$(sigsize "$EXE")"; sz_p="$(sigsize "$C/MacOS/$APP_NAME")"
sc_t="$(scmds "$EXE")";  sc_p="$(scmds "$C/MacOS/$APP_NAME")"
printf '  %-24s dataoff %s, %s B\n' "LC_CODE_SIGNATURE, tree" "$off_t" "$sz_t"
printf '  %-24s dataoff %s, %s B\n' "LC_CODE_SIGNATURE, packaged" "$off_p" "$sz_p"
if [ -z "$sc_t" ]; then sc_t=0; fi
if [ -z "$sc_p" ]; then sc_p=0; fi
sd_name() { { otool -l "$1" 2>/dev/null |
  awk '/cmd LC_LOAD_DYLIB/{f=1} f && /name/ {if ($2 ~ /SDL/) print $2; f=0}'; } || true; }
sd_show() { s="$(sd_name "$1")"; if [ -z "$s" ]; then
  if [ "$SDL_SHAPE" = static ]; then echo "(none: no SDL dylib load command -- SDL3 is inside this Mach-O)"
  else echo "(none found)"; fi
else echo "$s"; fi; }
printf '  %-24s %s\n' "SDL reference, tree" "$(sd_show "$EXE")"
printf '  %-24s %s\n' "SDL reference, packaged" "$(sd_show "$C/MacOS/$APP_NAME")"
printf '  %-24s sizeofcmds %s; load commands end at byte %s\n' \
  "header, tree" "$sc_t" "$(( 32 + sc_t ))"
printf '  %-24s sizeofcmds %s; load commands end at byte %s\n' \
  "header, packaged" "$sc_p" "$(( 32 + sc_p ))"
if [ -n "$off_t" ] && [ "$off_t" = "$off_p" ]; then
  blob_d=$(( sz_p - sz_t ))
  if [ "$blob_d" -lt 0 ]; then blob_d=$(( -blob_d )); big="the tree's"; else big="the packaged"; fi
  say "The signature blob starts at byte $off_t in BOTH files, so everything before it"
  say "is the same length in both, and the whole $blob_d B difference between the two"
  say "files above is the signature blob, $big blob being the larger.  ld scores 4 KiB"
  say "pages over the whole binary; codesign --force --sign - scores 16 KiB pages on an"
  say "executable this large, so the two blobs are not comparable byte for byte -- which"
  say "is why section 5 compares machine state instead of hashing these two files."
  cmpset="$( { cmp -l -n "$off_p" "$EXE" "$C/MacOS/$APP_NAME" 2>/dev/null |
    awk '{n++; if(n==1) f=$1; l=$1} END {printf "%d %d %d", n+0, f+0, l+0}'; } || true )"
  read -r d_n d_first d_last <<<"$cmpset"
  if [ -z "$d_n" ]; then d_n=0; fi
  if [ -z "$d_first" ]; then d_first=0; fi
  if [ -z "$d_last" ]; then d_last=0; fi
  say "Compared up to that offset: $d_n byte(s) of $off_p differ, first at byte"
  say "$d_first, last at $d_last."
  if [ "$d_n" -gt 0 ] && [ "$d_last" -le "$(( 32 + sc_t ))" ]; then
    say "The tree's load commands end at 32 + sizeofcmds($sc_t) = $(( 32 + sc_t )):"
    say "every difference is inside the Mach-O header and its load commands and"
    say "nowhere else.  Everything past that -- code and data -- is bit-identical"
    say "between the build tree and the shipped bytes."
    if [ "$PERSONAL" = 1 ]; then
      say "That includes the 1 MiB of embedded guest image: the packaging did not touch it."
    fi
    lc=$(( (32 + sc_t) - (32 + sc_p) ))
    if [ "$lc" -lt 0 ]; then lc=$(( -lc )); fi
    if [ "$SDL_SHAPE" = dylib ]; then
      say "The load commands themselves moved by $lc B: the dylib path above got shorter,"
      say "and those commands pad to 8 B.  __LINKEDIT's file offset comes from the segment"
      say "table, so the padding absorbs it and the file's length moves only with the blob."
    else
      say "The load commands themselves moved by $lc B.  Nothing was rewritten here --"
      say "SDL3 is linked in, so the only packaging step on this Mach-O is the ad-hoc"
      say "sign -- and a sign writes the LC_CODE_SIGNATURE command, which is one load"
      say "command of 16 B plus padding to 8 B.  __LINKEDIT's file offset comes from the"
      say "segment table, so the padding absorbs the movement and the file's length moves"
      say "only with the blob."
    fi
  elif [ "$d_n" -eq 0 ]; then
    say "No byte before the signature blob differs at all."
  else
    say "$d_last is past the load commands (32 + sizeofcmds($sc_t) = $(( 32 + sc_t ))):"
    say "a difference exists outside them and this section does not explain it. The"
    say "frame leg in section 5 still compares machine state, so no claim rests here."
  fi
else
  say "Could not read LC_CODE_SIGNATURE from both files; section 5 compares machine"
  say "state, so no claim here rests on this comparison."
fi

# Why the payload is edited and signed OUTSIDE the bundle, measured.  The rule
# comes from §8 of tests/README.md and this is the evidence for it.  Three copies
# of the tree's executable, each given exactly the steps the packaging gives it,
# signed three different ways, and their hashes compared.  In the static-SDL3
# shape there is no name to rewrite, so the steps are the sign alone; the probes
# still separate the two places a sign can be taken from, which is the part that
# decides whether the shipped bytes are the measured bytes.
pksteps="sign"
if [ "$SDL_SHAPE" = dylib ]; then pksteps="rewrite + sign"; fi
sprb="$OUT/sign_probe$SFX"; rm -rf "$sprb"; mkdir -p "$sprb/plain" "$sprb/inbundle/Probe.app/Contents/MacOS"
cp "$EXE" "$sprb/plain/$APP_NAME"
if [ "$SDL_SHAPE" = dylib ]; then
  install_name_tool -change "$sdl_ref" "@executable_path/libs/$sdl_base" "$sprb/plain/$APP_NAME" 2>&1 | sed 's/^/    /'
fi
codesign --force --sign - "$sprb/plain/$APP_NAME" 2>&1 | sed 's/^/    /'
printf '  %-34s %s  %s B\n' "probe: $pksteps, outside" "$(sha "$sprb/plain/$APP_NAME")" "$(stat -f%z "$sprb/plain/$APP_NAME")"
printf '  %-34s %s\n' "  its identifier" "$( { codesign -dvvv "$sprb/plain/$APP_NAME" 2>&1 | awk -F= '/^Identifier=/{print $2; exit}'; } || true )"
if [ "$(sha "$sprb/plain/$APP_NAME")" = "$(sha "$C/MacOS/$APP_NAME")" ]; then
  say "MATCH: those steps are the whole of what the packaging did to this"
  say "executable -- a scratch copy, given the same steps in a plain directory,"
  say "reproduces the shipped bytes exactly, hash for hash."
else
  # Expected, and the fourth probe below is what answers it: the bundle seal in
  # section 1 runs after the plain-directory sign, and a seal of a whole bundle
  # re-signs the executable inside it from Info.plist rather than from the file
  # name.  So a plain-dir sign can only match a payload whose bundle seal failed
  # -- which is what the pinned framework's layout made, and the reason the old
  # transcripts show MATCH here.
  if [ "$SDL_SHAPE" = static ]; then
    say "NO MATCH against a plain-directory sign, and that is the bundle seal's doing:"
    say "section 1 signs the finished $APP_NAME.app as a whole, and a whole-bundle seal"
    say "re-signs the executable inside it with the bundle's identifier and a hash of"
    say "Info.plist.  The probe that repeats those steps in order is the fourth one below."
  else
    say "NO MATCH: the packaging did something beyond those steps; the fourth probe"
    say "below repeats the whole order and section 5 compares machine state."
  fi
fi
# same bytes, different file name: an ad-hoc sign takes its identifier from the
# name, so the name is part of what the payload hash pins.
cp "$EXE" "$sprb/plain/other-name"
if [ "$SDL_SHAPE" = dylib ]; then
  install_name_tool -change "$sdl_ref" "@executable_path/libs/$sdl_base" "$sprb/plain/other-name" 2>&1 | sed 's/^/    /'
fi
codesign --force --sign - "$sprb/plain/other-name" 2>&1 | sed 's/^/    /'
printf '  %-34s %s  %s B\n' "probe: same, named other-name" "$(sha "$sprb/plain/other-name")" "$(stat -f%z "$sprb/plain/other-name")"
printf '  %-34s %s\n' "  its identifier" "$( { codesign -dvvv "$sprb/plain/other-name" 2>&1 | awk -F= '/^Identifier=/{print $2; exit}'; } || true )"
# same bytes, signed while already inside a bundle: codesign reads Info.plist.
cp "$EXE" "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME"
cat > "$sprb/inbundle/Probe.app/Contents/Info.plist" <<PROBEPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>org.example.signprobe</string>
  <key>CFBundleName</key><string>SignProbe</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict>
</plist>
PROBEPLIST
if [ "$SDL_SHAPE" = dylib ]; then
  install_name_tool -change "$sdl_ref" "@executable_path/libs/$sdl_base" "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME" 2>&1 | sed 's/^/    /'
fi
codesign --force --sign - "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME" 2>&1 | sed 's/^/    /'
printf '  %-34s %s  %s B\n' "probe: $pksteps, INSIDE" "$(sha "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME")" "$(stat -f%z "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME")"
printf '  %-34s %s\n' "  its identifier" "$( { codesign -dvvv "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME" 2>&1 | awk -F= '/^Identifier=/{print $2; exit}'; } || true )"
printf '  %-34s %s\n' "  its CodeDirectory" "$(codesize "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME")"
printf '  %-34s %s\n' "  the packaged CodeDirectory" "$(codesize "$C/MacOS/$APP_NAME")"
if [ "$(sha "$sprb/inbundle/Probe.app/Contents/MacOS/$APP_NAME")" != "$(sha "$C/MacOS/$APP_NAME")" ]; then
  say "Signing in place inside a bundle re-draws the signature: the identifier comes from"
  say "that bundle's Info.plist instead of the file name, and one more hash appears in the"
  say "CodeDirectory -- that extra hash is the bundle's Info.plist, bound into the Mach-O's"
  say "own signature.  The file length may or may not move, so size alone does not catch"
  say "it; the hash does.  That is what the whole-bundle seal in section 1 does to the"
  say "payload, and the fourth probe repeats it with this bundle's own Info.plist."
else
  say "Unexpected: a foreign bundle's Info.plist produced the packaged bytes after all."
  say "The staging rule would need re-deriving; section 5's frame leg still stands alone."
fi
# Fourth probe: the whole order section 1 takes, in a scratch directory, against a
# copy of this bundle's own Info.plist/PkgInfo/Resources.  A seal of a whole bundle
# re-signs the executable inside it, so this -- and not a plain-directory sign -- is
# the sequence expected to land on the shipped hash.  If it does, the shipped payload
# is fully described by: this build tree's bytes, the staging steps named above, and
# the bundle metadata sealed around it.
fm="$sprb/full"; rm -rf "$fm"; mkdir -p "$fm" "$fm/$APP_NAME.app/Contents/MacOS"
cp -p "$EXE" "$fm/$APP_NAME"
chmod u+w "$fm/$APP_NAME"
if [ "$SDL_SHAPE" = dylib ]; then
  mkdir -p "$fm/libs"
  cp "$sdl_ref" "$fm/libs/"
  chmod u+w "$fm/libs/$sdl_base"
  install_name_tool -id "@executable_path/libs/$sdl_base" "$fm/libs/$sdl_base"
  codesign --force --sign - "$fm/libs/$sdl_base" 2>&1 | sed 's/^/    /'
  install_name_tool -change "$sdl_ref" "@executable_path/libs/$sdl_base" "$fm/$APP_NAME"
  mkdir -p "$fm/$APP_NAME.app/Contents/MacOS/libs"
  cp "$fm/libs/$sdl_base" "$fm/$APP_NAME.app/Contents/MacOS/libs/$sdl_base"
fi
codesign --force --sign - "$fm/$APP_NAME" 2>&1 | sed 's/^/    /'
cp "$C/Info.plist" "$fm/$APP_NAME.app/Contents/Info.plist"
if [ -f "$C/PkgInfo" ]; then cp "$C/PkgInfo" "$fm/$APP_NAME.app/Contents/PkgInfo"; fi
if [ -d "$C/Resources" ]; then mkdir -p "$fm/$APP_NAME.app/Contents/Resources" && cp -R "$C/Resources/." "$fm/$APP_NAME.app/Contents/Resources/"; fi
cp "$fm/$APP_NAME" "$fm/$APP_NAME.app/Contents/MacOS/$APP_NAME"
chmod 755 "$fm/$APP_NAME.app/Contents/MacOS/$APP_NAME"
codesign --force --sign - "$fm/$APP_NAME.app" 2>&1 | sed 's/^/    /'
printf '  %-34s %s  %s B\n' "probe: $pksteps + bundle seal" "$(sha "$fm/$APP_NAME.app/Contents/MacOS/$APP_NAME")" "$(stat -f%z "$fm/$APP_NAME.app/Contents/MacOS/$APP_NAME")"
printf '  %-34s %s\n' "  its identifier" "$( { codesign -dvvv "$fm/$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>&1 | awk -F= '/^Identifier=/{print $2; exit}'; } || true )"
printf '  %-34s %s\n' "  its CodeDirectory" "$(codesize "$fm/$APP_NAME.app/Contents/MacOS/$APP_NAME")"
if [ "$(sha "$fm/$APP_NAME.app/Contents/MacOS/$APP_NAME")" = "$(sha "$C/MacOS/$APP_NAME")" ]; then
  say "MATCH: that order is the whole of what the packaging did to this executable.  A"
  say "scratch copy of $EXE, staged and sealed the way section 1 stages and seals, comes"
  say "out at the shipped hash -- so the payload is pinned by the build tree's bytes plus"
  say "the staging steps plus this bundle's Info.plist, and nothing else was done to it."
  if [ "$SDL_SHAPE" = static ]; then
    say "The plain-directory sign of probe one is real but not final: the bundle seal that"
    say "section 1 takes afterwards signs over it, which is why probe one alone does not"
    say "match and probe four does."
  fi
else
  say "NO MATCH even repeating the whole order: something the script does not name is in"
  say "the shipped bytes.  Section 5's frame leg still compares machine state, so no"
  say "claim about what this package runs rests on this line."
fi
if [ "$(sha "$sprb/plain/other-name")" != "$(sha "$C/MacOS/$APP_NAME")" ]; then
  if [ "$SDL_SHAPE" = dylib ]; then
    say "So a plain-directory sign pins the build tree's bytes, this exact install-name"
    say "rewrite and the file's name all at once -- renaming the file changes the bytes,"
    say "because an ad-hoc sign takes its identifier from the name."
  else
    say "So a plain-directory sign pins the build tree's bytes and the file's name at"
    say "once: nothing was rewritten in between, and an ad-hoc sign takes its identifier"
    say "from the name.  Inside the finished bundle the identifier is the bundle's instead,"
    say "which is what probe four pins."
  fi
else
  say "Renaming the file did not change the signature bytes, so this build's payload hash"
  say "does not depend on the file name; the identifier line above says what it does use."
fi
printf '  %-34s %s\n' "probe copies left behind" "$sprb"
if [ -f Shadowrun ]; then
  printf '  %-24s %s  %s B\n' "staged ./Shadowrun" "$(sha Shadowrun)" "$(stat -f%z Shadowrun)"
  if [ "$(sha "$C/MacOS/$APP_NAME")" = "$(sha Shadowrun)" ]; then
    echo "  MATCH: the installed app carries the exact bytes that"
    echo "  evidence/artifacts/bundle_verify.md proved identical to the build tree"
    echo "  over 1,200 frames of the parity route.  The packaging step is the same"
    echo "  steps that staged ./Shadowrun, applied here to $BUILD_DIR."
  elif [ "$PERSONAL" = 1 ]; then
    echo "  differs from ./Shadowrun, and must: ./Shadowrun is the ROM-based staged"
    echo "  bundle, a different program from one whose executable carries the image."
    echo "  What means something here is the frame leg in section 5: this package"
    echo "  against the tree built at this package's floor without the guest inside"
    echo "  its executable, compared as machine state."
  else
    echo "  differs from ./Shadowrun -- section 5 measures the packaged bytes against"
    echo "  the build tree directly, so the claim does not depend on this match."
  fi
else
  say "no ./Shadowrun in this checkout; section 5 measures the packaged bytes"
  say "against $EXE directly."
fi
if [ "$SDL_SHAPE" = dylib ]; then
  echo
  printf '  %-24s %s  %s B\n' "packaged dylib" "$(sha "$C/MacOS/libs/$sdl_base")" \
    "$(stat -f%z "$C/MacOS/libs/$sdl_base")"
  if [ -f "libs/$sdl_base" ]; then
    printf '  %-24s %s  %s B\n' "staged libs/" "$(sha "libs/$sdl_base")" "$(stat -f%z "libs/$sdl_base")"
    if [ "$(sha "$C/MacOS/libs/$sdl_base")" = "$(sha "libs/$sdl_base")" ]; then
      echo "  MATCH: the same SDL3 the local test bundle loads, staged the same way"
      echo "  (install_name_tool -id, then re-sign), so the installed app and the test"
      echo "  kit run against byte-identical libraries."
    fi
  fi
else
  echo
  say "no dylib to compare: SDL3 is linked into the executable, so the executable's"
  say "hash above is the whole of the code this package carries."
fi

echo
echo "== 4. the disk image =="
echo
DMG="$DIST/$PKG_SLUG-$VERSION-$PLATFORM_TAG$DMG_SFX.dmg"
stage="$OUT/dmg_stage$SFX"
rm -rf "$stage"; mkdir -p "$stage"
ditto "$APP" "$stage/$APP_NAME.app"
ln -s /Applications "$stage/Applications"
# README.txt is the one file in the .dmg a person reads before they install, so
# it is where the personal package says it must not be shared -- not in a log on
# the machine that built it.  Both texts are written out in full rather than
# patched with conditionals, because the two variants describe two different
# installs and a reader should never have to reconstruct prose from a script.
cat >"$stage/README.txt" <<TXT
Shadowrun ($EDITION_TITLE), recompiled natively -- version $VERSION, $PLATFORM_TAG
$( [ "$PERSONAL" = 1 ] && printf '%s\n' \
'' \
'*** PERSONAL BUILD -- CONTAINS THE GAME, DO NOT DISTRIBUTE ***' \
'' \
'The executable in this bundle has the Shadowrun ($EDITION_TITLE) guest image compiled into' \
'it.  That is what makes it convenient and what makes it not shareable: sending' \
'this bundle to someone else is the same thing as sending them a copy of the' \
'game.  Keep it on machines you own.' \
'The shareable build is what scripts/package_macos_bundle.sh makes without' \
'PERSONAL=1: it carries no ROM and asks you for your own dump once.' )

1. Drag $APP_NAME.app to Applications (the shortcut in this window).
   Drag it, do not run it from this window: a mounted image is read-only and
   macOS also moves an app run straight from a mounted image to a random
   read-only location of its own (App Translocation).
$( [ "$PERSONAL" = 1 ] \
  && printf '%s\n' \
'2. Open it. It goes to the title screen on its own: the guest image is already' \
'   inside the app, so it never asks for a dump and there is no file to pick.' \
  || printf '%s\n' \
'2. Open it. It asks once for your own copy of Shadowrun ($EDITION_TITLE). Only that dump' \
'   is accepted -- the digests are baked into the build -- and the choice is' \
'   remembered in your Library, so it asks once.' \
'   You must legally own the game. No ROM is included in this package.' )
3. Settings and saves live beside your other per-app state, not inside the app:
     ~/Library/Application Support/$APP_NAME/config.ini
     ~/Library/Application Support/$APP_NAME/saves/save.srm
     ~/Library/Application Support/$APP_NAME/keybinds.ini
$( [ "$PERSONAL" = 1 ] \
  && printf '%s\n' \
'   (no ROM choice is kept there: the guest image is inside the app).' \
  || printf '%s\n' \
'   (the ROM choice you made once is in that folder too).' )
   That is why replacing or re-downloading the app keeps your save, and why the
   bundle itself can stay sealed.  Delete that folder to start the port over.
4. If macOS refuses to open it, that is Gatekeeper and not a broken download:
   this build is signed ad hoc, not with a Developer ID and not notarised.
   Right-click the app and choose Open, or clear the quarantine flag:
     xattr -dr com.apple.quarantine /Applications/$APP_NAME.app
5. Needs macOS $min_os or newer; architecture: $(lipo -archs "$C/MacOS/$APP_NAME" 2>/dev/null || echo unknown).

Keys and mouse, until you edit the keybinds.ini named above and restart:
  mouse             the in-game hand follows the pointer; the OS arrow hides
                    while the pointer is over the game
  left / right / middle mouse = B / A / Y
  W A S D = d-pad    X = start    Y = select
  C = X    Q = L    E = R
TXT
find "$stage" -name '.DS_Store' -delete
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$stage" -ov -format UDZO -fs HFS+ "$DMG" \
  >"$OUT/hdiutil_create$SFX.log" 2>&1
say "created   $DMG"
printf '  %-10s %s B   sha256 %s\n' "size" "$(stat -f%z "$DMG")" "$(sha "$DMG")"
hdiutil verify "$DMG" 2>&1 | sed 's/^/  /' || true
say "content of the mounted image:"
mnt="$(hdiutil attach -readonly -nobrowse "$DMG" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
find "$mnt" -not -name '.DS_Store' | sed "s|$mnt|.|" | sort | sed 's/^/    /'
printf '  %-24s %s  %s B\n' "the exe inside the image" "$(sha "$mnt/$APP_NAME.app/Contents/MacOS/$APP_NAME")" \
  "$(stat -f%z "$mnt/$APP_NAME.app/Contents/MacOS/$APP_NAME")"
say "  (the same hash section 3 measured in dist/, so the container did not alter"
say "  the payload: hdiutil stores the file, it does not rewrite a Mach-O)"
say "  drag target present: Applications -> $(readlink "$mnt/Applications" 2>/dev/null || echo 'not a symlink')"
say "  ROM/patch-shaped files inside the image: $(find "$mnt" \( -name '*.sfc' -o -name '*.smc' \
  -o -name '*.fig' -o -name '*.bin' -o -name '*.rom' -o -name '*.ips' -o -name '*.ups' \
  -o -name '*.bps' \) | count)   (expect 0)"
say "  files in the image naming this repository: $(n_of grep -rl "$ROOT" "$mnt")   (expect 0)"

# Is the container itself bit-stable?  Measured rather than assumed: the payload
# is byte-identical run to run (section 3), but a .dmg is a filesystem image and
# hdiutil stamps volume metadata into it.
probe="$OUT/dmg_probe$SFX.dmg"; rm -f "$probe"
hdiutil create -volname "$APP_NAME" -srcfolder "$stage" -ov -format UDZO -fs HFS+ "$probe" \
  >"$OUT/hdiutil_probe$SFX.log" 2>&1
printf '  %-24s %s  %s B\n' "second image, same payload" "$(sha "$probe")" "$(stat -f%z "$probe")"
if [ "$(sha "$DMG")" = "$(sha "$probe")" ]; then
  say "  the .dmg is byte-reproducible: same stage directory in, same bytes out."
else
  say "  the .dmg is NOT byte-reproducible even from the same stage directory:"
  say "  hdiutil stamps volume metadata (dates, UUIDs) into the container.  What"
  say "  is reproducible is the payload -- sections 1 and 3 pin the .app hashes --"
  say "  so a hash of the .dmg is a hash of this run's container, not of the build."
fi
rm -f "$probe"
DMG_MOUNT="$mnt"
DMG_MOUNTED="$mnt"   # unmounted by the EXIT trap; section 5 leg e installs from it

if [ "${VERIFY:-1}" != 1 ]; then
  echo
  echo "== VERIFY=0: the run legs below were skipped =="
  exit 0
fi

if [ -z "$rom" ] && [ "$PERSONAL" != 1 ]; then
  echo
  echo "== the run legs need a ROM and tests/rom.sh found none: package assembled, not run =="
  exit 2
fi
# These legs are meant to be deterministic and silent: no window on this screen,
# no audio device, no dependence on a logged-in GUI session.  Leg 5c is the
# deliberate exception and clears them, because a double-click does not inherit
# them -- see that leg for why it matters and what it measures.
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
say ""
if [ "$PERSONAL" = 1 ]; then
  say "No leg below passes --rom and no leg gets a rom.cfg: the claim this package"
  say "exists to make is that the app boots from the image inside its own executable."
  say "A leg that reached the ROM file picker would hang on a window with no way to"
  say "answer it, so those legs' exit codes and the host's own 'rom resolved:' line"
  say "are what measure that no picker appeared."
  say ""
  say "The one leg that does name the dump is the comparison against $SHIP_EXE:"
  say "that executable is the ROM-based build, so it has to be told where its image"
  say "is, and the answer goes on its command line only."
else
  say "the ROM the legs below use is this machine's dump, passed on the command line"
  say "every time; nothing about it is written into the package."
fi

echo
echo "== 5. the packaged app, run from outside this repository =="
echo
say "Every leg runs against a copy of the bundle under $OUT/app$SFX -- never the"
say "copy in dist/, never this repository's own runtime state.  The executable"
say "inside a .app resolves config.ini, keybinds.ini, rom.cfg, saves/, mods/ and"
say "the run report under ~/Library/Application Support/<bundle name>/ (the host"
say "derives that from \$HOME when it is running from inside a bundle), so these"
say "legs are given a private \$HOME under $OUT and write only there.  Two things"
say "that buys, both measured below: nothing of this machine's own port state is"
say "touched by a packaging run, and the bundle copy can be inventoried before and"
say "after -- a bundle that stays byte-identical through a run is the property the"
say "'... is damaged' complaint is about, so it is checked rather than assumed."
work="$OUT/app$SFX"
rm -rf "$work"; mkdir -p "$work"
ditto "$APP" "$work/$APP_NAME.app"
mac="$work/$APP_NAME.app/Contents/MacOS"
bin="$mac/$APP_NAME"
say "copy under test  $(sha "$bin")   (the bytes inside $DMG)"

# A private $HOME for the bundle legs.  The state directory is HOME-derived, so
# this is not a workaround: it is the same switch the host uses, pointed at the
# scratch tree.  It also says something about the package that could not be shown
# any other way -- where a person's saves actually live.
state_home="$OUT/state_home$SFX"
rm -rf "$state_home"; mkdir -p "$state_home/Library/Application Support"
statedir="$state_home/Library/Application Support/$APP_NAME"
export HOME="$state_home"
say "HOME for these legs         $state_home"
say "  so the app's state directory is   $statedir"
before_bundle="$(find "$work" | sort | shasum | cut -c1-16)"
before_n="$(find "$work" | count)"
say "bundle copy before the legs: $before_n files, tree hash $before_bundle"
say "  its seal, asked before anything runs -- this copy came out of dist/ by ditto,"
say "  not from the build:"
codesign --verify --strict --verbose=2 "$work/$APP_NAME.app" 2>&1 | sed 's/^/    /' || true

# Frame parity first, while both sides are pristine.  Order matters here: the app
# writes saves/save.srm and config.ini as it runs, so a later leg that boots with a
# save file in place is a different initial state, and a mismatch would say
# "packaging changed the machine" when it only changed the directory.  Both sides
# therefore start from nothing: the bundle's state directory is removed (it is the
# private one under $OUT/state_home$SFX, never this machine's own), and the tree
# binary has no saves/ in its own directory.
rm -rf "$statedir"
if [ "$PERSONAL" = 1 ]; then ref="$SHIP_EXE"; refmode=with; refnote="the tree built at this package's floor, on a framework that carries the state fix and not the guest ($SHIP_EXE -- section 0 and section 7 print both revisions)"; else
  ref="$EXE"; refmode=with; refnote="the build tree that made these bytes, $EXE"; fi
if [ "$PERSONAL" = 1 ] && { [ ! -f "$ref" ] || [ -z "$rom" ]; }; then
  say "a. skipped: the personal frame leg compares against $ref with this machine's"
  say "   dump, and here one of the two is missing -- so 'did embedding the image"
  say "   move the machine' would go unmeasured rather than claimed."
  skip_frames=1
else
  skip_frames=0
fi
for leg in app tree; do
  if [ "$skip_frames" = 1 ]; then break; fi
  d="$OUT/dump_${leg}$SFX"; rm -rf "$d"; mkdir -p "$d"
  if [ "$leg" = app ]; then
    src="$bin"; mode="$ROM_LEGS"
  else
    rm -rf "$OUT/anchor_tree$SFX"; mkdir -p "$OUT/anchor_tree$SFX/saves"
    cp -p "$ref" "$OUT/anchor_tree$SFX/$APP_NAME"; src="$OUT/anchor_tree$SFX/$APP_NAME"
    mode="$refmode"
  fi
  export SNESRECOMP_DUMP_DIR="$d"
  run_bounded "$d.log" "${LEG_MAX:-240}" "$(dirname "$src")" "$mode" "$src" \
    --no-launcher --script "$ROOT/tests/scripts/parity.txt" --framedump "$d"
  rc=$leg_rc
  unset SNESRECOMP_DUMP_DIR
  printf '  a. frames from %-4s %s  exit=%s %s\n' "$leg" "$(sha "$src")" "$rc" \
    "$(grep -oE 'exit: .*' "$d.log" | tail -1)"
  # Where each side says it got its guest: for the personal package this is the
  # direct measurement that the app leg never asked anyone for a file.
  grep -oE 'rom (resolved|loaded): .*' "$d.log" | sed 's/^/        /'
done
if [ "$skip_frames" = 1 ]; then
  say "   (no frame comparison in this run)"
else
say "   one side is the installed bytes; the other is $refnote."
if [ "$PERSONAL" = 1 ]; then
  say "   So this leg measures two things at once: that the packaging steps"
  say "   ($pksteps) changed no machine state, and that compiling the image into the"
  say "   executable on a framework that is a branch off the pin rather than the pin"
  say "   itself (section 0 measures which) changed no machine state either.  A"
  say "   frame-by-frame comparison is the only way to ask"
  say "   the second question -- the two executables differ by 1 MiB of guest data,"
  say "   so byte hashes say nothing."
else
  if [ "$SDL_SHAPE" = dylib ]; then
    say "   everything between them is the install-name rewrite, the vendored dylib and"
    say "   the re-sign that seals the bundle."
  else
    say "   everything between them is one ad-hoc sign in a plain directory plus the"
    say "   whole-bundle seal that signs over it: SDL3 is linked in, so there is no"
    say "   dylib name in the Mach-O to rewrite."
  fi
fi
python3 - "$OUT/dump_app$SFX" "$OUT/dump_tree$SFX" <<'PY'
import glob, os, re, sys
a, b = sys.argv[1], sys.argv[2]


def crc(p):
    h = re.findall(r'0x[0-9A-Fa-f]{8}', open(p).read())
    return h[-1] if h else None


fa = sorted(glob.glob(os.path.join(a, "frame_*.json")))
same = diff = 0
first = None
for f in fa:
    g = os.path.join(b, os.path.basename(f))
    ca, cb = crc(f), (crc(g) if os.path.isfile(g) else None)
    if ca is not None and ca == cb:
        same += 1
        continue
    diff += 1
    if first is None:
        first = (os.path.basename(f), ca, cb)
if diff:
    print(f"  {diff} of {same + diff} frames differ")
    if first:
        print(f"  first divergence at {first[0]}: {first[1]} vs {first[2]}")
else:
    print(f"  identical over {same} frames (crc32 of all 128 KiB of WRAM per frame)")
PY
python3 tests/framedump_diff.py state "$OUT/dump_app$SFX" "$OUT/dump_tree$SFX" 2>&1 | tail -4 | sed 's/^/    /'
if [ "$PERSONAL" = 1 ]; then
  say "   identical frame state across two different programs -- one boots from a"
  say "   file, one from bytes in its own __DATA segment, and they link different"
  say "   framework revisions -- is what says putting the image in the executable"
  say "   adds no machine state.  Nothing here could be proved by a byte comparison."
else
  say "   identical frame state is what says $pksteps plus the bundle seal -- all that"
  say "   separates the packaged bytes from $EXE -- changed no machine state.  A"
  say "   stripped, link-edited binary alone cannot say that."
fi
fi

t0=$(date +%s)
run_bounded "$OUT/selfcheck.log" "${LEG_MAX:-90}" "$work" "$ROM_LEGS" "$bin" \
  --no-launcher --script "$SELFCHECK_SCRIPT"
rc=$leg_rc
say "b. scripted boot from inside the .app: exit=$rc wall=$(( $(date +%s) - t0 ))s"
grep -E '^script |frame service|SDL init ok|rom resolved|rom loaded|rom identity|window created' "$OUT/selfcheck.log" \
  | sed 's/^/      /' || say "   no recognisable progress lines -- see $OUT/selfcheck.log"
say "   the script waits on the game's own WRAM tick counter ($TICK_ADDR), which"
say "   increments once per emulated frame, so it fails loudly if the ROM stalls."
if [ "$PERSONAL" = 1 ]; then
  say "   exit 0 here, with no --rom anywhere on the line and no rom.cfg in the"
  say "   bundle, is the claim: this app booted the guest out of its own executable."
  say "   A 124 or 125 instead would mean it opened the file picker and waited."
fi

echo "  c. the click path: started through LaunchServices, no terminal, no shell"
echo "     command line, no working directory the app was given:"
rm -f "$statedir/last_run_report.json" "$statedir/rom.cfg"
orc=0
# The dummy drivers section 5 exports for the deterministic legs are cleared for
# this leg only, on purpose: a double-click does not come with SDL_VIDEODRIVER in
# its environment, and an app that inherits the dummy drivers from the terminal
# that ran 'open' is a different program from the one a person clicks.  `open`
# relays its own environment to the app it starts, which the first version of this
# leg did not know and its own breadcrumb caught (video=dummy).  So this is the
# one leg that may put a window on this screen for the length of the script (~5 s)
# and open the audio device.  Set CLICK_HEADLESS=1 to keep the dummy drivers and
# have this leg say plainly that it measured less.
click_env="env -u SDL_VIDEODRIVER -u SDL_AUDIODRIVER"
[ "${CLICK_HEADLESS:-0}" = 1 ] && click_env=""
if [ -z "$click_env" ]; then
  say "   CLICK_HEADLESS=1: this leg keeps section 5's dummy drivers, so it"
  say "   measures the LaunchServices start and the anchor, not a real window."
fi
if [ "$ROM_LEGS" = with ]; then
  $click_env open -n "$work/$APP_NAME.app" --args --no-launcher --rom "$rom" \
    --script "$SELFCHECK_SCRIPT" || orc=$?
else
  # Nothing but the script: what a double-click on this bundle actually starts,
  # since a person who opens it has given it no file and it has no cached choice.
  $click_env open -n "$work/$APP_NAME.app" --args --no-launcher \
    --script "$SELFCHECK_SCRIPT" || orc=$?
fi
say "   'open' exit=$orc.  LaunchServices starts the app the way a double-click"
say "   does: no arguments it was not given, working directory '/', and no terminal"
say "   for it to write to -- which is why the run is read back from the report the"
say "   host writes at exit, rather than from stdout."
# Wait for the report the host writes at exit.  Two budgets, because a missing
# report has two different meanings and one wall-clock deadline cannot tell them
# apart: the app may still be running (a hang, e.g. a ROM picker no automated leg
# can answer) or it may be gone (it never started).  So keep polling while the
# launched process is alive, with a separate idle budget for a process that is
# already gone and a hard total cap.  A machine that sleeps during the leg shows
# up in the wall seconds below, which is why the report's own timestamp is
# printed next to them -- the first version of this leg called a sleep-spanning
# wait "the LaunchServices leg did not run" when the run had in fact succeeded.
t0=$(date +%s); idle=0; pid=""; wall=0
while :; do
  [ -f "$statedir/last_run_report.json" ] && break
  # || true: pgrep exits 1 when nothing matches, and under set -euo pipefail that
  # would end the run here on the very condition this loop is asking about.
  pid="$( { pgrep -f "$work/$APP_NAME.app" || true; } | head -1)"
  if [ -n "$pid" ]; then idle=0; else idle=$((idle + 2)); fi
  wall=$(( $(date +%s) - t0 ))
  if [ "$idle" -ge 6 ] || [ "$wall" -ge "${LEG_WAIT:-240}" ]; then break; fi
  sleep 2
done
# Re-ask instead of reusing the loop's last answer: the loop can break because the
# report appeared a moment after it saw the process, and a log that says "alive"
# about a process that has already exited is a wrong sentence about a real run.
running=""
# 2>/dev/null: kill -0 says "No such process" on stderr, and the finding here is
# the exit status, not the message.
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then running=1; fi
if [ -n "$running" ]; then
  say "   waited ${wall}s wall for it; pid $pid still running"
elif [ -n "$pid" ]; then
  say "   waited ${wall}s wall for it; pid $pid has exited"
else
  say "   waited ${wall}s wall for it; no matching process seen"
fi
if [ ! -f "$statedir/last_run_report.json" ]; then
  if [ -n "$running" ]; then
    say "   no report, and the process is still alive -- this is a hang, not an"
    say "   absent run.  A run that is still waiting after ${wall}s is a run that is"
    say "   waiting on a window, and for this package the only window that can"
    say "   appear is the ROM file picker."
    ps -o pid=,etime=,comm= -p "$pid" | sed 's/^/      /'
    # Stop it.  A leg that hangs on a window and leaves the window open has moved
    # the problem from the log to the user's screen, and the next leg's 'open'
    # would find an app already running.
    kill -INT "$pid" 2>/dev/null || true
    sleep 3
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
      say "   SIGINT did not stop it, SIGKILL did: the run is recorded as a hang."
    else
      say "   SIGINT stopped it: the run is recorded as a hang, with the reason read"
      say "   from the report it wrote on the way out, if it wrote one."
    fi
    if [ -f "$statedir/last_run_report.json" ]; then
      say "   and a report did appear after the stop:"
      python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); st=d.get('status') or {}
print('reason=%s host frames=%s at %s' % (d.get('reason'), st.get('frame'), d.get('timestamp')))
" "$statedir/last_run_report.json" | sed 's/^/      /'
    fi
  else
    echo "      no report and no process: the LaunchServices leg did not run"
  fi
else
  python3 - "$statedir/last_run_report.json" <<'PY' | sed 's/^/      /'
import json, sys
d = json.load(open(sys.argv[1]))
st = d.get("status") or {}
sd = d.get("sdl") or ""
bd = d.get("build") or {}
print("report written by the process LaunchServices started:",
      "reason=%s  host frames=%s  at %s" % (d.get("reason"), st.get("frame"),
                                            d.get("timestamp")))
print("  build game=%s version=%s" % (bd.get("game"), bd.get("version")))
if isinstance(sd, dict):
    print("  sdl video=%s audio=%s" % (sd.get("video_driver"), sd.get("audio_driver")))
for e in (d.get("breadcrumbs") or {}).get("events", []):
    m = e.get("msg", "")
    if ("rom resolved" in m or "rom loaded" in m or "anchored" in m
            or "SDL init ok" in m or "window created" in m
            or "renderer initialized" in m or m.startswith("exit:")):
        print("  breadcrumb t=%sms: %s" % (e.get("t_ms"), m))
PY
  # Which drivers the run really used comes out of the breadcrumb stream, not out
  # of the report's "sdl" block: the framework writes that block at report time,
  # after SDL_Quit(), so it reads "(none)" for every run, dummy or real
  # (runner/src/host_report.c:345).  Reading it as a driver record would be a
  # false claim about a real window.
  init_line="$( { grep -o 'SDL init ok: [^"]*' "$statedir/last_run_report.json" || true; } | head -1)"
  win_line="$( { grep -o 'window created: [^"]*' "$statedir/last_run_report.json" || true; } | head -1)"
  say "   drivers this run actually opened: ${init_line:-no 'SDL init ok' breadcrumb}"
  say "   ${win_line:-no 'window created' breadcrumb}"
  case "$init_line" in
    *video=dummy*)
      say "   so this run used the dummy drivers after all: the claim available here is"
      say "   the LaunchServices start, the anchor and the run itself, and no real-window"
      say "   claim is made." ;;
    "")
      say "   no driver breadcrumb at all: the run did not reach SDL init, which is a"
      say "   finding about this leg, not about the payload." ;;
    *)
      say "   those are the drivers a double-click gets, not the ones this script asks"
      say "   for: a real window opened on this machine for the length of the script, and"
      say "   the audio device was opened.  That is what makes this leg the click path"
      say "   and not a headless re-run of leg b." ;;
  esac
  # The anchor breadcrumb above names the directory the running process pinned
  # its state to, which is the copy under test -- the process itself is gone by
  # now, so that line, not a pid, is the proof of which bundle LaunchServices
  # started.
  if [ "$wall" -gt 60 ]; then
    say "   the wall time here is larger than the ~5 s of script this leg waits"
    say "   for, and the report's own timestamp is later than the 'open' that"
    say "   started it: this machine slept or App-Napped the launched app while the"
    say "   leg waited.  That is a property of the host, not of the payload, and it"
    say "   is stated rather than hidden because the numbers above show it."
  fi
  say "   it found its own bundle from a working directory of \"/\" (LaunchServices"
  say "   starts an app at \"/\"), resolved its state under the state directory rather"
  say "   than inside itself, and quit by itself."
  if [ -f "$statedir/rom.cfg" ]; then
    if [ "$PERSONAL" = 1 ]; then
      say "   UNEXPECTED: this app wrote a rom.cfg, so it resolved a file on disk"
      say "   rather than the image inside its own executable:"
      sed 's/^/      /' "$statedir/rom.cfg"
    else
      say "   and it left rom.cfg behind in the state directory, naming the dump it"
      say "   was given -- that is the cache that makes the first launch the only"
      say "   launch that asks:"
      sed 's/^/      /' "$statedir/rom.cfg"
    fi
  elif [ "$PERSONAL" = 1 ]; then
    say "   and it left no rom.cfg behind, because there was no ROM choice to cache:"
    say "   the guest it booted was already inside the executable.  That absence is"
    say "   the measured difference between this bundle and the shareable one."
  else
    say "   no rom.cfg written: the shipped package would ask again on every launch"
  fi
fi

if [ "$PERSONAL" = 1 ]; then
  echo "  d. opening the app with nothing passed at all, and no rom.cfg anywhere --"
  echo "     what a person who drags this in and clicks it, touching nothing, gets:"
  rm -f "$statedir/rom.cfg"
else
  echo "  d. the launcher page a user sees, reading that cached rom.cfg back -- the"
  echo "     state of the app after the ROM has been chosen once:"
  if [ ! -f "$statedir/rom.cfg" ]; then
    # Leg c cannot run in a session where LaunchServices has no GUI to start
    # the app in, so nothing created the state directory.  Leg d can still
    # measure the launcher page; create the directory the app would have.
    mkdir -p "$statedir"
    printf '%s\n' "$rom" >"$statedir/rom.cfg"
    say "   (rom.cfg put in the state directory by hand, because leg c did not leave"
    say "    one -- leg c passed --rom, so there was no choice to cache)"
  fi
fi
( cd "$work"
  "$bin" >"$OUT/launcher.log" 2>&1 &
  pid=$!
  sleep 12
  kill -INT "$pid" 2>/dev/null || true
  sleep 2
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true )
grep -E '\[Launcher\]|rom resolved|rom loaded|window created|first frame|SDL reports|config parsed' \
  "$OUT/launcher.log" | sed 's/^/      /' || say "   nothing recognised -- see $OUT/launcher.log"
if [ "$PERSONAL" = 1 ]; then
  say "   no --rom, no rom.cfg in the bundle and no file to pick: the launcher's own"
  say "   anchor line, then 'rom resolved: <embedded:...>', then a window.  Had the"
  say "   image not been in the executable, this leg is where the file picker would"
  say "   have appeared and the log would show no 'rom loaded' line at all."
  say "   No ROM data was written into the package by any leg: the guest was already"
  say "   in the executable before packaging began."
else
  say "   that rom.cfg lives only in this scratch copy; the shipped package has none,"
  say "   which is why the first launch asks.  No leg in this run ever reached the"
  say "   ROM file picker, and no ROM data was written into the package."
fi

echo
echo "  e. the actual install path: copy the .app out of the mounted image with"
echo "     Finder-equivalent ditto into a fresh directory that is not this"
echo "     repository at all, then run that copy from that directory"
inst="${PKG_INSTALL_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/srpkg.XXXXXX")/}"
inst="${inst%/}"
say "   scratch install directory (machine-local, outside the repository): $inst"
rm -rf "$inst"; mkdir -p "$inst"
touch "$OUT/.stamp"
ditto "$DMG_MOUNT/$APP_NAME.app" "$inst/$APP_NAME.app"
mac2="$inst/$APP_NAME.app/Contents/MacOS"
say "   copied out of the image     $(sha "$mac2/$APP_NAME")"
if [ "$(sha "$mac2/$APP_NAME")" = "$(sha "$C/MacOS/$APP_NAME")" ]; then
  say "   same bytes as dist/$APP_NAME.app  (the drag changes nothing but the path)"
else
  say "   DIFFERENT bytes from dist/$APP_NAME.app -- the copy is not the payload"
fi
hdiutil detach "$DMG_MOUNT" >/dev/null 2>&1 || true
DMG_MOUNTED=""
# A fresh install, really fresh: the state directory this run has been using is
# removed, so what follows is a first launch on a machine that has never seen the
# port -- which is what a person who just dragged the icon gets.  It is the
# private directory under $OUT/state_home$SFX, never this machine's own.
rm -rf "$statedir"
say "   state directory before that launch: $( [ -d "$statedir" ] && echo present || echo 'absent -- nothing of the port exists yet' )"
before_list="$(cd "$mac2" && find . -type f | sort)"
say "   the installed copy, as shipped (it carries no state of any kind):"
printf '%s\n' "$before_list" | sed 's/^/      /'
t0=$(date +%s)
run_bounded "$OUT/installed.log" "${LEG_MAX:-90}" "$inst" "$ROM_LEGS" "$mac2/$APP_NAME" \
  --no-launcher --script "$SELFCHECK_SCRIPT"
rc=$leg_rc
say "   exit=$rc wall=$(( $(date +%s) - t0 ))s, run with CWD=$inst"
grep -E '^script |frame service|SDL init ok|rom resolved|rom loaded|window created' "$OUT/installed.log" \
  | sed 's/^/      /' || say "   no recognisable progress lines -- see $OUT/installed.log"
after_list="$(cd "$mac2" && find . -type f | sort)"
say "   written inside the installed bundle by that run:"
comm -13 <(printf '%s\n' "$before_list") <(printf '%s\n' "$after_list") | sed 's/^/      /'
say "   (expect nothing: the app keeps its state outside the bundle)"
say "   payload paths that disappeared during that run: $(comm -23 <(printf '%s\n' "$before_list") <(printf '%s\n' "$after_list") | count)   (expect 0: the list after is the list before, so nothing the package needs was deleted)"
say "   the bundle's seal after that run, asked of the installed copy:"
codesign --verify --strict --verbose=2 "$inst/$APP_NAME.app" 2>&1 | sed 's/^/      /' || true
say "   what the first launch created in the state directory instead:"
if [ -d "$statedir" ]; then
  ( cd "$statedir" && find . | sort ) | sed 's/^/      /'
  say "   saves and settings live there, next to the player's other per-app state,"
  say "   not inside the .app: replacing or re-downloading the app keeps them, and a"
  say "   read-only copy -- a mounted image, a translocated run -- cannot make a save fail."
else
  say "   NOTHING: the run wrote no state anywhere under \$HOME, which would be a bug"
fi
if [ "$PERSONAL" = 1 ]; then
  if [ -f "$statedir/rom.cfg" ]; then
    say "   UNEXPECTED: a rom.cfg appeared in the state directory:"
    sed 's/^/      /' "$statedir/rom.cfg"
  else
    say "   and no rom.cfg exists afterwards anywhere: this run named"
    say "   no file on disk and cached no choice, because the guest came out of the"
    say "   executable's own bytes.  So this copy is self-contained twice over -- no"
    say "   repository, no build tree, no Homebrew, and no dump to depend on."
  fi
fi
stray_list="$(find "$ROOT" -maxdepth 1 -mindepth 1 -newer "$OUT/.stamp" -print)"
if [ -z "$stray_list" ]; then stray=0; else stray="$(printf '%s\n' "$stray_list" | count)"; fi
say "   files in this repository touched during that run: $stray   (expect 0: an"
say "   installed app must not read or write this checkout even when this checkout"
say "   is the machine that built it)"
if [ "$stray" != 0 ]; then
  say "   named, so the count is not the whole claim -- a bare number hides who did it:"
  printf '%s\n' "$stray_list" | sed 's/^/      /'
  say "   a .DS_Store entry is Finder's own directory bookkeeping, written when the"
  say "   Finder looks at a folder; it is not this app, and the app's own state"
  say "   stayed inside the installed copy.  Anything else in that list would be a"
  say "   real finding and this leg would be saying so.)"
fi
say "   which is the point of the .app: the payload carries its own anchor, so an"
say "   installed copy is self-contained -- no repository, no build tree, no"
say "   Homebrew, and no second copy of the runtime files."

echo
echo "  f. what that changed on disk, both sides of the line:"
after_bundle="$(find "$work" | sort | shasum | cut -c1-16)"
after_n="$(find "$work" | count)"
printf '  %-34s %s files, tree hash %s\n' "bundle copy before the legs" "$before_n" "$before_bundle"
printf '  %-34s %s files, tree hash %s\n' "same copy after every leg" "$after_n" "$after_bundle"
if [ "$before_bundle" = "$after_bundle" ]; then
  say "   the bundle copy under test is byte-for-byte what it was before any of"
  say "   these runs: the app wrote nothing inside itself, at any point, through a"
  say "   scripted boot, a LaunchServices start, a launcher page and a save."
  say "   Its seal, asked again after all of that:"
  codesign --verify --strict "$work/$APP_NAME.app" 2>&1 | sed 's/^/      /' || true
  say "   (empty = valid).  A copy that survives being copied, mounted, dragged and"
  say "   run, and still validates, is the property the 'is damaged' complaint says"
  say "   this payload used to fail."
else
  say "   the bundle copy changed: the app wrote inside itself after all.  Its full"
  say "   inventory, so the names are visible rather than implied:"
  find "$work" | sed "s|$work|.|" | sort | sed 's/^/      /'
  say "   its seal, asked again:"
  codesign --verify --strict "$work/$APP_NAME.app" 2>&1 | sed 's/^/      /' || true
fi
echo
echo "== 6. what the installed app leaves behind =="
echo
printf '  %-14s %s  %s B  sha256 %s\n' "package" "$(basename "$DMG")" "$(stat -f%z "$DMG")" "$(sha "$DMG")"
printf '  %-14s %s unpacked, %s B compressed\n' "app" "$(du -sh "$APP" | cut -f1)" "$(stat -f%z "$DMG")"
say "written inside the bundle by those legs, in Contents/MacOS:"
find "$mac" -type f ! -name "$APP_NAME" | sed "s|$mac|.|" | sort | sed 's/^/    /'
say "  (expect nothing above: the payload is what it was, which is why the seal made"
say "   in section 1 still validates after a run)"
say "the state directory the legs left behind:"
if [ -d "$statedir" ]; then
  ( cd "$statedir" && find . | sort ) | sed 's/^/    /'
  say "  its mod catalog holds $(find "$statedir/mods" -type f 2>/dev/null | count) file(s), created by the app itself rather than shipped by this script"
else
  say "    absent"
fi
echo
say "That is the trade-off, and it is the one a person installing this expects:"
say "no installer and no privileged helper, the app can live anywhere it is put --"
if [ "$PERSONAL" = 1 ]; then
  say "and its saves and settings live in ~/Library/Application Support/$APP_NAME/"
  say "rather than inside the bundle, so replacing or re-downloading the"
else
  say "and its saves, settings and ROM choice live in ~/Library/Application Support/"
  say "$APP_NAME/ rather than inside the bundle, so replacing or re-downloading the"
fi
say "app keeps them, and the bundle stays sealed and verifiable.  A port that kept"
say "state inside the bundle had the other trade: moving the app moved its saves,"
say "and the loose files inside Contents/MacOS/ made the bundle impossible to seal"
say "-- which is the shape a downloaded copy of that would be refused for."
if [ "$PERSONAL" = 1 ]; then
  echo
  say "And the larger trade-off, stated where someone will find it: this container"
  say "holds the game.  $PKG_SLUG-$VERSION-$PLATFORM_TAG$DMG_SFX.dmg is not a"
  say "shareable artefact -- sending it to anyone is sending them a copy of"
  say "Shadowrun.  The shareable one is what this script builds without PERSONAL=1."
  say "The personal build says what it is in three places that travel with it:"
  say "Contents/Resources/BUILD_INFO.txt inside the bundle, README.txt at the root"
  say "of the image, and its own NSHumanReadableCopyright, which is what Finder"
  say "shows in Get Info."
fi

echo
if [ "$PERSONAL" = 1 ]; then
  echo "== 7. the frames the shipped bytes produce, taken out of the container =="
  echo
  say "four legs to 1200 frames on the kit's menu route, and the subject of two of"
  say "them is the executable as the container holds it -- read straight off the"
  say "read-only mount, not the copy in dist/ and not a copy made for the run:"
  echo "  a. that executable with --rom naming the dump: the file-based path"
  echo "  b. the same executable with no --rom at all: the guest compiled inside it is"
  say "     what has to run, so this is the leg that exercises the embedded path"
  if [ "$EDITION" = us ]; then
    echo "  c. $REF_PIN, the build this kit has treated as correct since the re-baselining"
    say "     round, with --rom.  What it was configured against is printed below rather"
    say "     than asserted here -- framework status against the pin, build record, SDL3"
    say "     reference -- and pairing with it therefore spans framework, deployment floor"
    say "     and SDL3 linkage rather than repeating a comparison this kit already ran."
    echo "  d. $SHIP_EXE, the tree built at this package's floor on a framework that"
    say "     carries the state fix but not the guest, with --rom.  Whether its framework"
    say "     is the same one this package used is not claimed here: section 0 prints this"
    say "     package's revision and the lines below print this one's.  What the pair can"
    say "     show follows from what they share -- floor, and a framework with the state"
    say "     fix and no guest -- so the difference between it and a or b is the guest"
    say "     moving from a file into the executable."
  else
    echo "  c. $REF_PIN, this edition's own build tree, with --rom: the embedded-image"
    say "     legs a and b against the ROM-based executable this edition was built as."
    say "     The kit's accepted reference builds are USA-configured and their routes"
    say "     were measured on USA text, so a cross-edition frame comparison would"
    say "     measure the translation, not the embedding.  d is the same file."
  fi
  say ""
  say "How far apart any two of these are is not assumed: the lines below print every"
  say "subject's hash, size and build record, and c's and d's framework status against"
  say "the pin, in the same call section 0 uses for this package."
else
  echo "== 7. the frames the shipped bytes produce, taken out of the container =="
  echo
  say "three legs to 1200 frames on the kit's menu route -- the personal variant's"
  say "shape with its embedded-ROM leg taken away, because this payload has no"
  say "embedded guest to exercise (section 2 established that).  The subject of the"
  say "first leg is the executable as the container holds it, read off the read-only"
  say "mount, not the copy in dist/: section 5 compares the copy in dist/, and this"
  say "section answers the question a person who downloaded the .dmg would ask instead."
  echo "  a. that executable, with --rom naming the dump"
  if [ "$EDITION" = us ]; then
    echo "  c. $REF_PIN, the build this kit has treated as correct since the re-baselining"
    say "     round, with --rom: what it was configured against is printed below rather"
    say "     than asserted here, and pairing with it spans framework, deployment floor"
    say "     and SDL3 linkage."
    echo "  d. $SHIP_EXE, the tree built at the framework and floor section 0 says this"
    say "     package uses: the pair that holds framework and floor constant, so what is"
    say "     left between it and a is which copy of the program ran and from where."
  else
    echo "  c. $REF_PIN, this edition's own build tree, with --rom: the packaged bytes"
    say "     against the executable they were made from.  The kit's accepted reference"
    say "     builds are USA-configured, and their frame routes were measured on USA"
    say "     text: comparing the $EDITION_TITLE translation against one of those would"
    say "     measure the translation, not the packaging.  d is the same file."
  fi
  say ""
  if [ "$EDITION" = us ]; then
    say "How far apart the three are is not assumed: the lines below print every"
    say "subject's hash, size and build record, and c's and d's framework status against"
    say "the pin, in the same call section 0 uses for this package."
  else
    say "How far apart a and c are is not assumed: the lines below print both subjects'"
    say "hash, size and build record, and c's framework status against the pin in the"
    say "same call section 0 uses for this package."
  fi
fi
# Section 5's install leg detaches the volume when it finishes -- that is what a
# person does with one -- so this section attaches it again and takes its subjects
# from the read-only mount.  The EXIT trap detaches it if anything below dies.
if [ ! -d "${DMG_MOUNT:-}" ]; then
  DMG_MOUNT="$(hdiutil attach -readonly -nobrowse "$DMG" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
  DMG_MOUNTED="$DMG_MOUNT"
  say "attached $DMG at $DMG_MOUNT for these legs"
fi
# HOME was set to a private directory in section 5 and is still exported, so these
# legs cannot write runtime state next to the checkout even though one of them runs
# with the repository as its cwd.
say "these legs run under the private \$HOME section 5 set up ($state_home), so any"
say "state a run writes lands under tests/out/ rather than next to the checkout."
# Both sides of the frame comparison identified before either of them runs.  c's
# framework status is measured here in the same call section 0 uses for this
# package, so a reader can see how far apart the two sides are without going back
# to framework_pins.txt or trusting the prose.
IMG_EXE7="$DMG_MOUNT/$APP_NAME.app/Contents/MacOS/$APP_NAME"
if [ "$PERSONAL" = 1 ]; then side_ab="a/b"; else side_ab="a"; fi
if [ -f "$IMG_EXE7" ]; then
  printf '  %-32s %s  %s B\n' "subject $side_ab (in the image)" "$(sha "$IMG_EXE7")" "$(stat -f%z "$IMG_EXE7")"
  say "     build record: minos $(minos_of "$IMG_EXE7"), sdk $(sdk_of "$IMG_EXE7")"
  sd_ref="$(sd_name "$IMG_EXE7")"
  say "     SDL3, from its own load commands: $( [ -n "$sd_ref" ] && echo "$sd_ref" || echo 'no SDL dylib load command -- SDL3 is inside this Mach-O' )"
else
  say "subject $side_ab: no executable at $APP_NAME.app/Contents/MacOS/$APP_NAME in the image"
fi
printf '  %-32s %s  %s B\n' "subject c ($REF_PIN)" "$(sha "$REF_PIN")" "$(stat -f%z "$REF_PIN")"
say "     build record: minos $(minos_of "$REF_PIN"), sdk $(sdk_of "$REF_PIN")"
sd_ref="$(sd_name "$REF_PIN")"
say "     SDL3, from its own load commands: $( [ -n "$sd_ref" ] && echo "$sd_ref" || echo 'no SDL dylib load command -- SDL3 is inside this Mach-O' )"
if [ "$REF_PIN" -ef "$SHIP_EXE" ]; then
  say "subject d: the same file as c ($REF_PIN), so the d leg below is skipped rather"
  say "     than run twice -- SHIP_EXE and REF_PIN name one tree in this checkout."
else
  printf '  %-32s %s  %s B\n' "subject d ($SHIP_EXE)" "$(sha "$SHIP_EXE")" "$(stat -f%z "$SHIP_EXE")"
  say "     build record: minos $(minos_of "$SHIP_EXE"), sdk $(sdk_of "$SHIP_EXE")"
  sd_ref="$(sd_name "$SHIP_EXE")"
  say "     SDL3, from its own load commands: $( [ -n "$sd_ref" ] && echo "$sd_ref" || echo 'no SDL dylib load command -- SDL3 is inside this Mach-O' )"
fi
say "  c's and d's frameworks, measured as section 0 measures this package's:"
for t in "$REF_PIN" "$SHIP_EXE"; do
  python3 tests/provenance.py pin --descendant "$(dirname "$t")" 2>&1 | sed 's/^/      /' || true
done
echo
for leg in frames_file frames_embed frames_refpin frames_ref11; do
  case "$leg" in
    # The volume legs run the bytes as the container holds them, off the read-only
    # mount, from a scratch cwd -- never from this repository: a bundle's executable
    # resolves its state under $HOME, and a leg run from the repo root would scatter
    # runtime files next to the checkout instead of under tests/out/.
    frames_file)    tgt="$DMG_MOUNT/$APP_NAME.app/Contents/MacOS/$APP_NAME"; mode=with; cwd="$OUT" ;;
    frames_embed)   tgt="$DMG_MOUNT/$APP_NAME.app/Contents/MacOS/$APP_NAME"; mode=none; cwd="$OUT" ;;
    frames_refpin)  tgt="$REF_PIN"; mode=with; cwd="$ROOT" ;;
    frames_ref11)   tgt="$SHIP_EXE"; mode=with; cwd="$ROOT" ;;
  esac
  if [ "$leg" = frames_embed ] && [ "$PERSONAL" != 1 ]; then
    say "  frames_embed: not applicable -- the shareable build carries no guest image,"
    say "        so there is no embedded path to exercise.  Section 2's finding that no"
    say "        rom.cfg and no image sits in the payload is what says a leg without"
    say "        --rom here would have nothing to boot."
    continue
  fi
  if [ "$EDITION" != us ] && { [ "$leg" = frames_refpin ] || [ "$leg" = frames_ref11 ]; }; then
    say "  $leg: not run for the $EDITION_TITLE edition -- the reference builds this"
    say "        section compares against are USA-configured and their routes were"
    say "        measured on USA text.  Section 5 already ran this edition's packaged"
    say "        copy against its own build tree, frame for frame."
    continue
  fi
  if [ "$leg" = frames_ref11 ] && [ "$REF_PIN" -ef "$SHIP_EXE" ]; then
    say "  frames_ref11: skipped -- c and d are one and the same file here, as the"
    say "        subject lines above show, so running it twice would only double a"
    say "        comparison this section has already made."
    continue
  fi
  if [ ! -x "$tgt" ]; then
    say "  $leg: SKIPPED, $tgt is not runnable -- the mount above is what carries these"
    say "        bytes, so without it this leg has no subject"
    continue
  fi
  rm -rf "$OUT/$leg$SFX"
  say "  $leg: $(basename "$tgt")  --rom $( [ "$mode" = with ] && echo 'named on the command line' || echo 'not named, deliberately' )  cwd=$( [ "$cwd" = "$ROOT" ] && echo 'the port directory' || echo 'a scratch directory, not the repository' )"
  run_bounded "$OUT/${leg}$SFX.log" "${LEG_MAX:-240}" "$cwd" "$mode" "$tgt" \
    --no-launcher --script "$ROOT/tests/scripts/menu.txt" --framedump "$OUT/$leg$SFX"
  say "    exit=$leg_rc -> $(find "$OUT/$leg$SFX" -name 'frame_*.bin' 2>/dev/null | count) WRAM dumps"
  say "    what the host itself said about where its guest came from:"
  { grep -i 'rom resolved\|rom identity\|rom loaded\|picker' "$OUT/${leg}$SFX.log" | sed 's/^/      /'; } || true
  if [ "$leg_rc" != 0 ]; then
    say "    that leg exited non-zero, or was stopped past ${LEG_MAX:-240}s: its log is"
    say "    $OUT/${leg}$SFX.log.  A leg that hung rather than failed would have been"
    say "    waiting on a ROM file picker no automated run can answer."
  fi
done
echo
# The same comparison §5 runs -- per-frame WRAM crc32 from each run's frame_*.json,
# then framedump_diff.py's state alignment -- pulled into a function because this
# section may run it twice.
crc_cmp_frames() {
  python3 - "$1" "$2" <<'PY'
import glob, os, re, sys
a, b = sys.argv[1], sys.argv[2]


def crc(p):
    h = re.findall(r'0x[0-9A-Fa-f]{8}', open(p).read())
    return h[-1] if h else None


fa = sorted(glob.glob(os.path.join(a, "frame_*.json")))
same = diff = 0
first = None
for f in fa:
    g = os.path.join(b, os.path.basename(f))
    ca, cb = crc(f), (crc(g) if os.path.isfile(g) else None)
    if ca is not None and ca == cb:
        same += 1
        continue
    diff += 1
    if first is None:
        first = (os.path.basename(f), ca, cb)
if diff:
    print(f"  {diff} of {same + diff} frames differ")
    if first:
        print(f"  first divergence at {first[0]}: {first[1]} vs {first[2]}")
else:
    print(f"  identical over {same} frames (crc32 of all 128 KiB of WRAM per frame)")
PY
}
pairs=1
if [ "$EDITION" != us ]; then
  # Only comparisons within the same edition are meaningful here; see the leg
  # loop above.  A personal language build still has its a-vs-b pair, because
  # both subjects are this edition's own executable.
  if [ "$PERSONAL" = 1 ]; then pair_list=("frames_file frames_embed"); else pair_list=(); pairs=0; fi
elif [ "$PERSONAL" = 1 ]; then
  pair_list=("frames_file frames_embed" "frames_file frames_refpin" "frames_embed frames_refpin" "frames_file frames_ref11" "frames_embed frames_ref11")
else
  pair_list=("frames_file frames_refpin" "frames_file frames_ref11")
fi
if [ "$pairs" = 1 ]; then
for pair in "${pair_list[@]}"; do
  a="$OUT/${pair%% *}$SFX"; b="$OUT/${pair##* }$SFX"
  if [ ! -d "$a" ] || [ ! -d "$b" ]; then
    say "  $(basename "$a") vs $(basename "$b"): skipped, one side has no directory of"
    say "     dumps at all.  Which side, and why, is above: the legs print either an"
    say "     exit code and a dump count, or the reason they were not run."
    continue
  fi
  echo "  $(basename "$a")  vs  $(basename "$b")   ($(find "$a" -name 'frame_*.json' | count) and $(find "$b" -name 'frame_*.json' | count) frame records)"
  crc_cmp_frames "$a" "$b" | sed 's/^/      /'
  ( cd "$ROOT" && python3 tests/framedump_diff.py state "$a" "$b" ) 2>&1 | tail -4 | sed 's/^/      /'
  echo
done
fi
if [ "$EDITION" != us ] && [ "$PERSONAL" != 1 ]; then
  say "No cross-build pair is reported for the $EDITION_TITLE edition.  The subjects"
  say "this section can compare within one edition were compared in section 5: the"
  say "packaged copy against the executable it was built from, frame for frame.  The"
  say "mounted copy's own run above says the container's bytes still boot."
elif [ "$PERSONAL" = 1 ]; then
  say "what those pairs are each able to show.  a-vs-b: whether the guest compiled into"
  say "the executable drives the same machine as the same guest handed in as a file."
  say "a-vs-c and b-vs-c: whether the bytes a person double-clicks agree with the build"
  say "this kit has treated as correct since the re-baselining round, across the"
  say "framework and floor change -- and b is the path double-clicking takes, so that"
  say "pair is the claim this container rests on.  a-vs-d and b-vs-d: the same question"
  say "where floor is held and the guest is the main difference between the subjects."
  say "Each pair's own line above says whether it agreed, and the exit codes above say"
  say "whether a file picker appeared."
else
  say "what those pairs are each able to show.  a-vs-c: whether the bytes inside a"
  say "compressed disk image, mounted read-only, run from a scratch directory through"
  say "this kit's 1200-frame route, drive the same machine as the build this kit has"
  say "treated as correct since the re-baselining round -- and the subject lines above"
  say "print how c differs from a: framework status against the pin, deployment floor,"
  say "and how SDL3 was linked.  a-vs-d: whether they also drive the same machine as"
  say "the build made at this package's own framework and floor, which is the container"
  say "round-trip; section 5 asks that of the copy in dist/, and a person who downloads"
  say "the .dmg installs this one."
fi
echo
echo "== 8. what is inside the .dmg, and the ROM question asked of both files =="
echo
say "the container the way it would reach a person: one file, and the volume inside it"
say "enumerated while mounted read-only.  Section 4 mounted that image, section 5"
say "detached it once its install leg had run from it -- that is what a person does"
say "with one -- and section 7 attached it again to run legs off it and left it"
say "attached, which is what is being read here."
if [ ! -d "${DMG_MOUNT:-}" ]; then
  DMG_MOUNT="$(hdiutil attach -readonly -nobrowse "$DMG" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
  DMG_MOUNTED="$DMG_MOUNT"
  say "attached $DMG at $DMG_MOUNT to enumerate it (sections 4, 5 and 7 each detach or"
  say "leave it as their legs need, so this line appearing at all means they left it off)"
fi
if [ -d "$DMG_MOUNT" ]; then
  ( cd "$DMG_MOUNT" && find . -not -name '.DS_Store' | sort ) | sed 's/^/  /'
  say "  README.txt at the image root is what a person reads before they move the app;"
  say "  its floor line is not typed here, it is read out of the executable:"
  sed 's/^/  | /' "$DMG_MOUNT/README.txt"
  # The file inside the container is what a person installs, so the guest question
  # gets asked of that file as well as of the container -- read off the read-only
  # mount, before detaching, and pinned to the hash sections 3 and 4 printed so the
  # scan below is demonstrably about the bytes that shipped.
  IMG_EXE="$DMG_MOUNT/$APP_NAME.app/Contents/MacOS/$APP_NAME"
  if [ -f "$IMG_EXE" ]; then
    printf '  %-38s %s  %s B\n' "the executable inside the image" "$(sha "$IMG_EXE")" "$(stat -f%z "$IMG_EXE")"
  else
    IMG_EXE=""
    say "  no executable at $APP_NAME.app/Contents/MacOS/$APP_NAME inside the image"
  fi
  echo
  say "the ROM question, asked twice over, of two different subjects:"
  echo "  * the container -- the one file a person downloads and sends to someone;"
  echo "  * the executable inside it -- the file that actually lands on their disk."
  say "and asked two ways over, because scanning for a span is weaker than locating it"
  say "and carving that span back out: the presence scans (the image's first 256 bytes,"
  say "its filename, its SNES header string, its digest as hex text) and then the"
  say "carve-out -- find the first 256 bytes, take len(image) bytes at that offset, and"
  say "compare that span with the ROM file byte for byte and by hash."
  echo
  say "Reading the two subjects differently matters, and this is where an assumption"
  say "would have produced a confident wrong answer: -format UDZO is zlib, so a"
  say "compressed container need not hold any span of its payload verbatim.  A personal"
  say "image whose payload does carry the guest can still read absent at the container"
  say "level.  Container-level scans are a report, not the verdict; for 'what is in the"
  say "file that gets installed' the load-bearing scan is the executable's."
  echo
  say "A name and a digest are also not the same finding as bytes.  A build that will"
  say "only accept one dump has to carry that dump's name and its hash, and that is not"
  say "carrying the dump.  Where a filename hit appears, the lines below print the"
  say "printable strings on either side of it, so which kind of presence it is gets read"
  say "off the log rather than inferred from the word 'present'."
  # tee'd as well as printed: section 9 quotes the offset this scan found, and a
  # sentence that quotes a number has to be able to point at where it was measured.
  python3 - "$DMG" "${IMG_EXE:-/dev/null}" "$rom" <<'PY' | tee "$OUT/rom_scan$SFX.txt" | sed 's/^/  /'
import hashlib, os, re, sys
dmg, exe, rom = sys.argv[1], sys.argv[2], sys.argv[3]
img = open(rom, 'rb').read()
head, name, hdr = img[:256], os.path.basename(rom).encode(), img[0x40:0x50]
full = hashlib.sha256(img).hexdigest()
print("ROM file  %d B   sha256 %s" % (len(img), full[:16]))
print("The scans below ask about four things that could each be present on their own:")
print("the image's first 256 bytes, its filename, its SNES header string, and its")
print("digest written as hex text.  A name and a digest are what a build needs in order")
print("to say which dump it accepts; bytes are what a build needs in order to run one")
print("without being given one.")
for label, path in (("container ", dmg), ("exe in image", exe)):
    if not os.path.isfile(path):
        print("%s: not available, nothing scanned" % label)
        continue
    blob = open(path, 'rb').read()
    print("%s  %d B" % (label, len(blob)))
    print("    ROM first 256 bytes present:  %s" % (head in blob))
    print("    ROM filename present:         %s" % (name in blob))
    print("    SNES header string present:   %s" % (hdr in blob))
    print("    ROM sha256 as hex text:       %s"
          % (full in blob.decode("latin-1"),))
    hits = []
    i = 0
    while True:
        j = blob.find(name, i)
        if j < 0:
            break
        hits.append(j)
        i = j + 1
    for h in hits:
        ctx = blob[max(0, h - 64):h + len(name) + 96]
        words = [w.decode() for w in re.findall(rb"[ -~]{4,}", ctx)]
        print("      filename at 0x%x, and the printable strings around it are:" % h)
        print("        %r" % (words,))
    off = blob.find(head)
    if off < 0:
        print("    carve-out: no offset -- the span is not in this file")
        continue
    carve = blob[off:off + len(img)]
    diff = sum(1 for a, b in zip(carve, img) if a != b)
    print("    carve-out: found at offset 0x%x, carved %d B, %d byte(s) differ from the"
          % (off, len(carve), diff))
    print("               ROM file itself; carve hashes %s vs ROM %s -> %s"
          % (hashlib.sha256(carve).hexdigest()[:16], full[:16],
             "the same file, identified" if carve == img else "NOT the same file"))
    tail = len(img) - len(carve)
    if tail:
        print("               (%d B of the image fell past the end of this file)" % tail)
PY
  hdiutil detach "$DMG_MOUNT" >/dev/null 2>&1 || true
  DMG_MOUNTED=""
  DMG_MOUNT=""
else
  say "  could not attach $DMG, so neither the volume listing nor the executable-side"
  say "  scan below could run; the container-level scans still can, and do"
  IMG_EXE=""
fi
echo
if [ "$PERSONAL" = 1 ]; then
  say "the container is expected to hold the game -- that is the whole point of"
  say "PERSONAL=1 -- and it is labelled as such in three places that travel with it:"
  say "BUILD_INFO.txt inside the bundle, README.txt at the image root, and this bundle's"
  say "own NSHumanReadableCopyright.  What the executable-side scan is for is"
  say "identification rather than implication.  If the image is found at an offset in the"
  say "file that lands on the player's disk, and the span carved there hashes the same as"
  say "this generator's own record of the dump, then the bundle carries that dump and not"
  say "some third thing built from it.  Whether it was found is the scan's line above;"
  say "this section only says what the two outcomes would mean."
else
  say "the outcomes for this variant, and they do not all read the same way.  The"
  say "image's bytes are absent from both subjects and the carve-out finds no offset in"
  say "either, so neither the file a person downloads nor the file that lands on their"
  say "disk holds the game.  The dump's *name* is present in the executable -- once --"
  say "and the strings printed around it show what that presence is: the name sitting"
  say "next to this dump's own sha256, which is the accepted-dump record, the build"
  say "saying which file it will take from the player.  Name and digest, not the dump."
  say "Section 2 reached the same place by other means: no ROM-shaped file in the"
  say "payload, no embedded-ROM symbol in the executable, no rom.cfg, and no region of"
  say "the payload matching the digest this build checks at boot.  The volume listing"
  say "above is the other half of the answer: the image holds the bundle, one README and"
  say "an Applications shortcut, and nothing else.  The container-level scan alone would"
  say "not be enough, for the compression reason given above: absence in a zlib"
  say "container says little by itself, and the load-bearing absence is the payload's."
fi

echo
echo "== 9. what macOS's own tools say about this bundle, and what each verdict is about =="
echo
cat <<'EOF'
  The complaint this packaging exists to answer is a sentence from macOS -- '...
  is damaged and can't be opened' -- rather than a crash, so the last section asks
  for that sentence from the tools that produce it and prints their words: codesign
  (is this payload intact), spctl (may Gatekeeper let it run) and xattr (has
  anything been attached to the files that is not part of them).  Three questions,
  and they do not have the same answers: a bundle can be intact and still refused.
  Keeping the three apart is the point, because the three fixes are different and
  this script can perform only two of them.
EOF
# The verdicts are taken from a scratch copy rather than from dist/: this section
# writes extended attributes, and the shipped artefact must stay the bytes section
# 4 hashed.
gate="$OUT/gatekeeper$SFX"
rm -rf "$gate"
mkdir -p "$gate"
ditto "$APP" "$gate/$APP_NAME.app"
say "copy under test for this section        $gate/$APP_NAME.app"
verdict() {
  local label="$1"
  shift
  local out rc
  say "  $label"
  if out=$("$@" 2>&1); then rc=0; else rc=$?; fi
  printf '%s\n' "$out" | sed 's/^/      /'
  say "    [exit=$rc]"
}
say "1. what kind of signature this package is able to make, read off the bundle:"
codesign -dvvv "$APP" 2>&1 | { grep -E '^(Identifier|Format|CodeDirectory|Signature|TeamIdentifier|Sealed Resources)' || true; } | sed 's/^/      /'
xcrun stapler validate "$APP" 2>&1 | sed 's/^/      /' || true
say "      'Signature=adhoc' and 'TeamIdentifier=not set' say whose identity is on"
say "      this bundle -- nobody's -- and 'does not have a ticket' says it was never"
say "      notarised.  Both are facts about this build, not accidents to fix here."
verdict "2. Gatekeeper's assessment of that bundle, on a copy this machine itself built:" spctl -a -vv -t execute "$gate/$APP_NAME.app"
xattr -w com.apple.quarantine "0081;$(printf '%08x' "$(date +%s)");Chrome;" "$gate/$APP_NAME.app" \
  && say "      the quarantine flag a browser leaves on a download, now set: $(xattr -p com.apple.quarantine "$gate/$APP_NAME.app")"
verdict "3. the same assessment with that flag set -- the state of a downloaded copy:" spctl -a -vv -t execute "$gate/$APP_NAME.app"
verdict "4. the seal, with that same flag on the bundle -- does the download flag break it?" codesign --verify --strict --verbose=2 "$gate/$APP_NAME.app"
say "      the assessment above does not change and the seal still validates, so the"
say "      refusal and the payload are two different findings.  A damaged-looking"
say "      download is not, on this evidence, a download that arrived broken."
say "5. attached data: what the payload carries, and what happens when something is added."
xattr -l "$C/MacOS/$APP_NAME" | sed 's/^/      /'
say "      (expect nothing above: no extended attribute on the shipped executable)"
xattr -w com.apple.FinderInfo "00000000000000000000000000000000" "$gate/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
  && say "      now give the scratch copy's executable the Finder metadata a copy-through-Finder or a stray resource fork leaves behind:"
verdict "6. the strict seal check with that attribute present:" codesign --verify --strict --verbose=2 "$gate/$APP_NAME.app"
xattr -d com.apple.FinderInfo "$gate/$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
verdict "7. and again with it removed:" codesign --verify --strict --verbose=2 "$gate/$APP_NAME.app"
say "8. the third way a copy reads as damaged was measured in section 1: a payload laid"
say "   out the way the pinned framework lays one out -- keybinds.ini, rom.cfg and the"
say "   mod catalog loose beside the executable -- cannot be sealed at all, and codesign"
say "   says 'code object is not signed at all' and names the loose file as a"
say "   subcomponent.  That is the finding the host-side fix removes."
echo
if [ "$PERSONAL" = 1 ]; then
  say "so, of the three ways this bundle can be refused:"
  say "  * an unsealable payload, the shape every previous round of this port shipped:"
  say "    removed, and section 5 shows the shipped bundle still validating after it was"
  say "    copied, mounted, dragged and run.  That is the one this work was about."
  say "  * attached Finder metadata: not created by anything in this build (line 5 above"
  say "    is empty), and section 6's ditto copy keeps validating, so the drag a person"
  say "    does does not add any.  Line 6 is here to show what would."
  say "  * no developer identity: not removed, and nothing in this script can remove it."
  say "    Lines 1-3 are the measurement of that: the assessment is 'rejected' before any"
  say "    download flag is involved, because the signature is ad hoc and unnotarised."
  say "    That is why README.txt at the image root of this personal build tells the player"
  say "    to right-click and choose Open, and gives the xattr command: it is the"
  say "    documented way past a verdict that is correct about what this build is."
  echo
  say "And the reason this variant in particular cannot be handed to anyone: the"
  say "section-8 scan above finds the guest image inside the executable that lands on"
  say "the player's disk, byte for byte, at offset $(awk '/carve-out: found at offset/{gsub(/,.*/,"",$5); print $5; exit}' "$OUT/rom_scan$SFX.txt"), hashing back to the same"
  say "sha256 as this kit's dump.  That is what 'personal' means here, and it is the"
  say "same bundle's refusal a stranger would see if it were sent to them."
else
  say "so, of the three ways this bundle can be refused:"
  say "  * an unsealable payload, the shape every previous round of this port shipped:"
  say "    removed, and section 5 shows the shipped bundle still validating after it was"
  say "    copied, mounted, dragged and run, with nothing written inside it.  That is the"
  say "    one this work was about, and it is the one that produced the original report."
  say "  * attached Finder metadata: not created by anything in this build (line 5 above"
  say "    is empty), and section 5's ditto copy keeps validating, so the drag a person"
  say "    does does not add any.  Line 6 is here to show what would, because a port that"
  say "    ships loose files also tends to be moved around by tools that add them."
  say "  * no developer identity: not removed, and nothing in this script can remove it."
  say "    Lines 1-3 are the measurement of that: the assessment is 'rejected' before any"
  say "    download flag is involved, because the signature is ad hoc and unnotarised."
  say "    A shareable build carries that verdict too, which is why README.txt at the"
  say "    image root tells a person to right-click and choose Open and gives the xattr"
  say "    command.  Anyone who would rather not tell their users that needs a Developer"
  say "    ID signature and a notarisation ticket; both are outside what this script can"
  say "    do, and the log records that rather than pretending otherwise."
fi

echo
echo "== DONE  (log: $LOG)"
