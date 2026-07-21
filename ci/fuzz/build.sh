#!/bin/sh
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
#
# fuzz/build.sh -- build the libFuzzer targets.
#
#   bash fuzz/build.sh          # build into fuzz/
#   bash fuzz/build.sh clean    # remove built binaries
#
# Needs clang with -fsanitize=fuzzer. The nginx source tree must already be at
# .build/nginx-<VER>/ (run tools/ci-build.sh first): the target links nginx's
# real ngx_unescape_uri()/ngx_strlcasestrn() out of src/core/ngx_string.c, so
# the decoder and matcher under test are production code, not stubs.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BIN_DIR="$SCRIPT_DIR"

if [ "${1:-}" = "clean" ]; then
    rm -f "$BIN_DIR/fuzz_scan" "$BIN_DIR/fuzz_body"
    echo "fuzz binaries removed"
    exit 0
fi

# --- Locate the nginx source headers. --------------------------------------
# ci-build.sh keeps ONE TREE PER MODE (.build/nginx-<ver>-<mode>), because
# debug and asan objects are not interchangeable. The fuzz target only needs
# HEADERS (ngx_auto_config.h) plus ngx_string.c, which are mode-independent --
# so any tree will do, but the glob must not mistake the "-<mode>" suffix for
# part of the version. NGINX_BUILD_MODE picks one explicitly.
NGINX_BUILD_MODE="${NGINX_BUILD_MODE:-debug}"

if [ -z "${NGINX_VERSION:-}" ]; then
    for d in "$REPO_ROOT"/.build/nginx-*-"$NGINX_BUILD_MODE"/; do
        [ -d "$d" ] || continue
        v=${d%/}; v=${v##*/nginx-}; v=${v%-"$NGINX_BUILD_MODE"}
        case "$v" in *.tar*) continue;; esac
        NGINX_VERSION=$v   # last glob match wins; a single tree in practice
    done
fi
if [ -z "${NGINX_VERSION:-}" ]; then
    echo "ERROR: could not determine NGINX_VERSION; run tools/ci-build.sh first" >&2
    exit 1
fi

NGX_SRC="$REPO_ROOT/.build/nginx-${NGINX_VERSION}-${NGINX_BUILD_MODE}"
if [ ! -d "$NGX_SRC/src/core" ]; then
    echo "ERROR: nginx source not found at $NGX_SRC" >&2
    echo "       Run: bash tools/ci-build.sh nginx $NGINX_VERSION" >&2
    exit 1
fi
if [ ! -d "$NGX_SRC/objs" ]; then
    echo "ERROR: nginx not configured ($NGX_SRC/objs missing); that dir holds" >&2
    echo "       ngx_auto_config.h. Run tools/ci-build.sh first." >&2
    exit 1
fi

echo "Using nginx source: $NGX_SRC"
echo "Building into: $BIN_DIR"
mkdir -p "$BIN_DIR"

CC="${CC:-clang}"
SANITIZERS="-fsanitize=fuzzer,address,undefined"
COMMON_CFLAGS="-g -O1 $SANITIZERS -fno-omit-frame-pointer"

NGX_INCS="-I$NGX_SRC/src/core -I$NGX_SRC/src/event -I$NGX_SRC/src/event/modules \
    -I$NGX_SRC/src/os/unix -I$NGX_SRC/objs \
    -I$NGX_SRC/src/http -I$NGX_SRC/src/http/modules -I$NGX_SRC/src/http/v2"

# --- fuzz_scan: the normalize + match core. --------------------------------
# Links the module's real scan TU plus nginx's real ngx_string.c, so the decoder
# under test (ngx_unescape_uri) is production code rather than a stub.
#
# ngx_string.c is one TU: it also carries ngx_pstrdup()/ngx_sort()/ngx_vslprintf(),
# which reference the allocator and the global cycle. The scan path never calls
# them, but the linker still needs the symbols -- hence ngx_stubs.c, which aborts
# if any of them is ever actually reached. Linking nginx's real ngx_palloc.c
# instead would drag in the log, the cycle, and eventually the conf parser.
echo
echo "==> Building fuzz_scan ..."
# shellcheck disable=SC2086
"$CC" $COMMON_CFLAGS $NGX_INCS \
    -I "$REPO_ROOT/src" \
    -o "$BIN_DIR/fuzz_scan" \
    "$SCRIPT_DIR/fuzz_scan.c" \
    "$SCRIPT_DIR/ngx_stubs.c" \
    "$REPO_ROOT/src/ngx_http_skel_scan.c" \
    "$NGX_SRC/src/core/ngx_string.c"
echo "    OK: $BIN_DIR/fuzz_scan"

# --- fuzz_body: the seam/multi-chunk stream-scan core (scan_piece). --------
# Same TU + real ngx_string.c as fuzz_scan above; scan_piece is now declared
# in ngx_http_skel_scan.h (moved out of module.c so this target can link it
# without pulling in the module's ngx_http_request_t plumbing).
echo
echo "==> Building fuzz_body ..."
# shellcheck disable=SC2086
"$CC" $COMMON_CFLAGS $NGX_INCS \
    -I "$REPO_ROOT/src" \
    -o "$BIN_DIR/fuzz_body" \
    "$SCRIPT_DIR/fuzz_body.c" \
    "$SCRIPT_DIR/ngx_stubs.c" \
    "$REPO_ROOT/src/ngx_http_skel_scan.c" \
    "$NGX_SRC/src/core/ngx_string.c"
echo "    OK: $BIN_DIR/fuzz_body"

echo
echo "Build complete. Binaries in $BIN_DIR/"
echo
echo "Quick smoke-run (15 s):"
echo "  $BIN_DIR/fuzz_scan -max_total_time=15 $SCRIPT_DIR/corpus/fuzz_scan"
echo "  $BIN_DIR/fuzz_body -max_total_time=15 $SCRIPT_DIR/corpus/fuzz_body"
