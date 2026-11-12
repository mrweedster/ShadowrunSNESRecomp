#!/usr/bin/env python3
"""Find the compiled bodies behind the round-5 f1828 gate divergence.

    SNESRECOMP_ROOT=<pin> python3 tests/cluster_ddmin.py [--universe 52]

The candidate tree is the shipped pair plus the rejected $80C1C9 seed
(`tests/cluster_hunt.sh`). It adds 109 AOT bodies over the pair. Demoting all
of them back to the interpreter reproduces the shipped pair exactly; demoting
none reproduces the sweep's divergence (state first differs at f1830). This
driver starts from a known-clean demotion set and removes bodies until no
single one can be put back, i.e. a 1-minimal clean set.

`--universe` is how many of the added AOT bodies (in PC order) to start from.
The recorded run used 52: demoting the first 52 was already observed clean in
the bisection leg `ddinit52`, so the search only had to minimize that set. The
driver re-derives the body lists from the two archived manifests; it does not
read a hand-typed PC list.

Every leg is `tests/cluster_hunt.sh <label> <force-file>`, which regenerates at
the pin, rebuilds, and runs the parity route against `build-r6pair`. The
verdict used for the search is `framedump_diff.py state` (label bytes
excluded), not the label-inclusive per-frame crc32. Both are saved per leg.

Outputs (scratch):
  tests/out/r6/forces_all.txt       109 added AOT bodies
  tests/out/r6/forces_firstN.txt    the universe
  tests/out/r6/hunt.tsv             one row per leg (label, bodies, exe, crc, state)
  tests/out/r6/minimal.txt          the 1-minimal clean demotion set
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests/out/r6")


def manifest(path):
    opener = open
    import bz2
    if path.endswith(".bz2"):
        opener = bz2.open
    with opener(path) as f:
        return json.load(f)


def added_aot(pair_man, cand_man):
    p = set(pair_man["nodes"])
    return [pc.split(":")[0].upper() for pc in sorted(set(cand_man["nodes"]) - p)
            if cand_man["nodes"][pc]["disposition"] == "aot_eligible"]


def test(pin, label, subset):
    path = os.path.join(OUT, f"forces_{label}.txt")
    with open(path, "w") as f:
        for pc in subset:
            f.write(f"force_lle {pc}\n")
    env = dict(os.environ, SNESRECOMP_ROOT=pin)
    p = subprocess.run(["./tests/cluster_hunt.sh", label, path], cwd=ROOT,
                       env=env, capture_output=True, text=True)
    out = p.stdout + p.stderr
    if p.returncode != 0:
        sys.exit(f"leg {label} failed:\n{out[-3000:]}")
    state = next((l.split(":", 1)[1].strip() for l in out.splitlines()
                  if l.startswith("   state:")), "")
    clean = "no non-label WRAM byte differs" in state
    print(f"[{label}] n={len(subset)} clean={clean} {state}", flush=True)
    return clean


def split(lst, n):
    out, start = [], 0
    for i in range(n):
        end = start + len(lst) // n + (1 if i < len(lst) % n else 0)
        out.append(lst[start:end])
        start = end
    return [c for c in out if c]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--universe", type=int, default=52)
    args = ap.parse_args()
    pin = os.environ.get("SNESRECOMP_ROOT", "")
    if not os.path.isfile(os.path.join(pin, "snesrecomp_cli.py")):
        sys.exit("SNESRECOMP_ROOT must point at the pinned framework checkout")
    os.makedirs(OUT, exist_ok=True)

    pair = manifest(os.path.join(ROOT, "tests/out/r4/manifest_r6pair.json.bz2"))
    cand = manifest(os.path.join(ROOT, "tests/out/r4/manifest_r6pc1c9.json.bz2"))
    allb = added_aot(pair, cand)
    with open(os.path.join(OUT, "forces_all.txt"), "w") as f:
        for pc in allb:
            f.write(f"force_lle {pc}\n")
    universe = allb[:args.universe]
    with open(os.path.join(OUT, f"forces_first{args.universe}.txt"), "w") as f:
        for pc in universe:
            f.write(f"force_lle {pc}\n")
    print(f"added AOT bodies: {len(allb)}; universe: {len(universe)}")

    if not test(pin, f"ddinit{args.universe}", universe):
        sys.exit("universe is not clean: pick a different starting set")
    if test(pin, "ddinit0", []):
        sys.exit("the empty demotion set is clean: nothing to search")

    c = list(universe)
    n = 2
    step = 0
    while len(c) >= 2:
        reduced = False
        for ch in split(c, min(n, len(c))):
            step += 1
            if test(pin, f"dd{step:02d}", [x for x in c if x not in ch]):
                c = [x for x in c if x not in ch]
                n = max(n - 1, 2)
                reduced = True
                break
        if not reduced:
            if n >= len(c):
                break
            n = min(2 * n, len(c))
        print(f"  -> c={len(c)} n={n}", flush=True)

    print("minimal clean set:", " ".join(c))
    with open(os.path.join(OUT, "minimal.txt"), "w") as f:
        f.write("\n".join(c) + "\n")
    for pc in c:
        if test(pin, f"verify_{pc}", [x for x in c if x != pc]):
            sys.exit(f"{pc} is not needed: set is not 1-minimal")
    print("each body is necessary: removing either from the set is dirty")


if __name__ == "__main__":
    main()
