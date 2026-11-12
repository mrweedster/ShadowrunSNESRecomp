# A1 — Coverage capture report

Scope: Stage 1, workstream A1 (coverage capture) of
`~/.opencode/plan/shadowrun-stage1-rom-free.md`.

Status: **capture complete for four scripted routes; full-game coverage not yet
captured.** This report is the input to the M1 go/no-go, not the go/no-go
itself.

Reference build: bundle `7e353a2`, binary sha256
`208c2dc78ee11fc52bb223e9f0ac98fc48d770f42f0190a6e6d0c2130cfa86ad`.
Raw capture data lives in `tests/out/a1/` (gitignored, regenerable); the
numeric summary is `tests/out/a1/summary.json`.

---

## 1. Method

```sh
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
SNESRECOMP_TIER2_CAPTURE=1 SNESRECOMP_COVERAGE_DIR=<dir> \
./Shadowrun --no-launcher --script <script>
```

Each run writes a per-run JSON (`execution_share`, `costs`, `discoveries`) and
a JSONL discovery journal. The capture is instruction-level: every interpreted
target PC is recorded with an entry M/X state, an instruction count, and a
guest-cycle count. `observed_hits` in the journal records a transfer target the
analyzer did not have an entry for (`fallback_reason: missing_entry`).

The bundle currently emits **0 AOT functions** (`recomp/funcs.h`), so
`InterpExecutionShareGet` reports `interp_cycle_pct: 100.0`,
`aot_cycle_pct: 0.0` on every route. `total_tier_hits` is therefore 0 and is not
a useful signal yet; the useful signal is the static instruction profile below.

## 2. Routes

| Run | Script | Frames | What it covers |
|---|---|---|---|
| `selfcheck` | `tests/scripts/selfcheck.txt` | 276 | boot → tick counter → quit |
| `menu` | `tests/scripts/menu.txt` | 1,245 | boot → narration → title menu → move → pick |
| `nav1` | `sr-probe-port/tests/scripts/nav1.txt` | 1,932 | boot → new game → advance intro |
| `nav2` | `sr-probe-port/tests/scripts/nav2.txt` | 4,823 | nav1 + first dialogue and a short scripted walk |

All four exited 0. These routes cover boot, menu, and the opening of the game.
They do **not** cover combat, inventory/shop/cyberdeck, dialog trees beyond the
opening, or map transitions deeper into the game.

## 3. Per-run profile

| Run | Frames | Interpreted instructions | Guest cycles | Instr/frame | (pc, mx) targets |
|---|---:|---:|---:|---:|---:|
| selfcheck | 276 | 2,201,337 | 8,857,993 | 7,976 | 690 |
| menu | 1,245 | 10,325,616 | 40,930,560 | 8,294 | 1,667 |
| nav1 | 1,932 | 17,370,633 | 68,550,083 | 8,991 | 8,513 |
| nav2 | 4,823 | 52,471,657 | 207,633,019 | 10,880 | 9,678 |
| **merged** | **8,276** | **82,369,243** | **325,971,655** | **9,953** | **9,678** |

Merged distinct PCs: **9,638**.

## 4. Concentration

Instruction share is heavily loop-weighted:

| Top N targets | Share of interpreted instructions |
|---:|---:|
| 10 | 46.1% |
| 50 | 54.4% |
| 100 | 59.7% |
| 250 | 70.8% |
| 500 | 83.9% |
| 1,000 | 93.0% |
| 2,000 | 97.6% |

- 2,470 targets executed fewer than 10 instructions each.
- 690 targets appear in all four runs and account for 41.1% of instructions.
- nav2-only targets account for 1.08% of instructions.

**Caveat:** the two hottest targets are a wait loop at `$81EE8E` / `$81EE92`
(M1X0), 13,261,662 and 13,261,660 instructions respectively — **32.2% of all
captured instructions**. Excluding those two, 64.1% of the profile remains
across 9,674 targets. Instruction-share rankings measure idle time, not code
coverage; promotion decisions should also use unweighted distinct-PC counts.

## 5. Entry-state and bank distribution

| Entry M/X | Instructions | Share |
|---|---:|---:|
| M0X0 | 41,163,670 | 50.0% |
| M1X0 | 37,664,491 | 45.7% |
| M1X1 | 3,183,675 | 3.9% |
| M0X1 | 357,407 | 0.4% |

| Bank | Instructions | Share |
|---|---:|---:|
| `$81` | 48,459,128 | 58.8% |
| `$80` | 33,672,755 | 40.9% |
| `$00` | 237,360 | 0.3% |

So the two game banks (`$80`, `$81`) account for 99.7% of executed code. All
four M/X combinations are live, although M0X1 is marginal.

## 6. Unresolved transfer targets (promotion candidates)

Merged journal: **322 distinct targets**, 1,196 observations.

| Property | Value |
|---|---|
| Fallback reason | `missing_entry` — 100% |
| Site kind | `call_gap` 241, `goto_gap` 84 (targets can carry both) |
| Bank | `$80` 174, `$81` 148 |
| `completed_hits` / `yielded_hits` / `pending_hits` / `bail_hits` | 0 / 0 / 0 / 0 |

Those counters being zero means the capture detected the sites but did not
replay them; they are **candidates**, not qualified promotions. The analyzer
simply has no function entry at those targets.

Top candidates by observation count:

| Target | M/X | Obs | Kind | Runs |
|---|---|---|---:|---|
| `0x81EFC8` | M0X0 | 73 | call_gap | all 4 |
| `0x809DE8` | M0X0 | 42 | call_gap | all 4 |
| `0x81EE7C` | M0X0 | 34 | call_gap | all 4 |
| `0x818E57` | M0X0 | 26 | call_gap | nav1, nav2 |
| `0x80B101` | M0X0 | 25 | call_gap | nav2 |
| `0x81EFFB` | M1X0 | 20 | call_gap | menu, nav1, nav2 |
| `0x81EFC8` | M1X0 | 15 | call_gap | menu, nav1, nav2 |
| `0x81D4EE` | M0X0 | 15 | call_gap | menu, nav1, nav2 |
| `0x81EB58` | M0X0 | 14 | call_gap | all 4 |
| `0x81EBD7` | M0X0 | 14 | call_gap | all 4 |

Coverage overlap: 37 targets are seen in all four runs, 35 only in nav2, 0
menu-only, 0 nav1-only. The opening walk is what is still adding new targets;
the menu adds none that nav1 does not also reach.

## 7. What this does not prove

- **No full-game coverage.** Routes stop at the first walk; combat, menus
  beyond the title, shops, cyberdeck, and later maps are unmeasured.
- **No AOT/LLE comparison.** The bundle is 100% interpreted, so there is no
  instruction-share split to report yet.
- **Instruction share ≠ code coverage.** Idle loops dominate the weighted
  numbers; they say little about how much of the game's code is reachable.
- **Discovery is route-local.** The 322 targets are only those the four routes
  exercised; the true missing-entry set for the whole game is larger.
- **No variant qualification.** `completed_hits` is zero, so no entry-M/X
  variant has been proven against a replay.

## 8. M1 decision input

The full-AOT vs hybrid decision cannot be made from these routes alone. What the
data does support:

1. Executed code is concentrated in `$80`/`$81`; bank `$00` is negligible
   (0.3%) and `$81` is the larger half.
2. All four entry M/X states occur, so AOT variants are required for all four —
   a single-variant promotion would leave a large residue.
3. The static analyzer already found 214 functions on the `sr` scaffold with
   only two roots, which suggests broad static reachability is achievable.
4. The 322 `missing_entry` targets are the likely remainder that needs either
   promotion seeds or an embedded-code fallback.

Proposed M1 gate when coverage is extended:

- **Full AOT** if promotion on a longer route set leaves <1% of executed
  instructions interpreted and parity stays identical (modulo the documented
  frame-counter delta in `tests/README.md` §7).
- **Hybrid** if the residue is concentrated in proven-dynamic sites; embed the
  code banks and keep the interpreter for those sites.

## 9. Next actions

1. **Extend routes** — scripted combat and at least one room/map transition, or
   a recorded play session, before the M1 sign-off.
2. **A2** — flip `I_RESET`/`I_NMI` to `emit = true`, regenerate, build, gate on
   `PORT_BIN2` parity; then expand promotion batch by batch.
3. **B0** — in parallel, instrument `cart_read` to separate code reads from data
   reads; the read trace is the other half of M1.
