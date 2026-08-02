#!/bin/sh
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
#
# ci/tools/ci-hang-guard.sh -- run a command under a soft watchdog that captures
# evidence BEFORE the job timeout kills the runner with none.
#
#   ci/tools/ci-hang-guard.sh <soft_timeout_s> <artifact_dir> -- <cmd...>
#
# On timeout it writes, into <artifact_dir>:
#   cmd.log              the wrapped command's own output
#   backtrace-<pid>.txt  a gdb all-thread backtrace per hung process
#   ps.txt               the process tree at the moment of the timeout
#   watchdog.log         the watchdog's own diagnostics, replayed on stderr
#   watchdog.fired       empty marker; its presence is what makes this exit 124
# ...then kills the tree and exits 124, the same status timeout(1) uses.
#
# NO nginx-debug-<pid>.txt, and deliberately not: this header used to promise
# one and capture_one() used to `kill -ABRT` every nginx in the tree to get it.
# That did two wrong things and one useful one, which was none of them. nginx
# installs handlers for HUP/USR1/USR2/WINCH/TERM/QUIT/ALRM/INT/IO/CHLD and
# ignores SYS/PIPE -- there is no SIGABRT entry in its signal table -- so ABRT
# took the DEFAULT action and simply terminated the worker. It produced no dump
# to collect, and it did so on the line before gdb attached, so the backtrace
# this tool exists to capture was taken against a process that had just been
# killed by the capture itself. The debug report nginx can write comes from
# `debug_points abort` in a debug build calling abort() at its own check
# points; it is not reachable by signalling a stock binary from outside, and it
# lands in that instance's error_log, whose path a generic wrapper does not
# know (it is prefix-relative when unset). If a future fixture wants it, the
# fixture -- which owns the prefix -- should collect its own error_log into
# <artifact_dir>.
#
# WHY. A job-level `timeout-minutes:` produces exactly one artifact: the word
# "cancelled". Every intermittent wedge in this class -- an event loop that
# stops progressing, a fixture waiting on a socket nobody will write to, a
# deadlock between two workers -- is unreproducible locally by definition (it
# is the CI box's timing that provokes it), so the ONE run where it happens is
# the only chance to see a stack. Without this wrapper that chance is spent.
#
# SCOPE, and why it matters more here than it looks: the process scan is
# restricted to the tree rooted at the wrapped command. The build host runs six
# ephemeral CI slots at once, so a scan by process NAME would attach gdb to a
# NEIGHBOURING job's nginx and publish its backtrace and its config paths into
# this job's artifact -- an information leak between unrelated runs (CWE-200),
# on top of being useless evidence. Never widen this to a pgrep by name.
#
# Related trap, same reasoning: never pkill/killall from CI on this host. A
# pattern kill here has taken out live neighbouring jobs before.
#
# Exit: the wrapped command's status, or 124 if the watchdog fired.
#
# Limits: gdb attach needs ptrace permission. On a host with
# kernel.yama.ptrace_scope=1 a same-uid attach is refused, so this tries sudo
# first (passwordless on the runners) and falls back to a bare gdb. If BOTH
# fail the guard still writes ps.txt and cmd.log and still exits 124 -- a
# partial artifact beats none, and the missing backtrace is reported in the log
# rather than silently skipped.
#
# Extend: a new dump format goes in capture_one(); keep everything it writes
# inside <artifact_dir> so one upload-artifact step collects it all.

set -eu

SOFT="${1:?usage: ci-hang-guard.sh <soft_timeout_s> <artifact_dir> -- <cmd...>}"
shift
ARTDIR="${1:?missing artifact dir}"
shift
[ "${1:-}" = "--" ] && shift
[ "$#" -gt 0 ] || { echo "ci-hang-guard: no command given" >&2; exit 2; }

mkdir -p "$ARTDIR"
ARTDIR="$(cd "$ARTDIR" && pwd)"

# A caller may reuse one artifact dir across several wrapped commands. A marker
# left by an EARLIER command would then make the next one -- which exited fine
# -- report 124 and replay someone else's backtrace. Clear it up front so the
# marker only ever describes this run.
rm -f "$ARTDIR/watchdog.fired"

GDB="gdb"
if ! gdb --version >/dev/null 2>&1; then
    GDB=""
fi

capture_one() {
    pid="$1"
    [ -d "/proc/$pid" ] || return 0

    # Nothing is signalled before the backtrace. The hung process must be left
    # exactly as it was found: it IS the evidence, and any signal that the
    # target does not explicitly handle terminates it (see the header on the
    # SIGABRT this used to send). Killing happens after every capture, in the
    # sweep at the bottom.
    [ -n "$GDB" ] || return 0
    out="$ARTDIR/backtrace-$pid.txt"
    if sudo -n true 2>/dev/null; then
        # SC2024: the redirect is intentionally performed by the UNPRIVILEGED
        # shell, not by sudo. Only the ptrace attach needs root; writing the
        # artifact as root would leave a file the upload step cannot read on a
        # runner whose workspace it does not own.
        # shellcheck disable=SC2024
        sudo "$GDB" -p "$pid" -batch \
            -ex 'thread apply all bt full' > "$out" 2>&1 || true
    else
        "$GDB" -p "$pid" -batch \
            -ex 'thread apply all bt full' > "$out" 2>&1 || true
    fi
    # An empty or permission-denied capture is reported, never left to be
    # mistaken for "no threads were running".
    if ! grep -q '#0' "$out" 2>/dev/null; then
        echo "ci-hang-guard: gdb produced no frames for pid $pid" >&2
        echo "  (kernel.yama.ptrace_scope? see the header)" >> "$out"
    fi
}

# Descendants of $1, deepest last. Walks /proc rather than using pgrep -P in a
# loop so the whole tree is collected in one pass, and so a process that exits
# mid-walk cannot abort the scan.
descendants() {
    root="$1"
    echo "$root"
    for p in /proc/[0-9]*; do
        pid="${p#/proc/}"
        [ -r "$p/stat" ] || continue
        # Field 4 of /proc/<pid>/stat is the ppid. comm (field 2) can contain
        # spaces and parentheses, so cut at the LAST ')' before splitting.
        ppid="$(sed 's/.*) //' "$p/stat" 2>/dev/null | cut -d' ' -f2)" || continue
        [ "$ppid" = "$root" ] || continue
        descendants "$pid"
    done
}

"$@" > "$ARTDIR/cmd.log" 2>&1 &
CMD_PID=$!

# The watchdog is a plain background sleep rather than a SIGALRM trap: POSIX sh
# has no reliable alarm, and a trap-based version silently does nothing under
# `set -e` when the sleep is interrupted.
(
    sleep "$SOFT"
    kill -0 "$CMD_PID" 2>/dev/null || exit 0
    echo "ci-hang-guard: no exit after ${SOFT}s -- capturing evidence" >&2
    # The marker is what the caller below tests, instead of inferring a
    # watchdog fire from exit status 137. The wrapped process is not always the
    # one that receives the KILL: a python or shell parent whose child was
    # killed exits 1 or 143, so the hang was reported as an ordinary test
    # failure and the backtrace this tool had just written was never mentioned.
    # (The converse -- a command OOM-killed on its own, exiting 137 with no
    # watchdog fire -- was already covered, since the old test also required
    # ps.txt to exist.) Written before any capture, so it exists even if gdb
    # dies or ptrace is refused.
    : > "$ARTDIR/watchdog.fired"
    ps -ef > "$ARTDIR/ps.txt" 2>&1 || true
    for pid in $(descendants "$CMD_PID"); do
        capture_one "$pid"
    done
    # Every capture is complete by here, so the tree is safe to kill. The
    # descendants list is re-walked rather than reused: gdb attaching and
    # detaching can change what is alive, and a stale list would leave a
    # process behind holding the runner's workspace open.
    for pid in $(descendants "$CMD_PID"); do
        kill -KILL "$pid" 2>/dev/null || true
    done
# BOTH streams go to a FILE, never to the inherited ones.
#
# A background subshell inherits this script's stdout/stderr, which in practice
# is a PIPE (`ci-hang-guard.sh ... | tail`, a CI step's log collector). A reader
# sees EOF only when the LAST writer closes it -- and the watchdog's `sleep`
# child holds it open for the whole soft timeout, AFTER the wrapped command has
# already exited. The wrapper then turns a 7-second command into a 300-second
# step that looks exactly like the hang it exists to diagnose.
#
# Measured while wiring this in: with the streams inherited, a command that
# prints and exits immediately took 20s through `| tail` against a 20s soft
# timeout; redirected, 0s. Closing the descriptors instead of redirecting fixes
# the same thing but throws the watchdog's own diagnostics away -- so they go to
# a file that is replayed below when it actually fired.
) > "$ARTDIR/watchdog.log" 2>&1 &
WATCHDOG_PID=$!

RC=0
wait "$CMD_PID" || RC=$?

# The watchdog must not outlive a command that finished in time, or the job
# hangs on the wait below for the remainder of the soft timeout.
kill "$WATCHDOG_PID" 2>/dev/null || true
wait "$WATCHDOG_PID" 2>/dev/null || true

cat "$ARTDIR/cmd.log"

# Report a watchdog fire as 124 (timeout(1)'s convention) so a reader does not
# mistake it for the OOM kill that is the other common source of 137 here. The
# test is the marker file the watchdog wrote, not the exit status: see the
# comment at the marker for the two ways reading 137 got this wrong.
if [ -f "$ARTDIR/watchdog.fired" ]; then
    cat "$ARTDIR/watchdog.log" >&2 2>/dev/null || true
    echo "ci-hang-guard: watchdog fired; artifacts in $ARTDIR" >&2
    exit 124
fi

exit "$RC"
