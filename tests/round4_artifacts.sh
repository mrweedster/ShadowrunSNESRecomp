#!/usr/bin/env bash
# Regenerate every artifact the M2 promotion round-4 record cites, from files
# that already exist.
#
#   SNESRECOMP_ROOT=/path/to/pin ./tests/round4_artifacts.sh
#   ART=evidence/artifacts ROUND=tests/out/r4 ./tests/round4_artifacts.sh
#
# Three rules this script exists to enforce:
#
#   * it runs no route leg, no tools/regen.sh and no cmake: every number is read
#     out of tests/out/<round> (the per-variant ledgers, the archived program
#     manifests, the archived generated sets, the tagged checkpoint dumps and the
#     aot_charge.sh leg logs). Re-measuring here would silently replace a
#     measured number with a different measurement.
#   * tests/out is scratch and git-ignored, so anything the record cites has to
#     land in the artifact directory, together with the manifests it was derived
#     from; the record cites these files, not the scratch tree.
#   * the artifact text is this script's output. If a claim in the record does
#     not appear here, the claim is wrong.
#
# What is deliberately NOT regenerated here: round4_probe_81b061.txt, whose
# generator is tests/round4_probe.py. That tool prints the probe experiment from
# archived logs too, but it also re-runs the seed generator and the pin's symbol
# loader (the $81B05D mode-conflict demonstration), so it stays its own entry
# point instead of being a cat inside this script.
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
root="${SNESRECOMP_ROOT:?run with SNESRECOMP_ROOT=<framework pin>}"
art="${ART:-evidence/artifacts}"
out="${ROUND:-tests/out/r4}"
cap="${CAPTURE:-$art/tier2_capture_round3_combat.json}"
route="${ROUTE:-tests/scripts/combat.txt}"
probe="${PROBE:-tests/out/probe_dense.txt}"
mkdir -p "$art"
charge="${CHARGE:-tests/out/charge}"
pin=$(awk -F= '/^snesrecomp=/{print $2}' framework_pins.txt)
utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
[ -f "$cap" ] || { echo "capture missing: $cap" >&2; exit 1; }

hdr() { # hdr <file> <what it answers> <how it was produced>
  printf '# %s\n#\n# what: %s\n# how:  %s\n' "$(basename "$1")" "$2" "$3" > "$1"
  printf '#\n# framework pin: %s\n# generated: %s (host %s)\n' \
    "$pin" "$utc" "$(uname -sm)" >> "$1"
  printf '# source tree: %s\n\n' "$(pwd)" >> "$f"
}

# -------------------------------------------------- 0. archived input sets
# The record's claims are measured against archived programs, not the live
# src/gen, so those archives are part of the evidence.  The flat, unversioned
# names an earlier pass used are renamed into the round4_ set rather than left
# beside it: two digests for one program is a second source of truth.
[ -f "$art/manifest_pre_round4.json.bz2" ] \
  && mv "$art/manifest_pre_round4.json.bz2" "$art/round4_manifest_pre.json.bz2"
[ -f "$art/manifest_round4_full10.json.bz2" ] && rm -f "$art/manifest_round4_full10.json.bz2"
[ -f "$art/seeds10_gen_round4.tar.gz" ] && rm -f "$art/seeds10_gen_round4.tar.gz"
for v in $(ls "$out" | sed -n 's/^manifest_\(.*\)\.json\.bz2$/\1/p' | sort -u); do
  cp -p "$out/manifest_$v.json.bz2" "$art/round4_manifest_$v.json.bz2"
done
[ -f "$out/manifest_r4_full10.json" ] \
  && bzip2 -9c "$out/manifest_r4_full10.json" > "$art/round4_manifest_full10.json.bz2"
for v in r4base r4pair; do
  [ -f "$out/gen_$v.tar.gz" ] && cp -p "$out/gen_$v.tar.gz" "$art/round4_gen_$v.tar.gz"
done
# The accepted tree's own capture: the round-4 ranking is measured against the
# control program, so a claim about what is left to seed after the pair needs a
# capture of the accepted program, and that has to ship for the claim to be
# checkable at all.
acc="$out/accepted"
[ -f "$acc/capture_accepted.json" ] \
  && cp -p "$acc/capture_accepted.json" "$art/tier2_capture_round4_accepted.json"
capacc="$art/tier2_capture_round4_accepted.json"
# The parity legs (the state gate) ran a probe route that lives in the scratch
# tree; without an archived copy those legs are not reproducible, so it ships.
[ -f "$probe" ] && cp -p "$probe" "$art/round4_probe_route.txt"

# ---------------------------------------------------------------- 1. ledgers
f="$art/round4_variant_ledgers.txt"
hdr "$f" "one block per seed variant: seed table, regen counts, manifest and generated-set digests, exe digest, route exit, execution share" \
      "cat of $out/variant_<name>.out, the redirects of tests/seed_variant.sh; the 'baseline: ... [[func]] entries left' line is re-derived from recomp/symbols.toml (the committed table the variants were cut from) by the current gap_seeds.py, because those logs predate the anchored entry counter (a loose count read the table's header prose as an entry, 41 for a 40-entry baseline)"
# The archived leg logs were written by a gap_seeds.py that counted `[[func]]`
# with a substring match, so their baseline line says 41 for a table that
# declares 40. Re-derive that one line from the same table with the current
# generator; every other line in the log stays byte-for-byte as the leg wrote it.
base_line=$(python3 tests/gap_seeds.py --baseline-only recomp/symbols.toml 2>&1 >/dev/null)
for v in $(ls "$out" | sed -n 's/^variant_\(.*\)\.out$/\1/p' | sort -u); do
  printf '\n================================================================================\n' >> "$f"
  printf '## variant %s  (source: %s)\n' "$v" "$out/variant_${v}.out" >> "$f"
  sed "s|baseline: .*|$base_line|" "$out/variant_${v}.out" >> "$f"
done

# --------------------------------------------------------------- 2. sweep
f="$art/round4_sweep.tsv"
hdr "$f" "the per-seed sweep: one row per gap seed, what the route did with it, and the frame-dump verdict" \
      "cat of $out/sweep_r4base.tsv (redirect of tests/seed_sweep.sh); columns: variant, seed, build, route exit, first abandon, aot share, state verdict"
cat "$out/sweep_r4base.tsv" >> "$f"

# ------------------------------------------------------------- 3. seed rank
f="$art/round4_seed_ranking.txt"
hdr "$f" "which (pc,mx) entries round 4 could seed, in the capture's own cycle order, and what is still seedable once a set is shipped" \
      "python3 tests/gap_seeds.py \$cap --top 10 --route combat --list --manifest M --symbols T; stdout is the ranking, stderr the summary of what --top 10 covers"
run_rank() { # run_rank <label> <manifest> <symbols>
  printf '\n==== %s\n     manifest %s\n     symbols  %s\n' "$1" "$2" "$3" >> "$f"
  python3 tests/gap_seeds.py "$cap" --top 10 --route combat --list \
      --manifest "$2" --symbols "$3" >> "$f" 2>&1
}
run_rank "the pre-round program and the pre-round seed table (what round 4 started from)" \
  "$art/round4_manifest_pre.json.bz2" "$out/cfg/symbols_base.toml"
run_rank "the control tree r4base (committed table, gap blocks stripped)" \
  "$out/manifest_r4base.json.bz2" "$out/variant_r4base_symbols.toml"
run_rank "the accepted pair shipped (live recomp/symbols.toml)" \
  "$out/manifest_r4pair.json.bz2" recomp/symbols.toml

# ------------------------------------------------------------ 4. seed text
f="$art/round4_seed_tables.txt"
hdr "$f" "the generated seed blocks: the one the tree ships, and the ones the round generated and did not ship" \
      "generated blocks extracted out of the tables, plus their digests; the generator is tests/gap_seeds.py, so a block is checked against a fresh generation of the same seeds"
python3 - "$out" "$cap" "$art/round4_manifest_pre.json.bz2" <<'PY' >> "$f" 2>&1
import hashlib, os, re, subprocess, sys
out, cap, pre = sys.argv[1:4]

def blocks(path):
    """The generated (gap-driven seeds) blocks, by the same split accepted_tree.sh uses."""
    text = open(path).read()
    return [c for c in re.split(r"(?m)^(?=# --- )", text)
            if "(gap-driven seeds)" in c.split("\n", 1)[0]]

def sha(s):
    return hashlib.sha256(s if isinstance(s, bytes) else s.encode()).hexdigest()[:16]

def n_entries(text):
    """Real `[[func]]` headers only: the file's own header comment and every block
    note mention `[[func]]` in prose, and a substring count reads that as an entry."""
    if isinstance(text, bytes):
        return len(re.findall(rb"(?m)^\[\[func\]\][ \t]*\r?$", text))
    return len(re.findall(r"(?m)^\[\[func\]\][ \t]*\r?$", text))

def show(path):
    bs = blocks(path)
    whole = open(path, "rb").read()
    print("== %s" % path)
    print("   whole table sha256 %s, %d [[func]] entries in the file"
          % (sha(whole), n_entries(whole)))
    for b in bs:
        head = b.split("\n", 1)[0]
        pcs = ["$" + n.upper() for n in re.findall(r'^name = "GS_([0-9A-Fa-f]{6})"', b, re.M)]
        print("   block: %d lines, %d [[func]], seeds %s"
              % (len(b.splitlines()), n_entries(b), " ".join(pcs)))
        print("   block sha256 %s (leading separator normalised)"
              % sha(b.lstrip("\n")))
        print(b.rstrip())
    return bs

show("recomp/symbols.toml")
for name in ("symbols_pair.toml", "symbols_full10.toml"):
    p = os.path.join(out, name)
    if os.path.exists(p):
        show(p)

# Re-derive the shipped block from the capture over the shipped table with its
# generated blocks stripped, and compare.  A typed edit to the shipped block
# would show up here as a sha mismatch.
live = os.path.join(out, "cfg", "artifacts_live_base.toml")
regen = os.path.join(out, "cfg", "artifacts_gap_block.toml")
with open(live, "w") as fh:
    subprocess.run([sys.executable, "tests/gap_seeds.py", "--baseline-only",
                    "recomp/symbols.toml"], stdout=fh, check=True)
with open(regen, "w") as fh:
    subprocess.run([sys.executable, "tests/gap_seeds.py", cap, "--route", "combat",
                    "--round", "4", "--only", "$80C399,$80AAB3", "--symbols", live,
                    "--manifest", pre], stdout=fh, check=True)
ship = "".join(blocks("recomp/symbols.toml")).lstrip("\n")
new = open(regen).read().lstrip("\n")
print("\n== shipped block re-derived from the capture over the stripped shipped table")
print("   command: tests/gap_seeds.py %s --route combat --round 4 "
      "--only '$80C399,$80AAB3' --symbols <stripped table> --manifest %s" % (cap, pre))
print("   shipped sha256 %s   re-derived sha256 %s   %s   (%d lines)"
      % (sha(ship), sha(new), "MATCH" if ship == new else "MISMATCH", len(new.splitlines())))
if ship != new:
    import difflib
    print("\n".join(list(difflib.unified_diff(ship.splitlines(), new.splitlines(),
                                              lineterm=""))[:40]))
PY

# -------------------------------------------------------- 5. gap-seed audit
f="$art/round4_gap_seed_audit.txt"
hdr "$f" "what the analyzer did with each seed set: node disposition, plus the capture-side cost that falls inside the bodies it added" \
      "python3 tests/gap_seed_audit.py, four invocations, over the archived manifests; the merged-span figure is an upper bound because two ranges can share a body"
for spec in "accepted pair, shipped|$out/manifest_r4pair.json.bz2|$out/variant_r4pair_symbols.toml" \
            "all 10 seeds, not shipped|$art/round4_manifest_full10.json.bz2|$out/cfg/symbols_r4_full10.toml" \
            "rejected seed \$80ABBC|$out/manifest_s80ABBC.json.bz2|$out/variant_s80ABBC_symbols.toml" \
            "rejected seed \$80B1DB|$out/manifest_s80B1DB.json.bz2|$out/variant_s80B1DB_symbols.toml"; do
  IFS='|' read -r label man sym <<<"$spec"
  printf '\n================================================================================\n' >> "$f"
  printf '## %s\n##   symbols        %s\n##   post-manifest  %s\n' "$label" "$sym" "$man" >> "$f"
  python3 tests/gap_seed_audit.py --post-manifest "$man" --capture "$cap" \
      --pre-manifest "$art/round4_manifest_pre.json.bz2" --symbols "$sym" >> "$f" 2>&1
done

# ----------------------------------------------------------- 6. state gate
f="$art/round4_state_gate.md"
hdr "$f" "the adoption gate: per-checkpoint machine state for every seeded tree against the control run" \
      "tests/cpdump_matrix.py then tests/apu_shift.py per variant; the checkpoint dumps they read live in $out/<variant>/ (scratch: 22 tagged checkpoints per run).  The same question at byte level is in $art/round4_state_bytes.md"
python3 tests/cpdump_matrix.py "$out/r4base" "$out/r4pair" "$out/r4clean" \
    "$out/s80C399" "$out/s80AAB3" "$out/s80ABBC" "$out/s80B1DB" "$out/r4probe" >> "$f" 2>&1
for v in r4pair r4clean s80C399 s80AAB3 s80ABBC s80B1DB; do
  [ -f "$out/apu_shift_$v.md" ] || continue
  printf '\n==== apu_shift %s (source: %s/apu_shift_%s.md)\n' "$v" "$out" "$v" >> "$f"
  cat "$out/apu_shift_$v.md" >> "$f"
done

# ----------------------------------------- 6a. the state bytes behind the gate
# cpdump_matrix answers "does this checkpoint's state match"; this says *how much*
# of it differs, and separates the WRAM bytes the label rule excuses (the host's
# frame-kernel counter window and the game's timer singletons, both of which move
# when the clock moves) from the ones that are a computation going somewhere else.
# The whole point is that a rejection can cite a byte: the rejected seeds all show
# exactly one non-label WRAM byte at the first gate checkpoint, and it is the same
# address.  fb.bgrx is on the surface list because a guest-state change eventually
# lands there; the accepted tree's framebuffer is identical too.
f="$art/round4_state_bytes.md"
hdr "$f" "the same gate read at byte level: for every checkpoint, how many state-image bytes differ, how many of them are label bytes, and the exact non-label bytes; then whether a rejected seed's split survives phase alignment" \
      "tests/cp_byte_diff.py <control> <variant> over every tagged checkpoint with all five guest memory images plus the host framebuffer (wram.bin vram.bin oam.bin cgram.bin sram.bin fb.bgrx); label/state split comes from the label rule in tests/framedump_diff.py, which cp_byte_diff.py imports rather than restates.  Inputs are the checkpoint dumps in $out/<variant>/ and $out/accepted/.  The alignment probes at the end come from tests/rejected_shift.sh, whose logs are $out/shift_<variant>.md"
printf '#\n# how to read: `label` bytes are the ones the framedump_diff rule excuses (frame-kernel\n' >> "$f"
printf '# counter window $01C80-$01D40, timer singletons $012C/$012E/$012F/$0132); `state` is every\n' >> "$f"
printf '# other differing byte, and those are the ones shown.  A row with state 0 is a clock shift,\n' >> "$f"
printf '# not a wrong computation -- and it still fails the gate, because the gate is byte equality\n' >> "$f"
printf '# against the control tree.  The first pair is the same program run twice: that is what a\n' >> "$f"
printf '# clean row looks like here, so any non-zero state count on a seeded tree is the seed.\n' >> "$f"
while IFS='|' read -r label a b; do
  [ -d "$out/$a" ] && [ -d "$out/$b" ] || { printf '\n==== %s\nmissing %s or %s\n' "$label" "$out/$a" "$out/$b" >> "$f"; continue; }
  printf '\n==== %s\n' "$label" >> "$f"
  python3 tests/cp_byte_diff.py "$out/$a" "$out/$b" \
      wram.bin vram.bin oam.bin cgram.bin sram.bin fb.bgrx >> "$f" 2>&1
done <<EOF
same program, run twice (harness determinism control): accepted tree vs its own anchor exe|accepted/r4pair_accepted|accepted/anchor_pair
r4pair, the accepted pair|r4base|r4pair
the accepted tree, as checked out|r4base|accepted/r4pair_accepted
seed only: \$80C399|r4base|s80C399
seed only: \$80AAB3|r4base|s80AAB3
rejected: seed only \$80ABBC|r4base|s80ABBC
rejected: seed only \$80B1DB|r4base|s80B1DB
rejected: all ten gap seeds that gate (\$80C399+\$80AAB3+\$80ABBC+\$80B1DB)|r4base|r4clean
EOF

# The byte rows above compare the two runs at the *same checkpoint*, which leaves
# one objection open: the legs may sit at different points of the guest's own
# timeline, so the control's state would line up at run2[f+k] rather than run2[f].
# tests/rejected_shift.sh settles that on the frame dumps -- parity.sh on the probe
# route with per-frame WRAM, then framedump_diff.py tick (is the offset even
# constant?), shift (does any offset make them byte-identical once label bytes are
# excluded?) and byte (one address's value timeline and a histogram per leg, so
# "same values, counts moved" reads as phase and "a value only one leg writes"
# reads as state).  Each probe block names the exes that made its dumps.
printf '\n==== does the split of a rejected seed survive phase alignment on the frame dumps?\n' >> "$f"
printf '# how:  tests/rejected_shift.sh -- tests/parity.sh on route %s (control exe\n' "$probe" >> "$f"
printf '#       build-r4base/ShadowrunSNESRecomp, seeded exe copied to %s/anchor_<variant>/),\n' "$out" >> "$f"
printf '#       then tests/framedump_diff.py tick / shift / drift / state / byte on that\n' >> "$f"
printf '#       leg and its frame dumps; `tick` is what makes the f<->f coordinate honest, `state`\n' >> "$f"
printf '#       is what names the bytes on this route\n' >> "$f"
for v in s80ABBC s80B1DB r4clean; do
  if [ -f "$out/shift_$v.md" ]; then
    printf '\n---- %s\n' "$v" >> "$f"
    cat "$out/shift_$v.md" >> "$f"
  else
    printf '\n---- %s: missing %s\n' "$v" "$out/shift_$v.md" >> "$f"
  fi
done

# ------------------------------------------------- 6b. the parity legs joined
# The state verdicts in $out/sweep_r4base.tsv come from tests/parity.sh legs on
# a probe route, not the 22,044-frame combat route, and the counters that explain
# them are the same legs' reports in each build dir.  This section puts the two
# side by side and refuses to join a report whose frame count disagrees with the
# log it is joined to.
f="$art/round4_parity_legs.md"
hdr "$f" "the parity legs the state verdicts come from, joined to the same leg's cycle counters: which seeded bodies move the machine's clock and which do not" \
      "tests/parity.sh logs in $out/parity_*.log (run1/run2 lines, exe digests, verdict) joined to build-<run2>/last_run_report.json, whose execution_share block is that leg's report; the route is $probe (archived as $(basename "$art")/round4_probe_route.txt)"
python3 - "$out" "$art" "$probe" <<'PY' >> "$f" 2>&1
import glob, json, os, re, sys
out, art, probe = sys.argv[1:4]

def report(build):
    p = os.path.join(build, "last_run_report.json")
    if not os.path.exists(p):
        return None
    j = json.load(open(p))
    return j.get("execution_share") or {}

def leg(path):
    """run1/run2 binaries, their exits and exe digests, and the verdict lines."""
    txt = open(path, errors="replace").read()
    runs = re.findall(r"^(run\d)\s+(\S+)\n(.*?)(?=^run\d|^\S|\Z)", txt, re.M | re.S)
    outs = []
    for tag, exe, body in runs:
        ex = re.search(r"exit: script (\w+)[^\n]*?(\d+) frames", body)
        sha = re.search(r"exe\s+sha256 ([0-9a-f]{16})", body)
        outs.append(dict(tag=tag, exe=exe,
                         exit=(ex.group(1) + " " + ex.group(2)) if ex else "?",
                         frames=ex.group(2) if ex else "",
                         sha=sha.group(1) if sha else "?"))
    verdict = [v for v in re.findall(r"identical over \d+ frames|"
                                     r"first divergence at frame_\d+[^\n]*|"
                                     r"\d+ of \d+ frames differ", txt)]
    return outs, verdict

import time
print("probe route: `%s`, sha256 %s, last touched %s\n"
      % (probe, __import__("hashlib").sha256(open(probe, "rb").read()).hexdigest()[:16],
         time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(os.path.getmtime(probe)))))
print("A `last_run_report.json` is whichever leg last ran in that build dir, so")
print("each row also shows the report's own mtime and frame count; a row is only")
print("printed when the report's frame count equals the frame count the log says")
print("that leg ran.\n")
print("| parity leg | run1 exe | run2 exe | route exit | frames | cpu_cycles delta | master_cycles delta | verdict |")
print("|---|---|---|---|---|---|---|---|")
base = report("build-r4base")
skipped = []
for log in sorted(glob.glob(os.path.join(out, "parity_*.log"))):
    runs, verdict = leg(log)
    if len(runs) < 2:
        continue
    b1, b2 = runs[0], runs[1]
    m1 = re.search(r"^(\.?/?.*build-[^/]+)/ShadowrunSNESRecomp$", b1["exe"])
    m2 = re.search(r"^(\.?/?.*build-[^/]+)/ShadowrunSNESRecomp$", b2["exe"])
    build1, build2 = m1.group(1) if m1 else "?", m2.group(1) if m2 else "?"
    ra, rb = report(build1), report(build2)
    tag = os.path.basename(log)[len("parity_"):-len(".log")]
    if not ra or not rb:
        skipped.append((tag, "no last_run_report.json in %s or %s" % (build1, build2)))
        continue
    frames = rb.get("frame")
    if str(frames) != b2["frames"] or str(ra.get("frame")) != b1["frames"]:
        skipped.append((tag, "report frame=%s/%s but the legs ended at %s/%s"
                        % (ra.get("frame"), frames, b1["frames"], b2["frames"])))
        continue
    print("| %s | %s | %s | %s | %s | %+d | %+d | %s |"
          % (tag, os.path.basename(build1), os.path.basename(build2),
             b2["exit"], frames,
             (rb.get("cpu_cycles", 0) or 0) - (base.get("cpu_cycles", 0) or 0),
             (rb.get("master_cycles", 0) or 0) - (base.get("master_cycles", 0) or 0),
             "; ".join(verdict)))
if skipped:
    print("\nnot joined (the report in the build dir does not describe that leg):")
    for tag, why in skipped:
        print("  %-22s %s" % (tag, why))
print("\nControl for the deltas: `build-r4base/last_run_report.json`, written %s "
      "(frame %s, cpu_cycles %s, master_cycles %s)."
      % (time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(
            os.path.getmtime("build-r4base/last_run_report.json"))),
         base.get("frame"), base.get("cpu_cycles"), base.get("master_cycles")))
print("\nSame join on the 22,044-frame combat route (from the variant ledgers,")
print("which are the legs tests/seed_variant.sh ran):")
print("\n| variant | route exit | interp_cycles | cpu_cycles | master_cycles |")
print("|---|---|---|---|---|")
for v in ("r4base", "r4pair", "s80C399", "s80AAB3", "r4clean", "s80ABBC", "s80B1DB"):
    p = os.path.join(out, "variant_%s.out" % v)
    if not os.path.exists(p):
        continue
    txt = open(p).read()
    m = re.search(r"interp +[\d.]+%  aot +[\d.]+%  interp_cycles ([\d,]+)  "
                  r"cpu_cycles ([\d,]+)  master_cycles ([\d,]+)", txt)
    e = re.search(r"exit=(\d+) .*exit: script (\w+) (?:after|timed out after) "
                  r"(\d+) frames", txt)
    if m and e:
        print("| %s | %s after %s frames (exit %s) | %s | %s | %s |"
              % (v, e.group(2), e.group(3), e.group(1), m.group(1), m.group(2), m.group(3)))
PY

# -------------------------------------------------- 6c. generated-set deltas
f="$art/round4_generated_sets.md"
hdr "$f" "what each seed actually changed in the generated program: which files, and which functions appeared" \
      "the archived generated sets (round4_gen_r4base.tar.gz, round4_gen_r4pair.tar.gz and $out/gen_<variant>.tar.gz) unpacked and compared; function names read out of dispatch_v2.c"
tmp=$(mktemp -d)
unpack() { mkdir -p "$tmp/$1"; tar xzf "$2" -C "$tmp/$1" 2>/dev/null; }
unpack base "$art/round4_gen_r4base.tar.gz"
for v in r4pair s80C399 s80AAB3 s80ABBC s80B1DB r4clean; do
  [ -f "$out/gen_$v.tar.gz" ] && unpack "$v" "$out/gen_$v.tar.gz"
done
python3 - "$tmp" <<'PY' >> "$f" 2>&1
import os, re, sys
tmp = sys.argv[1]

def funcs(d):
    # Entry-symbol names as the generator spells them: FR_/CC_ come from the
    # committed cfg blocks, GS_ from tests/gap_seeds.py's generated seed block.
    p = os.path.join(d, "gen", "dispatch_v2.c")
    if not os.path.exists(p):
        return set()
    return set(re.findall(r"\b((?:GS|CC|FR)_[0-9A-Fa-f]{6})\b", open(p).read()))

def files(d):
    g = os.path.join(d, "gen")
    return {f: os.path.getsize(os.path.join(g, f))
            for f in os.listdir(g) if os.path.isfile(os.path.join(g, f))}

base_f, base_n = files(os.path.join(tmp, "base")), funcs(os.path.join(tmp, "base"))
print("control generated set: %d files, %d dispatch function names\n"
      % (len(base_f), len(base_n)))
for v in sorted(d for d in os.listdir(tmp) if d != "base"):
    d = os.path.join(tmp, v)
    cur, n = files(d), funcs(d)
    changed = [(k, base_f.get(k), cur[k]) for k in sorted(cur)
               if base_f.get(k) != cur[k]]
    print("== %s: %d file(s) differ, functions +%d / -%d (total %d)"
          % (v, len(changed), len(n - base_n), len(base_n - n), len(n)))
    for k, a, b in changed:
        print("   %-28s %s -> %s B" % (k, a, b))
    if n - base_n:
        print("   new:  %s" % " ".join(sorted(n - base_n)))
    if base_n - n:
        print("   gone: %s" % " ".join(sorted(base_n - n)))
    # A seeded body is emitted as <name>_M<m>X<x>; show which variants of the
    # seeded entry appeared, because only some mode combinations are compiled.
    for fn in sorted(n - base_n):
        pats = set()
        g = os.path.join(d, "gen")
        for f in sorted(os.listdir(g)):
            if f.endswith(".c"):
                pats |= set(re.findall(r"\b(%s_M\dX\d)\b" % fn,
                                       open(os.path.join(g, f)).read()))
        print("   %s compiled mode variants: %s" % (fn, " ".join(sorted(pats)) or "none"))
PY
rm -rf "$tmp"

# Same variants, read from the manifests instead of the source: the node-level
# delta says which bodies the seed reached and how the recompiler disposed of
# each one, which is what the file-level diff above is really summarising.
printf '\n==== manifest node delta\n' >> "$f"
python3 - "$art/round4_manifest_r4base.json.bz2" "$out" <<'PY' >> "$f" 2>&1
import bz2, glob, json, os, sys
ctrl_path, out = sys.argv[1:3]


def nodes(path):
    j = json.load(bz2.open(path)) if path.endswith(".bz2") else json.load(open(path))
    prog = j.get("program") or j
    return {k: v for k, v in (prog.get("nodes") or {}).items()}


def fmt(k, v):
    return "%-14s %-12s %4d insns  $%06X-$%06X" % (
        k, v.get("disposition", "?"), v.get("instruction_count", 0),
        v.get("min_pc24", 0), v.get("max_pc24", 0))


ctrl = nodes(ctrl_path)
print("control program: %d nodes (%s)\n" % (
    len(ctrl), ", ".join("%s %d" % (d, sum(1 for v in ctrl.values()
                                           if v.get("disposition") == d))
                         for d in sorted({v.get("disposition") for v in ctrl.values()}))))
for path in sorted(glob.glob(os.path.join(out, "manifest_*.json.bz2"))):
    name = os.path.basename(path)[len("manifest_"):-len(".json.bz2")]
    cur = nodes(path)
    added, gone = sorted(set(cur) - set(ctrl)), sorted(set(ctrl) - set(cur))
    changed = [k for k in sorted(set(cur) & set(ctrl))
               if cur[k].get("digest") != ctrl[k].get("digest")
               or (cur[k].get("min_pc24"), cur[k].get("max_pc24"),
                   cur[k].get("instruction_count"), cur[k].get("disposition"))
               != (ctrl[k].get("min_pc24"), ctrl[k].get("max_pc24"),
                   ctrl[k].get("instruction_count"), ctrl[k].get("disposition"))]
    print("== %s: %d nodes (%+d), removed %d, changed %d"
          % (name, len(cur), len(cur) - len(ctrl), len(gone), len(changed)))
    for k in added:
        print("   + %s" % fmt(k, cur[k]))
    for k in gone:
        print("   - %s" % fmt(k, ctrl[k]))
    for k in changed:
        print("   ~ %s -> %s" % (fmt(k, ctrl[k]), fmt(k, cur[k])))
PY

# --------------------------------------------------------- 7. hot vs aot
f="$art/round4_hot_vs_aot.md"
hdr "$f" "how much of the interpreted residue already sits inside a body this same program has, and how little of that is reachable at a transfer gap" \
      "python3 tests/hot_vs_aot.py $cap $out/manifest_r4base.json.bz2 (the control program: no other tree in this round was captured)"
python3 tests/hot_vs_aot.py "$cap" "$out/manifest_r4base.json.bz2" >> "$f" 2>&1

# ------------------------------------------------------- 8. cycle ledger
f="$art/round4_charge_ledger.md"
hdr "$f" "the cycle ledger: one route, several trees, every host switch pinned per leg, so the counters subtract" \
      "tests/charge_report.py $charge base_nf <legs>, over the legs listed in $out/charge_ledger_run.log; each leg's switches come from its own <leg>.flags.tsv.  tests/aot_charge.sh writes its legs and flags into $charge, not into $out"
legs=$(sed -n 's/^== leg \([a-z0-9_]*\).*/\1/p' "$out/charge_ledger_run.log" | tr '\n' ' ')
printf 'legs: the %s legs of $out/charge_ledger_run.log, joined against base_nf\n\n' \
  "$(printf '%s\n' $legs | wc -l | tr -d ' ')" >> "$f"
python3 tests/charge_report.py "$charge" base_nf $legs >> "$f" 2>&1
printf '\n==== leg headers, exits and counters, as tests/aot_charge.sh printed them\n' >> "$f"
grep -E '^== leg|exit=|frames=' "$out/charge_ledger_run.log" | sed 's/^/  /' >> "$f"

# --------------------------------------------------------- 9. wall clock
f="$art/round4_wall_clock.md"
hdr "$f" "wall clock per binary in ms: same-binary replicates give the noise floor, and an interleaved batch is read pairwise against the control leg it ran next to" \
      "tests/charge_wall.py over every $out/charge_hostcost_run.log / $out/charge_wallbatch*.log; legs from tests/aot_charge.sh with SCRIPT=$route. exit=0 means the differences cleared the floor, 1 means inconclusive"
wall() { # wall <log> <control-prefix> <other prefixes...>   (prefix order fixes the control)
  local log=$1; shift
  [ -f "$log" ] || return 0
  printf '\n==== %s\n     tests/charge_wall.py %s %s\n' "$log" "$log" "$*" >> "$f"
  python3 tests/charge_wall.py "$log" "$@" >> "$f" 2>&1
  printf '     (tool exit=%s: 0 resolved, 1 inconclusive)\n' "$?" >> "$f"
}
wall "$out/charge_hostcost_run.log" base_ pair_ c399_ aab3_ probe_
wall "$out/charge_wallbatch.log" wbase_ wpair_
wall "$out/charge_wallbatch2.log" base_ c399_ aab3_

# ----------------------------------------------------- 10. execution mode
f="$art/round4_execution_mode_grep.txt"
hdr "$f" "whether SNESRECOMP_FORCE_FLOOR / SNESRECOMP_EXECUTION_MODE is a lever in this port" \
      "grep over the pinned framework's runner, recompiler and docs, plus this tree's src/, recomp/ and CMakeLists.txt, plus every round-4 leg log"
{
  printf '\n## pinned framework: FORCE_FLOOR and the execution-mode entry points\n'
  grep -rn 'FORCE_FLOOR\|EXECUTION_MODE\|execution_publishes_floor\|execution_mode()' \
      "$root/runner" "$root/recompiler" "$root/docs" 2>/dev/null
  printf '\n## files under runner/src that reference the execution-mode unit\n'
  grep -rl 'execution_mode' "$root/runner/src" 2>/dev/null | sed 's/^/  /'
  printf '\n## this port: src/gen, recomp/, CMakeLists.txt\n'
  grep -rn 'FORCE_FLOOR\|EXECUTION_MODE\|execution_mode' src recomp CMakeLists.txt 2>/dev/null
  printf '\n## every round-4 leg log: did any of them print an execution-mode banner?\n'
  grep -rlE '\[execution_mode\] policy=' "$out" "$art" 2>/dev/null | sed 's/^/  /'
  printf '  (nothing above = no leg printed one, so floor/nofloor legs measure the same program)\n'
} >> "$f"

# ------------------------------------------------- 11. symbol table shape
f="$art/round4_symbol_table_key.txt"
hdr "$f" "can the seed table declare one entry per (address, mode)? the pin's own loader rule, quoted, joined to the capture's hot rows" \
      "python3 tests/symbol_table_key.py $cap $out/manifest_r4base.json.bz2"
python3 tests/symbol_table_key.py "$cap" "$out/manifest_r4base.json.bz2" >> "$f" 2>&1

# ----------------------------------------------------- 12. accepted tree
f="$art/round4_accepted_tree.txt"
hdr "$f" "the checked-out tree is the accepted variant, and its seed block is what the generator emits for it" \
      "OUT=$out PRE=$art/round4_manifest_pre.json.bz2 SNESRECOMP_ROOT=$root ./tests/accepted_tree.sh r4pair"
OUT="$out" PRE="$art/round4_manifest_pre.json.bz2" ROUTE_NAME=combat \
  ./tests/accepted_tree.sh r4pair >> "$f" 2>&1
printf '\n     (tool exit=%s)\n' "$?" >> "$f"

# ------------------------------------------------- 13. the abandon wall
f="$art/round4_abandon_wall.txt"
hdr "$f" "the seeds that stopped the route: what the host reported when a seeded body met an unauthorized dispatch" \
      "the sweep rows whose route exit is not a script quit, joined to the abandon accounting in each build's last_run_report.json"
awk -F'\t' '$4 !~ /quit/' "$out/sweep_r4base.tsv" >> "$f"
printf '\n' >> "$f"
for d in build-r4base build-r4pair build-r4clean build-s80C1C9 build-s80C1B3 build-s80C399 \
         build-s80F495 build-s80F362 build-s80AAB3 build-s80F4F9 build-s80ABBC build-s80B1DB \
         build-s80F889 build-r4probe; do
  [ -f "$d/last_run_report.json" ] || continue
  printf '==== %s\n' "$d" >> "$f"
  python3 - "$d/last_run_report.json" <<'PY' >> "$f" 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
a = d.get("unresolved_abandons") or {}
print("   total_hits=%s distinct_sites=%s sites=%s"
      % (a.get("total_hits"), a.get("distinct_sites"), a.get("sites")))
PY
done

# ------------------------------------------- 14. the accepted tree, measured
# The round's verdict is about a tree that is now checked out, so the record also
# carries the legs that re-measure that tree: same route, same script, state
# compared against the control run, parity against the control exe.  The log is
# tests/accepted_verify.sh's own output; it runs the legs, this script only cats
# it, so the numbers here are the same measurement, not a second one.
f="$art/round4_accepted_verify.md"
hdr "$f" "the accepted tree measured again end to end: generated-set and exe identity, route counters, per-checkpoint state against the control run, parity against the control exe, and a capture of the program that shipped the pair" \
      "cat of $acc/accepted_verify.log, the redirect of tests/accepted_verify.sh (its legs run from a scratch anchor under $acc/, never in a build dir, so no last_run_report.json used above is overwritten)"
if [ -f "$acc/accepted_verify.log" ]; then
  cat "$acc/accepted_verify.log" >> "$f"
else
  printf 'missing %s: run tests/accepted_verify.sh\n' "$acc/accepted_verify.log" >> "$f"
fi

# ------------------------------------------------- 15. residue after the pair
# A shipped body makes its own entry unseedable, so the seed list for the next
# round is not the round-4 ranking minus what was adopted: it has to be re-ranked
# over a capture of the tree that has those bodies.  One tool, two captures, so
# both sides of the join are measured by the same rules.
f="$art/round4_residue_after.md"
hdr "$f" "the residue and the gap ranking measured against the tree that shipped the accepted pair: what left the seedable list, what is still there, and what the next round could seed" \
      "tests/gap_seeds.py over $cap (the control program the round ranked against) with --then $capacc (the accepted program), plus tests/coverage_gaps.py on each capture"
if [ -f "$capacc" ]; then
  printf '==== residue on the control capture (the program round 4 ranked against)\n' >> "$f"
  python3 tests/coverage_gaps.py "$cap" --top 3 >> "$f" 2>&1
  printf '\n==== residue on the accepted program capture\n' >> "$f"
  python3 tests/coverage_gaps.py "$capacc" --top 3 >> "$f" 2>&1
  printf '\n==== the round-4 ranking, re-ranked against the accepted program\n' >> "$f"
  printf '     tests/gap_seeds.py %s --top 10 --route combat --list \\\n' \
    "$(basename "$cap")" >> "$f"
  printf '       --manifest %s --symbols %s \\\n' \
    "$art/round4_manifest_pre.json.bz2" "$out/cfg/symbols_base.toml" >> "$f"
  printf '       --then %s --then-manifest %s --then-symbols recomp/symbols.toml\n' \
    "$(basename "$capacc")" "$art/round4_manifest_r4pair.json.bz2" >> "$f"
  python3 tests/gap_seeds.py "$cap" --top 10 --route combat --list \
    --manifest "$art/round4_manifest_pre.json.bz2" --symbols "$out/cfg/symbols_base.toml" \
    --then "$capacc" --then-manifest "$art/round4_manifest_r4pair.json.bz2" \
    --then-symbols recomp/symbols.toml >> "$f" 2>&1
  printf '     (tool exit=%s)\n' "$?" >> "$f"
else
  printf 'missing %s: run tests/accepted_verify.sh, then re-run this script\n' \
    "$capacc" >> "$f"
fi

# ------------------------------------------------------- 16. provenance
f="$art/round4_provenance.txt"
hdr "$f" "what round 4 measured against, and every artifact that carries its evidence" \
      "this script; the file index is shasum -a 256 over $art/round4_*"
{
  printf 'framework pin file : framework_pins.txt\n'
  sed 's/^/  /' framework_pins.txt
  printf 'framework root     : %s\n' "$root"
  printf '  rev=%s  dirty=%s\n' "$(git -C "$root" rev-parse HEAD 2>/dev/null)" \
    "$(test -n "$(git -C "$root" status --porcelain 2>/dev/null)" && echo yes || echo no)"
  printf 'route              : %s  sha256 %s\n' "$route" "$(shasum -a 256 "$route" | cut -d' ' -f1)"
  printf 'capture (round 3)  : %s  sha256 %s\n' "$cap" "$(shasum -a 256 "$cap" | cut -d' ' -f1)"
  if [ -f "$capacc" ]; then
    printf 'capture (accepted) : %s  sha256 %s\n' "$capacc" \
      "$(shasum -a 256 "$capacc" | cut -d' ' -f1)"
  fi
  printf 'save state         : saves/save.srm  sha256 %s\n' "$(shasum -a 256 saves/save.srm | cut -d' ' -f1)"
  printf 'seed table (live)  : recomp/symbols.toml  sha256 %s\n' "$(shasum -a 256 recomp/symbols.toml | cut -d' ' -f1)"
  printf 'committed cfg set  : %s\n' "$(ls recomp/*.cfg | tr '\n' ' ')"
  printf '== identity of the run that measures the checked-out tree\n'
  if [ -f "$acc/r4pair_accepted/run_manifest.json" ]; then
    python3 tests/provenance.py key "$acc/r4pair_accepted" 2>&1 | sed 's/^/  /'
  else
    printf '  (no run_manifest.json under %s: run tests/accepted_verify.sh)\n' "$acc"
  fi
  printf '  live src/gen      : %s files, manifest sha256 %s\n' \
    "$(ls -A src/gen | wc -l | tr -d ' ')" \
    "$(shasum -a 256 src/gen/program_manifest.json | cut -c1-16)"
  printf '\n== every round-4 executable, by digest\n'
  for d in build-r4base build-r4pair build-r4clean build-r4probe build-s80C1C9 build-s80C399 \
           build-s80C1B3 build-s80F495 build-s80F362 build-s80AAB3 build-s80F4F9 build-s80ABBC \
           build-s80B1DB build-s80F889; do
    [ -x "$d/ShadowrunSNESRecomp" ] || continue
    printf '  %-20s %s  %s B\n' "$d" "$(shasum -a 256 "$d/ShadowrunSNESRecomp" | cut -c1-16)" \
      "$(wc -c < "$d/ShadowrunSNESRecomp" | tr -d ' ')"
  done
  printf '\n== artifacts, by digest (this file excepted)\n'
  for a in "$art"/round4_*; do
    case "$a" in "$art/round4_provenance.txt") continue ;; esac
    printf '  %-46s %10s B  %s\n' "$(basename "$a")" "$(wc -c < "$a" | tr -d ' ')" \
      "$(shasum -a 256 "$a" | cut -c1-16)"
  done
} >> "$f"

echo "artifacts written under $art"
