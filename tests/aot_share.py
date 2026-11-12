#!/usr/bin/env python3
"""Bind a measured AOT/LLE dispatch share to the program that produced it.

Why this exists: the dispatch share is the headline extraction-progress number
(what fraction of the run's cycles were served by compiled code), but until now
it only ever appeared inside cross-path logs — attached to no file, with no
hash of the executable or the generated set behind it. A share quoted without
its program is unfalsifiable, which is how a "fully LLE" control tree could
report 0 % AOT while carrying 133 compiled bank functions: the LLE-ness lives
in the generated set that was compiled in, not in any switch you can see today.

So a recorded share carries the same provenance the frame-buffer comparisons
carry (tests/provenance.py): executable hash, generated-set digest, framework
revision — plus the counters that make a difference readable, and three proofs
a claim can be checked against:

  coverage proof   every wrapper src/gen declares, checked against the symbols
                   actually present in this executable (nm): a generated body
                   that did not link in can never be dispatched to;
  frame proof      which frame service produced a --framedump directory (the
                   runtime announces it in its breadcrumb list), plus a hash
                   over that directory's frame buffers, so the frames in the
                   directory are bound to this run and this binary;
  trace proof      with --cart-trace, the cart-trace dump's size and sha256
                   bound into the same record.

Usage:
  python3 tests/aot_share.py <binary> [--dump-dir DIR] [--cart-trace PATH]
                       [--gen-root .] [--json OUT]
      reads <binary>/../last_run_report.json (the runner's exe-dir anchor).

  python3 tests/aot_share.py --pair A.json B.json
      compare two recorded shares: same inputs, same share?

Exit codes: 0 ok; 1 a claim failed (declared wrappers missing from the binary,
a named dump missing, no run report); 2 usage.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance as prov  # noqa: E402  (same directory as this file)

SCHEMA = "snesrecomp.aot-share.v1"


def wrapper_names(gen_dir):
    """The function names src/gen declares as dispatchable bodies."""
    out = set()
    pat = re.compile(r"^void ([A-Za-z0-9_]+)\(CpuState \*cpu\) \{")
    for name in sorted(os.listdir(gen_dir)):
        if not name.endswith(".c"):
            continue
        for line in open(os.path.join(gen_dir, name), errors="replace"):
            m = pat.match(line)
            if m:
                out.add(m.group(1))
    return out


def binary_symbols(binary):
    try:
        r = subprocess.run(["nm", binary], capture_output=True, text=True,
                           check=False)
    except FileNotFoundError:
        return None
    names = set()
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3:
            names.add(parts[-1].lstrip("_"))
    return names or None


def report(binary, dump_dir=None, gen_root=".", cart_trace_path=None):
    binary = os.path.abspath(binary)
    missing_trace = None
    gen_dir = os.path.join(gen_root, "src", "gen")
    p = prov.provenance(binary)
    # The set the coverage claim is measured against, by digest. ./src/gen is one
    # shared directory, so a build tree's own set only survives as an archive --
    # name it here and the claim stays checkable after the next regeneration.
    measured = prov.generated_set(gen_root) if os.path.isdir(gen_dir) else None
    declared = wrapper_names(gen_dir) if os.path.isdir(gen_dir) else set()
    syms = binary_symbols(binary)
    missing = sorted(n for n in declared if syms is not None and n not in syms)
    entered = sorted(n for n in declared if syms is not None and n in syms)

    rec_path = os.path.join(os.path.dirname(binary), "last_run_report.json")
    run = None
    if os.path.isfile(rec_path):
        try:
            run = json.load(open(rec_path))
        except ValueError:
            run = None
    share = (run or {}).get("execution_share") or {}
    crumbs = [e.get("msg", "") for e in
              ((run or {}).get("breadcrumbs") or {}).get("events", [])]
    frame_service = next((m for m in crumbs
                          if "frame service: implementation" in m), None)

    trace = None
    if cart_trace_path:
        if os.path.isfile(cart_trace_path):
            trace = {"path": os.path.abspath(cart_trace_path),
                     "bytes": os.path.getsize(cart_trace_path),
                     "sha256": prov._sha256_file(cart_trace_path)}
        else:
            missing_trace = cart_trace_path

    out = {
        "schema": SCHEMA,
        "binary": binary,
        "exe": p["exe"],
        "generated_set": p.get("generated_set"),
        "framework": p.get("framework"),
        "build_tree": p.get("build_tree"),
        "execution_share": share or None,
        "coverage": {
            "wrappers_declared": len(declared),
            "wrappers_in_binary": len(entered),
            "wrappers_missing_from_binary": missing,
            "nm_available": syms is not None,
            "measured_against": {
                "root": os.path.abspath(gen_root),
                "generated_set_sha256": (measured or {}).get("sha256"),
                "units": (measured or {}).get("units"),
            },
        },
        "frame_service": frame_service,
        "dump_dir": None,
        "cart_trace": trace,
    }
    problems = []
    if not share:
        problems.append(f"no execution_share in {rec_path}: was this ever run?")
    if missing:
        problems.append(f"{len(missing)} generated wrapper(s) are not symbols "
                        f"in this executable, e.g. {', '.join(missing[:4])}: "
                        "the dispatch table cannot reach them")
    if missing_trace:
        problems.append(f"--cart-trace {missing_trace}: no such file, so this "
                        "record cannot bind a trace to this run")
    if dump_dir:
        fbs = sorted(f for f in os.listdir(dump_dir) if f.endswith(".fb.bmp"))
        if not fbs:
            problems.append(f"no frame buffers in {dump_dir}")
        else:
            out["dump_dir"] = {
                "path": os.path.abspath(dump_dir),
                "frames": len(fbs),
                "frame_bytes_sha256": hashlib.sha256(b"".join(
                    prov._sha256_file(os.path.join(dump_dir, f)).encode()
                    for f in fbs)).hexdigest(),
                "manifest": os.path.isfile(
                    os.path.join(dump_dir, "run_manifest.json")),
            }
    out["problems"] = problems
    return out


def main():
    ap = argparse.ArgumentParser(
        description="bind an AOT/LLE dispatch share to its program")
    ap.add_argument("binary", nargs="?", help="the executable to inspect")
    ap.add_argument("--dump-dir", help="its --framedump directory")
    ap.add_argument("--cart-trace", help="the cart-trace dump this run wrote")
    ap.add_argument("--gen-root", default=".", help="project root with src/gen")
    ap.add_argument("--json", help="write the record here")
    ap.add_argument("--pair", nargs=2, metavar=("A", "B"),
                    help="compare two recorded share json files")
    a = ap.parse_args()

    if a.pair:
        x, y = (json.load(open(p)) for p in a.pair)
        # "Same inputs" has to mean the machine code each binary was linked from.
        # The top-level generated_set is whatever ./src/gen held at record time,
        # which two trees built from different sets can both report; the set the
        # coverage claim was measured against is the one that identifies the program.
        def set_id(d):
            ma = (d.get("coverage") or {}).get("measured_against") or {}
            return (ma.get("generated_set_sha256")
                    or (d.get("generated_set") or {}).get("sha256"))
        same = (set_id(x) == set_id(y)
                and prov._fw_id(x["framework"]) == prov._fw_id(y["framework"]))
        print(f"same inputs   : {'yes' if same else 'no'}")
        for tag, d in (("A", x), ("B", y)):
            s = d["execution_share"]
            live = (d.get("generated_set") or {}).get("sha256") or ""
            meas = set_id(d) or ""
            extra = "" if meas == live else \
                f"   (linked set {meas[:16]}, live src/gen was {live[:16]})"
            print(f"share {tag}    : aot {s.get('aot_cycle_pct')} % of cycles, "
                  f"{s.get('interp_insns'):,} interp insns, "
                  f"exe sha {d['exe']['sha256'][:16]}{extra}")
        return 0

    if not a.binary:
        ap.error("give a binary, or --pair two recorded shares")
    r = report(a.binary, a.dump_dir, a.gen_root, a.cart_trace)
    gs, fw, s = r["generated_set"], r["framework"], r["execution_share"] or {}
    print(f"== AOT/LLE dispatch share: {r['binary']}")
    print(f"   exe    sha256 {r['exe']['sha256'][:16]}  {r['exe']['bytes']:,} B")
    print(f"   gen    {gs['units']} units, {gs['promoted_functions']} promoted "
          f"functions, {gs['dispatch_entries']} dispatch entries, "
          f"sha256 {gs['sha256'][:16]}")
    print(f"   fw     {prov._fw_id(fw)}")
    if s:
        print(f"   share  AOT {s.get('aot_cycle_pct')} % of cycles "
              f"(interp {s.get('interp_cycle_pct')} %), "
              f"{s.get('interp_insns'):,} interp insns by frame "
              f"{s.get('frame'):,}")
    print(f"   coverage {r['coverage']['wrappers_in_binary']}/"
          f"{r['coverage']['wrappers_declared']} generated wrappers present "
          f"in this binary")
    print(f"   frames   {r['frame_service'] or 'no frame-service breadcrumb'}")
    if r["dump_dir"]:
        d = r["dump_dir"]
        print(f"   dump     {d['frames']} frames in {d['path']}  frame-bytes "
              f"sha256 {d['frame_bytes_sha256'][:16]}  "
              f"run_manifest={'yes' if d['manifest'] else 'NO'}")
    if r["cart_trace"]:
        t = r["cart_trace"]
        print(f"   trace    {t['path']}  {t['bytes']:,} B  "
              f"sha256 {t['sha256'][:16]}")
    for w in r["problems"]:
        print(f"   WARN     {w}")
    if a.json:
        os.makedirs(os.path.dirname(a.json) or ".", exist_ok=True)
        with open(a.json, "w") as f:
            json.dump(r, f, indent=1, sort_keys=True)
        print(f"   wrote    {a.json}")
    return 1 if r["problems"] else 0


if __name__ == "__main__":
    main()
