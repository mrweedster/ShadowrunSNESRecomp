#!/usr/bin/env python3
"""Compare two tagged APU traces and say *how* they differ, not just that they do.

    apu_shift.py <run-dir-a> <run-dir-b> [TAG ...]

`tests/framedump_diff.py cpdump` reports "apu.tsv differs".  That line is the
only difference a state-clean seeded tree leaves behind, so the record has to
say what kind of difference it is: the same APU bus events with different
per-frame timing, or different events.

The trace header is

    # frame  scanline  hclock  event  port  value  sample

Two rules decide the claim:

  events-equal   the multiset of (frame, event, port, value, sample) rows is the
                 same in both runs, so the APU observed the same writes with the
                 same data and the SPC produced the same number of samples; only
                 the (scanline, hclock) stamp on some rows moved.  In that case
                 the script prints the shift distribution, in hclocks, where a
                 frame is 512 hclocks (scanline 0..261 NTSC).

  events-differ  one side has rows the other does not: a real difference in what
                 the APU did, which no amount of timing explains.

Tag arguments default to every TAG.* pair found in both directories.
Exit 0 always; this generates text for the round record, it does not gate.
"""
import os
import sys
from collections import Counter

LINE_FIELDS = ("frame", "scanline", "hclock", "event", "port", "value", "sample")
HCLK_PER_LINE = 512


def rows(path):
    out = []
    with open(path) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 7:
                continue
            fr, sl, hc, ev, port, val, smp = parts
            out.append((int(fr), int(sl), int(hc), ev, port, val, int(smp)))
    return out


def key(row):
    fr, _sl, _hc, ev, port, val, smp = row
    return (fr, ev, port, val, smp)


def pos(row):
    fr, sl, hc, _ev, _port, _val, _smp = row
    return fr * 262 * HCLK_PER_LINE + sl * HCLK_PER_LINE + hc


def compare(dirs, tag):
    pa, pb = (os.path.join(d, tag + ".apu.tsv") for d in dirs)
    if not (os.path.exists(pa) and os.path.exists(pb)):
        return None
    a, b = rows(pa), rows(pb)
    ka, kb = Counter(key(r) for r in a), Counter(key(r) for r in b)
    same_events = ka == kb
    res = {"rows": (len(a), len(b)), "same_events": same_events,
           "line_diffs": sum(1 for x, y in zip(a, b) if x != y)}
    if same_events:
        # Zip by occurrence order within each event key: the events are the
        # same, so nth-writer to nth-writer is the pairing.
        shifts = []
        buckets = {}
        for r in a:
            buckets.setdefault(key(r), []).append(r)
        for r in b:
            src = buckets.get(key(r))
            if not src:
                continue
            ra = src.pop(0)
            shifts.append(pos(r) - pos(ra))
        shifts.sort()
        res["shift"] = {
            "n": len(shifts),
            "zero": sum(1 for s in shifts if s == 0),
            "moved": sum(1 for s in shifts if s != 0),
            "min": shifts[0] if shifts else 0,
            "max": shifts[-1] if shifts else 0,
            "median": shifts[len(shifts) // 2] if shifts else 0,
            "max_frames": (max(abs(s) for s in shifts) // (262 * HCLK_PER_LINE))
                          if shifts else 0,
        }
        # The columns that must not move if this is only scheduling.
        res["sample_col_equal"] = [r[6] for r in a] == [r[6] for r in b]
    else:
        res["only_a"] = sum((ka - kb).values())
        res["only_b"] = sum((kb - ka).values())
    return res


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip())
        return 2
    dirs = sys.argv[1:3]
    tags = sys.argv[3:]
    if not tags:
        tags = sorted({os.path.basename(p).split(".")[0]
                       for p in _walk(dirs[0]) if p.endswith(".apu.tsv")}
                      & {os.path.basename(p).split(".")[0]
                         for p in _walk(dirs[1]) if p.endswith(".apu.tsv")})
    print("# APU-trace comparison: %s vs %s" % (dirs[0], dirs[1]))
    print()
    print("Header is `frame scanline hclock event port value sample`; one frame")
    print("is 262 scanlines x 512 hclocks of stamping space.")
    print()
    print("| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | shift hclocks (min / median / max) | worst shift, frames | `sample` column identical |")
    print("|" + "---|" * 8)
    for tag in tags:
        r = compare(dirs, tag)
        if r is None:
            print("| %s | missing | | | | | |" % tag)
            continue
        if r["same_events"]:
            s = r["shift"]
            print("| %s | %d / %d | %d | yes | %d of %d | %d / %d / %d | %s | %s |"
                  % (tag, r["rows"][0], r["rows"][1], r["line_diffs"],
                     s["moved"], s["n"], s["min"], s["median"], s["max"],
                     s["max_frames"], "yes" if r["sample_col_equal"] else "NO"))
        else:
            print("| %s | %d / %d | %d | **no: %d rows only in a, %d only in b** | | | | |"
                  % (tag, r["rows"][0], r["rows"][1], r["line_diffs"],
                     r["only_a"], r["only_b"]))
    return 0


def _walk(d):
    for name in os.listdir(d):
        yield os.path.join(d, name)


if __name__ == "__main__":
    sys.exit(main())
