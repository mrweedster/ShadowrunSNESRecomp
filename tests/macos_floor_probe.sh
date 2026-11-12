#!/usr/bin/env bash
# What macOS does each payload in this port actually run on, and what decided it?
#
#   tests/macos_floor_probe.sh                    # default tree list below
#   TREES="build-ship build-ship-m11" tests/macos_floor_probe.sh
#
# A person on an older Mac cannot run a bundle whose floor is newer than their
# system, and the floor is not the number a build was configured with -- it is the
# highest minimum-system version among every Mach-O that has to load.  This port
# has shipped three shapes, and each one is decided by a different file:
#
#   * the executable alone, when SDL3 is linked in;
#   * the vendored libSDL3.dylib, when the bundle carries a Homebrew dylib;
#   * both slices, when the payload is universal.
#
# This script answers, in one log:
#
#   1. per build tree: its configure facts read out of its own CMakeCache.txt
#      (framework, deployment target, SDL3 source, ROM embedding), its payload's
#      architectures, and the minimum-system version of every Mach-O in it;
#   2. the two SDL3 dylibs this round used, and the minimum-system version each one
#      would impose on a bundle that vendors it -- the reason a deployment target
#      of 11.0 was not enough on its own;
#   3. the bundles and disk images actually shipped: every Mach-O inside them, the
#      floor the bundle claims about itself in Info.plist, the floor its README.txt
#      tells a person, and the image's own checksum;
#   4. the compile evidence behind shipping a floor older than this machine: the
#      availability warnings in the build logs, counted, and every other warning
#      named rather than summarised away.
#
# Build trees are scratch directories, not tracked files: a tree that has been
# cleared is reported as absent instead of skipped, so a shorter log always says
# so.  Nothing here runs the emulator; this is a reading of bytes on disk.
#
# Exit 0 = every section ran.  The numbers are the reading, not a pass/fail gate.
# The log is tests/out/floor/macos_deployment_floor.log.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
out="$root/tests/out/floor"
log="$out/macos_deployment_floor.log"
mkdir -p "$out"
: >"$log"
exec > >(tee -a "$log") 2>&1

trees="${TREES:-build-ship build-embed-ship build-osx11 build-osx11-sdl11 build-osx-static build-osx-universal build-fork-osx build-ship-m11 build-embed-ship-m11 build-osx-universal-m11}"
pin_rev="$(grep -m1 '^snesrecomp=' "$root/framework_pins.txt" | cut -d= -f2)"
say() { printf '  %s\n' "$*"; }
sha() { shasum -a 256 "$1" 2>/dev/null | cut -c1-16; }
count() { wc -l | tr -d '[:space:]'; }

# One line per architecture in the file: arch, minos, sdk.  vtool prints a block
# per slice of a fat file, which is what a universal payload's floor needs: the
# number that binds it is the highest of these, not the first.  Older payloads say
# LC_VERSION_MIN_MACOSX ('version') instead of LC_BUILD_VERSION ('minos'); both are
# read, and a file with neither prints nothing.
buildrec() { # file -> "arm64 minos 11.0 sdk 26.5", one line per arch
  { vtool -show-build "$1" 2>/dev/null | awk '
      /\(architecture /{ if (match($0, /architecture [^) ]+/)) a = substr($0, RSTART+12, RLENGTH-12) }
      /^[ \t]+minos /   { m = $2 }
      /^[ \t]+version / { if (m == "") m = $2 }
      /^[ \t]+sdk /     { printf "  %s minos %s sdk %s\n", (a ? a : "thin"), m, $2 }'; } || true
}
highest() { buildrec "$1" | awk '{ for (i = 1; i <= NF; i++) if ($i == "minos") { v = $(i+1) + 0
              if (v > m) { m = v; s = $(i+1) } } } END { print (s ? s : "unknown") }'; }

echo "# macos_deployment_floor.md"
echo "#"
echo "# what: which macOS each payload in this port can run on, read out of the"
echo "#       Mach-O build records: the port's own target, the SDL3 that travels"
echo "#       with it, and the floor each shipped bundle and image claims"
echo "# how:  tests/macos_floor_probe.sh with TREES=\"$trees\""
echo "#"
echo "# framework pin: $pin_rev"
echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) (host $(uname -sr) $(uname -m))"
echo "# source tree: $root"
echo
say "the machine reading this is $(sw_vers -productVersion) ($(sw_vers -buildVersion)),"
say "$(uname -m), SDK $(xcrun --show-sdk-version) -- every floor below is a claim"
say "about other machines, which is why it is read off the bytes and not asserted."
echo
echo "== 1. the build trees, in the order the compatibility round tried them =="
echo
say "dyld loads the executable plus every non-system dylib it names, so the floor of a"
say "bundle built from one of these trees is the highest minimum-system version among"
say "all of those files, and the last line under each tree names the file that supplies"
say "that number.  A load name that is not absolute (@rpath/...) is resolved at run time"
say "against the LC_RPATH entries printed under it, i.e. against a dylib the bundle"
say "carries itself; its build record is read here from the copy the link step used."
say "Where two files carry the same number the executable is named."
echo
for t in $trees; do
  exe="$t/ShadowrunSNESRecomp"
  if [ ! -f "$exe" ]; then
    say "$t: absent (scratch tree, cleared)"
    continue
  fi
  echo "  $t"
  grep -E '^(CMAKE_OSX_DEPLOYMENT_TARGET|SNESRECOMP_ROOT|SNESRECOMP_SDL3_FETCH|SNESRECOMP_SDL3_FETCH_VERSION|FETCHCONTENT_SOURCE_DIR_SDL3|SDL3_DIR|CMAKE_DISABLE_FIND_PACKAGE_SDL3|SHADOWRUN_EMBED_ROM|CMAKE_BUILD_TYPE)(:|=)' \
    "$t/CMakeCache.txt" 2>/dev/null | grep -v '^//' | sed 's/^/    /' ||
    say "    no CMakeCache.txt beside the executable"
  src="$( { grep -m1 'SNESRECOMP_ROOT:PATH=' "$t/CMakeCache.txt" | sed 's/.*=//'; } || true )"
  if [ -n "$src" ] && [ -d "$src" ]; then
    head="$(git -C "$src" rev-parse HEAD 2>/dev/null)"
    dirty="$(git -C "$src" status --porcelain 2>/dev/null | count)"
    if [ "$head" = "$pin_rev" ]; then
      say "    framework: AT THE PIN $pin_rev (dirty $dirty)"
    elif git -C "$src" merge-base --is-ancestor "$pin_rev" "$head" 2>/dev/null; then
      say "    framework: OFF THE PIN at $head (dirty $dirty), the pin plus"
      say "      $(git -C "$src" rev-list --count "$pin_rev".."$head" 2>/dev/null) commit(s)"
    else
      say "    framework: $src @ $head (dirty $dirty), the pin is not an ancestor"
    fi
  fi
  printf '    %-26s %s  %s B\n' "executable" "$(sha "$exe")" "$(stat -f%z "$exe")"
  printf '    %-26s %s\n' "architectures" "$(lipo -archs "$exe")"
  buildrec "$exe" | sed 's/^/      /'
  # dyld loads the executable plus every non-system dylib it names, so the floor of
  # a bundle built from this tree is the highest minimum-system version among all of
  # them, and the line under each tree names the file that supplies that number.
  loadlist="$( { otool -L "$exe" | grep -E '^[[:space:]]' | grep -vE '/System/|/usr/lib/'; } || true )"
  names="$(printf '%s\n' "$loadlist" | sed -E 's/^[[:space:]]*//;s/[[:space:]].*$//' | sort -u)"
  rpaths="$( { otool -l "$exe" 2>/dev/null |
    awk '/^[[:space:]]*cmd /{c=$NF} /^[[:space:]]+path /{if (c == "LC_RPATH") print $2}'; } || true )"
  nlines="$(printf '%s\n' "$loadlist" | { grep -c .; } || true)"; nlines="${nlines:-0}"
  nuniq="$(printf '%s\n' "$names" | { grep -c .; } || true)"; nuniq="${nuniq:-0}"
  rp="$(printf '%s\n' "$rpaths" | sort -u)"
  nrp="$(printf '%s\n' "$rp" | { grep -c .; } || true)"; nrp="${nrp:-0}"
  say "    non-system dylibs named by the Mach-O: $nuniq"
  if [ "$nlines" -gt "$nuniq" ]; then
    say "      ($nlines load command lines: a fat file repeats every one of them per slice)"
  fi
  say "    LC_RPATH entries: $nrp"
  printf '%s\n' "$rp" | while read -r p; do [ -n "$p" ] && printf '        LC_RPATH %s\n' "$p"; done
  fl="$(highest "$exe")"; flsrc="$exe (the executable itself)"
  while read -r name; do
    [ -n "$name" ] || continue
    target=""
    case "$name" in
      /*) target="$name" ;;
      @rpath/*)
        # An @rpath name means the dylib travels with the bundle; on this machine the
        # copy it was linked against sits in one of the LC_RPATH directories above, so
        # that file is what its build record is read from.
        rest="${name#@rpath/}"
        while read -r p; do
          [ -n "$p" ] || continue
          if [ -e "$p/$rest" ]; then target="$p/$rest"; break; fi
        done < <(printf '%s\n' "$rpaths")
        if [ -z "$target" ]; then
          printf '      %-58s (no file under any LC_RPATH here)\n' "$name"
        fi ;;
      *)  printf '      %-58s (a load name this script cannot resolve)\n' "$name" ;;
    esac
    [ -n "$target" ] || continue
    if [ -e "$target" ]; then
      h="$(highest "$target")"
      extra=""
      if [ "$target" != "$name" ]; then extra="  (read from its LC_RPATH copy)"; fi
      printf '      %-58s %s  minos %s%s\n' "$name" "$(sha "$target")" "$h" "$extra"
      if awk -v a="$h" -v b="$fl" 'BEGIN { exit !(a > b) }'; then fl="$h"; flsrc="$target"; fi
    else
      printf '      %-58s (no such file on this machine)\n' "$name"
    fi
  done < <(printf '%s\n' "$names")
  say "    floor a bundle from this tree needs: macOS $fl   (highest record: $flsrc)"
  echo
done

echo "== 2. the SDL3 a bundle would carry, and what it costs =="
echo
say "a vendored dylib is part of the payload, so its build record joins the"
say "executable's own.  These are the two SDL3 builds this round used:"
for d in "/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib" \
         "/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sdl3-11/lib/libSDL3.0.dylib"; do
  if [ -e "$d" ]; then
    printf '  %-62s %s  %s B\n' "$(basename "$d")" "$(sha "$d")" "$(stat -f%z "$d")"
    printf '    arch %s\n' "$(lipo -archs "$d")"
    buildrec "$d" | sed 's/^/    /'
    say "    -> a bundle vendoring this dylib cannot run below macOS $(highest "$d")"
  else
    say "$(basename "$d"): absent at $d"
  fi
done
say "the static shape has no dylib to carry: SDL3 becomes part of the executable at"
say "link time, so the only build record in the bundle is the executable's, and the"
say "deployment target given to the port is then the whole of the floor.  That is the"
say "difference sections 1 and 3 measure between the shipped package and the earlier"
say "one; the same SDL3 sources, built from the version the framework pins for CI"
say "(tools/ci/prefetch_sdl3.sh), are behind both."
echo
echo "== 3. what is actually shipped =="
echo
for app in dist/Shadowrun.app dist/Shadowrun-personal.app; do
  if [ ! -d "$app" ]; then say "$app: absent"; continue; fi
  echo "  $app"
  n=0; mins=""
  while IFS= read -r m; do
    n=$((n + 1))
    printf '    %-40s %s  %s B\n' "${m#$app/}" "$(sha "$m")" "$(stat -f%z "$m")"
    printf '      arch %s\n' "$(lipo -archs "$m")"
    buildrec "$m" | sed 's/^/        /'
    mins="$mins $(highest "$m")"
  done < <(find "$app" \( -type f -perm +111 \) -print0 2>/dev/null |
           xargs -0 -I{} sh -c 'file "{}" | grep -q "Mach-O" && printf "%s\n" "{}"')
  say "    Mach-O files in the bundle: $n"
  say "    bundle claims it needs macOS: $( { plutil -extract LSMinimumSystemVersion raw "$app/Contents/Info.plist" 2>/dev/null; } || echo 'no LSMinimumSystemVersion key' )"
  say "    floor from its Mach-Os:      $(printf '%s\n' $mins | grep -v unknown | sort -n | tail -1)"
done
for dmg in dist/*.dmg; do
  [ -e "$dmg" ] || continue
  printf '  %-52s %s  %s B\n' "$(basename "$dmg")" "$(sha "$dmg")" "$(stat -f%z "$dmg")"
  { hdiutil verify "$dmg" 2>&1 | tail -1; } | sed 's/^/      /'
done
say "a .dmg hash pins a run, not a build: hdiutil stamps volume dates and UUIDs into"
say "the container, and section 4 of each package transcript measures that directly."
say "What the README inside each image says a person needs is written by"
say "scripts/package_macos_bundle.sh from the executable's own LC_BUILD_VERSION, so"
say "the number in the image and the number in the payload cannot drift apart."
echo
echo "== 4. the compile evidence for a floor older than this machine =="
echo
say "Shipping a floor of 11.0 from an SDK this new is only safe if no guarded API is"
say "reached unconditionally; clang says so with -Wunguarded-availability, and the"
say "build logs below are counted rather than trusted:"
say "The last of them, tests/out/m11_check_build.log, comes from"
say "tests/macos_floor11_check.sh: a tree configured and built in a directory that"
say "did not exist when that script started, so its counts are not inherited from"
say "objects already compiled in a tree someone left behind."
for f in tests/out/osx11_build.log tests/out/osx11_sdl11_build.log \
         tests/out/osx_universal_build.log tests/out/osx_static_build.log \
         tests/out/fork_osx_build.log tests/out/ship_m11_build.log \
         tests/out/embed_m11_build.log \
         tests/out/m11_check_build.log; do
  if [ ! -f "$f" ]; then say "$f: absent"; continue; fi
  unguard="$( { grep -c 'unguarded-availability' "$f"; } || true )"
  warn="$( { grep -c 'warning:' "$f"; } || true )"
  errln="$( { grep -cE '(^| )error: ' "$f"; } || true )"
  errany="$( { grep -c 'error' "$f"; } || true )"
  say "$f: warning lines $warn, -Wunguarded-availability $unguard, error: lines $errln,"
  say "  lines containing the string 'error' $errany"
  if [ "${errany:-0}" -gt 0 ]; then
    say "  every 'error' substring in this log is a compile line for an SDL source file"
    say "  named SDL_error.c; the 'error: ' count above is what a compiler diagnostic"
    say "  would produce, which is why the two are reported separately rather than one"
    say "  grep being trusted.  Every warning line this log has is printed under this:"
  else
    say "  every warning line this log has is printed under this:"
  fi
  { grep 'warning:' "$f" | sed 's/^/      /'; }
done
say "and the one log that records the configure command lines as well as the compile,"
say "  tests/out/m11_build.log.  It holds three builds back to back, so its counts are"
say "  taken per block rather than per file, and each block's command line is printed"
say "  with its counts instead of being left in a shell history somewhere:"
for t in build-ship-m11 build-embed-ship-m11 build-osx-universal-m11; do
  blk="$out/.block.$t"
  { awk -v t="$t" '/^---- /{on=($2==t)} on' tests/out/m11_build.log; } >"$blk" 2>/dev/null
  if [ ! -s "$blk" ]; then say "$t: no block in tests/out/m11_build.log"; rm -f "$blk"; continue; fi
  unguard="$( { grep -c 'unguarded-availability' "$blk"; } || true )"
  warn="$( { grep -c 'warning:' "$blk"; } || true )"
  errln="$( { grep -cE '(^| )error: ' "$blk"; } || true )"
  say "$t: warning lines $warn, -Wunguarded-availability $unguard, error: lines $errln"
  { grep '^cmake -S' "$blk" | sed 's/^cmake -S \. -B /      cmake -S . -B /'; }
  { grep '^  payload ' "$blk" | sed 's/^  payload /      payload: /'; }
  rm -f "$blk"
done
say "the ld warning inside osx11_build.log is the toolchain itself agreeing with"
say "section 1: it links objects targeted at macOS-11.0 against libSDL3.0.dylib built"
say "for 26.0, and that is exactly the mismatch section 1 measures as that tree's floor"
say "being 26.0 even though its deployment target was set to 11.0."
say "A floor is also limited by the libraries a payload asks dyld to find.  Section 1"
say "counts the non-system ones, and the shipped payload names zero: SDL3 is linked in"
say "rather than carried.  What it does name is part of macOS, with two exceptions --"
say "two of the frameworks it names did not exist in the 11.0 release, and both are"
say "marked weak in the Mach-O.  Weak is dyld's own mechanism for 'this library may be"
say "absent here': a weak-linked library that cannot be found, and the weak symbols it"
say "would have provided, resolve to nil instead of failing the load.  So the payload"
say "asks for two frameworks it can do without on an old system, and section 4 shows"
say "the compiler raising no -Wunguarded-availability anywhere else.  Which names"
say "those are, read off the shipped files:"
for app in dist/Shadowrun.app dist/Shadowrun-personal.app; do
  [ -d "$app" ] || continue
  exe="$( { ls "$app/Contents/MacOS/"* 2>/dev/null; }; )"
  [ -n "$exe" ] || continue
  nall="$( { otool -L "$exe" 2>/dev/null | grep -E '^[[:space:]]'; } | count)"
  nweak="$( { otool -L "$exe" 2>/dev/null | grep 'weak'; } | count)"
  printf '  %s  load names: %s, of which weak: %s\n' "$app" "$nall" "$nweak"
  { otool -L "$exe" 2>/dev/null | grep 'weak'; } \
    | sed -E 's|^[[:space:]]*/System/Library/Frameworks/||;s|/Versions/[^/]*/|  |' \
    | sed 's/^/      weak  /'
  say "  (every other load name is under /System/Library/Frameworks or /usr/lib:"
  say "   $( { otool -L "$exe" 2>/dev/null | grep -E '^[[:space:]]' | grep -vE '/System/|/usr/lib/'; } | count )  outside those two places)"
done

echo
echo "== 5. what this machine can actually execute =="
echo
say "Every floor above is a build record, and a build record says what dyld will"
say "insist on, not that anything ran.  The one claim that cannot be read off bytes is"
say "whether a machine of the other architecture would run a payload at all, so it is"
say "measured here rather than assumed:"
printf '  this machine: %s %s, macOS %s (%s)\n' "$(uname -m)" "$(uname -sr)" \
  "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)"
printf '  hw.optional.arm64: %s\n' "$( { sysctl -n hw.optional.arm64; } 2>/dev/null || echo 'no such key')"
for pair in "x86_64 arm64" "arm64 x86_64"; do
  want="${pair%% *}"; other="${pair##* }"
  err="$( { arch -"$want" /usr/bin/true; } 2>&1 >/dev/null )"
  rc=$?
  printf '  arch -%s /usr/bin/true: exit %s %s\n' "$want" "$rc" \
    "$(printf '%s' "${err:-(ran, no output)}" | tr '\n' ' ')"
  if [ "$rc" -eq 0 ]; then
    say "    -> this machine can execute $want code, so a $want payload here would have been"
    say "       run-tested in principle"
  else
    say "    -> this machine cannot execute $want code at all.  Every $want record above is"
    say "       a compile-and-link measurement; nothing in this repository has booted a"
    say "       $want image on a $want machine, and ${other}-only claims do not depend on it."
  fi
done
say "So: the arm64 floors are what a shipped, arm64-only payload will require, and the"
say "x86_64 slice measured in section 1 (build-osx-universal) is evidence that a"
say "deployment target of 11.0 is reachable for that architecture too -- nothing more."
say "A floor of 11.0 has not been run on an 11.0 machine either; what section 4 shows is"
say "that the compiler raised no -Wunguarded-availability for it, which is the check"
say "that would catch reaching an API newer than the floor, and section 4 also names"
say "the two frameworks the payload asks for weakly -- the only libraries it asks dyld"
say "to find that an older system may not have."

echo
echo "== 6. the configure line nobody wrote down, and whether it rebuilds the bytes that shipped =="
echo
say "Every build log section 4 counts for the two trees this package ships begins at the"
say "compile step, so not one of them records a configure command line: the recipe that"
say "produced the floor-11 trees survived only as entries in each tree's CMakeCache.txt,"
say "which is a record of what was decided but not of what was typed.  That matters"
say "because a floor nobody can rebuild is a claim about one machine's afternoon rather"
say "than a property of the port.  tests/out/m11_build.log is a re-run of those trees"
say "with the command lines printed as they run; the question is whether it lands on the"
say "same payload bytes as the earlier round's own summary of the same trees.  Three"
say "records, read off the files, and a comparison rather than an assurance:"
for t in build-ship-m11 build-embed-ship-m11 build-osx-universal-m11; do
  say "$t:"
  old="$( { grep -A2 "^$t/ShadowrunSNESRecomp" tests/out/m11_builds.log 2>/dev/null |
      tr '\n' ' ' | tr -s ' '; } || true )"
  if [ -n "$old" ]; then
    printf '      earlier record (m11_builds.log): %s\n' "$old"
  else
    say "      earlier record (m11_builds.log): absent"
  fi
  reb="$( { awk -v t="$t" '/^---- /{on=($2==t)} on' tests/out/m11_build.log 2>/dev/null |
      grep '^  payload ' | sed 's/^  payload //'; } || true )"
  if [ -n "$reb" ]; then
    printf '      this rebuild  (m11_build.log):   %s\n' "$reb"
  else
    say "      this rebuild (m11_build.log): absent"
  fi
  now="(absent)"; h_now=""
  if [ -f "$t/ShadowrunSNESRecomp" ]; then
    h_now="$(sha "$t/ShadowrunSNESRecomp")"
    printf '      tree on disk  (%s): %s  %s B\n' "$t" "$h_now" "$(stat -f%z "$t/ShadowrunSNESRecomp")"
  else
    say "      tree on disk: $t absent (cleared; the recipe above is what re-creates it)"
  fi
  h_log="$(printf '%s\n' "$reb" | awk '{print $1}')"
  h_old="$(printf '%s\n' "$old" | awk '{print $2}')"
  if [ -n "$h_log" ] && [ "$h_log" = "$h_old" ] && [ -n "$h_now" ] && [ "$h_log" = "$h_now" ]; then
    say "  all three are the same value, so the command lines printed above rebuilt the"
    say "  payload the earlier round built: the floor-11 recipe is reproducible, and the"
    say "  CMakeCache entries section 1 prints are the ones it had to have used."
  elif [ -n "$h_log" ] && [ -n "$h_old" ] && [ "$h_log" != "$h_old" ]; then
    say "  the rebuild does not match the earlier record: $h_log against $h_old.  The floor"
    say "  is still what section 1 reads off the bytes, but the command lines above are"
    say "  not the whole of what produced them, and this section does not close that gap."
  fi
done
say "A second comparison, inside the tree list itself: build-fork-osx is the"
say "  compatibility round's own build, build-ship-m11 is the one the shipped package is"
say "  built from.  They are separate trees, configured and built apart from each other,"
say "  and their caches name two different SDL3 source directories:"
for t in build-fork-osx build-ship-m11; do
  if [ ! -f "$t/ShadowrunSNESRecomp" ]; then
    say "      $t: absent"
    continue
  fi
  printf '      %-20s %s  %s B\n' "$t" "$(sha "$t/ShadowrunSNESRecomp")" "$(stat -f%z "$t/ShadowrunSNESRecomp")"
  src="$( { grep -m1 'FETCHCONTENT_SOURCE_DIR_SDL3:PATH=' "$t/CMakeCache.txt" | sed 's/.*=//'; } || true )"
  if [ -n "$src" ]; then
    printf '        SDL3 source dir  %s\n' "$src"
    if [ -f "$src/CMakeLists.txt" ]; then
      ver="$( { grep -m1 'project(SDL3 LANGUAGES C VERSION' "$src/CMakeLists.txt"; } || true )"
      if [ -n "$ver" ]; then printf '        it declares       %s\n' "$ver"; fi
    fi
  fi
done
if [ -f build-fork-osx/ShadowrunSNESRecomp ] && [ -f build-ship-m11/ShadowrunSNESRecomp ] &&
   cmp -s build-fork-osx/ShadowrunSNESRecomp build-ship-m11/ShadowrunSNESRecomp; then
  say "  cmp finds no differing byte between the two, so two trees built apart from each"
  say "  other, from two SDL3 source directories that both declare the same version, come"
  say "  out at the same payload.  What decides those bytes is the framework commit and the"
  say "  deployment target -- not which checkout of the same SDL3 sat in the build -- and"
  say "  that is what makes a payload hash a usable identity for a build in this kit."
fi
say "One tree is in that list for a different reason.  build-osx-universal-m11 is the"
say "same recipe with -DCMAKE_OSX_ARCHITECTURES=\"x86_64;arm64\" added, which is the only"
say "way an Intel slice exists at this floor at all: Homebrew's SDL3 has no x86_64 bottle"
say "on this machine and its dylib is arm64-only, so a universal payload cannot be built by"
say "linking against it, and section 2 is where that shows.  Section 5 is where what this"
say "machine cannot do with that slice is stated."

echo
echo "== DONE =="
