#!/usr/bin/env bash
#
# Build nginx (or angie) with the module, for local dev and CI.
#
#   tools/ci-build.sh [flavor] [version] [mode]
#     flavor : nginx (default) | angie
#     version: source version, e.g. 1.31.2
#     mode   : debug (default, dynamic .so) | asan (static, sanitizers)
#              | module (dynamic .so only, nginx core NOT compiled)
#
# The built tree lives under ./.build, ONE TREE PER MODE:
#   .build/<dir>-<mode>/objs/nginx                     (server binary)
#   .build/<dir>-<mode>/objs/ngx_http_skel_module.so   (debug/module mode)
#
# Why "module" mode exists: CodeQL builds its database for C/C++ from whatever
# the traced build actually COMPILES -- the workflow's paths/paths-ignore filters
# do not apply to compiled languages. Building the nginx core therefore pulls all
# of upstream nginx into the database and raises alerts against code we neither
# own nor patch. Compiling only the module keeps the database to our TU.
#
# Why asan mode is a STATIC build: a sanitizer runtime must be linked into the
# executable. A dynamic .so loaded by a non-instrumented nginx gets no ASan
# runtime, and the job passes while checking nothing.
#
# ---------------------------------------------------------------------------
# CACHING -- and the one trap that makes it dangerous
#
# The three modes compile the SAME sources with INCOMPATIBLE flags (asan adds
# -fsanitize=address; debug does not). They used to share a single
# .build/<dir> tree and got away with it only because ./configure was re-run
# unconditionally and rewrote objs/Makefile every time -- i.e. correctness was
# an accident of NOT caching.
#
# The moment you cache the build tree (which is the whole point of this file),
# that accident becomes a bug: a cached debug objs/ restored into an asan job
# links non-instrumented objects, and the sanitizer job goes green while
# checking NOTHING. That is strictly worse than a slow build.
#
# So: the mode is part of the tree path AND part of every cache key. Never
# collapse these trees back into one to "save disk".
#
# Caches used, cheapest first:
#   1. ccache        -- compiler cache; keyed by content, so it survives a
#                       reconfigure. Wired via --with-cc, NOT the CC env var:
#                       nginx's configure ignores a bare CC=.
#   2. mold          -- faster linker, used when present.
#   3. the .build tree itself -- skips configure (5s of serial shell that
#                       ccache CANNOT help with; on this codebase configure is
#                       the dominant cost, not compilation).
#   4. the source tarball -- see the workflows' actions/cache step.
#
# Everything is opt-out via NO_CACHE=1, so a job can force a from-scratch
# build (release verification) without editing this script.
# ---------------------------------------------------------------------------

set -euo pipefail

FLAVOR="${1:-nginx}"
VERSION="${2:-1.31.2}"
MODE="${3:-debug}"

case "$MODE" in
    debug|asan|module) ;;
    *)
        echo "unsupported mode: $MODE (want: debug|asan|module)" >&2
        exit 2
        ;;
esac

ROOT="${BUILD_ROOT:-$PWD/.build}"
MODULE_DIR="$PWD"

case "$FLAVOR" in
    nginx)
        URL="https://nginx.org/download/nginx-${VERSION}.tar.gz"
        DIR="nginx-${VERSION}"
        ;;
    angie)
        URL="https://download.angie.software/files/angie-${VERSION}.tar.gz"
        DIR="angie-${VERSION}"
        ;;
    *)
        echo "unsupported flavor: $FLAVOR" >&2
        exit 2
        ;;
esac

NO_CACHE="${NO_CACHE:-0}"

# --- integrity: pinned SHA-256 for nginx tarballs we've actually verified ---
# nginx.org serves plain HTTP-adjacent PGP signatures, not a sha256sum file, so
# "verify against the vendor" means pinning a known-good digest for each source
# tarball we build, computed once from a tarball fetched over HTTPS from
# nginx.org and recorded here -- not fabricated. A version not in this table
# builds anyway (this skeleton tracks a moving nginx release, and refusing to
# build an unpinned version would break every future version bump until someone
# updates this table first) but prints a loud warning instead of silently
# skipping verification, so the gap is visible rather than assumed-safe.
declare -A NGINX_SHA256=(
    ["1.31.1"]="9fcaaeb8f22544b09a19a761f3412c4112215422401634bebdd1296a403cc4bc"
    ["1.31.2"]="af2a957c41da636ddc4f883e4523c6d140b4784dbce42000c364ae5092aa473c"
    ["1.30.3"]="e5823dc6f45610993def93ebf6cfce68264af4958c77e874b7d20f3709001b8f"
)

# Same idea as NGINX_SHA256, for the angie flavor.
declare -A ANGIE_SHA256=(
    ["1.12.0"]="cd7867d200b22a80165b93696c30a1ac3a28c1162544b7f43c71232b19814ef6"
)

# The mode is in the tree path. See the CACHING block above -- sharing one tree
# across modes is what lets a cached debug objs/ silently disarm the asan job.
SRCDIR="$ROOT/${DIR}-${MODE}"

mkdir -p "$ROOT"
if [ ! -f "$ROOT/${DIR}.tar.gz" ]; then
    curl -fsSL "$URL" -o "$ROOT/${DIR}.tar.gz"

    # A fresh download is the only time a bad tarball can enter the cache, so
    # this is where verification belongs -- a tarball already sitting in
    # .build/ from a prior verified run doesn't need re-checking every
    # invocation. Pinned digests are computed once from an HTTPS fetch and
    # recorded in NGINX_SHA256/ANGIE_SHA256 above; this is a stopgap for
    # nginx.org's plain HTTP-adjacent PGP signatures (not a sha256sum file) --
    # see https://nginx.org/en/pgp_keys.html for the upstream-recommended
    # `gpg --verify` method against nginx's published release-signing keys.
    case "$FLAVOR" in
        nginx) EXPECTED="${NGINX_SHA256[$VERSION]:-}" ;;
        angie) EXPECTED="${ANGIE_SHA256[$VERSION]:-}" ;;
    esac
    if [ -n "$EXPECTED" ]; then
        ACTUAL="$(sha256sum "$ROOT/${DIR}.tar.gz" | awk '{print $1}')"
        if [ "$ACTUAL" != "$EXPECTED" ]; then
            echo "FATAL: sha256 mismatch for ${DIR}.tar.gz" >&2
            echo "  expected: $EXPECTED" >&2
            echo "  actual:   $ACTUAL" >&2
            rm -f "$ROOT/${DIR}.tar.gz"
            exit 1
        fi
        echo "sha256: OK ($VERSION)"
    else
        echo "WARNING: no pinned sha256 for $FLAVOR $VERSION -- add one to" \
             "${FLAVOR^^}_SHA256 in tools/ci-build.sh (downloaded tarball is" \
             "UNVERIFIED)" >&2
    fi
fi
if [ "$NO_CACHE" = "1" ]; then
    rm -rf "$SRCDIR"
fi
if [ ! -d "$SRCDIR" ]; then
    tar -xzf "$ROOT/${DIR}.tar.gz" -C "$ROOT"
    mv "$ROOT/$DIR" "$SRCDIR"
fi

# Strict flags: this is hostile-input parser code, so warnings are errors.
CC_OPT="-g -Wall -Wextra -Wshadow"
LD_OPT=""
ADD_MODULE="--add-dynamic-module=$MODULE_DIR"

if [ "$MODE" = "asan" ]; then
    SAN="-fsanitize=address,undefined -fno-sanitize-recover=undefined"
    SAN="$SAN -fno-omit-frame-pointer -g -O1"
    if "${CC:-cc}" --version 2>/dev/null | grep -qi clang; then
        # The nginx core trips a few benign UBSan sub-checks; silence only those.
        SAN="$SAN -fno-sanitize=function,nonnull-attribute,pointer-overflow"
    fi
    CC_OPT="$SAN -Wall"
    LD_OPT="$SAN"
    ADD_MODULE="--add-module=$MODULE_DIR"
fi

# --- ccache -------------------------------------------------------------
# nginx's configure IGNORES a bare `CC=` env var, so the usual `CC="ccache cc"`
# trick silently does nothing here -- it must go through --with-cc. That is the
# difference between a warm cache and a cache that never gets a single hit.
BASE_CC="${CC:-cc}"
WITH_CC="$BASE_CC"
if [ "$NO_CACHE" != "1" ] && command -v ccache >/dev/null 2>&1; then
    WITH_CC="ccache $BASE_CC"
    # Compiler identity is content-hashed, so a toolchain bump invalidates
    # correctly on its own; no manual key bumping needed.
    export CCACHE_DIR="${CCACHE_DIR:-$HOME/.cache/ccache}"
    export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-2G}"
    # Sanitizer flags are part of the hash, so an asan object can never be
    # served to a debug build (or vice versa) -- belt and braces alongside
    # the per-mode tree.
    export CCACHE_COMPILERCHECK=content
    ccache --set-config=max_size="$CCACHE_MAXSIZE" 2>/dev/null || true
fi

# --- mold ---------------------------------------------------------------
# Link time is a rounding error on a module this small, but a real module with
# a heavy scan core links a much bigger .so -- and this template exists to be
# cloned. Skipped under asan: the sanitizer runtimes want the default linker.
if [ "$NO_CACHE" != "1" ] && [ "$MODE" != "asan" ] \
   && command -v mold >/dev/null 2>&1; then
    LD_OPT="$LD_OPT -fuse-ld=mold"
fi

cd "$SRCDIR"

# --- configure skip -----------------------------------------------------
# configure is ~5s of SERIAL shell -- on this codebase it costs more than the
# compile it precedes, and ccache cannot touch it. Skip it when the resulting
# objs/Makefile was produced by an identical invocation. Keying on the exact
# argv (not just the version) is what makes this safe: change a flag, change
# the stamp, get a reconfigure.
CONF_ARGS="--with-compat --with-cc=${WITH_CC} --with-cc-opt=${CC_OPT} --with-ld-opt=${LD_OPT} ${ADD_MODULE}"
STAMP="objs/.conf-stamp"

if [ "$NO_CACHE" != "1" ] && [ -f objs/Makefile ] && [ -f "$STAMP" ] \
   && [ "$(cat "$STAMP")" = "$CONF_ARGS" ]; then
    echo "configure: cached (identical flags) -- skipping"
else
    ./configure \
        --with-compat \
        --with-cc="$WITH_CC" \
        --with-cc-opt="$CC_OPT" \
        --with-ld-opt="$LD_OPT" \
        "$ADD_MODULE"
    printf '%s' "$CONF_ARGS" > "$STAMP"
fi

case "$MODE" in
    asan)
        make -j"$(nproc)"
        echo "built: $SRCDIR/objs/nginx"
        ;;
    module)
        # Only the .so -- deliberately no full `make`, so the nginx core never
        # enters a traced CodeQL database.
        make -j"$(nproc)" modules
        echo "built: $SRCDIR/objs/ngx_http_skel_module.so"
        ;;
    *)
        make -j"$(nproc)" modules
        make -j"$(nproc)"
        echo "built: $SRCDIR/objs/nginx"
        ;;
esac

# A cache that silently stops hitting is worse than no cache: you keep paying
# for it (keys, restore steps, disk) and get nothing back. Print the hit rate
# so a regression is visible in the job log instead of invisible.
if [ "$NO_CACHE" != "1" ] && command -v ccache >/dev/null 2>&1; then
    echo "--- ccache"
    ccache --show-stats 2>/dev/null \
        | grep -Ei 'hits|misses|cache size' || true
fi
