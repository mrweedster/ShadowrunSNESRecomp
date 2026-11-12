# A2 — First AOT promotion batch

Scope: Stage 1, workstream A2 (promotion loop) of
`~/.opencode/plan/shadowrun-stage1-rom-free.md`. This batch proves the
promotion path end to end and records exactly how far it gets. It is **not**
shipped: the reference binary remains the LLE build.

## 1. Setup

- Base: bundle `7e353a2`, exported with `git archive` to a scratch tree so the
  working bundle is untouched.
- `recomp/symbols.toml`: `I_RESET` (`$00:E34C`) and `I_NMI` (`$00:C0E2`) set to
  `emit = true`.
- Regenerated with `SNESRECOMP_ROOT=<clean framework checkout>` and the verified
  ROM; analysis found **9 roots → 226 exact variants, 490 edges; 214
  AOT-eligible, 12 LLE-only**.
- Emitted 3 banks: `bank81_v2.c` (largest), `bank80_v2.c`, `bank00_v2.c`;
  `src/gen` = 4.8 MB.
- Built with gcc-16, `SNESRECOMP_SDL3_FETCH=OFF`.

| Build | Size | Notes |
|---|---:|---|
| Reference LLE (`./Shadowrun`) | 1,457,824 B | shipped, 0 AOT |
| Clean-framework LLE rebuild | 2,573,776 B | matches `tests/README.md` §7 |
| A2 AOT batch | 4,975,664 B | matches §7's documented AOT size |

The 9 roots are the two declared vectors in all M/X forms plus `$00:F27D` in
all four forms, which the generator adds from its host-root scan.

## 2. AOT participation

`last_run_report.json` → `execution_share`:

| Route | Frames | Interp cycles | AOT cycles | AOT share |
|---|---:|---:|---:|---:|
| `wait 505; quit` | 505 | 17,299,736 | 633,361 | **3.53%** |
| `menu.txt` | 1,245 | 38,896,240 | 2,283,473 | **5.55%** |
| `nav1.txt` | 1,932 | 64,829,512 | 4,122,630 | **5.98%** |

So the batch is live and deterministic, but covers only the boot/vector code
and what that reaches. It is a path proof, not a coverage milestone.

## 3. Parity

Gate: `tests/parity.sh` with `PORT_BIN2`, per-frame crc32 of all 128 KiB WRAM.

### Controls

| Comparison | Result |
|---|---|
| Shipped LLE vs shipped LLE | identical, 1200/1200 |
| Bundle `build/` LLE vs shipped LLE | identical, 1200/1200 |
| Clean-framework LLE rebuild vs shipped LLE | identical, 1200/1200 |

The clean-framework control matters: it rules out the framework checkout,
compiler and build tree as the source of any difference. Only the AOT code path
changes the result.

### AOT vs LLE

| Route | Frames | Byte-identical frames | Median diff bytes | Worst frame |
|---|---:|---:|---:|---:|
| `parity.txt` | 1,200 | 124 | 6 | 1,448 B @ f496 |
| `menu.txt` | 1,245 | 124 | 5 | 2,056 B @ f759 |
| `wait 505; quit` | 520 | 124 | 5 | 1,448 B @ f496 |

The steady-state delta is the documented `tests/README.md` §7 set — the frame
counters/timers `$7E01C92`, `$7E01C94`, `$7E01CD4`, `$7E01CD6`, `$7E00133`,
`$7E0001C`. That part is expected.

**Not expected:** transient bursts during the intro (roughly frames 2–7,
196–203, 474–478 and 496) with hundreds to ~2,000 differing bytes. The regions
are staging buffers such as `$7E4E84–$7E5xxx`; at f496 the AOT run still has
zeros there while LLE has a filled tilemap, i.e. the two paths write the same
buffers at slightly different times.

### Presentation check

Frames were dumped as BMPs from both binaries and compared by md5:

| Route | Frames compared | Identical |
|---|---:|---:|
| `wait 505` | 470–500, step 1 | **31 / 31** |
| `menu.txt` | 745–762, step 1 | **18 / 18** |

Every frame, including the worst WRAM-diff frames, renders byte-identically.
The transient deltas are therefore not visible in the framebuffer. Audio was
not captured; that remains unverified.

## 4. Reading

The AOT emitter checks the master deadline at **basic-block boundaries** and
unwinds to the block start when it is crossed. That preserves architectural
state, but an interrupt landing mid-block is delivered later than the
interpreter would deliver it. A few cycles of skew is enough to reorder a
buffer write against NMI/vblank, which is exactly the transient pattern seen.
It converges because the buffers are rewritten before they are consumed.

This is a framework behaviour, not a miscompile in this batch: the batch is
deterministic (AOT vs AOT = identical 60/60), the controls are identical, and
rendering never differs.

## 5. Decision

- **Do not ship the A2 batch.** Stage 1's bar is behaviour identity; strict WRAM
  parity currently fails at transient frames, even though presentation matches.
- **Keep the LLE binary as the reference** (`tests/parity.sh` baseline).
- Before scaling promotion, either:
  1. tighten AOT interrupt delivery to instruction granularity (framework
     change), or
  2. formally widen the Stage 1 gate to "presentation-identical + documented
     steady-state timer delta, with transient scratch-buffer deltas allowed",
     and add an audio comparison to close the remaining gap.

Recommendation: option 1 for the code banks that matter to gameplay, because a
future Stage 2/3 rewrite will build on this AOT path. A gate relaxation now
would hide real timing skew that gets harder to find later.

## 6. Reproduce

```sh
# scratch tree
git archive HEAD | tar -x -C /tmp/sr-a2
cd /tmp/sr-a2
# set I_RESET/I_NMI emit = true in recomp/symbols.toml
SNESRECOMP_ROOT=<snesrecomp> bash tools/regen.sh --rom "<rom>"
CC=/opt/homebrew/opt/gcc/bin/gcc-16 CXX=g++ \
  cmake -S . -B build -DSNESRECOMP_ROOT=<snesrecomp> -DSNESRECOMP_SDL3_FETCH=OFF
cmake --build build -j

# gate
cd <bundle>
PORT_BIN=/tmp/sr-a2/build/ShadowrunSNESRecomp PORT_BIN2=./Shadowrun \
  ./tests/parity.sh tests/scripts/parity.txt
PORT_BIN=/tmp/sr-a2/build/ShadowrunSNESRecomp PORT_BIN2=./Shadowrun \
  ./tests/parity.sh tests/scripts/menu.txt
```

Raw logs and dumps: `tests/out/a2/` (gitignored).
