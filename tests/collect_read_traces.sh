#!/usr/bin/env bash
# Collect a ROM-read trace for every scripted route (B0).
#
#   ./tests/collect_read_traces.sh                       # build-b0, all routes
#   PORT_BIN=./build-x ./tests/collect_read_traces.sh    # any tree's binary
#   ROUTES="menu nav2" ./tests/collect_read_traces.sh    # a subset
#
# The observer lives in the framework (SNESRECOMP_CART_TRACE=<path.json>); this
# script only drives it. Each route writes <out>/<route>.json and the report is
# written next to them.
#
# SRAM is anchored to the binary's own directory, so a route that saves leaves
# the next route starting from that state. Same reasoning as tests/parity.sh:
# snapshot the bundle's save at entry and restore it before every route, so the
# traces describe the same starting state as the framedump baselines.
set -euo pipefail
cd "$(dirname "$0")/.."
. tests/rom.sh

bin="${PORT_BIN:-./build-b0/ShadowrunSNESRecomp}"
rom=$(sr_rom) || exit 2
out="${TRACE_OUT:-tests/out/b0}"
routes="${ROUTES:-selfcheck menu nav1 nav2 combat door}"

[ -x "$bin" ] || { echo "not executable: $bin" >&2; exit 2; }

# The numbers only mean something if the binary is known: the pin, or the pin plus
# the observer. A copy of the framework reports framework=unknown and its revision
# cannot be named at all, so refuse it here instead of publishing a trace whose
# provenance cannot be checked later.
python3 tests/provenance.py pin --descendant "$bin" || {
  echo "refusing to collect: $bin does not link a framework with the pin as an" \
       " ancestor (tests/provenance.py pin)" >&2
  exit 2
}
mkdir -p "$out"

anchor="$(cd "$(dirname "$bin")" && pwd)/saves"
snap="$out/srm_snap"
mkdir -p "$snap" "$anchor"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$snap/$f"
done
restore_sram() {
  for f in save.srm save.srm.bak; do
    [ -f "$snap/$f" ] && cp -p "$snap/$f" "$anchor/$f"
  done
}

export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
echo "binary: $bin"
for route in $routes; do
  script="tests/scripts/$route.txt"
  [ -f "$script" ] || { echo "no such script: $script" >&2; exit 2; }
  restore_sram
  trace="$PWD/$out/$route.json"
  rm -f "$trace"
  SNESRECOMP_CART_TRACE="$trace" "$bin" --no-launcher --rom "$rom" --script "$script" \
      >"$out/$route.log" 2>&1 || { echo "route $route failed, see $out/$route.log" >&2; exit 1; }
  frames=$(grep -E 'exit: script quit' "$out/$route.log" | tail -1 | grep -oE '[0-9]+ frames' || true)
  printf '%-10s %-16s %8s  %s\n' "$route" "${frames:-?}" \
      "$(wc -c <"$trace" | tr -d ' ')" "$trace"
done

# The join needs the port's own symbol map, which the framework does not have, so
# the collector passes it: --port-root is the directory holding src/gen and
# recomp/, not src/gen itself. The A1 coverage capture is optional; it is a
# different build, and the report says so where it uses it.
extra=(--port-root "${PORT_ROOT:-.}")
[ -f "${COVERAGE:-tests/out/a1/summary.json}" ] && extra+=(--coverage "${COVERAGE:-tests/out/a1/summary.json}")
python3 tests/cart_trace_report.py "${extra[@]}" "$out"/*.json --markdown "$out/report.md"
