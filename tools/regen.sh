#!/usr/bin/env bash
# Regenerate src/gen/*.c for Shadowrun from a verified ROM.
#
# Generated C is derived from copyrighted ROM data and is never committed;
# every developer regenerates from their own copy. The ROM digests come from
# rom_identity.txt, which the build and the release workflow read too, so
# there is one place to change when a revision changes.
#
# Flags:
#   --rom <path>  ROM to generate from. Defaults to SNESRECOMP_ROM, a known
#                 filename at the repo root, then the path in rom.cfg (which
#                 the setup wizard writes). The ROM does not have to live in
#                 the repo — keeping it on your own drive is the better
#                 habit, and SNESRECOMP_ROM sets it once for a shell.
#   --identity <file>
#                 ROM identity to verify against and name the dump from.
#                 Default rom_identity.txt (USA). The language editions use
#                 rom_identity.de.txt and rom_identity.sv.txt.
#   --out-dir <dir>
#                 generated-code directory. Default src/gen (USA); the
#                 language editions use src/gen-de and src/gen-sv.
#   --cfg-dir <dir>
#                 analysis seeds. Default recomp (the USA symbol map); the
#                 translations use recomp-lle, which carries no USA addresses.
#   --funcs-h <path>
#                 header to write. Default <out-dir>/funcs.h.
#   --module-id <id>
#                 program-module id recorded in the generated tree. Default
#                 main; the universal build's translations use shadowrun-de
#                 and shadowrun-sv so the runtime can select them by name.
#   --module-prefix <prefix>
#                 emit this tree in its own C namespace (module_namespace.h)
#                 so it can link beside the stock tree in one executable.
#                 The translations use shadowrun_de / shadowrun_sv.
#   --no-verify   skip the ROM digest check (for a revision this project has
#                 not been pinned to yet — expect the generated C to differ)
#   --cfg-roots   seed analysis from every func declaration in <cfg-dir>/*.cfg
#   -h|--help     this message
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

VERIFY=1
CFG_ROOTS=0
ROM=""
IDENTITY_FILE="$ROOT/rom_identity.txt"
OUT_DIR="src/gen"
CFG_DIR="recomp"
FUNCS_H=""
MODULE_ID=""
MODULE_PREFIX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rom) ROM=$2; shift 2 ;;
    --identity) IDENTITY_FILE=$2; shift 2 ;;
    --out-dir) OUT_DIR=$2; shift 2 ;;
    --cfg-dir) CFG_DIR=$2; shift 2 ;;
    --funcs-h) FUNCS_H=$2; shift 2 ;;
    --module-id) MODULE_ID=$2; shift 2 ;;
    --module-prefix) MODULE_PREFIX=$2; shift 2 ;;
    --no-verify) VERIFY=0; shift ;;
    --cfg-roots) CFG_ROOTS=1; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed -n '/^# /p' | sed 's/^# //'; exit 0 ;;
    *) echo "regen.sh: unknown flag: $1 (try --help)" >&2; exit 2 ;;
  esac
done

case "$IDENTITY_FILE" in
  /*) ;;
  *) IDENTITY_FILE="$ROOT/$IDENTITY_FILE" ;;
esac
if [ ! -f "$IDENTITY_FILE" ]; then
  echo "regen.sh: identity file not found: $IDENTITY_FILE" >&2
  exit 1
fi
if [ -z "$FUNCS_H" ]; then FUNCS_H="$OUT_DIR/funcs.h"; fi

SNESRECOMP_ROOT="${SNESRECOMP_ROOT:-snesrecomp}"
CLI="$SNESRECOMP_ROOT/snesrecomp_cli.py"
if [ ! -f "$CLI" ]; then
  echo "regen.sh: $CLI missing — run: git submodule update --init --recursive" >&2
  exit 1
fi

PYTHON=${PYTHON:-}
if [ -z "$PYTHON" ]; then
  # Windows App Execution Aliases can exist on PATH without running Python.
  for _snes_python in python3 python; do
    if "$_snes_python" -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then
      PYTHON=$_snes_python
      break
    fi
  done
fi
if [ -z "$PYTHON" ]; then
  echo "regen.sh: no python3 on PATH" >&2
  exit 1
fi

# The framework parses the identity file (the same parser CI uses), so this
# script carries no copy of a digest to forget on a revision bump.
IDENTITY="$SNESRECOMP_ROOT/tools/rom_identity.py"
EXPECTED_CRC32="${SNESRECOMP_EXPECTED_CRC32:-$("$PYTHON" "$IDENTITY" "$IDENTITY_FILE" --get expected_crc32)}"
EXPECTED_SHA256="${SNESRECOMP_EXPECTED_SHA256:-$("$PYTHON" "$IDENTITY" "$IDENTITY_FILE" --get expected_sha256)}"
IDENTITY_ROM=$("$PYTHON" "$IDENTITY" "$IDENTITY_FILE" --get rom_file)

# The framework owns the search: --rom, then SNESRECOMP_ROM, then the
# identity's own filename, then a known name at the root, then rom.cfg.
RESOLVE=(resolve-rom --project-root "$ROOT")
if [ -n "$IDENTITY_ROM" ]; then RESOLVE+=(--name "$IDENTITY_ROM"); fi
RESOLVE+=(--name "Shadowrun (USA).sfc" --name "shadowrun.sfc" --name "shadowrun.smc")
if [ -n "$ROM" ]; then RESOLVE+=(--rom "$ROM"); fi
if ! ROM=$("$PYTHON" "$CLI" "${RESOLVE[@]}"); then
  echo "regen.sh: pass --rom /path/to/Shadowrun (USA).sfc, set SNESRECOMP_ROM, put it" >&2
  echo "          at the repo root, or record its path in rom.cfg. You must" >&2
  echo "          legally own a copy of Shadowrun." >&2
  exit 1
fi
ROM=${ROM%$'\r'}  # Windows Python ends lines with CRLF

VERIFY_ARGS=()
if [ "$VERIFY" -eq 1 ]; then
  VERIFY_ARGS=(--expected-crc32 "$EXPECTED_CRC32" --expected-sha256 "$EXPECTED_SHA256")
  echo "== Verifying $ROM =="
  "$PYTHON" "$CLI" verify-rom --rom "$ROM" "${VERIFY_ARGS[@]}"
else
  echo "== Skipping ROM verification (--no-verify) =="
fi

GEN_ARGS=(--rom "$ROM" --cfg-dir "$CFG_DIR" --out-dir "$OUT_DIR"
          --funcs-h "$FUNCS_H" --project-root "$ROOT")
if [ "$CFG_ROOTS" -eq 1 ]; then GEN_ARGS+=(--cfg-roots); fi
if [ "$VERIFY" -eq 1 ]; then GEN_ARGS+=("${VERIFY_ARGS[@]}"); fi

echo "== Generating $OUT_DIR =="
if [ -n "$MODULE_ID" ] || [ -n "$MODULE_PREFIX" ]; then
  # A prefixed tree has to be emitted by v2_emit directly: the CLI's
  # generate command does not forward --module-id/--module-prefix, and the
  # prefix needs a funcs.h beside the cfg directory for the module's own
  # declarations (the emitter copies it into the tree).
  MODULE_ID="${MODULE_ID:-main}"
  FUNCS_CFG="$CFG_DIR/funcs.h"
  "$PYTHON" "$SNESRECOMP_ROOT/tools/v2_sync_funcs_h.py" \
      --cfg-dir "$CFG_DIR" --out "$FUNCS_CFG"
  EMIT_ARGS=(--rom "$ROM" --cfg-dir "$CFG_DIR" --out-dir "$OUT_DIR"
             --module-id "$MODULE_ID" --host-alias-header "$FUNCS_CFG")
  if [ -n "$MODULE_PREFIX" ]; then
    EMIT_ARGS+=(--module-prefix "$MODULE_PREFIX")
  fi
  if [ "$CFG_ROOTS" -eq 1 ]; then EMIT_ARGS+=(--cfg-roots); fi
  "$PYTHON" "$SNESRECOMP_ROOT/tools/v2_emit.py" "${EMIT_ARGS[@]}"
  cp "$FUNCS_CFG" "$FUNCS_H"
else
  "$PYTHON" "$CLI" generate "${GEN_ARGS[@]}"
fi

# The default build historically read recomp/funcs.h. Keep that path in step
# for the USA edition so framework tools that look there still see this
# build's declarations; the language editions keep theirs beside their gen.
if [ "$IDENTITY_FILE" = "$ROOT/rom_identity.txt" ] && [ "$FUNCS_H" = "$OUT_DIR/funcs.h" ]; then
  cp "$FUNCS_H" "$ROOT/recomp/funcs.h"
fi

echo
echo "Done. Build with:"
echo "  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"
