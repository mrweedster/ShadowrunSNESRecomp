# macos_exec_hold.md
#
# what: what it means on this machine when macOS holds an app's exec open instead
#       of refusing it: what a held process looks like, how long the hold lasts,
#       what it is and is not keyed to, and what clears it and what does not.  The
#       condition is made on purpose,
#       from the shipped image, by clicking a quarantined copy twice: once as the
#       bytes that shipped, once as those same bytes re-signed under a new bundle
#       identifier, and both answers are printed.  All of it happens inside a
#       directory of this run's own.
# how:  tests/macos_exec_hold_probe.sh (HELD_WAIT=12 HOLD_PATIENCE=120 DENY_WAIT=30)
#
# inputs: dist/shadowrun-0.1.0-macos-arm64.dmg, built in the packaging round; its hash is printed in section 0.
#         the ROM and input script every start names are staged copies under
#         /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/staged, sha256 e6bc0a595d5c7c4b and 457b319c4a66fbb8, copied from
#         /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/Shadowrun (USA).sfc and /Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/scripts/shorter.txt; the reason is printed in section 2.
# scratch: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612 (earlier passes under /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold are removed at the start.  This one keeps
#          the copy it takes out of the image in /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/payload and the copy it re-signs
#          for section 2 in /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh; /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2 is where section 5 makes the hold it
#          measures the rename on, together with the moved name and the copy of it made
#          at a path of its own, and all three are removed at the end of section 5, so no
#          bundle this pass may have left held stays standing on this machine)
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad (framework_pins.txt), printed for cross-reference only
# generated: 2026-11-10T05:56:12Z (host Darwin 25.6.0 arm64, macOS 26.7.1 25G241)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

== 0. what this costs, and what it is not ==

  this script deliberately puts directories of its own on this machine into a state where
  their app cannot start, and then measures what clears that state and what does not,
  removing the copies it made in order to measure.  Both halves are printed
  rather than asserted, because the open-path probe's design rests on them: its
  refusal leg stops a process macOS is holding at exec, so that probe takes a scratch
  directory of its own per pass, takes the leg that has to run the app first, and
  checks the paths it used at the end.
  every start here is direct, with dummy drivers, so no window and no audio device
  opens, and each one gets a private $HOME (/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/home).  The one thing that cannot
  be done quietly is section 2: making the condition needs a quarantined bundle
  opened through LaunchServices, and that puts macOS's own sheet on this user's
  screen.  Section 2 clicks twice and section 5 clicks once more, on a copy of its own,
  so that is three sheets, each up for 30s and no longer, because syspolicyd
  logs its decision for a bundle about nine seconds after its prompt.
  shadowrun-0.1.0-macos-arm64.dmg                         2221175 B  sha256 fe2648738fad58a6

== 1. the payload, copied out of the image, asked to run where it was put ==

      "disk6" ejected.
  payload copied out           37d08a86a2a86414   5953488 B
    cdhash of the copy: c8c8553aba8d7cfa26d89445d20aad08b6dc5d86
    attached data on it: [] -- a build product carries
    no download flag, which is why section 2 puts one on deliberately.
    asked to run before anything has been stopped anywhere:
    clean: started Shadowrun from run-20261110-065612/payload/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 29 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0

== 2. the condition made on purpose: a download flag, a click, and what the click leaves ==

  the flag a browser leaves on a download, written here because nothing downloaded this
  file.  'open' is the double-click path, and a quarantined bundle is translocated by
  macOS, so the process that exists afterwards is not at the path that was opened --
  which is why each leg below reads the process table rather than the copy on disk.
  the ROM and the script these legs name are staged copies under /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/staged, not the
  repository's own files, which sit under ~/Documents: a copy started this way was
  measured sitting inside the open() of a file in that folder, and a leg waiting on a
  folder cannot be told apart from a leg macOS is holding at exec.
  two legs, and they differ in exactly one thing -- whose code macOS is being asked
  about:
    a. the copy taken out of the image, byte for byte the bytes that shipped, a cdhash
       this machine has already been shown by this repository's earlier rounds, and one
       section 1 just ran at this very path;
    b. a copy of those same bytes re-signed ad hoc under a new bundle identifier, so its
       cdhash is one this machine has never been asked about.  That is the position a
       person is in the first time they open one of these images.  The seal still
       validates and the signature is still ad hoc; the identifier and the cdhash are new,
       and the payload digest and size before and after that re-signing are printed below
       too, so 're-signed' is not something this run asks the reader to take on trust.
  nothing in this run claims the re-signed copy is what ships: it is the copy that lets
  the condition be made on purpose at all, and the lines say which code each answer is
  about.

  leg shipped: opening payload/Shadowrun.app
    identifier org.retroportingtoolkit.shadowrun, cdhash c8c8553aba8d7cfa26d89445d20aad08b6dc5d86
    flag now on the bundle: 0081;6af2b20a;Chrome;
    what 'open' said in those 30s:
        (nothing)
    processes of this bundle alive now:
        none -- this launch ended rather than waited, so macOS refused it rather than
        holding it, and this leg leaves no condition to measure.
        what macOS's own agents logged for this leg -- syspolicyd is Gatekeeper's
        decision-maker and CoreServicesUIAgent draws the sheet:
        2026-11-10 06:56:26.113 Df CoreServicesUIAgent[59804:f5591a] [com.apple.launchservices:uiagent] GKQuarantineResolver initWithProperties: <private>
        2026-11-10 06:56:26.115 Df CoreServicesUIAgent[59804:f5591a] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareCheckEnded:result:forURL:]: XProtect defer executable analysis: true
        2026-11-10 06:56:26.115 Df CoreServicesUIAgent[59804:f2a4bc] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareChecksFinished]_block_invoke: XProtect suppress first launch warning: true
        2026-11-10 06:56:26.206 Df syspolicyd[231:f5574a] [com.apple.xprotect:xprotect] Forwarding detection succeeded!
        2026-11-10 06:56:26.257 Df syspolicyd[231:f55963] [com.apple.xprotect:xprotect] Forwarding detection succeeded!
        of those lines, 0 contain 'damag'

  now the second copy: the same bytes, taken from the first one, with a new bundle
  identifier and a fresh ad hoc signature over them.
    the copy as it was copied out of the image:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: replacing existing signature
    the same copy after that re-signing:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
  identifier  org.retroportingtoolkit.shadowrun -> org.retroportingtoolkit.holdprobe1794290216
  cdhash      c8c8553aba8d7cfa26d89445d20aad08b6dc5d86 -> b159fec2ef53c0d77c7b59650e9abb048524c01f
  payload     37d08a86a2a86414 (5953488 B) -> 0376e0c30fb9ccec (5953488 B)

  leg fresh: opening fresh/Shadowrun.app
    identifier org.retroportingtoolkit.holdprobe1794290216, cdhash b159fec2ef53c0d77c7b59650e9abb048524c01f
    flag now on the bundle: 0081;6af2b228;Chrome;
    what 'open' said in those 30s:
        (nothing)
    processes of this bundle alive now:
        pid 73307 from:
          /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/AppTranslocation/4672ED85-0FE7-4B47-90ED-1B3A5424D977/d/Shadowrun.app/Contents/MacOS/Shadowrun
        2 mapped file(s),  0:00.01 of CPU
        after 31s of waiting.
        no run report newer than this open: nothing this launch started has reached
        the host's exit path, which is what a held exec looks like from the state
        side as well as from the process table.
        the sampler's own lines for its thread:
            877 Thread_16079907: Main Thread   DispatchQueue_<multiple>
              877 _dyld_start  (in dyld) + 0  [0x1022609c0]
        now stopped, because nothing in this script is going to answer the sheet,
        and what the path does after such a stop is what section 3 asks:
          pid 73307 killed by SIGKILL
        what macOS's own agents logged for this leg -- syspolicyd is Gatekeeper's
        decision-maker and CoreServicesUIAgent draws the sheet:
        2026-11-10 06:56:56.992 Df CoreServicesUIAgent[59804:f55bef] [com.apple.launchservices:uiagent] GKQuarantineResolver initWithProperties: <private>
        2026-11-10 06:56:56.994 Df CoreServicesUIAgent[59804:f55bef] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareCheckEnded:result:forURL:]: XProtect defer executable analysis: true
        2026-11-10 06:56:56.994 Df CoreServicesUIAgent[59804:f2a4bc] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareChecksFinished]_block_invoke: XProtect suppress first launch warning: true
        2026-11-10 06:56:57.109 E  syspolicyd[231:f55963] [com.apple.syspolicy.exec:default] Error Domain=GatekeeperPolicyScanError Code=-67018 "Code did not match any currently allowed policy" UserInfo={NSURL=<private>, NSLocalizedDescription=Code did not match any currently allowed policy}
        2026-11-10 06:56:57.282 Df syspolicyd[231:f55c29] [com.apple.syspolicy.exec:default] GK evaluateScanResult: 0, PST: (path: cbf44b80f5a3e7f6), (team: (null)), (id: org.retroportingtoolkit.holdprobe1794290216), (bundle_id: org.retroportingtoolkit.holdprobe1794290216), 1, 0, 1, 0, 0, 0, 0
        2026-11-10 06:56:57.283 Df syspolicyd[231:f55c29] [com.apple.syspolicy.exec:default] Prompt shown (6, 0), waiting for response: PST: (path: cbf44b80f5a3e7f6), (team: (null)), (id: org.retroportingtoolkit.holdprobe1794290216), (bundle_id: org.retroportingtoolkit.holdprobe1794290216)
        of those lines, 0 contain 'damag'

== 3. after those stops: both paths asked again, and the held one watched ==

  the same direct probe at each path section 2 used, before anything else is done to
  either copy.  What right-click -> Open does to a copy is take the flag off, so these
  are asked with no flag on them, which is the state a person who overrode Gatekeeper
  leaves their copy in; the attached data on each copy is printed first so the answer
  below can be read as 'a copy with no download flag, at this path'.
    attached data on the image copy now:  []
    attached data on the re-signed copy:  []
    again-shipped: started Shadowrun from run-20261110-065612/payload/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 28 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
    again-fresh: started Shadowrun from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73379 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           876 Thread_16080480: Main Thread   DispatchQueue_<multiple>
             876 _dyld_start  (in dyld) + 0  [0x1058049c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    the fresh copy is the one whose path is held, so that is the path the rest of this
    run measures.  Asked for once more with whatever it leaves left standing:
    watch-fresh: started Shadowrun from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73409 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           877 Thread_16080632: Main Thread   DispatchQueue_<multiple>
             877 _dyld_start  (in dyld) + 0  [0x1019d49c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    watched rather than assumed: the same pid, asked nothing, for 120s.
      20s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      40s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      60s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      80s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      100s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
      120s: pid 73409 alive, 2 mapped file(s),  0:00.00 CPU, 0 line(s) of output
    still the same process, still no output, still those same mappings: the hold did
    not resolve on its own inside 120s.  Stopped to keep watching.

== 4. the same code at other paths, so a hold here cannot be blamed on the code ==

  three more copies, each with its cdhash printed next to it, each asked the same
  question at a path this run has never stopped a process at.  The cdhashes are
  compared rather than assumed equal, and the image's own payload is called out when it
  is a different code from the held one.
  a) bare Mach-O at a path of its own        0376e0c30fb9ccec  cdhash b159fec2ef53c0d77c7b59650e9abb048524c01f  same-code
    bare-copy: started Shadowrun from run-20261110-065612/Shadowrun
       no process left: it ran and finished on its own, 29 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
  b) a fresh ditto of the whole bundle       0376e0c30fb9ccec  cdhash b159fec2ef53c0d77c7b59650e9abb048524c01f  same-code
    second-bundle: started Shadowrun from run-20261110-065612/copy2/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 28 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
  c) the payload inside the image itself     37d08a86a2a86414  cdhash c8c8553aba8d7cfa26d89445d20aad08b6dc5d86  different-code
    in-image: started Shadowrun from run-20261110-065612/mnt2/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 28 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
      "disk6" ejected.
    2 of these three paths carry exactly the held code, and all three of them ran
    while the path section 3 named stayed held.  So at this moment on this machine that
    cdhash was held at one path and let through at 2 others, and a third path -- a
    different code, as its own column says -- ran as well.  The hold at that one path is
    not an effect of those bytes.  What it is keyed to is what section 5 measures, and
    that section prints its answer whichever way it falls.
    (line c is marked different-code: the payload inside the image and the copy this run
    holds are not the same code, which is what the cdhash column prints rather than
    assumes, so the finding above rests on lines a and b: held=b159fec2ef53c0d77c7b59650e9abb048524c01f a=b159fec2ef53c0d77c7b59650e9abb048524c01f
    b=b159fec2ef53c0d77c7b59650e9abb048524c01f c=c8c8553aba8d7cfa26d89445d20aad08b6dc5d86)

== 5. how wide that directory is, and what clears it ==

  each line is one thing a person or a script could do to the held path, followed by the
  same direct probe there.  The order of these lines is part of what they mean: an
  intervention can only be credited with clearing a path if that path was still held when
  it was asked, so once one of them has made the path able to exec again, every probe
  after it on that same path is measuring a path that was already clear.  The first one
  after which the path ran is printed at the end of this list for that reason.
  the rename -- the directory that holds the bundle, not the bundle's own name -- is not
  in that list.  It is measured below, on a hold made for it by the same recipe, so that
  its answer belongs to it rather than to whichever of these four cleared this one.
  and the same measurement then copies that held bundle to a path of its own and asks
  that copy twice, once with the download flag it was copied with and once without it, so
  a hold that stays with the file through a rename can be told from a hold on those bytes
  at any path at all, and from a fresh Gatekeeper question made by the flag itself.
  held bundle for this section: /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app
  first, the width: the same bundle, the same directory, a second file name inside it.
  If the hold covers that too, it is the directory rather than the file.
    other-name: started Shadowrun2 from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun2
       pid 73609 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           878 Thread_16082480: Main Thread   DispatchQueue_<multiple>
             878 _dyld_start  (in dyld) + 0  [0x1037e49c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    (that copy was made by this section and removed again; the seal is re-asked at the
     end of this section)
    spctl, asked to assess this bundle again:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: rejected
      [exit=3]
    after-spctl: started Shadowrun from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73644 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           876 Thread_16082676: Main Thread   DispatchQueue_<multiple>
             876 _dyld_start  (in dyld) + 0  [0x101a109c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    every extended attribute cleared on the bundle:
      
      [exit=0]
    after-xattr: started Shadowrun from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73678 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           876 Thread_16082910: Main Thread   DispatchQueue_<multiple>
             876 _dyld_start  (in dyld) + 0  [0x101fd09c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    LaunchServices told this bundle changed:
      
      [exit=0]
    after-lsregister: started Shadowrun from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73712 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           879 Thread_16083091: Main Thread   DispatchQueue_<multiple>
             879 _dyld_start  (in dyld) + 0  [0x105cc09c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    this user's own UI agent sent SIGKILL -- the signal that ends a process rather than
    asking it to stop.  launchd relaunches it on demand; its root-owned decision-maker
    syspolicyd cannot be reached at all without a password, and this script does not
    ask for one.  The pid before and after says whether it actually restarted, and the
    label below says SIGTERM-to-SIGKILL rather than 'restart' for the reason this line
    prints: an earlier attempt here used killall with no signal, which sends SIGTERM, and
    the pid was simply still there afterwards, so that line measured nothing.
      before: 59804
        killall exit=0
        after:  (not running)
    after-uiagent: started Shadowrun from run-20261110-065612/fresh/Shadowrun.app/Contents/MacOS/Shadowrun
       no process left: it ran and finished on its own, 28 line(s) of
       its own output, first line: [host +0.000s] host_report: Shadowrun 0.1.0
    of these four, the first after which this path ran again was number 4:
    4, the SIGKILL sent to this user's UI agent.
    the lines before that one asked a path that was still held, and that number is the
    one thing in this list this machine measured clear.  The list ends there: the rename
    is measured below, on a hold nothing in this list has touched, because an earlier
    pass of this script asked the rename about a path one of these four had already
    cleared and read that as the rename's own answer.
    the bundle's seal, after all of that:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]

  the rename, on a hold of its own.  A second copy of the payload, a new bundle
  identifier, a fresh ad hoc signature over it, the download flag, one click, the stop:
  the same recipe section 2 used for its leg b, in a directory of this run's that
  nothing else has touched.  Then the directory holding the bundle is renamed aside,
  the app is asked to run from there, the directory is put back, and the app is asked
  to run at the original path again.
    the second copy, before the re-signing:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: replacing existing signature
    the second copy, after it:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
  identifier  org.retroportingtoolkit.shadowrun -> org.retroportingtoolkit.holdprobeb1794290524
  cdhash      c8c8553aba8d7cfa26d89445d20aad08b6dc5d86 -> 666a0c5239660495d6073848689721b371e8bbc0
  payload     37d08a86a2a86414 (5953488 B) -> b158c5eea5e2ca7e (5953488 B)

  leg second: opening fresh2/Shadowrun.app
    identifier org.retroportingtoolkit.holdprobeb1794290524, cdhash 666a0c5239660495d6073848689721b371e8bbc0
    flag now on the bundle: 0081;6af2b35c;Chrome;
    what 'open' said in those 30s:
        (nothing)
    processes of this bundle alive now:
        pid 73819 from:
          /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/AppTranslocation/DC5F6FF4-8C8C-4FE0-AFFB-7E7A7344DDCD/d/Shadowrun.app/Contents/MacOS/Shadowrun
        2 mapped file(s),  0:00.01 of CPU
        after 30s of waiting.
        no run report newer than this open: nothing this launch started has reached
        the host's exit path, which is what a held exec looks like from the state
        side as well as from the process table.
        the sampler's own lines for its thread:
            877 Thread_16083644: Main Thread   DispatchQueue_<multiple>
              877 _dyld_start  (in dyld) + 0  [0x105e409c0]
        now stopped, because nothing in this script is going to answer the sheet,
        and what the path does after such a stop is what section 3 asks:
          pid 73819 killed by SIGKILL
        what macOS's own agents logged for this leg -- syspolicyd is Gatekeeper's
        decision-maker and CoreServicesUIAgent draws the sheet:
        2026-11-10 07:02:04.369 Df CoreServicesUIAgent[73816:f56a92] [com.apple.launchservices:uiagent] GKQuarantineResolver initWithProperties: <private>
        2026-11-10 07:02:04.389 Df CoreServicesUIAgent[73816:f56a92] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareCheckEnded:result:forURL:]: XProtect defer executable analysis: true
        2026-11-10 07:02:04.389 Df CoreServicesUIAgent[73816:f56a7b] [com.apple.launchservices:uiagent] -[GKQuarantineResolver malwareChecksFinished]_block_invoke: XProtect suppress first launch warning: true
        2026-11-10 07:02:04.525 E  syspolicyd[231:f56a00] [com.apple.syspolicy.exec:default] Error Domain=GatekeeperPolicyScanError Code=-67018 "Code did not match any currently allowed policy" UserInfo={NSURL=<private>, NSLocalizedDescription=Code did not match any currently allowed policy}
        2026-11-10 07:02:04.696 Df syspolicyd[231:f56ac4] [com.apple.syspolicy.exec:default] GK evaluateScanResult: 0, PST: (path: 839c58190865d4f3), (team: (null)), (id: org.retroportingtoolkit.holdprobeb1794290524), (bundle_id: org.retroportingtoolkit.holdprobeb1794290524), 1, 0, 1, 0, 0, 0, 0
        2026-11-10 07:02:04.696 Df syspolicyd[231:f56ac4] [com.apple.syspolicy.exec:default] Prompt shown (6, 0), waiting for response: PST: (path: 839c58190865d4f3), (team: (null)), (id: org.retroportingtoolkit.holdprobeb1794290524), (bundle_id: org.retroportingtoolkit.holdprobeb1794290524)
        of those lines, 0 contain 'damag'
    again-second: started Shadowrun from run-20261110-065612/fresh2/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73867 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           877 Thread_16084113: Main Thread   DispatchQueue_<multiple>
             877 _dyld_start  (in dyld) + 0  [0x1024289c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    that path is held, and nothing but the click and the stop has touched it.  Now the
    directory that holds the bundle moves aside:
        /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2 -> /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2-moved
    rename-on-fresh-hold: started Shadowrun from run-20261110-065612/fresh2-moved/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73899 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           878 Thread_16084274: Main Thread   DispatchQueue_<multiple>
             878 _dyld_start  (in dyld) + 0  [0x1057809c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    and the directory put back the way it was, to ask whether the original path is
    held again:
        /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2-moved -> /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2
    back-at-fresh-path: started Shadowrun from run-20261110-065612/fresh2/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73930 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           880 Thread_16084423: Main Thread   DispatchQueue_<multiple>
             880 _dyld_start  (in dyld) + 0  [0x101cc09c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    and that same held bundle copied to a path of its own, so a hold that stayed with
    the file through a rename can be told from a hold on those bytes wherever they sit.
    That copy is asked twice, and the difference between the two questions is printed
    first: the download flag this section wrote on the original for its click is carried
    across by a copy tool that keeps extended attributes, and section 2 measured that
    flag plus a click is enough to make this condition at all.  So a copy that still
    carries it is a fresh Gatekeeper question rather than a control on these bytes, and
    it is asked as one and then asked again with the flag taken off it:
    attached data on the held bundle this copy was made from: [com.apple.quarantine: 0081;6af2b35c;Chrome; ]
    attached data on the copy as it stands:                   [com.apple.quarantine: 0081;6af2b35c;Chrome; ]
  copy at a new path  cdhash 666a0c5239660495d6073848689721b371e8bbc0  same-code-as-the-held-file
    copy-flag-on: started Shadowrun from run-20261110-065612/fresh3/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 73979 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           877 Thread_16084605: Main Thread   DispatchQueue_<multiple>
             877 _dyld_start  (in dyld) + 0  [0x10624c9c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    attached data on that same copy now the flag is off it:   []
    copy-flag-off: started Shadowrun from run-20261110-065612/fresh3/Shadowrun.app/Contents/MacOS/Shadowrun
       pid 74013 alive after 12s: 0 line(s) of output,
        0:00.00 of CPU, 2 mapped file(s)
       macOS's own sampler, asked about that same pid:
           879 Thread_16084770: Main Thread   DispatchQueue_<multiple>
             879 _dyld_start  (in dyld) + 0  [0x1042f49c0]
       that is dyld's entry point, named in the sampler's own words: the process
       exists and has not been allowed to start, and the only 2 file(s) mapped
       are the executable itself and the dynamic linker.  A held exec.
    the rename did not move this hold: the same bundle, the same cdhash, the same
    file, still held at the path its directory was moved to and still held at the
    original path once that directory was put back.  A directory rename is therefore
    not a remedy on this machine, and the hold does not follow the name of the path
    the bundle is asked at.  What it does follow is not measured here.
    and the copy says the same thing about this code from the other side: it was
    held at a path of its own as well, both with the download flag this run had
    written for its click and with that flag then taken off it.  So for this code
    nothing this script can reach from user level moved the hold -- not the path the
    bundle sat at, not the name that path was renamed to, not a copy of the whole
    bundle made at a path this run has never stopped a process at, and not the flag.
    One difference between this code and the code section 4 asked about at three
    paths that ran is worth naming rather than glossed: they are different cdhashes,
    printed in both places above, and between those two sets of answers sits the one
    thing this run did to macOS's own agent -- the SIGKILL that made the first path
    able to exec again.  Which of those two its answer turns on is not measured here.
    the second copy's seal, after all of that:
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: valid on disk
      /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2/Shadowrun.app: satisfies its Designated Requirement
      [exit=0]
    this section made /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2, /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2-moved and /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh3 only to be
    measured, and all three are removed here, so nothing this section may have left
    held stays standing on the machine.

== 6. what this run wrote, and the machine checked around it ==

  what the private $HOME holds, which is all the state the starts above were allowed
  to produce:
  ./Library
  ./Library/Application Support
  ./Library/Application Support/Shadowrun
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
  which state directory the host chose is printed above rather than assumed here.

  this machine's own ~/Library/Application Support/, fingerprinted before the run and
  now:
    before:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    after:
    6 file(s), fingerprint 32f3a7138b6c405e  Library/Application Support/Shadowrun
    identical: the private $HOME relay held, and a person running this loses nothing.

  crash reports: 9 in ~/Library/Logs/DiagnosticReports, oldest by name:
    continuation-2026-11-05-122414.ips
    none of them names Shadowrun or Shadowrun-personal.  That includes the processes
    stopped by SIGKILL above: a process macOS never let start writes no report, which
    is part of why a held exec and a crash are different complaints.

  every process of this bundle still alive now the sections are over:
    none.
  and this run's own scratch, so the next pass does not start inside a held path:
    /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612 is left on disk for reading; earlier passes under /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold were removed at the
    start of this one.  Its copy out of the image lives in /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/payload and the copy
    section 2 re-signs lives in /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh; /private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/srhold/run-20261110-065612/fresh2 is where section 5 made the hold
    it measured the rename on, and that one is gone again -- see below.
    run-20261110-065612/fresh2 is the directory the rename was measured in.  It, the copy
    made of it at a new path, and the moved name were removed at the end of section 5,
    so no copy of a bundle this section may have left held stays standing on the machine.

== 7. what this measured ==

  the shapes this run leaves on the page, one line each:
    * a held exec is a live process whose sampler call graph names dyld's entry point
      and nothing else; a refused launch is a process that ends.  tests/macos_user_open_
      probe.sh keeps them apart rather than reading both as 'no run report'.
    * the mapping count alone cannot keep those shapes apart: a copy started by a click
      and told to read a file under ~/Documents was measured with the same two mapped
      files and its main thread inside open().  So every 'held' above rests on the
      sampler naming dyld's entry point, and a live process it cannot place there is
      reported as neither held nor run.
    * which copy carries which cdhash is printed next to each click in section 2, and
      section 4 marks every other path it asks as the same code as the held one or a
      different one, rather than assuming it.
    * the payload execed at its path before the condition was made: 0 (0 = it
      ran).  The two clicks in section 2 left a process standing: shipped copy=0,
      re-signed copy=1 (1 = a process was there to stop, 0 = the launch ended).
      At the paths they used, after those stops: shipped=0,
      re-signed=1, and the path the rest of the run measured is the fresh
      copy: 1 (1 = held).
    * the other paths section 4 asked about: bare copy=0 second bundle=0 inside the image=0 (0 = ran, 1 = held, -1 = alive but not at dyld's entry point, and each one is marked same-code or different-code beside its cdhash).
    * second file name in the same bundle=1, spctl=1, xattr -c=1, lsregister=1, UI agent SIGKILL=0 (1 = still held, 0 = ran).  The first of those four after which this path ran again was number 4 (4, the SIGKILL sent to this user's UI agent); every line before that number was asked of a path that was still held when it was asked, and the list stops at that number.
    * the rename was measured on a hold of its own, in run-20261110-065612/fresh2: that hold formed=1 (1 = it did), the same bundle asked at the moved path=1 and at the original path again=1, and a copy of that held bundle made at a path of its own asked twice -- with the download flag it was copied with=1 and with that flag taken off=1 (1 = still held, 0 = ran, -1 = not asked or alive but not at dyld's entry point).  Those copies are removed at the end of section 5, so this pass leaves no copy of them standing.
    * the machine: state unchanged, no report naming either executable, no process of this bundle left, and the bundle the rename was measured on removed rather than left in a held directory.

  nothing unexpected.

  exit status of this script, printed here so the log itself carries it: 0 --
  0 means the sections above agree with each other and the machine is as it was
  found, anything else means one of the checks counted a finding.
