# M1 go/no-go: full AOT vs hybrid, and what "ROM-free" may claim

Decided 2026-11-06 on the measurements in
`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/b0_read_trace.md`
plus the earlier coverage and split-cycle records. Written as a decision, per
`/Users/wee/.opencode/plan/shadowrun-stage1-rom-free.md` §10 item 2.

Plain language first, then numbers.

Shadowrun's guest code is not mostly compiled today, and compiling more of it is
the cheap direction — but compiling *everything* does not produce a ROM-free
build, because the cart's bytes are still needed by the reset path, by DMA, and by
bank `$00` which bus bank `$80` aliases under LoROM. So the real choice is not
"recompile the game versus keep the cart". It is: keep an interpreter for the code
the analyzer cannot prove, and stop treating the cart file as the storage layer.
The decision is **hybrid, with a standing promotion loop**, and the interpreted
residue is no longer an unknown quantity — it is a named 13 KiB list.

What the earlier plan pre-committed to: *"if the reads are mostly data from a few
routines, go B2/B3 rather than M5."* That condition is **false as measured** — the
reads are mostly *instructions* — so the branch has to be argued from the
measurement rather than from the pre-decision. It is argued below.

## The decision

1. **Hybrid stays.** The interpreter is not a compatibility shim we can delete; it
   runs code at addresses nothing has analysed. Promote what analysis can reach,
   keep LLE for the rest, and make that split a measured list instead of an
   accident of the seed symbols.
2. **Do not chase full AOT as a path to a ROM-free runtime.** A fully compiled
   build would still boot from the cart image and still serve DMA from it. Full AOT
   is a performance question, and A7 already measured the performance answer.
3. **The ROM-free work targets storage, not fetch.** The cart *file* can go away
   (the embed and staged paths already boot without an external ROM — see
   `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c0_rom_free.md`
   and `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c1b_run_provenance.md`).
   The cart *bytes* stay resident. Data extraction therefore means host-side
   tables for the read-but-never-fetched set, not "make the interpreter read
   somewhere else".
4. **The next action is a round of the loop, and the loop is not blocked by a
   toolchain.** Adding `[[func]]` entries in
   `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/recomp/symbols.toml` and
   regenerating takes ~16 s, measured. An earlier version of this point said
   "there is no `cargo` on this machine", and that was wrong twice over. The
   analyzer runs here as a stamp-verified prebuilt
   (`/Users/wee/Documents/work/snesrecomp/recompiler-rs/target/release/snesrecomp-analyze`,
   stamped `03e1938ea65e…` — the digest of the pinned crate's `src`,
   `Cargo.toml` and `Cargo.lock`, and the same digest framework `main` produces).
   Naming it through `SNESRECOMP_NATIVE_ANALYZER` satisfies the framework's own
   rebuild-or-refuse rule
   (`/Users/wee/Documents/work/snesrecomp/tools/native_analyzer_identity.py`), and
   the pinned CLI generated this port's tree in ~16 s reporting
   `9 roots -> 226 exact variants, 214 AOT-eligible, 12 LLE-only`
   (`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/out/gen-pin-check.log`).
   Run again with that analyzer copied inside the pinned worktree, the same CLI
   reproduces the committed `src/gen` **byte for byte** in 7.9 s — 17 units, the
   manifest, and `module_v2.c` down to its `build_digest` — so a symbols round's
   diff is that round's doing and nothing else
   (`/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/c1c_framework_copy.md`).
   Cargo and rustc do exist here, just not on `PATH`
   (`~/.rustup/toolchains/1.97.1-aarch64-apple-darwin/bin/`, no rustup shims and
   no `~/.rustup/settings.toml`); what that leaves unavailable is *rebuilding* the
   crate, which wants network for `serde_json` and has no registry cache to serve
   it. Running the prebuilt does not. So the loop's first dependency is the
   symbols edit, not a toolchain. One caution for the round: `tools/regen.sh`
   writes `src/gen`, `recomp/funcs.h` and `recomp/symbols.toml` in place, so it
   wants a clean git tree around it.

## Why, from the numbers

| measured | value | what it rules in or out |
|---|---|---|
| instruction-stream share of CPU ROM reads | 65.8 % of 2.78 B reads (1.83 B fetches) | the plan's "reads are mostly data" premise is false; a data-only extraction moves a third of the traffic |
| DMA share of ROM reads | 0.235 % (6.54 M of 2.79 B) | satisfying the DMA engine is a small engineering item, not the blocker |
| blocks with a fetch mark | 88 of 2,048 = 45 KiB, all below physical `00F3FF` | interpreted code is a bounded set, so "hybrid" is a bounded decision, not a permanent tax |
| fetched blocks inside no analysis span | **26 blocks = 13 KiB, 1,084,397,942 reads = 38.9 % of all reads** | the promotion frontier: named ranges with a cfg + `tools/regen.sh` path |
| how that traffic splits | 1,070,883,869 fetch vs 13,511,786 by address (98.8 % fetch) | the frontier is instructions, not constants hiding in a code bank |
| nodes the analyzer proved but left interpreted | 12 nodes / 7 blocks (`lle_only`) | a cfg decision, not new analysis |
| image never read on six routes | 1,283 blocks = 656,896 B = 62.6 % | the set a host-side table representation replaces most easily |
| read but never fetched | 677 blocks = 346,624 B = 33.1 %, 156 runs | the data-extraction target set; concentrated (top 20 blocks carry 93.3 % of reads) |
| recompiled path's share of cycles | 1.88–5.58 % (`evidence/a7_aot_split_hunt.md`) | an "AOT build" is, in cycle terms, an interpreted build — full AOT is not a ROM-free lever |
| bank aliasing | physical bank 0 is bus `$00` and `$80`; `$00` is read on every route | 25 of the 26 frontier blocks cannot leave the cart image even once compiled |

## What this decides downstream

- **B2/B3 (host-side data tables) go ahead**, aimed at the 156 contiguous
  read-not-fetched runs, hottest first. Not M5-shaped "route the interpreter at a
  different source": the reads that matter are fetches, and the interpreter has to
  keep fetching until the frontier is promoted.
- **The frontier list is the standing work item.** Round shape: seed
  `recomp/symbols.toml` from the frontier ranges → `tools/regen.sh` → re-collect
  the six traces with `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/collect_read_traces.sh`
  → re-run `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/tests/cart_trace_report.py`
  → the frontier's block count and read share are the metric. Two rounds are
  enough to tell whether the frontier shrinks geometrically or stalls; a stall
  means computed-address entry points the static analyzer cannot seed, which is a
  different problem with a different fix (runtime-discovered promotion).
- **The observer stays opt-in and off the pin.** The capability lives on
  `feat/cart-read-trace` (`48d2d1b7`, unpushed); the pin
  `773285b8210f2254ae87d0a14113980fb36990ad` in
  `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/framework_pins.txt` does
  not move for an unmerged opt-in observer. Whether it becomes a framework PR is
  still open; nothing in this decision depends on that.

## What would change this decision

- A promotion round that does not shrink the frontier → the game reaches code by
  computed address faster than static analysis seeds it; then hybrid is permanent
  and M5-shaped work (an interpreter that fetches from a host-resident image, which
  is a *storage* change, not a compilation change) becomes the main line.
- Any route where a bank shows instruction fetches that six routes never touched →
  the 45 KiB bound is a floor and the footprint claim weakens. Widening the route
  set is cheap and is the honest way to test the bound; it does not require any
  framework change.
- A framework re-pin that changes bus read ordering or DMA pacing → the read-share
  numbers would need re-collecting before this decision is re-read, because every
  figure here is bound to the pinned tree and to the six trace digests listed in
  `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/evidence/artifacts/b0_digest.txt`.

## Limits of this decision

- Six scripted routes are not a playthrough. The footprint bounds are floors on
  fetch traffic and ceilings on the untouched set, not proofs about the whole game.
- Manifest spans are bounding boxes, and analysis is seeded by
  `/Users/wee/Documents/work/ports/ShadowrunSNESRecomp/recomp/symbols.toml`, so
  "inside no span" means unanalysed, never proven-data. Both errors make the
  frontier smaller, so the 13 KiB is a conservative list.
- The 38.9 % read share is read *count*, not cycle cost. Nothing measured here says
  the frontier costs 38.9 % of anything except ROM read traffic.
- No promotion round has actually been run, so "the loop shrinks the frontier" is
  the expected shape, not a measured one.
