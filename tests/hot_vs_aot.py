#!/usr/bin/env python3
"""Where the interpreted cost sits relative to the bodies the same program has.

    hot_vs_aot.py <tier2-capture.json> <program_manifest.json[.bz2]>

`tests/coverage_gaps.py` answers how much of the interpreted residue a seed
*could* intercept: cost at a PC that the capture also sighted at a transfer gap
(`call_gap` / `goto_gap`).  That is the only address a `[[func]]` entry can
claim.  This tool asks the other question, which is what a round has to know
before it seeds anything else: for every PC the interpreter executed, does this
same program already hold a compiled body covering it?

The two are joined on (pc24, entry M/X) and on the node's own `min_pc24` /
`max_pc24`.  A node's span never crosses a bank, so a span test runs on the low
16 bits with the bank byte compared separately; LoROM banks $80-$BF mirror
$00-$3F, so a bank that differs only in bit 7 still matches, and every match
made that way is counted in the header.

Classes, most-optimistic first:

  exact-aot     the program has a node at exactly this entry, and it is
                `aot_eligible`: a body exists for this PC.  If the interpreter
                still paid for it, the body was never handed control here.
  exact-lle     a node exists at this entry but is `lle_only`.
  span-aot      no node at this entry, but some `aot_eligible` node's body
                covers this address.
  span-lle      same, covered by an `lle_only` body.
  no-node       nothing compiled covers this address at this mode.

Exit 0 always; this generates text for the round record, it does not gate.
"""
import bz2
import collections
import json
import sys

GAP_KINDS = ("call_gap", "goto_gap")
CLASSES = ("exact-aot", "exact-lle", "span-aot", "span-lle", "no-node")


def I(x):
    return int(x, 16) if isinstance(x, str) else int(x)


def manifest(path):
    raw = open(path, "rb").read()
    if path.endswith(".bz2"):
        raw = bz2.decompress(raw)
    return json.loads(raw)


def spellings(pc):
    seen, out = set(), []
    for p in (pc, pc | 0x800000, pc & 0x7FFFFF):
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def same_bank(a, b):
    """Bank bytes match, or are LoROM mirrors ($80-$BF mirror $00-$3F)."""
    return ((a >> 16) ^ (b >> 16)) & 0xFF in (0x00, 0x80)


def in_span(pc, lo, hi):
    """Is pc inside [lo, hi]?  A node's own span never crosses a bank, so the
    test runs on the low 16 bits with the bank compared separately (mirrors
    allowed)."""
    return same_bank(pc, lo) and (lo & 0xFFFF) <= (pc & 0xFFFF) <= (hi & 0xFFFF)


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip())
        return 2
    cap = json.load(open(sys.argv[1]))
    man = manifest(sys.argv[2])

    by_key = {}
    spans = []
    for k, n in man["nodes"].items():
        entry, mx = k.split(":", 1)
        entry = int(entry, 16)
        by_key.setdefault((entry & 0xFFFF, mx), []).append((entry, k, n))
        lo, hi = n.get("min_pc24"), n.get("max_pc24")
        if lo is not None and hi is not None:
            spans.append((lo, hi, mx, k, n["disposition"]))

    gaps = collections.Counter()
    gap_kinds = {}
    for d in cap.get("discoveries", []):
        if d.get("site_kind") not in GAP_KINDS:
            continue
        key = (I(d["target_pc24"]) & 0xFFFF, d["entry_mx"])
        gaps[key] += d.get("observed_hits", 0)
        gap_kinds[key] = d["site_kind"]

    cost = collections.Counter()
    insns = collections.Counter()
    rows = []
    for row in cap["hot_instructions"]:
        pc, mx = I(row["target_pc24"]), row["entry_mx"]
        c, i2 = row.get("guest_cycles", 0), row.get("interpreted_instructions", 0)
        cost[(pc, mx)] += c
        insns[(pc, mx)] += i2
        rows.append((pc, mx, c, i2, row))

    total = sum(cost.values())
    tot_i = sum(insns.values())

    cls_c = collections.Counter()
    cls_i = collections.Counter()
    cls_n = collections.Counter()
    cls_gap = collections.Counter()
    detail = []
    spell_used = collections.Counter()
    for pc, mx, c, i2, row in rows:
        node = None
        kind = "no-node"
        for entry, k2, n2 in by_key.get((pc & 0xFFFF, mx), ()):
            if same_bank(pc, entry):
                node = (k2, n2)
                kind = ("exact-aot" if n2["disposition"] == "aot_eligible"
                        else "exact-lle")
                if ((pc >> 16) ^ (entry >> 16)) & 0xFF == 0x80:
                    spell_used["mirror"] += 1
                break
        if node is None:
            hit = [s for s in spans if s[2] == mx and in_span(pc, s[0], s[1])]
            if hit:
                aot = [s for s in hit if s[4] == "aot_eligible"]
                s = aot[0] if aot else hit[0]
                node = (s[3], man["nodes"][s[3]])
                kind = ("span-aot" if s[4] == "aot_eligible" else "span-lle")
                if ((pc >> 16) ^ (s[0] >> 16)) & 0xFF == 0x80:
                    spell_used["mirror"] += 1
        cls_c[kind] += c
        cls_i[kind] += i2
        cls_n[kind] += 1
        hits = gaps.get((pc & 0xFFFF, mx), 0)
        cls_gap[kind] += 1 if hits else 0
        detail.append((c, i2, pc, mx, kind, node, hits,
                       gap_kinds.get((pc & 0xFFFF, mx), "")))

    print("# interpreted cost vs the bodies the same program already has")
    print()
    print("capture    %s" % sys.argv[1])
    print("           program_digest %s"
          % cap.get("identity", {}).get("program_digest", "")[:16])
    print("manifest   %s" % sys.argv[2])
    print("           %d nodes (%d aot_eligible, %d lle_only), %d roots"
          % (len(man["nodes"]),
             sum(1 for n in man["nodes"].values()
                 if n["disposition"] == "aot_eligible"),
             sum(1 for n in man["nodes"].values()
                 if n["disposition"] == "lle_only"),
             len(man.get("roots", []))))
    print()
    print("Every hot row of the capture, classified against that manifest: does a")
    print("compiled body cover the PC the interpreter paid for, in the same M/X mode?")
    print("Bank mirror spellings tried as well; %d rows matched only on a mirror."
          % spell_used["mirror"])
    print()
    print("| class | hot PCs | interpreted insns | guest cycles | % of residue | of those PCs, sighted at a transfer gap |")
    print("|" + "---|" * 6)
    for k in CLASSES:
        if not cls_n[k]:
            continue
        print("| %s | %d | %s | %s | %.2f %% | %d |"
              % (k, cls_n[k], f"{cls_i[k]:,}", f"{cls_c[k]:,}",
                 100.0 * cls_c[k] / total if total else 0.0, cls_gap[k]))
    print("| **total** | %d | %s | %s | 100.00 %% | %d |"
          % (sum(cls_n.values()), f"{tot_i:,}", f"{total:,}", sum(cls_gap.values())))
    print()

    print("The hottest 15 PCs in the capture, same join.")
    print()
    print("| PC | M/X | insns | guest cycles | % of residue | class | covering node | body span | gap sighting |")
    print("|" + "---|" * 9)
    for c, i2, pc, mx, kind, node, hits, gk in sorted(detail, key=lambda r: -r[0])[:15]:
        node_s = ""
        if node:
            n = node[1]
            node_s = "%s (%s insns, $%06X-$%06X)" % (
                node[0], n.get("instruction_count"), n["min_pc24"], n["max_pc24"])
        print("| $%06X | %s | %s | %s | %.2f %% | %s | %s | %s | %s |"
              % (pc, mx, f"{i2:,}", f"{c:,}", 100.0 * c / total if total else 0.0,
                 kind, node_s or "-", "",
                 ("%s, %s hits" % (gk, f"{hits:,}")) if hits else "none"))
    print()

    aot_c = cls_c["exact-aot"]
    print("exact-aot cycles (%s, %.2f %% of the residue) sit at an entry the program"
          % (f"{aot_c:,}", 100.0 * aot_c / total if total else 0.0))
    print("already has a compiled body for, and %d of those %d hot PCs have no"
          % (cls_n["exact-aot"] - cls_gap["exact-aot"], cls_n["exact-aot"]))
    print("transfer-gap sighting at all, so no `[[func]]` entry at any address")
    print("intercepts them: the only way in is the interpreter handing control over,")
    print("which is the seam, not the seed table.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
