#!/usr/bin/env python3
"""Prove what a scripted route's checkpoints really are, and fail if they are not.

Why this exists: the checkpoint dumps a route writes with `dump <tag>` are the
corpus every cross-path verdict, share record and baseline is measured on. Until
now nothing checked what those checkpoints contained, so a route whose tail
pressed menu keys into a wiped party kept producing checkpoints -- one of them
was the title screen -- and the corpus quietly carried them. A dead checkpoint is
a harness defect, not a measurement, and it costs a round to notice afterwards.

So this reads a leg's tagged dumps and answers one question per checkpoint: is
the party still alive here? It reports the guest frame, the running screen origin,
the party's hp bytes, and the message-window text, and its exit code is the
verdict. A route passes when every tagged checkpoint is before the death; the
last one is where the route should stop.

What "alive" means here, and why it is the test:
  * death markers -- `Jake is dead.` / `Game Over.` in the WRAM window. These are
    the game's own words and they are the strongest signal. Caveat: the message
    window keeps old text as residue for a long time (`Game Over.ad.` was still
    visible inside the morgue cutscene), so residue marks a checkpoint as
    *after* the death, which is what the verdict needs; it does not date it.
  * all-zero hp bytes -- the wipe itself. The seven hp offsets are single bytes
    and they also hold cutscene/menu garbage during the intro (values like 84 or
    245), which is neither alive-confirmed nor dead; those checkpoints are
    flagged `hp=` for a human to read, not failed.
  * the title screen is not detected directly: reaching it on this route always
    follows a wipe, so the death markers catch it. Any future route that can
    reach a title screen without a wipe needs a real title marker added here.

Usage:
  python3 tests/route_state.py <leg-dir> [<leg-dir> ...]
      leg-dir is a --framedump directory; tagged dumps are <tag>.wram.bin plus
      <tag>.info.json (the frame label). frame_* per-frame files are ignored.
  --tags TAG[,TAG]   restrict to these tags (repeatable)
  --from N           skip checkpoints before guest frame N
  --quiet            verdict lines only

Exit codes: 0 = every selected checkpoint is alive; 1 = at least one is after a
death (the route's tail needs cutting); 2 = usage or no tagged dumps found.
"""

import json
import os
import re
import sys

# $7E01F0/$7E01F2: the running screen origin (LE16 pairs). Not the party's own
# position -- the party sub-screen position is not nameable in this 128 KiB
# window -- but the camera origin is stable per screen and clamps to the same
# value on both execution paths, which makes it the usable screen identity.
SCREEN_X = 0x01F0
SCREEN_Y = 0x01F2
# $7E21A0: the message window's text. 18 characters are live at a time and the
# window overlaps older lines, so the readout below shows a wider slice and lets
# the residue show, rather than pretending to cut it.
LABEL = 0x21A0
LABEL_LEN = 30
# Party hp / alive bytes. Measured values: 4 = alive, 0 = dead, 255 = the
# death-transition value on one of them.
HP = (0x0029, 0x0481, 0x04AB, 0x04B0, 0x0CE3, 0x135E, 0x14C2)
DEATH_MARKERS = (b"Jake is dead", b"Game Over")


def frame_of(leg, tag):
    path = os.path.join(leg, tag + ".info.json")
    if not os.path.isfile(path):
        return -1
    try:
        m = re.search(r'"frame":\s*"?(\d+)"?', open(path, errors="replace").read())
        return int(m.group(1)) if m else -1
    except OSError:
        return -1


def read(leg, tag):
    data = open(os.path.join(leg, tag + ".wram.bin"), "rb").read()
    u16 = lambda a: data[a] | (data[a + 1] << 8) if a + 1 < len(data) else -1
    marks = [m.decode() for m in DEATH_MARKERS if m in data]
    hp = [data[a] for a in HP if a < len(data)]
    text = "".join(chr(c) if 32 <= c < 127 else "." for c in data[LABEL:LABEL + LABEL_LEN])
    return {
        "tag": tag,
        "frame": frame_of(leg, tag),
        "screen": (u16(SCREEN_X), u16(SCREEN_Y)),
        "hp": hp,
        "dead": marks or (bool(hp) and all(v == 0 for v in hp)),
        "marks": marks,
        "label": text.strip(),
    }


def main(argv):
    args, legs, want, quiet, frm = argv[1:], [], [], False, 0
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--tags":
            i += 1
            want += args[i].split(",")
        elif a == "--from":
            i += 1
            frm = int(args[i])
        elif a == "--quiet":
            quiet = True
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            legs.append(a.rstrip("/"))
        i += 1
    if not legs:
        print(__doc__.strip().splitlines()[-3])
        return 2

    bad = 0
    seen = 0
    for leg in legs:
        if not os.path.isdir(leg):
            print("%s: no such directory" % leg)
            return 2
        tags = sorted(f[:-9] for f in os.listdir(leg)
                      if f.endswith(".wram.bin") and not f.startswith("frame_"))
        if not tags:
            print("%s: no tagged dumps" % leg)
            return 2
        rows = []
        for t in tags:
            if want and t not in want:
                continue
            r = read(leg, t)
            if r["frame"] < frm:
                continue
            rows.append(r)
        if not rows:
            print("%s: no checkpoint selected" % leg)
            continue
        rows.sort(key=lambda r: r["frame"])
        last_alive = None
        print("== %s (%d checkpoints, f%d..f%d)"
              % (leg, len(rows), rows[0]["frame"], rows[-1]["frame"]))
        for r in rows:
            seen += 1
            flag = "DEAD" if r["dead"] else ("hp=" if any(v != 4 for v in r["hp"]) else "alive")
            if not quiet:
                print("   %-5s f%-7d scr=(%d,%d) hp=%-30s %-5s %r"
                      % (r["tag"], r["frame"], r["screen"][0], r["screen"][1],
                         str(r["hp"]), flag, r["label"]))
            if not r["dead"]:
                last_alive = r
            else:
                bad += 1
        if last_alive:
            print("   last alive checkpoint: %s at f%d" % (last_alive["tag"], last_alive["frame"]))
    if not seen:
        print("no checkpoints matched")
        return 2
    print("verdict: %d of %d checkpoints are after a death -> %s"
          % (bad, seen, "FAIL (route tail needs cutting)" if bad else "all alive"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
