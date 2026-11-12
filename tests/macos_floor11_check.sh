#!/usr/bin/env bash
# Does the macOS 11 floor recipe reach the shipped bytes from a clean tree?
#
#   tests/macos_floor11_check.sh
#   SHIP_TREE=build-ship-m11 tests/macos_floor11_check.sh      # other baseline
#
# The floor probe (tests/macos_floor_probe.sh) reads build records; it never
# builds.  The floor-11 build round (tests/out/m11_build.log) does build, but it
# ran inside trees that already existed, so its `cmake --build` step found SDL3
# and the generated objects already in place -- it shows the recorded command
# lines relink to the same payload, not that a clean tree reaches them.
#
# This script builds one tree from scratch -- fresh directory, nothing cached --
# using the configure line as the floor-11 round printed it, and then compares
# the result with the tree the shipped shareable .app was packaged from:
#
#   0. where every input came from -- the shipped tree's own CMakeCache.txt, so
#      no path or option here is typed by hand; the framework and SDL3 source
#      directories are checked to exist and to be what that cache says;
#   1. the clean build, with the exact cmake and cmake --build lines echoed as
#      they run, and its warnings and errors counted rather than trusted;
#   2. the payload against the shipped tree's: hashes, sizes, `cmp`, minimum
#      system version, and the load commands each one asks dyld to find.
#
# The framework and SDL3 directories this needs are clones outside this
# repository; if they are gone the script says so and stops rather than
# configuring against something else and presenting the result as the same build.
#
# Exit 0 = the clean build produced byte-identical payload bytes to the shipped
# tree.  Anything else exits nonzero and says which leg decided it.
# The log is tests/out/m11_check.log, committed verbatim as
# evidence/artifacts/macos_floor11_rebuild.md.  The clean tree's raw cmake/cmake
# --build output (~900 lines of compiler probing) goes to
# tests/out/m11_check_build.log, committed verbatim as
# evidence/artifacts/macos_floor11_rebuild_build.md; the warning and error counts
# in section 1 are read out of that file, so they cannot count this script's own
# summary lines as output, and section 1 hashes it so the two committed files
# cannot be mismatched.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
ship="${SHIP_TREE:-build-ship-m11}"        # what scripts/package_macos_bundle.sh packaged
fresh="${FRESH_TREE:-build-ship-m11-check}"
out="$root/tests/out"
log="$out/m11_check.log"
mkdir -p "$out"
: >"$log"
exec > >(tee -a "$log") 2>&1

say() { printf '  %s\n' "$*"; }
sha() { shasum -a 256 "$1" 2>/dev/null | cut -c1-16; }
bytes() { wc -c <"$1" | tr -d '[:space:]'; }
minos() { otool -l "$1" 2>/dev/null | awk '/LC_BUILD_VERSION/{f=1;next} f&&/minos/{print $2; exit} /LC_SOURCE_VERSION|LC_VERSION_MIN/{f=0}'; }
arch_of() { lipo -archs "$1" 2>/dev/null | wc -w | tr -d '[:space:]'; }
nonSystem() { otool -L "$1" 2>/dev/null | tail -n +2 | grep -vcE '/System/|/usr/lib'; }
nproc_="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
pin_rev="$(grep -m1 '^snesrecomp=' "$root/framework_pins.txt" | cut -d= -f2)"
# The build's own output goes to a separate file, and the warning counts are read
# out of *that* file.  Counting them out of this script's log would count this
# script's own "warning lines: N" summary line as a warning, which is how a
# clean build starts reporting one.
blog="$out/m11_check_build.log"
: >"$blog"
# grep -c prints 0 AND exits 1 when there are no matches, so a naive `|| echo 0`
# prints the zero twice.  head -1 keeps exactly the number grep counted.
count_in() { { grep -c -- "$1" "$blog" || true; } 2>/dev/null | head -1; }
count_warnings() { count_in 'warning:'; }
count_unguarded() { count_in 'Wunguarded-availability'; }
count_errors() { count_in 'error:'; }

rc_final=0
fail() { say "FAIL: $*"; rc_final=1; }

echo "== 0. where the inputs come from =="
echo
say "baseline tree (the one the shipped .app came from): $ship"
if [ ! -f "$ship/CMakeCache.txt" ]; then
  say "$ship/CMakeCache.txt not found -- nothing to take inputs from, so this script"
  say "has no recorded recipe to reproduce.  Nothing was built."
  exit 1
fi
cache="$ship/CMakeCache.txt"
pick() { grep -m1 "^$1:" "$cache" | cut -d= -f2-; }
fw="$(pick SNESRECOMP_ROOT)"
sdl3="$(pick FETCHCONTENT_SOURCE_DIR_SDL3)"
tgt="$(pick CMAKE_OSX_DEPLOYMENT_TARGET)"
mods="$(pick SNESRECOMP_ENABLE_MODS)"
dis="$(pick CMAKE_DISABLE_FIND_PACKAGE_SDL3)"
btype="$(pick CMAKE_BUILD_TYPE)"
say "read out of $cache (nothing below is typed by hand):"
for k in CMAKE_BUILD_TYPE CMAKE_OSX_DEPLOYMENT_TARGET CMAKE_DISABLE_FIND_PACKAGE_SDL3 FETCHCONTENT_SOURCE_DIR_SDL3 SNESRECOMP_ENABLE_MODS SNESRECOMP_ROOT; do
  say "  $(grep -m1 "^$k:" "$cache")"
done
echo
say "framework pin this repository records (framework_pins.txt): $pin_rev"
if [ -d "$fw" ]; then
  head="$(git -C "$fw" rev-parse HEAD 2>/dev/null)"
  dirty="$(git -C "$fw" status --porcelain 2>/dev/null | wc -l | tr -d '[:space:]')"
  ahead="$(git -C "$fw" rev-list --count "$pin_rev..HEAD" 2>/dev/null)"
  say "framework $fw"
  say "  HEAD $head  dirty $dirty  commits past the pin: $ahead"
  say "  its last commit: $(git -C "$fw" log -1 --format='%s')"
  [ "$dirty" = 0 ] || fail "the framework clone has uncommitted changes, so its bytes are not the bytes the baseline tree was built from"
  if ! git -C "$fw" merge-base --is-ancestor "$pin_rev" HEAD 2>/dev/null; then
    fail "the pin is not an ancestor of $fw -- the baseline tree's cache names a framework that is not this recipe"
  fi
else
  say "framework directory $fw does not exist."
  say "This is the honest failure mode: the framework is not vendored in this"
  say "repository, so the recipe cannot be replayed without its clone.  Stopping."
  exit 1
fi
echo
if [ -f "$sdl3/CMakeLists.txt" ]; then
  say "SDL3 source $sdl3"
  say "  it declares  $(grep -m1 'project(SDL3' "$sdl3/CMakeLists.txt" | tr -s ' ')"
  say "  version the framework pins for CI: $(grep -m1 'set(SNESRECOMP_SDL3_FETCH_VERSION' "$fw/runner/runner.cmake" 2>/dev/null)"
else
  say "SDL3 source $sdl3 does not exist -- stopping for the same reason as the framework."
  exit 1
fi
say "the baseline tree's SDL3 source is reused as-is, which is what the floor-11"
say "round recorded; a different SDL3 checkout would make the comparison in section"
say "2 a comparison of SDL3 versions rather than of recipes."
echo
say "deployment target of the baseline: ${tgt:-<none set>}   (this script passes it again)"
[ -n "$tgt" ] || fail "the baseline tree has no CMAKE_OSX_DEPLOYMENT_TARGET, so there is no floor to reproduce"
[ "$tgt" = 11.0 ] || say "  note: the baseline floor is $tgt, not 11.0 -- the comparison still runs, on those terms"

echo
echo "== 1. a clean tree, built from that recipe =="
echo
rm -rf "$fresh"
say "rm -rf $fresh   (this script never reuses a tree it did not just make)"
cfgline="cmake -S . -B $fresh -DCMAKE_BUILD_TYPE=$btype -DSNESRECOMP_ROOT=$fw -DCMAKE_OSX_DEPLOYMENT_TARGET=$tgt -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=$dis -DFETCHCONTENT_SOURCE_DIR_SDL3=$sdl3 -DSNESRECOMP_ENABLE_MODS=$mods"
say "$cfgline"
# The build's own output is kept in a file of its own: it is ~900 lines of cmake
# probing, and the numbers this script needs (warning and error counts, the exact
# lines a compiler emitted) are read out of THAT file rather than out of this
# script's log, where this script's own summary lines would be counted as output.
# The raw file stays beside the log so the counts can be re-derived by hand.
eval "$cfgline" >"$blog" 2>&1
rc=$?
say "configure exit=$rc"
[ "$rc" = 0 ] || fail "configure of the clean tree failed"
say "  configure output, lines:  $(wc -l <"$blog" | tr -d '[:space:]')"
say "  $(grep -m1 'Build files have been written to' "$blog" || echo '(no "Build files have been written to" line -- that configure did not finish)')"
say "cmake --build $fresh -j $nproc_"
{ cmake --build "$fresh" -j "$nproc_" >>"$blog" 2>&1; rc=$?; }
say "build exit=$rc"
[ "$rc" = 0 ] || fail "build of the clean tree failed"
say "  build output, lines:      $(wc -l <"$blog" | tr -d '[:space:]')  (with configure's, above)"
say "what that build produced:"
say "  warning lines:             $(count_warnings)"
say "  -W unguarded-availability: $(count_unguarded)"
say "  'error:' lines:            $(count_errors)"
say "  every warning line, printed rather than summarised:"
{ grep 'warning:' "$blog" | sed 's/^/      /'; } || say "      (none)"
# The log names the file the counts above were taken from, and hashes it, so the
# committed copy of that raw output can be tied to this transcript by anyone who
# wants to re-run the greps by hand.
say "  raw output the counts above were read out of: $blog"
say "  it holds $(wc -l <"$blog" | tr -d '[:space:]') lines, $(bytes "$blog") B, sha256 $(sha "$blog")"
echo
built="$fresh/ShadowrunSNESRecomp"
if [ ! -f "$built" ]; then
  fail "no executable in $fresh"
  echo "== DONE (with failures) =="
  exit 1
fi

echo
echo "== 2. the clean tree's payload against the shipped one =="
echo
base="$ship/ShadowrunSNESRecomp"
printf '  %-14s %s  %s B\n' "shipped tree" "$(sha "$base")" "$(bytes "$base")"
printf '  %-14s %s  %s B\n' "clean tree" "$(sha "$built")" "$(bytes "$built")"
say "minimum system version, read off each Mach-O:"
say "  shipped tree:  $(minos "$base")"
say "  clean tree:    $(minos "$built")"
say "dyld asks for (non-system load commands):  shipped $(nonSystem "$base")   clean $(nonSystem "$built")"
say "architectures:                             shipped $(arch_of "$base") slice(s)   clean $(arch_of "$built") slice(s)"
echo
say "the two trees' configuration, key by key, as their own caches record it:"
for k in CMAKE_BUILD_TYPE CMAKE_OSX_DEPLOYMENT_TARGET CMAKE_DISABLE_FIND_PACKAGE_SDL3 FETCHCONTENT_SOURCE_DIR_SDL3 SNESRECOMP_SDL3_FETCH SNESRECOMP_SDL3_FETCH_VERSION SNESRECOMP_ENABLE_MODS SNESRECOMP_ROOT SHADOWRUN_EMBED_ROM; do
  a="$(grep -m1 "^$k:" "$cache" | cut -d= -f2-)"
  b="$(grep -m1 "^$k:" "$fresh/CMakeCache.txt" 2>/dev/null | cut -d= -f2-)"
  if [ "$a" = "$b" ]; then
    say "  same     $k = ${a:-<absent in both>}"
  else
    say "  DIFFERS  $k: baseline '${a:-<absent>}' vs clean '${b:-<absent>}'"
  fi
done
say "only the keys this script passes are forced to agree; everything else is left"
say "at the framework's own default, so a difference here would be the framework's"
say "default changing underneath the recipe, not this script disagreeing with itself."
echo
if cmp "$built" "$base"; then
  say "cmp finds no differing byte between $built and $base"
  say "so the recipe in section 0 reaches the shipped bytes from an empty directory:"
  say "a floor that can only be reached inside a tree someone already built would be"
  say "a claim about one afternoon; this one is a property of the recipe."
else
  fail "cmp reports a difference -- see the byte offset above"
fi
echo
say "what this does NOT prove, in its own words:"
say "  * it says nothing about whether a macOS 11 machine runs the result; the floor"
say "    is a build record and tests/out/floor/macos_deployment_floor.log §5 is where"
say "    this machine's own reach is measured."
say "  * the personal variant is not rebuilt here: its payload additionally carries a"
say "    1 MiB generated array, and the framework behind it is a different clone.  Its"
say "    identity is pinned by tests/out/pkg/macos_package_personal.log instead."
say "  * $fresh is a scratch tree, left in place so the byte comparison above can be"
say "    re-run by hand; it is not a shipped artifact and nothing is committed from it."

echo
if [ "$rc_final" = 0 ]; then
  echo "== DONE (payload bytes match) =="
else
  echo "== DONE (with failures) =="
fi
exit "$rc_final"
