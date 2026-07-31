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
MODE="${3:-debug}"

# Version pins (and their sha256s) all come from .github/versions.env -- see
# the integrity block below. Sourced this early so the default version tracks
# the pinned one instead of being a literal that silently rots.
VERSIONS_FILE="${VERSIONS_FILE:-$PWD/.github/versions.env}"
if [ ! -f "$VERSIONS_FILE" ]; then
    echo "FATAL: $VERSIONS_FILE not found (run from the module root)" >&2
    exit 1
fi
# Validate before sourcing. load-versions.sh applies the same KEY=value check
# on the CI side, but this script `source`s the file directly -- so without a
# check here, a stray line that is not a pin would be executed as shell rather
# than rejected. Same rule enforced in both consumers.
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|\#*) continue ;;
    esac
    if ! printf '%s' "$line" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*=[A-Za-z0-9._-]*$'; then
        echo "FATAL: malformed line in $VERSIONS_FILE: $line" >&2
        exit 1
    fi
done < "$VERSIONS_FILE"
# shellcheck source=/dev/null
. "$VERSIONS_FILE"

case "$FLAVOR" in
    nginx) DEFAULT_VERSION="${NGINX_VERSION:-}" ;;
    angie) DEFAULT_VERSION="${ANGIE_VERSION:-}" ;;
    *)     DEFAULT_VERSION="" ;;
esac
VERSION="${2:-$DEFAULT_VERSION}"

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

# --- integrity: sha256 pins come from .github/versions.env -------------------
# nginx.org serves plain HTTP-adjacent PGP signatures, not a sha256sum file, so
# "verify against the vendor" means pinning a known-good digest for each source
# tarball we build. Those digests used to live in a table right here, which put
# the version (in seven workflow files) and its digest (here) in different
# places under different writers -- so a bumped version with a stale digest was
# a live failure mode. Both now live on adjacent lines in .github/versions.env,
# written by one tool (.github/scripts/compute-versions.sh).
#
# Verification is MANDATORY: a version with no digest here is a hard failure,
# not a warning. compute-versions.sh always emits version+digest together, so
# the only way to reach this error is a hand-edit that half-did the job.
#
# (versions.env was already sourced near the top, to default $VERSION.)
#
# Pick the digest matching the flavor+version being built. The single-version
# jobs all build NGINX_VERSION; ci-deep's matrix also builds NGINX_STABLE and
# ANGIE_VERSION. Anything else has no pin and must not be built silently.
EXPECTED=""
if [ -z "$VERSION" ]; then
    # Guard before the case below: an empty $VERSION would match an empty
    # "${NGINX_STABLE:-}" pattern and silently adopt the wrong digest.
    echo "FATAL: no version given and no default pin for flavor '$FLAVOR'" >&2
    exit 1
fi
case "$FLAVOR" in
    nginx)
        case "$VERSION" in
            "${NGINX_VERSION:-}")  EXPECTED="${NGINX_VERSION_SHA256:-}" ;;
            "${NGINX_MAINLINE:-}") EXPECTED="${NGINX_MAINLINE_SHA256:-}" ;;
            "${NGINX_STABLE:-}")   EXPECTED="${NGINX_STABLE_SHA256:-}" ;;
        esac
        ;;
    angie)
        case "$VERSION" in
            "${ANGIE_VERSION:-}") EXPECTED="${ANGIE_SHA256:-}" ;;
        esac
        ;;
esac

if [ -z "$EXPECTED" ]; then
    echo "FATAL: no pinned sha256 for $FLAVOR $VERSION" >&2
    echo "  $VERSIONS_FILE pins:" >&2
    echo "    nginx  ${NGINX_VERSION:-?} (mainline ${NGINX_MAINLINE:-?}, stable ${NGINX_STABLE:-?})" >&2
    echo "    angie  ${ANGIE_VERSION:-?}" >&2
    echo "  Regenerate it with .github/scripts/compute-versions.sh, or add the" >&2
    echo "  version + its sha256 there -- never build an unverified tarball." >&2
    exit 1
fi

# The mode is in the tree path. See the CACHING block above -- sharing one tree
# across modes is what lets a cached debug objs/ silently disarm the asan job.
SRCDIR="$ROOT/${DIR}-${MODE}"

mkdir -p "$ROOT"
# fetch-verify.sh downloads (with retries/timeouts) and checks the digest. It
# re-checks a tarball already present in .build/ rather than trusting it, so a
# poisoned build cache is caught too -- and deletes nothing it did not verify.
if ! bash "$MODULE_DIR/.github/scripts/fetch-verify.sh" \
        "$URL" "$EXPECTED" "$ROOT/${DIR}.tar.gz"; then
    # A tarball that fails verification must not survive to be picked up as a
    # "cache hit" by the next run.
    rm -f "$ROOT/${DIR}.tar.gz"
    exit 1
fi
if [ "$NO_CACHE" = "1" ]; then
    rm -rf "$SRCDIR"
fi
if [ ! -d "$SRCDIR" ]; then
    tar -xzf "$ROOT/${DIR}.tar.gz" -C "$ROOT"
    mv "$ROOT/$DIR" "$SRCDIR"
fi

# Whole-tree flags: --with-cc-opt lands in CFLAGS for EVERY object configure
# compiles -- the upstream core included, not just our module. So only warnings
# that upstream is expected to be clean under belong here.
#
# -Wshadow deliberately does NOT: angie's configure puts -Werror in its own
# default CFLAGS, so -Wshadow here turns shadow warnings in ANGIE's sources
# (ngx_http_client_module.c, ngx_http_prometheus_module.c) into hard build
# failures in code we neither own nor patch. Our own sources ARE kept clean
# under -Wshadow -Werror by the "Strict module compile" step in build-test.yml,
# which applies the full strict set to src/*.c alone -- that is the right place
# for it, and the reason this list is the laxer one.
CC_OPT="-g -Wall -Wextra"
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
