#!/usr/bin/env python3
"""Compare two legs' guest state at frame boundaries around a WRAM write split.

    SNESRECOMP_ROOT=<pin> \
    WT_LEGS=ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/ShadowrunSNESRecomp \
        python3 tests/latch_state.py --frames 14662,14671,14701,16181,16201

Why this exists next to tests/latch_writer.py: that tool names *what* value a
byte took and which block wrote it, but it does not say whether the machine
around that byte agrees.  A 16-bit store split into two 8-bit stores at an
AOT/interpreter seam can show one transient write while the registers, the live
stack and the latch bytes are identical at every frame boundary.  This tool
measures that, so "transient" is a finding rather than an excuse.

What is compared at each requested frame:

  * S and D from `get_v2_cpu`, and cpu/master cycle counters;
  * the direct page ($00-$FF at D=0);
  * the stack page ($100-$1FF), split at max(S): bytes at or above S are live,
    bytes below S are dead scratch and are reported separately;
  * the two latch bytes $0126-$0127.

Writes tests/out/latch_state.json and prints one row per frame plus the
first differing live byte, if any.
"""
import argparse
import json
import os
import sys

import wram_trace as wt


def read(d, addr, n):
    r = d.q(f"read_ram {addr:x} {n}")
    if not isinstance(r, dict):
        raise SystemExit(f"read_ram {addr:x} {n}: {r}")
    return bytes.fromhex(r.get("hex", ""))


def run_leg(leg, binary, route, frames, port):
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
    d = wt.Dbg(port).connect()
    out = {"leg": leg, "exe": binary, "frames": []}
    for f in frames:
        wt.park(d, f)
        got = d.frame()
        c = d.q("get_v2_cpu")
        out["frames"].append({
            "frame": got,
            "S": int(c["S"], 16),
            "D": int(c["D"], 16),
            "cpu_cycles": c.get("cpu_cycles"),
            "master_cycles": c.get("master_cycles"),
            "resume_pc": c.get("resume_pc"),
            "dp": read(d, 0x0000, 0x100).hex(),
            "stack": read(d, 0x0100, 0x100).hex(),
            "latch": read(d, 0x0126, 2).hex().upper(),
        })
        e = out["frames"][-1]
        print(f'{leg} f{got:<6} S={c["S"]} D={c["D"]} '
              f'cyc={e["cpu_cycles"]} mcyc={e["master_cycles"]} '
              f'pc={e["resume_pc"]} latch126_127={e["latch"]}')
    d.q("continue")
    try:
        proc.wait(timeout=900)
    except Exception:
        proc.terminate()
        proc.wait(timeout=60)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--legs", default="ctrl,seed")
    ap.add_argument("--route", default="tests/scripts/bisect_h8.txt")
    ap.add_argument("--frames", default="14662,14671,14701,16181,16201")
    ap.add_argument("--port-base", type=int, default=4620)
    ns = ap.parse_args()
    frames = [int(x) for x in ns.frames.split(",") if x.strip()]
    legs = [x.strip() for x in ns.legs.split(",") if x.strip()]
    for leg in legs:
        if leg not in wt.LEGS:
            raise SystemExit(f"unknown leg {leg!r}; set WT_LEGS=name=path,...")

    res = {}
    for i, leg in enumerate(legs):
        res[leg] = run_leg(leg, wt.LEGS[leg], ns.route, frames,
                           ns.port_base + i * 10)
    json.dump(res, open(os.path.join(wt.OUT, "latch_state.json"), "w"), indent=1)

    a, b = legs[0], legs[1]
    print()
    worst = 0
    for ea, eb in zip(res[a]["frames"], res[b]["frames"]):
        sa, sb = bytes.fromhex(ea["stack"]), bytes.fromhex(eb["stack"])
        hi = max(ea["S"], eb["S"])
        live = [(0x100 + k, sa[k], sb[k]) for k in range(0x100)
                if 0x100 + k >= hi and sa[k] != sb[k]]
        dead = [(0x100 + k, sa[k], sb[k]) for k in range(0x100)
                if 0x100 + k < hi and sa[k] != sb[k]]
        worst = max(worst, len(live))
        print(f'f{ea["frame"]}/{eb["frame"]}: '
              f'DP identical={ea["dp"] == eb["dp"]} '
              f'latch identical={ea["latch"] == eb["latch"]} '
              f'live-stack diffs={len(live)} below-S diffs={len(dead)} '
              f'S {a}={ea["S"]:04X} {b}={eb["S"]:04X} '
              f'mcyc d={eb["master_cycles"] - ea["master_cycles"]:+d} '
              f'cyc d={eb["cpu_cycles"] - ea["cpu_cycles"]:+d}')
        if live[:4]:
            print("   live:", [(f"${x:04X}", f"{p:02X}", f"{q:02X}")
                               for x, p, q in live[:4]])
        if dead[:4]:
            print("   below-S:", [(f"${x:04X}", f"{p:02X}", f"{q:02X}")
                                  for x, p, q in dead[:4]])
    return 1 if worst else 0


if __name__ == "__main__":
    sys.exit(main())
