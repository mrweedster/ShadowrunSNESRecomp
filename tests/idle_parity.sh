#!/usr/bin/env bash
# Idle-poll behaviour check: same binary, route and SRAM; which waits declared.
#
#   ./tests/idle_parity.sh                     # combat.txt, the 4-leg matrix
#   IDLE_POLLS='81b061,81ee8e' ./tests/idle_parity.sh   # what 'ip_on' declares
#   SCRIPT=tests/scripts/horizon.txt ./tests/idle_parity.sh
#   LEGS="ip_m0x0" TRIM=1 ./tests/idle_parity.sh  # control + one leg, then drop
#                                                # the per-frame dumps it read
#
# Legs: ip_off (control, none declared), ip_on (the pair), ip_m0x0 ($81b061
# only), ip_m1x0 ($81ee8e only). Each is compared frame by frame to ip_off.
# LEGS picks which declared legs run; ip_off always runs as the control.
#
# The verdict is a per-frame crc, which detects a divergence but does not read
# it, so the log also carries the byte shape of the first divergence: how many
# bytes move per frame, which addresses, and one address's value timeline in
# both legs (framedump_diff.py offsets/byte). That part is what distinguishes
# "the replay changed state" from "the replay moved when the same writes
# happened", and it survives TRIM=1, which deletes the ~2.9 GiB of per-frame
# dumps the byte read is derived from.
#
# tests/idle_ab.sh answers the cost question. This answers the only question
# that can invalidate it: docs/IDLE_POLL.md promises a declaration can only
# convert interpreted steps into replayed steps with the same guest clock,
# cycle count, refresh, open bus, APU time, resume PC and registers, and that
# any cycle failing a guard is interpreted as if nothing were declared. The
# gate for that promise is frame state: every frame's crc32 of all 128 KiB of
# WRAM, over the whole route, plus the frame count itself.
#
# One changed cycle anywhere -- a yield at a different clock, an NMI landing
# inside a replayed wait, the scripted alley timer firing early -- moves the
# whole route and shows up here as a diverging CRC, because the checkpoints
# A0..A5 in combat.txt are gated on WRAM screen-origin state.
#
# Legs get separate anchors for the same reason tests/crosspath.sh insists on
# it: saves/, config.ini and last_run_report.json are anchored to the
# executable's directory, and two legs sharing one anchor would silently share
# -- and corrupt -- each other's state.

set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

bin="${BIN:-build-r3/ShadowrunSNESRecomp}"
script="${SCRIPT:-tests/scripts/combat.txt}"
out="${OUT:-tests/out}"
. tests/rom.sh
rom=$(sr_rom) || exit 1
IDLE="${IDLE_POLLS:-81b061,81ee8e}"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

absbin=$(cd "$(dirname "$bin")" && printf '%s/%s\n' "$PWD" "$(basename "$bin")")
[ -x "$absbin" ] || { echo "not executable: $bin" >&2; exit 1; }

rm -rf "$out/ip_srm"; mkdir -p "$out/ip_srm"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$out/ip_srm/$f"
done
[ -f "$out/ip_srm/save.srm" ] || { echo "no saves/save.srm to seed from" >&2; exit 1; }

leg() { # $1 = label  (env SNESRECOMP_IDLE_POLLS set by the caller)
  local leg="$1" t0 t1 rc
  local dir="$out/$leg" log="$out/$leg.log"
  rm -rf "$dir"; mkdir -p "$dir"
  cp -p "$absbin" "$dir/ShadowrunSNESRecomp"
  ln -sfn "$PWD/libs" "$dir/libs"
  sr_rom_stage "$dir"               # so the host never has to ask for a ROM
  mkdir -p "$dir/saves"
  for f in save.srm save.srm.bak; do
    [ -f "$out/ip_srm/$f" ] && cp -p "$out/ip_srm/$f" "$dir/saves/$f"
  done
  echo "== $leg  polls=${SNESRECOMP_IDLE_POLLS:-<none>}"
  t0=$(date +%s)
  ( export SNESRECOMP_DUMP_DIR="$PWD/$dir"
    "./$dir/ShadowrunSNESRecomp" --no-launcher --rom "$rom" \
      --script "$PWD/$script" --framedump "$PWD/$dir" >"$log" 2>&1 )
  rc=$?
  t1=$(date +%s)
  echo "   exit=$rc wall=$((t1 - t0))s  $(grep -oE 'exit: .*' "$log" | tail -1)"
  grep -E '^\[shadowrun\] idle polls' "$log" | sed 's/^/   /'
  echo "   frame dumps: $(find "$dir" -name 'frame_*.json' | wc -l | tr -d ' ')"
  python3 tests/provenance.py record "$PWD/$dir/ShadowrunSNESRecomp" "$dir" 2>&1 | head -2 | sed 's/^/   /'
}

# The matrix: control, the pair round 3 measured, and each PC alone. One leg
# failing does not condemn the lever -- a narrower declaration may be the one
# the guard set actually accepts, and only the frame-by-frame comparison says
# which. So every leg runs, and every leg is compared to the control. LEGS
# narrows the matrix when one pair is enough (a byte-level re-read, a bisect).
unset SNESRECOMP_IDLE_POLLS
leg ip_off
LEGS="${LEGS:-ip_on ip_m0x0 ip_m1x0}"
polls_of() {  # leg label -> what it declares (ip_off is always the control)
  case "$1" in
    ip_on) printf '%s\n' "$IDLE" ;;
    ip_m0x0) printf '81b061\n' ;;
    ip_m1x0) printf '81ee8e\n' ;;
    *) return 1 ;;
  esac
}
for leg_name in $LEGS; do
  polls=$(polls_of "$leg_name") || { echo "unknown leg: $leg_name" >&2; exit 1; }
  export SNESRECOMP_IDLE_POLLS="$polls"
  leg "$leg_name"
done

echo
echo "== verdict: per-frame WRAM crc32 across the whole route, vs ip_off =="
python3 - "$out" $LEGS <<'PY'
import glob, json, os, sys
root = sys.argv[1]
legs = sys.argv[2:] or ["ip_on", "ip_m0x0", "ip_m1x0"]
def load(d):
    out = {}
    for p in glob.glob(os.path.join(d, "frame_*.json")):
        out[int(os.path.basename(p)[6:12])] = json.loads(open(p).read())["crc32_wram"]
    return out
ref = load(os.path.join(root, "ip_off"))
if not ref:
    print("no framedumps in ip_off -- nothing to compare"); raise SystemExit(1)
print("control ip_off: %d frames f%d..f%d" % (len(ref), min(ref), max(ref)))
worst = 0
firsts = []
for name in legs:
    d = os.path.join(root, name)
    if not os.path.isdir(d):
        print("%-8s MISSING" % name); worst = 1; continue
    b = load(d)
    common = sorted(set(ref) & set(b))
    bad = [f for f in common if ref[f] != b[f]]
    first = bad[0] if bad else None
    tail = "last common f%d" % common[-1] if common else "no overlap"
    print("%-8s frames=%-6d first divergence=%s  mismatches=%d/%d  (%s)"
          % (name, len(b), ("f%d" % first) if first else "none",
             len(bad), len(common), tail))
    for f in bad[:3]:
        print("            f%d off=%s leg=%s" % (f, ref[f], b[f]))
    if first is not None:
        firsts.append((name, first))
    if bad or set(ref) != set(b):
        worst = 1
print("=> PASS: every declaration left every frame's state identical"
      if worst == 0 else
      "=> FAIL: at least one declaration moved guest state -- the guard set "
      "did not hold on this route")
# the shell reads this to do the byte-level pass below; a crc is a detection,
# the byte pass is the evidence.
with open(os.path.join(root, "ip_first_divergence.txt"), "w") as fh:
    for name, f in firsts:
        fh.write("%s %d\n" % (name, f))
raise SystemExit(worst)
PY
rc=$?

echo
echo "== the first divergence, read as bytes =="
# A crc is a detection, not evidence: this prints which bytes differ at the
# first divergent frame, and the polled word $7E1C92 beside them, so a moved
# poll value reads differently from a moved frame position.
: > "$out/ip_first_bytes.txt"
python3 - "$out" $LEGS <<'PY'
import glob, json, os, sys
root, legs = sys.argv[1], sys.argv[2:] or ["ip_on", "ip_m0x0", "ip_m1x0"]


def crcs(d):
    return {int(os.path.basename(p)[6:12]): json.load(open(p))["crc32_wram"]
            for p in glob.glob(os.path.join(d, "frame_*.json"))}


def wram(d, f):
    p = os.path.join(d, f"frame_{f:06d}_wram.bin")
    return open(p, "rb").read() if os.path.isfile(p) else None


ref = crcs(os.path.join(root, "ip_off"))
for name in legs:
    d = os.path.join(root, name)
    b = crcs(d)
    bad = sorted(f for f in set(ref) & set(b) if ref[f] != b[f])
    if not bad:
        continue
    f0 = bad[0]
    a, c = wram(os.path.join(root, "ip_off"), f0), wram(d, f0)
    if a is None or c is None:
        print("%s f%d: no frame dump to read" % (name, f0))
        continue
    o = [i for i, (x, y) in enumerate(zip(a, c)) if x != y]
    runs = []  # group into runs of consecutive offsets
    for i in o:
        if runs and i == runs[-1][1] + 1:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    print("%s: first divergence f%d -- %d byte positions over %d run(s)"
          % (name, f0, len(o), len(runs)))
    for lo, hi in runs[:12]:
        print("   $7E%05X..$7E%05X (%d) off=%s leg=%s"
              % (lo, hi, hi - lo + 1, a[lo:hi + 1].hex(), c[lo:hi + 1].hex()))
    # A single differing byte rarely says what changed on its own. Print the
    # window around each of the first runs: a differing byte that sits next to
    # the word the poll is waiting on reads very differently from one in the
    # middle of the tilemap.
    for lo, hi in runs[:3]:
        w0, w1 = max(0, lo - 16), min(len(a), hi + 17)
        mark = "  <- the polled word $7E1C92 sits in this window" \
            if w0 <= 0x1C92 < w1 else ""
        print("   window $7E%05X: off %s" % (w0, a[w0:w1].hex()))
        print("   window $7E%05X: leg %s%s" % (w0, c[w0:w1].hex(), mark))
    print("   polled word $7E1C92: off=$%04X leg=$%04X   $7E1C90: off=$%04X leg=$%04X"
          % (int.from_bytes(a[0x1C92:0x1C94], "little"),
             int.from_bytes(c[0x1C92:0x1C94], "little"),
             int.from_bytes(a[0x1C90:0x1C92], "little"),
             int.from_bytes(c[0x1C90:0x1C92], "little")))
    # The addresses worth putting on a timeline are the ones that move *at this
    # frame*, not the ones that move most often over the whole route: the
    # route-wide hot bytes are hot because the frame boundary moved, and at the
    # onset frame they are usually still identical.
    with open(os.path.join(root, "ip_first_bytes.txt"), "a") as fh:
        picks = [lo for lo, hi in runs[:3]]
        fh.write("%s %d %s\n" % (name, f0,
                                 " ".join("%05X" % p for p in picks)))
PY

# FULLBYTES=1 adds the whole-corpus shape of the difference: offsets prints how
# many bytes per frame and which addresses across every frame (a 5.8 GB read per
# leg), and byte prints one address's value timeline in both legs with a value
# histogram per leg -- equal value sets with the counts shifted is phase, a
# value one leg never writes is a state change. The addresses put on timelines
# are the ones read off the onset frame above, in a window around it.
if [ "${FULLBYTES:-0}" = 1 ] && [ -f "$out/ip_first_divergence.txt" ]; then
  echo
  echo "== the whole route's shape, per leg (framedump_diff.py offsets / byte) =="
  while read -r leg_name f0; do
    echo "-- $leg_name (first divergence f$f0)"
    python3 tests/framedump_diff.py offsets "$out/ip_off" "$out/$leg_name" 2>&1 | sed 's/^/   /'
  done < "$out/ip_first_divergence.txt"
  echo
  echo "== the onset frame's bytes, on a timeline (window: f0-30..f0+30) =="
  while read -r leg_name f0 addr1 addr2 addr3; do
    lo=$((f0 > 30 ? f0 - 30 : 0)); hi=$((f0 + 30))
    echo "-- $leg_name, bytes differing at f$f0"
    for a in $addr1 $addr2 $addr3; do
      [ -n "$a" ] || continue
      python3 tests/framedump_diff.py byte "$out/ip_off" "$out/$leg_name" "$a" \
               "$lo" "$hi" 2>&1 | sed 's/^/   /'
    done
  done < "$out/ip_first_bytes.txt"
fi
echo
echo "== the route's checkpoints, compared (framedump_diff.py cpdump) =="
# The crc verdict says a frame moved; this reads the same two legs at the route's
# own gates, where both legs are at the same guest frame by construction: guest
# clock, PPU/HDMA register state, and the image hashes. A gate where every image
# and every register matches and only master_clock moved is a changed cycle
# count with no state change anywhere in sight -- the one thing docs/IDLE_POLL.md
# says a declaration cannot do.
for leg_name in $LEGS; do
  echo "-- $leg_name vs ip_off"
  python3 tests/framedump_diff.py cpdump "$out/ip_off" "$out/$leg_name" 2>&1 | sed 's/^/   /'
done
echo
echo "artifacts: $out/ip_off $out/ip_on $out/ip_m0x0 $out/ip_m1x0  (SRAM seed: $out/ip_srm)"

if [ "${TRIM:-0}" = 1 ]; then
  # The per-frame dumps are ~128 KiB x every frame of the route: ~2.9 GiB per
  # leg. Two things are computed from them and land in this log: the crc
  # verdict, and the bytes at the first divergent frame. The whole-corpus
  # shape (framedump_diff.py offsets/byte over all 22,044 frames) only lands
  # here if FULLBYTES=1 was set for this run, so set that too if you want the
  # shape kept. The tagged checkpoints (A0..A5) always stay.
  echo "trim: removing frame_* dumps (what was derived from them is in this log)"
  find "$out/ip_off" $out/ip_m0x0 $out/ip_m1x0 $out/ip_on -maxdepth 1 \
      -name 'frame_*' -type f -print0 2>/dev/null | xargs -0 rm -f
fi
exit $rc

