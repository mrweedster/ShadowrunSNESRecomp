#!/usr/bin/env python3
"""Name the instruction and function that writes one WRAM byte, on two legs.

    SNESRECOMP_ROOT=<pin> \
    WT_LEGS=ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/ShadowrunSNESRecomp \
        python3 tests/latch_writer.py --addrs 0x126,0x127 --park 16200

Why this exists next to tests/wram_trace.py: that tool answers "do the two
paths write the same value stream" for a set of addresses, but `wram_writes_at`
returns a trimmed record (frame, old, value, func, parent) with no PC. The full
ring (`get_wram_trace`) carries the writing block's PC, so a byte that diverges
can be attributed to an address instead of to "(none)".

The comparison is per byte, not per transfer: AOT code emits 16-bit stores where
the interpreter emits two 8-bit ones, so a raw entry stream disagrees on width
before it disagrees on value.  Every transfer is split into (address, byte) and
keyed by the ring's bus index; the two legs are then compared as value
sequences per address.

Two passes, because one ring dump cannot hold a 16,000-frame history:

  1. arm the ring at boot, park past the checkpoint, and page the write record
     with `wram_writes_at` in frame chunks.  This gives the first write where
     the two legs' byte value sequences differ -- the onset, with frames.
  2. relaunch both legs, arm only around that onset, and dump the full ring
     (`get_wram_trace`) which carries `pc` and `func` for every write.

Build both legs with -DSNESRECOMP_ENABLE_TRACE=ON.  The route is cut short
(`dump H8` + a little) because the latch question is about the combat route's
first split.  The pc pass arms `--pc-window` frames before the split by
default; if the ring fills before reaching the split (it does for a busy DP
address), pass `--pc-arm FRAME` to arm closer.

Writes tests/out/latch_<leg>.json and prints both the split and its writers.
"""
import argparse
import collections
import json
import os
import sys

import wram_trace as wt


def arm(d, lo, hi):
    r = d.q("trace_wram_reset")
    if not (isinstance(r, dict) and r.get("ok")):
        raise SystemExit(f"trace_wram_reset: {r}")
    r = d.q(f"trace_wram {lo:x} {hi:x}")
    if not (isinstance(r, dict) and r.get("ok")):
        raise SystemExit(f"trace_wram: {r}")


def launch(leg, binary, route, port):
    binary = os.path.abspath(binary)
    dump = os.path.join(wt.OUT, f"latch_{leg}")
    os.makedirs(dump, exist_ok=True)
    wt.seed_sram(os.path.dirname(binary))
    old_route = wt.ROUTE
    wt.ROUTE = os.path.abspath(route)
    try:
        proc = wt.launch(leg, binary, dump,
                         os.path.join(wt.OUT, f"latch_{leg}.log"), port)
    finally:
        wt.ROUTE = old_route
    return proc, wt.Dbg(port).connect()


def finish(proc, d):
    d.q("continue")
    try:
        return proc.wait(timeout=900)
    except Exception:
        proc.terminate()
        return proc.wait(timeout=60)


def page_writes(d, addrs, park, chunk=2000, limit=4096):
    rows = {}
    for addr in addrs:
        lo = 0
        while lo <= park:
            hi = min(park, lo + chunk - 1)
            r = d.q(f"wram_writes_at {addr:x} {lo} {hi} {limit}")
            if not (isinstance(r, dict) and r.get("ok")):
                raise SystemExit(f"wram_writes_at {addr:x} {lo}-{hi}: {r}")
            for e in r.get("matches", []):
                rows[int(e["bi"])] = e
            lo = hi + 1
    return [rows[k] for k in sorted(rows)]


def expand(rows):
    """{byte address: [(bi, value, frame, pc, func, parent)]}, widths flattened."""
    ev = collections.defaultdict(list)
    for e in rows:
        base, w = int(e["adr"], 16), int(e["w"])
        val = int(e["val"], 16)
        for k in range(w):
            ev[base + k].append((int(e["bi"]), (val >> (8 * k)) & 0xFF,
                                 e["f"], e.get("pc", "?"),
                                 e.get("func", "-"), e.get("parent", "-")))
    for a in ev:
        ev[a].sort()
    return ev


def collect(leg, binary, route, addrs, park, port, lo_hi):
    proc, d = launch(leg, binary, route, port)
    if lo_hi is None:
        arm(d, min(addrs), max(addrs))
        at = wt.park(d, park)
        r = d.q("get_wram_trace")
        if not (isinstance(r, dict) and "log" in r):
            raise SystemExit(f"get_wram_trace: {r}")
        rows = [e for e in r["log"]
                if min(addrs) <= int(e["adr"], 16) <= max(addrs)]
        kind = "full ring"
    else:
        arm(d, lo_hi[0], lo_hi[1])
        at = wt.park(d, park)
        rows = page_writes(d, addrs, at)
        kind = "paged record"
    finish(proc, d)
    ev = expand(rows)
    print(f"== {leg}: parked f{at}, {len(rows)} transfers, "
          f"{sum(len(v) for v in ev.values())} byte writes ({kind})")
    out = {"leg": leg, "parked_at": at, "addrs": [f"{a:04X}" for a in addrs],
           "full_ring": lo_hi is None, "writes": rows}
    path = os.path.join(wt.OUT, f"latch_{leg}.json")
    json.dump(out, open(path, "w"), indent=1)
    print(f"   wrote {path}")
    return out


def first_split(a, b):
    ea, eb = expand(a["writes"]), expand(b["writes"])
    out = {}
    for addr in sorted(set(ea) | set(eb)):
        sa, sb = ea.get(addr, []), eb.get(addr, [])
        n = min(len(sa), len(sb))
        i = next((j for j in range(n) if sa[j][1] != sb[j][1]), None)
        if i is None and len(sa) != len(sb):
            i = n
        if i is not None:
            out[addr] = (i, sa, sb)
    return out


def compare(a, b, with_pc):
    splits = first_split(a, b)
    if not splits:
        print(f"\n{a['addrs']}: identical byte value sequences")
        return 0
    for addr, (i, sa, sb) in splits.items():
        print(f"\n${addr:04X}: first byte value split at write #{i} "
              f"(ctrl {len(sa)} bytes, seed {len(sb)})")
        for leg, s in (("ctrl", sa), ("seed", sb)):
            lo = max(0, i - 2)
            print(f"  {leg}:")
            for j in range(lo, min(len(s), i + 3)):
                bi, val, f, pc, func, parent = s[j]
                mark = "  <" if j == i else ""
                if not with_pc:
                    print(f"    #{j:<6} f{f:<6} ={val:02X}  func={func:<22} "
                          f"parent={parent}{mark}")
                else:
                    print(f"    #{j:<6} f{f:<6} ={val:02X}  pc={pc:<10} "
                          f"func={func:<22} bi={bi}{mark}")
    return 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--legs", default="ctrl,seed")
    ap.add_argument("--addrs", default="0x126,0x127")
    ap.add_argument("--route", default="tests/scripts/bisect_h8.txt")
    ap.add_argument("--park", type=int, default=16200)
    ap.add_argument("--port-base", type=int, default=4490)
    ap.add_argument("--pc-window", type=int, default=400,
                    help="frames before the split to arm the pc pass")
    ap.add_argument("--pc-arm", type=int, default=None,
                    help="frame to arm the pc pass (default: split - pc-window); "
                         "use when the ring fills before the split")
    ap.add_argument("--no-pc", action="store_true",
                    help="only the onset pass (no relaunch, no pc)")
    ns = ap.parse_args()
    addrs = [int(a, 16) for a in ns.addrs.split(",") if a.strip()]
    legs = [l.strip() for l in ns.legs.split(",") if l.strip()]
    for leg in legs:
        if leg not in wt.LEGS:
            raise SystemExit(f"unknown leg {leg!r}; set WT_LEGS=name=path,...")

    onset = {}
    for i, leg in enumerate(legs):
        onset[leg] = collect(leg, wt.LEGS[leg], ns.route, addrs, ns.park,
                             ns.port_base + i * 10, lo_hi=(min(addrs), max(addrs)))
    rc = compare(onset[legs[0]], onset[legs[1]], with_pc=False)
    if ns.no_pc or len(legs) != 2 or rc == 0:
        return rc

    splits = first_split(onset[legs[0]], onset[legs[1]])
    first_addr = sorted(splits)[0]
    i, sa, sb = splits[first_addr]
    frames = [s[i][2] for s in (sa, sb) if i < len(s)]
    park = max(frames) + 50
    lo = ns.pc_arm if ns.pc_arm is not None else max(0, park - ns.pc_window)
    print(f"\n== pc pass: arm at f{lo} and park at f{park} for ${first_addr:04X}")
    data = {}
    for k, leg in enumerate(legs):
        proc, d = launch(leg, wt.LEGS[leg], ns.route, ns.port_base + 100 + k * 10)
        wt.park(d, lo)
        arm(d, min(addrs), max(addrs))
        at = wt.park(d, park)
        r = d.q("get_wram_trace")
        if not (isinstance(r, dict) and "log" in r):
            raise SystemExit(f"get_wram_trace: {r}")
        rows = [e for e in r["log"]
                if min(addrs) <= int(e["adr"], 16) <= max(addrs)]
        finish(proc, d)
        data[leg] = {"leg": leg, "parked_at": at,
                     "addrs": [f"{a:04X}" for a in addrs],
                     "full_ring": True, "writes": rows}
        json.dump(data[leg], open(os.path.join(wt.OUT, f"latch_{leg}.json"), "w"),
                  indent=1)
        print(f"== {leg}: armed f{lo}+, {len(rows)} transfers in the ring")
    return compare(data[legs[0]], data[legs[1]], with_pc=True)


if __name__ == "__main__":
    sys.exit(main())
