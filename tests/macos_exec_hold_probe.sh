#!/usr/bin/env bash
# What it means when macOS holds an app's exec open instead of refusing it.
#
#   tests/macos_exec_hold_probe.sh
#
# A pass of tests/macos_user_open_probe.sh printed, for leg after leg, that no process of
# the bundle had appeared at all -- while the process table showed two processes of it
# alive on the machine, held at exec, minutes after the legs that had denied them.  Every
# one of those legs was measuring that condition rather than the app, and the reason was
# that an earlier leg had stopped a process macOS was still deciding about.  This script
# makes that condition on purpose, in a directory of its own, and measures five things
# about it, because the open-path probe's design rests on all five:
#
#   1. what a held exec looks like, in the system's own tools rather than in this
#      script's words: the process is alive, uses no CPU, prints nothing, maps nothing
#      but its own Mach-O and /usr/lib/dyld, and macOS's own sampler names dyld's entry
#      point as its main thread's whole call graph -- which is not the shape of a
#      *refused* launch, because a refusal ends the process.  The mapping count by itself
#      cannot make that call: tests/macos_user_open_probe.sh measured a copy started by a
#      click and told to read a file under ~/Documents with the same two mapped files and
#      a completely different call graph, so 'held' here always means the sampler named
#      dyld's entry point;
#   2. how long it lasts: watched rather than assumed;
#   3. whether it follows the code: the same code -- identical cdhash -- is run at a bare
#      path, at a second copy of the bundle, and inside the mounted image, while the
#      payload inside the image itself is called out as the same code or a different one;
#   4. how wide the held place is: a second file name inside the same bundle, whether
#      renaming the directory that holds the bundle moves the hold with it, and whether a
#      copy of that held bundle at a path of its own is held -- asked twice, with the
#      download flag it was copied with and with that flag taken off, because a copy that
#      still carries the flag is a fresh Gatekeeper question rather than a control on the
#      bytes;
#   5. what clears it: everything a user-level process may do that looked plausible --
#      spctl's assessment, clearing every xattr, re-registering the bundle with
#      LaunchServices, sending SIGKILL to this user's UI agent (the pid before and after
#      is printed, because an earlier attempt here used the default SIGTERM and the agent
#      was simply still there, which measured nothing) -- and then the rename, asked away
#      from a hold made for it, so that its answer cannot be credited to one of the four
#      or taken from one that already cleared the first path.  An earlier pass of this
#      script did the rename on the same path the SIGKILL had just cleared and so read a
#      clear path as a remedy; that is why the rename has its own hold here.
#
# Nothing here is a claim that the payload is broken: whether anything this section tries
# makes a held path able to run again is printed rather than assumed, and that is the point
# of section 5.  And nothing here touches a person's
# machine state: every start is given a private $HOME and dummy drivers, so no window and
# no audio device opens, and the real ~/Library/Application Support/ and
# ~/Library/Logs/DiagnosticReports are fingerprinted before and after rather than
# trusted.  The condition is created inside a directory of this run's own, and the copy
# the rename is measured on is removed at the end of section 5, so however that answer
# falls this pass does not leave a held bundle standing on the machine it ran on.
#
# Making the condition reliably is the hard part, and section 2 measures both sides of it.
# An earlier pass of this script made it with the shipped copy and then could not make it
# again: the cdhash the shipped bundle carries is one this machine has already been shown
# many times by this repository's earlier rounds, and syspolicyd's own lines for a code it
# has already decided on do not include the prompt.  So section 2 clicks twice, and the two
# clicks differ in exactly one thing -- whose code macOS is being asked about:
#
#   a. the copy taken out of the image, byte for byte what shipped, whose cdhash section 1
#      just ran at that very path;
#   b. a copy of those same bytes re-signed ad hoc under a new bundle identifier, so its
#      cdhash is one this machine has never been asked about -- which is the position a
#      person is in the first time they open one of these images.
#
# Exit 0 = the sections agree with each other: the payload ran before the condition was
# made, the condition had the shape described above if it was made at all, the same
# cdhash ran at every other path, the hold the rename is measured on did form and the
# rename's two answers agreed with each other whichever way they fell, and this machine's
# own state, crash reports and process table are as they were.  A run in which the
# condition did not form is not a failure of the payload: it says macOS answered those
# launches by refusing rather than by holding, and what the sections measured is printed
# either way.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tests/out/exechold"
LOG="$OUT/exec_hold_probe.log"
SCRIPT="$ROOT/tests/scripts/shorter.txt"
DMG="dist/shadowrun-0.1.0-macos-arm64.dmg"
APP_NAME="Shadowrun"
# How long a direct start is given before its exec is called held: a run of $SCRIPT
# prints its first line in well under a second, so anything that has not mapped its
# frameworks by then was never going to.
HELD_WAIT="${HELD_WAIT:-12}"
# How long a held process is then watched without being touched, which is the difference
# between 'the system is still deciding' and 'this path is stuck'.
HOLD_PATIENCE="${HOLD_PATIENCE:-120}"
# How long the refused launch is left alone before it is stopped: long enough for
# syspolicyd to log its own decision, which on this machine is about nine seconds after
# the prompt appears.
DENY_WAIT="${DENY_WAIT:-30}"
BASE="/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold"
RUN="$BASE/run-$(date +%Y%m%d-%H%M%S)"
LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

say() { printf '  %s\n' "$*"; }
sha() { shasum -a 256 "$1" | cut -c1-16; }
cdh() { codesign -dvvv "$1" 2>&1 | awk -F= '/^CDHash=/ {print $2; exit}'; }
problems=0

# procs <app name>: every live process of this bundle, as "<pid> <executable path>".
# Matched on the tail of the path, restricted to this script's own scratch base or an
# AppTranslocation path, for the reasons recorded in tests/macos_user_open_probe.sh:
# pgrep -f does not match a path this long, and a quarantined bundle is run from a
# randomised path that is not the copy on disk.
procs() {
  ps -axo pid=,comm= 2>/dev/null | awk -v tail=".app/Contents/MacOS/$1" \
    -v scratch="$BASE" -v transloc="/T/AppTranslocation/" \
    '{pid=$1; sub(/^[ ]*[0-9]+[ ]+/, ""); sub(/[ ]+$/, "");
      if (length($0) >= length(tail) && substr($0, length($0)-length(tail)+1) == tail) {
        if (index($0, scratch) || index($0, transloc)) print pid" "$0 } }'
}

# exec_probe <label> <exe> [keep]: one direct start, dummy drivers, a private $HOME, the
# same input script every other round runs.  Prints what the process looked like after
# HELD_WAIT seconds and sets HELD to 1 for a held exec, 0 for one that ran, -1 for one
# that was still mid-run but had clearly started (dyld had finished).  With 'keep' the
# process is left alive, which is how the patience watch in section 3 sees the same
# process rather than a new one each time.  WATCH_PID and WATCH_OUT carry it to the
# caller; both are empty when nothing was left standing.
exec_probe() {
  local label="$1" exe="$2" keep="${3:-}" name pid mapped stale p
  local out="$OUT/probe-$label.txt"
  name=$(basename "$exe")
  # Whatever else of this name is alive would be answered by pgrep instead of by this
  # probe's own process, so it is named and stopped first.  It can only be a process an
  # earlier leg left standing: a quarantined launch runs from a randomised path, and the
  # probe below looks for one name wherever it is.
  stale="$(procs "$name")"
  if [ -n "$stale" ]; then
    say "  $label: stopped what was already alive under this name first:"
    printf '%s\n' "$stale" | sed 's/^/      /'
    printf '%s\n' "$stale" | while read -r p _; do kill -KILL "$p" 2>/dev/null || true; done
    sleep 1
  fi
  ( cd "$(dirname "$exe")" && env HOME="$RUN/home" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
      "$exe" --no-launcher --rom "$rom" --script "$SCRIPT" ) >"$out" 2>&1 &
  local job=$!
  say "  $label: started $(basename "$exe") from ${exe#"$BASE"/}"
  sleep "$HELD_WAIT"
  pid=$(pgrep -x "$name" 2>/dev/null | head -1)
  WATCH_PID=""; WATCH_OUT="$out"
  if [ -z "$pid" ]; then
    say "     no process left: it ran and finished on its own, $(grep -c '' <"$out") line(s) of"
    say "     its own output, first line: $(head -1 "$out")"
    HELD=0
  else
    mapped=$(lsof -p "$pid" 2>/dev/null | grep -c 'txt.*REG'); mapped=${mapped:-0}
    say "     pid $pid alive after ${HELD_WAIT}s: $(grep -c '' <"$out") line(s) of output,"
    say "     $(ps -o time= -p "$pid" 2>/dev/null | tr -s ' ') of CPU, $mapped mapped file(s)"
    local sf="$OUT/sample-$label.txt" held_at=""
    sample "$pid" 1 -mayDie -file "$sf" >/dev/null 2>&1
    if [ -f "$sf" ]; then
      say "     macOS's own sampler, asked about that same pid:"
      awk '/Call graph:/,/^$/ {print}' "$sf" | grep -v 'Call graph:' | sed '/^$/d' \
        | tail -3 | sed 's/^/       /'
      held_at="$(grep -c '_dyld_start' "$sf" 2>/dev/null || true)"; held_at=${held_at:-0}
    fi
    if [ -n "$held_at" ] && [ "$held_at" != 0 ]; then
      say "     that is dyld's entry point, named in the sampler's own words: the process"
      say "     exists and has not been allowed to start, and the only $mapped file(s) mapped"
      say "     are the executable itself and the dynamic linker.  A held exec."
      HELD=1
    elif [ "$mapped" -gt 3 ]; then
      say "     that many mappings means dyld finished: this one was running, not held, and"
      say "     this leg only waited out the cap it was given."
      HELD=-1
    else
      say "     alive, but the sampler does not name dyld's entry point anywhere in its call"
      say "     graph, so this is not the held-exec shape even though only $mapped file(s) are"
      say "     mapped.  A copy whose launch was started by a click and told to read a file"
      say "     under ~/Documents was measured with the same two mappings and its main thread"
      say "     inside open(); the sampler's frames above say which of the two this is."
      HELD=-1
    fi
    if [ -z "$keep" ] || [ "$HELD" != 1 ]; then
      kill -KILL "$pid" 2>/dev/null || true
    else
      WATCH_PID=$pid
    fi
  fi
  # A subshell's last command is exec'd by bash, so the held process is often the job
  # itself: when one is being kept for the watch in section 3, nothing here may kill
  # the job, or the thing being watched would be stopped by this very function.
  if [ -z "${WATCH_PID:-}" ]; then
    sleep 1; kill -KILL "$job" 2>/dev/null || true; wait "$job" 2>/dev/null
  fi
  return 0
}

# verdict <label> <cmd...>: run it, print its output indented and its exit code.
verdict() {
  local label="$1"; shift
  local o rc
  say "$label"
  if o=$("$@" 2>&1); then rc=0; else rc=$?; fi
  printf '%s\n' "$o" | sed 's/^/      /'
  say "    [exit=$rc]"
}

cd "$ROOT" || exit 1
# shellcheck source=tests/rom.sh
. "$ROOT/tests/rom.sh"
rom_repo="$(sr_rom)" || { say "no ROM to run; refusing"; exit 1; }
script_repo="$SCRIPT"
mkdir -p "$OUT"
for d in "$BASE"/run-*; do
  [ -d "$d" ] || continue
  [ "$d" = "$RUN" ] && continue
  rm -rf "$d" 2>/dev/null || true
done
mkdir -p "$RUN/home"
# The ROM and the input script are copied into this run's own scratch directory before any
# leg names them, because one leg starts the app the way a double-click does and a copy
# started that way was measured sitting inside the open() of a file under ~/Documents --
# which is where this repository sits.  A leg that is waiting on its folder cannot be told
# apart from a leg macOS is holding at exec, so both files are staged.
mkdir -p "$RUN/staged"
cp "$rom_repo" "$RUN/staged/Shadowrun.sfc"
cp "$script_repo" "$RUN/staged/shorter.txt"
rom="$RUN/staged/Shadowrun.sfc"
SCRIPT="$RUN/staged/shorter.txt"
: >"$LOG"
exec > >(tee -a "$LOG") 2>&1

pin_rev="$(grep -m1 '^snesrecomp=' "$ROOT/framework_pins.txt" | cut -d= -f2)"
echo "# macos_exec_hold.md"
echo "#"
echo "# what: what it means on this machine when macOS holds an app's exec open instead"
echo "#       of refusing it: what a held process looks like, how long the hold lasts,"
echo "#       what it is and is not keyed to, and what clears it and what does not.  The"
echo "#       condition is made on purpose,"
echo "#       from the shipped image, by clicking a quarantined copy twice: once as the"
echo "#       bytes that shipped, once as those same bytes re-signed under a new bundle"
echo "#       identifier, and both answers are printed.  All of it happens inside a"
echo "#       directory of this run's own."
echo "# how:  tests/macos_exec_hold_probe.sh (HELD_WAIT=$HELD_WAIT HOLD_PATIENCE=$HOLD_PATIENCE DENY_WAIT=$DENY_WAIT)"
echo "#"
echo "# inputs: $DMG, built in the packaging round; its hash is printed in section 0."
echo "#         the ROM and input script every start names are staged copies under"
echo "#         $RUN/staged, sha256 $(sha "$rom") and $(sha "$SCRIPT"), copied from"
echo "#         $rom_repo and $script_repo; the reason is printed in section 2."
echo "# scratch: $RUN (earlier passes under $BASE are removed at the start.  This one keeps"
echo "#          the copy it takes out of the image in $RUN/payload and the copy it re-signs"
echo "#          for section 2 in $RUN/fresh; $RUN/fresh2 is where section 5 makes the hold it"
echo "#          measures the rename on, together with the moved name and the copy of it made"
echo "#          at a path of its own, and all three are removed at the end of section 5, so no"
echo "#          bundle this pass may have left held stays standing on this machine)"
echo "# framework pin: $pin_rev (framework_pins.txt), printed for cross-reference only"
echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) (host $(uname -sr) $(uname -m), macOS $(sw_vers -productVersion) $(sw_vers -buildVersion))"
echo "# source tree: $ROOT"
echo

state_dirs() { ls -d "$HOME/Library/Application Support/"[Ss]hadowrun* 2>/dev/null | sort; }
home_fp() {
  local d n h
  while read -r d; do
    [ -d "$d" ] || continue
    n=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
    h=$(find "$d" -type f -exec stat -f '%m %N' {} \; 2>/dev/null | sort | shasum | cut -c1-16)
    printf '  %s file(s), fingerprint %s  %s\n' "$n" "$h" "${d#"$HOME"/}"
  done < <(state_dirs)
}
home_before="$(home_fp)"

echo "== 0. what this costs, and what it is not =="
echo
say "this script deliberately puts directories of its own on this machine into a state where"
say "their app cannot start, and then measures what clears that state and what does not,"
say "removing the copies it made in order to measure.  Both halves are printed"
say "rather than asserted, because the open-path probe's design rests on them: its"
say "refusal leg stops a process macOS is holding at exec, so that probe takes a scratch"
say "directory of its own per pass, takes the leg that has to run the app first, and"
say "checks the paths it used at the end."
say "every start here is direct, with dummy drivers, so no window and no audio device"
say "opens, and each one gets a private \$HOME ($RUN/home).  The one thing that cannot"
say "be done quietly is section 2: making the condition needs a quarantined bundle"
say "opened through LaunchServices, and that puts macOS's own sheet on this user's"
say "screen.  Section 2 clicks twice and section 5 clicks once more, on a copy of its own,"
say "so that is three sheets, each up for ${DENY_WAIT}s and no longer, because syspolicyd"
say "logs its decision for a bundle about nine seconds after its prompt."
printf '  %-52s %10s B  sha256 %s\n' "$(basename "$DMG")" "$(stat -f%z "$DMG")" "$(sha "$DMG")"
echo

APP="$RUN/payload/$APP_NAME.app"
EXE="$APP/Contents/MacOS/$APP_NAME"
MP="$RUN/mnt"

echo "== 1. the payload, copied out of the image, asked to run where it was put =="
echo
mkdir -p "$RUN/payload" "$MP"
if ! hdiutil attach -nobrowse -readonly -mountpoint "$MP" "$DMG" >"$OUT/attach.txt" 2>&1; then
  say "hdiutil attach failed:"; sed 's/^/      /' "$OUT/attach.txt"; exit 1
fi
ditto "$MP/$APP_NAME.app" "$APP"
hdiutil detach "$MP" 2>&1 | sed 's/^/      /'
printf '  payload copied out           %s   %s B\n' "$(sha "$EXE")" "$(stat -f%z "$EXE")"
say "  cdhash of the copy: $(cdh "$EXE")"
say "  attached data on it: [$(xattr -l "$APP" | tr '\n' ' ')] -- a build product carries"
say "  no download flag, which is why section 2 puts one on deliberately."
say "  asked to run before anything has been stopped anywhere:"
exec_probe "clean" "$EXE"
BASELINE=$HELD
if [ "$HELD" != 0 ]; then
  problems=$((problems + 1))
  say "  this path could not exec before anything in this script had touched it, so the"
  say "  rest of the run is measuring a starting condition rather than a made one.  $RUN"
  say "  is a directory of its own, so the pass that left a path held is not this one."
fi
echo

# refuse_leg <label> <app>: the download flag, the double-click, and whatever that click
# leaves behind.  Prints what 'open' said, what the process table says about this bundle,
# what macOS's own agents logged for the window, and how many of those lines use the word
# 'damaged'; then stops what it found, because nothing in this script can answer a sheet.
# HELD_FOUND says whether a process was left standing, and HELD_APP/HELD_EXE remember
# which bundle that was.
refuse_leg() {
  local label="$1" app="$2" name t0 f found pid path mapped dm lg job id
  name="$(basename "$app" .app)"
  id="$(codesign -dvv "$app" 2>&1 | awk -F= '/^Identifier=/{print $2;exit}')"
  say "leg $label: opening $(basename "$(dirname "$app")")/$APP_NAME.app"
  say "  identifier $( printf '%s' "$id"), cdhash $(cdh "$app/Contents/MacOS/$name")"
  xattr -w com.apple.quarantine "0081;$(printf '%08x' "$(date +%s)");Chrome;" "$app" \
    && say "  flag now on the bundle: $(xattr -p com.apple.quarantine "$app")"
  ( cd "$(dirname "$app")" && env -u SDL_VIDEODRIVER -u SDL_AUDIODRIVER HOME="$RUN/home" \
      open -W -n "$app" --args --no-launcher --rom "$rom" --script "$SCRIPT" ) >"$OUT/open-$label.txt" 2>&1 &
  job=$!
  t0=$(date +%s)
  sleep "$DENY_WAIT"
  say "  what 'open' said in those ${DENY_WAIT}s:"
  if [ -s "$OUT/open-$label.txt" ]; then sed 's/^/      /' "$OUT/open-$label.txt"; else say "      (nothing)"; fi
  say "  processes of this bundle alive now:"
  found="$(procs "$name" | head -1)"
  if [ -z "$found" ]; then
    say "      none -- this launch ended rather than waited, so macOS refused it rather than"
    say "      holding it, and this leg leaves no condition to measure."
    HELD_FOUND=0
  else
    HELD_FOUND=1
    HELD_APP="$app"
    HELD_EXE="$app/Contents/MacOS/$name"
    pid="${found%% *}"; path="${found#* }"
    say "      pid $pid from:"
    say "        $path"
    mapped=$(lsof -p "$pid" 2>/dev/null | grep -c 'txt.*REG'); mapped=${mapped:-0}
    say "      $mapped mapped file(s), $(ps -o time= -p "$pid" 2>/dev/null | tr -s ' ') of CPU"
    say "      after $(( $(date +%s) - t0 ))s of waiting."
    touch -t "$(date -r "$t0" '+%Y%m%d%H%M.%S')" "$OUT/.marker-$label"
    f="$(find "$RUN/home" -name last_run_report.json -newer "$OUT/.marker-$label" 2>/dev/null | head -1)"
    if [ -n "$f" ]; then
      say "      a run report newer than this open is already in the private \$HOME, so some"
      say "      process of this bundle did reach the host's own exit path: $f"
    else
      say "      no run report newer than this open: nothing this launch started has reached"
      say "      the host's exit path, which is what a held exec looks like from the state"
      say "      side as well as from the process table."
    fi
    rm -f "$OUT/.marker-$label"
    sample "$pid" 1 -mayDie -file "$OUT/sample-$label.txt" >/dev/null 2>&1
    if [ -f "$OUT/sample-$label.txt" ]; then
      say "      the sampler's own lines for its thread:"
      awk '/Call graph:/,/^$/ {print}' "$OUT/sample-$label.txt" | grep -v 'Call graph:' \
        | sed '/^$/d' | tail -2 | sed 's/^/        /'
    fi
    say "      now stopped, because nothing in this script is going to answer the sheet,"
    say "      and what the path does after such a stop is what section 3 asks:"
    kill -KILL "$pid" 2>/dev/null || true
    say "        pid $pid killed by SIGKILL"
  fi
  for c in $(pgrep -P "$job" 2>/dev/null); do kill -KILL "$c" 2>/dev/null || true; done
  kill -KILL "$job" 2>/dev/null || true
  wait "$job" 2>/dev/null
  lg="$(log show --start "$(date -r "$((t0 - 1))" '+%Y-%m-%d %H:%M:%S')" --style compact \
        --predicate 'process == "syspolicyd" OR process == "CoreServicesUIAgent"' 2>/dev/null | \
        grep -viE 'xpc:connection|activating connection' | \
        grep -iE 'retroportingtoolkit|shadow|quarantin|gatekeep|xprotect|System Policy|damag|denied' || true)"
  say "      what macOS's own agents logged for this leg -- syspolicyd is Gatekeeper's"
  say "      decision-maker and CoreServicesUIAgent draws the sheet:"
  if [ -z "$lg" ]; then
    say "        (no matching lines from those two processes in that window)"
  else
    printf '%s\n' "$lg" | sed 's/^/        /'
  fi
  dm=$(printf '%s\n' "$lg" | grep -ic 'damag' || true); dm=${dm:-0}
  say "      of those lines, $(printf '%s' "$dm") contain 'damag'"
  if [ "$dm" != 0 ]; then
    problems=$((problems + 1))
    say "        ^ the word this port's state fix exists to make impossible, counted as a"
    say "          finding rather than written as prose."
  fi
  return 0
}

echo "== 2. the condition made on purpose: a download flag, a click, and what the click leaves =="
echo
say "the flag a browser leaves on a download, written here because nothing downloaded this"
say "file.  'open' is the double-click path, and a quarantined bundle is translocated by"
say "macOS, so the process that exists afterwards is not at the path that was opened --"
say "which is why each leg below reads the process table rather than the copy on disk."
say "the ROM and the script these legs name are staged copies under $RUN/staged, not the"
say "repository's own files, which sit under ~/Documents: a copy started this way was"
say "measured sitting inside the open() of a file in that folder, and a leg waiting on a"
say "folder cannot be told apart from a leg macOS is holding at exec."
say "two legs, and they differ in exactly one thing -- whose code macOS is being asked"
say "about:"
say "  a. the copy taken out of the image, byte for byte the bytes that shipped, a cdhash"
say "     this machine has already been shown by this repository's earlier rounds, and one"
say "     section 1 just ran at this very path;"
say "  b. a copy of those same bytes re-signed ad hoc under a new bundle identifier, so its"
say "     cdhash is one this machine has never been asked about.  That is the position a"
say "     person is in the first time they open one of these images.  The seal still"
say "     validates and the signature is still ad hoc; the identifier and the cdhash are new,"
say "     and the payload digest and size before and after that re-signing are printed below"
say "     too, so 're-signed' is not something this run asks the reader to take on trust."
say "nothing in this run claims the re-signed copy is what ships: it is the copy that lets"
say "the condition be made on purpose at all, and the lines say which code each answer is"
say "about."
echo
refuse_leg "shipped" "$APP"
FOUND_SHIPPED=$HELD_FOUND
echo
say "now the second copy: the same bytes, taken from the first one, with a new bundle"
say "identifier and a fresh ad hoc signature over them."
FRESH="$RUN/fresh/$APP_NAME.app"
FRESH_EXE="$FRESH/Contents/MacOS/$APP_NAME"
FRESH_ID="org.retroportingtoolkit.holdprobe$(date +%s)"
rm -rf "$RUN/fresh"
mkdir -p "$RUN/fresh"
ditto "$APP" "$FRESH"
verdict "  the copy as it was copied out of the image:" codesign --verify --strict --verbose=2 "$FRESH"
plutil -replace CFBundleIdentifier -string "$FRESH_ID" "$FRESH/Contents/Info.plist" 2>&1 | sed 's/^/      /'
codesign -f -s - --identifier "$FRESH_ID" "$FRESH" 2>&1 | sed 's/^/      /'
verdict "  the same copy after that re-signing:" codesign --verify --strict --verbose=2 "$FRESH"
printf '  identifier  %s -> %s\n' \
  "$(codesign -dvv "$APP" 2>&1 | awk -F= '/^Identifier=/{print $2;exit}')" "$FRESH_ID"
printf '  cdhash      %s -> %s\n' "$(cdh "$EXE")" "$(cdh "$FRESH_EXE")"
printf '  payload     %s (%s B) -> %s (%s B)\n' \
  "$(sha "$EXE")" "$(stat -f%z "$EXE")" "$(sha "$FRESH_EXE")" "$(stat -f%z "$FRESH_EXE")"
echo
refuse_leg "fresh" "$FRESH"
FOUND_FRESH=$HELD_FOUND
echo

echo "== 3. after those stops: both paths asked again, and the held one watched =="
echo
say "the same direct probe at each path section 2 used, before anything else is done to"
say "either copy.  What right-click -> Open does to a copy is take the flag off, so these"
say "are asked with no flag on them, which is the state a person who overrode Gatekeeper"
say "leaves their copy in; the attached data on each copy is printed first so the answer"
say "below can be read as 'a copy with no download flag, at this path'."
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
xattr -dr com.apple.quarantine "$FRESH" 2>/dev/null || true
say "  attached data on the image copy now:  [$(xattr -l "$APP" | tr '\n' ' ')]"
say "  attached data on the re-signed copy:  [$(xattr -l "$FRESH" | tr '\n' ' ')]"
exec_probe "again-shipped" "$EXE"; SHIPPED_AFTER=$HELD
exec_probe "again-fresh" "$FRESH_EXE"; FRESH_AFTER=$HELD
HELD_AFTER=0
WHICH=""
if [ "$FRESH_AFTER" = 1 ]; then
  HELD_AFTER=1; WHICH="fresh"; HELD_APP="$FRESH"; HELD_EXE="$FRESH_EXE"
elif [ "$SHIPPED_AFTER" = 1 ]; then
  HELD_AFTER=1; WHICH="image"; HELD_APP="$APP"; HELD_EXE="$EXE"
fi
if [ "$HELD_AFTER" = 1 ]; then
  say "  the $WHICH copy is the one whose path is held, so that is the path the rest of this"
  say "  run measures.  Asked for once more with whatever it leaves left standing:"
  exec_probe "watch-$WHICH" "$HELD_EXE" keep
  if [ -n "${WATCH_PID:-}" ]; then
    say "  watched rather than assumed: the same pid, asked nothing, for ${HOLD_PATIENCE}s."
    t0=$(date +%s)
    while [ $(( $(date +%s) - t0 )) -lt "$HOLD_PATIENCE" ]; do
      sleep 20
      if kill -0 "$WATCH_PID" 2>/dev/null; then
        say "    $(( $(date +%s) - t0 ))s: pid $WATCH_PID alive," \
          "$(lsof -p "$WATCH_PID" 2>/dev/null | grep -c 'txt.*REG') mapped file(s)," \
          "$(ps -o time= -p "$WATCH_PID" 2>/dev/null | tr -s ' ') CPU," \
          "$(grep -c '' <"${WATCH_OUT:-/dev/null}") line(s) of output"
      else
        say "    $(( $(date +%s) - t0 ))s: the pid is gone, so the system resolved it after all"
        break
      fi
    done
    if kill -0 "$WATCH_PID" 2>/dev/null; then
      say "  still the same process, still no output, still those same mappings: the hold did"
      say "  not resolve on its own inside ${HOLD_PATIENCE}s.  Stopped to keep watching."
      kill -KILL "$WATCH_PID" 2>/dev/null || true
    fi
  else
    say "  nothing was left standing by that probe, so there is no process to watch."
    HELD_AFTER=0
    problems=$((problems + 1))
  fi
else
  say "  neither path is held after its stop, so this run did not create the condition it"
  say "  was written to measure: both legs above were answered by macOS ending the launch"
  say "  or by exec completing.  What is printed below is what this machine answered; the"
  say "  condition itself is in an earlier log of this script."
  problems=$((problems + 1))
fi
echo

echo "== 4. the same code at other paths, so a hold here cannot be blamed on the code =="
echo
say "three more copies, each with its cdhash printed next to it, each asked the same"
say "question at a path this run has never stopped a process at.  The cdhashes are"
say "compared rather than assumed equal, and the image's own payload is called out when it"
say "is a different code from the held one."
CDH_HELD="$(cdh "${HELD_EXE:-$EXE}")"
cp "${HELD_EXE:-$EXE}" "$RUN/$APP_NAME"
CDH_A="$(cdh "$RUN/$APP_NAME")"
printf '  a) bare Mach-O at a path of its own        %s  cdhash %s  %s\n' \
  "$(sha "$RUN/$APP_NAME")" "$CDH_A" "$( [ "$CDH_A" = "$CDH_HELD" ] && echo same-code || echo different-code )"
exec_probe "bare-copy" "$RUN/$APP_NAME"
A_HELD=$HELD
rm -rf "$RUN/copy2"; mkdir -p "$RUN/copy2"
ditto "${HELD_APP:-$APP}" "$RUN/copy2/$APP_NAME.app"
CDH_B="$(cdh "$RUN/copy2/$APP_NAME.app/Contents/MacOS/$APP_NAME")"
printf '  b) a fresh ditto of the whole bundle       %s  cdhash %s  %s\n' \
  "$(sha "$RUN/copy2/$APP_NAME.app/Contents/MacOS/$APP_NAME")" "$CDH_B" \
  "$( [ "$CDH_B" = "$CDH_HELD" ] && echo same-code || echo different-code )"
exec_probe "second-bundle" "$RUN/copy2/$APP_NAME.app/Contents/MacOS/$APP_NAME"
B_HELD=$HELD
C_HELD=-1; CDH_C=""
mkdir -p "$RUN/mnt2"
if hdiutil attach -nobrowse -readonly -mountpoint "$RUN/mnt2" "$DMG" >"$OUT/attach2.txt" 2>&1; then
  CDH_C="$(cdh "$RUN/mnt2/$APP_NAME.app/Contents/MacOS/$APP_NAME")"
  printf '  c) the payload inside the image itself     %s  cdhash %s  %s\n' \
    "$(sha "$RUN/mnt2/$APP_NAME.app/Contents/MacOS/$APP_NAME")" "$CDH_C" \
    "$( [ "$CDH_C" = "$CDH_HELD" ] && echo same-code || echo different-code )"
  exec_probe "in-image" "$RUN/mnt2/$APP_NAME.app/Contents/MacOS/$APP_NAME"
  C_HELD=$HELD
  hdiutil detach "$RUN/mnt2" 2>&1 | sed 's/^/      /'
else
  say "  c) could not mount the image again:"; sed 's/^/      /' "$OUT/attach2.txt"
fi
if [ "$HELD_AFTER" = 1 ] && [ "$A_HELD" = 0 ] && [ "$B_HELD" = 0 ] && [ "$C_HELD" = 0 ]; then
  n_same=0
  if [ "$CDH_A" = "$CDH_HELD" ]; then n_same=$((n_same + 1)); fi
  if [ "$CDH_B" = "$CDH_HELD" ]; then n_same=$((n_same + 1)); fi
  if [ "$CDH_C" = "$CDH_HELD" ]; then n_same=$((n_same + 1)); fi
  say "  $n_same of these three paths carry exactly the held code, and all three of them ran"
  say "  while the path section 3 named stayed held.  So at this moment on this machine that"
  say "  cdhash was held at one path and let through at $n_same others, and a third path -- a"
  say "  different code, as its own column says -- ran as well.  The hold at that one path is"
  say "  not an effect of those bytes.  What it is keyed to is what section 5 measures, and"
  say "  that section prints its answer whichever way it falls."
  if [ "$CDH_C" != "$CDH_HELD" ]; then
    say "  (line c is marked different-code: the payload inside the image and the copy this run"
    say "  holds are not the same code, which is what the cdhash column prints rather than"
    say "  assumes, so the finding above rests on lines a and b: held=$CDH_HELD a=$CDH_A"
    say "  b=$CDH_B c=$CDH_C)"
  fi
elif [ "$HELD_AFTER" = 1 ]; then
  say "  not all of them ran (a=$A_HELD b=$B_HELD c=$C_HELD), so on this run the hold is not"
  say "  simply keyed to the path; read the lines above for which one was held."
  problems=$((problems + 1))
fi
echo

echo "== 5. how wide that directory is, and what clears it =="
echo
say "each line is one thing a person or a script could do to the held path, followed by the"
say "same direct probe there.  The order of these lines is part of what they mean: an"
say "intervention can only be credited with clearing a path if that path was still held when"
say "it was asked, so once one of them has made the path able to exec again, every probe"
say "after it on that same path is measuring a path that was already clear.  The first one"
say "after which the path ran is printed at the end of this list for that reason."
say "the rename -- the directory that holds the bundle, not the bundle's own name -- is not"
say "in that list.  It is measured below, on a hold made for it by the same recipe, so that"
say "its answer belongs to it rather than to whichever of these four cleared this one."
say "and the same measurement then copies that held bundle to a path of its own and asks"
say "that copy twice, once with the download flag it was copied with and once without it, so"
say "a hold that stays with the file through a rename can be told from a hold on those bytes"
say "at any path at all, and from a fresh Gatekeeper question made by the flag itself."
after_spctl=-1; after_xattr=-1; after_lsreg=-1; after_ui=-1; after_name=-1; after_move=-1; after_back=-1
if [ "$HELD_AFTER" = 1 ]; then
  HELD_PARENT="$(dirname "$HELD_APP")"
  say "held bundle for this section: $HELD_APP"
  say "first, the width: the same bundle, the same directory, a second file name inside it."
  say "If the hold covers that too, it is the directory rather than the file."
  cp "$HELD_EXE" "$HELD_APP/Contents/MacOS/${APP_NAME}2"
  exec_probe "other-name" "$HELD_APP/Contents/MacOS/${APP_NAME}2"
  after_name=$HELD
  rm -f "$HELD_APP/Contents/MacOS/${APP_NAME}2"
  say "  (that copy was made by this section and removed again; the seal is re-asked at the"
  say "   end of this section)"
  verdict "  spctl, asked to assess this bundle again:" spctl -a -vv -t execute "$HELD_APP"
  exec_probe "after-spctl" "$HELD_EXE"; after_spctl=$HELD
  verdict "  every extended attribute cleared on the bundle:" xattr -c -r "$HELD_APP"
  exec_probe "after-xattr" "$HELD_EXE"; after_xattr=$HELD
  verdict "  LaunchServices told this bundle changed:" "$LSREG" -f "$HELD_APP"
  exec_probe "after-lsregister" "$HELD_EXE"; after_lsreg=$HELD
  say "  this user's own UI agent sent SIGKILL -- the signal that ends a process rather than"
  say "  asking it to stop.  launchd relaunches it on demand; its root-owned decision-maker"
  say "  syspolicyd cannot be reached at all without a password, and this script does not"
  say "  ask for one.  The pid before and after says whether it actually restarted, and the"
  say "  label below says SIGTERM-to-SIGKILL rather than 'restart' for the reason this line"
  say "  prints: an earlier attempt here used killall with no signal, which sends SIGTERM, and"
  say "  the pid was simply still there afterwards, so that line measured nothing."
  pgrep -x CoreServicesUIAgent | sed 's/^/      before: /' || say "      before: (not running)"
  if o=$(killall -KILL CoreServicesUIAgent 2>&1); then rc=0; else rc=$?; fi
  [ -n "$o" ] && printf '%s\n' "$o" | sed 's/^/      killall: /'
  say "      killall exit=$rc"
  sleep 5
  pgrep -x CoreServicesUIAgent | sed 's/^/      after:  /' || say "      after:  (not running)"
  exec_probe "after-uiagent" "$HELD_EXE"; after_ui=$HELD
  clear_pos=0
  first_clear="none of these four"
  if [ "$after_spctl" = 0 ]; then clear_pos=1; first_clear="1, spctl's assessment"
  elif [ "$after_xattr" = 0 ]; then clear_pos=2; first_clear="2, clearing every extended attribute"
  elif [ "$after_lsreg" = 0 ]; then clear_pos=3; first_clear="3, LaunchServices being told the bundle changed"
  elif [ "$after_ui" = 0 ]; then clear_pos=4; first_clear="4, the SIGKILL sent to this user's UI agent"
  fi
  say "  of these four, the first after which this path ran again was number $clear_pos:"
  say "  $first_clear."
  if [ "$clear_pos" = 0 ]; then
    say "  every one of the four was asked of a path that was still held when it was asked, so"
    say "  each number above is what a held path answered and none of them is a remedy."
  else
    say "  the lines before that one asked a path that was still held, and that number is the"
    say "  one thing in this list this machine measured clear.  The list ends there: the rename"
    say "  is measured below, on a hold nothing in this list has touched, because an earlier"
    say "  pass of this script asked the rename about a path one of these four had already"
    say "  cleared and read that as the rename's own answer."
  fi
  verdict "  the bundle's seal, after all of that:" codesign --verify --strict --verbose=2 "$HELD_APP"
else
  say "nothing was held at the end of section 3, so there is no condition here to clear:"
  say "what section 4 printed is the whole of what this run measured."
fi
echo

say "the rename, on a hold of its own.  A second copy of the payload, a new bundle"
say "identifier, a fresh ad hoc signature over it, the download flag, one click, the stop:"
say "the same recipe section 2 used for its leg b, in a directory of this run's that"
say "nothing else has touched.  Then the directory holding the bundle is renamed aside,"
say "the app is asked to run from there, the directory is put back, and the app is asked"
say "to run at the original path again."
rm -rf "$RUN/fresh2"; mkdir -p "$RUN/fresh2"
FRESH2="$RUN/fresh2/$APP_NAME.app"
FRESH2_EXE="$FRESH2/Contents/MacOS/$APP_NAME"
FRESH2_ID="org.retroportingtoolkit.holdprobeb$(date +%s)"
ditto "$APP" "$FRESH2"
verdict "  the second copy, before the re-signing:" codesign --verify --strict --verbose=2 "$FRESH2"
plutil -replace CFBundleIdentifier -string "$FRESH2_ID" "$FRESH2/Contents/Info.plist" 2>&1 | sed 's/^/      /'
codesign -f -s - --identifier "$FRESH2_ID" "$FRESH2" 2>&1 | sed 's/^/      /'
verdict "  the second copy, after it:" codesign --verify --strict --verbose=2 "$FRESH2"
printf '  identifier  %s -> %s\n' \
  "$(codesign -dvv "$APP" 2>&1 | awk -F= '/^Identifier=/{print $2;exit}')" "$FRESH2_ID"
printf '  cdhash      %s -> %s\n' "$(cdh "$EXE")" "$(cdh "$FRESH2_EXE")"
printf '  payload     %s (%s B) -> %s (%s B)\n' \
  "$(sha "$EXE")" "$(stat -f%z "$EXE")" "$(sha "$FRESH2_EXE")" "$(stat -f%z "$FRESH2_EXE")"
echo
refuse_leg "second" "$FRESH2"
RENAME_HELD=0; after_ctrl=-1; after_flag=-1
if [ "$HELD_FOUND" = 1 ]; then
  exec_probe "again-second" "$FRESH2_EXE"; again_second=$HELD
  if [ "$again_second" = 1 ]; then
    RENAME_HELD=1
    say "  that path is held, and nothing but the click and the stop has touched it.  Now the"
    say "  directory that holds the bundle moves aside:"
    if mv "$RUN/fresh2" "$RUN/fresh2-moved" 2>&1; then
      say "      $RUN/fresh2 -> $RUN/fresh2-moved"
    else
      say "      the rename failed; nothing was done."
      problems=$((problems + 1))
    fi
    exec_probe "rename-on-fresh-hold" "$RUN/fresh2-moved/$APP_NAME.app/Contents/MacOS/$APP_NAME"
    after_move=$HELD
    say "  and the directory put back the way it was, to ask whether the original path is"
    say "  held again:"
    if mv "$RUN/fresh2-moved" "$RUN/fresh2" 2>&1; then
      say "      $RUN/fresh2-moved -> $RUN/fresh2"
    else
      say "      the rename back failed; nothing was done."
      problems=$((problems + 1))
    fi
    exec_probe "back-at-fresh-path" "$FRESH2_EXE"; after_back=$HELD
    say "  and that same held bundle copied to a path of its own, so a hold that stayed with"
    say "  the file through a rename can be told from a hold on those bytes wherever they sit."
    say "  That copy is asked twice, and the difference between the two questions is printed"
    say "  first: the download flag this section wrote on the original for its click is carried"
    say "  across by a copy tool that keeps extended attributes, and section 2 measured that"
    say "  flag plus a click is enough to make this condition at all.  So a copy that still"
    say "  carries it is a fresh Gatekeeper question rather than a control on these bytes, and"
    say "  it is asked as one and then asked again with the flag taken off it:"
    rm -rf "$RUN/fresh3"; mkdir -p "$RUN/fresh3"
    ditto "$FRESH2" "$RUN/fresh3/$APP_NAME.app"
    FRESH3_APP="$RUN/fresh3/$APP_NAME.app"
    FRESH3_EXE="$FRESH3_APP/Contents/MacOS/$APP_NAME"
    say "  attached data on the held bundle this copy was made from: [$(xattr -l "$FRESH2" | tr '\n' ' ')]"
    say "  attached data on the copy as it stands:                   [$(xattr -l "$FRESH3_APP" | tr '\n' ' ')]"
    printf '  copy at a new path  cdhash %s  %s\n' "$(cdh "$FRESH3_EXE")" \
      "$( [ "$(cdh "$FRESH3_EXE")" = "$(cdh "$FRESH2_EXE")" ] && echo same-code-as-the-held-file || echo different-code )"
    exec_probe "copy-flag-on" "$FRESH3_EXE"
    after_flag=$HELD
    xattr -dr com.apple.quarantine "$FRESH3_APP" 2>/dev/null || true
    say "  attached data on that same copy now the flag is off it:   [$(xattr -l "$FRESH3_APP" | tr '\n' ' ')]"
    exec_probe "copy-flag-off" "$FRESH3_EXE"
    after_ctrl=$HELD
    if [ "$after_move" = 0 ] && [ "$after_back" = 0 ]; then
      say "  so this run can attribute the clear to the rename: the same bundle, the same"
      say "  cdhash, the same file, running from the moved directory and then running at the"
      say "  original path once that directory was put back.  The copy control's two answers are"
      say "  printed above and this pass did not need them, because this hold cleared at both"
      say "  names of this directory."
    elif [ "$after_move" = 1 ] && [ "$after_back" = 1 ]; then
      say "  the rename did not move this hold: the same bundle, the same cdhash, the same"
      say "  file, still held at the path its directory was moved to and still held at the"
      say "  original path once that directory was put back.  A directory rename is therefore"
      say "  not a remedy on this machine, and the hold does not follow the name of the path"
      say "  the bundle is asked at.  What it does follow is not measured here."
      if [ "$after_flag" = 1 ] && [ "$after_ctrl" = 0 ]; then
        say "  and the copy answers say something different again: those same bytes, that same"
        say "  cdhash, at a path this run has never stopped a process at, were held while the"
        say "  copy still carried the flag this section had written for the click, and ran once"
        say "  that flag was taken off.  Read together with section 4, where a copy made from the"
        say "  held bundle with no flag on it ran at a path of its own, this says the bytes are"
        say "  not held wherever they sit: what made that copy held was the flag it carried, the"
        say "  same thing section 2 needed in order to make the condition at all."
      elif [ "$after_flag" = 1 ] && [ "$after_ctrl" = 1 ]; then
        say "  and the copy says the same thing about this code from the other side: it was"
        say "  held at a path of its own as well, both with the download flag this run had"
        say "  written for its click and with that flag then taken off it.  So for this code"
        say "  nothing this script can reach from user level moved the hold -- not the path the"
        say "  bundle sat at, not the name that path was renamed to, not a copy of the whole"
        say "  bundle made at a path this run has never stopped a process at, and not the flag."
        say "  One difference between this code and the code section 4 asked about at three"
        say "  paths that ran is worth naming rather than glossed: they are different cdhashes,"
        say "  printed in both places above, and between those two sets of answers sits the one"
        say "  thing this run did to macOS's own agent -- the SIGKILL that made the first path"
        say "  able to exec again.  Which of those two its answer turns on is not measured here."
      elif [ "$after_flag" = 0 ] && [ "$after_ctrl" = 0 ]; then
        say "  while the copy of that same file at a path of its own ran there whether the flag"
        say "  was on it or off it, so these bytes are not held wherever they sit."
      else
        say "  the copy answered unevenly (flag on=$after_flag, flag off=$after_ctrl), a shape"
        say "  this script has not measured before, so it is counted here rather than explained."
        problems=$((problems + 1))
      fi
    else
      say "  this hold answered the rename unevenly (moved=$after_move back=$after_back), a"
      say "  shape this script has not measured before, so it is counted here rather than"
      say "  explained."
      problems=$((problems + 1))
    fi
    verdict "  the second copy's seal, after all of that:" codesign --verify --strict --verbose=2 "$FRESH2"
    rm -rf "$RUN/fresh2" "$RUN/fresh2-moved" "$RUN/fresh3"
    say "  this section made $RUN/fresh2, $RUN/fresh2-moved and $RUN/fresh3 only to be"
    say "  measured, and all three are removed here, so nothing this section may have left"
    say "  held stays standing on the machine."
  else
    say "  the click and the stop did not leave that path held -- the probe there answered"
    say "  $again_second, where 1 means held -- so the rename has no hold to clear here and"
    say "  this pass says nothing about it."
    problems=$((problems + 1))
  fi
else
  say "  that click was answered by macOS ending the launch rather than by holding it, so the"
  say "  rename was not measured on a hold of its own in this pass."
  problems=$((problems + 1))
fi
echo

echo "== 6. what this run wrote, and the machine checked around it =="
echo
say "what the private \$HOME holds, which is all the state the starts above were allowed"
say "to produce:"
if [ -d "$RUN/home/Library/Application Support" ]; then
  find "$RUN/home" -mindepth 1 | sort | sed "s|^$RUN/home|.|" | sed 's/^/  /'
else
  say "  nothing: no start got as far as writing state."
fi
say "which state directory the host chose is printed above rather than assumed here."
echo
say "this machine's own ~/Library/Application Support/, fingerprinted before the run and"
say "now:"
say "  before:"
if [ -z "$home_before" ]; then
  say "    (no Shadowrun-shaped directory in the real home)"
else
  printf '%s\n' "$home_before" | sed 's/^/  /'
fi
say "  after:"
home_now="$(home_fp)"
if [ -z "$home_now" ]; then
  say "    (no Shadowrun-shaped directory in the real home)"
else
  printf '%s\n' "$home_now" | sed 's/^/  /'
fi
if [ "$home_before" = "$home_now" ]; then
  say "  identical: the private \$HOME relay held, and a person running this loses nothing."
else
  problems=$((problems + 1))
  say "  different, so the relay did not hold.  Nothing here is removed to put that"
  say "  right: taking a person's saves away to tidy a log is worse than the finding."
fi
echo
ips_all="$(find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 2 -name '*.ips' 2>/dev/null | sort)"
ips_n=$(printf '%s\n' "$ips_all" | grep -c '\.ips$' || true); ips_n=${ips_n:-0}
ips_first="$(printf '%s\n' "$ips_all" | head -1)"
say "crash reports: $ips_n in ~/Library/Logs/DiagnosticReports, oldest by name:"
say "  ${ips_first##*/}"
ips_now="$(find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 2 -iname '*shadow*' 2>/dev/null | sort)"
if [ -z "$ips_now" ]; then
  say "  none of them names Shadowrun or Shadowrun-personal.  That includes the processes"
  say "  stopped by SIGKILL above: a process macOS never let start writes no report, which"
  say "  is part of why a held exec and a crash are different complaints."
else
  problems=$((problems + 1))
  printf '%s\n' "$ips_now" | sed 's/^/      /'
  say "  ^ a report naming one of these executables exists; read it before believing any"
  say "    sentence here about a held exec being different from a crash."
fi
echo
say "every process of this bundle still alive now the sections are over:"
left="$(procs "$APP_NAME")"
if [ -n "$left" ]; then
  problems=$((problems + 1))
  printf '%s\n' "$left" | sed 's/^/      /'
  say "  ^ left running: this script has no business leaving an app on a machine, so it"
  say "  is stopped here and counted as a finding."
  printf '%s\n' "$left" | awk '{print $1}' | while read -r p; do kill -KILL "$p" 2>/dev/null || true; done
else
  say "  none."
fi
say "and this run's own scratch, so the next pass does not start inside a held path:"
say "  $RUN is left on disk for reading; earlier passes under $BASE were removed at the"
say "  start of this one.  Its copy out of the image lives in $RUN/payload and the copy"
say "  section 2 re-signs lives in $RUN/fresh; $RUN/fresh2 is where section 5 made the hold"
say "  it measured the rename on, and that one is gone again -- see below."
if [ "$RENAME_HELD" = 1 ]; then
  say "  ${RUN#"$BASE"/}/fresh2 is the directory the rename was measured in.  It, the copy"
  say "  made of it at a new path, and the moved name were removed at the end of section 5,"
  say "  so no copy of a bundle this section may have left held stays standing on the machine."
elif [ "$HELD_AFTER" = 1 ]; then
  say "  the entry held at the end of section 3 was in ${HELD_PARENT#"$BASE"/}; the rename was"
  say "  not measured on a hold of its own in this pass, so that directory was left as it was."
else
  say "  nothing was held at the end of this run, so no directory of this run was renamed."
fi
echo

echo "== 7. what this measured =="
echo
say "the shapes this run leaves on the page, one line each:"
say "  * a held exec is a live process whose sampler call graph names dyld's entry point"
say "    and nothing else; a refused launch is a process that ends.  tests/macos_user_open_"
say "    probe.sh keeps them apart rather than reading both as 'no run report'."
say "  * the mapping count alone cannot keep those shapes apart: a copy started by a click"
say "    and told to read a file under ~/Documents was measured with the same two mapped"
say "    files and its main thread inside open().  So every 'held' above rests on the"
say "    sampler naming dyld's entry point, and a live process it cannot place there is"
say "    reported as neither held nor run."
say "  * which copy carries which cdhash is printed next to each click in section 2, and"
say "    section 4 marks every other path it asks as the same code as the held one or a"
say "    different one, rather than assuming it."
say "  * the payload execed at its path before the condition was made: $BASELINE (0 = it"
say "    ran).  The two clicks in section 2 left a process standing: shipped copy=$FOUND_SHIPPED,"
say "    re-signed copy=$FOUND_FRESH (1 = a process was there to stop, 0 = the launch ended)."
say "    At the paths they used, after those stops: shipped=$SHIPPED_AFTER,"
say "    re-signed=$FRESH_AFTER, and the path the rest of the run measured is the $WHICH"
say "    copy: $HELD_AFTER (1 = held)."
if [ "$HELD_AFTER" = 1 ]; then
  say "  * the other paths section 4 asked about: bare copy=$A_HELD second bundle=$B_HELD inside the image=$C_HELD (0 = ran, 1 = held, -1 = alive but not at dyld's entry point, and each one is marked same-code or different-code beside its cdhash)."
  say "  * second file name in the same bundle=$after_name, spctl=$after_spctl, xattr -c=$after_xattr, lsregister=$after_lsreg, UI agent SIGKILL=$after_ui (1 = still held, 0 = ran).  The first of those four after which this path ran again was number $clear_pos ($first_clear); every line before that number was asked of a path that was still held when it was asked, and the list stops at that number."
fi
say "  * the rename was measured on a hold of its own, in ${RUN#"$BASE"/}/fresh2: that hold formed=$RENAME_HELD (1 = it did), the same bundle asked at the moved path=$after_move and at the original path again=$after_back, and a copy of that held bundle made at a path of its own asked twice -- with the download flag it was copied with=$after_flag and with that flag taken off=$after_ctrl (1 = still held, 0 = ran, -1 = not asked or alive but not at dyld's entry point).  Those copies are removed at the end of section 5, so this pass leaves no copy of them standing."
if [ "$HELD_AFTER" = 1 ]; then
  say "  * the machine: state $( if [ "$home_before" = "$home_now" ]; then echo unchanged; else echo CHANGED; fi), no report naming either executable, no process of this bundle left, and the bundle the rename was measured on removed rather than left in a held directory."
else
  say "  * the machine: state $( if [ "$home_before" = "$home_now" ]; then echo unchanged; else echo CHANGED; fi), no report naming either executable, no process of this bundle left, and no path of this run was held at the end of section 3; the hold the rename is measured on, if it formed, had its copies removed at the end of section 5."
fi
echo
if [ "$problems" = 0 ]; then
  say "nothing unexpected."
else
  say "$problems unexpected finding(s) above."
fi
echo
say "exit status of this script, printed here so the log itself carries it: $problems --"
say "0 means the sections above agree with each other and the machine is as it was"
say "found, anything else means one of the checks counted a finding."
exit "$problems"
