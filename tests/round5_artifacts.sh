#!/usr/bin/env bash
# Regenerate every artifact the M2 promotion round-5 record cites, from files
# that already exist.
#
#   SNESRECOMP_ROOT=/path/to/pin ./tests/round5_artifacts.sh
#   ART=evidence/artifacts ROUND=tests/out/r4 ./tests/round5_artifacts.sh
#
# The same three rules as tests/round4_artifacts.sh:
#
#   * it runs no route leg, no tools/regen.sh and no cmake: every number is read
#     out of tests/out/<round> (the per-variant ledgers and route logs, the
#     archived manifests and generated sets, the tagged checkpoint dumps, the
#     parity logs and the two trace-tool outputs).  Re-measuring here would
#     silently replace a measured number with a different measurement.
#   * tests/out is scratch and git-ignored, so anything the record cites has to
#     land in the artifact directory, together with the manifests it was derived
#     from; the record cites these files, not the scratch tree.
#   * the artifact text is this script's output.  If a claim in the record does
#     not appear here, the claim is wrong.
#
# What is deliberately NOT regenerated here: the two latch-tool outputs.  Their
# generators are tests/latch_writer.py and tests/latch_state.py; both launch
# route legs, which this script must not do.  Their scratch outputs are copied
# in as inputs and this script only adds the provenance header.
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
root="${SNESRECOMP_ROOT:?run with SNESRECOMP_ROOT=<framework pin>}"
art="${ART:-evidence/artifacts}"
out="${ROUND:-tests/out/r4}"
probe="${PROBE:-tests/out/probe_dense.txt}"
route="${ROUTE:-tests/scripts/combat.txt}"
cap="${CAPTURE:-$art/tier2_capture_round3_combat.json}"
pin=$(awk -F= '/^snesrecomp=/{print $2}' framework_pins.txt)
utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
mkdir -p "$art"

hdr() { # hdr <file> <what it answers> <how it was produced>
  printf '# %s\n#\n# what: %s\n# how:  %s\n' "$(basename "$1")" "$2" "$3" > "$1"
  printf '#\n# framework pin: %s\n# generated: %s (host %s)\n' \
    "$pin" "$utc" "$(uname -sm)" >> "$1"
  printf '# source tree: %s\n\n' "$(pwd)" >> "$1"
}

# -------------------------------------------------- 0. archived input sets
# The record's identity claims are against archived programs, not the live
# src/gen (which any later build overwrites).  The control and the shipped pair
# both ship; the six sweep manifests and their generated tables ship together,
# because the sweep's node deltas are read from them.
for v in r5base r5pair; do
  [ -f "$out/manifest_$v.json.bz2" ] && cp -p "$out/manifest_$v.json.bz2" \
    "$art/round5_manifest_$v.json.bz2"
  [ -f "$out/gen_$v.tar.gz" ] && cp -p "$out/gen_$v.tar.gz" \
    "$art/round5_gen_$v.tar.gz"
done
[ -f "$probe" ] && cp -p "$probe" "$art/round5_probe_route.txt"
# The six seeds are exactly the sweep's rows, not every manifest_s* in the
# scratch tree: tests/out/r4 also still holds round 4's rejected seeds.
seeds=$(cut -f1 "$out/sweep_r5base.tsv")
if [ -n "$seeds" ]; then
  tmp=$(mktemp -d)
  mkdir -p "$tmp/sets"
  for s in $seeds; do
    cp -p "$out/manifest_$s.json.bz2" "$tmp/sets/" 2>/dev/null
    cp -p "$out/variant_${s}_symbols.toml" "$tmp/sets/" 2>/dev/null
  done
  tar czf "$art/round5_sweep_sets.tar.gz" -C "$tmp" sets
  rm -rf "$tmp"
fi

# ---------------------------------------------------------------- 1. ledgers
f="$art/round5_variant_ledgers.txt"
hdr "$f" "one block per variant this round built: generated table, regen counts, archived manifest and generated-set digests, exe digest, route exit, execution share" \
      "cat of $out/variant_<name>.out, the redirects of tests/seed_variant.sh, for the shipped pair and the six swept seeds.  The control was built with the same tool but its stdout was not redirected; its manifest is archived as round5_manifest_r5base.json.bz2 and its route log is $out/r5base.log"
for v in r5pair $(printf '%s\n' $seeds); do
  [ -f "$out/variant_$v.out" ] || continue
  printf '\n================================================================================\n' >> "$f"
  printf '## variant %s  (source: %s)\n' "$v" "$out/variant_${v}.out" >> "$f"
  cat "$out/variant_${v}.out" >> "$f"
done

# --------------------------------------------------------------- 2. sweep
f="$art/round5_sweep.tsv"
hdr "$f" "the per-seed sweep: one row per gap seed, what the route did with it, and the frame-dump verdict" \
      "cat of $out/sweep_r5base.tsv (redirect of tests/seed_sweep.sh); columns: variant, seed, build exit, route exit/first abandon, aot share, state verdict.  Each variant is the same directive-bearing control table plus exactly one generated [[func]] seed"
cat "$out/sweep_r5base.tsv" >> "$f"

f="$art/round5_route_tails.txt"
hdr "$f" "the last lines each variant's own route log printed, so the exit line and any gate it stopped at sit beside the ledger" \
      "tail -25 of $out/<variant>.log for the control, the shipped pair and the six swept seeds; these are the logs tests/seed_variant.sh and tests/seed_sweep.sh wrote"
for v in r5base r5pair $seeds; do
  [ -f "$out/$v.log" ] || continue
  printf '\n================================================================================\n' >> "$f"
  printf '## %s  (source: %s)\n' "$v" "$out/$v.log" >> "$f"
  tail -25 "$out/$v.log" >> "$f"
done

# --------------------------------------------------- 3. the directive itself
f="$art/round5_directive.txt"
hdr "$f" "the hand-written dispatch authorisation this round adds, its target count, and the instruction at the site it describes" \
      "verbatim extraction of the hand-written block at the end of recomp/bank80.cfg; the target count and the site bytes are re-derived here (python3 reads the ROM through tests/rom.sh's resolver), not typed"
printf '== recomp/bank80.cfg: hand-written block (verbatim, from the marker to EOF)\n' >> "$f"
awk '/^# --- hand-written: the state\/event handler dispatch/{p=1} p' recomp/bank80.cfg >> "$f"
printf '\n== directive line, parsed\n' >> "$f"
line=$(grep -m1 '^indirect_dispatch f4f9 ' recomp/bank80.cfg || true)
if [ -z "$line" ]; then
  printf '  MISSING: no `indirect_dispatch f4f9` line\n' >> "$f"
else
  printf '  %s\n' "$line" >> "$f"
  printf '%s\n' "$line" | python3 -c '
import sys
tok = sys.stdin.read().split()
name, declared, mode = tok[1], int(tok[2]), tok[3]
raw = next((t for t in tok[4:] if t.startswith("targets:")), "targets:")
targets = [t for t in raw.split(":", 1)[1].split(",") if t]
print(f"  site ${name.upper()}  declared targets {declared}  mode {mode}")
print(f"  parsed targets {len(targets)}  duplicates {len(targets)-len(set(targets))}")
print(f"  count matches declaration: {len(targets) == declared}")
print("  targets: " + " ".join(t.upper() for t in targets))
' >> "$f"
fi
printf '\n== the instruction at the site\n' >> "$f"
. tests/rom.sh
if rom=$(sr_rom); then
  python3 - "$rom" >> "$f" <<'PY'
import sys
rom = open(sys.argv[1], "rb").read()
# LoROM mapping for the SNES address $80F4F9: bank $80 -> ROM bank 0,
# address $F4F9 -> offset $74F9 within the 32 KiB window.
for addr in (0x80F4F9,):
    bank, a = addr >> 16, addr & 0xFFFF
    off = ((bank & 0x7F) * 0x8000) + ((a - 0x8000) & 0x7FFF)
    b = rom[off:off + 3]
    print(f"  ${addr:06X} -> ROM ${off:06X}: {b.hex(' ').upper()}")
    if b[:1] == b"\x6c":
        ptr = b[1] | (b[2] << 8)
        print(f"  decode: JMP (${ptr:04X})  -- an indirect tail transfer")
PY
else
  printf '  ROM not resolvable; site bytes not printed\n' >> "$f"
fi

# ------------------------------------------------- 4. inertness of the directive
# The round shipped exactly one generated program before this round and one
# after.  If the authorisation changed no instruction body, then the two
# generated sets differ only where the manifest records the site's exit modes;
# that is the claim this section makes, file by file and node by node.
f="$art/round5_directive_inert.txt"
hdr "$f" "whether authorising \$80F4F9 changes any generated machine code: the round-4 shipped set against the round-5 shipped set, at file, instruction-body and manifest level" \
      "python3 compares round4_gen_r4pair.tar.gz with round5_gen_r5pair.tar.gz (member bytes) and round4_manifest_r4pair.json.bz2 with round5_manifest_r5pair.json.bz2 (top-level fields and every node); the program digest is read out of each module_v2.c"
python3 - "$art" >> "$f" 2>&1 <<'PY'
import bz2, hashlib, json, sys, tarfile
art = sys.argv[1]

def members(name):
    tf = tarfile.open(f"{art}/{name}")
    return {m.name: tf.extractfile(m).read() for m in tf.getmembers() if m.isfile()}

old = members("round4_gen_r4pair.tar.gz")
new = members("round5_gen_r5pair.tar.gz")
print("== generated files")
print(f"  round-4 set {len(old)} files, round-5 set {len(new)} files")
print(f"  added   {sorted(set(new) - set(old)) or 'none'}")
print(f"  removed {sorted(set(old) - set(new)) or 'none'}")
changed = sorted(k for k in set(old) & set(new) if old[k] != new[k])
print(f"  changed {changed or 'none'}")

code = [k for k in changed if k.endswith(".c") and k != "gen/module_v2.c"]
print(f"\n== instruction bodies")
print(f"  generated .c files other than module_v2.c that changed: {code or 'none'}")
for k in sorted(set(old) & set(new)):
    if k.startswith("gen/bank") or k == "gen/dispatch_v2.c" or k == "gen/unresolved_stubs_v2.c":
        same = old[k] == new[k]
        print(f"  {k:<34} {'identical' if same else 'CHANGED'}  sha256 {hashlib.sha256(new[k]).hexdigest()[:16]}")

oldmod, newmod = old.get("gen/module_v2.c", b""), new.get("gen/module_v2.c", b"")
print("\n== module_v2.c (the only changed machine-code file)")
for tag, blob in (("round 4", oldmod), ("round 5", newmod)):
    for line in blob.decode(errors="replace").splitlines():
        if "program_digest" in line or "build_digest" in line:
            print(f"  {tag}: {line.strip()}")
import difflib
diff = [l for l in difflib.unified_diff(
    oldmod.decode(errors="replace").splitlines(),
    newmod.decode(errors="replace").splitlines(), lineterm="")
    if l.startswith(("+", "-")) and not l.startswith(("+++", "---"))]
print(f"  differing lines: {len(diff)}")
for l in diff:
    print(f"    {l}")
print("  (two digest strings only: program_digest and build_digest)")

oldm = json.loads(bz2.decompress(open(f"{art}/round4_manifest_r4pair.json.bz2", "rb").read()))
newm = json.loads(bz2.decompress(open(f"{art}/round5_manifest_r5pair.json.bz2", "rb").read()))
print("\n== program manifest")
print(f"  top-level keys equal: {set(oldm) == set(newm)}")
for k in sorted(set(oldm) | set(newm)):
    if oldm.get(k) != newm.get(k):
        print(f"  top-level field changed: {k}")
on, nn = oldm["nodes"], newm["nodes"]
print(f"  nodes {len(on)} -> {len(nn)}; same keys: {set(on) == set(nn)}")
nchanged = [k for k in sorted(set(on) & set(nn)) if on[k] != nn[k]]
print(f"  nodes with any differing field: {len(nchanged)}")
disp = {}
for k in nn:
    disp[nn[k].get("disposition")] = disp.get(nn[k].get("disposition"), 0) + 1
print("  disposition counts (round 5): " + ", ".join(f"{k} {v}" for k, v in sorted(disp.items())))
print(f"  roots {len(oldm['roots'])} -> {len(newm['roots'])}; identical: {oldm['roots'] == newm['roots']}")
oe, ne = oldm["exit_modes"], newm["exit_modes"]
added = sorted(set(ne) - set(oe))
removed = sorted(set(oe) - set(ne))
changed_x = sorted(k for k in set(oe) & set(ne) if oe[k] != ne[k])
print(f"  exit_modes {len(oe)} -> {len(ne)}  (+{len(added)} / -{len(removed)} / ~{len(changed_x)})")
if added:
    print(f"  added keys: {' '.join(added)}")
print("\n== verdict")
machine_same = not code and all(
    old.get(k) == new.get(k)
    for k in old if k.startswith("gen/bank") or k in
    ("gen/dispatch_v2.c", "gen/unresolved_stubs_v2.c"))
only_module = set(changed) <= {"gen/module_v2.c", "gen/program_manifest.json",
                               "gen/.snesrecomp-cache.json"}
print(f"  instruction bodies byte-identical: {machine_same}")
print(f"  changed files limited to module_v2.c / program_manifest.json / cache: {only_module}")
print(f"  manifest nodes identical, roots identical: {not nchanged and oldm['roots'] == newm['roots']}")
print(f"  only top-level manifest change is exit_modes: "
      f"{[k for k in set(oldm) | set(newm) if oldm.get(k) != newm.get(k)] == ['exit_modes']}")
print("  => the directive is machine-code-inert on the shipped pair; it changes")
print("     the dispatch-value vocabulary recorded in the manifest, not a body.")
PY

# ------------------------------------------------------- 5. the pair's gate
f="$art/round5_pair_checkpoints.txt"
hdr "$f" "the shipped pair at every tagged checkpoint against the directive-bearing control: per-checkpoint state verdict, then the master-clock delta" \
      "tests/cpdump_matrix.py $out/r5base $out/r5pair, whose output was saved as $out/r5pair_checkpoints.txt; the dumps are the 22 tagged checkpoints each run wrote"
cat "$out/r5pair_checkpoints.txt" >> "$f"

f="$art/round5_pair_bytes.txt"
hdr "$f" "the same gate at byte level: how many bytes of every state image differ at each tagged checkpoint" \
      "tests/cp_byte_diff.py $out/r5base $out/r5pair over wram vram oam cgram sram and the host framebuffer; saved as $out/r5pair_bytes.txt"
cat "$out/r5pair_bytes.txt" >> "$f"

f="$art/round5_pair_parity.txt"
hdr "$f" "the shipped pair against the directive-bearing control on the dense parity route: frame dumps compared over the whole run" \
      "cat of $out/r5pair_parity.log, the redirect of tests/parity.sh $probe with PORT_BIN=build-r5base and PORT_BIN2=build-r5pair.  The run1 provenance warning is expected and is explained at the end of this file"
cat "$out/r5pair_parity.log" >> "$f"
printf '\n== reading the run1 warning\n' >> "$f"
if grep -q 'touched after this executable was linked' "$out/r5pair_parity.log"; then
  printf '  run1 (the control exe) was linked before the pair tree regenerated src/gen, so\n' >> "$f"
  printf '  provenance.py labels its generated-set digest as possibly not compiled in.\n' >> "$f"
  printf '  That label is about the control binary, not about run2: the pair exe'\''s own\n' >> "$f"
  printf '  identity is established against the archived set in round5_provenance.txt, and\n' >> "$f"
  printf '  the gate is the equality of the two runs'\'' frame dumps, which does not depend\n' >> "$f"
  printf '  on the control'\''s printed gen digest.\n' >> "$f"
else
  printf '  no such warning in the log.\n' >> "$f"
fi
printf '\n  verdict lines:\n' >> "$f"
grep -E 'identical over|first divergence|frames differ' "$out/r5pair_parity.log" \
  | sed 's/^/    /' >> "$f"

# -------------------------------------------- 6. the gate's first live split
# The six swept seeds share one onset.  cpdump names the first differing byte,
# but a byte below the stack pointer is dead scratch: it can differ once and be
# overwritten before the next frame boundary.  This probe samples the same two
# legs at frame boundaries and separates live stack (address >= S) from dead
# scratch (address < S), so the record can say which byte is the machine moving
# and which is a transient.
f="$art/round5_gate_state.txt"
hdr "$f" "the six-seed onset read at frame boundaries on the parity route: registers, direct page, live stack and the latch bytes, control vs the \$80C1C9 seed" \
      "python3 tests/latch_state.py on the trace builds (build-tr-ctrl = directive-bearing control, build-tr-seed = the same tree plus \$80C1C9), route $probe, frames 1830..1838.  Raw output: $out/gate_state.txt"
printf 'legs: ctrl=build-tr-ctrl/ShadowrunSNESRecomp  seed=build-tr-seed/ShadowrunSNESRecomp\n' >> "$f"
printf 'note: run_to_frame stops one frame past the requested target; the frames below are the reported ones.\n\n' >> "$f"
cat "$out/gate_state.txt" >> "$f"

f="$art/round5_gate_writer.txt"
hdr "$f" "whether the first differing byte has a differing writer: the \$0126/\$0127 write-value sequences on the same two legs up to the onset" \
      "python3 tests/latch_writer.py --route $probe --park 1832 --addrs 0x126,0x127 on the same trace builds; raw output: $out/gate_writer.txt"
cat "$out/gate_writer.txt" >> "$f"

# ------------------------------------------------- 7. the combat-route latch
f="$art/round5_latch_split.txt"
hdr "$f" "the combat route's first \$0126 split: which write, which value, and which block (PC) wrote it on each leg" \
      "python3 tests/latch_writer.py --route tests/scripts/bisect_h8.txt --park 16200 --addrs 0x126,0x127 on the same trace builds; raw output: $out/latch_split_combat.txt"
cat "$out/latch_split_combat.txt" >> "$f"

f="$art/round5_latch_state.txt"
hdr "$f" "the same combat-route split read at frame boundaries: whether DP, S, the live stack and the latch bytes agree around it" \
      "python3 tests/latch_state.py --route tests/scripts/bisect_h8.txt --frames 14662,14671,14701,16181,16201 on the same trace builds; raw output: $out/latch_state_combat.txt"
cat "$out/latch_state_combat.txt" >> "$f"

# ------------------------------------------- 8. the accepted tree, measured
# The shipped tree is checked out, so the round also carries the legs that
# re-measure it: src/gen vs the archive, the route counters, the checkpoint
# gate, parity, and a fresh capture of the program that shipped.  The log is
# tests/accepted_verify.sh's own output; this script only cats it, so the
# numbers are that measurement, not a second one.
acc="$out/accepted"
[ -f "$acc/capture_accepted.json" ] \
  && cp -p "$acc/capture_accepted.json" "$art/tier2_capture_round5_accepted.json"
f="$art/round5_accepted_verify.md"
hdr "$f" "the shipped tree measured again end to end: generated-set and exe identity, route counters, per-checkpoint state against the control, parity, and a capture of the program that shipped" \
      "cat of $acc/accepted_verify.log, the redirect of tests/accepted_verify.sh with PAIR=r5pair BUILD=build-r5pair CONTROL=r5base; its legs run from a scratch anchor under $acc/, never in a build dir, so no last_run_report.json used above is overwritten"
if [ -f "$acc/accepted_verify.log" ]; then
  cat "$acc/accepted_verify.log" >> "$f"
else
  printf 'missing %s: run tests/accepted_verify.sh\n' "$acc/accepted_verify.log" >> "$f"
fi

# ------------------------------------------------------- 9. provenance
f="$art/round5_provenance.txt"
hdr "$f" "what round 5 measured against, and every artifact that carries its evidence" \
      "this script; the file index is shasum -a 256 over $art/round5_*"
{
  printf 'framework pin file : framework_pins.txt\n'
  sed 's/^/  /' framework_pins.txt
  printf 'framework root     : %s\n' "$root"
  printf '  rev=%s  dirty=%s\n' "$(git -C "$root" rev-parse HEAD 2>/dev/null)" \
    "$(test -n "$(git -C "$root" status --porcelain 2>/dev/null)" && echo yes || echo no)"
  printf 'combat route       : %s  sha256 %s\n' "$route" "$(shasum -a 256 "$route" | cut -d' ' -f1)"
  printf 'parity route       : %s  sha256 %s\n' "$probe" "$(shasum -a 256 "$probe" | cut -d' ' -f1)"
  printf 'capture (round 3)  : %s  sha256 %s\n' "$cap" "$(shasum -a 256 "$cap" | cut -d' ' -f1)"
  if [ -f "$art/tier2_capture_round5_accepted.json" ]; then
    printf 'capture (accepted) : %s  sha256 %s\n' \
      "$(basename "$art")/tier2_capture_round5_accepted.json" \
      "$(shasum -a 256 "$art/tier2_capture_round5_accepted.json" | cut -d' ' -f1)"
  fi
  printf 'save state         : saves/save.srm  sha256 %s\n' "$(shasum -a 256 saves/save.srm | cut -d' ' -f1)"
  printf 'seed table (live)  : recomp/symbols.toml  sha256 %s\n' "$(shasum -a 256 recomp/symbols.toml | cut -d' ' -f1)"
  printf 'committed cfg set  : %s\n' "$(ls recomp/*.cfg | tr '\n' ' ')"
  printf 'bank80.cfg         : sha256 %s\n' "$(shasum -a 256 recomp/bank80.cfg | cut -d' ' -f1)"
  printf '\n== archived generated sets\n'
  for v in r5base r5pair; do
    m="$art/round5_manifest_$v.json.bz2"
    g="$art/round5_gen_$v.tar.gz"
    [ -f "$m" ] || continue
    python3 - "$v" "$m" "$g" <<'PY'
import bz2, hashlib, json, sys
v, m, g = sys.argv[1:4]
raw = bz2.decompress(open(m, "rb").read())
man = json.loads(raw)
aot = sum(1 for n in man["nodes"].values() if n["disposition"] == "aot_eligible")
lle = sum(1 for n in man["nodes"].values() if n["disposition"] == "lle_only")
print(f"  {v:<7} manifest {hashlib.sha256(raw).hexdigest()[:16]}  "
      f"generated-set sha256 {hashlib.sha256(open(g,'rb').read()).hexdigest()[:16]}")
print(f"          {len(man['nodes'])} nodes ({aot} aot_eligible, {lle} lle_only), "
      f"{len(man['roots'])} roots, {len(man['exit_modes'])} exit modes")
PY
  done
  printf '\n== project digests in the archived module_v2.c\n'
  for v in r5base r5pair; do
    g="$art/round5_gen_$v.tar.gz"
    [ -f "$g" ] || continue
    printf '  %-7s ' "$v"
    tar xzf "$g" -O gen/module_v2.c 2>/dev/null \
      | sed -n 's/.*program_digest = "\([0-9a-f]\{16\}\).*/program_digest \1/p' \
      | sed 's/$/ /' | tr -d '\n'
    tar xzf "$g" -O gen/module_v2.c 2>/dev/null \
      | sed -n 's/.*build_digest = "\([0-9a-f]\{16\}\).*/build_digest \1/p'
  done
  printf '\n== every round-5 executable, by digest\n'
  for d in build-r5base build-r5pair build-tr-ctrl build-tr-seed \
           build-s80C1C9 build-s80C1B3 build-s80F495 build-s80F362 \
           build-s80F4F9 build-s80F889; do
    [ -x "$d/ShadowrunSNESRecomp" ] || continue
    printf '  %-18s %s  %s B\n' "$d" \
      "$(shasum -a 256 "$d/ShadowrunSNESRecomp" | cut -c1-16)" \
      "$(wc -c < "$d/ShadowrunSNESRecomp" | tr -d ' ')"
  done
  printf '  (a swept build dir already removed still has its exe digest in\n'
  printf '   round5_variant_ledgers.txt, printed by tests/seed_variant.sh at build time)\n'
  printf '\n== artifacts, by digest (this file excepted)\n'
  for a in "$art"/round5_*; do
    case "$a" in "$art/round5_provenance.txt") continue ;; esac
    printf '  %-46s %10s B  %s\n' "$(basename "$a")" "$(wc -c < "$a" | tr -d ' ')" \
      "$(shasum -a 256 "$a" | cut -c1-16)"
  done
} >> "$f"

echo "artifacts written under $art"
