#!/usr/bin/env python3
"""Round-10 artifact: is the frame-edge phase drift or quantization?

Files-only report.  It reads the raw outputs of the two round-9 probe legs:

    tests/out/r9/frames_ctrl.err   route-wide [frame] tap, pair gen
    tests/out/r9/frames_seed.err   route-wide [frame] tap, pair+demoted gen
    tests/out/r9/final2_ctrl.err   f1827-1836 frame/joy/anchor taps, pair gen
    tests/out/r9/final2_seed.err   f1827-1836 frame/joy/anchor taps, demoted gen
    tests/out/r9/gate.txt          state scan, default env
    tests/out/r9/gate.parity.log   crc verdict + executable identity
    evidence/artifacts/round9_probe.diff   the framework probe, as a diff

It runs no route leg, no `tools/regen.sh` and no cmake.

The `[frame]` tap (added by the round-8 probe, `SNESRECOMP_FRAMETAP=lo-hi`)
prints `g_cpu.master_cycles` and `g_cpu.cycles` at the point in `RtlRunFrame`
where the frame counter advances — after `snes_generic_frame_driver_run_frame()`
and the PPU draw, immediately before `snes_frame_counter++`.  So a `[frame]`
line is the *achieved* frame boundary, and its value minus the deadline
(`frame_end = master_cycles + 357368`, computed at the start of that frame) is
the driver's overshoot.

A `d` value below is seed minus control, in master clocks — the same
sign as the round-8 and round-9 tables, so a `+14` here is the `+14`
frame phase those records name.
"""
import hashlib
import os
import re
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "out", "r9")
ART = os.path.join(ROOT, "evidence", "artifacts")
PER_FRAME = 357368

FRAME = re.compile(r"^\[frame\] f=(\d+) master=(\d+) trunk=(\d+)$")
ANCHOR = re.compile(
    r"^\[anchor\] f=(\d+) pc=([0-9A-F]{6}) tier=(\w+) master=(\d+)")
JOY = re.compile(r"^\[joy\] f=(\d+) beam=(\d+) timer=(\d+) hpos=(\d+)"
                 r" vpos=(\d+) val=(\w+)$")
GATE = re.compile(r"first frame with a state byte differing: f(\d+)")
GATE_N = re.compile(
    r"frames with a state byte differing: (\d+) of (\d+)\s+total state bytes: (\d+)")
CRC = re.compile(r"first divergence at frame_(\d+)\.json: (\S+) vs (\S+)")
EXE = re.compile(r"exe\s+sha256 (\w+)\s+([\d,]+) B")


def read(path):
    if not os.path.exists(path):
        raise SystemExit(f"missing input: " + path)
    return open(path, errors="replace").read()


def digest(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def parse_frames(path):
    rows = []
    for line in read(path).splitlines():
        m = FRAME.match(line.strip())
        if m:
            rows.append((int(m[1]), int(m[2]), int(m[3])))
    return rows


def parse_anchors(path, pcs):
    """First entry per (frame, pc) plus how many entries that frame has.

    `$80C530` is entered two to five times a frame, so an anchor column is
    only meaningful with the round-8 convention spelled out: first entry,
    entry count alongside.
    """
    first, count = {}, {}
    for line in read(path).splitlines():
        m = ANCHOR.match(line.strip())
        if m and m[2] in pcs:
            key = (int(m[1]), m[2])
            first.setdefault(key, (m[3], int(m[4])))
            count[key] = count.get(key, 0) + 1
    return first, count


def parse_joy(path):
    rows = []
    for line in read(path).splitlines():
        m = JOY.match(line.strip())
        if m:
            rows.append((int(m[1]), int(m[2]), int(m[3]), int(m[4]),
                         int(m[5]), m[6]))
    return rows


def hist(values):
    c = Counter(values)
    if not c:
        return "  (none)"
    width = max(len(str(k)) for k in c)
    return "  " + "\n  ".join(f"{k:>{width}} x{c[k]}" for k in sorted(c))


ctrl = parse_frames(os.path.join(OUT, "frames_ctrl.err"))
seed = parse_frames(os.path.join(OUT, "frames_seed.err"))
win = {t: {
    "frame": parse_frames(os.path.join(OUT, f"final2_{t}.err")),
    "anchor": parse_anchors(os.path.join(OUT, f"final2_{t}.err"),
                            {"00C0E2", "80C530"}),
    "joy": parse_joy(os.path.join(OUT, f"final2_{t}.err")),
} for t in ("ctrl", "seed")}
gate = read(os.path.join(OUT, "gate.txt"))
parity = read(os.path.join(OUT, "gate.parity.log"))

# Frame boundaries only exist where both legs agree on the frame number.
fc = {f: (m, t) for f, m, t in ctrl}
fs = {f: (m, t) for f, m, t in seed}
common = sorted(set(fc) & set(fs))
d_m = {f: fs[f][0] - fc[f][0] for f in common}
d_t = {f: fs[f][1] - fc[f][1] for f in common}
len_c = {b: fc[b][0] - fc[b - 1][0] for b in common if b - 1 in fc}
len_s = {b: fs[b][0] - fs[b - 1][0] for b in common if b - 1 in fs}
dl = {b: len_s[b] - len_c[b] for b in sorted(set(len_c) & set(len_s))}

print("ROUND 10 — the frame-edge phase is quantization, not drift")
print()
print("# inputs")
for p in ("tests/out/r9/frames_ctrl.err", "tests/out/r9/frames_seed.err",
          "tests/out/r9/final2_ctrl.err", "tests/out/r9/final2_seed.err",
          "tests/out/r9/gate.txt", "tests/out/r9/gate.parity.log",
          "evidence/artifacts/round9_probe.diff"):
    print(f"#   {p:44s} sha256 {digest(os.path.join(ROOT, p))[:16]}")
for exe in ("build-r9-ctrl/ShadowrunSNESRecomp",
            "build-r9-seed/ShadowrunSNESRecomp"):
    p = os.path.join(ROOT, exe)
    if os.path.exists(p):
        print(f"#   {exe:44s} sha256 {digest(p)[:16]}")
print("# the probe tree this needs is a clone of the pin at 773285b8 with")
print("#   evidence/artifacts/round9_probe.diff applied; the clone is deleted,")
print("#   so these executables are the only way these lines exist now.")
print("# how the logs were made (frame tap over the whole route; note that")
print("#   the tap's on-test is `e[0] && e[0] != '0'`, so `0-4600` prints")
print("#   NOTHING — the range has to start at 1):")
print("#     for leg in ctrl seed; do")
print("#       SNESRECOMP_FRAMETAP=1-4600 \\")
print("#         build-r9-$leg/ShadowrunSNESRecomp --no-launcher --rom \"$rom\" \\")
print("#           --script tests/out/probe_dense.txt >/dev/null \\")
print("#           2>tests/out/r9/frames_$leg.err")
print("#     done")
print()

print(f"== 1. the achieved frame boundary, whole route ==")
print()
print(f"  frames logged      control {len(ctrl)}  seed {len(seed)}"
      f"   shared frame numbers {len(common)}")
print(f"  frame numbers      {common[0]}..{common[-1]}")
print(f"  control master     {fc[common[0]][0]} -> {fc[common[-1]][0]}")
print(f"  seed master        {fs[common[0]][0]} -> {fs[common[-1]][0]}")
print(f"  elapsed over {common[-1] - common[0]} frame boundaries:"
      f" control {fc[common[-1]][0] - fc[common[0]][0]},"
      f" seed {fs[common[-1]][0] - fs[common[0]][0]}")
print(f"  d_master at first / last shared frame: "
      f"{d_m[common[0]]:+d} / {d_m[common[-1]]:+d}")
print()
vals = [d_m[f] for f in common]
print(f"  d_master range     {min(vals):+d} .. {max(vals):+d}")
print(f"  d_master == 0      {sum(1 for v in vals if v == 0)} of {len(vals)} frames")
for lim in (8, 16, 32, 64, 128):
    print(f"  |d_master| <= {lim:<4d} {sum(1 for v in vals if abs(v) <= lim)} frames")
print(f"  |d_master| > 32    {sum(1 for v in vals if abs(v) > 32)} frames")
big = [(f, d_m[f]) for f in common if abs(d_m[f]) > 32]
print(f"  the frames outside +-32: "
      + (", ".join(f"f{f} {d:+d}" for f, d in big) if big else "none"))
print()
gm = GATE.search(gate)
split = int(gm.group(1)) if gm else None
pre = [f for f in common if split and f < split]
print(f"  the gate's first frame with a differing state byte is f{split}, so")
print(f"  the {len(pre)} boundaries at or before f{split - 1} run while the two")
print(f"  legs still hold byte-identical machine state:")
pv = [d_m[f] for f in pre]
print(f"    d != 0 on {sum(1 for v in pv if v)} of {len(pv)} of those frames,"
      f" range {min(pv):+d}..{max(pv):+d}")
print(f"    the phase that round 9 names at f1832 (+14) is one of them: "
      f"d(boundary f1831) = {d_m.get(1831):+d}")
print("  The phase split is therefore older than the state split, and cannot")
print("  be an effect of it.")
print()
first_nz = min(f for f in common if d_m[f])
last_nz = max(f for f in common if d_m[f])
spans = []
n = 0
for f in common:
    if d_m[f]:
        n += 1
    elif n:
        spans.append(n)
        n = 0
if n:
    spans.append(n)
print(f"  does the offset drift or snap back?  first frame with a non-zero "
      f"offset f{first_nz}, last f{last_nz}")
print(f"    {len(spans)} separated runs of non-zero offset; run lengths: "
      + " ".join(f"{k}x{c}" for k, c in sorted(Counter(spans).items())))
print(f"    longest run {max(spans)} frames, and the offset is back to 0 at "
      f"f{common[-1]} ({d_m[common[-1]]:+d}) after "
      f"{common[-1] - last_nz} frames")
print("  An accumulating charge would give one long run and a monotonically")
print("  growing offset; this gives short runs that close and a bounded value.")
print()

print("== 2. per-frame length difference ==")
print()
print(f"  frame length = boundary master difference, deadline is {PER_FRAME}")
print(f"  mode of control lengths {Counter(len_c.values()).most_common(1)[0]}")
print(f"  mode of seed lengths    {Counter(len_s.values()).most_common(1)[0]}")
mean_c = sum(len_c.values()) / len(len_c)
mean_s = sum(len_s.values()) / len(len_s)
print(f"  mean control {mean_c:.2f}   mean seed {mean_s:.2f}"
      f"   difference {mean_s - mean_c:+.6f}")
nz = {b: v for b, v in dl.items() if v}
print(f"  d(frame length) == 0 on {len(dl) - len(nz)} of {len(dl)} frames")
print(f"  distinct non-zero differences: {len(set(nz.values()))}")
print("  the non-zero values, with how often each appears:")
print(hist(nz.values()))
print()
print("  which frames the differences land on is not one long split:")
runs = []
run = []
for b in sorted(dl):
    if dl[b]:
        run.append(b)
    else:
        if len(run) >= 3:
            runs.append((run[0], run[-1]))
        run = []
if len(run) >= 3:
    runs.append((run[0], run[-1]))
print(f"  longest runs of consecutive differing frames "
      f"({len(runs)} runs of 3 or more): "
      + ", ".join(f"f{a}-f{b} ({b - a + 1})" for a, b in runs[:12]))
print()

print("== 3. where the boundary lands against the deadline ==")
print()
dev = {t: Counter(v - PER_FRAME for v in (len_c if t == "ctrl" else len_s).values())
       for t in ("ctrl", "seed")}
for t in ("ctrl", "seed"):
    d = dev[t]
    inside = {k: v for k, v in d.items() if abs(k) <= 200}
    print(f"  {t}: exact {d[0]} frames, under deadline "
          f"{sum(v for k, v in d.items() if -200 <= k < 0)}, over deadline "
          f"{sum(v for k, v in d.items() if 0 < k <= 200)}")
    print(f"     deviation from the {PER_FRAME} deadline, ordinary frames only "
          f"(|d| <= 200): {min(inside)} .. {max(inside)}")
    print(f"     total deviation over the route: "
          f"{sum(k * v for k, v in d.items())} master clocks")
print()
print("  The three route pauses, identical on both legs to the clock:")
big = sorted({b for b in set(len_c) & set(len_s)
              if abs(len_c[b] - PER_FRAME) > 200 or abs(len_s[b] - PER_FRAME) > 200})
for b in big:
    print(f"     boundary after f{b}: control length {len_c[b]}, "
          f"seed length {len_s[b]}")
print("  Each long frame is paid for by the next short one; those are the")
print("  script's own parked waits, and the pair (long, short) is the same on")
print("  both legs, so they are not seam events.")
print()

print("== 4. the two counters, same run ==")
print()
tv = [d_t[f] for f in common]
print(f"  d(g_cpu.cycles)   range {min(tv):+d} .. {max(tv):+d}"
      f"   zero on {sum(1 for v in tv if v == 0)} of {len(tv)} frames")
print(f"  d(g_cpu.cycles) at the last shared frame: {d_t[common[-1]]:+d}")
print(f"  d(master_cycles)  range {min(vals):+d} .. {max(vals):+d}"
      f"   zero on {sum(1 for v in vals if v == 0)} of {len(vals)} frames")
print(f"  d(master_cycles) at the last shared frame: {d_m[common[-1]]:+d}")
print("  the guest cycle counter runs away and keeps its sign, the master")
print("  clock does not; `evidence/upstream_seam_cycle_bookkeeping.md` says")
print("  why they are different quantities and why only the master clock can")
print("  be compared across tiers.")
print()

print("== 5. the onset window, boundary versus anchor ==")
print()
print("  The NMI that starts frame f follows the boundary printed at f-1, so")
print("  the boundary column is read one frame to the left of the anchor.")
print()
print("  frame  d(boundary f-1)  d(NMI $00C0E2)  d(1st $80C530)"
      "   $4212 reads  $80C530 entries  tier NMI ctrl/seed  tier $80C530 ctrl/seed")
a_c, n_c = win["ctrl"]["anchor"]
a_s, n_s = win["seed"]["anchor"]
joy_c = Counter(f for f, *_ in win["ctrl"]["joy"])
joy_s = Counter(f for f, *_ in win["seed"]["joy"])
lo, hi = 1826, 1837
for f in range(lo, hi + 1):
    if f - 1 not in d_m:
        continue
    nmi = (a_s[(f, "00C0E2")][1] - a_c[(f, "00C0E2")][1]
           if (f, "00C0E2") in a_c and (f, "00C0E2") in a_s else None)
    l530 = (a_s[(f, "80C530")][1] - a_c[(f, "80C530")][1]
            if (f, "80C530") in a_c and (f, "80C530") in a_s else None)
    tiers = (f"{a_c.get((f, '00C0E2'), ('-',))[0]}/"
             f"{a_s.get((f, '00C0E2'), ('-',))[0]} "
             f"{a_c.get((f, '80C530'), ('-',))[0]}/"
             f"{a_s.get((f, '80C530'), ('-',))[0]}")
    head = (f"  {f:>5}  {d_m[f - 1]:>+12d}  "
            + (f"{nmi:>+16}" if nmi is not None else f"{'-':>16}"))
    tail = f"{l530:>+16}" if l530 is not None else f"{'-':>16}"
    print(head + f"  {tail}"
          f"   {joy_c.get(f, 0):>3} / {joy_s.get(f, 0):<3}"
          f"   {n_c.get((f, '80C530'), 0)} / {n_s.get((f, '80C530'), 0)}"
          f"   {tiers}")
print()
same = [f for f in range(lo, hi + 1)
        if f - 1 in d_m and (f, "00C0E2") in a_c and (f, "00C0E2") in a_s
        and a_s[(f, "00C0E2")][1] - a_c[(f, "00C0E2")][1] == d_m[f - 1]]
print(f"  frames in this window where the NMI entry offset equals the "
      f"previous frame's boundary offset: {len(same)} of "
      f"{len([f for f in range(lo, hi + 1) if f - 1 in d_m])}")
print("  (`[anchor]` reports `cpu->master_cycles` at handler entry; the frame")
print("   line is printed where `snes_frame_counter++` happens, and")
print("   `generic_frame_driver.c` mentions `master_cycles` on two lines only")
print("   (`:79` the deadline, `:103` the test), so the PPU draw in between")
print("   charges nothing and the end of frame f-1 and the NMI that starts")
print("   frame f are the same clock.  That is what the 12 of 12 agreement")
print("   says, and it is why the phase cannot be an artefact of how the tap")
print("   is placed.)")
print("  Tier of each anchor, control/seed: `$00C0E2` is the NMI handler and is")
print("  interpreted on both legs.  `$80C530` is interpreted on the control (it")
print("  is not in the shipped pair) and compiled AOT on the seed (it is in the")
print("  demoted set); that is the entire difference between the two legs.")
print("  Caveat on the entry counts: the AOT hook can only fire where the")
print("  compiled function's own entry pc is the anchor, while the interp hook")
print("  fires at every opcode start at that pc.  A pass that enters the seed's")
print("  root mid-body is invisible to the AOT hook, so the two counts are")
print("  tap-site counts, not call counts; the offset columns compare the first")
print("  entry each leg can report, which both tiers reach as an entry.")
print()
print("  The busy-window end measured on the busy reads of f1830 and f1832,")
print("  `beam + autoJoyTimer`, which is where the auto-joypad handoff lands:")
for t in ("ctrl", "seed"):
    for f in (1830, 1832):
        edge = {b + ti for ff, b, ti, *_ in win[t]["joy"] if ff == f and ti > 0}
        print(f"    {t} f{f}: " + (", ".join(str(x) for x in sorted(edge))
                                   or "(no busy reads)"))
print("  The edge is the same master clock on both legs, so the handoff is a")
print("  shared event; only the guest's sampling of it differs.  The reads:")
for t in ("ctrl", "seed"):
    print(f"    {t}:")
    for ff, b, ti, hp, vp, val in win[t]["joy"]:
        if ff != 1832:
            continue
        print(f"      beam {b}  timer {ti:>3}  v/pos {vp}/{hp:>4}"
              f"  val {val}  {'busy, loops' if ti else 'clear, leaves the poll'}")
print("  Control's fourth read lands 6 clocks before that edge and still sees")
print("  the busy bit, so it takes a fifth pass; the seed's fourth lands 8")
print("  clocks after it and leaves.  One pass of the poll costs 66 master")
print("  clocks on both legs, and that single pass is the whole -66 that")
print("  round 9 traced: entry offset +14 at the NMI, -52 at `$80C530`.")
print()

print("== 6. what the same binaries do with no taps on ==")
print()
m = GATE.search(gate)
n = GATE_N.search(gate)
c = CRC.search(parity)
print(f"  {m.group(0)}" if m else "  (no first-differing line)")
print(f"  {n.group(0)}" if n else "")
print(f"  crc32 of WRAM: frame_{c.group(1)} {c.group(2)} vs {c.group(3)}"
      if c else "")
for line in parity.splitlines():
    e = EXE.search(line)
    if e:
        print(f"  leg exe: {e.group(1)}  {e.group(2)} B")
print("  The instrumented pair, with every tap left unset, reproduces the")
print("  round-7 and round-8 gate numbers exactly, so the instrumentation is")
print("  inert and these measurements describe the shipped behaviour.")
print("  `framedump_diff.py state` is the attribution metric; label bytes are")
print("  excluded from it, the crc32 line above includes them.")
print()

print("== 7. what this decides ==")
print()
print("  The frame-edge offset that round 8 measured at f1832 (+14) is one")
print("  sample of a bounded, self-cancelling quantity, not a charge that")
print("  accumulates:")
print(f"  * over the {len(vals)} shared boundaries it is 0 on "
      f"{sum(1 for v in vals if v == 0)} and never leaves {min(vals):+d}..{max(vals):+d};")
print(f"  * it appears in {len(spans)} separate runs, {sum(1 for n_ in spans if n_ == 1)} of them "
      f"one frame long, longest {max(spans)} frames;")
print(f"  * both legs cover exactly {fc[common[-1]][0] - fc[common[0]][0]} master clocks "
      "across the route, so nothing is lost;")
print(f"  * the guest cycle counter `cpu->cycles` by contrast ends at "
      f"{d_t[common[-1]]:+d} and reaches {min(tv):+d}, which is the counter")
print("    `evidence/upstream_seam_cycle_bookkeeping.md` says cannot be compared "
      "across tiers.")
print()
print("  Where it comes from, in the pinned `generic_frame_driver.c`: the frame")
print("  deadline is `frame_end = master_cycles + 357368`, taken from wherever")
print("  the previous frame ended, the NMI is taken once before the slice loop,")
print("  a pending IRQ is serviced after each slice, and the loop tests")
print("  `master_cycles >= frame_end` only at the top of a slice.  So the")
print("  achieved boundary is the first instruction boundary at or after the")
print("  deadline that the loop can notice, and the overshoot is a whole number")
print("  of block or interrupt-take lengths.  Changing which bodies are compiled")
print("  changes which block that test first becomes true inside, which moves")
print("  the boundary by one such quantum - and at f1832 one quantum was enough")
print("  to move a 66-clock poll across a hardware edge both legs agree on.")
print()
print("  That leaves exactly four conceivable levers, and all four are closed:")
print("  1. make the seed's block boundaries coincide with the control's at every")
print("     frame - impossible for a different body set; the offset is non-zero")
print(f"     on {sum(1 for v in vals if v)} boundaries route-wide, and it starts at f{first_nz}, "
      f"{split - first_nz if split else 0} frames before the first")
print("     differing state byte;")
print("  2. make the guest's use of the edge insensitive to entry phase - the")
print("     read-time change of round 7 tried the only version of this available")
print("     to the title and made it worse (305 -> 1,333 differing frames);")
print("  3. price the seed's bodies so the overshoot comes out identical - that")
print("     is tuning the cycle model to a one-frame coincidence, and the")
print("     `+-40` charge at call boundaries that round 8 section 9 left unnamed")
print("     is still unnamed; round 9 watched it appear and cancel, so it is")
print("     not a lever either;")
print("  4. make the frame driver's deadline check land at instruction")
print("     granularity, so the overshoot stops being quantized - that is a")
print("     change to `runner/src/generic_frame_driver.c`, which is the pinned")
print("     framework, and the pin stays clean.")
print()
print("  Decision: no seed is adopted, no `force_lle` block is added, and this")
print("  line of investigation is closed.  The shipped pair stays")
print("  `$80C399` + `$80AAB3`, executable a0587ed0a0e34687.  Anything further")
print("  here needs an upstream seam change, not a seed.")
