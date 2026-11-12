#!/usr/bin/env bash
# AOT bisection for the f16122 cross-path split (evidence a7).
#
#   ./tests/bisect_aot.sh                     # current gen, both legs, diff only
#   ./tests/bisect_aot.sh forces/80c11f.txt   # force $80:C11F back to LLE first
#
# One experiment per invocation: the force-list file (one `force_lle <pc24>`
# per line, empty file = no demotion) is spliced into the marked block at the
# bottom of recomp/bank00.cfg, src/gen is regenerated, build-tr-aot is rebuilt,
# and both trace trees run tests/scripts/bisect_h8.txt -- the combat route cut
# just past the H8 dump (host f16188, 66 frames after the first physical split
# at f16122). The floor leg is the reference; the verdict is three lines:
#
#   pre-onset max (f15900-f16121): <n> B     -- label/timer noise floor
#   onset f16122: <n> B  f16123: <n> B  H8 f16188: <n> B
#   == SPLIT at onset | == IDENTICAL at onset
#
# "First frame that differs at all" is deliberately not the metric: boot puts
# timer label bytes out of step on every leg (a6 §3), so only the onset window
# says whether a demotion removed the physical split.
#
# Cost per experiment: regen ~1 min, rebuild ~3-5 min (17 large generated
# files), both legs in parallel ~5 min. Run from the bundle root.
#
# The two trace trees share src/gen with every other build tree: never run a
# regen while another leg is reading src/gen objects, and finish bisecting
# before re-running the long gate captures.
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
rom=$(sr_rom) || exit 2
forces="${1:-}"
route="tests/scripts/bisect_h8.txt"
out=tests/out

apply_forces() {
  python3 - "$forces" <<'PY'
import sys
path, src = "recomp/bank00.cfg", sys.argv[1]
block = []
if src:
    block = [l.strip() for l in open(src) if l.strip() and not l.startswith("#")]
s = open(path).read()
b0, _, rest = s.partition("# >>> BEGIN force_lle (bisect)")
if not _:
    raise SystemExit("bank00.cfg: bisect block markers missing")
_, _, tail = rest.partition("# <<< END force_lle (bisect)")
body = "\n".join(block)
open(path, "w").write(
    b0 + "# >>> BEGIN force_lle (bisect)\n" + body +
    ("\n" if body else "") + "# <<< END force_lle (bisect)\n" + tail)
print(f"force_lle block: {len(block)} demotions")
PY
}

apply_forces
export SNESRECOMP_ROOT=/Users/wee/Documents/work/snesrecomp
tools/regen.sh || { echo "regen failed"; exit 1; }
cmake --build build-tr-aot -j 8 || { echo "build failed"; exit 1; }

rm -rf $out/bs_lle $out/bs_aot
for leg in lle aot; do
  port=$((4410 + 10 * $( [ $leg = lle ] && echo 0 || echo 1 )))
  (SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy SNESRECOMP_DEBUG_PORT=$port \
     ./build-tr-$leg/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
     --framedump $out/bs_$leg --script $route > $out/bs_$leg.log 2>&1) &
done
wait

# Each experiment regenerates src/gen with a different force_lle block, so the
# generated set is expected to change from run to run here. That is the reason to
# record it next to the dumps rather than in a notebook: the manifest names the
# demotion set, the framework and the tree these frames came from, and a later
# horizon check refuses to judge a pair against a baseline captured from other
# inputs.
for leg in lle aot; do
  python3 tests/provenance.py record ./build-tr-$leg/ShadowrunSNESRecomp \
    $out/bs_$leg 2>&1 | sed 's/^/  /'
done

python3 - <<'PY'
import os, json
def rd(d, f):
    try: return open(f'{d}/frame_{f:06d}_wram.bin', 'rb').read()
    except OSError: return None
a, b = 'tests/out/bs_lle', 'tests/out/bs_aot'
fa = set(f for f in os.listdir(a) if f.endswith('_wram.bin'))
fb = set(f for f in os.listdir(b) if f.endswith('_wram.bin'))
fs = sorted(int(e[6:12]) for e in fa & fb)
nd = 0
for f in fs:
    x, y = rd(a, f), rd(b, f)
    n = sum(1 for u, v in zip(x, y) if u != v)
    if n > nd:
        nd = n
for leg in ('lle', 'aot'):
    try:
        s = json.load(open(f'build-tr-{leg}/last_run_report.json'))['execution_share']
        print(f"  {leg}: interp {s['interp_cycle_pct']:6.2f}% aot {s['aot_cycle_pct']:5.2f}%", end='')
    except Exception:
        print(f"  {leg}: no share", end='')
print()

# The verdict metric is the onset itself, not "first frame that differs": boot
# puts label/timer bytes out of step within the first ~500 frames on every leg
# (a6 §3), so that number is always 2. What we are chasing is the physical
# split at f16122 in the $00DF-$00F2 direct-page table, and its growth by the
# H8 checkpoint (f16188).
ONSET = 16122
h8 = next((f for f in fs if 16180 <= f <= 16200), None)
def nbytes(f):
    x, y = rd(a, f), rd(b, f)
    return sum(1 for u, v in zip(x, y) if u != v) if x and y else None
on1, on2, hb = nbytes(ONSET), nbytes(ONSET + 1), nbytes(h8) if h8 else None
pre = [nbytes(f) for f in fs if 15900 <= f <= 16121]
pre = max([v for v in pre if v is not None] or [0])
print(f"  pre-onset max (f15900-f16121): {pre} B")
print(f"  onset f{ONSET}: {on1} B   f{ONSET+1}: {on2} B   H8 f{h8}: {hb} B")
split = (on1 or 0) > max(8, pre) or (hb or 0) > max(8, pre)
print(f"== {'SPLIT' if split else 'IDENTICAL'} at onset"
      f"   (frames {len(fs)}, max {nd})")
PY
