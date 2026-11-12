#!/usr/bin/env python3
"""Frontier seed list for a promotion round (the loop in evidence/m1_hybrid_decision.md).

The M1 decision leaves a standing loop: the B0 read trace names 512-byte blocks
the interpreter takes instructions from and that sit inside no analysed span, and
each round answers that by adding [[func]] entries in recomp/symbols.toml, so the
next generation analyses them as code. This script derives the seed list for the
next round from a set of traces and a program_manifest.json, and prints it as
paste-ready TOML.

    tests/frontier_seeds.py                       # current traces + current src/gen
    tests/frontier_seeds.py --traces 'tests/out/b0/[a-z]*.json'
    tests/frontier_seeds.py --manifest <dir-or-file>   # join against a candidate gen
    tests/frontier_seeds.py --all                  # include sub-1Ki-read blocks

What a seed is, and what it is not:

  * a seed is the FIRST BYTE of a frontier block. The pair table is keyed
    (reading PC, block index), so it can prove a block was fetched from but not
    which byte inside it an entry sits at; only block starts are defensible
    without a per-read log, which the observer deliberately does not produce.
  * that is also the round's weakness, and it is measurable: mid-block entries
    stay interpreted, so the frontier shrinks only as far as entry discovery from
    those seeds reaches. The next round's seed list falls out of the next trace.
  * blocks fetched with fewer than 1,024 reads are held back by default: at that
    size a "routine" is as likely to be a two-byte stub or an aliased data
    table, and promoting data into AOT is the one failure mode this loop has.
"""

import argparse
import collections
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cart_trace_report as ctr  # noqa: E402

ROM_DEFAULT, BLOCK = 1048576, 512
MIN_READS = 1024


def bus_of(off):
    """Bus address a LoROM ROM byte at this physical offset is read at.

    The trace's key is a physical cart offset, `off = (bank & 0x7f) << 15 |
    (adr & 0x7fff)`, so it is lossy in two ways and both have to be undone here:

      * LoROM maps a cart bank into $8000-$FFFF only, so every ROM read has
        adr >= $8000 and bit 15 of the address is not in `off` at all: it is
        always $8000. Dropping it produced addresses below $8000, which are not
        ROM addresses in LoROM, and the analyzer answered every one of them with
        `empty_decode` - a whole round of seeds decoding to nothing.
      * Bank $80 aliases $00 (bit 7 of the bank byte is ignored by the cart),
        so the same byte is also $00:AC00. Seeds are named in the form the
        trace shows, which is the form the interpreter's PC carries.
    """
    return 0x80 + (off >> 15), 0x8000 | (off & 0x7FFF)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--traces", default="tests/out/b0/[a-z]*.json")
    ap.add_argument("--manifest", default="src/gen/program_manifest.json",
                    help="manifest file, or a directory holding one")
    ap.add_argument("--min-reads", type=int, default=MIN_READS)
    ap.add_argument("--all", action="store_true",
                    help="no read-count floor")
    a = ap.parse_args()

    paths = sorted(glob.glob(a.traces))
    if not paths:
        raise SystemExit(f"no traces match {a.traces!r}")
    traces = [(os.path.basename(p)[:-5], ctr.load_trace(p)) for p in paths]
    man_path = a.manifest
    if os.path.isdir(man_path):
        man_path = os.path.join(man_path, "program_manifest.json")
    man = _manifest_at(man_path)

    routes, blocks, pairs, banks = ctr.merge(traces)
    fetched = {o for o, e in blocks.items() if "f" in e["via"]}
    frontier = sorted(fetched - man["span_blocks"])

    held = [o for o in frontier if blocks[o]["count"] < a.min_reads]
    if a.all:
        held = []
    seeds = [o for o in frontier if o not in held]

    total_reads = sum(d["totals"]["rom_reads"] for _, d in traces)
    fr_reads = sum(blocks[o]["count"] for o in frontier)
    print(f"traces: {len(traces)} ({', '.join(n for n, _ in traces)})")
    print(f"manifest: {man_path}")
    print(f"  {man['nodes']} nodes, {man['roots']} roots, {man['insns']:,} "
          f"instructions, spans over {len(man['span_blocks'])} blocks")
    print(f"frontier: {len(frontier)} blocks, {len(frontier)*BLOCK:,} B, "
          f"{fr_reads:,} reads ({100*fr_reads/total_reads:.1f} % of "
          f"{total_reads:,})")
    if held:
        print(f"held back below {a.min_reads:,} reads: {len(held)} blocks "
              f"({sum(blocks[o]['count'] for o in held):,} reads) "
              f"[{', '.join(f'${bank:02X}:{adr:04X}' for bank, adr
                             in (bus_of(o) for o in held))}]")
    print()

    # group contiguous seeds so a round reads as ranges, not a wall of addresses
    runs = []
    for o in seeds:
        if runs and o == runs[-1][-1] + BLOCK:
            runs[-1].append(o)
        else:
            runs.append([o])
    for run in runs:
        lo, hi = run[0], run[-1]
        bank0, adr0 = bus_of(lo)
        bank1, adr1 = bus_of(hi)
        reads = sum(blocks[o]["count"] for o in run)
        span = (hi - lo + BLOCK)
        print(f"# ${bank0:02X}:{adr0:04X}-${bank1:02X}:{adr1:04X}  "
              f"phys {lo:06X}-{hi+BLOCK-1:06X}  {span//1024} KiB, {len(run)} blocks, "
              f"{reads:,} reads")
        for o in run:
            bank, adr = bus_of(o)
            print(f'[[func]]\nname = "FR_{bank:02X}{adr:04X}"\n'
                  f'addr = "{adr:04X}"\nbank = 0x{bank:02X}\nemit = true\n'
                  f'note = "promotion round seed: B0 trace fetched '
                  f'{blocks[o]["count"]:,} reads at ${bank:02X}:{adr:04X}"\n')
    return 0


def _manifest_at(path):
    """load_manifest() is port-root based; call it on an arbitrary manifest."""
    with open(path) as fh:
        doc = json.load(fh)
    nodes = doc.get("nodes") or {}
    if not nodes:
        raise SystemExit(f"{path}: nodes is empty")
    span, insns = set(), 0
    for node in nodes.values():
        lo, hi = node.get("min_pc24"), node.get("max_pc24")
        if lo is None or hi is None or hi < lo:
            continue
        insns += node.get("instruction_count") or 0
        for pc in range(lo, hi + 1):
            span.add(ctr.block_of(
                ctr.bus_to_phys((pc >> 16) & 0xFF, pc & 0xFFFF, ROM_DEFAULT), BLOCK))
    return {"nodes": len(nodes), "roots": len(doc.get("roots") or []),
            "insns": insns, "span_blocks": span}


if __name__ == "__main__":
    raise SystemExit(main())
