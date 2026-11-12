#!/usr/bin/env python3
"""Group interpreted cost by interrupt-wait loop, from a coverage capture.

usage: wait_class.py <tier2_ingest.json> [min_head_cycles]

docs/IDLE_POLL.md names one lever for interpreted cost that no seed address can
reach: declare the PC of an interrupt-wait poll and the bridge replays the
wait's cycle to the deadline. Which waits qualify, and what they cost, is a
measurement, not a guess. This walks the capture's hot PCs through the pinned
framework's decoder and groups each self-branching wait (a compare/load whose
conditional branch jumps back to the loop's own head) with its branch PC, which
the capture bills separately.

The `polled` column is the operand of the head's memory read. A WRAM operand
($7E-bank via a 24-bit operand, or direct-page/abs below $2000) is the shape
the guard set can accept; a `$21xx`-style operand is an IO register, and
guard 3 (no volatile read) refuses those regardless of what is declared. So
the table is a candidate list with the disqualifying column printed, not an
instruction to declare everything in it.

Set SNESRECOMP_ROOT to the pinned framework checkout; the decoder comes from
there so the mnemonics match what the analyzer saw.
"""
import collections
import json
import os
import re
import subprocess
import sys

PIN = os.environ.get("SNESRECOMP_ROOT")
if not PIN:
    sys.exit("SNESRECOMP_ROOT must point at the pinned framework checkout")
ROM = os.environ.get("ROM", "Shadowrun (USA).sfc")

MIN = int(sys.argv[2]) if len(sys.argv) > 2 else 100_000
r = json.load(open(sys.argv[1]))


def I(x):
    return int(x, 16) if isinstance(x, str) else x


cost = collections.Counter()
for row in r["hot_instructions"]:
    cost[(I(row["target_pc24"]), row["entry_mx"])] += row["guest_cycles"]
total = sum(cost.values())

BR = {"BEQ", "BNE", "BCS", "BCC", "BMI", "BPL", "BVC", "BVS", "BRA", "BRL", "BBR", "BBS"}
LOAD = {"LDA", "LDX", "LDY", "CMP", "BIT", "CPX", "CPY", "TST"}

heads = []
for (pc, mx), cyc in cost.items():
    if cyc < MIN:
        continue
    out = subprocess.run(
        ["python3", "tests/disasm_span.py", "%X" % pc, "4",
         "1" if mx.startswith("M1") else "0", "1" if mx.endswith("X1") else "0", ROM],
        capture_output=True, text=True)
    lines = [l.split(None, 2) for l in out.stdout.strip().splitlines()]
    for i, parts in enumerate(lines):
        if len(parts) < 3:
            continue
        w = parts[2].split()
        if len(w) < 2 or w[0] not in BR:
            continue
        try:
            tgt = int(w[1].lstrip("$"), 16)
        except ValueError:
            continue
        if tgt != pc % 0x10000:
            continue
        # The cycle is the head..branch span; bill every PC in it, and record
        # the operand the head's poll read touches.
        span = [int(l[0].lstrip("$"), 16) for l in lines[: i + 1]]
        body = sum(cost[(p, mx)] for p in span if (p, mx) in cost)
        poll = ""
        for parts2 in lines[: i + 1]:
            w2 = parts2[2].split()
            if len(w2) >= 2 and w2[0] in LOAD and not re.match(r"#\$", w2[1]):
                poll = w2[1]
                break
        heads.append((body, pc, mx, cyc, parts[2], poll, len(span)))
        break

heads.sort(key=lambda t: -t[0])
print("attributed interpreted guest cycles: %s" % f"{total:,}")
print("%-9s %-5s %13s %6s  %-26s %s" % ("poll PC", "mx", "loop cyc", "%tot", "loop", "polled"))
sum_loops = 0
for body, pc, mx, hcyc, branch, poll, n in heads:
    sum_loops += body
    print("$%06X %-5s %13s %5.2f%%  %-26s %s"
          % (pc, mx, f"{body:,}", 100 * body / total, branch, poll or "-"))
print("declared-poll candidates over %d loops: %s = %.2f%% of attributed"
      % (len(heads), f"{sum_loops:,}", 100 * sum_loops / total))
