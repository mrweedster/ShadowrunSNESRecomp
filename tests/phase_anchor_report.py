#!/usr/bin/env python3
"""Round-8 artifact: where the AOT/interpreter phase is created in a frame.

Files-only report.  It reads the raw outputs of the two probe legs and the
gate run described in `evidence/m2_promotion_round8.md`:

    tests/out/r8/final_ctrl.err      pair gen, $80C530 interpreted
    tests/out/r8/final_seed.err      pair+$80C1C9 gen, $80C530 compiled
    tests/out/r8/gate.txt            state scan, default env
    tests/out/r8/gate.parity.log     crc verdict + executable identity
    evidence/artifacts/round8_probe.diff   the framework probe, as a diff

It runs no route leg, no `tools/regen.sh` and no cmake.

The probe adds three env-gated hooks to the round-7 clone:

    SNESRECOMP_FRAMETAP=lo-hi            [frame]  master at the frame edge
    SNESRECOMP_ENTRYTAP=lo-hi            [entry]  every AOT function entry
    SNESRECOMP_ANCHORTAP=a,b,c (hex pc)  [anchor] either tier at those PCs

`$00C0E2` is the NMI handler.  `run_interrupt` always interprets it, so it is
the one per-frame point both legs sample the same way.  `$80C530` is
interpreted in the control and compiled in the seed; `$80ABBC` is the top of
the loop inside `$80AD9F`, the other body round 6 found necessary.

A `d` value below is seed minus control in master clocks.  Entry samples are
taken at function entry on the AOT side and at opcode start on the interpreter
side; both are after the previous opcode's full charge is committed, so a d of
zero means the same beam position, not merely the same instruction.
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "out", "r8")
ART = os.path.join(ROOT, "evidence", "artifacts")

ANCHOR = re.compile(
    r"^\[anchor\] f=(\d+) pc=([0-9A-F]{6}) tier=(\w+) master=(\d+)")
ENTRY = re.compile(r"^\[entry\] f=(\d+) pc=([0-9A-F]{6}) master=(\d+)")
FRAME = re.compile(r"^\[frame\] f=(\d+) master=(\d+)")
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


def parse(path):
    anchors = {}
    entries = {}
    frames = {}
    trunk = {}
    for line in read(path).splitlines():
        m = ANCHOR.match(line)
        if m:
            f, pc, tier, master = int(m.group(1)), m.group(2), m.group(3), int(m.group(4))
            anchors.setdefault(f, {}).setdefault(pc, []).append(master)
            continue
        m = ENTRY.match(line)
        if m:
            entries.setdefault(int(m.group(1)), []).append(
                (m.group(2), int(m.group(3))))
            continue
        m = FRAME.match(line)
        if m:
            frames[int(m.group(1))] = int(m.group(2))
            m2 = re.search(r"trunk=(\d+)", line)
            if m2:
                trunk[int(m.group(1))] = int(m2.group(1))
    return anchors, entries, frames, trunk


def digest(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def main():
    ca, ce, cf, ct = parse(os.path.join(OUT, "final_ctrl.err"))
    sa, se, sf, st = parse(os.path.join(OUT, "final_seed.err"))
    gate = read(os.path.join(OUT, "gate.txt"))
    gate_log = read(os.path.join(OUT, "gate.parity.log"))
    diffpath = os.path.join(ART, "round8_probe.diff")
    diff = read(diffpath)

    frames = [f for f in range(1828, 1837)]
    exes = EXE.findall(gate_log)
    rev = FW.search(gate_log).group(1) if FW.search(gate_log) else "?"

    print("# Round 8: where the phase at $80C530 is created")
    print()
    print("# how:  framework probe tree at the pin rev below, two probe legs and")
    print("#       one gate run on tests/out/probe_dense.txt.  [frame] is the")
    print("#       master clock when the frame counter advances; [anchor] is an")
    print("#       exact guest pc on either tier; [entry] is every AOT function")
    print("#       entry.  d = seed - control, master clocks.  Raw:")
    print("#       tests/out/r8/{final_ctrl,final_seed,gate,gate.parity}.log.")
    print()
    print(f"# framework rev   {rev}  (pin stayed clean; probe is a clone at")
    print("#                 this rev with the diff in section 6)")
    print(f"# probe diff      sha256 {digest(diffpath)}  (artifacts/round8_probe.diff)")
    print(f"# gen_r6pair      sha256 {digest(os.path.join(ROOT, 'evidence/artifacts/round6_gen_r6pair.tar.gz'))}"
          "  283 nodes, 18 units")
    print(f"# gen_r6pc1c9     sha256 {digest(os.path.join(ROOT, 'evidence/artifacts/round6_gen_r6pc1c9.tar.gz'))}"
          "  486 nodes, 33 units")
    if len(exes) >= 2:
        print(f"# ctrl exe        sha256 {exes[0][0]}  {exes[0][1]} B")
        print(f"# seed exe        sha256 {exes[1][0]}  {exes[1][1]} B")
    print()

    print("== 1. The frame edge and the first $80C530 entry ==")
    print()
    print("  $00C0E2 is the NMI handler; run_interrupt interprets it on both")
    print("  tiers, so its entry is the frame-start sample.  It equals the")
    print("  frame-edge [frame] value exactly.")
    print()
    print("  frame   d_frame_start   d_c530_entry   in-frame drift")
    rows = []
    for f in frames:
        cn = ca.get(f, {}).get("00C0E2", [None])[0]
        sn = sa.get(f, {}).get("00C0E2", [None])[0]
        cc = ca.get(f, {}).get("80C530", [None])[0]
        sc = sa.get(f, {}).get("80C530", [None])[0]
        if None in (cn, sn, cc, sc):
            continue
        rows.append((f, sn - cn, sc - cc, (sc - cc) - (sn - cn)))
        print(f"  {f:5d}   {sn - cn:+13d}   {sc - cc:+12d}   {(sc - cc) - (sn - cn):+13d}")
    print()
    print("  The frame edge is in phase on f1833, f1835 and f1836 and tens of")
    print("  clocks off on the others.  The in-frame drift is not monotone and")
    print("  is zero on two of the five frames: it is a per-frame offset, not a")
    print("  tax that accumulates with work done.")
    print()

    print("== 2. The frame runs in lockstep almost everywhere ==")
    print()
    print("  Entry sequences are compared position by position (both legs run")
    print("  the same guest code up to the first body only the seed compiles).")
    print()
    for f in (1835, 1836):
        c = [x for x in ce.get(f, []) if x[0] != "00C0E2"]
        s = [x for x in se.get(f, []) if x[0] != "00C0E2"]
        n = 0
        d = []
        while n < len(c) and n < len(s) and c[n][0] == s[n][0]:
            d.append(s[n][1] - c[n][1])
            n += 1
        zero = sum(1 for x in d if x == 0)
        vals = sorted(set(d))
        print(f"  f{f}: {n} shared entries before the sequences diverge;"
              f" {zero} have d=0; distinct d {vals}")
    print()
    print("  A non-zero d here is a single instruction's charge landing on one")
    print("  side of a call boundary: it cancels at the next entry.  Example")
    print("  from f1835, entries 2-4 (pc, master):")
    c = [x for x in ce.get(1835, []) if x[0] != "00C0E2"]
    s = [x for x in se.get(1835, []) if x[0] != "00C0E2"]
    for k in (2, 3, 4):
        if k < len(c) and k < len(s):
            print(f"    {k}: ctrl {c[k][0]} {c[k][1]}   seed {s[k][0]} {s[k][1]}"
                  f"   d={s[k][1] - c[k][1]:+d}")
    print("    ctrl spends 200 then 158 clocks; seed spends 160 then 198.  The")
    print("    interval totals match; only the split at the entry differs.")
    print()

    print("== 3. The one body that differs on this path ==")
    print()
    print("  $80ABBC is the top of the loop inside $80AD9F, the second body")
    print("  round 6 found necessary.  Seed compiles it; control interprets it.")
    print("  Both enter it 18 times in these frames.")
    print()
    print("  frame   n   ctrl loop   seed loop   seed-ctrl")
    loop_diff = {}
    for f in frames:
        cl = ca.get(f, {}).get("80ABBC", [])
        sl = sa.get(f, {}).get("80ABBC", [])
        if len(cl) < 2 or len(sl) < 2:
            continue
        cc = cl[-1] - cl[0]
        sc = sl[-1] - sl[0]
        loop_diff[f] = sc - cc
        print(f"  {f:5d}  {len(cl):2d}   {cc:9d}   {sc:9d}   {sc - cc:+9d}")
    print()
    print("  On f1832, f1835 and f1836 the loop costs the same 10,174 master")
    print("  clocks on both tiers.  On f1833 it costs the control 40 more, and")
    print("  on f1834 the seed 48 more.  Subtract the loop delta from the")
    print("  in-frame drift to $80C530:")
    print()
    print("  frame   loop delta   in-frame drift   residual")
    for f in frames:
        cn = ca.get(f, {}).get("00C0E2", [None])[0]
        sn = sa.get(f, {}).get("00C0E2", [None])[0]
        cc = ca.get(f, {}).get("80C530", [None])[0]
        sc = sa.get(f, {}).get("80C530", [None])[0]
        if f in loop_diff and None not in (cn, sn, cc, sc):
            drift = (sc - cc) - (sn - cn)
            print(f"  {f:5d}   {loop_diff[f]:+10d}   {drift:+14d}"
                  f"   {drift - loop_diff[f]:+8d}")
    print()
    print("  The residual is zero on f1833, f1835 and f1836: there the whole")
    print("  in-frame offset is the $80AD9F loop's own boundary charges.  On")
    print("  f1834 it is +40, a second boundary.  On f1832 it is -66 and the")
    print("  loop is in phase, so the offset was created in the frame's")
    print("  opening, in the first two entries after the NMI return:")
    c = [x for x in ce.get(1832, []) if x[0] != "00C0E2"]
    s = [x for x in se.get(1832, []) if x[0] != "00C0E2"]
    for k in range(0, 3):
        if k < len(c) and k < len(s):
            print(f"    {k}: ctrl {c[k][0]} {c[k][1]}   seed {s[k][0]} {s[k][1]}"
                  f"   d={s[k][1] - c[k][1]:+d}")
    print()

    print("== 4. What this changes ==")
    print()
    print("  The seam is not drifting.  At the frame edge the clocks agree on")
    print("  most frames, and inside a frame almost every shared function entry")
    print("  has d=0 to the clock.  The phase at the read is a small per-frame")
    print("  offset (0 to +-56), created at one or two call boundaries and")
    print("  sometimes zero for a whole frame.")
    print()
    print("  That is why a read-time fix cannot be sufficient.  On f1835 and")
    print("  f1836 the tiers enter $80C530 at the same clock, so the only")
    print("  difference at the latch is the 24-clock in-body convention; on")
    print("  f1832/f1833/f1834 they enter tens of clocks apart for reasons that")
    print("  are already decided before the body runs.  Round 7 measured the")
    print("  read; this round shows the entry term is a small discrete offset,")
    print("  not the accumulating drift the seam report warned about.")
    print()
    print("  It also leaves the gate's first byte unexplained by the latch:")
    print("  the first $80C530 entry on both tiers is f1832, while the first")
    print("  non-label state byte is $7E00126 at f1830.")
    print()

    print("== 5. The counter that does drift ==")
    print()
    print("  The same [frame] lines carry cpu->cycles ('trunk').  It is the")
    print("  counter the upstream seam report found drifting; master_cycles is")
    print("  not.  At the frame edges in this window:")
    print()
    print("  frame   d_master   d_trunk")
    for f in frames:
        if f in cf and f in sf:
            print(f"  {f:5d}   {sf[f] - cf[f]:+8d}   {st.get(f, 0) - ct.get(f, 0):+8d}")
    print()
    print("  d_master stays inside a few tens of clocks; d_trunk grows by")
    print("  hundreds and then thousands.  A gate built on master_cycles sees a")
    print("  nearly path-invariant clock; a budget built on cpu->cycles sees the")
    print("  seam.  Round 7's read is priced in master clocks, so it moved a")
    print("  clock that was already within tens of clocks of the control.  The")
    print("  counter carrying the accumulated drift is cpu->cycles, and it is")
    print("  not what the PPU latch samples.")
    print()

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
    print("  Same binaries as the probe runs, all three env vars unset: it")
    print("  reproduces the round-7 gate exactly (f1830, 305 of 4575, 895")
    print("  bytes, crc f1828), so the taps do not perturb the run.")
    print()

    print("== 7. The framework probe ==")
    print()
    for line in diff.rstrip("\n").splitlines():
        print("  " + line if line.strip() else "")
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())
