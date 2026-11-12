# A6 clean cross-path rerun: physics identical to f21800, then the legs part at the street-transition gate

> **Addendum (a7):** the "physics-identical to f21800" claim below holds only
> against a 1 KiB-block gate, which this route's own byte-level sweep beats.
> The AOT and LLE legs part physically at **host f16122** — 16 WRAM bytes in
> the $00DF-$00F2 direct-page table — and carry a steady 10²–10³ byte delta
> from there on. The street-gate mode switch at f21800+ is downstream of that.
> See `evidence/a7_aot_split_hunt.md` §3–§5 for the onset table, the state
> bisection that rules out the gate code, and the 5-minute repro
> (`tests/scripts/bisect_h8.txt`); §7–§8 for the attribution: identical
> byte-write streams labelled one loop iteration apart under a pinned
> 357,368-clock frame budget — a hand-off phase split, not a value bug.

> **Addendum (route fix, 2026-11-07):** the checkpoint table below (`W1`,
> `T0`/`T1`, `U1`–`U9`, `S1`–`S6`, `W2`/`W3`) describes the *old* `combat.txt`
> tail, which pressed menu keys into a party the alley script kills on a
> game-driven timer — `W1` at f22951 was the title screen. That tail is gone:
> `combat.txt` now gates the alley segment on WRAM state and ends alive at
> `A5` (~f22,044). The f16125 horizon claim was re-measured on the fixed route
> at the round-2b binaries (`tests/out/xp_aot_r9`/`xp_lle_r9`) and holds
> unchanged; see `evidence/m2_promotion_round2b.md` §6.

Closes a5 §6. Setup: `tests/crosspath.sh` (new, uncommitted at time of writing)
with `tests/scripts/combat.txt`, both legs from the same tree and the same
master SRAM seed, one absolute dump dir per leg.

- **run1** = `./Shadowrun` (AOT build; `execution_share`: interp 96.27% /
  aot 3.73% in the root report for this route).
- **run2** = `build-lle/ShadowrunSNESRecomp` (separate cmake tree; `execution_
  share`: **interp 100.00% / aot 0.00%** — the proof the floor really ran;
  `SNESRECOMP_FORCE_FLOOR` would not have done it, see crosspath.sh header).
- Both legs: 25,902 host frames, 25,902 WRAM frame dumps + all 43 tagged
  checkpoints, `tests/out/xp_aot`, `tests/out/xp_lle`.
- Analysis tools: `tests/framedump_diff.py` `tick` / `shift` / `drift` /
  `guest` (new modes). Raw outputs archived here:
  `a6_drift_xp.txt`, `a6_shift_xp.txt`, `a6_guest_xp.txt`.

## Headline (replaces a5's whole-route framing)

**AOT and LLE are physics-identical (label bytes excluded) through the entire
alley route up to host f21800 / guest tick ~21700. At the street-transition
window the two paths make different game decisions — the LLE leg enters the
transition and ends up reset to the title screen, while the AOT leg never
enters it and walks on into the shadowrun menu.** Every checkpoint after
~f22900 is title-mode vs in-game-menu: those diffs are game-mode differences,
not physics differences, and must not be read as cross-path mismatches.

## 1. Tick-phase timeline (`tick` mode) — reproduces a5 §1

| guest counters | phase k = run1 − run2 host frame | host frames |
|---|---|---|
| 0–186 | +0 | 0–194 |
| 187–1217 | −3 | 205–1315 |
| 1219–1469 | −3 | 1349–1599 |
| 1473–22609 | **−3 constant** (21,137 ticks) | 1712–22848 |
| 22610–25625 | **−37** | 22849–25864 |

(Phase sign is inverted vs a5 §1 — that table was run1 − run2 in tick space;
same events, same boundaries: the +37 step lands at host f22849, matching
a5's f22852.) Two transient excursions (k=−35 for one tick at counter 1218,
k=−112 for three ticks at 1470–1472) sit inside the title-screen `wait`
windows and are first-occurrence bookkeeping, not drift. **Phase is constant
elsewhere across the whole run: the two paths tick at exactly the same rate.**
run1 ends with 37 counters run2 never reaches — the +37 label offset.

## 2. Physics probe (`shift` mode)

12 of 41 sampled guest counters are **byte-identical** (kernel window
$7E01C80–$7E01D40 and timer singletons $7E0012C/12E/12F/132 excluded) after
host-frame alignment; through counter 15360 the best-k diff is 0–6 bytes.
It rises 100–350 B at 16000–21120 (fade/timer label bytes), then
**5.7 KB at c21760–22400** (run2 mid street-transition while run1 is still in
the alley — see §5), then ~30 KB from c23040 (title mode vs in-game). The
a5 "0 B through the shared-physics route" verdict is confirmed **up to the
transition window** and stops there.

## 3. Route divergence curve (`drift` mode)

Differing 1 KiB blocks per host frame (WRAM = 128 blocks):
≈1–2 through f15999 (label only), 4–16 at 16000–21999 (transition/label),
then a knee at f21800–22905 climbing to a **flat 70 blocks from f22905 to the
end** (worst frame f22905). `first frame over threshold: 476` is the boot-time
tick gain (a5 §1's f497 +1: 1,448 bytes at $7E04E00–56FF, animation phase
re-aligned one tick later — not a physics desync).
Full curve in `a6_drift_xp.txt`.

## 4. Guest-tick gate (`guest` mode) and checkpoint md5s

25,626 counter-aligned pairs: 634 identical, 24,992 differing; top offsets are
label families ($7E01D00/D04 kernel, $7E00120, and the $7E006xx/$7E00Cxx
tick-derived animation block). `guest` alignment alone is no longer the right
gate after f22900 — it compares title-mode WRAM against in-game WRAM.

Checkpoint frame-buffer md5s (`md5`, both legs, 43 tags):
**9 match / 34 differ.** Matches: H8, J4, J7–J10, K1, K2, J10; pixel-count of
the differing pairs tells the story:

| tags | px diff @256x224 | reading |
|---|---|---|
| J1,J2,J3,J6,K3 | 16–571 px | same scene, animation phase |
| L1, M0–M2, P1–P3, Q0 | ~12.1–12.3 K px | same alley, same scene, sprite phase (the "3" damage popup lands at different animation frames) |
| J5 | 43% | one leg mid-walk-cycle, other standing |
| **P3** | — | run1 alley, characters standing; **run2 near-black = fade in flight** |
| W1 (f22951) | — | **run1: shadowrun menu open (Joshua, Beretta Pistol); run2: title attract screen** |
| T0/T1, U1–U9, S1–S6, W2/W3 | ~75% | run1 in-game menu; **run2 at title / title options menu** |

The 74.92% "constant" across S tags is coincidence (each S frame differs by
its own ~43 K px, verified by md5: all distinct), and the S-tag BMPs show
run2 navigating the **title options menu** (CONTROL TYPE / STEREO / B.G. MUSIC
/ EXIT) — the script's `press start` + `press down/a` landed on the title
menu, not the shadowrun menu.

## 5. What actually happened at f21800–22930

- f21836 (checkpoint P3): run2's framebuffer is near-black — run2 has entered
  the tick-gated street transition; run1 is still in the alley.
- f22850–22950: cross-diff grows 11 → 22 of 32 (4 KiB) blocks; run2 switches
  to the title game-mode (its later tagged dumps are title/attract and title
  options). The a5 "run2's label **stalls** at f22852" observation is this
  game-mode switch: the tick label behaves differently in title mode.
- run1 opens the shadowrun menu (W1/T0) and stays in-game to the end (S tags,
  orc scene visible at S1).
- The stale Nov-4 LLE binary in a5 §6 branched at the **same route point**
  (post-transition content divergence from c~22000). So this is not an
  artifact of the fresh `build-lle` tree: some build of the faithful floor
  path, at the street-transition gate, goes to title, while the promoted AOT
  build walks on. Candidate mechanism: the transition trigger condition reads
  a tick/timer quantity the label offset pushes across a threshold, or the
  promoted banks 80/81 (vblank/NMI tick increment — a5 §5) change the
  transition state machine. **Not yet attributed to code.**

## 6. Implications for the cross-path gate

1. Same-binary determinism: PASS (unchanged).
2. Physics cross-path claim holds, scoped: **byte-identical through the alley
   (f ≤ ~21800 / c ≤ ~21700)**, label-only diffs inside the fade, and a
   genuine content decision at the street-transition gate.
3. The 43-checkpoint md5 table after ~f22900 is **not a parity signal** for
   this pair; it is evidence of the mode switch. Checkpoint comparisons are
   only meaningful guest-event-tagged, and only while both legs are in the
   same scene.
4. Open follow-ups, in order:
   a. Attribute the transition decision to code: trace build with the
      `$7E1C92` range write-trace (a5 §5 recipe) plus a scene/game-mode
      trigger probe around f21800–22950; answer why run1 never fired the
      transition and why run2's transition ended at the title.
   b. Route hygiene: the combat.txt route passes the transition gate only
      for the AOT tick phase; for cross-path reruns either freeze the gate
      (shorter route, nav1/nav2 stop before it) or re-land route steps on
      guest events (`until` on scene bytes) rather than host-frame waits.
   c. Then a5 §5's tick-gain attribution (f205/f417/f497/f1349) can proceed
      with the same trace build.
