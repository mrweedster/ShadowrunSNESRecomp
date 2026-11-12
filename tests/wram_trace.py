#!/usr/bin/env python3
"""Name the function that writes each WRAM byte at the split, on both paths.

    wram_trace.py                      # both trace legs, park at f16130
    wram_trace.py --park 16200         # park later
    wram_trace.py --legs lle           # one leg
    wram_trace.py --report             # re-render from saved JSON only
    wram_trace.py --streams            # the value gate, from saved JSON only

The framework's reverse-debug WRAM-write ring (`trace_wram` +
`wram_writes_at`, runner/src/debug_server.c) hooks the bus write path, so it
sees writes made by interpreted code *and* by AOT-compiled code, and it stamps
every entry with the recompiler's own bookkeeping: `func` (innermost recompiled
function), `parent` (one level up its call stack) and `block_idx`.

Method: run the fast repro route (scripts/bisect_h8.txt: the gate route cut
after `dump H8`) on each leg, arm the ring over the WRAM window where the split
appears, park the main thread a few frames past the onset with `run_to_frame`,
then read back the write history per address.

What it settled (evidence/a7 §7): a7 first ran this looking for the compiled
function that computes a wrong value at f16122, and there is none. On every
tracked address the two paths write the same bytes, in the same order, the same
number of times; only the frame a write is stamped with comes apart, and that
starts at f16122. `--streams` is that check, so it can be re-run against a
baseline instead of re-argued; `--report` shows where the stamps and the writing
function come apart, which is the hand-off, not a fault.

Ranges default to the three families evidence/a7 §3 names: the $00DF-indexed
table, the $011F-$012B latch bytes, and the $1C92-$1CD7 timer labels. Requires
trace builds (SNESRECOMP_ENABLE_TRACE=ON compiled with reverse debug), i.e.
build-tr-aot and build-tr-lle. Ring is 1 Mi entries, so arming for a whole
16,000-frame route over these ranges is cheap; queries are frame-bounded.
"""
import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "tests", "out")
SRAM_SEED = os.path.join(OUT, "xp_srm")
ROUTE = os.environ.get("WT_ROUTE", os.path.join(HERE, "scripts", "bisect_h8.txt"))
LEGS = {"lle": "build-tr-lle/ShadowrunSNESRecomp",
        "aot": "build-tr-aot/ShadowrunSNESRecomp"}
# WT_LEGS="ctrl=build-tr-ctrl/ShadowrunSNESRecomp,seed=build-tr-seed/...": the
# a7 legs are the default because this tool first answered an a7 question; a
# later question brings its own two binaries rather than renaming its builds.
if os.environ.get("WT_LEGS"):
    LEGS = {}
    for item in os.environ["WT_LEGS"].split(","):
        name, _, path = item.strip().partition("=")
        LEGS[name] = path
DEFAULT_RANGES = [(0x00DF, 0x00F2), (0x011F, 0x012B), (0x1C92, 0x1CD7)]
if os.environ.get("WT_RANGES"):
    DEFAULT_RANGES = [tuple(int(x, 16) for x in r.split(":"))
                      for r in os.environ["WT_RANGES"].split(",")]
DEFAULT_ADDRS = [0x00DF, 0x00E5, 0x00E9, 0x00EB, 0x00EF, 0x00F1, 0x00F2]


class Dbg:
    """Same line protocol client gate_state.py uses."""

    def __init__(self, port, timeout=30.0):
        self.port, self.timeout = port, timeout
        self.s = None
        self.buf = b""

    def connect(self, deadline=120.0):
        end = time.time() + deadline
        while True:
            try:
                self.s = socket.create_connection(("127.0.0.1", self.port), 3.0)
                self.s.settimeout(self.timeout)
                return self
            except OSError:
                if time.time() > end:
                    raise
                time.sleep(0.5)

    def _line(self):
        while b"\n" not in self.buf:
            chunk = self.s.recv(262144)
            if not chunk:
                raise ConnectionError("debug server closed")
            self.buf += chunk
        line, self.buf = self.buf.split(b"\n", 1)
        return line.decode().strip()

    def q(self, cmd):
        self.s.sendall((cmd + "\n").encode())
        for _ in range(3):
            obj = json.loads(self._line())
            if isinstance(obj, dict) and obj.get("connected") is True:
                continue
            return obj
        return None

    def frame(self):
        r = self.q("ping")
        return r.get("frame", -1) if isinstance(r, dict) else -1


def seed_sram(anchor):
    os.makedirs(os.path.join(anchor, "saves"), exist_ok=True)
    for f in ("save.srm", "save.srm.bak"):
        src = os.path.join(SRAM_SEED, f)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(anchor, "saves", f))


def _rom_path():
    """The dump this checkout regenerates from: repo-root rom.cfg line 1.

    A trace leg is still a harness leg, so it must never reach the picker: the
    old launch relied on a rom.cfg beside the executable, which a build tree
    does not have.
    """
    try:
        with open(os.path.join(ROOT, "rom.cfg")) as fh:
            rom = fh.readline().strip()
    except OSError:
        rom = os.path.join(ROOT, "Shadowrun (USA).sfc")
    return rom


def launch(leg, binary, dump, log, port):
    os.makedirs(dump, exist_ok=True)
    env = dict(os.environ)
    env.update(SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy",
               SNESRECOMP_DUMP_DIR=dump, SNESRECOMP_DEBUG_PORT=str(port),
               SNESRECOMP_FRAMEDUMP_LIMIT="0")
    args = [binary, "--no-launcher", "--rom", _rom_path(),
            "--script", ROUTE]
    return subprocess.Popen(args, env=env, cwd=ROOT,
                            stdout=open(log, "w"), stderr=subprocess.STDOUT)


def park(d, target, deadline=3600.0):
    r = d.q(f"run_to_frame {target}")
    if isinstance(r, dict) and r.get("error"):
        raise SystemExit(f"run_to_frame {target}: {r['error']}")
    end, last, still = time.time() + deadline, -1, 0
    while time.time() < end:
        f = d.frame()
        if f >= target and f == last:
            still += 1
            if still >= 2:
                return f
        elif f != last:
            still = 0
        last = f
        time.sleep(1.0 if f < target - 60 else 0.3)
    raise SystemExit(f"never parked at frame {target} (at {last})")


def collect(leg, binary, park_at, frm, to, ranges, addrs, limit, port):
    binary = os.path.abspath(binary)
    anchor = os.path.dirname(binary)
    dump = os.path.join(OUT, f"wt_{leg}")
    shutil.rmtree(dump, ignore_errors=True)
    seed_sram(anchor)
    print(f"== {leg}: {binary}  park f{park_at}  window f{frm}-f{to}")
    proc = launch(leg, binary, dump, os.path.join(OUT, f"wt_{leg}.log"), port)
    d = Dbg(port).connect()
    d.q("trace_wram_reset")
    for lo, hi in ranges:
        r = d.q(f"trace_wram {lo:x} {hi:x}")
        if not (isinstance(r, dict) and r.get("ok")):
            raise SystemExit(f"trace_wram {lo:x}-{hi:x}: {r}")
    at = park(d, park_at)
    out = {"leg": leg, "parked_at": at, "park_requested": park_at,
           "ranges": [[lo, hi] for lo, hi in ranges], "writes": {}}
    for a in addrs:
        r = d.q(f"wram_writes_at {a:x} {frm} {to} {limit}")
        if not (isinstance(r, dict) and r.get("ok")):
            print(f"   ${a:04X}: {r}")
            continue
        out["writes"][f"{a:04X}"] = r.get("matches", [])
        print(f"   ${a:04X}: {r.get('count')} writes f{frm}-f{to}")
    # Let the route finish on its own (`quit` at the end of bisect_h8.txt) so the
    # binary writes its own last_run_report.json -- that file is the proof of
    # which path ran, and SIGTERM would skip it.
    d.q("continue")
    try:
        rc = proc.wait(timeout=900)
    except subprocess.TimeoutExpired:
        proc.terminate()
        rc = proc.wait(timeout=60)
    print(f"   exit {rc}")
    share(binary, leg)
    path = os.path.join(OUT, f"wt_{leg}.json")
    json.dump(out, open(path, "w"), indent=1)
    print(f"   wrote {path}")
    return out


def share(binary, label):
    rep = os.path.join(os.path.dirname(binary), "last_run_report.json")
    try:
        s = json.load(open(rep))["execution_share"]
        print(f"   {label}: interp {s['interp_cycle_pct']:6.2f}%  "
              f"aot {s['aot_cycle_pct']:5.2f}%")
    except Exception as e:
        print(f"   {label}: no execution_share ({e})")


def load(legs):
    data = {}
    for leg in legs:
        p = os.path.join(OUT, f"wt_{leg}.json")
        if not os.path.isfile(p):
            raise SystemExit(f"missing {p} -- run the collect step first")
        data[leg] = json.load(open(p))
    return data


def _byte_events(leg):
    """{(bus index, byte address): (value, frame)} -- store widths made comparable.

    AOT blocks emit 16-bit transfers, so the ring records one event carrying the
    whole value at the base address; the interpreted floor writes those same two
    bytes as two events with their own addresses. Compared raw, the two legs
    disagree about the count, the addresses and the values of every write, which
    is an artifact of the record and not of the machine (evidence/a7 §7). The
    ring stamps each transfer with a unique bus index, so keying by that and
    splitting every transfer into its bytes -- low byte at adr, high byte at
    adr+1 -- puts both legs in one coordinate system.
    """
    ev = {}
    for entries in leg["writes"].values():
        for e in entries:
            base, w = int(e["adr"], 16), int(e["w"])
            val, bi = int(e["val"], 16), int(e["bi"])
            for k in range(w):
                ev[(bi, base + k)] = ((val >> (8 * k)) & 0xFF, e["f"])
    return ev


def streams(data, addrs):
    """The value-fidelity gate: do both paths write the same values, in order?

    This is what a frame dump cannot answer. Two paths that cut a guest loop at
    different points of the same frame produce frame dumps that differ, forever,
    and the difference grows on its own -- so "the WRAM images are byte-equal" is
    not a cross-path test once AOT coverage is real. What has to hold is
    weaker and stronger at once:

      weaker: the frame a value lands in may move, because that is where the
        frame boundary fell (the framework's Axis 6 ruling);
      stronger: the values, their order and their count may not. One loop pass
        too many or too few in a frame changes *when* the physics table updates,
        never *what* it updates to. A stream that differs in value, order or
        count is a wrong value somewhere, and that is a bug, not drift.

    Keyed by bus index, so two transfers that wrote the same byte the same way in
    the same frame still count as two writes.

    Exit codes: 0 every tracked address has an identical value stream, 1 some
    stream differs, 2 nothing was recorded.
    """
    vals = list(data.values())
    a = data.get("aot") or (vals[0] if len(vals) >= 2 else None)
    b = data.get("lle") or (vals[1] if len(vals) >= 2 else None)
    if not a or not b:
        print("need both legs -- run both or use --legs name,name")
        return 2
    ea, eb = _byte_events(a), _byte_events(b)
    if not ea or not eb:
        print("no writes recorded in one of the legs -- nothing to compare")
        return 2
    print(f"write-order gate: aot {a['parked_at']} / lle {b['parked_at']} parked, "
          f"transfers aot {sum(1 for _ in ea)} lle {sum(1 for _ in eb)}")
    print("           transfers  values   first value split            "
          "first frame-stamp split")
    bad = []
    tot_stamp = tot_writes = 0
    for x in addrs:
        k = f"{x:04X}"
        sa = [(v, f) for (bi, ad), (v, f) in sorted(ea.items()) if ad == x]
        sb = [(v, f) for (bi, ad), (v, f) in sorted(eb.items()) if ad == x]
        va, vb = [v for v, _ in sa], [v for v, _ in sb]
        split = next((i for i, (p, q) in enumerate(zip(va, vb)) if p != q), None)
        if split is None and len(va) != len(vb):
            split = min(len(va), len(vb))
        stamps = [(i, sa[i][1], sb[i][1]) for i in range(min(len(sa), len(sb)))
                  if sa[i][1] != sb[i][1]]
        tot_stamp += len(stamps)
        tot_writes += len(va)
        if split is not None:
            bad.append((k, split,
                        va[split] if split < len(va) else None,
                        vb[split] if split < len(vb) else None))
        fs = (f"#{stamps[0][0]} aot f{stamps[0][1]} lle f{stamps[0][2]} "
              f"({len(stamps)} of {len(va)} writes)" if stamps else "none")
        vs = (f"#{split} aot={va[split] if split < len(va) else None:} "
              f"lle={vb[split] if split < len(vb) else None:}"
              if split is not None else "none")
        print(f"  ${k}  {len(va):5d}/{len(vb):-5d}  "
              f"{'DIFF' if split is not None else 'same':>6}   {vs:<24} {fs}")
    print(f"\n{len(addrs) - len(bad)} of {len(addrs)} tracked addresses write an "
          f"identical value stream; {tot_stamp} frame stamps of {tot_writes} "
          "writes sit a frame apart")
    if bad:
        for k, i, x, y in bad:
            print(f"  FAIL ${k}: value #{i} is {x} on the AOT path and {y} on "
                  "the interpreted path -- a wrong value, not a hand-off point")
        print("VERDICT: FAIL -- the two paths do not compute the same state")
        return 1
    print("VERDICT: PASS -- the two paths write the same values in the same "
          "order; only which frame they land in moves (evidence/a7 §7)")
    return 0


def report(data, addrs):
    """Merged per-address, per-frame view: first frame the two legs disagree.

    Read this as "where did the frame stamps come apart", not "which path has
    the wrong value": it keeps one entry per frame, so a frame whose loop ran one
    pass further than the other leg's frame looks like a value difference. The
    value question is `--streams`.
    """
    vals = list(data.values())
    a = data.get("aot") or (vals[0] if len(vals) >= 2 else None)
    b = data.get("lle") or (vals[1] if len(vals) >= 2 else None)
    keys = [f"{x:04X}" for x in addrs]
    print(f"park: aot f{a['parked_at']} lle f{b['parked_at']}")
    print("first frame where the write history differs (AOT is the suspect leg)")
    hdr = f"{'addr':>6}  {'f':>6}  {'aot old->new':>16}  {'lle old->new':>16}  aot func / parent"
    for k in keys:
        wa = {e["f"]: e for e in a["writes"].get(k, [])}
        wb = {e["f"]: e for e in b["writes"].get(k, [])}
        first = None
        for f in sorted(set(wa) | set(wb)):
            ea, eb = wa.get(f), wb.get(f)
            if not ea or not eb:
                continue
            if ea["val"] != eb["val"] or ea["old"] != eb["old"]:
                first = f
                break
            if ea["func"] != eb["func"] and ea["func"] and eb["func"]:
                first = f
                break
        print(f"\n-- ${k}: aot {len(wa)} writes, lle {len(wb)} writes"
              + (f"   FIRST DIFF f{first}" if first else "   no diff"))
        if first is None:
            continue
        print(hdr)
        ks = sorted(set(wa) | set(wb))
        for f in range(max(ks[0], first - 2), min(ks[-1], first + 4)):
            ea, eb = wa.get(f), wb.get(f)
            if not ea or not eb:
                continue
            fa = f"{ea['old']}->{ea['val']}"
            fb = f"{eb['old']}->{eb['val']}"
            flag = "  <" if ea["val"] != eb["val"] else ""
            print(f"${k:>4}  {f:>6}  {fa:>16}  {fb:>16}  "
                  f"{ea['func'] or '-'} / {ea['parent'] or '-'}{flag}")
        # the writer set across the whole window, both legs
        for leg, w in (("aot", wa), ("lle", wb)):
            fs = {}
            for e in w.values():
                fs[(e["func"] or "-", e["parent"] or "-")] = \
                    fs.get((e["func"] or "-", e["parent"] or "-"), 0) + 1
            who = ", ".join(f"{f}<-{p}:{n}" for (f, p), n in
                            sorted(fs.items(), key=lambda kv: -kv[1])[:4])
            print(f"      writers {leg:3s}: {who}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--park", type=int, default=16130,
                    help="host frame to park each leg at (default 16130)")
    ap.add_argument("--window", type=int, default=25,
                    help="frames of history to read back (default 25)")
    ap.add_argument("--legs", default="lle,aot")
    ap.add_argument("--port-base", type=int, default=4450)
    ap.add_argument("--addrs", default=",".join(f"{a:x}" for a in DEFAULT_ADDRS))
    ap.add_argument("--limit", type=int, default=4096)
    ap.add_argument("--report", action="store_true",
                    help="only render saved JSON, run nothing")
    ap.add_argument("--streams", action="store_true",
                    help="the value gate on saved JSON: same values, same "
                         "order; exits 0/1/2 and runs nothing")
    ns = ap.parse_args()

    legs = [l.strip() for l in ns.legs.split(",") if l.strip()]
    addrs = [int(a, 16) for a in ns.addrs.split(",") if a.strip()]
    if ns.report or ns.streams:
        data = load(legs)
        if ns.streams:
            sys.exit(streams(data, addrs))
        report(data, addrs)
        return
    for i, leg in enumerate(legs):
        if leg not in LEGS:
            raise SystemExit(f"unknown leg {leg!r}")
    data = {}
    for i, leg in enumerate(legs):
        data[leg] = collect(leg, LEGS[leg], ns.park, ns.park - ns.window,
                            ns.park, DEFAULT_RANGES, addrs, ns.limit,
                            ns.port_base + i * 10)
    if len(data) == 2:
        report(data, addrs)
        sys.exit(streams(data, addrs))


if __name__ == "__main__":
    main()
