# macos_user_open.md
#
# what: what a person who downloads one of the shipped images actually gets:
#       copy the .app out with ditto, ask whether this machine can exec these bytes
#       at that path at all, double-click the copy with no download flag on it, then
#       put the download flag on and double-click again, and finally ask whether
#       the copy that just ran is still the bytes that shipped, whether it still
#       seals, and whether anything said the word 'damaged' on the way; and, in
#       click-path legs of its own, what the same copy does when the ROM or the input
#       script it is handed sits inside ~/Documents rather than in a plain directory.
# how:  tests/macos_user_open_probe.sh (OPEN_WAIT=45 DENY_WAIT=30 NO_PID_WAIT=25 HELD_WAIT=12 FOLDER_WAIT=30 ROM_LEGS=with)
#
# inputs: dist/shadowrun-0.1.0-macos-arm64.dmg (shareable) and
#          dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg (personal), both
#          built in the packaging round; their hashes are printed in section 0.
# scratch: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509 -- one directory of its own per pass, because stopping a
#          process macOS holds at exec is measured to leave that bundle directory
#          unable to exec (tests/macos_exec_hold_probe.sh), and section 7 checks
#          and clears what this pass leaves of its own paths.
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad (framework_pins.txt), printed for cross-reference only
# generated: 2026-11-10T06:25:09Z (host Darwin 25.6.0 arm64, macOS 26.7.1 25G241)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

== 0. the images, and what this probe is about to cost ==

  the packaging round's section 9 measures an assessment; this probe measures the
  open itself.  Both packages that exist in dist/ go through the same walk: copy
  out of the image with ditto, set the download flag, double-click, clear the flag
  the way right-click -> Open does, double-click again, and then ask whether the
  copy that just ran is still the bytes that shipped and still seals.

  shadowrun-0.1.0-macos-arm64.dmg                         2221175 B  sha256 fe2648738fad58a6
  shadowrun-embed-0.1.0-macos-arm64-personal.dmg          2949133 B  sha256 7edb5fe11827d880
  a .dmg hash pins one run rather than one build, so the payload hashes inside are
  the figures that repeat across rounds; they are printed per package below.

  two costs of doing this for real, stated before the legs rather than after:
    * the legs start through LaunchServices, so their $HOME is whatever 'open'
      relays.  They are given a private one, /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/state_home, and section
      6 checks this machine's real ~/Library/Application Support/ before and after
      to show the relay held.  A test has no business rewriting a person's saves.
    * the successful open legs are not headless: a real window and a real audio
      device open for the length of /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/scripts/shorter.txt -- 60 emulated frames, a couple of
      seconds of wall clock per run -- which is what makes them the click path
      rather than another dummy-driver re-run.
  how each open is read back, because 'open' does not report the app's outcome:
    the leg looks for a process of this bundle by the tail of its executable path,
    records the pid and the path it saw, and then reads the run report the host
    writes on its way out -- the only thing a LaunchServices start leaves behind.
    Matching the tail rather than the path the leg opened is not a detail: a bundle
    that still carries the download flag can be translocated by macOS, run from a
    randomised read-only path rather than from the copy on disk, and an earlier pass
    of this probe printed 'no process at all' for legs whose processes were on the
    machine the whole time, held at exec.  Each leg ends by stopping whatever it
    left, so a leftover is never read as the next leg's process and no app stays on
    the user's screen.  macOS's own syspolicyd and CoreServicesUIAgent log lines for
    the same window are printed too, because that is where a refusal would be
    recorded in the system's words.
  three waits rather than one, and one of them is a cost paid on the user's screen:
    * 25s with no process at all ends a leg, because
      'open -W' never returns when LaunchServices refuses the launch -- measured, its
      own wait sits there forever -- so waiting out a longer cap would buy the same
      answer and leave Gatekeeper's sheet on the screen the whole time.
    * 30s caps a leg whose point is that it gets refused: measured on this
      machine, syspolicyd logs its own decision for this bundle about nine seconds
      after its prompt, so anything past that is only waiting.
    * 45s is the cap for a leg that started something and would not
      end, which is the shape of a window this harness cannot answer; such a leg is
      stopped by signal and recorded as hung.
  one thing is counted as a finding rather than written as prose: if the word 'damag'
   appears in what those two system agents logged about either open, that is the
   sentence this port's state-out-of-the-bundle fix exists to make impossible, and the
   leg that printed it fails the run.
  the shareable legs pass --no-launcher and --rom, so nothing here can stop at a
  ROM file picker:
    ROM given to the legs:    /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/staged/Shadowrun.sfc
    script given to the legs: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/staged/shorter.txt
    staged out of:            /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc
                            and /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/scripts/shorter.txt
    sizes: 1048576 B and 13 B, sha256 e6bc0a595d5c7c4b and 457b319c4a66fbb8

== 1.shareable: copying Shadowrun.app out of the image the way a drag does ==

  mounted read-only at /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/mnt-shareable
      "disk6" ejected.
  ditto is the copy a drag-and-drop performs, xattrs and all, so the copy under
  test here is what a person gets rather than what this machine staged.
  copy under test            37d08a86a2a86414   5953488 B
  bundle before any of it    11 entries, tree hash 61cd989abe7b934d
    (the listing is a find over the directory holding the .app, which is the
     listing the packaging log takes over its own staging copy, so the entry
     counts are the same kind of figure -- 11 there as well -- while the hashes
     are digests over different absolute paths and are not expected to match.
     The payload digest above is what ties this copy to the one that shipped.)
  its seal before anything has been done to it:
    codesign --verify --strict --verbose=2
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]

== 2.shareable: before any open, can this machine exec these bytes at all? ==

  one question asked first, because a machine that cannot exec this code signature
  makes every leg below print a tidy-looking nothing while measuring nothing:
  is the exec of these bytes being held by macOS right now?
    started directly from a shell, dummy drivers, its own $HOME (/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/preflight_home),
    with the same /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/staged/shorter.txt every other leg runs:
     it ran and finished on its own: 29 line(s) of its own output,
     and its run report is /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/preflight_home/Library/Application Support/Shadowrun/last_run_report.json
     (--rom on this line because the shareable payload carries no image)
    exec is not held, so the legs that have to run the app can tell the difference
    between running, being refused, and being held.

== 3.shareable: the copy with the download flag cleared, and the double-click after it ==

  this leg runs before the refusal leg on purpose.  A refused launch can leave a
  process held at exec while macOS waits for a sheet nobody in this run answers, and
  on this machine a path that had held one was measured still refusing to exec
  afterwards -- see section 2.shareable above and the end of section 7.  The claim
  that has to be measured here, that the copy a person ends up with after
  right-click -> Open starts, is therefore taken first, while the path is known to
  be able to run it.
  macOS's own wording for an unverified download is right-click the app, choose
  Open, then Open again in the sheet.  What that does to the files on disk is
  remove the quarantine flag, and the command the README at the image root tells
  a person to type does the same thing, so it is done here rather than guessed.
    attached data on the copy (expect nothing):
    Gatekeeper's assessment of the copy with no flag on it:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: rejected
      [exit=3]
    rejected is expected here too: an ad hoc, unnotarised signature never passes an
    assessment.  So the assessment is not what makes the app start for a person --
    their explicit choice, remembered by LaunchServices, is.  Which means the
    double-click below is the measurement, and this line is not.
     nothing of Shadowrun is running yet, so any process below is this leg's
     the leg's process was pid 77747, running from:
       /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app/Contents/MacOS/Shadowrun
     this leg took 3s of wall clock
     'open' exit=0
     (the 'open' command printed nothing on stdout or stderr)
     reading the state directories for the run this leg should have written:
     run report written by this leg: Library/Application Support/Shadowrun/last_run_report.json
      reason=atexit host frames=60 at 2026-11-10T06:25:23Z
      drivers: video=cocoa audio=coreaudio
     what macOS's own agents logged in the window this leg covers -- from 2026-11-10 07:25:21,
     when it started, to now, a few seconds after it ended, unedited (syspolicyd
     is Gatekeeper's decision-maker, CoreServicesUIAgent draws the sheet):
      2026-11-10 07:25:22.286 Df CoreServicesUIAgent[73816:f59e04] [com.apple.xpc:connection] [0xb3e1ecc00] activating connection: mach=false listener=false peer=true name=com.apple.coreservices.quarantine-resolver.peer[77738].0xb3e1ecc00
      2026-11-10 07:25:22.339 Df CoreServicesUIAgent[73816:f59e04] [com.apple.processmanager:front-35286506] LAUNCH: 0x0-0x79b79b org.retroportingtoolkit.shadowrun starting stopped process.
      2026-11-10 07:25:22.412 Df syspolicyd[231:f5af5c] [com.apple.xpc:connection] [0x9ca616d00] activating connection: mach=false listener=false peer=false name=com.apple.XProtectBridgeService
      2026-11-10 07:25:22.426 Df syspolicyd[231:f5af5c] [com.apple.xprotect:xprotect] Forwarding detection succeeded!
      2026-11-10 07:25:22.474 Df syspolicyd[231:f5af5c] [com.apple.xpc:connection] [0x9ca616d00] activating connection: mach=false listener=false peer=false name=com.apple.XProtectBridgeService
      2026-11-10 07:25:22.481 Df syspolicyd[231:f5af5c] [com.apple.xprotect:xprotect] Forwarding detection succeeded!
        [log show exit=0: 71 line(s) from those two processes, 6 matched retroportingtoolkit|shadow|quarantin|gatekeep|xprotect|System Policy|damag|denied, and 0 of those contain the substring 'damag']

== 4.shareable: the flag put back on, and the double-click that gets refused ==

  the flag a browser leaves on a download, set by hand here because nothing
  downloaded this file -- the .dmg this machine built carries no flag at all, so
  the flag has to be put on deliberately for the refusal to be measurable.
  flag now on the copy: 0081;6af2b8d7;Chrome;
    Gatekeeper's assessment with the flag on:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: rejected
      [exit=3]
    (rejected is expected and is not this probe's finding: it is the ad hoc,
     unnotarised signature.  What is being looked for is the sentence a person
     is shown when they open it, which an assessment does not produce.)
    the seal, with that same flag on the bundle:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
    the seal still validates with the flag on, so this copy is not broken in
    the sense 'damaged' means -- which is the half the payload fix controls.
  'open' is the path a double-click takes: LaunchServices, working directory
  '/', no terminal, and the app's own drivers rather than dummy ones.  its legs pass --rom, and the payload has no image in it at all.
     nothing of Shadowrun is running yet, so any process below is this leg's
     the leg's process was pid 77849, running from:
       /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/AppTranslocation/2BAC3B75-A803-47BA-8609-C04F1F4096D9/d/Shadowrun.app/Contents/MacOS/Shadowrun
     this leg took 3s of wall clock
     that path is not where this probe put the copy: macOS applies App Path
     Randomisation (App Translocation) to a bundle that carries the download
     flag, and runs it from a randomised read-only path instead.  So the
     process is not the copy on disk, and asking whether that copy changed
     says nothing about it -- which is why the copy's own payload digest and
     tree hash are re-read in section 5.shareable rather than inferred here.
     'open' exit=0
     (the 'open' command printed nothing on stdout or stderr)
     reading the state directories for a run report this leg may have written:
     run report written by this leg: Library/Application Support/Shadowrun/last_run_report.json
      reason=atexit host frames=60 at 2026-11-10T06:25:28Z
      drivers: video=cocoa audio=coreaudio
     what macOS's own agents logged in the window this leg covers -- from 2026-11-10 07:25:26,
     when it started, to now, a few seconds after it ended, unedited (syspolicyd
     is Gatekeeper's decision-maker, CoreServicesUIAgent draws the sheet):
      2026-11-10 07:25:27.466 Df CoreServicesUIAgent[73816:f5b03d] [com.apple.xpc:connection] [0xb3e1ecc00] activating connection: mach=false listener=false peer=true name=com.apple.coreservices.quarantine-resolver.peer[77840].0xb3e1ecc00
      2026-11-10 07:25:27.508 Df CoreServicesUIAgent[73816:f5b03d] [com.apple.xpc:connection] [0xb3f0aaa80] activating connection: mach=true listener=false peer=false name=com.apple.coreservices.quarantine-resolver
      2026-11-10 07:25:27.508 Df CoreServicesUIAgent[73816:f59e04] [com.apple.xpc:connection] [0xb3e1ec600] activating connection: mach=false listener=false peer=true name=com.apple.coreservices.quarantine-resolver.peer[73816].0xb3e1ec600
      2026-11-10 07:25:27.508 Df CoreServicesUIAgent[73816:f5b1cc] [com.apple.launchservices:uiagent] GKQuarantineResolver initWithProperties: <private>
      2026-11-10 07:25:27.509 Df CoreServicesUIAgent[73816:f56a7b] [com.apple.xpc:connection] [0xb3f0abac0] activating connection: mach=false listener=false peer=false name=com.apple.XprotectFramework.AnalysisService
      2026-11-10 07:25:27.511 Df CoreServicesUIAgent[73816:f5b1cc] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareCheckEnded:result:forURL:]: XProtect defer executable analysis: true
      2026-11-10 07:25:27.511 Df CoreServicesUIAgent[73816:f56a7b] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareChecksFinished]_block_invoke: XProtect suppress first launch warning: true
        [log show exit=0: 35 line(s) from those two processes, 7 matched retroportingtoolkit|shadow|quarantin|gatekeep|xprotect|System Policy|damag|denied, and 0 of those contain the substring 'damag']

== 5.shareable: the copy that just ran, asked whether it is still the bytes that shipped ==

  payload after the open legs  37d08a86a2a86414
  bundle before the legs       11 entries, tree hash 61cd989abe7b934d
  bundle after the legs        11 entries, tree hash 61cd989abe7b934d
    unchanged: the app wrote nothing inside itself, through two open attempts,
    a real window, a scripted boot and a save.  That is the property the
    'is damaged' report says a copy of this port used to fail.
    its seal, asked after the run:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/shareable/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
    the directory holding the executable, after all of that -- every file in it
    other than the binary itself, which is where the pre-fix host wrote config.ini,
    keybinds.ini, rom.cfg and saves/ while running from inside a bundle:
    (expect nothing above: only the executable, which is why the whole-bundle
     seal is possible at all)

== 1.personal: copying Shadowrun-personal.app out of the image the way a drag does ==

  mounted read-only at /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/mnt-personal
      "disk6" ejected.
  ditto is the copy a drag-and-drop performs, xattrs and all, so the copy under
  test here is what a person gets rather than what this machine staged.
  copy under test            44a3da74ddca0062   7004144 B
  bundle before any of it    11 entries, tree hash fd40cfe3f6adccc1
    (the listing is a find over the directory holding the .app, which is the
     listing the packaging log takes over its own staging copy, so the entry
     counts are the same kind of figure -- 11 there as well -- while the hashes
     are digests over different absolute paths and are not expected to match.
     The payload digest above is what ties this copy to the one that shipped.)
  its seal before anything has been done to it:
    codesign --verify --strict --verbose=2
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: satisfies its Designated Requirement
      [exit=0]

== 2.personal: before any open, can this machine exec these bytes at all? ==

  one question asked first, because a machine that cannot exec this code signature
  makes every leg below print a tidy-looking nothing while measuring nothing:
  is the exec of these bytes being held by macOS right now?
    started directly from a shell, dummy drivers, its own $HOME (/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/preflight_home),
    with the same /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/staged/shorter.txt every other leg runs:
     it ran and finished on its own: 28 line(s) of its own output,
     and its run report is /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/preflight_home/Library/Application Support/Shadowrun-personal/last_run_report.json
     (no --rom on this line: the personal payload carries its image)
    exec is not held, so the legs that have to run the app can tell the difference
    between running, being refused, and being held.

== 3.personal: the copy with the download flag cleared, and the double-click after it ==

  this leg runs before the refusal leg on purpose.  A refused launch can leave a
  process held at exec while macOS waits for a sheet nobody in this run answers, and
  on this machine a path that had held one was measured still refusing to exec
  afterwards -- see section 2.personal above and the end of section 7.  The claim
  that has to be measured here, that the copy a person ends up with after
  right-click -> Open starts, is therefore taken first, while the path is known to
  be able to run it.
  macOS's own wording for an unverified download is right-click the app, choose
  Open, then Open again in the sheet.  What that does to the files on disk is
  remove the quarantine flag, and the command the README at the image root tells
  a person to type does the same thing, so it is done here rather than guessed.
    attached data on the copy (expect nothing):
    Gatekeeper's assessment of the copy with no flag on it:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: rejected
      [exit=3]
    rejected is expected here too: an ad hoc, unnotarised signature never passes an
    assessment.  So the assessment is not what makes the app start for a person --
    their explicit choice, remembered by LaunchServices, is.  Which means the
    double-click below is the measurement, and this line is not.
     nothing of Shadowrun-personal is running yet, so any process below is this leg's
     the leg's process was pid 78018, running from:
       /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal
     this leg took 4s of wall clock
     'open' exit=0
     (the 'open' command printed nothing on stdout or stderr)
     no --rom on this line and no rom.cfg in the bundle, so a report with
     frames in it means the click path booted the guest out of the executable.
     reading the state directories for the run this leg should have written:
     run report written by this leg: Library/Application Support/Shadowrun-personal/last_run_report.json
      reason=atexit host frames=60 at 2026-11-10T06:25:46Z
      drivers: video=cocoa audio=coreaudio
     an older report is already there: Library/Application Support/Shadowrun/last_run_report.json, mtime Nov 10 07:25:28 2026  (a state directory not named for this bundle)
     what macOS's own agents logged in the window this leg covers -- from 2026-11-10 07:25:43,
     when it started, to now, a few seconds after it ended, unedited (syspolicyd
     is Gatekeeper's decision-maker, CoreServicesUIAgent draws the sheet):
      2026-11-10 07:25:44.892 Df CoreServicesUIAgent[73816:f5b3f3] [com.apple.xpc:connection] [0xb3e1ecc00] activating connection: mach=false listener=false peer=true name=com.apple.coreservices.quarantine-resolver.peer[78009].0xb3e1ecc00
      2026-11-10 07:25:44.943 Df CoreServicesUIAgent[73816:f5b46e] [com.apple.processmanager:front-35286506] LAUNCH: 0x0-0x79f79f org.retroportingtoolkit.shadowrun.personal starting stopped process.
      2026-11-10 07:25:45.005 Df syspolicyd[231:f5b440] [com.apple.xpc:connection] [0x9ca616d00] activating connection: mach=false listener=false peer=false name=com.apple.XProtectBridgeService
      2026-11-10 07:25:45.020 Df syspolicyd[231:f5b440] [com.apple.xprotect:xprotect] Forwarding detection succeeded!
      2026-11-10 07:25:45.058 Df syspolicyd[231:f5b444] [com.apple.xpc:connection] [0x9ca616d00] activating connection: mach=false listener=false peer=false name=com.apple.XProtectBridgeService
      2026-11-10 07:25:45.068 Df syspolicyd[231:f5b444] [com.apple.xprotect:xprotect] Forwarding detection succeeded!
        [log show exit=0: 71 line(s) from those two processes, 6 matched retroportingtoolkit|shadow|quarantin|gatekeep|xprotect|System Policy|damag|denied, and 0 of those contain the substring 'damag']

== 4.personal: the flag put back on, and the double-click that gets refused ==

  the flag a browser leaves on a download, set by hand here because nothing
  downloaded this file -- the .dmg this machine built carries no flag at all, so
  the flag has to be put on deliberately for the refusal to be measurable.
  flag now on the copy: 0081;6af2b8ed;Chrome;
    Gatekeeper's assessment with the flag on:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: rejected
      [exit=3]
    (rejected is expected and is not this probe's finding: it is the ad hoc,
     unnotarised signature.  What is being looked for is the sentence a person
     is shown when they open it, which an assessment does not produce.)
    the seal, with that same flag on the bundle:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: satisfies its Designated Requirement
      [exit=0]
    the seal still validates with the flag on, so this copy is not broken in
    the sense 'damaged' means -- which is the half the payload fix controls.
  'open' is the path a double-click takes: LaunchServices, working directory
  '/', no terminal, and the app's own drivers rather than dummy ones.  its legs pass neither --rom nor a rom.cfg, because the guest is compiled into the payload.
     nothing of Shadowrun-personal is running yet, so any process below is this leg's
     the leg's process was pid 78125, running from:
       /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/AppTranslocation/C0B6E797-D0E2-4336-94BB-FA8797EB5C47/d/Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal
     this leg took 4s of wall clock
     that path is not where this probe put the copy: macOS applies App Path
     Randomisation (App Translocation) to a bundle that carries the download
     flag, and runs it from a randomised read-only path instead.  So the
     process is not the copy on disk, and asking whether that copy changed
     says nothing about it -- which is why the copy's own payload digest and
     tree hash are re-read in section 5.personal rather than inferred here.
     'open' exit=0
     (the 'open' command printed nothing on stdout or stderr)
     no --rom on this line and no rom.cfg in the bundle, so a report with
     frames in it means the click path booted the guest out of the executable.
     reading the state directories for a run report this leg may have written:
     run report written by this leg: Library/Application Support/Shadowrun-personal/last_run_report.json
      reason=atexit host frames=60 at 2026-11-10T06:25:51Z
      drivers: video=cocoa audio=coreaudio
     an older report is already there: Library/Application Support/Shadowrun/last_run_report.json, mtime Nov 10 07:25:28 2026  (a state directory not named for this bundle)
     what macOS's own agents logged in the window this leg covers -- from 2026-11-10 07:25:48,
     when it started, to now, a few seconds after it ended, unedited (syspolicyd
     is Gatekeeper's decision-maker, CoreServicesUIAgent draws the sheet):
      2026-11-10 07:25:49.981 Df CoreServicesUIAgent[73816:f5b3f3] [com.apple.xpc:connection] [0xb3e1ecc00] activating connection: mach=false listener=false peer=true name=com.apple.coreservices.quarantine-resolver.peer[78116].0xb3e1ecc00
      2026-11-10 07:25:50.042 Df CoreServicesUIAgent[73816:f5b3f3] [com.apple.xpc:connection] [0xb3f0abe80] activating connection: mach=true listener=false peer=false name=com.apple.coreservices.quarantine-resolver
      2026-11-10 07:25:50.042 Df CoreServicesUIAgent[73816:f5b62a] [com.apple.xpc:connection] [0xb3e1eca80] activating connection: mach=false listener=false peer=true name=com.apple.coreservices.quarantine-resolver.peer[73816].0xb3e1eca80
      2026-11-10 07:25:50.042 Df CoreServicesUIAgent[73816:f5b62a] [com.apple.launchservices:uiagent] GKQuarantineResolver initWithProperties: <private>
      2026-11-10 07:25:50.043 Df CoreServicesUIAgent[73816:f56a7b] [com.apple.xpc:connection] [0xb3f15c140] activating connection: mach=false listener=false peer=false name=com.apple.XprotectFramework.AnalysisService
      2026-11-10 07:25:50.044 Df CoreServicesUIAgent[73816:f5b46e] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareCheckEnded:result:forURL:]: XProtect defer executable analysis: true
      2026-11-10 07:25:50.044 Df CoreServicesUIAgent[73816:f56a7b] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareChecksFinished]_block_invoke: XProtect suppress first launch warning: true
        [log show exit=0: 39 line(s) from those two processes, 7 matched retroportingtoolkit|shadow|quarantin|gatekeep|xprotect|System Policy|damag|denied, and 0 of those contain the substring 'damag']

== 5.personal: the copy that just ran, asked whether it is still the bytes that shipped ==

  payload after the open legs  44a3da74ddca0062
  bundle before the legs       11 entries, tree hash fd40cfe3f6adccc1
  bundle after the legs        11 entries, tree hash fd40cfe3f6adccc1
    unchanged: the app wrote nothing inside itself, through two open attempts,
    a real window, a scripted boot and a save.  That is the property the
    'is damaged' report says a copy of this port used to fail.
    its seal, asked after the run:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/personal/Shadowrun-personal.app: satisfies its Designated Requirement
      [exit=0]
    the directory holding the executable, after all of that -- every file in it
    other than the binary itself, which is where the pre-fix host wrote config.ini,
    keybinds.ini, rom.cfg and saves/ while running from inside a bundle:
    (expect nothing above: only the executable, which is why the whole-bundle
     seal is possible at all)

== 6. the folder a named path sits in, when the copy is started by a click ==

  every leg above names files this probe staged in its own scratch directory, and that
  is a measurement rather than tidiness: an earlier pass of this probe caught a copy
  started by 'open' with no run report and no guest, sitting inside the open() of a ROM
  file that lives in this repository, and this repository sits under ~/Documents.  So
  the folder question is measured here, in the click path rather than from a shell, and
  the same bundle and the same bytes are used in each leg:
    a. the ROM path inside this repository, the script staged;
    b. the same ROM staged in this pass's own directory, the script staged;
    c. the ROM staged, the script inside this repository -- a script the app cannot read
       is a run that never receives its scripted quit, which looks like a hang.
  each leg is given a real window and audio driver, as the click path is, and is stopped
  after 30s whether or not it has finished.  Only leg a and leg c read this
  repository's own ROM file, and nothing here writes to it or to the script: the question
  is where a person's files sit, not what they contain.
  the personal package is not part of this section: its guest is inside the executable
  and no leg gives it a file path it would have to read.

  a fresh copy out of the shareable image, in a directory of this section's own:
    payload 37d08a86a2a86414  5953488 B  cdhash c8c8553aba8d7cfa26d89445d20aad08b6dc5d86
  asked whether that directory can exec it before any leg has stopped anything:
    run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun RAN   28 line(s) of its own output

  leg a: the ROM where this repository keeps it -- /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc
     nothing of Shadowrun is running yet, so any process below is this leg's
     no process of Shadowrun left after 30s: this open ended on its own
     'open' exit=0 because this script stopped the waiting command; what the app
     did is the run report, asked for below.
     run report newer than this leg: Library/Application Support/Shadowrun/last_run_report.json

  leg b: the same bytes of ROM, staged in this pass's own directory -- /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/staged/Shadowrun.sfc
     nothing of Shadowrun is running yet, so any process below is this leg's
     no process of Shadowrun left after 30s: this open ended on its own
     'open' exit=0 because this script stopped the waiting command; what the app
     did is the run report, asked for below.
     run report newer than this leg: Library/Application Support/Shadowrun/last_run_report.json

  leg c: the input script where this repository keeps it -- /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/scripts/shorter.txt
     nothing of Shadowrun is running yet, so any process below is this leg's
     no process of Shadowrun left after 30s: this open ended on its own
     'open' exit=0 because this script stopped the waiting command; what the app
     did is the run report, asked for below.
     run report newer than this leg: Library/Application Support/Shadowrun/last_run_report.json

  the three answers, in one place: still there at 30s / run report newer
  than the leg.  A leg that finished on its own and left a report is a run; a leg still
  sitting there with no report is a process waiting on something.
    a. ROM in this repository          still there=0  run report=1
    b. same ROM, staged outside        still there=0  run report=1
    c. script in this repository       still there=0  run report=1
  (1 = yes, 0 = no; the sampler's frames and the lsof lines above name what each
  still-standing process was waiting on, in macOS's own words)

  what macOS's own agents logged across these three legs, from just before the first
  one: tccd answers a request to read a protected folder, sandboxd enforces a
  container, and syspolicyd plus CoreServicesUIAgent are the Gatekeeper pair.  Their
  lines are printed here because the sampler says where the process is waiting, and
  only these processes can say why.
    before the excerpt, the counts: 1723 line(s) logged by those four processes in
    that window, 403 of them match retroportingtoolkit|shadow|documents|denied|prompt|container|sandbox|deny once connection chatter is
    filtered out, and 71 of those name a denial or a prompt.
    the first 40 of those 403, in time order:
    2026-11-10 07:26:08.363 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:open] _LSLaunchRB(org.retroportingtoolkit.shadowrun <private>, event=-, args=--no-launcher --rom /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc --script /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/staged/shorter.txt 0x8080000/newInstance  opts=LSOpen2Options(spawnNew skipWaitForCheckin )
    2026-11-10 07:26:08.363 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:open] LAUNCH: _LSLaunchThruRunningboard: org.retroportingtoolkit.shadowrun / <private>
    2026-11-10 07:26:08.365 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:open] LAUNCH: Set flag for disabling pointer auth for launching org.retroportingtoolkit.shadowrun <private>
    2026-11-10 07:26:08.365 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.runningboard:general] Sending launch request: <RBSLaunchRequest| app<application.org.retroportingtoolkit.shadowrun.13707992.13707998.1D9F1CF2-FC56-4429-A228-A5DF3E06ACD5(501)>; "LS launch org.retroportingtoolkit.shadowrun">
    2026-11-10 07:26:08.383 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:open] LAUNCH: Successful launched 0x0-0x7a37a3 pid=78269 org.retroportingtoolkit.shadowrun  '<private>'
    2026-11-10 07:26:08.383 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:cas] notifying server side, pid=78269 appInfo={ "ApplicationType"="Foreground", "CFBundleExecutablePath"="/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun", "CFBundleExecutablePathDeviceID"=16777233, "CFBundleExecutablePathINode"=13707998, "CFBundleIdentifier"="org.retroportingtoolkit.shadowrun", "CFBundleName"="Shadowrun", "CFBundlePackageType"="APPL", "LSASN"=ASN:0x0-0x7a37a3:, "LSAuditToken"=$F5010000F501000014000000F501000014000000BD310100A28601004ECAA600, "LSBundlePath"="/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app", "LSBundlePathDeviceID"=16777233, "LSBundlePathINode"=13707992, "LSDisplayName"="Shadowrun", "LSExecutableFormat"="LSExecutableMachOFormat", "LSFrontApplicationSeed"=1560, "LSLaunchDoNotBringFrontmost"=false, "LSLaunchEventRecordTime"=810957360003625, "LSLaunchTime"=now-ish 2026/11/10 07:26:08, "LSLaunchedByLaunchServices"=true, "LSLaunchedWithLaunchD"=true, "LSParentASN"=ASN:0x1-0x<…> launchModifiers=<decode: missing data> sessionID=<decode: missing data>
    2026-11-10 07:26:08.384 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:cas] LaunchedApplication: "/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun", psn=[ 0x0-0x7a37a3]
    2026-11-10 07:26:08.384 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:open] LAUNCH: Application 0x0-0x7a37a3 org.retroportingtoolkit.shadowrun launched with pid 78269, starting the application.
    2026-11-10 07:26:08.384 I  CoreServicesUIAgent[73816:f5b63e] [com.apple.launchservices:open] LAUNCH: Starting application with ASN 0x0-0x7a37a3 org.retroportingtoolkit.shadowrun because it was launched and still stopped.
    2026-11-10 07:26:08.384 Df CoreServicesUIAgent[73816:f5b63e] [com.apple.processmanager:front-35286506] LAUNCH: 0x0-0x7a37a3 org.retroportingtoolkit.shadowrun starting stopped process.
    2026-11-10 07:26:08.384 I  CoreServicesUIAgent[73816:f5b8b6] [com.apple.launchservices:open] LAUNCH: Completed async hint of application org.retroportingtoolkit.shadowrun to appleeventsd
    2026-11-10 07:26:08.396 A  sandboxd[29999:f5b8d0] request approval
    2026-11-10 07:26:08.396 A  sandboxd[29999:f5b8d0] (TCC) tcc_send_request_authorization() IPC
    2026-11-10 07:26:08.396 I  sandboxd[29999:f5b8d0] [com.apple.TCC:access] SEND: 0/7 synchronous to com.apple.tccd.system: request: msgID=29999.657, function=TCCAccessRequest, service=kTCCServiceSystemPolicyAllFiles,
    	TCCD_MSG_MESSAGE_OPTION_REQUEST_PROMPT_RIGHTS_MASK_KEY=5 (0x5)
    	TCCD_MSG_MESSAGE_OPTION_REQUEST_PROMPT_POLICY_KEY=2 (0x2)
    2026-11-10 07:26:08.397 I  tccd[161:f5b803] [com.apple.TCC:access] AttributionChain: accessing={TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, requesting={TCCDProcess: identifier=com.apple.sandboxd, pid=29999, auid=0, euid=0, binary_path=/usr/libexec/sandboxd},
    2026-11-10 07:26:08.397 I  tccd[161:f5b803] [com.apple.TCC:access] <TCCDProcess: identifier=com.apple.sandboxd, pid=29999> has the com.apple.private.tcc.manager.check-by-audit-token entitlement for service kTCCServiceAll (composed to parent: (null))
    2026-11-10 07:26:08.397 I  tccd[161:f5b803] [com.apple.TCC:access] AttributionChain: accessing={TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, requesting={TCCDProcess: identifier=com.apple.sandboxd, pid=29999, auid=0, euid=0, binary_path=/usr/libexec/sandboxd},
    2026-11-10 07:26:08.397 Df tccd[161:f5b803] [com.apple.TCC:access] AUTHREQ_ATTRIBUTION: msgID=29999.657, attribution={accessing={TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, requesting={TCCDProcess: identifier=com.apple.sandboxd, pid=29999, auid=0, euid=0, binary_path=/usr/libexec/sandboxd}, },
    2026-11-10 07:26:08.403 I  tccd[161:f5b803] [com.apple.TCC:access] BUNDLE_ATTRIBUTION: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun is main executable for candidateBundle(/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app).
    2026-11-10 07:26:08.403 I  tccd[161:f5b803] [com.apple.TCC:access] BUNDLE_ATTRIBUTION: executable path file:///private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun resolves to attributed bundle: file:///private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/
    2026-11-10 07:26:08.403 Df tccd[161:f5b803] [com.apple.TCC:access] AUTHREQ_SUBJECT: msgID=29999.657, subject=org.retroportingtoolkit.shadowrun,
    2026-11-10 07:26:08.403 I  tccd[161:f5b8d5] [com.apple.TCC:access] <TCCDProcess: identifier=com.apple.Terminal, pid=97730> has the com.apple.private.tcc.allow-prompting entitlement for service kTCCServiceAll (composed to parent: (null))
    2026-11-10 07:26:08.403 Df tccd[161:f5b8d5] [com.apple.TCC:access] responsible process has com.apple.private.tcc.allow-prompting entitlement
    2026-11-10 07:26:08.403 I  tccd[161:f5b8d5] [com.apple.TCC:access] -[TCCDPlatformMacOS promptingPolicyForIdentity:accessingService:withAttributionChain:]: promptPolicy = 2; isApplePlatformBinary = 1
    2026-11-10 07:26:08.403 I  tccd[161:f5b8d5] [com.apple.TCC:access] Handling access request to kTCCServiceListenEvent, from Sub:{com.apple.Terminal}Resp:{TCCDProcess: identifier=com.apple.Terminal, pid=97730, auid=501, euid=501, responsible_path=/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal, binary_path=/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal}, ReqResult(Auth Right: Unknown (None), promptType: 1,DB Action:None, UpdateVerifierData)
    	prompt_type=1 (0x1)
    2026-11-10 07:26:08.404 Df tccd[161:f5b803] [com.apple.TCC:access] -[TCCDAccessIdentity staticCode]: static code for: identifier org.retroportingtoolkit.shadowrun, type: 0: 0x752dac300 at /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] -[TCCDAccessIdentity matchesCodeRequirement:]: SecStaticCodeCheckValidity() static code (0x752dac300) from org.retroportingtoolkit.shadowrun : anchor apple; status: -67050
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] For org.retroportingtoolkit.shadowrun: matches platform requirements: No
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] -[TCCDPlatformMacOS promptingPolicyForIdentity:accessingService:withAttributionChain:]: promptPolicy = 0; isApplePlatformBinary = 0
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] -[TCCDAccessIdentity matchesCodeRequirement:]: SecStaticCodeCheckValidity() static code (0x752dac300) from org.retroportingtoolkit.shadowrun : anchor apple; status: -67050
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] For org.retroportingtoolkit.shadowrun: matches platform requirements: No
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] Background Session: service kTCCServiceSystemPolicyAllFiles from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}: determinedPlatformBinaryStatus: 1, clientIsApplePlatformBinary: 0, clientHasGraphicsAccess: 1, validRequester: 1
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] Handling access request to kTCCServiceSystemPolicyAllFiles, from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, ReqResult(Auth Right: Denied (Service Policy), promptType: 1,DB Action:None, UpdateVerifierData)
    	prompt_type=1 (0x1)
    2026-11-10 07:26:08.405 I  sandboxd[29999:f5b8d0] [com.apple.TCC:access] RECV: synchronous reply <dictionary: 0xbf103c000> { count = 5, transaction: 0, voucher = 0x0, contents =
    	"prompt_type" => <uint64: 0x983cd98f15993ec7>: 1
    2026-11-10 07:26:08.405 I  sandboxd[29999:f5b8d0] [com.apple.TCC:cache] Credential is not this process

  and the 6 of those 403 that name kTCCServiceSystemPolicyAllFiles, the
  service whose answer is a yes or no about reading a folder a person keeps files
  in.  Those lines are the system's own answer to the request the parked open() is
  waiting on, so they are printed here in full rather than as a count: the time-
  ordered excerpt above can stop before they come.
    2026-11-10 07:26:08.396 I  sandboxd[29999:f5b8d0] [com.apple.TCC:access] SEND: 0/7 synchronous to com.apple.tccd.system: request: msgID=29999.657, function=TCCAccessRequest, service=kTCCServiceSystemPolicyAllFiles,
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] Background Session: service kTCCServiceSystemPolicyAllFiles from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}: determinedPlatformBinaryStatus: 1, clientIsApplePlatformBinary: 0, clientHasGraphicsAccess: 1, validRequester: 1
    2026-11-10 07:26:08.405 I  tccd[161:f5b803] [com.apple.TCC:access] Handling access request to kTCCServiceSystemPolicyAllFiles, from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78269, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, ReqResult(Auth Right: Denied (Service Policy), promptType: 1,DB Action:None, UpdateVerifierData)
    2026-11-10 07:27:10.854 I  sandboxd[29999:f5bdc1] [com.apple.TCC:access] SEND: 0/7 synchronous to com.apple.tccd.system: request: msgID=29999.659, function=TCCAccessRequest, service=kTCCServiceSystemPolicyAllFiles,
    2026-11-10 07:27:10.864 I  tccd[161:f5b8dc] [com.apple.TCC:access] Background Session: service kTCCServiceSystemPolicyAllFiles from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78329, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}: determinedPlatformBinaryStatus: 1, clientIsApplePlatformBinary: 0, clientHasGraphicsAccess: 1, validRequester: 1
    2026-11-10 07:27:10.864 I  tccd[161:f5b8dc] [com.apple.TCC:access] Handling access request to kTCCServiceSystemPolicyAllFiles, from Sub:{org.retroportingtoolkit.shadowrun}Resp:{TCCDProcess: identifier=org.retroportingtoolkit.shadowrun, pid=78329, auid=501, euid=501, binary_path=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sropen/run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun}, ReqResult(Auth Right: Denied (Service Policy), promptType: 1,DB Action:None, UpdateVerifierData)

  and the leftover check for this section: 0 process(es) of
  Shadowrun still alive now these three legs are over.

== 7. where the state the legs produced actually went, and the real home checked ==

  what the private $HOME now holds -- this is the state the opened apps created,
  in exactly the shape a person would find it in, and the listing is the evidence
  that the run left config.ini, keybinds.ini, rom.cfg, saves/ and the mod catalog
  outside the .app rather than inside it.
  ./Library
  ./Library/Application Support
  ./Library/Application Support/Shadowrun
  ./Library/Application Support/Shadowrun-personal
  ./Library/Application Support/Shadowrun-personal/config.ini
  ./Library/Application Support/Shadowrun-personal/keybinds.ini
  ./Library/Application Support/Shadowrun-personal/last_run_report.json
  ./Library/Application Support/Shadowrun-personal/mods
  ./Library/Application Support/Shadowrun-personal/mods/preloaded
  ./Library/Application Support/Shadowrun-personal/mods/preloaded/packages
  ./Library/Application Support/Shadowrun-personal/mods/preloaded/state.toml
  ./Library/Application Support/Shadowrun-personal/saves
  ./Library/Application Support/Shadowrun-personal/saves/save.srm
  ./Library/Application Support/Shadowrun-personal/saves/save.srm.bak
  ./Library/Application Support/Shadowrun/config.ini
  ./Library/Application Support/Shadowrun/keybinds.ini
  ./Library/Application Support/Shadowrun/last_run_report.json
  ./Library/Application Support/Shadowrun/mods
  ./Library/Application Support/Shadowrun/mods/preloaded
  ./Library/Application Support/Shadowrun/mods/preloaded/packages
  ./Library/Application Support/Shadowrun/mods/preloaded/state.toml
  ./Library/Application Support/Shadowrun/rom.cfg
  ./Library/Application Support/Shadowrun/saves
  ./Library/Application Support/Shadowrun/saves/save.srm
  ./Library/Application Support/Shadowrun/saves/save.srm.bak
  the state directory name the app chose is printed above rather than assumed here.

  and the check that the relay held: this machine's own ~/Library/Application
  Support/, fingerprinted before the legs and again now.  A new directory, a
  different file count, or a different fingerprint inside a directory that was
  already here, would all mean the legs wrote into this person's state after all.
    before:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    after:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    identical, which is the condition: the legs wrote inside the private $HOME
    above and a person running this probe loses nothing.
  removing a directory here costs an app its settings, saves and cached ROM path --
  which is the point of it living outside the bundle rather than inside it.

  the last witness, and the one that speaks to the exact sentence this port exists
   to answer: when a process dies, macOS writes a report to
   ~/Library/Logs/DiagnosticReports/ named for the executable, and the listing
   below is every report that directory holds whose name matches either bundle.
   How far back that listing reaches is printed rather than assumed:
    9 report(s) in that directory, oldest by name: continuation-2026-11-05-122414.ips
   A copy macOS calls 'damaged' never reaches that directory, because the refusal
   happens in LaunchServices before any process exists; so an empty listing for
   these two executables is the shape of 'nothing of mine crashed', and a
   non-empty one is a crash to read.
    none.  No report in that directory, including ones this machine wrote long
    before this run, names Shadowrun or Shadowrun-personal -- so no process from
    either package ever died and wrote one, and the legs above ran both packages to
    a scripted quit with their own window and audio driver.

  the last check on the machine itself: every process belonging to either bundle
   that is still alive now the legs are over.  A refused leg can leave one
   behind -- macOS translocates a quarantined bundle and holds the process at exec
   while its sheet waits -- and such a process is invisible to a leg that only
   looks for the path it opened, so each leg stops what it left and this is the
   check that nothing slipped through: a live app left here is the test using the
   person's screen as its scratch space.
    Shadowrun: none
    Shadowrun-personal: none

  one last witness, and it is about this pass rather than about the payload.  The
  refusal leg stops a process macOS was holding at exec, and that act is measured --
  in tests/macos_exec_hold_probe.sh -- to leave the bundle's own directory unable to
  exec at that path, for as long as watching lasted and for every file inside that
  directory, while the same machine code at any other path runs normally.  So the
  directories this pass used are asked whether they can still run their app, and if
  they cannot, the measured way out is applied: renaming the directory, and then the
  same question asked after the rename and after putting it back.  A person should not
  be left with a directory whose app will not start because a test stopped something.
    shareable:
    run-20261110-072509/shareable/Shadowrun.app/Contents/MacOS/Shadowrun RAN   28 line(s) of its own output
    personal:
    run-20261110-072509/personal/Shadowrun-personal.app/Contents/MacOS/Shadowrun-personal RAN   27 line(s) of its own output
    folder:
    run-20261110-072509/folder/Shadowrun.app/Contents/MacOS/Shadowrun RAN   28 line(s) of its own output
    none of the 3 paths asked about is held: the stops this pass made left
    nothing behind, so the next pass of this probe, or a person dragging these copies
    somewhere else, is not walking into a path that cannot exec.

== 8. the three questions, per package ==


  shareable (Shadowrun), flag on: the app came up as pid 77849 ('open' exit 0).  After the override: the app came up as pid 77747 ('open' exit 0).  Through both, the copy kept the same entries and the same tree hash, and its seal afterwards exits 0.  The word 'damag' in macOS's own lines for the two legs: 0 and 0.
  personal (Shadowrun-personal), flag on: the app came up as pid 78125 ('open' exit 0).  After the override: the app came up as pid 78018 ('open' exit 0).  Through both, the copy kept the same entries and the same tree hash, and its seal afterwards exits 0.  The word 'damag' in macOS's own lines for the two legs: 0 and 0.

  nothing unexpected: every copy under test sealed before and after being opened,
  and no copy gained a file inside itself while it ran.  Gatekeeper's refusal of an
  ad hoc signature is the one refusal this machine cannot make go away, and it is
  measured rather than argued about.

  what this probe counts as unexpected, and what it therefore returns: 0
  finding(s), and the exit status of this script is that number.  Read that as the
  summary of the sections above rather than as a verdict on its own: a 0 here means
  the things that matter held -- after the override each package came up, each copy
  kept the entries and tree hash it started with, each still sealed, no system line
  used the word 'damaged', no crash report exists for either executable, no process
  of either bundle is left running, and this machine's own state directory is byte
  for byte what it was before.

== DONE  (log: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/openprobe/user_open_probe.log, exit status 0) ==
