#!/usr/bin/env bash
#
# Refresh every upstream pin in this repo. Called by .github/workflows/bump.yml
# on a schedule; also runnable locally to preview a bump before it lands.
#
#   ci/tools/bump-versions.sh [--dry-run]
#
# Four things move here:
#   - .github/versions.env            -- nginx mainline/stable + angie versions
#                                        AND their sha256s, rewritten wholesale
#                                        by .github/scripts/compute-versions.sh
#   - GitHub Action sha pins          -- ci/tools/bump-actions.sh (sha + the tag
#                                        comment beside it, as one unit)
#   - pinned linter versions          -- ci/tools/bump-tools.sh (semgrep, ruff;
#                                        every copy of each pin, kept in sync)
#   - ci/vendor/nginx-tests submodule -- `git submodule update --remote`
#
# This script used to sed a version literal into each of seven workflow files,
# patch ci-deep.yml's matrix, and insert a matching digest into a table in
# ci-build.sh. Those pins now live on adjacent lines in one file with one
# writer, so the failure modes that design had -- a bumped version carrying a
# stale digest, or one workflow missed by the sed and silently gating on an old
# nginx -- are gone by construction, and so is the code that managed them.
#
# --dry-run reports what WOULD change without writing anything: versions.env is
# regenerated into a scratch copy and diffed, and the submodule is left alone.
#
# Exit status is 0 whether or not anything changed; the caller decides what to
# do with a dirty tree. Prints CHANGED=0|1 as its last line.
#
# GH_TOKEN is honoured (passed through to compute-versions.sh as GITHUB_TOKEN):
# the runners share an egress IP, so unauthenticated api.github.com calls are
# routinely rate-limited to 403s.

set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(dirname "$0")/../.."

# compute-versions.sh reads GITHUB_TOKEN; bump.yml historically set GH_TOKEN.
export GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

CHANGED=0
VERSIONS_FILE=".github/versions.env"

# --- version + sha256 pins -------------------------------------------------
if [ "$DRY_RUN" = 0 ]; then
    # Tolerate a missing file: compute-versions.sh creates it from scratch, so
    # bootstrapping (or regenerating after a delete) should report "changed"
    # rather than dying here under set -e.
    before="$(cat "$VERSIONS_FILE" 2>/dev/null || true)"
    bash .github/scripts/compute-versions.sh
    if [ "$before" != "$(cat "$VERSIONS_FILE")" ]; then
        echo "--- versions.env changed ---"
        git --no-pager diff -- "$VERSIONS_FILE" || true
        CHANGED=1
    else
        echo "versions.env already up to date"
    fi
else
    # Regenerate into a scratch copy so the working tree is untouched.
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT
    cp -a .github "$scratch/.github"
    ( cd "$scratch" && bash .github/scripts/compute-versions.sh >/dev/null )
    if diff -u "$VERSIONS_FILE" "$scratch/$VERSIONS_FILE"; then
        echo "(dry-run: versions.env already up to date)"
    else
        echo "(dry-run: versions.env would change as shown above)"
        CHANGED=1
    fi
fi

# --- GitHub Action pins ----------------------------------------------------
# Actions are already sha-pinned; what was missing was anything that MOVES the
# pin. An unmaintained sha is not "stable", it is a frozen copy of an action
# that stopped receiving its own security fixes. Major-line only -- see
# bump-actions.sh for why crossing a major unattended is not wanted.
if [ "$DRY_RUN" = 0 ]; then
    bash ci/tools/bump-actions.sh
else
    bash ci/tools/bump-actions.sh --dry-run
fi
if ! git diff --quiet -- .github/ 2>/dev/null; then
    CHANGED=1
fi

# --- pinned linter versions ------------------------------------------------
# semgrep/ruff are pinned so local lint predicts remote CI; bump-tools.sh keeps
# every copy of each pin in step and fails if one is left behind.
if [ "$DRY_RUN" = 0 ]; then
    bash ci/tools/bump-tools.sh
else
    bash ci/tools/bump-tools.sh --dry-run
fi
if ! git diff --quiet -- .github/ ci/ 2>/dev/null; then
    CHANGED=1
fi

# --- vendored nginx-tests submodule ---------------------------------------
if [ "$DRY_RUN" = 0 ]; then
    OLD_SUB_SHA="$(git -C ci/vendor/nginx-tests rev-parse HEAD)"
    git submodule update --remote --quiet ci/vendor/nginx-tests
    NEW_SUB_SHA="$(git -C ci/vendor/nginx-tests rev-parse HEAD)"
    if [ "$OLD_SUB_SHA" != "$NEW_SUB_SHA" ]; then
        echo "bump ci/vendor/nginx-tests: ${OLD_SUB_SHA:0:12} -> ${NEW_SUB_SHA:0:12}"
        CHANGED=1
    fi
else
    echo "(dry-run: skipping submodule update)"
fi

if [ "$CHANGED" = 0 ]; then
    echo "everything up to date, nothing to bump"
fi

echo "CHANGED=$CHANGED"
