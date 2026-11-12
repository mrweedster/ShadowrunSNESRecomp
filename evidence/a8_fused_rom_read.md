# A8 — Fused interpreter ROM reads

Date: 2026-11-12. Status: ported, default on, verified on macOS; Linux
confirmation pending the player's rebuilt binary.

## Why

A `perf` profile of the Linux release at 52.7 fps put the interpreter's ROM
path at the top of the tree:

```
15.65%  cart_getRomPtr       (mapping lookup)
14.56%  _interp_run_core     (decode/dispatch)
 5.75%  bridge_bus_read      (classify read, calls the lookup)
 4.95%  cpu_read8            (fetch, calls the lookup again)
```

`bridge_bus_read()` decided whether a read was stable by decoding the ROM
mapping, then the fetch decoded the same mapping again inside
`cpu_read8 -> cart_getRomPtr`. Every plain LoROM/HiROM instruction byte paid
for the lookup twice. The recompiled share in the shipped build is only
2.95% (`execution_share.interp_cycle_pct` 97.05), so this pair really is the
hot loop.

## What was ported

Upstream `ca5673cb`, "perf: fuse immutable interpreter ROM reads behind build
selection", adapted to the pin (`773285b8`) where the bridge still calls
`bridge_timing_bus(adr, 'R')`. It is shipped as
`tools/interp_fused_rom_read_framework.patch`:

| file | change |
|---|---|
| `runner/runner.cmake` | `SNESRECOMP_INTERP_READ_IMPL` (REFERENCE/FUSED) |
| `runner/src/cpu_plain_rom_read.h` | new: `cpu_read8_plain_rom()` |
| `runner/src/cpu_state.c` | claim only plain LoROM/HiROM at `addr >= $8000` |
| `runner/src/snes/interp_bridge.c` | one claim per fetch when FUSED |

The fused path is deliberately narrow:

- only `CART_LOROM` and `CART_HIROM`, only the high window; SRAM/WRAM, MMIO,
  coprocessor and invalid mappings stay on `cpu_read8`;
- it updates the same open-bus and cartridge-bus latches as `cpu_read8`
  (`cpu_latch_read8()`, `cart_note_cpu_bus()`), so poll detection, traces and
  the SRAM/cart latch tests still see the read;
- no pointer or decoded mapping is cached across calls.

The port requires the patch (CMake fails with the `git apply` command if the
checkout lacks it) and selects `FUSED` by default; `REFERENCE` remains a cache
option for A/B testing.

## Measurement

macOS arm64 reference host, Release, universal build (USA+DE+SV), LLE frame
composition, USA ROM, 600 frames, vsync on a 59.96 Hz display. Same tree,
same compiler; only `SNESRECOMP_INTERP_READ_IMPL` differs.

| build | guest mean | guest p95 | guest max | cpu_seconds | fps |
|---|---|---|---|---|---|
| REFERENCE | 2.014 ms | 3.484 ms | 4.669 ms | 1.952 | 59.957 |
| FUSED | 1.750 ms | 3.330 ms | 4.849 ms | 1.846 | 59.955 |

An earlier FUSED run in the scratch tree measured 1.668 ms against a 2.038 ms
pin baseline (cpu 1.757 vs 2.008). Across runs the guest stage drops
**13–18%**, roughly 0.26–0.37 ms per frame here.

The macOS fps does not change: the frame already finishes inside the deadline
and spends the remainder in `deadline-wait` (14.4 ms). The gain only shows up
where the budget is short, which is the Linux machine: `guest 8.562 ms` with
`deadline-wait 8.454 ms` and only 597/600 waits reached. A 13–18% cut to that
stage is ~1.1–1.5 ms, taking the guest near 7.1–7.4 ms.

## Correctness checks (FUSED build)

| check | result |
|---|---|
| USA `selfcheck.txt` | exit 0, tick `$7E1C92` advanced |
| Germany `selfcheck-intl.txt` | exit 0, tick `$7E1C76` advanced |
| Sweden `selfcheck-intl.txt` | exit 0, tick `$7E1C76` advanced |
| 1 MiB unknown image | exit 1, `no module matches image` with sha256 |
| three patches apply to the pin | `git apply --check` clean in order |

## Reproduce

```sh
git -C snesrecomp apply /path/to/ShadowrunSNESRecomp/tools/interp_fused_rom_read_framework.patch
cmake --preset linux-x64          # FUSED by default
cmake --build --preset linux-x64 --parallel "$(nproc)"

# A/B the decoder on an existing build tree (one file relinks):
cmake -S . -B build-linux-x64 -DSNESRECOMP_INTERP_READ_IMPL=REFERENCE
cmake --build build-linux-x64 --parallel "$(nproc)"
```

Then run the 600-frame capture from `README.md` and compare `guest_ms` and
`fps` for the two binaries. The Linux numbers replace the estimate above when
they arrive.
