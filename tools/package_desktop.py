#!/usr/bin/env python3
"""Stage a built Shadowrun desktop tree as a portable release archive.

This is the cross-platform sibling of ``scripts/package_macos_bundle.sh``:
that one exists because a macOS release is a signed ``.app`` inside a ``.dmg``
and has rules of its own. Windows and Linux releases are a folder a player
extracts and runs, so this tool stages exactly the files the host reads
beside the executable, writes a README that travels with them, and seals the
folder as a ``.zip`` (Windows) or ``.tar.gz`` (Linux).

It does not build and it does not sign. Point it at a build directory --
the build root on Linux/macOS, the same root on Windows with the Visual
Studio build under Release/ (both are found):

    python3 tools/package_desktop.py --build build --platform linux-x64
    python tools/package_desktop.py --build build-windows-x64 --platform windows-x64
    python tools/package_desktop.py --build build-embed \
        --platform windows-x64 --personal
    python3 tools/package_desktop.py --build build-linux-x64-de \
        --platform linux-x64 --edition de

The edition comes from the build tree's CMakeCache: a default (universal)
tree is packaged as a multi-edition archive, and a single-edition tree as
that edition. ``--edition us|de|sv|universal`` overrides the guess and is
refused when it disagrees with the tree, so an archive cannot be labelled
for a dump its executable would reject. A universal archive gains
``-universal`` in its stem and lists every dump it accepts; a single-edition
one gains ``-de`` / ``-sv`` and names its one dump.

Shareable packages contain no ROM. The player supplies their own dump on
first run; the host verifies it against the matching rom_identity*.txt.
``--personal`` is for a build made with ``-DSHADOWRUN_EMBED_ROM=ON``, where
the image is already inside the executable: that archive is a copy of the
game and must not be redistributed. An embedded-ROM build is single-edition
by construction, so ``--personal --edition universal`` is refused.

The tool is deliberately stdlib-only, so it runs on the same three platforms
it packages for. It always writes ``<archive>.sha256`` and, when the packaged
executable can run on this machine, checks that it answers ``--help`` from
the staged folder (the host runs without a display for that path).
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import os
import pathlib
import platform as host_platform_module
import shutil
import subprocess
import sys
import tarfile
import zipfile
from typing import NoReturn

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_EXE = "ShadowrunSNESRecomp"

# Names the host reads exe-relative and a package should carry when the build
# staged them. Missing ones are simply skipped: a tree without mods is valid.
RUNTIME_DIRS = ("mods", "assets")

# One row per ROM edition this project knows. The identity file is the source
# of the ROM's display name and filename, so the README a player opens names
# the dump that build actually accepts.
EDITIONS = {
    "us": ("rom_identity.txt", "USA"),
    "de": ("rom_identity.de.txt", "German"),
    "sv": ("rom_identity.sv.txt", "Swedish"),
}
UNIVERSAL = "universal"


def read_identity(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip().lower()] = value.strip().strip('"')
    return values


def read_cmake_cache(build: pathlib.Path) -> dict[str, str]:
    """The build's cache as plain key -> value, or {} when there is none."""
    cache = build / "CMakeCache.txt"
    if not cache.is_file():
        return {}
    values: dict[str, str] = {}
    try:
        text = cache.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    for line in text.splitlines():
        if not line or line.startswith(("//", "#")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        # CMake writes "NAME:TYPE=value"; the type is noise here.
        values[key.split(":", 1)[0].strip()] = value.strip()
    return values


def cache_flag(values: dict[str, str], key: str) -> bool:
    return values.get(key, "").upper() in ("ON", "TRUE", "1", "YES")


def tree_edition_config(build: pathlib.Path) -> tuple[bool, list[str]] | None:
    """What a build tree was configured for: (universal, edition tags).

    None means the tree records no edition settings, so the caller's explicit
    --edition is all there is to go on. The default build is universal, and
    CMake reduces SHADOWRUN_EDITIONS to the single edition when
    SHADOWRUN_UNIVERSAL=OFF, so those two keys identify the tree.
    """
    values = read_cmake_cache(build)
    if "SHADOWRUN_EDITIONS" not in values and "SHADOWRUN_EDITION" not in values:
        return None

    listed = [tag.strip() for tag in values.get("SHADOWRUN_EDITIONS", "").split(";")
              if tag.strip() in EDITIONS]
    single = values.get("SHADOWRUN_EDITION", "").strip()

    if cache_flag(values, "SHADOWRUN_UNIVERSAL") and len(listed) > 1:
        return True, listed
    # SHADOWRUN_EDITIONS is authoritative for a one-edition tree too: CMake
    # leaves it at SHADOWRUN_EDITION's value when universal is OFF, and a
    # universal build narrowed to one edition (us or de) still lists that tag
    # there while SHADOWRUN_EDITION keeps its default.
    if len(listed) == 1:
        return False, listed
    if single in EDITIONS:
        return False, [single]
    return None


def edition_rows(tags: list[str]) -> list[dict[str, str]]:
    """The identity facts a README or BUILD_INFO needs, per edition tag."""
    rows: list[dict[str, str]] = []
    for tag in tags:
        identity_file, label = EDITIONS[tag]
        identity = read_identity(ROOT / identity_file)
        rows.append({
            "tag": tag,
            "label": label,
            "identity_file": identity_file,
            "rom_file": identity.get("rom_file") or f"Shadowrun ({label}).sfc",
            "sha256": identity.get("expected_sha256", ""),
        })
    return rows


def edition_heading(rows: list[dict[str, str]], universal: bool) -> str:
    if universal:
        return ("Editions: "
                + ", ".join(f"{row['label']} ({row['rom_file']})" for row in rows))
    row = rows[0]
    return f"Edition: {row['label']} ({row['rom_file']})"


# Shared libraries that can sit beside a binary and must travel with it. The
# framework builds SDL3 statically (runner.cmake forces SDL_SHARED=OFF), so in
# practice this list is empty; it exists so a tree built against a shared SDL
# is packaged correctly rather than silently broken.
LIB_PATTERNS = ("*.dll", "*.so", "*.so.*", "*.dylib")


def fail(message: str) -> NoReturn:
    print(f"package_desktop.py: {message}", file=sys.stderr)
    raise SystemExit(1)


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def version_from_tree() -> str:
    value = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if not value:
        fail("VERSION is empty")
    return value


def framework_pins() -> str:
    path = ROOT / "framework_pins.txt"
    if not path.is_file():
        return "(not recorded)"
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()
             if line.strip() and not line.lstrip().startswith("#")]
    return ", ".join(lines) if lines else "(not recorded)"


def host_platform() -> str:
    system = sys.platform
    machine = host_platform_module.machine()
    if system.startswith("darwin"):
        return f"macos-{machine}"
    if system.startswith("win"):
        return "windows-x64" if machine.lower() in ("amd64", "x86_64") else f"windows-{machine}"
    return f"linux-{machine}"


def normalise_arch(platform: str) -> str:
    return (platform.replace("x86_64", "x64")
                    .replace("amd64", "x64")
                    .replace("aarch64", "arm64"))


# Multi-config generators (Visual Studio) put the executable, the staged
# assets and the DLLs under <build>/<config>/, not at the build root.
CONFIG_DIRS = ("Release", "RelWithDebInfo", "Debug")


def pick_executable(build: pathlib.Path, platform: str, explicit: str | None) -> pathlib.Path:
    roots = [build] + [build / name for name in CONFIG_DIRS]
    names = [explicit] if explicit else [DEFAULT_EXE + suffix for suffix in
                                         ((".exe", "") if platform.startswith("windows") else ("",))]
    for name in names:
        for root in roots:
            candidate = root / name
            if candidate.is_file():
                return candidate
    if explicit:
        fail(f"--exe {explicit} not found in {build} or its "
             f"{', '.join(CONFIG_DIRS)} subdirectories")
    # A renamed build is still packageable; say what was looked for.
    candidates = sorted(path.name for root in roots if root.is_dir()
                        for path in root.iterdir()
                        if path.is_file() and os.access(path, os.X_OK)
                        and not path.name.endswith((".cmake", ".txt", ".json", ".ini")))
    fail(f"no {names[0]} in {build} or its {', '.join(CONFIG_DIRS)} "
         "subdirectories"
         + (f"; executable files found: {', '.join(candidates)}" if candidates else ""))


def readme_text(version: str, platform: str, exe_name: str, personal: bool,
                rows: list[dict[str, str]], universal: bool) -> str:
    run = exe_name
    if platform.startswith("linux"):
        run = f"./{exe_name}"

    if personal:
        # A personal build bakes one image in, so it is single-edition.
        row = rows[0]
        rom_block = (
            "*** PERSONAL BUILD -- CONTAINS THE GAME, DO NOT DISTRIBUTE ***\n"
            "\n"
            f"The executable in this folder has the {row['rom_file']} image\n"
            "compiled into it.  That is what makes it convenient and what makes\n"
            "it not shareable: sending this archive to someone else is sending\n"
            "them a copy of Shadowrun.  Use it on your own machines.\n"
            "\n"
            f"Run: {run}\n"
            "\n"
            "It opens straight into the game: no ROM picker, no rom.cfg, nothing\n"
            "to point at.\n"
        )
    elif universal:
        listing = "".join(
            f"  - {row['rom_file']:<26} {row['label']:<8} "
            f"({row['identity_file']})\n"
            for row in rows)
        rom_block = (
            "This build does not contain the game.  It accepts any of these dumps:\n"
            "\n"
            f"{listing}"
            "\n"
            "The edition is selected from the dump itself: pass one on the\n"
            "command line, or choose it in the launcher on first run.  A dump\n"
            "that matches none of them is refused.  Keeping dumps outside this\n"
            "folder is the better habit; set SNESRECOMP_ROM once for a shell.\n"
            "\n"
            f"Run: {run} [path/to/one of those dumps]\n"
        )
    else:
        row = rows[0]
        rom_block = (
            "This build does not contain the game.  It needs your own copy of\n"
            f"{row['rom_file']}, and checks it against {row['identity_file']}\n"
            "before it runs.  Keeping the dump outside this folder is the better\n"
            "habit; set SNESRECOMP_ROM once, or pick it in the launcher on first\n"
            "run.\n"
            "\n"
            f"Run: {run} [path/to/{row['rom_file']}]\n"
        )

    if platform.startswith("macos"):
        state_block = (
            "Settings and saves live in ~/Library/Application Support/Shadowrun/,\n"
            "so the package folder can stay read-only.  The macOS release is the\n"
            ".dmg built by scripts/package_macos_bundle.sh; this folder is the\n"
            "portable form.\n"
        )
    elif universal:
        state_block = (
            "Settings and saves live beside the executable: config.ini,\n"
            "keybinds.ini, rom.cfg and saves/.  Each edition keeps its battery\n"
            "save and save-states apart under saves/, saves/de/ and saves/sv/.\n"
            "Keep this folder somewhere you can write to -- not Program Files\n"
            "or /usr -- so the game can save.\n"
        )
    else:
        state_block = (
            "Settings and saves live beside the executable: config.ini,\n"
            "keybinds.ini, rom.cfg and saves/.  Keep this folder somewhere you can\n"
            "write to -- not Program Files or /usr -- so the game can save.\n"
        )

    unsigned = (
        "Windows may warn about an unsigned executable (SmartScreen).  This\n"
        "package is not code-signed; choose More info -> Run anyway if you\n"
        "trust where it came from.\n"
        if platform.startswith("windows") else
        "This build is not code-signed.\n"
    )

    if universal:
        identities = [row["identity_file"] for row in rows]
        if len(identities) == 1:
            identity_names = identities[0]
        else:
            identity_names = ", ".join(identities[:-1]) + " and " + identities[-1]
        identity_line = (
            f"ROM identity: {identity_names} in the source tree, or the\n"
            "launcher's error message, name the exact dumps this build accepts.\n")
    else:
        identity_line = (
            f"ROM identity: {rows[0]['identity_file']} in the source tree, or the\n"
            "launcher's error message, names the exact dump this build accepts.\n")

    return f"""Shadowrun, recompiled natively -- version {version}, {platform}
{edition_heading(rows, universal)}

{rom_block}
Controls
  mouse             the in-game hand follows the pointer; the OS arrow hides
                    while the pointer is over the game
  left / right / middle mouse = B / A / Y
  W A S D = d-pad    X = start    Y = select
  C = X    Q = L    E = R

The mouse action buttons travel with the pointer, so A/B/Y have no keyboard
binding.  A controller still works alongside the mouse.

Files
  {exe_name}

{state_block}
{unsigned}
{identity_line}"""


def build_info(version: str, platform: str, exe: pathlib.Path, exe_hash: str,
               personal: bool, rows: list[dict[str, str]],
               universal: bool) -> str:
    try:
        commit = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        commit = "(not a git checkout)"
    if universal:
        edition_line = "editions  : " + ", ".join(
            f"{row['label']} ({row['rom_file']}, {row['identity_file']})"
            for row in rows)
        selects = "the edition is chosen from the loaded dump"
    else:
        row = rows[0]
        edition_line = (f"edition   : {row['label']} ({row['rom_file']}, "
                        f"{row['identity_file']})")
        selects = "only the edition above"
    return (
        f"Shadowrun, recompiled natively\n"
        f"version   : {version}\n"
        f"platform  : {platform}\n"
        f"{edition_line}\n"
        f"selects   : {selects}\n"
        f"variant   : {'personal (embedded ROM)' if personal else 'shareable (no ROM)'}\n"
        f"executable: {exe.name}\n"
        f"sha256    : {exe_hash}\n"
        f"source    : {commit}\n"
        f"framework : {framework_pins()}\n"
    )



def copy_runtime(runtime_dir: pathlib.Path, stage: pathlib.Path,
                 exe: pathlib.Path) -> list[str]:
    copied: list[str] = []
    shutil.copy2(exe, stage / exe.name)
    copied.append(exe.name)

    # Libraries, mods/ and assets/ are staged beside the executable by the
    # build, so they live in exe.parent: the build root for Makefiles/Ninja,
    # the Release/ folder for Visual Studio.
    for pattern in LIB_PATTERNS:
        for path in sorted(runtime_dir.glob(pattern)):
            if path.is_file():
                shutil.copy2(path, stage / path.name)
                copied.append(path.name)

    for name in RUNTIME_DIRS:
        source = runtime_dir / name
        if source.is_dir():
            shutil.copytree(source, stage / name)
            copied.append(name + "/")

    # A build tree's mod state is this machine's, not the package's. The
    # framework writes it on first run.
    for stale in (stage / "mods" / "state.toml",
                  stage / "mods" / "preloaded" / "state.toml"):
        if stale.exists():
            stale.unlink()

    for name in ("LICENSE",):
        source = ROOT / name
        if source.is_file():
            shutil.copy2(source, stage / name)
            copied.append(name)

    return copied


def write_archive(stage: pathlib.Path, stem: str, archive: pathlib.Path,
                  fmt: str) -> None:
    files = sorted(path for path in stage.rglob("*") if path.is_file())

    if fmt == "zip":
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            for path in files:
                rel = path.relative_to(stage).as_posix()
                info = zipfile.ZipInfo(f"{stem}/{rel}", date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (0o644 & 0xFFFF) << 16
                bundle.writestr(info, path.read_bytes())
    elif fmt == "tar.gz":
        # tarfile's "w:gz" lets gzip stamp the current time into its header,
        # so two runs of the same tree differed in their first bytes. Own the
        # GzipFile and pin mtime=0 (and omit the file name) to make the bytes
        # depend on the tree alone.
        with archive.open("wb") as raw:
            with gzip.GzipFile(filename="", mode="wb", fileobj=raw,
                               mtime=0) as gz:
                with tarfile.open(fileobj=gz, mode="w",
                                  format=tarfile.PAX_FORMAT) as bundle:
                    for path in files:
                        rel = path.relative_to(stage).as_posix()
                        info = bundle.gettarinfo(str(path), arcname=f"{stem}/{rel}")
                        info.mtime = 0
                        info.uid = info.gid = 0
                        info.uname = info.gname = ""
                        with path.open("rb") as handle:
                            bundle.addfile(info, handle)
    else:
        fail(f"unknown archive format {fmt}")


def verify_archive(archive: pathlib.Path, stem: str, fmt: str,
                   expected_exe_name: str, expected_exe_hash: str) -> int:
    if fmt == "zip":
        with zipfile.ZipFile(archive) as bundle:
            names = bundle.namelist()
            bad = bundle.testzip()
            if bad:
                fail(f"{archive.name}: corrupt member {bad}")
            exe_member = f"{stem}/{expected_exe_name}"
            if exe_member not in names:
                fail(f"{archive.name}: {exe_member} missing")
            data = bundle.read(exe_member)
    else:
        with tarfile.open(archive, "r:gz") as bundle:
            names = bundle.getnames()
            exe_member = f"{stem}/{expected_exe_name}"
            if exe_member not in names:
                fail(f"{archive.name}: {exe_member} missing")
            handle = bundle.extractfile(exe_member)
            if handle is None:
                fail(f"{archive.name}: {exe_member} is not a file")
            data = handle.read()

    if hashlib.sha256(data).hexdigest() != expected_exe_hash:
        fail(f"{archive.name}: packaged executable is not the built one")
    return len(names)


def smoke_test(stage: pathlib.Path, exe_name: str, platform: str) -> str:
    """Run --help from the staged folder, but only on the host platform.

    --help exits before SDL video/audio init, so it needs no display and works
    on a CI runner. Cross-packaged trees cannot run here and are skipped
    rather than reported as a failure.
    """
    host = normalise_arch(host_platform())
    target = normalise_arch(platform)
    same_os = host.split("-", 1)[0] == target.split("-", 1)[0]
    same_arch = target.endswith("universal") or host == target
    if not (same_os and same_arch):
        return f"skipped (cannot run a {platform} executable on {host})"

    exe = stage / exe_name
    env = dict(os.environ)
    env.setdefault("SDL_VIDEODRIVER", "dummy")
    env.setdefault("SDL_AUDIODRIVER", "dummy")
    result = subprocess.run([str(exe), "--help"], cwd=str(stage), env=env,
                            capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        fail(f"staged {exe_name} --help exited {result.returncode}:\n"
             f"{result.stdout}{result.stderr}")
    return "ok (--help exited 0 from the staged folder)"


def display_path(path: pathlib.Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Stage a built Shadowrun tree as a Windows zip or Linux tarball.")
    parser.add_argument("--build", default="build",
                        help="build directory (default: build)")
    parser.add_argument("--platform", default=None,
                        help="artifact tag, e.g. linux-x64, windows-x64 "
                             "(default: this host)")
    parser.add_argument("--dist", default="dist",
                        help="output directory (default: dist)")
    parser.add_argument("--personal", action="store_true",
                        help="the build has the ROM compiled in; mark it not shareable")
    parser.add_argument("--version", default=None,
                        help="release version (default: VERSION)")
    parser.add_argument("--edition", choices=tuple(EDITIONS) + (UNIVERSAL,),
                        default=None,
                        help="ROM edition the build targets; default: detect it "
                             "from the build's CMakeCache (us when there is none)")
    parser.add_argument("--exe", default=None,
                        help=f"executable name inside --build (default: {DEFAULT_EXE})")
    parser.add_argument("--archive", choices=("zip", "tar.gz"), default=None,
                        help="archive format (default: zip on Windows, tar.gz elsewhere)")
    parser.add_argument("--keep-stage", action="store_true",
                        help="leave the staged folder in --dist")
    args = parser.parse_args(argv)

    build = (ROOT / args.build).resolve()
    if not build.is_dir():
        fail(f"build directory not found: {build}")

    platform = normalise_arch(args.platform or host_platform())
    version = args.version or version_from_tree()
    personal = bool(args.personal)

    # The archive's label must describe what the executable does. Read the
    # tree's configuration first; an explicit --edition is an assertion about
    # the tree, not a way to relabel it.
    configured = tree_edition_config(build)
    tree_values = read_cmake_cache(build)
    if configured is not None:
        tree_universal, tree_tags = configured
        if args.edition is None:
            requested = UNIVERSAL if tree_universal else tree_tags[0]
        else:
            requested = args.edition
        if requested == UNIVERSAL and not tree_universal:
            fail(f"{display_path(build)} was configured for "
                 f"{', '.join(tree_tags)} only, not a universal build.\n"
                 f"Pass --edition {tree_tags[0]}, or configure a universal tree "
                 f"(the presets without -de/-sv).")
        if requested != UNIVERSAL and tree_universal:
            fail(f"{display_path(build)} is a universal build "
                 f"({', '.join(tree_tags)}); it accepts more than one dump.\n"
                 f"Pass --edition universal, or package a single-edition tree "
                 f"(one of the -de/-sv presets).")
        if requested != UNIVERSAL and requested not in tree_tags:
            fail(f"{display_path(build)} was configured for "
                 f"{', '.join(tree_tags)}, not {requested}; package the tree "
                 f"that carries that edition or choose {tree_tags[0]}.")
        tags = list(tree_tags) if requested == UNIVERSAL else [requested]
    else:
        requested = args.edition or "us"
        tags = list(EDITIONS) if requested == UNIVERSAL else [requested]

    universal = requested == UNIVERSAL
    if personal and universal:
        fail("--personal with a universal build: an embedded-ROM executable is "
             "single-edition by construction, because it carries one image.\n"
             "Package the edition tree that has the image compiled in "
             "(-DSHADOWRUN_UNIVERSAL=OFF -DSHADOWRUN_EDITION=us|de|sv).")
    if tree_values:
        embedded = cache_flag(tree_values, "SHADOWRUN_EMBED_ROM")
        if embedded and not personal:
            fail(f"{display_path(build)} was configured with "
                 "SHADOWRUN_EMBED_ROM=ON: the executable contains the game.\n"
                 "Package it with --personal, or point at a ROM-free tree.")
        if personal and not embedded:
            fail(f"--personal wants a tree built with "
                 f"-DSHADOWRUN_EMBED_ROM=ON; {display_path(build)} is ROM-free. "
                 "Package it without --personal.")

    rows = edition_rows(tags)
    exe = pick_executable(build, platform, args.exe)
    exe_hash = sha256(exe)

    slug = "shadowrun-embed" if personal else "shadowrun"
    if universal:
        slug += "-universal"
    elif requested != "us":
        slug += f"-{requested}"
    stem = f"{slug}-{version}-{platform}"
    if personal:
        stem += "-personal"

    fmt = args.archive or ("zip" if platform.startswith("windows") else "tar.gz")
    dist = (ROOT / args.dist).resolve()
    dist.mkdir(parents=True, exist_ok=True)

    stage = dist / stem
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)

    copied = copy_runtime(exe.parent, stage, exe)
    (stage / "README.txt").write_text(
        readme_text(version, platform, exe.name, personal, rows, universal),
        encoding="utf-8")
    (stage / "BUILD_INFO.txt").write_text(
        build_info(version, platform, exe, exe_hash, personal, rows, universal),
        encoding="utf-8")

    archive = dist / f"{stem}.{fmt}"
    write_archive(stage, stem, archive, fmt)
    members = verify_archive(archive, stem, fmt, exe.name, exe_hash)

    digest = sha256(archive)
    (dist / f"{stem}.{fmt}.sha256").write_text(
        f"{digest}  {archive.name}\n", encoding="utf-8")

    smoke = smoke_test(stage, exe.name, platform)

    print(f"staged  : {display_path(stage)}")
    print(f"exe     : {display_path(exe)}")
    print(f"files   : {', '.join(copied)}")
    print(f"archive : {display_path(archive)}")
    print(f"size    : {archive.stat().st_size} B")
    print(f"sha256  : {digest}")
    print(f"members : {members}")
    print(f"smoke   : {smoke}")
    if not args.keep_stage:
        shutil.rmtree(stage)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        raise SystemExit(130)
