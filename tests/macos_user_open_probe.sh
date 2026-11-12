#!/usr/bin/env bash
# What a person who downloads one of these images actually experiences.
#
#   tests/macos_user_open_probe.sh
#
# The packaging round's section 9 asks macOS's tools about the bundle and gets a
# useful answer: spctl says 'rejected' because the signature is ad hoc and
# unnotarised, and that refusal does not change when a browser's download flag is
# added, while the seal still validates with the flag on.  What it never does is
# *open* the thing.  The complaint this packaging exists to answer is a sentence a
# person reads on their own screen -- '... is damaged and can't be opened' -- and a
# sentence a person reads comes from the open path, not from an assessor's exit
# code.  So this probe walks the whole user sequence against the shipped images:
#
#   1. mount the .dmg read-only and copy the .app out with ditto, which is what a
#      drag out of the image does, into a scratch directory outside this repository --
#      a directory of its own for each pass, for a reason measured in section 2 below;
#   2. ask, from a shell, whether this machine can exec these bytes at that path at
#      all, before any leg that has to run the app is believed;
#   3. open the copy while it carries no download flag -- 'open', no terminal in front
#      of it, the same thing right-click -> Open leaves behind -- and print whatever
#      macOS does, in its own words;
#   4. give the copy the quarantine flag a browser leaves on a download, ask
#      Gatekeeper, and open it again, which is the launch it refuses;
#   5. check that the copy that just ran is still the bytes that shipped and still
#      seals, because a run that writes inside its own bundle is the failure that
#      made the original report.
#   6. ask one folder question in that same click path, with a fresh copy: what happens
#      when the ROM it is handed sits inside ~/Documents, what happens when the same
#      bytes are staged outside that folder, and what happens when only the input
#      script sits inside it.  This is the reason every other leg names staged copies.
#
# The order of 3 and 4 is the other half of the finding in section 2: the run that has
# to happen is taken first, because a refused launch can leave a process held at exec
# while its sheet waits for a person who is not in this script, and on this machine a path
# that has held one was measured going on refusing to exec afterwards.  When that happens,
# what the held process looks like, and what clears it, is measured by
# tests/macos_exec_hold_probe.sh; this probe only checks its own paths in section 7.
#
# Two things this measures that no other leg in this kit does, and both are said up
# front in the log as well as here:
#
#   * the legs really do start through LaunchServices -- 'open', not a shell
#     command line -- and a LaunchServices start has no $HOME handed to it the way a
#     shell run does.  So the private $HOME these legs use is relayed by 'open'
#     itself, which is a fact the packaging log already measured: its section 5
#     breadcrumb caught SDL_VIDEODRIVER travelling from the shell that ran 'open'
#     into the app, and that is the same route.  Without the relay these legs would
#     write into this machine's real ~/Library/Application Support/, and a test does
#     not get to overwrite a person's saves; section 7 checks the real directory
#     before and after rather than trusting the relay.
#   * the successful open legs are not headless: the app opens a real window and a
#     real audio device for the length of the input script, as it does for a person.
#   * 'open -W' is asked for but measured against rather than trusted.  On this
#     machine 'open' has returned while the process it launched was still running,
#     and for a launch Gatekeeper refuses it never returns at all.  So each leg waits
#     for the app process itself and reads the run report the host writes on its way
#     out.  The pid, the executable path it was seen at, and the wall-clock length of
#     the leg are all printed, so a leg can be checked rather than believed.
#   * a process is matched by the tail of its executable path, '.app/Contents/MacOS/
#     <name>', and not by the path the leg opened.  Measured the hard way: a bundle
#     that still carries the download flag is translocated by macOS -- run from a
#     randomised read-only path under .../T/AppTranslocation/<uuid>/d/ -- so the leg
#     that looked only for its own copy printed 'no process at all' while a process
#     held at exec sat on the machine.  One pass of this probe ended with two of them
#     still alive four minutes after their legs; app_procs finds them, and every leg
#     ends by stopping whatever it left, because a leftover is also the process the
#     next leg would read as its own.
#   * a refused launch leaves a sheet on the user's screen that nothing in this script
#     can answer, which is why the waits differ by what a leg is looking for: a leg
#     that never produced a process gives up after NO_PID_WAIT rather than sitting out
#     a whole cap, and a leg whose point is that it gets refused is capped at
#     DENY_WAIT, which on this machine is enough for syspolicyd to log its own
#     decision.
#
# Nothing here reaches the ROM file picker: every leg passes --no-launcher, the
# shareable leg also passes --rom, and the personal leg needs neither because the
# guest is inside its executable.  A leg that ends at 124/125, or that leaves a
# live process and no run report, is recorded as reaching a window it cannot answer.
#
# Exit 0 = both packages went through the whole sequence and the things that matter
# held: each path could exec its payload before the legs and after them, after the
# override each open brought the app up, the copy that ran is still
# the bytes that shipped, it still seals, nothing on the open path said the word
# 'damaged', and this machine's own state directory and crash reports are as they
# were.  Anything unexpected -- a copy that changed, a seal that broke, a leg that
# hung, an override that still did not start the app, the machine's own state touched,
# a crash report for either executable -- prints under the verdict and makes the exit
# non-zero.  Gatekeeper refusing the *flagged* open is expected here and does not fail
# the run: it is a fact about an ad hoc, unnotarised signature, and sections 3 and 4
# keep it apart from the payload question that section 5 answers.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tests/out/openprobe"
LOG="$OUT/user_open_probe.log"
ROM_LEG="${ROM_LEGS:-with}"            # with = pass --rom like every other leg
# Two waits rather than one, because the ways an open does not finish need different
# amounts of patience: a leg that has produced a process is given OPEN_WAIT (a
# quarantined ad hoc bundle is held at exec pending a sheet nobody in this run answers,
# and measuring how long Gatekeeper takes to decide is not what this probe is about),
# while a leg that has produced no process at all gives up after NO_PID_WAIT.
OPEN_WAIT="${OPEN_WAIT:-45}"           # cap for a leg that started something
NO_PID_WAIT="${NO_PID_WAIT:-25}"       # wait for a process to appear at all
# A leg whose whole point is that it gets refused, measured on this machine: syspolicyd
# logs its own decision about nine seconds after its prompt, so thirty covers that and
# nothing more.
DENY_WAIT="${DENY_WAIT:-30}"          # cap for a leg expected to be refused
# How long to watch a process before calling its exec held: a run of $SCRIPT prints its
# first line in well under a second, so anything that has not mapped its frameworks
# after this many seconds was never going to.
HELD_WAIT="${HELD_WAIT:-12}"
# How long a folder-question leg watches its process.  Measured on this machine with the
# same images: a leg whose ROM and script are staged outside a protected folder had finished
# its scripted run and was gone inside 30s, while a leg naming the ROM inside this
# repository was still sitting in the open() of that file at 30s.  So 30s separates the two
# answers, and every extra second is a second a window is on the user's screen.
FOLDER_WAIT="${FOLDER_WAIT:-30}"
SCRIPT="$ROOT/tests/scripts/shorter.txt"
# A scratch directory of its own for every pass, and that is not tidiness: measured on
# this machine, a bundle directory can go on refusing to exec *at that path* after a
# process was held there -- held for as long as watching lasted, and covering a second
# file name inside that same bundle, while the identical code (same cdhash) execs normally
# at any other path, including inside the shipped image.  Renaming that directory is what
# measured clear.  tests/macos_exec_hold_probe.sh measures all of that; a
# pass of this probe creates exactly that condition in its own refusal leg, so a pass that
# reused a fixed path would later measure legs that print a tidy-looking nothing.  Each
# pass gets a path of its own, and section 7 shows the pass leaving nothing held behind.
SCRATCH_BASE="/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen"
SCRATCH_ROOT="$SCRATCH_BASE/run-$(date +%Y%m%d-%H%M%S)"
# what counts as a gatekeeper-shaped line in the system log: the bundle's own name,
# the quarantine resolver, Gatekeeper, XProtect, the policy decision, or a 'damaged'
# complaint.  Anything else those two agents log is plumbing noise about xpc
# connections and this probe has no business putting it in an artifact.
LOGWORDS='retroportingtoolkit|shadow|quarantin|gatekeep|xprotect|System Policy|damag|denied'
# inside those lines, two narrower questions are counted rather than eyeballed: does
# Gatekeeper say it refused, in its own phrasing rather than this probe's, and does
# anything on the open path use the word 'damaged'.
GKWORDS='Gatekeeper|denial|allowed policy|Terminating process'
DAMAGEDWORDS='damag'
# The four processes that can speak about a folder request, and the words that name one:
# tccd answers a request for a protected folder, sandboxd passes it on and enforces the
# answer, and the Gatekeeper pair are there in case a refusal is what happened.  The
# word list is printed beside the counts so an excerpt can be read as a sample of a
# counted window rather than as everything the machine said.
FOLDER_WORDS='retroportingtoolkit|shadow|documents|denied|prompt|container|sandbox|deny'

say() { printf '  %s\n' "$1"; }
sha() { shasum -a 256 "$1" | cut -c1-16; }
count() { printf '%s' "$(printf '%s\n' "$1" | grep -c '' )"; }

# verdict <label> <cmd...>: run it, print its output indented and its exit code.
problems=0
verdict() {
  local label="$1"; shift
  local out rc
  say "$label"
  if out=$("$@" 2>&1); then rc=0; else rc=$?; fi
  printf '%s\n' "$out" | sed 's/^/      /'
  say "    [exit=$rc]"
  RC=$rc
}

# app_procs <app name>: every live process belonging to one of these bundles, one per
# line as "<pid> <executable path>".
#
# Two ways this looked for a process failed on this machine, and both are recorded
# here because each one produced a leg that silently measured nothing:
#   * pgrep -f with the full path never matched, because the path is long enough that
#     pgrep's own match rule stops applying;
#   * matching the exact path the leg opened missed the case that matters most,
#     because a copy that still carries the download flag is *translocated*: macOS
#     runs it from a randomised read-only path under .../T/AppTranslocation/<uuid>/d/,
#     so the process that exists is not at the path that was opened.  Measured, and
#     twice over: one pass of this probe ended with two such processes still held at
#     exec, four minutes after their legs had printed "no process at all".
# So the match is on the tail '.app/Contents/MacOS/<name>' of ps's comm= column,
# compared as an exact suffix rather than a substring -- which is what keeps the
# shareable legs from reading a Shadowrun-personal process as one of their own -- and
# only inside this probe's scratch base (any pass of it, not just this pass) or an
# AppTranslocation path, so a Shadowrun this machine runs some other way is never this
# leg's process.
app_procs() {
  ps -axo pid=,comm= 2>/dev/null | awk -v tail=".app/Contents/MacOS/$1" \
    -v scratch="$SCRATCH_BASE" -v transloc="/T/AppTranslocation/" \
    '{pid=$1; sub(/^[ ]*[0-9]+[ ]+/, ""); sub(/[ ]+$/, "");
      if (length($0) >= length(tail) && substr($0, length($0)-length(tail)+1) == tail) {
        if (index($0, scratch) || index($0, transloc)) print pid" "$0 } }'
}

# clean_apps <app name> <why>: stop every process of this bundle that a leg left
# behind, printing each one first.  A person answering Gatekeeper's sheet ends up with
# that held process resolved one way or another; nobody is answering it here, so the
# run has to stop it rather than leave an app on the user's screen -- and a process
# left running between legs is a process the next leg will read as its own.
#
# What stopping one costs, measured on this machine and said here rather than found
# later: stopping a process that macOS is holding at exec leaves that bundle's *own
# directory* unable to exec -- measured in tests/macos_exec_hold_probe.sh, where the
# payload stopped while translocated then sat at dyld's entry point at its own path, for
# as long as watching lasted, and covering a second file name in that same bundle, while
# the identical machine code with the identical cdhash ran to completion at a bare path,
# at a second copy of the bundle, and inside the mounted image.  So the hold follows the
# bundle's directory rather than the bytes: renaming that directory is what cleared it,
# even a rename away and back again, while spctl's assessment, clearing every xattr,
# re-registering the bundle with LaunchServices and restarting the user's UI agent each
# left it held.  That is why this probe takes the leg that has to run the app *before*
# the refusal leg, why each pass works in a scratch directory of its own, and why section
# 6 checks the paths this pass used and clears them the measured way.
clean_apps() {
  local n="$1" why="$2" line pid path
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    pid="${line%% *}"; path="${line#* }"
    say "   $why: stopping pid $pid running from $path"
    kill -KILL "$pid" 2>/dev/null || true
    case "$path" in
      */T/AppTranslocation/*)
        say "   that one was translocated and held at exec, so stopping it is the act"
        say "   that leaves the bundle's own directory held; section 7 checks and clears"
        say "   that below."
        ;;
    esac
  done < <(app_procs "$n")
  sleep 1
  if [ -n "$(app_procs "$n")" ]; then
    say "   a process of $n is still alive after SIGKILL; this run cannot be trusted"
    say "   to have left the machine as it found it."
    problems=$((problems + 1))
  fi
}

# held_at_exec <app name> <exe>: can this machine exec these bytes at all right now?
# A process whose exec macOS has not finished deciding maps nothing but its own Mach-O
# and /usr/lib/dyld, uses no CPU, prints nothing, and sample shows its only thread at
# _dyld_start.  That is the shape of a held exec, and it is not the same as a refused
# launch: a refusal ends the process, a hold keeps it.
#
# This is asked before any leg that has to run the app, because on a machine already
# holding exec at this path, every leg below would print a tidy-looking 'no run report'
# while measuring nothing.  Started directly, with dummy drivers and its own private
# $HOME: it is a check on the machine, not a leg, so it opens no window and its state
# goes nowhere near the state section 7 reads.
held_at_exec() {
  local name="$1" exe="$2" job pid mapped tops=""
  local out="$OUT/held-$name.txt"
  say "  started directly from a shell, dummy drivers, its own \$HOME ($PREFLIGHT_HOME),"
  say "  with the same $SCRIPT every other leg runs:"
  if [ "$PKG" = shareable ]; then
    ( cd "$(dirname "$exe")" && env HOME="$PREFLIGHT_HOME" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        "$exe" --no-launcher --rom "$rom" --script "$SCRIPT" ) >"$out" 2>&1 &
  else
    ( cd "$(dirname "$exe")" && env HOME="$PREFLIGHT_HOME" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        "$exe" --no-launcher --script "$SCRIPT" ) >"$out" 2>&1 &
  fi
  job=$!
  sleep "$HELD_WAIT"
  pid=$(pgrep -x "$name" 2>/dev/null | head -1)
  if [ -n "$pid" ]; then
    say "   the process this check is looking at is pid $pid, running from:"
    say "     $(ps -o comm= -p "$pid" 2>/dev/null)"
  fi
  if [ -z "$pid" ]; then
    say "   it ran and finished on its own: $(grep -c '' <"$out") line(s) of its own output,"
    say "   and its run report is $(ls "$PREFLIGHT_HOME/Library/Application Support/$name/last_run_report.json" 2>/dev/null || echo "(none found)")"
    if [ "$PKG" = shareable ]; then
      say "   (--rom on this line because the shareable payload carries no image)"
    else
      say "   (no --rom on this line: the personal payload carries its image)"
    fi
    wait "$job" 2>/dev/null
    HELD=0
    return 0
  fi
  mapped=$(lsof -p "$pid" 2>/dev/null | grep -c 'txt.*REG'); mapped=${mapped:-0}
  local sf="$OUT/sample-$name.txt"
  sample "$pid" 1 -mayDie -file "$sf" >/dev/null 2>&1
  if [ -f "$sf" ]; then
    tops=$(awk '/Call graph:/,/^$/ {print}' "$sf" | grep -v 'Call graph:' | tail -2 | tr -s ' ' | tr '\n' ' ')
  fi
  if [ "$mapped" -gt 3 ]; then
    say "   pid $pid is already running with $mapped mapped files, so exec completed; stopping it."
    kill -KILL "$pid" 2>/dev/null
    HELD=0
  else
    say "   pid $pid is alive after ${HELD_WAIT}s with $mapped mapped file(s).  It has"
    say "   written $(grep -c '' <"$out") line(s) of its own output and used"
    say "   $(ps -o time= -p "$pid" 2>/dev/null | tr -s ' ') of CPU in those ${HELD_WAIT}s."
    say "   macOS's own sampler puts its only thread here:"
    say "     $tops"
    say "     (its own words, from $(basename "$sf") in the run's output directory)"
    say "   that is dyld's entry point: the process exists and has never been allowed to"
    say "   start.  It is stopped below; what a path does after such a process is stopped is"
    say "   measured in tests/macos_exec_hold_probe.sh and checked again in section 7."
    kill -KILL "$pid" 2>/dev/null
    HELD=1
  fi
  sleep 1; kill -KILL "$job" 2>/dev/null; wait "$job" 2>/dev/null
  [ "$HELD" = 0 ] || return 1
  return 0
}

# exec_at <label> <exe> <name> <$HOME for it> [args for it...]: the lean form of the
# question 'can this path exec these bytes right now?'.  One direct start with dummy
# drivers and a private $HOME, watched for HELD_WAIT seconds.  RAN means no process was
# left standing and the executable printed its own output; HELD means a process sat
# there with nothing mapped but its own Mach-O and /usr/lib/dyld, which is the shape of
# an exec macOS has not finished deciding about, and it is stopped.  EXEC_HELD carries
# the answer to the caller.  Used by section 7 to check the paths this pass used rather
# than to claim anything about the payload: the measurement of the condition and of the
# way out of it is tests/macos_exec_hold_probe.sh.
exec_at() {
  local label="$1" exe="$2" name="$3" home="$4"; shift 4
  local out="$OUT/exec-$label.txt" job pid mapped rc=0 where
  where="${exe#"$SCRATCH_BASE"/}"
  ( cd "$(dirname "$exe")" && env HOME="$home" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
      "$exe" "$@" ) >"$out" 2>&1 &
  job=$!
  sleep "$HELD_WAIT"
  pid=$(pgrep -x "$name" 2>/dev/null | head -1)
  if [ -z "$pid" ]; then
    printf '    %-46s RAN   %s line(s) of its own output\n' "$where" "$(grep -c '' <"$out")"
    EXEC_HELD=0
  else
    mapped=$(lsof -p "$pid" 2>/dev/null | grep -c 'txt.*REG'); mapped=${mapped:-0}
    printf '    %-46s HELD  pid %s, %s mapped file(s), %s line(s) of output\n' \
      "$where" "$pid" "$mapped" "$(grep -c '' <"$out")"
    say "                  that pid's own executable path: $(ps -o comm= -p "$pid" 2>/dev/null)"
    kill -KILL "$pid" 2>/dev/null || true
    EXEC_HELD=1
    rc=1
  fi
  sleep 1; kill -KILL "$job" 2>/dev/null || true; wait "$job" 2>/dev/null
  return $rc
}

# folder_leg <label> <app> <$HOME for it> [args for the app...]: one open-the-way-a-click
# does, watched for FOLDER_WAIT seconds, with macOS's own sampler asked where the process
# is sitting if it is still there.  This is the leg that measures the folder a path names,
# so the app runs with a real window and audio driver exactly as a click does: the point is
# what the click path does, not what a headless run does.  Alive is a process still standing
# at FOLDER_WAIT; the sampler's frames and the run report are what say whether that is a
# run in progress or a process waiting on something it was never given.
folder_leg() {
  local label="$1" app="$2" home="$3"; shift 3
  local f="$OUT/folder-$label.txt" mark="$OUT/.fmark-$label" job pid mapped rc=0 name sf pre=""
  name="$(basename "$app" .app)"
  pre="$(app_procs "$name")"
  if [ -n "$pre" ]; then
    say "   $name was already running when this leg started:"
    printf '%s\n' "$pre" | sed 's/^/      /'
    clean_apps "$name" "before the leg"
  else
    say "   nothing of $name is running yet, so any process below is this leg's"
  fi
  touch "$mark"
  ( cd "$SCRATCH_ROOT" && env -u SDL_VIDEODRIVER -u SDL_AUDIODRIVER HOME="$home" \
      open -W -n "$app" --args "$@" ) >"$f" 2>&1 &
  job=$!
  sleep "$FOLDER_WAIT"
  pid=$(pgrep -x "$name" 2>/dev/null | head -1)
  if [ -z "$pid" ]; then
    FOLDER_ALIVE=0
    say "   no process of $name left after ${FOLDER_WAIT}s: this open ended on its own"
  else
    FOLDER_ALIVE=1
    mapped=$(lsof -p "$pid" 2>/dev/null | grep -c 'txt.*REG'); mapped=${mapped:-0}
    say "   pid $pid is still there after ${FOLDER_WAIT}s, running from:"
    say "     $(ps -o comm= -p "$pid" 2>/dev/null)"
    say "   it has used $(ps -o time= -p "$pid" 2>/dev/null | tr -s ' ') of CPU and has $mapped mapped file(s)."
    sf="$OUT/folder-sample-$label.txt"
    sample "$pid" 1 -mayDie -file "$sf" >/dev/null 2>&1
    if [ -f "$sf" ]; then
      say "   macOS's own sampler puts its main thread here (its words, from $(basename "$sf")):"
      awk '/Call graph:/{gc=1;next} /^Total number/{gc=0} gc' "$sf" \
        | awk '/main-thread/{f=1} f && /^[ ]*[0-9]+ Thread_/ && !/main-thread/{exit} f' \
        | head -16 | sed 's/^/     /'
      say "   that is the whole call graph of the main thread; the sampler also found"
      say "   $(grep -c 'Thread_' "$sf" 2>/dev/null || echo 0) thread(s) in this process, and"
      say "   their names are the second thing to read here: a process whose main thread sits"
      say "   in open() with audio and event threads running is a started app waiting on a"
      say "   file, while one whose only thread is at dyld's entry point has not been allowed"
      say "   to start at all."
    else
      say "   the sampler wrote nothing to $sf"
    fi
    lsof -p "$pid" 2>/dev/null | grep -iE '\.sfc|shorter\.txt' | sed 's/^/     lsof /'
  fi
  for c in $(pgrep -P "$job" 2>/dev/null); do kill -KILL "$c" 2>/dev/null || true; done
  kill -KILL "$job" 2>/dev/null || true
  wait "$job" 2>/dev/null; rc=$?
  clean_apps "$name" "at the end of the leg"
  say "   'open' exit=$rc because this script stopped the waiting command; what the app"
  say "   did is the run report, asked for below."
  local rep; rep="$(find "$home/Library/Application Support/$name/last_run_report.json" -newer "$mark" 2>/dev/null | head -1)"
  if [ -n "$rep" ]; then
    FOLDER_REP=1
    say "   run report newer than this leg: ${rep#"$home"/}"
  else
    FOLDER_REP=0
    say "   no run report for $name under this leg's \$HOME is newer than this leg started"
  fi
  rm -f "$mark"
  return 0
}

# stop_open <job>: kill the waiting 'open' and its own children.  Killing only the
# subshell would leave 'open -W' running, and that is precisely what a refused launch
# leaves behind -- measured on this machine, syspolicyd's own line says 'Terminating
# process due to Gatekeeper rejection' and the waiting command never comes back.
stop_open() {
  local j="$1" c
  if kill -0 "$j" 2>/dev/null; then KILLED=1; fi
  for c in $(pgrep -P "$j" 2>/dev/null); do kill -KILL "$c" 2>/dev/null || true; done
  kill -KILL "$j" 2>/dev/null || true
  sleep 1
}

# open_bounded <label> <app> <cap-seconds> [args for the app...]
# The leg starts the app the way a double-click does and then waits for the app
# itself, not for 'open': -W is asked for, but measured against rather than trusted,
# because on this machine 'open' returns while its app is still running for one leg
# and never returns at all when LaunchServices refuses the launch.  The two ends of
# the leg are read from the process table and the run report, and both the wall
# seconds and the pid and executable path that were seen are printed so the leg can
# be checked.
#
# Two waits rather than one timeout, because the two ways an open does not finish want
# different patience: <cap> caps a leg that started something and would not end (a
# window this harness cannot answer, say), while NO_PID_WAIT ends a leg that never
# produced a process at all -- waiting longer there cannot change the answer, and
# every extra second is a second Gatekeeper's sheet sits on the user's screen.
open_bounded() {
  local label="$1" app="$2" cap="$3"; shift 3
  local f="$OUT/open-${label}.txt" job rc t0 now timed=0 nopid=0 seen="" seenpath="" exe p wall=0 transloc=0
  KILLED=0
  exe="$app/Contents/MacOS/$(basename "$app" .app)"
  # Nothing of this bundle may be running before the leg starts, or the leg would read
  # a leftover as its own process.  Checked, and said, rather than assumed.
  local pre; pre="$(app_procs "$(basename "$app" .app)")"
  if [ -n "$pre" ]; then
    say "   $(basename "$app" .app) was already running when this leg started:"
    printf '%s\n' "$pre" | sed 's/^/      /'
    clean_apps "$(basename "$app" .app)" "before the leg"
  else
    say "   nothing of $(basename "$app" .app) is running yet, so any process below is this leg's"
  fi
  # HOME is given, not inherited: a person who runs this probe does not get their
  # own saves and settings rewritten by it.  See the header for why that is possible
  # through LaunchServices at all, and section 7 for the check that it worked.
  # The -u options go before the assignment: env parses its options first, and
  # `env HOME=x -u FOO cmd` reads -u as a program name and dies at 127, which is how
  # the first version of this leg measured nothing at all while still printing a
  # tidy-looking line.
  t0=$(date +%s)
  ( cd "$SCRATCH" && env -u SDL_VIDEODRIVER -u SDL_AUDIODRIVER HOME="$STATE_HOME" \
        open -W -n "$app" --args "$@" ) >"$f" 2>&1 &
  job=$!
  while :; do
    p="$(app_procs "$(basename "$app" .app)" | head -1)"
    if [ -n "$p" ]; then seen="${p%% *}"; seenpath="${p#* }"; fi
    now=$(date +%s)
    # One end of a normal leg: a process this leg started is gone again.  The input
    # script quits, so 'gone' is the expected answer; 'open -W' is stopped here in
    # case it is the one that has not noticed.
    if [ -n "$seen" ] && [ -z "$(app_procs "$(basename "$app" .app)")" ]; then
      stop_open "$job"
      break
    fi
    # The other end: nothing ever appeared.  Every leg here runs a script that brings
    # a window up in a couple of seconds, so a leg with no process after
    # NO_PID_WAIT seconds was refused before it started, and 'open -W' will sit there
    # forever saying so in silence.
    if [ -z "$seen" ] && [ $((now - t0)) -ge "$NO_PID_WAIT" ]; then
      nopid=1
      say "   ${NO_PID_WAIT}s with no process at all, so this open is read as refused"
      say "   before it started rather than as a run that hung.  The waiting 'open' is"
      say "   stopped here; waiting for it to return is not an option, because for a"
      say "   refused launch it never does."
      stop_open "$job"
      break
    fi
    if [ $((now - t0)) -ge "$cap" ]; then
      timed=1
      say "   ${cap}s with no end to this leg, so what it left is stopped by signal below"
      stop_open "$job"
      break
    fi
    sleep 1
  done
  wait "$job" 2>/dev/null; rc=$?
  wall=$(( $(date +%s) - t0 ))
  OPEN_RC=$rc
  OPEN_TIMED=$timed
  OPEN_NOPID=$nopid
  OPEN_T0=$t0
  OPEN_WALL=$wall
  OPEN_PID_SEEN="$seen"
  OPEN_PID_PATH="$seenpath"
  if [ -n "$seen" ]; then
    say "   the leg's process was pid $seen, running from:"
    say "     $seenpath"
    say "   this leg took ${wall}s of wall clock"
    case "$seenpath" in
      */T/AppTranslocation/*)
        transloc=1
        say "   that path is not where this probe put the copy: macOS applies App Path"
        say "   Randomisation (App Translocation) to a bundle that carries the download"
        say "   flag, and runs it from a randomised read-only path instead.  So the"
        say "   process is not the copy on disk, and asking whether that copy changed"
        say "   says nothing about it -- which is why the copy's own payload digest and"
        say "   tree hash are re-read in section 5.$PKG rather than inferred here."
        ;;
    esac
    clean_apps "$(basename "$app" .app)" "at the end of the leg"
  else
    say "   no process of $(basename "$app" .app), at the opened path or a translocated"
    say "   one, existed at any point in these ${wall}s"
  fi
  if [ "$timed" = 1 ] || [ "$nopid" = 1 ]; then
    say "   'open' exit=$rc -- that is the exit of the waiting command this script"
    say "   stopped, not a verdict from LaunchServices.  The verdict is in the run"
    say "   report and in the system's own log lines printed below."
  elif [ "$KILLED" = 1 ]; then
    say "   'open' exit=$rc because this script stopped the waiting 'open -W' after the"
    say "   app it launched had already gone; the app's outcome is the run report below."
  else
    say "   'open' exit=$rc"
  fi
  if [ -s "$f" ]; then
    say "   what the 'open' command printed, verbatim:"
    sed 's/^/      /' "$f"
  else
    say "   (the 'open' command printed nothing on stdout or stderr)"
  fi
  # A leg that ends before its app has exited would otherwise be read as "nothing
  # happened"; wait briefly for the report the host writes on its way out.  The
  # marker file is what makes "newer than this leg" a question BSD find can answer.
  if [ -z "$seen" ]; then
    touch "$OUT/.marker-$label"
    for _ in 1 2 3 4 5; do
      if [ -n "$(find "$STATE_HOME" -name last_run_report.json -newer "$OUT/.marker-$label" 2>/dev/null | head -1)" ]; then break; fi
      sleep 1
    done
    rm -f "$OUT/.marker-$label"
  fi
}

# system_words <since-epoch>: print what macOS's own gatekeeper/quarantine agents
# logged from that moment to now, in their words rather than this probe's paraphrase.
# That is where a refusal would be recorded if the open path produced one, and it is
# the only place the reason for a silent open is.  The window is opened with --start
# at the leg rather than --last Ns: measured with --last, a long enough window pulled
# the previous package's leg into this package's section, and a log that mixes two
# legs is not evidence about either of them.
GK_REJECTED=0
DAMAGED_LINES=0
system_words() {
  local since="$1" out rc total kept gk dm t0s
  # BSD date takes the epoch with -r; GNU's -d is not what /usr/bin/date speaks.
  t0s="$(date -r "$((since - 1))" '+%Y-%m-%d %H:%M:%S')"
  say "   what macOS's own agents logged in the window this leg covers -- from $t0s,"
  say "   when it started, to now, a few seconds after it ended, unedited (syspolicyd"
  say "   is Gatekeeper's decision-maker, CoreServicesUIAgent draws the sheet):"
  if out=$(log show --start "$t0s" --style compact --predicate \
        'process == "syspolicyd" OR process == "CoreServicesUIAgent"' 2>&1); then rc=0; else rc=$?; fi
  total=$(printf '%s\n' "$out" | grep -c '' || true)
  kept="$(printf '%s\n' "$out" | grep -iE "$LOGWORDS" || true)"
  if [ -n "$kept" ]; then
    printf '%s\n' "$kept" | sed 's/^/      /'
  else
    say "      (nothing those two processes logged in that window matches $LOGWORDS)"
  fi
  gk=$(printf '%s\n' "$kept" | grep -icE "$GKWORDS" || true); gk=${gk:-0}
  dm=$(printf '%s\n' "$kept" | grep -icE "$DAMAGEDWORDS" || true); dm=${dm:-0}
  kept_n=$(printf '%s\n' "$kept" | grep -c '' || true); kept_n=${kept_n:-0}
  if [ -z "$kept" ]; then kept_n=0; fi
  say "      [log show exit=$rc: $total line(s) from those two processes, $kept_n matched $LOGWORDS, and $dm of those contain the substring 'damag']"
  GK_REJECTED=$gk
  DAMAGED_LINES=$dm
  if [ "$dm" != 0 ]; then
    say "      the word 'damaged' appears above: that is the report this port's whole"
    say "      state-out-of-the-bundle fix is meant to prevent, and it is counted as a"
    say "      problem rather than prose."
  fi
}

# leg <label>: one open leg for the package currently being walked, with that
# package's arguments.  Written as a branch rather than an argument array because
# the personal package takes no ROM argument at all, and bash 3.2 expands an empty
# array under set -u as an unbound variable -- which would end the run at the very
# line that is supposed to be measuring the app.
leg() {
  # A leg that is expected to be refused gets less patience than one that is expected
  # to run: measured on this machine, syspolicyd's own decision for a quarantined ad
  # hoc bundle arrives roughly nine seconds after its prompt, so waiting a whole
  # OPEN_WAIT out would buy the same answer and keep the sheet on the user's screen
  # that whole time.
  local cap="$OPEN_WAIT"
  case "$1" in flag-on-*) cap="$DENY_WAIT";; esac
  if [ "$PKG" = shareable ]; then
    open_bounded "$1" "$APP" "$cap" --no-launcher --rom "$rom" --script "$SCRIPT"
  else
    open_bounded "$1" "$APP" "$cap" --no-launcher --script "$SCRIPT"
    say "   no --rom on this line and no rom.cfg in the bundle, so a report with"
    say "   frames in it means the click path booted the guest out of the executable."
  fi
}

# reports_since <epoch>: print every last_run_report.json under the private state
# home that is newer than <epoch>, and say where it was found.  The directory name
# inside it is discovered rather than assumed: it is what the host chose for this
# bundle, and this probe should not be the thing that claims that name.
reports_since() {
  local since="$1" f m found=0 dir note
  for f in "$STATE_HOME/Library/Application Support/"*/last_run_report.json; do
    [ -f "$f" ] || continue
    dir="$(basename "$(dirname "$f")")"
    note=""
    [ "$dir" = "$APP_NAME" ] || note="  (a state directory not named for this bundle)"
    m=$(stat -f %m "$f")
    if [ "$m" -ge "$since" ]; then
      found=1
      say "   run report written by this leg: ${f#"$STATE_HOME"/}$note"
      python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); st=d.get('status') or {}
print('reason=%s host frames=%s at %s' % (d.get('reason'), st.get('frame'), d.get('timestamp')))
" "$f" 2>/dev/null | sed 's/^/      /'
      { grep -o 'video=[a-z]* audio=[a-z]*' "$f" || true; } | head -1 | sed 's/^/      drivers: /'
    else
      say "   an older report is already there: ${f#"$STATE_HOME"/}, mtime $(stat -f '%Sm' "$f")$note"
    fi
  done
  RAN_SEEN=$found
  if [ "$found" = 0 ]; then
    say "   no run report under the private \$HOME is newer than this leg started, so"
    say "   this leg did not bring the app up: it was refused, or it never started, or"
    say "   the report went somewhere else.  The leg's own words above are what to read."
  fi
}

cd "$ROOT" || exit 1
# shellcheck source=tests/rom.sh
. "$ROOT/tests/rom.sh"        # sr_rom: every leg gets its ROM, so none can reach the picker
mkdir -p "$OUT"
# This pass works in a directory of its own, and the passes before it are removed --
# not for tidiness, but because on this machine a directory that has held a process at
# exec was measured still refusing to exec at that path, so a stale scratch path could be
# the starting point of the next pass.  Nothing in them belongs to this repository: they are copies of the
# shipped bundles, made by an earlier pass of this same probe.
mkdir -p "$SCRATCH_ROOT"
for d in "$SCRATCH_BASE"/run-*; do
  [ -d "$d" ] || continue
  [ "$d" = "$SCRATCH_ROOT" ] && continue
  rm -rf "$d" 2>/dev/null || true
done
RESULTS=""

STATE_HOME="$OUT/state_home"
rm -rf "$STATE_HOME"
mkdir -p "$STATE_HOME"
# A second private $HOME, only for the pre-flight check of whether this machine can
# exec these bytes at all.  Kept apart on purpose: whatever that check writes must
# never be read as one of the legs' state in section 8.
PREFLIGHT_HOME="$OUT/preflight_home"
rm -rf "$PREFLIGHT_HOME"
mkdir -p "$PREFLIGHT_HOME"
: >"$LOG"
exec > >(tee -a "$LOG") 2>&1

# A header for the log, because the log is what gets promoted to evidence/artifacts/
# verbatim, and a reader of that file needs to know which round's images it walked.
# Nothing here rebuilds anything: the two .dmg files are the packager round's output,
# and section 0 prints their hashes so the images under test are pinned to it.  The
# pin is printed for cross-reference with the framework round, not because a framework
# is consulted on this path.
pin_rev="$(grep -m1 '^snesrecomp=' "$ROOT/framework_pins.txt" | cut -d= -f2)"
echo "# macos_user_open.md"
echo "#"
echo "# what: what a person who downloads one of the shipped images actually gets:"
echo "#       copy the .app out with ditto, ask whether this machine can exec these bytes"
echo "#       at that path at all, double-click the copy with no download flag on it, then"
echo "#       put the download flag on and double-click again, and finally ask whether"
echo "#       the copy that just ran is still the bytes that shipped, whether it still"
echo "#       seals, and whether anything said the word 'damaged' on the way; and, in"
echo "#       click-path legs of its own, what the same copy does when the ROM or the input"
echo "#       script it is handed sits inside ~/Documents rather than in a plain directory."
echo "# how:  tests/macos_user_open_probe.sh (OPEN_WAIT=$OPEN_WAIT DENY_WAIT=$DENY_WAIT NO_PID_WAIT=$NO_PID_WAIT HELD_WAIT=$HELD_WAIT FOLDER_WAIT=$FOLDER_WAIT ROM_LEGS=$ROM_LEG)"
echo "#"
echo "# inputs: dist/shadowrun-0.1.0-macos-arm64.dmg (shareable) and"
echo "#          dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg (personal), both"
echo "#          built in the packaging round; their hashes are printed in section 0."
echo "# scratch: $SCRATCH_ROOT -- one directory of its own per pass, because stopping a"
echo "#          process macOS holds at exec is measured to leave that bundle directory"
echo "#          unable to exec (tests/macos_exec_hold_probe.sh), and section 7 checks"
echo "#          and clears what this pass leaves of its own paths."
echo "# framework pin: $pin_rev (framework_pins.txt), printed for cross-reference only"
echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) (host $(uname -sr) $(uname -m), macOS $(sw_vers -productVersion) $(sw_vers -buildVersion))"
echo "# source tree: $ROOT"
echo

# The machine's own state directory, read before and after the legs: the legs are
# supposed to write to $STATE_HOME instead, and this is the check rather than the
# assumption.  A directory name is not enough to say a person's state is untouched,
# because the legs could edit files inside one that was already here, so each one is
# fingerprinted by file count and a digest over every file's mtime and name.
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

echo "== 0. the images, and what this probe is about to cost =="
echo
say "the packaging round's section 9 measures an assessment; this probe measures the"
say "open itself.  Both packages that exist in dist/ go through the same walk: copy"
say "out of the image with ditto, set the download flag, double-click, clear the flag"
say "the way right-click -> Open does, double-click again, and then ask whether the"
say "copy that just ran is still the bytes that shipped and still seals."
echo
for d in dist/shadowrun-0.1.0-macos-arm64.dmg dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg; do
  if [ ! -f "$d" ]; then
    say "MISSING: $d -- build it with scripts/package_macos_bundle.sh first"
    exit 1
  fi
  printf '  %-52s %10s B  sha256 %s\n' "$(basename "$d")" "$(stat -f%z "$d")" "$(sha "$d")"
done
say "a .dmg hash pins one run rather than one build, so the payload hashes inside are"
say "the figures that repeat across rounds; they are printed per package below."
echo
say "two costs of doing this for real, stated before the legs rather than after:"
say "  * the legs start through LaunchServices, so their \$HOME is whatever 'open'"
say "    relays.  They are given a private one, $STATE_HOME, and section"
say "    6 checks this machine's real ~/Library/Application Support/ before and after"
say "    to show the relay held.  A test has no business rewriting a person's saves."
say "  * the successful open legs are not headless: a real window and a real audio"
say "    device open for the length of $SCRIPT -- 60 emulated frames, a couple of"
say "    seconds of wall clock per run -- which is what makes them the click path"
say "    rather than another dummy-driver re-run."
say "how each open is read back, because 'open' does not report the app's outcome:"
say "  the leg looks for a process of this bundle by the tail of its executable path,"
say "  records the pid and the path it saw, and then reads the run report the host"
say "  writes on its way out -- the only thing a LaunchServices start leaves behind."
say "  Matching the tail rather than the path the leg opened is not a detail: a bundle"
say "  that still carries the download flag can be translocated by macOS, run from a"
say "  randomised read-only path rather than from the copy on disk, and an earlier pass"
say "  of this probe printed 'no process at all' for legs whose processes were on the"
say "  machine the whole time, held at exec.  Each leg ends by stopping whatever it"
say "  left, so a leftover is never read as the next leg's process and no app stays on"
say "  the user's screen.  macOS's own syspolicyd and CoreServicesUIAgent log lines for"
say "  the same window are printed too, because that is where a refusal would be"
say "  recorded in the system's words."
say "three waits rather than one, and one of them is a cost paid on the user's screen:"
say "  * ${NO_PID_WAIT}s with no process at all ends a leg, because"
say "    'open -W' never returns when LaunchServices refuses the launch -- measured, its"
say "    own wait sits there forever -- so waiting out a longer cap would buy the same"
say "    answer and leave Gatekeeper's sheet on the screen the whole time."
say "  * ${DENY_WAIT}s caps a leg whose point is that it gets refused: measured on this"
say "    machine, syspolicyd logs its own decision for this bundle about nine seconds"
say "    after its prompt, so anything past that is only waiting."
say "  * ${OPEN_WAIT}s is the cap for a leg that started something and would not"
say "    end, which is the shape of a window this harness cannot answer; such a leg is"
say "    stopped by signal and recorded as hung."
say "one thing is counted as a finding rather than written as prose: if the word 'damag'"
say " appears in what those two system agents logged about either open, that is the"
say " sentence this port's state-out-of-the-bundle fix exists to make impossible, and the"
say " leg that printed it fails the run."
if [ "$ROM_LEG" = with ]; then
  rom_repo="$(sr_rom)" || { say "no ROM to run; refusing"; exit 1; }
  script_repo="$SCRIPT"
  # Both files this probe names on the app's command line are copied into this pass's own
  # scratch directory before any leg uses them, and that is a measurement rather than
  # tidiness: an earlier pass caught a copy started through LaunchServices sitting inside
  # open() of a ROM that lived in this repository, which is under ~/Documents, and section
  # 6 measures that folder question in full.  Naming them where they already sit would
  # measure the folder rather than the payload, so every leg below gets the staged copies
  # and section 6 is the only place the repository paths are used.
  STAGED="$SCRATCH_ROOT/staged"
  mkdir -p "$STAGED"
  cp "$rom_repo" "$STAGED/Shadowrun.sfc"
  cp "$script_repo" "$STAGED/shorter.txt"
  rom="$STAGED/Shadowrun.sfc"
  SCRIPT="$STAGED/shorter.txt"
  say "the shareable legs pass --no-launcher and --rom, so nothing here can stop at a"
  say "ROM file picker:"
  say "  ROM given to the legs:    $rom"
  say "  script given to the legs: $SCRIPT"
  say "  staged out of:            $rom_repo"
  say "                          and $script_repo"
  say "  sizes: $(stat -f%z "$rom") B and $(stat -f%z "$SCRIPT") B, sha256 $(sha "$rom") and $(sha "$SCRIPT")"
else
  rom=""; rom_repo=""; script_repo="$SCRIPT"
  say "ROM_LEGS=none: legs run without --rom, which for the shareable package means"
  say "whatever rom.cfg the state directory already caches.  This is a diagnostic mode"
  say "only: every shipped leg passes --rom, so a pass run this way says nothing about"
  say "what a person gets."
fi
echo

for pkg in shareable personal; do
  PKG="$pkg"
  if [ "$pkg" = shareable ]; then
    dmg="dist/shadowrun-0.1.0-macos-arm64.dmg"; APP_NAME="Shadowrun"
    romnote="its legs pass --rom, and the payload has no image in it at all"
  else
    dmg="dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg"; APP_NAME="Shadowrun-personal"
    romnote="its legs pass neither --rom nor a rom.cfg, because the guest is compiled into the payload"
  fi
  SCRATCH="$SCRATCH_ROOT/$pkg"
  MP="$SCRATCH_ROOT/mnt-$pkg"
  APP="$SCRATCH/$APP_NAME.app"

  echo "== 1.$pkg: copying $APP_NAME.app out of the image the way a drag does =="
  echo
  rm -rf "$SCRATCH" "$MP"
  mkdir -p "$SCRATCH" "$MP"
  if ! hdiutil attach -nobrowse -readonly -mountpoint "$MP" "$dmg" >"$OUT/attach-$pkg.txt" 2>&1; then
    say "hdiutil attach failed:"
    sed 's/^/      /' "$OUT/attach-$pkg.txt"
    exit 1
  fi
  say "mounted read-only at $MP"
  if ! ditto "$MP/$APP_NAME.app" "$APP"; then
    say "ditto failed"
    exit 1
  fi
  hdiutil detach "$MP" 2>&1 | sed 's/^/      /'
  say "ditto is the copy a drag-and-drop performs, xattrs and all, so the copy under"
  say "test here is what a person gets rather than what this machine staged."
  exe="$APP/Contents/MacOS/$APP_NAME"
  printf '  copy under test            %s   %s B\n' "$(sha "$exe")" "$(stat -f%z "$exe")"
  before_list="$(find "$SCRATCH" | sort)"
  before_n=$(count "$before_list")
  before_hash="$(printf '%s\n' "$before_list" | shasum | cut -c1-16)"
  printf '  bundle before any of it    %s entries, tree hash %s\n' "$before_n" "$before_hash"
  say "  (the listing is a find over the directory holding the .app, which is the"
  say "   listing the packaging log takes over its own staging copy, so the entry"
  say "   counts are the same kind of figure -- 11 there as well -- while the hashes"
  say "   are digests over different absolute paths and are not expected to match."
  say "   The payload digest above is what ties this copy to the one that shipped.)"
  say "its seal before anything has been done to it:"
  verdict "  codesign --verify --strict --verbose=2" codesign --verify --strict --verbose=2 "$APP"
  if [ "$RC" != 0 ]; then problems=$((problems + 1)); fi
  echo

  echo "== 2.$pkg: before any open, can this machine exec these bytes at all? =="
  echo
  say "one question asked first, because a machine that cannot exec this code signature"
  say "makes every leg below print a tidy-looking nothing while measuring nothing:"
  say "is the exec of these bytes being held by macOS right now?"
  if ! held_at_exec "$APP_NAME" "$exe"; then
    problems=$((problems + 1))
    echo
    say "STOP: this machine is holding exec of these bytes at this path, so an open leg"
    say "here cannot tell a refusal from a hold and no leg below can measure a run.  The"
    say "condition is measured, not assumed, and its shape is in the section above: a"
    say "process at dyld's entry point with nothing but its own Mach-O and /usr/lib/dyld"
    say "mapped.  tests/macos_exec_hold_probe.sh measures what puts a directory into it"
    say "(stopping a process macOS is holding at exec, at that directory) and what gets"
    say "out of it (renaming that directory; not the download flag, not spctl, not"
    say "re-registering the bundle).  A pass of this probe takes a scratch directory of"
    say "its own for that reason, so a pass that lands here has a name to look at:"
    say "  $SCRATCH_ROOT"
    exit 1
  fi
  say "  exec is not held, so the legs that have to run the app can tell the difference"
  say "  between running, being refused, and being held."
  echo

  echo "== 3.$pkg: the copy with the download flag cleared, and the double-click after it =="
  echo
  say "this leg runs before the refusal leg on purpose.  A refused launch can leave a"
  say "process held at exec while macOS waits for a sheet nobody in this run answers, and"
  say "on this machine a path that had held one was measured still refusing to exec"
  say "afterwards -- see section 2.$pkg above and the end of section 7.  The claim"
  say "that has to be measured here, that the copy a person ends up with after"
  say "right-click -> Open starts, is therefore taken first, while the path is known to"
  say "be able to run it."
  say "macOS's own wording for an unverified download is right-click the app, choose"
  say "Open, then Open again in the sheet.  What that does to the files on disk is"
  say "remove the quarantine flag, and the command the README at the image root tells"
  say "a person to type does the same thing, so it is done here rather than guessed."
  say "  attached data on the copy (expect nothing):"
  xattr -l "$APP" | sed 's/^/      /'
  xattr -l "$exe" | sed 's/^/      /'
  verdict "  Gatekeeper's assessment of the copy with no flag on it:" spctl -a -vv -t execute "$APP"
  say "  rejected is expected here too: an ad hoc, unnotarised signature never passes an"
  say "  assessment.  So the assessment is not what makes the app start for a person --"
  say "  their explicit choice, remembered by LaunchServices, is.  Which means the"
  say "  double-click below is the measurement, and this line is not."
  leg "flag-off-$pkg"
  OPEN_OFF_RC=$OPEN_RC
  OPEN_PID_SEEN_OFF=$OPEN_PID_SEEN
  say "   reading the state directories for the run this leg should have written:"
  reports_since "$OPEN_T0"
  RAN_OFF=$RAN_SEEN
  system_words "$OPEN_T0"
  GK_OFF=$GK_REJECTED
  DM_OFF=$DAMAGED_LINES
  echo

  echo "== 4.$pkg: the flag put back on, and the double-click that gets refused =="
  echo
  say "the flag a browser leaves on a download, set by hand here because nothing"
  say "downloaded this file -- the .dmg this machine built carries no flag at all, so"
  say "the flag has to be put on deliberately for the refusal to be measurable."
  xattr -w com.apple.quarantine "0081;$(printf '%08x' "$(date +%s)");Chrome;" "$APP" \
    && say "flag now on the copy: $(xattr -p com.apple.quarantine "$APP")"
  verdict "  Gatekeeper's assessment with the flag on:" spctl -a -vv -t execute "$APP"
  say "  (rejected is expected and is not this probe's finding: it is the ad hoc,"
  say "   unnotarised signature.  What is being looked for is the sentence a person"
  say "   is shown when they open it, which an assessment does not produce.)"
  verdict "  the seal, with that same flag on the bundle:" codesign --verify --strict --verbose=2 "$APP"
  if [ "$RC" != 0 ]; then
    problems=$((problems + 1))
    say "  the download flag broke the seal: that would be a real finding."
  else
    say "  the seal still validates with the flag on, so this copy is not broken in"
    say "  the sense 'damaged' means -- which is the half the payload fix controls."
  fi
  say "'open' is the path a double-click takes: LaunchServices, working directory"
  say "'/', no terminal, and the app's own drivers rather than dummy ones.  $romnote."
  leg "flag-on-$pkg"
  OPEN_ON_RC=$OPEN_RC
  OPEN_PID_SEEN_ON=$OPEN_PID_SEEN
  say "   reading the state directories for a run report this leg may have written:"
  reports_since "$OPEN_T0"
  RAN_ON=$RAN_SEEN
  system_words "$OPEN_T0"
  GK_ON=$GK_REJECTED
  DM_ON=$DAMAGED_LINES
  if [ "$DM_ON" != 0 ] || [ "$DM_OFF" != 0 ]; then
    problems=$((problems + 1))
  fi
  echo

  echo "== 5.$pkg: the copy that just ran, asked whether it is still the bytes that shipped =="
  echo
  printf '  payload after the open legs  %s\n' "$(sha "$exe")"
  after_list="$(find "$SCRATCH" | sort)"
  after_n=$(count "$after_list")
  after_hash="$(printf '%s\n' "$after_list" | shasum | cut -c1-16)"
  printf '  bundle before the legs       %s entries, tree hash %s\n' "$before_n" "$before_hash"
  printf '  bundle after the legs        %s entries, tree hash %s\n' "$after_n" "$after_hash"
  UNCHANGED=0
  if [ "$before_hash" = "$after_hash" ] && [ "$before_n" = "$after_n" ]; then
    UNCHANGED=1
    if [ "$RAN_OFF" = 1 ]; then
      say "  unchanged: the app wrote nothing inside itself, through two open attempts,"
      say "  a real window, a scripted boot and a save.  That is the property the"
      say "  'is damaged' report says a copy of this port used to fail."
    else
      say "  unchanged -- but no leg brought the app up for this package, so that word"
      say "  buys nothing here: the copy would read the same had nothing touched it."
      say "  Read sections 3.$pkg and 4.$pkg for what the two opens actually did."
    fi
  else
    problems=$((problems + 1))
    UNCHANGED=0
    say "  CHANGED.  Diff of the two listings:"
    diff <(printf '%s\n' "$before_list") <(printf '%s\n' "$after_list") | sed 's/^/      /'
    say "  a bundle that gains files while it runs cannot hold a seal, which is the"
    say "  shape every earlier round of this port shipped."
  fi
  verdict "  its seal, asked after the run:" codesign --verify --strict --verbose=2 "$APP"
  SEAL_AFTER_RC=$RC
  if [ "$RC" != 0 ]; then problems=$((problems + 1)); fi
  say "  the directory holding the executable, after all of that -- every file in it"
  say "  other than the binary itself, which is where the pre-fix host wrote config.ini,"
  say "  keybinds.ini, rom.cfg and saves/ while running from inside a bundle:"
  (cd "$APP/Contents/MacOS" && find . -type f ! -name "$APP_NAME" | sort | sed 's/^/      /')
  say "  (expect nothing above: only the executable, which is why the whole-bundle"
  say "   seal is possible at all)"
  if [ "$RAN_ON" = 1 ]; then
    on_words="the app came up as pid $OPEN_PID_SEEN_ON"
  elif [ -n "$OPEN_PID_SEEN_ON" ]; then
    on_words="a process appeared (pid $OPEN_PID_SEEN_ON, path printed in section 4.$pkg)"
    on_words="$on_words but never wrote a run report, so it never reached the guest"
  elif [ "$GK_ON" != 0 ]; then
    on_words="the app did not come up, and $GK_ON line(s) in section 4.$pkg are macOS's"
    on_words="$on_words own words for Gatekeeper refusing this bundle by name"
  else
    on_words="the app did not come up and nothing in section 4.$pkg says why"
  fi
  if [ "$RAN_OFF" = 1 ]; then
    off_words="the app came up as pid $OPEN_PID_SEEN_OFF"
  elif [ -n "$OPEN_PID_SEEN_OFF" ]; then
    off_words="a process appeared (pid $OPEN_PID_SEEN_OFF) and never wrote a run report"
  elif [ "$GK_OFF" != 0 ]; then
    off_words="still refused, with $GK_OFF line(s) in section 3.$pkg to that effect"
  else
    off_words="the app did not come up and nothing in section 3.$pkg says why"
  fi
  RESULTS="$RESULTS
  $pkg ($APP_NAME), flag on: $on_words ('open' exit $OPEN_ON_RC).  After the override: $off_words ('open' exit $OPEN_OFF_RC).  Through both, the copy kept $( [ "$UNCHANGED" = 1 ] && echo "the same entries and the same tree hash" || echo "CHANGED entries or tree hash" ), and its seal afterwards exits $SEAL_AFTER_RC.  The word 'damag' in macOS's own lines for the two legs: $DM_ON and $DM_OFF."
  if [ "$RAN_OFF" != 1 ]; then
    problems=$((problems + 1))
    RESULTS="$RESULTS
    NOTE: $pkg never came up on the second open, so the click path is not measured for it and nothing in section 5.$pkg says the payload runs."
  fi
  echo
done

echo "== 6. the folder a named path sits in, when the copy is started by a click =="
echo
say "every leg above names files this probe staged in its own scratch directory, and that"
say "is a measurement rather than tidiness: an earlier pass of this probe caught a copy"
say "started by 'open' with no run report and no guest, sitting inside the open() of a ROM"
say "file that lives in this repository, and this repository sits under ~/Documents.  So"
say "the folder question is measured here, in the click path rather than from a shell, and"
say "the same bundle and the same bytes are used in each leg:"
say "  a. the ROM path inside this repository, the script staged;"
say "  b. the same ROM staged in this pass's own directory, the script staged;"
say "  c. the ROM staged, the script inside this repository -- a script the app cannot read"
say "     is a run that never receives its scripted quit, which looks like a hang."
say "each leg is given a real window and audio driver, as the click path is, and is stopped"
say "after ${FOLDER_WAIT}s whether or not it has finished.  Only leg a and leg c read this"
say "repository's own ROM file, and nothing here writes to it or to the script: the question"
say "is where a person's files sit, not what they contain."
say "the personal package is not part of this section: its guest is inside the executable"
say "and no leg gives it a file path it would have to read."
echo
FOLDER_DIR=""
if [ "$ROM_LEG" != with ]; then
  say "ROM_LEGS=none: no leg of this pass names a ROM path at all, so there is no folder"
  say "question to ask here."
else
FOLDER_DIR="$SCRATCH_ROOT/folder"
rm -rf "$FOLDER_DIR"
mkdir -p "$FOLDER_DIR"
hdiutil attach -nobrowse -readonly -mountpoint "$SCRATCH_ROOT/mnt-folder" \
  dist/shadowrun-0.1.0-macos-arm64.dmg >/dev/null 2>&1
ditto "$SCRATCH_ROOT/mnt-folder/Shadowrun.app" "$FOLDER_DIR/Shadowrun.app" 2>/dev/null
hdiutil detach "$SCRATCH_ROOT/mnt-folder" >/dev/null 2>&1
FOLDER_APP="$FOLDER_DIR/Shadowrun.app"
if [ ! -x "$FOLDER_APP/Contents/MacOS/Shadowrun" ]; then
  say "no copy at $FOLDER_APP, so this section measures nothing."
else
  say "a fresh copy out of the shareable image, in a directory of this section's own:"
  printf '    payload %s  %s B  cdhash %s\n' \
    "$(sha "$FOLDER_APP/Contents/MacOS/Shadowrun" | cut -c1-16)" \
    "$(stat -f%z "$FOLDER_APP/Contents/MacOS/Shadowrun")" \
    "$(codesign -dvvv "$FOLDER_APP/Contents/MacOS/Shadowrun" 2>&1 | awk -F= '/^CDHash=/{print $2;exit}')"
  say "asked whether that directory can exec it before any leg has stopped anything:"
  exec_at "folder-pre" "$FOLDER_APP/Contents/MacOS/Shadowrun" Shadowrun "$PREFLIGHT_HOME" \
    --no-launcher --rom "$rom" --script "$SCRIPT"
  echo
  say "leg a: the ROM where this repository keeps it -- $rom_repo"
  FOLDER_T0=$(date +%s)
  folder_leg "rom-in-repo" "$FOLDER_APP" "$STATE_HOME" --no-launcher --rom "$rom_repo" --script "$SCRIPT"
  A_ALIVE=$FOLDER_ALIVE; A_REP=$FOLDER_REP
  echo
  say "leg b: the same bytes of ROM, staged in this pass's own directory -- $rom"
  folder_leg "rom-staged" "$FOLDER_APP" "$STATE_HOME" --no-launcher --rom "$rom" --script "$SCRIPT"
  B_ALIVE=$FOLDER_ALIVE; B_REP=$FOLDER_REP
  echo
  say "leg c: the input script where this repository keeps it -- $script_repo"
  folder_leg "script-in-repo" "$FOLDER_APP" "$STATE_HOME" --no-launcher --rom "$rom" --script "$script_repo"
  C_ALIVE=$FOLDER_ALIVE; C_REP=$FOLDER_REP
  echo
  say "the three answers, in one place: still there at ${FOLDER_WAIT}s / run report newer"
  say "than the leg.  A leg that finished on its own and left a report is a run; a leg still"
  say "sitting there with no report is a process waiting on something."
  printf '    %-34s still there=%s  run report=%s\n' "a. ROM in this repository" "$A_ALIVE" "$A_REP"
  printf '    %-34s still there=%s  run report=%s\n' "b. same ROM, staged outside" "$B_ALIVE" "$B_REP"
  printf '    %-34s still there=%s  run report=%s\n' "c. script in this repository" "$C_ALIVE" "$C_REP"
  say "(1 = yes, 0 = no; the sampler's frames and the lsof lines above name what each"
  say "still-standing process was waiting on, in macOS's own words)"
  if [ "$B_REP" = 1 ] && [ "$A_REP" != 1 ]; then
    say "  so on this machine the same bundle, the same bytes, the same arguments and the"
    say "  same \$HOME ran when the ROM sat outside ~/Documents and did not finish a run when"
    say "  the same bytes sat inside it.  That is the reason every other leg of this probe"
    say "  names staged copies: without it a leg measures the folder, not the payload."
  elif [ "$B_REP" != 1 ]; then
    problems=$((problems + 1))
    say "  leg b, the leg that should have been an ordinary run, has no run report, so this"
    say "  section cannot separate the folder from the payload and the click path is not"
    say "  measured by this pass.  Read the sampler's frames above."
  fi
  if [ "$C_REP" != 1 ] && [ "$B_REP" = 1 ]; then
    say "  leg c differs from leg b only in where the input script sits, and it too has no"
    say "  report, so the folder question is about any file the app is handed, not only the"
    say "  ROM."
  fi
  echo
  say "what macOS's own agents logged across these three legs, from just before the first"
  say "one: tccd answers a request to read a protected folder, sandboxd enforces a"
  say "container, and syspolicyd plus CoreServicesUIAgent are the Gatekeeper pair.  Their"
  say "lines are printed here because the sampler says where the process is waiting, and"
  say "only these processes can say why."
  # The raw window first, then the two filters, and the counts of each printed next to
  # the excerpt.  Without those counts an excerpt reads like the whole of what macOS
  # said, and a section whose answer is "the system said nothing" needs the number of
  # lines that were looked at to mean anything.
  fraw="$(log show --start "$(date -r "$((FOLDER_T0 - 1))" '+%Y-%m-%d %H:%M:%S')" --info --style compact \
        --predicate 'process == "tccd" OR process == "sandboxd" OR process == "syspolicyd" OR process == "CoreServicesUIAgent"' 2>/dev/null || true)"
  flog="$(printf '%s\n' "$fraw" \
        | grep -viE 'xpc:connection|activating connection|boringssl|connect_block_invoke|nw_[a-z_]*_handler' \
        | grep -iE "$FOLDER_WORDS" | head -40 || true)"
  fall="$(printf '%s\n' "$fraw" \
        | grep -viE 'xpc:connection|activating connection|boringssl|connect_block_invoke|nw_[a-z_]*_handler' \
        | grep -iE "$FOLDER_WORDS" || true)"
  f_tot=$(printf '%s\n' "$fraw" | grep -c '' || true); f_tot=${f_tot:-0}
  f_kep=$(printf '%s\n' "$fall" | grep -c '' || true); f_kep=${f_kep:-0}
  if [ -z "$fall" ]; then f_kep=0; fi
  f_dny=$(printf '%s\n' "$fall" | grep -icE 'denied|deny|promptPolicy|prompt_type' || true); f_dny=${f_dny:-0}
  # The two excerpts answer different questions.  The first is the window in time
  # order, so the legs can be read in sequence.  The service that answers a request
  # for a protected folder names itself in every line it logs about one, and those
  # lines can sit anywhere in the window, so they are pulled out on their own rather
  # than hoped to fall inside the first 40.
  fallf="$(printf '%s\n' "$fall" | grep -iE 'SystemPolicyAllFiles' || true)"
  f_af=$(printf '%s\n' "$fallf" | grep -c '' || true); f_af=${f_af:-0}
  if [ -z "$fallf" ]; then f_af=0; fi
  say "  before the excerpt, the counts: $f_tot line(s) logged by those four processes in"
  say "  that window, $f_kep of them match $FOLDER_WORDS once connection chatter is"
  say "  filtered out, and $f_dny of those name a denial or a prompt."
  if [ -z "$flog" ]; then
    say "  (no matching lines from those four processes in that window -- macOS logged"
    say "   nothing about a folder request for these legs, so the sampler's frames and the"
    say "   run reports above are the whole of what this machine said about it)"
  else
    say "  the first 40 of those $f_kep, in time order:"
    printf '%s\n' "$flog" | sed 's/^/    /'
  fi
  echo
  if [ "$f_af" = 0 ]; then
    say "and of those $f_kep, none names the service that answers a request for a"
    say "protected folder, kTCCServiceSystemPolicyAllFiles.  So this machine did not log"
    say "answering the request the parked open() is waiting on, which is a finding in its"
    say "own right rather than an absence to read past."
    problems=$((problems + 1))
  else
    say "and the $f_af of those $f_kep that name kTCCServiceSystemPolicyAllFiles, the"
    say "service whose answer is a yes or no about reading a folder a person keeps files"
    say "in.  Those lines are the system's own answer to the request the parked open() is"
    say "waiting on, so they are printed here in full rather than as a count: the time-"
    say "ordered excerpt above can stop before they come."
    printf '%s\n' "$fallf" | sed 's/^/    /'
  fi
  echo
  say "and the leftover check for this section: $(app_procs Shadowrun | wc -l | tr -d ' ') process(es) of"
  say "Shadowrun still alive now these three legs are over."
fi
fi
echo

echo "== 7. where the state the legs produced actually went, and the real home checked =="
echo
say "what the private \$HOME now holds -- this is the state the opened apps created,"
say "in exactly the shape a person would find it in, and the listing is the evidence"
say "that the run left config.ini, keybinds.ini, rom.cfg, saves/ and the mod catalog"
say "outside the .app rather than inside it."
if [ -d "$STATE_HOME/Library/Application Support" ]; then
  find "$STATE_HOME" -mindepth 1 | sort | sed "s|^$STATE_HOME|.|" | sed 's/^/  /'
else
  say "  nothing: no leg got far enough to create a state directory."
fi
say "the state directory name the app chose is printed above rather than assumed here."
echo
say "and the check that the relay held: this machine's own ~/Library/Application"
say "Support/, fingerprinted before the legs and again now.  A new directory, a"
say "different file count, or a different fingerprint inside a directory that was"
say "already here, would all mean the legs wrote into this person's state after all."
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
  say "  identical, which is the condition: the legs wrote inside the private \$HOME"
  say "  above and a person running this probe loses nothing."
else
  problems=$((problems + 1))
  say "  different.  The \$HOME relay did not hold, and these legs reached this"
  say "  machine's real state after all.  Nothing here removes or rewrites anything to"
  say "  put that right -- taking a save file away to tidy up a log is worse than"
  say "  leaving a finding on the page -- so it is reported for a human to judge."
fi
say "removing a directory here costs an app its settings, saves and cached ROM path --"
say "which is the point of it living outside the bundle rather than inside it."
echo

say "the last witness, and the one that speaks to the exact sentence this port exists"
say " to answer: when a process dies, macOS writes a report to"
say " ~/Library/Logs/DiagnosticReports/ named for the executable, and the listing"
say " below is every report that directory holds whose name matches either bundle."
say " How far back that listing reaches is printed rather than assumed:"
ips_all="$(find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 2 -name '*.ips' 2>/dev/null | sort)"
ips_n=$(printf '%s\n' "$ips_all" | grep -c '\.ips$' || true); ips_n=${ips_n:-0}
ips_first="$(printf '%s\n' "$ips_all" | head -1)"
say "  $ips_n report(s) in that directory, oldest by name: ${ips_first##*/}"
say " A copy macOS calls 'damaged' never reaches that directory, because the refusal"
say " happens in LaunchServices before any process exists; so an empty listing for"
say " these two executables is the shape of 'nothing of mine crashed', and a"
say " non-empty one is a crash to read."
ips_now="$(find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 2 -iname '*shadow*' 2>/dev/null | sort)"
if [ -z "$ips_now" ]; then
  say "  none.  No report in that directory, including ones this machine wrote long"
  say "  before this run, names Shadowrun or Shadowrun-personal -- so no process from"
  say "  either package ever died and wrote one, and the legs above ran both packages to"
  say "  a scripted quit with their own window and audio driver."
else
  problems=$((problems + 1))
  printf '%s\n' "$ips_now" | sed 's/^/      /'
  say "  ^ a crash report for one of these two executables exists.  Read it: a process"
  say "    that dies is a different complaint from a Gatekeeper refusal, and the two"
  say "    must not be conflated in the log's own summary."
fi
echo

say "the last check on the machine itself: every process belonging to either bundle"
say " that is still alive now the legs are over.  A refused leg can leave one"
say " behind -- macOS translocates a quarantined bundle and holds the process at exec"
say " while its sheet waits -- and such a process is invisible to a leg that only"
say " looks for the path it opened, so each leg stops what it left and this is the"
say " check that nothing slipped through: a live app left here is the test using the"
say " person's screen as its scratch space."
for n in Shadowrun Shadowrun-personal; do
  left="$(app_procs "$n")"
  if [ -n "$left" ]; then
    problems=$((problems + 1))
    printf '%s\n' "$left" | sed 's/^/      /'
    clean_apps "$n" "at the end of the run"
  else
    say "  $n: none"
  fi
done
echo

say "one last witness, and it is about this pass rather than about the payload.  The"
say "refusal leg stops a process macOS was holding at exec, and that act is measured --"
say "in tests/macos_exec_hold_probe.sh -- to leave the bundle's own directory unable to"
say "exec at that path, for as long as watching lasted and for every file inside that"
say "directory, while the same machine code at any other path runs normally.  So the"
say "directories this pass used are asked whether they can still run their app, and if"
say "they cannot, the measured way out is applied: renaming the directory, and then the"
say "same question asked after the rename and after putting it back.  A person should not"
say "be left with a directory whose app will not start because a test stopped something."
HELD_LEFT=0
PATHS_ASKED=0
for pkg in shareable personal folder; do
  if [ "$pkg" = personal ]; then APP_NAME="Shadowrun-personal"; else APP_NAME="Shadowrun"; fi
  if [ "$pkg" = folder ]; then dir="$FOLDER_DIR"; else dir="$SCRATCH_ROOT/$pkg"; fi
  if [ -z "$dir" ]; then
    say "  folder: this pass never made the section 6 copy, so there is nothing to ask there."
    continue
  fi
  app2="$dir/$APP_NAME.app"; exe2="$app2/Contents/MacOS/$APP_NAME"
  if [ ! -x "$exe2" ]; then
    say "  $pkg: nothing at $app2 to ask; this pass never got a copy there."
    continue
  fi
  PATHS_ASKED=$((PATHS_ASKED + 1))
  say "  $pkg:"
  if [ "$pkg" = personal ]; then
    exec_at "post-$pkg" "$exe2" "$APP_NAME" "$PREFLIGHT_HOME" --no-launcher --script "$SCRIPT"
  else
    exec_at "post-$pkg" "$exe2" "$APP_NAME" "$PREFLIGHT_HOME" --no-launcher --rom "$rom" --script "$SCRIPT"
  fi
  if [ "$EXEC_HELD" = 1 ]; then
    HELD_LEFT=$((HELD_LEFT + 1))
    say "     held, which is what the refusal leg's stop predicts.  Renaming the"
    say "     directory is the remedy that measured clear, so it is applied here:"
    if mv "$dir" "$dir-cleared" 2>/dev/null; then
      say "     $dir -> $dir-cleared"
      if [ "$pkg" = personal ]; then
        exec_at "renamed-$pkg" "$dir-cleared/$APP_NAME.app/Contents/MacOS/$APP_NAME" "$APP_NAME" \
          "$PREFLIGHT_HOME" --no-launcher --script "$SCRIPT"
      else
        exec_at "renamed-$pkg" "$dir-cleared/$APP_NAME.app/Contents/MacOS/$APP_NAME" "$APP_NAME" \
          "$PREFLIGHT_HOME" --no-launcher --rom "$rom" --script "$SCRIPT"
      fi
      if [ "$EXEC_HELD" = 1 ]; then
        problems=$((problems + 1))
        say "     still held after the rename, so this pass has left a directory that"
        say "     cannot start its app, and the remedy that measured clear on this"
        say "     machine for the tests/macos_exec_hold_probe.sh case did not measure"
        say "     clear here.  Read the two lines above as the finding."
      fi
      if mv "$dir-cleared" "$dir" 2>/dev/null; then
        say "     and back again: $dir-cleared -> $dir"
        if [ "$pkg" = personal ]; then
          exec_at "again-$pkg" "$exe2" "$APP_NAME" "$PREFLIGHT_HOME" --no-launcher --script "$SCRIPT"
        else
          exec_at "again-$pkg" "$exe2" "$APP_NAME" "$PREFLIGHT_HOME" --no-launcher --rom "$rom" --script "$SCRIPT"
        fi
        if [ "$EXEC_HELD" = 1 ]; then
          problems=$((problems + 1))
          say "     the original path is held again after the round trip, so the only"
          say "     thing this pass can say is that its copies now live at $dir-cleared"
          say "     and that the path it used for the legs cannot start them."
        fi
      else
        problems=$((problems + 1))
        say "     the rename back failed, so this pass leaves the copy at $dir-cleared"
        say "     and says nothing about the original path."
      fi
    else
      problems=$((problems + 1))
      say "     the rename failed, so nothing was done to it."
    fi
  fi
done
if [ "$HELD_LEFT" = 0 ]; then
  say "  none of the $PATHS_ASKED paths asked about is held: the stops this pass made left"
  say "  nothing behind, so the next pass of this probe, or a person dragging these copies"
  say "  somewhere else, is not walking into a path that cannot exec."
else
  say "  $HELD_LEFT of the $PATHS_ASKED paths were held at the end, as the refusal legs'"
  say "  stops predict; the rename lines above say what happened to each one, and each pass"
  say "  of this probe takes a directory of its own ($SCRATCH_ROOT) so that condition is"
  say "  never the starting point of a later pass."
fi
echo

echo "== 8. the three questions, per package =="
echo
printf '%s\n' "$RESULTS"
echo
if [ "$problems" = 0 ]; then
  say "nothing unexpected: every copy under test sealed before and after being opened,"
  say "and no copy gained a file inside itself while it ran.  Gatekeeper's refusal of an"
  say "ad hoc signature is the one refusal this machine cannot make go away, and it is"
  say "measured rather than argued about."
else
  say "$problems unexpected finding(s) above."
fi
echo
say "what this probe counts as unexpected, and what it therefore returns: $problems"
say "finding(s), and the exit status of this script is that number.  Read that as the"
say "summary of the sections above rather than as a verdict on its own: a 0 here means"
say "the things that matter held -- after the override each package came up, each copy"
say "kept the entries and tree hash it started with, each still sealed, no system line"
say "used the word 'damaged', no crash report exists for either executable, no process"
say "of either bundle is left running, and this machine's own state directory is byte"
say "for byte what it was before."
echo
echo "== DONE  (log: $LOG, exit status $problems) =="
exit "$problems"
