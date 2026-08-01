#!/usr/bin/env bash
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
#
# ci/tests/unit/run.sh -- build and run the scan-core unit tests.
#
#   ci/tests/unit/run.sh            # build with warnings-as-errors, then run
#   ci/tests/unit/run.sh clean      # remove the built binary
#   COVERAGE=1 ci/tests/unit/run.sh # also instrument, so ci/tools/coverage.sh
#                                   # can gcov src/ afterwards
#
# Env:
#   CC                 compiler (default cc). The cross legs pass a full
#                      driver line here, e.g. CC="gcc -m32".
#   NGINX_BUILD_MODE   which .build tree to take headers + ngx_string.c from
#                      (default debug; the coverage leg passes `coverage`).
#
# Exit: 0 all checks passed, 1 a check failed or the build failed.
#
# Runs in well under a second and needs no nginx process, no network and no
# root -- so it is the layer a derived module can afford to run on every save,
# and the layer the -m32 leg can afford to run under a cross toolchain.
#
# WHAT IT DOES *NOT* DO, deliberately: it does not shim nginx. The test binary
# links the REAL src/core/ngx_string.c out of the build tree, which is why a
# tree must exist first (ci/tools/ci-build.sh). A shimmed ngx_unescape_uri()
# would make this hermetic and worthless: the decoder is the single most likely
# place for our matching to diverge from what nginx actually serves, so a test
# asserting against a private copy of it asserts only that the copy is
# self-consistent. Paying a build dependency to keep the decoder honest is the
# right side of that trade.
#
# -Werror applies to OUR translation units only. ngx_string.c is upstream code
# we neither own nor patch, and gating on warnings in it would make an nginx
# version bump look like a test regression -- the same reasoning that keeps
# -Wshadow out of ci-build.sh's whole-tree --with-cc-opt.
#
# SEEN RED -- every mutation below was APPLIED to src/ and the named check was
# observed failing (2026-08-01). Re-run them after touching the scan core or
# this script: a check that has never failed is not known to be a check.
#
#   * cap clamp off by one -- in ngx_http_skel_scan(), clamp to
#     `NGX_HTTP_SKEL_SCAN_MAX - 1`
#       -> "marker ending exactly at the cap matches" FAILS (1 of 23).
#   * seam carry disabled -- in ngx_http_skel_scan_piece(), `keep = 0` instead
#     of the clamp
#       -> 5 of the 6 split-invariance checks FAIL. The sixth is the CLEAN
#          control, which correctly stays green -- that asymmetry is the reason
#          it is in the input list.
#   * matcher always matches -- `return NGX_HTTP_SKEL_MATCH` at the top of
#     ngx_http_skel_match()
#       -> 5 FAIL, spread across the clean baseline, the double-encoding case
#          and both negative cap cases.
#   * hold not cleared -- drop `st->hold_len = 0;` from
#     ngx_http_skel_stream_final()
#       -> "final() clears the hold" FAILS.
#
# TWO MUTATIONS THAT SURVIVE, recorded so the next person does not mistake
# either for a gap in this file:
#   * `if (len > MAX)` -> `>=` in the cap clamp is a NO-OP (clamping a value
#     that already equals MAX to MAX changes nothing). It is not a defect and
#     nothing here should catch it.
#   * stubbing ngx_http_skel_stream_final() to `return CLEAN` immediately
#     leaves all 23 green. That is a real limit, not an oversight: the held
#     bytes are always an INCOMPLETE escape, and no SHIPPED rule ends in those
#     literal bytes, so final() cannot produce a MATCH for this rule table. It
#     becomes matchable in a derived module whose rules contain a literal '%'.
#     See case_stream_hold_and_flush() for what IS asserted instead.
#
# Extend: add a CASE() to test_scan.c and one line to its main(). New source
# file in src/ -> add it to SRCS below.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
BIN="$DIR/test_scan"

if [ "${1:-}" = "clean" ]; then
    # *.o too: this script produces them below and .gitignore already lists
    # them as generated. Leaving them behind meant `clean` did not give you a
    # clean tree -- switching $CC (say to `gcc -m32` while reproducing the
    # 32-bit leg) then relinked stale objects from the previous toolchain.
    rm -f "$BIN" "$DIR"/*.o "$DIR"/*.gcda "$DIR"/*.gcno
    echo "unit test binary removed"
    exit 0
fi

NGX_SRC="$(sh "$ROOT/ci/tools/nginx-tree.sh" "${NGINX_BUILD_MODE:-debug}")"
echo "Using nginx source: $NGX_SRC"

CC="${CC:-cc}"

NGX_INCS=(
    -I"$NGX_SRC/src/core"
    -I"$NGX_SRC/src/event"
    -I"$NGX_SRC/src/event/modules"
    -I"$NGX_SRC/src/os/unix"
    -I"$NGX_SRC/objs"
    -I"$NGX_SRC/src/http"
    -I"$NGX_SRC/src/http/modules"
)

# Our code: the full warning wall. A 32-bit leg that only passes
# with these loosened would be hiding the exact class of defect it exists for.
OWN_CFLAGS=(-g -O1 -Wall -Wextra -Wshadow -Wstrict-prototypes -Werror)
# Upstream code: warnings visible, not fatal (see the header).
NGX_CFLAGS=(-g -O1 -Wall)

if [ "${COVERAGE:-0}" = 1 ]; then
    OWN_CFLAGS+=(--coverage)
    NGX_CFLAGS+=(--coverage)
    LINK_EXTRA=(--coverage)
else
    LINK_EXTRA=()
fi

# ci/fuzz/ngx_stubs.c is reused, not copied: it already resolves the
# allocator/log symbols ngx_string.c drags in, and aborts if the scan path ever
# reaches one. A second copy here would be a second thing to keep in sync with
# the scan core's no-allocate contract.
echo "==> Building $BIN with ${CC}"
# shellcheck disable=SC2086  # $CC may legitimately carry flags (e.g. "gcc -m32")
$CC "${OWN_CFLAGS[@]}" "${NGX_INCS[@]}" -I"$ROOT/src" -c "$DIR/test_scan.c" \
    -o "$DIR/test_scan.o"
# shellcheck disable=SC2086
$CC "${OWN_CFLAGS[@]}" "${NGX_INCS[@]}" -I"$ROOT/src" \
    -c "$ROOT/src/ngx_http_skel_scan.c" -o "$DIR/ngx_http_skel_scan.o"
# shellcheck disable=SC2086
$CC "${OWN_CFLAGS[@]}" "${NGX_INCS[@]}" -c "$ROOT/ci/fuzz/ngx_stubs.c" \
    -o "$DIR/ngx_stubs.o"
# shellcheck disable=SC2086
$CC "${NGX_CFLAGS[@]}" "${NGX_INCS[@]}" -c "$NGX_SRC/src/core/ngx_string.c" \
    -o "$DIR/ngx_string.o"
# shellcheck disable=SC2086
$CC "${LINK_EXTRA[@]}" -o "$BIN" \
    "$DIR/test_scan.o" "$DIR/ngx_http_skel_scan.o" "$DIR/ngx_stubs.o" \
    "$DIR/ngx_string.o"

echo "==> Running"
"$BIN"
