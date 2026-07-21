#!/usr/bin/env bash
#
# Sustained soak of the scan path under a sanitizer or valgrind.
#
# Fires a mixed storm of matching requests (must be blocked) and non-matching
# requests (must pass) at a `skel block` location, in both URI and body form,
# so the normalize + scan + body-buffering paths churn under concurrent,
# high-volume load. The Test::Nginx suite proves correctness once per case;
# this proves the same code stays clean under sustained load with no leak,
# OOB, or race.
#
# The assertion is meaningful on purpose: a green run must have seen at least
# one match BLOCKED and at least one non-matching request PASS. A soak that
# only asserts "the process did not crash" passes just as happily when the
# module was never actually reached -- which is how a soak silently rots into
# a no-op.
#
# Usage:
#   tools/soak.sh <nginx-binary> [duration_seconds] [concurrency]
#   USE_VALGRIND=1 tools/soak.sh <nginx-binary> 600 4
#   USE_HELGRIND=1 tools/soak.sh <nginx-binary> 600 4
#
# Build first -- ASan for the sanitizer path, plain debug for valgrind:
#   CC=clang bash tools/ci-build.sh nginx 1.31.2 asan
#   bash tools/ci-build.sh nginx 1.31.2 debug

set -euo pipefail

NGINX="${1:?usage: soak.sh <nginx-binary> [duration] [concurrency]}"
DURATION="${2:-120}"
CONC="${3:-4}"
PORT="${SOAK_PORT:-18254}"

command -v curl >/dev/null || { echo "soak: curl not found" >&2; exit 2; }

WORK="$(mktemp -d)"
mkdir -p "$WORK/conf" "$WORK/logs" "$WORK/html"
echo ok > "$WORK/html/ok"

NGINX_OBJS="$(cd "$(dirname "$NGINX")" && pwd)"
MODULE_SO="$NGINX_OBJS/ngx_http_skel_module.so"

# Dynamic build ships a .so to load; the asan build is static and must not.
if [ -f "$MODULE_SO" ]; then
    LOAD_MODULE="load_module $MODULE_SO;"
else
    LOAD_MODULE=""
fi

# empty_gif is a real content handler, so it reaches PRECONTENT where the module
# runs. `return 200` would finalize in REWRITE -- before PRECONTENT -- and the
# module would never see the request, making the whole soak vacuous.
# Body-case matches count as blocked on 403 (a passed-through POST is a 405 from
# empty_gif and is deliberately not counted; correctness of the pass-through is
# t/02-scan.t's job -- the soak only needs churn plus the two branch proofs).
cat > "$WORK/conf/nginx.conf" <<EOF
daemon off;
master_process off;
error_log $WORK/logs/error.log info;
pid $WORK/logs/nginx.pid;
$LOAD_MODULE

events { worker_connections 256; }

http {
    access_log off;

    server {
        listen 127.0.0.1:$PORT;

        location /t {
            skel block;
            skel_max_body 8k;
            empty_gif;
        }
    }
}
EOF

RUNNER=()
if [ "${USE_VALGRIND:-0}" = "1" ]; then
    RUNNER=(valgrind --tool=memcheck --leak-check=full --error-exitcode=99
            --suppressions="$(dirname "$0")/valgrind.supp")
elif [ "${USE_HELGRIND:-0}" = "1" ]; then
    RUNNER=(valgrind --tool=helgrind --error-exitcode=99
            --suppressions="$(dirname "$0")/valgrind.supp")
fi

"${RUNNER[@]}" "$NGINX" -p "$WORK" -c "$WORK/conf/nginx.conf" &
NGINX_PID=$!

cleanup() {
    kill "$NGINX_PID" 2>/dev/null || true
    wait "$NGINX_PID" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

# Wait for the listener. Valgrind starts slowly, so allow generous time.
for _ in $(seq 1 120); do
    if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/t?ping=1" 2>/dev/null; then
        break
    fi
    kill -0 "$NGINX_PID" 2>/dev/null || { echo "soak: nginx died on startup" >&2
                                          cat "$WORK/logs/error.log" >&2; exit 1; }
    sleep 0.5
done

MATCHING=(
    "/t?id=SKEL-MARKER"
    "/t?x=prefix-SKEL-MARKER-suffix"
    "/t?f=SkEl-MaRkEr"
    "/t?x=%53KEL-%4dARKER"
    "/t/SKEL-MARKER/more"
)
BENIGN=(
    "/t?page=2&sort=name"
    "/t?q=select+a+restaurant"
    "/t?path=/usr/share/doc"
    "/t?id=12345"
)

BLOCKED="$WORK/blocked"; PASSED="$WORK/passed"
: > "$BLOCKED"; : > "$PASSED"

storm() {
    local deadline=$(( $(date +%s) + DURATION ))
    local code
    while [ "$(date +%s)" -lt "$deadline" ]; do
        for a in "${MATCHING[@]}"; do
            code=$(curl -s -o /dev/null -w '%{http_code}' \
                   "http://127.0.0.1:$PORT$a" || echo 000)
            [ "$code" = "403" ] && echo x >> "$BLOCKED"

            # Same payload as a body.
            code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
                   --data-binary "payload=SKEL-MARKER" \
                   "http://127.0.0.1:$PORT/t" || echo 000)
            [ "$code" = "403" ] && echo x >> "$BLOCKED"
        done
        for b in "${BENIGN[@]}"; do
            code=$(curl -s -o /dev/null -w '%{http_code}' \
                   "http://127.0.0.1:$PORT$b" || echo 000)
            [ "$code" = "200" ] && echo x >> "$PASSED"
        done
    done
}

echo "soak: ${DURATION}s @ ${CONC} concurrent (runner: ${RUNNER[*]:-none})"

# Collect the storm PIDs explicitly and wait on exactly those. A bare `wait`
# would also block on $NGINX_PID, which only exits when we kill it below.
STORM_PIDS=()
for _ in $(seq 1 "$CONC"); do
    storm &
    STORM_PIDS+=("$!")
done
wait "${STORM_PIDS[@]}" 2>/dev/null || true

# Stop nginx cleanly so valgrind reports leaks at exit and sets the exit code.
kill -QUIT "$NGINX_PID" 2>/dev/null || true
set +e
wait "$NGINX_PID"
NGINX_RC=$?
set -e

n_blocked=$(wc -l < "$BLOCKED")
n_passed=$(wc -l < "$PASSED")
echo "soak: blocked=$n_blocked passed=$n_passed nginx_exit=$NGINX_RC"

if [ "$NGINX_RC" -eq 99 ]; then
    echo "FAIL: valgrind reported errors (exit 99)" >&2
    sed -n '1,200p' "$WORK/logs/error.log" >&2 || true
    exit 1
fi

# Any OTHER nonzero exit (a crash, e.g. 139 for SIGSEGV, or plain 1) used to
# slide through here as long as both counters were nonzero -- a worker that
# died mid-soak but still served enough requests to pass both checks above
# produced a deterministic false "OK". A clean `kill -QUIT` shutdown exits 0;
# anything else is a real failure and gets treated as one.
if [ "$NGINX_RC" -ne 0 ]; then
    echo "FAIL: nginx exited $NGINX_RC (expected 0 for a clean QUIT shutdown)" >&2
    sed -n '1,200p' "$WORK/logs/error.log" >&2 || true
    exit 1
fi

# The meaningful part: prove BOTH branches actually executed.
if [ "$n_blocked" -eq 0 ]; then
    echo "FAIL: no matching request was ever blocked -- the module did not run" >&2
    exit 1
fi
if [ "$n_passed" -eq 0 ]; then
    echo "FAIL: no benign request ever passed -- the module blocks everything" >&2
    exit 1
fi

# ASan/UBSan write here rather than to the exit code when nginx traps them.
if grep -qE 'runtime error|AddressSanitizer|LeakSanitizer' \
        "$WORK/logs/error.log" 2>/dev/null; then
    echo "FAIL: sanitizer diagnostics in the error log" >&2
    grep -nE 'runtime error|AddressSanitizer|LeakSanitizer' \
        "$WORK/logs/error.log" >&2
    exit 1
fi

echo "OK: soak clean"
