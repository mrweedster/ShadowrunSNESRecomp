#!/usr/bin/env python3
"""Turn the framework's ROM-read traces (SNESRECOMP_CART_TRACE) into the
extraction question answered: which ROM bytes does the game actually read, how,
and which routine reads them.

    cart_trace_report.py tests/out/b0/*.json [--markdown report.md]
                         [--gen src/gen] [--coverage tests/out/a1/summary.json]

One file per scripted route (tests/collect_read_traces.sh makes them). The
observer records counts, not a log, so the joins here work on 512-byte physical
blocks and (reading PC, block) pairs -- which is the shape the question is asked
in: a range that is only ever read by address is data, a range that was fetched
is code, and a range nobody read is a candidate for not shipping at all.

Reading a trace is not the same as trusting one, so the report repeats the
observer's honesty fields (pair_overflows, ring_wraps, tail_reads) rather than
letting a bound silently under-count, refuses a file whose seam list does not
name the CPU bus (a v1 trace sees ~1% of the reads and no fetches at all), and
every range it names is given in both physical ROM offsets and bus addresses,
since the game addresses ROM by bank and an extraction has to write bytes at
offsets.
"""

import argparse
import collections
import glob
import json
import os
import re
import sys

SCHEMA = "snesrecomp.cart-trace.v2"
# The seam the numbers are only credible with. v1 watched cart_read only, which
# the CPU bus does not go through, and produced 264,368 reads with zero fetches
# on a route that really performs ~38 million; a file with an older seam list
# would silently under-count by three orders of magnitude.
REQUIRED_SEAMS = ("cpu_read8",)


# ---------------------------------------------------------------- reading ----

def load_trace(path):
    with open(path) as fh:
        doc = json.load(fh)
    if doc.get("schema") != SCHEMA:
        extra = ""
        if doc.get("schema") == "snesrecomp.cart-trace.v1":
            extra = (" -- v1 watched the cart bus only and missed every CPU "
                     "ROM read; re-collect with a build of the framework that "
                     "has the cpu_read8 seam")
        raise SystemExit(f"{path}: schema {doc.get('schema')!r}, "
                         f"expected {SCHEMA!r}{extra}")
    seams = (doc.get("seams") or "").split(",")
    for want in REQUIRED_SEAMS:
        if want not in seams:
            raise SystemExit(f"{path}: seams={doc.get('seams')!r} does not name "
                             f"{want!r}, so this trace does not see the CPU bus")
    if doc.get("totals", {}).get("cpu_reads", 0) == 0:
        raise SystemExit(f"{path}: cpu_reads = 0, which on a route that runs the "
                         "guest is not possible -- the seam is not wired")
    for field in ("pair_overflows", "ring_wraps", "tail_reads", "rom_resets"):
        if doc.get("totals", {}).get(field):
            print(f"note: {os.path.basename(path)}: {field} = "
                  f"{doc['totals'][field]} (a bound was hit)", file=sys.stderr)
    if doc.get("pairs_truncated"):
        print(f"note: {os.path.basename(path)}: pair list truncated at the dump cap",
              file=sys.stderr)
    return doc


# ------------------------------------------------------- bus <-> physical ----
# LoROM, matching cart_getRomPtr: canonical = bank & 0x7f, then
# off = (canonical << 15) | (adr & 0x7fff), then modulo the ROM size. Banks
# $C0-$FF therefore alias $40-$7F, and for a 1 MiB image both land back inside
# the first megabyte. Kept here rather than trusted from memory of the game.

def bus_to_phys(bank, adr, rom_size):
    canonical = bank & 0x7F
    off = (canonical << 15) | (adr & 0x7FFF)
    return off % rom_size


def parse_pc(text):
    return int(text, 16)


# ------------------------------------------------------ function starts ----

GEN_DEF = re.compile(r"^(?:RecompReturn|void)\s+(\w+)\s*\(\s*CpuState", re.M)
GEN_ENTRY = re.compile(r'cpu_trace_func_entry\(cpu,\s*(0x[0-9A-Fa-f]{6}),\s*"([^"]+)"\)')
CFG_FUNC = re.compile(r"^func\s+(\w+)\s+([0-9a-fA-F]{4})\b", re.M)
CFG_BANK = re.compile(r"^bank\s*=\s*(\d+)", re.M)


def code_entries(root, rom_size):
    """(starts, promoted): the port's entry points, and the promoted subset.

    `starts` is every entry point the port names, used to label the ranges the
    trace finds. `promoted` is the subset the recompiler compiled into host
    code, which matters separately: the AOT path runs those as host functions,
    so it never fetches their bytes from ROM and the read trace cannot say they
    are code. Only that list can.

    Three sources, in order of how much they can be trusted:

      - `cpu_trace_func_entry(cpu, 0xBBBBBB, "name")` in the generated units
        states the 24-bit bus address and the name together, straight from the
        recompiler, so it is the primary source and it also names the handful of
        vectors (I_RESET_M1X1, I_IRQ_*) whose symbols say nothing about address;
      - a definition called `bank_BB_AAAA_MxXy` encodes the same thing in its
        name, which is how the older units are read;
      - `recomp/bankNN.cfg` names entry points by hand with a bank taken from
        the file, which is where the vectors and the hand-written entries live.

    Extents are recorded nowhere, so a label is only ever "the nearest known
    entry at or below this address" -- an upper-bounded guess, labelled as such
    in the report.
    """
    starts, promoted = {}, {}
    for path in sorted(glob.glob(os.path.join(root, "src", "gen", "*.c"))):
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        for m in GEN_ENTRY.finditer(text):
            bus, name = int(m.group(1), 16), m.group(2)
            phys = bus_to_phys((bus >> 16) & 0xff, bus & 0xffff, rom_size)
            label = f"{name} (${bus >> 16:02X}:{bus & 0xffff:04X})"
            starts.setdefault(phys, label)
            promoted.setdefault(phys, label)
        for m in GEN_DEF.finditer(text):
            name = m.group(1)
            base = re.sub(r"_M[01]X[01]$", "", name)
            mm = re.fullmatch(r"bank_([0-9A-Fa-f]{2})_([0-9A-Fa-f]{4})", base)
            if not mm:
                continue
            bank, adr = int(mm.group(1), 16), int(mm.group(2), 16)
            starts.setdefault(bus_to_phys(bank, adr, rom_size),
                              f"{base} (${bank:02X}:{adr:04X})")
    for cfg in sorted(glob.glob(os.path.join(root, "recomp", "bank*.cfg"))):
        with open(cfg, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        bm = CFG_BANK.search(text)
        bank = int(bm.group(1)) if bm else 0
        for m in CFG_FUNC.finditer(text):
            name, adr = m.group(1), int(m.group(2), 16)
            starts.setdefault(bus_to_phys(bank, adr, rom_size),
                              f"{name} (${bank:02X}:{adr:04X})")
    return sorted(starts.items()), sorted(promoted.items())


# ------------------------------------------------- program manifest join ----
# The trace says which bytes were fetched. It cannot say how far a routine runs,
# because the port records no extents. The recompiler's own analysis does have a
# shape that is close: src/gen/program_manifest.json, one node per (PC, M, X) the
# analyzer reached, each with a bounding [min_pc24, max_pc24] span. Joining the
# two is the only extents-like statement available in this project, and it is
# worth being precise about which way its error goes:
#   * a span is a bounding box, not a routine body, so it over-marks code;
#   * the analyzer is seeded by recomp/symbols.toml, so a block in no span is
#     unanalysed, not proven to be data.
# Both errors point the same way for the question asked here: the "fetched but in
# no span" set is a conservative list of places where the interpreter demonstrably
# takes instructions and nothing has ever analysed them.

MANIFEST_FORMAT = 3


def block_of(off, block_bytes):
    """The trace's block key containing this physical offset.

    Keys are block *starting offsets*, not block numbers, and a byte offset has
    to be floored to one rather than assumed to be one. Deriving them here the
    same way the trace does is what keeps a join honest; a join that assumed
    block numbers produced confidently wrong answers, and the answer it produced
    ("no promoted code was ever read") was the opposite of the truth. The trace's
    own keys are checked for alignment where they are read, not here.
    """
    return off - off % block_bytes


def load_manifest(root, rom_size, block_bytes=512):
    path = os.path.join(root, "src", "gen", "program_manifest.json")
    if not os.path.isfile(path):
        return None
    with open(path) as fh:
        doc = json.load(fh)
    fmt = doc.get("format_version")
    if fmt != MANIFEST_FORMAT:
        print(f"note: {path}: format_version {fmt!r}, expected {MANIFEST_FORMAT}; "
              f"reading it anyway", file=sys.stderr)
    nodes = doc.get("nodes") or {}
    if not nodes:
        raise SystemExit(f"{path}: nodes is empty, which is not a usable analysis")
    span_blocks, lle_blocks = set(), set()
    span_bytes = 0
    insns = 0
    dispositions = collections.Counter()
    for key, node in nodes.items():
        lo, hi = node.get("min_pc24"), node.get("max_pc24")
        if lo is None or hi is None or hi < lo:
            continue
        dispositions[node.get("disposition")] += 1
        span_bytes += hi - lo + 1
        insns += node.get("instruction_count") or 0
        # Walk the bus span a byte at a time and map each address on its own bank
        # byte: a node whose min and max sit in different banks is not one
        # contiguous physical range under LoROM.
        # An `lle_only` node is still analysed code -- the analyzer proved it and
        # chose to leave it interpreted. So it belongs in span_blocks (it is not a
        # gap in what has been analysed) and additionally in lle_blocks.
        for pc in range(lo, hi + 1):
            pb = block_of(bus_to_phys((pc >> 16) & 0xFF, pc & 0xFFFF, rom_size),
                          block_bytes)
            span_blocks.add(pb)
            if node.get("disposition") == "lle_only":
                lle_blocks.add(pb)
    return {"path": path, "format_version": fmt, "nodes": len(nodes),
            "roots": len(doc.get("roots") or []), "span_blocks": span_blocks,
            "lle_blocks": lle_blocks, "span_bytes": span_bytes, "insns": insns,
            "dispositions": dispositions}


def attribute_pairs(pairs, block_bytes, rom_size):
    """Split each block's reads into instruction-stream and by-address, by row.

    For a fetch the reading PC *is* the fetched byte's own address, so a pair row
    carrying `f` whose PC maps into the same block it names is an instruction-stream
    read; any other row is a read taken by address. Both sides are floors, because
    the pair table is the dumped sample and long routes hit the row cap -- but the
    ratio between the two survives a cut that drops whole (PC, block) keys, which is
    what makes this worth quoting at all. The block table is the authority on
    amounts; this is the authority on what kind of reads they were.
    """
    fetch, data = collections.Counter(), collections.Counter()
    for (pc, off), e in pairs.items():
        pb = block_of(off, block_bytes)
        pc_blk = block_of(bus_to_phys((pc >> 16) & 0xFF, pc & 0xFFFF, rom_size),
                          block_bytes)
        (fetch if ("f" in e["via"] and pc_blk == pb) else data)[pb] += e["count"]
    return fetch, data


class Labeler:
    def __init__(self, starts):
        self.starts = starts
        self.addrs = [a for a, _ in starts]

    def label(self, phys):
        """(label, distance) for the nearest known entry at or below phys."""
        import bisect
        if not self.addrs:
            return None
        i = bisect.bisect_right(self.addrs, phys) - 1
        if i < 0:
            return None
        return self.starts[i][1], phys - self.addrs[i]


# ------------------------------------------------------------- merging ----

def merge(traces):
    blocks, pairs, banks = {}, {}, {}
    routes = []
    for name, doc in traces:
        routes.append((name, doc))
        for b in doc.get("blocks", []):
            off = int(b["off"], 16)
            e = blocks.setdefault(off, {"count": 0, "via": set(), "first": None, "last": 0})
            e["count"] += b["count"]
            e["via"] |= set(b.get("via", ""))
            first, last = b.get("frames", [0, 0])
            if e["first"] is None or first:
                e["first"] = first if e["first"] is None else min(e["first"], first)
            e["last"] = max(e["last"], last)
        for p in doc.get("pairs", []):
            key = (int(p["pc"], 16), int(p["off"], 16))
            e = pairs.setdefault(key, {"count": 0, "via": set(), "first": None, "last": 0})
            e["count"] += p["count"]
            e["via"] |= set(p.get("via", ""))
            first, last = p.get("frames", [0, 0])
            e["first"] = first if e["first"] is None else min(e["first"], first) if first else e["first"]
            e["last"] = max(e["last"], last)
        for b in doc.get("banks", []):
            bkn = int(b["bank"], 16)
            e = banks.setdefault(bkn, {"reads": 0, "via": set()})
            e["reads"] += b["reads"]
            e["via"] |= set(b.get("via", ""))
    return routes, blocks, pairs, banks


# ------------------------------------------------------------- ranges ----

def coalesce(blocks, want):
    """Contiguous runs of 512-byte blocks whose `via` satisfies want()."""
    offs = sorted(o for o, e in blocks.items() if want(e["via"]))
    runs = []
    for o in offs:
        if runs and o == runs[-1][1] + 512:
            runs[-1][1] = o
        else:
            runs.append([o, o])
    return [(a, b) for a, b in runs]


def reads_in(blocks, lo, hi):
    return sum(e["count"] for o, e in blocks.items() if lo <= o <= hi)


def frames_in(blocks, lo, hi):
    entries = [e for o, e in blocks.items() if lo <= o <= hi]
    firsts = [e["first"] for e in entries if e["first"]]
    lasts = [e["last"] for e in entries if e["last"]]
    return (min(firsts) if firsts else 0, max(lasts) if lasts else 0)


def near_label(lab, pc, rom_size, within=0x200):
    """Containing function when a known entry sits just below the PC.

    Extents are not recorded anywhere, so a big distance means "unknown", not
    "inside": an entry 0x400 bytes back is a different routine as often as not.
    """
    got = lab.label(pc % rom_size)
    if not got or got[1] > within:
        return ""
    return f"{got[0]} +{got[1]:#x}"


def readers(pairs, lo, hi, top=3):
    hits = {}
    for (pc, off), e in pairs.items():
        if lo <= off <= hi:
            hits[pc] = hits.get(pc, 0) + e["count"]
    return sorted(hits.items(), key=lambda kv: -kv[1])[:top]


# ------------------------------------------------------------- report ----

def write_digest(path, traces, paths, blocks, banks, promoted, cls,
                 fetched_only, fetch_blocks, block_bytes, rom_size,
                 neutral_logs=(), man_summary=None):
    """Commit-worthy plain-text summary of the same numbers as the markdown.

    The traces are build output (`tests/out/` is gitignored), so an evidence file
    would otherwise quote numbers a reader cannot re-check. This records them in
    the same shapes, and names each input by sha256 so a later run can tell
    whether it is re-deriving a number or contradicting one.
    """
    import hashlib

    def sha(p):
        h = hashlib.sha256()
        with open(p, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 16), b""):
                h.update(chunk)
        return h.hexdigest()[:16]

    L = []
    def out(s=""):
        L.append(s)

    def bar(title):
        head = "-- " + title + " "
        return head + "-" * max(3, 72 - len(head))

    seams = sorted({str(d.get("seams")) for _, d in traces})
    out("=== ROM-read trace digest ===")
    out(f"schema {SCHEMA}  rom_size {rom_size}  block_bytes {block_bytes}")
    out(f"seams {';'.join(seams)}")
    out("re-derive: bash tests/collect_read_traces.sh   (writes the traces and")
    out("tests/out/b0/report.md), then this file with --digest. The traces are")
    out("build output and are not committed; their hashes are what bind this file.")
    out("Both gates refuse a binary whose framework is not the revision named in")
    out("framework_pins.txt (tests/provenance.py pin), so the program behind these")
    out("numbers is named by the run, not by this file.")
    out()
    out(bar("inputs"))
    for (name, d), p in zip(traces, paths):
        out(f"{name:10} {os.path.getsize(p):>9} B  sha256 {sha(p)}  {p}")
    out()
    out(bar("per route"))
    out(f"{'route':10} {'rom_reads':>13} {'cpu':>13} {'dma':>10} {'instr':>13} "
        f"{'pairs':>7} {'ring_wraps':>10} {'trunc':>6} {'blocks':>7}")
    tot = collections.Counter()
    for name, d in traces:
        t = d["totals"]
        for k in ("rom_reads", "cpu_reads", "dma_reads", "fetch_reads",
                  "distinct_pairs", "ring_wraps", "pair_overflows", "tail_reads",
                  "rom_resets"):
            tot[k] += t.get(k, 0)
        out(f"{name:10} {t['rom_reads']:>13} {t['cpu_reads']:>13} "
            f"{t['dma_reads']:>10} {t['fetch_reads']:>13} "
            f"{t['distinct_pairs']:>7} {t.get('ring_wraps', 0):>10} "
            f"{str(bool(d.get('pairs_truncated'))):>6} {len(d.get('blocks', [])):>7}")
    out(f"{'merged':10} {tot['rom_reads']:>13} {tot['cpu_reads']:>13} "
        f"{tot['dma_reads']:>10} {tot['fetch_reads']:>13}"
        f"{'':>25}{len(blocks):>7}")
    out(f"{'':10} of {rom_size // block_bytes} blocks in the image; "
        f"{sum(1 for e in blocks.values() if 'f' in e['via'])} carry instruction reads")
    out()
    out(f"instruction-stream share: {100 * tot['fetch_reads'] / tot['rom_reads']:.1f}%"
        f"   DMA share: {100 * tot['dma_reads'] / tot['rom_reads']:.3f}%")
    honest = {k: tot[k] for k in ("pair_overflows", "tail_reads", "rom_resets",
                                  "ring_wraps")}
    out(f"honesty: " + "  ".join(f"{k}={v}" for k, v in honest.items())
        + f"   pairs_truncated={', '.join(n for n, d in traces if d.get('pairs_truncated')) or 'none'}")
    out("(ring_wraps only rolls the recent-read sample; blocks, pairs and the")
    out("totals are complete. pairs_truncated shortens the pair table only.)")
    out()

    fetched = {o for o, e in blocks.items() if "f" in e["via"]}
    read = set(blocks)
    never = set(range(0, rom_size, block_bytes)) - read
    nblocks = rom_size // block_bytes
    out(bar(f"footprint, {block_bytes} B blocks ({nblocks} blocks in the image)"))
    out(f"read at all            {len(read):>5} blocks {len(read) * block_bytes:>8} B "
        f"{100 * len(read) / nblocks:5.1f}%")
    out(f"fetched (instruction)  {len(fetched):>5} blocks {len(fetched) * block_bytes:>8} B "
        f"{100 * len(fetched) / nblocks:5.1f}%")
    out(f"read, never fetched    {len(read - fetched):>5} blocks "
        f"{len(read - fetched) * block_bytes:>8} B "
        f"{100 * len(read - fetched) / nblocks:5.1f}%")
    out(f"never read             {len(never):>5} blocks {len(never) * block_bytes:>8} B "
        f"{100 * len(never) / nblocks:5.1f}%")
    out()

    all_reads = sum(e["count"] for e in blocks.values())
    ranked = sorted(blocks.items(), key=lambda kv: -kv[1]["count"])
    out(bar(f"where the reads go (merged {all_reads} reads)"))
    for o, e in ranked[:8]:
        out(f"  {o:06X} {phys_to_bus(o)} {e['count']:>13} "
            f"{100 * e['count'] / all_reads:5.2f}% via {''.join(sorted(e['via']))} "
            f"f{e['first']}-{e['last']}")
    for n in (8, 20):
        share = sum(e["count"] for _, e in ranked[:n])
        out(f"  top {n} blocks ({n * block_bytes // 1024} KiB) carry "
            f"{100 * share / all_reads:.1f}% of all reads")
    out()

    fruns = coalesce(blocks, lambda v: "f" in v)
    out(bar(f"fetched runs ({len(fruns)} of {len(fetched)} fetched blocks)"))
    for a, b in fruns:
        out(f"  {a:06X}-{b + block_bytes - 1:06X}  {phys_to_bus(a)}-{phys_to_bus(b + block_bytes - 1)}"
            f"  {(b - a + block_bytes) // 1024} KiB")
    out()
    fbanks = sorted(f"${k:02X}" for k, e in banks.items() if "f" in e["via"])
    out(f"bus banks carrying a fetch mark: {', '.join(fbanks)}")
    out("(the bank table is never truncated, unlike the pair table; $00 is the")
    out("LoROM mirror of physical bank 0)")
    out()

    never_runs = coalesce({o: {"via": ""} for o in never}, lambda v: True)
    never_runs.sort(key=lambda r: -(r[1] - r[0]))
    out(bar(f"largest never-read runs ({len(never_runs)} of {len(never)} blocks)"))
    for a, b in never_runs[:10]:
        out(f"  {a:06X}-{b + block_bytes - 1:06X}  {phys_to_bus(a)}-{phys_to_bus(b + block_bytes - 1)}"
            f"  {(b - a + block_bytes) // 1024} KiB")
    out()

    out(bar(f"join against promoted code ({len(promoted)} entry points)"))
    for k in ("fetched", "read not fetched", "not read at all"):
        out(f"  {k:16} {len(cls[k]):>4}")
    out(f"  fetched blocks with no promoted entry point: {len(fetched_only)}"
        f" = {len(fetched_only) * block_bytes // 1024} KiB of {fetch_blocks} fetched blocks")
    out("  (a promoted function's extent is not recorded anywhere, so these are")
    out("  block-level statements: one 512 B block can hold a promoted routine and")
    out("  a neighbour the interpreter ran. That is why this trace cannot produce")
    out("  the byte-level extraction list; it can only bound it.)")
    for phys, name in sorted(cls["read not fetched"] + cls["not read at all"]):
        e = blocks.get(block_of(phys, block_bytes))
        det = "none" if e is None else f"{e['count']} reads, via {''.join(sorted(e['via']))}"
        out(f"  {phys:06X} {phys_to_bus(phys)} {name}  [{det}]")
    out()
    out(bar("join against program_manifest.json"))
    if man_summary is None:
        out("  (no src/gen/program_manifest.json under --port-root; nothing to join)")
    else:
        ms = man_summary
        out("  nodes %d (%s)  roots %d  insns %d" %
            (ms["nodes"],
             " ".join(f"{k}={v}" for k, v in sorted(ms["dispositions"].items())),
             ms["roots"], ms["insns"]))
        out("  bounding spans: %d B over %d blocks (%d KiB, %.1f%% of image)" %
            (ms["span_bytes"], ms["span_blocks"], ms["span_blocks"] * block_bytes // 1024,
             100 * ms["span_blocks"] * block_bytes / rom_size))
        out("  span blocks: fetched %d  read-not-fetched %d  never-read %d" %
            (ms["fetched_in_span"], ms["span_blocks_read_not_fetched"],
             ms["never_read"]))
        out("  promotion frontier (fetched, inside no span): %d blocks = %d KiB, "
            "%d reads = %.1f%% of all reads" %
            (ms["frontier"], ms["frontier_bytes"] // 1024, ms["frontier_reads"],
             100 * ms["frontier_reads"] / ms["all_reads"]))
        out("  lle_only blocks: %d  (proven code left interpreted on purpose)" %
            ms["lle_blocks"])
        out("  frontier reads split by kind (pair rows, so a floor; row tables "
            "short on %s):" % (", ".join(ms["pairs_truncated"]) or "none"))
        out("    %-22s %14s %14s %14s" % ("run", "reads", "fetch", "by address"))
        for a, b, r, f, d in ms["runs"]:
            out("    %06X-%06X  %14d %14d %14d" % (a, b + block_bytes - 1, r, f, d))
        out("    %-22s %14d %14d %14d" %
            ("frontier total", sum(x[2] for x in ms["runs"]),
             ms["frontier_fetch_rows"], ms["frontier_data_rows"]))
        out("  (a node's span is a bounding box, and analysis is seeded by")
        out("  recomp/symbols.toml: 'inside no span' means unanalysed, not proven to")
        out("  be data. Both errors make the frontier smaller, not bigger.)")
        out("  action: [[func]] entries at those addresses, then tools/regen.sh")
    out()
    out(bar("neutrality (tests/cart_trace_neutral.sh)"))
    out("Same SRAM snapshot, three legs, per-frame WRAM crc32. ctrl differs from")
    out("off by the framework source only; off differs from on by the env variable.")
    extracted = 0
    for log in neutral_logs:
        try:
            with open(log) as fh:
                lines = fh.read().splitlines()
        except OSError as exc:
            out(f"  (could not read {log}: {exc})")
            continue
        legs = [l for l in lines if re.match(r"^(ctrl|off|on)\s+gen_sha256=", l)]
        verdicts = [l.strip() for l in lines
                    if re.match(r"^\s+(ctrl/off|off/on): ", l)]
        # Which programs the legs ran, checked against framework_pins.txt by the
        # gate itself before it started. Without these lines the digest records
        # "identical over 25,902 frames" without saying what the control was --
        # which is precisely the claim that had to be re-measured once.
        # dict.fromkeys: the gate prints the pin check twice on purpose (once at
        # startup, so an operator sees it before the legs, once in its verdict
        # file, which is the copy other tooling reads).
        binding = list(dict.fromkeys(
            l.strip() for l in lines if re.match(
                r"^(scenario:|frames:|AT THE PIN|OFF THE PIN|NOT THE PIN|UNKNOWN)",
                l)))
        if not legs and not verdicts:
            continue
        extracted += 1
        out(f"  {os.path.basename(log)}")
        for l in binding:
            out(f"    {l}")
        for l in legs:
            out(f"    {l}")
        for v in verdicts:
            out(f"  -> {v}")
    if not extracted:
        out("  (no --neutral logs given; the gate prints these lines itself)")

    with open(path, "w") as fh:
        fh.write("\n".join(L) + "\n")
    print(f"(digest written to {path})", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("traces", nargs="+", help="cart-trace JSON files (one per route)")
    ap.add_argument("--markdown", help="also write the report here")
    ap.add_argument("--port-root", default=".", dest="port_root",
                    help="port root, the directory holding src/gen and recomp/ "
                         "(not src/gen itself)")
    ap.add_argument("--coverage", help="optional A1 coverage summary.json, for a cross-check")
    ap.add_argument("--digest", help="also write a compact plain-text digest here "
                                     "(this is the file worth committing; the "
                                     "traces themselves are build output)")
    ap.add_argument("--neutral", action="append", default=[],
                    metavar="LOG",
                    help="cart_trace_neutral.sh log file to fold into the digest "
                         "(repeatable)")
    ap.add_argument("--top", type=int, default=20, help="rows per table")
    args = ap.parse_args()

    paths = []
    for pattern in args.traces:
        paths.extend(sorted(glob.glob(pattern)) or [pattern])
    traces = [(os.path.splitext(os.path.basename(p))[0], load_trace(p)) for p in paths]
    if not traces:
        raise SystemExit("no trace files")

    rom_sizes = {d.get("rom_size") for _, d in traces}
    if len(rom_sizes) > 1:
        raise SystemExit(f"traces disagree about ROM size: {rom_sizes}")
    rom_size = rom_sizes.pop()
    block_bytes = traces[0][1].get("block_bytes", 512)

    routes, blocks, pairs, banks = merge(traces)
    starts, promoted = code_entries(args.port_root, rom_size)
    lab = Labeler(starts)
    if not starts:
        # An empty entry-point set is not "the game has no named routines", it is
        # the report reading the wrong directory: --port-root wants the port root,
        # and src/gen/recomp are looked for underneath it. Every label column in
        # this report would be a dash, which reads like a finding.
        print(f"note: no entry points found under {args.port_root!r} "
              f"(--port-root wants the port root, holding src/gen and recomp/); "
              f"the label columns will be empty", file=sys.stderr)

    L = []
    def out(line=""):
        L.append(line)

    out(f"# ROM-read trace report")
    out()
    out(f"Schema `{SCHEMA}`, block size {block_bytes} B, ROM {rom_size:,} B "
        f"({rom_size // block_bytes:,} blocks).")
    seam_sets = {d.get("seams") for _, d in traces}
    out(f"Seams: {'; '.join(sorted(str(s) for s in seam_sets))}.")
    out(f"Routes: {', '.join(n for n, _ in traces)}.  "
        f"{len(starts)} entry points known, {len(promoted)} of them promoted to "
        f"host code (from {os.path.join(args.port_root, 'src/gen')} and "
        f"{os.path.join(args.port_root, 'recomp')}/*.cfg).")
    if not starts:
        out()
        out(f"**No entry points were found under {args.port_root!r}, so every "
            f"label column below is empty. Pass `--port-root` the port root.**")
    out()
    out("What the numbers can and cannot say, because three of them are narrower")
    out("than they look:")
    out()
    out("- the fetch mark (`f`) only exists on the interpreted path. The AOT path")
    out("  runs host functions and never fetches ROM through the emulator at all,")
    out("  so a block that is code but was only ever executed recompiled shows up")
    out("  here as not-fetched. What the AOT path executes is the promoted-function")
    out("  list (--port-root) and the A1 coverage capture (--coverage), not this")
    out("  file; the join against it is its own section below.")
    out("- `f` marks an instruction's bytes, not only its opcode. The interpreter's")
    out("  code-bank reader also serves the operand bytes of direct, absolute and")
    out("  indexed modes, so the mark runs a little wider than 'opcode' and never")
    out("  wider than the instruction. Immediates and jump tables reached by")
    out("  computed address stay `c`.")
    out("- the reading PC on a pair is the last PC the interpreter published. Reads")
    out("  made by recompiled code therefore carry the PC of whatever instruction")
    out("  ran interpreted just before them, so use the PC columns to rank on the")
    out("  interpreted path, not to attribute individual reads to routines. For a")
    out("  fetch the PC is the fetched byte's own address, which is why a pair row")
    out("  for hot code usually reads `cf`: the fetch and the following read of the")
    out("  next byte land on the same row.")
    out()

    out("## Totals per route")
    out()
    out("| route | ROM reads | CPU | DMA | instruction-stream reads | distinct pairs | blocks touched |")
    out("|---|---:|---:|---:|---:|---:|---:|")
    for name, d in traces:
        t = d["totals"]
        out(f"| {name} | {t['rom_reads']:,} | {t['cpu_reads']:,} | {t['dma_reads']:,} | "
            f"{t['fetch_reads']:,} | {t['distinct_pairs']:,} | "
            f"{len(d.get('blocks', [])):,} |")
    out()
    honest = {f: sum(d['totals'].get(f, 0) for _, d in traces)
              for f in ("pair_overflows", "tail_reads", "ring_wraps", "rom_resets")}
    bad = {k: v for k, v in honest.items() if v and k != "ring_wraps"}
    trunc = [n for n, d in traces if d.get("pairs_truncated")]
    out("Which bounds were reached, and what each one costs, because they are not")
    out("interchangeable and a single 'under-counts' line would overstate the damage")
    out("as easily as hide it:")
    out()
    ring = {n: d["totals"].get("ring_wraps", 0) for n, d in traces}
    out(f"- `ring_wraps` (every route: {', '.join(f'{n} {v:,}' for n, v in ring.items() if v)}, "
        f"total {honest['ring_wraps']:,}): the ring is a 16,384-entry recent-traffic")
    out("  sample, so a wrap means the sample rolled over. Nothing else in the file")
    out("  is affected -- `blocks`, `pairs` and the totals are all complete.")
    if trunc:
        out(f"- `pairs_truncated` ({', '.join(trunc)}): the pair list is capped at")
        out("  20,000 rows. The totals above still count every read; the reading-PC")
        out("  table below is the one that is short, and its counts are the ones the")
        out("  cap kept.")
    if bad:
        out("- " + ", ".join(f"`{k}`={v:,}" for k, v in bad.items()))
    else:
        out("- `pair_overflows`, `tail_reads`, `rom_resets`: all zero, so the pair")
        out("  hash never had to drop a key, no read arrived while the tables were")
        out("  being torn down, and the ROM image was never swapped mid-run.")
    out()

    fetched = coalesce(blocks, lambda v: "f" in v)
    data = coalesce(blocks, lambda v: "f" not in v)
    fetch_blocks = sum(1 for e in blocks.values() if "f" in e["via"])
    data_blocks = len(blocks) - fetch_blocks
    dma_blocks = sum(1 for e in blocks.values() if "d" in e["via"])

    out("## Code vs data, by observation")
    out()
    out(f"- blocks read at all: {len(blocks):,} of {rom_size // block_bytes:,} "
        f"({100.0 * len(blocks) / (rom_size // block_bytes):.1f}% of the image)")
    out(f"- **fetched as opcodes** (so it is code): {fetch_blocks:,} blocks "
        f"= {fetch_blocks * block_bytes // 1024:,} KiB")
    out(f"- **never fetched** (only ever read by address): {data_blocks:,} blocks "
        f"= {data_blocks * block_bytes // 1024:,} KiB")
    out(f"- read by DMA as well as the CPU: {dma_blocks:,} blocks")
    out(f"- never read by anything in these routes: "
        f"{rom_size // block_bytes - len(blocks):,} blocks "
        f"= {(rom_size // block_bytes - len(blocks)) * block_bytes // 1024:,} KiB")
    out()
    out("Not-fetched is the extraction candidate set, but it is not proof of data: a"
        " routine can reach code these routes never execute, and the mark is recorded"
        " at block granularity, so a block counts as fetched when any byte in it was"
        " taken from the instruction stream, not when the whole block is instructions.")
    out()

    # ---- the join the trace cannot do on its own ----
    # Every promoted function's own bytes are invisible to this observer unless
    # something also read them: host code does not fetch. So the promoted list is
    # what turns "not fetched" from a guess into a statement, and the two sets
    # overlapping is a finding rather than noise -- it says that range ran both
    # ways on these routes.
    #
    # `blocks` is keyed by the block's starting OFFSET (0x01E800), not by block
    # number, so everything here has to round the offset down and stay in that
    # space. Guard it: keyed wrong, every lookup misses and the table below reads
    # as "no promoted code was ever touched", which is exactly the wrong answer
    # and looks like a finding.
    misaligned = [o for o in blocks if o % block_bytes]
    if misaligned:
        raise SystemExit(f"block keys are not {block_bytes}-byte aligned "
                         f"(e.g. {misaligned[0]:#08x}); the join would compare the "
                         f"wrong key space")

    def blk(off):
        """The trace's block key containing this physical offset."""
        return block_of(off, block_bytes)

    ent_blk = {}
    for phys, name in promoted:
        ent_blk.setdefault(blk(phys), []).append(name)

    cls = {"fetched": [], "read not fetched": [], "not read at all": []}
    for phys, name in promoted:
        e = blocks.get(blk(phys))
        if e is None:
            cls["not read at all"].append((phys, name))
        elif "f" in e["via"]:
            cls["fetched"].append((phys, name))
        else:
            cls["read not fetched"].append((phys, name))
    fetched_only = [o for o, e in blocks.items()
                    if "f" in e["via"] and o not in ent_blk]

    out("## The join against promoted code")
    out()
    out(f"The observer cannot see recompiled code fetching anything, so the promoted"
        f" list is what makes `not fetched` mean something. Classified at block"
        f" granularity ({block_bytes} B), against {len(promoted)} promoted entry points:")
    out()
    out("| promoted entry point's block was... | entries | what it means |")
    out("|---|---:|---|")
    out(f"| fetched on at least one route | {len(cls['fetched']):,} | the block holding")
    out("  that entry point had instruction-stream traffic, so code in that block ran")
    out("  interpreted somewhere on these routes. At 512 B this is not the same as 'this")
    out("  function ran interpreted': a block can hold a promoted routine and a")
    out("  neighbouring routine that never got promoted |")
    out(f"| read but never fetched | {len(cls['read not fetched']):,} | something")
    out("  reads those bytes by address: a table or constant sharing the block, or a")
    out("  routine entered by computed address whose bytes are data as well |")
    out(f"| not read at all | {len(cls['not read at all']):,} | nothing read this")
    out("  block on these routes, so whatever lives there ran only as host code |")
    out()
    others = cls["read not fetched"] + cls["not read at all"]
    if others:
        out("The entry points outside the first row are the interesting ones: their")
        out("blocks carry no instruction traffic at all, so on these routes the")
        out("recompiler is the only thing that ran them and the cart is not needed to")
        out("run them:")
        out()
        out("| physical | bus | entry point | block traffic |")
        out("|---|---|---|---|")
        for phys, name in sorted(others):
            e = blocks.get(blk(phys))
            if e is None:
                detail = "none"
            else:
                detail = f"{e['count']:,} reads, via {''.join(sorted(e['via']))}"
            out(f"| {phys:06X} | {phys_to_bus(phys)} | {name} | {detail} |")
        out()
    out(f"Fetched blocks holding no promoted entry point: {len(fetched_only):,} "
        f"= {len(fetched_only) * block_bytes // 1024:,} KiB, out of {fetch_blocks:,} "
        f"fetched blocks. That is the code the interpreter still ran on these routes "
        f"and the recompiler has not compiled, and it is the part of the image a "
        f"ROM-free build has to keep fetchable rather than extract, because the "
        f"interpreter is what reads it.")
    if cls["fetched"]:
        out()
        out("Promoted entry points whose block was also fetched (so these ranges ran")
        out("interpreted too):")
        out()
        out("| physical | bus | entry point | reads | frames |")
        out("|---|---|---|---:|---|")
        for phys, name in sorted(cls["fetched"],
                                 key=lambda pn: -blocks[blk(pn[0])]["count"]
                                 )[: args.top]:
            e = blocks[blk(phys)]
            out(f"| {phys:06X} | {phys_to_bus(phys)} | {name} | {e['count']:,} | "
                f"{e['first']}-{e['last']} |")
    out()

    out("### By bank: what could leave the cart")
    out()
    per_bank_blocks = min(rom_size, 0x8000) // block_bytes
    out("Keyed on physical offsets, so the `$00`-`$7F` mirror folds into the same")
    out("row as its `$80`-`$FF` window, and each row is one 32 KiB bank "
        f"({per_bank_blocks} blocks).")
    out()
    out("| bank (bus window) | promoted entries | fetched blocks | read, not fetched | never read |")
    out("|---|---:|---:|---:|---:|")
    ent_per_bank = {}
    for phys, _ in promoted:
        bk = phys_to_bus_bank(phys)
        ent_per_bank[bk] = ent_per_bank.get(bk, 0) + 1
    per_bank = {}
    for o, e in blocks.items():
        bk = phys_to_bus_bank(o)
        row = per_bank.setdefault(bk, {"f": 0, "d": 0})
        row["f" if "f" in e["via"] else "d"] += 1
    for bk in sorted(set(per_bank) | set(ent_per_bank)):
        row = per_bank.get(bk, {"f": 0, "d": 0})
        never = max(0, per_bank_blocks - row["f"] - row["d"])
        out(f"| {bk:02X} | {ent_per_bank.get(bk, 0):,} | {row['f']:,} | {row['d']:,} | "
            f"{never:,} |")
    out()
    out("A bank with no fetched blocks and no promoted entries inside is where an")
    out("extraction starts: nothing in these routes took instruction bytes from it,")
    out("and no compiled function lives there. A bank with fetched blocks is where the")
    out("interpreter still needs the cart.")
    out()

    man = load_manifest(args.port_root, rom_size, block_bytes)
    fetch_set = {o for o, e in blocks.items() if "f" in e["via"]}
    if man is None:
        out("### The same question against `program_manifest.json`")
        out()
        out(f"No `src/gen/program_manifest.json` under {args.port_root!r}, so this")
        out("report cannot say which of those fetched bytes the recompiler's analysis")
        out("has already looked at. That file is generated by `tools/regen.sh`.")
        man_summary = None
    else:
        read_set = set(blocks)
        inside = man["span_blocks"] & set(fetch_set)
        out("### The same question against `program_manifest.json`")
        out()
        out(f"The trace cannot give routine extents; the analyzer's own manifest can,")
        out(f"in a bounded form. `{os.path.relpath(man['path'], args.port_root)}`")
        out(f"(format v{man['format_version']}) has {man['nodes']} nodes "
            f"({'/'.join(f'{k}={v}' for k, v in sorted(man['dispositions'].items()))}),")
        out(f"{man['roots']} roots, {man['insns']:,} instructions, bounding spans over")
        out(f"{man['span_bytes']:,} B in {len(man['span_blocks'])} blocks "
            f"({len(man['span_blocks']) * block_bytes // 1024} KiB, "
            f"{100 * len(man['span_blocks']) / (rom_size // block_bytes):.1f}% of the image).")
        out()
        out("| manifest span blocks that are... | blocks |")
        out("|---|---:|")
        out(f"| fetched on a route | {len(inside):,} |")
        out(f"| read but never fetched | {len(man['span_blocks'] & (read_set - set(fetch_set))):,} |")
        out(f"| never read on these routes | {len(man['span_blocks'] - read_set):,} |")
        out()
        frontier = sorted(set(fetch_set) - man["span_blocks"])
        freads = sum(blocks[o]["count"] for o in frontier)
        all_reads = sum(e["count"] for e in blocks.values())
        out(f"Fetched blocks inside no manifest span: **{len(frontier)} = "
            f"{len(frontier) * block_bytes // 1024:,} KiB**, carrying "
            f"**{freads:,} reads ({100 * freads / all_reads:.1f}% of all ROM reads)**.")
        out()
        out("That is the promotion frontier: the interpreter provably takes instruction")
        out("bytes there, and nothing in this project has ever analysed them as code.")
        out("Two errors, both in the conservative direction:")
        out()
        out("- a node's span is a bounding box between its lowest and highest PC, so a")
        out("  table in the middle of a routine marks that block as analysed;")
        out("- analysis is seeded by `recomp/symbols.toml`, so a block in no span is")
        out("  unanalysed, not proven to be data.")
        out()
        out(f"Acting on it needs no new framework capability: add `[[func]]` entries at")
        out(f"those addresses and re-run `tools/regen.sh`. The 12 nodes already marked")
        out(f"`lle_only` ({len(man['lle_blocks'])} blocks) are a different case: the")
        out("analyzer proved them and chose to leave them interpreted, which is a cfg")
        out("flag rather than new analysis.")
        out()
        runs = [(a, b) for a, b in coalesce({o: {"via": ""} for o in frontier},
                                            lambda v: True)]
        pf, pd = attribute_pairs(pairs, block_bytes, rom_size)
        out("| physical | bus | bytes | reads | of which fetch (`f`) | of which by address |")
        out("|---|---|---:|---:|---:|---:|")
        tf = td = tt = 0
        run_stats = []
        for a, b in runs:
            offs = range(a, b + block_bytes, block_bytes)
            r = sum(blocks[o]["count"] for o in offs)
            f = sum(pf[o] for o in offs)
            d = sum(pd[o] for o in offs)
            tf += f
            td += d
            tt += r
            run_stats.append((a, b, r, f, d))
            out(f"| {a:06X}-{b + block_bytes - 1:06X} | {phys_to_bus(a)}-"
                f"{phys_to_bus(b + block_bytes - 1)} | {(b - a + block_bytes):,} | "
                f"{r:,} | {f:,} | {d:,} |")
        out(f"| **frontier total** | | {len(frontier) * block_bytes:,} | {tt:,} | "
            f"{tf:,} | {td:,} |")
        out()
        truncated = sorted(name for name, d in traces if d.get("pairs_truncated"))
        out(f"Those last two columns come from the pair rows, not the block table, so "
            f"they are floors: the row tables are short on "
            f"{', '.join(truncated) if truncated else 'no route'}. Their ratio is not "
            f"affected the way an amount is, because the cut drops whole (reading PC, "
            f"block) keys rather than skewing one kind of read. On the frontier, "
            f"{100 * tf / max(tf + td, 1):.1f} % of what the rows can see is "
            f"instruction-stream traffic.")
        out()
        out("So the frontier is not the game reading constants that happen to sit in a "
            "code bank: it is the interpreter taking instructions from addresses its "
            "analysis never covered. That is a promotion job, and a bounded one.")
        out()
        out("Note which bank most of this sits in: `$80` and `$00` are the same physical")
        out("bytes under LoROM, and bank `$00` is read on every route, so those bytes")
        out("cannot leave the cart image even once they are compiled -- promoting them")
        out("removes interpreted traffic, not the cart.")
        man_summary = {
            "nodes": man["nodes"], "dispositions": man["dispositions"],
            "roots": man["roots"], "insns": man["insns"],
            "span_bytes": man["span_bytes"], "span_blocks": len(man["span_blocks"]),
            "lle_blocks": len(man["lle_blocks"]), "fetched_in_span": len(inside),
            "span_blocks_read_not_fetched": len(man["span_blocks"] & (read_set - set(fetch_set))),
            "frontier": len(frontier), "frontier_bytes": len(frontier) * block_bytes,
            "frontier_reads": freads, "all_reads": all_reads,
            "frontier_fetch_rows": tf, "frontier_data_rows": td,
            "pairs_truncated": truncated,
            "runs": run_stats, "blocks": blocks,
            "never_read": len(man["span_blocks"] - read_set),
        }
    out()

    out(f"## Largest non-fetched (data) ranges")
    out()
    out("| physical | bus | KiB | reads | frames | top readers |")
    out("|---|---|---:|---:|---|---|")
    ranked = sorted(data, key=lambda r: -reads_in(blocks, r[0], r[1]))
    for lo, hi in ranked[: args.top]:
        size = (hi - lo + block_bytes)
        rd = reads_in(blocks, lo, hi)
        first, last = frames_in(blocks, lo, hi)
        readers_s = "; ".join(
            f"{pc:06X} ({c:,})" + (f" ← {near}" if (near := near_label(lab, pc, rom_size)) else "")
            for pc, c in readers(pairs, lo, hi))
        out(f"| {lo:06X}-{hi + block_bytes - 1:06X} | {phys_to_bus(lo)}-{phys_to_bus(hi + block_bytes - 1)} "
            f"| {size // 1024:,} | {rd:,} | {first}-{last} | {readers_s} |")
    out()
    total_data = sum((hi - lo + block_bytes) for lo, hi in data)
    out(f"Sum of non-fetched ranges: {total_data // 1024:,} KiB across "
        f"{len(data):,} range(s).")
    out()

    out(f"## Top reading PCs (all routes merged)")
    out()
    per_pc = {}
    for (pc, off), e in pairs.items():
        per_pc[pc] = per_pc.get(pc, 0) + e["count"]
    out("| reading PC (bus) | reads | known entry at/below | blocks |")
    out("|---|---:|---|---:|")
    for pc, cnt in sorted(per_pc.items(), key=lambda kv: -kv[1])[: args.top]:
        near = near_label(lab, pc, rom_size) or "-"
        nb = sum(1 for (p, _), e in pairs.items() if p == pc and e["count"])
        out(f"| {pc:06X} | {cnt:,} | {near} | {nb} |")
    out()

    out("## Banks touched")
    out()
    out("| bus bank | reads | via |")
    out("|---|---:|---|")
    for bkn in sorted(banks):
        out(f"| {bkn:02X} | {banks[bkn]['reads']:,} | {''.join(sorted(banks[bkn]['via']))} |")
    out()

    if args.coverage:
        out("## Cross-check against executed code (A1 coverage)")
        out()
        try:
            with open(args.coverage) as fh:
                cov = json.load(fh)
        except OSError as exc:
            out(f"(could not read {args.coverage}: {exc})")
            cov = None
        if cov:
            out("The coverage capture and the read trace come from different builds")
            out("and different flags, so this is a sanity check on the observer's")
            out("instruction-stream counter, not a proof that the two runs match. The")
            out("ratio is read-bytes per instruction: a fully interpreted run sits near")
            out("the mean instruction length (2-5 bytes, less because an immediate")
            out("operand is not read from the code stream), and it falls towards zero")
            out("the more the AOT path ran, because recompiled code reads nothing from")
            out("the cart. A ratio is only printed when the two runs are the same")
            out("length: a coverage capture from an older, shorter version of a script")
            out("is not a denominator for a longer trace.")
            out()
            out("| run | frames (coverage / trace) | instructions | instruction-stream bytes | bytes/instruction |")
            out("|---|---:|---:|---:|---:|")
            for row in cov.get("per_run", []):
                d = dict(traces).get(row["run"])
                if not d:
                    continue
                fr = d["totals"]["fetch_reads"]
                # The trace does not record a route length, but the last frame any
                # block was read in is a bound on how far the run got.
                span = max((b["frames"][1] for b in d.get("blocks", [])
                            if b.get("frames")), default=0)
                same = row["frames"] and span and abs(span - row["frames"]) <= 0.25 * row["frames"]
                ratio = f"{fr / row['instr']:.3f}" if same else f"- (routes differ: {span:,} vs {row['frames']:,} frames)"
                out(f"| {row['run']} | {row['frames']:,} / {span:,} | {row['instr']:,} | "
                    f"{fr:,} | {ratio} |")
            out()

    text = "\n".join(L) + "\n"
    print(text)
    if args.markdown:
        with open(args.markdown, "w") as fh:
            fh.write(text)
        print(f"(written to {args.markdown})", file=sys.stderr)
    if args.digest:
        write_digest(args.digest, traces, paths, blocks, banks, promoted, cls,
                     fetched_only, fetch_blocks, block_bytes, rom_size,
                     neutral_logs=args.neutral, man_summary=man_summary)


def phys_to_bus(off):
    """A representative bus address for a physical offset (LoROM)."""
    bank = 0x80 + (off >> 15)
    return f"${bank:02X}:{0x8000 + (off & 0x7FFF):04X}"


def phys_to_bus_bank(off):
    """The `$80`-window bank whose window holds this physical offset."""
    return 0x80 + (off >> 15)


if __name__ == "__main__":
    main()
