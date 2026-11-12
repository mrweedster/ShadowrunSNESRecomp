#!/usr/bin/env bash
# Frame screenshots. The host writes frame_XXXXXX.bmp into the directory named by
# SNESRECOMP_FRAME_BMP_DIR; the range/step come from _START/_END/_STEP. The
# directory has to exist first (the host does not mkdir).
#
# Each BMP includes the game's own frame counter at the top-left, which is what
# makes two builds' output comparable frame by frame instead of "looks similar".
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
out="${1:-tests/out/shots}"
start="${START:-60}"
end="${END:-1200}"
step="${STEP:-60}"
script="${SCRIPT:-tests/scripts/menu.txt}"
port="${PORT_BIN:-./Shadowrun}"
rom=$(sr_rom)

rm -rf "$out"
mkdir -p "$out"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
export SNESRECOMP_FRAME_BMP_DIR="$out"
export SNESRECOMP_FRAME_BMP_START="$start"
export SNESRECOMP_FRAME_BMP_END="$end"
export SNESRECOMP_FRAME_BMP_STEP="$step"
"$port" --no-launcher --rom "$rom" --script "$script"
echo
ls -l "$out" | tail -n +2 | awk '{print $5, $9}'
md5 -q "$out"/*.bmp | sort -u | wc -l | xargs echo "distinct frames:"
