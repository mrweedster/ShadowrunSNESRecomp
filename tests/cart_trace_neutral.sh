#!/usr/bin/env bash
# Is the ROM-read observer (SNESRECOMP_CART_TRACE) inert?
#
# Three runs of one scenario, each starting from the same SRAM snapshot:
#   ctrl  control build   -- framework at the pin, no observer at all
#   off   observer build  -- SNESRECOMP_CART_TRACE unset (what a player runs)
#   on    observer build  -- SNESRECOMP_CART_TRACE=<file> (collector armed)
#
# Two questions, and they are different questions:
#   off vs ctrl  adding the seam to the framework changed nothing observable
#   on  vs off   arming the collector changed nothing observable
# A build can pass the first and fail the second (a collector that perturbs
# memory or ordering), and passing only the second says nothing about the code
# that every player executes.
#
# The measure is the WRAM crc32 of every --framedump frame, the same one
# tests/parity.sh uses; same-binary comparisons are byte-exact here, unlike the
# cross-path verdict. ctrl differs from the other two by one thing only: the
# framework source it linked. So a ctrl/off difference is the seam's doing, not
# noise -- which is why the manifest lines are printed: if the framework root
# moved for some other reason, this run is not the comparison it claims to be.
#
#   tests/cart_trace_neutral.sh                       # menu scenario
#   tests/cart_trace_neutral.sh tests/scripts/combat.txt
#   CTRL_BIN=./x OBS_BIN=./y tests/cart_trace_neutral.sh
#
# The ctrl leg is the only thing standing between "the seam changed nothing" and
# "a different program changed nothing", so its framework is checked against
# framework_pins.txt before any leg runs (tests/provenance.py pin). A build tree
# configured against a *copy* of the framework cannot pass that check -- the copy
# is only as current as the day it was copied -- so it is refused here rather
# than recorded in a verdict.
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
script="${1:-tests/scripts/menu.txt}"
rom=$(sr_rom) || exit 2
ctrl="${CTRL_BIN:-./build-pin/ShadowrunSNESRecomp}"
obs="${OBS_BIN:-./build-b0/ShadowrunSNESRecomp}"

# Before any leg runs: ctrl must link the pinned framework exactly, obs may be
# that revision plus the observer. Anything else and ctrl/off compares two
# programs instead of one seam. The strings are kept so the verdict file names
# the same check the gate applied.
pin_ctrl=$(python3 tests/provenance.py pin --exact "$ctrl") || {
  printf '%s\n' "$pin_ctrl" >&2
  echo "refusing to run: $ctrl is not a control at the pinned framework" >&2
  exit 2
}
pin_obs=$(python3 tests/provenance.py pin --descendant "$obs") || {
  printf '%s\n' "$pin_obs" >&2
  echo "refusing to run: $obs does not link a framework with the pin as an " \
       "ancestor" >&2
  exit 2
}
printf '%s\n%s\n' "$pin_ctrl" "$pin_obs"
out="$PWD/tests/out/ct_neutral"
trace_file="$out/collect.json"
# The two verdict lines and the provenance keys, in a stable path, so other
# tooling (tests/cart_trace_report.py --neutral) can fold them without depending
# on what the operator happened to redirect stdout into.
verdict="$out/verdict.txt"

export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
rm -rf "$out"
mkdir -p "$out/run_ctrl" "$out/run_off" "$out/run_on"

# Long routes write SRAM as they play, so every leg must start from the same
# save state -- into the directory each binary really anchors to (see the note
# in tests/parity.sh: a relative dump path against the wrong anchor is silent).
snap="$out/srm_snap"
mkdir -p "$snap"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$snap/$f"
done

restore_sram() { # $1 = binary
  local dir anchor
  dir=$(cd "$(dirname "$1")" && pwd)
  anchor="$dir/saves"
  mkdir -p "$anchor"
  [ -f "$snap/save.srm" ] && cp -p "$snap/save.srm" "$anchor/save.srm"
  [ -f "$snap/save.srm.bak" ] && cp -p "$snap/save.srm.bak" "$anchor/save.srm.bak"
}

run_leg() { # $1=label $2=binary $3=dump dir [$4=trace path]
  printf '%-5s %s\n' "$1" "$2"
  if [ ! -x "$2" ]; then
    echo "      not executable: $2" >&2
    return 1
  fi
  restore_sram "$2"
  if [ -n "${4:-}" ]; then
    SNESRECOMP_DUMP_DIR="$3" SNESRECOMP_CART_TRACE="$4" \
      "$2" --no-launcher --rom "$rom" --script "$script" --framedump "$3" >"$3.log" 2>&1
  else
    env -u SNESRECOMP_CART_TRACE SNESRECOMP_DUMP_DIR="$3" \
      "$2" --no-launcher --rom "$rom" --script "$script" --framedump "$3" >"$3.log" 2>&1
  fi
  grep -E '^\[host .*exit' "$3.log" | tail -1 | sed 's/^/      /' || true
  grep -vE '^\[host \+' "$3.log" | grep -iE 'error|cannot|fail' | head -3 | sed 's/^/      /' || true
  python3 tests/provenance.py record "$2" "$3" 2>&1 | sed 's/^/      /'
  printf '      frames=%s\n' "$(find "$3" -name 'frame_*.json' | wc -l | tr -d ' ')"
  return 0
}

rc=0
run_leg ctrl "$ctrl" "$out/run_ctrl" || rc=1
run_leg off  "$obs"  "$out/run_off"  || rc=1
run_leg on   "$obs"  "$out/run_on" "$trace_file" || rc=1

crc() { grep -o '0x[0-9A-Fa-f]\{8\}' "$1" 2>/dev/null | tail -1; }

# Both places, so the verdict is readable on screen and in $verdict for other
# tooling to fold. Lines are collected and emitted at the end of the comparison
# so nothing prints before rc is settled.
say() { printf '%s\n' "$1"; printf '%s\n' "$1" >>"$verdict"; }

compare() { # $1=label-a $2=dir-a $3=label-b $4=dir-b
  local a="$2" b="$4" same=0 diff=0 first="" base f g n2 msg=""
  shopt -s nullglob
  for f in "$a"/frame_*.json; do
    base=$(basename "$f")
    g="$b/$base"
    if [ ! -f "$g" ]; then
      [ -z "$first" ] && { first="$base"; n2=$(find "$b" -name 'frame_*.json' | wc -l | tr -d ' ')
        msg="$msg  $1/$3: first problem at $base ($3 stopped after $n2 frames)"$'\n'; }
      diff=$((diff + 1)); continue
    fi
    if [ "$(crc "$f")" = "$(crc "$g")" ]; then
      same=$((same + 1))
    elif [ -z "$first" ]; then
      first="$base"; msg="$msg  $1/$3: first divergence at $base: $(crc "$f") vs $(crc "$g")"$'\n'
      diff=$((diff + 1))
    else
      diff=$((diff + 1))
    fi
  done
  if [ "$diff" -eq 0 ]; then
    msg="$msg  $1/$3: identical over $same frames"
  else
    msg="$msg  $1/$3: $diff of $((same + diff)) frames differ"
    rc=1
  fi
  say "${msg%$'\n'}"
}

: >"$verdict"
say "scenario: $script"
say "$pin_ctrl"
say "$pin_obs"
say "frames:   ctrl=$(find "$out/run_ctrl" -name 'frame_*.json' | wc -l | tr -d ' ')  off=$(find "$out/run_off" -name 'frame_*.json' | wc -l | tr -d ' ')  on=$(find "$out/run_on" -name 'frame_*.json' | wc -l | tr -d ' ')"
echo
compare ctrl "$out/run_ctrl" off "$out/run_off"
compare off  "$out/run_off"  on  "$out/run_on"
echo
for n in ctrl off on; do
  line=$(printf '%-5s %s\n' "$n" "$(python3 tests/provenance.py key "$out/run_$n" 2>&1)")
  say "$line"
done
say "ctrl/off inputs: $(python3 tests/provenance.py same-src "$out/run_ctrl" "$out/run_off" 2>&1)"

if [ -f "$trace_file" ]; then
  echo
  echo "collected: $trace_file ($(wc -c < "$trace_file" | tr -d ' ') bytes)"
  python3 - "$trace_file" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
t = d.get("totals", {})
print("  schema=%s rom_size=%s block_bytes=%s" %
      (d.get("schema"), d.get("rom_size"), d.get("block_bytes")))
print("  totals=" + ", ".join("%s=%s" % (k, v) for k, v in t.items()))
print("  blocks=%d banks=%d pairs=%d" %
      (len(d.get("blocks", [])), len(d.get("banks", {})), len(d.get("pairs", []))))
PY
else
  echo "no trace file written by the armed leg" >&2
  rc=1
fi
exit $rc
