# M2 promotion round 3: the residue is wait-shaped, and the framework's idle-poll replay does not hold on this title

Action record for the third round of the standing M1/M2 promotion loop opened by
`evidence/m1_hybrid_decision.md` (round 1: `m2_promotion_round1.md`, round 2:
`m2_promotion_round2.md`, round 2b: `m2_promotion_round2b.md`). Date: 2026-11-07.

Provenance for everything below: framework pin `773285b8210f2254ae87d0a14113980fb36990ad`
(`framework_pins.txt`, clean tree at `<TMP>/sr-pin`); the round-2b AOT executable
`4c1775badab30111…` in `./build-r2b`, which is the program the **capture** was taken with;
the round-3 executable `1341448773c19617…` in `./build-r3`, which is the same program plus
the idle-poll wiring in `src/game_rtl.c` and is the program the **A/B** was taken with; the
generated set unchanged across both (18 units, 269 nodes, 47 roots, 252 dispatch rows) —
the captures' own identity block says `program_digest 240af24bb4a71049…`,
`generation_digest 4e902f1ff9bdca6f…`, `rom_sha256 e6bc0a595d5c…`, mapper `lorom`; route
`tests/scripts/combat.txt`, 22,044 frames, from the committed SRAM seed.

Plain language first, then numbers.

Round 2b closed the *address* question and said the next lever, if there is one, is about
*entry*, not addresses. Round 3 goes and measures that, in both directions:

1. **The framework's tier-2 coverage capture says the residue is not entry-seedable, and
   says what it is instead.** Over the committed route: 292 gap tuples, 226,953,466
   interpreted instructions, 919,307,323 attributed guest cycles, 0 warnings
   (`evidence/artifacts/tier2_capture_round3_combat.json`). Of that residue **3.06 %**
   (28,131,074 cyc, 233 `(pc,mx)` entries) is hot *and* sighted at a transfer gap — the
   only part an entry-side seed could reach — and **96.94 %** (891,176,249 cyc) is never
   sighted at a gap at all. The hottest five instruction PCs in the whole run —
   `$81B061`, `$81B065`, `$81EE8E`, `$81EE92`, `$81F007` — have **zero** transfer sightings
   between them. That confirms round 2b's inference from the other side, and it kills the
   remaining `[[func]]` idea as a lever for this residue.
2. **What the residue is made of: interrupt waits.** 13 self-branching compare-and-branch
   back-edges account for 310,681,830 cycles = **33.80 %** of the attributed residue, and
   two of them — Shadowrun's own frame-counter waits on `$7E1C92` — are 289,832,044 cycles
   = **31.53 %**. This is the first thing in three rounds that describes a *majority-class*
   of the residue rather than a tail.
3. **The one entry-side lever the framework offers for that class was implemented here and
   measured, and it does not hold.** `docs/IDLE_POLL.md` names a mechanism that needs no
   entry: declare the PC of an interrupt-wait poll and the interpreter bridge replays the
   wait's cycle to the frame deadline instead of interpreting it, with eight guards whose
   stated purpose is that a wrong declaration costs speed and never changes behaviour. No
   framework host fills that table in, so the title now does (`DeclareIdlePolls` in
   `src/game_rtl.c`, fed by `SNESRECOMP_IDLE_POLLS`). The cost half works: declaring the
   pair takes the interpreted share of cpu cycles from **96.15 % to 55.13 %**, and the
   declared waits from 289,832,044 cycles (31.53 %) to 6,127,213 (0.98 %). The behaviour
   half fails on the first frame that matters: per-frame WRAM crc32 over the whole route
   diverges from the undeclared control at **frame 9** with the pair and with `$81EE8E`
   alone, and at **frame 1,733** with `$81B061` alone — and at frame 9 the two legs differ
   by exactly one WRAM byte (`$7E0012E` = `92` vs `8E`) while the polled word `$7E1C92` is
   identical. So the lever is recorded as **measured and not adopted**: nothing is declared
   by default, the default leg reproduces the round-2b control byte for byte, and the
   promise IDLE_POLL.md makes is a framework bug worth taking to its owner, with a
   one-command reproduction.

The M2 promotion state itself is unchanged by this round: no seed was added, no body was
promoted, the AOT share stays 3.94 % of cpu cycles, and the f16125 cross-path horizon and
its baselines were not touched.

## 1. The capture: what a tier-2 run actually saw

Taken on the round-2b executable, so it is the same program the round-2b baselines measure,
with the framework's own capture armed at launch:

```sh
. tests/rom.sh; rom=$(sr_rom)        # the one ROM answer — see §8, no leg may ask for it
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
SNESRECOMP_TIER2_MANIFEST="$PWD/tests/out/idle_off_cov.json" \
  ./build-r2b/ShadowrunSNESRecomp --no-launcher --rom "$rom" --coverage-capture=on \
  --script "$PWD/tests/scripts/combat.txt"          # 22,044 frames, exit 0, 31 s
python3 <pin>/tools/tier2_ingest.py --json --cfg-dir recomp \
  --program-manifest src/gen/program_manifest.json <export>.json
```

| quantity | value |
| --- | --- |
| captures ingested | 1 |
| gap tuples (`discoveries`) | 292 |
| hot instruction rows | 9,563 |
| interpreted instructions | 226,953,466 |
| attributed interpreted guest cycles | 919,307,323 |
| warnings | 0 |
| capture file | 1,750,420 B (`tests/out/idle_off_cov.json`) |
| ingest report | `evidence/artifacts/tier2_capture_round3_combat.json` |

The residue split, which is the entry-shape question answered with numbers
(`tests/coverage_gaps.py`, new):

| class | cycles | share | entries |
| --- | --- | --- | --- |
| hot **and** sighted at a transfer gap — seedable | 28,131,074 | 3.06 % | 233 |
| never sighted at a gap — entry-shape residue | 891,176,249 | 96.94 % | — |

And the five hottest instruction PCs in the run, all of them inside the second class:

| PC | mode | guest cycles | share | interpreted insns | transfer sightings |
| --- | --- | --- | --- | --- | --- |
| `$81B061` | M0X0 | 165,447,390 | 18.00 % | 27,574,565 | 0 |
| `$81B065` | M0X0 | 82,703,990 | 9.00 % | 27,574,565 | 0 |
| `$81EE8E` | M1X0 | 26,051,305 | 2.83 % | 5,210,261 | 0 |
| `$81EE92` | M1X0 | 15,629,359 | 1.70 % | 5,210,261 | 0 |
| `$81F007` | M1X0 | 2,859,300 | 0.31 % | 714,825 | 0 |

`0` sightings means no gap tuple anywhere in 22,044 frames hands control to that address:
exactly the entry shape round 2b inferred from `found:0` being empty. A `[[func]]` seed at
`$81B061` would put a body there that the dispatch table is never asked for.

## 2. The wait class: 33.80 % of the residue is compare-and-branch-back

`tests/wait_class.py` (new) walks the capture's hot PCs through the *pinned* framework's
decoder and groups each self-branching wait with its branch PC, which the capture bills
separately. Threshold 300,000 cycles, full table:

| poll PC | mode | loop cycles | % of residue | loop shape | polled |
| --- | --- | --- | --- | --- | --- |
| `$81B061` | M0X0 | 248,151,380 | 26.99 % | `BEQ $B061` | `7E1C92` |
| `$81EE8E` | M1X0 | 37,935,840 | 4.13 % | `BEQ $EE8E` | `7E1C92` |
| `$80C1B3` | M0X0 | 6,013,080 | 0.65 % | `BRA $C1B3` | `026C` |
| `$81F007` | M1X0 | 4,954,175 | 0.54 % | `BNE $F007` | `2140` |
| `$81EE8E` | M1X1 | 3,744,824 | 0.41 % | `BEQ $EE8E` | `7E1C92` |
| `$80ABE5` | M0X0 | 2,716,279 | 0.30 % | `BEQ $ABE5` | `10AC,x` |
| `$81AC6B` | M0X0 | 2,022,074 | 0.22 % | `BNE $AC6B` | `0214` |
| `$81EFCF` | M1X0 | 1,492,666 | 0.16 % | `BNE $EFCF` | `2140` |
| `$81AC79` | M0X0 | 995,931 | 0.11 % | `BNE $AC79` | `0212` |
| `$81E4D1` | M1X0 | 753,043 | 0.08 % | `BNE $E4D1` | `2142` |
| `$81AC85` | M0X0 | 696,053 | 0.08 % | `BNE $AC85` | `0218` |
| `$819025` | M0X0 | 653,493 | 0.07 % | `BPL $9025` | — |
| `$81AC7F` | M0X0 | 552,992 | 0.06 % | `BNE $AC7F` | `0216` |

**13 loops, 310,681,830 cycles = 33.80 % of the attributed residue.** The `polled` column
is why the table is a candidate list and not an instruction: a `$7E`-bank WRAM operand is
the shape guard 3 can accept, a `$21xx` operand is an MMIO register and is refused whatever
is declared, so the four `$214x` beam polls (~7.2 M cycles) are out by construction.
`$819025` polls a register, not memory, and is the one shape the scan cannot resolve.

Disassembled through the pin's own decoder (`tests/disasm_span.py`), the two declared
candidates are one shape appearing twice:

```
$81:B05D  AF 92 1C 7E   LDA $7E1C92      entry: read the counter
$81:B061  CF 92 1C 7E   CMP $7E1C92  \   the wait, and the PC the compiled
$81:B065  F0 FA         BEQ $B061    /   body yields back to every frame
$81:B067  6B            RTL
$81:EE8E  CF 92 1C 7E   CMP $7E1C92      the same wait in another routine,
$81:EE92  F0 FA         BEQ $EE8E        demanded in M1X0 and M1X1
```

`$7E1C92` is the game's frame counter: in the round-2b r9 framedump corpus it advances by
exactly one every host frame across f16000..f16199, which is the promise IDLE_POLL.md asks
the host to be able to make. Note the shape's exit is a *deadline* cut, not a mid-run
branch: the counter is written by the game's vblank handler, which the frame driver
delivers **after** the LLE run returns (`docs/IDLE_POLL.md`, "Deadline and event
boundaries"), so the wait loop never exits inside a run — the frame boundary ends it.

## 3. The lever, wired up on the title side

`docs/IDLE_POLL.md`'s table is filled in through `interp_bridge_set_idle_poll(pc24)`, max
8 slots, and **no framework host calls it** — `runner/src/desktop/host_main.c` does not, and
neither does the test host. So it is title-owned here: `DeclareIdlePolls()` in
`src/game_rtl.c`, hung on `kGameInfo.initialize`, reading `SNESRECOMP_IDLE_POLLS` (a
comma-separated list of hex PCs; unset or `off` declares nothing). Two PCs are declared in
this round's work, `$81B061` and `$81EE8E`; `$81F007` is deliberately left out, its read is
DB-register-relative so the bus address is not provable from the ROM and `$7E2140` reads 0
at every sampled frame edge.

The default is nothing declared, and that matters twice over: it is what a player runs, and
it is the control for everything below. The round-3 executable's undeclared legs reproduce
the round-2b capture exactly — 226,953,466 insns / 919,307,323 cycles / 956,096,571 cpu
cycles / 7,878,127,092 master cycles, capture 1,750,420 B — so the new code path is inert
until asked, measured rather than asserted.

## 4. Cost: the lever really does remove the wait

One executable, one route, one SRAM seed, legs differing by one environment variable
(`tests/idle_ab.sh`, new; every leg re-arms capture so the share is measured, not inferred):

| leg | declared | frames | exit | interp % of cpu | interp insns | interp cycles | cpu cycles | master cycles |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `off` | — | 22,044 | quit | 96.15 % | 226,953,466 | 919,307,323 | 956,096,571 | 7,878,127,092 |
| `off2` | — | 22,044 | quit | 96.15 % | *identical* | 919,307,323 | 956,096,571 | 7,878,127,092 |
| `m0x0` | `$81B061` | 22,044 | quit | 60.20 % | 173,406,404 | 678,130,192 | 1,126,390,276 | 7,878,127,092 |
| `m1x0` | `$81EE8E` | 22,044 | quit | 88.73 % | 216,934,653 | 878,900,160 | 990,558,327 | 7,878,127,126 |
| `on` | `$81B061` + `$81EE8E` | **21,639** | **until timed out** | 55.13 % | 160,742,293 | 627,692,693 | 1,138,549,946 | 7,733,393,070 |

`off` and `off2` are two runs of the undeclared leg: their captures are byte-identical
(1,750,420 B each), which is the harness determinism check the rest of the table leans on.

The declared waits themselves, per PC, from each leg's own ingest
(`tests/wait_cost.py`, new; the same four PCs summed in every leg, so the legs that declared
nothing are the price of the same waits):

| leg | attributed cycles | `$81B061` | `$81B065` | `$81EE8E` | `$81EE92` | declared total | share |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `off`/`off2` | 919,307,323 | 165,447,390 | 82,703,990 | 26,051,305 | 15,629,359 | 289,832,044 | 31.53 % |
| `m0x0` | 678,130,192 | 3,901,782 | 1,971,872 | 26,051,305 | 15,629,359 | 47,554,318 | 7.01 % |
| `m1x0` | 878,900,160 | 164,371,158 | 82,165,884 | 234,960 | 137,959 | 246,909,961 | 28.09 % |
| `on` | 627,692,693 | 3,822,582 | 1,931,712 | 234,960 | 137,959 | 6,127,213 | 0.98 % |

So replay happens, and it removes ~98 % of the declared waits' interpreted cost. The whole
wait class of §2 follows it down — 33.80 % (`off`, 13 loops) → 30.46 % (`m1x0`, 11 loops)
→ 10.08 % (`m0x0`, 13 loops) → 4.20 % (`on`, 11 loops), re-binned per leg by
`tests/wait_class.py`. The loop count falls by two exactly when `$81EE8E` is declared — its
two loops, demanded in M1X0 and M1X1, both drop under the 300,000-cycle floor (234,960 +
137,959 cycles between the two hot rows) — while declaring `$81B061` leaves all 13 loops
standing, still hot, at a twentieth of their cost. And the single-PC legs are what
say the two waits are independent: declaring `$81B061` leaves `$81EE8E`/`$81EE92` at
*exactly* their undeclared 26,051,305 / 15,629,359 cycles, while declaring `$81EE8E` leaves
`$81B061`/`$81B065` at 164,371,158 / 82,165,884, within 0.7 % of undeclared — that leg's
master total moved +34 cycles, so the loop ran a few fewer times, which is the seam's doing
and not the other wait's.

All of §4 is kept as text at `evidence/artifacts/idle_poll_cost_round3.txt`, generated from
the per-leg logs and ingests named in it.

Host time on the same 22,044-frame route, capture off, turbo, dummy drivers
(`tests/out/spd_off`, `tests/out/spd_m0x0`):

| leg | frame service | fps | cpu_seconds | wall |
| --- | --- | --- | --- | --- |
| undeclared | 31.244 s | 705.5 | 31.018 | 31 s |
| `$81B061` declared | 28.137 s | 783.4 | 26.650 | 29 s |

−9.9 % frame-service, −14.1 % cpu_seconds for a −26 % interpreted-cycle cut: real, but well
short of what the cycle share suggests, because the replay still walks the recorded steps
host-side and the interpreter is not the only cost per frame.

One more cost reading, because it is the one that points at a bug rather than at a win. Guest
`cpu_cycles` divided by host frames, all five legs, from the same reports
(`artifacts/idle_poll_cost_round3.txt`, "guest cpu cycles per host frame"):

| leg | frames | cpu cycles | cycles per host frame |
| --- | --- | --- | --- |
| `off` / `off2` | 22,044 | 956,096,571 | 43,372 |
| `m1x0` | 22,044 | 990,558,327 | 44,936 |
| `m0x0` | 22,044 | 1,126,390,276 | **51,097** |
| `on` | 21,639 (timed out) | 1,138,549,946 | 52,616 (not comparable) |

The declared legs charge the guest **more cycles per frame** (+17.8 % for `$81B061`) while the
same leg spends *less* host time and, for `m0x0`, lands on exactly the undeclared
`master_cycles` (7,878,127,092). So the extra 170,293,705 charged cycles are neither guest
work — interpreted cost fell — nor host work — wall time fell — nor a different number of
machine cycles. They are the seam's arithmetic, and §6 item (2) is what to report about it.

## 5. Behaviour: it does not hold, and it does not hold narrowly

Cost and behaviour are different questions, so they are different harnesses.
`tests/idle_parity.sh` (new) runs the same four legs with `--framedump` and compares the
WRAM crc32 of **every** frame against the undeclared control:

| leg | declared | frames | first divergence | mismatching frames |
| --- | --- | --- | --- | --- |
| `ip_off` | — | 22,044 | — | control |
| `ip_on` | `$81B061` + `$81EE8E` | 21,639 | **f9** | 21,105 / 21,639 |
| `ip_m0x0` | `$81B061` | 22,044 | **f1733** | 20,311 / 22,044 |
| `ip_m1x0` | `$81EE8E` | 22,044 | **f9** | 21,510 / 22,044 |

The narrowest declaration is not the safe one either: `$81EE8E` alone trips it at f9, and
`$81B061` alone survives 1,732 frames and then trips. Verdict: **FAIL**, on every
declaration tried, on the committed route.

`tests/idle_f205.sh` (new) then reads the divergence at byte level over two short routes —
a no-input boot (`tests/scripts/idle_f205.txt`, 210 frames) and a dense-input one
(`idle_dense.txt`, 14 frames) — because "the crc differs" is not evidence, a byte is. Its
artifact directories carry both the route and the declaration
(`tests/out/idle_f205_p81b061_81ee8e`, `tests/out/idle_dense_p81ee8e`, …), which is not
cosmetic: a shared `on` directory here once silently overwrote another leg's dumps.

The per-frame numbers below come from `tests/framedump_diff.py offsets` (per-frame byte
counts) and its new `byte ADDR` mode (one address's value in both legs, frame by frame, plus
a value histogram per leg — equal value sets with the counts shifted is *phase*, a value one
leg never writes is a state change). Both were run over the surviving dump directories and
their output is kept in `tests/out/idle_f205_bytes_r3.log` and
`tests/out/idle_dense_bytes_r3.log`.

* **Boot, pair declared:** first differing frame **f9**, 181 of 210 frames differ — but by
  423 byte-frames in total and never more than 8 bytes in one frame, so a handful of bytes
  moved, the machine did not diverge wholesale. At f9 exactly **one** WRAM byte differs:
  `$7E0012E` = `92` undeclared, `8E` declared, while the polled word `$7E1C92` is `$0001` in
  both. That byte is a phase readout, not a value: over f8..f16 the undeclared leg runs
  `21 92 92 92 8E 92 92 8E 92` and the declared leg runs `21 8E 92 92 8E 92 8E 92 92`. Both
  legs see exactly the same six values across the whole boot (`00 21 25 8E 92 EC`), and their
  histograms differ only by a shift between `92` and `8E` (24/11 vs 22/13). No new value
  appears anywhere; the same bytes land on other frames.
* **The same byte at the onset of the full route.** `tests/idle_parity.sh` now reads its own
  crc verdict the same way, so the parity log carries the byte evidence next to the verdict
  (`tests/out/idle_parity_r3.log`, "the first divergence, read as bytes" and "the onset
  frame's bytes, on a timeline"). For `ip_on` and `ip_m1x0` that onset is f9 and, as on the
  boot route, it is **one byte**: `$7E0012E` `92`→`8E`, polled word `$7E1C92` = `$0001` in
  both. Over the window f0..f39 the value sets are again identical (`00 21 25 8E 92 EC`) with
  `8E` 3→7 and `92` 12→8, and the differing frames are f9, f14, f15, f17, f19–20, f22, f23 —
  scattered, not one constant offset, which is what a phase difference looks like when the
  frame boundary moves by a few cycles rather than a whole frame.
* **`$81B061` alone, on the full route, is not only a phase shift.** Its onset is f1733, again
  exactly one byte, `$7E01C96` `26`→`24`, and over the window f1703..f1763 the two legs'
  histograms are *not* the same multiset: the declared leg writes `27`, which the control
  never writes in that window (`tests/out/idle_parity_r3.log`, the "onset frame's bytes"
  section, which only the full four-leg run with `FULLBYTES=1` prints). A value one leg never
  writes is the definition this harness uses for a state change, so this divergence is not
  only the same writes landing on other frames.
* **And those legs are reproducible from a cold start.** The four-leg parity run was repeated
  (`tests/out/idle_parity_r4.log`) and then `ip_m0x0` was run alone (`LEGS="ip_m0x0"`,
  `tests/out/idle_parity_m0x0_r3.log`); both reproduce the verdict to the digit — f1733,
  20,311 of 22,044 frames mismatched, the same crc32 pair at the onset (`0x94F07F60` /
  `0x8D574912`), the same one byte `$7E01C96` `26`→`24` with `$7E1C92` = `$05D3` in both legs,
  and the same checkpoint rows. `ip_on` (f9, 21,105 / 21,639) and `ip_m1x0` (f9,
  21,510 / 22,044) repeat the same way. So the divergence is the declaration, not a noisy
  run.
* **The clock moves even where WRAM does not.** `tests/framedump_diff.py cpdump` over the
  boot route's two legs: at p195/p200/p203/p205/p210 the guest `frame` matches, and WRAM from
  p200 on is byte-identical, yet `info.json` puts the machine elsewhere in the frame —
  `master_clock` −2, +20, −2, −2, −2 cycles and `hpos` 900→898, 0→0, 34→32, 0→0, 18→16. All
  24 PPU/HDMA register keys match at all five of those checkpoints, `vram/oam/cgram/fb/
  ppuw/dma` match, and only `wram.bin` (at p195) and `apu.tsv` (at every one, because the
  SPC is paced by master time) differ. This is the cleanest falsification available of the
  guard promise: same guest frame index, same PPU state, same WRAM bytes, a different number
  of cycles spent to get there. The dense route says the same from the other side and even
  more cleanly: only 1 of 14 frames differs in WRAM (f9, the same single byte), q005..q008
  are identical including the clock, and from q009 the same frame index carries
  `master_clock` +14, −8, −2, −6, −10, +4 with `hpos` 0→14, 30→22, 10→8, 8→2, 20→10, 10→14 —
  while **all nine images and all 24 register keys are identical** at q009, q011, q012, q013
  and q014. Five of the six moved-clock checkpoints differ in nothing but the clock.
* **The same reading over the whole route, every checkpoint at once**
  (`artifacts/idle_poll_checkpoints_round3.txt`, generated by
  `tests/idle_artifacts.py checkpoints` out of the four parity legs and the four probe
  directories, so none of these rows is hand-typed):

  | leg | checkpoints | clock deltas | images differing |
  | --- | --- | --- | --- |
  | `$81EE8E` | 22 tagged, all at the control's frame index | −26 … +38 | all 22; the narrowest is `wram`+`apu` only (`H8`) |
  | pair | 17 of the 22 — the rest of the route was never reached | −26 … +60 | all 17 |
  | `$81B061` | 22 tagged, all at the control's frame index | −24 … +34, and **+0 at `A1`, `A4`, `A5`** | all 22 |
  | `$81B061`, both probes | 15 tagged | **+0 at every one** | **none**, every dumped byte equal |
  | `$81EE8E` / pair, boot probe | 5 tagged | −2 … +20 | 4 of 5 differ in `apu` alone, 1 in `wram`+`apu` |
  | `$81EE8E` / pair, dense probe | 10 tagged | −10 … +14 | 9 of 10 differ in nothing; 1 in `wram` |

  Three things fall out of that grid. The `+170 M` charged cycles of §4 leave no trace in the
  master timeline even where state differs: at the route's own end, `A5`, the `$81B061` leg
  reports the control's `master_clock` to the cycle (7,878,127,092) while its `wram`, `vram`,
  `oam`, `cgram`, `fb` and `ppuw` all differ. Where the clock has moved and nothing else has
  (five of six dense checkpoints, and `A1`/`A4`/`A5` for `$81B061` in reverse — the clock
  back on the control's, the state not), the two harnesses disagree about what happened
  without disagreeing about any byte. And the two probes are the control group for §7's trap:
  declaring `$81B061` costs 170 M charged cycles on the combat route and changes *nothing at
  all* over 210 boot frames and 14 dense frames, because those routes never reach that wait.
* **Attribution, by declaring one PC at a time:** `$81EE8E` alone reproduces the pair's
  f9 breakage byte for byte — f9, `181/210` frames, 423 byte-frames, max 8 in a frame, the
  same 12 distinct offsets, `$7E0012E` `92`→`8E` in 12 frames, and the same five timing
  rows — so the f9 breakage is `$81EE8E`'s, not `$81B061`'s. `$81B061` alone is clean on
  both short routes — **0 of 210** boot frames and **0 of 14** dense frames differ, every
  checkpoint identical *including `master_clock`* — and on the full route it holds 1,732
  frames and then differs at **f1733 by exactly one byte**, `$7E01C96` = `26` → `24`, with
  the polled word `$7E1C92` = `$05D3` identical in both legs.
* **Full route, at the `A0` checkpoint, which all four parity legs reach at the same guest
  frame (20,730):** `master_clock` is 7,408,545,540 undeclared and 7,408,545,544 / …548 /
  …560 for `$81EE8E` / the pair / `$81B061` (+4, +8, +20), with `hpos` 0 → 4 / 8 / 20 at the
  same `vpos` 225. What a checkpoint actually carries is the guest clock plus **PPU / HDMA
  register state** — `runner/src/state_dump.h` calls `<tag>.regs.json` exactly that, and
  neither it nor `info.json` writes CPU registers, so nothing here can say anything about
  A, X, Y, S, DB or PC, and this record no longer claims it. Of the 24 register keys
  compared at `A0`, exactly four differ in every declared leg, and they are the same four:
  `hscroll`, `vscroll`, the MODE 7 matrix (whose last two entries are those same two
  offsets) and DMA channel 1's transfer address. Per leg, from
  `artifacts/idle_poll_a0_round3.txt`:

  | leg | hscroll | vscroll | m7matrix tail | dma |
  | --- | --- | --- | --- | --- |
  | `off` | `[207,207,0,0]` | `[31,31,0,0]` | `…,207,31` | ch1 `aAdr` `$C6C0` |
  | `$81EE8E` | `[217,217,0,0]` | `[26,26,0,0]` | `…,217,26` | ch1 `$C6C0`→`$B600` |
  | pair | `[226,226,0,0]` | `[24,24,0,0]` | `[4,256,…]`→`[23,512,…]` | ch1, ch3, ch7 |
  | `$81B061` | `[216,216,0,0]` | `[26,26,0,0]` | `…,216,26` | ch1 `$C6C0`→`$B600` |

  The other 20 keys (`bgmode`, `tm`, `ts`, `window`, `mosaic`, …) are identical in all four.
  `sram.bin` and `dma.tsv` match in all four legs, `cgram.bin` matches for the pair and
  `$81EE8E` but not for `$81B061`, and `wram/vram/oam/fb/apu/ppuw` all differ. Same guest
  frame, same SRAM, different clock, and the PPU's own latched position with it: what differs
  is *when the frame boundary fell*, read back afterwards. The pair's row is the one that is
  not only phase — its MODE 7 matrix header changes (`[4,256,…]` → `[23,512,…]`), i.e. the
  scene it is drawing at `A0` is a different one, which is what its 405 lost frames of route
  would predict. `tests/framedump_diff.py cpdump` (new mode) prints all of that, and
  `tests/idle_artifacts.py a0` re-derives it into `artifacts/idle_poll_a0_round3.txt`.

The pair leg also stopped answering the route's WRAM gates: its `until` timed out at
f21,639 and it exited 3 where the control exits 0 at 22,044 frames, i.e. 405 frames of
route lost. (A script `until` timeout does **not** stop the script — it continues to the
next entry, which is why the `on` leg still reached `A0` and still produced a capture. Any
leg that exits 3 has measured less route than the legs it is compared with.)

## 6. How far the mechanism is established, and what is not

Established by the measurements above:

1. The guard set does not hold for this title's frame waits, at two different
   declarations, first visible at frame 9 of a no-input boot.
2. The replay's cycle bookkeeping is not conserved: with `$81B061` declared,
   `interp_cycles` falls by 241,177,131 while `cpu_cycles` **rises** by 170,293,705, against
   a `master_cycles` total and a frame count identical to the control to the last digit.
   Whatever the seam's units are, the CPU clock and the master timeline come apart across
   it, and `m1x0`'s master total overshoots the control's by 34 cycles over the same
   22,044 frames.
3. The difference starts as phase, and stops being only phase. The undeclared and declared
   legs agree on the polled word at every divergence examined (`$7E1C92` identical at f9, at
   f1733 and at p195), and disagree by +4 to +20 master cycles at the `A0` checkpoint while
   still sitting on the same guest frame index — where the guest records its position in the
   frame, those differences become bytes: `$7E0012E` (12 of 210 boot frames, same value
   multiset in both legs), `$7E00128-9` at p195, `$7E01C96` at f1733, and the PPU's own
   latched state at `A0` — hscroll, vscroll, the MODE 7 matrix, the DMA addresses. (No
   checkpoint in this round dumps CPU registers, so no claim is made about them.) And the
   `f1733` divergence is not phase at all: in that window the declared leg writes a value,
   `27`, that the control never writes.

The account those facts support, and this part is *not* proven to the instruction: because
this title's wait exits only at the frame deadline (the counter moves in the vblank handler,
delivered outside the run), the only thing a replay can change observably is *how many
cycles the wait consumes before the run ends* and *which instruction it ends on* — and (2)
says exactly those two things do change. What the pin establishes is only that the replay
path is inside the loop that pays for time, not outside it: the replay site calls the same
display-refresh charge the ordinary step paths do (`snes_refresh_charge()`,
`runner/src/common_cpu_infra.c:890`, +40 master cycles per 1364-cycle scanline crossed,
called at `runner/src/snes/interp_bridge.c:1723`, `:2143` — the idle-replay site — and
`:2733`), so a replayed wait decides *when inside the frame* that tax is paid. What it does
**not** license is a claim that the phase state gets lost here: the pin carries it in the
rollback residue (`refresh_phase` / `refresh_charged_upto`, `runner/src/common_rtl.c:1164`,
captured at `:1296`, applied at `:1316`, reset at `:510`) — that file's own comment says the
opposite used to be true and was fixed — and this route loads SRAM once at start and never
save/loads mid-run, so this round has no evidence about that path either way. Nor is the tax
the arithmetic of the deltas we measured: a scanline charge moves the clock in steps of 40,
and the checkpoint deltas are +4/+8/+20. The claims that rest on measurement alone are the
table in §4 and the bytes in §5: a declaration moves `interp_cycles`, `cpu_cycles` and the
resume point, and the guest then records a different position in the frame.

IDLE_POLL.md's sufficiency argument is the sentence "The CPU cannot observe the difference:
the replayed cycle reads no MMIO (guard 3), no IRQ can be taken (guard 6), and HDMA cannot
write the polled memory (guard 8)" — and the measured answer is that the CPU can observe it
through the cycle count and the resume point, not through the read.

Guard 6 is worth naming precisely, because it is the one that reads as covering this case
and does not: it refuses replay when `I` is clear at some step *and* an H or V **timer** is
armed (`bridge_idle_replay_allowed`, `runner/src/snes/interp_bridge.c` at the pin). The
vblank NMI is a different event and is not part of that condition; here `I` stays set, so
the guard passes. What would make this title replay-safe, in order of how little it asks of
the framework:

* make the replay's cycle and resume accounting exactly equal to what interpreting the same
  window costs — measurable as `cpu_cycles` and `master_cycles` both unchanged by a
  declaration. This is the symptom (2) above, and it is the one to report upstream: a
  declaration that changes `cpu_cycles` by +170 M on a fixed master timeline is a bug in the
  replay seam, not a property of the game.
* or re-check the poll's own exit condition each replayed step instead of only at the
  deadline, which for this shape costs the speedup back (the loop's exit is unreachable
  mid-run anyway, so it is cheap to state and probably useless here).
* or have the guard set treat a pending/enabled vblank NMI as an event the wait cannot be
  run past, which for a frame-synchronisation poll refuses the whole class — the honest
  outcome for this title.

Not tested, and it is the falsifiable follow-up if the lever is ever revisited: a wait whose
polled byte is written by *main-loop* code rather than by an interrupt handler should be
replay-safe under the current guards. All 13 loops in §2 poll bytes the game only touches
at frame events, so no declarable wait of that other shape is known in this title.
`BIN=<pin-built exe> ./tests/idle_parity.sh` (§10) is the one-command retest at any new pin.

## 7. A trap this opens in the existing baselines

`execution_share.aot_cycle_pct` is computed as "everything not interpreted", and replayed
cycles land on that side of the line: on an unchanged generated set, declaring the pair moves
`aot_cycle_pct` from **3.85 % to 44.87 %** (and `$81B061` alone to 39.80 %) without one byte
of the generated set changing. Every existing consumer of that column —
`tests/aot_share.py`, `tests/baselines/*`, the promotion records' "AOT share" claims — reads
a promotion that did not happen. Keep `SNESRECOMP_IDLE_POLLS` unset for any baseline run,
and treat a large AOT share on an unchanged gen set as the signature of declared polls.

## 8. No run has to be told where the ROM is (and one that was, was caught)

The user-facing defect this round removed: scripted legs kept opening the ROM file picker.
The host resolves a dump as launcher → `--rom`/positional → a `.sfc` beside the executable →
`rom.cfg` beside the executable → **GUI file picker**; the last one is the failure mode, and
both causes were the harness's own: legs that copy the binary into a fresh anchor under
`tests/out` (which has no `rom.cfg`) and legs that pass no `--rom`. So `tests/rom.sh` (new)
is now the single answer to "which ROM does this binary open" — `sr_rom` returns the
validated absolute path, `sr_rom_stage <anchor>` writes the cache beside a copied binary —
and every launcher script in the kit (`play.sh`, `headless.sh`, `selfcheck.sh`, `shots.sh`,
`parity.sh`, `crosspath.sh`, `gate_probe.sh`, `cart_trace_neutral.sh`,
`collect_read_traces.sh`, `bisect_aot.sh`, `idle_ab.sh`, `idle_parity.sh`, `idle_f205.sh`)
carries `--rom` *and* stages the anchor, so a typo in either cannot resurrect the picker.
`tests/make_lle_floor.sh` never launches the game, so it needs neither. `./tests/selfcheck.sh`
passes on the changed kit: `PASS: rom executed, tick counter advanced (exit 0)`, with
`rom resolved: …/Shadowrun (USA).sfc` at +0.013 s.

The picker is also a provenance hazard, measured the hard way while writing this: one ad-hoc
leg sourced `tests/rom.sh` from zsh, where `BASH_SOURCE` is unset, so the repo root resolved
one directory too high, `--rom` came out empty, and the panel sat on screen for 77 s before
answering with `/Users/wee/Documents/Shadowrun (USA).sfc` — a *different file* from the
checkout's copy. It happened to be the same bytes (`sha256 e6bc0a595d5c…`), which is luck,
not a contract; the capture's `rom_sha256` field is what would have caught a mismatch.
`sr_root()` now locates the root by the nearest ancestor holding `framework_pins.txt`
instead, and works sourced from bash or zsh, from the root or from `tests/`.

## 9. Decision record for the round

* **The idle-poll lever is measured and not adopted.** `src/game_rtl.c` keeps
  `DeclareIdlePolls()` because it is the only host that can fill the table at all, and it is
  inert by default; `SNESRECOMP_IDLE_POLLS` is unset in the committed harnesses except in
  the legs that name what they declare. No title default declares anything.
* **Round 2b's open question is answered, and answered against us on both sides.** The
  residue is not reachable from the entry side as a seed (3.06 % seedable, 96.94 % never
  sighted, zero sightings on the five hottest PCs), and the one non-seed entry lever the
  framework offers changes guest state on this title, so it is not adoptable as-is either.
* **What is worth taking to the framework's owner** is not "the lever does not work" — it
  demonstrably does, 98 % of the declared waits' interpreted cost gone — but the replay
  seam's cycle bookkeeping: same route, same frame count, same `master_cycles`, +170 M
  `cpu_cycles`, and a one-byte WRAM divergence at frame 9. Reproduction is the two
  `tests/idle_ab.sh` lines in §10 — the undeclared legs there must first reproduce the
  round-2b control counters exactly.
* **Promotion state is untouched**: 40 `[[func]]` seeds, 269 nodes / 47 roots / 252 rows,
  AOT share 3.94 %, horizon f16125, baselines unmodified. The title's interpreted residue
  stands at 96.15 % of cpu cycles on the committed route, of which 31.53 % is two
  frame-counter waits that the framework can currently only replay by changing the game.

## 10. Reproduce

```sh
# the capture (§1) — capture-capable exe is the round-2b one:
. tests/rom.sh; rom=$(sr_rom)
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
SNESRECOMP_TIER2_MANIFEST="$PWD/tests/out/idle_off_cov.json" \
  ./build-r2b/ShadowrunSNESRecomp --no-launcher --rom "$rom" --coverage-capture=on \
  --script "$PWD/tests/scripts/combat.txt"
python3 <pin>/tools/tier2_ingest.py --json --cfg-dir recomp \
  --program-manifest src/gen/program_manifest.json <export>.json \
  > evidence/artifacts/tier2_capture_round3_combat.json
python3 tests/coverage_gaps.py evidence/artifacts/tier2_capture_round3_combat.json  # 3.06 / 96.94
SNESRECOMP_ROOT=<pin> python3 tests/wait_class.py evidence/artifacts/tier2_capture_round3_combat.json 300000
SNESRECOMP_ROOT=<pin> python3 tests/disasm_span.py 81b05d 5 0 0        # the wait's shape (§2)

# cost A/B (§4) — poll-capable exe, and the undeclared legs must reproduce §1:
#   first line runs off/off2/on, second runs the two single-PC legs. Bare labels
#   (anything but `on`) declare nothing; `on` declares $IDLE_POLLS.
BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_ab.sh
LEGS="m0x0:81b061 m1x0:81ee8e" BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_ab.sh
python3 tests/wait_cost.py off=tests/out/idle_off_ingest.json on=tests/out/idle_on_ingest.json  # the §4 wait table

# behaviour parity (§5): FULLBYTES=1 makes the harness also print the whole-route
# byte shape of each divergence (framedump_diff offsets/byte), TRIM=1 gives back
# the ~2.9 GiB/leg of per-frame dumps afterwards; the log keeps both readings.
FULLBYTES=1 TRIM=1 BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_parity.sh   # ip_off ip_on ip_m0x0 ip_m1x0
# the determinism check behind §5's last bullet — the whole matrix repeated, and then
# one leg alone; both give the same first-divergence frame and mismatch counts:
FULLBYTES=1 TRIM=1 BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_parity.sh   # again -> idle_parity_r4.log
LEGS="ip_m0x0" TRIM=1 BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_parity.sh
# byte level, one leg pair per declaration; artifact dirs are named by route and
# declaration, so the pair/m0x0/m1x0 legs cannot overwrite each other's dumps:
for p in 81b061,81ee8e 81b061 81ee8e; do
  IDLE_POLLS=$p SCRIPT=tests/scripts/idle_f205.txt  BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_f205.sh
  IDLE_POLLS=$p SCRIPT=tests/scripts/idle_dense.txt BIN=build-r3/ShadowrunSNESRecomp ./tests/idle_f205.sh
done                       # f9 = $7E0012E 92->8E, and 81b061 alone is clean on both routes
# the shape of the difference across every frame, which is what says phase not state:
python3 tests/framedump_diff.py offsets tests/out/idle_f205_off tests/out/idle_f205_p81b061_81ee8e
python3 tests/framedump_diff.py byte    tests/out/idle_f205_off tests/out/idle_f205_p81b061_81ee8e 0012E
python3 tests/framedump_diff.py byte    tests/out/ip_off tests/out/ip_m0x0 01C96 1700 1760   # the f1733 byte
python3 tests/framedump_diff.py cpdump  tests/out/ip_off tests/out/ip_m0x0 A0                # one checkpoint pair

# the three text artifacts, each read back out of the files above (nothing in them is
# hand-typed, so a number that no longer reproduces is a broken claim, not a typo):
python3 tests/idle_artifacts.py cost         > evidence/artifacts/idle_poll_cost_round3.txt
python3 tests/idle_artifacts.py a0           > evidence/artifacts/idle_poll_a0_round3.txt
python3 tests/idle_artifacts.py checkpoints  > evidence/artifacts/idle_poll_checkpoints_round3.txt

# host time (§4, capture off):
. tests/rom.sh; rom=$(sr_rom)
for polls in "" 81b061; do SNESRECOMP_IDLE_POLLS=$polls SDL_VIDEODRIVER=dummy \
  SDL_AUDIODRIVER=dummy ./build-r3/ShadowrunSNESRecomp --no-launcher --rom "$rom" \
  --script "$PWD/tests/scripts/combat.txt" | grep 'frame service'; done

# the default path is still the round-2b control:
./tests/selfcheck.sh                                                  # PASS, exit 0
python3 tests/provenance.py pin build-r3/ShadowrunSNESRecomp          # pin 773285b8210f…
grep -l -- '--no-launcher' tests/*.sh | xargs grep -L -- '--rom'      # empty: no leg may ask (§8)
```

Scratch, not committed: `tests/out/idle_{off,off2,on,m0x0,m1x0}` (captures, ingests,
`last_run_report.json`), `tests/out/idle_off_cov.json` (the §1 capture export),
`tests/out/ip_{off,on,m0x0,m1x0}`, `tests/out/idle_f205_{off,p81b061,p81ee8e,p81b061_81ee8e}`
and `tests/out/idle_dense_{off,p81b061,p81ee8e,p81b061_81ee8e}` (the §5 byte-level legs),
`tests/out/spd_{off,m0x0}`, and the logs `idle_ab_r3.log`, `idle_ab_singles_r3.log`,
`idle_parity_r3.log`, `idle_parity_m0x0_r3.log`, `idle_f205_{pair,m0x0,m1x0}_r3.log`,
`idle_dense_{pair,m0x0,m1x0}_r3.log`, `idle_parity_r4.log`, `idle_{f205,dense}_bytes_r3.log`,
plus the per-leg run logs (`ip_*.log`, `idle_{off,off2,on,m0x0,m1x0}.log`,
`idle_{f205,dense}_{off,p*}.log`).
Only the parity legs ran with `TRIM=1`, which deletes `frame_*` files and nothing else: each
of `ip_*` keeps its tagged checkpoint dumps (`<tag>.info.json`, `<tag>.regs.json`, the six
images, `A0.fb.bmp`) and its `<tag>.json` crc lines, which is everything
`tests/idle_artifacts.py` and `framedump_diff.py cpdump` read, and those three artifacts
regenerate byte-for-byte from the trimmed directories as they sit now. The probe legs are
210 frames and 14 frames long, so their per-frame dumps are kept whole (~36 MB/leg) — that
is where the §5 f9 byte evidence lives.
