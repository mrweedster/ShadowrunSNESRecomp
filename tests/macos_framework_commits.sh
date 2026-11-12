#!/usr/bin/env bash
# What the framework commits that the shipped macOS packages depend on actually are.
#
#   tests/macos_framework_commits.sh
#
# The packaging round's claims about *capability* -- the guest compiled into the
# personal payload, and the writable state living outside the .app in both -- are
# claims about commits in a framework checkout that this repository does not vendor.
# Every other measurement in this kit is read from bytes this repository produced;
# for these, the bytes are in the clones, so this script brings them here as a log.
#
# Nothing is typed by hand:
#   * the pin revision comes from framework_pins.txt;
#   * the three framework directories come out of the CMakeCache.txt of the trees
#     that used them -- build-ship (the pin), build-ship-m11 (shareable package),
#     build-embed-ship-m11 (personal package) -- so the clone named is the one the
#     build actually configured against;
#   * the two capability commits are *found* by their subjects in the range
#     pin..HEAD of those clones, not hard-coded, so if the branch is rewritten the
#     script says the subject is gone instead of quoting an old hash.
#
# Sections:
#   0. the three checkouts: HEAD, dirty, whether the pin is an ancestor, and how
#      many commits past the pin;
#   1. the two capability commits: full hash, subject, per-file diffstat, and the
#      whole patch, so a code site quoted in tests/README.md can be grepped back;
#   2. the host-side symbols each capability needs, counted per checkout -- this is
#      what "the pin has no embedded-host code at all" means, as a number;
#   3. the diff between the shareable and personal frameworks, which is the
#      evidence for the pairing section 7 of the packaging transcripts leans on:
#      the state code is the same on both branches (diffed file by file, and the
#      fix's own files hashed), and the only runner/src difference is the guest;
#   4. the SDL3 release each framework checkout pins, as that checkout declares it,
#      beside what the two floor-11 build caches recorded and the project() line of
#      the source tree those caches point at -- the witness for "the framework pins
#      the SDL3 release itself"; plus the line numbers of the mechanism itself (the
#      option that turns the fetch on, the line that forces the library static, the
#      source-directory hook) and whether that file moves at all between the pin and
#      the shipped clones, which is what makes those line numbers stable, plus the
#      same release as the framework's own CI prefetch script states it.
#
# A clone that is gone is reported as absent and the script stops with 2: presenting
# a different checkout's history as the same framework would be a fabricated witness.
#
# Exit 0 = every section ran.  The log is
# tests/out/framework/framework_commits.log, committed verbatim as
# evidence/artifacts/macos_framework_commits.md.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
out="$root/tests/out/framework"
log="$out/framework_commits.log"
mkdir -p "$out"
: >"$log"
exec > >(tee -a "$log") 2>&1

say() { printf '  %s\n' "$*"; }

pin_rev="$(grep -m1 '^snesrecomp=' "$root/framework_pins.txt" | cut -d= -f2)"
cache_root() {  # SNESRECOMP_ROOT as recorded by the build that used it
  grep -m1 '^SNESRECOMP_ROOT:PATH=' "$1/CMakeCache.txt" 2>/dev/null | cut -d= -f2-
}

declare -a NAMES=() DIRS=()
for pair in "pin:build-ship" "shareable:build-ship-m11" "personal:build-embed-ship-m11"; do
  n="${pair%%:*}"; t="${pair##*:}"
  d="$(cache_root "$t")"
  NAMES+=("$n"); DIRS+=("$d")
done

echo "# what the framework commits behind the shipped macOS packages are"
echo "# when: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "# how:  tests/macos_framework_commits.sh"
echo "# source tree: $root"
echo "# framework pin: $pin_rev"
echo

echo "== 0. the three framework checkouts the shipped bytes came out of =="
echo
say "the directory is whatever SNESRECOMP_ROOT says in the CMakeCache.txt of the"
say "build tree named under it, so this is the checkout that supplied the code, not a"
say "checkout that happens to have the same history.  dirty is a line count of"
say "\`git status --porcelain\`: how many uncommitted paths the checkout holds.  0 is"
say "the condition every framework leg in this kit requires, because otherwise the"
say "bytes compiled are not the commit named."
echo
i=0
declare -a HEADS=()
for n in "${NAMES[@]}"; do
  d="${DIRS[$i]}"; i=$((i + 1))
  printf '  %-10s %s\n' "$n" "$d"
  if [ ! -d "$d" ]; then
    say "  ABSENT -- this checkout is gone, and the claims below need it. Stopping."
    exit 2
  fi
  h="$(git -C "$d" rev-parse HEAD 2>/dev/null)"
  dirty="$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d '[:space:]')"
  anc=1; git -C "$d" merge-base --is-ancestor "$pin_rev" "$h" 2>/dev/null || anc=0
  ahead="$(git -C "$d" rev-list --count "$pin_rev..$h" 2>/dev/null || echo '?')"
  HEADS+=("$h")
  say "  HEAD $h  dirty $dirty"
  if [ "$h" = "$pin_rev" ]; then
    say "  AT THE PIN (commits past it: 0)"
  elif [ "$anc" = 1 ]; then
    say "  OFF THE PIN, pin is an ancestor, commits past it: $ahead"
  else
    say "  OFF THE PIN and the pin is NOT an ancestor -- not a branch off the pin"
  fi
  echo
done
pin_head="${HEADS[0]}"; share_head="${HEADS[1]}"; embed_head="${HEADS[2]}"

echo "== 1. the two capability commits, found by subject =="
echo
say "each commit is located by grepping the subjects in pin..HEAD of the checkout that"
say "carries it, so the hash below is this round's reading of that branch rather than a"
say "number carried over from an older round.  The patch follows in full, so a code"
say "site quoted in prose can be found here by grep instead of taken on trust."
echo

find_commit() {  # <dir> <rev-range-tail> <subject substring>
  git -C "$1" log --format='%H %s' "$2" 2>/dev/null | grep -F "$3" | head -1 | cut -d' ' -f1
}

embed_c="$(find_commit "${DIRS[2]}" "$pin_rev..$embed_head" "SNESRECOMP_EMBEDDED_ROM")"
state_c="$(find_commit "${DIRS[1]}" "$pin_rev..$share_head" "keep writable state out of the .app bundle")"
for pair in "embedded guest image:$embed_c:${DIRS[2]}" \
            "state out of the bundle:$state_c:${DIRS[1]}"; do
  label="${pair%%:*}"; rest="${pair#*:}"; c="${rest%%:*}"; d="${rest##*:}"
  echo "  --- $label"
  if [ -z "$c" ]; then
    say "  NOT FOUND in $d -- the branch no longer carries that subject"
    echo
    continue
  fi
  git -C "$d" show --stat --format='%H%n%s%n%ad' --date=iso "$c" | sed 's/^/  /'
  echo
  say "  full patch:"
  git -C "$d" show --format='' "$c" | sed 's/^/  /'
  echo
done

echo "== 2. the host-side symbols each capability needs, counted per checkout =="
echo
say "absent at the pin and present at the branch head is what makes a capability a"
say "framework change rather than something this port already had.  Counts are"
say "lines matching in the file named, per checkout, from the same clones as section 0."
say "Not every symbol listed is new: what matters is the 0 at the pin.  A nonzero"
say "count there would mean the hook already existed and the commit only reached for it,"
say "which is a different claim, so the table shows both kinds rather than a curated one."
echo
for f in runner/src/desktop/host_main.c runner/src/host_paths.c; do
  say "file: $f"
  for sym in g_rom_embedded HostEmbeddedRomReady snesrecomp_embedded_rom embedded: \
             "Application Support" snesrecomp_state_dir_path snesrecomp_anchor_to_exe_dir; do
    line="$(printf '    %-28s' "$sym")"
    i=0
    for n in "${NAMES[@]}"; do
      c="$(grep -c -F -- "$sym" "${DIRS[$i]}/$f" 2>/dev/null || true)"
      line="$line  ${n}=${c:-0}"
      i=$((i + 1))
    done
    say "$line"
  done
  echo
done
say "the comment in the personal checkout that says the embedded image is re-hashed by"
say "the same check as a file ROM, quoted with its line number so the prose can cite it:"
grep -n 'same one, not a weaker one' "${DIRS[2]}/runner/src/desktop/host_main.c" 2>/dev/null | sed 's/^/    /' || say "    not found"
echo

echo "== 3. shareable framework versus personal framework =="
echo
say "both carry the writable-state fix; only one carries the embedded guest.  That is"
say "what lets the packaging transcripts compare a payload that reads a ROM file with"
say "one whose guest came out of its own executable and attribute the difference to the"
say "guest alone.  The diff below is the whole of what separates the two trees."
echo
say "commits in personal that are not in shareable:"
git -C "${DIRS[2]}" log --oneline --format='    %h %s' "$share_head..$embed_head" 2>/dev/null \
  || say "    (the two heads are not on branches that can be ranged)"
say "the state fix as each branch carries it.  Same subject, different hash, because"
say "the personal branch has it as a cherry-pick; so the comparison to make is of"
say "content, and what follows is that comparison in both directions -- the fix's own"
say "files across the two branches, then the whole tree."
say "  shareable: $(git -C "${DIRS[1]}" show -s --format='%h %s' "$share_head" 2>/dev/null)"
say "  personal:  $(git -C "${DIRS[2]}" show -s --format='%h %s' "$embed_head" 2>/dev/null)"
say "same content check -- diffing the two state-fix commits against each other:"
if [ -n "$state_c" ]; then
  state_p="$(find_commit "${DIRS[2]}" "$pin_rev..$embed_head" "keep writable state out of the .app bundle")"
  say "  personal's copy of the state fix: $(git -C "${DIRS[2]}" show -s --format='%h %s' "$state_p" 2>/dev/null)"
  say "  the files that fix touches, other than the one the embedded guest also edits,"
  say "  diffed across the two branches:"
  git -C "${DIRS[2]}" diff --stat "$state_c" "$state_p" -- runner/src/host_paths.c \
      runner/src/host_paths.h runner/src/keybinds.c runner/src/launcher_cache.c | sed 's/^/  /'
  say "  empty output above means those files are identical on both branches, so the"
  say "  two frameworks do carry the same state code."
  say "  host_main.c does differ across those two commits, and that diff is the guest:"
  git -C "${DIRS[2]}" diff --stat "$state_c" "$state_p" -- runner/src/desktop/host_main.c | sed 's/^/    /'
  say "  host_paths.c as each branch has it, hashed rather than eyeballed:"
  for pair2 in "shareable:${DIRS[1]}" "personal:${DIRS[2]}"; do
    lbl="${pair2%%:*}"; dd="${pair2##*:}"
    sc="$(find_commit "$dd" "$pin_rev..HEAD" "keep writable state out of the .app bundle")"
    for f in runner/src/host_paths.c runner/src/keybinds.c; do
      say "    ${lbl} $(git -C "$dd" show "$sc:$f" 2>/dev/null | shasum -a 256 | cut -c1-16)  $f"
    done
  done
fi
say "the whole of what separates the two trees, with no path limit:"
git -C "${DIRS[2]}" diff --stat "$share_head" "$embed_head" | sed 's/^/    /' || say "    (no common history to diff)"
say "the runner/src part of that diff, which is the only part the payload can contain:"
git -C "${DIRS[2]}" diff --stat "$share_head" "$embed_head" -- runner/src | sed 's/^/    /' || say "    (no common history to diff)"
say "so the two frameworks this round built from differ by one host file: the guest."
say "That is the witness for the packaging transcripts pairing a payload that reads a"
say "ROM file with one whose guest came out of its own .text, and for the state fix"
say "being common to both."
echo

echo "== 4. the SDL3 release each framework checkout pins, and what the floor-11 caches recorded =="
echo
say "the packaging round builds SDL3 from source at a macOS 11 floor, so the exact"
say "SDL3 release matters to the shipped bytes.  A framework that pins a release"
say "declares it, so the numbers below are grep output from the same checkouts section"
say "0 named, and the cache lines are grep output from the same build trees section 0"
say "named.  Two statements of the same digest in two kinds of file is the point: a"
say "checkout that disagreed with the build would show up here as a mismatch."
echo
say "as each framework checkout declares it (runner/runner.cmake, -A1 so the digest"
say "on the continuation line is shown, line numbers kept):"
i=0
for n in "${NAMES[@]}"; do
  say "  $n  ${DIRS[$i]}"
  grep -nE -A1 'SNESRECOMP_SDL3_FETCH_VERSION "|SNESRECOMP_SDL3_FETCH_SHA256$' \
      "${DIRS[$i]}/runner/runner.cmake" 2>/dev/null | sed 's/^/      /' \
    || say "      runner/runner.cmake not readable in this checkout"
  i=$((i + 1))
done
echo

say "the same file's mechanism, grep -n, so a claim about where the fetch option is"
say "declared, where the library is forced static, or where a caller may hand the"
say "framework a source tree is a line number in this record and not a guess:"
i=0
for n in "${NAMES[@]}"; do
  say "  $n  ${DIRS[$i]}"
  grep -nE -A1 'option\(SNESRECOMP_SDL3_FETCH$|set\(SDL_SHARED OFF|set\(SDL_STATIC ON|SNESRECOMP_SDL3_SOURCE_DIR|FetchContent_Declare\(SDL3|URL_HASH' \
      "${DIRS[$i]}/runner/runner.cmake" 2>/dev/null | sed 's/^/      /' \
    || say "      runner/runner.cmake not readable in this checkout"
  i=$((i + 1))
done
echo

say "the framework states the same release in its own CI prefetch script, which is"
say "what the packaging round's -DFETCHCONTENT_SOURCE_DIR_SDL3 mirrors:"
i=0
for n in "${NAMES[@]}"; do
  say "  $n  tools/ci/prefetch_sdl3.sh"
  grep -nE '^(VERSION|SHA256)=|releases/download' \
      "${DIRS[$i]}/tools/ci/prefetch_sdl3.sh" 2>/dev/null | sed 's/^/      /' \
    || say "      tools/ci/prefetch_sdl3.sh not readable in this checkout"
  i=$((i + 1))
done
echo

say "and whether that file moves between the pin and the two shipped clones at all:"
say "if it does not, the line numbers above are also the line numbers the shipped"
say "builds were configured from, and tests/README.md may cite them."
i=0
for n in "${NAMES[@]}"; do
  if [ "$n" = "pin" ]; then
    say "  $n  at the pin, so nothing to diff"
    i=$((i + 1))
    continue
  fi
  say "  $n  git diff --stat $pin_rev..HEAD -- runner/runner.cmake"
  d="$(git -C "${DIRS[$i]}" diff --stat "${pin_rev}..HEAD" -- runner/runner.cmake 2>/dev/null)"
  if [ -z "$d" ]; then
    say "      runner/runner.cmake unchanged between the pin and this HEAD"
  else
    printf '%s\n' "$d" | sed 's/^/      /'
  fi
  i=$((i + 1))
done
echo
say "as each floor-11 build cache recorded it, plus the source directory that cache"
say "names and that directory's own project() line:"
for t in build-ship-m11 build-embed-ship-m11; do
  say "  $t"
  grep -E '^(SNESRECOMP_SDL3_FETCH|SNESRECOMP_SDL3_FETCH_VERSION|SNESRECOMP_SDL3_FETCH_SHA256|SDL3_SOURCE_DIR):' \
      "$root/$t/CMakeCache.txt" 2>/dev/null | sed 's/^/      /' || say "      no cache"
  src="$(grep -m1 '^SDL3_SOURCE_DIR:STATIC=' "$root/$t/CMakeCache.txt" 2>/dev/null | cut -d= -f2-)"
  if [ -n "$src" ] && [ -f "$src/CMakeLists.txt" ]; then
    say "      $src/CMakeLists.txt:  $(grep -m1 'project(SDL3' "$src/CMakeLists.txt")"
  else
    say "      the source directory that cache names is not readable"
  fi
done
echo

echo "== DONE  (log: $log)"
