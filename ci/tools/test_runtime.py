#!/usr/bin/env python3
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
"""Runtime tests for the skeleton module: the cases Test::Nginx cannot express.

ci/t/*.t already covers the request path one request at a time. This driver
covers the three shapes that need a live server driven from outside the harness:

  R1  CONCURRENCY -- many simultaneous requests carrying the marker must ALL be
      blocked. The scan core keeps its streaming state in a caller-owned struct;
      a derived module that promotes it to a static or to a per-worker global
      passes every single-request test and fails here.
  R2  CHUNK SEAM, end to end -- the marker split across HTTP chunk boundaries
      must still be blocked. ci/tests/unit/ asserts the same property against
      the scan core directly; this asserts that the module's body handler
      actually feeds nginx's chain buffers through it with the carry intact,
      which the unit test cannot see.
  R3  RELOAD UNDER LOAD -- SIGHUP while requests are in flight must not drop a
      verdict. Configuration reload replaces the module's conf structs while old
      workers are still serving; a lifetime bug there is invisible to any test
      that reloads an idle server.

Every case asserts a STATUS THAT DIFFERS between the working and broken states.
A case whose broken state also returns 200 would be satisfied by a server that
never loaded the module at all, so the suite starts by proving the module is
loaded and blocking (`test_marker_is_blocked`) and every later case is read
against that baseline.

Usage:
    ci/tools/test_runtime.py --nginx .build/nginx-<v>-debug/objs/nginx \\
        --module .build/nginx-<v>-debug/objs/ngx_http_skel_module.so \\
        [--port 18880] [-k PATTERN] [-v]

--port is the BASE of a 64-wide band this run owns end to end. Today exactly one
CI job starts this driver (build-test.yml's Test::Nginx job, band 19200), so the
band is not yet load-bearing -- it is the SECOND job that makes it so, and that
is the point. builder02's workflows pin the same runner with disjoint
concurrency groups, so nothing serialises them: a second runtime job added later
without its own band would take this default, bind the same port as the first,
and produce two unrelated-looking reds from one cause. ci/linter/lint-ci-ports.sh
fails the build if such a job is ever added. See that script's header.

SEEN RED (2026-08-01, mutations applied to src/ and the module rebuilt):
  * `keep = 0` instead of the seam-carry clamp in ngx_http_skel_scan_piece()
      -> test_marker_split_across_chunks FAILS at the first interior split
         ("returned 405, want 403"), while the clean control stays green.

test_reload_under_load has NO cheap mutation control, and that is stated rather
than glossed: the defect it hunts is a conf-struct lifetime bug across SIGHUP,
which cannot be injected with a one-line edit the way the carry can. Treat it as
exercised, not as proven -- the distinction the repo's coverage note draws.

Exit: 0 all cases passed, 1 a case failed, 2 the fixture could not start.
"""

from __future__ import annotations

import argparse
import http.client
import os
import pathlib
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor

MARKER = "skel-marker"
BLOCKED = 403
ALLOWED = 200
# What a NOT-blocked POST looks like here. empty_gif is the content handler in
# the test config and it answers 405 to a POST -- so 405 is this suite's "the
# module let it through" for a body case, exactly as 200 is for a GET.
#
# It is deliberately NOT replaced with a `return 200` location: `return` is
# handled in the REWRITE phase, which runs BEFORE the PRECONTENT phase this
# module hooks, so a `return` location would answer before the module ever ran
# and every body case would pass vacuously. Same trap ci/t/01-modes.t documents.
ALLOWED_POST = 405

# How long to wait for the server to answer on its port before calling the
# fixture dead. Generous on purpose: this runs on a shared build host where a
# cold start competes with package builds. A tight bound here is the classic
# way a suite becomes "flaky" for reasons that have nothing to do with the code
# under test.
START_TIMEOUT_S = 30


class Failure(Exception):
    """A case's assertion did not hold."""


# --------------------------------------------------------------------------
# fixture


CONF = """\
daemon off;
master_process on;
worker_processes 2;
error_log {prefix}/error.log info;
pid {prefix}/nginx.pid;
load_module {module};

events {{
    worker_connections 64;
}}

http {{
    access_log off;
    client_body_buffer_size 1k;

    server {{
        listen {port};
        server_name localhost;

        location /scan {{
            skel block;
            skel_status 403;
            empty_gif;
        }}

        location /off {{
            skel off;
            empty_gif;
        }}
    }}
}}
"""


class Server:
    """One nginx process on a private prefix, owning one port."""

    def __init__(self, nginx: str, module: str, port: int) -> None:
        self.nginx = os.path.abspath(nginx)
        self.module = os.path.abspath(module)
        self.port = port
        self.prefix = pathlib.Path(tempfile.mkdtemp(prefix="skel-runtime-"))
        self.proc: subprocess.Popen[bytes] | None = None

    def start(self) -> None:
        (self.prefix / "logs").mkdir(exist_ok=True)
        conf = self.prefix / "nginx.conf"
        conf.write_text(
            CONF.format(prefix=self.prefix, module=self.module, port=self.port)
        )
        self.proc = subprocess.Popen(
            [self.nginx, "-p", str(self.prefix), "-c", str(conf)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + START_TIMEOUT_S
        while time.monotonic() < deadline:
            if self.proc.poll() is not None:
                raise SystemExit(
                    f"nginx exited during startup (rc={self.proc.returncode}); "
                    f"error log:\n{self.errors()}"
                )
            try:
                with socket.create_connection(("127.0.0.1", self.port), 0.5):
                    return
            except OSError:
                time.sleep(0.1)
        raise SystemExit(
            f"nginx did not listen on {self.port} within {START_TIMEOUT_S}s; "
            f"error log:\n{self.errors()}"
        )

    def errors(self) -> str:
        log = self.prefix / "error.log"
        return log.read_text() if log.exists() else "(no error.log)"

    def reload(self) -> None:
        """SIGHUP the master. Deliberately signals OUR OWN child only.

        Never pkill/killall here: this host runs self-hosted CI slots, and a
        pattern kill has taken out live neighbouring jobs before.
        """
        assert self.proc is not None
        self.proc.send_signal(signal.SIGHUP)

    def stop(self) -> None:
        if self.proc is not None and self.proc.poll() is None:
            self.proc.send_signal(signal.SIGQUIT)  # graceful: flushes gcov arcs
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        shutil.rmtree(self.prefix, ignore_errors=True)


# --------------------------------------------------------------------------
# request helpers


def get(port: int, path: str, timeout: float = 10.0) -> int:
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    try:
        conn.request("GET", path)
        return conn.getresponse().status
    finally:
        conn.close()


def post_chunked(
    port: int, path: str, chunks: list[bytes], timeout: float = 10.0
) -> int:
    """POST `chunks` as separate HTTP chunks, one write each.

    One write per chunk is the whole point: it is what makes nginx hand the
    module more than one buffer, which is the only way to exercise the
    cross-buffer carry from the outside. A single write of the joined bytes
    would arrive as one buffer and the case would pass on a module with no
    carry at all.
    """
    sock = socket.create_connection(("127.0.0.1", port), timeout)
    try:
        head = (
            f"POST {path} HTTP/1.1\r\n"
            "Host: localhost\r\n"
            "Transfer-Encoding: chunked\r\n"
            "Connection: close\r\n\r\n"
        ).encode()
        sock.sendall(head)
        for chunk in chunks:
            sock.sendall(b"%x\r\n%s\r\n" % (len(chunk), chunk))
            # A beat between writes so they land as distinct reads rather than
            # being coalesced by the kernel into one buffer.
            time.sleep(0.01)
        sock.sendall(b"0\r\n\r\n")

        data = b""
        while b"\r\n" not in data:
            more = sock.recv(4096)
            if not more:
                break
            data += more
        m = re.match(rb"HTTP/1\.[01] (\d{3})", data)
        if not m:
            raise Failure(f"no status line in response: {data[:200]!r}")
        return int(m.group(1))
    finally:
        sock.close()


# --------------------------------------------------------------------------
# cases


def test_marker_is_blocked(srv: Server) -> None:
    """Baseline. Every other case is read against this one.

    Without it, a suite where the module silently failed to load would report
    "nothing blocked" as a series of green allow-cases.
    """
    status = get(srv.port, f"/scan?q={MARKER}")
    if status != BLOCKED:
        raise Failure(
            f"marker request returned {status}, want {BLOCKED} -- the module "
            "is not blocking, so no later case in this file means anything"
        )


def test_clean_is_allowed(srv: Server) -> None:
    """The other direction: a matcher that blocks everything is not a matcher."""
    status = get(srv.port, "/scan?q=harmless")
    if status != ALLOWED:
        raise Failure(f"clean request returned {status}, want {ALLOWED}")


def test_off_mode_allows_the_marker(srv: Server) -> None:
    """`skel off` must really be off, in the same server as a blocking location."""
    status = get(srv.port, f"/off?q={MARKER}")
    if status != ALLOWED:
        raise Failure(f"off-mode marker returned {status}, want {ALLOWED}")


def test_concurrent_markers_all_blocked(srv: Server) -> None:
    """R1: 64 simultaneous marker requests, every one blocked.

    64, not 8: the failure this hunts (streaming state promoted out of the
    caller-owned struct) needs two requests to interleave inside one worker, and
    with 2 workers and a fast handler a small burst can serialise by accident.
    """
    n = 64
    with ThreadPoolExecutor(max_workers=n) as pool:
        results = list(pool.map(lambda _: get(srv.port, f"/scan?q={MARKER}"), range(n)))
    bad = [s for s in results if s != BLOCKED]
    if bad:
        raise Failure(
            f"{len(bad)}/{n} concurrent marker requests were NOT blocked "
            f"(statuses seen: {sorted(set(bad))})"
        )


def test_concurrent_clean_all_allowed(srv: Server) -> None:
    """The clean direction under the same concurrency.

    Paired with the case above on purpose: alone, "all 64 blocked" is also what
    a module that blocks unconditionally under load would produce.
    """
    n = 64
    with ThreadPoolExecutor(max_workers=n) as pool:
        results = list(pool.map(lambda i: get(srv.port, f"/scan?q=clean{i}"), range(n)))
    bad = [s for s in results if s != ALLOWED]
    if bad:
        raise Failure(
            f"{len(bad)}/{n} concurrent clean requests were blocked "
            f"(statuses seen: {sorted(set(bad))})"
        )


def test_marker_split_across_chunks(srv: Server) -> None:
    """R2: the marker split at every interior byte, one chunk per side.

    This is the unit suite's split-invariance property driven through the real
    body handler, so it also covers the plumbing between nginx's chain buffers
    and the scan core -- the part ci/tests/unit/ cannot reach.
    """
    body = f"pad {MARKER} pad".encode()
    for at in range(1, len(body)):
        status = post_chunked(srv.port, "/scan", [body[:at], body[at:]])
        if status != BLOCKED:
            raise Failure(
                f"marker split at byte {at} returned {status}, want {BLOCKED} "
                "-- the cross-buffer carry does not survive the body handler"
            )


def test_clean_body_split_across_chunks(srv: Server) -> None:
    """The clean control for the case above, split the same way."""
    body = b"pad harmless payload pad"
    for at in range(1, len(body)):
        status = post_chunked(srv.port, "/scan", [body[:at], body[at:]])
        if status != ALLOWED_POST:
            raise Failure(
                f"clean body split at byte {at} returned {status}, "
                f"want {ALLOWED_POST} -- a clean body must reach the content "
                "handler, not the module's refusal"
            )


def test_reload_under_load(srv: Server) -> None:
    """R3: SIGHUP with requests in flight; no verdict may change or be lost.

    The assertion is on the VERDICTS, not on "nginx survived": a reload that
    leaves an old worker serving with a freed conf struct usually keeps
    answering, it just stops blocking. So the marker stream must stay 403 for
    its whole duration, across the reload.
    """
    deadline = time.monotonic() + 5.0
    seen: list[int] = []

    def hammer() -> None:
        while time.monotonic() < deadline:
            seen.append(get(srv.port, f"/scan?q={MARKER}"))

    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(hammer) for _ in range(8)]
        time.sleep(1.0)
        srv.reload()
        time.sleep(1.0)
        srv.reload()
        for f in futures:
            f.result()

    if not seen:
        raise Failure("no requests completed during the reload window")
    bad = [s for s in seen if s != BLOCKED]
    if bad:
        raise Failure(
            f"{len(bad)}/{len(seen)} requests stopped being blocked across a "
            f"reload (statuses seen: {sorted(set(bad))})"
        )


CASES = [
    test_marker_is_blocked,
    test_clean_is_allowed,
    test_off_mode_allows_the_marker,
    test_concurrent_markers_all_blocked,
    test_concurrent_clean_all_allowed,
    test_marker_split_across_chunks,
    test_clean_body_split_across_chunks,
    test_reload_under_load,
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--nginx", required=True, help="path to the nginx binary")
    ap.add_argument("--module", required=True, help="path to the module .so")
    ap.add_argument(
        "--port",
        type=int,
        default=18880,
        help="base of this run's 64-wide port band (see the module docstring)",
    )
    ap.add_argument("-k", dest="pattern", help="run only cases matching this")
    ap.add_argument("-v", dest="verbose", action="store_true")
    args = ap.parse_args()

    cases = CASES
    if args.pattern:
        cases = [c for c in cases if args.pattern in c.__name__]
        # An empty selection is "could not run", never "clean" -- the same rule
        # ci/linter/run-all.sh enforces for LINT_ONLY, and for the same reason.
        if not cases:
            print(f"-k {args.pattern!r} matched no case; known:", file=sys.stderr)
            for c in CASES:
                print(f"  {c.__name__}", file=sys.stderr)
            return 2

    srv = Server(args.nginx, args.module, args.port)
    failures = 0
    # start() INSIDE the try. Both of its failure paths raise SystemExit, and
    # with the call outside this block neither one reached stop(): the nginx it
    # had already spawned kept running and its temp prefix was never removed.
    # On a persistent self-hosted runner that leaked process goes on holding
    # this job's port, so the NEXT run binds on top of a server from the last
    # one and tests the old module -- the failure ci/tools/max-port.sh exists
    # to catch, manufactured by the suite itself. stop() is null-safe and
    # idempotent, so covering the constructor costs nothing.
    try:
        srv.start()
        for case in cases:
            started = time.monotonic()
            try:
                case(srv)
            except Failure as exc:
                print(f"FAIL {case.__name__}: {exc}")
                failures += 1
            else:
                took = time.monotonic() - started
                print(f"ok   {case.__name__} ({took:.2f}s)")
        if failures:
            print("\n--- nginx error.log ---")
            print(srv.errors())
    finally:
        srv.stop()

    print(f"\n{len(cases)} case(s), {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
