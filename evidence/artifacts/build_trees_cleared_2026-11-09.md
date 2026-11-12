# Build trees cleared at the repository root (2026-11-09)

One pass over the repository root removed every CMake build tree that a closed
round had used, keeping only the two trees the shipped packages are cut from.

* removed: 53 of the 55 root-level directories matching `build*`
* kept: `build-ship`, `build-embed-ship`
* rule applied: delete a root directory matching `build*` unless it is one of those two

No build tree is a git-tracked path: `.gitignore:11-12` carries `/build/` and
`/build-*/`, so nothing in the pushed history changed and `git status --porcelain`
was empty before the pass and empty after it.

## Sizes as measured immediately before the deletion

`du -sh build*` in the repository root, verbatim:

```
5,2M	build-llefloor
5,3M	build-llefloor-r2
7,3M	build
8,9M	build-ctrl2
8,9M	build-ctrl3
9,0M	build-lle
9,0M	build-r2
9,2M	build-r4base
9,2M	build-r4probe
9,2M	build-s80ABBC
9,2M	build-s80C399
9,4M	build-ship
9,5M	build-r4pair
9,5M	build-r5pair
9,5M	build-r6pair
9,5M	build-s80AAB3
9,5M	build-s80B1DB
9,6M	build-ctrl
9,6M	build-embed-off
9,8M	build-up
11M	build-r5base
11M	build-r6pc1c9
12M	build-pin
12M	build-r0
12M	build-r4clean
12M	build-r7l-ctrl
12M	build-r8-ctrl
12M	build-r9-ctrl
14M	build-r7l-seed
14M	build-r8-seed
14M	build-r9-seed
14M	build-s80C1B3
14M	build-s80C1C9
14M	build-s80F362
14M	build-s80F4F9
14M	build-s80F889
15M	build-r6hunt
15M	build-s80F495
18M	build-embed-ship
18M	build-up-embed
20M	build-embed
20M	build-embed2
68M	build-r3
123M	build-llefloor-r2b
127M	build-dh
132M	build-b0
143M	build-r2b
218M	build-trace
220M	build-r6tr-ctrl
220M	build-tr-ctrl
222M	build-r6tr-seed
222M	build-tr-lle
222M	build-tr-seed
224M	build-tr-aot
337M	build-dht
```

Recomputed from that block by the script that wrote this file: 55 entries, sum of the
rounded values 3,037,491 KiB = 2.90 GiB, matching the `du -ch build*` line printed with the
listing itself: `2,9G total`. The two kept entries above (`build-ship` 9,4 M,
`build-embed-ship` 18 M) are the same numbers measured again below.

## The two survivors, measured after the deletion

```
build-ship         9,652 KiB
  exe     a0587ed0a0e34687  3,103,776 B
  SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-pin
build-embed-ship   18,052 KiB
  exe     5822a85675b2640d  4,160,576 B
  SNESRECOMP_ROOT:PATH=/private/var/folders/cc/_czwdt293dg9ty_zgc1b57x00000gn/T/opencode/sr-embed
src/gen         20 files, sha256 over name+bytes 24376f14b0abf500
sr-pin    773285b8  dirty=0
sr-embed  c5024e74  dirty=0
```

These are the payload trees of the two macOS packages: `build-ship` is the
shareable (§7.19) tree at the pin, `build-embed-ship` the personal (§7.20) tree off
the pin on the embedded-ROM clone. The packaged payload hashes those runs recorded
are `60067549c3ee8d3b` (3,103,872 B) and `6a9baf0bbb72b737` (4,154,528 B); the
deltas come from `install_name_tool` plus the ad-hoc re-sign, measured byte-wise in
§3 of both transcripts.

## What still regenerates, measured by re-running every files-only generator

Full transcript: `tests/out/regen_check_2026-11-09.txt` (scratch). Each generator was
run and its stdout diffed against the committed artifact; `diff_lines` counts the
lines that differ.

| generator | artifact it writes | exit | diff_lines |
| --- | --- | --- | --- |
| `tests/latch_phase_report.py` | `round7_latch_phase.txt` | 0 | 0 |
| `tests/phase_anchor_report.py` | `round8_phase_anchor.txt` | 0 | 0 |
| `tests/round9_opening_report.py` | `round9_opening.txt` | 0 | 0 |
| `tests/round10_frame_phase_report.py` | `round10_frame_edge_phase.txt` | 0 | 2 |
| `tests/cluster_hunt_report.py` | `round6_cluster_hunt.txt` | 1 | -- |
| `tests/idle_artifacts.py cost` | `idle_poll_cost_round3.txt` | 0 | 20 |
| `tests/idle_artifacts.py a0` | `idle_poll_a0_round3.txt` | 1 | -- |
| `tests/idle_artifacts.py checkpoints` | `idle_poll_checkpoints_round3.txt` | 0 | 71 |

Three re-run byte-for-byte. For those the only change was an input path: all three
digested `tests/out/r4/gen_r6pair.tar.gz` and `…gen_r6pc1c9.tar.gz`, which are
deleted, and now digest `evidence/artifacts/round6_gen_r6pair.tar.gz` /
`…round6_gen_r6pc1c9.tar.gz` -- the same bytes, so the hashes they print are
unchanged (`7ea8e46f…`, `7fc3f392…`) and the artifacts stay identical. Nothing else
was edited in any of them.

The rest print less than what is committed, for two distinct reasons:

* **Deleted executables.** `round10_frame_edge_phase.txt` loses exactly two lines,
  the identity of `build-r9-ctrl` / `build-r9-seed` (`d4e56dadd93b9dcc`,
  `355133810fb5efac`); every tap number is unchanged, because the `.err` ledgers in
  `tests/out/r9/` survived. `idle_artifacts.py` loses the same kind of block -- the
  identity and generated-set lines for `build-r3` and `build-r2b` -- and prints
  `wait class: no framework root in build-r3/CMakeCache.txt` where it used to print
  the counters read from that cache. Rebuilding the named trees brings the lines
  back: §7.16-§7.17 carry the configure lines, and `round9_probe.diff` recreates the
  probe framework clone.
* **Pruned captures.** `idle_artifacts.py a0` refuses outright -- `no A0 checkpoint
  in: off m1x0 on m0x0 -- run ./tests/idle_parity.sh first` -- because the A0
  checkpoint captures under `tests/out/ip_*` are gone while the anchor dirs and
  their `last_run_report.json` files stayed.
* **A deleted input that was never committed.** `tests/cluster_hunt_report.py` exits
  1 with `FileNotFoundError: … /tests/out/r4/manifest_r6pair.json.bz2`. Its other
  inputs are all still there (242 files in `tests/out/r6/`, 50 of them the
  `hunt.tsv` / `forces_*` / `crc_*` / `state_*` rows it reads), but those two
  control manifests only ever lived in `tests/out/r4/`. Re-deriving
  `round6_cluster_hunt.txt` means re-running round 6's legs.
