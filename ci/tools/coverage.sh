#!/usr/bin/env bash
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
#
# ci/tools/coverage.sh -- line + branch coverage of the MODULE's own sources.
#
#   ci/tools/coverage.sh [version]
#
# Steps:
#   1. ci-build.sh nginx <version> coverage  -> a gcov-instrumented .so plus a
#      server binary, in its own .build/nginx-<ver>-coverage tree. The .gcno
#      files land under objs/addon/src/.
#   2. ci/tests/unit/run.sh with COVERAGE=1 -> the scan core's boundary cases.
#   3. prove ci/t/ against that server -> the request-path cases. nginx flushes
#      .gcda on a graceful exit, which is how the worker's arcs reach disk;
#      Test::Nginx stops the server between blocks, so this needs no special
#      handling, but a test that KILLs nginx contributes nothing.
#   4. gcovr over the module's own src/ only.
#
# Env:
#   COVERAGE_FAIL_UNDER   if set, gcovr exits non-zero below this line %.
#                         UNSET by default, and that is a decision, not an
#                         omission: the repo policy is meaningful tests over a
#                         percentage (see the coverage note in CONTRIBUTING.md).
#                         CI publishes the report; it does not fail on a number,
#                         because the cheapest way to move a number is to write
#                         the tests that move it without asserting anything.
#   COVERAGE_OUT          output directory (default .build/coverage).
#
# Exit: 0 on success (or a below-threshold report when COVERAGE_FAIL_UNDER is
# unset), non-zero if a build/test step failed or the threshold was set and
# missed.
#
# WHY THE FILTER IS `src/` AND NOTHING ELSE: nginx's core objects are compiled
# by the same instrumented configure run, so an unfiltered gcovr reports ~1% of
# a 200k-line upstream tree and the module's own numbers vanish into it. The
# module's sources are the coverage target; upstream nginx is not ours to test.
#
# Extend: a new test layer belongs between steps 2 and 3, before gcovr runs --
# adding it after the report is generated silently contributes nothing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Validated, not just sourced: this file is `source`d, so a line that is not a
# pin runs as shell. This script used to source it bare while ci-build.sh
# validated -- the rule now lives in one place and every consumer calls it.
# shellcheck source=ci/tools/versions-env.sh
. "$ROOT/ci/tools/versions-env.sh"
load_versions_env "$ROOT/.github/versions.env" || exit 1
VERSION="${1:-$NGINX_VERSION}"
OUT="${COVERAGE_OUT:-$ROOT/.build/coverage}"

command -v gcovr >/dev/null 2>&1 || {
    echo "ERROR: gcovr not found. Install it: pipx install gcovr" >&2
    exit 2
}

echo "==> Building nginx $VERSION with gcov instrumentation"
bash ci/tools/ci-build.sh nginx "$VERSION" coverage

BUILD="$ROOT/.build/nginx-${VERSION}-coverage"
OBJDIR="$BUILD/objs/addon/src"

# The instrumented objects must actually exist before anything is run against
# them. Without this the suite runs, gcovr finds no .gcno, and the report reads
# "0.0%" -- which looks like a coverage finding rather than a broken build.
if ! compgen -G "$OBJDIR/*.gcno" >/dev/null; then
    echo "FAIL: no .gcno under $OBJDIR -- the build was NOT instrumented." >&2
    echo "      A coverage report from this tree would read 0% and mean nothing." >&2
    echo "      Suspect a cached non-coverage build tree restored into this mode." >&2
    exit 1
fi

# Stale arcs from a previous run would be merged into this one's counts.
find "$OBJDIR" -name '*.gcda' -delete

echo "==> Unit tests (instrumented)"
# NGINX_VERSION passed explicitly. Without it ci/tests/unit/run.sh falls back to
# ci/tools/nginx-tree.sh's glob, which would have to pick between build trees on
# its own -- and this script knows exactly which tree it just built. Relying on
# the glob here meant the instrumented unit run could be pointed at a leftover
# tree of a different version than the one the report is generated from.
COVERAGE=1 NGINX_VERSION="$VERSION" NGINX_BUILD_MODE=coverage \
    bash ci/tests/unit/run.sh

echo "==> Test::Nginx suite against the instrumented server"
# TEST_NGINX_PORT pinned to this job's band. Test::Nginx::Socket falls back to
# TEST_NGINX_SERVER_PORT, then TEST_NGINX_PORT, then a hardcoded 1984
# (Test/Nginx/Util.pm: `our $ServerPort = $ENV{TEST_NGINX_SERVER_PORT} ||
# $ENV{TEST_NGINX_PORT} || 1984`). The build host runs six CI slots at once, so two
# jobs reaching that default bind the same port on one host: one fails with
# "Address already in use", or worse, one suite quietly talks to the other
# job's server. The band is per-job and the two suites here run in sequence, so
# they can share it.
TEST_NGINX_BINARY="$BUILD/objs/nginx" \
TEST_NGINX_LOAD_MODULES="$BUILD/objs/ngx_http_skel_module.so" \
TEST_NGINX_TIMEOUT="${TEST_NGINX_TIMEOUT:-20}" \
TEST_NGINX_PORT="${TEST_BASE_PORT:-18880}" \
TEST_NGINX_SERVROOT="$ROOT/ci/t/servroot" \
    prove ci/t/

echo "==> Report"
mkdir -p "$OUT"
GCOVR_ARGS=(
    --root "$ROOT"
    # Only the module's own sources. See the header for why an unfiltered run
    # is worse than useless here.
    --filter "$ROOT/src/"
    --branches
    --print-summary
    --html-details "$OUT/index.html"
    --txt "$OUT/summary.txt"
)
if [ -n "${COVERAGE_FAIL_UNDER:-}" ]; then
    GCOVR_ARGS+=(--fail-under-line "$COVERAGE_FAIL_UNDER")
fi

# Both object dirs: the nginx-linked module objects and the unit-test objects,
# which cover the same src/ TUs from a different driver. Merging them is the
# point -- a line reached only by the unit harness is still reached.
# --object-directory, not --gcov-object-directory: the latter was only added in
# gcovr 7.0 as an alias for this one, and an unknown option is a hard argparse
# failure, not a warning. The fork arm of this job runs on ubuntu-latest, whose
# gcovr is older than the self-hosted runner's -- so the newer spelling would
# fail exactly on the runner nobody watches. Both spellings work on 7.x.
gcovr "${GCOVR_ARGS[@]}" \
    --object-directory "$OBJDIR" \
    "$OBJDIR" "$ROOT/ci/tests/unit"

echo
echo "HTML report: $OUT/index.html"
echo "Summary:     $OUT/summary.txt"
