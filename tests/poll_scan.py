#!/usr/bin/env python3
"""Classify the coverage capture's hot interpreted PCs by loop shape.

usage: poll_scan.py <tier2_ingest.json> [min_cycles]

For every PC the capture says the interpreter spent >= min_cycles on, print
the next few ROM instructions and say whether the PC is the head of a
self-branching wait (the docs/IDLE_POLL.md shape: a compare/load whose
conditional branch jumps back to itself), and what the polled read touches:
WRAM (replayable) or an IO/device register (never replayed, guard 3).
"""
import collections
import json
import os
import subprocess
import sys

MIN = int(sys.argv[2]) if len(sys.argv) > 2 else 500_000
r = json.load(open(sys.argv[1]))
cost = collections.Counter()
for row in r["hot_instructions"]:
    pc = int(row["target_pc24"], 16) if isinstance(row["target_pc24"], str) else row["target_pc24"]
    cost[(pc, row["entry_mx"])] += row["guest_cycles"]

BR = {"BEQ", "BNE", "BCS", "BCC", "BMI", "BPL", "BVC", "BVS", "BRA", "BRL", "BBR", "BBS"}
LOAD = {"LDA", "LDX", "LDY", "CMP"}

print("pc        mx   cyc         shape")
for (pc, mx), cyc in sorted(cost.items(), key=lambda kv: -kv[1]):
    if cyc < MIN:
        continue
    out = subprocess.run(["python3", "tests/disasm_span.py", "%X" % pc, "3",
                          "1" if mx.startswith("M1") else "0",
                          "1" if mx.endswith("X1") else "0"],
                         capture_output=True, text=True).stdout.strip().splitlines()
    rows = [l.split(None, 2) for l in out]
    txt = [r[2] if len(r) > 2 else "?" for r in rows]
    shape = "not a self-loop"
    detail = ""
    for i, t in enumerate(txt):
        words = t.split()
        if len(words) >= 2 and words[0] in BR:
            try:
                tgt = int(words[1].lstrip("$"), 16)
            except ValueError:
                continue
            if tgt == pc % 0x10000:
                head = " ".join(txt[:i])
                shape = "WAIT loop (%d insn): %s -> %s" % (i + 1, head, t)
                detail = rows[i][1]
                break
    print("$%06X %-4s %11d  %s" % (pc, mx, cyc, shape or txt[0]))
    if shape == "not a self-loop":
        print("            %-11s %s" % ("", " | ".join(txt)))
