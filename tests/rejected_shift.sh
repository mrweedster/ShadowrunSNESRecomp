#!/usr/bin/env bash
# Is a rejected seed's state split a pairing artefact, or a byte that goes somewhere else?
#
#   ./tests/rejected_shift.sh                       # s80ABBC s80B1DB r4clean
#   CTRL_BIN=build-r4base/ShadowrunSNESRecomp BYTE=0x127 ./tests/rejected_shift.sh s80B1DB
#
# tests/cp_byte_diff.py says a rejected tree's WRAM disagrees with the control at
# the same tagged checkpoint.  A reader can object that the two runs merely sit at
# different points of the guest's own timeline at the same host frame, so the
# control's state would show up at run2[f+k] instead of run2[f] -- phase, not a
# wrong computation.  That is a real possibility: this round's accepted pair moves
# nothing, but a seeded body can re-stamp clock labels and shift when work lands.
#
# This answers it on the frame dumps, not at checkpoints:
#
#   parity.sh on the probe route        per-frame crc32 + full WRAM for both legs
#   framedump_diff.py tick              at every shared guest tick, how far apart
#                                       the two legs sit in host frames (constant
#                                       k = phase; stepping = one leg ran a frame
#                                       the other did not)
#   framedump_diff.py shift             same guest tick, host frames aligned, label
#                                       bytes excluded: does any offset make them
#                                       byte-identical?
#   framedump_diff.py drift             the per-frame count of differing 1 KiB
#                                       blocks, the frame where it stops being a
#                                       label-block distance, and the exact bytes
#                                       (label bytes excluded) in a window there
#   framedump_diff.py state             which non-label bytes differ at the same
#                                       host frame, with both legs' values, from
#                                       the first frame where any appear
#   framedump_diff.py byte <addr>       one byte's value timeline plus a histogram
#                                       per leg: same values with counts moved is
#                                       phase, a value only one leg writes is state
#
# The byte probes track the addresses the *combat-route* checkpoint diff names
# ($7E0126/$7E0127).  On the probe route $7E0127 turns out to be identical in every
# frame, which is a fact worth having: the two routes diverge in different bytes,
# so `state` is what names the bytes for this route.
#
# Legs run from scratch anchors under $OUT (a copy of the build's exe plus a libs
# symlink next to it), never inside build-*/: a build dir's last_run_report.json is
# the join target for round4_parity_legs.md, and an extra leg there would silently
# replace the counters the shipped table cites.  The control leg does run its own
# build-dir exe, the same way tests/accepted_verify.sh does; its counters are the
# deterministic parity-route ones the table already shows.
#
# Writes $OUT/shift_parity_<variant>.log (the parity leg) and
# $OUT/shift_<variant>.md (the three probes).  tests/out/run1 and run2 hold the
# last variant's frame dumps afterwards.  Exit 0 if every variant produced probes.
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
. tests/rom.sh

out="${OUT:-tests/out/r4}"
route="${PROBE:-tests/out/probe_dense.txt}"
ctrl="${CTRL_BIN:-build-r4base/ShadowrunSNESRecomp}"
bytes="${BYTE:-0x126 0x127}"
variants=("$@")
[ ${#variants[@]} -gt 0 ] || variants=(s80ABBC s80B1DB r4clean)

rom=$(sr_rom) || exit 2
[ -x "$ctrl" ] || { echo "missing control exe: $ctrl" >&2; exit 1; }
[ -f "$route" ] || { echo "missing probe route: $route" >&2; exit 2; }
mkdir -p "$out"
rc=0
for v in "${variants[@]}"; do
  src="build-$v/ShadowrunSNESRecomp"
  if [ ! -x "$src" ]; then
    echo "==== $v: no exe at $src (build it with tests/seed_variant.sh $v)"
    rc=1
    continue
  fi
  anchor="$out/anchor_$v"
  rm -rf "$anchor"
  mkdir -p "$anchor"
  cp -p "$src" "$anchor/ShadowrunSNESRecomp" || { rc=1; continue; }
  ln -sfn "$PWD/libs" "$anchor/libs"

  echo "==== $v: parity leg $ctrl vs $anchor (route $route)"
  plog="$out/shift_parity_$v.log"
  PORT_BIN="$ctrl" PORT_BIN2="$anchor/ShadowrunSNESRecomp" \
    ./tests/parity.sh "$route" >"$plog" 2>&1
  prc=$?
  grep -E 'run[12] +|exe  *sha256|exit: script|identical over|first divergence|frames differ|generated_set' \
    "$plog" | sed 's/^/     /'

  # Both legs must have run the same route to the same end, or the probes below
  # compare two different amounts of play (the exit-3 legs from this round's
  # sweep are the cautionary case).
  e1=$(grep -oE 'exit: script [a-z]+ after [0-9]+ frames' "tests/out/run1.log" | tail -1)
  e2=$(grep -oE 'exit: script [a-z]+ after [0-9]+ frames' "tests/out/run2.log" | tail -1)
  if [ -z "$e1" ] || [ "$e1" != "$e2" ]; then
    echo "     NOT COMPARABLE: run1 '$e1' vs run2 '$e2' -- probes skipped"
    rc=1
    continue
  fi
  echo "     both legs: $e1 (parity rc=$prc)"

  pmd="$out/shift_$v.md"
  {
    printf '# shift probe: %s vs the control, on the probe route\n' "$v"
    printf '#\n# what: does aligning the two legs on the guest timeline remove the\n'
    printf '# state difference, or does the difference survive alignment?\n'
    printf '# how:  tests/parity.sh %s (PORT_BIN=%s, PORT_BIN2=%s), then\n' \
      "$route" "$ctrl" "$anchor/ShadowrunSNESRecomp"
    printf '#       tests/framedump_diff.py tick / shift / drift / state / byte on tests/out/run1 run2\n'
    printf '#       byte addresses probed: %s\n' "$bytes"
    printf '#       both legs: %s\n' "$e1"
    printf '#       exe run1=%s run2=%s\n' \
      "$(grep -oE 'exe  *sha256 +[0-9a-f]{16}' "$plog" | sed -n '1s/.* //p')" \
      "$(grep -oE 'exe  *sha256 +[0-9a-f]{16}' "$plog" | sed -n '2s/.* //p')"
    printf '\n==== tick (guest tick offset timeline)\n'
    python3 tests/framedump_diff.py tick tests/out/run1 tests/out/run2 2>&1
    printf '\n==== shift (same guest tick, host frames aligned, label bytes excluded)\n'
    python3 tests/framedump_diff.py shift tests/out/run1 tests/out/run2 2>&1
    printf '\n==== drift (per-frame differing 1 KiB blocks, then the exact bytes at the onset)\n'
    python3 tests/framedump_diff.py drift tests/out/run1 tests/out/run2 2>&1
    printf '\n==== state (which non-label bytes differ at the same host frame, and their values)\n'
    python3 tests/framedump_diff.py state tests/out/run1 tests/out/run2 2>&1
    printf '\n==== byte probes (the latch bytes the combat-route checkpoint diff names)\n'
    for a in $bytes; do
      python3 tests/framedump_diff.py byte tests/out/run1 tests/out/run2 "$a" 2>&1
      printf '\n'
    done
  } >"$pmd" 2>&1
  echo "     probes -> $pmd"
  tail -3 "$pmd" | sed 's/^/     /'
done
exit $rc
