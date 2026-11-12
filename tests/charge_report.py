#!/usr/bin/env python3
"""Join one tests/aot_charge.sh run into a cycle ledger: flags, then counters.

    tests/charge_report.py tests/out/charge <control-leg> [leg...]

A delta between two hosts' cycle counters is only a measurement when the two
legs ran with the same switches, so the table starts with what each leg was:
the leg's own tests/out/charge/<name>.flags.tsv (binary, exe sha256, floor,
capture, argv) and the host's startup line reporting the execution policy it
resolved.  Only then the counters, and only then the subtraction against the
control leg.

A leg whose scripted route did not reach its end (exit != 0) is kept in the
table and dropped from the deltas: its counters describe a different amount of
route, which is the trap this whole round keeps hitting.
"""
import json
import os
import re
import sys

POLICY_RE = re.compile(r"\[execution_mode\] policy=(\w+) \(default (\w+), from ([^)]*)\)")
EXIT_RE = re.compile(r"exit: .*")


def flags(path):
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path):
        parts = line.rstrip("\n").split("\t")
        # aot_charge.sh writes the switches as one tab-separated key/value run:
        #   floor<TAB>nofloor<TAB>capture<TAB>off<TAB>dump<TAB>0
        # while every other line is "key<TAB>value" (argv / env / binary carry
        # tabs of their own, so those are kept whole).
        if len(parts) >= 4 and parts[0] == "floor":
            for i in range(0, len(parts) - 1, 2):
                out[parts[i]] = parts[i + 1]
        else:
            out[parts[0]] = "\t".join(parts[1:])
    return out


def leg(d, name):
    r = {"leg": name}
    f = flags(os.path.join(d, name + ".flags.tsv"))
    r.update({"binary": f.get("binary"), "exe_sha256": f.get("exe_sha256"),
              "floor": f.get("floor"), "capture": f.get("capture"),
              "dump": f.get("dump"), "argv": f.get("argv"), "script": f.get("script")})
    log = os.path.join(d, name + ".log")
    if os.path.exists(log):
        text = open(log).read()
        m = POLICY_RE.search(text)
        if m:
            r["policy"], r["policy_default"], r["policy_from"] = m.groups()
        exits = EXIT_RE.findall(text)
        r["exit_line"] = exits[-1] if exits else None
    rep = os.path.join(d, name, "last_run_report.json")
    if os.path.exists(rep):
        d_ = json.load(open(rep))
        s = d_.get("execution_share") or {}
        r["report"] = {"path": rep, "status": d_.get("status"), "reason": d_.get("reason"),
                       "frames": s.get("frame"), "interp_insns": s.get("interp_insns"),
                       "interp_cycles": s.get("interp_cycles"), "cpu_cycles": s.get("cpu_cycles"),
                       "master_cycles": s.get("master_cycles"),
                       "interp_pct": s.get("interp_cycle_pct"), "aot_pct": s.get("aot_cycle_pct"),
                       "abandons": (d_.get("unresolved_abandons") or {}).get("total_hits")}
    cov = os.path.join(d, name + "_cov.json")
    if os.path.exists(cov):
        c = json.load(open(cov))
        ident = c.get("identity") or {}
        r["capture_file"] = cov
        r["capture_hits"] = c.get("total_tier_hits")
        r["program_digest"] = (ident.get("program_digest") or "")[:16]
    if r.get("exit_line", "").startswith("exit: script quit"):
        r["comparable"] = True
    else:
        r["comparable"] = False
    return r


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip())
        return 2
    d, ctrl = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or sorted(
        os.path.basename(p)[:-len(".log")] for p in
        __import__("glob").glob(os.path.join(d, "*.log")))
    rows = [leg(d, n) for n in names]
    base = next((r for r in rows if r["leg"] == ctrl), None)
    if base is None:
        print(f"no leg named {ctrl} in {d}")
        return 2

    print("# cycle ledger (%s)" % d)
    print()
    print("Route: %s.  Control leg: %s." % (base.get("script"), ctrl))
    print()
    print("## what each leg was")
    print()
    print("| leg | binary | exe sha256 | floor | capture | policy (from) | capture program |")
    print("|---|---|---|---|---|---|---|")
    for r in rows:
        pol = "%s (%s)" % (r.get("policy"), r.get("policy_from")) if r.get("policy") else ""
        print("| %s | %s | `%s` | %s | %s | %s | `%s` |" % (
            r["leg"], r.get("binary"), (r.get("exe_sha256") or "")[:16],
            r.get("floor"), r.get("capture"), pol, r.get("program_digest", "")))
    print()
    print("## counters")
    print()
    print("| leg | route end | frames | aot % | interp insns | interp cycles "
          "| cpu cycles | master cycles | abandons |")
    print("|" + "---|" * 9)
    for r in rows:
        rep = r.get("report") or {}
        print("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["leg"], r.get("exit_line") or "-", rep.get("frames", ""),
            rep.get("aot_pct", ""), f"{rep['interp_insns']:,}" if rep.get("interp_insns") is not None else "",
            f"{rep['interp_cycles']:,}" if rep.get("interp_cycles") is not None else "",
            f"{rep['cpu_cycles']:,}" if rep.get("cpu_cycles") is not None else "",
            f"{rep['master_cycles']:,}" if rep.get("master_cycles") is not None else "",
            rep.get("abandons", "")))
    print()
    print("## deltas against %s" % ctrl)
    print()
    b = base.get("report") or {}
    print("| leg | d interp insns | d interp cycles | d cpu cycles | d master cycles |")
    print("|" + "---|" * 5)
    for r in rows:
        rep = r.get("report") or {}
        if not r["comparable"]:
            print("| %s | %s |" % (r["leg"], "excluded: route did not reach its end "
                                          "(%s)" % (r.get("exit_line") or "no exit line")))
            continue
        if not rep or not b:
            continue
        print("| %s | %s | %s | %s | %s |" % (
            r["leg"], f"{rep['interp_insns'] - b['interp_insns']:+,}",
            f"{rep['interp_cycles'] - b['interp_cycles']:+,}",
            f"{rep['cpu_cycles'] - b['cpu_cycles']:+,}",
            f"{rep['master_cycles'] - b['master_cycles']:+,}"))
    print()
    print("The interp-cycles delta is work that stopped being interpreted. The")
    print("cpu/master deltas are what it cost or saved overall: a conversion is real")
    print("only if the interp delta is large and the cpu/master delta is not.")
    if "--json" in sys.argv:
        out = os.path.join(d, "charge_ledger.json")
        json.dump(rows, open(out, "w"), indent=1)
        print("\njson: %s" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
