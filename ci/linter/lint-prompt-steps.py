#!/usr/bin/env python3
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
"""Every "step N" citation names a step that ci/PROMPT.md actually defines.

PROMPT.md is 2100+ lines and is the specification nine sibling modules are
rolled out against. Its steps are addressed BY NUMBER, both from inside the file
and from README.md, ci/feedback/, ci/tools/ and ci/linter/. Nothing else in the
tree can tell whether those numbers still resolve: renumbering a step, deleting
one, or rewriting a block that cited one is a silent edit, and the reader who
follows a dangling "see step 27" lands on the wrong instruction -- or on nothing
-- with no error anywhere.

Two directions, both silent on their own:

  * a citation naming a step that does not exist -- the renumber/deletion case;
  * a gap or duplicate in the step sequence itself (1..N, no holes), which is
    how a half-finished renumber leaves the file and how two headings end up
    answering to one citation number.

Deliberately NOT checked: whether a citation points at the RIGHT step. That
needs a human, and a check pretending to do it would be false comfort.

Exit: 0 clean, 1 findings, 2 could not run (no recognisable step headings).

Env: PROMPT_STEPS_ROOT   tree to check (default: the git checkout). The selftest
                         generates a small tree here; nothing else sets it.

Extend: add a citing path to CITERS_RE. Resist asserting citation semantics.
"""

import os
import re
import subprocess
import sys

# A step DEFINITION is a heading "## N — Title" at the start of a line. The
# em-dash is the file's own convention; a hyphen is accepted so a step typed
# with the wrong dash registers as defined rather than turning every citation
# of it into a dangling-reference finding.
DEF_RE = re.compile(r"^##[ \t]+(\d+)[ \t]*[—-]", re.MULTILINE)

# A CITATION is the prose form "step 27" / "Step 27". Bounded on the right so
# "step 3" does not match inside "step 33".
CITE_RE = re.compile(r"\bstep[ \t]+(\d+)\b", re.IGNORECASE)

CITERS_RE = re.compile(
    r"^(ci/PROMPT\.md|README\.md|ci/feedback/.*\.md|ci/tools/.*|ci/linter/.*)$"
)

# Files that WRITE ABOUT citations rather than making them. ci/linter/README.md
# documents the reproduce recipe ("append `See step 99`, watch it go red"), and
# this checker's own source and selftest carry example numbers -- all of which
# this check read as dangling citations the first time it ran over the tree it
# had just been documented in. The fixture tree carries deliberate defects for
# the same reason.
#
# Scoped to ci/linter/ deliberately: a genuine dangling citation in README.md,
# ci/feedback/ or ci/tools/ is exactly what the check is for, and widening this
# list to silence a finding would hollow it out.
SKIP_PREFIXES = ("ci/linter/fixtures/",)
SKIP_EXACT = (
    "ci/linter/lint-prompt-steps.py",
    "ci/linter/lint-prompt-steps.sh",
    "ci/linter/selftest.sh",
    "ci/linter/README.md",
)

# One mistyped heading ("## 127" for "## 27") makes every number above the real
# last step read as missing. Truncate the list; the count stays exact.
MAX_GAPS_SHOWN = 12


def _git_env():
    """The ambient environment with git's tree-location overrides removed.

    A git hook exports GIT_DIR (and sometimes GIT_WORK_TREE), and those win over
    `cwd`. Inherited, `git ls-files` below answers for the CHECKOUT no matter
    which directory it is pointed at -- so the selftest's generated root would
    be listed as the real repo, the os.walk fallback would never run, and the
    controls would assert against the wrong tree while still printing ok.
    """
    env = os.environ.copy()
    for var in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
        env.pop(var, None)
    return env


def candidate_files(root):
    """Files that may cite a step, relative to root."""
    try:
        out = subprocess.run(
            ["git", "ls-files"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
            env=_git_env(),
        ).stdout
        names = out.splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Not a git tree (the selftest's generated root). Walk it instead --
        # falling back to "no files" would make every control pass vacuously.
        names = []
        for dirpath, _, filenames in os.walk(root):
            for fn in filenames:
                rel = os.path.relpath(os.path.join(dirpath, fn), root)
                names.append(rel.replace(os.sep, "/"))
    return [n for n in names if CITERS_RE.match(n)]


def repo_root():
    """The checkout root, or None when there is not one to find.

    None rather than an exception: the caller turns it into exit 2 ("could not
    run"), which is the documented contract. Letting CalledProcessError escape
    printed a traceback and exited 1, and 1 is the status that means "findings"
    -- so a missing git, or a run from outside any checkout, read as a defect in
    PROMPT.md.
    """
    try:
        return subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
            env=_git_env(),
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def main():
    root = os.environ.get("PROMPT_STEPS_ROOT") or repo_root()
    if not root:
        print(
            "lint-prompt-steps: not a git checkout and PROMPT_STEPS_ROOT is "
            "unset -- cannot locate ci/PROMPT.md",
            file=sys.stderr,
        )
        return 2

    prompt_rel = "ci/PROMPT.md"
    prompt_path = os.path.join(root, prompt_rel)
    try:
        with open(prompt_path, encoding="utf-8") as fh:
            prompt = fh.read()
    except OSError as exc:
        print(f"lint-prompt-steps: cannot read {prompt_rel}: {exc}", file=sys.stderr)
        return 2

    defined = [int(m) for m in DEF_RE.findall(prompt)]
    if not defined:
        # Exit 2, not 1: with an empty step set every citation in the tree is
        # "dangling", and reporting hundreds of findings is how a useful gate
        # earns itself a deletion. "Could not run" is the honest verdict.
        print(
            f'lint-prompt-steps: {prompt_rel} has no "## N - Title" step '
            f"headings -- has the heading convention changed? Refusing to "
            f"report every citation as dangling.",
            file=sys.stderr,
        )
        return 2

    defined_set = set(defined)
    last = max(defined_set)
    problems = []

    dupes = sorted({n for n in defined if defined.count(n) > 1})
    if dupes:
        problems.append(
            f"{prompt_rel}: duplicate step number(s): "
            + ", ".join(str(n) for n in dupes)
            + " -- two headings answer to one citation"
        )

    gaps = sorted(set(range(1, last + 1)) - defined_set)
    if gaps:
        shown = ", ".join(str(n) for n in gaps[:MAX_GAPS_SHOWN])
        if len(gaps) > MAX_GAPS_SHOWN:
            shown += (
                f", ... ({len(gaps)} missing in total -- a step number "
                f"typed far too high looks like this)"
            )
        problems.append(
            f"{prompt_rel}: gap in the step sequence: missing "
            f"{shown} (steps run 1..{last})"
        )

    files = candidate_files(root)
    for rel in files:
        if rel in SKIP_EXACT or rel.startswith(SKIP_PREFIXES):
            continue
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as fh:
                lines = fh.readlines()
        except (OSError, UnicodeDecodeError):
            continue  # binary or unreadable: not a citation surface
        for lineno, line in enumerate(lines, 1):
            for m in CITE_RE.finditer(line):
                n = int(m.group(1))
                if n not in defined_set:
                    problems.append(
                        f"{rel}:{lineno}: cites step {n}, but {prompt_rel} "
                        f"defines steps 1..{last}"
                    )

    if problems:
        print("lint-prompt-steps: findings", file=sys.stderr)
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        return 1

    print(
        f"lint-prompt-steps: {len(defined_set)} steps defined, all citations "
        f"in {len(files)} file(s) resolve"
    )
    return 0


if __name__ == "__main__":
    # `--citers-re` exists so lint-prompt-steps.sh can ask for the trigger
    # pattern instead of keeping a second copy of it. A copy goes stale the
    # first time someone follows the docstring and extends CITERS_RE here: the
    # wrapper's list would still be the old one, and under LINT_MODE=staged a
    # change to the newly-added citing path would no longer start the check --
    # the gate staying quiet in exactly the case it was extended for.
    if len(sys.argv) > 1 and sys.argv[1] == "--citers-re":
        print(CITERS_RE.pattern)
        sys.exit(0)
    sys.exit(main())
