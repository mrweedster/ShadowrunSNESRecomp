#!/usr/bin/env bash
# Cycle ledger: one route, several trees, every host switch that moves a cycle
# counter pinned per leg, so the numbers can be subtracted.
#
#   ./tests/aot_charge.sh <leg>...   leg = <name>:<binary>:<floor>:<capture>[:dump]
#
#   ./tests/aot_charge.sh base_nofloor_off:build-r4base/ShadowrunSNESRecomp:nofloor:off \
#                         b1db_nofloor_off:build-s80B1DB/ShadowrunSNESRecomp:nofloor:off
#
#   floor    = SNESRECOMP_FORCE_FLOOR=1   the faithful path; optimized
#                                         replacements are blocked, so a
#                                         tree's compiled bodies never run
#   nofloor  = SNESRECOMP_FORCE_FLOOR unset  (execution policy as built)
#   capture  = on|off, passed as --coverage-capture=on|off
#   dump     = 1|0 (default 1) whether to give the leg a SNESRECOMP_DUMP_DIR.
#              Only costs anything if the route itself has `dump` steps; with a
#              tagged route those TAG.* files are what tests/cpdump_matrix.py
#              compares, and two legs of the *same* binary bound the noise in
#              that comparison.
#
# Why this exists next to tests/seed_variant.sh: a variant run reports its own
# cycle counters, but the trees are not all built with the same capture default
# and the host's capture path costs real host time.  Subtracting one variant's
# cpu_cycles from another's is only meaningful when the switches that decide
# what gets counted are the same on both sides, so this script sets them
# explicitly instead of inheriting them, and records the resulting policy line
# and program digest per leg.
#
# Two trap notes, both of which have already cost a bad number here:
#   * SNESRECOMP_FORCE_FLOOR is presence-tested: any value except one starting
#     with '0' forces the floor, including the string "off".  So the token
#     here is `nofloor`, and it *removes* the variable rather than setting it.
#     Round 4 measured what it does in *this* port: nothing.  In the pinned
#     framework `SNESRECOMP_FORCE_FLOOR` and the execution-mode API appear only
#     in runner/runner.cmake and runner/src/execution_mode.{c,h}; no other file
#     in runner/src (including snes/interp_bridge.c) or in the generated
#     src/gen set references them, and no leg log prints an
#     `[execution_mode] policy=` banner.  So the floor/nofloor legs of the same
#     binary are expected to be identical counters, and they are (tests/out/r4/
#     charge_ledger_run.log: base_nf/base_fl and pair_nf/pair_fl agree to the
#     unit in interp_insns, interp_cycles, cpu_cycles and master_cycles).  The
#     pair is kept as a null control, not as a lever.
#   * The share line's aot_cycle_pct counts "not interpreted", so capture and
#     declared polls inflate it; a share is only ever compared inside one
#     capture state.
#
# Each leg gets its own anchor directory under tests/out (its own saves/,
# config.ini and last_run_report.json), re-seeded from saves/save.srm, with a
# staged rom.cfg and an explicit --rom so no leg can reach the ROM file picker.
#
# Legs and their `<leg>.flags.tsv` / `<leg>.log` records go in `tests/out/charge`
# (`CHARGE_DIR=<dir>` moves them).  That is deliberately not under the per-round
# scratch dir: tests/round4_artifacts.sh joins the ledger from this dir, and a
# leg written somewhere else silently leaves the artifact with raw headers only.
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
. tests/rom.sh
rom=$(sr_rom) || exit 2
script="${SCRIPT:-${PROBE:-tests/out/probe_dense.txt}}"
out="${CHARGE_DIR:-tests/out/charge}"
mkdir -p "$out"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

# Wall clock to milliseconds. `date +%s` is whole seconds and the effect being
# measured here (a seeded route run 22,044 frames) is ~10 % of a ~30 s leg, so
# second-granularity timing swamps it.
now()     { python3 -c 'import time;print("%.3f"%time.time())'; }
elapsed() { python3 -c 'print("%.2f"%(float(__import__("sys").argv[2])-float(__import__("sys").argv[1])))' "$1" "$2"; }

snap="$out/srm_snap"
mkdir -p "$snap"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$snap/$f"
done
[ -f "$snap/save.srm" ] || { echo "no saves/save.srm to seed from" >&2; exit 1; }

for leg in "$@"; do
  IFS=: read -r name bin floor cap dump <<<"$leg"
  [ -x "$bin" ] || { echo "leg $name: no executable $bin" >&2; exit 2; }
  case "$floor" in floor|nofloor) ;; *) echo "leg $name: floor must be floor|nofloor" >&2; exit 2 ;; esac
  case "$cap"   in on|off)       ;; *) echo "leg $name: capture must be on|off" >&2; exit 2 ;; esac
  case "${dump:-1}" in 1|0) ;; *) echo "leg $name: dump must be 1|0" >&2; exit 2 ;; esac
  anchor="$out/$name"
  rm -rf "$anchor"; mkdir -p "$anchor/saves"
  cp -p "$bin" "$anchor/ShadowrunSNESRecomp"
  ln -sfn "$PWD/libs" "$anchor/libs"
  sr_rom_stage "$anchor"
  for f in save.srm save.srm.bak; do
    [ -f "$snap/$f" ] && cp -p "$snap/$f" "$anchor/saves/$f"
  done
  cov="$PWD/$out/${name}_cov.json"
  rm -f "$cov" "$cov.jsonl" "$anchor/last_run_report.json"
  args=(--no-launcher --rom "$rom" --script "$PWD/$script" "--coverage-capture=$cap")
  # What a leg *is*, in the leg's own words: the comparability claim in the
  # joined table cites this file rather than the leg's name.
  dumpdir=""
  [ "${dump:-1}" = 1 ] && dumpdir="$PWD/$out/$name"
  { printf 'binary\t%s\n' "$bin"
    printf 'exe_sha256\t%s\n' "$(shasum -a 256 "$bin" | cut -d' ' -f1)"
    printf 'floor\t%s\tcapture\t%s\tdump\t%s\n' "$floor" "$cap" "${dump:-1}"
    printf 'argv\t%s\n' "${args[*]}"
    printf 'env\tSNESRECOMP_FORCE_FLOOR=%s\tSNESRECOMP_TIER2_MANIFEST=%s\tSNESRECOMP_DUMP_DIR=%s\n' \
      "$([ "$floor" = floor ] && echo 1 || echo unset)" "$([ "$cap" = on ] && echo "$cov" || echo unset)" "${dumpdir:-unset}"
    printf 'script\t%s\n' "$script"
  } >"$out/$name.flags.tsv"
  echo "== leg $name  $bin  floor=$floor capture=$cap dump=${dump:-1}"
  t0=$(now)
  envcmd=()
  [ "$floor" = floor ] && envcmd+=(SNESRECOMP_FORCE_FLOOR=1)
  [ "$cap" = on ] && envcmd+=(SNESRECOMP_TIER2_MANIFEST="$cov")
  [ -n "$dumpdir" ] && envcmd+=(SNESRECOMP_DUMP_DIR="$dumpdir")
  ( cd "$anchor" && env ${envcmd[@]+"${envcmd[@]}"} ./ShadowrunSNESRecomp "${args[@]}" \
      >"$OLDPWD/$out/$name.log" 2>&1 )
  rc=$?; t1=$(now)
  echo "   exit=$rc wall=$(elapsed "$t0" "$t1")s  $(grep -oE 'exit: .*' "$out/$name.log" | tail -1)"
  grep -m1 -E '\[execution_mode\] policy=' "$out/$name.log" | sed 's/^/   /'
  grep -oE '\[unresolved-abandon\].*' "$out/$name.log" | sort -u | sed 's/^/   /'
  python3 tests/provenance.py key "$anchor/ShadowrunSNESRecomp" "$anchor" 2>&1 | grep -E 'exe |gen |fw |WARN' | sed 's/^/   /'
  python3 - "$anchor/last_run_report.json" "$cov" <<'PY' 2>/dev/null | sed 's/^/   /'
import json, os, sys
d = json.load(open(sys.argv[1]))
s = d["execution_share"]
ab = d.get("unresolved_abandons") or {}
print(f"frames={s['frame']} abandons={ab.get('total_hits')} "
      f"interp {s['interp_cycle_pct']:6.2f}%  aot {s['aot_cycle_pct']:6.2f}%  "
      f"interp_insns {s['interp_insns']:,}  interp_cycles {s['interp_cycles']:,}  "
      f"cpu_cycles {s['cpu_cycles']:,}  master_cycles {s['master_cycles']:,}")
cov = sys.argv[2]
if os.path.exists(cov):
    c = json.load(open(cov))
    print(f"capture: hits={c.get('total_tier_hits')} sites={c.get('distinct_sites')} "
          f"program={c['identity'].get('program_digest','')[:16]} "
          f"build={c['identity'].get('build_digest','')[:16]}")
PY
done
echo
echo "joined table: python3 tests/charge_report.py $out <control-leg>"
