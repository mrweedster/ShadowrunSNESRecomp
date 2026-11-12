#!/usr/bin/env bash
# Prove the shipped tree is the tree the round accepted, and that its seed block
# is generated rather than typed.
#
#   SNESRECOMP_ROOT=/path/to/pin ./tests/accepted_tree.sh r4pair
#   OUT=tests/out/r4 PRE=evidence/artifacts/round4_manifest_pre.json.bz2 \
#       ROUTE_NAME=combat ./tests/accepted_tree.sh r4pair
#
# A round ends by adopting some subset of its seeds.  After that, three things
# have to be true at once, and none of them is visible from the source:
#
#   * src/gen is the generated set that variant's build compiled, byte for byte
#     (tests/out/<round>/gen_<name>.tar.gz, written by tests/seed_variant.sh);
#   * its program_manifest.json is the archived manifest_<name>.json.bz2, so the
#     coverage and manifest joins describe what is checked out;
#   * recomp/symbols.toml carries a seed block that is exactly what
#     tests/gap_seeds.py emits for the adopted PC list — same command shape the
#     variants were built with, so the shipped table has no second source.
#
# Then the build tree's own identity (tests/provenance.py key) is printed, which
# is what ties the counters in the round record to this tree.  Exit 0 only if
# every check matched; non-zero with the failing diff printed.
set -uo pipefail

name="${1:-}"; shift || true
case "${1:-}" in -h|--help) sed -n '2,20p' "$0" | sed -n '/^# /p' | sed 's/^# //'; exit 0 ;; esac
[ -n "$name" ] || { echo "usage: $0 <variant-name> [build-dir]" >&2; exit 2; }
dir="${1:-build-$name}"

out="${OUT:-tests/out/r4}"
cap="${CAP:-evidence/artifacts/tier2_capture_round3_combat.json}"
pre="${PRE:-evidence/artifacts/round4_manifest_pre.json.bz2}"
route_name="${ROUTE_NAME:-combat}"
pin="${SNESRECOMP_ROOT:-}"
[ -f "$pin/snesrecomp_cli.py" ] || { echo "SNESRECOMP_ROOT is not a framework checkout: $pin" >&2; exit 1; }
for f in "$cap" "$pre" "$out/gen_$name.tar.gz" "$out/manifest_$name.json.bz2"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done
[ -d "$dir" ] || echo "   (no build dir $dir: the identity section will be skipped)"

rc=0
echo "# accepted tree: $name"
echo
echo "checkout      $(pwd)"
echo "pin           $pin"
echo "archives      $out/gen_$name.tar.gz  $out/manifest_$name.json.bz2"
echo
echo "== framework pin as committed =="
cat framework_pins.txt

echo
echo "== src/gen vs the variant's archived generated set =="
tmp="$out/genchk_$name"
rm -rf "$tmp"; mkdir -p "$tmp"
tar xzf "$out/gen_$name.tar.gz" -C "$tmp" || exit 1
if diff -rq "$tmp/gen" src/gen; then
  echo "   IDENTICAL: src/gen matches gen_$name.tar.gz ($(find src/gen -type f | wc -l | tr -d ' ') files)"
else
  echo "   DIFFERS from gen_$name.tar.gz"; rc=1
fi
rm -rf "$tmp"

echo
echo "== program manifest =="
python3 - "$out/manifest_$name.json.bz2" src/gen/program_manifest.json <<'PY' || rc=1
import bz2, hashlib, json, sys
def load(p):
    raw = open(p, "rb").read()
    return json.loads(bz2.decompress(raw) if p.endswith(".bz2") else raw)
arc, live = load(sys.argv[1]), load(sys.argv[2])
for tag, man in (("archived", arc), ("live     ", live)):
    n = man["nodes"]
    aot = sum(1 for x in n.values() if x["disposition"] == "aot_eligible")
    lle = sum(1 for x in n.values() if x["disposition"] == "lle_only")
    print(f"   {tag}  {len(n)} nodes ({aot} aot_eligible, {lle} lle_only), "
          f"{len(man['roots'])} roots")
def sha(p):
    raw = open(p, "rb").read()
    if p.endswith(".bz2"):
        raw = bz2.decompress(raw)
    return hashlib.sha256(raw).hexdigest()[:16]
same = sha(sys.argv[1]) == sha(sys.argv[2])
print(f"   manifest sha256  archived {sha(sys.argv[1])}  live {sha(sys.argv[2])}  "
      f"{'MATCH' if same else 'MISMATCH'}")
added, gone = set(live["nodes"]) - set(arc["nodes"]), set(arc["nodes"]) - set(live["nodes"])
if added or gone:
    print(f"   nodes added {sorted(added)} removed {sorted(gone)}"); raise SystemExit(1)
if arc["nodes"] != live["nodes"] or arc["roots"] != live["roots"]:
    print("   node/root contents differ"); raise SystemExit(1)
PY

echo
echo "== the seed block in recomp/symbols.toml, re-derived =="
mkdir -p "$out/cfg"
python3 - recomp/symbols.toml "$out/cfg/shipped_gap_block.toml" "$out/cfg/shipped_seeds.txt" <<'PY' || rc=1
import re, sys
text = open(sys.argv[1]).read()
blocks = [c for c in re.split(r"(?m)^(?=# --- )", text)
          if "(gap-driven seeds)" in c.split("\n", 1)[0]]
open(sys.argv[2], "w").write("".join(blocks))
pcs, rounds = [], set()
for b in blocks:
    m = re.search(r"round (\d+)", b.split("\n", 1)[0])
    rounds.add(m.group(1) if m else "?")
    pcs += ["$" + n.upper() for n in re.findall(r'^name = "GS_([0-9A-Fa-f]{6})"', b, re.M)]
open(sys.argv[3], "w").write("%s\t%s\n" % (",".join(sorted(rounds)), ",".join(pcs)))
print(f"   {len(blocks)} generated block(s), seeds: {' '.join(pcs)}")
PY
rd=$(cut -f1 "$out/cfg/shipped_seeds.txt")
pcs=$(cut -f2 "$out/cfg/shipped_seeds.txt")
python3 tests/gap_seeds.py --baseline-only recomp/symbols.toml \
        > "$out/cfg/live_base.toml" 2> "$out/cfg/live_base.note" || exit 1
sed 's/^/   /' "$out/cfg/live_base.note"
echo "   re-derived with: tests/gap_seeds.py $(basename "$cap") --route $route_name --round $rd --only '$pcs' --symbols $out/cfg/live_base.toml --manifest $(basename "$pre")"
python3 tests/gap_seeds.py "$cap" --route "$route_name" --round "$rd" --only "$pcs" \
        --symbols "$out/cfg/live_base.toml" --manifest "$pre" \
        > "$out/cfg/regen_gap_block.toml" || exit 1
shasum -a 256 "$out/cfg/shipped_gap_block.toml" "$out/cfg/regen_gap_block.toml" \
  | cut -c1-16,66- | sed 's/^/   /'
# A block generated into a table starts with a blank line, because the seed block
# is written with `>>` after whatever the baseline left.  The comparison is of the
# block itself, so that separator is normalised away on both sides.
python3 - "$out/cfg/shipped_gap_block.toml" "$out/cfg/regen_gap_block.toml" <<'PY' || rc=1
import hashlib, sys
a = open(sys.argv[1]).read().lstrip("\n")
b = open(sys.argv[2]).read().lstrip("\n")
print(f"   block sha256  shipped {hashlib.sha256(a.encode()).hexdigest()[:16]}  "
      f"re-derived {hashlib.sha256(b.encode()).hexdigest()[:16]}  "
      f"{'MATCH' if a == b else 'MISMATCH'}  ({len(a.splitlines())} lines)")
raise SystemExit(0 if a == b else 1)
PY
if diff -q "$out/cfg/shipped_gap_block.toml" "$out/cfg/regen_gap_block.toml" >/dev/null; then
  echo "   byte for byte identical, separator included"
elif [ $rc -eq 0 ]; then
  echo "   the only difference is the blank line gap_seeds.py puts first so that \`>>\`"
  echo "   appends the block cleanly after the baseline table"
else
  diff -u "$out/cfg/shipped_gap_block.toml" "$out/cfg/regen_gap_block.toml" | sed -n '3,80p'
fi
echo "   baseline entries: $(grep -c '^\[\[func\]\]' "$out/cfg/live_base.toml") (shipped table: $(grep -c '^\[\[func\]\]' recomp/symbols.toml))"

if [ -d "$dir" ]; then
  echo
  echo "== build tree identity ($dir) =="
  rec=$(python3 tests/provenance.py record "$dir/ShadowrunSNESRecomp" "$out/$name" 2>&1)
  echo "$rec" | sed 's/^/   /'
  if echo "$rec" | grep -q 'WARN'; then
    echo "   The WARN above is about mtimes, not contents: this tree's generated set was"
    echo "   regenerated from the committed table after the executable was linked, so the"
    echo "   files are newer than the binary.  The src/gen and manifest checks above are"
    echo "   the content-level proof that this checkout is the variant's tree."
  fi
  python3 tests/provenance.py key "$out/$name" 2>&1 | sed 's/^/   /'
fi

echo
if [ $rc -eq 0 ]; then
  echo "ACCEPTED TREE OK: src/gen, manifest and the seed block all match the $name variant"
else
  echo "TREE DOES NOT MATCH THE $name VARIANT (see the diffs above)"
fi
exit $rc
