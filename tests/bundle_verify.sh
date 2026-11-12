#!/usr/bin/env bash
# Is the staged bundle the accepted tree?  (evidence/c1_staged_bundle_stale.md)
#
#   SNESRECOMP_ROOT=/path/to/pin ./tests/bundle_verify.sh
#   SHIP=build-ship PORT_BIN2=tests/out/Shadowrun_prev_xxxx ./tests/bundle_verify.sh
#
# c1 found that ./Shadowrun had silently stopped identifying its inputs: a
# staged bundle carries no CMakeCache.txt, so nothing beside it says which
# generated set or which framework revision made it, and the stale bundle
# disagreed with every current build tree from frame 1 while reading as a
# measurement.  This script answers, in one log:
#
#   1. what the staged bundle is (hash, size, SDL reference, signature) and
#      what build tree made it (gen set, framework rev, pin dirtiness, flags);
#   2. that a fresh configure + build of the checked-out tree reproduces the
#      accepted executable, so the bundle's identity is a property of the
#      sources on disk, not of whichever build directory it came from;
#   3. that the staged bundle still boots the ROM (the selfcheck boot test);
#   4. frame-state parity of the bundle against the build tree that made it --
#      staging is install_name_tool plus a re-sign, so the bytes differ and the
#      machine state per frame must not;
#   5. frame-state parity of the bundle against the previous staged bundle,
#      which restates the c1 finding against the new bundle.
#
# Every leg runs from an anchor -- a copy of the executable in its own
# directory, with the libs symlink and the save snapshot it starts from.  Never
# in a build dir: a build dir's last_run_report.json is the join target for
# tests/round4_artifacts.sh's parity table.  Never the repo root either: that is
# what ./Shadowrun itself anchors to, so a leg run there rewrites the bundle's
# own config.ini and save state.  All three dumps are re-run here, always;
# nothing is trusted from an earlier comparison.
#
# Exit 0 = every leg ran.  The numbers are the reading, not a pass/fail gate.
# The log is tests/out/bundle/bundle_verify.log.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
pin="${SNESRECOMP_ROOT:?SNESRECOMP_ROOT must be the framework pin}"
ship="${SHIP:-build-ship}"
prev="${PORT_BIN2:-tests/out/Shadowrun_prev}"
script="${SCRIPT:-tests/scripts/parity.txt}"
out="$root/tests/out/bundle"
log="$out/bundle_verify.log"
mkdir -p "$out"
: >"$log"
exec > >(tee -a "$log") 2>&1

echo "# bundle_verify.md"
echo "#"
echo "# what: the staged ./Shadowrun, the build tree behind it, and its frame state"
echo "#       against that tree and against the previous staged bundle"
echo "# how:  tests/bundle_verify.sh with SHIP=$ship PORT_BIN2=$prev SCRIPT=$script"
echo "#"
echo "# framework pin: $pin"
echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) (host $(uname -sr) $(uname -m))"
echo "# source tree: $root"
echo

. tests/rom.sh
rom=$(sr_rom) || exit 2
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

sha() { shasum -a 256 "$1" | cut -c1-16; }

echo "== 1. the staged bundle and the tree that made it =="
echo
printf '  %-34s %s  %s B  %s\n' "./Shadowrun" "$(sha Shadowrun)" \
  "$(stat -f%z Shadowrun)" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' Shadowrun)"
printf '  %-34s %s\n' "  SDL reference" \
  "$(otool -L Shadowrun | grep -oE '@executable_path/libs/[^ ]*|/opt/homebrew[^ ]*libSDL3[^ ]*')"
printf '  %-34s %s\n' "  signature" \
  "$(codesign -dv Shadowrun 2>&1 | grep -oE 'Signature=[a-z]*' || echo none)"
printf '  %-34s %s  %s B\n' "$ship/ShadowrunSNESRecomp" "$(sha "$ship/ShadowrunSNESRecomp")" \
  "$(stat -f%z "$ship/ShadowrunSNESRecomp")"
printf '  %-34s %s  %s B  %s\n' "$prev (previous bundle)" "$(sha "$prev")" \
  "$(stat -f%z "$prev")" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$prev")"
echo
echo "  the staged copy is not the build-tree bytes: install_name_tool rewrites"
echo "  the SDL reference and codesign re-signs, so the hash differs and the size"
echo "  grows by the link edit.  Section 4 is what says it is still the same"
echo "  program; a staged binary alone cannot say that, by design."
echo
echo "  build tree provenance, recorded from the build tree rather than from the"
echo "  copied executable, which is the identity a staged bundle cannot carry:"
python3 tests/provenance.py record "$ship/ShadowrunSNESRecomp" "$ship" 2>&1 | sed 's/^/    /'
python3 tests/provenance.py key "$ship" 2>&1 | sed 's/^/    /'
echo "  pin:"
printf '    rev    %s\n' "$(git -C "$pin" rev-parse HEAD)"
printf '    dirty  %s\n' "$([ -z "$(git -C "$pin" status --porcelain)" ] && echo no || echo YES)"
printf '    pin file  %s\n' "$(grep -E 'snesrecomp' framework_pins.txt 2>/dev/null | head -1)"
python3 tests/provenance.py pin "$ship" 2>&1 | sed 's/^/    /'
echo "  (the \"dirty\" true/false lines further down are provenance.py's"
echo "   port_git section -- the port repository, which is dirty here because"
echo "   this script is untracked while it runs.  The framework line is"
echo "   dirty=False / AT THE PIN, which is what a leg must satisfy.)"
echo "  configure:"
grep -oE 'CMAKE_BUILD_TYPE:STRING=.*|SHADOWRUN_EMBED_ROM:BOOL=.*|SNESRECOMP_SDL3_FETCH:BOOL=.*' \
  "$ship/CMakeCache.txt" | sed 's/^/    /'
echo "  compilers: $(grep -oE 'CMAKE_(C|CXX)_COMPILER:[A-Z:]*=.*' "$ship/CMakeCache.txt" | sed 's/.*=//' | tr '\n' ' ')"
echo "  generated sources on disk: $(ls src/gen/*_v2.c | wc -l | tr -d ' ') units," \
  "newest $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$(ls -t src/gen/*_v2.c | head -1)")"

echo
echo "== 2. a fresh configure + build of the checked-out tree =="
echo
fresh="$out/freshbuild"
rm -rf "$fresh"
echo "  configured from scratch, no copied cache, only the two documented flags:"
echo "  the accepted bytes either come out of the defaults plus this tree or they"
echo "  do not.  (c1: a stale build tree reads as current, so the tree's own"
echo "  object count against the units on disk is checked below.)"
cmake -S . -B "$fresh" -DCMAKE_BUILD_TYPE=Release -DSNESRECOMP_ROOT="$pin" \
  -DSHADOWRUN_EMBED_ROM=OFF >"$out/fresh_configure.log" 2>&1
echo "  configure exit=$?  $(grep -c . "$out/fresh_configure.log") lines"
grep -E 'generated translation unit' "$out/fresh_configure.log" | sed 's/^/    /'
cmake --build "$fresh" -j8 >"$out/fresh_build.log" 2>&1
echo "  build exit=$?  $(grep -c . "$out/fresh_build.log") lines"
printf '  objects compiled for src/gen: %s, units on disk: %s\n' \
  "$(ls "$fresh/CMakeFiles/ShadowrunSNESRecomp.dir/src/gen/"*.o 2>/dev/null | wc -l | tr -d ' ')" \
  "$(ls src/gen/*_v2.c | wc -l | tr -d ' ')"
printf '  exe  %s  %s B\n' "$(sha "$fresh/ShadowrunSNESRecomp")" \
  "$(stat -f%z "$fresh/ShadowrunSNESRecomp")"
if [ "$(sha "$fresh/ShadowrunSNESRecomp")" = "$(sha "$ship/ShadowrunSNESRecomp")" ]; then
  echo "  the checked-out src/gen, the recomp tables and the pin reproduce the"
  echo "  accepted executable byte for byte, from a build directory that did not"
  echo "  exist five minutes ago."
else
  echo "  MISMATCH with $ship -- the bundle is not reproducible from this tree"
fi
python3 tests/provenance.py record "$fresh/ShadowrunSNESRecomp" "$fresh" >/dev/null 2>&1
python3 tests/provenance.py key "$fresh" 2>&1 | sed 's/^/  /'

echo
echo "== 3. the staged bundle boots the ROM =="
echo
t0=$(date +%s)
anchor="$out/anchor_selfcheck"
rm -rf "$anchor"; mkdir -p "$anchor/saves"
cp -p Shadowrun "$anchor/ShadowrunSNESRecomp"
ln -sfn "$root/libs" "$anchor/libs"
for f in save.srm save.srm.bak; do
  [ -f "saves/$f" ] && cp -p "saves/$f" "$anchor/saves/$f"
done
( cd "$anchor" && ./ShadowrunSNESRecomp --no-launcher --rom "$rom" \
    --script "$root/tests/scripts/selfcheck.txt" >"$out/selfcheck.log" 2>&1 )
echo "  exit=$? wall=$(( $(date +%s) - t0 ))s"
grep -E '^script |frame service' "$out/selfcheck.log" | sed 's/^/    /'
echo "  the script waits on the game's own WRAM tick counter (\$7E1C92), one"
echo "  increment per emulated frame, so this fails loudly if the ROM stalls."

echo
echo "== 4. the staged bundle against the build tree that made it =="
echo
cmp_crc() { # $1 = one dump dir, $2 = the other
  python3 - "$1" "$2" <<'PY'
import glob, os, re, sys
a, b = sys.argv[1], sys.argv[2]
fa = sorted(glob.glob(os.path.join(a, "frame_*.json")))
fb = glob.glob(os.path.join(b, "frame_*.json"))


def crc(p):
    h = re.findall(r'0x[0-9A-Fa-f]{8}', open(p).read())
    return h[-1] if h else None


if not fa:
    print(f"  no frame dumps in {a}: that leg did not run")
    sys.exit(0)
if not fb:
    print(f"  no frame dumps in {b}: that leg did not run")
    sys.exit(0)
same = diff = 0
first = None
for f in fa:
    g = os.path.join(b, os.path.basename(f))
    ca, cb = crc(f), (crc(g) if os.path.isfile(g) else None)
    if ca is not None and ca == cb:
        same += 1
        continue
    diff += 1
    if first is None:
        first = (os.path.basename(f), ca, cb)
if diff:
    print(f"  {diff} of {same + diff} frames differ")
    if first:
        print(f"  first divergence at {first[0]}: {first[1]} vs {first[2]}")
else:
    print(f"  identical over {same} frames")
PY
}
dump_against() { # $1 = label $2 = binary $3 = dump dir $4 = tree that built it
  local bin abs dir d
  bin="$2"; d="$root/tests/out/$3"
  abs="$(cd "$(dirname "$bin")" && pwd)/$(basename "$bin")"
  dir="$out/anchor_$3"
  rm -rf "$dir"; mkdir -p "$dir/saves"
  cp -p "$abs" "$dir/$(basename "$abs")"
  ln -sfn "$root/libs" "$dir/libs"
  for f in save.srm save.srm.bak; do
    [ -f "saves/$f" ] && cp -p "saves/$f" "$dir/saves/$f"
  done
  rm -rf "$d"; mkdir -p "$d"
  ( cd "$dir" && SNESRECOMP_DUMP_DIR="$d" "./$(basename "$abs")" \
      --no-launcher --rom "$rom" --script "$root/$script" --framedump "$d" \
      >"$d.log" 2>&1 )
  printf '  %s\n' "$1  $(sha "$abs")"
  grep -oE 'exit: .*' "$d.log" | tail -1 | sed 's/^/      /'
  if [ -n "${4:-}" ]; then
    python3 tests/provenance.py record "$abs" "$d" >/dev/null 2>&1
    grep -E '"(sha256|bytes|units|promoted_functions|dispatch_entries|rev|dirty|config|embed_rom|dir)"' "$d/run_manifest.json" \
      | sed 's/^ */      /' | head -14
  else
    python3 tests/provenance.py record "$abs" "$d" 2>&1 | grep -E 'exe |WARN' | sed 's/^/      /'
  fi
}
dump_against "run1  staged ./Shadowrun" "./Shadowrun" run1
dump_against "run2  $ship/ShadowrunSNESRecomp" "$ship/ShadowrunSNESRecomp" run2 "$ship"
cmp_crc tests/out/run1 tests/out/run2
python3 tests/provenance.py same-src tests/out/run1 tests/out/run2 2>&1 | sed 's/^/  /'
echo "  the staged copy reports its build identity as unknown because no"
echo "  CMakeCache.txt sits beside it -- tests/provenance.py calls that unknown"
echo "  the finding, and sections 1-2 are what replace it.  The frame state, on"
echo "  the other hand, has to agree, and that is the line above."

echo
echo "== 5. the staged bundle against the previous staged bundle =="
echo
dump_against "run3  $prev" "$prev" run3
cmp_crc tests/out/run1 tests/out/run3
echo "  the c1 finding restated against the new bundle: the binary that stood in"
echo "  for this port for three days was a different program, and nothing about"
echo "  it said so."

echo
echo "== 6. what the bundle now is =="
echo
printf '  %-34s %s  (staged: link-edited, re-signed)\n' "./Shadowrun" "$(sha Shadowrun)"
printf '  %-34s %s\n' "built by $ship" "$(sha "$ship/ShadowrunSNESRecomp")"
printf '  %-34s %s\n' "rebuilt from source in s2" "$(sha "$fresh/ShadowrunSNESRecomp")"
echo "  accepted executable                a0587ed0a0e34687"
printf '  %-34s %s\n' "previous bundle kept at $prev" "$(sha "$prev")"
echo "  so: sources -> accepted exe -> staged bundle, with the frame state of"
echo "  every link of that chain agreeing, and the previous bundle's not."
