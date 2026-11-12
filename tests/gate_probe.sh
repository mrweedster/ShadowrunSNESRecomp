#!/usr/bin/env bash
# Gate probe: instruction-level attribution of the street-transition divergence
# found by crosspath.sh (evidence/a6_crosspath_divergence.md).
#
#   ./tests/gate_probe.sh                    # NMI entry + tick increment
#   RANGE=80c11f-80c400 ./tests/gate_probe.sh   # the vblank dispatcher
#   RANGE=810000-81ffff ./tests/gate_probe.sh   # all of bank $81
#
# Both legs replay the same SRAM seed and the same script prefix
# (tests/scripts/gate_state.txt: combat.txt through `dump P3` + 120 frames,
# then quit), so host frames line up and the gate at f21812-21836 is inside
# the run. Nothing after the gate is replayed. Keep the `quit`: without it the
# leg runs past the window forever and the trace log grows without bound.
#
# The instrument is the framework's runtime-gated bus trace (no rebuild):
# SNESRECOMP_BUS_TRACE="<lo>-<hi>" (hex pc24) prints, per executed instruction
# in that pc range, one [bus] line per bus transfer
#   [bus] f=<frame> pc=$80C128 r $7E026C sp=3
# followed by one [bus-end] summary. Frame numbers come from the guest frame
# counter, so the two logs align by frame; diffing the per-frame opcode
# sequences locates the first instruction where the AOT leg and the LLE leg
# take different branches, with the exact addresses/values read.
#
# Range choices, with what each one costs (22k-frame route):
#   00c0e2-00c11e  the NMI entry: the OAMDMA/$4210 latch read, the tick
#                  increment `inc w $1C92` at $00:C103, the jsl to the vblank
#                  dispatcher and the rti. ~10^5-10^6 lines. This is the
#                  range that answers a5 5: does a leg gain or lose a tick,
#                  and at which host frame.
#   80c11f-80c400  the vblank dispatcher the NMI calls. The NMI handler
#                  ($00:C0E2) is interpreted in both builds and JSLs $80:C11F;
#                  its object-table loop walks $7E02CE/$7E026C/$7E032E/
#                  $7E038E/$7E03EE/$7E0BBE, the exact WRAM tables that start
#                  churning on the LLE leg at f21822 and not on the AOT leg.
#                  ~2x10^7 lines (~1 GB): trace it on one leg at a time.
#
# This works on the two existing binaries; SNESRECOMP_ENABLE_TRACE is not
# needed (bridge_timing_bus is compiled in and only checks the env var).
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
script="tests/scripts/gate_state.txt"
port_aot="${PORT_AOT:-./Shadowrun}"
port_lle="${PORT_LLE:-./build-lle/ShadowrunSNESRecomp}"
range="${RANGE:-00c0e2-00c11e}"
rom=$(sr_rom) || exit 2
out="$PWD/tests/out"
D_AOT="$out/gate_aot"
D_LLE="$out/gate_lle"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

abspath() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$PWD" "$(basename "$1")"); }
abs_aot=$(abspath "$port_aot"); abs_lle=$(abspath "$port_lle")
dir_aot=$(dirname "$abs_aot"); dir_lle=$(dirname "$abs_lle")

rm -rf "$D_AOT" "$D_LLE"
mkdir -p "$D_AOT" "$D_LLE"

# Same single master SRAM seed as crosspath.sh (the AOT leg's own saves/ is
# canonical); each binary reads saves/ from its own anchor directory.
[ -d "$out/gate_srm" ] || { mkdir -p "$out/gate_srm"
  for f in save.srm save.srm.bak; do [ -f "saves/$f" ] && cp -p "saves/$f" "$out/gate_srm/$f"; done; }
seed_sram() {
  mkdir -p "$1/saves"
  [ -f "$out/gate_srm/save.srm" ] && cp -p "$out/gate_srm/save.srm" "$1/saves/save.srm"
  [ -f "$out/gate_srm/save.srm.bak" ] && cp -p "$out/gate_srm/save.srm.bak" "$1/saves/save.srm.bak"
}

leg() { # $1 = label $2 = binary $3 = anchor dir $4 = trace log
  echo "== $1 bus trace: $2  RANGE=$range"
  seed_sram "$3"
  SNESRECOMP_BUS_TRACE="$range" "$2" --no-launcher --rom "$rom" --script "$script" \
    >"$4" 2>&1
  echo "   exit=$?  [bus] lines: $(grep -c '^\[bus\]' "$4")"
}

leg run1 "$abs_aot" "$dir_aot" "$D_AOT.log"
leg run2 "$abs_lle" "$dir_lle" "$D_LLE.log"

echo
echo "== first frame where the interpreted opcode stream diverges =="
python3 - "$D_AOT.log" "$D_LLE.log" "$range" <<'PY'
import re, sys
from collections import OrderedDict
pat = re.compile(r'^\[bus\] f=(\d+) pc=\$([0-9A-Fa-f]+) (.) \$([0-9A-Fa-f]+) sp=(\d+)')
def instr_stream(path):
    # frame -> ordered (pc,kind,addr,sp) transfers, as a per-frame signature
    frames = {}
    for line in open(path, errors='replace'):
        m = pat.match(line)
        if not m: continue
        f, pc, kind, adr, sp = m.groups()
        frames.setdefault(int(f), []).append((pc.upper(), kind, adr.upper()))
    return frames
A, B = instr_stream(sys.argv[1]), instr_stream(sys.argv[2])
fa, fb = set(A), set(B)
only = sorted(fa ^ fb)
if only: print(f"frames traced by only one leg: {only[:10]} ...")
common = sorted(fa & fb)
first = None
for f in common:
    if A[f] != B[f]:
        first = f; break
if first is None:
    print(f"opcode streams identical across all {len(common)} traced frames "
          f"({sys.argv[3]} range) -> divergence lives outside this pc range")
    raise SystemExit
print(f"traced frames in both legs: {len(common)}; first divergent frame: f{first}")
for f in range(first, min(first+3, max(common)+1)):
    if f not in A or f not in B: continue
    sa, sb = A[f], B[f]
    k = 0
    while k < min(len(sa), len(sb)) and sa[k] == sb[k]: k += 1
    ctx_a = " ".join(f"{p[-4:]}{kd}{a[-5:]}" for p, kd, a in sa[max(0,k-6):k])
    print(f"  f{f}: agree on {k} transfers, then")
    print(f"    aot: ...{ctx_a} | {' '.join(f'{p[-4:]}{kd}{a[-5:]}' for p,kd,a in sa[k:k+8])}")
    print(f"    lle: ...{' '.join(f'{p[-4:]}{kd}{a[-5:]}' for p,kd,a in sb[k:k+8])}")
PY

echo
echo "artifacts: $D_AOT.log  $D_LLE.log  (SRAM seed: $out/gate_srm)"
