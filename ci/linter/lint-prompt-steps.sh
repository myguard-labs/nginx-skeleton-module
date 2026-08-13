#!/usr/bin/env bash
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
#
# ci/linter/lint-prompt-steps.sh -- every "step N" citation names a step that
# ci/PROMPT.md actually defines.
#
# The rule and the reasoning live in ci/linter/lint-prompt-steps.py; this
# wrapper exists so run-all.sh picks the check up by glob and
# LINT_ONLY=prompt-steps selects it.
#
# Usage: ci/linter/lint-prompt-steps.sh [files...]   Env: LINT_MODE=staged|all

# shellcheck source=ci/linter/lib.sh
. "$(git rev-parse --show-toplevel)/ci/linter/lib.sh"

need python3 "apt-get install python3"

PY="$(git rev-parse --show-toplevel)/ci/linter/lint-prompt-steps.py"

# The trigger pattern is OWNED by CITERS_RE in the Python module and read back
# from it, never copied here: the module's docstring tells the next maintainer
# to extend CITERS_RE, and a second copy in this file would silently not be
# extended with it.
CITERS_RE="$(python3 "$PY" --citers-re)" \
    || die "cannot read the citing-path pattern from $PY"

mapfile -t FILES < <(lint_files "$CITERS_RE" "$@")
[ "${#FILES[@]}" -gt 0 ] || { echo "lint-prompt-steps: no citing files changed"; exit 0; }

# Whole-tree by nature: a citation lives in one file and the step it names lives
# in another, so a narrowed file list would validate README.md against a
# PROMPT.md that is usually not itself staged -- or against nothing at all. The
# file list above is a "did anything relevant change" trigger, not the scope.
exec python3 "$PY"
