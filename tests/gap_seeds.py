#!/usr/bin/env python3
"""Seed list for a gap-driven promotion round, derived from a coverage capture.

usage: gap_seeds.py <tier2_ingest.json> [--top N] [--route NAME]
                    [--manifest F] [--symbols F] [--min-cycles N]

    tests/gap_seeds.py evidence/artifacts/tier2_capture_round3_combat.json --top 10
    tests/gap_seeds.py <capture.json> --top 10 >> recomp/symbols.toml
    tests/gap_seeds.py <capture.json> --top 10 --list
    tests/gap_seeds.py <capture.json> --top 10 --exclude $80F4F9
    tests/gap_seeds.py <capture.json> --only '$80C399,$80AAB3' >> recomp/symbols.toml
    tests/gap_seeds.py --baseline-only recomp/symbols.toml > baseline.toml

--only / --exclude subset the ranking by entry PC ($-prefixed or bare, 6 hex
digits), and --list prints the ranking as `$PC M x m cycles` rows without
emitting TOML. A round that has to attribute a behaviour change to one seed
rebuilds with the ranking minus that seed, and that variant's seed table must
be generated the same way as the full one — an edited-by-hand symbols.toml is
a second source of truth. --baseline-only is what makes that repeatable: it
prints the table with this tool's own blocks removed, since this tool owns the
block marker.

--force-pc emits rows the ranking does not keep, for a probe: an address where
the capture never sees a transfer, so no seed can intercept it, but where a
declaration tests whether a compiled body the program already has ever gets
control. Those rows are labelled probes in the header and carry the capture's
own `0 gap hits` in the note, and their cycles are never counted inside the
seedable total, so a probe cannot be mistaken for a priced seed.

coverage_gaps.py measures the seedable slice of the interpreted residue: hot
(per-instruction interpreted cost) *and* sighted at a transfer gap (call_gap /
goto_gap), which is the only part a [[func]] entry can intercept. This tool
turns the top of that ranking into paste-ready TOML for recomp/symbols.toml,
so the seed set of a round is a generated artifact of the capture, not a list
someone typed. It carries the capture's own numbers into each note, and it
refuses to emit an entry the program already has (manifest node, or an addr
already declared in symbols.toml).

The numbers also carry the round's ceiling, and it is worth reading before
seeding anything: the ranking is long-tailed, so the top entries cover most of
the seedable slice and the whole seedable slice is a few percent of the
residue. Seeding costs dispatch rows, generated code, and compile time, so a
round that chases past the knee spends those for nothing.

Entry modes come from the capture (`entry_mx`), not the default: a seed with
the wrong mode creates a variant nobody calls.
"""
import argparse
import bz2
import collections
import gzip
import json
import os
import re
import sys
import textwrap

GAP_KINDS = ("call_gap", "goto_gap")


def wrap(text, width=79, indent="# "):
    """One TOML comment paragraph, wrapped, so no emitted line runs long."""
    return textwrap.fill(text, width=width, initial_indent=indent,
                         subsequent_indent=indent)


def I(x):
    return int(x, 16) if isinstance(x, str) else x


def top_json(path):
    """Read a JSON file, transparently uncompressing .bz2 / .gz.

    The archived program manifests in evidence/artifacts are bzip2'd (the same
    shape the captures are stored in), so a tool that ranks against a manifest
    must be able to open the archived one and not a loose scratch copy.
    """
    with open(path, "rb") as raw:
        magic = raw.read(3)
    opener = (bz2.open if magic[:3] == b"BZh" else
              gzip.open if magic[:2] == b"\x1f\x8b" else open)
    with opener(path, "rb") as fh:
        return json.load(fh)


def fr0(g):
    return g["frames"][0] if g["frames"][0] is not None else "-"


def fr1(g):
    return g["frames"][1] if g["frames"][1] is not None else "-"


def rank(r, have, declared, min_cycles):
    """(rows, total attributed, total seedable) — rows ranked by interpreted cycles.

    `have` is every entry the program already has, as spelled by the manifest
    node keys (`80C1C9:M0X0`), and `declared` the same way for what
    recomp/symbols.toml already declares. An entry is dropped when the exact
    key, or one of the capture's own `variant` spellings for it, is in `have`:
    the manifest and the capture do not always spell the bank the same way
    (LoROM banks $80-$BF mirror $00-$3F), so both spellings are checked rather
    than a mask, and nothing is dropped on a mirror that the bridge would not
    in fact have intercepted.
    """
    cost = collections.Counter()
    insns = collections.Counter()
    for row in r["hot_instructions"]:
        key = (I(row["target_pc24"]), row["entry_mx"])
        cost[key] += row["guest_cycles"]
        insns[key] += row["interpreted_instructions"]
    total = sum(cost.values())

    gaps = {}
    for d in r["discoveries"]:
        if d["site_kind"] not in GAP_KINDS:
            continue
        key = (I(d["target_pc24"]), d["entry_mx"])
        g = gaps.setdefault(key, {"kind": d["site_kind"], "hits": 0,
                                  "status": d.get("candidate_status"),
                                  "sites": set(), "frames": [None, None],
                                  "names": set()})
        g["hits"] += d["observed_hits"]
        g["sites"].add(I(d["site_pc24"]))
        if d.get("variant"):
            g["names"].add(d["variant"].upper())
        lo, hi = d.get("first_frame"), d.get("last_frame")
        if lo is not None:
            if g["frames"][0] is None:
                g["frames"] = [lo, hi]
            else:
                g["frames"] = [min(g["frames"][0], lo), max(g["frames"][1], hi)]

    rows = []
    for key, g in gaps.items():
        cyc = cost.get(key, 0)
        if cyc < min_cycles:
            continue
        exact = "%06X:%s" % (key[0], key[1])
        if exact in have or exact in declared:
            continue
        if any(n in have or n in declared for n in g["names"]):
            continue
        rows.append((cyc, key, insns[key], g))
    rows.sort(key=lambda x: -x[0])
    hot_sighted = sum(1 for k in gaps if cost.get(k, 0))
    return rows, total, sum(cost.get(k, 0) for k in gaps), hot_sighted - len(rows)


# The header this tool writes for its own block. Anything containing this marker
# is generated by this tool, so removing it is this tool's job: a variant table
# and the shipped table then differ only by what this tool was asked to emit,
# never by what someone cut by hand.
BLOCK_MARK = "(gap-driven seeds)"


def strip_generated(text):
    """This symbol table with every block this tool generated removed."""
    kept, dropped = [], 0
    for chunk in re.split(r"(?m)^(?=# --- )", text):
        if BLOCK_MARK in chunk.split("\n", 1)[0]:
            dropped += 1
            continue
        kept.append(chunk)
    return "".join(kept), dropped


def manifest_nodes(path):
    """Manifest nodes, or {} when the path is empty or missing."""
    return top_json(path).get("nodes", {}) if path and os.path.exists(path) else {}


def declared_entries(path):
    """`[[func]]` entries a symbol table already declares, as manifest node keys."""
    out = set()
    if not path or not os.path.exists(path):
        return out
    # anchored to a `[[func]]` on a line of its own: the table's own header comment
    # mentions `[[func]]` in prose, and a loose match would count that sentence
    text = open(path).read()
    hdr = re.compile(r"(?m)^\[\[func\]\][ \t]*$")
    starts = [m.end() for m in hdr.finditer(text)]
    for i, at in enumerate(starts):
        blk = text[at:starts[i + 1] if i + 1 < len(starts) else len(text)]
        addr = re.search(r'addr\s*=\s*"([0-9A-Fa-f]+)"', blk)
        bank = re.search(r'bank\s*=\s*0x([0-9A-Fa-f]+)', blk)
        em = re.search(r'entry_m\s*=\s*(\d)', blk)
        ex = re.search(r'entry_x\s*=\s*(\d)', blk)
        if addr and bank:
            mx = "M%sX%s" % (em.group(1) if em else "1", ex.group(1) if ex else "1")
            out.add("%06X:%s" % (int(bank.group(1), 16) << 16
                                 | int(addr.group(1), 16), mx))
    return out


def compare(a, rows, total, seedable):
    """Re-run the same ranking against a capture of the program that shipped
    those seeds, and print what moved.  One tool, two invocations: the seedable
    slice of a shipped tree has to be measured the same way as the round's,
    because a body that is already compiled makes an entry unseedable and that
    is the whole difference between the two numbers."""
    r2 = top_json(a.then)
    man2 = manifest_nodes(a.then_manifest or a.manifest)
    have2 = {k.upper() for k in man2}
    declared2 = declared_entries(a.then_symbols or a.symbols)
    rows2, total2, seedable2, _sk = rank(r2, have2, declared2, a.min_cycles)
    i2 = r2.get("identity", {})

    def line(tag, before, after):
        d = after - before
        print("%-14s %16s -> %16s   (%s%13s, %6.2f%%)"
              % (tag, f"{before:,}", f"{after:,}", "+" if d >= 0 else "-",
                 f"{abs(d):,}", 100.0 * d / before if before else 0.0))

    print("\n==== residue measured again on the program that shipped those seeds")
    print("     capture %s  program_digest %s  build_digest %s"
          % (os.path.basename(a.then), str(i2.get("program_digest"))[:16],
             str(i2.get("build_digest"))[:16]))
    print("     manifest %s  nodes %d  symbols %s  entries %d"
          % (a.then_manifest or a.manifest, len(man2),
             a.then_symbols or a.symbols, len(declared2)))
    line("attributed", total, total2)
    line("seedable", seedable, seedable2)
    line("never sighted", total - seedable, total2 - seedable2)
    print("     seedable entries: %d -> %d   (%.2f%% of attributed -> %.2f%%)"
          % (len(rows), len(rows2), 100.0 * seedable / total,
             100.0 * seedable2 / total2))

    before = {(pc, mx): (cyc, ins) for cyc, (pc, mx), ins, _g in rows}
    after = {(pc, mx): (cyc, ins) for cyc, (pc, mx), ins, _g in rows2}
    gone = sorted((k for k in before if k not in after), key=lambda k: -before[k][0])
    new = sorted((k for k in after if k not in before), key=lambda k: -after[k][0])
    both = [k for k in before if k in after]
    print("\n  left the seedable list (that program has a body there, or the cost "
          "moved inside one): %d entries, %s cyc"
          % (len(gone), f"{sum(before[k][0] for k in gone):,}"))
    for k in gone[:a.top]:
        print("     $%06X %s  %11s cyc  %9s insns"
              % (k[0], k[1], f"{before[k][0]:,}", f"{before[k][1]:,}"))
    if len(gone) > a.top:
        print("     ... %d more" % (len(gone) - a.top))
    print("  entered the seedable list: %d entries, %s cyc"
          % (len(new), f"{sum(after[k][0] for k in new):,}"))
    for k in new[:a.top]:
        print("     $%06X %s  %11s cyc  %9s insns"
              % (k[0], k[1], f"{after[k][0]:,}", f"{after[k][1]:,}"))
    moved = [(k, after[k][0] - before[k][0]) for k in both if after[k][0] != before[k][0]]
    moved.sort(key=lambda x: x[1])
    print("  still seedable, and its interpreted cost at that PC changed: %d entries, "
          "net %s%scyc"
          % (len(moved), "+" if sum(m for _k, m in moved) >= 0 else "-",
             f"{abs(sum(m for _k, m in moved)):,}"))
    for k, d in moved[:a.top]:
        print("     $%06X %s  %11s -> %11s cyc  (%s%10s)"
              % (k[0], k[1], f"{before[k][0]:,}", f"{after[k][0]:,}",
                 "+" if d >= 0 else "-", f"{abs(d):,}"))


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("capture", nargs="?",
                    help="the tier2 capture JSON this round seeds from")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--round", type=int, default=4,
                    help="promotion round this block is for (header and note text)")
    ap.add_argument("--route", default="", help="route the capture ran (note text only)")
    ap.add_argument("--manifest", default="src/gen/program_manifest.json")
    ap.add_argument("--symbols", default="recomp/symbols.toml")
    ap.add_argument("--min-cycles", type=int, default=0)
    ap.add_argument("--only", default="",
                    help="keep only these entry PCs ($80C399,$80AAB3, ...)")
    ap.add_argument("--exclude", default="",
                    help="drop these entry PCs from the ranking")
    ap.add_argument("--force-pc", default="",
                    help=("emit these entry PCs even though the ranking does not "
                          "keep them (e.g. a hot spin loop the capture never sighted "
                          "at a transfer gap); the note says so"))
    ap.add_argument("--list", action="store_true",
                    help="print the ranking as rows instead of TOML")
    ap.add_argument("--baseline-only", metavar="SYMBOLS",
                    help=("print that symbol table with every block this tool generated "
                          "removed, then exit: that is a variant's baseline, cut by the "
                          "tool that owns the marker instead of by hand"))
    ap.add_argument("--then", metavar="CAPTURE",
                    help=("compare against a second capture of the *next* program (needs "
                          "--list): the residue and ranking the round shipped, measured "
                          "again on the tree that already has those bodies"))
    ap.add_argument("--then-manifest", default="",
                    help="program manifest of the --then capture (default: --manifest)")
    ap.add_argument("--then-symbols", default="",
                    help="symbol table of the --then capture (default: --symbols)")
    a = ap.parse_args()

    if a.baseline_only:
        text, dropped = strip_generated(open(a.baseline_only).read())
        sys.stdout.write(text)
        print("baseline: %d generated block(s) removed, %d [[func]] entries left"
              % (dropped, len(re.findall(r"(?m)^\[\[func\]\][ \t]*\r?$", text))),
              file=sys.stderr)
        return 0
    if not a.capture:
        ap.error("a tier2 capture JSON is required unless --baseline-only is given")
    if a.then and not a.list:
        ap.error("--then re-ranks a second capture, so it needs --list")

    def pcs(spec):
        return {int(t.strip().lstrip("$"), 16)
                for t in spec.split(",") if t.strip()}

    only, drop = pcs(a.only), pcs(a.exclude)

    r = top_json(a.capture)
    ident = r.get("identity", {})

    # What the program already has, so a seed never duplicates an entry.
    man_nodes = manifest_nodes(a.manifest)
    have = {k.upper() for k in man_nodes}
    declared = declared_entries(a.symbols)

    rows, total, seedable, skipped = rank(r, have, declared, a.min_cycles)
    full = list(rows)
    if only or drop:
        rows = [x for x in full
                if (not drop or x[1][0] not in drop)
                and (not only or x[1][0] in only)]

    # --force-pc: an address the ranking does not keep, because the capture never
    # sighted a transfer gap there.  Its cost still comes from the capture's own
    # hot_instructions rows, so the emitted note carries real numbers; what is
    # missing is a gap, and the note says that instead of hiding it.
    forced = []
    for spec in [t.strip() for t in a.force_pc.split(",") if t.strip()]:
        pc_s, _, mx_s = spec.partition(":")
        pc = int(pc_s.lstrip("$"), 16)
        mx = mx_s or "M0X0"
        cyc = sum(x.get("guest_cycles", 0) for x in r["hot_instructions"]
                  if I(x["target_pc24"]) == pc and x["entry_mx"] == mx)
        ins = sum(x.get("interpreted_instructions", 0) for x in r["hot_instructions"]
                  if I(x["target_pc24"]) == pc and x["entry_mx"] == mx)
        hits = sum(d.get("observed_hits", 0) for d in r["discoveries"]
                   if I(d["target_pc24"]) == pc and d["entry_mx"] == mx
                   and d["site_kind"] in GAP_KINDS)
        cov_nodes = sorted(k for k, n in man_nodes.items()
                           if n.get("min_pc24") is not None
                           and n["min_pc24"] <= pc <= n["max_pc24"]
                           and k.split(":")[1] == mx)
        forced.append((cyc, (pc, mx), ins,
                       {"kind": "no-gap-sighting", "hits": hits, "sites": set(),
                        "frames": [None, None], "status": "not sighted at a gap",
                        "probe": True, "covering": cov_nodes}))
    rows = forced + rows
    picked = rows[:a.top]
    if not picked:
        sys.exit("no gap-sighted hot entry survived the filters")

    if a.list:
        for cyc, (pc, mx), ins, g in rows:
            print("$%06X  %s  %11s cyc  %9s insns  %8s gap hits  frames %s..%s%s"
                  % (pc, mx, f"{cyc:,}", f"{ins:,}", f"{g['hits']:,}",
                     fr0(g), fr1(g),
                     ("   probe, already covered by "
                      + ",".join(g.get("covering", ()))) if g.get("probe") else ""))
        # The list is the whole ranking; what --top would actually seed is a fact
        # about the list, so say it here rather than leave the reader to count rows.
        n_p = sum(1 for *_x, g in rows[:a.top] if g.get("probe"))
        cyc_p = sum(c for c, *_x, g in rows[:a.top] if g.get("probe"))
        print("ranked: %d entries (%d dropped: the program already has them, or they "
              "are under --min-cycles), "
              "--top %d seeds the first %d: %s ranked cyc = %.2f%% of the %s cyc "
              "seedable slice, %.2f%% of the %s cyc attributed residue%s"
              % (len(rows), skipped, a.top, len(picked),
                 f"{sum(c for c, *_x in picked):,}",
                 100.0 * sum(c for c, *_x, g in picked if not g.get("probe")) / seedable,
                 f"{seedable:,}",
                 100.0 * sum(c for c, *_x, g in picked if not g.get("probe")) / total,
                 f"{total:,}",
                 "" if not n_p else " ; %d probe row(s) worth %s cyc, outside that "
                                    "seedable slice" % (n_p, f"{cyc_p:,}")),
              file=sys.stderr)
        if a.then:
            compare(a, full, total, seedable)
        sys.exit(0)

    cov = sum(c for c, _k, _i, g in picked if not g.get("probe"))
    probe_c = sum(c for c, _k, _i, g in picked if g.get("probe"))
    n_rank = sum(1 for *_x, g in picked if not g.get("probe"))
    print()
    head = "# --- M2 promotion round %d %s" % (a.round, BLOCK_MARK)
    print(head + " " + "-" * (79 - len(head) - 1))
    print("#")
    print(wrap("Rounds 1-2 seeded from the read trace (tests/frontier_seeds.py), a source "
               "retired at 0.0 %% of reads left. Round 3 measured what the interpreted "
               "residue is instead (evidence/m2_promotion_round3.md): %s of %s attributed "
               "interpreted guest cycles sit at a transfer gap the bridge could hand a body "
               "to, and the other %.2f %% is entered by fall-through, back-edge or resume, "
               "where no seed at any address intercepts it."
               % (f"{seedable:,}", f"{total:,}", 100.0 * (total - seedable) / total)))
    print("#")
    print(wrap("The %d entries below are the top of that ranking as tests/coverage_gaps.py "
               "ranks it, emitted by tests/gap_seeds.py from %s%s, and %d sighted entries "
               "already have an entry at that address and mode, so they are left out. Every "
               "number in a note is the capture's own for that address, not a guess."
               % (len(picked), os.path.basename(a.capture),
                  (" over " + a.route) if a.route else "", skipped)))
    if only or drop:
        print("#")
        print(wrap("This block is a subset of the ranking, emitted with %s: %d of the %d "
                   "kept entries survive it, and they gate %s cyc. The ceiling figures below "
                   "still describe the full ranking."
                   % (" ".join((["--only " + a.only] if only else [])
                               + (["--exclude " + a.exclude] if drop else [])),
                      len(rows), len(full), f"{cov:,}"), indent="#   "))
    probes = [pc for _c, (pc, _mx), _i, g in picked if g.get("probe")]
    if probes:
        print("#")
        print(wrap("Probe entries (%s) are not ranking rows: the capture never sights a "
                   "transfer gap at them, so a `[[func]]` entry there tests whether a root "
                   "makes the program run a body it already compiled, and is not a claim "
                   "that the gap ranking prices that address."
                   % ", ".join("$%06X" % pc for pc in probes), indent="#   "))
    print("#")
    facts = ["capture identity  program_digest %s  generation_digest %s"
                 % (str(ident.get("program_digest"))[:16],
                    str(ident.get("generation_digest"))[:16]),
                 "rom_sha256 %s  mapper %s  captures %s  warnings %s"
                 % (str(ident.get("rom_sha256"))[:16], ident.get("mapper"),
                    r.get("capture_count"), r.get("warnings")),
                 "these %d ranking seeds gate %s cyc = %.2f %% of the residue, %.1f %% of what is "
                 "seedable (top 10 = %.2f %%, top 50 = %.2f %%, all %d kept entries = "
                 "%.2f %%): the knee is at the top of the list, so a round that stops here "
                 "is not leaving money on the table"
                 % (n_rank, f"{cov:,}", 100.0 * cov / total, 100.0 * cov / seedable,
                    100.0 * sum(c for c, *_ in full[:10]) / total,
                    100.0 * sum(c for c, *_ in full[:50]) / total, len(full),
                    100.0 * seedable / total)]
    if probe_c:
        facts.append("the %d probe row(s) here carry %s cyc at their own PCs = %.2f %% of the "
                     "residue, and none of that is inside the %s cyc the gap ranking calls "
                     "seedable"
                     % (len(picked) - n_rank, f"{probe_c:,}", 100.0 * probe_c / total,
                        f"{seedable:,}"))
    for fact in facts:
        print(wrap(fact, indent="#   "))
    print()
    for cyc, (pc, mx), ins, g in picked:
        bank, addr = (pc >> 16) & 0xFF, pc & 0xFFFF
        sites = ",".join("$%06X" % s for s in sorted(g["sites"])[:3])
        fr = g["frames"]
        print("[[func]]")
        print('name = "GS_%06X"' % pc)
        print('addr = "%04X"' % addr)
        print("bank = 0x%02X" % bank)
        print("emit = true")
        if mx != "M1X1":
            print("entry_m = %s" % mx[1])
            print("entry_x = %s" % mx[3])
        if g.get("probe"):
            note = ('note = "round-%d probe seed: %s cyc interp / %s insns at this'
                    ' PC; %d gap hits, i.e. the capture never sees a transfer hand'
                    ' control here, so this entry tests whether a root at a hot'
                    ' address makes the program run the body it already compiled'
                    + ('  already covered by ' + ','.join(g['covering'])
                       if g['covering'] else '  no body covers it')
                    + '; gate %s"' % g['status'])
            print(note % (a.round, f"{cyc:,}", f"{ins:,}", g['hits']))
        else:
            print('note = "round-%d gap seed: %s cyc interp, %s hits via %s at %s;'
                  ' frames %s..%s; gate %s"'
                  % (a.round, f"{cyc:,}", f"{g['hits']:,}",
                     g["kind"].replace("_gap", ""), sites, fr0(g), fr1(g),
                     g["status"]))
        print()


if __name__ == "__main__":
    main()
