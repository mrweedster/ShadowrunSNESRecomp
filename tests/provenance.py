#!/usr/bin/env python3
"""Bind a --framedump run to the program that made it.

    provenance.py record <binary> <dump-dir>   write <dump-dir>/run_manifest.json
    provenance.py show <dump-dir|manifest>     print one leg's manifest
    provenance.py key <dump-dir|manifest>      the comparison key, one line
    provenance.py same <leg> <leg>             are these the same program?
    provenance.py same-src <leg> <leg>         same inputs, ignoring the
                                               executable's own bytes
    provenance.py pin [--exact|--descendant] <binary|build-tree|framework-root>...
                                               is this tree the pinned framework?

    <leg> is a --framedump directory or a manifest path. Exit codes: record is
    0 unless the binary is unreadable; same / same-src are 0 identical, 1
    different, 2 one side has no manifest; show and key are 0; pin is 0 when
    every argument passes, 1 when any does not, 2 when the pin cannot be read.

Why this exists. A --framedump run leaves behind thousands of frame files and
nothing that says which executable wrote them, and a recorded baseline in
tests/baselines names a pair of scratch paths under tests/out that any later
build overwrites. So "is this new difference the known cross-path effect, or a
different program?" becomes archaeology. It already cost one round: the staged
./Shadowrun disagrees with every build the current tree makes from frame 1
(evidence/c1_staged_bundle_stale.md), and the tree called ./build was compiled
against 4 generated files while src/gen carried 17. Neither was visible from the
artefacts.

Plain language, then numbers. The manifest records three things that together
identify a build:

  1. the executable itself -- sha256 and size;
  2. the generated machine code it was compiled from -- a hash over src/gen,
     plus the counts that make a difference readable (translation units,
     promoted guest functions, dispatch-table entries);
  3. the framework checkout it linked -- path and git revision, plus the build
     type and the ROM-free flag, because those change behaviour too.

`key_of` is (1)+(2)+(3) with paths dropped: two build trees in different
directories, built from the same sources, are the same program. `source_key_of`
is the same without (1) -- the question "are these the same *inputs*?", which is
what a recorded baseline is judged on, because rebuilding the same sources must
not turn into a new verdict.

Two staleness checks come along for free, and both are the failure mode above:

  - `gen_objects_compiled` != `units`: the tree's own object files cover fewer
    generated units than the sources on disk, so that tree predates the current
    generated set (./build: 4 objects against 17 units);
  - `sources_newer_than_binary`: any generated file touched after the executable
    was linked. `cp -p` of a restored generated file keeps the older mtime, so
    cmake will not recompile it -- this catches the other direction too.

A binary with no CMakeCache.txt beside it (a staged bundle, or a copy parked in
tests/out) still gets an executable fingerprint; the build-tree sections say
"unknown" rather than guessing, and that unknown is itself the finding.

A third check, `pin`, answers what the manifest cannot: is the framework a tree
linked against the revision `framework_pins.txt` claims? Its absence cost a
measurement. A control build tree configured against a *copy* of the framework
reported `framework=unknown`, which reads as "the pin, just un-nameable" -- and
was read that way. Hashing that copy's files says otherwise: its
`runner/src/snes/interp_bridge.c` blob (`98fb3b69`) is the pre-image the pin
(`773285b8`) replaced, so that control ran a framework from before the pin.
`pin` refuses that case rather than recording it.

One measured fact makes the executable hash worth using at all: two build trees,
configured at different times from the same framework root, the same src/gen and
the same flags, produced sha256-identical executables (build-embed against
build-embed2, 7eb8008d...). A different hash therefore means a different input,
not a different link.
"""
import hashlib
import json
import os
import subprocess
import sys

MANIFEST = "run_manifest.json"
SCHEMA = 1


def _sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _git(root, *args):
    """git output for `root`, or None if it is not a repository."""
    try:
        r = subprocess.run(["git", "-C", root, *args], capture_output=True,
                           text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip()


def _cmake_cache(tree):
    """The handful of CMakeCache.txt entries that identify a build tree."""
    p = os.path.join(tree, "CMakeCache.txt")
    if not os.path.isfile(p):
        return None
    want = ("CMAKE_BUILD_TYPE", "SNESRECOMP_ROOT", "CMAKE_HOME_DIRECTORY",
            "SHADOWRUN_EMBED_ROM", "SNESRECOMP_BUILD_VERSION")
    out = {}
    for line in open(p, errors="replace"):
        key, _, val = line.strip().partition("=")
        key = key.split(":")[0]
        if key in want:
            out[key] = val
    return out


def generated_set(root):
    """Fingerprint of the generated machine code in `<root>/src/gen`.

    Hash over name + bytes of every file, sorted, so a rename or a changed
    count shows up. The counts are here because a hash alone says "different"
    and nothing about how: 17 units / 205 promoted functions / 217 dispatch
    entries is what makes a delta readable in one line.
    """
    gen = os.path.join(root, "src", "gen")
    if not os.path.isdir(gen):
        return None
    names = sorted(e for e in os.listdir(gen)
                   if os.path.isfile(os.path.join(gen, e)))
    h = hashlib.sha256()
    for n in names:
        h.update(n.encode())
        h.update(b"\0")
        with open(os.path.join(gen, n), "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        h.update(b"\0")
    units = [n for n in names if n.endswith(".c")]
    funcs = entries = 0
    for n in units:
        for line in open(os.path.join(gen, n), errors="replace"):
            if line.startswith("void bank_"):
                funcs += 1
            elif line.startswith("    { 0x"):
                entries += 1
    return {"sha256": h.hexdigest(), "units": len(units),
            "promoted_functions": funcs, "dispatch_entries": entries,
            "files": len(names)}


def provenance(binary):
    """Everything this script can prove about `binary`, as a dict."""
    binary = os.path.abspath(binary)
    exe = {"path": binary, "bytes": os.path.getsize(binary),
           "sha256": _sha256_file(binary)}
    out = {"schema": SCHEMA, "exe": exe, "build_tree": None, "framework": None,
           "generated_set": None, "port_git": None, "warnings": []}

    tree = os.path.dirname(binary)
    cache = _cmake_cache(tree)
    if cache is None:
        out["warnings"].append(
            "no CMakeCache.txt beside the executable: this is a staged or "
            "copied binary, so the framework and generated set behind it are "
            "unknown from the artefact alone")
        return out

    out["build_tree"] = {"dir": tree, "config": cache.get("CMAKE_BUILD_TYPE"),
                         "embed_rom": cache.get("SHADOWRUN_EMBED_ROM"),
                         "build_version": cache.get("SNESRECOMP_BUILD_VERSION")
                                         or "(derived from VERSION)"}
    home = cache.get("CMAKE_HOME_DIRECTORY")
    if home and os.path.isdir(home):
        rev = _git(home, "rev-parse", "HEAD")
        dirty = _git(home, "status", "--porcelain")
        out["port_git"] = {"root": home, "rev": rev,
                           "dirty": bool(dirty) if dirty is not None else None}
        gs = generated_set(home)
        out["generated_set"] = gs
        objs = os.path.join(tree, "CMakeFiles",
                            os.path.basename(binary) + ".dir", "src", "gen")
        n_obj = len([e for e in os.listdir(objs)
                     if e.endswith(".o")]) if os.path.isdir(objs) else None
        out["build_tree"]["gen_objects_compiled"] = n_obj
        if gs:
            # src/gen is a single shared directory: whoever regenerated last
            # owns it, and a build tree configured from an older regeneration
            # keeps linking the older units. A leg can therefore be digesting a
            # generated set it was not compiled from -- label it, because a
            # digest printed without this flag reads as a fact about the binary.
            gs["describes_this_binary"] = (n_obj is not None
                                           and n_obj == gs["units"])
        if gs and n_obj is not None and n_obj != gs["units"]:
            out["warnings"].append(
                f"stale build tree: {n_obj} generated .o against "
                f"{gs['units']} generated units in {home}/src/gen")
        if gs:
            link = os.path.getmtime(binary)
            newer = [n for n in os.listdir(os.path.join(home, "src", "gen"))
                     if os.path.getmtime(os.path.join(home, "src", "gen", n))
                     > link + 1]
            out["build_tree"]["sources_newer_than_binary"] = len(newer)
            if newer:
                out["warnings"].append(
                    f"{len(newer)} generated file(s) touched after this "
                    "executable was linked: the binary may not contain them")
    else:
        out["warnings"].append(
            f"CMakeCache.txt names no readable source directory ({home})")

    fw = cache.get("SNESRECOMP_ROOT")
    if fw and os.path.isdir(fw):
        rev = _git(fw, "rev-parse", "HEAD")
        dirty = _git(fw, "status", "--porcelain")
        out["framework"] = {"root": fw, "rev": rev,
                            "dirty": bool(dirty) if dirty is not None else None}
        if rev is None:
            out["warnings"].append(
                f"framework root {fw} is not a git checkout, so its revision "
                "cannot be named -- only its files can be hashed")
    else:
        out["warnings"].append(f"CMakeCache.txt names no readable SNESRECOMP_ROOT ({fw})")
    return out


def key_of(prov):
    """The part of a manifest that says *which program* this was.

    Paths are deliberately left out: the same sources built in two directories
    must compare equal, or every scratch copy of a build is a new program. The
    executable hash is in here because this is the strict question -- "did the
    same bytes run both legs" -- and the build was measured to answer it: two
    trees configured at different times from the same framework root, the same
    src/gen and the same flags produced sha256-identical executables
    (build-embed against build-embed2, 7eb8008d...). So a different hash means
    a different input, not a different link.

    `source_key_of` is the same thing without that hash, for judging a rerun
    against a recorded baseline: rebuilding the same sources is allowed to
    change nothing about the verdict.
    """
    gs, fw, bt = prov.get("generated_set"), prov.get("framework"), prov.get("build_tree")
    k = {
        "gen_sha256": gs["sha256"] if gs else None,
        "gen_units": gs["units"] if gs else None,
        "gen_functions": gs["promoted_functions"] if gs else None,
        "gen_dispatch": gs["dispatch_entries"] if gs else None,
        "framework": _fw_id(fw),
        "config": bt["config"] if bt else None,
        "embed_rom": bt["embed_rom"] if bt else None,
    }
    k["exe_sha256"] = prov["exe"]["sha256"]
    return k


def source_key_of(prov):
    """Identity of the *inputs*: framework, generated set, build options."""
    return {k: v for k, v in key_of(prov).items() if k != "exe_sha256"}


def _fw_id(fw):
    """One field, one cause: `rev`, `rev-dirty`, or `unknown`.

    A pristine copy of the pinned sources is not a git checkout, so its revision
    genuinely cannot be named from the artefact. `unknown` is that finding, not a
    bug to paper over -- and it is not a substitute for a pin check: a copy is
    only as current as the day it was copied. `cmd_pin` is the check.
    """
    if not fw or not fw.get("rev"):
        return "unknown"
    return fw["rev"] + ("-dirty" if fw.get("dirty") else "")


PINS_FILE = "framework_pins.txt"


def pinned_rev(name="snesrecomp"):
    """The framework revision this port claims to build against, or None.

    Read from framework_pins.txt rather than hardcoded, so the check follows a
    pin bump instead of arguing with it -- and refuses to pass a tree that does
    not match whatever that file now says.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, PINS_FILE)
    if not os.path.isfile(path):
        return None
    for line in open(path, errors="replace"):
        key, _, val = line.strip().partition("=")
        if key == name:
            return val.strip()
    return None


def framework_root(what):
    """The framework source tree `what` was built against, or None.

    `what` may be an executable, a build tree with a CMakeCache.txt, or a
    framework root itself, so the question can be asked before anything is built.
    """
    path = os.path.abspath(what)
    if os.path.isfile(path):
        path = os.path.dirname(path)
    cache = _cmake_cache(path)
    if cache:
        return cache.get("SNESRECOMP_ROOT") or None
    if os.path.isfile(os.path.join(path, "runner", "runner.cmake")):
        return path
    return None


def cmd_pin(targets, mode="exact"):
    """Do these build trees link the framework this port is pinned to?"""
    pin = pinned_rev()
    if not pin:
        print(f"no {PINS_FILE} entry for snesrecomp: cannot check a pin",
              file=sys.stderr)
        return 2
    bad = 0
    for what in targets:
        fw = framework_root(what)
        if not fw or not os.path.isdir(fw):
            print(f"NOT THE PIN  {what}: no framework root named by its build "
                  "tree -- a staged or copied binary")
            bad += 1
            continue
        rev = _git(fw, "rev-parse", "HEAD")
        if rev is None:
            print(f"UNKNOWN      {what}: framework root {fw} is not a git "
                  "checkout, so its revision cannot be named. A copy is not a "
                  "control: build the control from a checkout of the pin "
                  f"(git worktree add <dir> {pin[:12]})")
            bad += 1
            continue
        dirty = bool(_git(fw, "status", "--porcelain"))
        if rev == pin and not dirty:
            print(f"AT THE PIN   {what}: {fw} @ {rev}")
        elif rev == pin:
            print(f"NOT THE PIN  {what}: {fw} @ {rev} but the tree is dirty -- "
                  "unrecorded edits are not the pin")
            bad += 1
        elif (mode == "descendant"
              and _git(fw, "merge-base", "--is-ancestor", pin, "HEAD") is not None):
            print(f"OFF THE PIN  {what}: {fw} @ {rev}, with {pin[:12]} as an "
                  "ancestor -- a branch off the pin, fine for a capability leg")
        else:
            print(f"NOT THE PIN  {what}: {fw} @ {rev}, pin is {pin}")
            bad += 1
    return 1 if bad else 0


def _one_line(key):
    def short(v):
        return v[:12] if isinstance(v, str) and len(v) > 12 else v
    return "  ".join(f"{k}={short(v)}" for k, v in key.items())


def load(what):
    """A manifest from a dump directory, a manifest path, or None."""
    p = what
    if os.path.isdir(what):
        p = os.path.join(what, MANIFEST)
    if not os.path.isfile(p):
        return None
    try:
        return json.load(open(p))
    except ValueError:
        return None


def cmd_record(binary, dump_dir):
    if not os.path.isfile(binary) or not os.access(binary, os.X_OK):
        print(f"not an executable: {binary}", file=sys.stderr)
        return 1
    os.makedirs(dump_dir, exist_ok=True)
    prov = provenance(binary)
    path = os.path.join(dump_dir, MANIFEST)
    json.dump(prov, open(path, "w"), indent=1)
    print(f"manifest: {path}")
    print(f"  exe    sha256 {prov['exe']['sha256'][:16]}  "
          f"{prov['exe']['bytes']:,} B")
    bt, fw, gs = prov["build_tree"], prov["framework"], prov["generated_set"]
    if bt:
        print(f"  tree   {bt['dir']}  config={bt['config']} "
              f"embed={bt['embed_rom']} gen_objects={bt['gen_objects_compiled']}")
    if gs:
        stale = ""
        if not gs.get("describes_this_binary", True):
            stale = "   <-- NOT this binary's set (linked from {} .o)".format(
                bt["gen_objects_compiled"] if bt else "?")
        print(f"  gen    {gs['units']} units, {gs['promoted_functions']} promoted "
              f"functions, {gs['dispatch_entries']} dispatch entries, "
              f"sha256 {gs['sha256'][:16]}{stale}")
    if fw:
        print(f"  fw     {fw['root']}  rev={fw['rev']} dirty={fw['dirty']}")
    for w in prov["warnings"]:
        print(f"  WARN   {w}")
    return 0


def cmd_show(what):
    prov = load(what)
    if prov is None:
        print(f"no {MANIFEST} at {what}", file=sys.stderr)
        print("record it: python3 tests/provenance.py record <binary> <dump-dir>",
              file=sys.stderr)
        return 2
    print(json.dumps(prov, indent=1))
    return 0


def cmd_key(what):
    prov = load(what)
    if prov is None:
        print(f"no {MANIFEST} at {what}", file=sys.stderr)
        return 2
    print(_one_line(key_of(prov)))
    return 0


def diff_keys(a, b):
    """Field names where two keys disagree."""
    return [k for k in sorted(set(a) | set(b))
            if a.get(k) != b.get(k)]


def cmd_same(x, y, sources=False):
    keyf = source_key_of if sources else key_of
    ka, kb = _key_or_none(x, keyf), _key_or_none(y, keyf)
    if ka is None or kb is None:
        for w, side in ((x, "first"), (y, "second")):
            if load(w) is None:
                print(f"no manifest for the {side} leg: {w}")
        print("VERDICT: no provenance recorded -- cannot say whether these are "
              "the same program")
        return 2
    d = diff_keys(ka, kb)
    what = "same inputs" if sources else "same program"
    if not d:
        print(f"{what}: " + _one_line(ka))
        return 0
    print(f"different {'inputs' if sources else 'program'}")
    for f in d:
        print(f"  {f}: {ka.get(f)}  !=  {kb.get(f)}")
    return 1


def _key_or_none(what, keyf=key_of):
    prov = load(what)
    return keyf(prov) if prov else None


def main():
    a = sys.argv[1:]
    if len(a) == 3 and a[0] == "record":
        raise SystemExit(cmd_record(a[1], a[2]))
    if len(a) == 2 and a[0] in ("show", "key"):
        raise SystemExit({"show": cmd_show, "key": cmd_key}[a[0]](a[1]))
    if len(a) == 3 and a[0] in ("same", "same-src"):
        raise SystemExit(cmd_same(a[1], a[2], a[0] == "same-src"))
    if a[:1] == ["pin"]:
        rest, mode = a[1:], "exact"
        if rest and rest[0] in ("--exact", "--descendant"):
            mode = rest.pop(0)[2:]
        if not rest:
            raise SystemExit(__doc__)
        raise SystemExit(cmd_pin(rest, mode))
    raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
