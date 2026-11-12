# B0: which ROM bytes the game reads at runtime, and who reads them

Measured 2026-11-06. In one line: **every instruction byte the interpreter gave
up on six routes came from the bottom 61 KiB of the image — 45 KiB carries a
fetch mark and nothing above physical `0x00F3FF` (`$81:F3FF`) was ever fetched —
71 % of 2.79 billion reads land in 4 KiB of that, and 62.6 % of the image was not
read at all. But 200 of the 206 promoted entry points sit in blocks that also
carry fetch traffic, which is the measurement saying a 512-byte decision is too
coarse to plan an extraction with. Joining the trace to the recompiler's own
analysis manifest is what fixes that: the interpreted residue is **26 blocks —
13 KiB — inside no analysed span, 98.8 % instruction fetch, 38.9 % of all the
reads**, and there is a named path (cfg entry plus regeneration) to shrink it.**

Plain language first, then numbers.

## What this feeds

M1 is the go/no-go on moving guest data out of the cart file and into host-side
tables. To decide it, the port needs to know which ROM bytes the running game
actually reads, which of those are instructions, and how much of the traffic is
DMA. Nothing in the framework answered that before this round. The observer that
does it is one env variable (`SNESRECOMP_CART_TRACE`), one commit
(`48d2d1b7`) off the pinned framework on branch `feat/cart-read-trace` — never
pushed, and zero cost when the variable is unset.

## How it was measured

| thing | value |
| --- | --- |
| build under test | `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-b0/ShadowrunSNESRecomp` — sha256 `33747276272ae9e6…`, 3,312,288 B |
| control build | `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/build-pin/ShadowrunSNESRecomp` — sha256 `09b317eba13353e6…`, 3,294,704 B, framework a git checkout of the pin, no observer at all. The control used by the first version of this round, `build-ctrl` (`3a9f15ec33693fe8…`), was configured against a **copy** of the framework that predates the pin; it is superseded and `tests/cart_trace_neutral.sh` now refuses it (`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c1c_framework_copy.md`) |
| generated set (both) | 17 units, 205 promoted guest functions, 217 dispatch entries, `src/gen` sha256 `24df45247dc21b36` |
| framework source | `/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-b0` at `48d2d1b7` (one commit off pin `773285b8`) |
| schema | `snesrecomp.cart-trace.v2`, `seams: cpu_read8,cpu_read16,cart_read,dma_abus,interp816_fetch` |
| routes | `selfcheck` 276 f, `menu` 1,245 f, `nav1` 16,188 f, `nav2` 18,401 f, `combat` 25,902 f, `door` 14,641 f |
| collector | `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/collect_read_traces.sh` |
| report | `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/cart_trace_report.py` → `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/b0/report.md` |
| traces | `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/b0/*.json` (2.7 MB total, not committed — `.gitignore` already excludes `tests/out/`) |

This is the shipped AOT build, so both paths are in play in one set of numbers:
the counts include what recompiled code reads as data *and* what the interpreter
still runs.

## Totals

| route | ROM reads | CPU | DMA | instruction-stream reads | fetch share | distinct pairs | blocks touched |
|---|---:|---:|---:|---:|---:|---:|---:|
| combat | 921,317,878 | 919,016,826 | 2,301,052 | 611,733,580 | 66.4 % | 24,228 | 765 |
| door | 550,013,957 | 548,883,861 | 1,130,096 | 357,334,926 | 65.0 % | 17,738 | 483 |
| menu | 38,258,200 | 37,996,056 | 262,144 | 27,872,467 | 72.9 % | 2,583 | 149 |
| nav1 | 598,297,144 | 597,111,592 | 1,185,552 | 391,198,672 | 65.4 % | 18,849 | 507 |
| nav2 | 669,676,961 | 668,145,417 | 1,531,544 | 439,480,162 | 65.6 % | 23,132 | 724 |
| selfcheck | 8,423,454 | 8,292,382 | 131,072 | 6,167,123 | 73.2 % | 885 | 32 |
| **six routes** | **2,785,987,594** | **2,779,446,134** | **6,541,460** | **1,833,786,930** | **65.8 %** | — | 765 merged |

Two things to hold onto: DMA is **0.235 %** of everything read, and two thirds of
every read is the interpreter taking an instruction byte out of the cart. The
interpreter is not a vestigial path in the shipped build — 1.83 billion
instruction bytes came from the ROM across these six runs.

The combat route's block set is a superset of every other route's, at 512-byte
granularity, for both "read at all" (765 = the union) and "fetched" (88 = the
union). One long route already bounds the others here, which is convenient and
slightly suspicious — it says these routes are not very different from each other
in what they touch.

## The seam was wrong before it was right

The first version of the observer watched `cart_readLorom` / `cart_readHirom`
plus the DMA A-bus, on the assumption that ROM reads funnel through `cart_read`.
On the 1,245-frame menu route that build reported **264,368 reads, of which
262,144 were DMA and exactly 0 were instruction fetches.** Zero fetches is the
tell: that route executes tens of millions of instructions, all fetched from
ROM. The guest CPU does not call `cart_read` for ROM — `cpu_read8` / `cpu_read16`
resolve the mapping through `RomPtr()` / `cart_getRomPtr()` and dereference the
pointer.

Re-measured on the same route with the seams at `cpu_read8` / `cpu_read16` (ROM
branches), the `cart.c` ROM-hit branches, `dma.c`'s A-bus window and
`interp816_readOpcode`: **38,258,200 reads, 37,996,056 of them from the CPU bus,
27,872,467 marked as instruction-stream reads** — three orders of magnitude
apart. Schema v2 names its seams in the file, because a consumer holding a
partial trace has no other way to notice it is holding one.

## Instruction traffic is confined to the bottom of the image

At 512-byte block granularity, merged over the six routes:

| set | blocks | bytes | share of the 1 MiB image |
|---|---:|---:|---:|
| read at all | 765 | 391,680 | 37.4 % |
| — of which fetched as instruction bytes | 88 | 45,056 | 4.3 % |
| — of which read by address, never fetched | 677 | 346,624 | 33.1 % |
| never read by anything | 1,283 | 656,896 | **62.6 %** |

The fetched set does not scatter: all 88 blocks fall inside physical
`0x000000`–`0x00F3FF`, in eight runs —

| physical | bus | size |
|---|---|---:|
| 000000-0053FF | $80:8000-$80:D3FF | 21 KiB (42 blocks) |
| 005E00-0063FF | $80:DE00-$80:E3FF | 1 KiB (3) |
| 007200-0097FF | $80:F200-$81:97FF | 9 KiB (19) |
| 009A00-00A5FF | $81:9A00-$81:A5FF | 3 KiB (6) |
| 00A800-00B1FF | $81:A800-$81:B1FF | 2 KiB (5) |
| 00D400-00D7FF | $81:D400-$81:D7FF | 1 KiB (2) |
| 00DC00-00E7FF | $81:DC00-$81:E7FF | 3 KiB (6) |
| 00EA00-00F3FF | $81:EA00-$81:F3FF | 2 KiB (5) |

and the per-bank table, which unlike the pair table is never truncated, shows the
`f` mark in three bus banks on **every** route: `$80`, `$81`, and `$00` — which is
the LoROM mirror of physical bank 0, so those are boot-time fetches through the
mirror. No bank above `$81` ever gave up an instruction byte.

And the largest never-touched runs, which is where an extraction would start:

| physical | bus | size |
|---|---|---:|
| 090E00-09F9FF | $92:8E00-$93:F9FF | 59 KiB |
| 042C00-04BFFF | $88:AC00-$89:BFFF | 37 KiB |
| 032800-03A1FF | $86:A800-$87:A1FF | 30 KiB |
| 0F0A00-0F63FF | $9E:8A00-$9E:E3FF | 22 KiB |
| 0E8600-0EDDFF | $9D:8600-$9D:DDFF | 22 KiB |
| 09FC00-0A49FF | $93:FC00-$94:C9FF | 19 KiB |
| 075400-0791FF | $8E:D400-$8F:91FF | 15 KiB |
| 0A7400-0AB1FF | $94:F400-$95:B1FF | 15 KiB |

1,283 never-read blocks in 160 runs — the long tail is 152 runs of under 14 KiB
each, which is what "mostly scattered" looks like at this granularity.

## Where the reads actually go

The traffic is far more concentrated than the footprint suggests. Merged over the
six routes, all 2,785,987,594 reads:

| physical | bus | reads | share | `via` | frames |
|---|---|---:|---:|---|---|
| 00B000 | $81:B000 | 628,704,912 | 22.57 % | `cf` | 1712-25901 |
| 003200 | $80:B200 | 304,711,164 | 10.94 % | `cf` | 1767-25901 |
| 00EE00 | $81:EE00 | 261,904,344 | 9.40 % | `cdf` | 1-25260 |
| 003600 | $80:B600 | 239,774,540 | 8.61 % | `cf` | 1767-25901 |
| 002A00 | $80:AA00 | 151,367,723 | 5.43 % | `cf` | 1765-25901 |
| 007400 | $80:F400 | 132,954,923 | 4.77 % | `cf` | 1766-25901 |
| 002E00 | $80:AE00 | 132,346,567 | 4.75 % | `cf` | 1765-25901 |
| 003000 | $80:B000 | 125,238,136 | 4.50 % | `cf` | 1765-25901 |

**Eight blocks — 4 KiB — carry 71.0 % of all reads; twenty blocks — 10 KiB —
carry 93.3 %.** All of them are in the bottom 61 KiB. For a ROM-free build that
is the number that matters: the hot read set is small enough to hold in host
tables, and the question is only whether the cold remainder can also be answered
without the file.

Two readings of that table worth spelling out:

- `00B000` is the single hottest block and it is not a leaf: it holds eight
  promoted entry points (`bank_81_B020_M0X0`, `…_B05D`, `…_B068`, `…_B079`,
  `…_B0D6`, `…_B0E8`, `…_B130_M1X0`, `…_B167_M0X0`) *and* carries fetch traffic.
  Combat alone read it 238,950,614 times, door 100,065,036, nav1 130,149,548,
  nav2 159,539,714. So a 512-byte window holds code the recompiler compiled and
  code the interpreter ran, both hot — exactly the case where a block-level join
  cannot say which is which.
- The other seven blocks fall into two groups, and the frame windows say so.
  `$80:AA00`, `$80:AE00`, `$80:B000`, `$80:B200`, `$80:B600`, `$80:F400` and
  `$81:B000` are read **only on the four long routes** and start at frames
  1712-1767 in every one of them — combat 1712/1765/1766/1767, door the same,
  nav1 the same, nav2 the same — while the 1,245-frame menu and 276-frame
  selfcheck never reach them. The frozen routes share a scripted prefix, so that
  onset is the point in the title/intro sequence where the in-game loop starts.
  Four routes agreeing to the frame is also a useful check on the observer's
  frame-window bookkeeping. `$81:EE00` is the odd one out: read from frame 1 on
  **all six** routes, DMA-marked (`cdf`), which fits a table the very first
  frames already consult.

## The join against promoted code

The observer cannot see recompiled code fetch anything — host functions need no
bytes from the cart — so the promoted-function list is what makes "not fetched"
mean something. Against the entry points the port names in
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/src/gen` (via
`cpu_trace_func_entry`) and `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/recomp/*.cfg`:
207 known, 206 promoted.

| the entry point's block was… | entries |
|---|---:|
| fetched on at least one route | **200** |
| read but never fetched (`via: d`) | 2 |
| not read at all | 4 |

and **32 of the 88 fetched blocks (16 KiB) hold no promoted entry point** — code
the interpreter still ran and the recompiler has not compiled, so a ROM-free
build either keeps those bytes fetchable or promotes them.

The 200 is the number to read carefully, because it is **not** "200 functions ran
twice". A generated unit records a function's *entry*, not its extent, so a
block-level join cannot separate a promoted routine's own bytes from a neighbouring
routine's traffic inside the same 512 bytes. What 200 of 206 means is that promoted
and interpreted code interleave at finer than 512 bytes, and therefore the
extraction list cannot be cut from this trace and the promoted list alone. It can
be cut from this trace and the recompiler's own analysis, which does keep a
byte-covering shape — see the next section. That is the finding that changes M1's
shape.

The six entry points whose blocks carry no instruction traffic are the clean
case — on these routes nothing read their bytes from the cart:

| physical | bus | entry point | block traffic |
|---|---|---|---|
| 00A772 | $81:A772 | bank_81_A772_M0X0 | 10,880 reads, via `d` |
| 00A7FC | $81:A7FC | bank_81_A7FC_M0X0 | 10,880 reads, via `d` |
| 00D839 | $81:D839 | bank_81_D839_M0X0 | none |
| 00D8A2 | $81:D8A2 | bank_81_D8A2_M0X0 | none |
| 00D8E4 | $81:D8E4 | bank_81_D8E4_M0X0 | none |
| 00E8A6 | $81:E8A6 | bank_81_E8A6_M0X0 | none |

A floor on the fetch counter, from a different axis: for a fetch the pair's
reading PC is the fetched byte's own address, so the number of pair rows carrying
`f` lower-bounds the number of distinct fetched addresses — 16,641 (combat),
16,689 (nav2), 16,303 (nav1), 15,496 (door), 2,029 (menu), 747 (selfcheck), in
bus banks `$00` (1,004 rows), `$80` (36,392) and `$81` (30,509). Those are floors
on truncated tables: combat and nav2 hit the 20,000-row cap.

## The same question against the analyzer's own manifest

The trace cannot say where a routine ends, but the recompiler's analysis keeps a
shape that is close:
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/src/gen/program_manifest.json`
(format v3, written by `tools/regen.sh`) has one node per `(PC, M, X)` the analyzer
reached — **226 nodes, 9 roots, 8,621 instructions**, each with a bounding
`[min_pc24, max_pc24]` span. Those spans cover **19,888 B in 66 blocks** (33 KiB,
3.2 % of the image). Joining that to the trace is the only extents-like statement
available in this project, and the two counts that look comparable are not: 207
entry points / 206 promoted is what the generated C *calls*, 226 is what the
analyzer *proved*, and neither is a subset relation the reader should check.

| manifest span blocks that are… | blocks |
|---|---:|
| fetched on a route | 62 |
| read but never fetched | 1 |
| never read on these routes | 3 |

and the number that matters:

**Fetched blocks inside no manifest span: 26 blocks = 13 KiB, carrying
1,084,397,942 reads = 38.9 % of all ROM reads.**

That is the promotion frontier — the interpreter demonstrably takes instruction
bytes there, and nothing in this project has ever analysed those addresses as
code. It sits in nine runs, dominated by two:

| physical | bus | bytes | reads | of which fetch | of which by address |
|---|---|---:|---:|---:|---:|
| 002C00-0039FF | `$80:AC00-$B9FF` | 3,584 | 911,958,913 | 901,604,832 | 10,354,001 |
| 007400-0077FF | `$80:F400-$F7FF` | 1,024 | 141,308,239 | 138,929,631 | 2,378,510 |
| 000000-0003FF | `$80:8000-$83FF` | 1,024 | 13,130,909 | 13,043,361 | 87,412 |
| six smaller runs (15 blocks) | `$80`, `$81` | 7,680 | 17,999,881 | 17,306,045 | 691,863 |
| **frontier total** | | **13,312** | **1,084,397,942** | **1,070,883,869** | **13,511,786** |

The last two columns come from the pair rows rather than the block table, so they
are floors (combat and nav2 hit the 20,000-row cap) — but the *ratio* survives a
cut that drops whole `(reading PC, block)` keys, and it says the frontier is
**98.8 % instruction-stream traffic**. This is not constants that happen to sit in
a code bank; it is the interpreter fetching instructions from addresses no analysis
covered. Which makes it a promotion job, and a bounded one: 13 KiB of named ranges,
plus 12 nodes (7 blocks) the analyzer already proved and deliberately left
`lle_only` — those need a cfg decision, not new analysis.

Two errors in this join, both pointing the conservative way, so the frontier is a
floor and not a guess:

- a node's span is a bounding box between its lowest and highest PC, so a table in
  the middle of a routine marks that block as analysed;
- analysis is seeded by `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/recomp/symbols.toml`,
  so "inside no span" means *unanalysed*, not proven to be data.

One bank note, because it bounds what promotion buys: 25 of the 26 blocks are in
physical bank 0, which bus bank `$80` aliases, and `$00` is read on every route.
Promoting those bytes removes interpreted traffic; it does not remove the cart.

Acting on the frontier needs no new framework capability — `[[func]]` entries at
those addresses and a regeneration — and it can be done here: the analyzer runs as
a stamp-verified prebuilt against the pinned CLI, 7.9 s a round, and that round
reproduces the committed `src/gen` byte for byte, so a symbols edit's effect is the
only thing a diff can show (`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c1c_framework_copy.md`,
§The pin reproduces `src/gen` byte for byte). What is *not* available is rebuilding
the analyzer from source, which wants network for `serde_json`.

## Is the observer inert? measured two ways, on two routes

Two separate questions, in
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/cart_trace_neutral.sh`:
**off vs ctrl** (does adding the seam to the framework change what a player runs?)
and **on vs off** (does arming the collector change it?). A build can pass one and
fail the other. The measure is the per-frame WRAM crc32 that `tests/parity.sh`
uses, and a same-binary comparison there is byte-exact, not phase-tolerant.

| route | frames | ctrl / off | off / on |
|---|---:|---|---|
| menu | 1,245 | identical, 0 mismatches | identical, 0 mismatches |
| combat | 25,902 | identical, 0 mismatches | identical, 0 mismatches |

Both numbers above come from a re-run against a control that is provably at the
pin — `build-pin/ShadowrunSNESRecomp`, 3,294,704 bytes, sha256
`09b317eba13353e6…`, framework root `sr-pin` at `773285b8`, built with the same
compilers as the observer leg (`gcc-16` / `g++`). Logs
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/ct_neutral-pin-menu.log`
and `…/ct_neutral-pin-combat.log`; the verdict lines are also written to
`tests/out/ct_neutral/verdict.txt`. The original pair, same routes and the same
verdicts, ran against a control that was **not** at the pin; what changed, and the
gate that now refuses that control, is
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c1c_framework_copy.md`.

The two legs of each pair differ in exactly one input, and the gate prints that
audit next to the verdict rather than leaving it to be assumed:

| leg | exe | framework source |
|---|---|---|
| ctrl | `09b317eba13353e6…` | the pin, `773285b8`, clean git checkout, no observer |
| off, on | `33747276272ae9e6…` | `sr-b0`, rev `48d2d1b7`, clean tree — the pin plus the observer |

Three extra facts that fell out of doing it in this order:

- The gate now checks the control *before* running any leg
  (`tests/provenance.py pin --exact`), and prints the check into the verdict file,
  so "identical frames" is no longer quietly compatible with "the control linked
  some framework". The observer leg is checked with `--descendant`, which is what
  a capability branch off the pin has to be.
- The menu run happened while the framework commit was still `de9a806b`; the
  combat run ran after a documentation-only amend to `48d2d1b7`. Both report the
  **same executable sha256**, `33747276272ae9e6…`, and rebuilding `build-b0`
  touched 0 C objects. So the numbers above belong to the committed tree's code,
  and the binding is not "I promise the code didn't move".
- The combat run's `on` trace is **byte-identical** (`cmp`, 2,712,742 bytes) to
  `tests/out/b0/combat.json`, collected in a separate process, from a different
  working directory, minutes earlier, and again in the re-run against the pinned
  control. Schema v2 deliberately writes no timestamp, so the aggregate file —
  including which 20,000 pairs survived the cap — is a pure function of the run.

Framework side, the same tree was checked against the pin's C suite
(`/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/c-tests-b0-v4.log`
vs `…/c-tests-pin.log`): **27 sections vs 26**, the only addition
`=== ROM-read observer ===` with **40 checks (33 on the main leg, 7 on the
truncation leg)**, zero `FAIL` lines, and both trees stopping at the same missing
`lib/recomp-net` checkout.

## Two bugs this round found in the tooling, not the game

Both are worth recording because both produced *plausible* tables:

1. **The framework dump wrote invalid JSON on long routes.** The truncation flag
   was emitted as `], "pairs_truncated": true` with no comma joining it to the
   next field, so every route past the 20,000-pair cap died mid-decode in the
   port's reader — `combat.json` and `nav2.json` were unreadable. The truncation
   gate now asserts the flag, the comma, that the file still parses, and that the
   totals still count the reads the truncated list leaves out.
2. **The report looked up blocks in the wrong key space.** `blocks` is keyed by a
   block's starting *offset* (`0x01E800`); the join used *block numbers*, so every
   lookup missed and the table printed "206 promoted entry points, **none** of
   them ever read" — the opposite of the truth, and it looked like a finding.
   Fixed, and the report now aborts on a trace whose block keys are not
   512-aligned instead of printing an empty join.

The manifest join, added the same round, found two more of the same species:

3. **Operator precedence in a unit conversion.** `100 * blocks * 512 // 1024`
   printed `3250 KiB` where the answer was 32 KiB: the `100 ×`, which belongs to
   the percentage, was scaling the bytes before the division. The percentage and
   the KiB figure now come from separate expressions.
4. **`lle_only` counted as a gap.** The analyzer marks 12 nodes `lle_only`: it
   proved them and chose to leave them interpreted. Treating those spans as
   "not analysed" inflated the frontier to 27 blocks / 1,084,398,838 reads and
   made a cfg decision look like a discovery. They belong in the analysed set;
   the frontier is 26 blocks / 1,084,397,942 reads.

Both times the wrong version was the one that produced a *bigger, more exciting*
number, which is the reason the report keeps its honesty fields visible rather
than in a debug flag.

## Bounds that were reached, honestly

- `ring_wraps` on every route (514 to 56,232, total 170,041): the 16,384-entry
  recent-traffic sample rolled over. It affects nothing else — `blocks`, `pairs`
  and the totals are complete.
- `pairs_truncated` on combat (24,228 distinct pairs) and nav2 (23,132) against
  the 20,000-row cap: the reading-PC table is short on those two, the totals and
  the block table are not. Which is also why every claim about the fetched set
  above is made from the block and bank tables.
- `pair_overflows`, `tail_reads`, `rom_resets`: all zero — the pair hash never had
  to drop a key, no read arrived while the tables were being torn down, and the
  ROM image was never swapped mid-run.

## What M1 can and cannot conclude from this

Can:

- the interpreted code footprint is bounded and small — 45 KiB of fetch marks, all
  inside the bottom 61 KiB of the image, and nothing else took an instruction byte
  on these routes;
- the read traffic is concentrated, not spread: 4 KiB of blocks carry 71.0 % of
  all reads and 10 KiB carry 93.3 %, all inside that same bottom 61 KiB. A
  host-side representation of the hot set is a small table, not a copy of the
  image;
- 62.6 % of the image is untouched by these routes and another 33.1 % is read only
  by address, so that is the set a host-side table representation would replace;
- DMA reads are 0.235 % of read traffic, so satisfying the DMA engine is a small
  part of the problem;
- the interpreter still runs real code in the shipped build, and that residue is
  now *named*: 32 fetched blocks (16 KiB) hold no promoted entry point, and the
  narrower analysis-based join says **26 blocks / 13 KiB were fetched inside no
  manifest span at all**, 98.8 % of that traffic being instruction fetches. The
  two counts answer different questions — "no compiled function starts in this
  block" versus "no analysis covered this block" — and the second is the one with
  an action attached: `[[func]]` entries plus `tools/regen.sh`. So M1's hybrid
  question is no longer "how much do we have to leave interpreted?", it is "how
  many trace → promote → re-trace rounds until the frontier is empty", and each
  round is a measurable step.

Cannot:

- "never fetched" is not proof of data. Six routes are not a playthrough; a
  routine none of them reached would fetch from a bank that shows no `f` today;
- the frontier is a floor, not a complete list: spans are bounding boxes, analysis
  is seeded by `recomp/symbols.toml`, and the six routes never reached some code
  the analyzer did;
- the promotion loop is not something B0 ran: `tools/regen.sh` drives the Rust
  analyzer, which runs here only as a prebuilt binary (a source rebuild wants
  network). B0 has answered its question; the next step is a symbols round, not
  another measurement;
- reads made by recompiled code carry a stale reading PC, so the report's
  per-PC tables are an interpreted-path statement only.

## Re-deriving it

```sh
cd /Users/wee/Documents/work/ports/ShadowrunSNESRecomp
# six route traces + the report
bash tests/collect_read_traces.sh
# neutrality, the short route and the long one
bash tests/cart_trace_neutral.sh
bash tests/cart_trace_neutral.sh tests/scripts/combat.txt
```

Both scripts check their own binaries against `framework_pins.txt` before running
(`tests/provenance.py pin`), so the control build has to exist: how it was built is
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c1c_framework_copy.md`.
