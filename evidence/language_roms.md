# Language editions — German and Swedish

> Historical note: these runs measured the three generated trees as separate
> builds. The tree now builds one universal executable that links USA, German
> and Swedish as program modules and selects one from the loaded ROM's digest;
> the measurements below still describe the per-edition code and cursor words
> that the universal table carries.

The port builds and plays the two European translations of Shadowrun as
separate editions. This record covers what was measured: the images' identity,
how far they differ from the USA release, the generated-code counts, the
headless boot and menu runs, and the WRAM measurement that moved the hand
cursor.

Host: macOS arm64, the same machine as `evidence/cross_platform.md`. Framework
checkout `2bfb3a63` (`mod/mouse`) with `tools/mouse_mod_framework.patch`
applied. Generated code is never committed; these runs used the trees the
commands below produce.

## Identity

| | USA | Germany | Sweden |
|---|---|---|---|
| file | `Shadowrun (USA).sfc` | `Shadowrun (Germany).sfc` | `Shadowrun (Sweden).sfc` |
| size | 1,048,576 B | 1,048,576 B | 1,048,576 B |
| header title | `SHADOWRUN` | `SHADOWRUN` | `SHADOWRUN` |
| region byte | `0x01` | `0x09` | `0x03` |
| CRC32 | `3f34dff0` | `e420e96f` | `30829d8e` |
| MD5 | `694be8df403ee59225c4b6b53c30fb7b` | `c3dac1984c06eee0f9889667f83dc869` | `cd22a7ff4908575f2fe5bd9f1e34ffc8` |
| SHA-1 | `b04afb21c94dab5c8b982d0c133898dd5ec1d104` | `3118192dd257c0666067bfb6797769f26bdf4489` | `830464152553faada700bb93d4bb6b8975f79e0a` |
| SHA-256 | `e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4` | `fda5d1cc6e5202ee311e4777eaa8614ed7361a8f77661aad52c7a1a8cf86a17f` | `4fb9eb8fa4d9c3a0b6c24bac5b0a0b0f079f083f5e6dfa937a161c8f4bcde853` |

All three are headerless 1 MiB LoROM images. The digests are in
`rom_identity.txt`, `rom_identity.de.txt` and `rom_identity.sv.txt`; the build
compiles in only the one its edition names.

## How far the translations differ

Byte comparison of the bare images:

| pair | differing bytes | runs |
|---|---:|---:|
| Germany vs USA | 685,458 | 21,781 |
| Sweden vs USA | 683,411 | 22,568 |
| Germany vs Sweden | 270,618 | — |

Per 64 KiB bank against USA, Germany:

```
b0  51611   b1  62959   b2  64360   b3  64502
b4  63343   b5  63356   b6  49918   b7      0
b8      0   b9      0   bA   3338   bB  63713
bC  48076   bD  43716   bE  43312   bF  63254
```

Banks 7–9 are identical; every bank that carries code or text differs heavily.
This is why one generated AOT set cannot serve all three ROMs, and why the
cursor's WRAM block moved.

## Generated code

Two seed sets were tried, and the difference is the reason `recomp-lle/`
exists.

**USA symbols (`recomp/`).** The German ROM generated 51 roots → 289 exact
variants: 242 AOT, 47 LLE, 4 banks. Its menus rendered correctly, but the
`nav1.txt` route — the same one the USA build follows into the first scene —
hit architectural `BRK` at `$80:FDF1` and then at `$80:00AB` onward. The USA
symbol addresses do not name the translations' routine entries.

**No USA symbols (`recomp-lle/`).** Both translations generate from the
ROM-agnostic directives only (`bank = N`, `auto_vectors`,
`tier_down_stubs`). The analyzer seeds reset/NMI from each cartridge header and
follows their call graph:

```
analysis: 9 roots -> 225 exact variants, 488 edges
analysis: 213 AOT-eligible, 12 LLE-only
v2_emit: 9 roots, 213 exact AOT variants, 12 LLE variants
v2_emit: 4 bank(s) emitted
```

Both builds then ran the full 16,188-frame `nav1.txt` route headless with no
`BRK` and exited on the script's `quit`:

```
[host +24.253s] exit: script quit after 16188 frames
[host +25.000s] video totals: simulations=16188 presentations=1011
```

Most cycles still run on the interpreter, as in the USA build, so the
translation builds cost about the same as the USA build on the same route.

Commands (from the repo root; `SNESRECOMP_ROOT` names the framework):

```sh
bash tools/regen.sh --identity rom_identity.de.txt \
                    --out-dir src/gen-de --cfg-dir recomp-lle
bash tools/regen.sh --identity rom_identity.sv.txt \
                    --out-dir src/gen-sv --cfg-dir recomp-lle
cmake --preset macos-arm64-de     # or -sv, windows-x64-de, linux-x64-de, ...
cmake --build --preset macos-arm64-de --parallel 8
```

The `linux-x64-de` preset (Unix Makefiles, Release) also configured, built and
booted 120 frames headless on this host with the German dump; the difference
from the macOS preset is the generator, not the port.

## Boots and localized menus

`menu.txt` (wait, A, A, Start, Down, A) was run against each translation's own
generated tree; frame 850 is the main menu. The German build shows ``NEUES
SPIEL STARTEN`` / ``GESICHERTES SPIEL STARTEN`` / ``OPTIONEN``; the Swedish
build shows ``STARTA NYTT SPEL`` / ``STARTA SPARAT SPEL`` / ``VAL``. The
screenshots were written by the framework's framedump (`SNESRECOMP_FRAMEDUMP_*`)
and converted from BMP with `sips`.

## The hand cursor moved with the code

The USA cursor lives at `$7E01F0` (X, `x << 8`), `$7E01F2` (Y) and `$7E01F4`
(the hand-up gate), with `$7E01F6` holding `0xffff` beside it. The in-game
routine that initialises that block writes `0, 0, A, A, 0, 0xffff` into
`$01EC…`; in the translations the same routine writes the same values into
`$01D0…`, i.e. `0x1C` lower. The generated C shows the shift directly: the USA
routine stores `$01F0/$01F2/$01F4` where the German routine stores
`$01D4/$01D6/$01D8`.

Running the same `nav1.txt` route on each translated build confirms it in WRAM.
At frame 12,600, before the hand is raised, both translations hold:

```
$7E01D4 = 0x7500   $7E01D6 = 0x7100   $7E01D8 = 0x0000   $7E01DA = 0xffff
```

which is exactly the USA state at `$7E01F0`/`$7E01F2`/`$7E01F4`/`$7E01F6`. The
finger then follows the scripted right-stick/`R` route:

| frame | Germany `$01D4` | Germany `$01D6` | Germany `$01D8` | Sweden `$01D4` | Sweden `$01D6` | Sweden `$01D8` | USA `$01F0`…`$01F4` at the same route |
|---:|---|---|---|---|---|---|---|
| 12600 | `0x7500` | `0x7100` | `0x0000` | `0x7500` | `0x7100` | `0x0000` | `0x7500` `0x7100` `0x0000` |
| 12813/12840 | `0x3300` | `0x8d00` | `0xffff` | `0x3300` | `0x8d00` | `0xffff` | `0x3300` `0x8d00` `0xffff` |
| 13131/13160 | `0x2f00` | `0x8d00` | `0xffff` | `0x2f00` | `0x8d00` | `0xffff` | `0x2f00` `0x8d00` `0xffff` |

The one-frame intermediate values (`0x32d0`, `0x3270`, `0x31e0`, `0x3120`,
`0x3030`, `0x2f10`) are the hand easing toward its target and appear on both
translations at the same frames. So the three words keep the USA semantics
exactly, and `src/mouse_cursor.c` needs only the addresses, which CMake passes
as `SHADOWRUN_CURSOR_X/Y/GATE`:

| edition | X | Y | gate |
|---|---|---|---|
| USA | `0x01F0` | `0x01F2` | `0x01F4` |
| Germany | `0x01D4` | `0x01D6` | `0x01D8` |
| Sweden | `0x01D4` | `0x01D6` | `0x01D8` |

## Packaging

`tools/package_desktop.py --edition de` (or `sv`) appends the edition to the
archive stem and writes the matching dump name into `README.txt` and
`BUILD_INFO.txt`. Measured on the two macOS arm64 builds above:

```
shadowrun-de-0.1.0-macos-arm64.tar.gz   1,968,734 B
  sha256 1cfecfe33a711282a6f642fc3f8acfccdc660e08ca9e79760498aa11084c8671
shadowrun-sv-0.1.0-macos-arm64.tar.gz   1,968,260 B
  sha256 a467c72223d7cd6bb2c1ed0ecfdb005345ddaffeed72e2084dff0cde36f546eb
```

Both staged archives answered `--help` from the extracted folder (`smoke: ok`).
The shareable archives carry no ROM; the `-de-embed` / `-sv-embed` presets are
the personal, ROM-carrying form and are not distributable.

### macOS drag-install packages

`scripts/package_macos_bundle.sh` takes `EDITION=de|sv` (default `us`) and
derives the bundle name, identifier, state directory, `.dmg` stem, accept-list
and the dump the run legs use. It refuses a build tree configured for another
edition, so a language package cannot contain the USA binary. Full runs on this
host (assembly, scans, mount, install, and 1200-frame parity against the
edition's own build tree):

| artefact | bytes | sha256 |
|---|---:|---|
| `shadowrun-de-0.1.0-macos-arm64.dmg` | 2,180,698 | `08cd17e264a0cb9ce7cf9d2522946f490486617ab07441d0e8c1933fac7d8678` |
| `shadowrun-sv-0.1.0-macos-arm64.dmg` | 2,179,662 | `fc1d200ec9435b7c3e93c4ea9f914d7c28ea4b448fdfd6552b93e68f9cc12e3c` |

Both runs exited 0. In each, the packaged executable and the build-tree
executable produced identical WRAM crc32 over all 1200 shared frames, the
scripted boot, LaunchServices click and installed-copy legs all exited 0, and
the mounted image's executable ran with `rom resolved:` naming the edition's
own dump. The translations' per-frame tick counter is `$7E1C76` (measured for
both editions from two WRAM dumps ten frames apart), so the scripted legs use
`tests/scripts/selfcheck-intl.txt`; the USA counter is `$7E1C92`.

Transcripts: `evidence/artifacts/macos_package_de.md` and
`macos_package_sv.md`. Cross-edition frame comparisons are deliberately not
reported: the kit's accepted reference builds are USA-configured, and their
routes were measured on USA text.

A refreshed source build kit, `shadowrun-build-kit-c58af86.zip` (18,926,267 B,
sha256 `5811959b0eb93993d9b746462878370a18d3a88e6aa829814682348e878813f1`),
includes `src/gen-de`, `src/gen-sv`, `recomp-lle`, both language identity files
and edition instructions for Linux and Windows.


## Not measured here

- The German and Swedish builds were not compiled with MSVC. The
  `windows-x64-de` / `windows-x64-sv` presets are the same ones the USA release
  uses with only the edition variable changed; the user builds those binaries
  themselves. The Unix Makefiles preset was built and booted on this host.
- The mouse mod was not driven by a real pointer on the translations (this host
  is headless for that path); the WRAM measurement above shows the three words
  the mod reads and writes are the same words the game moves, at the addresses
  the edition passes to it.
- CI cannot run: the framework pin is local and no remote is configured. The
  translation presets are listed by `cmake --list-presets=all`.
