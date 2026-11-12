#!/usr/bin/env bash
# One variant of the gap-seed table, built and run, so a behaviour change can
# be attributed to a seed instead of asserted.
#
#   SNESRECOMP_ROOT=/path/to/pin ./tests/seed_variant.sh r4g --only '$80F362,$80F495,$80F4F9,$80F889'
#   SNESRECOMP_ROOT=/path/to/pin ./tests/seed_variant.sh r4h --exclude '$80F4F9'
#   ROUTE=tests/scripts/combat.txt SNESRECOMP_ROOT=... ./tests/seed_variant.sh r4h --exclude '$80F4F9'
#   KEEP_CFG=1 ./tests/seed_variant.sh ...      # leave the variant's symbols.toml in place
#
# Why this exists: a coverage capture says which entries are worth seeding, and
# the manifest says which of them the analyzer actually gave a body to, but
# neither says whether a body changes what the game does. Seeding a PC also
# re-routes its callers: an entry that used to be interpreted straight through
# becomes an aot_call into a body that may be one instruction wide. The only
# evidence for that is a build with that seed in, or out, and a route run on it.
#
# What a variant is, exactly: the live recomp/symbols.toml with every generated
# gap-seed block (the "# --- ... (gap-driven seeds)" header tests/gap_seeds.py
# writes) removed, that file then fed to tests/gap_seeds.py over the round's
# archived capture with --only/--exclude naming the subset. Nothing here is a
# hand-edited symbols.toml, and the baseline does not move with HEAD: rounds 1
# and 2 named their entries by hand and those blocks stay in.
#
# Three files get overwritten by tools/regen.sh — recomp/symbols.toml, the
# symbols block it syncs into recomp/bank80.cfg, and recomp/funcs.h — so all
# three are snapshotted into tests/out/r4/cfg first and put back at the end
# (also on a trap, so a failed build cannot leave the tree mid-variant).
#
# src/gen is left holding the variant's generated set. To bring it back to the
# committed table: regen with the live recomp/symbols.toml in place.
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

name="${1:-}"; shift || true
case "$name" in ''|-h|--help)
  sed -n '2,/^set -uo/p' "$0" | sed -n '/^# /p' | sed 's/^# //'; exit 0 ;;
esac
filter=("$@")
# --no-seeds means "the committed table on its own": a control tree, built by
# the same steps as every variant, so its numbers and its executable hash are
# comparable to the variants' — and if the committed table regenerates the
# program an earlier round built, that is the provenance claim in one line.
[ "${1:-}" = "--no-seeds" ] && filter=()
[ ${#filter[@]} -gt 0 ] || filter=("--no-seeds")

root="recomp"
cap="evidence/artifacts/tier2_capture_round3_combat.json"
preman="evidence/artifacts/round4_manifest_pre.json.bz2"
route="${ROUTE:-tests/scripts/combat.txt}"
out="tests/out/r4"
dir="build-$name"
pin="${SNESRECOMP_ROOT:-}"
[ -f "$cap" ] && [ -f "$preman" ] && [ -f "$route" ] || { echo "missing capture / manifest / route" >&2; exit 1; }
[ -f "$pin/snesrecomp_cli.py" ] || { echo "SNESRECOMP_ROOT is not a framework checkout: $pin" >&2; exit 1; }

mkdir -p "$out/cfg"
# tools/regen.sh rewrites symbols.toml, funcs.h and the generated block of every
# recomp/bank*.cfg that the symbol table touches (sync_symbols.py writes those
# blocks), so every .cfg is snapshotted, not just the bank of the seeded PC:
# a probe seed in bank $81 would otherwise leave its line behind in bank81.cfg.
for f in "$root"/symbols.toml "$root"/funcs.h "$root"/*.cfg; do
  cp -p "$f" "$out/cfg/$(basename "$f").live" 2>/dev/null || true
done
rm -f "$out/cfg/symbols.toml" "$out/cfg/funcs.h"
restore() {
  [ -n "${KEEP_CFG:-}" ] && { echo "!! keeping the variant's $root/symbols.toml"; return; }
  for f in "$out/cfg"/*.live; do
    mv -f "$f" "$root/$(basename "$f" .live)"
  done
}
trap restore EXIT

echo "== variant $name: committed table minus gap-seed blocks + gap_seeds.py ${filter[*]} =="
# The baseline is what this tool's own --baseline-only prints, so the difference
# between the shipped table and a variant's is exactly the block gap_seeds.py
# was asked to emit, and nothing a hand cut.
python3 tests/gap_seeds.py --baseline-only "$root/symbols.toml" \
        > "$out/cfg/symbols_base.toml" 2> "$out/cfg/symbols_base.note" || exit 1
sed 's/^/   /' "$out/cfg/symbols_base.note"
cp -p "$out/cfg/symbols_base.toml" "$root/symbols.toml"
if [ "${filter[0]}" = "--no-seeds" ]; then
  echo "   no gap seeds added (control tree)"
else
  python3 tests/gap_seeds.py "$cap" --top 10 --route combat --symbols "$root/symbols.toml" \
         --manifest "$preman" "${filter[@]}" >> "$root/symbols.toml" || exit 1
fi
cp -p "$root/symbols.toml" "$out/variant_${name}_symbols.toml"
grep -c '^\[\[func\]\]' "$root/symbols.toml" | sed 's/^/   symbols [[func]] entries: /'
sed -n 's/^name = "GS_\([0-9A-F]*\)"/   seed \1/p' "$root/symbols.toml"

# Compile cost has to be measured in the same pass as the behaviour, or the
# round ends up claiming a win without saying what it cost to rebuild.
STEP_T=$SECONDS
step() { local now=$SECONDS; printf '   [cost %ss %s]\n' "$((now - STEP_T))" "$1"; STEP_T=$now; }

echo "== regen at the pin =="
SNESRECOMP_ROOT="$pin" bash tools/regen.sh >"$out/regen_$name.log" 2>&1 || {
  echo "   regen FAILED"; tail -20 "$out/regen_$name.log"; exit 1; }
grep -E 'exact variants|AOT-eligible' "$out/regen_$name.log" | tail -2 | sed 's/^/   /'
step regen
python3 - "$out/regen_$name.log" src/gen/program_manifest.json "$dir/CMakeCache.txt" <<'PY'
import hashlib, json, sys
man = json.load(open(sys.argv[2]))
nodes = man["nodes"]
aot = sum(1 for n in nodes.values() if n["disposition"] == "aot_eligible")
lle = sum(1 for n in nodes.values() if n["disposition"] == "lle_only")
print(f"   manifest: {len(nodes)} nodes ({aot} aot_eligible, {lle} lle_only), "
      f"{len(man['roots'])} roots, sha256 "
      f"{hashlib.sha256(open(sys.argv[2],'rb').read()).hexdigest()[:16]}")
PY
# Every variant's program has to survive the next variant's regen: the manifest
# (bz2, it is what tests/gap_seed_audit.py joins against) and the whole
# generated set (so a shipped variant can be rebuilt exactly).
bzip2 -kc src/gen/program_manifest.json > "$out/manifest_$name.json.bz2"
tar czf "$out/gen_$name.tar.gz" -C src gen
shasum -a 256 "$out/manifest_$name.json.bz2" "$out/gen_$name.tar.gz" \
  | cut -c1-16,66- | sed 's/^/   archived /'

echo "== configure + build $dir =="
cmake -S . -B "$dir" -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT="$pin" >"$out/config_$name.log" 2>&1 || {
  echo "   configure FAILED"; tail -20 "$out/config_$name.log"; exit 1; }
cmake --build "$dir" -j8 >"$out/build_$name.log" 2>&1 || {
  echo "   build FAILED"; tail -30 "$out/build_$name.log"; exit 1; }
grep -E 'generated translation unit' "$out/config_$name.log" | tail -1 | sed 's/^/   /'
shasum -a 256 "$dir/ShadowrunSNESRecomp" | cut -c1-16,66- | sed 's/^/   exe sha256 /'
step build

echo "== run $route on it =="
. tests/rom.sh
rom=$(sr_rom) || exit 1
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
mkdir -p "$dir/saves" "$out/$name"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$dir/saves/$f"
done
python3 tests/provenance.py record "$dir/ShadowrunSNESRecomp" "$out/$name" >/dev/null
python3 tests/provenance.py key "$out/$name" 2>&1 | sed 's/^/   /'
t0=$(date +%s)
( cd "$dir" && SNESRECOMP_DUMP_DIR="$OLDPWD/$out/$name" "./ShadowrunSNESRecomp" \
    --no-launcher --rom "$rom" --script "$OLDPWD/$route" >"$OLDPWD/$out/$name.log" 2>&1 )
rc=$?; t1=$(date +%s)
echo "   exit=$rc wall=$((t1 - t0))s  $(grep -oE 'exit: .*' "$out/$name.log" | tail -1)"
grep -oE '\[unresolved-abandon\].*' "$out/$name.log" | sort -u | sed 's/^/   /'
grep -oE '\[interp_cap\] entry=\$[0-9A-F]+ last=\$[0-9A-F]+.*' "$out/$name.log" \
  | awk '{print $3}' | sort | uniq -c | sort -rn | sed 's/^/   interp_cap entries: /'
python3 - "$dir/last_run_report.json" <<'PY' 2>/dev/null | sed 's/^/   /'
import json, sys
s = json.load(open(sys.argv[1]))["execution_share"]
print(f"interp {s['interp_cycle_pct']:6.2f}%  aot {s['aot_cycle_pct']:6.2f}%  "
      f"interp_cycles {s['interp_cycles']:,}  cpu_cycles {s['cpu_cycles']:,}  "
      f"master_cycles {s['master_cycles']:,}")
PY
step run
echo
echo "src/gen now holds variant $name. To restore the committed table:"
echo "  SNESRECOMP_ROOT=$pin bash tools/regen.sh   # with the live recomp/symbols.toml"
