#!/usr/bin/env python3
"""Where does the compiled path hand the CPU back to the interpreter?

    handoff_probe.py                       # both legs, f16115-f16135
    handoff_probe.py --start 16120 --until 16126 --step 1
    handoff_probe.py --legs aot
    handoff_probe.py --report              # render saved JSON only

Why: cyc_probe.py (evidence/a7 §8) shows the two legs park at the SAME guest
PC through f16121 and at DIFFERENT PCs from f16123 ($809f29 vs $809dea) while
`master_cycles` at the parked boundary stay identical. The frame boundary is a
fixed 357,368-master-clock budget (BFD_MASTER_CYCLES_PER_FIELD), and every
generated AOT block polls `interp_bridge_lle_master_deadline_reached()` between
instructions and unwinds to the interpreter where it fires. So the hand-off
point -- not any computed value -- is what can move the frame boundary across
a loop iteration. This tool reads the framework's own LLE resume/yield-unwind
ring (`resume_ring`, runner/src/debug_server.c) at each park and compares the
events per frame across the two paths: kind (deadline / irq / wai / rollback),
site, old->new resume PC, and the two depth guards that suppress the deadline.

It answers, for the onset window: does the AOT leg take deadline unwinds inside
the $809D-$809F burst that the floor leg does not (or at a different address)?
"""
import argparse
import collections
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cyc_probe import (OUT, ROOT, LEGS, Dbg, launch, park, seed_sram,
                       share)  # noqa: E402

BURST = (0x809D00, 0x809FFF)


def in_burst(pc):
    return isinstance(pc, str) and BURST[0] <= int(pc, 16) <= BURST[1]


def collect(leg, binary, start, until, step, port, ring=512):
    binary = os.path.abspath(binary)
    anchor = os.path.dirname(binary)
    dump = os.path.join(OUT, f"ho_{leg}")
    shutil.rmtree(dump, ignore_errors=True)
    seed_sram(anchor)
    print(f"== {leg}: {binary}  f{start}-f{until} step {step}")
    proc = launch(binary, dump, os.path.join(OUT, f"ho_{leg}.log"), port)
    d = Dbg(port).connect()
    samples = []
    at = park(d, start)
    while True:
        cpu = d.q("get_v2_cpu")
        ring_ev = d.q(f"resume_ring n={ring}")
        s = {"parked_at": at}
        if isinstance(cpu, dict):
            for k in ("cpu_cycles", "master_cycles", "resume_pc"):
                s[k] = cpu.get(k)
        if isinstance(ring_ev, dict) and "writes" in ring_ev:
            s["total"] = ring_ev["total"]
            s["events"] = ring_ev["writes"]
        else:
            s["ring_err"] = ring_ev
        samples.append(s)
        ev = s.get("events", [])
        kinds = collections.Counter(e["kind"] for e in ev)
        print(f"   f{at}: cycles={s.get('cpu_cycles')} "
              f"resume_pc={s.get('resume_pc')} ring={len(ev)} "
              + " ".join(f"{k}={v}" for k, v in kinds.most_common(4)))
        if at >= until:
            break
        at = park(d, at + step)
    d.q("continue")
    try:
        rc = proc.wait(timeout=900)
    except subprocess.TimeoutExpired:
        proc.terminate()
        rc = proc.wait(timeout=60)
    print(f"   exit {rc}")
    share(binary, leg)
    out = {"leg": leg, "start": start, "until": until, "step": step,
           "samples": samples}
    path = os.path.join(OUT, f"ho_{leg}.json")
    json.dump(out, open(path, "w"), indent=1)
    print(f"   wrote {path}")
    return out


def report(data):
    legs = [k for k in ("lle", "aot") if k in data]
    if len(legs) < 2:
        print("(one leg only -- nothing to compare)")
        return
    print("\n=== per-frame hand-off events, split by frame stamp "
          "(ring is old->new, so late frames dominate the newest dump) ===")
    for f in sorted({s["parked_at"] for k in legs for s in data[k]["samples"]}):
        line = [f"f{f}"]
        for leg in legs:
            for s in data[leg]["samples"]:
                if s["parked_at"] != f:
                    continue
                per = collections.Counter()
                burst = collections.Counter()
                for e in s.get("events", []):
                    per[(e["kind"], e["site"])] += 1
                    if in_burst(e["new"]) or in_burst(e["old"]):
                        burst[e["kind"]] += 1
                top = " ".join(f"{k[0]}/{k[1]}={v}"
                               for k, v in per.most_common(3))
                line.append(f"{leg}: {sum(per.values())} ev "
                            f"[burst-range {sum(burst.values())}] {top}")
        print("  " + " | ".join(line))

    print("\n=== resume-PC sequence inside the burst, per park ===")
    for leg in legs:
        seq = []
        for s in data[leg]["samples"]:
            for e in s.get("events", []):
                if in_burst(e["new"]):
                    seq.append((e["frame"], e["kind"], e["new"]))
        seen = []
        for f, k, new in seq:
            t = (f, k, new)
            if t not in seen:
                seen.append(t)
        print(f"  {leg}: " + " ".join(f"f{f}:{k}:{p}" for f, k, p in seen[-16:]))

    print("\n=== deadline suppressions (depth guards) ===")
    for leg in legs:
        cnt = collections.Counter()
        for s in data[leg]["samples"]:
            for e in s.get("events", []):
                if e.get("sched_depth", 0) == 0 or e.get("bridge_depth", 0) == 0:
                    cnt[(e["kind"], e["site"])] += 1
        print(f"  {leg}: " + (", ".join(f"{k[0]}/{k[1]}={v}" for k, v in
                                        cnt.most_common(5)) or "none"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--start", type=int, default=16115)
    ap.add_argument("--until", type=int, default=16135)
    ap.add_argument("--step", type=int, default=4)
    ap.add_argument("--ring", type=int, default=512)
    ap.add_argument("--legs", default="lle,aot")
    ap.add_argument("--port-base", type=int, default=4510)
    ap.add_argument("--report", action="store_true")
    ns = ap.parse_args()
    legs = [x.strip() for x in ns.legs.split(",") if x.strip()]
    if ns.report:
        data = {l: json.load(open(os.path.join(OUT, f"ho_{l}.json")))
                for l in legs if os.path.exists(os.path.join(OUT, f"ho_{l}.json"))}
        report(data)
        return
    data = {}
    for i, leg in enumerate(legs):
        if leg not in LEGS:
            raise SystemExit(f"unknown leg {leg!r}")
        data[leg] = collect(leg, LEGS[leg], ns.start, ns.until, ns.step,
                            ns.port_base + i * 10, ns.ring)
    if len(data) == 2:
        report(data)


if __name__ == "__main__":
    main()
