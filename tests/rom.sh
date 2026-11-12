# shellcheck shell=bash
# tests/rom.sh -- source this, do not run it.
#
# One answer to "which ROM does this binary open?", so no harness leg ever
# stops to ask. The host resolves a dump in this order:
#
#   launcher -> positional/--rom -> a .sfc beside the executable -> rom.cfg
#   beside the executable -> a GUI file picker
#
# The picker is the failure mode: a headless or scripted leg that reaches it
# blocks with a window on the user's screen and no way to answer, which reads
# as a hung run. Two habits cause it here, and both are the harness's fault,
# not the game's:
#
#   * legs that copy the binary into a fresh anchor under tests/out (two
#     binaries in one directory fight over saves/ and config.ini, so legs get
#     their own anchor -- and a fresh anchor has no rom.cfg), and
#   * legs that point --framedump at a scratch dir while the binary lives in a
#     build tree; that half is fine, the cache is keyed to the *executable*.
#
# It is also a provenance hazard, not just an annoyance: a picker that is
# waiting on someone's screen gets answered by whatever dump they last looked
# at. Measured the hard way while writing this file -- an empty --rom, the
# panel answered 77 s later, and the run continued against
# /Users/wee/Documents/Shadowrun (USA).sfc rather than the checkout's copy.
# That copy happened to be the same bytes (sha256 e6bc0a595d5c…), which is luck,
# not a contract; the capture's own rom_sha256 is what would have caught it.
#
# So: every leg gets a rom.cfg staged next to its copy of the binary AND an
# explicit --rom. Either one alone is enough; both means a typo in one cannot
# resurrect the picker. rom.cfg is git-ignored because it holds an absolute
# path into whoever's checkout this is.
#
#   . tests/rom.sh
#   rom="$(sr_rom)"          # absolute ROM path, or this shell exits
#   sr_rom_stage "$anchor"   # cache file beside a copied binary
#   "$exe" --no-launcher --rom "$rom" ...

# Repo root, whether the caller is the repo root or tests/ itself. Marker-first:
# every harness cd's to the root before sourcing this, so the root is the nearest
# ancestor holding framework_pins.txt. (Deriving it from BASH_SOURCE instead is
# how this file once resolved one level too high: the same `rom.cfg` fallback
# sourced from zsh has no BASH_SOURCE, and an ad-hoc timing run then handed the
# host an empty --rom and fell into the picker.)
sr_root() {
  local d="$PWD" src here
  while [ "$d" != "/" ] && [ ! -f "$d/framework_pins.txt" ]; do d=$(dirname "$d"); done
  if [ -f "$d/framework_pins.txt" ]; then printf '%s\n' "$d"; return 0; fi
  src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ]; then
    here=$(cd "$(dirname "$src")" && pwd)
    cd "$(dirname "$here")" && pwd
    return 0
  fi
  echo "tests/rom.sh: cannot find a repo root (no framework_pins.txt above $PWD)" >&2
  return 1
}

# The dump this project was generated from: repo-root rom.cfg, which is what
# tools/regen.sh and snesrecomp_target_rom_cache agree on. Validated, because
# a leg that runs against the wrong dump measures nothing and says nothing.
sr_rom() {
  local edition="${1:-us}" root rom name
  root=$(sr_root)
  case "$edition" in
    us) name="Shadowrun (USA).sfc" ;;
    de) name="Shadowrun (Germany).sfc" ;;
    sv) name="Shadowrun (Sweden).sfc" ;;
    *) echo "tests/rom.sh: unknown edition '$edition' (us, de or sv)" >&2; return 1 ;;
  esac
  # SR_ROM names one dump explicitly.  Otherwise the repo-root rom.cfg is the
  # USA tree's own record, so it is only trusted for the USA edition; a
  # language tree is generated from its own file and has no rom.cfg here.
  rom="${SR_ROM:-}"
  if [ -z "$rom" ] && [ "$edition" = us ]; then
    rom=$(sed -n '1p' "$root/rom.cfg" 2>/dev/null | tr -d '\r')
  fi
  if [ -z "$rom" ]; then
    rom="$root/$name"
  fi
  if [ ! -f "$rom" ]; then
    echo "tests/rom.sh: no ROM to run -- $rom is not a file" >&2
    echo "  set SR_ROM to an absolute path, fix repo-root rom.cfg (one absolute" >&2
    echo "  path, USA), or drop the dump at $root/$name" >&2
    return 1
  fi
  printf '%s\n' "$rom"
}

# Stage the cache for a binary that was copied somewhere else, so even a leg
# launched without --rom finds the dump instead of asking for it. Written from
# sr_rom rather than copied, so the staged file always names the ROM the leg
# resolves to.
sr_rom_stage() {
  local dest="${1:?sr_rom_stage: anchor dir required}"
  local edition="${2:-us}" rom
  rom=$(sr_rom "$edition") || return 1
  printf '%s\n' "$rom" >"$dest/rom.cfg"
}
