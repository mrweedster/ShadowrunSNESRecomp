# round4_hot_vs_aot.md
#
# what: how much of the interpreted residue already sits inside a body this same program has, and how little of that is reachable at a transfer gap
# how:  python3 tests/hot_vs_aot.py evidence/artifacts/tier2_capture_round3_combat.json tests/out/r4/manifest_r4base.json.bz2 (the control program: no other tree in this round was captured)
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T08:02:38Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

# interpreted cost vs the bodies the same program already has

capture    evidence/artifacts/tier2_capture_round3_combat.json
           program_digest 240af24bb4a71049
manifest   tests/out/r4/manifest_r4base.json.bz2
           269 nodes (226 aot_eligible, 43 lle_only), 47 roots

Every hot row of the capture, classified against that manifest: does a
compiled body cover the PC the interpreter paid for, in the same M/X mode?
Bank mirror spellings tried as well; 0 rows matched only on a mirror.

| class | hot PCs | interpreted insns | guest cycles | % of residue | of those PCs, sighted at a transfer gap |
|---|---|---|---|---|---|
| exact-aot | 25 | 718,590 | 3,409,819 | 0.37 % | 1 |
| exact-lle | 9 | 41,111 | 161,948 | 0.02 % | 4 |
| span-aot | 2801 | 62,733,369 | 275,979,837 | 30.02 % | 12 |
| span-lle | 326 | 695,427 | 3,161,778 | 0.34 % | 1 |
| no-node | 6402 | 162,764,969 | 636,593,941 | 69.25 % | 237 |
| **total** | 9563 | 226,953,466 | 919,307,323 | 100.00 % | 255 |

The hottest 15 PCs in the capture, same join.

| PC | M/X | insns | guest cycles | % of residue | class | covering node | body span | gap sighting |
|---|---|---|---|---|---|---|---|---|
| $81B061 | M0X0 | 27,574,565 | 165,447,390 | 18.00 % | span-aot | 81B05D:M0X0 (4 insns, $81B05D-$81B067) |  | none |
| $81B065 | M0X0 | 27,574,565 | 82,703,990 | 9.00 % | span-aot | 81B05D:M0X0 (4 insns, $81B05D-$81B067) |  | none |
| $81EE8E | M1X0 | 4,742,142 | 23,710,710 | 2.58 % | no-node | - |  | none |
| $81EE92 | M1X0 | 4,742,142 | 14,225,130 | 1.55 % | no-node | - |  | none |
| $80F353 | M0X0 | 1,230,254 | 9,842,026 | 1.07 % | no-node | - |  | none |
| $80F35A | M0X0 | 1,230,254 | 7,381,524 | 0.80 % | no-node | - |  | none |
| $80F356 | M0X0 | 1,230,254 | 3,690,762 | 0.40 % | no-node | - |  | none |
| $81F007 | M1X0 | 714,825 | 2,859,300 | 0.31 % | span-aot | 81EFFB:M1X0 (21 insns, $81EFFB-$81F027) |  | none |
| $80B7BF | M0X0 | 358,612 | 2,510,284 | 0.27 % | no-node | - |  | none |
| $80B74E | M0X0 | 357,965 | 2,505,755 | 0.27 % | no-node | - |  | none |
| $80F359 | M0X0 | 1,230,254 | 2,460,508 | 0.27 % | no-node | - |  | none |
| $80F355 | M0X0 | 1,230,254 | 2,460,508 | 0.27 % | no-node | - |  | none |
| $81EE8E | M1X1 | 468,119 | 2,340,595 | 0.25 % | span-aot | 81EE7C:M1X1 (13 insns, $81EE7C-$81EE95) |  | none |
| $80C1C9 | M0X0 | 366,165 | 2,196,990 | 0.24 % | no-node | - |  | call_gap, 366,165 hits |
| $80C399 | M0X0 | 366,165 | 2,196,990 | 0.24 % | no-node | - |  | call_gap, 366,165 hits |

exact-aot cycles (3,409,819, 0.37 % of the residue) sit at an entry the program
already has a compiled body for, and 24 of those 25 hot PCs have no
transfer-gap sighting at all, so no `[[func]]` entry at any address
intercepts them: the only way in is the interpreter handing control over,
which is the seam, not the seed table.
