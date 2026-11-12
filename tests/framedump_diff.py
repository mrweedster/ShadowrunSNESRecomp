#!/usr/bin/env python3
"""Compare two --framedump runs byte-level, in nine alignments.

    framedump_diff.py horizon  run1 run2   THE CROSS-PATH GATE: the fidelity
                         [FROM TO]          horizon, judged against a recorded
                         [BASELINE.json]    baseline. At the same host frame,
                                            with the frame-label bytes ignored,
                                            the first frame whose state
                                            difference never comes back inside
                                            the noise band. Exits 0 pass, 1
                                            fail, 2 no verdict: the scan misses
                                            the baseline's horizon, there is no
                                            baseline file to judge against, or
                                            the legs were not built from the
                                            inputs that baseline names: each
                                            leg's dump dir carries a
                                            run_manifest.json (provenance.py)
                                            and a recorded baseline carries the
                                            pair's, so a rerun built from other
                                            programs stops rather than judging
                         [--inputs-changed]   judge the pair anyway and print the
                                             input delta: a bisect step changes
                                             src/gen on purpose, and the baseline
                                             is the reference across those steps
    framedump_diff.py offsets  run1 run2   per-frame WRAM byte-diff table
    framedump_diff.py ksweep   run1 run2   compare run1[f] vs run2[f+k]
    framedump_diff.py guest    run1 run2   match frames by the guest's own
                                            tick counter $7E1C92 (16-bit LE
                                            in the WRAM dump) before diffing
    framedump_diff.py tick     run1 run2   the tick-label offset timeline: at
                                            every shared counter, how far apart
                                            are the two legs in HOST frames
    framedump_diff.py shift    run1 run2   the shift-compensated physics probe:
                                            same guest tick, host frames aligned,
                                            kernel/timer label bytes excluded
    framedump_diff.py drift    run1 run2   where a long route diverges: the
                                            per-frame diff curve and the first
                                            frame whose state stops matching
    framedump_diff.py drift    run1 run2 FROM TO
                                            same scan restricted to a frame
                                            range, decoded byte-exactly
    framedump_diff.py state    run1 run2   name the state bytes at the same host
                         [FROM TO]        frame: the first frames where a
                                         non-label WRAM byte differs, with both
                                         legs' values (`drift` counts blocks)
    framedump_diff.py clock    run1 run2   the game's tick counter at the same
                                            host frame in both legs: constant
                                            delta = phase, stepping = one leg
                                            ran a guest frame the other didn't
    framedump_diff.py byte     run1 run2   one WRAM byte's value timeline in
                         ADDR [FROM TO]    both legs, with a value histogram
                                            per leg: same value set with the
                                            counts moved is phase, a value one
                                            leg never writes is a state change
    framedump_diff.py cpdump   run1 run2   the route's tagged checkpoints compared:
                         [TAG...]         guest clock, PPU/HDMA regs, image
                                         hashes at every `dump <tag>` both runs
                                         have (no CPU registers are dumped)
    framedump_diff.py scene    run ref[:F] how scene-like each frame is: the
                                            count of 1 KiB WRAM blocks matching
                                            reference frame F (default: F's own
                                            dir's last frame), sampled every
                                            STEP frames (20 by default)

`horizon` is the only mode here with a verdict, and the verdict is measured
rather than assumed: the two code paths stop a long guest loop at different
points of the same frame, so byte-identity at a fixed host frame index is not a
cross-path test once AOT coverage is real (framework Axis 6 ruling, and
evidence/a7 §8.6). Every other mode is how you read *why* a horizon moved;
none of them is a pass/fail rule.

`guest` and `shift` pair by the guest tick counter, which is the honest
coordinate for presentation and a misleading one for state. While the paths
agree completely their frames are byte-identical at the same host index even
though the counter inside them sits 3 apart, so counter pairing reads 85 B of
difference where f<->f reads 0 B (tests/out/xp_aot against tests/out/xp_lle,
f15900-f16121). `offsets` answers "which bytes and how often", `ksweep` finds
the host phase.

`drift` answers the question a long route actually poses: not "do they differ"
(they do, by a handful of label bytes almost everywhere) but "at which frame
does the state stop matching, and how fast". Reading 128 KiB twice per frame is
the cost, so it first scans 1 KiB blocks with crc32 and only decodes bytes
around the onset. `horizon` rides the same scan and the same block prefilter.
"""
import glob
import hashlib
import json
import os
import sys
import zlib
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance as prov  # noqa: E402  (same directory as this file)


def frames(d):
    return sorted(
        int(e[6:12])
        for e in os.listdir(d)
        if e.startswith("frame_") and e.endswith("_wram.bin")
    )


def rd(d, f):
    p = os.path.join(d, f"frame_{f:06d}_wram.bin")
    return open(p, "rb").read() if os.path.isfile(p) else None


def offs(a, b):
    return [i for i, (x, y) in enumerate(zip(a, b)) if x != y]


def money(s):  # $7Exxxxx with a leading $ and 5 hex digits
    return f"$7E{s:05X}"


def mode_offsets(d1, d2):
    offcount = Counter()
    worst = []
    same = 0
    fs = frames(d1)
    for f in fs:
        a, b = rd(d1, f), rd(d2, f)
        if a is None or b is None:
            worst.append((10**9, f, []))
            continue
        o = offs(a, b)
        if not o:
            same += 1
        else:
            offcount.update(o)
            worst.append((len(o), f, [(i, a[i], b[i]) for i in o[:12]]))
    print(f"frames={len(fs)} identical={same} differing={len(fs)-same}")
    real = [w for w in worst if w[0] != 10**9]
    print(f"byte-frames: {sum(offcount.values())} byte positions differ across "
          f"{len(fs) - same} frames, "
          f"max {max((w[0] for w in real), default=0)} bytes in one frame")
    print(f"distinct differing offsets: {len(offcount)}")
    for o, n in sorted(offcount.items(), key=lambda t: -t[1])[:20]:
        print(f"  {money(o)}  differs in {n} frames")
    worst.sort(reverse=True)
    print("worst frames:")
    for w in worst[:8]:
        n, f, samp = w
        if n == 10**9:
            print(f"  f{f}: missing counterpart")
            continue
        s = " ".join(f"{money(o)}:{x:02X}/{y:02X}" for o, x, y in samp)
        print(f"  f{f}: {n} bytes  {s}")


def mode_ksweep(d1, d2):
    fs = frames(d1)
    for k in (-2, -1, 0, 1, 2):
        same = 0
        diffs = []
        worst = (0, 0)
        n = 0
        for f in fs:
            a, b = rd(d1, f), rd(d2, f + k)
            if a is None or b is None:
                continue
            n += 1
            d = len(offs(a, b))
            if d == 0:
                same += 1
            else:
                diffs.append(d)
                if d > worst[0]:
                    worst = (d, f)
        med = sorted(diffs)[len(diffs) // 2] if diffs else 0
        print(f"k={k:+d}: compared={n} identical={same} median_diff={med} "
              f"worst={worst[0]}@f{worst[1]} sum={sum(diffs)}")


def counter_index(d):
    m = defaultdict(list)
    for f in frames(d):
        with open(os.path.join(d, f"frame_{f:06d}_wram.bin"), "rb") as fh:
            fh.seek(0x1C92)
            c = int.from_bytes(fh.read(2), "little")
        m[c].append((f, os.path.join(d, f"frame_{f:06d}_wram.bin")))
    return m


def _pair_ticks(d1, d2, lo=None, hi=None):
    """(guest counter, run1 host frame, run2 host frame) for shared ticks.

    Only the *first* host frame carrying a given counter is used, so a tick a
    paused or stalled run repeats cannot pair one run's frame with an unrelated
    frame of the other. lo/hi filter on run1's host frame index.
    """
    m1, m2 = counter_index(d1), counter_index(d2)
    for c in sorted(set(m1) & set(m2)):
        f1, _ = m1[c][0]
        f2, _ = m2[c][0]
        if lo is not None and f1 < lo:
            continue
        if hi is not None and f1 > hi:
            continue
        yield c, f1, f2


def mode_guest(d1, d2):
    m1, m2 = counter_index(d1), counter_index(d2)
    common = sorted(set(m1) & set(m2))
    offc = Counter()
    worst = []
    same = tot = 0
    for c in common:
        f1, p1 = m1[c][-1]
        f2, p2 = m2[c][-1]
        a, b = open(p1, "rb").read(), open(p2, "rb").read()
        o = offs(a, b)
        tot += 1
        if not o:
            same += 1
        else:
            offc.update(o)
            worst.append((len(o), c, f1, f2, [(i, a[i], b[i]) for i in o[:10]]))
    print(f"guest-counter pairs={tot} identical={same} differing={tot-same}")
    print(f"distinct offsets: {len(offc)}")
    for o, n in sorted(offc.items(), key=lambda t: -t[1])[:16]:
        print(f"  {money(o)} in {n} pairs")
    worst.sort(reverse=True)
    for n, c, f1, f2, samp in worst[:6]:
        s = " ".join(f"{money(o)}:{x:02X}/{y:02X}" for o, x, y in samp)
        print(f"  counter={c} run1@f{f1} run2@f{f2}: {n}B {s}")


def mode_tick(d1, d2):
    """Host-frame separation at each shared guest tick.

    The guest's own counter is the only label both legs agree on, so
    (run1 frame) - (run2 frame) at the same counter is the phase between them.
    A constant phase means one bounded event shifted the label and nothing
    drifts afterwards; a phase that grows without bound means the two legs
    disagree on tick rate, which is a real cross-path bug.
    """
    m1, m2 = counter_index(d1), counter_index(d2)
    common = sorted(set(m1) & set(m2))
    if not common:
        print("no shared guest tick counters -- nothing to compare")
        return
    print(f"counters: run1={len(m1)} run2={len(m2)} shared={len(common)} "
          f"range={common[0]}..{common[-1]}")
    print(f"only in run1: {len(set(m1) - set(m2))}  "
          f"only in run2: {len(set(m2) - set(m1))}")
    seg = []  # [k, first_counter, last_counter, first_frame, last_frame]
    for c in common:
        f1 = m1[c][0][0]
        f2 = m2[c][0][0]
        k = f1 - f2
        if seg and seg[-1][0] == k:
            seg[-1][2] = c
            seg[-1][4] = f1
        else:
            seg.append([k, c, c, f1, f1])
    print("phase segments (run1 host frame - run2 host frame, same guest tick):")
    for k, c0, c1, f0, f1 in seg:
        print(f"  k={k:+d}  counters {c0}..{c1}  host f{f0}..f{f1}  "
              f"({c1 - c0 + 1} ticks)")
    steps = [(seg[i][1], seg[i][0] - seg[i - 1][0]) for i in range(1, len(seg))]
    print("steps:", ", ".join(f"counter {c}: {d:+d}" for c, d in steps)
          if steps else "none -- phase is constant across the whole run")


# Label bytes, not physics: the host's own frame kernel counter and the game's
# documented timer singletons. `shift` ignores these so what is left is state
# the two legs genuinely share. Addresses are dump offsets ($7E00000 base).
KERNEL_WINDOW = (0x01C80, 0x01D40)
TIMER_SINGLETONS = (0x0012C, 0x0012E, 0x0012F, 0x00132)

# Scan granularity for `drift`: 128 KiB of WRAM is 128 of these, so a frame
# that only moves label bytes lights up at most two of them.
BLOCK = 1024


def _is_label(off):
    return KERNEL_WINDOW[0] <= off <= KERNEL_WINDOW[1] or off in TIMER_SINGLETONS


def _diff_nolabel(a, b):
    return [i for i, (x, y) in enumerate(zip(a, b)) if x != y and not _is_label(i)]


def mode_shift(d1, d2, samples=40, margin=12):
    """Same guest tick, host frames lined up, label bytes ignored.

    For a sampled guest counter c: run1 reaches it at host frame f1, run2 at
    f2, so the same-host-frame pairing is run1[f1] vs run2[f1 + (f2 - f1)].
    Pairing by label instead (k=0) compares different amounts of any held
    press, which is exactly where counter-aligned diffs first appear; the
    phase explains them away.
    """
    m1, m2 = counter_index(d1), counter_index(d2)
    common = sorted(set(m1) & set(m2))
    if not common:
        print("no shared guest tick counters -- nothing to compare")
        return
    if len(common) > samples:
        stride = max(1, len(common) // samples)
        picked = common[::stride][:samples]
        if common[-1] not in picked:
            picked.append(common[-1])
    else:
        picked = common
    host2 = {f: p for c in common for (f, p) in m2[c]}
    print(f"sampled guest counters: {len(picked)} of {len(common)} shared")
    print("  counter      f1      f2  diff@k=0   best k   best diff  aligned at")
    exact = 0
    for c in picked:
        f1 = m1[c][0][0]
        f2 = m2[c][0][0]
        pa = m1[c][0][1]
        a = open(pa, "rb").read()
        k0 = f2 - f1
        best = (10 ** 9, None, None)
        zero = None
        for k in range(k0 - margin, k0 + margin + 1):
            pb = host2.get(f1 + k)
            if pb is None:
                continue
            d = _diff_nolabel(a, open(pb, "rb").read())
            if k == 0:
                zero = len(d)
            if len(d) < best[0]:
                best = (len(d), k, f1 + k)
            if not d:
                break
        n, bk, bf = best
        if n == 0:
            exact += 1
        print(f"  {c:7d} {f1:7d} {f2:7d} "
              f"{(str(zero) if zero is not None else '-'):>9} "
              f"{('%+d' % bk) if bk is not None else '-':>8} {n:10d}  "
              f"{('host f%d' % bf) if bf is not None else 'no counterpart'}")
    print(f"byte-identical after phase alignment: {exact} of {len(picked)}")


def mode_drift(d1, d2, threshold=3, detail=24, lo=None, hi=None):
    """Where a long route diverges: per-frame diff curve, then the onset.

    A route that only disagrees on label bytes keeps this count at one or two
    blocks forever. A route that really desyncs goes to double digits, and the
    frame where that starts is the interesting number -- not the total. The
    exact bytes are then decoded in a window around the onset. lo/hi restrict
    the scan to a frame range, which is how a window in the middle of a long
    route gets decoded byte-exactly without reading the whole run.
    """
    fs1, fs2 = frames(d1), frames(d2)
    common = sorted(set(fs1) & set(fs2))
    if lo is not None:
        common = [f for f in common if f >= lo]
    if hi is not None:
        common = [f for f in common if f <= hi]
    if not common:
        print("no shared host frames -- nothing to compare")
        return
    curve = []  # (frame, differing 1 KiB blocks)
    for f in common:
        a, b = rd(d1, f), rd(d2, f)
        if a is None or b is None:
            continue
        n = sum(1 for i in range(0, len(a), BLOCK)
                if zlib.crc32(a[i:i + BLOCK]) != zlib.crc32(b[i:i + BLOCK]))
        curve.append((f, n))
    if not curve:
        print("nothing to compare")
        return

    bin_w = 500
    bins = defaultdict(list)
    for f, n in curve:
        bins[f // bin_w].append(n)
    print(f"frames compared: {len(curve)}   differing 1 KiB blocks per frame "
          f"(WRAM is 128 KiB = 128 blocks)")
    print("   frames     mean   max")
    for b in sorted(bins):
        v = bins[b]
        print(f"  {b*bin_w:6d}-{b*bin_w+len(v)-1:<6d} {sum(v)/len(v):6.2f} "
              f"{max(v):5d}")

    onset = next((f for f, n in curve if n > threshold), None)
    peak = max(curve, key=lambda t: t[1])
    head = (f"first frame over {threshold} differing blocks: {onset}"
            if onset is not None else
            f"first frame over {threshold} differing blocks: never -- the two "
            "legs stay within label-block distance")
    print("\n" + head)
    print(f"worst frame: f{peak[0]} with {peak[1]} differing blocks")
    if onset is None and lo is None:
        return

    anchor = onset if onset is not None else common[0]
    print(f"\nexact bytes around the onset (f{anchor-detail}..f{anchor+detail}):")
    worst = (0, 0, [])
    for f in range(max(common[0], anchor - detail),
                   min(common[-1], anchor + detail) + 1):
        a, b = rd(d1, f), rd(d2, f)
        if a is None or b is None:
            continue
        off = offs(a, b)
        phys = [o for o in off if not _is_label(o)]
        if len(off) > worst[0]:
            worst = (len(off), f, off)
        print(f"  f{f:6d}: {len(off):6d} bytes total, {len(phys):6d} outside "
              f"label bytes")
    n, f, off = worst
    print(f"\nworst frame in the window: f{f}, {n} bytes")
    counts = Counter((o & ~0xFF) for o in off)
    for base, c in counts.most_common(12):
        print(f"  {money(base)} +0xFF: {c} bytes")


def mode_state(d1, d2, lo=None, hi=None, show=8, hits=6):
    """Which state bytes differ, at the same host frame, as the divergence starts.

    usage: framedump_diff.py state run1 run2 [FROM TO]

    `drift` says how far apart the legs are; this says *which bytes*.  It walks
    the same f<->f coordinate the gates use (the tick probe has to show the phase
    constant first, or this names bytes that are merely out of step), uses the
    same 1 KiB crc prefilter, and prints the first `hits` frames in which a byte
    outside the label rule differs, with that frame's count and the exact
    `run1 -> run2` values.  The last two lines count the whole range, so a small
    number of printed frames cannot hide how wide the split is.
    """
    fs1, fs2 = frames(d1), frames(d2)
    common = sorted(set(fs1) & set(fs2))
    if lo is not None:
        common = [f for f in common if f >= lo]
    if hi is not None:
        common = [f for f in common if f <= hi]
    if not common:
        print("no shared host frames -- nothing to compare")
        return
    first = nframes = total = printed = 0
    for f in common:
        a, b = rd(d1, f), rd(d2, f)
        if a is None or b is None:
            continue
        body, tot = _diff_counts(a, b)
        if not body:
            continue
        if not first:
            first = f
        nframes += 1
        total += body
        if printed >= hits:
            continue
        printed += 1
        d = _diff_nolabel(a, b)
        print(f"\n  f{f}: {len(d)} state bytes differ "
              f"({tot} bytes including label bytes)")
        for o in d[:show]:
            print(f"      {money(o)}: {a[o]:02X} -> {b[o]:02X}")
        if len(d) > show:
            print(f"      ... {len(d) - show} more")
    if not first:
        print(f"no non-label WRAM byte differs in {len(common)} shared frames")
        return
    print(f"\nfirst frame with a state byte differing: f{first}")
    print(f"frames with a state byte differing: {nframes} of {len(common)}"
          f"   total state bytes: {total}")


# The noise band for `horizon`: how far apart the two paths' WRAM may be at the
# same host frame while still counting as the same state sampled at different
# points of the frame. Measured, not guessed -- on the shipped cross-path pair
# (tests/out/xp_aot against tests/out/xp_lle) every frame up to f16121 is
# byte-exact outside the label bytes (0 B across f15900-f16121), and the widest
# pre-onset band on the narrower AOT sets is 3 B (evidence/a7 §3, §5). The band
# is deliberately not 0: "first frame that differs at all" is not a usable
# metric, because every leg puts label bytes out of step during boot.
NOISE_MAX = 3
# How far the frame label may be moved when testing whether a difference is
# sampling phase. The tick-label offset between the paths is piecewise constant
# in steps of 0/+1/+3/+37 (evidence/a5), so +-3 absorbs the local phase without
# pretending away a real divergence.
ALIGN_MAX = 3
# A horizon may not move earlier than its recorded baseline by more than this
# many host frames. One frame of slack is presentation, not physics.
HORIZON_SLACK = 1
# How much longer a *healing* stretch out of the band may run before the horizon
# before it stops being presentation jitter worth tolerating. The port's route is
# scripted input, so the same build gives the same stretches every run and this
# can only move because the code under test moved.
PRE_RUN_SLACK = 10


def _diff_counts(a, b):
    """(bytes outside the frame-label bytes, bytes total) between two frames.

    1 KiB crc32 first: a route's frames are usually identical, and pairing all
    25,902 frames of a long route means reading 128 KiB twice per frame -- 6.6
    GiB decoded to arrive at one number.
    """
    body = tot = 0
    for i in range(0, min(len(a), len(b)), BLOCK):
        x, y = a[i:i + BLOCK], b[i:i + BLOCK]
        if zlib.crc32(x) == zlib.crc32(y):
            continue
        for j, (p, q) in enumerate(zip(x, y)):
            if p != q:
                tot += 1
                if not _is_label(i + j):
                    body += 1
    return body, tot


def frame_profile(d1, d2, lo=None, hi=None):
    """[(host frame, bytes outside the frame-label bytes, bytes total)], f<->f.

    The same host frame is the coordinate that measures state rather than phase.
    While the two paths agree, their frames are byte-identical at the same index
    even though the guest tick counter inside them sits a constant 3 apart
    (tests/out/xp_aot against tests/out/xp_lle, f15900-f16121: 0 B outside the
    label bytes, at a tick phase of -3). Pairing by that counter instead compares
    states one sample apart and invents a difference: the same pair reads 85 B
    there, and 0 B once the label is moved back. So `guest` and `shift` are for
    reading presentation, and this is what the gate runs on.
    """
    have = set(frames(d2))
    out = []
    for f in frames(d1):
        if (lo is not None and f < lo) or (hi is not None and f > hi):
            continue
        if f not in have:
            continue
        a, b = rd(d1, f), rd(d2, f)
        if a is None or b is None:
            continue
        body, tot = _diff_counts(a, b)
        out.append((f, body, tot))
    return out


def horizon_of(prof):
    """(last frame that matched, first frame after it) -- or None.

    An onset in the only sense the cross-path question needs. A stopping-point
    difference that heals is not evidence of anything: the f496 boot burst moves
    1443 B and is gone a frame later, and the menu stretches of this route run
    2-3 KB out of step for thousands of frames and come back to 0 B. A difference
    that never returns inside the band is where the two paths stopped describing
    the same game -- and it is reproducible across instruments: on the shipped
    pair it is f16122, which is also where evidence/a7 §3 put it from the
    byte-write stamps.

    None when the state never left the band, or had left it before the first
    sampled frame.
    """
    for i in range(len(prof) - 1, -1, -1):
        if prof[i][1] <= NOISE_MAX:
            return (prof[i], prof[i + 1]) if i + 1 < len(prof) else None
    return None


def _runs(prof):
    """[(first frame, length in frames, peak bytes)] per out-of-band stretch.

    A stretch is a run of consecutive paired frames whose state difference is
    outside the noise band. Every stretch that ends before the horizon healed on
    its own -- presentation getting out of step and back in line, which the
    ruling accepts as harmless. The stretch that does not heal is the last one,
    and it starts at the horizon.
    """
    runs, cur = [], None
    for f, body, _ in prof:
        if body > NOISE_MAX:
            if cur is None:
                cur = [f, 1, body]
            else:
                cur[1] += 1
                cur[2] = max(cur[2], body)
        elif cur is not None:
            runs.append(tuple(cur))
            cur = None
    if cur is not None:
        runs.append(tuple(cur))
    return runs


def _prov_legs(d1, d2):
    """Each leg's run_manifest.json, plus a short block saying what it says.

    Nothing here is a verdict on its own: it answers "which program produced
    this leg", which is the question every other number in this file depends on.
    A leg with no manifest is a leg nobody recorded, and that is said out loud.
    """
    p1, p2 = prov.load(d1), prov.load(d2)
    print("provenance of the two legs (run_manifest.json):")
    for tag, d, p in (("run1", d1, p1), ("run2", d2, p2)):
        if p is None:
            print(f"  {tag}  {d}\n        no manifest recorded -- "
                  f"python3 tests/provenance.py record <binary> {d}")
            continue
        bt, fw, gs = p.get("build_tree"), p.get("framework"), p.get("generated_set")
        exe = p["exe"]
        print(f"  {tag}  {exe['sha256'][:16]}  {exe['bytes']:,} B  "
              f"{os.path.basename(exe['path'])}")
        if gs:
            stale = "" if gs.get("describes_this_binary", True) else \
                "   <-- live src/gen, not this binary's set"
            print(f"        gen {gs['units']} units / {gs['promoted_functions']} "
                  f"promoted fns / {gs['dispatch_entries']} dispatch entries  "
                  f"sha256 {gs['sha256'][:16]}{stale}")
        else:
            print("        generated set: unknown from this artefact")
        extra = []
        if fw:
            extra.append(f"fw {fw.get('rev') or 'unknown'}"
                         + ("-dirty" if fw.get("dirty") else ""))
        if bt:
            extra.append(f"config {bt.get('config')}")
            extra.append(f"embed {bt.get('embed_rom')}")
        if extra:
            print("        " + "  ".join(extra))
        for w in p.get("warnings", []):
            print(f"        WARN {w}")
    return p1, p2


def _prov_against_baseline(baseline, legs):
    """Do these legs match the inputs the baseline recorded? -> (bad, notes)

    Only the *inputs* are compared -- generated set, framework revision, build
    options -- not the executable's own bytes, so rebuilding the same sources in
    a fresh tree is not mistaken for a different program.

    A baseline with no provenance block gets a note, not a verdict: the recorded
    gates were captured before this check existed, and refusing to judge them
    would make the kit useless for exactly the comparisons it already has.

    What does something about `bad` is the caller: a bisect step regenerates
    src/gen on purpose, so `--inputs-changed` turns these into notes. That is
    deliberate -- a gate's metric is a monitored property with a recorded
    reference, and the reference has to survive the steps that test it.
    """
    if not baseline or not os.path.isfile(baseline):
        return [], []          # the missing baseline is reported further down
    try:
        stored = json.load(open(baseline)).get("provenance")
    except ValueError as e:
        return [f"baseline {baseline} is not readable JSON ({e})"], []
    if not stored:
        return [], [f"{os.path.basename(baseline)} records no provenance: it was "
                    "captured before this check existed, so these legs cannot be "
                    "bound to the programs that made them. The next capture with "
                    "--update will bind them."]
    bad = []
    for tag, p in zip(("run1", "run2"), legs):
        want = stored.get(tag)
        if not want:
            bad.append(f"{tag}: the baseline records no inputs for this leg")
            continue
        if p is None:
            bad.append(f"{tag}: no run_manifest.json in this leg's directory, so "
                       "nothing proves it is the input the baseline names")
            continue
        a, b = prov.source_key_of(want), prov.source_key_of(p)
        for f in prov.diff_keys(a, b):
            bad.append(f"{tag}: {f} was {a[f]} in the baseline, {b[f]} here")
    return bad, []


def mode_horizon(d1, d2, lo=None, hi=None, baseline=None, update=False,
                 inputs_changed=False):
    """The cross-path fidelity horizon, and the verdict against a baseline.

    The two code paths -- the shipped AOT binary and the interpreted floor --
    stop a long guest loop at different points of the same frame, because the
    frame boundary is a fixed master-clock budget that each path can only check
    where it is able to (evidence/a7 §8; the framework records the ruling under
    Axis 6 of docs/validation/accuracy-history.md). So two frame dumps taken at
    the same host index can differ purely in which pass of that loop had already
    run, with every written value still in the same order. This mode asks the two
    questions that have to stay separate:

      1. Where do the paths stop agreeing about the game's state in a way that
         never heals? That frame is the horizon. It is a monitored property with
         a recorded baseline, not a byte-exact target: later is an improvement,
         earlier is a regression.
      2. Is the difference at the horizon a question of where the frame was cut,
         or is a value actually wrong? Whole-frame realignment answers the first
         part here; tests/wram_trace.py --streams settles the second.

    Everything after the horizon is downstream consequence, reported for context
    only: once the legs sample the same state at different points of a loop the
    diff grows by itself (f16122 59 B, f16132 419 B, f25900 30 KB) and that
    growth is not evidence of a bug.

    Exit codes: 0 pass (horizon and the pre-horizon band both hold against the
    baseline) or 0 measured-only when no baseline argument is given at all; 1
    fail (the horizon moved earlier, or the state before it differs beyond the
    band); 2 no verdict: nothing to compare, no coverage of the baseline, a
    baseline path that does not exist, or the legs are not built from the inputs
    the baseline recorded -- a horizon difference between different programs is
    not a measurement of anything (that is how the stale staged bundle read as a
    physics split, evidence/c1_staged_bundle_stale.md).
    """
    p1, p2 = _prov_legs(d1, d2)
    bad, notes = _prov_against_baseline(baseline, (p1, p2))
    if bad and inputs_changed:
        # A deliberate experiment -- the bisect gate demotes guest functions and
        # regenerating src/gen is the point of every step -- gets the delta
        # printed and judged anyway. Absent this flag the same delta is an
        # accident nobody noticed, which is the thing worth refusing for.
        notes = [f"inputs changed on purpose ({b})" for b in bad] + notes
        bad = []
    for n in notes:
        print(f"  note: {n}")
    if bad:
        print()
        for b in bad:
            print("  " + b)
        print("VERDICT: no verdict -- these legs are not the inputs the recorded "
              "baseline names, so a horizon measured here would compare two "
              "different programs. Either rebuild the inputs the baseline "
              "names, or if changing them is the point of the run -- a bisect "
              "step regenerates src/gen by design -- say so with "
              "--inputs-changed and the delta is printed and the pair is judged "
              "anyway. The scan was not run at all: ~26k frames of decoding to "
              "produce a number that would mean nothing.")
        return 2
    prof = frame_profile(d1, d2, lo, hi)
    if not prof:
        print("no host frame is present in both runs in this range -- "
              "nothing to compare")
        return 2
    cut = horizon_of(prof)
    onset = cut[1] if cut else None
    pre = [p for p in prof if onset is None or p[0] < onset[0]]
    runs = _runs(prof)
    healed = runs[:-1] if onset else runs
    pre_frames = len(pre)
    longest = max((r[1] for r in healed), default=0)
    peak = max((r[2] for r in healed), default=0)
    print(f"paired at the same host frame: {len(prof)} frames "
          f"(f{prof[0][0]}..f{prof[-1][0]}), frame-label bytes ignored")
    print(f"noise band: {NOISE_MAX} B outside the frame-label bytes")
    print(f"before the horizon: {pre_frames} frames; {len(healed)} stretches left "
          f"the band and came back on their own (longest {longest} frames, "
          f"peak {peak} B)")
    if onset is None:
        if not runs:
            print(f"horizon: none -- the state stays inside the band for all "
                  f"{len(prof)} frames")
        elif len(runs) == 1 and prof[0][1] > NOISE_MAX:
            print(f"horizon: before this range -- the first sampled frame "
                  f"f{prof[0][0]} is already {prof[0][1]} B out of band")
        else:
            print(f"horizon: none -- every stretch that left the band came back "
                  f"on its own (longest {longest} frames, peak {peak} B)")
    else:
        f0 = onset[0]
        print(f"horizon: host f{f0}; the last frame that still matched was "
              f"f{cut[0][0]}")
        print(f"  at the horizon: {onset[1]} B outside the frame labels "
              f"({onset[2]} B including them)")
        a = rd(d1, f0)
        print("  whole-frame realignment at the horizon "
              f"(run1 f{f0} against run2 f{f0}+k, labels ignored):")
        best = (10 ** 9, None)
        for k in range(-ALIGN_MAX, ALIGN_MAX + 1):
            b, aa = rd(d2, f0 + k), a
            if b is None or aa is None:
                continue
            v, _ = _diff_counts(aa, b)
            if v < best[0]:
                best = (v, k)
            print(f"    k={k:+d}: {v:6d} B"
                  + ("   <- horizon pairing" if k == 0 else ""))
        mv, mk = best
        if mv == 0:
            print(f"  a whole-frame shift of k={mk:+d} removes it: one leg is a "
                  "frame behind in presentation, not in state")
        else:
            print(f"  no whole-frame shift removes it (best k={mk:+d} leaves "
                  f"{mv} B): the difference is inside the frame -- one leg ran a "
                  "pass of a guest loop the other had not reached")
        print("  after the horizon (consequence, not evidence):")
        for ahead in (10, 100, 1000, 5000):
            row = next((p for p in prof if p[0] >= f0 + ahead), None)
            if row:
                print(f"    +{ahead:5d} frames: f{row[0]}: {row[1]:6d} B")
        print(f"    last frame f{prof[-1][0]}: {prof[-1][1]:6d} B")

    summary = {"mode": "horizon", "pair": [d1, d2], "noise_max": NOISE_MAX,
               "range": [prof[0][0], prof[-1][0]], "frames": len(prof),
               "horizon_host": onset[0] if onset else None,
               "horizon_body": onset[1] if onset else 0,
               "horizon_total": onset[2] if onset else 0,
               "pre_frames": pre_frames, "healed_runs": len(healed),
               "pre_longest_run": longest, "pre_peak": peak,
               "last_body": prof[-1][1]}
    if p1 or p2:
        # The recorded baseline has to say which programs made it, or a later
        # run of anything can be judged against it. Whole manifests, not hashes
        # alone: the paths and warnings in them are what a reader needs to know
        # when a later comparison refuses to judge.
        summary["provenance"] = {"run1": p1, "run2": p2}
    if not baseline:
        print("\nmachine summary: " + " ".join(
            f"{s}={summary[s]}" for s in
            ("horizon_host", "horizon_body", "pre_frames", "healed_runs",
             "pre_longest_run", "pre_peak", "last_body")))
        print("VERDICT: no baseline given -- measured only, nothing was judged")
        return 0
    if update:
        os.makedirs(os.path.dirname(baseline) or ".", exist_ok=True)
        json.dump(summary, open(baseline, "w"), indent=1)
        print(f"\nbaseline recorded: {baseline}")
        return 0
    if not os.path.isfile(baseline):
        print(f"\nno baseline at {baseline} -- nothing was judged. Everything "
              "above is a measurement, not a verdict: point at the recorded "
              "baseline in tests/baselines/, or pass --update to record one")
        print("VERDICT: no baseline")
        return 2

    base = json.load(open(baseline))
    bh, bp = base.get("horizon_host"), summary["horizon_host"]
    print(f"\nverdict against baseline {baseline} "
          f"(horizon f{bh}; before it {base.get('healed_runs')} stretches, "
          f"longest {base.get('pre_longest_run')} frames):")
    fails = []
    if bh is not None and prof[-1][0] < bh - HORIZON_SLACK:
        print(f"  no coverage: this scan ends at f{prof[-1][0]} and the baseline "
              f"horizon is f{bh}, so nothing has been shown about it")
        return 2
    if bp is None and runs and prof[0][1] > NOISE_MAX:
        print(f"  no coverage: the scan starts at f{prof[0][0]}, already "
              f"{prof[0][1]} B out of band, so the horizon it crossed on the way "
              "there is not visible -- cannot say it is gone")
        return 2
    blong = base.get("pre_longest_run", 0)
    if longest > blong + PRE_RUN_SLACK:
        fails.append(f"a state difference stayed out of the band for {longest} "
                     f"frames before the horizon, against {blong} in the "
                     "baseline -- the paths lose the same state much earlier, "
                     "even though it comes back")
    if bh is None:
        if bp is None:
            print("  holds: neither pair has a horizon")
        else:
            print(f"  improvement: the baseline pair had a horizon at f{bh}, "
                  "this pair has none")
    elif bp is None:
        print(f"  improvement: the baseline horizon f{bh} is gone on this pair")
    elif bp < bh - HORIZON_SLACK:
        fails.append(f"horizon moved earlier: f{bp} vs baseline f{bh} "
                     f"({bh - bp - HORIZON_SLACK} frames sooner)")
    elif bp > bh + HORIZON_SLACK:
        print(f"  improvement: horizon f{bp} vs baseline f{bh}")
    else:
        print(f"  holds: horizon f{bp} vs baseline f{bh} "
              f"(within {HORIZON_SLACK} frame of slack)")
    for f in fails:
        print("  FAIL: " + f)
    if fails:
        print("VERDICT: FAIL -- see evidence/a7 §8.6 for what a horizon "
              "difference means, and what does not count as evidence")
        return 1
    print("VERDICT: PASS")
    return 0


def mode_clock(d1, d2):
    """The guest's own clock, frame by frame, in both legs.

    The host frame index is the script's clock, so two legs that agree on it
    have seen the same input. The tick counter at $7E1C92 is the game's clock.
    A constant delta means one leg is running the game a few ticks ahead --
    same physics, different phase. A delta that steps means one leg executed a
    guest frame the other did not, which is a timing difference between the
    two paths and the point where a long route stops being comparable.
    """
    fs = sorted(set(frames(d1)) & set(frames(d2)))
    if not fs:
        print("no shared host frames -- nothing to compare")
        return
    seg = []  # [delta, first_frame, last_frame]
    bad = 0
    for f in fs:
        a, b = rd(d1, f), rd(d2, f)
        if a is None or b is None:
            bad += 1
            continue
        d = int.from_bytes(a[0x1C92:0x1C94], "little") \
            - int.from_bytes(b[0x1C92:0x1C94], "little")
        if seg and seg[-1][0] == d:
            seg[-1][2] = f
        else:
            seg.append([d, f, f])
    print(f"frames compared: {len(fs) - bad} (missing: {bad})")
    print("tick delta (run1 - run2) at the same host frame:")
    for d, f0, f1 in seg:
        print(f"  {d:+5d}  host f{f0}..f{f1}  ({f1 - f0 + 1} frames)")
    steps = [(seg[i][1], seg[i][0] - seg[i - 1][0]) for i in range(1, len(seg))]
    print("steps:", ", ".join(f"f{f}: {d:+d} ticks" for f, d in steps)
          if steps else "none -- both legs tick at the same rate throughout")


def mode_byte(d1, d2, addr, lo=None, hi=None):
    """One WRAM byte's value timeline, frame by frame, in both legs.

    usage: framedump_diff.py byte run1 run2 ADDR [FROM TO]

    A differing frame crc always raises the same question: is this a different
    *value*, or the same value landing on a different frame? This answers it
    for one address. The pair of value histograms is the whole point -- equal
    value sets with the counts shifted by a frame or two is phase, the writes
    moved in time; a value that appears in one leg only is a state change.

    ADDR is a WRAM offset (0x12E, $7E0012E and 0012E all name the same byte).
    FROM/TO restrict the timeline; the histograms always cover every frame the
    two runs share, so a narrow window cannot hide a value.
    """
    off = int(str(addr), 16) & 0x1FFFF
    fs = sorted(f for f in set(frames(d1)) & set(frames(d2))
                if (lo is None or f >= lo) and (hi is None or f <= hi))
    if not fs:
        print("no shared frames in that range")
        return
    va, vb = [], []
    for f in fs:
        a, b = rd(d1, f), rd(d2, f)
        if a is None or b is None or off >= min(len(a), len(b)):
            continue
        va.append(a[off])
        vb.append(b[off])
    n = len(va)
    diff = sum(1 for x, y in zip(va, vb) if x != y)
    print(f"{money(off)}  frames compared={n} identical={n - diff} differing={diff}")
    ha, hb = Counter(va), Counter(vb)
    print("  run1 values: " + "  ".join(f"{v:02X}x{ha[v]}" for v in sorted(ha)))
    print("  run2 values: " + "  ".join(f"{v:02X}x{hb[v]}" for v in sorted(hb)))
    only1, only2 = sorted(set(ha) - set(hb)), sorted(set(hb) - set(ha))
    if only1 or only2:
        print("  NOT the same values -- "
              + " ".join(f"run1 only {v:02X}" for v in only1) + " "
              + " ".join(f"run2 only {v:02X}" for v in only2))
    else:
        print("  same value set in both legs")
    shift = [(v, ha[v], hb[v]) for v in sorted(set(ha) | set(hb)) if ha[v] != hb[v]]
    if shift:
        print("  count moved: " + "  ".join(f"{v:02X} {a} -> {b}" for v, a, b in shift))
    print("  timeline (frame: run1/run2), runs where both legs hold steady:")
    i = 0
    while i < n:
        j = i
        while j + 1 < n and va[j + 1] == va[i] and vb[j + 1] == vb[i]:
            j += 1
        span = f"f{fs[i]}" if i == j else f"f{fs[i]}..f{fs[j]}"
        if va[i] == vb[i]:
            if j - i > 6:
                print(f"    {span:14s} {va[i]:02X}== identical")
            else:
                print(f"    {span:14s} {va[i]:02X}==")
        else:
            print(f"    {span:14s} {va[i]:02X}/{vb[i]:02X}  DIFFERS")
        i = j + 1


def mode_cpdump(d1, d2, tags=None):
    """The route's own checkpoints compared: guest clock, PPU state, images.

    usage: framedump_diff.py cpdump run1 run2 [TAG ...]

    A script's `dump <tag>` writes a checkpoint set: <tag>.info.json (frame,
    master_clock, vpos, hpos), <tag>.regs.json and the wram/vram/oam/cgram/
    sram/fb/apu/ppuw/dma images beside it. Route gates sit on WRAM state, so
    both legs reach a tag at the same guest frame -- and this prints what is
    left to compare there. Note what regs.json is: PPU / HDMA register state
    (runner/src/state_dump.h), not CPU registers, and info.json carries no CPU
    registers either. Nothing in a checkpoint set speaks to CPU registers, so
    this mode does not claim anything about them.

    Two legs agreeing on frame and WRAM at a tag while master_clock differs is
    the cleanest available reading of a cycle-count change: same guest frame,
    same guest bytes, different number of cycles spent to get there.
    """
    def tag_of(d):
        return {os.path.basename(p)[:-len(".info.json")]
                for p in glob.glob(os.path.join(d, "*.info.json"))}

    def fmt(v):
        if isinstance(v, list):
            return "[" + ",".join(str(x) for x in v) + "]"
        return str(v)

    def dma_delta(a, b):
        out = []
        for ca, cb in zip(a, b):
            fields = [k for k in set(ca) | set(cb) if ca.get(k) != cb.get(k)]
            if fields:
                out.append("ch%d " % ca.get("ch", -1) + " ".join(
                    "%s %s->%s" % (k, ca.get(k), cb.get(k)) for k in fields))
        return out

    common = sorted(tag_of(d1) & tag_of(d2) & set(tags or tag_of(d1) | tag_of(d2)))
    if not common:
        print("no tagged checkpoints in both runs")
        return
    print("checkpoints in both: " + " ".join(common))
    for tag in common:
        ia = json.loads(open(os.path.join(d1, tag + ".info.json")).read())
        ib = json.loads(open(os.path.join(d2, tag + ".info.json")).read())
        same_frame = ia.get("frame") == ib.get("frame")
        print(f"\n== {tag} ==  frame {ia.get('frame')}/"
              f"{ib.get('frame')}{'' if same_frame else '  DIFFERENT GUEST FRAME'}")
        print("   master_clock %13s -> %13s  delta %+d"
              % (ia.get("master_clock"), ib.get("master_clock"),
                 int(ib.get("master_clock", 0)) - int(ia.get("master_clock", 0))))
        print("   vpos %s/%s  hpos %s/%s"
              % (ia.get("vpos"), ib.get("vpos"), ia.get("hpos"), ib.get("hpos")))
        pa, pb = (os.path.join(d1, tag + ".regs.json"),
                  os.path.join(d2, tag + ".regs.json"))
        if os.path.isfile(pa) and os.path.isfile(pb):
            ra, rb = json.loads(open(pa).read()), json.loads(open(pb).read())
            diff = sorted(k for k in set(ra) | set(rb) if ra.get(k) != rb.get(k))
            print("   regs.json: %d keys compared, %d differ"
                  " (PPU/HDMA state; no CPU registers are dumped)"
                  % (len(set(ra) | set(rb)), len(diff)))
            for k in diff:
                if k == "dma" and isinstance(ra.get(k), list):
                    for line in dma_delta(ra[k], rb[k]):
                        print("      dma " + line)
                else:
                    print(f"      {k}: {fmt(ra.get(k))} -> {fmt(rb.get(k))}")
        rows = []
        for pre in ("wram.bin", "vram.bin", "oam.bin", "cgram.bin", "sram.bin",
                    "fb.bgrx", "apu.tsv", "ppuw.tsv", "dma.tsv"):
            fa, fb = (os.path.join(d1, f"{tag}.{pre}"),
                      os.path.join(d2, f"{tag}.{pre}"))
            if not (os.path.isfile(fa) and os.path.isfile(fb)):
                continue
            ha = hashlib.sha256(open(fa, "rb").read()).hexdigest()[:10]
            hb = hashlib.sha256(open(fb, "rb").read()).hexdigest()[:10]
            rows.append(f"{pre} {'=' if ha == hb else 'DIFFERS'}")
        print("   images: " + "  ".join(rows))


def mode_scene(d, refspec, step=20):
    """How scene-like each frame is, measured against one reference frame.

    `refspec` is `dir:frame` (the frame is looked up in that directory's
    frame_NNNNNN_wram.bin). A WRAM dump of a scene sitting still matches its
    own reference in almost every 1 KiB block; a scene that has walked away
    matches in fewer. A leg that converges on the title screen after a
    transition *climbs* toward a title reference while a leg that stays put
    does not, which is what the scene/game-mode check in a6 asks for.
    """
    rdir, sep, rs = refspec.rpartition(":")
    if not sep:
        rdir, rs = d, refspec
    ref = rd(rdir, int(rs))
    if not ref:
        raise SystemExit(f"no reference frame {rs} in {rdir}")
    fs = frames(d)
    blk, nb = 1024, (len(ref) + 1023) // 1024
    print(f"scene fingerprint: {d} vs {rdir} frame {int(rs)} "
          f"({nb} x {blk} B blocks, every {step} frames)")
    row, out, half = [], [], None
    for i, f in enumerate(fs):
        if i % step:
            continue
        b = rd(d, f)
        if not b:
            continue
        hit = sum(1 for i in range(0, nb * blk, blk)
                  if b[i:i + blk] == ref[i:i + blk])
        row.append(f"f{f} {hit}")
        out.append((f, hit))
        if half is None and hit >= nb * 0.9:
            half = f
        if len(row) == 6:
            print("  " + "  ".join(row))
            row = []
    if row:
        print("  " + "  ".join(row))
    if out:
        lo, hi = min(h for _, h in out), max(h for _, h in out)
        print(f"blocks matching: {lo} -> {hi} of {nb}; "
              + (f"first frame at 90%+: f{half}" if half else
                 "never reaches 90% -- this run does not converge on that scene"))


def main():
    args = sys.argv[1:]
    if len(args) >= 4 and args[0] == "byte":
        mode_byte(args[1], args[2], args[3],
                  int(args[4], 0) if len(args) > 4 else None,
                  int(args[5], 0) if len(args) > 5 else None)
        return
    if len(args) >= 5 and args[0] == "drift":
        mode_drift(args[1], args[2], lo=int(args[3], 0), hi=int(args[4], 0))
        return
    if len(args) >= 3 and args[0] == "state":
        rest = args[3:]
        mode_state(args[1], args[2],
                   int(rest[0], 0) if len(rest) > 0 else None,
                   int(rest[1], 0) if len(rest) > 1 else None)
        return
    if len(args) >= 3 and args[0] == "cpdump":
        mode_cpdump(args[1], args[2], args[3:] or None)
        return
    if args and args[0] == "horizon":
        rest = args[1:]
        if len(rest) < 2:
            raise SystemExit(__doc__)
        # --update re-records the baseline; --inputs-changed judges a pair whose
        # inputs differ from the baseline's *on purpose*, which is what a bisect
        # step is. Positionals left after the flags: two range bounds and at most
        # one baseline path. Flags are recognised by the leading "--", not by
        # lstrip("-"), or a flag name would read as a number's tail.
        flags = {a for a in rest[2:] if a.startswith("--")}
        unknown = flags - {"--update", "--inputs-changed"}
        if unknown:
            raise SystemExit("unknown horizon flag(s): "
                             + " ".join(sorted(unknown)))
        pos = [a for a in rest[2:] if a not in flags]
        nums = [a for a in pos if a.lstrip("-").isdigit()]
        base = next((a for a in pos if not a.lstrip("-").isdigit()), None)
        raise SystemExit(mode_horizon(
            rest[0], rest[1],
            int(nums[0], 0) if nums else None,
            int(nums[1], 0) if len(nums) > 1 else None,
            base, "--update" in flags, "--inputs-changed" in flags))
    if len(args) < 3 or args[0] not in (
            "offsets", "ksweep", "guest", "tick", "shift", "drift", "clock",
            "scene"):
        raise SystemExit(__doc__)
    mode = {"offsets": mode_offsets, "ksweep": mode_ksweep,
            "guest": mode_guest, "tick": mode_tick, "shift": mode_shift,
            "drift": mode_drift, "clock": mode_clock, "scene": mode_scene}[args[0]]
    if args[0] == "scene" and len(args) > 3:
        mode(args[1], args[2], int(args[3]))
    else:
        mode(*args[1:3])


if __name__ == "__main__":
    main()
