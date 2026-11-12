#!/usr/bin/env python3
"""Check that this file's quoted evidence is traceable, rather than plausible.

    python3 tests/doc_quote_audit.py            # audits sections 7.19 to 8.2
    python3 tests/doc_quote_audit.py START END  # or an explicit line range
    tests/run_doc_audit.sh                      # this, with its output kept as a log

Four checks over tests/README.md:

  fences      every ``` block that is not marked sh reproduces verbatim inside the
              witness set below (``` sh blocks are recipes, so they are checked one
              command line at a time instead, with continuations joined);
  quotes      every double-quoted span of 25+ characters in prose appears verbatim
              in the witness set.  Quote marks are paired in the order they occur
              inside a paragraph, because a sentence that wraps is one sentence:
              pairing whole lines instead would leave the tail of every wrapped
              quotation unchecked.  A paragraph holding an odd number of them is
              itself a finding;
  figures     every hex-ish token (16+ hex digits, or a 16-char abbreviation of one)
              and every comma-grouped byte count appears there as a token;
  artifacts   every committed artifact under evidence/artifacts/ that this file cites
              is still byte-for-byte the scratch log it was copied from.

A finding is a defect unless it is in ALLOW below, where the reason for accepting it
is stated next to it.  Exit code is the number of findings.

The witnesses are the committed evidence, not the scratch logs: evidence/**/*.md plus
the scripts that produced them.  Then two tiers of git history, because the round
being described sometimes no longer has its log on disk:

  * an older *evidence* blob (CORPUS_GIT_EVIDENCE) witnesses a quotation outright --
    it is a record, just an old one, and the rows that use it say which revision;
  * an older revision of this README (CORPUS_GIT_DOC) witnesses a quotation only when
    the prose beside it names that revision inline, e.g. "still readable at `git show
    21c1109:tests/README.md`".  The document may not vouch for its own prose by
    repeating itself across revisions; what makes a past round's wording traceable is
    the citation next to it;
  * figures may use either tier: a number measured in an earlier round stays a
    measurement after the page that first printed it moved.

Three files are kept out of the witness set: this script, the log of its own run, and
the script that writes sections 7.26 and 7.27.  All three contain README text, so a
quotation witnessed by any of them would be circular.

Elisions and machine-local paths may differ, in the way a person reads a transcript
quote: "..." / U+2026 stands for any non-empty span of the source (the omission's size
belongs to the source, not to this file, and the spaces this file puts around it are
markup rather than source, so a kept span may end in punctuation at the join),
/path/to/... and <name> stand for one word, a quoted "/path/to/..." stands for any
quoted string, and a '\' line continuation in this file matches a record that wrote the
command on one line, with or without it.  Backticks are removed from both sides of the
comparison: they are markdown markup for a code word, not part of what the record said,
and leaving them on the witness side alone would reject a quotation that differs from
its record only in that markup.

A comma-grouped byte count that is not a transcript line is still accepted if it is
arithmetic on witnessed operands: the 2,057 B between the two packages' CodeDirectory
sizes is accepted only because 13,859 and 11,802 are both transcript values, and an
operand has to be four digits or more for the subtraction to count.  A count only
matching as a fragment of a longer number (2057 inside "cycles":1205758) witnesses
nothing, which is why byte counts are compared as tokens.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
README = ROOT / "tests" / "README.md"

# Corpus: committed evidence and the scripts that emit it.  tests/out/ is
# git-ignored scratch; evidence/artifacts/*.md are its committed verbatim copies.
CORPUS_FILES = sorted(set(
    [str(p.relative_to(ROOT)) for p in (ROOT / "evidence").rglob("*.md")]
    + [str(p.relative_to(ROOT))
       for pat in ("scripts/*.sh", "tests/*.sh", "tests/*.py", "tools/*.sh")
       for p in ROOT.glob(pat)]
))
# ... but not this script itself, and not the log of its own run: both echo the README
# text they are checking, so either one witnessing a quote would be circular.  The
# same reason rules out the script that writes sections 7.26 and 7.27: the prose it
# assembles is this file's prose, and its transcripts come from the artifacts anyway.
CORPUS_EXCLUDE = {"doc_quote_audit", "doc_probe_sections"}
CORPUS_FILES = [f for f in CORPUS_FILES
                if pathlib.PurePath(f).stem not in CORPUS_EXCLUDE]
# Superseded figures are quoted from revisions that are no longer in the working
# tree, and git history is their witness; the README names the blob it cites beside
# each such row.
CORPUS_GIT_EVIDENCE = [
    "50c7405:evidence/artifacts/macos_package.md",
    "21c1109:evidence/artifacts/macos_package.md",
    "390924f6:evidence/README.md",
]
# Older revisions of this same file.  They witness figures, and they witness a
# quotation only when the prose beside it cites them by name (see below).
CORPUS_GIT_DOC = [
    "50c7405:tests/README.md",
    "21c1109:tests/README.md",
]

# finding -> why it is accepted.  Keep this list short and specific.
ALLOW = {
    # What macOS shows a person.  The assessment it renders is itself quoted from
    # the transcripts (code has no resources but signature indicates they must be
    # present), and both passages say they are describing the dialog, not a log.
    "*Shadowrun* is damaged and can't be opened":
        "the user-visible dialog wording, not a transcript line",
}

HEX = re.compile(r"\b[0-9a-f]{8,64}\b")
BYTES = re.compile(r"\b\d{1,3}(?:,\d{3})+ B\b")
QUOTE_MIN = 25
QUOTE = re.compile(r'"([^"]{%d,})"' % QUOTE_MIN)
NOT_HEX = {"arm64", "x86_64"}


def norm(text):
    return re.sub(r"\s+", " ", text).strip()


def corpus(text):
    """Corpus side of the quotation comparison.  Backticks are markdown markup, and
    this file writes them inside a quotation for the code word they mark rather than
    as part of what was said, so they are removed from both sides.  Leaving them on
    the corpus side would reject a quotation that differs from its witness only in
    that markup."""
    return norm(text.replace("`", ""))


def token_seen(tok, blob):
    """Is this token a token in the corpus, rather than a fragment of a longer one?
    2057 appearing inside guest_cycles":1205758, or a mistyped 63-character digest
    that shares a 16-character prefix with the real one, witness nothing."""
    return re.search(r"(?<![0-9a-fA-F])" + tok + r"(?![0-9a-fA-F])", blob) is not None


def hex_seen(tok, blob, marked=False):
    """A hash is witnessed if the corpus has the same token; an abbreviation that
    this file marks with '...' is witnessed by any corpus token it prefixes."""
    if token_seen(tok, blob):
        return True
    return marked and len(tok) >= 12 and re.search(
        r"(?<![0-9a-f])" + tok + r"[0-9a-f]+", blob) is not None


# An ALLOW entry is matched whether the README wrote the phrase bare or wrapped in
# double quotes, so compare it in normalised form.
ALLOW_NORM = {norm(k): v for k, v in ALLOW.items()}


def to_rx(fragment, whole=False):
    """README-shaped fragment -> regex over the whitespace-normalised corpus."""
    # A shell continuation in this file may or may not be a continuation in the
    # record: the build round's log writes the command on one line, the markdown
    # evidence keeps the backslash.  So the backslash becomes optional, and the
    # spaces around it are consumed here rather than left to the join below.
    fragment = re.sub(r"\s*\\\s+", "@BS@", fragment)
    fragment = norm(fragment.replace("`", ""))
    # A quoted placeholder stands for any quoted string: the value inside the quotes
    # is machine-local, and it may contain spaces, which the one-word rule below
    # could not span.
    fragment = re.sub(r'"/path/to/[^"]*"', "@Q@", fragment)
    parts = re.split(
        r"(@Q@|@BS@|…|\.\.\.|<[\w .()/*-]+>|/path/to/[\w./+-]*|/[\w./+-]*/\.\.\.)",
        fragment)
    out = []
    for i, part in enumerate(parts):
        if not part:
            continue
        if part == "@Q@":
            out.append(r'"[^"]*"')
        elif part == "@BS@":
            out.append(r"(?: \\)? ")
        elif part in ("…", "..."):
            # An omission's length belongs to the source, not to this file, so it is
            # a non-empty wildcard rather than a fixed-width window.  The space this
            # file puts on each side of the ellipsis is not part of the source, and
            # the source may end the kept span with punctuation ("ROM image, compiled
            # into …"), so the seam is loose: each neighbouring span keeps its words
            # and gives up its spacing to the wildcard.
            out.append(r".+")
        else:
            if part.startswith("<") or part.startswith("/path/to/") or part.endswith("/..."):
                out.append(r"\S*")
                continue
            if i and parts[i - 1] in ("…", "..."):
                part = part.lstrip()
            if i + 1 < len(parts) and parts[i + 1] in ("…", "..."):
                part = part.rstrip()
            if part:
                out.append(re.escape(part))
    rx = "".join(out)
    return re.compile(r"\A%s\Z" % rx) if whole else re.compile(rx)


def main():
    if len(sys.argv) == 3:
        start, end = int(sys.argv[1]), int(sys.argv[2])
    else:
        text = README.read_text().splitlines()
        start = next(i for i, l in enumerate(text, 1)
                     if l.startswith("### 7.19 "))
        end = next(i for i, l in enumerate(text[start - 1:], start)
                   if l.startswith("## 9. ")) - 1

    # Two corpora, deliberately different sizes.
    #
    # blob: committed evidence plus the scripts that emit it.  This is the only
    # witness accepted for a quotation -- a fence or a sentence in " -- because the
    # README must not vouch for its own prose.
    blob_parts = []
    for f in CORPUS_FILES:
        p = ROOT / f
        if p.exists():
            blob_parts.append(corpus(p.read_text(errors="replace")))
    for spec in CORPUS_GIT_EVIDENCE:
        out = subprocess.run(["git", "-C", str(ROOT), "show", spec],
                             capture_output=True, text=True).stdout
        blob_parts.append(corpus(out))
    blob = " ".join(blob_parts)

    # blob_hist: this README's older revisions, kept apart because they are a
    # different kind of witness (see the docstring).  blob_all is what figures use.
    hist_parts = []
    for spec in CORPUS_GIT_DOC:
        out = subprocess.run(["git", "-C", str(ROOT), "show", spec],
                             capture_output=True, text=True).stdout
        hist_parts.append(corpus(out))
    blob_hist = " ".join(hist_parts)
    blob_all = blob + " " + blob_hist
    blob_all_nocomma = blob_all.replace(",", "")

    lines = README.read_text().splitlines()
    in_fence = set()
    fence = False
    for n, line in enumerate(lines, start=1):
        if line.startswith("```"):
            fence = not fence
            in_fence.add(n)
            continue
        if fence:
            in_fence.add(n)

    findings = []
    accepted_cited = {}   # quote -> (quote, [revisions cited beside it], line)

    # 1. fences.  The range boundary can fall outside any fence, so the parser has
    # to enter a block only at a ``` line: seeding it at the range start would turn
    # every prose paragraph into a "block" and every real fence into prose.
    block, recipe, open_at = [], False, 0
    for n in range(start, end + 1):
        line = lines[n - 1]
        if line.startswith("```"):
            if open_at:
                if recipe:
                    # A ``` sh block is a recipe, so each command line is checked on
                    # its own.  The README annotates recipes with '#' prose lines;
                    # those are prose, not part of a command line, so they are
                    # dropped rather than glued onto the command that follows them.
                    frags, cur = [], []
                    for bl in block:
                        if not bl.strip() or bl.lstrip().startswith("#"):
                            continue
                        cur.append(bl)
                        if not bl.rstrip().endswith("\\"):
                            frags.append(" ".join(cur))
                            cur = []
                    if cur:
                        frags.append(" ".join(cur))
                else:
                    frags = [" ".join(block)]
                for frag in frags:
                    if frag.strip() and not to_rx(frag).search(blob):
                        findings.append(("fence", open_at, frag[:110]))
                block, open_at, recipe = [], 0, False
            else:
                open_at, recipe = n, line.strip() == "```sh"
            continue
        if open_at:
            block.append(line)
    if open_at:
        findings.append(("fence", open_at, "unbalanced ``` inside the audited range"))

    # 2. prose quotes, 3. figures
    def para_around(n, span=8):
        """The prose of n's own paragraph: the lines on both sides up to the blank
        line or fence that bounds it (n itself may be mid-paragraph)."""
        back, fwd = [], []
        for m in range(n - 1, max(n - span, start - 1), -1):
            if m in in_fence or not lines[m - 1].strip():
                break
            back.append(lines[m - 1])
        for m in range(n + 1, min(n + span, end + 1)):
            if m in in_fence or not lines[m - 1].strip():
                break
            fwd.append(lines[m - 1])
        return " ".join(list(reversed(back)) + [lines[n - 1]] + fwd)

    # Quotations are read off paragraphs, not off single lines.  This file wraps its
    # prose, so a quotation that breaks across a line break is still one quotation;
    # scanning line by line would let a wrapped paraphrase pass as a quote, which is
    # exactly the failure this check exists to catch.  Each paragraph is joined the
    # way norm() would join it, and a finding names the line the quote starts on.
    paragraphs, cur_lines = [], []
    for n in range(start, end + 1):
        if n in in_fence or not lines[n - 1].strip():
            if cur_lines:
                paragraphs.append(cur_lines)
                cur_lines = []
            continue
        cur_lines.append(n)
    if cur_lines:
        paragraphs.append(cur_lines)

    QUOTE_PARAS = {}
    for ns in paragraphs:
        joined, offsets = "", []
        for n in ns:
            offsets.append((len(joined), n))
            joined += (" " if joined else "") + lines[n - 1]
        # Quotation marks are read in pairs, in order.  Searching for a long quoted
        # span instead would pair a closing mark with the next opening mark and read
        # the prose between two quotations as if it were one (the "is damaged" scare
        # quote at 7.19 and the next quotation in the same paragraph, for example).
        marks = [m.start() for m in re.finditer(r'"', joined)]
        if len(marks) % 2:
            findings.append(("quote", ns[0],
                             "unmatched double quote in the paragraph starting here"))
        for a, b in zip(marks[0::2], marks[1::2]):
            if b - a - 1 < QUOTE_MIN:
                continue
            at = max(n for o, n in offsets if o <= a)
            QUOTE_PARAS.setdefault(at, []).append(joined[a + 1:b])

    for n in range(start, end + 1):
        if n in in_fence:
            continue
        line = lines[n - 1]
        for q in QUOTE_PARAS.get(n, []):
            qn = norm(q.replace("`", ""))
            if to_rx(qn).search(blob):
                continue
            if qn in {norm(k) for k in ALLOW} or q in ALLOW:
                continue
            # Second tier: a quotation from a past round whose scratch log is gone is
            # traceable if the prose names the revision that preserved it, and that
            # revision is one this auditor loads.
            window = para_around(n)
            cited = [spec for spec in CORPUS_GIT_DOC if spec in window]
            if cited and to_rx(qn).search(blob_hist):
                accepted_cited.setdefault(qn, (qn, cited, n))
                continue
            findings.append(("quote", n, qn[:110]))
        for m in HEX.finditer(line):
            h = m.group(0)
            if h in NOT_HEX or len(h) < 16:
                continue
            # An abbreviation counts as marked when this file writes '...' or U+2026
            # right after it; an unmarked token has to match a whole corpus token.
            tail = line[m.end():m.end() + 3]
            marked = tail.startswith("…") or tail.startswith("...")
            if hex_seen(h, blob_all, marked):
                continue
            findings.append(("hash", n, h))
        for b in BYTES.findall(line):
            digits = b.replace(",", "").replace(" B", "")
            if token_seen(digits, blob_all) or token_seen(digits, blob_all_nocomma):
                continue
            value = int(digits)
            # Derived figure: accepted only when the surrounding paragraph names
            # both operands and both of those are transcript values.  Operands are
            # restricted to 4+ digits, because otherwise a stray 0 in the paragraph
            # (flags=0x2, hashes=1447+0) would let any number pass as "itself minus
            # zero".  A derived number is not evidence; the operands are.
            window = para_around(n)
            line_nums = [int(x.replace(",", "")) for x in re.findall(r"\d[\d,]*", window)]
            witnesses = [x for x in line_nums
                         if x >= 1000 and token_seen(str(x), blob_all)]
            if value >= 1000 and any(abs(a - b) == value
                                     for a in witnesses for b in witnesses if a != b):
                continue
            findings.append(("size", n, b))

    # 4. the committed artifacts are still byte-for-byte their source logs.  Which
    # artifacts count is decided by what this file cites, so a new artifact cannot be
    # cited without a comparison being added next to it.
    pairs = [("tests/out/pkg/macos_package.log", "evidence/artifacts/macos_package.md"),
             ("tests/out/pkg/macos_package_personal.log",
              "evidence/artifacts/macos_package_personal.md"),
             ("tests/out/floor/macos_deployment_floor.log",
              "evidence/artifacts/macos_deployment_floor.md"),
             ("tests/out/state_probe/macos_state_probe.log",
              "evidence/artifacts/macos_state_out_of_bundle.md"),
             ("tests/out/m11_check.log", "evidence/artifacts/macos_floor11_rebuild.md"),
             ("tests/out/m11_check_build.log",
              "evidence/artifacts/macos_floor11_rebuild_build.md"),
             ("tests/out/framework/framework_commits.log",
              "evidence/artifacts/macos_framework_commits.md"),
             ("tests/out/bundle/bundle_verify.log",
              "evidence/artifacts/bundle_verify.md"),
             ("tests/out/exechold/exec_hold_probe.log",
              "evidence/artifacts/macos_exec_hold.md"),
             ("tests/out/openprobe/user_open_probe.log",
              "evidence/artifacts/macos_user_open.md"),
             ("tests/out/doc_audit/doc_quote_audit.log",
              "evidence/artifacts/doc_quote_audit.md")]
    cited_arts = set(re.findall(r"evidence/artifacts/[A-Za-z0-9_-]+\.md",
                                "\n".join(lines[start - 1:end])))
    for art in sorted(cited_arts - {p[1] for p in pairs}):
        findings.append(("artifact", 0, "cited in the range, never compared: %s" % art))
    checked = 0
    for log, art in pairs:
        p, a = ROOT / log, ROOT / art
        if not p.exists():
            print("  log absent (scratch pruned), artifact compared elsewhere: %s" % log)
            continue
        if p.read_bytes() != a.read_bytes():
            findings.append(("artifact", 0, "%s != %s" % (log, art)))
        checked += 1

    print("witnesses: %d evidence files + %d history blobs = %.1f KB for quotations"
          % (len(CORPUS_FILES), len(CORPUS_GIT_EVIDENCE), len(blob) / 1024))
    print("figures may also use this README's %d older revisions (+%.1f KB)"
          % (len(CORPUS_GIT_DOC), len(" ".join(hist_parts)) / 1024))
    print("range audited: tests/README.md lines %d-%d" % (start, end))
    print("artifact/log byte comparisons clean: %d of %d pairs on disk"
          % (checked, len(pairs)))
    seen = set()
    for kind, n, what in findings:
        if what in ALLOW or norm(what) in ALLOW_NORM:
            print("  accepted  %-8s line %-5d %s\n            because: %s"
                  % (kind, n, what, ALLOW.get(what, ALLOW_NORM.get(norm(what)))))
            continue
        seen.add(what)
        print("  FINDING   %-8s line %-5d %s" % (kind, n, what))
    for qn, (_q, cited, n) in sorted(accepted_cited.items(), key=lambda kv: kv[1][2]):
        print("  accepted  quote    line %-5d %s\n            because: this README's "
              "older revision preserves it, and the prose beside it cites %s"
              % (n, qn, ", ".join(cited)))
    print("untraceable findings: %d" % len(seen))
    return len(seen)


if __name__ == "__main__":
    sys.exit(main())
