#!/usr/bin/env python3
"""Read a declared idle poll's cost straight off a capture, per leg.

usage: wait_cost.py <leg>=<tier2_ingest.json> [...]

`tests/wait_class.py` groups the whole residue by loop shape and bills a wait's
branch with its head; this answers the narrower question the idle-poll A/B
turns on -- how much does the *specific set of declared PCs* cost, before and
after the declaration. It reads the capture's own hot table, no decoder, so it
runs anywhere:

    tests/wait_cost.py off=tests/out/idle_off_ingest.json \
                       on=tests/out/idle_on_ingest.json

The four PCs below are the two frame-counter compare heads the round-3 record
declares ($81B061 M0X0, $81EE8E M1X0) plus the back-edges they own ($81B065,
$81EE92), which the capture bills as separate rows. Pass `polls=` to check a
different declaration; a declared poll that replays never re-enters the
interpreter, so what is left of its cost is the part the guard set refused --
or the part this route never reached.
"""
import json
import sys

POLLS = {0x81B061, 0x81B065, 0x81EE8E, 0x81EE92}
args = sys.argv[1:]
if args and args[0].startswith("polls="):
    POLLS = {int(p, 16) for p in args.pop(0)[len("polls="):].split(",") if p}
if not args:
    sys.exit(__doc__)


def pc(v):
    return int(v, 16) if isinstance(v, str) else v


print("declared: " + " ".join("$%06X" % p for p in sorted(POLLS)))
print("%-10s %18s %18s %9s" % ("leg", "attributed cyc", "declared waits", "wait %"))
for arg in args:
    leg, _, path = arg.partition("=")
    try:
        r = json.load(open(path))
    except FileNotFoundError:
        print("%-10s  no ingest: %s" % (leg, path))
        continue
    rows = r["hot_instructions"]
    tot = sum(row["guest_cycles"] for row in rows)
    per = {}
    for row in rows:
        p = pc(row["target_pc24"])
        if p in POLLS:
            per[p] = per.get(p, 0) + row["guest_cycles"]
    w = sum(per.values())
    print("%-10s %18s %18s %8.2f%%" % (leg, f"{tot:,}", f"{w:,}",
                                       100 * w / tot if tot else 0))
    for p in sorted(per):
        print("         $%06X %18s" % (p, f"{per[p]:,}"))
