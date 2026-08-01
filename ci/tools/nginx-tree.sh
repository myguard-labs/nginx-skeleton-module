#!/bin/sh
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
#
# ci/tools/nginx-tree.sh -- print the path of a build tree produced by
# ci/tools/ci-build.sh, or fail with the command that would create it.
#
#   ci/tools/nginx-tree.sh              # the debug tree
#   ci/tools/nginx-tree.sh coverage     # the coverage tree
#
# Env:
#   NGINX_BUILD_MODE   same as $1 (default: debug)
#   NGINX_VERSION      skip the glob and use this version
#
# Output: the absolute tree path on stdout, nothing else -- callers do
#   NGX_SRC="$(ci/tools/nginx-tree.sh debug)"
# so any diagnostic MUST go to stderr or it lands in the caller's variable.
#
# Exit: 0 found, 1 no such tree (message names the ci-build.sh line to run).
#
# Why this is its own file: three consumers now need the same tree and the same
# "which mode suffix belongs to the version" parsing -- ci/fuzz/build.sh,
# ci/tests/unit/run.sh and ci/tools/coverage.sh. The parsing is the fiddly part:
# ci-build.sh keeps ONE TREE PER MODE at .build/nginx-<ver>-<mode>, so a naive
# `nginx-*` glob reads "1.31.3-asan" as the version and every consumer that
# copied the loop got to rediscover that separately. One copy, one place to fix.
#
# Limits: only nginx trees (angie names its binary differently and no consumer
# here needs it yet). Does not build anything -- deliberately, so a caller can
# fail with an actionable message instead of silently starting a 5-minute build.
#
# Extend: a new mode needs no change here; it is just $1.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MODE="${1:-${NGINX_BUILD_MODE:-debug}}"

if [ -z "${NGINX_VERSION:-}" ]; then
    for d in "$REPO_ROOT"/.build/nginx-*-"$MODE"/; do
        [ -d "$d" ] || continue
        v=${d%/}; v=${v##*/nginx-}; v=${v%-"$MODE"}
        # The tarball sits beside the trees; a glob that matched it would
        # yield a version ending in ".tar".
        case "$v" in *.tar*) continue ;; esac
        NGINX_VERSION=$v   # last match wins; a single tree in practice
    done
fi

if [ -z "${NGINX_VERSION:-}" ]; then
    echo "ERROR: no .build/nginx-*-$MODE tree found." >&2
    echo "       Run: bash ci/tools/ci-build.sh nginx <version> $MODE" >&2
    exit 1
fi

NGX_SRC="$REPO_ROOT/.build/nginx-${NGINX_VERSION}-${MODE}"

# Both checks matter and fail for different reasons. src/core missing means the
# tarball was never unpacked; objs missing means configure never ran, and objs
# is where ngx_auto_config.h lives -- without it every consumer here fails deep
# inside a compile with a missing-header error that names neither cause.
if [ ! -d "$NGX_SRC/src/core" ]; then
    echo "ERROR: nginx source not found at $NGX_SRC" >&2
    echo "       Run: bash ci/tools/ci-build.sh nginx $NGINX_VERSION $MODE" >&2
    exit 1
fi
if [ ! -d "$NGX_SRC/objs" ]; then
    echo "ERROR: $NGX_SRC is unconfigured (no objs/, so no ngx_auto_config.h)." >&2
    echo "       Run: bash ci/tools/ci-build.sh nginx $NGINX_VERSION $MODE" >&2
    exit 1
fi

printf '%s\n' "$NGX_SRC"
