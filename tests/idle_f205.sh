#!/usr/bin/env bash
# Where the declared idle polls first change the machine, in bytes.
#
#   ./tests/idle_f205.sh                                  # pair vs none, idle_f205.txt
#   IDLE_POLLS=81b061 ./tests/idle_f205.sh                # one PC
#   SCRIPT=tests/scripts/idle_dense.txt ./tests/idle_f205.sh
#
# tests/idle_parity.sh says the two $7E1C92 waits move guest state -- f9 of a
# boot with no input for the pair and for $81EE8E alone, f1733 for $81B061
# alone. That is the whole case against the lever, so it is worth reading the
# difference rather than only detecting it: this runs the same binary with and
# without the declaration on short routes that straddle the early frames, dumps
# 128 KiB of WRAM at checkpoints either side, and prints
#
#   * the byte runs at the FIRST frame whose crc disagrees (a frame dump is
#     evidence; "the crc differs" is not),
#   * the byte runs per checkpoint, with the polled word $7E1C92 printed so a
#     moved poll value reads differently from a moved *frame position*, and
#   * info.json's master_clock / vpos / hpos per checkpoint, because a phase
#     difference shows up there as same frame, different clock.
#
# What the answer can be, in docs/IDLE_POLL.md's own terms: either the polled
# word changed while a replayed cycle ran -- an invisible write, which the
# guard set can only see for HDMA into $2180-$2183, not for a cartridge DMA
# landing in WRAM -- or the replay moved when something *else* ran, which
# shows up as the same bytes at a different clock, not as new bytes.
#
# Artifact directories are named after the route AND what the leg declares
# (f205_idle_f205_off, f205_idle_f205_p81b061, ...), not just off/on: a bare
# `on` label here once overwrote another leg's dumps, and a bare `off` control
# is only a control for whichever route ran last.

set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
. tests/rom.sh

bin="${BIN:-build-r3/ShadowrunSNESRecomp}"
script="${SCRIPT:-tests/scripts/idle_f205.txt}"
out="${OUT:-tests/out}"
IDLE="${IDLE_POLLS:-81b061,81ee8e}"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

rom=$(sr_rom) || exit 1
absbin=$(cd "$(dirname "$bin")" && printf '%s/%s\n' "$PWD" "$(basename "$bin")")
[ -x "$absbin" ] || { echo "not executable: $bin" >&2; exit 1; }

# One leg label per route and declaration, so legs never overwrite each other:
# the boot route writes tests/out/idle_f205_{off,p81b061,...} and the dense one
# tests/out/idle_dense_{off,...} (TAG overrides the label). A bare `off` control
# is only a control for whichever route ran last, so the route is in the name.
routetag=$(basename "$script" .txt)
polltag=$(printf '%s' "$IDLE" | tr ',' '_' | tr -cd '0-9a-fA-F_')
base="$out/${TAG:-$routetag}"
dir_off="${base}_off"
dir_on="${base}_p$polltag"

# Same start state as every other round-3 leg: the repo-root SRAM, re-seeded.
rm -rf "$out/f205_srm"; mkdir -p "$out/f205_srm"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$out/f205_srm/$f"
done
[ -f "$out/f205_srm/save.srm" ] || { echo "no saves/save.srm to seed from" >&2; exit 1; }

run() { # $1 = leg label, $2 = dir, $3 = polls ("" = declare nothing)
  local leg="$1" dir="$2" polls="$3" rc
  rm -rf "$dir"; mkdir -p "$dir"
  cp -p "$absbin" "$dir/ShadowrunSNESRecomp"
  ln -sfn "$PWD/libs" "$dir/libs"
  sr_rom_stage "$dir"
  mkdir -p "$dir/saves"
  for f in save.srm save.srm.bak; do
    [ -f "$out/f205_srm/$f" ] && cp -p "$out/f205_srm/$f" "$dir/saves/$f"
  done
  echo "== $leg  route=$script  polls=${polls:-<none>}"
  ( if [ -n "$polls" ]; then export SNESRECOMP_IDLE_POLLS="$polls"; else unset SNESRECOMP_IDLE_POLLS; fi
    export SNESRECOMP_DUMP_DIR="$PWD/$dir"
    "./$dir/ShadowrunSNESRecomp" --no-launcher --rom "$rom" \
      --script "$PWD/$script" --framedump "$PWD/$dir" >"$dir.log" 2>&1 )
  rc=$?
  echo "   exit=$rc  $(grep -oE 'exit: .*' "$dir.log" | tail -1)"
  grep -E '^\[shadowrun\] idle polls' "$dir.log" | sed 's/^/   /'
  echo "   dumps: $(ls "$dir"/*.wram.bin 2>/dev/null | wc -l | tr -d ' ') wram," \
       "$(find "$dir" -name 'frame_*.json' | wc -l | tr -d ' ') frames"
}

run off "$dir_off" ""
run "polls:$polltag" "$dir_on" "$IDLE"

echo
echo "== first frame whose WRAM crc32 differs =="
python3 - "$dir_off" "$dir_on" <<'PY'
import glob, json, os, sys
a, b = sys.argv[1], sys.argv[2]
def load(d):
    return {int(os.path.basename(p)[6:12]): json.loads(open(p).read())["crc32_wram"]
            for p in glob.glob(os.path.join(d, "frame_*.json"))}
A, B = load(a), load(b)
common = sorted(set(A) & set(B))
bad = [f for f in common if A[f] != B[f]]
print(f"frames off={len(A)} on={len(B)} first diff={('f%d' % bad[0]) if bad else 'none'}"
      f"  diffs={len(bad)}/{len(common)}")

def runs(A, B):
    d = [i for i in range(len(A)) if A[i] != B[i]]
    out, s = [], None
    for i in d:
        if s is None or i != prev + 1:
            if s is not None:
                out.append((s, prev))
            s = i
        prev = i
    if s is not None:
        out.append((s, prev))
    return d, out

# The first frame that disagrees, in bytes. This is the frame whose crc moved
# while nothing on the route changed, so it is the frame worth reading.
if bad:
    f = bad[0]
    pa, pb = (os.path.join(d, "frame_%06d_wram.bin" % f) for d in (a, b))
    if os.path.exists(pa) and os.path.exists(pb):
        A2, B2 = open(pa, "rb").read(), open(pb, "rb").read()
        d, r = runs(A2, B2)
        print(f"\nbyte runs at frame {f}: {len(d):,} bytes over {len(r)} run(s)")
        for lo, hi in r[:8]:
            print(f"   $7E{lo:05X}..$7E{hi:05X} ({hi - lo + 1})"
                  f" off={A2[lo:hi + 1][:16].hex()} on={B2[lo:hi + 1][:16].hex()}")
        for off, name in ((0x1C92, "frame counter $7E1C92"), (0x1C90, "$7E1C90")):
            wa = A2[off] | (A2[off + 1] << 8)
            wb = B2[off] | (B2[off + 1] << 8)
            print(f"   {name}: off=${wa:04X} on=${wb:04X}"
                  f"{'  <- the polled word differs' if wa != wb else ''}")
PY

echo
echo "== the whole route read at byte level (framedump_diff.py) =="
# A first differing frame plus one byte is the headline; this is the shape of
# the difference across every frame, which is what decides whether the replay
# changed state or moved when the same writes happened. offsets gives the
# per-frame byte counts; byte gives one address's timeline and a value
# histogram per leg -- equal value sets with the counts shifted is phase.
python3 tests/framedump_diff.py offsets "$dir_off" "$dir_on" 2>&1 | sed 's/^/   /'
for addr in $(echo "$BYTES" | tr ',' ' '); do
  python3 tests/framedump_diff.py byte "$dir_off" "$dir_on" "$addr" 2>&1 | sed 's/^/   /'
done

echo
echo "== the WRAM bytes that differ, per checkpoint =="
python3 - "$dir_off" "$dir_on" <<'PY'
import glob, json, os, sys
a, b = sys.argv[1], sys.argv[2]
for pa in sorted(glob.glob(os.path.join(a, "*.wram.bin"))):
    tag = os.path.basename(pa)[:-9]
    pb = os.path.join(b, tag + ".wram.bin")
    if not os.path.exists(pb):
        continue
    A, B = open(pa, "rb").read(), open(pb, "rb").read()
    if len(A) != len(B):
        print(f"{tag}: size differs {len(A)} vs {len(B)}"); continue
    diffs = [i for i in range(len(A)) if A[i] != B[i]]
    if not diffs:
        print(f"{tag}: identical ({len(A):,} bytes)"); continue
    # Group into runs so a shifted byte stream reads as runs, not 40k lines.
    runs, s = [], diffs[0]
    for prev, cur in zip(diffs, diffs[1:]):
        if cur != prev + 1:
            runs.append((s, prev)); s = cur
    runs.append((s, diffs[-1]))
    print(f"{tag}: {len(diffs):,} bytes over {len(runs)} run(s), "
          f"first $7E{runs[0][0]:05X}")
    for lo, hi in runs[:8]:
        w = hi - lo + 1
        va = A[lo:hi + 1][:16].hex()
        vb = B[lo:hi + 1][:16].hex()
        print(f"   $7E{lo:05X}..$7E{hi:05X} ({w}) off={va} on={vb}")
    # The polled word itself, $7E1C92: if the wait's own value moved, the
    # replay was reading a byte something else wrote.
    for off, name in ((0x1C92, "frame counter $7E1C92"), (0x1C90, "$7E1C90")):
        wa = A[off] | (A[off + 1] << 8)
        wb = B[off] | (B[off + 1] << 8)
        print(f"   {name}: off=${wa:04X} on=${wb:04X}"
              f"{'  <- the polled word differs' if wa != wb else ''}")
PY

echo
echo "== position inside the frame, per checkpoint (info.json) =="
python3 - "$dir_off" "$dir_on" <<'PY'
import glob, json, os, sys
a, b = sys.argv[1], sys.argv[2]
keys = ("frame", "master_clock", "vpos", "hpos")
for pa in sorted(glob.glob(os.path.join(a, "*.info.json"))):
    tag = os.path.basename(pa)[:-10]
    pb = os.path.join(b, tag + ".info.json")
    if not os.path.exists(pb):
        continue
    A, B = json.load(open(pa)), json.load(open(pb))
    row = " ".join("%s=%s" % (k, A.get(k)) for k in keys)
    same = all(A.get(k) == B.get(k) for k in keys)
    print(f"{tag}: {row}   " + ("identical" if same else
          "-> on: " + " ".join("%s=%s" % (k, B.get(k)) for k in keys)))
PY

echo
echo "artifacts: $dir_off  $dir_on  (SRAM seed: $out/f205_srm)"
