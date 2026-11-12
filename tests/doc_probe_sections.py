#!/usr/bin/env python3
"""Assemble README sections 7.26 and 7.27 so that every transcript block in them is
copied verbatim out of the two probe artifacts rather than retyped.

Every fence is an anchor span over the committed artifact: this script never writes a
transcript line by hand, so a fence cannot drift from its witness.  An anchor that
matches more than one line has to be given an occurrence index, so a span cannot
silently take another section's lines.

    python3 tests/doc_probe_sections.py   # rewrites 7.26 and 7.27 in tests/README.md

The prose around the fences lives in the SEC block below, which is this script's own
text; only the transcript blocks are assembled from the artifacts.  A span whose anchors
no longer match is an error rather than a silent omission, so an artifact that moves
fails here before it can leave a stale fence in the document.  Re-running it against a
README it already wrote is a byte-for-byte no-op, which is how the fences are checked:
run it, and `git diff --stat tests/README.md` has to say the same thing the run says.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
O = (ROOT / "evidence/artifacts/macos_user_open.md").read_text().splitlines()
H = (ROOT / "evidence/artifacts/macos_exec_hold.md").read_text().splitlines()

SPANS = []


def span(lines, start, end, name, nth=None, nth_end=0, back=0):
    """lines[i:j+1]: i is the nth line containing `start` (an anchor with more than
    one match must say which), j is the nth_end-th line at or after i containing
    `end`, moved back `back` lines."""
    hits = [i for i, l in enumerate(lines) if start in l]
    if not hits:
        sys.exit("anchor %r matched nothing" % start)
    if nth is None:
        if len(hits) != 1:
            sys.exit("anchor %r matches %d lines; give it an occurrence index"
                     % (start, len(hits)))
        nth = 0
    elif nth >= len(hits):
        sys.exit("anchor %r matched %d times, wanted occurrence %d"
                 % (start, len(hits), nth))
    i = hits[nth]
    ends = [j for j in range(i, len(lines)) if end in lines[j]]
    if len(ends) <= nth_end:
        sys.exit("end anchor %r found %d times after %r" % (end, len(ends), start))
    j = ends[nth_end] - back
    if j < i:
        sys.exit("span %r ends before it starts" % name)
    SPANS.append((name, i + 1, j + 1))
    return "\n".join(lines[i:j + 1])


def fence(block):
    return "```text\n" + block + "\n```"


F = {}

# ------------------------------------------------------------ 7.26 fences
F["FENCE_O_COST"] = span(O, "two costs of doing this for real",
                         "rather than another dummy-driver re-run.", "cost")
F["FENCE_O_WAITS"] = span(O, "three waits rather than one",
                          "stopped by signal and recorded as hung.", "waits")
F["FENCE_O_EXEC"] = span(O, "one question asked first",
                         "between running, being refused, and being held.", "exec", nth=0)
F["FENCE_O_ORDER"] = span(O, "this leg runs before the refusal leg on purpose",
                          "be able to run it.", "leg order", nth=0)
F["FENCE_O_FLAGOFF"] = span(O, "Gatekeeper's assessment of the copy with no flag on it:",
                            "double-click below is the measurement, and this line is not.",
                            "assessment, no flag", nth=0)
F["FENCE_O_LEGA"] = span(O, "the leg's process was pid ",
                         "drivers: video=cocoa audio=coreaudio", "open, flag off", nth=0)
F["FENCE_O_FLAGON"] = span(O, "the leg's process was pid ",
                           "rather than inferred here.", "open, flag on", nth=1)
F["FENCE_O_DAMAG"] = span(O, "[log show exit=0: ",
                          "and 0 of those contain the substring 'damag']", "damag count",
                          nth=0)
F["FENCE_O_AFTER"] = span(O, "payload after the open legs  37d08a86a2a86414",
                          "seal is possible at all)", "what the copy still is")
F["FENCE_O_FOLDER"] = span(O, "every leg above names files this probe staged",
                           "RAN   28 line(s) of its own output", "folder legs")
F["FENCE_O_VERDICT"] = span(O, "the three answers, in one place",
                            "still-standing process was waiting on, in macOS's own words)",
                            "folder verdict")
F["FENCE_O_COUNTS"] = span(O, "before the excerpt, the counts", "name a denial or a prompt.",
                           "tccd counts")
F["FENCE_O_ALLFILES"] = span(O, "that name kTCCServiceSystemPolicyAllFiles, the",
                             "and the leftover check for this section: 0 process(es) of",
                             "AllFiles lines", back=2)
F["FENCE_O_HOME"] = span(O, "and the check that the relay held",
                         "a person running this probe loses nothing.", "state home")
F["FENCE_O_CRASH"] = span(O, "report(s) in that directory, oldest by name:",
                          "a scripted quit with their own window and audio driver.",
                          "crash reports")
F["FENCE_O_PATHS"] = span(O, "one last witness, and it is about this pass rather than about the payload",
                          "is not walking into a path that cannot exec.", "paths held")
F["FENCE_O_SUMMARY"] = span(O, "shareable (Shadowrun), flag on: the app came up as pid ",
                            "measured rather than argued about.", "summary")
F["FENCE_O_FINDINGS"] = span(O, "what this probe counts as unexpected, and what it therefore returns",
                             "for byte what it was before.", "findings")

# ------------------------------------------------------------ 7.27 fences
F["FENCE_H_END"] = span(H, "exit status of this script, printed here so the log itself carries it",
                        "anything else means one of the checks counted a finding.",
                        "exit status")
F["FENCE_H_COST"] = span(H, "this script deliberately puts directories of its own",
                         "after its prompt.", "cost")
F["FENCE_H_SHIPPED"] = span(H, "leg shipped: opening payload/Shadowrun.app",
                            "this leg leaves no condition to measure.", "click, shipped code")
F["FENCE_H_REPAIR"] = span(H, "the copy as it was copied out of the image:",
                           "  payload     ", "re-signing")
F["FENCE_H_HELD"] = span(H, "leg fresh: opening fresh/Shadowrun.app",
                         "as well as from the process table.", "click, new cdhash")
F["FENCE_H_SAMPLER"] = span(H, "the sampler's own lines for its thread",
                            "_dyld_start  (in dyld) + 0 ", "sampler",
                            nth=0)
F["FENCE_H_SYS"] = span(H, "what macOS's own agents logged for this leg",
                        "of those lines, 0 contain 'damag'", "syspolicyd", nth=1)
F["FENCE_H_WATCH"] = span(H, "watched rather than assumed: the same pid, asked nothing, for 120s.",
                          "not resolve on its own inside 120s.", "120s watch")
F["FENCE_H_PATHS4"] = span(H, "three more copies, each with its cdhash printed next to it",
                           "ejected.", "three other paths")
F["FENCE_H_PATHSVERDICT"] = span(H, "2 of these three paths carry exactly the held code",
                                 "(line c is marked different-code", "path verdict")
F["FENCE_H_ORDER"] = span(H, "each line is one thing a person or a script could do to the held path",
                          "printed at the end of this list for that reason.", "ordering")
F["FENCE_H_WIDTH"] = span(H, "first, the width: the same bundle, the same directory, a second file name inside it.",
                          "A held exec.", "second file name")
F["FENCE_H_KILL"] = span(H, "this user's own UI agent sent SIGKILL",
                         "4, the SIGKILL sent to this user's UI agent.", "UI agent")
F["FENCE_H_FRESHREPAIR"] = span(H, "the rename, on a hold of its own",
                                "  payload     ", "second hold made")
F["FENCE_H_FRESH2"] = span(H, "again-second: started Shadowrun from ",
                           "A held exec.", "second hold held")
F["FENCE_H_RENAME"] = span(H, "that path is held, and nothing but the click and the stop has touched it.",
                           "A held exec.", "rename", nth_end=1)
F["FENCE_H_COPYCTL"] = span(H, "and that same held bundle copied to a path of its own",
                            "A held exec.", "copy control", nth_end=1)
F["FENCE_H_RENAMEVERDICT"] = span(H, "the rename did not move this hold",
                                  "Which of those two its answer turns on is not measured here.",
                                  "rename verdict")
F["FENCE_H_CLEAN"] = span(H, "this section made /private/var/folders",
                          "stays standing on the machine", "copies removed")
F["FENCE_H_HOME"] = span(H, "this machine's own ~/Library/Application Support/, fingerprinted before the run",
                         "a person running this loses nothing.", "state home")
F["FENCE_H_CRASH"] = span(H, "crash reports: 9 in ~/Library/Logs/DiagnosticReports",
                          "a held exec and a crash are different complaints.", "crash reports")
F["FENCE_H_MARKS"] = span(H, "the shapes this run leaves on the page, one line each:",
                          "nothing unexpected.", "section 7 marks")

SEC = """### 7.26 Opening the shipped images the way a person opens them (2026-11-10)

§7.19 asks macOS's assessor about a built bundle and reads its exit code, and §7.23 proves the recipe
that builds it.  Neither of them *opens* the thing.  The complaint this packaging exists to answer is a
sentence a person reads on their own screen, and a sentence a person reads comes out of the open path,
not out of an assessor's status.  So `tests/macos_user_open_probe.sh` walks the whole user sequence
against both images in `dist/`: mount the `.dmg` read-only, copy the `.app` out with `ditto`, which is the
copy a drag-and-drop performs, ask whether this machine can exec those bytes at that path at all, open the
copy with the download flag cleared, put the flag back and open it again, and then ask whether the copy
that ran is still the bytes that shipped and still seals.

```sh
tests/macos_user_open_probe.sh
# log: tests/out/openprobe/user_open_probe.log
#      = evidence/artifacts/macos_user_open.md
```

The pass quoted here dates itself `2026-11-10T06:25:09Z`, runs every leg in a scratch directory of its
own, and prints its own finding count at the end of its log, which is also its exit status; that line is
the last fence below.

Two costs are stated in section 0 of its own log before any leg runs, because both of them change the
machine.  The legs go through LaunchServices, so their `$HOME` is whatever `open` relays, and they are
given a private one, and section 7 fingerprints this machine's real `~/Library/Application Support/`
before and after to show the relay held -- "A test has no business rewriting a person's saves."  The other
cost is a window on a person's screen, and the log's own words for that cost, and for the way every open
is read back, are:

FENCE_O_COST

The waits are three numbers rather than one, because each belongs to a different shape of leg, and the
shortest of them is itself a measurement: "'open -W' never returns when LaunchServices refuses the launch
-- measured, its own wait sits there forever", so a longer cap on a refused launch would buy the same
answer and leave Gatekeeper's sheet on the screen the whole time.

FENCE_O_WAITS

**The exec is asked about before any leg that has to run the app is believed (§2 of the log).**  A machine
that cannot exec this code signature makes every later leg print a tidy-looking nothing while measuring
nothing, so the probe first starts that copy directly from a shell, with dummy drivers and its own
`$HOME`:

FENCE_O_EXEC

That order is not caution for its own sake.  §7.27 measures that stopping a process macOS is holding at
exec leaves *that bundle's own directory* unable to exec at that path, and this probe says so at the head
of its own flag-cleared section:

FENCE_O_ORDER

**Flag cleared, then flag put back (§3 and §4).**  Clearing the download flag is what right-click → Open
leaves on disk, and it is the command the `README.txt` at the image root tells a person to type, so it is
done here rather than guessed; `spctl` still refuses either way, which the log explains rather than
leaves as a surprise:

FENCE_O_FLAGOFF

and the double-click brings the app up as pid 77747, at the path the probe put it, with a real window and
a real audio device, 3s of wall clock, and a run report that ends `reason=atexit` with 60 host frames:

FENCE_O_LEGA

With the flag put back on, the same `open` brings the same copy up again, and this time from a path this
probe never wrote:

FENCE_O_FLAGON

So the flag-on click of this pass was translocated and ran, and the log says so in its own summary --
"shareable (Shadowrun), flag on: the app came up as pid 77849 ('open' exit 0).  After the override: the
app came up as pid 77747 ('open' exit 0)." -- while keeping the two facts apart: an assessment refusal is
not an open refusal.  The word a person would have seen is counted in the system's own lines rather than
eyeballed, once per open leg, beside the number of lines that were looked at:

FENCE_O_DAMAG

That line is printed four times in this pass, always with the same tail: "and 0 of those contain the
substring 'damag'".

**The copy that ran, asked what it still is (§5).**

FENCE_O_AFTER

The personal package goes through the identical walk and gets the same answers: payload
`44a3da74ddca0062`, 11 entries and tree hash `fd40cfe3f6adccc1` before the legs and after them, a run
report at both opens, pids 78125 and 78018.

**Then the section this pass exists for: where a named path sits (§6).**  Every leg above names files
staged in the probe's own scratch directory, and the log is explicit that this is a measurement rather
than tidiness: "an earlier pass of this probe caught a copy started by 'open' with no run report and no
guest, sitting inside the open() of a ROM file that lives in this repository, and this repository sits
under ~/Documents."  The three paths, the three legs, and the pre-check on the fresh copy:

FENCE_O_FOLDER

FENCE_O_VERDICT

All three legs finished on their own inside the 30s cap and left a run report, so no process was still
standing and this pass has no sampler frames to place.  Leg a read the ROM where this repository keeps
it, leg b the same bytes staged outside it, and leg c the staged ROM with the script still inside the
repository; each is a run in the table above.

The sampler says where a standing process is waiting; only macOS's own agents can say why, so the log
dumps their window and prints its own counts first:

FENCE_O_COUNTS

and then the service that answers a request to read a folder a person keeps files in, as its own counted
block rather than hoped to fall inside the first 40 time-ordered lines.  That block prints every
`kTCCServiceSystemPolicyAllFiles` line in the window, six of them here, under the script's own reason for
printing them in full rather than as a count -- wording written for the earlier pass that had something
parked, since this one had nothing standing:

FENCE_O_ALLFILES

The request is named, the answer is `Denied (Service Policy)`, and the code identity behind it fails
`anchor apple` with `status: -67050` and `matches platform requirements: No`.  Those six lines are what
macOS's agents logged around this pass's folder reads; they are the system's record of the requests, not
evidence that a process waited on them, and the legs above nevertheless ran and finished.  That is the
whole of what this pass claims about the folder.

**What the pass left on the machine (§7).**  The private `$HOME` holds exactly the state an opened app
creates -- `config.ini`, `keybinds.ini`, `rom.cfg`, `saves/` and the mod catalog, under both bundle names
-- and that listing is the evidence that the run wrote outside the bundle.  This machine's own state
directory is fingerprinted before and after:

FENCE_O_HOME

Nine reports sit in `~/Library/Logs/DiagnosticReports`, and how far that listing reaches is printed
rather than assumed:

FENCE_O_CRASH

Then the check that only §7.27 makes worth having: the three directories this pass used are asked whether
they can still run their app, because the folder legs stopped processes.  This section offers renaming
the directory as the way out, and §7.27 is the section that measured a rename; this pass never needed it.

FENCE_O_PATHS

So "none of the 3 paths asked about is held", which is why that section leaves its scratch on disk for
reading rather than deleting it.  Section 8 closes the pass with the two opens per package, and then with
what it counted as unexpected:

FENCE_O_SUMMARY

FENCE_O_FINDINGS

### 7.27 macOS holding an exec instead of refusing it (2026-11-10)

The open-path probe above stops processes in a state neither it nor §7.19's assessment legs can see from
the outside.  On this machine a quarantined copy can be started and then *not allowed to run*, with
nothing on screen saying it is damaged: a process exists, mapped, and never runs, and the path it sat at
can stay that way after the script that made it has exited.  `tests/macos_exec_hold_probe.sh` makes that
condition on purpose, from the shipped image, in a scratch directory of its own per pass, and measures how
long it lasts, how wide it is, and what clears it.

```sh
tests/macos_exec_hold_probe.sh
# log: tests/out/exechold/exec_hold_probe.log
#      = evidence/artifacts/macos_exec_hold.md
```

The pass quoted here dates itself `2026-11-10T05:56:12Z` and prints its own verdict at the end of its log
rather than leaving it to a harness:

FENCE_H_END

It also states its own cost up front, because the cost falls on a person: this probe puts Gatekeeper's
sheet on this user's screen three times, "each up for 30s and no longer, because syspolicyd logs its
decision for a bundle about nine seconds after its prompt."

FENCE_H_COST

**§2 makes the condition twice, and its two legs differ in exactly one thing -- whose code macOS is being
asked about.**  The log states that difference before it acts on it.  The first leg, on the bytes that
shipped:

FENCE_H_SHIPPED

The second leg is those bytes re-signed ad hoc under a new bundle identifier, so its cdhash is one this
machine has never been asked about, which is the position a person is in the first time they open one of
these images.  The log prints the seal, the identifier, the cdhash, the payload digest and the payload
size on both sides of that re-signing, because its own comment says the word 're-signed' should not have
to be taken on trust:

FENCE_H_REPAIR

The two clicks answer differently, and the first one says so: "none -- this launch ended rather than
waited, so macOS refused it rather than holding it, and this leg leaves no condition to measure."  The
second one leaves a process standing:

FENCE_H_HELD

and macOS's own sampler, asked about that process, puts it at dyld's entry point and nowhere else:

FENCE_H_SAMPLER

"that is dyld's entry point, named in the sampler's own words: the process exists and has not been allowed
to start, and the only 2 file(s) mapped are the executable itself and the dynamic linker.  A held exec."
syspolicyd, which is Gatekeeper's decision-maker, says which kind of answer that click was:

FENCE_H_SYS

and the log counts its own headline word in the lines of all three clicks -- "of those lines, 0 contain
'damag'".  A held exec is not momentary either: §3 takes one such process, asks it nothing, and watches it
for two minutes.

FENCE_H_WATCH

"still the same process, still no output, still those same mappings: the hold did not resolve on its own
inside 120s."

That same mapping count is also why these two probes are separate scripts, and the hold log says why: "the
mapping count alone cannot keep those shapes apart: a copy started by a click and told to read a file
under ~/Documents was measured with the same two mapped files and its main thread inside open()."  So
every `held` in this artifact means the sampler named dyld's entry point, and a live process the sampler
cannot place there is printed as `-1` and "reported as neither held nor run" rather than counted as one of
the two.

**What the hold is not keyed to (§4).**  While the held path stays held, the payload is asked at three
other paths, each with its own cdhash printed beside it and compared against the held one rather than
assumed equal:

FENCE_H_PATHS4

FENCE_H_PATHSVERDICT

A hold at one path, for a cdhash that runs at two other paths, is not a verdict about those bytes.

**How wide the held place is, and what clears it (§5).**  A second file name inside the same bundle is
held too, at the same dyld entry point, so what is held is the bundle directory rather than one path
string:

FENCE_H_WIDTH

Then four things a user-level process can do are tried against that held path, in order, each followed by
the same direct probe there, and the log states why the order matters before it starts:

FENCE_H_ORDER

The four are `spctl` asked to assess the bundle again (still `rejected`, `[exit=3]`), `xattr -c -r`,
`lsregister -f`, and `killall -KILL` to this user's own CoreServicesUIAgent.  Only the last one is
followed by a path that runs, and the log prints the pid before and after so that 'restarted' is not a
guess:

FENCE_H_KILL

The fifth question -- does renaming the directory the bundle sits in move the hold -- is deliberately *not*
in that list, and the log says why: "an earlier pass of this script asked the rename about a path one of
these four had already cleared and read that as the rename's own answer."  The rename gets a hold of its
own instead, made by the same recipe in a fresh directory, with a third bundle identifier and cdhash, and
the log prints the re-signing that made them:

FENCE_H_FRESHREPAIR

and that new path is confirmed held by the sampler before anything at all is done to it:

FENCE_H_FRESH2

"that path is held, and nothing but the click and the stop has touched it."  Then the directory moves
aside, the app is asked there, the directory goes back, and the app is asked at the original path again:

FENCE_H_RENAME

and then the copy control, asked twice, because a copy tool that keeps extended attributes carries the
download flag across and this run measured that the flag plus a click is what makes the condition at all:
"So a copy that still carries it is a fresh Gatekeeper question rather than a control on these bytes", so
the copy is asked with the flag and then with the flag taken off:

FENCE_H_COPYCTL

and both questions are held.  The log's own answer for the rename, and for the difference between this
cdhash and the one §4 asked about at three paths that ran:

FENCE_H_RENAMEVERDICT

So nothing this script can reach from user level moved that hold, and the log refuses to guess why the two
cdhashes answered differently: "Which of those two its answer turns on is not measured here."

**Two housekeeping claims, because they are what makes the pass safe to run at all.**  The copies section
5 made are taken away by that same section, so a pass cannot leave a held bundle standing on the machine:

FENCE_H_CLEAN

and every direct start in the probe runs under a private `$HOME`, with the machine's own state directory
fingerprinted before and after:

FENCE_H_HOME

Nine crash reports were on this machine, and the log reads their emptiness as part of the finding:

FENCE_H_CRASH

and §7's own line for this section is a row of marks rather than a sentence:

FENCE_H_MARKS

What this is for is not a claim that the payload is broken.  It is the reason §7.26 is built the way it is:
its own scratch directory per pass, the leg that has to run the app taken first, and a check of the paths
it used at the end -- because a held exec is a thing that *stays* on the machine after the script that
made it has exited.

"""

for name, a, b in SPANS:
    print("%-18s lines %4d-%4d" % (name, a, b))

SEC = re.sub(r"\bFENCE_[A-Z0-9_]+\b", lambda m: fence(F[m.group(0)]), SEC)
if re.search(r"FENCE_", SEC):
    sys.exit("unresolved placeholder: %s" % re.findall(r"FENCE_\w+", SEC))

p = ROOT / "tests" / "README.md"
lines = p.read_text().splitlines(keepends=True)
start0 = next(i for i, l in enumerate(lines) if l.startswith("### 7.26 Opening"))
end0 = next(i for i, l in enumerate(lines) if l.startswith("## 8. Rebuilding"))
print("replacing tests/README.md lines %d-%d of %d" % (start0 + 1, end0, len(lines)))
p.write_text("".join(lines[:start0]) + SEC + "".join(lines[end0:]))
print("sections written:", len(SEC.splitlines()), "lines")
