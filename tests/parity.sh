#!/usr/bin/env bash
# Frame-state comparison.
#
#   ./tests/parity.sh                                  # same binary, twice
#   PORT_BIN2=./build/x ./tests/parity.sh              # AOT build vs LLE build
#   ./tests/parity.sh tests/scripts/menu.txt           # drive a longer scenario
#
# For every frame the host records the crc32 of all 128 KiB of WRAM in
# tests/out/<run>/frame_XXXXXX.json, so this compares full emulator state, not a
# screenshot. Same binary twice: any divergence is the dynamic recompiler
# disagreeing with itself. Two binaries: it is the static (AOT) path against the
# interpreter path -- expect a small, constant set of differences rather than
# zero, see the section 7 note in tests/README.md.
#
# PORT_BIN2 may point anywhere, including inside tests/out -- only the run
# directories are cleaned, so a scratch copy of a binary survives. If it lives
# under tests/out, give it a libs symlink to travel on:
#   cp -p Shadowrun tests/out/Shadowrun2 && ln -sfn "$PWD/libs" tests/out/libs
#
# A binary outside the bundle anchors config/saves to ITS OWN directory (the
# host logs "config dir anchored: ..." on startup), so both the save snapshot
# and the dump paths below are resolved per binary and made absolute. Getting
# this wrong is silent and poisonous: a relative SNESRECOMP_DUMP_DIR resolved
# against the anchor dir wrote tagged checkpoints to the wrong place, and the
# run played from a save state the snapshot never touched.
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
script="${1:-tests/scripts/parity.txt}"
port1="${PORT_BIN:-./Shadowrun}"
port2="${PORT_BIN2:-$port1}"
rom=$(sr_rom) || exit 2
out="$PWD/tests/out"

mkdir -p "$out"
rm -rf "$out/run1" "$out/run2" "$out/srm_snap"
mkdir -p "$out/run1" "$out/run2"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

# Long routes write SRAM as they play; both runs must start from the exact
# same save state, so snapshot once up front and restore it pre-run -- into the
# directory each binary really anchors to.
srm_snap="$out/srm_snap"
mkdir -p "$srm_snap"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$srm_snap/$f"
done
restore_sram() { # $1 = binary
  local dir anchor
  dir=$(cd "$(dirname "$1")" && pwd)
  anchor="$dir/saves"
  mkdir -p "$anchor"
  [ -f "$srm_snap/save.srm" ] && cp -p "$srm_snap/save.srm" "$anchor/save.srm"
  [ -f "$srm_snap/save.srm.bak" ] && cp -p "$srm_snap/save.srm.bak" "$anchor/save.srm.bak"
  if [ "$dir" != "$PWD" ]; then
    echo "       anchor: $dir (own saves/, own config.ini)"
  fi
}

run() { # $1=label $2=binary $3=dir
  printf 'run%s  %s\n' "$1" "$2"
  if [ ! -x "$2" ]; then
    echo "       not executable: $2" >&2
    return 1
  fi
  restore_sram "$2"
  # Tagged checkpoints (`dump TAG` lines in the script) land in the run dir,
  # not the repo root, so both runs' artifacts survive to be compared.
  SNESRECOMP_DUMP_DIR="$3" "$2" --no-launcher --rom "$rom" --script "$script" --framedump "$3" >"$3.log" 2>&1
  grep -E 'frame service' "$3.log" | tail -1 | sed 's/^/       /' || true
  grep -E '^\[host .*exit' "$3.log" | tail -1 | sed 's/^/       /' || true
  grep -vE '^\[host \+' "$3.log" | grep -iE 'error|cannot|fail' | head -3 | sed 's/^/       /' || true
  return 0
}

rc1=0; rc2=0
run 1 "$port1" "$out/run1" || rc1=$?
run 2 "$port2" "$out/run2" || rc2=$?

# Which programs produced these dumps, recorded before anything is compared.
# tests/out is scratch and any later build overwrites it, so the frame files on
# their own cannot say what made them -- that gap is how a stale tree and a
# stale staged bundle both read as measurements (see evidence/c1_*).
for n in 1 2; do
  case $n in
    1) bin="$port1" ;;
    2) bin="$port2" ;;
  esac
  python3 tests/provenance.py record "$bin" "$out/run$n" 2>&1 | sed 's/^/       /'
done
if [ "$port1" != "$port2" ]; then
  python3 tests/provenance.py same-src "$out/run1" "$out/run2" | sed 's/^/       /'
fi

shopt -s nullglob
files=("$out"/run1/frame_*.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "no frame dumps produced -- see $out/run1.log" >&2
  exit 1
fi

crc() { grep -o '0x[0-9A-Fa-f]\{8\}' "$1" 2>/dev/null | tail -1; }
same=0
diff=0
first=""
for f in "${files[@]}"; do
  base=$(basename "$f")
  g="$out/run2/$base"
  if [ ! -f "$g" ]; then
    if [ -z "$first" ]; then
      first="$base"
      n2=$(find "$out/run2" -name 'frame_*.json' 2>/dev/null | wc -l | tr -d ' ')
      echo "first problem at $base: run2 stopped after $n2 frames"
    fi
    diff=$((diff + 1))
    continue
  fi
  if [ "$(crc "$f")" = "$(crc "$g")" ]; then
    same=$((same + 1))
  elif [ -z "$first" ]; then
    first="$base"
    echo "first divergence at $base: $(crc "$f") vs $(crc "$g")"
    diff=$((diff + 1))
  else
    diff=$((diff + 1))
  fi
done

total=$((same + diff))
# Cross-path runs: report checkpoint frame-buffer md5s side by side
# (informational; pixel diffs at crossfade/dialogue landmarks are explained
# in evidence/a5_crosspath_tick.md).
if [ "$port1" != "$port2" ]; then
  bmps=("$out"/run1/*.fb.bmp)
  if [ ${#bmps[@]} -gt 0 ]; then
    echo "checkpoint fb bmp md5:"
    for f in "${bmps[@]}"; do
      base=$(basename "$f")
      g="$out/run2/$base"
      if [ -f "$g" ]; then
        if [ "$(md5 -q "$f")" = "$(md5 -q "$g")" ]; then
          printf '  %-16s match\n' "$base"
        else
          printf '  %-16s differ\n' "$base"
        fi
      else
        printf '  %-16s missing in run2\n' "$base"
      fi
    done
  fi
fi
if [ "$diff" -eq 0 ]; then
  echo "identical over $total frames"
  exit 0
fi
echo "$diff of $total frames differ"
if [ "$port1" = "$port2" ]; then
  echo "-> the same binary produced different state: a real determinism bug"
else
  echo "-> cross-path comparison: see section 7 of tests/README.md (frame counters, constant phase offset)"
fi
[ "$rc1" -ne 0 ] && echo "-> run1 exited $rc1" >&2
[ "$rc2" -ne 0 ] && echo "-> run2 exited $rc2" >&2
exit 1
