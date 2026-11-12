#!/usr/bin/env python3
"""Runtime promotion worklist: the (pc, mode) pairs the machine asks for and does not find.

The two static seed sources closed in promotion round 2 (evidence/m2_promotion_round2.md):
the read-trace frontier was already empty and the refusal-callee seeds produced four bodies
that never dispatch. What is left is a runtime signal, and the framework names it in
runner/src/cpu_state.c: the indirect-dispatch ring records (pc24, source_pc24, func, mx_idx,
found, mirror, frame) for every dispatch, and its own comment says *"`found:0` entries name
targets with no exact AOT body ... the promotion worklist"*. This script runs a diagnostic
build, reads that ring, ranks the misses, and joins them against a program_manifest.json so
each miss says which lever applies:

    tests/dispatch_worklist.py                                  # combat.txt, ./build-dh
    tests/dispatch_worklist.py --script tests/scripts/selfcheck.txt
    tests/dispatch_worklist.py --binary ./build-dht/ShadowrunSNESRecomp --tcp
    tests/dispatch_worklist.py --json evidence/artifacts/dispatch_worklist_combat.json

Three properties of the instrument, all of them the framework's, not this script's, and all
of them printed in the report:

  * The ring needs a diagnostic build. The event ring is compiled out unless the tree was
    configured -DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON (runner/runner.cmake), and a
    production report answers {"disabled": true}. This script refuses a tree without it.

  * Two readouts, different reach. At exit the binary writes the ring into
    <anchor>/last_run_report.json — that works in any tree with the flag on, and it is a
    tail of DISPATCH_LOG_CAP = 1024 events. The debug server's `dispatch_log_get` and
    `interp_stats` are the only live readout, and they need SNESRECOMP_TRACE (configure
    -DSNESRECOMP_ENABLE_TRACE=ON): without it debug_server_init is a no-op stub and the
    binary has no TCP port at all. The always-on found1/found0 tallies — the whole-run
    dispatch hit/miss rate, which the ring cannot give you — are readable *only* over TCP,
    so a trace-off tree answers the addresses but never the rate. --tcp says which happened.

  * The ring only sees *dispatches*. Dispatch happens at RTS/RTL trampolines and at
    runtime-pointer JSR (abs,X), not at branch targets, so a loop the interpreter enters by
    a branch never appears here at all. Absence of misses is not coverage; read the result
    with the mode histogram, which is exactly the round-2 question (four new bodies, zero
    dispatch change) come back with an instrument.

The join classifies each (pc, mode) miss:

    ADD MODE      a body exists for that address in another (m,x)  -> entry_mx_at <pc16> <m> <x>
    ADD SEED      no node for that address at all                  -> [[func]] in symbols.toml
    REFUSED       a node exists and the analyzer says lle_only      -> a seed cannot help
    PRESENT-NULL  the manifest HAS that exact (pc, m, x) yet the runtime found no entry ->
                  do not seed; the row is present and its slot is NULL

Round-2 lesson applied: a demand the analyzer resolves `lle_exact` cannot be converted by
seeding (5 of the 20 round-2 callee names were of that shape, into memory the LoROM mapping
does not back), so those are listed as refused, not proposed.
"""

import argparse
import collections
import json
import os
import re
import socket
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
BUNDLE = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import provenance as P  # noqa: E402

MODE_NAMES = {0: "m0x0", 1: "m0x1", 2: "m1x0", 3: "m1x1"}
RING_CAP = 1024                                           # cpu_state.c DISPATCH_LOG_CAP
CMD_CAP = 128          # dispatch_log_get says 256; its reply buffer truncates near 180
MX_IDX = lambda m, x: ((m & 1) << 1) | (x & 1)            # cpu_state.c's slot index


def as_int(v):
    return int(v, 16) if isinstance(v, str) else int(v)


def history_enabled(tree):
    """True/False from a build tree's configure flag; None when it cannot be read."""
    if not tree:
        return None
    try:
        with open(os.path.join(tree, "CMakeCache.txt"), encoding="utf-8") as f:
            cache = f.read()
    except OSError:
        return None
    m = re.search(r"SNESRECOMP_ENABLE_DISPATCH_HISTORY:BOOL=(\w+)", cache)
    if m:
        return m.group(1) == "ON"
    m = re.search(r"SNESRECOMP_ENABLE_TRACE:BOOL=(\w+)", cache)   # implies it (runner.cmake)
    return (m.group(1) == "ON") if m else None


def trace_enabled(tree):
    try:
        with open(os.path.join(tree, "CMakeCache.txt"), encoding="utf-8") as f:
            m = re.search(r"SNESRECOMP_ENABLE_TRACE:BOOL=(\w+)", f.read())
        return m.group(1) == "ON" if m else None
    except OSError:
        return None


def manifest_index(path):
    """(pc,mode) variant keys, and per-pc disposition/reason/resolution facts."""
    m = json.load(open(path))
    nodes = list(m["nodes"].values()) if isinstance(m["nodes"], dict) else list(m["nodes"])
    variants, by_pc = set(), {}
    for n in nodes:
        k = n["key"]
        pc, mx = k["pc24"], MX_IDX(k["m"], k["x"])
        variants.add((pc, mx))
        e = by_pc.setdefault(pc, {"disp": {}, "reasons": set(), "res": set()})
        e["disp"][mx] = n["disposition"]
        e["reasons"].update(n.get("reasons") or [])
        for d in (n.get("demands") or []):
            if (d.get("target") or {}).get("pc24") == pc:
                e["res"].add(d.get("resolution"))
    return variants, by_pc


def classify(pc, mx, variants, by_pc):
    if (pc, mx) in variants:
        return "PRESENT-NULL"
    node = by_pc.get(pc)
    if node is None:
        return "ADD SEED"
    if any(d == "aot_eligible" for d in node["disp"].values()):
        return "ADD MODE"
    if "lle_exact" in node["res"]:
        return "REFUSED (lle_exact)"
    return "REFUSED"


def harvest_live(sock, t0, deadline):
    """Sample the ring over TCP while the run goes.

    Returns (events by global index, events lost to eviction between polls, the largest
    run-wide dispatch total seen, the last interp_stats reply, its sample time).

    dispatch_log_get has no index field, but `total` is a monotone counter of the run's
    dispatches and replies walk backwards from it, so position k of a reply is index
    total-1-k. Anything that entered and left the 1024-entry ring between two cycles of
    this loop is unrecoverable, and counted as such. The found1/found0 tallies exist only
    here — the exit report has the ring and the cycle share, never the tallies — so every
    cycle also samples interp_stats, and the last reply before the process exits is the
    whole-run number.
    """
    seen, lost, total, tallies, t_seen = {}, 0, 0, {}, 0.0
    f = sock.makefile("rb")
    while time.monotonic() < deadline:
        prev = total
        try:
            for offset in range(0, RING_CAP, CMD_CAP):
                sock.sendall(b"dispatch_log_get count=%d offset=%d\n" % (CMD_CAP, offset))
                line = f.readline()
                if not line:
                    return seen, lost, total, tallies, t_seen   # process exited
                try:
                    d = json.loads(line)
                except ValueError:
                    continue                      # banner / unknown-command line
                if not d.get("ok"):
                    continue
                total = max(total, as_int(d.get("total", 0)))
                evs = d.get("events") or []
                for k, e in enumerate(evs):
                    seen.setdefault(total - 1 - (offset + k), e)
                if len(evs) < CMD_CAP:
                    break                         # oldest entry the ring still holds
            sock.sendall(b"interp_stats\n")
            line = f.readline()
            d = json.loads(line) if line else {}
            if d.get("ok"):
                tallies, t_seen = d, time.monotonic() - t0
        except OSError:
            # ECONNRESET/EPIPE: the run ended between commands. What we have is what
            # there is; the exit report's own ring dump fills the rest.
            return seen, lost, total, tallies, t_seen
        except ValueError:
            pass                                  # a non-JSON reply line; keep polling
        if total - prev > RING_CAP:
            lost += total - prev - RING_CAP
    return seen, lost, total, tallies, t_seen


def tcp_command(sock, cmd):
    sock.sendall((cmd + "\n").encode())
    return json.loads(sock.makefile("rb").readline())


def main():
    ap = argparse.ArgumentParser(description="runtime dispatch promotion worklist")
    ap.add_argument("--binary", default="build-dh/ShadowrunSNESRecomp")
    ap.add_argument("--script", default="tests/scripts/combat.txt")
    ap.add_argument("--manifest", default="src/gen/program_manifest.json")
    ap.add_argument("--json", help="write the provenance-bound record here")
    ap.add_argument("--tcp", action="store_true",
                    help="also sample live and read the found1/found0 tallies "
                         "(needs a tree configured SNESRECOMP_ENABLE_TRACE=ON)")
    ap.add_argument("--port", type=int, default=4711)
    ap.add_argument("--limit", type=float, default=600.0, help="wall-clock cap, seconds")
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--allow-off-pin", action="store_true")
    a = ap.parse_args()

    binary = a.binary if os.path.isabs(a.binary) else os.path.join(BUNDLE, a.binary)
    if not os.path.exists(binary):
        sys.exit("no such binary: %s" % binary)
    tree = os.path.dirname(binary) if os.path.exists(os.path.join(os.path.dirname(binary), "CMakeCache.txt")) else None
    flag = history_enabled(tree)
    if flag is False:
        sys.exit("%s was configured without SNESRECOMP_ENABLE_DISPATCH_HISTORY, so the ring is "
                 "compiled out and the report answers disabled:true. Configure a diagnostic "
                 "tree first:\n  cmake -S . -B build-dh -DCMAKE_BUILD_TYPE=Release "
                 "-DSNESRECOMP_ROOT=<pin> -DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON" % tree)

    prov = P.provenance(binary)
    fw = prov.get("framework") or {}
    pin = P.pinned_rev()
    if pin and not a.allow_off_pin and fw.get("rev") != pin:
        sys.exit("refusing an off-pin program: %s was built against framework %s, "
                 "framework_pins.txt says %s" % (binary, fw.get("rev") or "unknown", pin[:12]))

    man_path = a.manifest if os.path.isabs(a.manifest) else os.path.join(BUNDLE, a.manifest)
    variants, by_pc = manifest_index(man_path)

    env = dict(os.environ, SNESRECOMP_DEBUG_PORT=str(a.port))
    anchor = os.path.dirname(binary)
    report = os.path.join(anchor, "last_run_report.json")
    try:
        os.remove(report)
    except OSError:
        pass
    # cwd = the bundle root, so --script paths are the repo's; the run's saves/ and
    # last_run_report.json still anchor to the executable's directory (host_main.c).
    proc = subprocess.Popen([binary, "--no-launcher", "--script", a.script], cwd=BUNDLE, env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    sock, tallies, t_seen = None, {}, 0.0
    live, live_lost, live_total = {}, 0, 0
    t0 = time.monotonic()
    if a.tcp:
        for _ in range(100):
            if proc.poll() is not None:
                break
            try:
                sock = socket.create_connection(("127.0.0.1", a.port), timeout=3)
                break
            except OSError:
                time.sleep(0.1)
        if sock is None:
            print("note: no debug server on port %d (%s): SNESRECOMP_TRACE is %s, so "
                  "debug_server_init is a stub; the whole-run tallies are unavailable"
                  % (a.port, tree or "?", trace_enabled(tree)))
        else:
            sock.settimeout(10)
            live, live_lost, live_total, tallies, t_seen = harvest_live(sock, t0, t0 + a.limit)
            try:
                sock.close()
            except OSError:
                pass
    try:
        proc.wait(timeout=a.limit)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
        print("WARN: killed at the %g s cap; the run is partial" % a.limit)
    waited = time.monotonic() - t0

    try:
        rep = json.load(open(report))
    except (OSError, ValueError):
        sys.exit("no readable %s: the run did not finish, or the report lives somewhere else "
                 "for this anchor" % report)
    dl = rep.get("dispatch_log") or {}
    if dl.get("disabled"):
        sys.exit("the report says dispatch_log disabled: %s has no ring. Rebuild with "
                 "-DSNESRECOMP_ENABLE_DISPATCH_HISTORY=ON" % binary)
    events = dl.get("events") or []
    ring_total, ring_shown = int(dl.get("total", 0)), int(dl.get("shown", len(events)))

    share = rep.get("execution_share") or {}
    print("binary  %s" % binary)
    print("        exe %s %s B   fw %s %s" % (prov["exe"]["sha256"][:16],
                                              f"{prov['exe']['bytes']:,}", (fw.get("rev") or "?")[:12],
                                              "dirty" if fw.get("dirty") else "(clean)"))
    print("script  %s   wall %.1fs   exit %s" % (a.script, waited, proc.returncode))
    print("share   aot_cycle_pct %s  interp_cycle_pct %s" %
          (share.get("aot_cycle_pct"), share.get("interp_cycle_pct")))
    print("ring    total %d   file dump shows the last %d (%.2f %%)   cap %d"
          % (ring_total, ring_shown, 100.0 * ring_shown / ring_total if ring_total else 0, RING_CAP))
    if live:
        print("        live tcp sample %d (%.2f %%)  evicted-between-polls %d  frames %s-%s"
              % (len(live), 100.0 * len(live) / live_total if live_total else 0, live_lost,
                 min(e["frame"] for e in live.values()), max(e["frame"] for e in live.values())))
    if tallies:
        print("tallies found1 %s  found0 %s  found0_pct %s   (always-on, whole run, "
              "sampled live at t=%.1fs; the exit report does not carry these)"
              % (tallies.get("found1"), tallies.get("found0"), tallies.get("found0_pct"), t_seen))

    pool = dict(live) if live else {}
    pool.update({(ring_total - len(events)) + i: e for i, e in enumerate(events)})
    if not pool:
        sys.exit("no dispatch events at all in the run: nothing to rank")

    per = collections.Counter()
    src = collections.defaultdict(collections.Counter)
    frames = collections.defaultdict(lambda: [None, None])
    for idx, e in sorted(pool.items()):
        pc, key = as_int(e["pc24"]), (as_int(e["pc24"]), e["mx"])
        fr = frames[key]
        fr[0] = e["frame"] if fr[0] is None else min(fr[0], e["frame"])
        fr[1] = e["frame"] if fr[1] is None else max(fr[1], e["frame"])
        if not e["found"]:
            per[key] += 1
            src[key][as_int(e["source_pc24"])] += 1
    hits = collections.Counter(MODE_NAMES[e["mx"]] for e in pool.values() if e["found"])
    missm = collections.Counter(MODE_NAMES[e["mx"]] for e in pool.values() if not e["found"])
    print("modes   hits %s   misses %s" % (dict(sorted(hits.items())),
                                           dict(sorted(missm.items())) or "(none)"))
    if not per:
        print("\nNo dispatch misses in the captured window: every indirect dispatch resolved to "
              "an exact AOT body. That is NOT coverage of the route: dispatch happens at "
              "RTS/RTL trampolines and runtime-pointer JSR, never at branch targets, so "
              "interpreter loops entered by branch are invisible here. Read it with the mode "
              "histogram above — if every return is one mode, the lever is entry_mx_at on "
              "bodies the config already declares, not new seeds.")

    rows = []
    for (pc, mx), n in per.most_common(a.top):
        act = classify(pc, mx, variants, by_pc)
        node = by_pc.get(pc) or {}
        why = sorted(node.get("reasons") or [])
        print("   %06X %-5s misses %5d  %-20s frames %s  modes %s%s"
              % (pc, MODE_NAMES[mx], n, act, "%d-%d" % tuple(frames[(pc, mx)]),
                 {MODE_NAMES[k]: v[0] if isinstance(v, tuple) else v
                  for k, v in (node.get("disp") or {}).items()} or "-",
                 ("   reasons " + ",".join(w.split("_at_")[0] for w in why[:4])) if why else ""))
        rows.append({"pc24": pc, "mx": mx, "mode": MODE_NAMES[mx], "misses": n, "action": act,
                     "frames": frames[(pc, mx)],
                     "sources": [{"pc24": s, "n": c} for s, c in src[(pc, mx)].most_common(5)],
                     "node_dispositions": {MODE_NAMES[k]: v for k, v in
                                           (node.get("disp") or {}).items()},
                     "node_reasons": why})

    for act, line in (("ADD MODE", "entry_mx_at %04X %d %d   # $%02X:%04X  %d misses"),
                      ("ADD SEED", None)):
        picked = [r for r in rows if r["action"] == act]
        if not picked:
            continue
        print("\npaste-ready %s lines:" % act)
        for r in picked:
            if line:
                print("   " + line % (r["pc24"] & 0xFFFF, (r["mx"] >> 1) & 1, r["mx"] & 1,
                                      r["pc24"] >> 16, r["pc24"] & 0xFFFF, r["misses"]))
            else:
                print('   [[func]]\n   name = "CC_%06X"\n   addr = "%04X"\n   bank = 0x%02x\n'
                      '   emit = true\n   entry_m = %d\n   entry_x = %d\n'
                      '   note = "round-3 seed: runtime dispatch miss x%d at $%02X:%04X"'
                      % (r["pc24"], r["pc24"] & 0xFFFF, r["pc24"] >> 16, (r["mx"] >> 1) & 1,
                         r["mx"] & 1, r["misses"], r["pc24"] >> 16, r["pc24"] & 0xFFFF))

    if a.json:
        import hashlib
        man_bytes = open(man_path, "rb").read()
        rec = {"schema": 1, "binary": binary, "exe": prov["exe"], "framework": fw,
               "build_tree": prov.get("build_tree"), "script": a.script,
               "wall_seconds": round(waited, 2), "exit": proc.returncode,
               "execution_share": {"aot_cycle_pct": share.get("aot_cycle_pct"),
                                   "interp_cycle_pct": share.get("interp_cycle_pct")},
               "ring_cap": RING_CAP, "ring_total": ring_total, "ring_file_shown": ring_shown,
               "ring_live_captured": len(live), "ring_live_evicted": live_lost,
               "tallies": ({k: tallies.get(k) for k in ("found1", "found0", "found0_pct",
                                                        "dispatch_total")} |
                           {"sampled_at_seconds": round(t_seen, 2)}) if tallies else None,
               "hits_by_mode": dict(sorted(hits.items())),
               "misses_by_mode": dict(sorted(missm.items())),
               "distinct_miss_keys": len(per),
               "manifest_joined": {"path": os.path.abspath(man_path), "bytes": len(man_bytes),
                                   "sha256": hashlib.sha256(man_bytes).hexdigest(),
                                   "nodes_by_pc": len(by_pc), "variants": len(variants)},
               "worklist": rows}
        gs = P.generated_set(BUNDLE)
        if gs:
            rec["generated_set_live_src_gen"] = gs
            rec["generated_set_note"] = ("live src/gen digest, NOT a digest of the manifest "
                                         "this join used (that is manifest_joined)")
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(rec, f, indent=1, sort_keys=True)
        print("\nwrote %s" % a.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
