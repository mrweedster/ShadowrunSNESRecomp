#!/usr/bin/env bash
# Attribute the round-5 f1828 state divergence to compiled bodies.
#
#   SNESRECOMP_ROOT=<pin> ./tests/cluster_hunt.sh all     tests/out/r6/forces_all.txt
#   SNESRECOMP_ROOT=<pin> ./tests/cluster_hunt.sh adopted tests/out/r6/forces_adopted.txt
#
# The candidate tree is the shipped pair plus the rejected $80C1C9 seed
# (tests/seed_variant.sh r6pc1c9 --only '$80C399,$80AAB3,$80C1C9'), which
# reproduces the sweep's gate verdict exactly: first divergence at
# frame_001828, 2745 of 4575 frames. The control is the same pair rebuilt by
# the same steps (tests/seed_variant.sh r6pair --only '$80C399,$80AAB3'), which
# is byte-identical to the shipped pair (a0587ed0a0e34687).
#
# The force file holds `force_lle <pc24>` lines, one per body to keep on the
# interpreter tier. They are spliced into marked blocks at the end of
# recomp/bank80.cfg and recomp/bank81.cfg (all six bank-81 bodies are written to
# both; a pc24 outside a bank's own entries is inert there), src/gen is
# regenerated at the pinned framework, build-r6hunt is rebuilt, and the result
# is compared frame-for-frame against the control on the parity route.
#
# Why force_lle and not a smaller seed table: a seed root pulls its call-graph
# closure with it, so "pair + one body" is not expressible as a table. Starting
# from the failing candidate and demoting chosen bodies back to the tier the
# control used is the only way to ask which compiled body moves the state. A
# subset whose demotion restores `identical` contains a necessary body; a
# subset that still diverges does not.
#
# Nothing here edits the entry table by hand: the candidate table is
# tests/gap_seeds.py's --baseline-only plus --only, the same command shape
# tests/seed_variant.sh uses. The live symbols.toml and every bank cfg are
# snapshotted and restored on exit, so a failed leg cannot leave the tree
# mid-variant.
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

label="${1:-}"; forces="${2:-}"
case "$label" in ''|-h|--help)
  sed -n '2,/^set -uo/p' "$0" | sed -n '/^# /p' | sed 's/^# //'; exit 0 ;;
esac
[ -n "$forces" ] || { echo "usage: $0 <label> <force-file>" >&2; exit 2; }
[ -f "$forces" ] || { echo "no force file $forces" >&2; exit 2; }

pin="${SNESRECOMP_ROOT:-}"
[ -f "$pin/snesrecomp_cli.py" ] || {
  echo "SNESRECOMP_ROOT is not a framework checkout: $pin" >&2; exit 2; }
[ -z "$(cd "$pin" && git status --porcelain 2>/dev/null)" ] || {
  echo "framework pin is dirty; the experiment needs it clean" >&2; exit 2; }

control="${CONTROL:-build-r6pair}"
probe="${PROBE:-tests/out/probe_dense.txt}"
seed="${SEED:-\$80C1C9}"
pair="${PAIR:-\$80C399,\$80AAB3}"
cap="${CAP:-evidence/artifacts/tier2_capture_round3_combat.json}"
preman="${PRE:-evidence/artifacts/round4_manifest_pre.json.bz2}"
out="tests/out/r6"
dir="build-r6hunt"

[ -x "$control/ShadowrunSNESRecomp" ] || {
  echo "no control binary $control/ShadowrunSNESRecomp" >&2
  echo "build it with: tests/seed_variant.sh r6pair --only '$pair'" >&2
  exit 2; }
expect="a0587ed0a0e34687"
got=$(shasum -a 256 "$control/ShadowrunSNESRecomp" | cut -c1-16)
[ "$got" = "$expect" ] || {
  echo "control is not the shipped pair: $got != $expect" >&2; exit 2; }

mkdir -p "$out/cfg"
for f in recomp/symbols.toml recomp/funcs.h recomp/*.cfg; do
  cp -p "$f" "$out/cfg/$(basename "$f").live" 2>/dev/null || true
done
restore() {
  for f in "$out/cfg"/*.live; do
    [ -e "$f" ] && mv -f "$f" "recomp/$(basename "$f" .live)"
  done
}
trap restore EXIT

# Candidate table: the committed table minus the generated gap-seed block, plus
# the pair's two seeds and the one rejected seed. Regenerated, never typed.
echo "== $label: pair + $seed, $forces =="
python3 tests/gap_seeds.py --baseline-only recomp/symbols.toml \
        > "$out/cfg/symbols_base.toml" 2> "$out/cfg/symbols_base.note" || exit 1
cp -p "$out/cfg/symbols_base.toml" recomp/symbols.toml
python3 tests/gap_seeds.py "$cap" --top 10 --route combat \
        --symbols recomp/symbols.toml --manifest "$preman" \
        --only "$pair,$seed" >> recomp/symbols.toml || exit 1
sed -n 's/^name = "GS_\([0-9A-F]*\)"/   seed \1/p' recomp/symbols.toml

# Demotion block. The marker text is distinct from bank00's a7 bisect block so
# a reader can tell which experiment wrote it.
apply_forces() {
  python3 - "$forces" <<'PY'
import sys
lines = [l.strip() for l in open(sys.argv[1]) if l.strip()
         and not l.lstrip().startswith('#')]
for path in ("recomp/bank80.cfg", "recomp/bank81.cfg"):
    s = open(path).read()
    begin = "# >>> BEGIN force_lle (round-6 cluster hunt)"
    end = "# <<< END force_lle (round-6 cluster hunt)"
    if begin in s:
        head, _, rest = s.partition(begin)
        _, _, tail = rest.partition(end)
        s = head + tail.lstrip("\n")
    body = "\n".join(lines)
    open(path, "w").write(
        s.rstrip("\n") + "\n\n" + begin + "\n" + body +
        ("\n" if body else "") + end + "\n")
print(f"   force_lle bodies: {len(lines)}")
PY
}

apply_forces || exit 1
echo "== regen at the pin =="
SNESRECOMP_ROOT="$pin" bash tools/regen.sh >"$out/regen_$label.log" 2>&1 || {
  echo "   regen FAILED"; tail -20 "$out/regen_$label.log"; exit 1; }
grep -E 'AOT-eligible' "$out/regen_$label.log" | tail -1 | sed 's/^/   /'

echo "== build $dir =="
cmake -S . -B "$dir" -DCMAKE_BUILD_TYPE=Release \
      -DSNESRECOMP_ROOT="$pin" >"$out/config_$label.log" 2>&1 || {
  echo "   configure FAILED"; tail -20 "$out/config_$label.log"; exit 1; }
cmake --build "$dir" -j8 >"$out/build_$label.log" 2>&1 || {
  echo "   build FAILED"; tail -30 "$out/build_$label.log"; exit 1; }
exe=$(shasum -a 256 "$dir/ShadowrunSNESRecomp" | cut -c1-16)
echo "   exe sha256 $exe"

echo "== parity against $control =="
PORT_BIN="./$control/ShadowrunSNESRecomp" \
PORT_BIN2="./$dir/ShadowrunSNESRecomp" \
  ./tests/parity.sh "$probe" > "$out/parity_$label.log" 2>&1
cp -p "$dir/last_run_report.json" "$out/report_$label.json" 2>/dev/null || true
verdict=$(grep -oE 'identical over [0-9]+ frames|[0-9]+ of [0-9]+ frames differ|first divergence at frame_[0-9]+' \
          "$out/parity_$label.log" | tr '\n' ';')
# The per-frame crc32 includes the frame-kernel label bytes, which the seam can
# move without moving guest state. The state scan is the attribution metric:
# it ignores the label bytes and reports the first non-label WRAM byte.
python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 \
  > "$out/statediff_$label.txt" 2>&1
state=$(tail -1 "$out/statediff_$label.txt")
echo "   crc:   $verdict"
echo "   state: $state"
printf '%s\n' "$verdict" > "$out/crc_$label.txt"
printf '%s\n' "$state" > "$out/state_$label.txt"
n=$(awk 'NF && $1 !~ /^#/' "$forces" | wc -l | tr -d ' ')
printf '%s\t%s\t%s\t%s\t%s\n' "$label" "$n" "$exe" "$verdict" "$state" \
  | tee -a "$out/hunt.tsv"
