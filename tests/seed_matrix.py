#!/usr/bin/env python3
"""Seed matrix: what each gap-seed variant is, and what it did.

Round 4 asks a yes/no question of every entry the round-3 coverage gap said was
seedable: seed it into the entry table, regenerate at the pin, run the same
scripted route, and read what the host did with it.  This script joins the
per-variant logs (tests/out/r4/variant_<name>.out, the redirect of
tests/seed_variant.sh; a leg started as .log is the same text) with the archived
program manifest for that variant and
with the abandon accounting in build-<name>/last_run_report.json, and prints
one table.

The point of printing the manifest next to the run is that the failure mode has
a manifest-level signature.  The control table contains no node at all covering
the dispatch at $80F4F9 (that whole routine only ever runs in the interpreter);
a variant that fails reports an abandon at that address.  Reading the two
together is what separates "this seed is expensive" from "this seed breaks the
run", which neither log shows on its own.

    tests/seed_matrix.py [--dir tests/out/r4] [--site 0x80F4F9] [--json OUT]

Markdown on stdout.  Every number is read from a file; nothing is typed.
"""
import argparse
import bz2
import glob
import json
import os
import re

SEED_RE = re.compile(r"^\s+seed ([0-9A-Fa-f]{6})$")
MAN_RE = re.compile(r"^\s+manifest: (\d+) nodes \((\d+) aot_eligible, (\d+) lle_only\), "
                    r"(\d+) roots, sha256 ([0-9a-f]+)")
EXE_RE = re.compile(r"^\s+exe sha256 ([0-9a-f]+) (\S+)")
RUN_RE = re.compile(r"^\s+gen_sha256=([0-9a-f]+)\s+gen_units=(\d+)\s+gen_functions=(\d+)"
                    r"\s+gen_dispatch=(\d+)\s+framework=([0-9a-f]+).*exe_sha256=([0-9a-f]+)")
EXIT_RE = re.compile(r"^\s+exit=(\d+) wall=(\d+)s\s+(.*)$")
SHARE_RE = re.compile(r"^\s+interp\s+([\d.]+)%\s+aot\s+([\d.]+)%\s+interp_cycles ([\d,]+)"
                      r"\s+cpu_cycles ([\d,]+)\s+master_cycles ([\d,]+)")
ABAN_RE = re.compile(r"^\s+\[unresolved-abandon\] first hit site=\$([0-9A-F]+) frame=(\d+)")
CAPN_RE = re.compile(r"^\s+interp_cap entries:\s+(\d+) last=\$([0-9A-F]+)")


def manifest_for(d, name):
    """The archived program manifest for a variant, or None if it predates the
    archiving step in tests/seed_variant.sh."""
    for cand in (f"manifest_{name}.json.bz2", f"manifest_{name}.json"):
        p = os.path.join(d, cand)
        if os.path.exists(p):
            raw = bz2.open(p, "rb").read() if p.endswith(".bz2") else open(p, "rb").read()
            return p, json.loads(raw)
    return None, None


def cover(man, site):
    """Nodes that include `site` in their pc range, and the node entered at it."""
    if man is None:
        return None, None, None
    covering = [n for n in man["nodes"].values()
                if n["min_pc24"] <= site <= n["max_pc24"]]
    at = [n for n in covering if n["min_pc24"] == site]
    return covering, at, sum(1 for n in covering if n["disposition"] == "aot_eligible")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="tests/out/r4")
    ap.add_argument("--site", type=lambda s: int(s, 16), default=0x80F4F9,
                    help="dispatch address the abandon accounting is read at")
    ap.add_argument("--json", help="also write the joined rows as json")
    a = ap.parse_args()

    rows = []
    # .out is the usual redirect of tests/seed_variant.sh; .log is the same text
    # under the name a leg was started with, so both extensions are a variant log.
    logs = (glob.glob(os.path.join(a.dir, "variant_*.out"))
            + glob.glob(os.path.join(a.dir, "variant_*.log")))
    seen = set()
    for path in sorted(logs):
        name = os.path.basename(path)[len("variant_"):].rsplit(".", 1)[0]
        if name in seen:
            continue
        seen.add(name)
        text = open(path).read()
        r = {"variant": name, "path": path,
             "seeds": [m.group(1).upper() for m in
                       (SEED_RE.match(l) for l in text.splitlines()) if m],
             "report": None, "abandon": None, "manifest_path": None,
             "covering": None, "at_site": None, "cover_aot": None}
        for line in text.splitlines():
            for rx, keys in ((MAN_RE, ("nodes", "aot", "lle", "roots", "manifest_sha")),
                             (EXE_RE, ("exe_sha", "exe_path")),
                             (RUN_RE, ("gen_sha", "gen_units", "gen_functions",
                                       "gen_dispatch", "framework", "exe_sha_run")),
                             (EXIT_RE, ("exit", "wall_s", "exit_line")),
                             (SHARE_RE, ("interp_pct", "aot_pct", "interp_cycles",
                                         "cpu_cycles", "master_cycles")),
                             (ABAN_RE, ("abandon_site", "abandon_frame"))):
                m = rx.match(line)
                if m:
                    r.update(zip(keys, m.groups()))
        # the abandon accounting is always on and post-mortem-dumped, so the
        # report is the authoritative count, not a log grep.
        rep = os.path.join("build-%s" % name, "last_run_report.json")
        if os.path.exists(rep):
            d = json.load(open(rep))
            ab = d.get("unresolved_abandons") or {}
            es = d.get("execution_share") or {}
            r["report"] = {"path": rep, "total_hits": ab.get("total_hits"),
                           "distinct_sites": ab.get("distinct_sites"),
                           "sites": ab.get("sites"),
                           # whatever route left this tree's last report, which
                           # after a tests/parity.sh leg is the probe route
                           "frames": es.get("frame"), "probe_interp": es.get("interp_cycles"),
                           "probe_interp_insns": es.get("interp_insns"),
                           "probe_cpu": es.get("cpu_cycles"),
                           "probe_master": es.get("master_cycles"),
                           "probe_aot_pct": es.get("aot_cycle_pct")}
        # tests/parity.sh compares frame dumps of the probe route against the
        # control tree; that is the only leg that answers "same machine state?".
        par = os.path.join(a.dir, "parity_%s.log" % name)
        if os.path.exists(par):
            text = open(par).read()
            r["parity_path"] = par
            m = re.search(r"identical over (\d+) frames", text)
            if m:
                r["parity"] = "identical over %s frames" % m.group(1)
            else:
                m1 = re.search(r"first divergence at frame_(\d+)", text)
                m2 = re.search(r"(\d+) of (\d+) frames differ", text)
                r["parity"] = ("diverges at frame %s, %s of %s frames differ"
                               % (m1.group(1) if m1 else "?",
                                  m2.group(1) if m2 else "?",
                                  m2.group(2) if m2 else "?"))
        for m in re.finditer(r"^\s+\[cost (\d+)s (\w+)\]$", text, re.M):
            r["cost_" + m.group(2)] = int(m.group(1))
        r["manifest_path"], man = manifest_for(a.dir, name)
        if man is not None:
            cov, at, naot = cover(man, a.site)
            r["covering"] = len(cov)
            r["cover_aot"] = naot
            r["at_site"] = [{"key": "M%dX%d:$%06X" % (n["key"]["m"], n["key"]["x"], n["key"]["pc24"]),
                             "disposition": n["disposition"],
                             "insns": n["instruction_count"],
                             "span": "$%06X-$%06X" % (n["min_pc24"], n["max_pc24"]),
                             "reasons": n.get("reasons"),
                             "demands": [d.get("kind") for d in n.get("demands") or []]}
                            for n in at]
        rows.append(r)

    hdr = ("| variant | seeds added | roots | nodes (aot/lle) | manifest sha256 | exe sha256 "
           "| nodes covering $%06X | node at $%06X | route exit | route first abandon "
           "| route aot %% | probe aot %% | probe state (frame dumps vs control) "
           "| regen+build s |" % (a.site, a.site))
    print("# seed matrix (%s)" % os.path.relpath(a.dir))
    print()
    print("Route = %s (tests/seed_variant.sh); probe = the frame-dump route "
          "tests/parity.sh runs, whose report is the tree's last one." % "tests/scripts/combat.txt")
    print()
    print(hdr)
    print("|" + "---|" * 14)
    for r in rows:
        seeds = " ".join("$" + s for s in r["seeds"]) or "none (control)"
        nodes = ("%s (%s aot / %s lle)" % (r["nodes"], r["aot"], r["lle"])
                 if "nodes" in r else "")
        cov = r["covering"] if r["covering"] is not None else "n/a"
        at = "none"
        if r["at_site"]:
            at = "; ".join("%s, %s insns, %s" % (n["disposition"], n["insns"],
                                                 ",".join(n["demands"]) or "no demand")
                           for n in r["at_site"])
        ab = ("-" if not r.get("abandon_site")
              else "$%s f%s" % (r["abandon_site"], r["abandon_frame"]))
        pab = r["report"]["total_hits"] if (r["report"] and r.get("parity_path")) else ""
        ex = "%s: %s" % (r.get("exit", "?"), r.get("exit_line", "")) if "exit" in r else ""
        cost = sum(v for k, v in r.items() if k.startswith("cost_")) or ""
        # a tree's last_run_report is whatever route ran last in it, so the
        # probe columns are only meaningful after a tests/parity.sh leg.
        probe = r["report"].get("probe_aot_pct", "") if (r["report"] and r.get("parity_path")) else ""
        state = r.get("parity", "")
        if state and pab != "":
            state += " (%s probe abandons)" % pab
        print("| %s | %s | %s | %s | `%s` | `%s` | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["variant"], seeds, r.get("roots", ""), nodes,
            r.get("manifest_sha", ""), r.get("exe_sha_run", r.get("exe_sha", "")),
            cov, at, ex, ab, r.get("aot_pct", ""), probe,
            state, cost))
    print()
    print("Every breaking variant reports its first abandon at $%06X, and every one of" % a.site)
    print("them has a program that *contains* that address; the control's program has no")
    print("node covering it at all, so there it only ever runs in the interpreter.")
    print()
    print("## probe cycle deltas against the control")
    print()
    base = [r for r in rows if not r["seeds"]]
    bref = base[0]["report"] if base and base[0]["report"] else None
    if bref:
        print("| variant | probe frames | interp insns | interp cycles | cpu cycles | master cycles "
              "| d interp cyc | d cpu cyc | d master cyc |")
        print("|" + "---|" * 9)
        for r in rows:
            rep = r["report"]
            if not rep or not r.get("parity_path") or rep["probe_interp"] is None:
                continue
            print("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                r["variant"], rep["frames"], f"{rep['probe_interp_insns']:,}",
                f"{rep['probe_interp']:,}", f"{rep['probe_cpu']:,}", f"{rep['probe_master']:,}",
                f"{rep['probe_interp'] - bref['probe_interp']:+,}",
                f"{rep['probe_cpu'] - bref['probe_cpu']:+,}",
                f"{rep['probe_master'] - bref['probe_master']:+,}"))
    if a.json:
        json.dump(rows, open(a.json, "w"), indent=1)
        print("\njson: %s" % a.json)


if __name__ == "__main__":
    main()
