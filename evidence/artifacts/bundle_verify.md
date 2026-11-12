# bundle_verify.md
#
# what: the staged ./Shadowrun, the build tree behind it, and its frame state
#       against that tree and against the previous staged bundle
# how:  tests/bundle_verify.sh with SHIP=build-ship PORT_BIN2=tests/out/Shadowrun_prev_ebca100c SCRIPT=tests/scripts/parity.txt
#
# framework pin: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
# generated: 2026-11-08T17:12:27Z (host Darwin 25.6.0 arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

== 1. the staged bundle and the tree that made it ==

  ./Shadowrun                        60067549c3ee8d3b  3103872 B  2026-11-08 17:58
    SDL reference                    @executable_path/libs/libSDL3.0.dylib
    signature                        Signature=adhoc
  build-ship/ShadowrunSNESRecomp     a0587ed0a0e34687  3103776 B
  tests/out/Shadowrun_prev_ebca100c (previous bundle) ebca100c3a01201a  5941232 B  2026-11-05 13:20

  the staged copy is not the build-tree bytes: install_name_tool rewrites
  the SDL reference and codesign re-signs, so the hash differs and the size
  grows by the link edit.  Section 4 is what says it is still the same
  program; a staged binary alone cannot say that, by design.

  build tree provenance, recorded from the build tree rather than from the
  copied executable, which is the identity a staged bundle cannot carry:
    manifest: build-ship/run_manifest.json
      exe    sha256 a0587ed0a0e34687  3,103,776 B
      tree   /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-ship  config=Release embed=OFF gen_objects=18
      gen    18 units, 215 promoted functions, 263 dispatch entries, sha256 3f22138eb5d1b401
      fw     /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin  rev=773285b8210f2254ae87d0a14113980fb36990ad dirty=False
    gen_sha256=3f22138eb5d1  gen_units=18  gen_functions=215  gen_dispatch=263  framework=773285b8210f  config=Release  embed_rom=OFF  exe_sha256=a0587ed0a0e3
  pin:
    rev    773285b8210f2254ae87d0a14113980fb36990ad
    dirty  no
    pin file  snesrecomp=773285b8210f2254ae87d0a14113980fb36990ad
    AT THE PIN   build-ship: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin @ 773285b8210f2254ae87d0a14113980fb36990ad
  (the "dirty" true/false lines further down are provenance.py's
   port_git section -- the port repository, which is dirty here because
   this script is untracked while it runs.  The framework line is
   dirty=False / AT THE PIN, which is what a leg must satisfy.)
  configure:
    CMAKE_BUILD_TYPE:STRING=Release
    SHADOWRUN_EMBED_ROM:BOOL=OFF
    SNESRECOMP_SDL3_FETCH:BOOL=ON
  compilers: /usr/bin/c++ /usr/bin/cc 
  generated sources on disk: 18 units, newest 2026-11-08 16:33

== 2. a fresh configure + build of the checked-out tree ==

  configured from scratch, no copied cache, only the two documented flags:
  the accepted bytes either come out of the defaults plus this tree or they
  do not.  (c1: a stale build tree reads as current, so the tree's own
  object count against the units on disk is checked below.)
  configure exit=0  29 lines
    -- ShadowrunSNESRecomp: 18 generated translation unit(s) from /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/src/gen
  build exit=0  111 lines
  objects compiled for src/gen: 18, units on disk: 18
  exe  a0587ed0a0e34687  3103776 B
  the checked-out src/gen, the recomp tables and the pin reproduce the
  accepted executable byte for byte, from a build directory that did not
  exist five minutes ago.
  gen_sha256=3f22138eb5d1  gen_units=18  gen_functions=215  gen_dispatch=263  framework=773285b8210f  config=Release  embed_rom=OFF  exe_sha256=a0587ed0a0e3

== 3. the staged bundle boots the ROM ==

  exit=0 wall=5s
    script f=10 until 01C92 ok after 10 frames
    script f=276 until 01C93 ok after 266 frames
    script f=276 quit
    [host +4.727s] frame service: implementation=LLE seconds=4.679955792 fps=58.975 cpu_seconds=0.750181000
  the script waits on the game's own WRAM tick counter ($7E1C92), one
  increment per emulated frame, so this fails loudly if the ROM stalls.

== 4. the staged bundle against the build tree that made it ==

  run1  staged ./Shadowrun  60067549c3ee8d3b
      exit: script quit after 1200 frames
        exe    sha256 60067549c3ee8d3b  3,103,872 B
        WARN   no CMakeCache.txt beside the executable: this is a staged or copied binary, so the framework and generated set behind it are unknown from the artefact alone
  run2  build-ship/ShadowrunSNESRecomp  a0587ed0a0e34687
      exit: script quit after 1200 frames
      "bytes": 3103776,
      "sha256": "a0587ed0a0e346876d24c5a0ff03cfc85f6ccdea24afcccfefcc07cf194618f2"
      "dir": "/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-ship",
      "config": "Release",
      "embed_rom": "OFF",
      "rev": "773285b8210f2254ae87d0a14113980fb36990ad",
      "dirty": false
      "sha256": "3f22138eb5d1b401187e0487cdac437f07a1b8777539b5b2e06bf3bef921a2cf",
      "units": 18,
      "promoted_functions": 215,
      "dispatch_entries": 263,
      "rev": "3a881aa011b9e6b5849ac734992522d8c2d45bef",
      "dirty": true
  identical over 1200 frames
  different inputs
    config: None  !=  Release
    embed_rom: None  !=  OFF
    framework: unknown  !=  773285b8210f2254ae87d0a14113980fb36990ad
    gen_dispatch: None  !=  263
    gen_functions: None  !=  215
    gen_sha256: None  !=  3f22138eb5d1b401187e0487cdac437f07a1b8777539b5b2e06bf3bef921a2cf
    gen_units: None  !=  18
  the staged copy reports its build identity as unknown because no
  CMakeCache.txt sits beside it -- tests/provenance.py calls that unknown
  the finding, and sections 1-2 are what replace it.  The frame state, on
  the other hand, has to agree, and that is the line above.

== 5. the staged bundle against the previous staged bundle ==

  run3  tests/out/Shadowrun_prev_ebca100c  ebca100c3a01201a
      exit: script quit after 1200 frames
        exe    sha256 ebca100c3a01201a  5,941,232 B
        WARN   no CMakeCache.txt beside the executable: this is a staged or copied binary, so the framework and generated set behind it are unknown from the artefact alone
  1174 of 1200 frames differ
  first divergence at frame_000001.json: 0xA5618AC7 vs 0x609BDB9F
  the c1 finding restated against the new bundle: the binary that stood in
  for this port for three days was a different program, and nothing about
  it said so.

== 6. what the bundle now is ==

  ./Shadowrun                        60067549c3ee8d3b  (staged: link-edited, re-signed)
  built by build-ship                a0587ed0a0e34687
  rebuilt from source in s2          a0587ed0a0e34687
  accepted executable                a0587ed0a0e34687
  previous bundle kept at tests/out/Shadowrun_prev_ebca100c ebca100c3a01201a
  so: sources -> accepted exe -> staged bundle, with the frame state of
  every link of that chain agreeing, and the previous bundle's not.
