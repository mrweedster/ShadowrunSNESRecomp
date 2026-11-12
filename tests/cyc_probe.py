#!/usr/bin/env python3
"""Do the two code paths spend the same guest cycles per frame?

    cyc_probe.py                       # both legs, sample f16110-f16180
    cyc_probe.py --start 16100 --until 16200 --step 20
    cyc_probe.py --legs lle            # one leg
    cyc_probe.py --report              # re-render from saved JSON only

Why: wram_trace.py (evidence/a7 §7) found that at the f16122 onset the two legs
emit the *same value sequence* at the divergent addresses ($00DF/$00E5/$00E9/
$00EB/$00EF/$00F1) -- element for element identical, same order, same counts
across the window -- but the same element carries a different frame label: the
$00EF entry #922 is f16123 on the AOT leg and f16122 on the floor leg, and the
frame-label split starts at the same write index for every one of those
addresses. Identical values at different frame labels is a timing signature,
not a value bug: the frame boundary lands one loop iteration off, so the frame
dump samples the physics table at a different point.

This tool measures the quantity that decides it: `cpu_cycles` from `get_v2_cpu`
sampled while parked at a guest frame, differenced over the *measured* frame
delta, per leg. Equal cycles/frame on both legs means the frame boundary is
placed identically and the frame-label split must come from the ring's frame
stamp; unequal cycles/frame means the compiled path's cycle accounting is the
fault and the WRAM diff is downstream of it.

Method: run the fast repro route (scripts/bisect_h8.txt) on each leg, park with
`run_to_frame`, read `get_v2_cpu` (cycles) plus the frame ring's per-frame
cpu/irq snapshot (`get_frame_extended` carries pc and hPos/vPos at the capture),
then `continue`. Parks are aimed at `last parked frame + --step`, never at a
fixed list: a headless leg runs ~55 guest frames/s, so `run_to_frame` lands up
to ~15 frames late and a fixed ladder walks into the past. The route's own
`quit` still runs, so last_run_report.json records the execution share proving
which path executed.
"""
import argparse
import json
import os
import shutil
import socket
import subprocess
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "tests", "out")
SRAM_SEED = os.path.join(OUT, "xp_srm")
ROUTE = os.path.join(HERE, "scripts", "bisect_h8.txt")
LEGS = {"lle": "build-tr-lle/ShadowrunSNESRecomp",
        "aot": "build-tr-aot/ShadowrunSNESRecomp"}


class Dbg:
    """Same line protocol client gate_state.py / wram_trace.py use."""

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


def launch(binary, dump, log, port):
    os.makedirs(dump, exist_ok=True)
    env = dict(os.environ)
    env.update(SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy",
               SNESRECOMP_DUMP_DIR=dump, SNESRECOMP_DEBUG_PORT=str(port),
               SNESRECOMP_FRAMEDUMP_LIMIT="0")
    args = [binary, "--no-launcher", "--script", ROUTE]
    return subprocess.Popen(args, env=env, cwd=ROOT,
                            stdout=open(log, "w"), stderr=subprocess.STDOUT)


def park(d, target, deadline=3600.0):
    """Pause at or just after `target`; return the frame it settled on."""
    r = d.q(f"run_to_frame {target}")
    if isinstance(r, dict) and r.get("error"):
        cur = d.frame()          # already past it: the leg outran the request
        if cur >= target:
            return cur
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
        # Poll fine near the target: a headless leg runs ~55 guest frames/s, so
        # a 1s poll overshoots by ~55 frames and a 0.3s one by ~17.
        time.sleep(1.0 if f < target - 500 else (0.2 if f < target - 20 else 0.05))
    raise SystemExit(f"never parked at frame {target} (at {last})")


def sample_at(d, at):
    s = {"parked_at": at}
    cpu = d.q("get_v2_cpu")
    if isinstance(cpu, dict) and "cpu_cycles" in cpu:
        for k in ("cpu_cycles", "master_cycles", "main_cycles",
                  "catchup_cycles"):
            s[k] = cpu[k]
        s["resume_pc"] = cpu.get("resume_pc")
    fr = d.q(f"get_frame_extended {at}")
    if isinstance(fr, dict) and fr.get("cpu"):
        s["pc"] = fr["cpu"].get("pc")
        irq = fr.get("irq") or {}
        s["irq"] = {k: irq[k] for k in
                    ("inNmi", "inVblank", "hPos", "vPos", "hTimer") if k in irq}
    else:
        s["frame_ext"] = fr
    return s


def collect(leg, binary, start, until, step, port):
    binary = os.path.abspath(binary)
    anchor = os.path.dirname(binary)
    dump = os.path.join(OUT, f"cy_{leg}")
    shutil.rmtree(dump, ignore_errors=True)
    seed_sram(anchor)
    print(f"== {leg}: {binary}  sampling f{start}-f{until} step {step}")
    proc = launch(binary, dump, os.path.join(OUT, f"cy_{leg}.log"), port)
    d = Dbg(port).connect()
    samples = []
    at = park(d, start)
    while True:
        s = sample_at(d, at)
        samples.append(s)
        print(f"   f{at}: cycles={s.get('cpu_cycles')} "
              f"master={s.get('master_cycles')} pc={s.get('pc')}")
        if at >= until:
            break
        at = park(d, at + step)
    d.q("continue")
    try:
        rc = proc.wait(timeout=900)
    except subprocess.TimeoutExpired:
        proc.terminate()
        rc = proc.wait(timeout=60)
    print(f"   exit {rc}")
    share(binary, leg)
    out = {"leg": leg, "start": start, "until": until, "step": step,
           "samples": samples}
    path = os.path.join(OUT, f"cy_{leg}.json")
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
        p = os.path.join(OUT, f"cy_{leg}.json")
        if not os.path.isfile(p):
            raise SystemExit(f"missing {p} -- run the collect step first")
        data[leg] = json.load(open(p))
    return data


def per_frame(d):
    """{frame_at_end_of_interval: (d_cycles, d_frames, cycles_per_frame)}"""
    rows, prev = {}, None
    for s in d["samples"]:
        f, c = s["parked_at"], s.get("cpu_cycles")
        if prev and c is not None and prev[1] is not None and f > prev[0]:
            rows[f] = (c - prev[1], f - prev[0], (c - prev[1]) / (f - prev[0]))
        prev = (f, c)
    return rows


def report(data):
    """Per-leg cycles/frame series, then the cycle-accounting verdict.

    Parked frames do not line up between legs (each park lands wherever the
    pause settles), so intervals are compared by frame-range overlap: an AOT
    interval and a floor interval that cover a common frame span must spend the
    same cycles over that span if the compiled path accounts cycles identically.
    """
    a = per_frame(data["aot"]) if "aot" in data else {}
    l = per_frame(data["lle"]) if "lle" in data else {}
    for leg, rows in (("aot", a), ("lle", l)):
        if not rows:
            continue
        print(f"\n-- {leg} leg")
        for f in sorted(rows):
            dcy, dfr, cpf = rows[f]
            print(f"   f{f - dfr + 1}-{f}: {dfr:>4} frames  {dcy:>9} cycles"
                  f"  {cpf:>10.2f} c/f")
    if not (a and l):
        return
    print("\noverlapping-interval comparison (aot - lle cycles per frame)")
    first, pairs = None, 0
    for fa in sorted(a):
        a0, a1, ca = fa - a[fa][1] + 1, fa, a[fa][2]
        best = None
        for fl in sorted(l):
            l0, l1, cl = fl - l[fl][1] + 1, fl, l[fl][2]
            ov = min(a1, l1) - max(a0, l0) + 1
            if ov > 0 and (best is None or ov > best[0]):
                best = (ov, fl, cl, l0, l1)
        if not best:
            continue
        ov, fl, cl, l0, l1 = best
        pairs += 1
        d = ca - cl
        if first is None and abs(d) > 1.0:
            first = fa
        print(f"   aot f{a0}-{a1} vs lle f{l0}-{l1}: {ca:>10.2f} vs "
              f"{cl:>10.2f}  d={d:>+9.2f}")
    print(f"\n   compared {pairs} overlapping intervals")
    print(("   FIRST interval where cycles/frame differ: ends f%d" % first)
          if first else
          "   cycles/frame agree (within 1 cycle) on both legs, every "
          "overlapping interval")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--start", type=int, default=16110,
                    help="first frame to sample (default 16110, onset is f16122)")
    ap.add_argument("--until", type=int, default=16180,
                    help="last frame to sample (default 16180; route ends f16188)")
    ap.add_argument("--step", type=int, default=6,
                    help="frames between parks (default 6)")
    ap.add_argument("--legs", default="lle,aot")
    ap.add_argument("--port-base", type=int, default=4470)
    ap.add_argument("--report", action="store_true",
                    help="only render saved JSON, run nothing")
    ns = ap.parse_args()

    legs = [x.strip() for x in ns.legs.split(",") if x.strip()]
    if ns.report:
        report(load(legs))
        return
    data = {}
    for i, leg in enumerate(legs):
        if leg not in LEGS:
            raise SystemExit(f"unknown leg {leg!r}")
        data[leg] = collect(leg, LEGS[leg], ns.start, ns.until, ns.step,
                            ns.port_base + i * 10)
    if len(data) == 2:
        report(data)


if __name__ == "__main__":
    main()
