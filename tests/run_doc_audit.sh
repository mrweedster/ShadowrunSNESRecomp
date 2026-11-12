#!/usr/bin/env bash
# Run the claim-to-artifact auditor and keep its output where it can be committed.
#
#   tests/run_doc_audit.sh
#
# tests/doc_quote_audit.py checks tests/README.md: fenced blocks, prose quotes,
# hashes and byte counts, and whether each cited artifact is still byte-for-byte the
# scratch log it was copied from.  Its exit code is the number of untraceable
# findings, and its summary lines carry the counts, so the claim "the README's quotes
# were checked and nothing was left untraceable" needs a record of a run.
#
# One awkwardness is specific to this auditor: its own log is one of the artifact/log
# pairs it compares, so the committed log has to be a *fixed point* -- the run that is
# committed must already be the run in which that file existed and was compared.  A
# single pass cannot be: the first pass runs while the committed copy is stale or
# absent, so its own counts are about a tree that no longer matches what it printed.
# So this wrapper iterates, saving each pass as the log and as the artifact, and stops
# when a pass reproduces the saved text exactly.  Three passes is enough because the
# only thing that changes between passes is the pair count and the missing/unequal
# lines; if a fourth would be needed the wrapper says so rather than committing a
# number that cannot be reproduced.
#
# The log is tests/out/doc_audit/doc_quote_audit.log, committed verbatim as
# evidence/artifacts/doc_quote_audit.md.  python3 -B because a stale tests/__pycache__
# has previously masked an edit to the script being tested.
#
# Exit 0 = fixed point reached and the auditor's last pass reported no finding.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/tests/out/doc_audit"
log="$out/doc_quote_audit.log"
art="$root/evidence/artifacts/doc_quote_audit.md"
mkdir -p "$out"

fixed=0
rc=1
for i in 1 2 3; do
  tmp="$out/run${i}.txt"
  python3 -B "$root/tests/doc_quote_audit.py" >"$tmp" 2>&1
  rc=$?
  if [ -f "$art" ] && cmp -s "$tmp" "$log" && cmp -s "$tmp" "$art"; then
    fixed=1
    echo "== pass $i reproduces the saved log and artifact exactly (fixed point)"
    break
  fi
  cp "$tmp" "$log"
  cp "$log" "$art"
  echo "== pass $i saved as the log and the artifact (exit $rc); re-running"
done
rm -f "$out"/run[0-9].txt

echo "== audited: tests/doc_quote_audit.py -> $log"
sed 's/^/   /' "$log"
if [ "$fixed" = 1 ]; then
  echo "== fixed point reached; committed artifact is reproducible from this log"
else
  echo "== NOT a fixed point after three passes: the saved log does not reproduce"
  echo "   itself, so its counts describe a tree other than the one it sits in."
  rc=1
fi
if [ "$rc" = 0 ]; then
  echo "== auditor exit 0: no untraceable finding (log: $log)"
else
  echo "== auditor exit $rc: findings above (log: $log)"
fi
exit "$rc"
