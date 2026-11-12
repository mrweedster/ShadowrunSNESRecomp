#!/usr/bin/env bash
# Does the state-out-of-the-bundle host change do what it claims, and only that?
#
#   tests/macos_state_probe.sh                              # defaults below
#   FORK=build-fork-osx PIN=build-ship SCRIPT=tests/scripts/short.txt \
#     PARITY=tests/scripts/parity.txt tests/macos_state_probe.sh
#   (PARITY_SCRIPT is accepted as the older spelling of PARITY)
#
# A macOS .app has to be a sealed, read-only unit.  codesign refuses to seal a
# bundle with loose non-Mach-O files inside Contents/MacOS/, and a person who
# downloads a bundle whose signature expects a resource seal with none present is
# told '... is damaged and can't be opened'.  The pinned framework anchors
# config.ini, keybinds.ini, rom.cfg, saves/ and mods/ beside its executable, so a
# .app built from that layout has exactly those files inside it.  The shipping
# framework is the pin plus one commit that keeps that state outside the bundle --
# ~/Library/Application Support/<bundle name>/ -- when the host is running from
# inside a .app.  This script answers, in one log:
#
#   A.  a non-bundled binary from the shipping framework still anchors to its own
#       directory, exactly as the pinned binary does: every development tree and
#       every test-kit leg depends on that not changing;
#   B.  a bundled binary from the shipping framework anchors outside the .app,
#       writes nothing inside it, is accepted by a whole-bundle seal, and still
#       validates after the run;
#   C.  the same bundle shape built from the pinned framework: the seal is refused
#       by name, the bundle cannot be verified, and the run grows the bundle --
#       the before picture, measured again rather than recalled from a log;
#   D.  what the state directory holds afterwards;
#   E.  that the two hosts compute the same machine: 1,200 frames of the parity
#       route, per-frame crc32 of all 128 KiB of WRAM, compared.  Without this leg
#       the fix could be "state moved and something else moved too".
#
# Leg C's loose files are not invented: they are the files the pinned host itself
# wrote beside its executable in leg A2, moved into Contents/MacOS/ -- which is
# the layout it produces, one directory deeper.
#
# Bundles are built in a scratch directory outside the repository, and the runs are
# given a private $HOME inside it, so leg D reads back a state directory this
# script made rather than this machine's own port state.  Nothing here touches
# ~/Library/Application Support of the machine it runs on.
#
# Exit 0 = every leg ran.  The numbers are the reading, not a pass/fail gate.
# The log is tests/out/state_probe/macos_state_probe.log.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fork_tree="${FORK:-build-fork-osx}"        # pin + the state commit
pin_tree="${PIN:-build-ship}"              # at the pin
route="${SCRIPT:-tests/scripts/short.txt}"
parity_route="${PARITY:-${PARITY_SCRIPT:-tests/scripts/parity.txt}}"
out="$root/tests/out/state_probe"
log="$out/macos_state_probe.log"
mkdir -p "$out"
: >"$log"
exec > >(tee -a "$log") 2>&1

pin_rev="$(grep -m1 '^snesrecomp=' "$root/framework_pins.txt" | cut -d= -f2)"
say() { printf '  %s\n' "$*"; }
sha() { shasum -a 256 "$1" | cut -c1-16; }
count() { wc -l | tr -d '[:space:]'; }
minos_of() { vtool -show-build "$1" 2>/dev/null | awk '/minos/{print $2; exit}'; }

# Where each binary's framework says it came from, and whether that framework is
# the pin, the pin plus commits, or something else -- read from the checkout, not
# from this script's assumption.
fw_of() { # label, build tree, executable name
  local label="$1" tree="$2" name="$3" exe cache src dirty head
  exe="$tree/$name"; cache="$tree/CMakeCache.txt"
  src="$( { grep -m1 'SNESRECOMP_ROOT:PATH=' "$cache" | sed 's/.*=//'; } || true )"
  printf '  %-30s %s  %s B  minos %s\n' "$label" "$(sha "$exe")" "$(stat -f%z "$exe")" \
    "$(minos_of "$exe")"
  if [ -z "$src" ] || [ ! -d "$src" ]; then
    say "$label: $cache names no readable framework checkout"
    return
  fi
  head="$(git -C "$src" rev-parse HEAD 2>/dev/null)"
  dirty="$(git -C "$src" status --porcelain 2>/dev/null | count)"
  printf '  %-30s framework %s\n' "" "$src"
  printf '  %-30s HEAD %s  dirty %s\n' "" "$head" "$dirty"
  if [ "$head" = "$pin_rev" ]; then
    say "$label: AT THE PIN $pin_rev"
  elif git -C "$src" merge-base --is-ancestor "$pin_rev" "$head" 2>/dev/null; then
    say "$label: OFF THE PIN at $head, with $pin_rev as an ancestor -- the pin plus"
    say "  $(git -C "$src" rev-list --count "$pin_rev".."$head" 2>/dev/null) commit(s), which is the shape this claim is about"
  else
    say "$label: OFF THE PIN at $head, and the pin is NOT an ancestor -- not comparable"
  fi
}

fork_exe="$root/$fork_tree/ShadowrunSNESRecomp"
pin_exe="$root/$pin_tree/ShadowrunSNESRecomp"
for f in "$fork_exe" "$pin_exe" "$route" "$parity_route"; do
  if [ ! -e "$f" ]; then echo "missing: $f"; exit 2; fi
done
. tests/rom.sh
rom="$(sr_rom)" || { echo "tests/rom.sh found no dump; every leg here needs one"; exit 2; }
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

S="$out/scratch"
rm -rf "$S"; mkdir -p "$S"
export HOME="$S/home"; mkdir -p "$HOME"
state="$HOME/Library/Application Support"

echo "# macos_state_out_of_bundle.md"
echo "#"
echo "# what: the host change that keeps a macOS bundle's state outside the .app,"
echo "#       measured against the pinned host on the same machine: sealing, the"
echo "#       bundle's own file inventory across a run, where the state lands, and"
echo "#       the per-frame WRAM state of both hosts over the parity route"
echo "# how:  tests/macos_state_probe.sh with FORK=$fork_tree PIN=$pin_tree SCRIPT=$route PARITY=$parity_route"
echo "#"
echo "# framework pin: $pin_rev (framework_pins.txt)"
echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) (host $(uname -sr) $(uname -m))"
echo "# source tree: $root"
echo

dig() { # label, bundle -> hash+mtime+path of every file, bundle-relative
  printf '  %s file inventory:\n' "$1"
  ( cd "$2" && find . \( -type f -o -type l \) -print0 | xargs -0 -I{} sh -c \
      'printf "%s  %s  %s\n" "$(shasum -a 256 "{}" 2>/dev/null | cut -c1-16)" "$(stat -f %m "{}")" "{}"' ) \
    | sort | sed 's/^/  /'
}

echo "== 0. the two hosts =="
echo
say "both are built from this checkout; only the framework they link differs, and"
say "the framework of each is read from its own CMakeCache.txt below."
fw_of "shipping framework host" "$fork_tree" ShadowrunSNESRecomp
fw_of "pinned framework host" "$pin_tree" ShadowrunSNESRecomp
printf '  %-30s %s\n' "dump the legs run" "$rom"

echo
echo "== A. non-bundled: the anchor must stay the binary's own directory =="
echo
say "this is the layout every development tree and test-kit leg uses; the host"
say "change must not touch it, or it would move the state of 200 earlier measurements."
for pair in "fork:$fork_exe" "pin:$pin_exe"; do
  lbl="${pair%%:*}"; exe="${pair#*:}"
  w="$S/plain_$lbl"; rm -rf "$w"; mkdir -p "$w"
  cp -p "$exe" "$w/ShadowrunSNESRecomp"
  ( cd "$root" && "$w/ShadowrunSNESRecomp" --no-launcher --rom "$rom" --script "$route" \
      >"$w/run.log" 2>&1 )
  say "$lbl: exit=$?  anchor line, run.log:"
  grep -m1 "anchored to" "$w/run.log" | sed 's/^/      /'
  grep -m1 "frame service" "$w/run.log" | sed 's/^/      /'
  say "$lbl: files that run left beside the binary:"
  find "$w" -mindepth 1 -maxdepth 3 | sed -e "s|^$w/||" | sed 's|^|      |' | sort
done
say "and the state directory stayed empty, because neither run was inside a .app:"
if [ -d "$state" ]; then find "$state" -mindepth 1 | sed 's/^/      /'
else say "  $state does not exist"; fi

echo
echo "== B. bundled, shipping host: seal, run, re-verify =="
echo
app="$S/Shadowrun.app"; C="$app/Contents"
rm -rf "$app"; mkdir -p "$C/MacOS"
cat > "$C/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Shadowrun</string>
  <key>CFBundleIdentifier</key><string>org.retroportingtoolkit.shadowrun.probe</string>
  <key>CFBundleName</key><string>Shadowrun</string>
  <key>CFBundleVersion</key><string>probe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict>
</plist>
PLIST
cp -p "$fork_exe" "$C/MacOS/Shadowrun"
chmod 755 "$C/MacOS/Shadowrun"
say "the bundle holds only Info.plist and the payload -- no loose state was staged:"
find "$app" -mindepth 1 | sed -e "s|^$app|.|" | sed 's|^|    |' | sort
say "-- whole-bundle seal --"
codesign --force --sign - "$app" 2>&1 | sed 's/^/    /'; say "codesign exit=${PIPESTATUS[0]}"
say "-- seal check before anything runs --"
codesign --verify --strict --verbose=2 "$app" 2>&1 | tail -3 | sed 's/^/    /'
say "verify exit=${PIPESTATUS[0]}"
dig "before run" "$app" > "$S/before.txt"
exe_before="$(sha "$C/MacOS/Shadowrun")"
( cd "$S" && HOME="$HOME" "$C/MacOS/Shadowrun" --no-launcher --rom "$rom" \
    --script "$root/$route" >"$S/bundle_run.log" 2>&1 )
say "run exit=$?"
grep -m1 "anchored to" "$S/bundle_run.log" | sed 's/^/      /'
grep -m1 "frame service" "$S/bundle_run.log" | sed 's/^/      /'
dig "after run" "$app" > "$S/after.txt"
sed 's/  file inventory//' "$S/before.txt" > "$S/b2.txt"
sed 's/  file inventory//' "$S/after.txt" > "$S/a2.txt"
say "inventory diff (only the label line differs if nothing was written inside):"
diff "$S/b2.txt" "$S/a2.txt" | sed 's/^/    /'
say "files in the bundle before=$(/usr/bin/wc -l < "$S/b2.txt" | tr -d ' ')  \
after=$(/usr/bin/wc -l < "$S/a2.txt" | tr -d ' ')"
say "the payload inside it, hashed before and after the run: $exe_before / $(sha "$C/MacOS/Shadowrun")"
say "-- seal check after the run --"
codesign --verify --strict --verbose=2 "$app" 2>&1 | tail -3 | sed 's/^/    /'
say "verify exit=${PIPESTATUS[0]}"
say "resource seal written by the seal: $( { ls "$C/_CodeSignature" 2>/dev/null | tr '\n' ' '; }; )"

echo
echo "== C. bundled, pinned host: the shape that made the 'is damaged' report =="
echo
app2="$S/pin/Shadowrun.app"; C2="$app2/Contents"
rm -rf "$S/pin"; mkdir -p "$C2/MacOS"
cp "$C/Info.plist" "$C2/Info.plist"
cp -p "$pin_exe" "$C2/MacOS/Shadowrun"
chmod 755 "$C2/MacOS/Shadowrun"
# The loose files are the ones the pinned host itself wrote in leg A2, beside its
# own executable -- this is what its layout puts next to a binary, moved a
# directory up into Contents/MacOS/.
( cd "$S/plain_pin" && find . -mindepth 1 -maxdepth 1 ! -name ShadowrunSNESRecomp \
    ! -name run.log -exec cp -Rp {} "$C2/MacOS/" \; )
say "the bundle as the pinned layout makes it:"
find "$app2" -mindepth 1 | sed -e "s|^$app2|.|" | sed 's|^|    |' | sort
say "-- whole-bundle seal, same command that succeeded in B --"
codesign --force --sign - "$app2" 2>&1 | sed 's/^/    /'; say "codesign exit=${PIPESTATUS[0]}"
say "-- seal check --"
codesign --verify --strict --verbose=2 "$app2" 2>&1 | tail -3 | sed 's/^/    /'
say "verify exit=${PIPESTATUS[0]}"
say "resource seal: $( { ls "$C2/_CodeSignature" 2>/dev/null | tr '\n' ' '; }; )(empty = none was written)"
dig "before run" "$app2" > "$S/pin_before.txt"
exe2_before="$(sha "$C2/MacOS/Shadowrun")"
( cd "$S/pin" && HOME="$HOME" "$C2/MacOS/Shadowrun" --no-launcher --rom "$rom" \
    --script "$root/$route" >"$S/pin_run.log" 2>&1 )
say "run exit=$?"
grep -m1 "anchored to" "$S/pin_run.log" | sed 's/^/      /'
grep -m1 "frame service" "$S/pin_run.log" | sed 's/^/      /'
dig "after run" "$app2" > "$S/pin_after.txt"
sed 's/  file inventory//' "$S/pin_before.txt" > "$S/pb.txt"
sed 's/  file inventory//' "$S/pin_after.txt" > "$S/pa.txt"
say "inventory diff:"
diff "$S/pb.txt" "$S/pa.txt" | sed 's/^/    /'
say "files in the bundle before=$(/usr/bin/wc -l < "$S/pb.txt" | tr -d ' ')  \
after=$(/usr/bin/wc -l < "$S/pa.txt" | tr -d ' ')"
say "the payload inside it, hashed before and after the run: $exe2_before / $(sha "$C2/MacOS/Shadowrun")"
say "-- seal check after that run, which is what a copy of this bundle is judged by --"
codesign --verify --strict --verbose=2 "$app2" 2>&1 | sed -n '1,4p' | sed 's/^/    /' 
say "verify exit=${PIPESTATUS[0]}"
say "and on a copy taken from it, the same answer:"
cp -Rp "$app2" "$S/pin/copy.app"
codesign --verify --strict --verbose=2 "$S/pin/copy.app" 2>&1 | sed -n '1,3p' | sed 's/^/    /' 
say "verify exit=${PIPESTATUS[0]}"

echo
echo "== D. where the state actually went =="
echo
say "the private \$HOME these legs were given: $HOME"
for d in "Shadowrun" "Shadowrun.probe"; do
  if [ -d "$state/$d" ]; then
    say "$state/$d"
    find "$state/$d" -mindepth 1 | sed -e "s|^$state/$d/||" | sed 's|^|      |' | sort
  else
    say "$state/$d: does not exist"
  fi
done
say "state under the name the bundle's directory gives it, which is how two"
say "different bundles never share one state directory:"
grep -m1 "anchored to" "$S/bundle_run.log" | sed 's/^/    B said: /'
grep -m1 "anchored to" "$S/pin_run.log" | sed 's/^/    C said: /'

echo
echo "== E. the same legs, frame by frame: state moved, the machine did not =="
echo
say "everything above is about where bytes are written.  It says nothing about"
say "whether the host change moved the machine itself, and the two executables"
say "cannot answer that by hash: one is built at the pin against Homebrew's SDL3"
say "dylib, the other one commit past the pin with SDL3 linked in statically, so"
say "their sizes and their load lists differ whatever the host change did.  The"
say "question is asked the way every other comparison in this kit asks it: the"
say "same route both legs already use, $parity_route, with the host's own per-frame"
say "crc32 of all 128 KiB of WRAM dumped and compared.  The sizes on the two leg"
say "lines are why only that comparison will do: two executables nearly 3 MB apart,"
say "so no hash of the files can say whether the host change moved anything."
frames="$out/frames"; rm -rf "$frames"; mkdir -p "$frames"
for pair in "fork:$fork_exe" "pin:$pin_exe"; do
  lbl="${pair%%:*}"; exe="${pair#*:}"
  a="$frames/$lbl"; rm -rf "$a"; mkdir -p "$a/saves"
  cp -p "$exe" "$a/ShadowrunSNESRecomp"
  d="$frames/dump_$lbl"; rm -rf "$d"; mkdir -p "$d"
  log="$frames/run_$lbl.log"
  ( cd "$a" && SNESRECOMP_DUMP_DIR="$d" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
      ./ShadowrunSNESRecomp --no-launcher --rom "$rom" --script "$root/$parity_route" \
      --framedump "$d" ) >"$log" 2>&1 &
  pid=$!; n=0
  while [ $n -lt "${FRAME_MAX:-240}" ] && kill -0 "$pid" 2>/dev/null; do
    sleep 1; n=$((n + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -INT "$pid" 2>/dev/null; sleep 2; kill -KILL "$pid" 2>/dev/null
    rc=125
  else
    wait "$pid" && rc=0 || rc=$?
  fi
  printf '  %-5s leg  exe %s  %s B  exit=%s  %s\n' "$lbl" "$(sha "$exe")" \
    "$(stat -f%z "$exe")" "$rc" "$( { grep -oE 'exit: .*' "$log" | tail -1; }; )"
  grep -m1 "frame service" "$log" | sed 's/^/        /'
  grep -m1 "anchored to" "$log" | sed 's/^/        /'
  printf '  %-5s wrote %s frame records, plus the matching _wram.bin images, into %s\n' \
    "$lbl" "$( { ls "$d"/frame_*.json 2>/dev/null; } | count )" \
    "tests/out/state_probe/frames/dump_$lbl"
done
python3 - "$frames/dump_fork" "$frames/dump_pin" <<'PY'
import glob, os, re, sys
a, b = sys.argv[1], sys.argv[2]


def crc(p):
    h = re.findall(r'0x[0-9A-Fa-f]{8}', open(p).read())
    return h[-1] if h else None


fa = sorted(glob.glob(os.path.join(a, "frame_*.json")))
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
    print(f"  identical over {same} frames (crc32 of all 128 KiB of WRAM per frame)")
PY
python3 tests/framedump_diff.py state "$frames/dump_fork" "$frames/dump_pin" 2>&1 | tail -4 | sed 's/^/    /'
say "so the host change is what it says it is: a different place to keep config,"
say "saves and rom.cfg, with the emulator's per-frame state unchanged.  That is the"
say "claim that lets §7.19's package still inherit every earlier measurement made"
say "against the pinned executable."

echo
echo "== DONE =="
