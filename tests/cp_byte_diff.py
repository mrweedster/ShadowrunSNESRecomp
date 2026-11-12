#!/usr/bin/env python3
"""Byte-level state diff at the route's tagged checkpoints, as markdown.

    cp_byte_diff.py <control-run-dir> <variant-run-dir> [TAG ...] [surface ...]

`tests/framedump_diff.py cpdump` says whether a checkpoint's state images match;
this says *how much* of them differs and shows the bytes, so a rejection can
cite a byte instead of "the crc differs".

Surfaces default to the raw guest-memory images the harness dumps at a tagged
`dump` step: wram ($7E0000, 128 KiB), vram, oam, cgram, sram.  The host
framebuffer (fb.bgrx) is listed separately because it is what a guest-state
change eventually shows up as, and it is not guest memory.

WRAM bytes are split with the rule `tests/framedump_diff.py` already uses and
does not redefine (imported here): the host's frame-kernel counter window and
the game's documented timer singletons are *labels*, so a row can say "10 bytes
differ, 9 of them labels, 1 of them state" instead of "the crc differs".  The
bytes shown are the state bytes; a row with 0 of them differs only in labels,
which is what a clock shift looks like and not what a wrong computation looks
like.  That split does not make such a seed acceptable: the gate is byte
equality, and the clock shift is itself the defect.

Tags default to every TAG.* pair present in both directories.
Exit 0 always; this generates text for the round record, it does not gate.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from framedump_diff import _is_label  # noqa: E402  (one label rule, not two)

DEFAULT_SURFACES = ("wram.bin", "vram.bin", "oam.bin", "cgram.bin", "sram.bin")
BASE = {"wram.bin": 0x7E0000, "vram.bin": 0x210000, "oam.bin": 0x020000,
        "cgram.bin": 0x3E8000, "sram.bin": 0x700000, "fb.bgrx": 0}
SHOW = 6


def diff(a, b):
    n = min(len(a), len(b))
    out = []
    for i in range(n):
        if a[i] != b[i]:
            out.append((i, a[i], b[i]))
    if len(a) != len(b):
        out.append((-1, 0, 0))
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip())
        return 2
    control, variant = sys.argv[1], sys.argv[2]
    rest = sys.argv[3:]
    surfaces = [s for s in rest if "." in s] or list(DEFAULT_SURFACES)
    tags = [s for s in rest if "." not in s] or sorted(
        {p.split(".")[0] for p in os.listdir(control) if "." in p} &
        {p.split(".")[0] for p in os.listdir(variant) if "." in p})
    print("# checkpoint byte diff: %s vs %s" % (control, variant))
    print()
    print("Bytes differing in the state images each run dumped at the same tagged")
    print("checkpoint (`dump TAG` in the route).  Address columns are the guest")
    print("bus address of the byte, control value then variant value.  On wram,")
    print("`label` counts the bytes the label rule in framedump_diff.py excuses")
    print("(host frame-kernel counter window, documented timer singletons);")
    print("`state` is every other differing byte, and those are the ones shown.")
    print()
    print("| checkpoint | surface | bytes differ | label | state | size"
          " | state bytes (control -> variant) | span |")
    print("|" + "---|" * 8)
    physics = {}
    for tag in tags:
        for surf in surfaces:
            pa, pb = (os.path.join(d, "%s.%s" % (tag, surf))
                      for d in (control, variant))
            if not (os.path.exists(pa) and os.path.exists(pb)):
                continue
            d = diff(open(pa, "rb").read(), open(pb, "rb").read())
            size = os.path.getsize(pa)
            if not d:
                print("| %s | %s | 0 | 0 | 0 | %s | identical | - |"
                      % (tag, surf, f"{size:,}"))
                continue
            if d[0][0] < 0:
                print("| %s | %s | size differs | - | - | %s / %s | | |"
                      % (tag, surf, f"{os.path.getsize(pa):,}",
                         f"{os.path.getsize(pb):,}"))
                continue
            base = BASE.get(surf, 0)
            # The label rule is wram-offset based; on the other images the same
            # numbers would be a different chip's addresses, so nothing there
            # is excused as a label.
            label = (lambda off: _is_label(off)) if surf == "wram.bin" \
                else (lambda off: False)
            lab = [t for t in d if label(t[0])]
            keep = [t for t in d if not label(t[0])]
            physics[tag] = physics.get(tag, 0) + len(keep)
            shown = " ".join("$%06X:%02X->%02X" % (base + i, x, y)
                             for i, x, y in keep[:SHOW])
            if len(keep) > SHOW:
                shown += " …(%d more)" % (len(keep) - SHOW)
            if not keep:
                shown = "labels only"
            span = "$%06X-$%06X" % (base + d[0][0], base + d[-1][0])
            print("| %s | %s | %s | %s | %s | %s | %s | %s |"
                  % (tag, surf, f"{len(d):,}", f"{len(lab):,}", f"{len(keep):,}",
                     f"{size:,}", shown, span))
    def frame_of(tag):
        # tags arrive alphabetically (J1, J10, L1); the claim is about which
        # checkpoint came first on the route, so order by the control's frame.
        try:
            return int(json.load(open(os.path.join(control, "%s.info.json"
                                                   % tag)))["frame"])
        except Exception:
            return -1

    first = sorted((t for t, n in physics.items() if n), key=frame_of)
    print()
    if first:
        print("checkpoints with state (non-label) bytes differing, in route "
              "order: %s"
              % ", ".join("%s f%d (%s)" % (t, frame_of(t), f"{physics[t]:,}")
                          for t in first[:8]))
    else:
        print("no checkpoint has a state (non-label) byte differing: every WRAM "
              "difference on this run is a label byte")
    return 0


if __name__ == "__main__":
    sys.exit(main())
