# round4_parity_legs.md
#
# what: the parity legs the state verdicts come from, joined to the same leg's cycle counters: which seeded bodies move the machine's clock and which do not
# how:  tests/parity.sh logs in tests/out/r4/parity_*.log (run1/run2 lines, exe digests, verdict) joined to build-<run2>/last_run_report.json, whose execution_share block is that leg's report; the route is tests/out/probe_dense.txt (archived as artifacts/round4_probe_route.txt)
#
# framework pin: 773285b8210f2254ae87d0a14113980fb36990ad
# generated: 2026-11-08T08:02:38Z (host Darwin arm64)
# source tree: /Users/wee/Documents/work/ports/ShadowrunSNESRecomp

probe route: `tests/out/probe_dense.txt`, sha256 de38c3cf9499f14e, last touched 2026-11-08T02:53:13

A `last_run_report.json` is whichever leg last ran in that build dir, so
each row also shows the report's own mtime and frame count; a row is only
printed when the report's frame count equals the frame count the log says
that leg ran.

| parity leg | run1 exe | run2 exe | route exit | frames | cpu_cycles delta | master_cycles delta | verdict |
|---|---|---|---|---|---|---|---|
| r4base_r4clean | build-r4base | build-r4clean | quit 4575 | 4575 | -359252 | -12 | first divergence at frame_001831.json: 0x25A30A12 vs 0xE9DE0871; 2744 of 4575 frames differ |
| r4pair | build-r4base | build-r4pair | quit 4575 | 4575 | +0 | +0 | identical over 4575 frames |
| s80AAB3 | build-r4base | build-s80AAB3 | quit 4575 | 4575 | +0 | +0 | identical over 4575 frames |
| s80ABBC | build-r4base | build-s80ABBC | quit 4575 | 4575 | -584 | +0 | first divergence at frame_001828.json: 0xB615CF19 vs 0xC912779D; 2745 of 4575 frames differ |
| s80B1DB | build-r4base | build-s80B1DB | quit 4575 | 4575 | -359070 | -12 | first divergence at frame_001831.json: 0x25A30A12 vs 0xE9DE0871; 2744 of 4575 frames differ |
| s80B1DB_rerun | build-r4base | build-s80B1DB | quit 4575 | 4575 | -359070 | -12 | first divergence at frame_001831.json: 0x25A30A12 vs 0xE9DE0871; 2744 of 4575 frames differ |
| s80C1B3 | build-r4base | build-s80C1B3 | quit 4575 | 4575 | +31160765 | +269098180 | first divergence at frame_001766.json: 0x353B653D vs 0x63FA4232; 2809 of 4575 frames differ |
| s80C1C9 | build-r4base | build-s80C1C9 | quit 4575 | 4575 | +31160765 | +269098180 | first divergence at frame_001766.json: 0x353B653D vs 0x63FA4232; 2809 of 4575 frames differ |
| s80C399 | build-r4base | build-s80C399 | quit 4575 | 4575 | +0 | +0 | identical over 4575 frames |
| s80F362 | build-r4base | build-s80F362 | quit 4575 | 4575 | +31160765 | +269098180 | first divergence at frame_001766.json: 0x353B653D vs 0x63FA4232; 2809 of 4575 frames differ |
| s80F495 | build-r4base | build-s80F495 | quit 4575 | 4575 | +31160765 | +269098180 | first divergence at frame_001766.json: 0x353B653D vs 0x63FA4232; 2809 of 4575 frames differ |
| s80F4F9 | build-r4base | build-s80F4F9 | quit 4575 | 4575 | +31160765 | +269098180 | first divergence at frame_001766.json: 0x353B653D vs 0x63FA4232; 2809 of 4575 frames differ |
| s80F889 | build-r4base | build-s80F889 | quit 4575 | 4575 | +31160765 | +269098180 | first divergence at frame_001766.json: 0x353B653D vs 0x63FA4232; 2809 of 4575 frames differ |

Control for the deltas: `build-r4base/last_run_report.json`, written 2026-11-08T08:40:49 (frame 4575, cpu_cycles 195463918, master_cycles 1635265512).

Same join on the 22,044-frame combat route (from the variant ledgers,
which are the legs tests/seed_variant.sh ran):

| variant | route exit | interp_cycles | cpu_cycles | master_cycles |
|---|---|---|---|---|
| r4base | quit after 22044 frames (exit 0) | 919,307,323 | 956,096,571 | 7,878,127,092 |
| r4pair | quit after 22044 frames (exit 0) | 860,839,515 | 956,096,571 | 7,878,127,092 |
| s80C399 | quit after 22044 frames (exit 0) | 899,859,432 | 956,096,571 | 7,878,127,092 |
| s80AAB3 | quit after 22044 frames (exit 0) | 880,287,406 | 956,096,571 | 7,878,127,092 |
| r4clean | quit after 22044 frames (exit 0) | 626,711,944 | 955,775,558 | 7,878,127,112 |
| s80ABBC | quit after 22044 frames (exit 0) | 903,700,726 | 956,058,833 | 7,878,127,128 |
| s80B1DB | quit after 22044 frames (exit 0) | 701,658,067 | 954,239,118 | 7,878,127,130 |
