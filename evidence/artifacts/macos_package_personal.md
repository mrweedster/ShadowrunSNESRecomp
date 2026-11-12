# macos_package_personal.md
#
# variant: PERSONAL.  This package contains the guest image compiled into
#          its executable.  It is not a distributable artefact: see the
#          PERSONAL block in scripts/package_macos_bundle.sh.
# what: the click-and-install macOS package (Shadowrun-personal.app inside a .dmg):
#       what is in it, what is provably not in it, and that it runs from
#       outside this repository
# how:  PERSONAL=1 scripts/package_macos_bundle.sh build-embed-ship-m11 macos-arm64
#
# framework used: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx
#          (its status against the pin is measured in section 0, not claimed here)
# generated: 2026-11-10T06:21:26Z (host Darwin 25.6.0 arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

== 0. the build tree being packaged ==

  build dir  build-embed-ship-m11
  variant    PERSONAL: ships the guest image, not for distribution
  executable           594499e83171a0f8  7026848 B
  CMAKE_BUILD_TYPE:STRING=Release
  SHADOWRUN_EMBED_ROM:BOOL=ON
  SNESRECOMP_ENABLE_MODS:BOOL=ON
  no run manifest in build-embed-ship-m11, so provenance.py key has nothing to read.
  The executable's own hash above is its identity in this log; what ties it to
  the build this kit treats as correct is section 7's c leg, not a manifest.
  OFF THE PIN  build-embed-ship-m11: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx @ a7fb67e6c9f5644a98ade281b6d157693a31eb52, with 773285b8210f as an ancestor -- a branch off the pin, fine for a capability leg
  framework /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed-osx defines SNESRECOMP_EMBEDDED_ROM in 1 runner/src file(s)
  SDL3 the build tree links   nothing: the executable references no SDL3
    dylib at all, so SDL3 is linked in statically and no dylib is vendored.
    That is the shape this package ships: with no vendored dylib, nothing
    inside the bundle raises the floor above the port's own target.

== 1. the bundle ==

  /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/payload_stage_personal/Shadowrun-personal: replacing existing signature
  /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app: replacing existing signature
  payload, read back off the finished bundle:
  Shadowrun-personal (CFBundleExecutable) 44a3da74ddca0062  7004144 B
  no vendored dylib: SDL3 is inside Shadowrun-personal, so the tree below is the whole payload
  seal of the whole bundle     (empty output is codesign's pass)
    resource seal written:    Contents/_CodeSignature/CodeResources (2450 B)
  LSMinimumSystemVersion      11.0 (read from the executable's LC_BUILD_VERSION)
  the executable's own build record: minos 11.0, sdk 26.5  (MACOS)
  no other Mach-O in the bundle: SDL3 is linked into the executable, so the
    only build record in this package is the one above, and 11.0 is the floor.
  architecture of the payload: arm64
  size of the .app            6,7M
  tree:
    .
    ./Contents
    ./Contents/_CodeSignature
    ./Contents/_CodeSignature/CodeResources
    ./Contents/Info.plist
    ./Contents/MacOS
    ./Contents/MacOS/Shadowrun-personal
    ./Contents/PkgInfo
    ./Contents/Resources
    ./Contents/Resources/BUILD_INFO.txt
  
  the seal, put through the states a copy passes through (codesign's words, not this script's):
    1. the copy as shipped:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: valid on disk
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: satisfies its Designated Requirement
       [exit=0]
    2. the same copy with its resource seal taken away, which is what a bundle that was never sealed looks like to a Mac that expects one:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: invalid resource directory (directory or signature have been modified)
       [exit=1]
    3. that bundle laid out the way the pinned framework lays a bundle out -- a rom.cfg, a keybinds.ini and the launcher's mod catalog written beside the executable -- asked to be sealed at all:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: replacing existing signature
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: code object is not signed at all
       In subcomponent: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app/Contents/MacOS/mods/preloaded/state.toml
       [exit=1]
    4. the same bundle with the state taken back out and the seal put on again:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: replacing existing signature
       [exit=0]
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: valid on disk
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_personal/Shadowrun-personal.app: satisfies its Designated Requirement
       [exit=0]
       so a bundle whose executable directory stays free of writable state seals, and a
         bundle laid out the way the pinned framework lays one out does not.
  
    and two copies of the finished bundle, both re-sealed with this script's own codesign
    command line, to answer whether the seal is a reproducible identity or a one-off:
  copy A, re-sealed unchanged    44a3da74ddca0062
  copy B, BUILD_INFO.txt +1 line 48593d1b9729cdf2
  the bundle this run shipped    44a3da74ddca0062
    A reproduces the shipped payload hash byte for byte, so the seal is deterministic and
      a payload hash is a legitimate identity for a build.  B moves it, because a code
      signature over a bundle seals the bundle's resources into the executable's own
      CodeDirectory -- 'hashes=N+3', the +3 being the bundle's CodeResources, its
      Info.plist and its requirements.  The payload's hash therefore pins the whole
      bundle, BUILD_INFO.txt included, and not just the Mach-O inside it.
  what the bundle says about itself, read back off disk:
    CFBundleName               Shadowrun-personal
    CFBundleDisplayName        Shadowrun
    CFBundleIdentifier         org.retroportingtoolkit.shadowrun.personal
    CFBundleExecutable         Shadowrun-personal
    CFBundleShortVersionString 0.1.0
    NSHumanReadableCopyright   Personal build of the Shadowrun native recompilation. Contains the guest ROM image, compiled into the executable by tools/embed_rom.py. Not for redistribution: you must legally own a copy of the game.
      BUILD_INFO.txt states: "PERSONAL BUILD -- NOT FOR DISTRIBUTION"
    that label's image record, against both sources of truth:
    source             bytes      crc32 sha256
    BUILD_INFO.txt   1048576   3f34dff0 e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4
    embedded_rom.c   1048576   3f34dff0 e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4
    rom_identity     1048576   3f34dff0 e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4
      MATCH across all three: bundle label, generator record, rom_identity.txt

== 2. what is provably not in the payload ==

  Both variants are scanned the same way; only the expected answers differ, and
  each line says which.  Nothing below is relaxed for PERSONAL=1: the scans that
  hold for both keep their expect-0, and the one scan that inverts is reported
  as a presence check with the symbols named.
  ROM/patch-shaped files                   0   (expect 0 in both: the image is compiled into the Mach-O, never shipped beside it)
  embedded-ROM symbols in the executable   1   (_snesrecomp_embedded_rom )
                                           expect the array symbol here: it is the proof
                                           tools/embed_rom.py put the image in this binary.
  rom.cfg in the payload                   0   (expect 0: this app resolves the image inside its own executable, so it has no ROM choice to cache)
  src/gen or recomp/funcs.h in the payload 0   (expect 0: build inputs, git-ignored)
  files naming this repository              0   (expect 0: an absolute build path would be a machine-local claim)
  files naming this machine's ROM directory (/Users/wee/Documents/work/ports/ShadowrunSNESRecomp):
    0   (expect 0: a baked-in rom.cfg would point at a file that does not exist on the player's disk)
  the guest image, looked for inside the executable itself:
    found at offset 0x447d3e (1048576 B), sha256 e6bc0a595d5c7c4b -- matches the digest in rom_identity.txt
    MATCH: expected present, present
  load commands of the packaged executable:
    	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1356.0.0)
    	/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL (compatibility version 1.0.0, current version 1.0.0)
    	/System/Library/Frameworks/CoreMedia.framework/Versions/A/CoreMedia (compatibility version 1.0.0, current version 3320.8.5)
    	/System/Library/Frameworks/CoreVideo.framework/Versions/A/CoreVideo (compatibility version 1.2.0, current version 734.4.0)
    	/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa (compatibility version 1.0.0, current version 24.0.0)
    	/System/Library/Frameworks/UniformTypeIdentifiers.framework/Versions/A/UniformTypeIdentifiers (compatibility version 1.0.0, current version 709.0.0, weak)
    	/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit (compatibility version 1.0.0, current version 275.0.0)
    	/System/Library/Frameworks/ForceFeedback.framework/Versions/A/ForceFeedback (compatibility version 1.0.0, current version 1.0.2)
    	/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon (compatibility version 2.0.0, current version 170.0.0)
    	/System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio (compatibility version 1.0.0, current version 1.0.0)
    	/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox (compatibility version 1.0.0, current version 1000.0.0)
    	/System/Library/Frameworks/AVFoundation.framework/Versions/A/AVFoundation (compatibility version 1.0.0, current version 2.0.0)
    	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 5026.5.4)
    	/System/Library/Frameworks/GameController.framework/Versions/A/GameController (compatibility version 1.0.0, current version 13.5.1)
    	/System/Library/Frameworks/Metal.framework/Versions/A/Metal (compatibility version 1.0.0, current version 373.2.0)
    	/System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore (compatibility version 1.2.0, current version 1195.14.4)
    	/System/Library/Frameworks/CoreHaptics.framework/Versions/A/CoreHaptics (compatibility version 1.0.0, current version 1.0.0, weak)
    	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 2100.43.0)
    	/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 2685.60.104)
    	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 5026.5.4)
    	/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics (compatibility version 64.0.0, current version 1965.5.1)
    	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 1226.0.0)
    	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
    non-system load commands naming Homebrew: 0  (expect 0)
    LC_RPATH entries in the packaged executable: 0
    none at all: nothing in the Mach-O names a directory from this build.  That
    is what linking SDL3 statically buys next to the vendored-dylib shape, whose
    executable carried one entry naming this machine's Homebrew lib directory.
    files in the payload naming /opt/homebrew: 0
  signatures, each Mach-O on its own, asked where they were signed:
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/payload_stage_personal/Shadowrun-personal: valid on disk
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/payload_stage_personal/Shadowrun-personal: satisfies its Designated Requirement
      ('--validated:<path>' is codesign's pass; it prints nothing else.)
    Identifier=Shadowrun-personal-55554944c0b2cf45d5df34329f021914f1e68e25
    Format=Mach-O thin (arm64)
    Signature=adhoc
    TeamIdentifier=not set

  the packaged executable once it sits inside the .app, and the bundle as a whole:
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal: valid on disk
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal: satisfies its Designated Requirement
    bundle: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app: valid on disk
    bundle: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app: satisfies its Designated Requirement
      Empty output from --verify is codesign's pass; --verbose=2 adds the
      '--validated' lines and the seal's own hash.  Contents/_CodeSignature/
      CodeResources is the resource seal, and it exists because nothing writable
      sits inside the bundle: the host keeps its state outside (see the intro), so
      saving a game no longer breaks a seal.
    what the seal says about the bundle:
      Identifier=org.retroportingtoolkit.shadowrun.personal
      Format=app bundle with Mach-O thin (arm64)
      CodeDirectory v=20400 size=13859 flags=0x2(adhoc) hashes=426+3 location=embedded
      TeamIdentifier=not set
      TeamIdentifier not set = ad-hoc: made on this machine, for this machine, with
      no Apple certificate behind it.
  
      The counter-case, generated rather than asserted -- a scratch copy of the
      finished bundle staged the way the pinned framework's layout needs it, with
      the host's runtime files beside its executable:
      seal attempt: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_attempt_personal/Shadowrun-personal.app: code object is not signed at all
      seal attempt: In subcomponent: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_attempt_personal/Shadowrun-personal.app/Contents/MacOS/keybinds.ini
      seal check:     /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_attempt_personal/Shadowrun-personal.app: code object is not signed at all
      seal check:     In architecture: arm64
      That is the state a downloaded or mounted copy of such a bundle is re-assessed
      against: a signature that expects a resource seal with none present is what
      macOS reports to a person as '... is damaged and can't be opened'.  It is not
      a corrupt download; it is the bundle's own shape.  Fixing the shape is why the
      payload carries no loose state and why the seal above is made.
  Gatekeeper's verdict (ad-hoc is not a Developer ID, and notarisation needs one):
    exec:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app: rejected
    install: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app: rejected
    Rejected, and a sealed bundle does not change that: the assessment needs a
    Developer ID signature plus a notarisation ticket, and an ad-hoc signature can
    carry neither.  So a copy that arrives through a browser carries the quarantine
    flag and Gatekeeper refuses it until the person overrides once -- right-click >
    Open, or clear the flag with
    'xattr -dr com.apple.quarantine /Applications/Shadowrun-personal.app'.  Nothing in this
    script can change that; the signing identity is free, Apple's is not.
    The .dmg built here carries no quarantine flag, because nothing downloaded it,
    and a copy made on this machine is not refused by anything.

== 3. the executable inside the .app, against the bytes the kit already measured ==

  packaged                 44a3da74ddca0062  7004144 B
  build tree build-embed-ship-m11/ShadowrunSNESRecomp 594499e83171a0f8  7026848 B
  signature in the tree    CodeDirectory v=20400 size=54604 flags=0x20002(adhoc,linker-signed) hashes=1703+0
  signature when packaged  CodeDirectory v=20400 size=13859 flags=0x2(adhoc) hashes=426+3
  LC_CODE_SIGNATURE, tree  dataoff 6972224, 54624 B
  LC_CODE_SIGNATURE, packaged dataoff 6972224, 31920 B
  SDL reference, tree      (none: no SDL dylib load command -- SDL3 is inside this Mach-O)
  SDL reference, packaged  (none: no SDL dylib load command -- SDL3 is inside this Mach-O)
  header, tree             sizeofcmds 5520; load commands end at byte 5552
  header, packaged         sizeofcmds 5520; load commands end at byte 5552
  The signature blob starts at byte 6972224 in BOTH files, so everything before it
  is the same length in both, and the whole 22704 B difference between the two
  files above is the signature blob, the tree's blob being the larger.  ld scores 4 KiB
  pages over the whole binary; codesign --force --sign - scores 16 KiB pages on an
  executable this large, so the two blobs are not comparable byte for byte -- which
  is why section 5 compares machine state instead of hashing these two files.
  Compared up to that offset: 5 byte(s) of 6972224 differ, first at byte
  3074, last at 5550.
  The tree's load commands end at 32 + sizeofcmds(5520) = 5552:
  every difference is inside the Mach-O header and its load commands and
  nowhere else.  Everything past that -- code and data -- is bit-identical
  between the build tree and the shipped bytes.
  That includes the 1 MiB of embedded guest image: the packaging did not touch it.
  The load commands themselves moved by 0 B.  Nothing was rewritten here --
  SDL3 is linked in, so the only packaging step on this Mach-O is the ad-hoc
  sign -- and a sign writes the LC_CODE_SIGNATURE command, which is one load
  command of 16 B plus padding to 8 B.  __LINKEDIT's file offset comes from the
  segment table, so the padding absorbs the movement and the file's length moves
  only with the blob.
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_personal/plain/Shadowrun-personal: replacing existing signature
  probe: sign, outside               b88e847492887cb8  7004128 B
    its identifier                   Shadowrun-personal-55554944c0b2cf45d5df34329f021914f1e68e25
  NO MATCH against a plain-directory sign, and that is the bundle seal's doing:
  section 1 signs the finished Shadowrun-personal.app as a whole, and a whole-bundle seal
  re-signs the executable inside it with the bundle's identifier and a hash of
  Info.plist.  The probe that repeats those steps in order is the fourth one below.
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_personal/plain/other-name: replacing existing signature
  probe: same, named other-name      3f9f87c19f395623  7004128 B
    its identifier                   other-name-55554944c0b2cf45d5df34329f021914f1e68e25
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_personal/inbundle/Probe.app/Contents/MacOS/Shadowrun-personal: replacing existing signature
  probe: sign, INSIDE                2b35ab763ebc4402  7004128 B
    its identifier                   org.example.signprobe
    its CodeDirectory                CodeDirectory v=20400 size=13838 flags=0x2(adhoc) hashes=426+3
    the packaged CodeDirectory       CodeDirectory v=20400 size=13859 flags=0x2(adhoc) hashes=426+3
  Signing in place inside a bundle re-draws the signature: the identifier comes from
  that bundle's Info.plist instead of the file name, and one more hash appears in the
  CodeDirectory -- that extra hash is the bundle's Info.plist, bound into the Mach-O's
  own signature.  The file length may or may not move, so size alone does not catch
  it; the hash does.  That is what the whole-bundle seal in section 1 does to the
  payload, and the fourth probe repeats it with this bundle's own Info.plist.
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_personal/full/Shadowrun-personal: replacing existing signature
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_personal/full/Shadowrun-personal.app: replacing existing signature
  probe: sign + bundle seal          44a3da74ddca0062  7004144 B
    its identifier                   org.retroportingtoolkit.shadowrun.personal
    its CodeDirectory                CodeDirectory v=20400 size=13859 flags=0x2(adhoc) hashes=426+3
  MATCH: that order is the whole of what the packaging did to this executable.  A
  scratch copy of build-embed-ship-m11/ShadowrunSNESRecomp, staged and sealed the way section 1 stages and seals, comes
  out at the shipped hash -- so the payload is pinned by the build tree's bytes plus
  the staging steps plus this bundle's Info.plist, and nothing else was done to it.
  The plain-directory sign of probe one is real but not final: the bundle seal that
  section 1 takes afterwards signs over it, which is why probe one alone does not
  match and probe four does.
  So a plain-directory sign pins the build tree's bytes and the file's name at
  once: nothing was rewritten in between, and an ad-hoc sign takes its identifier
  from the name.  Inside the finished bundle the identifier is the bundle's instead,
  which is what probe four pins.
  probe copies left behind           /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_personal
  staged ./Shadowrun       60067549c3ee8d3b  3103872 B
  differs from ./Shadowrun, and must: ./Shadowrun is the ROM-based staged
  bundle, a different program from one whose executable carries the image.
  What means something here is the frame leg in section 5: this package
  against the tree built at this package's floor without the guest inside
  its executable, compared as machine state.

  no dylib to compare: SDL3 is linked into the executable, so the executable's
  hash above is the whole of the code this package carries.

== 4. the disk image ==

  created   /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg
  size       2949133 B   sha256 7edb5fe11827d880
  Prüfsumme für Protective Master Boot Record (MBR : 0) berechnen …
  Protective Master Boot Record (MBR :: Die überprüfte CRC32-Prüfsumme ist $0F78EC29
  Prüfsumme für GPT Header (Primary GPT Header : 1) berechnen …
   GPT Header (Primary GPT Header : 1): Die überprüfte CRC32-Prüfsumme ist $A7588EF0
  Prüfsumme für GPT Partition Data (Primary GPT Table : 2) berechnen …
  GPT Partition Data (Primary GPT Tabl: Die überprüfte CRC32-Prüfsumme ist $7672FCA1
  Prüfsumme für  (Apple_Free : 3) berechnen …
                      (Apple_Free : 3): Die überprüfte CRC32-Prüfsumme ist $00000000
  Prüfsumme für disk image (Apple_HFS : 4) berechnen …
            disk image (Apple_HFS : 4): Die überprüfte CRC32-Prüfsumme ist $6031DE23
  Prüfsumme für  (Apple_Free : 5) berechnen …
                      (Apple_Free : 5): Die überprüfte CRC32-Prüfsumme ist $00000000
  Prüfsumme für GPT Partition Data (Backup GPT Table : 6) berechnen …
  GPT Partition Data (Backup GPT Table: Die überprüfte CRC32-Prüfsumme ist $7672FCA1
  Prüfsumme für GPT Header (Backup GPT Header : 7) berechnen …
    GPT Header (Backup GPT Header : 7): Die überprüfte CRC32-Prüfsumme ist $95044398
  Die überprüfte CRC32-Prüfsumme ist $E586EB3E
  hdiutil: verify: checksum of "/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg" is VALID
  content of the mounted image:
    .
    ./Applications
    ./README.txt
    ./Shadowrun-personal.app
    ./Shadowrun-personal.app/Contents
    ./Shadowrun-personal.app/Contents/_CodeSignature
    ./Shadowrun-personal.app/Contents/_CodeSignature/CodeResources
    ./Shadowrun-personal.app/Contents/Info.plist
    ./Shadowrun-personal.app/Contents/MacOS
    ./Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal
    ./Shadowrun-personal.app/Contents/PkgInfo
    ./Shadowrun-personal.app/Contents/Resources
    ./Shadowrun-personal.app/Contents/Resources/BUILD_INFO.txt
  the exe inside the image 44a3da74ddca0062  7004144 B
    (the same hash section 3 measured in dist/, so the container did not alter
    the payload: hdiutil stores the file, it does not rewrite a Mach-O)
    drag target present: Applications -> /Applications
    ROM/patch-shaped files inside the image: 0   (expect 0)
    files in the image naming this repository: 0   (expect 0)
  second image, same payload abb9408aa64aa47a  2949123 B
    the .dmg is NOT byte-reproducible even from the same stage directory:
    hdiutil stamps volume metadata (dates, UUIDs) into the container.  What
    is reproducible is the payload -- sections 1 and 3 pin the .app hashes --
    so a hash of the .dmg is a hash of this run's container, not of the build.
  
  No leg below passes --rom and no leg gets a rom.cfg: the claim this package
  exists to make is that the app boots from the image inside its own executable.
  A leg that reached the ROM file picker would hang on a window with no way to
  answer it, so those legs' exit codes and the host's own 'rom resolved:' line
  are what measure that no picker appeared.
  
  The one leg that does name the dump is the comparison against build-ship-m11/ShadowrunSNESRecomp:
  that executable is the ROM-based build, so it has to be told where its image
  is, and the answer goes on its command line only.

== 5. the packaged app, run from outside this repository ==

  Every leg runs against a copy of the bundle under /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/app_personal -- never the
  copy in dist/, never this repository's own runtime state.  The executable
  inside a .app resolves config.ini, keybinds.ini, rom.cfg, saves/, mods/ and
  the run report under ~/Library/Application Support/<bundle name>/ (the host
  derives that from $HOME when it is running from inside a bundle), so these
  legs are given a private $HOME under /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg and write only there.  Two things
  that buys, both measured below: nothing of this machine's own port state is
  touched by a packaging run, and the bundle copy can be inventoried before and
  after -- a bundle that stays byte-identical through a run is the property the
  '... is damaged' complaint is about, so it is checked rather than assumed.
  copy under test  44a3da74ddca0062   (the bytes inside /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg)
  HOME for these legs         /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_personal
    so the app's state directory is   /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_personal/Library/Application Support/Shadowrun-personal
  bundle copy before the legs: 11 files, tree hash 27264ebd30d4708d
    its seal, asked before anything runs -- this copy came out of dist/ by ditto,
    not from the build:
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/app_personal/Shadowrun-personal.app: valid on disk
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/app_personal/Shadowrun-personal.app: satisfies its Designated Requirement
  a. frames from app  44a3da74ddca0062  exit=0 exit: script quit after 1200 frames
        rom resolved: <embedded:Shadowrun (USA).sfc>
        rom loaded: 1048576 bytes
  a. frames from tree 092b0e690cab97a1  exit=0 exit: script quit after 1200 frames
        rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc
        rom loaded: 1048576 bytes
     one side is the installed bytes; the other is the tree built at this package's floor, on a framework that carries the state fix and not the guest (build-ship-m11/ShadowrunSNESRecomp -- section 0 and section 7 print both revisions).
     So this leg measures two things at once: that the packaging steps
     (sign) changed no machine state, and that compiling the image into the
     executable on a framework that is a branch off the pin rather than the pin
     itself (section 0 measures which) changed no machine state either.  A
     frame-by-frame comparison is the only way to ask
     the second question -- the two executables differ by 1 MiB of guest data,
     so byte hashes say nothing.
  identical over 1200 frames (crc32 of all 128 KiB of WRAM per frame)
    no non-label WRAM byte differs in 1200 shared frames
     identical frame state across two different programs -- one boots from a
     file, one from bytes in its own __DATA segment, and they link different
     framework revisions -- is what says putting the image in the executable
     adds no machine state.  Nothing here could be proved by a byte comparison.
  b. scripted boot from inside the .app: exit=0 wall=5s
      [host +0.005s] rom resolved: <embedded:Shadowrun (USA).sfc>
      [host +0.014s] SDL init ok: video=dummy audio=dummy
      [host +0.014s] rom loaded: 1048576 bytes
      [host +0.017s] window created: 960x720 flags=0x20
      script f=10 until 01C92 ok after 10 frames
      script f=276 until 01C93 ok after 266 frames
      script f=276 quit
      [host +4.735s] frame service: implementation=LLE seconds=4.704748250 fps=58.664 cpu_seconds=0.747135000
     the script waits on the game's own WRAM tick counter ($7E1C92), which
     increments once per emulated frame, so it fails loudly if the ROM stalls.
     exit 0 here, with no --rom anywhere on the line and no rom.cfg in the
     bundle, is the claim: this app booted the guest out of its own executable.
     A 124 or 125 instead would mean it opened the file picker and waited.
  c. the click path: started through LaunchServices, no terminal, no shell
     command line, no working directory the app was given:
     'open' exit=0.  LaunchServices starts the app the way a double-click
     does: no arguments it was not given, working directory '/', and no terminal
     for it to write to -- which is why the run is read back from the report the
     host writes at exit, rather than from stdout.
     waited 4s wall for it; pid 76041 has exited
      report written by the process LaunchServices started: reason=atexit  host frames=276  at 2026-11-10T06:22:33Z
        build game=Shadowrun version=0.1.0
        sdl video=(none) audio=(none)
        breadcrumb t=11ms: config dir anchored: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_personal/Library/Application Support/Shadowrun-personal (exe-dir anchor: ok)
        breadcrumb t=24ms: rom resolved: <embedded:Shadowrun (USA).sfc>
        breadcrumb t=160ms: SDL init ok: video=cocoa audio=coreaudio
        breadcrumb t=160ms: rom loaded: 1048576 bytes
        breadcrumb t=195ms: window created: 960x720 flags=0x20
        breadcrumb t=198ms: renderer initialized: sdl
        breadcrumb t=4862ms: exit: script quit after 276 frames
     drivers this run actually opened: SDL init ok: video=cocoa audio=coreaudio
     window created: 960x720 flags=0x20
     those are the drivers a double-click gets, not the ones this script asks
     for: a real window opened on this machine for the length of the script, and
     the audio device was opened.  That is what makes this leg the click path
     and not a headless re-run of leg b.
     it found its own bundle from a working directory of "/" (LaunchServices
     starts an app at "/"), resolved its state under the state directory rather
     than inside itself, and quit by itself.
     and it left no rom.cfg behind, because there was no ROM choice to cache:
     the guest it booted was already inside the executable.  That absence is
     the measured difference between this bundle and the shareable one.
  d. opening the app with nothing passed at all, and no rom.cfg anywhere --
     what a person who drags this in and clicks it, touching nothing, gets:
      [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_personal/Library/Application Support/Shadowrun-personal/' (bundle run: state kept outside the .app).
      [host +0.001s] config parsed: output=0 new_renderer=1 scale=3 fullscreen=0 audio=1 freq=32000 samples=512
      [host +0.007s] rom resolved: <embedded:Shadowrun (USA).sfc>
      [host +0.017s] rom loaded: 1048576 bytes
      [host +0.020s] window created: 960x720 flags=0x20
      [Gamepad] SDL reports 0 joystick(s). enable_gamepad=[1,1,0,0,0]
      [host +0.035s] first frame simulated
     no --rom, no rom.cfg in the bundle and no file to pick: the launcher's own
     anchor line, then 'rom resolved: <embedded:...>', then a window.  Had the
     image not been in the executable, this leg is where the file picker would
     have appeared and the log would show no 'rom loaded' line at all.
     No ROM data was written into the package by any leg: the guest was already
     in the executable before packaging began.

  e. the actual install path: copy the .app out of the mounted image with
     Finder-equivalent ditto into a fresh directory that is not this
     repository at all, then run that copy from that directory
     scratch install directory (machine-local, outside the repository): /var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.hPuoR6
     copied out of the image     44a3da74ddca0062
     same bytes as dist/Shadowrun-personal.app  (the drag changes nothing but the path)
     state directory before that launch: absent -- nothing of the port exists yet
     the installed copy, as shipped (it carries no state of any kind):
      ./Shadowrun-personal
     exit=0 wall=5s, run with CWD=/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.hPuoR6
      [host +0.008s] rom resolved: <embedded:Shadowrun (USA).sfc>
      [host +0.020s] SDL init ok: video=dummy audio=dummy
      [host +0.021s] rom loaded: 1048576 bytes
      [host +0.024s] window created: 960x720 flags=0x20
      script f=10 until 01C92 ok after 10 frames
      script f=276 until 01C93 ok after 266 frames
      script f=276 quit
      [host +4.739s] frame service: implementation=LLE seconds=4.683490292 fps=58.930 cpu_seconds=0.747734000
     written inside the installed bundle by that run:
     (expect nothing: the app keeps its state outside the bundle)
     payload paths that disappeared during that run: 0   (expect 0: the list after is the list before, so nothing the package needs was deleted)
     the bundle's seal after that run, asked of the installed copy:
      /var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.hPuoR6/Shadowrun-personal.app: valid on disk
      /var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.hPuoR6/Shadowrun-personal.app: satisfies its Designated Requirement
     what the first launch created in the state directory instead:
      .
      ./config.ini
      ./keybinds.ini
      ./last_run_report.json
      ./mods
      ./mods/preloaded
      ./mods/preloaded/packages
      ./mods/preloaded/state.toml
      ./saves
      ./saves/save.srm
     saves and settings live there, next to the player's other per-app state,
     not inside the .app: replacing or re-downloading the app keeps them, and a
     read-only copy -- a mounted image, a translocated run -- cannot make a save fail.
     and no rom.cfg exists afterwards anywhere: this run named
     no file on disk and cached no choice, because the guest came out of the
     executable's own bytes.  So this copy is self-contained twice over -- no
     repository, no build tree, no Homebrew, and no dump to depend on.
     files in this repository touched during that run: 0   (expect 0: an
     installed app must not read or write this checkout even when this checkout
     is the machine that built it)
     which is the point of the .app: the payload carries its own anchor, so an
     installed copy is self-contained -- no repository, no build tree, no
     Homebrew, and no second copy of the runtime files.

  f. what that changed on disk, both sides of the line:
  bundle copy before the legs        11 files, tree hash 27264ebd30d4708d
  same copy after every leg          11 files, tree hash 27264ebd30d4708d
     the bundle copy under test is byte-for-byte what it was before any of
     these runs: the app wrote nothing inside itself, at any point, through a
     scripted boot, a LaunchServices start, a launcher page and a save.
     Its seal, asked again after all of that:
     (empty = valid).  A copy that survives being copied, mounted, dragged and
     run, and still validates, is the property the 'is damaged' complaint says
     this payload used to fail.

== 6. what the installed app leaves behind ==

  package        shadowrun-embed-0.1.0-macos-arm64-personal.dmg  2949133 B  sha256 7edb5fe11827d880
  app            6,7M unpacked, 2949133 B compressed
  written inside the bundle by those legs, in Contents/MacOS:
    (expect nothing above: the payload is what it was, which is why the seal made
     in section 1 still validates after a run)
  the state directory the legs left behind:
    .
    ./config.ini
    ./keybinds.ini
    ./last_run_report.json
    ./mods
    ./mods/preloaded
    ./mods/preloaded/packages
    ./mods/preloaded/state.toml
    ./saves
    ./saves/save.srm
    its mod catalog holds 1 file(s), created by the app itself rather than shipped by this script

  That is the trade-off, and it is the one a person installing this expects:
  no installer and no privileged helper, the app can live anywhere it is put --
  and its saves and settings live in ~/Library/Application Support/Shadowrun-personal/
  rather than inside the bundle, so replacing or re-downloading the
  app keeps them, and the bundle stays sealed and verifiable.  A port that kept
  state inside the bundle had the other trade: moving the app moved its saves,
  and the loose files inside Contents/MacOS/ made the bundle impossible to seal
  -- which is the shape a downloaded copy of that would be refused for.

  And the larger trade-off, stated where someone will find it: this container
  holds the game.  shadowrun-embed-0.1.0-macos-arm64-personal.dmg is not a
  shareable artefact -- sending it to anyone is sending them a copy of
  Shadowrun.  The shareable one is what this script builds without PERSONAL=1.
  The personal build says what it is in three places that travel with it:
  Contents/Resources/BUILD_INFO.txt inside the bundle, README.txt at the root
  of the image, and its own NSHumanReadableCopyright, which is what Finder
  shows in Get Info.

== 7. the frames the shipped bytes produce, taken out of the container ==

  four legs to 1200 frames on the kit's menu route, and the subject of two of
  them is the executable as the container holds it -- read straight off the
  read-only mount, not the copy in dist/ and not a copy made for the run:
  a. that executable with --rom naming the dump: the file-based path
  b. the same executable with no --rom at all: the guest compiled inside it is
       what has to run, so this is the leg that exercises the embedded path
  c. build-ship/ShadowrunSNESRecomp, the build this kit has treated as correct since the re-baselining
       round, with --rom.  What it was configured against is printed below rather
       than asserted here -- framework status against the pin, build record, SDL3
       reference -- and pairing with it therefore spans framework, deployment floor
       and SDL3 linkage rather than repeating a comparison this kit already ran.
  d. build-ship-m11/ShadowrunSNESRecomp, the tree built at this package's floor on a framework that
       carries the state fix but not the guest, with --rom.  Whether its framework
       is the same one this package used is not claimed here: section 0 prints this
       package's revision and the lines below print this one's.  What the pair can
       show follows from what they share -- floor, and a framework with the state
       fix and no guest -- so the difference between it and a or b is the guest
       moving from a file into the executable.
  
  How far apart any two of these are is not assumed: the lines below print every
  subject's hash, size and build record, and c's and d's framework status against
  the pin, in the same call section 0 uses for this package.
  attached /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg at /Volumes/Shadowrun-personal for these legs
  these legs run under the private $HOME section 5 set up (/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_personal), so any
  state a run writes lands under tests/out/ rather than next to the checkout.
  subject a/b (in the image)       44a3da74ddca0062  7004144 B
       build record: minos 11.0, sdk 26.5
       SDL3, from its own load commands: no SDL dylib load command -- SDL3 is inside this Mach-O
  subject c (build-ship/ShadowrunSNESRecomp) a0587ed0a0e34687  3103776 B
       build record: minos 26.0, sdk 26.5
       SDL3, from its own load commands: /opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib
  subject d (build-ship-m11/ShadowrunSNESRecomp) 092b0e690cab97a1  5970048 B
       build record: minos 11.0, sdk 26.5
       SDL3, from its own load commands: no SDL dylib load command -- SDL3 is inside this Mach-O
    c's and d's frameworks, measured as section 0 measures this package's:
      AT THE PIN   build-ship: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin @ 773285b8210f2254ae87d0a14113980fb36990ad
      OFF THE PIN  build-ship-m11: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx @ 32266300d722b8b31cde3bbdc55614587f7653ae, with 773285b8210f as an ancestor -- a branch off the pin, fine for a capability leg

    frames_file: Shadowrun-personal  --rom named on the command line  cwd=a scratch directory, not the repository
      exit=0 -> 1245 WRAM dumps
      what the host itself said about where its guest came from:
      [host +0.018s] rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc
      [host +0.032s] rom loaded: 1048576 bytes
    frames_embed: Shadowrun-personal  --rom not named, deliberately  cwd=a scratch directory, not the repository
      exit=0 -> 1245 WRAM dumps
      what the host itself said about where its guest came from:
      [host +0.004s] rom resolved: <embedded:Shadowrun (USA).sfc>
      [host +0.012s] rom loaded: 1048576 bytes
    frames_refpin: ShadowrunSNESRecomp  --rom named on the command line  cwd=the port directory
      exit=0 -> 1245 WRAM dumps
      what the host itself said about where its guest came from:
      [host +0.007s] rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc
      [host +0.018s] rom loaded: 1048576 bytes
    frames_ref11: ShadowrunSNESRecomp  --rom named on the command line  cwd=the port directory
      exit=0 -> 1245 WRAM dumps
      what the host itself said about where its guest came from:
      [host +0.007s] rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc
      [host +0.017s] rom loaded: 1048576 bytes

  frames_file_personal  vs  frames_embed_personal   (1245 and 1245 frame records)
        identical over 1245 frames (crc32 of all 128 KiB of WRAM per frame)
      no non-label WRAM byte differs in 1245 shared frames

  frames_file_personal  vs  frames_refpin_personal   (1245 and 1245 frame records)
        identical over 1245 frames (crc32 of all 128 KiB of WRAM per frame)
      no non-label WRAM byte differs in 1245 shared frames

  frames_embed_personal  vs  frames_refpin_personal   (1245 and 1245 frame records)
        identical over 1245 frames (crc32 of all 128 KiB of WRAM per frame)
      no non-label WRAM byte differs in 1245 shared frames

  frames_file_personal  vs  frames_ref11_personal   (1245 and 1245 frame records)
        identical over 1245 frames (crc32 of all 128 KiB of WRAM per frame)
      no non-label WRAM byte differs in 1245 shared frames

  frames_embed_personal  vs  frames_ref11_personal   (1245 and 1245 frame records)
        identical over 1245 frames (crc32 of all 128 KiB of WRAM per frame)
      no non-label WRAM byte differs in 1245 shared frames

  what those pairs are each able to show.  a-vs-b: whether the guest compiled into
  the executable drives the same machine as the same guest handed in as a file.
  a-vs-c and b-vs-c: whether the bytes a person double-clicks agree with the build
  this kit has treated as correct since the re-baselining round, across the
  framework and floor change -- and b is the path double-clicking takes, so that
  pair is the claim this container rests on.  a-vs-d and b-vs-d: the same question
  where floor is held and the guest is the main difference between the subjects.
  Each pair's own line above says whether it agreed, and the exit codes above say
  whether a file picker appeared.

== 8. what is inside the .dmg, and the ROM question asked of both files ==

  the container the way it would reach a person: one file, and the volume inside it
  enumerated while mounted read-only.  Section 4 mounted that image, section 5
  detached it once its install leg had run from it -- that is what a person does
  with one -- and section 7 attached it again to run legs off it and left it
  attached, which is what is being read here.
  .
  ./Applications
  ./README.txt
  ./Shadowrun-personal.app
  ./Shadowrun-personal.app/Contents
  ./Shadowrun-personal.app/Contents/_CodeSignature
  ./Shadowrun-personal.app/Contents/_CodeSignature/CodeResources
  ./Shadowrun-personal.app/Contents/Info.plist
  ./Shadowrun-personal.app/Contents/MacOS
  ./Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal
  ./Shadowrun-personal.app/Contents/PkgInfo
  ./Shadowrun-personal.app/Contents/Resources
  ./Shadowrun-personal.app/Contents/Resources/BUILD_INFO.txt
    README.txt at the image root is what a person reads before they move the app;
    its floor line is not typed here, it is read out of the executable:
  | Shadowrun, recompiled natively -- version 0.1.0, macos-arm64
  | 
  | *** PERSONAL BUILD -- CONTAINS THE GAME, DO NOT DISTRIBUTE ***
  | 
  | The executable in this bundle has the Shadowrun (USA) guest image compiled into
  | it.  That is what makes it convenient and what makes it not shareable: sending
  | this bundle to someone else is the same thing as sending them a copy of the
  | game.  Keep it on machines you own.
  | The shareable build is what scripts/package_macos_bundle.sh makes without
  | PERSONAL=1: it carries no ROM and asks you for your own dump once.
  | 
  | 1. Drag Shadowrun-personal.app to Applications (the shortcut in this window).
  |    Drag it, do not run it from this window: a mounted image is read-only and
  |    macOS also moves an app run straight from a mounted image to a random
  |    read-only location of its own (App Translocation).
  | 2. Open it. It goes to the title screen on its own: the guest image is already
  |    inside the app, so it never asks for a dump and there is no file to pick.
  | 3. Settings and saves live beside your other per-app state, not inside the app:
  |      ~/Library/Application Support/Shadowrun-personal/config.ini
  |      ~/Library/Application Support/Shadowrun-personal/saves/save.srm
  |      ~/Library/Application Support/Shadowrun-personal/keybinds.ini
  |    (no ROM choice is kept there: the guest image is inside the app).
  |    That is why replacing or re-downloading the app keeps your save, and why the
  |    bundle itself can stay sealed.  Delete that folder to start the port over.
  | 4. If macOS refuses to open it, that is Gatekeeper and not a broken download:
  |    this build is signed ad hoc, not with a Developer ID and not notarised.
  |    Right-click the app and choose Open, or clear the quarantine flag:
  |      xattr -dr com.apple.quarantine /Applications/Shadowrun-personal.app
  | 5. Needs macOS 11.0 or newer, Apple silicon.
  | 
  | Keys, until you edit the keybinds.ini named above and restart:
  |   arrows            d-pad
  |   Z = B   X = A   A = Y   S = X   C = L   V = R
  |   Return = start    Right Shift = select
  the executable inside the image        44a3da74ddca0062  7004144 B

  the ROM question, asked twice over, of two different subjects:
  * the container -- the one file a person downloads and sends to someone;
  * the executable inside it -- the file that actually lands on their disk.
  and asked two ways over, because scanning for a span is weaker than locating it
  and carving that span back out: the presence scans (the image's first 256 bytes,
  its filename, its SNES header string, its digest as hex text) and then the
  carve-out -- find the first 256 bytes, take len(image) bytes at that offset, and
  compare that span with the ROM file byte for byte and by hash.

  Reading the two subjects differently matters, and this is where an assumption
  would have produced a confident wrong answer: -format UDZO is zlib, so a
  compressed container need not hold any span of its payload verbatim.  A personal
  image whose payload does carry the guest can still read absent at the container
  level.  Container-level scans are a report, not the verdict; for 'what is in the
  file that gets installed' the load-bearing scan is the executable's.

  A name and a digest are also not the same finding as bytes.  A build that will
  only accept one dump has to carry that dump's name and its hash, and that is not
  carrying the dump.  Where a filename hit appears, the lines below print the
  printable strings on either side of it, so which kind of presence it is gets read
  off the log rather than inferred from the word 'present'.
  ROM file  1048576 B   sha256 e6bc0a595d5c7c4b
  The scans below ask about four things that could each be present on their own:
  the image's first 256 bytes, its filename, its SNES header string, and its
  digest written as hex text.  A name and a digest are what a build needs in order
  to say which dump it accepts; bytes are what a build needs in order to run one
  without being given one.
  container   2949133 B
      ROM first 256 bytes present:  False
      ROM filename present:         False
      SNES header string present:   False
      ROM sha256 as hex text:       False
      carve-out: no offset -- the span is not in this file
  exe in image  7004144 B
      ROM first 256 bytes present:  True
      ROM filename present:         True
      SNES header string present:   True
      ROM sha256 as hex text:       True
        filename at 0x57cad0, and the printable strings around it are:
          ['guard_hex', "missing glyph mapping for '", 'Shadowrun', 'Shadowrun (USA).sfc', 'e6bc0a595d5c7c4bc0bbb61ffe35a70288a77eb78544ed74682d489a9e6f07f4', '3f34dff0', 'shadowrun-usa', '0.1.0']
      carve-out: found at offset 0x447d3e, carved 1048576 B, 0 byte(s) differ from the
                 ROM file itself; carve hashes e6bc0a595d5c7c4b vs ROM e6bc0a595d5c7c4b -> the same file, identified

  the container is expected to hold the game -- that is the whole point of
  PERSONAL=1 -- and it is labelled as such in three places that travel with it:
  BUILD_INFO.txt inside the bundle, README.txt at the image root, and this bundle's
  own NSHumanReadableCopyright.  What the executable-side scan is for is
  identification rather than implication.  If the image is found at an offset in the
  file that lands on the player's disk, and the span carved there hashes the same as
  this generator's own record of the dump, then the bundle carries that dump and not
  some third thing built from it.  Whether it was found is the scan's line above;
  this section only says what the two outcomes would mean.

== 9. what macOS's own tools say about this bundle, and what each verdict is about ==

  The complaint this packaging exists to answer is a sentence from macOS -- '...
  is damaged and can't be opened' -- rather than a crash, so the last section asks
  for that sentence from the tools that produce it and prints their words: codesign
  (is this payload intact), spctl (may Gatekeeper let it run) and xattr (has
  anything been attached to the files that is not part of them).  Three questions,
  and they do not have the same answers: a bundle can be intact and still refused.
  Keeping the three apart is the point, because the three fixes are different and
  this script can perform only two of them.
  copy under test for this section        /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app
  1. what kind of signature this package is able to make, read off the bundle:
      Identifier=org.retroportingtoolkit.shadowrun.personal
      Format=app bundle with Mach-O thin (arm64)
      CodeDirectory v=20400 size=13859 flags=0x2(adhoc) hashes=426+3 location=embedded
      Signature=adhoc
      TeamIdentifier=not set
      Sealed Resources version=2 rules=13 files=1
      Processing: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-personal.app
      Shadowrun-personal.app does not have a ticket stapled to it.
        'Signature=adhoc' and 'TeamIdentifier=not set' say whose identity is on
        this bundle -- nobody's -- and 'does not have a ticket' says it was never
        notarised.  Both are facts about this build, not accidents to fix here.
    2. Gatekeeper's assessment of that bundle, on a copy this machine itself built:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app: rejected
      [exit=3]
        the quarantine flag a browser leaves on a download, now set: 0081;6af2b898;Chrome;
    3. the same assessment with that flag set -- the state of a downloaded copy:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app: rejected
      [exit=3]
    4. the seal, with that same flag on the bundle -- does the download flag break it?
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app: valid on disk
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app: satisfies its Designated Requirement
      [exit=0]
        the assessment above does not change and the seal still validates, so the
        refusal and the payload are two different findings.  A damaged-looking
        download is not, on this evidence, a download that arrived broken.
  5. attached data: what the payload carries, and what happens when something is added.
        (expect nothing above: no extended attribute on the shipped executable)
        now give the scratch copy's executable the Finder metadata a copy-through-Finder or a stray resource fork leaves behind:
    6. the strict seal check with that attribute present:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app: resource fork, Finder information, or similar detritus not allowed
      file with invalid attached data: Disallowed xattr com.apple.FinderInfo found on /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal
      [exit=1]
    7. and again with it removed:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app: valid on disk
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_personal/Shadowrun-personal.app: satisfies its Designated Requirement
      [exit=0]
  8. the third way a copy reads as damaged was measured in section 1: a payload laid
     out the way the pinned framework lays one out -- keybinds.ini, rom.cfg and the
     mod catalog loose beside the executable -- cannot be sealed at all, and codesign
     says 'code object is not signed at all' and names the loose file as a
     subcomponent.  That is the finding the host-side fix removes.

  so, of the three ways this bundle can be refused:
    * an unsealable payload, the shape every previous round of this port shipped:
      removed, and section 5 shows the shipped bundle still validating after it was
      copied, mounted, dragged and run.  That is the one this work was about.
    * attached Finder metadata: not created by anything in this build (line 5 above
      is empty), and section 6's ditto copy keeps validating, so the drag a person
      does does not add any.  Line 6 is here to show what would.
    * no developer identity: not removed, and nothing in this script can remove it.
      Lines 1-3 are the measurement of that: the assessment is 'rejected' before any
      download flag is involved, because the signature is ad hoc and unnotarised.
      That is why README.txt at the image root of this personal build tells the player
      to right-click and choose Open, and gives the xattr command: it is the
      documented way past a verdict that is correct about what this build is.

  And the reason this variant in particular cannot be handed to anyone: the
  section-8 scan above finds the guest image inside the executable that lands on
  the player's disk, byte for byte, at offset 0x447d3e, hashing back to the same
  sha256 as this kit's dump.  That is what 'personal' means here, and it is the
  same bundle's refusal a stranger would see if it were sent to them.

== DONE  (log: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/macos_package_personal.log)
