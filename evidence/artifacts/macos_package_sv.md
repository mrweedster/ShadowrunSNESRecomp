# macos_package_sv.md
#
# variant: shareable.  No ROM in the payload, in any form; the launcher
#          asks the player for their own dump once.
# what: the click-and-install macOS package (Shadowrun-sv.app inside a .dmg):
#       what is in it, what is provably not in it, and that it runs from
#       outside this repository
# how:  EDITION=sv scripts/package_macos_bundle.sh build-macos-arm64-sv macos-arm64
#
# framework used: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-mouse
#          (its status against the pin is measured in section 0, not claimed here)
# generated: 2026-11-11T08:50:45Z (host Darwin 25.6.0 arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

== 0. the build tree being packaged ==

  build dir  build-macos-arm64-sv
  edition    sv (Sweden); identity rom_identity.sv.txt; ROM /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
  variant    shareable: no ROM in the payload
  executable           3038f89d318db1d7  5783024 B
  CMAKE_BUILD_TYPE:STRING=Release
  SHADOWRUN_EDITION:STRING=sv
  SHADOWRUN_EMBED_ROM:BOOL=OFF
  SNESRECOMP_ENABLE_MODS:BOOL=ON
  no run manifest in build-macos-arm64-sv, so provenance.py key has nothing to read.
  The executable's own hash above is its identity in this log; what ties it to
  the build this kit treats as correct is section 7's c leg, not a manifest.
  NOT THE PIN  build-macos-arm64-sv: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-mouse @ 2bfb3a63d855dd12e043c4bcfac06858a9291498, pin is 773285b8210f2254ae87d0a14113980fb36990ad
  re-asking as a descendant of the pin:
  OFF THE PIN  build-macos-arm64-sv: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-mouse @ 2bfb3a63d855dd12e043c4bcfac06858a9291498, with 773285b8210f as an ancestor -- a branch off the pin, fine for a capability leg
    which is the shape this package is built from: a branch off the pin, one
    capability commit deep, kept as a branch rather than folded in because the
    commit changes where the port's saves live on macOS.  Section 5 compares
    the packaged bytes with this edition's own build tree, frame for frame, so
    what packaging and that commit did is measured rather than vouched for.
  SDL3 the build tree links   nothing: the executable references no SDL3
    dylib at all, so SDL3 is linked in statically and no dylib is vendored.
    That is the shape this package ships: with no vendored dylib, nothing
    inside the bundle raises the floor above the port's own target.

== 1. the bundle ==

  /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/payload_stage_sv/Shadowrun-sv: replacing existing signature
  /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app: replacing existing signature
  payload, read back off the finished bundle:
  Shadowrun-sv (CFBundleExecutable) 076aadfbabedf0c9  5767584 B
  no vendored dylib: SDL3 is inside Shadowrun-sv, so the tree below is the whole payload
  seal of the whole bundle     (empty output is codesign's pass)
    resource seal written:    Contents/_CodeSignature/CodeResources (2450 B)
  LSMinimumSystemVersion      11.0 (read from the executable's LC_BUILD_VERSION)
  the executable's own build record: minos 11.0, sdk 26.5  (MACOS)
  no other Mach-O in the bundle: SDL3 is linked into the executable, so the
    only build record in this package is the one above, and 11.0 is the floor.
  architecture of the payload: arm64
  size of the .app            5,5M
  tree:
    .
    ./Contents
    ./Contents/_CodeSignature
    ./Contents/_CodeSignature/CodeResources
    ./Contents/Info.plist
    ./Contents/MacOS
    ./Contents/MacOS/Shadowrun-sv
    ./Contents/PkgInfo
    ./Contents/Resources
    ./Contents/Resources/BUILD_INFO.txt
  
  the seal, put through the states a copy passes through (codesign's words, not this script's):
    1. the copy as shipped:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: valid on disk
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: satisfies its Designated Requirement
       [exit=0]
    2. the same copy with its resource seal taken away, which is what a bundle that was never sealed looks like to a Mac that expects one:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: invalid resource directory (directory or signature have been modified)
       [exit=1]
    3. that bundle laid out the way the pinned framework lays a bundle out -- a rom.cfg, a keybinds.ini and the launcher's mod catalog written beside the executable -- asked to be sealed at all:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: replacing existing signature
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: code object is not signed at all
       In subcomponent: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app/Contents/MacOS/mods/preloaded/state.toml
       [exit=1]
    4. the same bundle with the state taken back out and the seal put on again:
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: replacing existing signature
       [exit=0]
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: valid on disk
       /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_test_sv/Shadowrun-sv.app: satisfies its Designated Requirement
       [exit=0]
       so a bundle whose executable directory stays free of writable state seals, and a
         bundle laid out the way the pinned framework lays one out does not.
  
    and two copies of the finished bundle, both re-sealed with this script's own codesign
    command line, to answer whether the seal is a reproducible identity or a one-off:
  copy A, re-sealed unchanged    076aadfbabedf0c9
  copy B, BUILD_INFO.txt +1 line 6923e77e97a20052
  the bundle this run shipped    076aadfbabedf0c9
    A reproduces the shipped payload hash byte for byte, so the seal is deterministic and
      a payload hash is a legitimate identity for a build.  B moves it, because a code
      signature over a bundle seals the bundle's resources into the executable's own
      CodeDirectory -- 'hashes=N+3', the +3 being the bundle's CodeResources, its
      Info.plist and its requirements.  The payload's hash therefore pins the whole
      bundle, BUILD_INFO.txt included, and not just the Mach-O inside it.

== 2. what is provably not in the payload ==

  Both variants are scanned the same way; only the expected answers differ, and
  each line says which.  Nothing below is relaxed for PERSONAL=1: the scans that
  hold for both keep their expect-0, and the one scan that inverts is reported
  as a presence check with the symbols named.
  ROM/patch-shaped files                   0   (expect 0 in both: this package carries no ROM at all)
  embedded-ROM symbols in the executable   0   (expect 0; tools/embed_rom.py emits
                                           _snesrecomp_embedded_rom, and the host names
                                           _g_rom_embedded when it wires the image in)
  rom.cfg in the payload                   0   (expect 0: the launcher asks once and caches it under ~/Library/Application Support/Shadowrun-sv/, never inside the bundle)
  src/gen or recomp/funcs.h in the payload 0   (expect 0: build inputs, git-ignored)
  files naming this repository              0   (expect 0: an absolute build path would be a machine-local claim)
  files naming this machine's ROM directory (/Users/wee/Documents/work/ports/ShadowrunSNESRecomp):
    0   (expect 0: a baked-in rom.cfg would point at a file that does not exist on the player's disk)
  the guest image, looked for inside the executable itself:
    not found: no 1048576-byte region of Shadowrun-sv (5767584 B) matches the digest this build checks at boot
    MATCH: expected absent, absent
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
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/payload_stage_sv/Shadowrun-sv: valid on disk
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/payload_stage_sv/Shadowrun-sv: satisfies its Designated Requirement
      ('--validated:<path>' is codesign's pass; it prints nothing else.)
    Identifier=Shadowrun-sv-55554944642b7de924fa3b97939808b9f8fa84db
    Format=Mach-O thin (arm64)
    Signature=adhoc
    TeamIdentifier=not set

  the packaged executable once it sits inside the .app, and the bundle as a whole:
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app/Contents/MacOS/Shadowrun-sv: valid on disk
    exe:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app/Contents/MacOS/Shadowrun-sv: satisfies its Designated Requirement
    bundle: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app: valid on disk
    bundle: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app: satisfies its Designated Requirement
      Empty output from --verify is codesign's pass; --verbose=2 adds the
      '--validated' lines and the seal's own hash.  Contents/_CodeSignature/
      CodeResources is the resource seal, and it exists because nothing writable
      sits inside the bundle: the host keeps its state outside (see the intro), so
      saving a game no longer breaks a seal.
    what the seal says about the bundle:
      Identifier=org.retroportingtoolkit.shadowrun.sv
      Format=app bundle with Mach-O thin (arm64)
      CodeDirectory v=20400 size=11453 flags=0x2(adhoc) hashes=351+3 location=embedded
      TeamIdentifier=not set
      TeamIdentifier not set = ad-hoc: made on this machine, for this machine, with
      no Apple certificate behind it.
  
      The counter-case, generated rather than asserted -- a scratch copy of the
      finished bundle staged the way the pinned framework's layout needs it, with
      the host's runtime files beside its executable:
      seal attempt: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_attempt_sv/Shadowrun-sv.app: code object is not signed at all
      seal attempt: In subcomponent: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_attempt_sv/Shadowrun-sv.app/Contents/MacOS/mods/preloaded/README.md
      seal check:     /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/seal_attempt_sv/Shadowrun-sv.app: code object is not signed at all
      seal check:     In architecture: arm64
      That is the state a downloaded or mounted copy of such a bundle is re-assessed
      against: a signature that expects a resource seal with none present is what
      macOS reports to a person as '... is damaged and can't be opened'.  It is not
      a corrupt download; it is the bundle's own shape.  Fixing the shape is why the
      payload carries no loose state and why the seal above is made.
  Gatekeeper's verdict (ad-hoc is not a Developer ID, and notarisation needs one):
    exec:    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app: rejected
    install: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app: rejected
    Rejected, and a sealed bundle does not change that: the assessment needs a
    Developer ID signature plus a notarisation ticket, and an ad-hoc signature can
    carry neither.  So a copy that arrives through a browser carries the quarantine
    flag and Gatekeeper refuses it until the person overrides once -- right-click >
    Open, or clear the flag with
    'xattr -dr com.apple.quarantine /Applications/Shadowrun-sv.app'.  Nothing in this
    script can change that; the signing identity is free, Apple's is not.
    The .dmg built here carries no quarantine flag, because nothing downloaded it,
    and a copy made on this machine is not refused by anything.

== 3. the executable inside the .app, against the bytes the kit already measured ==

  packaged                 076aadfbabedf0c9  5767584 B
  build tree build-macos-arm64-sv/ShadowrunSNESRecomp 3038f89d318db1d7  5783024 B
  signature in the tree    CodeDirectory v=20400 size=44940 flags=0x20002(adhoc,linker-signed) hashes=1401+0
  signature when packaged  CodeDirectory v=20400 size=11453 flags=0x2(adhoc) hashes=351+3
  LC_CODE_SIGNATURE, tree  dataoff 5738064, 44960 B
  LC_CODE_SIGNATURE, packaged dataoff 5738064, 29520 B
  SDL reference, tree      (none: no SDL dylib load command -- SDL3 is inside this Mach-O)
  SDL reference, packaged  (none: no SDL dylib load command -- SDL3 is inside this Mach-O)
  header, tree             sizeofcmds 5520; load commands end at byte 5552
  header, packaged         sizeofcmds 5520; load commands end at byte 5552
  The signature blob starts at byte 5738064 in BOTH files, so everything before it
  is the same length in both, and the whole 15440 B difference between the two
  files above is the signature blob, the tree's blob being the larger.  ld scores 4 KiB
  pages over the whole binary; codesign --force --sign - scores 16 KiB pages on an
  executable this large, so the two blobs are not comparable byte for byte -- which
  is why section 5 compares machine state instead of hashing these two files.
  Compared up to that offset: 4 byte(s) of 5738064 differ, first at byte
  3089, last at 5550.
  The tree's load commands end at 32 + sizeofcmds(5520) = 5552:
  every difference is inside the Mach-O header and its load commands and
  nowhere else.  Everything past that -- code and data -- is bit-identical
  between the build tree and the shipped bytes.
  The load commands themselves moved by 0 B.  Nothing was rewritten here --
  SDL3 is linked in, so the only packaging step on this Mach-O is the ad-hoc
  sign -- and a sign writes the LC_CODE_SIGNATURE command, which is one load
  command of 16 B plus padding to 8 B.  __LINKEDIT's file offset comes from the
  segment table, so the padding absorbs the movement and the file's length moves
  only with the blob.
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_sv/plain/Shadowrun-sv: replacing existing signature
  probe: sign, outside               ce0743ee8ae8a260  5767568 B
    its identifier                   Shadowrun-sv-55554944642b7de924fa3b97939808b9f8fa84db
  NO MATCH against a plain-directory sign, and that is the bundle seal's doing:
  section 1 signs the finished Shadowrun-sv.app as a whole, and a whole-bundle seal
  re-signs the executable inside it with the bundle's identifier and a hash of
  Info.plist.  The probe that repeats those steps in order is the fourth one below.
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_sv/plain/other-name: replacing existing signature
  probe: same, named other-name      302dd833d0e77191  5767568 B
    its identifier                   other-name-55554944642b7de924fa3b97939808b9f8fa84db
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_sv/inbundle/Probe.app/Contents/MacOS/Shadowrun-sv: replacing existing signature
  probe: sign, INSIDE                d56d456f4bc98261  5767568 B
    its identifier                   org.example.signprobe
    its CodeDirectory                CodeDirectory v=20400 size=11438 flags=0x2(adhoc) hashes=351+3
    the packaged CodeDirectory       CodeDirectory v=20400 size=11453 flags=0x2(adhoc) hashes=351+3
  Signing in place inside a bundle re-draws the signature: the identifier comes from
  that bundle's Info.plist instead of the file name, and one more hash appears in the
  CodeDirectory -- that extra hash is the bundle's Info.plist, bound into the Mach-O's
  own signature.  The file length may or may not move, so size alone does not catch
  it; the hash does.  That is what the whole-bundle seal in section 1 does to the
  payload, and the fourth probe repeats it with this bundle's own Info.plist.
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_sv/full/Shadowrun-sv: replacing existing signature
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_sv/full/Shadowrun-sv.app: replacing existing signature
  probe: sign + bundle seal          076aadfbabedf0c9  5767584 B
    its identifier                   org.retroportingtoolkit.shadowrun.sv
    its CodeDirectory                CodeDirectory v=20400 size=11453 flags=0x2(adhoc) hashes=351+3
  MATCH: that order is the whole of what the packaging did to this executable.  A
  scratch copy of build-macos-arm64-sv/ShadowrunSNESRecomp, staged and sealed the way section 1 stages and seals, comes
  out at the shipped hash -- so the payload is pinned by the build tree's bytes plus
  the staging steps plus this bundle's Info.plist, and nothing else was done to it.
  The plain-directory sign of probe one is real but not final: the bundle seal that
  section 1 takes afterwards signs over it, which is why probe one alone does not
  match and probe four does.
  So a plain-directory sign pins the build tree's bytes and the file's name at
  once: nothing was rewritten in between, and an ad-hoc sign takes its identifier
  from the name.  Inside the finished bundle the identifier is the bundle's instead,
  which is what probe four pins.
  probe copies left behind           /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/sign_probe_sv
  staged ./Shadowrun       60067549c3ee8d3b  3103872 B
  differs from ./Shadowrun -- section 5 measures the packaged bytes against
  the build tree directly, so the claim does not depend on this match.

  no dylib to compare: SDL3 is linked into the executable, so the executable's
  hash above is the whole of the code this package carries.

== 4. the disk image ==

  created   /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-sv-0.1.0-macos-arm64.dmg
  size       2179662 B   sha256 fc1d200ec9435b7c
  Prüfsumme für Protective Master Boot Record (MBR : 0) berechnen …
  Protective Master Boot Record (MBR :: Die überprüfte CRC32-Prüfsumme ist $921771E1
  Prüfsumme für GPT Header (Primary GPT Header : 1) berechnen …
   GPT Header (Primary GPT Header : 1): Die überprüfte CRC32-Prüfsumme ist $E73F9054
  Prüfsumme für GPT Partition Data (Primary GPT Table : 2) berechnen …
  GPT Partition Data (Primary GPT Tabl: Die überprüfte CRC32-Prüfsumme ist $D320A068
  Prüfsumme für  (Apple_Free : 3) berechnen …
                      (Apple_Free : 3): Die überprüfte CRC32-Prüfsumme ist $00000000
  Prüfsumme für disk image (Apple_HFS : 4) berechnen …
            disk image (Apple_HFS : 4): Die überprüfte CRC32-Prüfsumme ist $88549181
  Prüfsumme für  (Apple_Free : 5) berechnen …
                      (Apple_Free : 5): Die überprüfte CRC32-Prüfsumme ist $00000000
  Prüfsumme für GPT Partition Data (Backup GPT Table : 6) berechnen …
  GPT Partition Data (Backup GPT Table: Die überprüfte CRC32-Prüfsumme ist $D320A068
  Prüfsumme für GPT Header (Backup GPT Header : 7) berechnen …
    GPT Header (Backup GPT Header : 7): Die überprüfte CRC32-Prüfsumme ist $EA6A7876
  Die überprüfte CRC32-Prüfsumme ist $A8CEE761
  hdiutil: verify: checksum of "/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-sv-0.1.0-macos-arm64.dmg" is VALID
  content of the mounted image:
    .
    ./Applications
    ./README.txt
    ./Shadowrun-sv.app
    ./Shadowrun-sv.app/Contents
    ./Shadowrun-sv.app/Contents/_CodeSignature
    ./Shadowrun-sv.app/Contents/_CodeSignature/CodeResources
    ./Shadowrun-sv.app/Contents/Info.plist
    ./Shadowrun-sv.app/Contents/MacOS
    ./Shadowrun-sv.app/Contents/MacOS/Shadowrun-sv
    ./Shadowrun-sv.app/Contents/PkgInfo
    ./Shadowrun-sv.app/Contents/Resources
    ./Shadowrun-sv.app/Contents/Resources/BUILD_INFO.txt
  the exe inside the image 076aadfbabedf0c9  5767584 B
    (the same hash section 3 measured in dist/, so the container did not alter
    the payload: hdiutil stores the file, it does not rewrite a Mach-O)
    drag target present: Applications -> /Applications
    ROM/patch-shaped files inside the image: 0   (expect 0)
    files in the image naming this repository: 0   (expect 0)
  second image, same payload c9df4ec3b103b3e4  2179655 B
    the .dmg is NOT byte-reproducible even from the same stage directory:
    hdiutil stamps volume metadata (dates, UUIDs) into the container.  What
    is reproducible is the payload -- sections 1 and 3 pin the .app hashes --
    so a hash of the .dmg is a hash of this run's container, not of the build.
  
  the ROM the legs below use is this machine's dump, passed on the command line
  every time; nothing about it is written into the package.

== 5. the packaged app, run from outside this repository ==

  Every leg runs against a copy of the bundle under /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/app_sv -- never the
  copy in dist/, never this repository's own runtime state.  The executable
  inside a .app resolves config.ini, keybinds.ini, rom.cfg, saves/, mods/ and
  the run report under ~/Library/Application Support/<bundle name>/ (the host
  derives that from $HOME when it is running from inside a bundle), so these
  legs are given a private $HOME under /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg and write only there.  Two things
  that buys, both measured below: nothing of this machine's own port state is
  touched by a packaging run, and the bundle copy can be inventoried before and
  after -- a bundle that stays byte-identical through a run is the property the
  '... is damaged' complaint is about, so it is checked rather than assumed.
  copy under test  076aadfbabedf0c9   (the bytes inside /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-sv-0.1.0-macos-arm64.dmg)
  HOME for these legs         /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_sv
    so the app's state directory is   /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_sv/Library/Application Support/Shadowrun-sv
  bundle copy before the legs: 11 files, tree hash f8b6b329db82fa1e
    its seal, asked before anything runs -- this copy came out of dist/ by ditto,
    not from the build:
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/app_sv/Shadowrun-sv.app: valid on disk
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/app_sv/Shadowrun-sv.app: satisfies its Designated Requirement
  a. frames from app  076aadfbabedf0c9  exit=0 exit: script quit after 1200 frames
        rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
        rom loaded: 1048576 bytes
  a. frames from tree 3038f89d318db1d7  exit=0 exit: script quit after 1200 frames
        rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
        rom loaded: 1048576 bytes
     one side is the installed bytes; the other is the build tree that made these bytes, build-macos-arm64-sv/ShadowrunSNESRecomp.
     everything between them is one ad-hoc sign in a plain directory plus the
     whole-bundle seal that signs over it: SDL3 is linked in, so there is no
     dylib name in the Mach-O to rewrite.
  identical over 1200 frames (crc32 of all 128 KiB of WRAM per frame)
    no non-label WRAM byte differs in 1200 shared frames
     identical frame state is what says sign plus the bundle seal -- all that
     separates the packaged bytes from build-macos-arm64-sv/ShadowrunSNESRecomp -- changed no machine state.  A
     stripped, link-edited binary alone cannot say that.
  b. scripted boot from inside the .app: exit=0 wall=6s
      [host +0.006s] rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
      [host +0.017s] SDL init ok: video=dummy audio=dummy
      [host +0.017s] rom loaded: 1048576 bytes
      [host +0.019s] window created: 960x720 flags=0x20
      script f=11 until 01C76 ok after 11 frames
      script f=278 until 01C77 ok after 267 frames
      script f=278 quit
      [host +4.764s] frame service: implementation=LLE seconds=4.729654125 fps=58.778 cpu_seconds=0.762850000
     the script waits on the game's own WRAM tick counter ($7E1C76), which
     increments once per emulated frame, so it fails loudly if the ROM stalls.
  c. the click path: started through LaunchServices, no terminal, no shell
     command line, no working directory the app was given:
     'open' exit=0.  LaunchServices starts the app the way a double-click
     does: no arguments it was not given, working directory '/', and no terminal
     for it to write to -- which is why the run is read back from the report the
     host writes at exit, rather than from stdout.
     waited 8s wall for it; pid 31830 has exited
      report written by the process LaunchServices started: reason=atexit  host frames=278  at 2026-11-11T08:51:55Z
        build game=Shadowrun version=0.1.0
        sdl video=(none) audio=(none)
        breadcrumb t=3477ms: config dir anchored: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_sv/Library/Application Support/Shadowrun-sv (exe-dir anchor: ok)
        breadcrumb t=3505ms: rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
        breadcrumb t=3609ms: SDL init ok: video=cocoa audio=coreaudio
        breadcrumb t=3610ms: rom loaded: 1048576 bytes
        breadcrumb t=3646ms: window created: 960x720 flags=0x20
        breadcrumb t=3867ms: renderer initialized: sdl
        breadcrumb t=8563ms: exit: script quit after 278 frames
     drivers this run actually opened: SDL init ok: video=cocoa audio=coreaudio
     window created: 960x720 flags=0x20
     those are the drivers a double-click gets, not the ones this script asks
     for: a real window opened on this machine for the length of the script, and
     the audio device was opened.  That is what makes this leg the click path
     and not a headless re-run of leg b.
     it found its own bundle from a working directory of "/" (LaunchServices
     starts an app at "/"), resolved its state under the state directory rather
     than inside itself, and quit by itself.
     and it left rom.cfg behind in the state directory, naming the dump it
     was given -- that is the cache that makes the first launch the only
     launch that asks:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
  d. the launcher page a user sees, reading that cached rom.cfg back -- the
     state of the app after the ROM has been chosen once:
      [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_sv/Library/Application Support/Shadowrun-sv/' (bundle run: state kept outside the .app).
      [host +0.000s] config parsed: output=0 new_renderer=1 scale=3 fullscreen=0 audio=1 freq=32000 samples=512
      [Launcher] ROM: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
      [host +0.008s] rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
      [host +0.021s] rom loaded: 1048576 bytes
      [host +0.024s] window created: 960x720 flags=0x20
      [Gamepad] SDL reports 0 joystick(s). enable_gamepad=[1,1,0,0,0]
      [host +0.039s] first frame simulated
     that rom.cfg lives only in this scratch copy; the shipped package has none,
     which is why the first launch asks.  No leg in this run ever reached the
     ROM file picker, and no ROM data was written into the package.

  e. the actual install path: copy the .app out of the mounted image with
     Finder-equivalent ditto into a fresh directory that is not this
     repository at all, then run that copy from that directory
     scratch install directory (machine-local, outside the repository): /var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.EL8jVa
     copied out of the image     076aadfbabedf0c9
     same bytes as dist/Shadowrun-sv.app  (the drag changes nothing but the path)
     state directory before that launch: absent -- nothing of the port exists yet
     the installed copy, as shipped (it carries no state of any kind):
      ./Shadowrun-sv
     exit=0 wall=5s, run with CWD=/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.EL8jVa
      [host +0.007s] rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
      [host +0.020s] SDL init ok: video=dummy audio=dummy
      [host +0.020s] rom loaded: 1048576 bytes
      [host +0.023s] window created: 960x720 flags=0x20
      script f=11 until 01C76 ok after 11 frames
      script f=278 until 01C77 ok after 267 frames
      script f=278 quit
      [host +4.784s] frame service: implementation=LLE seconds=4.737423208 fps=58.682 cpu_seconds=0.743561000
     written inside the installed bundle by that run:
     (expect nothing: the app keeps its state outside the bundle)
     payload paths that disappeared during that run: 0   (expect 0: the list after is the list before, so nothing the package needs was deleted)
     the bundle's seal after that run, asked of the installed copy:
      /var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.EL8jVa/Shadowrun-sv.app: valid on disk
      /var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T//srpkg.EL8jVa/Shadowrun-sv.app: satisfies its Designated Requirement
     what the first launch created in the state directory instead:
      .
      ./config.ini
      ./keybinds.ini
      ./last_run_report.json
      ./mods
      ./mods/preloaded
      ./mods/preloaded/packages
      ./mods/preloaded/state.toml
      ./rom.cfg
      ./saves
      ./saves/save.srm
     saves and settings live there, next to the player's other per-app state,
     not inside the .app: replacing or re-downloading the app keeps them, and a
     read-only copy -- a mounted image, a translocated run -- cannot make a save fail.
     files in this repository touched during that run: 0   (expect 0: an
     installed app must not read or write this checkout even when this checkout
     is the machine that built it)
     which is the point of the .app: the payload carries its own anchor, so an
     installed copy is self-contained -- no repository, no build tree, no
     Homebrew, and no second copy of the runtime files.

  f. what that changed on disk, both sides of the line:
  bundle copy before the legs        11 files, tree hash f8b6b329db82fa1e
  same copy after every leg          11 files, tree hash f8b6b329db82fa1e
     the bundle copy under test is byte-for-byte what it was before any of
     these runs: the app wrote nothing inside itself, at any point, through a
     scripted boot, a LaunchServices start, a launcher page and a save.
     Its seal, asked again after all of that:
     (empty = valid).  A copy that survives being copied, mounted, dragged and
     run, and still validates, is the property the 'is damaged' complaint says
     this payload used to fail.

== 6. what the installed app leaves behind ==

  package        shadowrun-sv-0.1.0-macos-arm64.dmg  2179662 B  sha256 fc1d200ec9435b7c
  app            5,5M unpacked, 2179662 B compressed
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
    ./rom.cfg
    ./saves
    ./saves/save.srm
    its mod catalog holds 1 file(s), created by the app itself rather than shipped by this script

  That is the trade-off, and it is the one a person installing this expects:
  no installer and no privileged helper, the app can live anywhere it is put --
  and its saves, settings and ROM choice live in ~/Library/Application Support/
  Shadowrun-sv/ rather than inside the bundle, so replacing or re-downloading the
  app keeps them, and the bundle stays sealed and verifiable.  A port that kept
  state inside the bundle had the other trade: moving the app moved its saves,
  and the loose files inside Contents/MacOS/ made the bundle impossible to seal
  -- which is the shape a downloaded copy of that would be refused for.

== 7. the frames the shipped bytes produce, taken out of the container ==

  three legs to 1200 frames on the kit's menu route -- the personal variant's
  shape with its embedded-ROM leg taken away, because this payload has no
  embedded guest to exercise (section 2 established that).  The subject of the
  first leg is the executable as the container holds it, read off the read-only
  mount, not the copy in dist/: section 5 compares the copy in dist/, and this
  section answers the question a person who downloaded the .dmg would ask instead.
  a. that executable, with --rom naming the dump
  c. build-macos-arm64-sv/ShadowrunSNESRecomp, this edition's own build tree, with --rom: the packaged bytes
       against the executable they were made from.  The kit's accepted reference
       builds are USA-configured, and their frame routes were measured on USA
       text: comparing the Sweden translation against one of those would
       measure the translation, not the packaging.  d is the same file.
  
  How far apart a and c are is not assumed: the lines below print both subjects'
  hash, size and build record, and c's framework status against the pin in the
  same call section 0 uses for this package.
  attached /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/shadowrun-sv-0.1.0-macos-arm64.dmg at /Volumes/Shadowrun-sv for these legs
  these legs run under the private $HOME section 5 set up (/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/state_home_sv), so any
  state a run writes lands under tests/out/ rather than next to the checkout.
  subject a (in the image)         076aadfbabedf0c9  5767584 B
       build record: minos 11.0, sdk 26.5
       SDL3, from its own load commands: no SDL dylib load command -- SDL3 is inside this Mach-O
  subject c (build-macos-arm64-sv/ShadowrunSNESRecomp) 3038f89d318db1d7  5783024 B
       build record: minos 11.0, sdk 26.5
       SDL3, from its own load commands: no SDL dylib load command -- SDL3 is inside this Mach-O
  subject d: the same file as c (build-macos-arm64-sv/ShadowrunSNESRecomp), so the d leg below is skipped rather
       than run twice -- SHIP_EXE and REF_PIN name one tree in this checkout.
    c's and d's frameworks, measured as section 0 measures this package's:
      OFF THE PIN  build-macos-arm64-sv: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-mouse @ 2bfb3a63d855dd12e043c4bcfac06858a9291498, with 773285b8210f as an ancestor -- a branch off the pin, fine for a capability leg
      OFF THE PIN  build-macos-arm64-sv: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-mouse @ 2bfb3a63d855dd12e043c4bcfac06858a9291498, with 773285b8210f as an ancestor -- a branch off the pin, fine for a capability leg

    frames_file: Shadowrun-sv  --rom named on the command line  cwd=a scratch directory, not the repository
      exit=0 -> 1245 WRAM dumps
      what the host itself said about where its guest came from:
      [host +0.011s] rom resolved: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (Sweden).sfc
      [host +0.025s] rom loaded: 1048576 bytes
    frames_embed: not applicable -- the shareable build carries no guest image,
          so there is no embedded path to exercise.  Section 2's finding that no
          rom.cfg and no image sits in the payload is what says a leg without
          --rom here would have nothing to boot.
    frames_refpin: not run for the Sweden edition -- the reference builds this
          section compares against are USA-configured and their routes were
          measured on USA text.  Section 5 already ran this edition's packaged
          copy against its own build tree, frame for frame.
    frames_ref11: not run for the Sweden edition -- the reference builds this
          section compares against are USA-configured and their routes were
          measured on USA text.  Section 5 already ran this edition's packaged
          copy against its own build tree, frame for frame.

  No cross-build pair is reported for the Sweden edition.  The subjects
  this section can compare within one edition were compared in section 5: the
  packaged copy against the executable it was built from, frame for frame.  The
  mounted copy's own run above says the container's bytes still boot.

== 8. what is inside the .dmg, and the ROM question asked of both files ==

  the container the way it would reach a person: one file, and the volume inside it
  enumerated while mounted read-only.  Section 4 mounted that image, section 5
  detached it once its install leg had run from it -- that is what a person does
  with one -- and section 7 attached it again to run legs off it and left it
  attached, which is what is being read here.
  .
  ./Applications
  ./README.txt
  ./Shadowrun-sv.app
  ./Shadowrun-sv.app/Contents
  ./Shadowrun-sv.app/Contents/_CodeSignature
  ./Shadowrun-sv.app/Contents/_CodeSignature/CodeResources
  ./Shadowrun-sv.app/Contents/Info.plist
  ./Shadowrun-sv.app/Contents/MacOS
  ./Shadowrun-sv.app/Contents/MacOS/Shadowrun-sv
  ./Shadowrun-sv.app/Contents/PkgInfo
  ./Shadowrun-sv.app/Contents/Resources
  ./Shadowrun-sv.app/Contents/Resources/BUILD_INFO.txt
    README.txt at the image root is what a person reads before they move the app;
    its floor line is not typed here, it is read out of the executable:
  | Shadowrun (Sweden), recompiled natively -- version 0.1.0, macos-arm64
  | 
  | 
  | 1. Drag Shadowrun-sv.app to Applications (the shortcut in this window).
  |    Drag it, do not run it from this window: a mounted image is read-only and
  |    macOS also moves an app run straight from a mounted image to a random
  |    read-only location of its own (App Translocation).
  | 2. Open it. It asks once for your own copy of Shadowrun ($EDITION_TITLE). Only that dump
  |    is accepted -- the digests are baked into the build -- and the choice is
  |    remembered in your Library, so it asks once.
  |    You must legally own the game. No ROM is included in this package.
  | 3. Settings and saves live beside your other per-app state, not inside the app:
  |      ~/Library/Application Support/Shadowrun-sv/config.ini
  |      ~/Library/Application Support/Shadowrun-sv/saves/save.srm
  |      ~/Library/Application Support/Shadowrun-sv/keybinds.ini
  |    (the ROM choice you made once is in that folder too).
  |    That is why replacing or re-downloading the app keeps your save, and why the
  |    bundle itself can stay sealed.  Delete that folder to start the port over.
  | 4. If macOS refuses to open it, that is Gatekeeper and not a broken download:
  |    this build is signed ad hoc, not with a Developer ID and not notarised.
  |    Right-click the app and choose Open, or clear the quarantine flag:
  |      xattr -dr com.apple.quarantine /Applications/Shadowrun-sv.app
  | 5. Needs macOS 11.0 or newer; architecture: arm64.
  | 
  | Keys and mouse, until you edit the keybinds.ini named above and restart:
  |   mouse             the in-game hand follows the pointer; the OS arrow hides
  |                     while the pointer is over the game
  |   left / right / middle mouse = B / A / Y
  |   W A S D = d-pad    X = start    Y = select
  |   C = X    Q = L    E = R
  the executable inside the image        076aadfbabedf0c9  5767584 B

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
  ROM file  1048576 B   sha256 4fb9eb8fa4d9c3a0
  The scans below ask about four things that could each be present on their own:
  the image's first 256 bytes, its filename, its SNES header string, and its
  digest written as hex text.  A name and a digest are what a build needs in order
  to say which dump it accepts; bytes are what a build needs in order to run one
  without being given one.
  container   2179662 B
      ROM first 256 bytes present:  False
      ROM filename present:         False
      SNES header string present:   False
      ROM sha256 as hex text:       False
      carve-out: no offset -- the span is not in this file
  exe in image  5767584 B
      ROM first 256 bytes present:  False
      ROM filename present:         True
      SNES header string present:   False
      ROM sha256 as hex text:       True
        filename at 0x44e2ec, and the printable strings around it are:
          ['address', 'guard_hex', "missing glyph mapping for '", 'Shadowrun', 'Shadowrun (Sweden).sfc', '4fb9eb8fa4d9c3a0b6c24bac5b0a0b0f079f083f5e6dfa937a161c8f4bcde853', '30829d8e', 'shadowrun-sv', '0.1.0']
      carve-out: no offset -- the span is not in this file

  the outcomes for this variant, and they do not all read the same way.  The
  image's bytes are absent from both subjects and the carve-out finds no offset in
  either, so neither the file a person downloads nor the file that lands on their
  disk holds the game.  The dump's *name* is present in the executable -- once --
  and the strings printed around it show what that presence is: the name sitting
  next to this dump's own sha256, which is the accepted-dump record, the build
  saying which file it will take from the player.  Name and digest, not the dump.
  Section 2 reached the same place by other means: no ROM-shaped file in the
  payload, no embedded-ROM symbol in the executable, no rom.cfg, and no region of
  the payload matching the digest this build checks at boot.  The volume listing
  above is the other half of the answer: the image holds the bundle, one README and
  an Applications shortcut, and nothing else.  The container-level scan alone would
  not be enough, for the compression reason given above: absence in a zlib
  container says little by itself, and the load-bearing absence is the payload's.

== 9. what macOS's own tools say about this bundle, and what each verdict is about ==

  The complaint this packaging exists to answer is a sentence from macOS -- '...
  is damaged and can't be opened' -- rather than a crash, so the last section asks
  for that sentence from the tools that produce it and prints their words: codesign
  (is this payload intact), spctl (may Gatekeeper let it run) and xattr (has
  anything been attached to the files that is not part of them).  Three questions,
  and they do not have the same answers: a bundle can be intact and still refused.
  Keeping the three apart is the point, because the three fixes are different and
  this script can perform only two of them.
  copy under test for this section        /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app
  1. what kind of signature this package is able to make, read off the bundle:
      Identifier=org.retroportingtoolkit.shadowrun.sv
      Format=app bundle with Mach-O thin (arm64)
      CodeDirectory v=20400 size=11453 flags=0x2(adhoc) hashes=351+3 location=embedded
      Signature=adhoc
      TeamIdentifier=not set
      Sealed Resources version=2 rules=13 files=1
      Processing: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/dist/Shadowrun-sv.app
      Shadowrun-sv.app does not have a ticket stapled to it.
        'Signature=adhoc' and 'TeamIdentifier=not set' say whose identity is on
        this bundle -- nobody's -- and 'does not have a ticket' says it was never
        notarised.  Both are facts about this build, not accidents to fix here.
    2. Gatekeeper's assessment of that bundle, on a copy this machine itself built:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app: rejected
      [exit=3]
        the quarantine flag a browser leaves on a download, now set: 0081;6af42cd7;Chrome;
    3. the same assessment with that flag set -- the state of a downloaded copy:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app: rejected
      [exit=3]
    4. the seal, with that same flag on the bundle -- does the download flag break it?
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app: valid on disk
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app: satisfies its Designated Requirement
      [exit=0]
        the assessment above does not change and the seal still validates, so the
        refusal and the payload are two different findings.  A damaged-looking
        download is not, on this evidence, a download that arrived broken.
  5. attached data: what the payload carries, and what happens when something is added.
        (expect nothing above: no extended attribute on the shipped executable)
        now give the scratch copy's executable the Finder metadata a copy-through-Finder or a stray resource fork leaves behind:
    6. the strict seal check with that attribute present:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app: resource fork, Finder information, or similar detritus not allowed
      file with invalid attached data: Disallowed xattr com.apple.FinderInfo found on /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app/Contents/MacOS/Shadowrun-sv
      [exit=1]
    7. and again with it removed:
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app: valid on disk
      /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/gatekeeper_sv/Shadowrun-sv.app: satisfies its Designated Requirement
      [exit=0]
  8. the third way a copy reads as damaged was measured in section 1: a payload laid
     out the way the pinned framework lays one out -- keybinds.ini, rom.cfg and the
     mod catalog loose beside the executable -- cannot be sealed at all, and codesign
     says 'code object is not signed at all' and names the loose file as a
     subcomponent.  That is the finding the host-side fix removes.

  so, of the three ways this bundle can be refused:
    * an unsealable payload, the shape every previous round of this port shipped:
      removed, and section 5 shows the shipped bundle still validating after it was
      copied, mounted, dragged and run, with nothing written inside it.  That is the
      one this work was about, and it is the one that produced the original report.
    * attached Finder metadata: not created by anything in this build (line 5 above
      is empty), and section 5's ditto copy keeps validating, so the drag a person
      does does not add any.  Line 6 is here to show what would, because a port that
      ships loose files also tends to be moved around by tools that add them.
    * no developer identity: not removed, and nothing in this script can remove it.
      Lines 1-3 are the measurement of that: the assessment is 'rejected' before any
      download flag is involved, because the signature is ad hoc and unnotarised.
      A shareable build carries that verdict too, which is why README.txt at the
      image root tells a person to right-click and choose Open and gives the xattr
      command.  Anyone who would rather not tell their users that needs a Developer
      ID signature and a notarisation ticket; both are outside what this script can
      do, and the log records that rather than pretending otherwise.

== DONE  (log: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/pkg/macos_package_sv.log)
