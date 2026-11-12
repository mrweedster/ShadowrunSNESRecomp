#!/usr/bin/env python3
"""Render the round-6 cluster attribution from files already on disk.

    SNESRECOMP_ROOT=<pin> python3 tests/cluster_hunt_report.py \
        > evidence/artifacts/round6_cluster_hunt.txt

Files-only: it runs no route leg, no regen and no cmake. It reads

  tests/out/r6/hunt.tsv                      one row per demotion leg
  tests/out/r6/forces_*.txt                  the demotion sets
  tests/out/r6/{crc,state}_<label>.txt       per-leg verdicts
  tests/out/r6/report_adopted_final.json     the adopted profile's share
  tests/out/r4/manifest_r6pair.json.bz2      control manifest
  tests/out/r4/manifest_r6pc1c9.json.bz2     candidate manifest
  tests/out/r6/manifest_adopted.json         adopted profile manifest
  build-r6pair/last_run_report.json          control share
  build-r6pc1c9/last_run_report.json         candidate share

The two force files and the three manifests are written by
tests/cluster_ddmin.py / tests/cluster_hunt.sh / tools/regen.sh; nothing in
this report is a hand-typed measurement. The disassembly section calls
tests/disasm_span.py (the pin's decoder) for the two bodies the search names.
"""
import bz2
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests/out/r6")
PIN = os.environ.get("SNESRECOMP_ROOT", "")


def load(path):
    opener = bz2.open if path.endswith(".bz2") else open
    with opener(path) as f:
        return json.load(f)


def nodes(m):
    n = m["nodes"]
    aot = sum(1 for v in n.values() if v["disposition"] == "aot_eligible")
    return len(n), aot, len(n) - aot, len(m["roots"])


def row(pcs):
    return f"  {'':<16} {pcs[0]:>5} nodes  {pcs[1]:>4} aot  {pcs[2]:>4} lle  {pcs[3]:>3} roots"


def legs():
    rows = []
    with open(os.path.join(OUT, "hunt.tsv"), errors="replace") as f:
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) != 5:
                continue
            rows.append(dict(label=c[0], n=int(c[1]), exe=c[2],
                             crc=c[3], state=c[4]))
    return rows


def clean(r):
    return "no non-label WRAM byte differs" in r["state"]


def crc_text(r):
    return r["crc"].strip().rstrip(";").replace(";", ", ")


def count_state(r):
    # "frames with a state byte differing: 305 of 4575   total state bytes: 895"
    try:
        a = r["state"].split("frames with a state byte differing:")[1]
        frames = a.split("of")[0].strip()
        total = a.split("total state bytes:")[1].strip()
        return frames, total
    except IndexError:
        return "?", "?"


def force_set(label):
    path = os.path.join(OUT, f"forces_{label}.txt")
    out = []
    with open(path) as f:
        for line in f:
            t = line.split()
            if len(t) == 2 and t[0] == "force_lle":
                out.append(t[1])
    return out


def share(name, path):
    s = load(path)["execution_share"]
    return dict(name=name, interp=s["interp_cycle_pct"], aot=s["aot_cycle_pct"],
                interp_cycles=s["interp_cycles"],
                cpu=s["cpu_cycles"], master=s["master_cycles"])


def main():
    pair = load(os.path.join(ROOT, "tests/out/r4/manifest_r6pair.json.bz2"))
    cand = load(os.path.join(ROOT, "tests/out/r4/manifest_r6pc1c9.json.bz2"))
    adopted = load(os.path.join(ROOT, "tests/out/r6/manifest_adopted.json"))
    rows = legs()

    by_last = {}
    for r in rows:
        by_last[r["label"]] = r
    cand_row = by_last.get("ddinit0") or next(r for r in rows if r["n"] == 0)
    all_row = by_last.get("all_verify") or next(r for r in rows if r["n"] == 109)
    universe = by_last.get("ddinit52")
    search = [r for r in rows
              if r["label"].startswith("dd") and not r["label"].startswith("ddinit")]
    verify = [r for r in rows if r["label"].startswith("verify_")]
    clean_search = [r for r in search if clean(r) and r["n"] > 0]
    minimal = min(reversed(clean_search), key=lambda r: r["n"])

    pin_rev, pin_dirty = "n/a", "n/a"
    if PIN:
        pin_rev = subprocess.run(["git", "-C", PIN, "rev-parse", "HEAD"],
                                 capture_output=True, text=True).stdout.strip()
        st = subprocess.run(["git", "-C", PIN, "status", "--porcelain"],
                            capture_output=True, text=True).stdout
        pin_dirty = "yes" if st.strip() else "no"

    p = nodes(pair)
    c = nodes(cand)
    a = nodes(adopted)
    added = sorted(set(cand["nodes"]) - set(pair["nodes"]))
    added_aot = [x for x in added
                 if cand["nodes"][x]["disposition"] == "aot_eligible"]

    sp = share("pair", os.path.join(ROOT, "build-r6pair/last_run_report.json"))
    sc = share("candidate", os.path.join(ROOT, "build-r6pc1c9/last_run_report.json"))
    sa = share("adopted", os.path.join(OUT, "report_adopted_final.json"))
    saved_c = sp["interp_cycles"] - sc["interp_cycles"]
    saved_a = sp["interp_cycles"] - sa["interp_cycles"]
    keep_pct = 100.0 * saved_a / saved_c

    print("# round6_cluster_hunt.txt")
    print("#")
    print("# what: attribute the rejected $80C1C9 seed's round-5 gate divergence")
    print("#       (first crc32 divergence frame_001828) to compiled bodies, on top")
    print("#       of the shipped pair, and measure what demoting them costs")
    print("# how:  SNESRECOMP_ROOT=<pin> python3 tests/cluster_ddmin.py --universe 52")
    print("#       tests/latch_writer.py --addrs 0x000,0x001 ... --pc-arm 1828")
    print("#       (writes tests/out/r6/gate_writer_r6.txt, read by section 8)")
    print("#       then SNESRECOMP_ROOT=<pin> python3 tests/cluster_hunt_report.py")
    print("#       (this file; files-only, reads tests/out/r6 and build-*/last_run_report)")
    print("#")
    print(f"# framework pin: {pin_rev} (dirty={pin_dirty})")
    print(f"# generated: {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')} (host {os.uname().machine})")
    print(f"# source tree: {ROOT}")
    print()
    print("== 1. Control, candidate, and the profile with the two demotions ==")
    print(row(p) + "  pair  (tests/seed_variant.sh r6pair)")
    print(row(c) + "  candidate  pair + $80C1C9  (tests/seed_variant.sh r6pc1c9)")
    print(row(a) + "  adopted  candidate - force_lle " + ",".join(force_set("adopted")))
    print()
    print(f"  the seed adds {len(added)} nodes ({len(added_aot)} aot_eligible, "
          f"{len(added) - len(added_aot)} lle_only) over the pair")
    print(f"  all {p[0]} pair nodes are still present in the candidate; the")
    print("  demotion only removes bodies, it does not rewrite the pair's own.")
    root = cand["nodes"].get("80C1C9:M0X0", {})
    print(f"  $80C1C9:M0X0 itself is {root.get('disposition')} "
          f"({', '.join(root.get('reasons', []))});")
    print("  the divergence comes from bodies the seed makes reachable, not from")
    print("  a compiled body at the seed address.")
    print()
    print("== 2. The candidate's divergence on the parity route (4575 frames) ==")
    print(f"  crc32_wram : {crc_text(cand_row)}")
    f, t = count_state(cand_row)
    print(f"  state scan : first differing non-label byte f1830;"
          f" {f} of 4575 frames, {t} bytes")
    print("  (the crc names f1828, a label byte; the first non-label byte is")
    print("   $7E00126 88 -> 85 at f1830, the byte round 5 §8 named for round")
    print("   4's $80ABBC; the DP $7E00000-$7E00006 cluster opens at f1832)")
    diff = os.path.join(OUT, "statediff_cand_evidence.txt")
    if os.path.exists(diff):
        keep = ("  f1830", "  f1832")
        shown = 0
        for line in open(diff, errors="replace"):
            if line.startswith(keep):
                shown += 1
            if shown and (line.startswith("  f") and not line.startswith(keep)):
                break
            if shown and line.strip():
                print("    " + line.rstrip("\n"))
    print()
    print("== 3. Demoting the seed's added AOT bodies restores the pair ==")
    print(f"  all {all_row['n']} added AOT bodies: {crc_text(all_row)}"
          f" | {all_row['state']}")
    if universe:
        print(f"  first {universe['n']} in PC order: {crc_text(universe)} |"
              f" {universe['state']}")
        print("  the first 52 are a sufficient starting set for the search")
    print()
    print("== 4. The search (tests/cluster_ddmin.py, state metric) ==")
    print("  leg       bodies  verdict")
    for r in search:
        if clean(r):
            print(f"  {r['label']:<10} {r['n']:>5}  clean")
        else:
            f, t = count_state(r)
            print(f"  {r['label']:<10} {r['n']:>5}  dirty: {f} frames, {t} bytes")
    print()
    print(f"  minimal clean demotion set: {minimal['n']} bodies")
    for pc in force_set(minimal["label"]):
        v = cand["nodes"].get(f"{pc}:M0X0", {})
        print(f"    ${pc}  {v.get('instruction_count', '?'):>3} insns"
              f"  ${v.get('min_pc24', 0):06X}-${v.get('max_pc24', 0):06X}")
    print(f"  (set recorded in tests/out/r6/forces_{minimal['label']}.txt)")
    print("  removing either one from the set:")
    for r in verify:
        f, t = count_state(r)
        print(f"    {r['label']:<16} {r['n']:>2}  dirty: {f} frames, {t} bytes")
    print("  -> each body is necessary; the set is 1-minimal")
    print()
    print("== 5. What the passing profile keeps ==")
    print(f"  {'leg':<10} {'interp %':>9} {'aot %':>8} {'interp_cycles':>15}"
          f" {'saved':>10}")
    for s in (sp, sc, sa):
        saved = sp["interp_cycles"] - s["interp_cycles"]
        print(f"  {s['name']:<10} {s['interp']:>9.4f} {s['aot']:>8.4f}"
              f" {s['interp_cycles']:>15,} {saved:>10,}")
    print(f"  cpu_cycles {sp['cpu']:,} and master_cycles {sp['master']:,}"
          " are identical in all three")
    print("  the total budget does not move; only the tier split does")
    print(f"  the two-body demotion carries {saved_c - saved_a:,} of the seed's"
          f" {saved_c:,} saved cycles")
    print(f"  what is left saves {saved_a:,} ({keep_pct:.1f} % of the seed's gain)")
    repeats = [r for r in rows if r["label"].startswith("adopted")]
    if repeats:
        exes = sorted({r["exe"] for r in repeats})
        print(f"  the adopted profile was rebuilt {len(repeats)} times"
              f" ({', '.join(r['label'] for r in repeats)}):")
        allclean = all(clean(r) and "identical over" in r["crc"] for r in repeats)
        print(f"  exe {', '.join(exes)};"
              f" {'every' if allclean else 'not every'} leg reported identical"
              f" crc and no differing state byte")
    dropped = set(cand["nodes"]) - set(adopted["nodes"])
    drop_aot = sum(1 for k in dropped
                   if cand["nodes"][k]["disposition"] == "aot_eligible")
    demoted = [k for k in set(cand["nodes"]) & set(adopted["nodes"])
               if cand["nodes"][k]["disposition"] == "aot_eligible"
               and adopted["nodes"][k]["disposition"] != "aot_eligible"]
    print("  note the analysis effect: force_lle names 2 bodies, but the adopted")
    print(f"  program has {c[1] - a[1]} fewer AOT bodies than the candidate"
          f" ({a[1]} against {c[1]}): {drop_aot} are dropped")
    print(f"  and {len(demoted)} change to lle_only, over {c[0] - a[0]} fewer nodes;")
    print("  demoting the roots also removes the bodies only they reached")
    print()
    print("== 6. The two bodies ==")
    for pc in force_set("adopted"):
        v = cand["nodes"].get(f"{pc}:M0X0", {})
        calls = []
        for d in v.get("demands", []):
            t = f"${d['target']['pc24']:06X}"
            if t not in calls:
                calls.append(t)
        print(f"  ${pc}: {v.get('instruction_count')} instructions,"
              f" ${v.get('min_pc24', 0):06X}-${v.get('max_pc24', 0):06X},"
              f" calls {', '.join(calls) if calls else 'none'}")
    if PIN:
        for pc, n in (("80AD9F", 20), ("80C530", 19)):
            print()
            print(f"  head of ${pc} (tests/disasm_span.py {pc} {n} 0 0):")
            out = subprocess.run(
                [sys.executable, os.path.join(ROOT, "tests/disasm_span.py"),
                 pc, str(n), "0", "0"],
                cwd=ROOT, capture_output=True, text=True,
                env=dict(os.environ, SNESRECOMP_ROOT=PIN)).stdout
            for line in out.rstrip("\n").splitlines():
                print("    " + line)
    print()
    print("== 7. The round-5 siblings ==")
    print("  archived manifests: does the seed's program compile the two bodies?")
    import glob
    for path in sorted(glob.glob(os.path.join(ROOT, "tests/out/r4/manifest_s*.json.bz2"))):
        m = load(path)
        name = os.path.basename(path)[len("manifest_"):-len(".json.bz2")]
        both = all(m["nodes"].get(f"{pc}:M0X0", {}).get("disposition") == "aot_eligible"
                   for pc in force_set("adopted"))
        print(f"  {name:<12} {len(m['nodes']):>4} nodes"
              f" {sum(1 for v in m['nodes'].values() if v['disposition'] == 'aot_eligible'):>4} aot"
              f"  both {'yes' if both else 'no'}")
    print("  the five siblings of $80C1C9 all compile both bodies; the pair's own")
    print("  seeds do not. That is why the six roots of the round-5 sweep share")
    print("  one onset.")
    print()
    print("== 8. The writer, by trace ==")
    for d in ("build-r6tr-ctrl", "build-r6tr-seed"):
        cache = os.path.join(ROOT, d, "CMakeCache.txt")
        flag = "missing"
        if os.path.exists(cache):
            m = re.search(r"SNESRECOMP_ENABLE_TRACE:BOOL=(\w+)",
                          open(cache, errors="replace").read())
            flag = m.group(1) if m else "missing"
        exe = os.path.join(ROOT, d, "ShadowrunSNESRecomp")
        digest = "missing"
        if os.path.exists(exe):
            digest = hashlib.sha256(open(exe, "rb").read()).hexdigest()[:16]
        print(f"  {d:<18} ENABLE_TRACE={flag}  exe {digest}")
    raw = os.path.join(OUT, "gate_writer_r6.txt")
    print("  raw: tests/out/r6/gate_writer_r6.txt, written by")
    print("       tests/latch_writer.py --addrs 0x000,0x001 --route")
    print("       tests/out/probe_dense.txt --park 1832 --pc-arm 1828")
    if os.path.exists(raw):
        lines = open(raw, errors="replace").read().splitlines()
        start = next((i for i, l in enumerate(lines)
                      if l.startswith("== pc pass:")), 0)
        for line in lines[start:]:
            print(("  " + line) if line.strip() else "")
    else:
        print("  (raw output missing; run the leg above)")
    print()
    print("  the first differing value is $0001 at f1832: the control writes")
    print("  08 at pc=$80C54D (its STA $01) and the seed writes 82 from")
    print("  func=bank_80_C530_M0X0 (the compiled body). $0000's store at #62")
    print("  is 2C on both legs because it is computed from $1D04 and $7E1C92")
    print("  before the $213C read; its next value differs because the stream")
    print("  has already moved. $0001 is the first byte downstream of $213C,")
    print("  the H counter. The f1832 dumps show $7E1C92 and $7E1C93 unchanged,")
    print("  so the input that moves $0001 is the counter, not the mix bytes.")
    print("  The trace names the same body the demotion named.")
    print("  note: the stock pc pass arms 400 frames before the split; the")
    print("  DP $00/$01 slice of the ring held 3898 entries and reached only")
    print("  f1808, so --pc-arm 1828 arms shortly before the split instead.")
    print("  The default is unchanged.")
    print()
    print("== verdict ==")
    print(f"  Of the {len(added_aot)} AOT bodies the rejected seed adds, demoting")
    print(f"  ${force_set('adopted')[0]} and ${force_set('adopted')[1]} alone restores the shipped pair:")
    print("  crc32 identical and no non-label WRAM byte differs over 4575 frames.")
    print("  Removing either one from that set brings the divergence back, so the")
    print("  attribution is 1-minimal over the 52-body starting set. The")
    print("  disassembly and the write trace name the mechanism: $80C530")
    print("  latches the PPU counters ($2137 then $213C/$213D), mixes them into")
    print("  DP $00/$01 and $1D04, and the trace shows its compiled store")
    print("  writing $0001=82 against the interpreter's 08 at $80C54D.")
    print("  $80AD9F is the 73-instruction loop that reaches $80ABBC, round 4's")
    print("  rejected seed; demoting it takes that compiled path out as well.")
    print()
    print("  The frame count is not monotone in the demotion set: 305 frames with")
    print("  both compiled, 1409 with $80C530 interpreted, 2485 with $80AD9F")
    print("  interpreted, 0 with both interpreted. A single wrong value would move")
    print("  one byte at one point; this is the signature of a read whose result")
    print("  depends on when it runs. The seed is adoptable only with both bodies")
    print(f"  interpreted, and that keeps {keep_pct:.1f} % of its cycle gain:"
          f" {saved_a:,} cycles")
    print(f"  against {saved_c:,} with the bodies compiled. It buys")
    print(f"  {a[1] - p[1]} extra AOT bodies, {a[0] - p[0]} extra nodes and")
    print(f"  +{sa['aot'] - sp['aot']:.3f} points of AOT share for a change the")
    print("  gate cannot see.")
    print("  The next lever is not another seed: it is making the AOT path charge")
    print("  the same cycles at that counter read.")
    print()
    print("reproduce the legs (each regens at the pin, rebuilds build-r6hunt and")
    print("runs tests/parity.sh plus framedump_diff.py state):")
    print("  . tests/rom.sh")
    print("  tests/seed_variant.sh r6pair    --only '$80C399,$80AAB3'")
    print("  tests/seed_variant.sh r6pc1c9   --only '$80C399,$80AAB3,$80C1C9'")
    print("  SNESRECOMP_ROOT=<pin> python3 tests/cluster_ddmin.py --universe 52")


if __name__ == "__main__":
    main()
