#!/usr/bin/env python3
"""Host wall-clock per leg from a tests/aot_charge.sh log, with spread.

    charge_wall.py <charge-log> [leg-prefix ...]

Wall time is what a user feels; the cycle counters are not.  A replicated set of
legs over the same binary gives the noise floor, so the difference between two
binaries is only a result if it clears that spread.  Legs are compared only when
every pin (floor / capture / dump) matches, which the log records per leg.

The guest-cycle counters come from <leg>/last_run_report.json and are exact, so
they are printed next to the wall clock: a change that shows up in cycles but
not in wall time is a change inside the 65816 loop that the host's frame cost
absorbs.  "resolved" means the gap is more than 2x the widest same-binary spread;
a smaller gap is inconclusive, not a result, and exit 1 says so.

A batch whose legs alternate binaries is also read pairwise: each leg is paired
with the control leg it ran next to, which cancels host drift, and the verdict
then needs one sign on every pair and |mean| > 2x the standard error.  A block of
replicates of one binary and a block of the other cannot say that, because
whatever made the machine slower in one block moved both means.
"""
import json
import os
import re
import statistics
import sys

LEG = re.compile(r"^== leg (\S+)\s+(\S+)\s+floor=(\w+) capture=(\w+) dump=(\w)")
EXIT = re.compile(r"^\s+exit=(\d+) wall=([\d.]+)s\s+(.*)$")


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        return 2
    log = sys.argv[1]
    prefixes = sys.argv[2:]
    legs, cur = [], None
    for line in open(log):
        m = LEG.match(line.rstrip())
        if m:
            b = m.group(2).rstrip("/")
            # The leg line names the executable, e.g. build-r4pair/ShadowrunSNESRecomp;
            # every build's binary has the same basename, so the build directory is
            # the identity.
            ident = b if not b.endswith("ShadowrunSNESRecomp") else (
                os.path.basename(os.path.dirname(b)) or b)
            cur = {"leg": m.group(1), "bin": ident, "order": len(legs),
                   "pins": m.group(3) + "/" + m.group(4) + "/" + m.group(5)}
            legs.append(cur)
            continue
        m = EXIT.match(line.rstrip())
        if m and cur and "wall" not in cur:
            cur["exit"], cur["wall"], cur["exitline"] = int(m.group(1)), float(m.group(2)), m.group(3)
            rep = os.path.join("tests", "out", "charge", cur["leg"], "last_run_report.json")
            if os.path.exists(rep):
                sh = json.load(open(rep))["execution_share"]
                cur["interp"] = sh["interp_cycles"]
                cur["cpu"] = sh["cpu_cycles"]
                cur["aot_pct"] = sh["aot_cycle_pct"]
    groups = {}
    for l in legs:
        if "wall" not in l:
            continue
        if prefixes and not l["leg"].startswith(tuple(prefixes)):
            continue
        groups.setdefault((l["bin"], l["pins"]), []).append(l)
    print("# wall clock per binary, from %s" % log)
    print()
    print("Same-binary replicates give the noise floor; a difference between two")
    print("binaries counts only if it clears that spread.")
    print()
    print("| binary | pins | legs | exit | wall s (min / mean / max) | stdev s |"
          " mean wall vs " + ("control" if prefixes else "slowest") +
          " | interp_cycles | delta | aot % |")
    print("|" + "---|" * 10)
    keys = sorted(groups, key=lambda k: -statistics.mean(x["wall"] for x in groups[k]))
    if prefixes:
        # The first prefix names the control group, and every delta and every
        # pairing reads against that, not against whichever group happened to run
        # slowest: a slow host minute moves all the means together.
        keys = sorted(groups, key=lambda k: (
            0 if any(x["leg"].startswith(prefixes[0]) for x in groups[k]) else 1,
            -statistics.mean(x["wall"] for x in groups[k])))
    ref = None
    rc = 0
    for k in keys:
        g = groups[k]
        w = [x["wall"] for x in g]
        mean = statistics.mean(w)
        if ref is None:
            ref = mean
        sd = statistics.stdev(w) if len(w) > 1 else 0.0
        cyc = [x.get("interp") for x in g]
        cyc_s = ""
        if all(c is not None for c in cyc):
            if len(set(cyc)) == 1:
                cyc_s = "{:,}".format(cyc[0])
            else:
                cyc_s = "NOT REPRODUCIBLE: " + ", ".join("{:,}".format(c) for c in cyc)
            ref_c = ref_c if "ref_c" in dir() else None
        delta = ""
        if cyc and cyc[0] is not None:
            if ref_c is None:
                ref_c = cyc[0]
                delta = "-"
            else:
                delta = "%+d cyc (%+.2f %%)" % (cyc[0] - ref_c,
                                                100.0 * (cyc[0] - ref_c) / ref_c)
        aot = g[0].get("aot_pct")
        print("| %s | %s | %d | %s | %.2f / %.2f / %.2f | %.2f | %+.2f s (%+.2f %%) | %s | %s | %s |"
              % (k[0], k[1], len(g), "/".join(str(x["exit"]) for x in g),
                 min(w), mean, max(w), sd, mean - ref, 100 * (mean - ref) / ref,
                 cyc_s, delta, ("%.2f" % aot) if aot is not None else ""))
    if len(keys) > 1:
        spreads = [statistics.stdev([x["wall"] for x in groups[k]])
                   for k in keys if len(groups[k]) > 1]
        floor = 2 * (max(spreads) if spreads else 0.0)
        ctrl = statistics.mean(x["wall"] for x in groups[keys[0]])

        # An interleaved batch (the legs alternate binaries) is a different
        # measurement from a block of replicates: host drift moves both sides
        # equally, so pairing each pair-leg with the control leg it ran next to
        # removes that drift.  The statistic is then the spread of the paired
        # differences, not of the raw legs, and it only reads as a result if the
        # differences point the same way on every replicate.  This is computed
        # first because it decides the exit code: a block-mean difference that is
        # inside the same-binary spread is not a result on its own, but if the
        # paired reading resolves it, the measurement is a result.
        lab = {}
        for k in keys:
            d = {}
            for x in groups[k]:
                p = next((q for q in prefixes if q and x["leg"].startswith(q)), "")
                d[x["leg"][len(p):]] = x["wall"]
            lab[k] = d
        pair = {}
        for k in keys[1:]:
            common = sorted(set(lab[keys[0]]) & set(lab[k]))
            if len(common) < 3:
                continue
            # Pairing is only a pairing if the batch alternates.  A block of one
            # binary and a block of the other would have its differences carry
            # the host drift between the blocks.
            both = sorted(groups[keys[0]] + groups[k], key=lambda y: y["order"])
            ids = [y["bin"] + " " + y["pins"] for y in both]
            run = mx = 1
            for a, b in zip(ids, ids[1:]):
                run = run + 1 if b == a else 1
                mx = max(mx, run)
            if mx > 2:
                pair[k] = ("blocked", mx)
                continue
            diffs = [lab[k][c] - lab[keys[0]][c] for c in common]
            mean = sum(diffs) / len(diffs)
            sd = statistics.stdev(diffs) if len(diffs) > 1 else 0.0
            se = sd / (len(diffs) ** 0.5)
            same = all(d < 0 for d in diffs) or all(d > 0 for d in diffs)
            word = "resolved" if same and abs(mean) > 2 * se else "inconclusive"
            pair[k] = (word, (mean, sd, se, same, common, diffs))

        print()
        print("widest same-binary spread: %.2f s, so a credible wall difference"
              " is more than %.2f s" % (floor / 2, floor))
        for k in keys[1:]:
            if len(groups[k]) < 2 or len(groups[keys[0]]) < 2:
                # A one-leg group carries no noise floor of its own, so its
                # difference is a data point and not a verdict.
                print("not judged    %s vs %s: %.2f s apart, but %s has %d leg(s)"
                      % (k[0], keys[0][0],
                         abs(ctrl - statistics.mean(x["wall"] for x in groups[k])),
                         k[0] if len(groups[k]) < 2 else keys[0][0],
                         min(len(groups[k]), len(groups[keys[0]]))))
                rc = max(rc, 1)
                continue
            d = abs(ctrl - statistics.mean(x["wall"] for x in groups[k]))
            resolved_paired = pair.get(k, ("",))[0] == "resolved"
            if d <= floor:
                print("inconclusive  %s vs %s: %.2f s apart, needs > %.2f s%s"
                      % (k[0], keys[0][0], d, floor,
                         " (the paired reading below resolves it)"
                         if resolved_paired else ""))
                if not resolved_paired:
                    rc = max(rc, 1)
            else:
                print("resolved      %s vs %s: %.2f s apart (> %.2f s)"
                      % (k[0], keys[0][0], d, floor))
        if any(len(groups[k]) == 1 for k in keys):
            print("note: a group with 1 leg has no spread of its own")

        printed = False
        for k in keys[1:]:
            if k not in pair:
                continue
            word, payload = pair[k]
            if word == "blocked":
                print()
                print("not paired      %s vs %s: this log runs the two binaries in blocks "
                      "(longest run of one binary: %d legs), so pairing them would compare "
                      "blocks, not pairs" % (k[0], keys[0][0], payload))
                continue
            if not printed:
                print()
                print("paired by replicate label (interleaved legs cancel host drift):")
                printed = True
            mean, sd, se, same, common, diffs = payload
            print("  %s  %s vs %s over %d pairs: mean %+.2f s (sd %.2f, se %.2f), "
                  "signs %s, needs |mean| > %.2f s and one sign"
                  % (word, k[0], keys[0][0], len(common), mean, sd, se,
                     "consistent" if same else "mixed", 2 * se))
            print("     pairs: " + ", ".join("%s %+.2f" % (c, d)
                                             for c, d in zip(common, diffs)))
            if word == "inconclusive":
                rc = max(rc, 1)
    return rc


if __name__ == "__main__":
    sys.exit(main())
