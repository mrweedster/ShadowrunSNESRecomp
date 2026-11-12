#!/usr/bin/env python3
"""Rank coverage-capture gap sightings by the interpreted cycles they gate.

usage: coverage_gaps.py <tier2_ingest.json> [--top N]

The ingest report joins two journals: per-instruction interpreted costs
(exclusive guest cycles per exact PC + M/X + E) and transfer sightings
(call_gap / goto_gap: a transfer the bridge made into a target with no
compiled body). A target that appears in both is seed-addressable: a body
seeded at that entry will run the next time the transfer happens. A hot PC
with no sighting is entered by fall-through, back-edge, or resume — no seed
at any address can intercept it. This tool ranks the seedable part and, by
the complement, measures the size of the entry-shape residue.
"""
import collections
import json
import sys


def I(x):
    return int(x, 16) if isinstance(x, str) else x


def main():
    argv = sys.argv[1:]
    top = 40
    if "--top" in argv:
        i = argv.index("--top")
        top = int(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    r = json.load(open(argv[0]))

    cost = collections.Counter()
    for row in r["hot_instructions"]:
        cost[(I(row["target_pc24"]), row["entry_mx"], row.get("emulation"))] += row["guest_cycles"]
    total = sum(cost.values())

    gaps = {}
    for d in r["discoveries"]:
        if d["site_kind"] not in ("call_gap", "goto_gap"):
            continue
        key = (I(d["target_pc24"]), d["entry_mx"])
        g = gaps.setdefault(key, {"kind": d["site_kind"], "hits": 0,
                                  "status": d.get("candidate_status"),
                                  "sites": set()})
        g["hits"] += d["observed_hits"]
        g["sites"].add(I(d["site_pc24"]))

    rows = []
    for (pc, mx), g in gaps.items():
        cyc = sum(c for k, c in cost.items() if k[0] == pc and k[1] == mx)
        if cyc:
            rows.append((cyc, pc, mx, g))
    rows.sort(key=lambda x: -x[0])

    seedable = sum(c for c, *_ in rows)
    sighted = {pc for _, pc, _, _ in rows}
    unseen = sum(c for k, c in cost.items() if k[0] not in sighted)
    print("attributed interpreted guest cycles: %s" % f"{total:,}")
    print("seedable (hot AND sighted):  %s = %.2f%% over %d (pc,mx) entries"
          % (f"{seedable:,}", 100.0 * seedable / total, len(rows)))
    print("never sighted at a site:     %s = %.2f%%  <- entry-shape residue"
          % (f"{unseen:,}", 100.0 * unseen / total))
    print()
    print("rank pc       mx   site kind hits      cyc        gate status")
    for n, (cyc, pc, mx, g) in enumerate(rows[:top], 1):
        print("%3d  $%06X  %-4s %-4s  hits=%-8d %11s  %s  sites=%s"
              % (n, pc, mx, "call" if g["kind"] == "call_gap" else "goto",
                 g["hits"], f"{cyc:,}", g["status"],
                 ",".join("$%06X" % s for s in sorted(g["sites"])[:3])))


main()
