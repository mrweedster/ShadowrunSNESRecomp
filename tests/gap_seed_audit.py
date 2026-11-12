#!/usr/bin/env python3
"""Audit a round's gap seeds against the program the analyzer actually built.

    gap_seed_audit.py --post-manifest F [--capture F] [--pre-manifest F]
                      [--symbols F] [--top N]

    tests/gap_seed_audit.py --post-manifest tests/out/r4/manifest_r4_full10.json

The capture ranks which (pc,mx) entries are worth seeding and says how many
guest cycles each one gates. That is the interpreter's view of the title. The
answer to "what did declaring them buy" lives in the program manifest the
analyzer wrote: per declared entry it records whether the body shipped
(aot_eligible) or the entry was refused (lle_only), how large the decode was,
which ROM span it covers, and the reasons for a refusal. This tool joins the
two and prints the join, so a round's seed table, what became of it, and the
ceiling the ranking promised all come out of the archived artifacts.

The ranking side calls the same code tests/gap_seeds.py emits from, with the
same drop rule, so the rows here are the rows that went into symbols.toml — and
"the baseline table" is that file minus the blocks gap_seeds.py generated, which
is how tests/seed_variant.sh builds a variant too.

A manifest argument accepts a JSON file, a .bz2/.gz of one, or a .tar.gz of a
generated set (its gen/program_manifest.json member).
"""
import argparse
import hashlib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gap_seeds as gs  # noqa: E402  (same ranking, same drop rule)

FUNC_RE = re.compile(r'\[\[func\]\](.*?)(?=\[\[func\]\]|\Z)', re.S)


def sha(path, n=16):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for blk in iter(lambda: fh.read(1 << 20), b""):
            h.update(blk)
    return h.hexdigest()[:n]


def manifest(path):
    """A program manifest: a JSON file, a compressed one, or a gen tarball."""
    import tarfile
    if path.endswith(".tar.gz"):
        with tarfile.open(path) as tf:
            mem = [m for m in tf.getmembers()
                   if m.name.endswith("program_manifest.json")]
            if len(mem) != 1:
                sys.exit("%s: %d program_manifest.json members" % (path, len(mem)))
            return json.load(tf.extractfile(mem[0]))
    return gs.top_json(path)


def declared(text):
    """The [[func]] entries a seed table declares, as `PC:MxXx` keys."""
    out = set()
    for blk in FUNC_RE.findall(text):
        addr = re.search(r'addr\s*=\s*"([0-9A-Fa-f]+)"', blk)
        bank = re.search(r'bank\s*=\s*0x([0-9A-Fa-f]+)', blk)
        em = re.search(r'entry_m\s*=\s*(\d)', blk)
        ex = re.search(r'entry_x\s*=\s*(\d)', blk)
        if addr and bank:
            mx = "M%sX%s" % (em.group(1) if em else "1",
                             ex.group(1) if ex else "1")
            out.add("%06X:%s" % (int(bank.group(1), 16) << 16
                                 | int(addr.group(1), 16), mx))
    return out


def strip_gap_blocks(text):
    """A seed table without the blocks tests/gap_seeds.py generated.

    The cut itself is gap_seeds.strip_generated(), because that tool owns the
    block marker it writes and is what tests/seed_variant.sh builds a variant's
    table from; matching the marker rather than a round number means a later
    round cannot silently redefine what "before this round" means.
    """
    return gs.strip_generated(text)[0]


def counts(man):
    nodes = man["nodes"]
    aot = sum(1 for n in nodes.values() if n["disposition"] == "aot_eligible")
    lle = sum(1 for n in nodes.values() if n["disposition"] == "lle_only")
    return len(nodes), aot, lle, len(man["roots"])


def span_cost(cap, lo, hi):
    """(pcs, instructions, guest cycles) of the capture's per-PC cost rows whose
    PC falls in the body's own [min_pc24, max_pc24].

    `cost_attribution` in the capture says the rows are attributed by
    "exclusive instruction PC, entry M/X and E; never inferred function
    ownership", so summing them over an address range is the interpreted cost
    that *stops* when a compiled body covering that range runs.  It is a
    different quantity from an entry's `guest_cycles` in `discoveries[]`, which
    counts the cost gated by that entry — the cost of reaching it as well as of
    running it.  Rows are not filtered by entry mode: a PC inside the span is
    covered by the body whichever mode reached it.
    """
    pcs = ins = cyc = 0
    for r in cap.get("hot_instructions", []):
        p = int(r["target_pc24"], 16) if isinstance(r["target_pc24"], str) else r["target_pc24"]
        if lo <= p <= hi:
            pcs += 1
            ins += r.get("interpreted_instructions", 0)
            cyc += r.get("guest_cycles", 0)
    return pcs, ins, cyc


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--post-manifest", required=True,
                    help="the manifest of the build the seeds went into")
    ap.add_argument("--capture",
                    default="evidence/artifacts/tier2_capture_round3_combat.json")
    ap.add_argument("--pre-manifest",
                    default="evidence/artifacts/round4_manifest_pre.json.bz2")
    ap.add_argument("--symbols", default="recomp/symbols.toml",
                    help="the candidate seed table; its gap-seed blocks are "
                         "the entries under audit")
    ap.add_argument("--top", type=int, default=10)
    a = ap.parse_args()

    cap = gs.top_json(a.capture)
    ident = cap.get("identity", {})
    pre, post = manifest(a.pre_manifest), manifest(a.post_manifest)
    cand_text = open(a.symbols).read()
    base_keys = declared(strip_gap_blocks(cand_text))
    seeds = sorted(declared(cand_text) - base_keys)

    # The ranking exactly as tests/gap_seeds.py saw it: filtered against the
    # pre-seed manifest, and dropping only what the baseline table declared.
    rows, total, seedable, dropped = gs.rank(
        cap, {k.upper() for k in pre.get("nodes", {})}, base_keys, 0)

    pn, pa, pl, pr = counts(pre)
    qn, qa, ql, qr = counts(post)
    added = sorted(set(post["nodes"]) - set(pre["nodes"]))
    gone = sorted(set(pre["nodes"]) - set(post["nodes"]))
    changed = [k for k in sorted(set(pre["nodes"]) & set(post["nodes"]))
               if pre["nodes"][k] != post["nodes"][k]]
    add_aot = sum(1 for k in added
                  if post["nodes"][k]["disposition"] == "aot_eligible")
    add_lle = sum(1 for k in added
                  if post["nodes"][k]["disposition"] == "lle_only")

    print("# gap-seed audit")
    print()
    print("capture        %s  sha256 %s" % (os.path.basename(a.capture),
                                            sha(a.capture)))
    print("               program_digest %s  generation_digest %s"
          % (ident.get("program_digest"), ident.get("generation_digest")))
    print("               rom_sha256 %s  mapper %s  captures %s  warnings %s"
          % (str(ident.get("rom_sha256"))[:16], ident.get("mapper"),
             cap.get("capture_count"), cap.get("warnings")))
    print("               interpreted %s insns / %s guest cycles"
          % (f"{cap['interpreted_instructions']:,}",
             f"{cap['interpreted_guest_cycles']:,}"))
    for label, path, man in (("pre ", a.pre_manifest, pre),
                             ("post", a.post_manifest, post)):
        n, ao, le, ro = counts(man)
        print("%s manifest   %s  sha256 %s" % (label, path, sha(path)))
        print("               %d nodes (%d aot_eligible, %d lle_only), "
              "%d roots" % (n, ao, le, ro))
    pre_sha = sha(a.pre_manifest, 16)
    if str(ident.get("program_digest", "")).startswith(pre_sha):
        print("               the pre manifest hashes to the capture's "
              "program_digest:\n               it is the program that made "
              "this capture, not a later one")
    print()
    print("manifest diff  %d -> %d nodes, %d -> %d roots" % (pn, qn, pr, qr))
    print("               +%d nodes (%d aot_eligible, %d lle_only), "
          "-%d removed, %d pre-existing node changed"
          % (len(added), add_aot, add_lle, len(gone), len(changed)))
    print()
    print("ranking        %d kept entries gate %s of %s cyc = %.2f %% of the "
          "residue" % (len(rows), f"{seedable:,}", f"{total:,}",
                       100.0 * seedable / total))
    print("               %d hot-sighted gap entries were not kept (already an "
          "entry at that address and mode)" % dropped)
    for n in dict.fromkeys((a.top, 20, 50, len(rows))):
        cov = sum(c for c, *_ in rows[:n])
        print("               top %-3d = %11s cyc  %.2f %% of the residue, "
              "%.1f %% of what is seedable"
              % (n, f"{cov:,}", 100.0 * cov / total, 100.0 * cov / seedable))
    print()
    print("seeds under audit (%d added over the baseline table, %s)"
          % (len(seeds), a.symbols))
    print("               entry       cyc   %res  hot insns  gap hits  frames"
          "        disposition  body  span                 in-span cyc"
          "     why")
    body_cyc = refus_cyc = 0
    n_body = n_refus = n_none = 0
    span_pcs = span_ins = span_cyc = 0
    for key in seeds:
        node = post["nodes"].get(key)
        disp, cnt, span, why, cyc, ins, g = seek(rows, post, key)
        if disp == "aot":
            n_body += 1
            body_cyc += cyc
        elif disp == "lle_only":
            n_refus += 1
            refus_cyc += cyc
        else:
            n_none += 1
        in_span = ""
        if node and node["disposition"] == "aot_eligible":
            p, i2, c2 = span_cost(cap, node["min_pc24"], node["max_pc24"])
            span_pcs += p
            span_ins += i2
            span_cyc += c2
            in_span = "%11s (%4.2f%%)" % (f"{c2:,}", 100.0 * c2 / total)
        print("               $%s  %11s %5.2f  %9s  %8s  %-12s  %-12s %5s  "
              "%-18s  %18s  %s"
              % (key.replace(":", " "), f"{cyc:,}",
                 100.0 * cyc / total if total else 0.0, f"{ins:,}",
                 f"{g['hits']:,}", "%s..%s" % (gs.fr0(g), gs.fr1(g)),
                 disp, cnt, span, in_span, why))
    tot = body_cyc + refus_cyc
    print()
    print("               entry-gated cycles (the capture's discoveries) are not the same"
          "\n               quantity as cycles spent inside a body's own span:"
          " `hot_instructions`"
          "\n               attributes exclusively per PC, so a body's span says how much"
          " interpreted"
          "\n               cost stops when the body runs.")
    print("               the %d compiled seeds' spans cover %d hot-instruction PCs, %s"
          " insns, %s cyc = %.2f %% of the residue"
          % (n_body, span_pcs, f"{span_ins:,}", f"{span_cyc:,}",
             100.0 * span_cyc / total if total else 0.0))

    # A seed does not only add its own body: the entry it declares pulls in the
    # callees that entry reaches, and those bodies cover interpreted cost too.
    # So the quantity a measured cycle drop has to line up with is the span of
    # every node the seeds added, not just the seeds'.
    added_aot = [post["nodes"][k] for k in added
                 if post["nodes"][k]["disposition"] == "aot_eligible"]
    rng = sorted((n["min_pc24"], n["max_pc24"]) for n in added_aot)
    merged = []
    for lo, hi in rng:
        if merged and lo <= merged[-1][1] + 1:
            merged[-1][1] = max(merged[-1][1], hi)
        else:
            merged.append([lo, hi])
    sum_cyc = sum_cyc_u = sum_ins = 0
    for lo, hi in rng:
        _, i2, c2 = span_cost(cap, lo, hi)
        sum_cyc += c2
        sum_ins += i2
    for lo, hi in merged:
        _, _i2, c2 = span_cost(cap, lo, hi)
        sum_cyc_u += c2
    print("               the %d nodes they added (%d seeds + %d bodies reached"
          " through them) span %d ranges that merge to %d;"
          "\n               their spans carry %s insns, %s cyc counted per range"
          " (sum of overlapping ranges counted twice), %s cyc over the merged"
          " ranges = %.2f %% of the residue"
          % (len(added_aot), n_body, len(added_aot) - n_body, len(rng),
             len(merged), f"{sum_ins:,}", f"{sum_cyc:,}", f"{sum_cyc_u:,}",
             100.0 * sum_cyc_u / total if total else 0.0))
    print()
    print("               of the %s cyc these entries gate: %s cyc (%.1f %%) "
          "reached a body, %s cyc (%.1f %%) stayed lle_only, %d got no node"
          % (f"{tot:,}", f"{body_cyc:,}",
             100.0 * body_cyc / tot if tot else 0.0, f"{refus_cyc:,}",
             100.0 * refus_cyc / tot if tot else 0.0, n_none))
    print("               entry-gated terms only: the analyzer agreed to give a body to"
          " %.2f %%\n               of the residue where the ranking promised %.2f %%"
          % (100.0 * body_cyc / total, 100.0 * tot / total))

    # Two declared entries can decode to one span: the same body under a second
    # name costs a dispatch row and buys no new coverage.
    spans = {}
    for key in seeds:
        node = post["nodes"].get(key)
        if node and node["disposition"] == "aot_eligible":
            spans.setdefault((node["min_pc24"], node["max_pc24"],
                              node["instruction_count"]), []).append(key)
    dup = sorted((k, v) for k, v in spans.items() if len(v) > 1)
    if dup:
        print()
        print("               seeds sharing one decoded span:")
        for (lo, hi, cnt), keys in dup:
            print("                 $%06X-$%06X (%d insns): %s"
                  % (lo, hi, cnt, " ".join(keys)))


def row_for(r):
    cyc, (pc, mx), ins, g = r
    return cyc, ("%06X:%s" % (pc, mx)), ins, g


def seek(rows, post, key):
    """(disposition, body insns, span, reasons, gated cycles, hot insns, gap)."""
    row = next(((c, i, g) for c, k, i, g in (row_for(r) for r in rows)
                if k == key), (0, 0, {"hits": 0, "frames": [None, None]}))
    cyc, ins, g = row
    node = post["nodes"].get(key)
    if node is None:
        return "absent", 0, "", "", cyc, ins, g
    disp = "aot" if node["disposition"] == "aot_eligible" else "lle_only"
    return (disp, node["instruction_count"],
            "$%06X-$%06X" % (node["min_pc24"], node["max_pc24"]),
            ",".join(node["reasons"]), cyc, ins, g)


main()
