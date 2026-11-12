# A measurement has to be bound to the program that made it

Measured 2026-11-06. Short version: **two artefacts in this repo silently stopped
identifying their inputs** — the staged `./Shadowrun` (c1) and the tree called
`./build` — and neither could be recognised as stale from the artefacts
themselves. The kit now writes a manifest next to every frame dump and refuses
to judge a pair against a baseline that names other inputs.

Plain language first, then numbers.

## The two failure modes, both measured

1. **A staged bundle whose provenance is unrecoverable.** `./Shadowrun`
   (5,941,232 B, 2026-11-05 13:20) disagrees with all four current build trees
   from frame 1 and its host-frame phase *drifts* between legs (k=0 f0–186, -1
   f187–628, -3 f630–1111). Nothing about the file says it was built from a
   different generated set — c1 has the full record.
2. **A build tree that predates the sources it appears to compile.**
   `build/CMakeFiles/ShadowrunSNESRecomp.dir/src/gen/` holds objects for **4**
   generated translation units while `src/gen` carries **17** (and
   `build-lle` also holds 4). That binary disagreed with a freshly configured
   control at frame 1 of `short.txt`. A tree full of `.o` files looks current.

Both are invisible from the artefacts, and both were read as measurements before
they were read as staleness.

## Why an executable hash is a usable identity

The guard would be noise if the same inputs linked to different bytes. Measured:

| trees | framework root | `src/gen` | flags | executable |
| --- | --- | --- | --- | --- |
| `build-embed`, `build-embed2` | same root, same rev | same 17 units | both `Release`, `SHADOWRUN_EMBED_ROM=ON`, configured at different times | **sha256 identical**, `7eb8008d7c31ae33…`, 4,351,584 B |

So a different executable hash means a different *input*, not a different link.
That is what makes the fingerprint worth comparing at all. The hashes, in full,
so a later reader can tell one artefact from another:

```
ebca100c3a01201a949104e46c5bd350da468cb15629aea9c7de6d5879fde46d  ./Shadowrun          (staged, 5,941,232 B)
3a9f15ec33693fe8178b51f0d7394690edd74d7dd5b8965c205ff9993bc76c41  build-ctrl           (3,294,480 B)
7eb8008d7c31ae33ad8c578cb3165573b7d2ced0ed109e3a55a6010588664252  build-embed   } identical
7eb8008d7c31ae33ad8c578cb3165573b7d2ced0ed109e3a55a6010588664252  build-embed2  } 4,351,584 B
```

and the generated set both embed builds were compiled from:
`24df45247dc21b36…` over 17 units / 205 promoted functions / 217 dispatch
entries.

## What a run now records

`tests/provenance.py record <binary> <dump-dir>` writes `<dump-dir>/run_manifest.json`:

- the executable: sha256 + size;
- the generated machine code it was compiled from: sha256 over `src/gen`
  (name + bytes, sorted) plus the counts that make a delta readable — **17
  units, 205 promoted guest functions, 217 dispatch entries**;
- the framework: root path, git rev, dirty flag — plus `SNESRECOMP_ROOT`,
  `CMAKE_BUILD_TYPE` and `SHADOWRUN_EMBED_ROM` read out of the tree's
  `CMakeCache.txt`;
- the port's own git rev and dirty flag;
- warnings: `stale build tree: 4 generated .o against 17 generated units`, and
  `N generated file(s) touched after this executable was linked` (the `cp -p`
  mtime hazard, which otherwise makes `cmake --build` decline to recompile).

`parity.sh`, `crosspath.sh` and `bisect_aot.sh` record every leg they run.
`framedump_diff.py horizon` prints both manifests before it prints any number.

The comparison **key drops paths**: two trees in different directories built from
the same sources are the same program. Judging a rerun against a baseline uses
the key **without** the executable hash — rebuilding identical inputs is allowed
to change nothing about the verdict.

Both warnings fire on the trace trees exactly as they sit now, and both are true
of them, which is a good sign that they are not noise:

```
build-tr-aot  WARN  stale build tree: 18 generated .o against 17 generated units in .../src/gen
build-tr-lle  WARN  18 generated file(s) touched after this executable was linked: the binary may not contain them
```

That pair is the `bs_aot`/`bs_lle` leg set behind `horizon_bs.json`, and the
cause is the §7.3 hazard: `bisect_aot.sh` regenerates `src/gen` for each
experiment, so a trace tree that was not rebuilt afterwards is looking at a
different generated set than the one it was linked from.

## The guard, both directions, with the machine

| case | what happens | exit |
| --- | --- | --- |
| legs match the inputs the baseline names | judged normally | 0 |
| baseline's stored framework rev edited to `deadbeef…` | `run1: framework was deadbeef… in the baseline, c5024e74… here`; **the scan is not run at all** | 2 |
| baseline's stored `gen_sha256` edited to `ff…`, on the real `bs_aot`/`bs_lle` dumps | refused, and `grep -c "paired at the same host frame"` over the output is **0** — no frames decoded | 2 |
| the same tampered baseline with `--inputs-changed` | delta printed as notes, then judged: `holds: horizon f16280 vs baseline f16280` | 0 |
| baseline carries no provenance block (both shipped baselines today) | a note, then judged normally | 0 |
| legs with no `run_manifest.json` beside their dumps | `no run_manifest.json in this leg's directory, so nothing proves it is the input the baseline names` | 2 |
| no baseline argument | measured, `nothing was judged` | 0 |
| baseline path does not exist | unchanged rule: no verdict | 2 |
| unknown `--nope` flag | `unknown horizon flag(s): --nope` — a flag is never read as a baseline path | 1 |

Refusing happens **before** the scan: the cross-path legs are ~26k frames and
~6.6 GiB of decoded dumps, and a horizon measured between two different programs
is not a measurement of anything — that is exactly how the stale bundle in c1
read as a physics split.

The escape hatch matters because one gate **wants** the inputs to differ. Each
bisect step regenerates `src/gen` with a different `force_lle` block, and
`horizon_bs.json` is the reference *across* those steps. So the flag is
`--inputs-changed`: it prints the delta as notes and judges the pair anyway.
Re-recording that baseline per step would destroy the reference, which is the
opposite of what a bisect needs.

## The version tag, which is a tag and not a proof

While characterising the staged bundle: `host_report:` printed `Shadowrun dev`
from its log, while every current tree prints `Shadowrun 0.1.0`. The value comes
from the port's `CMakeLists.txt`, which stamps the `VERSION` file (`0.1.0`) when
`CMAKE_BUILD_TYPE=Release`; `SNES_GAME_VERSION "dev"` in `src/main.c` is only the
fallback. All current trees carry the string `0.1.0`; the staged executable
carries neither. That says its configure differed. It is **not** evidence about
behaviour — the frame-1 divergence and the phase drift in c1 are what say that.

## What is still not bound

`tests/baselines/horizon_xp.json` and `tests/baselines/horizon_bs.json` were
captured before this existed and carry no provenance block, so against them the
guard is **note-only** and binds nothing. They get bound the next time those
gates are actually run and re-recorded with `--update`. Re-running ~26k frames
just to capture fingerprints would cost an hour of machine time and measure
nothing new, so it was deliberately not done.

Files: `tests/provenance.py` (new), `tests/framedump_diff.py` (`_prov_legs`,
`_prov_against_baseline`, the `--inputs-changed` escape hatch, provenance stored
under `summary["provenance"]` on `--update`), `tests/parity.sh`,
`tests/crosspath.sh`, `tests/bisect_aot.sh`, `tests/README.md` §4, §7.3, §7.6.
