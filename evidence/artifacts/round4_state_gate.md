# round4_state_gate.md
#
# what: the adoption gate: per-checkpoint machine state for every seeded tree against the control run
# how:  tests/cpdump_matrix.py then tests/apu_shift.py per variant; the checkpoint dumps they read live in tests/out/r4/<variant>/ (scratch: 22 tagged checkpoints per run).  The same question at byte level is in evidence/artifacts/round4_state_bytes.md
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T08:02:38Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

# checkpoint-state matrix

Control run: `tests/out/r4/r4base`.  Each cell is one tagged checkpoint, comparing the
state images both runs took at that frame (`tests/framedump_diff.py cpdump`):
24 regs.json keys, wram/vram/oam/cgram/sram images, the host framebuffer,
and the apu/ppuw/dma traces.

| checkpoint | control frame | tests/out/r4/r4pair | tests/out/r4/r4clean | tests/out/r4/s80C399 | tests/out/r4/s80AAB3 | tests/out/r4/s80ABBC | tests/out/r4/s80B1DB | tests/out/r4/r4probe |
|---|---|---|---|---|---|---|---|---|
| H8 | 16188 | apu-only | DIFFERS(apu.tsv,wram.bin) | apu-only | apu-only | DIFFERS(apu.tsv,wram.bin) | DIFFERS(apu.tsv,wram.bin) | clean |
| J1 | 16865 | apu-only | DIFFERS(regs+apu.tsv,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| J2 | 17196 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,vram.bin,wram.bin) | clean |
| J3 | 17317 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| J4 | 17438 | apu-only | DIFFERS(regs+apu.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(apu.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,vram.bin,wram.bin) | clean |
| J5 | 17559 | apu-only | DIFFERS(apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(apu.tsv,oam.bin,vram.bin,wram.bin) | DIFFERS(apu.tsv,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| J6 | 17680 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(apu.tsv,oam.bin,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| J7 | 17801 | apu-only | DIFFERS(regs+apu.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(apu.tsv,cgram.bin,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,vram.bin,wram.bin) | clean |
| J8 | 17951 | apu-only | DIFFERS(apu.tsv,oam.bin,vram.bin,wram.bin) | clean | apu-only | DIFFERS(apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | DIFFERS(apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | clean |
| J9 | 18101 | apu-only | DIFFERS(apu.tsv,oam.bin,vram.bin,wram.bin) | clean | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | clean |
| J10 | 18401 | apu-only | DIFFERS(apu.tsv,oam.bin,vram.bin,wram.bin) | clean | apu-only | DIFFERS(apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | DIFFERS(apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | clean |
| K1 | 18552 | apu-only | DIFFERS(apu.tsv,oam.bin,vram.bin,wram.bin) | clean | apu-only | DIFFERS(apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | DIFFERS(apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | clean |
| K2 | 18703 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean | apu-only | DIFFERS(apu.tsv,cgram.bin,oam.bin,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| K3 | 19003 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| L0 | 19454 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| L1 | 19761 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| A0 | 20730 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| A1 | 20844 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| A2 | 21144 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| A3 | 21444 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| A4 | 21744 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |
| A5 | 22044 | apu-only | DIFFERS(regs+apu.tsv,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | apu-only | apu-only | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | DIFFERS(regs+apu.tsv,cgram.bin,fb.bgrx,oam.bin,ppuw.tsv,vram.bin,wram.bin) | clean |

The master-clock delta is the variant's clock at that checkpoint minus
the control's; a seeded body runs the same guest instructions, so a
state-clean tree shows +0 there.

| variant | checkpoints | clean | apu-only | guest-state differing | regs keys differed | master-clock delta at first/last checkpoint |
|---|---|---|---|---|---|---|
| tests/out/r4/r4pair | 22 | 0 | 22 | none | 0 | H8 +0 / A5 +0 |
| tests/out/r4/r4clean | 22 | 0 | 0 | A0, A1, A2, A3, A4, A5, H8, J1, J10, J2, J3, J4, J5, J6, J7, J8, J9, K1, K2, K3, L0, L1 | 46 | H8 -4 / A5 +20 |
| tests/out/r4/s80C399 | 22 | 8 | 14 | none | 0 | H8 +0 / A5 +0 |
| tests/out/r4/s80AAB3 | 22 | 0 | 22 | none | 0 | H8 +0 / A5 +0 |
| tests/out/r4/s80ABBC | 22 | 0 | 0 | A0, A1, A2, A3, A4, A5, H8, J1, J10, J2, J3, J4, J5, J6, J7, J8, J9, K1, K2, K3, L0, L1 | 33 | H8 -20 / A5 +36 |
| tests/out/r4/s80B1DB | 22 | 0 | 0 | A0, A1, A2, A3, A4, A5, H8, J1, J10, J2, J3, J4, J5, J6, J7, J8, J9, K1, K2, K3, L0, L1 | 41 | H8 -16 / A5 +38 |
| tests/out/r4/r4probe | 22 | 22 | 0 | none | 0 | H8 +0 / A5 +0 |

==== apu_shift r4pair (source: tests/out/r4/apu_shift_r4pair.md)
# APU-trace comparison: tests/out/r4/r4base vs tests/out/r4/r4pair

Header is `frame scanline hclock event port value sample`; one frame
is 262 scanlines x 512 hclocks of stamping space.

| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | shift hclocks (min / median / max) | worst shift, frames | `sample` column identical |
|---|---|---|---|---|---|---|---|
| A0 | 65536 / 65536 | 4 | yes | 4 of 65536 | 0 / 0 / 1862 | 0 | yes |
| A5 | 65536 / 65536 | 6 | yes | 6 of 65536 | -778 / 0 / 1862 | 0 | yes |
| H8 | 65536 / 65536 | 26 | yes | 26 of 65536 | -742 / 0 / 794 | 0 | yes |
| J1 | 65536 / 65536 | 27 | yes | 27 of 65536 | -742 / 0 / 794 | 0 | yes |
| J10 | 65536 / 65536 | 2 | yes | 2 of 65536 | -58 / 0 / 392 | 0 | yes |
| L1 | 65536 / 65536 | 3 | yes | 3 of 65536 | -58 / 0 / 1862 | 0 | yes |

==== apu_shift r4clean (source: tests/out/r4/apu_shift_r4clean.md)
# APU-trace comparison: tests/out/r4/r4base vs tests/out/r4/r4clean

Header is `frame scanline hclock event port value sample`; one frame
is 262 scanlines x 512 hclocks of stamping space.

| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | shift hclocks (min / median / max) | worst shift, frames | `sample` column identical |
|---|---|---|---|---|---|---|---|
| A0 | 65536 / 65536 | 65536 | **no: 63221 rows only in a, 63221 only in b** | | | | |
| A5 | 65536 / 65536 | 65536 | **no: 63221 rows only in a, 63221 only in b** | | | | |
| H8 | 65536 / 65536 | 65536 | **no: 1527 rows only in a, 1527 only in b** | | | | |
| J1 | 65536 / 65536 | 65536 | **no: 31564 rows only in a, 31564 only in b** | | | | |

==== apu_shift s80C399 (source: tests/out/r4/apu_shift_s80C399.md)
# APU-trace comparison: tests/out/r4/r4base vs tests/out/r4/s80C399

Header is `frame scanline hclock event port value sample`; one frame
is 262 scanlines x 512 hclocks of stamping space.

| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | shift hclocks (min / median / max) | worst shift, frames | `sample` column identical |
|---|---|---|---|---|---|---|---|
| A0 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 156 | 0 | yes |
| A1 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 156 | 0 | yes |
| A2 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 156 | 0 | yes |
| A3 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 156 | 0 | yes |
| A4 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 156 | 0 | yes |
| A5 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 156 | 0 | yes |
| H8 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J1 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J10 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |
| J2 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J3 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J4 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J5 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J6 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J7 | 65536 / 65536 | 11 | yes | 11 of 65536 | -528 / 0 / 390 | 0 | yes |
| J8 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |
| J9 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |
| K1 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |
| K2 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |
| K3 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |
| L0 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |
| L1 | 65536 / 65536 | 0 | yes | 0 of 65536 | 0 / 0 / 0 | 0 | yes |

==== apu_shift s80AAB3 (source: tests/out/r4/apu_shift_s80AAB3.md)
# APU-trace comparison: tests/out/r4/r4base vs tests/out/r4/s80AAB3

Header is `frame scanline hclock event port value sample`; one frame
is 262 scanlines x 512 hclocks of stamping space.

| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | shift hclocks (min / median / max) | worst shift, frames | `sample` column identical |
|---|---|---|---|---|---|---|---|
| A0 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 1862 | 0 | yes |
| A1 | 65536 / 65536 | 2 | yes | 2 of 65536 | 0 / 0 / 1862 | 0 | yes |
| A2 | 65536 / 65536 | 4 | yes | 4 of 65536 | -778 / 0 / 1862 | 0 | yes |
| A3 | 65536 / 65536 | 4 | yes | 4 of 65536 | -778 / 0 / 1862 | 0 | yes |
| A4 | 65536 / 65536 | 4 | yes | 4 of 65536 | -778 / 0 / 1862 | 0 | yes |
| A5 | 65536 / 65536 | 4 | yes | 4 of 65536 | -778 / 0 / 1862 | 0 | yes |
| H8 | 65536 / 65536 | 15 | yes | 15 of 65536 | -742 / 0 / 794 | 0 | yes |
| J1 | 65536 / 65536 | 16 | yes | 16 of 65536 | -742 / 0 / 794 | 0 | yes |
| J10 | 65536 / 65536 | 2 | yes | 2 of 65536 | -58 / 0 / 392 | 0 | yes |
| J2 | 65536 / 65536 | 17 | yes | 17 of 65536 | -742 / 0 / 794 | 0 | yes |
| J3 | 65536 / 65536 | 18 | yes | 18 of 65536 | -742 / 0 / 794 | 0 | yes |
| J4 | 65536 / 65536 | 18 | yes | 18 of 65536 | -742 / 0 / 794 | 0 | yes |
| J5 | 65536 / 65536 | 18 | yes | 18 of 65536 | -742 / 0 / 794 | 0 | yes |
| J6 | 65536 / 65536 | 18 | yes | 18 of 65536 | -742 / 0 / 794 | 0 | yes |
| J7 | 65536 / 65536 | 18 | yes | 18 of 65536 | -742 / 0 / 794 | 0 | yes |
| J8 | 65536 / 65536 | 3 | yes | 3 of 65536 | -58 / 0 / 392 | 0 | yes |
| J9 | 65536 / 65536 | 2 | yes | 2 of 65536 | -58 / 0 / 392 | 0 | yes |
| K1 | 65536 / 65536 | 2 | yes | 2 of 65536 | -58 / 0 / 392 | 0 | yes |
| K2 | 65536 / 65536 | 2 | yes | 2 of 65536 | -58 / 0 / 392 | 0 | yes |
| K3 | 65536 / 65536 | 2 | yes | 2 of 65536 | -58 / 0 / 392 | 0 | yes |
| L0 | 65536 / 65536 | 3 | yes | 3 of 65536 | -58 / 0 / 1862 | 0 | yes |
| L1 | 65536 / 65536 | 3 | yes | 3 of 65536 | -58 / 0 / 1862 | 0 | yes |

==== apu_shift s80ABBC (source: tests/out/r4/apu_shift_s80ABBC.md)
# APU-trace comparison: tests/out/r4/r4base vs tests/out/r4/s80ABBC

Header is `frame scanline hclock event port value sample`; one frame
is 262 scanlines x 512 hclocks of stamping space.

| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | shift hclocks (min / median / max) | worst shift, frames | `sample` column identical |
|---|---|---|---|---|---|---|---|
| A0 | 65536 / 65536 | 65536 | **no: 65536 rows only in a, 65536 only in b** | | | | |
| A5 | 65536 / 65536 | 65536 | **no: 65531 rows only in a, 65531 only in b** | | | | |
| H8 | 65536 / 65536 | 65517 | **no: 1376 rows only in a, 1376 only in b** | | | | |
| J1 | 65536 / 65536 | 65536 | **no: 29782 rows only in a, 29782 only in b** | | | | |

==== apu_shift s80B1DB (source: tests/out/r4/apu_shift_s80B1DB.md)
# APU-trace comparison: tests/out/r4/r4base vs tests/out/r4/s80B1DB

Header is `frame scanline hclock event port value sample`; one frame
is 262 scanlines x 512 hclocks of stamping space.

| checkpoint | rows a/b | rows differing | same event multiset | rows re-stamped | shift hclocks (min / median / max) | worst shift, frames | `sample` column identical |
|---|---|---|---|---|---|---|---|
| A0 | 65536 / 65536 | 65536 | **no: 65536 rows only in a, 65536 only in b** | | | | |
| A5 | 65536 / 65536 | 65536 | **no: 65536 rows only in a, 65536 only in b** | | | | |
| H8 | 65536 / 65536 | 65536 | **no: 1710 rows only in a, 1710 only in b** | | | | |
| J1 | 65536 / 65536 | 65536 | **no: 31848 rows only in a, 31848 only in b** | | | | |
