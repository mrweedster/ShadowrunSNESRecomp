#!/usr/bin/env python3
"""Print the guest's live text buffer per frame for one framedump leg.

usage: menutext.py <leg-dir> [start-frame] [end-frame] [needle]

The name/message window at $7E21A0 is the only place the game renders item,
action and menu-entry names into WRAM, so its per-frame stream is the oracle
for "what screen is this" and "which entry is highlighted" -- labels, menu
rows, pickup notices and combat messages all pass through it, and the window
shows its first 18 characters. Residue persists across screens, so read the
stream per frame rather than only at dump tags.

Optional needle: also print every frame whose WRAM contains that substring
as printable ASCII, with the offsets, e.g. `Beretta` to watch the item name
move between the sign label, the item box and the equipment line.
"""
import glob
import os
import re
import sys

TEXT = 0x21A0
NAME = re.compile(rb"[\x20-\x7e]{5,}")


def main():
    leg = sys.argv[1]
    lo = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    hi = int(sys.argv[3]) if len(sys.argv) > 3 else 1 << 30
    needle = sys.argv[4].encode() if len(sys.argv) > 4 else None
    prev = None
    for f in sorted(glob.glob(os.path.join(leg, "frame_*_wram.bin"))):
        n = int(os.path.basename(f).split("_")[1])
        if n < lo or n > hi:
            continue
        d = open(f, "rb").read()
        head = "".join(chr(c) if 32 <= c < 127 else "." for c in d[TEXT:TEXT + 18])
        hits = set()
        if needle:
            for m in NAME.finditer(d):
                if needle in m.group():
                    hits.add((hex(m.start()), m.group().decode()[:40]))
        if head != prev or hits:
            print("f%-6d %-20s %s" % (n, head, sorted(hits) if hits else ""))
            prev = head


main()
