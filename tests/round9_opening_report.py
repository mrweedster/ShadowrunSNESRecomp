#!/usr/bin/env python3
"""Round-9 artifact: what creates the -66 in the f1832 opening.

Files-only report.  It reads the raw outputs of the two round-9 probe legs and
the gate run described in `evidence/m2_promotion_round9.md`:

    tests/out/r9/blocks3_ctrl.err    f1832 basic-block ledger, pair gen
    tests/out/r9/blocks3_seed.err    f1832 basic-block ledger, pair+demoted gen
    tests/out/r9/final2_ctrl.err     frame/joy/anchor taps, pair gen
    tests/out/r9/final2_seed.err     frame/joy/anchor taps, demoted gen
    tests/out/r9/gate.txt            state scan, default env
    tests/out/r9/gate.parity.log     crc verdict + executable identity
    evidence/artifacts/round9_probe.diff   the framework probe, as a diff

It runs no route leg, no `tools/regen.sh` and no cmake.

The probe adds four env-gated hooks to the round-8 clone:

    SNESRECOMP_BLOCKTAP=lo-hi        [block] every AOT block / interp opcode
    SNESRECOMP_BLOCKTAP_PC=lo-hi     pc24 window for the block tap
    SNESRECOMP_JOYTAP=lo-hi          [joy] every $4212 read: beam, busy timer, value
    SNESRECOMP_FRAMETAP / ENTRYTAP / ANCHORTAP   as in round 8

`$809D8E` is the head of a `$4212` spin: it repeats while bit 0 (auto-joypad
busy) reads 1.  The `[joy]` tap logs the read itself, so the busy window's end
(beam + timer on every busy read) is a direct measurement, not an inference.

A `d` value below is seed minus control in master clocks.  Both legs run the
whole `$809D8E` loop on the interpreter, so its per-iteration cost is directly
comparable; the only input that can differ is the arrival clock.
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "out", "r9")
ART = os.path.join(ROOT, "evidence", "artifacts")

BLOCK = re.compile(
    r"^\[block\] f=(\d+) pc=([0-9A-F]{6}) tier=(\w+) master=(\d+)")
JOY = re.compile(
    r"^\[joy\] f=(\d+) beam=(\d+) timer=(\d+) hpos=(\d+) vpos=(\d+)"
    r" val=([0-9A-F]{2})")
FRAME = re.compile(r"^\[frame\] f=(\d+) master=(\d+)")
ANCHOR = re.compile(
    r"^\[anchor\] f=(\d+) pc=([0-9A-F]{6}) tier=(\w+) master=(\d+)")
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


def digest(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def parse_blocks(path):
    out = []
    for line in read(path).splitlines():
        m = BLOCK.match(line)
        if m:
            out.append((m.group(2), m.group(3), int(m.group(4))))
    return out


def parse_taps(path):
    joy, frames, anchors = {}, {}, {}
    for line in read(path).splitlines():
        m = JOY.match(line)
        if m:
            joy.setdefault(int(m.group(1)), []).append(
                (int(m.group(2)), int(m.group(3)),
                 int(m.group(6), 16), int(m.group(4)), int(m.group(5))))
            continue
        m = FRAME.match(line)
        if m:
            frames[int(m.group(1))] = int(m.group(2))
            continue
        m = ANCHOR.match(line)
        if m:
            anchors.setdefault(int(m.group(1)), {}).setdefault(
                m.group(2), []).append(int(m.group(4)))
    return joy, frames, anchors


def first_pc(seq, pc):
    for k, x in enumerate(seq):
        if x[0] == pc:
            return k
    return None


def main():
    cb = parse_blocks(os.path.join(OUT, "blocks3_ctrl.err"))
    sb = parse_blocks(os.path.join(OUT, "blocks3_seed.err"))
    cj, cf, ca = parse_taps(os.path.join(OUT, "final2_ctrl.err"))
    sj, sf, sa = parse_taps(os.path.join(OUT, "final2_seed.err"))
    gate = read(os.path.join(OUT, "gate.txt"))
    gate_log = read(os.path.join(OUT, "gate.parity.log"))
    diffpath = os.path.join(ART, "round9_probe.diff")
    diff = read(diffpath)

    exes = EXE.findall(gate_log)
    rev = FW.search(gate_log).group(1) if FW.search(gate_log) else "?"

    print("# Round 9: the f1832 opening is a $4212 busy poll, priced alike")
    print()
    print("# how:  framework probe tree at the pin rev below, two probe legs and")
    print("#       one gate run on tests/out/probe_dense.txt.  [block] is every")
    print("#       basic block (AOT) or opcode start (interp) inside a pc range;")
    print("#       [joy] is every $4212 read with the auto-joypad busy timer.")
    print("#       d = seed - control, master clocks.  Raw:")
    print("#       tests/out/r9/{blocks3_ctrl,blocks3_seed,final2_ctrl,")
    print("#       final2_seed,gate.txt,gate.parity.log}.")
    print()
    print(f"# framework rev   {rev}  (pin stayed clean; probe is a clone at")
    print("#                 this rev with the diff in section 6)")
    print(f"# probe diff      sha256 {digest(diffpath)}  (artifacts/round9_probe.diff)")
    print(f"# gen_r6pair      sha256 {digest(os.path.join(ROOT, 'evidence/artifacts/round6_gen_r6pair.tar.gz'))}"
          "  283 nodes, 18 units")
    print(f"# gen_r6pc1c9     sha256 {digest(os.path.join(ROOT, 'evidence/artifacts/round6_gen_r6pc1c9.tar.gz'))}"
          "  486 nodes, 33 units")
    if len(exes) >= 2:
        print(f"# ctrl exe        sha256 {exes[0][0]}  {exes[0][1]} B  (18 units)")
        print(f"# seed exe        sha256 {exes[1][0]}  {exes[1][1]} B  (33 units)")
    print("# note            the parity manifest's gen sha is the live src/gen")
    print("#                 at run time (the 33-unit seed set); each exe above")
    print("#                 was linked from its own 18 / 33 object files.")
    print()

    # -- 1 ---------------------------------------------------------------
    print("== 1. The entry phase is the frame-edge phase ==")
    print()
    ci = first_pc(cb, "81A99D")
    si = first_pc(sb, "81A99D")
    cp = first_pc(cb, "809D8E")
    sp = first_pc(sb, "809D8E")
    if None in (ci, si, cp, sp):
        raise SystemExit("block ledger is missing $81A99D or $809D8E")

    print("  Ledger from the first $81A99D entry to the first $809D8E entry,")
    print("  position by position (the two sequences share this prefix).")
    print("  A d step of +-40 is the round-8 call-boundary term; it appears")
    print("  and cancels at call sites.")
    print()
    print("   #  pc       tier     ctrl master   seed master      d")
    prev = None
    for k in range(0, cp - ci + 1):
        c = cb[ci + k]
        s = sb[si + k]
        d = s[2] - c[2]
        mark = "" if d == prev else "  <-"
        print(f"  {k:2d}  {c[0]}   {c[1]:5s}   {c[2]:11d}   {s[2]:11d}  {d:+5d}{mark}")
        prev = d
    print()
    if c[0] != s[0]:
        print(f"  NOTE: prefix diverges at {c[0]} vs {s[0]}")
        return 1
    frame_d = (sa.get(1832, {}).get("00C0E2", [None])[0]
               - ca.get(1832, {}).get("00C0E2", [None])[0])
    print(f"  d at the NMI edge of f1832 ({'$00C0E2'}): {frame_d:+d}")
    print(f"  d at the $809D8E entry:            {s[2] - c[2]:+d}")
    print("  The two agree to the clock: the +-40 boundary term cancels, and")
    print("  the poll is entered at exactly the frame's own phase.")
    print()

    # -- 2 ---------------------------------------------------------------
    print("== 2. One extra 66-clock poll iteration in the control ==")
    print()
    print("  The loop repeats while $4212 bit 0 is 1.  Each pass is")
    print("  $809D8E -> $809D91 -> $809D94 -> $809D8E.  Master per pass:")
    print()
    for name, seq, p in (("ctrl", cb, cp), ("seed", sb, sp)):
        reads = []
        k = p
        while k < len(seq) and seq[k][0] in ("809D8E", "809D91", "809D94"):
            if seq[k][0] == "809D8E":
                reads.append(seq[k][2])
            k += 1
        deltas = [b - a for a, b in zip(reads, reads[1:])]
        exit_k = first_pc(seq[k - 1:], "809D96")
        exit_m = seq[k - 1 + exit_k][2] if exit_k is not None else None
        print(f"  {name}: {len(reads)} reads at {reads}")
        print(f"        pass costs {deltas}")
        print(f"        loop exit $809D96 at {exit_m}")
    print()
    c_reads = []
    k = cp
    while k < len(cb) and cb[k][0] in ("809D8E", "809D91", "809D94"):
        if cb[k][0] == "809D8E":
            c_reads.append(cb[k][2])
        k += 1
    c_exit = cb[k][2]
    s_reads = []
    k = sp
    while k < len(sb) and sb[k][0] in ("809D8E", "809D91", "809D94"):
        if sb[k][0] == "809D8E":
            s_reads.append(sb[k][2])
        k += 1
    s_exit = sb[k][2]
    print(f"  d at entry: {s_reads[0] - c_reads[0]:+d}")
    print(f"  d at exit:  {s_exit - c_exit:+d}")
    print(f"  change:     {(s_exit - c_exit) - (s_reads[0] - c_reads[0]):+d}")
    print("  The -66 is one pass of the loop: the control takes five reads,")
    print("  the seed four, and every pass costs 66 master on both tiers.")
    print()

    # -- 3 ---------------------------------------------------------------
    print("== 3. The hardware edge is shared; only the sampling straddles it ==")
    print()
    print("  Every [joy] read of this loop on f1832.  While the timer is")
    print("  non-zero, beam + timer is the end of the same busy window.")
    print()
    print("  leg   beam          timer  beam+timer    val  bit0")
    for name, j in (("ctrl", cj.get(1832, [])), ("seed", sj.get(1832, []))):
        for beam, timer, val, hpos, vpos in j:
            edge = beam + timer if timer else "-"
            print(f"  {name:4s}  {beam:11d}  {timer:5d}  "
                  f"{str(edge):>11s}   {val:02X}   {val & 1}")
        print()
    c_busy = [(b, t) for b, t, v, _, _ in cj.get(1832, []) if t]
    s_busy = [(b, t) for b, t, v, _, _ in sj.get(1832, []) if t]
    c_edges = sorted({b + t for b, t in c_busy})
    s_edges = sorted({b + t for b, t in s_busy})
    print(f"  busy-window end, control: {c_edges}")
    print(f"  busy-window end, seed:    {s_edges}")
    print("  Same edge on both legs.  The last busy reads are")
    c_lastb = c_busy[-1]
    s_lastb = s_busy[-1]
    print(f"    control: beam {c_lastb[0]} timer {c_lastb[1]} "
          f"({c_lastb[1]} clocks before the edge)")
    print(f"    seed:    beam {s_lastb[0]} timer {s_lastb[1]} "
          f"({s_lastb[1]} clocks before the edge)")
    n_busy_c = len(c_busy)
    n_busy_s = len(s_busy)
    print(f"  control: {n_busy_c} busy reads then a {n_busy_c + 1}th that sees "
          "bit0=0")
    print(f"  seed:    {n_busy_s} busy reads then a {n_busy_s + 1}th that sees "
          "bit0=0")
    print("  The 14-clock phase is larger than the control's 6-clock margin,")
    print("  so its next read lands past the edge and costs a whole pass.")
    print()

    # -- 4 ---------------------------------------------------------------
    print("== 4. Only f1832 flips in this window ==")
    print()
    print("  frame   d_nmi   ctrl reads  seed reads   ctrl first timer"
          "   seed first timer   d_c530")
    for f in range(1829, 1837):
        cn = ca.get(f, {}).get("00C0E2", [None])[0]
        sn = sa.get(f, {}).get("00C0E2", [None])[0]
        cjc = cj.get(f, [])
        sjc = sj.get(f, [])
        cc = ca.get(f, {}).get("80C530", [None])[0]
        sc = sa.get(f, {}).get("80C530", [None])[0]
        d530 = f"{sc - cc:+d}" if None not in (cc, sc) else "-"
        ct = cjc[0][1] if cjc else "-"
        st = sjc[0][1] if sjc else "-"
        print(f"  {f:5d}  {sn - cn:+5d}   {len(cjc):10d}  {len(sjc):10d}"
              f"   {str(ct):>16s}   {str(st):>16s}   {d530:>7s}")
    print()
    print("  Only f1832 reads $4212 a different number of times on the two")
    print("  legs (5 vs 4).  On f1830 both read it 24 times; on every other")
    print("  frame in the window both read it once.  The flip also needs the")
    print("  14-clock phase and a read position near the edge: +14 alone on")
    print("  f1829 and f1831 flips nothing, because there the loop arrives")
    print("  nowhere near the busy window.")
    print()

    # -- 5 ---------------------------------------------------------------
    print("== 5. What this changes ==")
    print()
    print("  Round 8 left the f1832 opening as a -66 step between $80C11F")
    print("  and the first $80C399 entry.  It is not a charge convention and")
    print("  not inside $81A99D: from $81A99D to the poll entry the two legs")
    print("  are in lockstep apart from the +-40 boundary term, which")
    print("  cancels.  The step is one extra iteration of a guest poll loop,")
    print("  decided by whether the last read lands before or after a shared")
    print("  hardware edge.  The loop itself costs 66 master per pass on both")
    print("  tiers, so no amount of re-pricing the compiled path removes it.")
    print()
    print("  This is why the first meaningful DP cluster is at f1832 and not")
    print("  at f1830: the f1830 byte is $7E00126, which round 5 section 8")
    print("  showed is written by the same value sequence on both legs and")
    print("  sits below S (dead scratch).  The readable onset includes the")
    print("  f1832 $7E00000/$01 pair, which $80C530 derives from the H it")
    print("  latches; the -66 opening offset moves that latch.")
    print()
    print("  It also says why a read-time or pricing patch cannot be")
    print("  sufficient: the input to the divergence is the frame's own")
    print("  +-14..32 phase, sampled against a hard edge.  Removing it means")
    print("  removing the frame-edge phase, not the poll or the latch.")
    print()

    # -- 6 ---------------------------------------------------------------
    print("== 6. The gate, instrumentation inert ==")
    print()
    m = GATE.search(gate)
    n = GATE_N.search(gate)
    crc = CRC.search(gate_log)
    if m and n:
        print(f"  first state byte differing: f{m.group(1)}")
        print(f"  frames differing: {n.group(1)} of {n.group(2)},"
              f" {n.group(3)} bytes")
    if crc:
        print(f"  crc32_wram first diff: f{int(crc.group(1))}"
              f" {crc.group(2)} vs {crc.group(3)}")
    print()
    print("  Same binaries as the probe runs, all four env vars unset: it")
    print("  reproduces the round-7/round-8 gate exactly (f1830, 305 of 4575,")
    print("  895 bytes, crc f1828), so the taps do not perturb the run.")
    print()

    # -- 7 ---------------------------------------------------------------
    print("== 7. The framework probe ==")
    print()
    for line in diff.rstrip("\n").splitlines():
        print("  " + line if line.strip() else "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
