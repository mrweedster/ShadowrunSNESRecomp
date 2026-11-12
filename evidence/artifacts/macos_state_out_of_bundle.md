# macos_state_out_of_bundle.md
#
# what: the host change that keeps a macOS bundle's state outside the .app,
#       measured against the pinned host on the same machine: sealing, the
#       bundle's own file inventory across a run, where the state lands, and
#       the per-frame WRAM state of both hosts over the parity route
# how:  tests/macos_state_probe.sh with FORK=build-fork-osx PIN=build-ship SCRIPT=tests/scripts/short.txt PARITY=tests/scripts/parity.txt
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad (framework_pins.txt)
# generated: 2026-11-09T15:15:15Z (host Darwin 25.6.0 arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

== 0. the two hosts ==

  both are built from this checkout; only the framework they link differs, and
  the framework of each is read from its own CMakeCache.txt below.
  shipping framework host        092b0e690cab97a1  5970048 B  minos 11.0
                                 framework /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-osx
                                 HEAD 32266300d722b8b31cde3bbdc55614587f7653ae  dirty 0
  shipping framework host: OFF THE PIN at 32266300d722b8b31cde3bbdc55614587f7653ae, with 773285b8210f2254ae87d0a14113980fb36990ad as an ancestor -- the pin plus
    1 commit(s), which is the shape this claim is about
  pinned framework host          a0587ed0a0e34687  3103776 B  minos 26.0
                                 framework /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
                                 HEAD 773285b8210f2254ae87d0a14113980fb36990ad  dirty 0
  pinned framework host: AT THE PIN 773285b8210f2254ae87d0a14113980fb36990ad
  dump the legs run              /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc

== A. non-bundled: the anchor must stay the binary's own directory ==

  this is the layout every development tree and test-kit leg uses; the host
  change must not touch it, or it would move the state of 200 earlier measurements.
  fork: exit=0  anchor line, run.log:
      [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/plain_fork/'.
      [host +3.180s] frame service: implementation=LLE seconds=3.142680708 fps=57.276 cpu_seconds=0.328823000
  fork: files that run left beside the binary:
      config.ini
      keybinds.ini
      last_run_report.json
      mods
      mods/preloaded
      mods/preloaded/packages
      mods/preloaded/state.toml
      rom.cfg
      run.log
      saves
      saves/save.srm
      ShadowrunSNESRecomp
  pin: exit=0  anchor line, run.log:
      [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/plain_pin/'.
      [host +3.184s] frame service: implementation=LLE seconds=3.148691125 fps=57.167 cpu_seconds=0.446131000
  pin: files that run left beside the binary:
      config.ini
      keybinds.ini
      last_run_report.json
      mods
      mods/preloaded
      mods/preloaded/packages
      mods/preloaded/state.toml
      rom.cfg
      run.log
      saves
      saves/save.srm
      ShadowrunSNESRecomp
  and the state directory stayed empty, because neither run was inside a .app:
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/home/Library/Application Support does not exist

== B. bundled, shipping host: seal, run, re-verify ==

  the bundle holds only Info.plist and the payload -- no loose state was staged:
    ./Contents
    ./Contents/Info.plist
    ./Contents/MacOS
    ./Contents/MacOS/Shadowrun
  -- whole-bundle seal --
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/Shadowrun.app: replacing existing signature
  codesign exit=0
  -- seal check before anything runs --
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/Shadowrun.app: valid on disk
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/Shadowrun.app: satisfies its Designated Requirement
  verify exit=0
  run exit=0
      [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/home/Library/Application Support/Shadowrun/' (bundle run: state kept outside the .app).
      [host +3.184s] frame service: implementation=LLE seconds=3.133761792 fps=57.439 cpu_seconds=0.461747000
  inventory diff (only the label line differs if nothing was written inside):
    1c1
    <   before run file inventory:
    ---
    >   after run file inventory:
  files in the bundle before=4  after=4
  the payload inside it, hashed before and after the run: 4300488f8b02c3e7 / 4300488f8b02c3e7
  -- seal check after the run --
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/Shadowrun.app: valid on disk
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/Shadowrun.app: satisfies its Designated Requirement
  verify exit=0
  resource seal written by the seal: CodeResources 

== C. bundled, pinned host: the shape that made the 'is damaged' report ==

  the bundle as the pinned layout makes it:
    ./Contents
    ./Contents/Info.plist
    ./Contents/MacOS
    ./Contents/MacOS/config.ini
    ./Contents/MacOS/keybinds.ini
    ./Contents/MacOS/last_run_report.json
    ./Contents/MacOS/mods
    ./Contents/MacOS/mods/preloaded
    ./Contents/MacOS/mods/preloaded/packages
    ./Contents/MacOS/mods/preloaded/state.toml
    ./Contents/MacOS/rom.cfg
    ./Contents/MacOS/saves
    ./Contents/MacOS/saves/save.srm
    ./Contents/MacOS/Shadowrun
  -- whole-bundle seal, same command that succeeded in B --
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/Shadowrun.app: replacing existing signature
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/Shadowrun.app: code object is not signed at all
    In subcomponent: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/Shadowrun.app/Contents/MacOS/mods/preloaded/state.toml
  codesign exit=1
  -- seal check --
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/Shadowrun.app: code has no resources but signature indicates they must be present
  verify exit=1
  resource seal: (empty = none was written)
  run exit=0
      [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/Shadowrun.app/Contents/MacOS/'.
      [host +3.199s] frame service: implementation=LLE seconds=3.152912833 fps=57.090 cpu_seconds=0.380857000
  inventory diff:
    1,3c1,2
    <   before run file inventory:
    <   1a652b1de2852fce  1794237319  ./Contents/MacOS/mods/preloaded/state.toml
    <   3b5c0a72384ffe55  1794237322  ./Contents/MacOS/last_run_report.json
    ---
    >   after run file inventory:
    >   1a652b1de2852fce  1794237326  ./Contents/MacOS/mods/preloaded/state.toml
    5c4,5
    <   9f1dcbc35c350d60  1794237322  ./Contents/MacOS/saves/save.srm
    ---
    >   9f1dcbc35c350d60  1794237322  ./Contents/MacOS/saves/save.srm.bak
    >   9f1dcbc35c350d60  1794237329  ./Contents/MacOS/saves/save.srm
    7a8
    >   b46a2e103a47a167  1794237330  ./Contents/MacOS/last_run_report.json
    9c10
    <   f3a321f4a6c41774  1794237319  ./Contents/MacOS/rom.cfg
    ---
    >   f3a321f4a6c41774  1794237326  ./Contents/MacOS/rom.cfg
  files in the bundle before=9  after=10
  the payload inside it, hashed before and after the run: a0587ed0a0e34687 / a0587ed0a0e34687
  -- seal check after that run, which is what a copy of this bundle is judged by --
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/Shadowrun.app: code has no resources but signature indicates they must be present
  verify exit=1
  and on a copy taken from it, the same answer:
    /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/copy.app: code has no resources but signature indicates they must be present
  verify exit=1

== D. where the state actually went ==

  the private $HOME these legs were given: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/home
  /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/home/Library/Application Support/Shadowrun
      config.ini
      keybinds.ini
      last_run_report.json
      mods
      mods/preloaded
      mods/preloaded/packages
      mods/preloaded/state.toml
      rom.cfg
      saves
      saves/save.srm
  /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/home/Library/Application Support/Shadowrun.probe: does not exist
  state under the name the bundle's directory gives it, which is how two
  different bundles never share one state directory:
    B said: [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/home/Library/Application Support/Shadowrun/' (bundle run: state kept outside the .app).
    C said: [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/scratch/pin/Shadowrun.app/Contents/MacOS/'.

== E. the same legs, frame by frame: state moved, the machine did not ==

  everything above is about where bytes are written.  It says nothing about
  whether the host change moved the machine itself, and the two executables
  cannot answer that by hash: one is built at the pin against Homebrew's SDL3
  dylib, the other one commit past the pin with SDL3 linked in statically, so
  their sizes and their load lists differ whatever the host change did.  The
  question is asked the way every other comparison in this kit asks it: the
  same route both legs already use, tests/scripts/parity.txt, with the host's own per-frame
  crc32 of all 128 KiB of WRAM dumped and compared.  The sizes on the two leg
  lines are why only that comparison will do: two executables nearly 3 MB apart,
  so no hash of the files can say whether the host change moved anything.
  fork  leg  exe 092b0e690cab97a1  5970048 B  exit=0  exit: script quit after 1200 frames
        [host +21.228s] frame service: implementation=LLE seconds=21.185414500 fps=56.643 cpu_seconds=2.991678000
        [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/frames/fork/'.
  fork  wrote 1200 frame records, plus the matching _wram.bin images, into tests/out/state_probe/frames/dump_fork
  pin   leg  exe a0587ed0a0e34687  3103776 B  exit=0  exit: script quit after 1200 frames
        [host +21.291s] frame service: implementation=LLE seconds=21.252613417 fps=56.464 cpu_seconds=2.985575000
        [Launcher] Config/saves anchored to '/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/state_probe/frames/pin/'.
  pin   wrote 1200 frame records, plus the matching _wram.bin images, into tests/out/state_probe/frames/dump_pin
  identical over 1200 frames (crc32 of all 128 KiB of WRAM per frame)
    no non-label WRAM byte differs in 1200 shared frames
  so the host change is what it says it is: a different place to keep config,
  saves and rom.cfg, with the emulator's per-frame state unchanged.  That is the
  claim that lets §7.19's package still inherit every earlier measurement made
  against the pinned executable.

== DONE ==
