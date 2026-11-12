#!/usr/bin/env python3
"""Pin the street-transition break to code, or to machine state, and nowhere else.

The long cross-path route (evidence/a6) says the two paths part somewhere around
the street transition, but a 21,000-frame route cannot say on which side of the
emulator the difference lives: WRAM differs at the gate only by animation-phase
noise, and the break still happens, so the carrier might be code, or it might be
state the WRAM dump never shows (PPU, APU, DMA, cart latches). This tool cuts
the question in half.

    gate_state.py capture                  # freeze machine states at the gate
    gate_state.py replay                   # boot each binary into each state
    gate_state.py report                   # diff the replay dumps

capture runs the frozen route on a leg, asks the debug server to park the main
thread at a frame boundary (run_to_frame; the loop parks in
debug_server_wait_if_paused, so nothing mutates while we look), and then writes
an L3 snapshot with save_state. That snapshot is the whole machine: CPU, PPU,
DMA, APU, cart, WRAM.

replay boots a binary, starts it paused, loads one of those snapshots before any
frame is simulated, and runs the idle window from tests/scripts/gate_replay.txt.
Input is irrelevant across this window (the route holds nothing from P2 on), so
the only two variables left are the snapshot and the binary. Four combinations:

    state from the LLE leg  x  code = LLE   must reproduce the break (control)
    state from the LLE leg  x  code = AOT   code is the only variable
    state from the AOT leg  x  code = LLE   state is the only variable
    state from the AOT leg  x  code = AOT

If the break follows the code, it is a recompilation fault. If it follows the
snapshot, the divergence is already inside the machine at the gate and lives in
something the WRAM dump does not cover.

Result (evidence/a7 §2): it follows the snapshot. Every state replays
bit-identically on both code paths for the whole 1,430-frame window (<= 2
differing 1 KiB label blocks per frame), and the CPU-register section of the
two legs' snapshots is byte-identical at the parked boundary. The machine
already differs at the gate because both legs' *live* runs diverged physically
at host f16122 -- see tests/bisect_aot.sh for the fast repro of that split.

Both binaries here must be trace builds (-DSNESRECOMP_ENABLE_TRACE=ON); the
debug server is what capture and replay talk to. Defaults are build-tr-aot and
build-tr-lle, which tools/regen.sh plus two cmake trees produce.
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
STATES = os.path.join(OUT, "states")
SRAM_SEED = os.path.join(OUT, "xp_srm")
DEFAULT_LEGS = {
    "aot": os.path.join(ROOT, "build-tr-aot", "ShadowrunSNESRecomp"),
    "lle": os.path.join(ROOT, "build-tr-lle", "ShadowrunSNESRecomp"),
}
CAPTURE_ROUTE = os.path.join(HERE, "scripts", "gate_state.txt")
REPLAY_ROUTE = os.path.join(HERE, "scripts", "gate_replay.txt")


class Dbg:
    """Minimal line protocol client for the framework debug server."""

    def __init__(self, port, timeout=20.0):
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
        for _ in range(2):
            line = self._line()
            try:
                obj = json.loads(line)
            except ValueError:
                return line
            if isinstance(obj, dict) and obj.get("connected") is True:
                continue
            return obj
        return None

    def frame(self):
        r = self.q("ping")
        return r.get("frame", -1) if isinstance(r, dict) else -1


def seed_sram(anchor):
    """Same SRAM seed crosspath.sh uses, so the pre-gate run is the same run."""
    os.makedirs(os.path.join(anchor, "saves"), exist_ok=True)
    for f in ("save.srm", "save.srm.bak"):
        src = os.path.join(SRAM_SEED, f)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(anchor, "saves", f))


def launch(binary, dump, log, port, extra):
    os.makedirs(dump, exist_ok=True)
    env = dict(os.environ)
    env.update(SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy",
               SNESRECOMP_DUMP_DIR=dump, SNESRECOMP_DEBUG_PORT=str(port))
    args = [binary, "--no-launcher", "--framedump", dump] + extra
    return subprocess.Popen(args, env=env, cwd=ROOT,
                            stdout=open(log, "w"), stderr=subprocess.STDOUT)


def wait_parked(d, target, deadline=3600.0):
    """Advance to `target` and confirm the main thread really is parked there."""
    r = d.q(f"run_to_frame {target}")
    if isinstance(r, dict) and r.get("error"):
        raise SystemExit(f"run_to_frame {target}: {r['error']}")
    end = time.time() + deadline
    last, still = -1, 0
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


def share(binary, label):
    """The proof of which path ran, read from the binary's own anchor."""
    rep = os.path.join(os.path.dirname(binary), "last_run_report.json")
    try:
        s = json.load(open(rep))["execution_share"]
        print(f"   {label}: interp {s['interp_cycle_pct']:6.2f}%  "
              f"aot {s['aot_cycle_pct']:6.2f}%")
    except Exception as e:
        print(f"   {label}: no execution_share ({e})")


def do_capture(legs, frames, ports, route=CAPTURE_ROUTE):
    os.makedirs(STATES, exist_ok=True)
    for name, binary in legs.items():
        binary = os.path.abspath(binary)
        anchor = os.path.dirname(binary)
        dump = os.path.join(OUT, f"gs_{name}")
        shutil.rmtree(dump, ignore_errors=True)
        seed_sram(anchor)
        print(f"== capture {name}: {binary}\n   route {os.path.basename(route)}"
              f"  states at {','.join(str(f) for f in frames)}")
        proc = launch(binary, dump, os.path.join(OUT, f"gs_{name}.log"),
                      ports[name], ["--script", route])
        d = Dbg(ports[name]).connect()
        for f in frames:
            at = wait_parked(d, f)
            path = os.path.join(STATES, f"{name}_f{at}.l3sn")
            r = d.q(f"save_state {path}")
            if not (isinstance(r, dict) and r.get("ok")):
                raise SystemExit(f"save_state failed: {r}")
            print(f"   state {os.path.basename(path)}  {r['bytes']} bytes  "
                  f"parked at f{at}")
            d.q("continue")
        d.q("continue")
        try:
            proc.wait(timeout=600)
        except subprocess.TimeoutExpired:
            proc.terminate()
            proc.wait(timeout=30)
        share(binary, name)
        print(f"   dumps: {dump}")


def do_replay(legs, states, port_base):
    """2x2: every captured state booted on every code path."""
    rows = []
    for i, st in enumerate(states):
        for j, (name, binary) in enumerate(legs.items()):
            binary = os.path.abspath(binary)
            tag = f"{os.path.splitext(os.path.basename(st))[0]}__{name}"
            dump = os.path.join(OUT, f"gr_{tag}")
            shutil.rmtree(dump, ignore_errors=True)
            seed_sram(os.path.dirname(binary))
            print(f"== replay {tag}: {os.path.basename(st)} on {name}")
            proc = launch(binary, dump, os.path.join(OUT, f"gr_{tag}.log"),
                          port_base + i * 10 + j,
                          ["--paused", "--script", REPLAY_ROUTE])
            d = Dbg(port_base + i * 10 + j).connect()
            r = d.q(f"load_state {st}")
            if not (isinstance(r, dict) and r.get("ok")):
                raise SystemExit(f"load_state failed: {r}")
            print(f"   loaded {r['bytes']} bytes")
            d.q("continue")
            rc = proc.wait(timeout=1800)
            share(binary, name)
            rows.append((tag, dump, rc))
    return rows


def wram(d, f):
    p = os.path.join(d, f"frame_{f:06d}_wram.bin")
    return open(p, "rb").read() if os.path.isfile(p) else None


def frames(d):
    return sorted(int(e[6:12]) for e in os.listdir(d)
                  if e.startswith("frame_") and e.endswith("_wram.bin")) if os.path.isdir(d) else []


def tick(b):
    return b[0x1C92] | (b[0x1C93] << 8)


def scene(b, ref, blk=4096):
    """Fraction of blocks that match a known title-screen frame: how close is
    this scene to the title screen the LLE leg drifted to."""
    if not ref:
        return -1.0
    n = (len(b) + blk - 1) // blk
    hit = sum(1 for i in range(0, len(b), blk) if b[i:i + blk] == ref[i:i + blk])
    return 100.0 * hit / n


def do_report(states, legs, ref_frame):
    ref = wram(os.path.join(OUT, "xp_lle"), ref_frame)
    if ref is None:
        print(f"   no title reference frame in xp_lle (frame {ref_frame})")
    print(f"== per-replay outcome (tick = guest frame counter $7E1C92, "
          f"scene = % blocks matching the LLE title frame)")
    for st in states:
        for name in legs:
            tag = f"{os.path.splitext(os.path.basename(st))[0]}__{name}"
            dump = os.path.join(OUT, f"gr_{tag}")
            fr = frames(dump)
            if not fr:
                print(f"   {tag:26s} no dumps")
                continue
            a, b = wram(dump, fr[0]), wram(dump, fr[-1])
            print(f"   {tag:26s} frames {len(fr):5d}  tick {tick(a):5d}->{tick(b):5d}"
                  f"  scene {scene(a, ref):5.1f}->{scene(b, ref):5.1f}")
    print()
    names = list(legs)
    for st in states:
        for i in range(len(names)):
            for j in range(i + 1, len(names)):
                base = os.path.splitext(os.path.basename(st))[0]
                da = os.path.join(OUT, f"gr_{base}__{names[i]}")
                db = os.path.join(OUT, f"gr_{base}__{names[j]}")
                if not (frames(da) and frames(db)):
                    continue
                print(f"== same state ({os.path.basename(st)}), code is the only "
                      f"variable: {names[i]} vs {names[j]}")
                subprocess.call([sys.executable,
                                 os.path.join(ROOT, "tests", "framedump_diff.py"),
                                 "drift", da, db])
                print()


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("mode", choices=["capture", "replay", "report", "all"])
    ap.add_argument("--leg", action="append", default=[],
                    help="name=path, repeatable (default: the two trace trees)")
    ap.add_argument("--frames", default="21700,21836",
                    help="comma list of host frames to freeze states at (capture)")
    ap.add_argument("--route", default=CAPTURE_ROUTE,
                    help="input script for capture (default: the gate route)")
    ap.add_argument("--state", action="append", default=[],
                    help="state file to replay (default: every one in states/)")
    ap.add_argument("--port", type=int, default=4391, help="debug port base")
    ap.add_argument("--title-frame", type=int, default=24434,
                    help="xp_lle frame used as the title-screen fingerprint")
    a = ap.parse_args()

    legs = dict(DEFAULT_LEGS)
    for spec in a.leg:
        name, _, path = spec.partition("=")
        legs[name] = path or DEFAULT_LEGS.get(name, "")
    legs = {k: v for k, v in legs.items() if v}
    ports = {name: a.port + i for i, name in enumerate(legs)}
    frames_list = [int(x) for x in a.frames.split(",") if x.strip()]

    if a.mode in ("capture", "all"):
        do_capture(legs, frames_list, ports, os.path.abspath(a.route))
    states = [os.path.abspath(s) for s in a.state] or (sorted(
        os.path.join(STATES, e) for e in os.listdir(STATES) if e.endswith(".l3sn")
    ) if os.path.isdir(STATES) else [])
    if a.mode in ("replay", "all"):
        if not states:
            raise SystemExit("no states captured yet")
        do_replay(legs, states, a.port)
    if a.mode in ("report", "all"):
        do_report(states, legs, a.title_frame)


if __name__ == "__main__":
    main()
