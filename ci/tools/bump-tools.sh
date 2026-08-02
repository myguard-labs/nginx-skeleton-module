#!/usr/bin/env bash
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
#
# ci/tools/bump-tools.sh -- move the pinned PyPI linter versions to their newest
# release, in EVERY file that names them.
#
#   ci/tools/bump-tools.sh [--dry-run]
#
# WHY THIS IS NOT A ONE-LINE sed
#
# `semgrep==1.169.0` appears in three files that must agree: the CI gate
# (.github/workflows/security-scanners.yml), the local installer
# (ci/linter/install-linters.sh) and the error message that tells you how to
# install it (ci/linter/lint-c.sh). They are pinned to the same version ON
# PURPOSE -- the whole point of the pin is that local lint predicts remote CI.
# Bumping one and missing another does not fail loudly; it just means local and
# CI quietly disagree about what "clean" means, which is the exact failure the
# pin exists to prevent. So this rewrites every occurrence repo-wide and
# asserts afterwards that one version is left.
#
# Deliberately NOT bumped here:
#   zizmor   -- unpinned by design (install-linters.sh explains: a frozen
#               security scanner stops finding what it was added for).
#   codespell -- same, the dictionary is the point.
# Adding a pin for either is a policy change, not a bump.
#
# Requires: curl, python3. Network: pypi.org.

set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(dirname "$0")/../.."

CHANGED=0
# See bump-actions.sh: "could not check" must never be reported as "up to
# date", or an outage/rename leaves the pins rotting behind a green job.
FAILED=0

# Package name -> the files allowed to carry its pin. Listing them rather than
# globbing keeps a stray match in a .md or a lockfile from being rewritten.
TOOLS=(
    "semgrep:.github/workflows/security-scanners.yml ci/linter/install-linters.sh ci/linter/lint-c.sh"
    "ruff:ci/linter/install-linters.sh"
)

newest_on_pypi() {
    # /json returns every release; info.version is the newest NON-prerelease,
    # which is what a CI pin wants. Fail loudly rather than emit an empty
    # string that a later sed would happily write into the file.
    local pkg="$1" body
    body="$(curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 60 \
              "https://pypi.org/pypi/${pkg}/json")" || return 1
    printf '%s' "$body" | python3 -c '
import json,sys
v = json.load(sys.stdin)["info"]["version"]
if not v:
    sys.exit(1)
print(v)
'
}

for entry in "${TOOLS[@]}"; do
    pkg="${entry%%:*}"
    files="${entry#*:}"

    # Current pin, read from the first file that has one. All files are asserted
    # to agree at the end, so any of them is a valid source of truth here.
    cur=""
    for f in $files; do
        [ -f "$f" ] || continue
        cur="$(grep -hoE "${pkg}==[0-9]+(\.[0-9]+)*" "$f" | head -1 | cut -d= -f3- || true)"
        [ -n "$cur" ] && break
    done
    if [ -z "$cur" ]; then
        echo "FAILED ${pkg}: no ${pkg}== pin found in any of its listed files" >&2
        FAILED=1
        continue
    fi

    if ! new="$(newest_on_pypi "$pkg")"; then
        echo "FAILED ${pkg}: could not reach pypi.org, ${cur} left alone" >&2
        FAILED=1
        continue
    fi

    if [ "$new" = "$cur" ]; then
        echo "${pkg}: already newest (${cur})"
        continue
    fi

    echo "bump ${pkg}: ${cur} -> ${new}"
    CHANGED=1
    [ "$DRY_RUN" = 1 ] && continue

    for f in $files; do
        [ -f "$f" ] || continue
        perl -pi -e "s{\Q${pkg}==${cur}\E}{${pkg}==${new}}g" "$f"
    done

    # The sync IS the feature -- assert it rather than assume the loop above
    # covered every copy. A pin that reappears somewhere unlisted must fail the
    # bump, not ship a split-brain version.
    stray="$(grep -rhoE "${pkg}==[0-9]+(\.[0-9]+)*" \
                --include='*.yml' --include='*.yaml' --include='*.sh' \
                .github ci 2>/dev/null | sort -u | grep -v "^${pkg}==${new}$" || true)"
    if [ -n "$stray" ]; then
        echo "FATAL: ${pkg} pins disagree after bump:" >&2
        printf '  %s\n' "$stray" >&2
        echo "  add the file holding it to TOOLS[] in $0" >&2
        exit 1
    fi
done

if [ "$FAILED" = 1 ]; then
    echo "FATAL: at least one tool pin could not be checked -- refusing to" >&2
    echo "  report success (see bump-actions.sh for why)." >&2
    echo "TOOLS_CHANGED=$CHANGED"
    exit 1
fi

[ "$CHANGED" = 0 ] && echo "tools: every pin already newest"
echo "TOOLS_CHANGED=$CHANGED"
