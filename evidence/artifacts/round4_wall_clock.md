# round4_wall_clock.md
#
# what: wall clock per binary in ms: same-binary replicates give the noise floor, and an interleaved batch is read pairwise against the control leg it ran next to
# how:  tests/charge_wall.py over every tests/out/r4/charge_hostcost_run.log / tests/out/r4/charge_wallbatch*.log; legs from tests/aot_charge.sh with SCRIPT=tests/scripts/combat.txt. exit=0 means the differences cleared the floor, 1 means inconclusive
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T08:02:38Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp


==== tests/out/r4/charge_hostcost_run.log
     tests/charge_wall.py tests/out/r4/charge_hostcost_run.log base_ pair_ c399_ aab3_ probe_
# wall clock per binary, from tests/out/r4/charge_hostcost_run.log

Same-binary replicates give the noise floor; a difference between two
binaries counts only if it clears that spread.

| binary | pins | legs | exit | wall s (min / mean / max) | stdev s | mean wall vs control | interp_cycles | delta | aot % |
|---|---|---|---|---|---|---|---|---|---|
| build-r4base | nofloor/off/0 | 7 | 0/0/0/0/0/0/0 | 30.27 / 30.91 / 31.48 | 0.52 | +0.00 s (+0.00 %) | 919,307,323 | - | 3.85 |
| build-s80C399 | nofloor/off/0 | 3 | 0/0/0 | 30.96 / 31.10 / 31.22 | 0.13 | +0.19 s (+0.61 %) | 899,859,432 | -19447891 cyc (-2.12 %) | 5.88 |
| build-s80AAB3 | nofloor/off/0 | 3 | 0/0/0 | 30.77 / 31.00 / 31.20 | 0.22 | +0.09 s (+0.29 %) | 880,287,406 | -39019917 cyc (-4.24 %) | 7.93 |
| build-r4probe | nofloor/off/0 | 2 | 0/0 | 30.19 / 30.50 / 30.80 | 0.43 | -0.42 s (-1.35 %) | 919,307,323 | +0 cyc (+0.00 %) | 3.85 |
| build-r4pair | nofloor/off/0 | 4 | 0/0/0/0 | 29.95 / 30.07 / 30.19 | 0.11 | -0.84 s (-2.71 %) | 860,839,515 | -58467808 cyc (-6.36 %) | 9.96 |
| build-r4probe | floor/off/1 | 1 | 0 | 29.98 / 29.98 / 29.98 | 0.00 | -0.93 s (-3.01 %) | 919,307,323 | +0 cyc (+0.00 %) | 3.85 |
| build-r4probe | nofloor/off/1 | 1 | 0 | 29.73 / 29.73 / 29.73 | 0.00 | -1.18 s (-3.82 %) | 919,307,323 | +0 cyc (+0.00 %) | 3.85 |

widest same-binary spread: 0.52 s, so a credible wall difference is more than 1.05 s
inconclusive  build-s80C399 vs build-r4base: 0.19 s apart, needs > 1.05 s
inconclusive  build-s80AAB3 vs build-r4base: 0.09 s apart, needs > 1.05 s
inconclusive  build-r4probe vs build-r4base: 0.42 s apart, needs > 1.05 s
inconclusive  build-r4pair vs build-r4base: 0.84 s apart, needs > 1.05 s
not judged    build-r4probe vs build-r4base: 0.93 s apart, but build-r4probe has 1 leg(s)
not judged    build-r4probe vs build-r4base: 1.18 s apart, but build-r4probe has 1 leg(s)
note: a group with 1 leg has no spread of its own

not paired      build-s80C399 vs build-r4base: this log runs the two binaries in blocks (longest run of one binary: 4 legs), so pairing them would compare blocks, not pairs

not paired      build-s80AAB3 vs build-r4base: this log runs the two binaries in blocks (longest run of one binary: 4 legs), so pairing them would compare blocks, not pairs

not paired      build-r4pair vs build-r4base: this log runs the two binaries in blocks (longest run of one binary: 4 legs), so pairing them would compare blocks, not pairs
     (tool exit=1: 0 resolved, 1 inconclusive)

==== tests/out/r4/charge_wallbatch.log
     tests/charge_wall.py tests/out/r4/charge_wallbatch.log wbase_ wpair_
# wall clock per binary, from tests/out/r4/charge_wallbatch.log

Same-binary replicates give the noise floor; a difference between two
binaries counts only if it clears that spread.

| binary | pins | legs | exit | wall s (min / mean / max) | stdev s | mean wall vs control | interp_cycles | delta | aot % |
|---|---|---|---|---|---|---|---|---|---|
| build-r4base | nofloor/off/0 | 10 | 0/0/0/0/0/0/0/0/0/0 | 30.33 / 31.60 / 32.43 | 0.72 | +0.00 s (+0.00 %) | 919,307,323 | - | 3.85 |
| build-r4pair | nofloor/off/0 | 10 | 0/0/0/0/0/0/0/0/0/0 | 29.28 / 30.24 / 30.94 | 0.48 | -1.36 s (-4.31 %) | 860,839,515 | -58467808 cyc (-6.36 %) | 9.96 |

widest same-binary spread: 0.72 s, so a credible wall difference is more than 1.43 s
inconclusive  build-r4pair vs build-r4base: 1.36 s apart, needs > 1.43 s (the paired reading below resolves it)

paired by replicate label (interleaved legs cancel host drift):
  resolved  build-r4pair vs build-r4base over 10 pairs: mean -1.36 s (sd 0.53, se 0.17), signs consistent, needs |mean| > 0.34 s and one sign
     pairs: p3 -2.16, p4 -1.74, p5 -1.40, p6 -1.41, p7 -1.83, p8 -1.44, r1 -1.05, r2 -0.80, r3 -0.31, r4 -1.49
     (tool exit=0: 0 resolved, 1 inconclusive)

==== tests/out/r4/charge_wallbatch2.log
     tests/charge_wall.py tests/out/r4/charge_wallbatch2.log base_ c399_ aab3_
# wall clock per binary, from tests/out/r4/charge_wallbatch2.log

Same-binary replicates give the noise floor; a difference between two
binaries counts only if it clears that spread.

| binary | pins | legs | exit | wall s (min / mean / max) | stdev s | mean wall vs control | interp_cycles | delta | aot % |
|---|---|---|---|---|---|---|---|---|---|
| build-r4base | nofloor/off/0 | 4 | 0/0/0/0 | 29.79 / 30.62 / 31.12 | 0.58 | +0.00 s (+0.00 %) | 919,307,323 | - | 3.85 |
| build-s80C399 | nofloor/off/0 | 4 | 0/0/0/0 | 29.65 / 30.07 / 30.30 | 0.29 | -0.55 s (-1.79 %) | 899,859,432 | -19447891 cyc (-2.12 %) | 5.88 |
| build-s80AAB3 | nofloor/off/0 | 4 | 0/0/0/0 | 29.74 / 30.02 / 30.34 | 0.32 | -0.59 s (-1.94 %) | 880,287,406 | -39019917 cyc (-4.24 %) | 7.93 |

widest same-binary spread: 0.58 s, so a credible wall difference is more than 1.15 s
inconclusive  build-s80C399 vs build-r4base: 0.55 s apart, needs > 1.15 s (the paired reading below resolves it)
inconclusive  build-s80AAB3 vs build-r4base: 0.59 s apart, needs > 1.15 s (the paired reading below resolves it)

paired by replicate label (interleaved legs cancel host drift):
  resolved  build-s80C399 vs build-r4base over 4 pairs: mean -0.55 s (sd 0.31, se 0.15), signs consistent, needs |mean| > 0.31 s and one sign
     pairs: a1 -0.14, a2 -0.48, a3 -0.75, a4 -0.82
  resolved  build-s80AAB3 vs build-r4base over 4 pairs: mean -0.59 s (sd 0.41, se 0.20), signs consistent, needs |mean| > 0.41 s and one sign
     pairs: a1 -0.03, a2 -0.97, a3 -0.59, a4 -0.78
     (tool exit=0: 0 resolved, 1 inconclusive)
