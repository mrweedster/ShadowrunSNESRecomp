# Measured evidence, kept out of `/tmp`

Copied out of the scratch directories used while validating the port, because
`/tmp` on macOS is purged. Everything here was produced by the runs described
in `tests/README.md`; nothing was hand-edited.

`framedump_json.tar.gz` — 4 × 1200 `frame_XXXXXX.json` files from `--framedump`
(the host's per-frame record: frame number, WRAM size, crc32 of all 128 KiB of
WRAM). Unpack with:

```sh
tar xzf framedump_json.tar.gz -C tests/out
```

| dir | what it is |
| --- | --- |
| `lle1`, `lle2` | two runs of the LLE/dynamic binary on the same input script |
| `aot1`, `aot2` | two runs of the statically recompiled (AOT) binary, same script |

Re-deriving the conclusions straight from these files:

```
lle1 vs lle2 : 1200 of 1200 frames identical      -> the run is deterministic
lle1 vs aot1 :  124 of 1200 frames identical,
               frame 0 = 0x84241060 both,
               frame 60 = 0x582ADF2C both         -> AOT matches LLE exactly
                                                       through the boot and the
                                                       first screen, then the
                                                       only diffs are the game's
                                                       own frame counters/timers
```

`shots_aot/` — the AOT binary's 256x224 BMPs at frames 300/600/900/1200. These
are md5-identical to the LLE binary's BMPs at the same frames, which is the
visual side of the same comparison.

## The A0–A4 investigation reports

The `.md` reports in this directory are the working notes behind the promotion
(`tests/README.md §7.1`), in order: `a1_coverage_report.md` (what the scripted
routes actually reach), `a2_aot_batch.md` (the first full AOT batch),
`a3_insn_deadline.md` (AOT interrupt responsiveness), `a4_bus_pace.md` (bus-exact
cycle charging, and why the cross-path gate was escalated to guest-aligned
parity), `sprite_limit.md` (the NoSpriteLimits A/B). They record dated
measurements; `tests/framedump_diff.py` re-derives the alignment tables from
fresh `--framedump` runs.

`c0_rom_free.md` is the same kind of record for one later claim: that the
executable can carry the guest image inside itself and play from an otherwise
empty folder (`tests/README.md §7.4`). It is the only file here that describes a
build which is **not** the shipped one.

`c1_staged_bundle_stale.md` records why that caveat is needed: the staged
`./Shadowrun` at the port root is a dated artefact that the current tree cannot
reproduce, measured against four build trees (`tests/README.md §7.5`).

`c1b_run_provenance.md` is the follow-up, the same failure seen from the other
side: a build tree (`./build`) holding objects for 4 of the 17 generated units
that were on disk. Neither was visible from the artefacts, so the kit now writes
a `run_manifest.json` next to every frame dump and the cross-path gate refuses to
judge legs against a baseline that names other inputs (`tests/README.md §7.6`).

`b0_read_trace.md` answers the question M1 turns on: which ROM bytes the running
game reads, who reads them, and how much of that traffic is instruction fetches
(`tests/README.md §7.7`). It is also the first record here written against a
framework branch that is **not** the pin — the ROM-read observer lives on
`snesrecomp` branch `feat/cart-read-trace`, and every claim is bound to the
executable that made it, so both framework inputs are visible: the pin for the
control leg, the branch for the observer legs. That binding is what caught the one
thing this round got wrong: its first control build was configured against a copy
of the framework that predated the pin.

`c1c_framework_copy.md` is that correction. A framework **copy** is not a control,
because a copy is only as current as the day it was copied, and `framework=unknown`
in a stamp does not say so — hashing that copy shows it predates the pin by 39
tracked source files, including a pin commit that changes the interpreted bridge the
neutrality leg measures. It records the control that does carry the claim
(`./build-pin`, a checkout at `773285b8`, same compilers as the observer leg), the
gate that now refuses the old one (`tests/provenance.py pin`, applied by both B0
scripts before they run), and the fact that the pinned generator reproduces this
port's `src/gen` byte for byte in under ten seconds.

`m1_hybrid_decision.md` is the decision that record was collected for: full AOT
versus hybrid, and how far a "ROM-free" claim may go. It comes out **hybrid with a
standing promotion loop**, because 65.8 % of the read traffic is instruction fetch
and the interpreted residue is now a named 13 KiB rather than an unknown — which
also inverts the earlier plan's premise that the reads would be mostly data. Its
first dependency is a symbols edit, not a toolchain: the loop runs through a
regeneration, and the analyzer it drives runs here as a stamp-verified prebuilt
binary — only rebuilding it from source is blocked, by network.

The M2 records are that loop running, one commit per round. `m2_promotion_round1.md`
seeds the 23 read-trace frontier blocks and closes the frontier: 26 blocks / 38.9 % of
reads becomes 3 blocks / 0.0 %, 8 new bodies, combat dispatch coverage 3.73 % → 3.94 % of
cycles; it is also the arbiter of the old f16122-vs-f16125 baseline dispute, which
resolves to f16125 / 26 B / 65 under every pinned program state.
`m2_lle_floor.md` records the control that round's claims needed: the old `build-lle` was
not a floor at all (it inherited the promoted bodies and measured 3.94 % AOT), because
LLE-ness lives in the generated set, not in a build switch — so
`tests/make_lle_floor.sh` splices `tests/forces/all_lle.txt` into `recomp/bank00.cfg`,
regenerates at the pin, builds, and proves 0.0 % AOT plus every wrapper the set declares
linked. A floor's generated set is archived as bytes (`artifacts/lle_floor_gen.tar.gz`)
because one `src/gen` is shared and the next regen would overwrite it.
`m2_promotion_round2.md` is the loop's first negative result: 20 seeds taken from round
1's refusal strings give 4 new AOT bodies and 45 instructions, and the round-2 binary
reproduces the round-1 binary byte for byte across the 25,902-frame route (both paths,
52,321 files each, `diff -rq` silent apart from `run_manifest.json`), horizon unchanged
at f16125. Two static seed sources are now exhausted, and 5 of those 20 seeds named
addresses the cart does not map at all. What is left is a runtime signal — the dispatch
ring's `found:0` entries, which the framework calls "the promotion worklist" and which
our production builds compile out.
`m2_promotion_round2b.md` closes both loose ends of that round. The 5 impossible seeds come
out of `recomp/symbols.toml` (45 `[[func]]` entries → 40), the regen takes exactly 5 nodes,
5 roots, 5 dispatch rows and 5 wrappers with it (`269 nodes / 47 roots / 252 rows`, AOT
bodies still 8,156 instructions), and both legs reproduce round 2's dumps byte for byte —
AOT frame bytes `574e66802bece79d…`, floor `f73f0014ad3618f3…`, same cycles — with `nm`
showing the 5 deleted symbols gone from both round-2b executables. Then the dispatch ring
gets built anyway (`./build-dht`, `tests/dispatch_worklist.py`,
`artifacts/dispatch_worklist_combat.json`) and answers **0 `found:0` in 574,973
dispatches**, which retires the runtime worklist as a seed source and decides round 2's
open question about *why* new bodies never run: the interpreter reaches those spans by
branch, so the dispatch table is never consulted there. All three seed sources are closed;
the remaining 96.06 % is not seed-addressable. That record also carries a harness finding
that every number above rests on, and its repair: the combat route's last ~2,900 frames
were a party dying in the alley prologue — a scripted kill scene, dead on both paths well
before the old corpus end — so the route now gates the alley on WRAM state and ends alive
at `A5`, the baseline is re-bound to the round-2b binaries at an unchanged f16125 horizon
(`artifacts/crosspath_round2b_r9.txt`), and `tests/route_state.py` fails any future route
whose tagged checkpoints sit after a death.

`m2_promotion_round3.md` is the round that changed the question. Round 2b closed the *address*
side, so round 3 measured the *entry* side and found nothing seedable there: over the committed
route's tier-2 coverage capture (`artifacts/tier2_capture_round3_combat.json` — 292 gap tuples,
226,953,466 interpreted instructions, 919,307,323 attributed guest cycles, 0 warnings) only
**3.06 %** of the residue is hot *and* sighted at a transfer gap, and the five hottest
instruction PCs of the run have zero sightings between them. What the residue is instead is
**interrupt waits**: 13 self-branching compare-and-branch-back loops at **33.80 %**, and
Shadowrun's two frame-counter waits on `$7E1C92` alone at **31.53 %** — the first
majority-class description of the residue in three rounds. That made the framework's
declared-idle-poll replay (`docs/IDLE_POLL.md`) the one entry-side lever worth building, and it
is the only lever this project has implemented and then **not adopted**: the table is
title-owned now (`DeclareIdlePolls()` in `src/game_rtl.c`, fed by `SNESRECOMP_IDLE_POLLS`) and
nothing is declared by default. The cost half works — interpreted share 96.15 % → 55.13 %, the
declared waits 289,832,044 cycles → 6,127,213 (`artifacts/idle_poll_cost_round3.txt`, the same
matrix as text) — and the behaviour half fails at **frame 9** of a
boot with no input, which falsifies IDLE_POLL.md's own promise that a wrong declaration costs
speed and never changes behaviour. Cost and behaviour are separate harnesses here for exactly
that reason (`tests/idle_ab.sh`, `tests/idle_parity.sh`, `tests/idle_f205.sh`), and the
byte-level answer is what makes the claim readable: f9 is **one** WRAM byte, `$7E0012E`
`92`→`8E`, with the polled word identical, and checkpoints whose WRAM is byte-identical still
disagree by −2…+20 master cycles (`artifacts/idle_poll_a0_round3.txt` and
`artifacts/idle_poll_checkpoints_round3.txt`, every tagged checkpoint of the route and of both
probe legs against the undeclared control — including the reverse case, `$81B061` back on the
control's `master_clock` to the cycle at `A5` while its `wram`, `vram`, `oam`, `cgram`, `fb`
and `ppuw` all differ). All three text artifacts are re-derived from the run files by
`tests/idle_artifacts.py`, so a committed number that stops reproducing is a broken claim and
not a typo. So the thing worth reporting upstream is the replay seam's cycle bookkeeping, not
that the lever fails. That record also closes a harness defect every
number above rests on: scripted legs were opening the GUI ROM file picker, which is a hang with
a window on the user's screen and a provenance hazard, and `tests/rom.sh` is now the single ROM
answer every script in the kit sources (`tests/README.md §7.9`).

`m2_promotion_round4.md` tests the 3.06 % directly: it takes the capture's own gap ranking,
seeds its top ten entries as `[[func]]` addresses, and keeps only what computes the same
machine state. Two survive — `$80C399` and `$80AAB3` — and they convert
**58,467,808** interpreted guest cycles (919,307,323 → 860,839,515, −6.36 %) with cpu and
master clocks unchanged to the unit; the drop equals the analyzer's merged span for the 14
new bodies to the cycle (`artifacts/round4_gap_seed_audit.txt`). Six seeds stop the route at
the same place — the indirect dispatch at `$80F4F9`, five unresolved abandons in frames
1766-1770 (`runner/src/common_cpu_infra.c:254`, `cpu_unresolved_abandon_balanced()`), a
cfg `indirect_dispatch` authorisation question rather than a seeding win. Two more finish the
route and change the machine: `$80ABBC` 387,641 and `$80B1DB` 482,431 differing state bytes
across the 22 checkpoints, and at checkpoint `H8` each is **one** non-label WRAM byte,
`$7E0127` `63`→`A2`/`6D`. The round's adoption gate is byte-level and has a control: the same
accepted program run twice differs in **0** of 132 rows of wram/vram/oam/cgram/sram/fb, and
`tests/apu_shift.py` shows every `apu-only` cell on an accepted tree is a pure re-stamp while
`r4clean`'s APU stream is a genuinely different event stream. Where the round stops is the
finding: 69.25 % of the residue is interpreted at PCs with no node at all, 30.02 % is inside
an `aot_eligible` span but sighted at a gap only 12 times in 2801 hot PCs, and a generated
root at the hottest PC (`$81B061`, 18.00 % of the residue) moves **0** cycles
(`artifacts/round4_hot_vs_aot.md`, `artifacts/round4_probe_81b061.txt`). Wall clock agrees
with the counters once read pairwise (−1.36 s over 10 interleaved pairs, the per-binary floor
being 1.43 s) — `artifacts/round4_wall_clock.md`. One generator re-derives the whole set from
files already on disk, running no leg, no regen and no cmake: `tests/round4_artifacts.sh`
(`tests/README.md §7.10`).

`m2_promotion_round5.md` authorises the dispatch round 4 had to leave alone. The
hand-written `indirect_dispatch f4f9 50 ptrtail targets:...` block at the end of
`recomp/bank80.cfg` turns `$80F4F9  JMP ($00A2)` into a value-matched switch: a listed
handler transfers with the caller's return context, an unlisted one takes the emitted
interpreter tail, so the authorisation cannot drop a transfer. It is also
**machine-code-inert on the shipped pair** — every `bank*_v2.c`, `dispatch_v2.c` and
`unresolved_stubs_v2.c` is byte-identical to round 4's, and only `module_v2.c`'s two
digests and the manifest's `exit_modes` (249 → 319, +70) move. That makes the program
digest move (`eea52f07…` → `aa4a6f28…`) without a body moving, which is why the round-4
digest no longer labels a rebuild of this tree (`artifacts/round5_directive_inert.txt`,
`artifacts/round5_directive.txt`). The shipped pair is re-baselined to executable
`a0587ed0…`, manifest `aa4a6f28…`, and the same combat counters to the unit
(`artifacts/round5_variant_ledgers.txt`); the gate is 22/22 `apu-only` checkpoints,
0 guest-state bytes, and `identical over 4575 frames` parity against the
directive-bearing control (`artifacts/round5_pair_checkpoints.txt`,
`artifacts/round5_pair_bytes.txt`, `artifacts/round5_pair_parity.txt`). The six seeds the
directive unblocked still fail: five now quit at 22044 and all six diverge at
`frame_001828` (`2745 of 4575`), while `$80F495` stops at `until $001F0` — a route gate,
not a dispatch question (`artifacts/round5_sweep.tsv`, `artifacts/round5_route_tails.txt`).
One correction falls out of the byte-level work: the gate's first named byte, `$0126`
`88 → 85` at `frame_001830`, is a within-frame transient (the `$0126/$0127` write
sequences are identical; the frame boundaries agree), and the persistent split starts two
frames later in live stack `$013A` and the direct page (`artifacts/round5_gate_writer.txt`,
`artifacts/round5_gate_state.txt`). The combat-route writer is the decompressor
`$809E01/$809E1E`; its one-write AOT/interpreter seam transient and the −2.5–2.8 k
`cpu_cycles` bookkeeping are in `artifacts/round5_latch_split.txt` and
`artifacts/round5_latch_state.txt`, and are a separate event from the parity divergence.
The checked-out tree is verified end to end again, and its fresh capture
(`artifacts/tier2_capture_round5_accepted.json`, `program_digest aa4a6f28…`) is the input
for the next round: the seedable slice is now 2.80 % over 219 `(pc,mx)` entries, with the
six rejected seeds still in the top eight (`artifacts/round5_accepted_verify.md`). One
generator re-derives the whole set from files already on disk, running no leg, no regen
and no cmake: `tests/round5_artifacts.sh` (`tests/README.md §7.11`).

`m2_promotion_round6.md` attributes the `f1828` cluster to bodies instead of seeds.
It takes the seed round 5 rejected (`$80C1C9`) on top of the shipped pair and demotes
that seed's 109 added AOT bodies one chunk at a time. Demoting all 109 reproduces the
pair exactly; a ddmin over a known-clean 52-body universe leaves a 1-minimal set of
two bodies, `$80AD9F` and `$80C530`, and removing either one brings the divergence
back (`artifacts/round6_cluster_hunt.txt`). `$80C530`'s 19 instructions latch the PPU
counters `$2137`/`$213C`/`$213D` and mix them into DP `$00`/`$01` and `$1D04` — the
bytes that split (`$7E00126: 88 -> 85` at `f1830`, DP `$7E00000-$7E00006` at `f1832`)
— and `$80AD9F` is the 73-instruction loop that carries `$80ABBC`, round 4's rejected
seed. A trace of the two builds names the compiled store: `bank_80_C530_M0X0` writes
`$0001=82` at `f1832` against the interpreter's `08` at `$80C54D`
(`artifacts/round6_cluster_hunt.txt` §8). The same two bodies are compiled by all five
round-5 sibling seeds and by none of the pair's own seeds, which is why six roots
shared one onset. Demoting them
restores the pair exactly, but keeps only 3.4 % of the seed's cycle gain
(`143,873` of `4,212,797` interpreted cycles; AOT share 10.82 % → 8.74 %), so the
round ships nothing and keeps the pair at `a0587ed0…`. The next lever is pricing the
counter read on the AOT tier, not another seed. The artifact generator is files-only:
`tests/cluster_hunt_report.py` (`tests/README.md §7.13`).

`m2_promotion_round7.md` tests that lever and rejects it. On a clone of the pin, two
probe builds (pair gen vs the `$80C1C9` seed gen) log the same guest `LDA $2137`
inside `$80C530` with the master clock each tier will latch at. The compiled body
latches 24 master clocks later than the interpreter at an equal entry clock — the
`LDA`'s own four bus transfers, charged before the read on AOT and after the
instruction on the interpreter — and the latched H follows that sample time exactly
(`d_h == d_latch / 4`). But the tiers also enter the body 0 to 56 master clocks apart,
so the latched H still moves by up to 20 dots. A read-time fix that advances the
interpreted latch by its pending master (`SNESRECOMP_LATCH_SYNC=1`) removes the
24-clock term and makes the gate worse: first state divergence stays at `f1830`,
differing frames go 305 → 1,333 and bytes 895 → 3,031 on the same binary pair
(`artifacts/round7_latch_phase.txt`). The first `$80C530` entry on both tiers is
`f1832`, so this latch explains round 6's DP `$00`/`$01` cluster, not the earlier
`$7E00126` byte. The pre-read guest timeline, not the read convention, is the next
target; nothing ships and the pair stays `a0587ed0…`. The probe patch is committed as
`artifacts/round7_probe.diff` and inlined in the artifact's §5; the artifact generator
is files-only: `tests/latch_phase_report.py` (`tests/README.md §7.14`).

`m2_promotion_round8.md` takes round 7 §7's next step and locates the pre-read phase.
It samples three fixed guest points per frame on the same two probe builds: the NMI
handler (`$00C0E2`, interpreted on both tiers), the first `$80C530` entry, and the
`$80AD9F` loop (`$80ABBC`, 18 iterations, compiled in the seed and interpreted in the
control), plus every compiled-function entry. The result is that the seam is not
drifting in `master_cycles`: the frame edge agrees to the clock on f1833/f1835/f1836,
46 of 51 shared entries on f1835 have identical clocks, and the non-zero ones are
±40-clock charges that cancel at the next entry. The `$80AD9F` loop costs the same
10,174 master clocks on both tiers on f1832/f1835/f1836. The offset at `$80C530` is a
discrete per-frame number (0 to ±56), created at one or two boundaries, and zero on
two of five frames — which is why a read-time fix cannot be sufficient. The same run
shows the counter that *does* drift is `cpu->cycles` (−144 to −1,624 across the
window), not the beam clock the PPU latch samples (`artifacts/round8_phase_anchor.txt`).
The artifact generator is files-only: `tests/phase_anchor_report.py`
(`tests/README.md §7.15`).

`m2_promotion_round9.md` closes round 8 §9's f1832 opening. A block tap shows
`$81A99D` is in lockstep apart from the cancelling ±40 boundary term, and that the
poll at `$809D8E` is entered at exactly the frame edge's `+14`. That poll is
`LDA $4212 / AND #1 / BNE`: control takes five reads, the seed four, and each pass
costs 66 master on both tiers (both run it interpreted). The joy tap measures the
shared auto-joypad edge directly: every busy read gives `beam+timer = 655009300`,
control's fourth read is 6 clocks before it, the seed's fourth is 8 after it, so the
14-clock frame phase buys one extra pass — the whole `-66`. Only f1832 flips in
f1829–f1836; f1830 reads `$4212` 24 times on both legs and the other frames once.
The f1830 `$7E00126` byte stays dead scratch (round 5 §8); the readable onset is the
f1832 DP cluster, whose `$80C530` latch is moved by the `-52` entry offset. This is
why no read-time or pricing patch is sufficient: the input is the frame-edge
`±14…32` phase (round 8), sampled against a hard edge. Nothing ships; the pair stays
`a0587ed0…` (`artifacts/round9_opening.txt`, `artifacts/round9_probe.diff`). The
artifact generator is files-only: `tests/round9_opening_report.py`
(`tests/README.md §7.16`).

`m2_promotion_round10.md` takes round 9's last remaining input, the frame-edge
phase, and measures it over the whole route with the round-9 probe binaries and
no new instrumentation. Over 4,574 frame boundaries the seed-minus-control
offset is 0 on 4,095, never leaves −58…+70, appears in 241 separate runs whose
longest is 16 frames, and both legs cover exactly 1,634,601,236 master clocks
end to end — bounded quantization of where the driver's
`master_cycles >= frame_end` test first sees the deadline, not a charge that
leaks. In the same runs `cpu->cycles` does run away (−2,609…+141, ending at
−1,309), which is the `upstream_seam_cycle_bookkeeping.md` distinction measured
route-wide. Frame lengths agree: mode exactly 357,368 on both legs, means equal
to six decimals, and the three route pauses identical to the clock. The phase
split begins at f1767, 63 frames before the first differing state byte at f1830,
so it is the input and not the fallout. In the onset window the boundary offset
equals the NMI entry offset on 12 of 12 frames, which validates the tap. That
closes the seed hunt: of the four levers that could move the f1832 flip, three
are measured dead (rounds 6–9) and the fourth is a change to the pinned frame
driver's slice loop. Nothing ships; the pair stays `a0587ed0…`
(`artifacts/round10_frame_edge_phase.txt`), and the generator is files-only:
`tests/round10_frame_phase_report.py` (`tests/README.md §7.17`).

`c1_staged_bundle_stale.md` left one decision open — re-stage `./Shadowrun` from the
current tree, or keep it as the dated artefact — and the tree has now been re-staged, so
the stale binary is no longer the thing the kit runs. `artifacts/bundle_verify.md` is that
close-out. The bundle is `60067549c3ee8d3b` (3,103,872 B), and the build tree behind it,
configured from nothing but the pin and the two documented flags, is `a0587ed0a0e34687`
(3,103,776 B) — byte-identical to the accepted executable, and reproduced byte for byte
again in a second scratch configure with 18 of 18 generated units compiled, so the accepted
bytes are a property of the sources plus `773285b8…` and not of one build directory. The
96 B between the two hashes is `install_name_tool`'s dylib install-name edit plus the
re-sign (§8's staging recipe), no code; the frame state on the parity route says so:
**identical over 1,200 frames**. Against the superseded bundle, kept at
`tests/out/Shadowrun_prev_ebca100c` (`ebca100c3a01201a`) because c1's own comparison needs
it, **1,174 of 1,200 frames differ**, first at frame 1 — `0xA5618AC7` vs `0x609BDB9F`. The
`artifacts/bundle_verify.md` shape of that: f0 agrees, f1 disagrees, and the 26 agreeing
frames afterwards are `0, 8-9, 12, 14-15, 23-26, 480-495` — scattered, not a prefix, with a
16-frame agreement window in the middle of a route that otherwise disagrees every frame.
Which is c1's frame-1 break restated against the new bundle. Boot is separately verified (exit 0, `$7E1C92` advancing,
`fps=58.9`). The staged copy still reports its build identity as `unknown`, because no
`CMakeCache.txt` sits beside it and `tests/provenance.py` refuses to guess — that unknown is
the finding c1 measured — and the log's §1–§2 are what supply it: gen set `3f22138eb5d1`,
18 units, 215 promoted functions, 263 dispatch entries, pin `AT THE PIN`. Reading trap in
the same log: its `"dirty": true` lines are provenance.py's *port_git* section (the script
was untracked while it ran), not the framework, which reads `dirty=False`. The check itself
is `tests/bundle_verify.sh` (`tests/README.md §7.18`), and unlike c1's reproduction it names
a build tree rather than `./Shadowrun`, which was c1's third consequence.

**The two entries below describe the first packaging round; the shipped images were
rebuilt at a macOS 11 floor on 2026-11-09 and are described after them.** Their figures
are that round's and stay readable in git: the payload `60067549c3ee8d3b` and the
container `15e0658e0f655d5e` at `git show 21c1109:evidence/artifacts/macos_package.md`,
the personal image 2,791,524 B / `cab7f7af8c0effff` and its payload `6a9baf0bbb72b737`
at `git show 21c1109:evidence/artifacts/macos_package_personal.md`. The shipped pair is
the one the current transcripts print, quoted to the byte below.

`artifacts/macos_package.md` is the transcript of the click-and-install package
(`scripts/package_macos_bundle.sh`, `tests/README.md §7.19`). The executable inside
`dist/Shadowrun.app` is `60067549c3ee8d3b` — byte-identical to the staged bundle §7.18
proved frame-for-frame equal to `a0587ed0a0e34687` — and the packager does not merely
inherit that claim: it re-measures the packaged bytes against `build-ship` and gets
**identical over 1,200 frames**, "no non-label WRAM byte differs in 1200 shared frames".
The no-ROM policy is measured five ways and reads 0 every time — ROM/patch-shaped files in
the payload *and* inside the mounted image, `_snesrecomp_embedded_rom`/`_g_rom_embedded`
under `nm`, `rom.cfg`, `grep -rl` for this repository's path and this machine's ROM
directory, and a byte scan of the executable itself for the 1,048,576-byte image
(`not found: no 1048576-byte region of Shadowrun (3103872 B) matches the digest this
build checks at boot` → `MATCH: expected absent, absent`). It is not only a build-time
claim: a copy `ditto`'d out of the mounted image into a scratch directory outside the
repository runs from there (exit 0), writes its `config.ini`, `rom.cfg`,
`last_run_report.json` and `saves/save.srm` inside itself, and touches **0 files** in the
checkout that built it — and the click path really is a click path: started through
LaunchServices with no terminal and no driver variables inherited, the app's own breadcrumb
records `SDL init ok: video=cocoa audio=coreaudio` and `window created: 960x720`
(§7.19's transcript first claimed that on the strength of `open` and was wrong: the app
had inherited the packager's `SDL_VIDEODRIVER=dummy`). Two things the artifact records as
not achievable instead of hiding them: no resource seal can exist for this payload — the
host anchors its runtime files beside its executable, so `Contents/MacOS` carries
non-Mach-O files and `codesign --force --sign -` on the bundle refuses at the first one it
walks (`mods/preloaded/README.md` in this transcript, `mods/preloaded/state.toml` in the
personal transcript and in the shareable one committed at `50c7405` — the file named
depends on the order `codesign` walks the directory) — and the `.dmg` is **not**
byte-reproducible (a second `hdiutil create` from
the same stage directory is `bf044111a21368ca` where this run's image is `15e0658e0f655d5e`),
so only the payload hashes pin the build — and a §3 probe shows how tightly: a scratch
copy of the build-tree executable given just the two staging steps in a plain directory
reproduces the shipped `60067549c3ee8d3b` hash exactly, while the same bytes signed
already inside a bundle come out `7f3cce8806caf7cc` (`hashes=188+3`: the bundle's
`Info.plist` bound into the Mach-O's own signature) and the same bytes under a different
file name come out `366aa2e1df5bfdd2`. The tree-vs-packaged executable difference is now
measured rather than asserted: `LC_CODE_SIGNATURE` starts at byte 3,079,584 in both files,
so the entire 96 B file difference is the signature blob, and `cmp` over the common prefix
finds **212 differing bytes, first at byte 21, last at 2,198** — all inside the Mach-O
header and its load commands, which is where the SDL install-name rewrite lives. Nothing
past byte 2,200 (where the load commands end) differs at all.

`artifacts/macos_package_personal.md` is the transcript of the other variant,
`PERSONAL=1 scripts/package_macos_bundle.sh` (`tests/README.md §7.20`) — a package that
carries the guest image, labelled as doing so, and therefore not a distributable
artefact. Nothing in it is a relaxed version of the scans above: the expect-0 counts stay
0 (ROM/patch-shaped files, `rom.cfg`, generated inputs, files naming this repository or
this machine's ROM directory), and the one inverted check is a *presence* check with its
evidence named — `nm` shows `_snesrecomp_embedded_rom`, and the image is found as bytes
inside the Mach-O at `0x28762e` (1,048,576 B) where re-hashing gives `e6bc0a59…`, the
digest in `rom_identity.txt`: `MATCH: expected present, present`. The same scan against
the shareable executable reads `absent`, so the check is not a tautology. The bundle's own
labels are read back off disk rather than asserted, and its `BUILD_INFO.txt` digest record
matches `embedded_rom.c` and `rom_identity.txt` — all three `1048576 / 3f34dff0 / e6bc0a59…`.
What makes this a fidelity question and not just a packaging one: the tree is
`build-embed-ship`, built from a framework clone **3 commits past the pin**
(`c5024e74abef…`, "boot an embedded guest image"; the pin has no embedded-host code at all),
and the packaged app still dumps a **frame-for-frame identical** machine against the
accepted ROM-based `build-ship` — identical over 1,200 frames, "no non-label WRAM byte
differs in 1200 shared frames" — with one side logging `rom resolved:
<embedded:Shadowrun (USA).sfc>` and the other naming a file. Byte hashes cannot answer that
question: the two executables differ by 1 MiB of guest data, and the tree's `4,160,576 B`
versus the packaged `4,154,528 B` is now measured rather than asserted — `LC_CODE_SIGNATURE`
starts at byte 4,128,192 in both, so the whole 6,048 B gap is the signature blob
(`hashes=1008+0 flags=0x20002(adhoc,linker-signed)` against `hashes=252+2 flags=0x2(adhoc)`),
and `cmp` over the common prefix finds **213 differing bytes, first at byte 21, last at
2,198**, all inside the header and load commands, so the code, the data and the 1 MiB image
are bit-identical. The same §3 probe as the shareable transcript runs on this tree: a
scratch copy given only `install_name_tool -change` and `codesign --force --sign -`
reproduces the shipped `6a9baf0bbb72b737` exactly, the same bytes under another file name
come out `9a210fd9ea907510`, and the same bytes signed already inside a bundle come out
`747bdadf36a11902` at the **same length** with `hashes=252+3`. The container is
`dist/shadowrun-embed-0.1.0-macos-arm64-personal.dmg`,
2,791,524 B, sha256 `cab7f7af8c0effff`, `hdiutil verify` VALID; opening it with nothing
passed at all reaches `rom resolved: <embedded:…>` and a window with no `rom.cfg` anywhere,
which is where the file picker would otherwise be.

**The floor-11 rebuild, and the six artifacts behind sections 7.21 to 7.27.** Every
figure in this block is printed by the transcript named beside it, and all of them are
the 2026-11-10 run.

`artifacts/macos_package.md` §1 reads the installed executable as
`37d08a86a2a86414`, 5,953,488 B - the same bytes inside the `.app`, inside the mounted
image, and inside the copy §5e drags out of it. The personal transcript reads
`44a3da74ddca0062`, 7,004,144 B the same way. `artifacts/macos_deployment_floor.md` §3
reads both bundles as `arch arm64`, `thin minos 11.0 sdk 26.5`, "bundle claims it needs
macOS: 11.0", and the two containers as `fe2648738fad58a6` (2,221,175 B) and
`7edb5fe11827d880` (2,949,133 B), each `hdiutil: verify: checksum ... is VALID`.

`artifacts/macos_state_out_of_bundle.md` is the transcript of
`tests/macos_state_probe.sh` (`tests/README.md §7.21`), the host change that lets a
bundle be sealed at all. The fork host anchors `config.ini`, `saves` and `rom.cfg` under
`~/Library/Application Support/Shadowrun/` and the bundle it is run from holds only
`Info.plist` and the payload; the pinned host anchors the same files beside its
executable. On the parity route the two executables - `092b0e690cab97a1`, 5,970,048 B,
against `a0587ed0a0e34687`, 3,103,776 B - read "identical over 1200 frames (crc32 of
all 128 KiB of WRAM per frame)" and "no non-label WRAM byte differs in 1200 shared
frames", which is what lets the packaged bytes inherit the measurements made against
the pinned executable.

`artifacts/macos_deployment_floor.md` is the transcript of `tests/macos_floor_probe.sh`
(`§7.22`): §1 reads `LC_BUILD_VERSION` (or `LC_VERSION_MIN_MACOSX`) out of ten build
trees in the order the compatibility round tried them, §2 what SDL3 each would carry
and whether as a dylib or statically, §3 what is actually shipped (above), §4 the
compile evidence for a floor older than this machine, and §5 what this machine can
execute - `arch -x86_64 /usr/bin/true` exits 1 with `Bad CPU type in executable`, so
every x86_64 record in this repository is a compile-and-link measurement.

`artifacts/macos_floor11_rebuild.md` is the log of `tests/macos_floor11_check.sh`
(`§7.23`) and `artifacts/macos_floor11_rebuild_build.md` is the build it ran: it reads
the baseline tree's `CMakeCache.txt`, configures an empty directory from the same
sources at `CMAKE_OSX_DEPLOYMENT_TARGET=11.0` with `CMAKE_DISABLE_FIND_PACKAGE_SDL3=ON`
and the SDL3 3.4.10 tree, builds, and reports "cmp finds no differing byte between
build-ship-m11-check/ShadowrunSNESRecomp and build-ship-m11/ShadowrunSNESRecomp", so the
floor is a property of the recipe rather than of one tree someone already built. The
log also states what it does not prove: nothing here says a macOS 11 machine runs the
result, and the personal variant is not rebuilt by it.

`artifacts/macos_framework_commits.md` is the generated log of
`tests/macos_framework_commits.sh` (`§7.24`): the three checkouts the shipped bytes came
out of - `pin` `773285b8210f`, dirty 0, 0 commits past; `sr-osx` `32266300d722`, dirty
0, 1 commit past; `sr-embed-osx` `a7fb67e6c9f5`, dirty 0, 4 commits past - then the two
capability commits located by subject with their full patches, and the SDL3 source each
build tree pinned.

`artifacts/doc_quote_audit.md` is the fixed-point log of `tests/run_doc_audit.sh`
(`§7.25`): 126 evidence files and 3 history blobs for quotations, range
`tests/README.md` lines 1688-4046, 11 of 11 artifact-against-log pairs byte-identical on
disk, and `untraceable findings: 0`. It records the check, not a measurement of the
port.

`artifacts/macos_user_open.md` is the transcript of `tests/macos_user_open_probe.sh`
(`§7.26`): both `dist/` images mounted read-only, the `.app` copied out with `ditto`,
the copy's own bytes asked to exec, the download flag off and then on for a click
through LaunchServices, and the copy that ran re-hashed and re-sealed. Both packages
came up, `'open' exit 0` in all four legs, macOS's own lines used the word `damag` 0
times, and the run's own findings count is 0.

`artifacts/macos_exec_hold.md` is the transcript of `tests/macos_exec_hold_probe.sh`
(`§7.27`): the condition where macOS holds a quarantined copy at exec instead of
refusing it, made on purpose by re-signing under a new bundle identifier
(`org.retroportingtoolkit.shadowrun` to `org.retroportingtoolkit.holdprobe1794290216`,
cdhash `c8c8553aba8d7cfa` to `b159fec2ef53c0d7`) and clicking it. The held process is a
live pid whose sampler call graph names `_dyld_start (in dyld) + 0` and nothing else,
watched as 2 mapped file(s), 0:00.00 CPU and 0 line(s) of output from 20 s to 120 s;
section 5 finds the first thing after which the path ran at number 4 (the SIGKILL sent
to this user's CoreServicesUIAgent), the rename measured on a hold of its own does not
move it, and the copies that section made are removed, so nothing it may have left held
stays standing.

`upstream_seam_cycle_bookkeeping.md` is the upstream report those seam numbers were for.
It reads the pinned framework (`773285b8…`) and the two round-5 probe artifacts, and finds
that the two counters are not the same kind of measurement. `master_cycles` is pinned by
the scheduler at a 357,368-clock frame boundary (`a7_aot_split_hunt.md` §8, item 1), so
agreement there is the budget, not the paths. `cpu->cycles` is charged by two different
models — the interpreter's runtime `interp816_runOpcode` result and the AOT emitter's
gen-time constant plus paced transfers — so a seam can move it by `−144` at `f1832` and
`−1,623…−2,788` once the sampled state diverges, while master stays inside `−32…+18`
(`artifacts/round5_gate_state.txt`, `artifacts/round5_latch_state.txt`). The report rules
out the per-opcode charge (a7 §8.4's directed 22-case table, every delta `+0`), DRAM
refresh (`snes_refresh_charge()` writes `master_cycles` only), and a wrong value (the
`$0126` write is one store that resynchronises), and names the one experiment that would
separate "the counter is wrong" from "the counter is honest about a different phase": the
framework's AOT block log against `SNESRECOMP_CYC_WATCH` on the control over the seed's
closure. That experiment is run in the report's §8: both probes already exist
(`SNESRECOMP_AOTBLK` at `cpu_trace.c:1233-1250`, `SNESRECOMP_CYC_WATCH` at
`interp_bridge.c:2763-2788`), `tests/seam_phase.py` reads their logs, and the result selects
"the executed set differs": the 92 common AOT PCs are identical over all 1,610 block entries
in f1820-1834, and the only block-count changes in the onset window are two entries at f1832
and eight at f1833 in the seeded cluster — the frame the park probe already shows `−144` with
DP identical, two frames before the sampled state split at f1834
(`artifacts/round5_seam_phase.txt`). What remains is the `−149` at f1830, which survives with
an identical block set and is therefore sub-block: it needs an instruction-level AOT charge
log inside a block, which the framework does not yet emit.
