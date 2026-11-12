#!/usr/bin/env bash
# Headless smoke test: boots the port, drives the title menu, prints fps.
# Pass a different script file as $1 to drive a longer scenario.
# PORT_BIN runs a build tree's binary rather than the staged bundle one, so a
# build does not have to be staged as ./Shadowrun to be smoke-tested.
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
script="${1:-tests/scripts/menu.txt}"
shift || true
rom=$(sr_rom)
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
exec "${PORT_BIN:-./Shadowrun}" --no-launcher --rom "$rom" --script "$script" "$@"
