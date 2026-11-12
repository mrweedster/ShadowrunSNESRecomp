#!/usr/bin/env bash
# Cross-path comparison: the shipped AOT binary against a faithful LLE build,
# both built from the same framework pin and the same ROM.
#
#   ./tests/crosspath.sh                                  # combat.txt, both defaults
#   ./tests/crosspath.sh tests/scripts/menu.txt           # a short route
#   PORT_LLE=./other-build/ShadowrunSNESRecomp ./tests/crosspath.sh
#
# This is NOT parity.sh, and parity.sh cannot do this job:
#
#   1. Saves are anchored to the *executable's* directory ("Config/saves
#      anchored to ..." in every log). A binary that lives in build-lle/ reads
#      build-lle/saves/save.srm, so a snapshot of the repo-root saves/ does not
#      apply to it, and the two legs start from different SRAM. Here each leg's
#      own anchor directory is snapshotted and re-seeded from one master copy.
#   2. SNESRECOMP_DUMP_DIR / --framedump are resolved against that same anchor,
#      so relative paths land somewhere surprising. Everything here is absolute.
#   3. Which path really ran has to be proven, not assumed. The breadcrumb is
#      execution_share in <anchor>/last_run_report.json: interp_cycle_pct 100 /
#      aot_cycle_pct 0 for the floor, aot_cycle_pct > 0 for the promoted build.
#      Do not reach for SNESRECOMP_FORCE_FLOOR or SNESRECOMP_EXECUTION_MODE for
#      this: those govern HLE optimizations registered by mods, and in this
#      build snesrecomp_execution_mode() has no caller at all. Measured on
#      ./Shadowrun, 180 frames, default vs FORCE_FLOOR=1 vs MODE=off vs
#      MODE=verify: identical every time (interp_insns 1391992, interp_cycles
#      5539694, aot_cycle_pct 3.8436, master_cycles 64275784). AOT selection is
#      a build-time property -- recomp/symbols.toml `emit` plus tools/regen.sh.
#
# What this decides (evidence/a7 §8.6, framework Axis 6): the shipped AOT path
# and the interpreted floor stop a long guest loop at different points of the
# same frame, because the frame boundary is a fixed master-clock budget each
# path can only poll where it is able to. So byte-identity at a fixed host frame
# index is not the gate, and neither is pairing by the guest tick counter: once
# the legs are tens of host frames out of phase, a counter-aligned comparison
# compares different amounts of held input and a genuine desync looks identical
# to a phase shift. The gate is the fidelity horizon:
#
#   framedump_diff.py horizon  -- at the same host frame, ignoring the
#       frame-label bytes, the first frame whose state difference never comes
#       back inside the noise band. Menu stretches on this route run 2-3 KB out
#       of step for thousands of frames and heal; those are not evidence. The
#       horizon is compared against a recorded baseline (tests/baselines/):
#       later is an improvement, earlier is a regression, and the exit code says
#       which.
#
#   wram_trace.py --streams    -- the value half: on the traced window both paths
#       must write the same bytes in the same order the same number of times.
#       Which frame a write lands in may move; what it writes may not.
#
# drift / tick / shift stay as diagnostics for reading *why* a verdict moved.
# Run parity.sh for same-binary determinism: that one is byte-exact, always.
#
# Second pair, for the same-path control: XP_TAG=2 keeps both pairs on disk
# (xp_aot/xp_lle and xp_aot2/xp_lle2) and XP_ANALYZE=0 runs the legs only.
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
script="${1:-tests/scripts/combat.txt}"
port_aot="${PORT_AOT:-./Shadowrun}"
port_lle="${PORT_LLE:-./build-lle/ShadowrunSNESRecomp}"
rom=$(sr_rom) || exit 2
out="$PWD/tests/out"
# XP_TAG keeps a second pair of legs side by side (xp_aot2 / xp_lle2) so the
# same-path control and a second independent sample are both available.
tag="${XP_TAG:-}"
# XP_ANALYZE=0 runs the legs only; compare afterwards with framedump_diff.py.
analyze="${XP_ANALYZE:-1}"
# XP_BASELINE points the horizon verdict at a recorded baseline. The defaults are
# tracked in tests/baselines (tests/out is scratch and gitignored), and a missing
# baseline is exit 2, never a silent pass. It deliberately does not follow
# XP_TAG: a second tagged pair is another sample of the same build and route, so
# it is judged against the first pair's record. (Not "base": analyse() already
# has a local `base` for the bmp basenames.)
hbase="${XP_BASELINE:-$PWD/tests/baselines/horizon_xp.json}"
D_AOT="$out/xp_aot$tag"
D_LLE="$out/xp_lle$tag"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

abspath() { # $1 = path -> absolute, or empty if missing
  [ -x "$1" ] || return 1
  (cd "$(dirname "$1")" && printf '%s/%s\n' "$PWD" "$(basename "$1")")
}

abs_aot=$(abspath "$port_aot") || { echo "not executable: $port_aot" >&2; exit 1; }
abs_lle=$(abspath "$port_lle") || { echo "not executable: $port_lle" >&2; exit 1; }
dir_aot=$(dirname "$abs_aot")
dir_lle=$(dirname "$abs_lle")
if [ "$dir_aot" = "$dir_lle" ]; then
  # Two binaries in one directory would fight over saves/, config.ini and
  # last_run_report.json, so the per-leg evidence below would be meaningless.
  echo "$abs_aot and $abs_lle share an anchor directory; build one of them" >&2
  echo "into its own tree (e.g. cmake -S . -B build-lle) and retry." >&2
  exit 1
fi

rm -rf "$D_AOT" "$D_LLE" "$out/xp_srm"
mkdir -p "$D_AOT" "$D_LLE" "$out/xp_srm"

# One master SRAM copy, seeded into both anchors, so both legs really do start
# from the same save state. The AOT leg's own saves/ is the canonical one.
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$out/xp_srm/$f"
done
[ -d "$out/xp_srm" ] || { echo "no saves/ to snapshot" >&2; exit 1; }
seed_sram() { # $1 = anchor dir
  mkdir -p "$1/saves"
  [ -f "$out/xp_srm/save.srm" ] && cp -p "$out/xp_srm/save.srm" "$1/saves/save.srm"
  [ -f "$out/xp_srm/save.srm.bak" ] && cp -p "$out/xp_srm/save.srm.bak" "$1/saves/save.srm.bak"
}

leg() { # $1 = label $2 = binary $3 = anchor dir $4 = dump dir $5 = log
  echo "== $1: $2"
  seed_sram "$3"
  SNESRECOMP_DUMP_DIR="$4" "$2" --no-launcher --rom "$rom" --script "$script" --framedump "$4" \
    >"$5" 2>&1
  echo "   exit=$?"
  grep -E 'config dir anchored' "$5" | head -1 | sed 's/^/   /'
  grep -E 'frame service' "$5" | tail -1 | sed 's/^/   /'
  grep -E '^\[host .*exit' "$5" | tail -1 | sed 's/^/   /'
  # The proof of which path ran. Read from the leg's own anchor.
  python3 - "$3/last_run_report.json" "$1" <<'PY' 2>/dev/null | sed 's/^/   /'
import json, sys
try:
    s = json.load(open(sys.argv[1]))["execution_share"]
except Exception as e:
    print(f"{sys.argv[2]}: no execution_share ({e})"); raise SystemExit
print(f"{sys.argv[2]}: interp {s['interp_cycle_pct']:6.2f}%  "
      f"aot {s['aot_cycle_pct']:6.2f}%  cpu_cycles {s['cpu_cycles']}  "
      f"master_cycles {s['master_cycles']}")
PY
  echo "   frame dumps: $(find "$4" -name 'frame_*.json' | wc -l | tr -d ' ')"
  # What program this leg really was, written next to its dumps. The baseline
  # verdict in analyse() is judged against the inputs recorded here, and a leg
  # without a manifest cannot be judged at all.
  python3 tests/provenance.py record "$2" "$4" 2>&1 | sed 's/^/   /'
}

leg run1 "$abs_aot" "$dir_aot" "$D_AOT" "$D_AOT.log"
leg run2 "$abs_lle" "$dir_lle" "$D_LLE" "$D_LLE.log"

analyse() { # $1 = label $2 = dir A $3 = dir B
  local rc=0
  echo
  # The baseline path is $hbase; `base` below is the basename of a checkpoint
  # dump and is only local from its own `local` line onward, so naming it here
  # is an unbound-variable abort under `set -u`.
  # XP_INPUTS_CHANGED=1 judges a pair whose inputs differ from the baseline's on
  # purpose -- that is what a promotion step is -- and prints the input delta.
  # XP_UPDATE=1 re-records the baseline (bound to provenance) from this pair.
  # Only ever re-record from a pair that has passed `provenance.py pin`.
  local hflags=()
  [ "${XP_INPUTS_CHANGED:-0}" = "1" ] && hflags+=(--inputs-changed)
  [ "${XP_UPDATE:-0}" = "1" ] && hflags+=(--update)
  echo "== $1 VERDICT: cross-path fidelity horizon (baseline $hbase) =="
  python3 tests/framedump_diff.py horizon "$2" "$3" "$hbase" ${hflags[@]+"${hflags[@]}"}
  rc=$?
  case $rc in
    0) echo "   => PASS" ;;
    1) echo "   => FAIL" ;;
    *) echo "   => no verdict: this scan does not cover the baseline horizon" ;;
  esac

  echo
  echo "== $1: tagged checkpoint frame buffers (md5) =="
  local same=0 differ=0 missing=0 f base g
  for f in "$2"/*.fb.bmp; do
    [ -e "$f" ] || { echo "   no tagged dumps in $2"; break; }
    base=$(basename "$f"); g="$3/$base"
    if [ ! -f "$g" ]; then printf '   %-16s missing in B\n' "$base"; missing=$((missing+1))
    elif [ "$(md5 -q "$f")" = "$(md5 -q "$g")" ]; then printf '   %-16s match\n' "$base"; same=$((same+1))
    else printf '   %-16s differ\n' "$base"; differ=$((differ+1)); fi
  done
  printf '   checkpoint bmps: %d match, %d differ, %d missing\n' "$same" "$differ" "$missing"

  echo
  echo "== $1: where the route diverges (diagnostic, not the gate) =="
  python3 tests/framedump_diff.py drift "$2" "$3" 2>&1 | head -70

  echo
  echo "== $1: host-frame phase between the legs (diagnostic) =="
  python3 tests/framedump_diff.py tick "$2" "$3" 2>&1 | tail -14

  echo
  echo "== $1: phase-aligned physics probe (diagnostic) =="
  python3 tests/framedump_diff.py shift "$2" "$3" 2>&1 | tail -12
  return $rc
}

verdict=0
if [ "$analyze" != 0 ]; then
  analyse "cross-path" "$D_AOT" "$D_LLE"
  verdict=$?
fi

echo
echo "artifacts: $D_AOT  $D_LLE  (SRAM seed: $out/xp_srm)"
echo "the other half of the verdict needs the trace builds and answers the value"
echo "question on its own window:  ./tests/wram_trace.py --streams"
exit $verdict
echo "interpretation: evidence/a5_crosspath_tick.md"
