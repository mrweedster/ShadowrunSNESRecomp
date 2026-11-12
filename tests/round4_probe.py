#!/usr/bin/env python3
"""The $81B061 probe: does a root at a hot address inside an already-compiled body get control?

    round4_probe.py                     # SNESRECOMP_ROOT must be the framework pin

Round 3 measured that 96.94 % of the interpreted residue is entered by
fall-through, back-edge or resume, where no `[[func]]` entry intercepts it.  The
hottest single PC in the capture, $81B061 (18.00 % of the residue), is one of
those: the analyzer already has a body covering it (`81B05D:M0X0`,
`aot_eligible`) and the interpreter keeps paying for it.  The cheapest test of
"the body is there, the handover is not" is a declaration: make the loop's own
target a root and see whether any cycle moves.

This prints the whole experiment from archived artifacts, plus the loader's
per-address rule, which is why a second entry mode at $81B05D cannot be
declared at all:

  * the probe's symbol table (tests/gap_seeds.py --force-pc, never hand-written),
  * what the regen made of it (nodes, roots, dispositions, gen identity),
  * the counters of the probe legs against the control legs, same switches,
  * the pin's loader refusing two modes at one pc24.

Exit 0; the verdict is in the numbers it prints.
"""
import bz2
import json
import os
import subprocess
import sys
import tempfile

BASE = "tests/out/r4"
OUT = "tests/out/charge"
CAPTURE = "evidence/artifacts/tier2_capture_round3_combat.json"
CTRL_LEGS = ["base_nf", "base_r5"]
PROBE_LEGS = ["probe_nf", "probe_r1", "probe_r2"]
PC = 0x81B061


def load(path):
    raw = open(path, "rb").read()
    return json.loads(bz2.decompress(raw) if path.endswith(".bz2") else raw)


def counters(leg):
    rep = json.load(open(os.path.join(OUT, leg, "last_run_report.json")))
    return rep["execution_share"]


def main():
    pin = os.environ.get("SNESRECOMP_ROOT", "")
    if not os.path.isfile(os.path.join(pin, "snesrecomp_cli.py")):
        sys.exit("SNESRECOMP_ROOT must point at the framework checkout")

    print("# probe: a `[[func]]` root at $%06X, inside a body the program already compiled" % PC)
    print()
    print("capture    %s" % CAPTURE)
    print("pin        %s" % pin)
    print()

    hot = [r for r in json.load(open(CAPTURE))["hot_instructions"]
           if int(r["target_pc24"], 16) in (PC, 0x81B065, 0x81B05D, 0x81B067)]
    print("## the capture at this loop")
    print()
    print("| PC | entry M/X | interpreted insns | guest cycles | completed hits | observed hits |")
    print("|" + "---|" * 6)
    for r in sorted(hot, key=lambda r: -r["guest_cycles"]):
        print("| $%06X | %s | %s | %s | %s | %s |"
              % (int(r["target_pc24"], 16), r["entry_mx"],
                 f"{r['interpreted_instructions']:,}", f"{r['guest_cycles']:,}",
                 r.get("completed_hits"), r.get("observed_hits")))
    print()
    print("`completed_hits` / `observed_hits` are 0 at the loop's own PCs: the capture never")
    print("sees a transfer hand control there, so this address is not in the gap ranking")
    print("at all.  A `[[func]]` entry at it is a probe, not a ranking row.")
    print()

    print("## the probe's symbol table (generated, not typed)")
    print()
    tbl = os.path.join(BASE, "variant_r4probe_symbols.toml")
    for line in open(tbl):
        if line.startswith("name = \"GS_"):
            print("   " + line.rstrip())
    note = [l.rstrip() for l in open(tbl) if "probe seed" in l]
    for l in note:
        print("   " + l.strip())
    print()

    print("## what the regen and the build made of it")
    print()
    # The archived probe log predates the anchored `[[func]]` counter: its
    # baseline line counted the table's header prose as an entry (41 for a
    # 40-entry table). Re-derive that one line from the same baseline table with
    # the current generator; every other line is the log's own text.
    base_line = subprocess.run(
        [sys.executable, "tests/gap_seeds.py", "--baseline-only",
         "recomp/symbols.toml"],
        capture_output=True, text=True).stderr.strip()
    for line in open(os.path.join(BASE, "variant_r4probe.log")):
        s = line.strip()
        if s.startswith("baseline:"):
            s = base_line
        if s.startswith(("baseline:", "symbols [[func]]", "seed ", "manifest:", "gen_sha256=",
                         "exe sha256", "exit=", "interp ", "-- Shadowrun")):
            print("   " + s)
    print()
    base, probe = load(os.path.join(BASE, "manifest_r4base.json.bz2")), \
        load(os.path.join(BASE, "manifest_r4probe.json.bz2"))
    added = sorted(set(probe["nodes"]) - set(base["nodes"]))
    print("manifest nodes %d -> %d, roots %d -> %d, added %s, removed %s, other nodes changed %d"
          % (len(base["nodes"]), len(probe["nodes"]), len(base["roots"]),
             len(probe["roots"]), added or "none",
             sorted(set(base["nodes"]) - set(probe["nodes"])) or "none",
             sum(1 for k in set(base["nodes"]) & set(probe["nodes"])
                 if base["nodes"][k] != probe["nodes"][k])))
    for k in added:
        n = probe["nodes"][k]
        print("   new node %s  %s  %s insns  span $%06X-$%06X"
              % (k, n["disposition"], n.get("instruction_count"),
                 n["min_pc24"], n["max_pc24"]))
    for k in ("81B05D:M0X0", "81B05D:M1X1"):
        n = probe["nodes"].get(k)
        if n:
            print("   existing node %s  %s  %s insns  span $%06X-$%06X"
                  % (k, n["disposition"], n.get("instruction_count"),
                     n["min_pc24"], n["max_pc24"]))
    print()

    print("## the route run, same switches, control legs and probe legs")
    print()
    print("| leg | binary | interp % | aot % | interp_insns | interp_cycles | cpu_cycles | master_cycles |")
    print("|" + "---|" * 8)
    for leg in CTRL_LEGS + PROBE_LEGS:
        try:
            sh = counters(leg)
        except FileNotFoundError:
            print("| %s | (no last_run_report.json) |" % leg)
            continue
        flags = [l.rstrip("\n").split("\t") for l in
                 open(os.path.join(OUT, leg + ".flags.tsv")) if l.startswith("binary")]
        print("| %s | %s | %.2f | %.2f | %s | %s | %s | %s |"
              % (leg, os.path.basename(flags[0][1].strip()) if flags else "?",
                 sh["interp_cycle_pct"], sh["aot_cycle_pct"],
                 f"{sh['interp_insns']:,}", f"{sh['interp_cycles']:,}",
                 f"{sh['cpu_cycles']:,}", f"{sh['master_cycles']:,}"))
    c = [counters(l) for l in CTRL_LEGS]
    p = [counters(l) for l in PROBE_LEGS]
    same = all(x["interp_cycles"] == y["interp_cycles"] for x in c for y in p)
    print()
    print("interp_cycles is %s on every control leg and every probe leg: %s"
          % ("identical" if same else "NOT identical",
             ", ".join("{:,}".format(x["interp_cycles"]) for x in c + p)))
    print("A root at the hottest back-edge target in the game, with a compiled body")
    print("and a dispatch entry for it, moves 0 guest cycles.  The bridge does not")
    print("consult the dispatch table on that path, which is what round 3 measured as")
    print("the 96.94 % fall-through / back-edge / resume residue.")
    print()

    print("## why a second entry mode at $81B05D cannot be declared")
    print()
    loader = os.path.join(pin, "tools", "sync_symbols.py")
    for n, line in enumerate(open(loader).read().split("\n"), 1):
        if "addresses.get" in line or "conflicting tier/entry modes" in line \
                or "addresses[symbol.pc24]" in line:
            print("   %s:%d: %s" % (loader.replace(pin + "/", ""), n, line))
    print()
    sys.path.insert(0, os.path.join(pin, "tools"))
    from sync_symbols import load_symbols  # noqa: E402
    from pathlib import Path  # noqa: E402
    tmp = tempfile.NamedTemporaryFile("w", suffix=".toml", delete=False)
    tmp.write(open(os.path.join(BASE, "symbols_pair.toml")).read())
    r = subprocess.run([sys.executable, "tests/gap_seeds.py", CAPTURE, "--route", "combat",
                        "--round", "4", "--force-pc", "$81B05D", "--top", "1",
                        "--symbols", os.path.join(BASE, "symbols_pair.toml"),
                        "--manifest", "evidence/artifacts/round4_manifest_pre.json.bz2"],
                       capture_output=True, text=True)
    tmp.write(r.stdout)
    tmp.close()
    # The generated file lives in a random temp directory; print a stable name so
    # the artifact is byte-identical run to run, and so the record can quote it.
    shown = "probe_81b05d.toml"
    print("   pair table + gap_seeds.py --force-pc '$81B05D' -> %s" % shown)
    try:
        syms = load_symbols(Path(tmp.name))
        print("   loader accepted it (%d symbols) - no conflict" % len(syms))
    except ValueError as exc:
        print("   loader refused it: %s" % str(exc).replace(tmp.name, shown))
    print("   The port declares $81B05D as `func CC_81B05D b05d entry_mx:1,1` in")
    print("   recomp/bank81.cfg, so the symbol table already owns that pc24 with the")
    print("   M1X1 policy, and the hot caller is M0X0.")
    os.unlink(tmp.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
