#!/usr/bin/env python3
"""Checkpoint-state matrix for the seeded trees, as markdown.

    cpdump_matrix.py <control-run-dir> <variant-run-dir>...

Each directory is one tree's dump of the same route (tests/seed_variant.sh
writes tests/out/r4/<variant>/).  The comparison itself is
tests/framedump_diff.py cpdump, which lines the runs up by the script's tagged
checkpoints (A0..A5, H8, J1..J10, K1..K3, L0..L1) and compares the per-frame
state images taken there: wram/vram/oam/cgram/sram as raw images, the host
framebuffer, the APU and PPU-register traces, and the 24-key regs.json.

The table one row per variant, one column per checkpoint:

  clean      every compared surface identical
  apu-only  regs.json and every state image identical; only apu.tsv differs
  DIFFERS   what differs, listed

The apu.tsv-only case matters because it is the one difference the seed changes
produce that is *not* machine state: the APU trace is a host-side record of the
APU's activity per frame, and it is the surface a host-timing change touches
first.  A checkpoint where wram.bin, vram.bin, oam.bin, cgram.bin, sram.bin,
the framebuffer or regs.json differ is a guest-state difference and blocks the
seed.

Exit 0 always; this generates text for the round record, it does not gate.
"""
import re
import subprocess
import sys

SURFACES = ("wram.bin", "vram.bin", "oam.bin", "cgram.bin", "sram.bin",
            "fb.bgrx", "apu.tsv", "ppuw.tsv", "dma.tsv")

FRAME_RE = re.compile(r"^== (\S+) ==\s+frame (\d+)/(\d+)")
CLOCK_RE = re.compile(r"^\s+master_clock\s+(\d+)\s*->\s*(\d+)\s+delta ([+-]\d+)")
REGS_RE = re.compile(r"^\s+regs\.json: (\d+) keys compared, (\d+) differ")
IMG_RE = re.compile(r"^\s+images: (.*)")


def parse(control, variant):
    out = subprocess.run([sys.executable, "tests/framedump_diff.py", "cpdump",
                          control, variant],
                         capture_output=True, text=True).stdout
    both = None
    cps = []
    tag = frames = clk = regs = None
    for line in out.splitlines():
        m = re.match(r"^checkpoints in both: (.*)", line)
        if m:
            both = m.group(1).split()
            continue
        m = FRAME_RE.match(line)
        if m:
            tag, frames, clk, regs = m.group(1), (int(m.group(2)), int(m.group(3))), 0, None
            continue
        m = CLOCK_RE.match(line)
        if m and tag:
            clk = int(m.group(2)) - int(m.group(1))
            continue
        m = REGS_RE.match(line)
        if m and tag:
            regs = int(m.group(2))
            continue
        m = IMG_RE.match(line)
        if m and tag:
            surf = {}
            for ent in re.split(r"\s{2,}", m.group(1).strip()):
                parts = ent.split()
                if len(parts) == 2:
                    surf[parts[0]] = parts[1]
            cps.append({"tag": tag, "frames": frames, "clock_delta": clk,
                        "regs_differ": regs, "surfaces": surf})
            tag = None
    return both, cps


def verdict(cp):
    bad = [k for k, v in cp["surfaces"].items() if v == "DIFFERS"]
    if cp["regs_differ"]:
        return "DIFFERS(regs+%s)" % ",".join(sorted(bad)) if bad else "DIFFERS(regs)"
    if not bad:
        return "clean"
    if bad == ["apu.tsv"]:
        return "apu-only"
    return "DIFFERS(%s)" % ",".join(sorted(bad))


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip())
        return 2
    control, variants = sys.argv[1], sys.argv[2:]
    print("# checkpoint-state matrix")
    print()
    print("Control run: `%s`.  Each cell is one tagged checkpoint, comparing the" % control)
    print("state images both runs took at that frame (`tests/framedump_diff.py cpdump`):")
    print("24 regs.json keys, wram/vram/oam/cgram/sram images, the host framebuffer,")
    print("and the apu/ppuw/dma traces.")
    print()
    print("| checkpoint | control frame | " + " | ".join(variants) + " |")
    print("|" + "---|" * (2 + len(variants)))
    rows = {}
    summary = {}
    for v in variants:
        _, cps = parse(control, v)
        for cp in cps:
            rows.setdefault(cp["tag"], {"frames": cp["frames"]})[v] = cp
            s = summary.setdefault(v, {"clean": 0, "apu": 0, "bad": [],
                                       "clk": {}, "regs": 0})
            vd = verdict(cp)
            if vd == "clean":
                s["clean"] += 1
            elif vd == "apu-only":
                s["apu"] += 1
            else:
                s["bad"].append(cp["tag"])
            s["clk"][cp["tag"]] = cp["clock_delta"]
            s["regs"] += cp["regs_differ"] or 0
    for tag in sorted(rows, key=lambda t: rows[t]["frames"][0]):
        info = rows[tag]
        cells = [verdict(info[v]) if v in info else "-" for v in variants]
        print("| %s | %d | %s |" % (tag, info["frames"][0], " | ".join(cells)))
    print()
    print("The master-clock delta is the variant's clock at that checkpoint minus")
    print("the control's; a seeded body runs the same guest instructions, so a")
    print("state-clean tree shows +0 there.")
    print()
    print("| variant | checkpoints | clean | apu-only | guest-state differing | regs keys differed | master-clock delta at first/last checkpoint |")
    print("|" + "---|" * 7)
    for v in variants:
        s = summary.get(v, {"clean": 0, "apu": 0, "bad": [], "clk": {}, "regs": 0})
        clk = s["clk"]
        span = ""
        if clk:
            first = min(clk, key=lambda t: rows[t]["frames"][0])
            last = max(clk, key=lambda t: rows[t]["frames"][0])
            span = "%s %s / %s %s" % (first, format(clk[first], "+,"),
                                      last, format(clk[last], "+,"))
        print("| %s | %d | %d | %d | %s | %d | %s |" %
              (v, s["clean"] + s["apu"] + len(s["bad"]), s["clean"], s["apu"],
               ", ".join(s["bad"]) or "none", s["regs"], span))
    return 0


if __name__ == "__main__":
    sys.exit(main())
