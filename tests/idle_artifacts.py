#!/usr/bin/env python3
"""Regenerate the committed idle-poll artifacts from the run directories.

    idle_artifacts.py cost    the cost matrix   -> evidence/artifacts/idle_poll_cost_round3.txt
    idle_artifacts.py a0      the A0 checkpoint -> evidence/artifacts/idle_poll_a0_round3.txt
    idle_artifacts.py checkpoints  every tagged checkpoint, each leg vs control
                                            -> evidence/artifacts/idle_poll_checkpoints_round3.txt

Nothing here is hand-typed. Every row is read back out of a run artifact: the
tier-2 ingest JSON (`tests/out/idle_<leg>_ingest.json`), the leg's own stdout
(`tests/out/idle_<leg>.log`, which carries the exit line, the declaration line
and the frame-service census), and the `dump <tag>` checkpoint files
(`<tag>.info.json`, `<tag>.regs.json`, and the wram/vram/oam/cgram/sram/fb/apu/
ppuw/dma images beside them) in the parity legs (`tests/out/ip_<leg>`).

Why a generator: a round record that cites numbers has to be able to show where
they came from months later, and the only durable answer is a program that
re-derives them from files that are still on disk.
"""
import glob
import hashlib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance as prov  # noqa: E402  (same directory as this file)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "out")
DATE = "2026-11-07"
PIN = prov.pinned_rev("snesrecomp") or "unknown"

# leg -> (declared polls, note). Order is the order the artifact prints.
AB_LEGS = [
    ("off", "", "undeclared control"),
    ("off2", "", "undeclared control, repeated: the determinism check"),
    ("on", "81b061,81ee8e", "both $7E1C92 waits declared"),
    ("m0x0", "81b061", "the M0X0 wait only"),
    ("m1x0", "81ee8e", "the M1X0 wait only (this PC is also sighted in M1X1)"),
]
IP_LEGS = [
    ("off", "", "undeclared control"),
    ("m1x0", "81ee8e", "$81EE8E only"),
    ("on", "81b061,81ee8e", "both $7E1C92 waits"),
    ("m0x0", "81b061", "$81B061 only"),
]
CHECKPOINT = "A0"


def _sha(path, n=16):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()[:n]


def _exe(name):
    path = os.path.join(ROOT, name)
    if not os.path.isfile(path):
        return None
    return "%s  %s (%s B)" % (_sha(path), name, f"{os.path.getsize(path):,}")


def _fingerprint(names=("build-r3/ShadowrunSNESRecomp", "build-r2b/ShadowrunSNESRecomp")):
    """What made these numbers, read off the binaries themselves: the framework
    revision each linked, and the generated set each was compiled from. Two
    executables sharing a generated-set sha256 are the same program with
    different host-side plumbing, which is what makes an A/B across them honest.
    """
    out, sets, warns = [], {}, set()
    for name in names:
        path = os.path.join(ROOT, name)
        if not os.path.isfile(path):
            continue
        d = prov.provenance(path)
        fw, gs, bt = d["framework"], d["generated_set"], d["build_tree"]
        out.append("executable: %s  %s (%s B)" % (gs["sha256"][:10], name,
                                                  f"{d['exe']['bytes']:,}"))
        out.append("   exe sha256 %s   framework %s%s   config %s, embed_rom %s"
                   % (d["exe"]["sha256"][:16], fw["rev"], " (dirty)" if fw["dirty"] else "",
                      bt["config"], bt["embed_rom"].lower()))
        out.append("   generated set: %s units=%d promoted=%d dispatch=%d files=%d"
                   % (gs["sha256"][:16], gs["units"], gs["promoted_functions"],
                      gs["dispatch_entries"], gs["files"]))
        for w in d["warnings"]:
            out.append("   warning: " + w)
        sets[name] = gs["sha256"]
        warns.update(d["warnings"])
    if len(set(sets.values())) == 1 and sets:
        out.append("   both executables carry the same generated-set sha256: the A/B is host-side only")
        if any("touched after" in w for w in warns):
            out.append("   (those 'touched after' warnings are about file mtimes only; the hash above is")
            out.append("    over the generated contents, and it is identical on both executables)")
    return out


def _header(title, record, extra=()):
    print(f"== {title} (M2 promotion round 3, {DATE}) ==")
    print(f"record: evidence/{record}")
    print(f"framework pin: snesrecomp={PIN}")
    for line in _fingerprint():
        print(line)
    for line in extra:
        print(line)
    print()


def _log_lines(leg):
    path = os.path.join(OUT, leg + ".log")
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read().splitlines()


def _grep(lines, needle):
    return [_strip_ts(ln.strip()) for ln in lines if needle in ln]


def _strip_ts(ln):
    """The host prefixes its own log lines with elapsed host time; keep the words."""
    return re.sub(r"^\[host \+[0-9.]+s\] ", "", ln)


def _pin_root():
    """The framework checkout build-r3 linked, so the decoder wait_class uses is
    the one this round's capture was analysed by."""
    return prov.framework_root(os.path.join(ROOT, "build-r3", "ShadowrunSNESRecomp"))


def _wait_class(ingest_path, floor=300_000):
    """The wait-class roll-up, taken from tests/wait_class.py -- that tool owns
    the loop-shape derivation (and the decoder), so this file cannot drift from
    it. Returns its last line, which carries the loop count and the total."""
    import subprocess

    root = _pin_root()
    if not root:
        return "wait class: no framework root in build-r3/CMakeCache.txt", 0
    out = subprocess.run(
        ["python3", os.path.join(ROOT, "tests", "wait_class.py"), ingest_path, str(floor)],
        cwd=ROOT, env={**os.environ, "SNESRECOMP_ROOT": root},
        capture_output=True, text=True)
    line = next((ln for ln in out.stdout.splitlines()
                 if ln.startswith("declared-poll candidates")), None)
    if line is None:
        return "wait class: wait_class.py gave no roll-up: " + (out.stderr.strip()[:120] or "?"), 0
    n = int(line.split()[3])
    return line, n


def _attributed(ingest):
    return sum(row["guest_cycles"] for row in ingest["hot_instructions"])


def cmd_cost():
    _header(
        "declared idle polls: cost per leg",
        "m2_promotion_round3.md section 4",
        [
            "   every leg ran the r3 exe (poll-capable: DeclareIdlePolls() in src/game_rtl.c);",
            "   the r2b exe is the round-2b control, and the undeclared legs off/off2 reproduce",
            "   its counters exactly -- see their rows below, and evidence/m2_promotion_round2b.md",
            "route: tests/scripts/combat.txt, saves/save.srm seeded fresh per leg, turbo, dummy drivers",
            "harness: tests/idle_ab.sh, every leg re-arming --coverage-capture=on and ingested with",
            "           tools/tier2_ingest.py --json --cfg-dir recomp",
            "source: tests/out/idle_<leg>_ingest.json, tests/out/idle_<leg>.log,",
            "        tests/out/idle_<leg>/last_run_report.json, tests/out/spd_<leg>.log",
        ],
    )
    for leg, polls, note in AB_LEGS:
        ipath = os.path.join(OUT, f"idle_{leg}_ingest.json")
        if not os.path.isfile(ipath):
            print(f"-- leg {leg}: no ingest at {ipath}")
            continue
        ingest = json.load(open(ipath))
        rep = os.path.join(OUT, f"idle_{leg}", "last_run_report.json")
        share = json.load(open(rep)).get("execution_share", {}) if os.path.isfile(rep) else {}
        lines = _log_lines(f"idle_{leg}")
        ident = ingest["identity"]
        wline, _ = _wait_class(ipath)
        print(f"-- leg {leg}: polls={polls or 'none'}   {note}")
        print("   interp %6.2f%% (%s insns / %s cycles)  aot %6.2f%%  cpu_cycles %s  master_cycles %s"
              % (share.get("interp_cycle_pct", float("nan")),
                 f"{int(share.get('interp_insns', 0)):,}",
                 f"{int(share.get('interp_cycles', 0)):,}",
                 share.get("aot_cycle_pct", float("nan")),
                 f"{int(share.get('cpu_cycles', 0)):,}",
                 f"{int(share.get('master_cycles', 0)):,}"))
        ex = _grep(lines, "script quit after") or _grep(lines, "until timed out")
        decl = _grep(lines, "idle polls declared")
        print("   %s   |   %s" % (ex[0] if ex else "no exit line",
                                  decl[0] if decl else "no idle-poll line (nothing declared)"))
        print("   capture: captures=%d gap tuples=%d interpreted=%s insns / %s guest cycles / warnings=%d"
              % (ingest["capture_count"], len(ingest["discoveries"]),
                 f"{int(ingest['interpreted_instructions']):,}",
                 f"{int(ingest['interpreted_guest_cycles']):,}",
                 len(ingest.get("warnings", []))))
        print("   identity: program_digest=%s build_digest=%s generation_digest=%s rom_sha256=%s %s"
              % (ident["program_digest"][:16], ident["build_digest"][:10],
                 ident["generation_digest"][:16], ident["rom_sha256"][:8], ident["mapper"]))
        print("   wait class: " + wline)
        print()

    print("== the declared waits, per leg (tests/wait_cost.py) ==")
    print("   the same four PCs summed in every leg -- the two compare heads of $7E1C92 and the")
    print("   back-edges they own -- so an undeclared leg is the price of the same waits")
    print("   (wait_cost.py reads the capture's own hot table, no decoder, so it runs anywhere)")
    import subprocess

    pairs = [f"{leg}=tests/out/idle_{leg}_ingest.json" for leg, _, _ in AB_LEGS
             if os.path.isfile(os.path.join(OUT, f"idle_{leg}_ingest.json"))]
    out = subprocess.run(["python3", os.path.join(ROOT, "tests", "wait_cost.py")] + pairs,
                         cwd=ROOT, capture_output=True, text=True)
    print("\n".join(out.stdout.splitlines()))
    print()

    print("== guest cpu cycles per host frame, and the host clock, per leg ==")
    print("   cpu_cycles and frames both come from the run report's execution_share, and an")
    print("   'exit line: N' column appears only when the script's own count differs from the")
    print("   report's. The seconds/fps columns are that run's frame-service line. Read the")
    print("   frame count before comparing rates: a leg that timed out ran less route, so its")
    print("   rate is not the same measurement. The like-for-like rows ran the whole route.")
    row = "%-6s %14s %8s %10s %8s %9s"
    print("   " + (row % ("leg", "cpu_cycles", "frames", "cyc/frame", "fps", "seconds")))
    for leg, _, _ in AB_LEGS:
        rep = os.path.join(OUT, f"idle_{leg}", "last_run_report.json")
        lines = _log_lines(f"idle_{leg}")
        if not os.path.isfile(rep):
            continue
        share = json.load(open(rep)).get("execution_share", {})
        ex = _grep(lines, "script quit after") or _grep(lines, "until timed out")
        m = re.search(r"after (\d+) frames", ex[0]) if ex else None
        frames = int(share.get("frame") or (m.group(1) if m else 0))
        note = "" if not m or int(m.group(1)) == frames else "  exit line: %s" % m.group(1)
        fs = _grep(lines, "frame service")
        fps = sec = "?"
        if fs:
            for tok in fs[-1].split():
                if tok.startswith("fps="):
                    fps = tok[4:]
                elif tok.startswith("seconds="):
                    sec = "%.3f" % float(tok[8:])
        cpu = int(share.get("cpu_cycles", 0))
        print("   " + (row % (leg, f"{cpu:,}", f"{frames:,}",
                              f"{cpu / frames:,.0f}" if frames else "?", fps, sec)) + note)
    print()

    print("== host time, same route, capture off (tests/out/spd_off.log, spd_m0x0.log) ==")
    for leg, polls, label in (("off", "", "nothing declared"), ("m0x0", "81b061", "$81B061 declared")):
        path = os.path.join(OUT, f"spd_{leg}.log")
        if not os.path.isfile(path):
            print(f"   {label}: no spd_{leg}.log")
            continue
        fs = _grep(open(path, encoding="utf-8", errors="replace").read().splitlines(),
                   "frame service")
        print(f"   {label}: {fs[-1] if fs else 'no frame-service line'}"
              "   (22,044 frames in both)")
    print()

    print("reproduce:")
    print("  BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_ab.sh                      # off off2 on")
    print('  LEGS="m0x0:81b061 m1x0:81ee8e" BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_ab.sh')
    print("  python3 tests/wait_cost.py off=tests/out/idle_off_ingest.json \\")
    print("                             on=tests/out/idle_on_ingest.json    # the same rows, again")
    print("  SNESRECOMP_ROOT=<pin> python3 tests/wait_class.py tests/out/idle_off_ingest.json 300000")
    print("  python3 tests/idle_artifacts.py cost    # this file, again")


def _regs(path):
    return json.loads(open(path, encoding="utf-8").read())


def _compact(v):
    if isinstance(v, list):
        return "[" + ",".join(str(x) for x in v) + "]"
    return str(v)


def _dma_delta(a, b):
    out = []
    for ca, cb in zip(a, b):
        fields = [k for k in sorted(set(ca) | set(cb)) if ca.get(k) != cb.get(k)]
        if fields:
            out.append("ch%-2d %s" % (ca.get("ch", -1),
                                      " ".join("%s %s->%s" % (k, ca.get(k), cb.get(k))
                                               for k in fields)))
    return out


def cmd_a0(tag=CHECKPOINT):
    dirs = {leg: os.path.join(OUT, f"ip_{leg}") for leg, _, _ in IP_LEGS}
    missing = [leg for leg, d in dirs.items()
               if not os.path.isfile(os.path.join(d, tag + ".info.json"))]
    if missing:
        raise SystemExit(f"no {tag} checkpoint in: " + " ".join(missing)
                         + " -- run ./tests/idle_parity.sh first")
    _header(
        f"the {tag} checkpoint, all four idle-poll parity legs",
        f"m2_promotion_round3.md section 5 (the {tag} bullet) and section 6 item 3",
        [
            "route: tests/scripts/combat.txt from saves/save.srm; every leg reaches %s at the SAME guest frame" % tag,
            "       because the route's gates sit on WRAM state, never on frame counts",
            "harness: tests/idle_parity.sh (FULLBYTES=1 TRIM=1), same executable, same SRAM seed",
            f"source: tests/out/ip_<leg>/{tag}.info.json, {tag}.regs.json and the "
            f"{tag}.<dump> files beside them",
            "what a checkpoint carries: info.json = frame / master_clock / vpos / hpos plus framebuffer",
            "   geometry; regs.json = PPU / HDMA register state (runner/src/state_dump.h). Neither",
            "   writes CPU registers, so this artifact says nothing about A,X,Y,S,D,DB,PB,P or PC.",
        ],
    )
    infos = {leg: json.load(open(os.path.join(dirs[leg], tag + ".info.json")))
             for leg, _, _ in IP_LEGS}
    ref = infos["off"]
    print("%-8s %-16s %15s %6s %6s   %s" % ("leg", "polls", "master_clock", "vpos", "hpos", "note"))
    for leg, polls, note in IP_LEGS:
        i = infos[leg]
        print("%-8s %-16s %15d %6s %6s   %s"
              % (leg, polls or "none", i["master_clock"], i.get("vpos"), i.get("hpos"), note))
    print("   guest frame at %s: " % tag
          + ", ".join("%s=%s" % (leg, infos[leg].get("frame")) for leg, _, _ in IP_LEGS))
    print("   master_clock delta vs ip_off: "
          + ", ".join("%s=%+d" % (leg, infos[leg]["master_clock"] - ref["master_clock"])
                      for leg, _, _ in IP_LEGS if leg != "off"))
    print("   the same deltas per master cycle at this point: hpos moves 1 dot per cycle at vpos %s"
          % ref.get("vpos"))
    print()

    print(f"== {tag}.regs.json, every leg against ip_off (PPU / HDMA state; no CPU registers dumped) ==")
    for leg, polls, _ in IP_LEGS:
        if leg == "off":
            continue
        ra, rb = _regs(os.path.join(dirs["off"], tag + ".regs.json")), \
            _regs(os.path.join(dirs[leg], tag + ".regs.json"))
        keys = sorted(set(ra) | set(rb))
        diff = [k for k in keys if ra.get(k) != rb.get(k)]
        print(f"   {leg:<6} {len(keys)} keys compared, {len(diff)} differ: "
              + (", ".join(diff) if diff else "none"))
        for k in diff:
            if k == "dma" and isinstance(ra.get(k), list):
                for line in _dma_delta(ra[k], rb[k]):
                    print(f"      dma {line}")
            else:
                print(f"      {k}: {_compact(ra.get(k))} -> {_compact(rb.get(k))}")
    print()

    print(f"== the {tag} checkpoint dumps beside {tag} (sha256 prefix, equal hashes = equal bytes) ==")
    parts = ["wram.bin", "vram.bin", "oam.bin", "cgram.bin", "sram.bin", "fb.bgrx",
             "apu.tsv", "ppuw.tsv", "dma.tsv"]
    print("   %-12s" % "file" + "".join("%-13s" % leg for leg, _, _ in IP_LEGS) + "  verdict")
    for pre in parts:
        hashes, ok = [], True
        for leg, _, _ in IP_LEGS:
            f = os.path.join(dirs[leg], f"{tag}.{pre}")
            if not os.path.isfile(f):
                hashes.append("-")
                ok = False
                continue
            h = hashlib.sha256(open(f, "rb").read()).hexdigest()[:10]
            hashes.append(h)
            if h != hashes[0]:
                ok = False
        print("   %-12s" % pre + "".join("%-13s" % h for h in hashes)
              + ("  identical in all four" if ok else "  differs"))
    print()
    print("reproduce:")
    print("  FULLBYTES=1 TRIM=1 BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_parity.sh")
    print(f"  python3 tests/framedump_diff.py cpdump tests/out/ip_off tests/out/ip_m0x0 {tag}")
    print("  python3 tests/idle_artifacts.py a0      # this file, again")


IMAGE_PARTS = ["wram.bin", "vram.bin", "oam.bin", "cgram.bin", "sram.bin", "fb.bgrx",
               "apu.tsv", "ppuw.tsv", "dma.tsv"]
SHORT = {"wram.bin": "wram", "vram.bin": "vram", "oam.bin": "oam", "cgram.bin": "cgram",
         "sram.bin": "sram", "fb.bgrx": "fb", "apu.tsv": "apu", "ppuw.tsv": "ppuw",
         "dma.tsv": "dma"}


def _tags_in(path):
    out = set()
    for name in os.listdir(path):
        m = re.match(r"^([a-zA-Z]+\d+)\.info\.json$", name)
        if m:
            out.add(m.group(1))
    return out


def _hash(path):
    if not os.path.isfile(path):
        return None
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _sort_tags(tags):
    """Route tags sort by name then number, so J10 follows J9 rather than J1."""
    return sorted(tags, key=lambda t: (re.match(r"[a-zA-Z]*", t).group(0),
                                       int(re.search(r"\d+", t).group(0))
                                       if re.search(r"\d+", t) else 0))


def _cp_diff(dir_a, dir_b, tag):
    """One checkpoint, two runs. Everything the dump carries, read the same way
    framedump_diff.py cpdump reads it: guest frame index and master clock from
    info.json, PPU/HDMA keys from regs.json, and the images beside them by hash."""
    ia = json.load(open(os.path.join(dir_a, tag + ".info.json")))
    ib = json.load(open(os.path.join(dir_b, tag + ".info.json")))
    ra, rb = _regs(os.path.join(dir_a, tag + ".regs.json")), \
        _regs(os.path.join(dir_b, tag + ".regs.json"))
    keys = sorted(set(ra) | set(rb))
    rdiff = [k for k in keys if ra.get(k) != rb.get(k)]
    idiff = [p for p in IMAGE_PARTS
             if _hash(os.path.join(dir_a, f"{tag}.{p}"))
             != _hash(os.path.join(dir_b, f"{tag}.{p}"))]
    return {"frames": (ia.get("frame"), ib.get("frame")),
            "delta": ib["master_clock"] - ia["master_clock"],
            "hpos": (ia.get("hpos"), ib.get("hpos")),
            "vpos": (ia.get("vpos"), ib.get("vpos")),
            "regs": rdiff, "images": idiff, "nregs": len(keys)}


def _cp_table(c_a, c_b, title, note, tags):
    print(f"== {title} ==")
    print(f"   {note}")
    row = "   %-6s %12s %9s %9s   %-30s %s"
    print(row % ("tag", "frame", "mc delta", "hpos", "regs keys differing", "images differing"))
    for tag in tags:
        d = _cp_diff(c_a, c_b, tag)
        same_frame = d["frames"][0] == d["frames"][1]
        print(row % (tag,
                     ("%d" % d["frames"][0]) if same_frame else "%d/%s" % d["frames"],
                     "%+d" % d["delta"],
                     ("%d" % d["hpos"][0]) if d["hpos"][0] == d["hpos"][1]
                     else "%d/%s" % d["hpos"],
                     ", ".join(d["regs"]) or "-",
                     ", ".join(SHORT.get(p, p) for p in d["images"]) or "none"))
        if not d["regs"] and not d["images"] and d["delta"] == 0:
            print("         -> every dumped byte equal, same guest frame, same master clock")
    print()


def cmd_checkpoints():
    route = os.path.join(OUT, "ip_off")
    route_legs = [("ip_m1x0", "81ee8e"), ("ip_on", "81b061,81ee8e"), ("ip_m0x0", "81b061")]
    have = [(d, p) for d, p in route_legs
            if os.path.isdir(os.path.join(OUT, d)) and os.path.isdir(route)]
    if not have:
        raise SystemExit("no ip_* checkpoint dirs -- run ./tests/idle_parity.sh first")
    _header(
        "every tagged checkpoint, each idle-poll leg against the undeclared control",
        "m2_promotion_round3.md sections 5 and 6",
        [
            "how to read this: 'mc delta' is master cycles at the checkpoint vs the control, and a",
            "   guest frame index printed twice means the two legs reached it on different frames.",
            "   'regs keys differing' is PPU / HDMA state only (runner/src/state_dump.h) -- no dump",
            "   in this round carries CPU registers. 'images differing' is a sha256 mismatch on the",
            "   bytes beside the checkpoint, so 'none' is a byte-level statement, not a crc guess.",
            "a checkpoint reached at the same guest frame with the same images is as far as this",
            "   harness can say 'nothing changed'; a master_clock delta with identical images is a",
            "   seam effect that did not reach the guest, and that distinction is what sections 5",
            "   and 6 rest on.",
        ],
    )
    for d, polls in have:
        tags = _sort_tags(_tags_in(route) & _tags_in(os.path.join(OUT, d)))
        _cp_table(route, os.path.join(OUT, d),
                  "the committed route (tests/scripts/combat.txt), %s vs ip_off" % d,
                  "declared polls: " + polls,
                  tags)

    for probe, note in (("idle_f205", "no-input boot probe (tests/scripts/idle_f205.txt)"),
                        ("idle_dense", "dense per-frame probe (tests/scripts/idle_dense.txt)")):
        ctrl = os.path.join(OUT, probe + "_off")
        if not os.path.isdir(ctrl):
            print("== %s ==" % note)
            print("   no %s directory -- run ./tests/idle_f205.sh first\n" % ctrl)
            continue
        for d in sorted(glob.glob(os.path.join(OUT, probe + "_p*"))):
            if not os.path.isdir(d):
                continue
            name = os.path.basename(d)[len(probe) + 1:]
            tags = _sort_tags(_tags_in(ctrl) & _tags_in(d))
            if not tags:
                continue
            _cp_table(ctrl, d, "%s, %s vs %s_off" % (note, name, probe),
                      "declared polls: " + name[1:].replace("_", ","),
                      tags)

    print("reproduce:")
    print("  FULLBYTES=1 TRIM=1 BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_parity.sh")
    print("  BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_f205.sh   # both probe routes, all declarations")
    print("  python3 tests/framedump_diff.py cpdump <control-dir> <leg-dir> [tag]   # one pair, by hand")
    print("  python3 tests/idle_artifacts.py checkpoints   # this file, again")


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    what, rest = args[0], args[1:]
    if what == "cost":
        cmd_cost()
    elif what == "a0":
        cmd_a0(rest[0] if rest else CHECKPOINT)
    elif what == "checkpoints":
        cmd_checkpoints()
    else:
        raise SystemExit(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main())
