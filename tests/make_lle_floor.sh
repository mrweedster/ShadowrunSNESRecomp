#!/usr/bin/env bash
# Build a full-LLE floor: a binary whose dispatch is 100 % interpreter, at the
# framework pin, from the same bundle and ROM as the shipped program.
#
#   ./tests/make_lle_floor.sh                       # build ../build-llefloor, then restore
#   TREE=./build-my-floor ./tests/make_lle_floor.sh # named tree
#   ./tests/make_lle_floor.sh --keep-dirty          # skip the config/gen restore
#   ./tests/make_lle_floor.sh --share DIR           # after a run: record the share
#       where DIR is the framedump the floor produced (tests/out/xp_lle_*). Uses the
#       archived set, so it works after any later regeneration.
#
# Why a script and not a build switch: LLE-ness lives in the generated set, not
# in a CMake option. Every promotion decision is made by the analyzer, so a tree
# configured "as LLE" but regenerated from the current symbols.toml inherits the
# promoted bodies anyway - build-lle did exactly that and measured aot_cycle_pct
# 3.94 (see evidence/m2_promotion_round1.md 0, and the 6 Nov note in the same
# file's lineage). The floor is made by forcing every promotable node back to lle:
#
#   tests/forces/all_lle.txt   one `force_lle <pc24>` per currently-promotable
#                              function, spliced into the marked block at the
#                              bottom of recomp/bank00.cfg
#
# Regenerate that list after any promotion (it tracks src/gen/program_manifest.json):
#
#   python3 - src/gen/program_manifest.json > forces-all_lle.txt <<'EOF'
#   import json,sys
#   m=json.load(open(sys.argv[1])); nodes=m["nodes"].values() if isinstance(m["nodes"],dict) else m["nodes"]
#   for pc in sorted({n["key"]["pc24"] for n in nodes if n["disposition"]=="aot_eligible"}):
#       print(f"force_lle {pc:06X}")
#   EOF
#
# This script leaves the bundle exactly as it found it (config block emptied,
# src/gen re-regenerated) unless --keep-dirty. src/gen is one shared directory,
# so the floor's own set would otherwise be overwritten by the very next regen:
# it is archived at evidence/artifacts/lle_floor_gen.tar.gz and the coverage
# proof is measured against the archive, bound by digest in the record.
set -euo pipefail
BUNDLE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${TREE:-$BUNDLE/build-llefloor}"
FLOOR_JSON="${FLOOR_JSON:-$BUNDLE/evidence/artifacts/aot_share_lle_floor.json}"
FLOOR_GEN="${FLOOR_GEN:-$BUNDLE/evidence/artifacts/lle_floor_gen.tar.gz}"
GENBOX=""
trap 'if [ -n "$GENBOX" ]; then rm -rf "$GENBOX"; fi' EXIT
FORCES="$BUNDLE/tests/forces/all_lle.txt"
CFG="$BUNDLE/recomp/bank00.cfg"
KEEP=0
SHARE_DUMP=""
if [ "${1:-}" = "--keep-dirty" ]; then KEEP=1; fi
if [ "${1:-}" = "--share" ]; then
  if [ -z "${2:-}" ]; then echo "--share needs the floor's framedump dir" >&2; exit 1; fi
  SHARE_DUMP="$2"
fi
if [ -n "$SHARE_DUMP" ]; then
  # Record-only mode: nothing here touches the config or src/gen, so the
  # working generated set stays wherever its owner left it.
  if [ ! -f "$FLOOR_GEN" ]; then echo "missing $FLOOR_GEN: build the floor first" >&2; exit 1; fi
  TREE="${TREE:-$BUNDLE/build-llefloor}"
  GENBOX=$(mktemp -d); mkdir -p "$GENBOX/src/gen"
  tar -xzf "$FLOOR_GEN" -C "$GENBOX/src/gen"
  echo "== recording the floor share from $SHARE_DUMP (set from $(basename "$FLOOR_GEN")) =="
  python3 "$BUNDLE/tests/aot_share.py" "$TREE/ShadowrunSNESRecomp" --gen-root "$GENBOX" \
    --dump-dir "$SHARE_DUMP" --json "$FLOOR_JSON"
  python3 - "$FLOOR_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
cov, share = d["coverage"], d.get("execution_share")
ok = (cov["wrappers_in_binary"] == cov["wrappers_declared"]
      and share and share["aot_cycle_pct"] == 0.0)
print("PROVEN" if ok else "NOT PROVEN",
      "-", f"{cov['wrappers_in_binary']}/{cov['wrappers_declared']} wrappers linked,",
      "aot_cycle_pct", None if not share else share["aot_cycle_pct"],
      "of", None if not share else f"{share['cpu_cycles']:,} cpu cycles")
sys.exit(0 if ok else 1)
PY
  exit $?
fi
if [ -x "$TREE/ShadowrunSNESRecomp" ]; then
    echo "floor already built: $TREE (rm it to rebuild)"; exit 0
fi
if [ ! -f "$FORCES" ]; then echo "missing $FORCES" >&2; exit 1; fi
FRAMEWORK="${SNESRECOMP_ROOT:-}"
if [ -z "$FRAMEWORK" ]; then
  # Find a framework checkout at the pinned revision. The pin lives in the bundle
  # (framework_pins.txt); the roots to try come from build trees' CMakeCache.txt and
  # from recorded legs' run_manifest.json, so the answer is a path this machine has
  # already built at, and it is only accepted if its git HEAD is the pin.
  FRAMEWORK=$(python3 - "$BUNDLE" <<'PY'
import glob, json, os, subprocess, sys
bundle = sys.argv[1]
pin = None
for line in open(os.path.join(bundle, "framework_pins.txt")):
    if line.startswith("snesrecomp="):
        pin = line.split("=", 1)[1].strip()
roots = []
for cache in glob.glob(os.path.join(bundle, "build-*/CMakeCache.txt")):
    for line in open(cache, errors="replace"):
        if line.startswith("SNESRECOMP_ROOT:PATH="):
            roots.append(line.split("=", 1)[1].strip())
for man in glob.glob(os.path.join(bundle, "tests/out/*/run_manifest.json")):
    try:
        roots.append(json.load(open(man))["framework"]["root"])
    except Exception:
        pass
for r in roots:
    if r and os.path.isdir(r):
        rev = subprocess.run(["git", "-C", r, "rev-parse", "HEAD"],
                             capture_output=True, text=True).stdout.strip()
        if pin and rev == pin:
            print(r)
            break
PY
)
fi
if [ ! -d "$FRAMEWORK" ]; then echo "framework not found (set SNESRECOMP_ROOT)" >&2; exit 1; fi
echo "framework: $FRAMEWORK"

restore() {
  if [ "$KEEP" = 1 ]; then return; fi
  python3 - "$CFG" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
B = "# >>> BEGIN force_lle (bisect)"
E = "# <<< END force_lle (bisect)"
b0, _, rest = s.partition(B)
_, _, tail = rest.partition(E)   # tail starts with the marker's own newline
open(p, "w").write(b0 + B + "\n" + E + tail)
PY
  echo "restoring the working generated set (empty force block) ..."
  SNESRECOMP_ROOT="$FRAMEWORK" "$BUNDLE/tools/regen.sh" >/dev/null
  # No rebuild here on purpose: build trees keep their own linked .o sets, and the
  # binaries named by hash in committed records (build-r0, exe 6d8b8e7f97da2cd9)
  # must not be touched. Rebuild a tree only when you want it to track the
  # restored set - and then say so in whatever record cites the new hash.
  echo "restored: $(python3 -c 'import sys;sys.path.insert(0,"'"$BUNDLE"'/tests");import provenance as P;g=P.generated_set("'"$BUNDLE"'");print(g["sha256"][:12], "promoted", g["promoted_functions"])')"
}
trap restore EXIT

echo "splicing $(grep -c '^force_lle' "$FORCES") demotions into $(basename "$CFG") ..."
python3 - "$CFG" "$FORCES" <<'PY'
import sys
cfg, src = sys.argv[1], sys.argv[2]
B = "# >>> BEGIN force_lle (bisect)"
E = "# <<< END force_lle (bisect)"
block = [l.strip() for l in open(src) if l.strip() and not l.startswith("#")]
s = open(cfg).read()
b0, _, rest = s.partition(B)
_, _, tail = rest.partition(E)   # tail starts with the marker's own newline
body = "".join(l + "\n" for l in block)
open(cfg, "w").write(b0 + B + "\n" + body + E + tail)
PY

echo "regen at the pin ..."
SNESRECOMP_ROOT="$FRAMEWORK" "$BUNDLE/tools/regen.sh" 2>&1 | grep -E "v2_emit: [0-9]+ roots|v2_emit: [0-9]+ bank"
python3 - "$BUNDLE" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]+"/tests")
import provenance as P
g = P.generated_set(sys.argv[1])
print("floor generated set:", g["sha256"][:12], "promoted_functions", g["promoted_functions"], "dispatch", g["dispatch_entries"])
if g["promoted_functions"]:
    print("ERROR: floor generated set still promotes functions"); sys.exit(1)
PY

# Archive the floor's set before the restore regens over it: deterministic tar
# (sorted names, zero mtime) so the archive itself is reproducible, and unpack it
# for the coverage proof so the claim is measured against the bytes this binary
# was linked from, not whatever ./src/gen holds afterwards.
echo "archiving the floor generated set -> $(basename "$FLOOR_GEN") ..."
# `ls -a` matters: the digest of a generated set covers every file in src/gen,
# including the analyzer's own .snesrecomp-cache.json; leaving it out changes the
# digest of the archive without changing a line of code. --uid/--gid zero so the
# archive does not depend on who built it. (tar's --options mtime=0 is not a BSD
# tar option, and a rejected option there silently yields an empty archive.)
(cd "$BUNDLE/src/gen" && COPYFILE_DISABLE=1 tar --uid=0 --gid=0 -cf - --files-from - \
    < <(cd "$BUNDLE/src/gen" && ls -a | grep -v '^\.\.\?$' | sort) | gzip -n > "$FLOOR_GEN")
GENBOX=$(mktemp -d)
mkdir -p "$GENBOX/src/gen" && tar -xzf "$FLOOR_GEN" -C "$GENBOX/src/gen"
tar -tzf "$FLOOR_GEN" | sed 's/^/    /' | head -8
python3 - "$GENBOX" "$BUNDLE" <<'PY'
import sys; sys.path.insert(0, sys.argv[2] + "/tests")
import provenance as P
arch, live = P.generated_set(sys.argv[1]), P.generated_set(sys.argv[2])
if not arch or arch["sha256"] != live["sha256"]:
    print("ERROR: the archived set is not the set this binary is built from:",
          None if not arch else arch["sha256"][:12], "vs", live["sha256"][:12])
    sys.exit(1)
print("archived set verified:", arch["sha256"][:12], arch["units"], "units")
PY

echo "configure + build $TREE ..."
cmake -S "$BUNDLE" -B "$TREE" -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT="$FRAMEWORK" >/dev/null
cmake --build "$TREE" -j"$(sysctl -n hw.ncpu)" 2>&1 | tail -1
# Two independent proofs, and they prove different things:
#   coverage  (nm)  -- every generated wrapper this set declares is really linked,
#                      so a 0.0 % share cannot mean "the AOT path failed to load";
#   share     (the run's own breadcrumb) -- 0.0 % of cycles went through AOT bodies.
# The share needs a run in that tree, so a fresh build prints the command that
# produces it; the committed record in evidence/artifacts/ is from the combat run.
python3 "$BUNDLE/tests/aot_share.py" "$TREE/ShadowrunSNESRecomp" --gen-root "$GENBOX" \
  --json "$FLOOR_JSON" \
  || echo "  (aot_share exits non-zero until this tree has run at least once;" \
          "the share check below is skipped in that case)"
python3 - "$FLOOR_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
cov = d["coverage"]
if cov["wrappers_in_binary"] != cov["wrappers_declared"]:
    print("ERROR: generated wrappers missing from the binary:", cov); sys.exit(1)
share = d.get("execution_share")
if share is None:
    print("coverage proven; cycle share needs a run in this tree, then re-run aot_share:")
    print("  PORT_AOT=%s PORT_LLE=./build-r0/ShadowrunSNESRecomp ./tests/crosspath.sh"
          % d["binary"])
    sys.exit(0)
if share["aot_cycle_pct"] != 0.0:
    print("ERROR: floor runs AOT code:", share); sys.exit(1)
print(f"floor proven: aot_cycle_pct 0.0 of {share['cpu_cycles']:,} cpu cycles, "
      f"{cov['wrappers_in_binary']}/{cov['wrappers_declared']} wrappers linked")
PY
echo "floor built: $TREE   (config/gen restored on exit)"
