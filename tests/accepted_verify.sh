#!/usr/bin/env bash
# Close-out verification of the accepted (checked-out) tree.
#
#   SNESRECOMP_ROOT=/path/to/pin ./tests/accepted_verify.sh          # current round (r5pair)
#   SNESRECOMP_ROOT=/path/to/pin PAIR=r4pair BUILD=build-r4pair \
#       CONTROL=r4base MANIFEST=evidence/artifacts/round4_manifest_r4pair.json.bz2 \
#       ./tests/accepted_verify.sh                                     # round 4
#
# tools/regen.sh has just re-derived src/gen from the committed tables, so this
# answers, on that tree: does the shipped executable match the generated set it
# was built from, does the route still reach its end at the same counters, does
# the machine state still match the control run at every tagged checkpoint, and
# does the parity leg still come out identical?  Then it captures the accepted
# program's interpreted residue again, which is the input the next round's seed
# list is cut from -- the ranking in evidence/artifacts/round4_seed_ranking.txt
# was taken against the *control* program and is stale for a tree that already
# compiles the accepted bodies.
#
# The tree is selected by PAIR (the variant name whose archived generated set
# and manifest src/gen must match) and BUILD (its build directory).  CONTROL
# names the build the gate compares against; it defaults to the current round's
# r5base, whose program is byte-identical to round 4's r4base control.  MANIFEST
# defaults to the round-5 archive when it exists, otherwise round 4's.
#
# Every leg runs from a scratch anchor under tests/out/r4/accepted/, never in
# build-*/: a build dir's last_run_report.json is the join target for
# tests/round4_artifacts.sh's parity table, and an extra leg in that dir would
# overwrite the report that artifact reads.  The anchor is a copy of
# $BUILD/ShadowrunSNESRecomp (same bytes, so the same program), with the libs
# symlink and the save snapshot it anchors to its own directory.
#
# Exit 0 = every leg ran; the numbers are the reading, not a pass/fail gate.
# The log is tests/out/r4/accepted/accepted_verify.log.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
pin="${SNESRECOMP_ROOT:?SNESRECOMP_ROOT must be the framework pin}"
pair="${PAIR:-r5pair}"
build="${BUILD:-build-$pair}"
control="${CONTROL:-r5base}"
manifest="${MANIFEST:-}"
if [ -z "$manifest" ]; then
  for cand in "evidence/artifacts/round5_manifest_$pair.json.bz2" \
              "evidence/artifacts/round4_manifest_$pair.json.bz2"; do
    [ -f "$cand" ] && { manifest="$cand"; break; }
  done
fi
pre="${PRE:-evidence/artifacts/round4_manifest_pre.json.bz2}"
out="$root/tests/out/r4/accepted"
log="$out/accepted_verify.log"
anchor="$out/anchor_$pair"
mkdir -p "$out"
: >"$log"
exec > >(tee -a "$log") 2>&1

echo "== accepted tree identity (live src/gen vs the shipped exe)"
sha256sum "$build/ShadowrunSNESRecomp" | cut -c1-16 | sed 's/^/  exe      /'
sha256sum src/gen/program_manifest.json | cut -c1-16 | sed 's/^/  manifest /'
OUT="$root/tests/out/r4" PRE="$root/$pre" \
  ROUTE_NAME=combat SNESRECOMP_ROOT="$pin" \
  bash tests/accepted_tree.sh "$pair" "$build" 2>&1 | sed 's/^/  accepted_tree: /'
echo "  accepted_tree exit=${PIPESTATUS[0]} (0 = the checked-out tree is the accepted variant)"

mkdir -p "$anchor/saves"
cp -p "$build/ShadowrunSNESRecomp" "$anchor/ShadowrunSNESRecomp"
ln -sfn "$root/libs" "$out/libs"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$anchor/saves/$f"
done
echo "  anchor     $anchor  exe $(sha256sum "$anchor/ShadowrunSNESRecomp" | cut -c1-16)"

. tests/rom.sh
rom=$(sr_rom) || exit 1
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

echo
echo "== 1. short scripted leg: no capture, and no ROM file-picker"
t0=$(date +%s)
( cd "$anchor" && ./ShadowrunSNESRecomp --no-launcher --rom "$rom" \
    --script "$root/tests/scripts/shorter.txt" >"$out/short.log" 2>&1 )
echo "   exit=$? wall=$(( $(date +%s) - t0 ))s  $(grep -oE 'exit: .*' "$out/short.log" | tail -1)"

echo
echo "== 2. combat route on the accepted tree (22 tagged checkpoints)"
dumps="$out/${pair}_accepted"
rm -rf "$dumps"; mkdir -p "$dumps"
t0=$(date +%s)
( cd "$anchor" && SNESRECOMP_DUMP_DIR="$dumps" ./ShadowrunSNESRecomp \
    --no-launcher --rom "$rom" --script "$root/tests/scripts/combat.txt" \
    >"$out/${pair}_accepted.log" 2>&1 )
rc=$?; t1=$(date +%s)
echo "   exit=$rc wall=$((t1 - t0))s  $(grep -oE 'exit: .*' "$out/${pair}_accepted.log" | tail -1)"
echo "   checkpoints: $(ls "$dumps" | wc -l | tr -d ' ') files, $(ls "$dumps"/*.wram.bin 2>/dev/null | wc -l | tr -d ' ') tagged"
python3 tests/provenance.py record "$build/ShadowrunSNESRecomp" "$dumps" >/dev/null 2>&1
python3 tests/provenance.py key "$dumps" 2>&1 | sed 's/^/   provenance: /'
grep -oE '\[unresolved-abandon\].*' "$out/${pair}_accepted.log" | sort -u | sed 's/^/   /'
python3 - "$anchor/last_run_report.json" <<'PY' | sed 's/^/   /'
import json, sys
s = json.load(open(sys.argv[1]))["execution_share"]
print(f"interp {s['interp_cycle_pct']:6.2f}%  aot {s['aot_cycle_pct']:6.2f}%  "
      f"interp_insns {s['interp_insns']:,}  interp_cycles {s['interp_cycles']:,}  "
      f"cpu_cycles {s['cpu_cycles']:,}  master_cycles {s['master_cycles']:,}  "
      f"frame {s['frame']:,}")
PY

echo
echo "== 3. checkpoint state gate: accepted tree vs the round-4 control run"
python3 tests/cpdump_matrix.py "tests/out/r4/$control" "$dumps" 2>&1 | sed 's/^/  /'

echo
echo "== 4. parity leg on the probe route: accepted exe vs control exe"
PORT_BIN="build-$control/ShadowrunSNESRecomp" PORT_BIN2="$anchor/ShadowrunSNESRecomp" \
  ./tests/parity.sh tests/out/probe_dense.txt >"$out/parity_accepted.log" 2>&1
echo "   rc=$?"
grep -E 'identical over|first divergence|frames differ|exe  *sha256|exit: script' \
  "$out/parity_accepted.log" | sed 's/^/   /'

echo
echo "== 5. capture the accepted program's interpreted residue"
t0=$(date +%s)
( cd "$anchor" && SNESRECOMP_TIER2_MANIFEST="$out/accepted_capture_leg.json" \
    ./ShadowrunSNESRecomp --no-launcher --rom "$rom" --coverage-capture=on \
    --script "$root/tests/scripts/combat.txt" >"$out/accepted_capture.log" 2>&1 )
echo "   exit=$? wall=$(( $(date +%s) - t0 ))s  $(grep -oE 'exit: .*' "$out/accepted_capture.log" | tail -1)"
python3 "$pin/tools/tier2_ingest.py" --json --cfg-dir recomp \
  --program-manifest src/gen/program_manifest.json \
  "$out/accepted_capture_leg.json" >"$out/capture_accepted.json" 2>"$out/ingest_err.log"
echo "   ingest rc=$?  $(wc -c <"$out/capture_accepted.json") B  sha $(sha256sum "$out/capture_accepted.json" | cut -c1-16)"
head -3 "$out/ingest_err.log" | sed 's/^/   /'
python3 - "$out/capture_accepted.json" <<'PY' | sed 's/^/   /'
import json, sys
j = json.load(open(sys.argv[1]))
i = j["identity"]
print(f"capture identity: program_digest {i['program_digest'][:16]}  "
      f"build_digest {i['build_digest'][:16]}  generation_digest {i['generation_digest'][:16]}")
print(f"capture totals:   {j['interpreted_instructions']:,} insns / "
      f"{j['interpreted_guest_cycles']:,} guest cycles  hot_pcs "
      f"{len(j.get('hot_instructions') or [])}  discoveries {len(j.get('discoveries') or [])}")
PY

echo
echo "== 6. residue and ranking on the accepted program"
python3 tests/coverage_gaps.py "$out/capture_accepted.json" 2>&1 | sed 's/^/   /'
python3 tests/gap_seeds.py "$out/capture_accepted.json" --top 10 --list \
  --manifest "$manifest" \
  --symbols recomp/symbols.toml 2>&1 | sed 's/^/   /'

echo
echo "== DONE  (log: $log)"
