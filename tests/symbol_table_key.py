#!/usr/bin/env python3
"""Can the seed table express an entry per (address, mode)?  Answer from the pin.

    symbol_table_key.py <tier2-capture.json> [program_manifest.json[.bz2]]

A round that wants to hand a hot loop to a compiled body has to declare that
loop's entry.  `recomp/symbols.toml` carries `entry_m` / `entry_x` per
`[[func]]`, so it looks like an entry per (address, mode) is expressible.  This
prints the pin's own loader rule, then the port's declarations joined to the
capture's hot rows at the same addresses, so the answer is quoted rather than
remembered.

Exit 0; this generates text for the round record.
"""
import bz2
import collections
import json
import os
import re
import subprocess
import sys


def I(x):
    return int(x, 16) if isinstance(x, str) else int(x)


def pin_root():
    root = os.environ.get("SNESRECOMP_ROOT")
    if not root or not os.path.isfile(os.path.join(root, "snesrecomp_cli.py")):
        sys.exit("SNESRECOMP_ROOT must point at the framework checkout "
                 "(see framework_pins.txt)")
    return root


def declared(port="recomp"):
    """(pc24 -> [(name, emit, m, x, where)]) from symbols.toml, as the loader reads it."""
    text = open(os.path.join(port, "symbols.toml")).read()
    out = collections.defaultdict(list)
    for blk in text.split("[[func]]")[1:]:
        name = re.search(r'name\s*=\s*"([^"]+)"', blk)
        addr = re.search(r'addr\s*=\s*"([0-9A-Fa-f]{4})"', blk)
        bank = re.search(r"bank\s*=\s*0x([0-9A-Fa-f]{2})", blk)
        emit = re.search(r"emit\s*=\s*(true|false)", blk)
        m = re.search(r"entry_m\s*=\s*(\d)", blk)
        x = re.search(r"entry_x\s*=\s*(\d)", blk)
        if not (name and addr and bank):
            continue
        pc = int(bank.group(1), 16) << 16 | int(addr.group(1), 16)
        out[pc].append((name.group(1), emit.group(1) if emit else "?",
                        m.group(1) if m else "1", x.group(1) if x else "1",
                        "%s/symbols.toml" % port))
    for fn in sorted(os.listdir(port)):
        if not fn.endswith(".cfg"):
            continue
        for n, line in enumerate(open(os.path.join(port, fn)), 1):
            m = re.match(r"\s*(func|lle)\s+(\S+)\s+([0-9A-Fa-f]{4})\s+entry_mx:(\d),(\d)",
                         line)
            if m:
                pc = int(fn[4:-4], 16) << 16 | int(m.group(3), 16)
                out[pc].append((m.group(2), m.group(1), m.group(4), m.group(5),
                                "%s/%s:%d" % (port, fn, n)))
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        return 2
    root = pin_root()
    cap = json.load(open(sys.argv[1]))
    man = None
    if len(sys.argv) > 2:
        raw = open(sys.argv[2], "rb").read()
        if sys.argv[2].endswith(".bz2"):
            raw = bz2.decompress(raw)
        man = json.loads(raw)

    print("# can the seed table declare an entry per (address, M/X)?")
    print()
    print("framework pin %s" % root)
    print()
    print("## the loader's rule, from the pin")
    print()
    loader = os.path.join(root, "tools", "sync_symbols.py")
    lines = open(loader).read().split("\n")
    for n, line in enumerate(lines, 1):
        if "addresses.get" in line or "conflicting tier/entry modes" in line \
                or "addresses[symbol.pc24]" in line:
            print("    %s:%d: %s" % (loader.replace(root + "/", ""), n, line))
    print()
    print("So one pc24 carries exactly one (emit, entry_m, entry_x) policy in the")
    print("symbol table; a second declaration of the same address in another mode is")
    print("a hard loader error, not an additional entry.")
    print()

    print("## what the port declares at the hottest addresses of the capture")
    print()
    dec = declared()
    hot = collections.Counter()
    hot_i = collections.Counter()
    for row in cap["hot_instructions"]:
        key = I(row["target_pc24"])
        hot[key] += row.get("guest_cycles", 0)
        hot_i[key] += row.get("interpreted_instructions", 0)
    modes_at = collections.defaultdict(collections.Counter)
    for row in cap["hot_instructions"]:
        modes_at[I(row["target_pc24"])][row["entry_mx"]] += row.get("guest_cycles", 0)
    gap_sites = collections.defaultdict(collections.Counter)
    for d in cap.get("discoveries", []):
        if d.get("site_kind") in ("call_gap", "goto_gap"):
            gap_sites[I(d["target_pc24"])][d["entry_mx"]] += d.get("observed_hits", 0)

    print("Top capture PCs whose *entry* address the port already declares, plus the")
    print("capture's M/X modes seen at that address:")
    print()
    print("| declared address | declaration | hot PC | entry modes the interpreter ran it in | interpreted insns | guest cycles | gap sightings per mode |")
    print("|" + "---|" * 7)
    shown = 0
    for pc, n_cyc in sorted(hot.items(), key=lambda kv: -kv[1]):
        if pc not in dec or shown >= 8:
            continue
        for (nm, emit, m, x, where) in dec[pc]:
            print("| $%06X | %s emit=%s m=%s x=%s (%s) | $%06X | %s | %s | %s | %s |"
                  % (pc, nm, emit, m, x, where, pc,
                     ", ".join("%s (%s cyc)" % (k, f"{v:,}")
                               for k, v in modes_at[pc].most_common()),
                     f"{hot_i[pc]:,}", f"{n_cyc:,}",
                     ", ".join("%s: %s hits" % (k, f"{v:,}")
                               for k, v in gap_sites[pc].most_common()) or "none"))
        shown += 1
    print()

    if man:
        print("## the same addresses in the generated program")
        print()
        nodes = man["nodes"]
        for pc, n_cyc in sorted(hot.items(), key=lambda kv: -kv[1])[:8]:
            mine = [(k, n) for k, n in nodes.items()
                    if n.get("min_pc24") is not None
                    and n["min_pc24"] <= pc <= n["max_pc24"]]
            if not mine:
                continue
            for k, n in mine:
                print("| $%06X (%s cyc interpreted) | node %s | %s | %s insns | span $%06X-$%06X | entry is a root: %s |"
                      % (pc, f"{n_cyc:,}", k, n["disposition"],
                         n.get("instruction_count"), n["min_pc24"], n["max_pc24"],
                         any(r.get("pc24") == I(k.split(":")[0]) for r in man["roots"])))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
