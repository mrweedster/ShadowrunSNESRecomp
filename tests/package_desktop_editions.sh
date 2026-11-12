#!/usr/bin/env bash
# Prove tools/package_desktop.py labels a Windows/Linux archive from the build
# tree, not from a flag the caller can get wrong.
#
#   ./tests/package_desktop_editions.sh
#
# The universal build is the default, and its executable accepts all three
# dumps; a single-edition tree accepts one. An archive whose README names the
# wrong dump is a packaging bug a player only finds after the download, so the
# packager reads SHADOWRUN_EDITIONS / SHADOWRUN_UNIVERSAL / SHADOWRUN_EDITION
# from CMakeCache.txt and refuses an --edition that disagrees with the tree.
# This test builds fake trees whose only real file is the executable and checks
# the stems, the README text and the refusals. No ROM, compiler or network.
set -euo pipefail
cd "$(dirname "$0")/.."

out="${OUT:-tests/out/package_desktop}"
rm -rf "$out"
mkdir -p "$out"
trap 'rm -rf "$out"' EXIT

python="${PYTHON:-}"
if [ -z "$python" ]; then
  if command -v python3 >/dev/null 2>&1; then python=python3; else python=python; fi
fi

version="$(sed -n '1p' VERSION | tr -d '[:space:]')"
[ -n "$version" ] || { echo "VERSION is empty" >&2; exit 1; }

# fake_tree <name> <universal ON|OFF> <editions> <edition> <embed ON|OFF>
fake_tree() {
  local name=$1 universal=$2 editions=$3 edition=$4 embed=$5
  local dir="$out/$name"
  mkdir -p "$dir"
  cat >"$dir/CMakeCache.txt" <<EOF
// fake cache for tests/package_desktop_editions.sh
SHADOWRUN_EDITIONS:STRING=$editions
SHADOWRUN_EDITION:STRING=$edition
SHADOWRUN_UNIVERSAL:BOOL=$universal
SHADOWRUN_EMBED_ROM:BOOL=$embed
EOF
  if [ -x /bin/true ]; then
    cp /bin/true "$dir/ShadowrunSNESRecomp"
  else
    cp /usr/bin/true "$dir/ShadowrunSNESRecomp"
  fi
  chmod +x "$dir/ShadowrunSNESRecomp"
}

# linux-arm64 is never this host, so the packager's --help smoke check is
# skipped on every CI runner and this test needs no runnable target binary.
package() {
  "$python" tools/package_desktop.py --platform linux-arm64 --dist "$out/dist" "$@"
}

rc=0
refuse() {
  local what=$1
  shift
  if package "$@" >"$out/last.out" 2>"$out/last.err"; then
    echo "FAIL: $what was accepted" >&2
    rc=1
  else
    echo "ok   refused: $what"
    sed -n '1p' "$out/last.err" | sed 's/^/       /'
  fi
}

fake_tree universal ON  'us;de;sv' us OFF
fake_tree de        OFF de         de OFF
fake_tree us        OFF us         us OFF
fake_tree embed     OFF us         us ON

echo "== universal tree, detected from the cache =="
package --build "$out/universal" --keep-stage >"$out/universal.out"
stem="shadowrun-universal-$version-linux-arm64"
grep -q "$stem" "$out/universal.out" || { echo "FAIL: no $stem in output" >&2; rc=1; }
readme="$out/dist/$stem/README.txt"
for name in 'Shadowrun (USA).sfc' 'Shadowrun (Germany).sfc' 'Shadowrun (Sweden).sfc'; do
  grep -qF "$name" "$readme" || { echo "FAIL: README does not list $name" >&2; rc=1; }
done
for identity in rom_identity.txt rom_identity.de.txt rom_identity.sv.txt; do
  grep -qF "$identity" "$readme" || { echo "FAIL: README does not name $identity" >&2; rc=1; }
done
grep -qF 'Editions: USA' "$readme" || { echo "FAIL: README has no editions line" >&2; rc=1; }
grep -q 'selects   : the edition is chosen' "$out/dist/$stem/BUILD_INFO.txt" \
  || { echo "FAIL: BUILD_INFO does not say how the edition is chosen" >&2; rc=1; }
echo "ok   $stem lists all three dumps"

echo
echo "== single-edition trees, detected from the cache =="
package --build "$out/de" --keep-stage >"$out/de.out"
stem="shadowrun-de-$version-linux-arm64"
grep -q "$stem" "$out/de.out" || { echo "FAIL: no $stem in output" >&2; rc=1; }
grep -qF 'Shadowrun (Germany).sfc' "$out/dist/$stem/README.txt" \
  && grep -qF 'rom_identity.de.txt' "$out/dist/$stem/README.txt" \
  && echo "ok   $stem names the German dump and identity" \
  || { echo "FAIL: German README is wrong" >&2; rc=1; }

package --build "$out/us" >"$out/us.out"
stem="shadowrun-$version-linux-arm64"
grep -q "$stem" "$out/us.out" || { echo "FAIL: no $stem in output" >&2; rc=1; }
echo "ok   $stem (USA keeps the unsuffixed name)"

echo
echo "== subset and narrowed trees follow SHADOWRUN_EDITIONS =="
fake_tree two      ON  'us;de' us OFF
fake_tree de-narrow ON  de      us OFF
package --build "$out/two" --keep-stage >"$out/two.out"
stem="shadowrun-universal-$version-linux-arm64"
grep -q "$stem" "$out/two.out" || { echo "FAIL: no $stem for us;de" >&2; rc=1; }
grep -qF 'Shadowrun (USA).sfc' "$out/dist/$stem/README.txt" \
  && grep -qF 'Shadowrun (Germany).sfc' "$out/dist/$stem/README.txt" \
  && ! grep -qF 'Shadowrun (Sweden).sfc' "$out/dist/$stem/README.txt" \
  && echo "ok   us;de names both linked dumps and omits Sweden" \
  || { echo "FAIL: us;de README does not match the linked set" >&2; rc=1; }

package --build "$out/de-narrow" --keep-stage >"$out/de-narrow.out"
stem="shadowrun-de-$version-linux-arm64"
grep -q "$stem" "$out/de-narrow.out" || { echo "FAIL: no $stem for the narrowed tree" >&2; rc=1; }
grep -qF 'rom_identity.de.txt' "$out/dist/$stem/README.txt" \
  && echo "ok   a universal build narrowed to de is labelled German" \
  || { echo "FAIL: narrowed tree kept the USA default" >&2; rc=1; }

echo
echo "== a flag that disagrees with the tree is refused =="
refuse '--edition de on a universal tree' \
  --build "$out/universal" --edition de
refuse '--edition universal on a single-edition tree' \
  --build "$out/de" --edition universal
refuse '--edition sv on the USA tree' \
  --build "$out/us" --edition sv
refuse '--personal on a shareable tree' \
  --build "$out/us" --personal
refuse '--personal on a universal tree' \
  --build "$out/universal" --personal

echo
echo "== the personal form still works on an embedded tree =="
package --build "$out/embed" --personal --keep-stage >"$out/embed.out"
stem="shadowrun-embed-$version-linux-arm64-personal"
grep -q "$stem" "$out/embed.out" || { echo "FAIL: no $stem in output" >&2; rc=1; }
grep -qF 'PERSONAL BUILD' "$out/dist/$stem/README.txt" \
  || { echo "FAIL: personal README is not marked" >&2; rc=1; }
echo "ok   $stem"

echo
if [ "$rc" -eq 0 ]; then
  echo "PASS: package_desktop.py labels windows/linux archives from the tree"
else
  echo "FAIL" >&2
fi
exit "$rc"
