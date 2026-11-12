#!/usr/bin/env bash
# Idle-poll A/B: does declaring the game's frame waits move interpreted cost?
#
#   ./tests/idle_ab.sh                       # all legs, combat.txt
#   LEGS="off on" ./tests/idle_ab.sh         # just the A/B pair
#   LEGS="off m0x0:81b061" ./tests/idle_ab.sh      # one leg declaring one PC
#   IDLE_POLLS='81b061,81ee8e' ./tests/idle_ab.sh   # what the 'on' leg declares
#   BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_ab.sh
#
# A leg label is a cost row; `label:pc,pc` declares those PCs for that leg, a
# bare label (other than `on`) declares nothing.
#
# The question (evidence/m2_promotion_round2b.md section 5, measured by
# round 3): 96.94 % of the interpreted residue is never sighted at a transfer
# gap, so no [[func]] seed can intercept it. docs/IDLE_POLL.md names a second
# lever that works without an entry: declare the PC of an interrupt-wait poll
# and the bridge replays the wait's cycle to the deadline instead of
# interpreting it. No framework host fills that table in, so src/game_rtl.c
# owns it here, fed by SNESRECOMP_IDLE_POLLS.
#
# One route, one SRAM seed, one executable, and legs that differ by exactly
# one environment variable -- see the LEGS block below for the three.
#
# Why legs run from scratch copies: two binaries sharing an anchor directory
# fight over saves/, config.ini and last_run_report.json (tests/crosspath.sh
# refuses that outright). Each leg gets its own anchor under tests/out, and
# every leg is re-seeded from one master SRAM snapshot, because the route has
# no loadstate -- SRAM is the start state.
#
# ROM lookup: rom.cfg is read from the *executable's* directory, so a fresh
# scratch anchor has no cache and the host falls back to a file picker. Every
# leg therefore gets a rom.cfg staged beside its copy of the binary (tests/rom.sh
# writes it from the repo-root rom.cfg) AND an explicit --rom, so nothing on
# earth can stop mid-run to ask the user for a dump.
#
# The framework's guard set (docs/IDLE_POLL.md) promises a wrong declaration
# is a lost speedup, never a behaviour change. That promise is exactly what
# this leg cannot see, so the behaviour half is tests/idle_parity.sh.
#
# What a leg produces (leg = off / off2 / on):
#   tests/out/idle_<leg>.log                   host log (frames, exit, breadcrumbs)
#   tests/out/idle_<leg>_cov.json(+.jsonl)     capture, SNESRECOMP_TIER2_MANIFEST
#   tests/out/idle_<leg>_ingest.json           pinned tier2_ingest.py --json report
#   tests/out/idle_<leg>/last_run_report.json  that leg's execution_share

set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

bin="${BIN:-build-r3/ShadowrunSNESRecomp}"
script="${SCRIPT:-tests/scripts/combat.txt}"
out="${OUT:-tests/out}"
# One place decides which ROM every leg runs: tests/rom.sh. --rom plus a
# staged rom.cfg removes the executable-directory lookup, and with it the GUI
# file picker, from the picture entirely.
. tests/rom.sh
rom=$(sr_rom) || exit 1
# One executable, three legs, and the only difference is the environment:
#   off   the r3 binary, SNESRECOMP_IDLE_POLLS unset   (the control)
#   off2  same again                                   (determinism of the harness)
#   on    the r3 binary with the two waits declared     (the measurement)
# The off leg doubles as the check that the r3 host change reproduces the
# round-2b capture exactly: it must print the same cpu/master cycles and the
# same attributed interpreted cycles (919,307,323) that round 3 recorded.
# The pair being declared: waits on WRAM word $7E1C92, and the compare PC is
# what interp_bridge_set_idle_poll takes. $81b065/$81ee92 are their branches,
# so one declaration names one loop.
IDLE="${IDLE_POLLS:-81b061,81ee8e}"
LEGS="${LEGS:-off off2 on}"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

absbin=$(cd "$(dirname "$bin")" && printf '%s/%s\n' "$PWD" "$(basename "$bin")")
[ -x "$absbin" ] || { echo "not executable: $bin" >&2; exit 1; }
[ -f "$script" ] || { echo "no route: $script" >&2; exit 1; }

# One master SRAM copy; the repo-root saves/ is the canonical start state.
rm -rf "$out/idle_srm"; mkdir -p "$out/idle_srm"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$out/idle_srm/$f"
done
[ -f "$out/idle_srm/save.srm" ] || { echo "no saves/save.srm to seed from" >&2; exit 1; }

run_leg() { # $1 = label; env SNESRECOMP_IDLE_POLLS is set by the caller
  local leg="$1" anchor="$out/idle_$1" exe t0 t1 rc
  rm -rf "$anchor"; mkdir -p "$anchor"
  cp -p "$absbin" "$anchor/ShadowrunSNESRecomp"
  ln -sfn "$PWD/libs" "$anchor/libs"
  sr_rom_stage "$anchor"            # so the host never has to ask for a ROM
  exe="$anchor/ShadowrunSNESRecomp"
  rm -f "$out/idle_${leg}_cov.json" "$out/idle_${leg}_cov.jsonl" \
      "$anchor/last_run_report.json"
  mkdir -p "$anchor/saves"
  for f in save.srm save.srm.bak; do
    [ -f "$out/idle_srm/$f" ] && cp -p "$out/idle_srm/$f" "$anchor/saves/$f"
  done
  # The legs differ by exactly this: declared PCs, or none at all. The export
  # is set by the caller before each leg, not inside this function, because a
  # function-scoped unset would not shadow an exported value.
  echo "== idle_$leg  anchor=$anchor  polls=${SNESRECOMP_IDLE_POLLS:-none}"
  t0=$(date +%s)
  ( export SNESRECOMP_TIER2_MANIFEST="$PWD/$out/idle_${leg}_cov.json"
    "$exe" --no-launcher --rom "$rom" --coverage-capture=on \
      --script "$PWD/$script" >"$out/idle_$leg.log" 2>&1 )
  rc=$?
  t1=$(date +%s)
  echo "   exit=$rc wall=$((t1 - t0))s  $(grep -oE 'exit: .*' "$out/idle_$leg.log" | tail -1)"
  grep -E '^\[shadowrun\] idle polls' "$out/idle_$leg.log" | sed 's/^/   /'
  grep -E '\[coverage\]' "$out/idle_$leg.log" | head -1 | sed 's/^/   /'
  # A leg that did not arm the table it claims to test measures nothing.
  if [ -n "${SNESRECOMP_IDLE_POLLS:-}" ]; then
    local n; n=$(grep -oE 'idle polls declared: [0-9]+' "$out/idle_$leg.log" | tail -1 | awk '{print $NF}')
    [ "${n:-0}" -ge 1 ] || echo "   !! declared 0 polls: this leg is not a test"
  fi
  python3 - "$anchor/last_run_report.json" "idle_$leg" <<'PY' 2>/dev/null | sed 's/^/   /'
import json, sys
try:
    s = json.load(open(sys.argv[1]))["execution_share"]
except Exception as e:
    print(f"{sys.argv[2]}: no execution_share ({e})"); raise SystemExit
print(f"{sys.argv[2]}: interp {s['interp_cycle_pct']:6.2f}%  "
      f"aot {s['aot_cycle_pct']:6.2f}%  interp_cycles {s['interp_cycles']:,}  "
      f"cpu_cycles {s['cpu_cycles']:,}  master_cycles {s['master_cycles']:,}")
PY
  [ -f "$out/idle_${leg}_cov.json" ] \
    && echo "   capture: $out/idle_${leg}_cov.json ($(wc -c <"$out/idle_${leg}_cov.json" | tr -d ' ') bytes)"
}

# Legs are labels, optionally with what they declare: `off` declares nothing,
# `on` declares $IDLE, and `m0x0:81b061` declares just that one PC. One pair
# failing does not condemn the lever -- a narrower declaration may be the one
# the guard set actually accepts, and the cost of each is what says how much
# the refusal costs.
ran=""
for spec in $LEGS; do
  case "$spec" in
    *:*) export SNESRECOMP_IDLE_POLLS="${spec#*:}"; leg="${spec%%:*}" ;;
    on)  export SNESRECOMP_IDLE_POLLS="$IDLE";        leg=on ;;
    *)   unset SNESRECOMP_IDLE_POLLS;                 leg="$spec" ;;
  esac
  run_leg "$leg"
  ran="$ran $leg"
done
# Every step below addresses legs by label, not by label:declaration.
LEGS="${ran# }"

echo
echo "== capture ingest (pinned tier2_ingest.py --json) =="
PIN="${SNESRECOMP_ROOT:-$(sed -n 's/^SNESRECOMP_ROOT:PATH=\(.*\)$/\1/p' build-r3/CMakeCache.txt | head -1 | tr -d '\r')}"
[ -f "$PIN/tools/tier2_ingest.py" ] || { echo "   SNESRECOMP_ROOT not a pin checkout: $PIN" >&2; exit 1; }
echo "   pin: $PIN"
for leg in $LEGS; do
  cov="$out/idle_${leg}_cov.json"
  [ -f "$cov" ] || { echo "   idle_$leg: no capture"; continue; }
  # --json or stdout is a human summary and every downstream tool chokes on it.
  if ! python3 "$PIN/tools/tier2_ingest.py" "$cov" --json \
      --cfg-dir recomp --program-manifest src/gen/program_manifest.json \
      > "$out/idle_${leg}_ingest.json" 2> "$out/idle_${leg}_ingest.log"; then
    echo "   idle_$leg: ingest FAILED"
    sed 's/^/     /' "$out/idle_${leg}_ingest.log"
    continue
  fi
  python3 - "$out/idle_${leg}_ingest.json" "idle_$leg" <<'PY' | sed 's/^/   /'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"{sys.argv[2]}: captures={r['capture_count']} tuples={len(r['discoveries'])} "
      f"interpreted={r['interpreted_instructions']:,} insns / "
      f"{r['interpreted_guest_cycles']:,} guest cycles / warnings={len(r['warnings'])}")
PY
done

echo
echo "== interpreted residue and wait cost, per leg =="
for leg in $LEGS; do
  ing="$out/idle_${leg}_ingest.json"
  [ -f "$ing" ] || continue
  echo "-- idle_$leg"
  python3 tests/coverage_gaps.py "$ing" --top 5 2>&1 | head -6 | sed 's/^/   /'
  SNESRECOMP_ROOT="$PIN" python3 tests/wait_class.py "$ing" 300000 2>&1 | tail -3 | sed 's/^/   /'
done

echo
echo "== the declared waits, per leg =="
# Same PC set for every leg, declared or not, so the row that did not declare
# anything is the cost of the same waits: that pair is the claim.
args=""; for leg in $LEGS; do args="$args $leg=$out/idle_${leg}_ingest.json"; done
# shellcheck disable=SC2086  # word-splitting the leg pairs is the point
python3 tests/wait_cost.py $args
