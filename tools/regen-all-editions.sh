#!/usr/bin/env bash
# Generate every recompiled tree the universal build links.
#
# The USA tree is the stock, unprefixed module (id "main"). The German and
# Swedish trees are emitted in their own C namespaces (--module-prefix) so all
# three can live in one executable; the runtime picks the one whose recorded
# ROM digest matches the dump the player supplied.
#
# Usage:
#   SNESRECOMP_ROOT=/path/to/snesrecomp tools/regen-all-editions.sh [options]
#   tools/regen-all-editions.sh --rom-dir ~/roms/shadowrun
#
# Options:
#   --rom-dir DIR     where the three dumps live (default: repo root)
#   --rom-us PATH     USA dump (default: DIR/Shadowrun (USA).sfc, or regen's search)
#   --rom-de PATH     German dump
#   --rom-sv PATH     Swedish dump
#   --no-verify       skip digest checks (only for an unpinned revision)
#   -h|--help         this message
#
# Generated code is derived from copyrighted ROM data and is never committed;
# this script writes src/gen, src/gen-de and src/gen-sv, all git-ignored.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

ROM_DIR="$ROOT"
ROM_US="${SNESRECOMP_ROM_US:-}"
ROM_DE="${SNESRECOMP_ROM_DE:-}"
ROM_SV="${SNESRECOMP_ROM_SV:-}"
VERIFY=1
while [ $# -gt 0 ]; do
  case "$1" in
    --rom-dir) ROM_DIR=$2; shift 2 ;;
    --rom-us) ROM_US=$2; shift 2 ;;
    --rom-de) ROM_DE=$2; shift 2 ;;
    --rom-sv) ROM_SV=$2; shift 2 ;;
    --no-verify) VERIFY=0; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed -n '/^# /p' | sed 's/^# //'; exit 0 ;;
    *) echo "regen-all-editions.sh: unknown flag: $1 (try --help)" >&2; exit 2 ;;
  esac
done

default_rom() {
  local name=$1
  if [ -f "$ROM_DIR/$name" ]; then
    printf '%s\n' "$ROM_DIR/$name"
  fi
}

# An explicit path wins; otherwise name the dump in --rom-dir when it exists;
# otherwise leave the flag off and let tools/regen.sh's own resolver search
# the repo root and rom.cfg.
rom_args() {
  local explicit=$1 name=$2 found
  if [ -n "$explicit" ]; then
    printf '%s\0%s\0' --rom "$explicit"
    return
  fi
  found=$(default_rom "$name")
  if [ -n "$found" ]; then
    printf '%s\0%s\0' --rom "$found"
  fi
}

VERIFY_ARGS=()
if [ "$VERIFY" -eq 0 ]; then VERIFY_ARGS=(--no-verify); fi

run_edition() {
  local tag=$1 identity=$2 out_dir=$3 cfg_dir=$4 name=$5 explicit=$6
  shift 6
  local args=()
  while IFS= read -r -d '' item; do args+=("$item"); done < <(rom_args "$explicit" "$name" || true)
  echo
  echo "== $tag: $out_dir ($identity) =="
  bash tools/regen.sh \
    --identity "$identity" \
    --out-dir "$out_dir" \
    --cfg-dir "$cfg_dir" \
    "${args[@]+"${args[@]}"}" \
    "${VERIFY_ARGS[@]+"${VERIFY_ARGS[@]}"}" \
    "$@"
}

# USA: stock module, unprefixed, module id main (the generator default).
run_edition us rom_identity.txt src/gen recomp \
  "Shadowrun (USA).sfc" "$ROM_US"

# Translations: prefixed so they can link beside the stock tree. The cursor
# words also moved (see src/edition.c); the runtime table carries that.
run_edition de rom_identity.de.txt src/gen-de recomp-lle \
  "Shadowrun (Germany).sfc" "$ROM_DE" \
  --module-id shadowrun-de --module-prefix shadowrun_de

run_edition sv rom_identity.sv.txt src/gen-sv recomp-lle \
  "Shadowrun (Sweden).sfc" "$ROM_SV" \
  --module-id shadowrun-sv --module-prefix shadowrun_sv

cat <<'EOF'

All three trees are generated. Build the universal executable with one of:

  cmake --preset macos-arm64           # or macos-universal
  cmake --preset linux-x64
  cmake --preset windows-x64
  cmake --build --preset <that preset> --parallel 8

The result accepts any of the three dumps: pass --rom, or let the host use
its usual resolution order. A build with only some editions is also valid --
configure with -DSHADOWRUN_EDITIONS=us (or us;de) and only those trees are
linked.
EOF
