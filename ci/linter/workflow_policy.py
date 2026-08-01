#!/usr/bin/env python3
# Copyright (C) 2026 Thijs Eilander
# SPDX-License-Identifier: BSD-2-Clause
"""Repo-policy checks over .github/workflows/ that no off-the-shelf linter makes.

    ci/linter/workflow_policy.py runners     runner trust boundary
    ci/linter/workflow_policy.py ports       per-job test port bands
    ci/linter/workflow_policy.py docs        README <-> workflows drift

Each subcommand is wrapped by a ci/linter/lint-*.sh so run-all.sh picks it up by
glob and a human can select it with LINT_ONLY. Exit: 0 clean, 1 findings,
2 could not run.

WHY THESE ARE NOT actionlint OR zizmor RULES. Both of those read a workflow
against GENERAL knowledge -- syntax, and a catalogue of known attack shapes.
The three checks here encode facts about THIS repo that no general tool can
know: which self-hosted labels exist, that the runners are persistent and
shared with package builds, which port band each job owns, and which files
document the pipeline. They are the checks that go red when a NEW workflow is
added without the property every existing one happens to have -- the case where
copying an existing file is the only thing standing between the repo and a
regression, and nothing enforces the copy.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"

# The approved runner selectors. Both keep FORK pull requests on a
# GitHub-hosted runner and everything else on the self-hosted pool.
#
# Why the split matters here specifically: a `pull_request`-triggered job checks
# out and EXECUTES scripts from the PR head. builder02's runners are persistent
# and shared with the Debian package builds, so running a fork's code on them is
# arbitrary code execution on the build host, with whatever the previous job
# left behind still on disk. The hosted arm is what makes this repo safe to
# accept outside contributions to -- which a public template repo exists to do.
#
# Add a form here ONLY if it preserves fork -> hosted / trusted -> self-hosted.
# Widening the self-hosted label set inside the second arm is fine (it only
# changes WHICH slots are eligible); moving the fork arm is not.
TRUST_SPLITS = frozenset(
    {
        "${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || "
        'fromJSON(\'["self-hosted","builder02","lxc"]\') }}',
        "${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || "
        'fromJSON(\'["self-hosted","builder02"]\') }}',
        "${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || "
        'fromJSON(\'["self-hosted","builder02","docker"]\') }}',
    }
)

HOSTED = re.compile(r"ubuntu-(?:latest|[0-9]+\.[0-9]+)")

# The runtime driver. A job that starts it is a "runtime-bearing" job and owes
# the port-band declaration checked below.
RUNTIME_DRIVER = "ci/tools/test_runtime.py"


def workflows() -> list[pathlib.Path]:
    return sorted(WORKFLOWS.glob("*.yml"))


def report(name: str, errors: list[str], ok_msg: str) -> int:
    if errors:
        print(f"{name}: {len(errors)} finding(s)", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1
    print(f"{name}: {ok_msg}")
    return 0


# --------------------------------------------------------------------------
# runners


def check_runners() -> int:
    errors: list[str] = []
    for path in workflows():
        text = path.read_text(encoding="utf-8")

        # pull_request_target runs with the BASE repo's secrets against the
        # HEAD's code. There is no configuration of it that is safe here, so it
        # is refused outright rather than conditioned.
        if re.search(r"(?m)^\s{2}pull_request_target\s*:", text):
            errors.append(f"{path.name}: pull_request_target is forbidden")

        # PR-REACHABLE, not just pull_request-triggered. Every heavy workflow in
        # this repo is `workflow_call`-only and reached from ci.yml, whose sole
        # trigger IS pull_request -- and a called workflow inherits the caller's
        # event payload, so `github.event.pull_request.head.repo.fork` is
        # populated inside it. A check that only looked for a literal
        # `pull_request:` trigger would therefore pass every single one of them
        # while checking nothing, which is precisely the vacuous-gate shape this
        # repo keeps re-learning.
        reachable = re.search(r"(?m)^\s{2}(pull_request|workflow_call)\s*:", text)
        if not reachable:
            continue

        runners = re.findall(r"(?m)^\s+runs-on:\s*(.+?)\s*$", text)
        if not runners:
            errors.append(f"{path.name}: PR-reachable workflow declares no runner")
            continue
        for runner in runners:
            if runner in TRUST_SPLITS or HOSTED.fullmatch(runner):
                continue
            errors.append(
                f"{path.name}: PR-reachable job has runs-on: {runner} -- must be "
                "GitHub-hosted or an approved fork-aware trust split "
                "(see TRUST_SPLITS in ci/linter/workflow_policy.py)"
            )
    return report(
        "lint-ci-runners",
        errors,
        "fork PRs stay on hosted runners; trusted events reach builder02",
    )


# --------------------------------------------------------------------------
# ports


def _jobs(text: str) -> list[tuple[str, str]]:
    """Split a workflow into (job-name, job-body) pairs.

    A regex split, not a YAML parse, and deliberately so: the body is needed
    verbatim (comments included) and job keys are always at exactly two spaces
    of indentation under `jobs:` in this repo's files. A YAML parse would also
    work, but it would make this checker depend on PyYAML being installed --
    and a checker that skips itself when a module is missing is the vacuous
    gate this file exists to prevent.
    """
    m = re.search(r"(?m)^jobs:\s*$", text)
    if not m:
        return []
    body = text[m.end() :]
    parts = re.split(r"(?m)^  (\w[\w-]*):\s*$", body)
    return list(zip(parts[1::2], parts[2::2]))


def check_ports() -> int:
    errors: list[str] = []
    bands: dict[str, str] = {}  # port value -> "file:job" that claimed it

    for path in workflows():
        text = path.read_text(encoding="utf-8")
        for job, body in _jobs(text):
            declared = re.search(r"(?m)^\s+TEST_BASE_PORT:\s*[\"']?(\d+)", body)
            starts_runtime = RUNTIME_DRIVER in body
            where = f"{path.name}:{job}"

            # THE CHECK THAT MATTERS MOST. A new runtime-bearing job added later
            # with no band is invisible to the uniqueness check below (it
            # declares nothing to collide), silently takes the driver's default
            # --port, and reintroduces exactly the cross-job collision the bands
            # exist to prevent: two jobs pinned to the same runner, disjoint
            # concurrency groups, nothing serialising them, both binding 18880.
            if starts_runtime and not declared:
                errors.append(
                    f"{where} starts {RUNTIME_DRIVER} without declaring "
                    "TEST_BASE_PORT -- it would take the driver's default port "
                    "and collide with any other runtime job on the same runner"
                )
                continue

            if not declared:
                continue

            port = declared.group(1)
            if port in bands:
                errors.append(
                    f"{where} and {bands[port]} both claim TEST_BASE_PORT "
                    f"{port} -- bands must be disjoint across ALL workflows"
                )
            else:
                bands[port] = where

            # A declared band that is not passed through is decoration: the
            # driver still binds its default.
            if starts_runtime and "--port" not in body:
                errors.append(
                    f"{where} declares TEST_BASE_PORT but never passes --port; "
                    "the driver would bind its default anyway"
                )
            if starts_runtime and "TEST_BASE_PORT" not in body.split("--port")[-1][:40]:
                errors.append(
                    f"{where} passes --port with something other than "
                    "$TEST_BASE_PORT -- the declaration and the bind must be "
                    "the same value or they drift"
                )

    return report(
        "lint-ci-ports",
        errors,
        f"{len(bands)} runtime job(s), all with distinct port bands"
        if bands
        else "no runtime-bearing jobs",
    )


# --------------------------------------------------------------------------
# docs


def check_docs() -> int:
    """Every workflow is documented, and every documented workflow exists.

    The drift this catches is silent in both directions and neither direction
    fails anything else: a workflow added without a README row is a gate nobody
    knows exists (so nobody notices when it is later removed), and a README row
    for a deleted workflow is a badge that 404s and a claim of coverage the repo
    does not have. Structural facts only -- deliberately NOT exact job counts or
    durations, which are the brittle claims that get a drift check deleted.
    """
    errors: list[str] = []
    readme = ROOT / "README.md"
    if not readme.is_file():
        print("lint-docs-drift: no README.md", file=sys.stderr)
        return 2
    text = readme.read_text(encoding="utf-8")

    names = {p.name for p in workflows()}
    for name in sorted(names):
        if name not in text:
            errors.append(
                f"{name} exists under .github/workflows/ but is not mentioned "
                "in README.md -- an undocumented gate"
            )
    # Only PATH-QUALIFIED references. A bare "ci.yml" in prose could mean any
    # file; ".github/workflows/ci.yml" is unambiguously a claim that this repo
    # has that workflow, which is the claim worth checking.
    for ref in sorted(set(re.findall(r"\.github/workflows/([\w.-]+\.yml)", text))):
        if ref not in names:
            errors.append(
                f"README.md references .github/workflows/{ref}, which does not "
                "exist -- a dead link or a stale badge"
            )
    return report(
        "lint-docs-drift",
        errors,
        f"{len(names)} workflow(s), all documented in README.md",
    )


COMMANDS = {
    "runners": check_runners,
    "ports": check_ports,
    "docs": check_docs,
}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in COMMANDS:
        print(f"usage: {argv[0]} {{{'|'.join(COMMANDS)}}}", file=sys.stderr)
        return 2
    if not WORKFLOWS.is_dir():
        print(f"no {WORKFLOWS} -- wrong tree?", file=sys.stderr)
        return 2
    return COMMANDS[argv[1]]()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
