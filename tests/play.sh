#!/usr/bin/env bash
# Launch the port in a window. Any extra args are passed through to the host
# (--fullscreen, --rom <path>, --no-launcher, ...). PORT_BIN runs a build
# tree's binary rather than the staged bundle one.
#
# The ROM is never asked for: repo-root rom.cfg names the dump this tree was
# generated from, and it goes in as --rom unless the caller already passed one.
# That matters most for copies of the binary that live outside a build tree --
# a binary whose own directory holds no rom.cfg and no .sfc falls back to a GUI
# file picker, which looks like a hung launch.
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh

bin="${PORT_BIN:-./Shadowrun}"
args=("$@")
has_rom=0
for a in "${args[@]+"${args[@]}"}"; do
  [ "$a" = "--rom" ] && has_rom=1
done
if [ "$has_rom" = 0 ]; then
  args=(--rom "$(sr_rom)" "${args[@]+"${args[@]}"}")
fi
exec "$bin" "${args[@]+"${args[@]}"}"
