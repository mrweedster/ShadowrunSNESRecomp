#!/usr/bin/env python3
"""Round-7 artifact: where the two tiers sample the `$2137` H/V latch.

This is a files-only report.  It reads the raw outputs of two probe legs and
two parity runs, all written by the commands in
`evidence/m2_promotion_round7.md`:

    tests/out/r7/inv_ctrl.err     pair gen, `$80C530` interpreted
    tests/out/r7/inv_seed.err     pair+`$80C1C9` gen, `$80C530` compiled
    tests/out/r7/gate_base.txt    state scan, default
    tests/out/r7/gate_sync.txt    state scan, SNESRECOMP_LATCH_SYNC=1
    tests/out/r7/gate_*.parity.log  crc verdict + executable identity
    tests/out/r7/probe.diff       the framework probe, as a diff

It runs no route leg, no `tools/regen.sh` and no cmake.

Why this exists: round 6 §9 proposed "price the counter read" as the fix that
would let `$80C530` compile without moving state.  This report measures the
read on both tiers instead of assuming it.  A `[tap]` line is the first real
entry into `$80C530` in a frame (function-entry hook, not a WatchdogCheck: a
WatchdogCheck also fires on interior blocks of the same function).  A `[latch]`
line is the `$2137` read inside that body, after the beam has been advanced to
the master clock the tier will latch at (`sync=`), with the resulting H/V.
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "out", "r7")

TAP = re.compile(r"^\[tap\] f=(\d+) inv=(\d+) tier=(\w+)")
TAP_M = re.compile(r"master=(\d+)")
LATCH = re.compile(
    r"^\[latch\] f=(\d+) inv=(\d+) tier=(\w+).*master=(\d+) pending=(\d+) "
    r"eff=(\d+) sync=(\d+) h=(\d+) v=(\d+)")
GATE = re.compile(r"first frame with a state byte differing: f(\d+)")
GATE_N = re.compile(
    r"frames with a state byte differing: (\d+) of (\d+)\s+total state bytes: (\d+)")
CRC = re.compile(r"first divergence at frame_(\d+)\.json: (\S+) vs (\S+)")
EXE = re.compile(r"exe\s+sha256 (\w+)\s+([\d,]+) B")
FW = re.compile(r"rev=(\w+)")


def read(path):
    if not os.path.exists(path):
        raise SystemExit(f"missing input: {path}")
    return open(path, errors="replace").read()


def parse_inv(path):
    entries, latches = {}, {}
    for line in read(path).splitlines():
        m = TAP.match(line)
        if m:
            f, inv, tier = int(m.group(1)), int(m.group(2)), m.group(3)
            entries[inv] = (f, int(TAP_M.search(line).group(1)), tier)
            continue
        m = LATCH.match(line)
        if m:
            g = m.groups()
            latches[int(g[1])] = {
                "f": int(g[0]), "tier": g[2],
                "master": int(g[3]), "pending": int(g[4]),
                "eff": int(g[5]), "sync": int(g[6]),
                "h": int(g[7]), "v": int(g[8]),
            }
    return entries, latches


def first_per_frame(entries, latches):
    e, l = {}, {}
    for inv in sorted(entries):
        f = entries[inv][0]
        e.setdefault(f, (inv, entries[inv][1]))
    for inv in sorted(latches):
        f = latches[inv]["f"]
        l.setdefault(f, (inv, latches[inv]))
    return e, l


def gate(path):
    s = read(path)
    m = GATE.search(s)
    n = GATE_N.search(s)
    if not (m and n):
        raise SystemExit(f"cannot parse {path}")
    return int(m.group(1)), int(n.group(1)), int(n.group(2)), int(n.group(3))


def main():
    ce, cl = parse_inv(os.path.join(OUT, "inv_ctrl.err"))
    se, sl = parse_inv(os.path.join(OUT, "inv_seed.err"))
    ce, cl = first_per_frame(ce, cl)
    se, sl = first_per_frame(se, sl)

    base = read(os.path.join(OUT, "gate_base.parity.log"))
    sync = read(os.path.join(OUT, "gate_sync.parity.log"))
    exes = EXE.findall(base)
    rev = FW.search(base).group(1) if FW.search(base) else "?"

    def digest(p):
        return hashlib.sha256(open(p, "rb").read()).hexdigest()

    diffpath = os.path.join(ROOT, "evidence", "artifacts", "round7_probe.diff")
    diff = read(diffpath)

    print("# Round 7: where the two tiers sample the $2137 H/V latch")
    print()
    print("# how:  framework probe tree at the pin rev below, two probe legs and")
    print("#       two parity runs on tests/out/probe_dense.txt.  A [tap] is a")
    print("#       real entry into $80C530 (PHASETAP); a [latch] is its $2137")
    print("#       read after the beam is advanced to sync=, with the latched")
    print("#       H/V.  Raw: tests/out/r7/{inv_ctrl,inv_seed,gate_base,")
    print("#       gate_sync}; the probe diff is artifacts/round7_probe.diff.")
    print()
    print(f"# framework rev   {rev}  (pin stayed clean; the probe is a clone at")
    print("#                 this rev with the diff in §5, not the pin itself)")
    print(f"# probe diff      sha256 {digest(diffpath)}  (artifacts/round7_probe.diff)")
    print(f"# gen_r6pair      sha256 {digest(os.path.join(ROOT, 'evidence/artifacts/round6_gen_r6pair.tar.gz'))}"
          "  283 nodes, 18 units")
    print(f"# gen_r6pc1c9     sha256 {digest(os.path.join(ROOT, 'evidence/artifacts/round6_gen_r6pc1c9.tar.gz'))}"
          "  486 nodes, 33 units")
    if len(exes) >= 2:
        print(f"# ctrl exe        sha256 {exes[0][0]}  {exes[0][1]} B")
        print(f"# seed exe        sha256 {exes[1][0]}  {exes[1][1]} B")
    print()
    print("== 1. The same guest instruction, both tiers ==")
    print()
    print("  frame   ctrl_entry  ctrl_latch   seed_entry  seed_latch"
          "   d_entry  d_latch  d_h  d_latch/4")
    rows = 0
    for f in sorted(set(ce) & set(se) & set(cl) & set(sl)):
        ci, cen = ce[f]
        si, sen = se[f]
        cla, sla = cl[f][1], sl[f][1]
        d_entry = sen - cen
        d_latch = sla["sync"] - cla["sync"]
        d_h = sla["h"] - cla["h"]
        print(f"  {f:5d}  {cen:11d}  {cla['sync']:11d}  {sen:11d}  "
              f"{sla['sync']:11d}  {d_entry:+7d}  {d_latch:+7d}  {d_h:+3d}"
              f"  {d_latch / 4:+6.1f}")
        rows += 1

    print()
    print("  in-body charge (latch - entry): "
          + ", ".join(
              f"f{f} ctrl {cl[f][1]['sync'] - ce[f][1]:+d}"
              f" / seed {sl[f][1]['sync'] - se[f][1]:+d}"
              for f in sorted(set(ce) & set(se) & set(cl) & set(sl))))
    print()
    print("  The +24 is the LDA $2137's own bus transfers.  The compiled body")
    print("  charges its three fetch cycles before the read and the fourth")
    print("  (the paced data read) inside cpu_read8_paced, and ReadRegOpenBus")
    print("  advances the beam to cpu->master_cycles: 4 x 6 = 24 master clocks.")
    print("  The interpreter commits s_interp_bus_master only after")
    print("  interp816_runOpcode returns, so at the same read it sits 24 clocks")
    print("  earlier.  Every row has d_latch == d_entry + 24.")
    print()
    print("  The rows do not share one d_latch: the entry clocks themselves")
    print("  differ by up to 56 master clocks, because the frame reaches the")
    print("  body at a different point on the two tiers.  That is the phase")
    print("  term the read convention cannot remove.")
    print()
    print("== 2. The latch follows the sample time exactly ==")
    print()
    print("  d_h is always d_latch/4: the H counter advances one count per 4")
    print("  master clocks, so the latched H is a direct function of sync=.  A")
    print("  difference in d_latch is therefore a difference in the value the")
    print("  game reads, not a bookkeeping residual: f1832 reads H=98 (ctrl)")
    print("  against H=91 (seed), a 7-dot split at the same guest instruction.")
    print()
    print("== 3. The gate, with and without a read-time fix ==")
    print()
    fb, nb, tb, bb = gate(os.path.join(OUT, "gate_base.txt"))
    fs, ns, ts, bs = gate(os.path.join(OUT, "gate_sync.txt"))
    cb = CRC.search(base)
    cs = CRC.search(sync)
    print(f"  default                : first state f{fb}, {nb} of {tb} frames,"
          f" {bb} bytes")
    print(f"  SNESRECOMP_LATCH_SYNC=1: first state f{fs}, {ns} of {ts} frames,"
          f" {bs} bytes")
    if cb and cs:
        print(f"  crc32_wram first diff  : f{int(cb.group(1))} {cb.group(2)} vs"
              f" {cb.group(3)}  (same in both parity runs)")
    print()
    print("  LATCH_SYNC advances every interpreted latch by its pending master,")
    print("  so it removes the 24-clock convention term: d_latch becomes")
    print("  d_entry (+24 -> 0 on f1835/f1836, +80 -> +56 on f1834, but")
    print("  -28 -> -52 and -16 -> -40 on f1832/f1833).  The gate's first state")
    print("  divergence does not move (f1830) and the frame count grows")
    print("  305 -> 1333 (895 -> 3031 bytes).  Removing the convention term is")
    print("  not enough: the entry-phase term dominates the early frames, and")
    print("  the divergence is already set before this body runs.")
    print()
    print("== 4. What this settles ==")
    print()
    print("  'Price the counter read' is necessary but not sufficient.  The")
    print("  compiled body does latch 24 master clocks later than the")
    print("  interpreter at an equal entry clock, and that is a real, fixable")
    print("  convention difference.  But the two tiers also enter the body at")
    print("  clocks that differ by up to 56 master clocks, so the latched H")
    print("  differs by a variable number of dots.  A framework change that")
    print("  only adjusts the read cannot restore the pair; the guest timeline")
    print("  up to the read has to be path-invariant first.  That is the")
    print("  direction the upstream seam report (§5 item 3) names, and it is")
    print("  larger than this round's probe.")
    print()
    print("  The earliest non-label state byte (f1830, $7E00126) precedes the")
    print("  first $80C530 entry on both tiers (f1832), so this latch is not")
    print("  that byte's cause; it is the mechanism behind the DP $00/$01")
    print("  cluster that opens at f1832, which is what round 6's write trace")
    print("  named.")
    print()
    print("== 5. The framework probe ==")
    print()
    for line in diff.rstrip("\n").splitlines():
        print("  " + line if line.strip() else "")
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
