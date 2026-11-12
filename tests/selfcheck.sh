#!/usr/bin/env bash
# Self-verifying boot test: no human watching, no screenshots.
#
# Waits on Shadowrun's own WRAM tick counter ($7E1C92, one increment per
# emulated frame) rather than guessing frame counts, so it fails loudly if the
# ROM stops executing. The host exits 3 when an `until` times out.
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh
port="${PORT_BIN:-./Shadowrun}"
rom=$(sr_rom) || exit 2
out=$(SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  "$port" --no-launcher --rom "$rom" --script tests/scripts/selfcheck.txt 2>&1)
code=$?
echo "$out" | grep -E "^script |frame service"
if [ "$code" -eq 0 ]; then
  echo "PASS: rom executed, tick counter advanced (exit 0)"
else
  echo "FAIL: exit $code" >&2
fi
exit $code
