#!/usr/bin/env python3
"""Remap a ruleset's required status check contexts after step 16.

Step 16 makes ci.yml the sole `pull_request:` entry point. GitHub then reports
every member's jobs as "<caller job name> / <job name>", so each BARE context a
ruleset requires ("Validation", "CodeQL", ...) becomes unsatisfiable: no check
run will ever report under that name again and the PR can never merge. The
symptom is a permanently pending required check, which is indistinguishable
from a queued one.

This maps each existing context to its prefixed form. It adds no gate and
removes none -- same count, same jobs, only the reporting names change. Making
a previously-optional check required is a separate decision for a human, not a
side effect of a rename, so an unmapped context is a hard error rather than a
guess.

The caller-job -> called-workflow mapping is derived from ci.yml, not from a
hand-written table: for each job with a `uses:` pointing at a local workflow,
the prefix is that job's `name:` if it sets one, else the CALLED workflow's own
top-level `name:` (which is what GitHub uses when the caller job is unnamed --
the reference deliberately leaves them unnamed; see step 20).

Usage:
    ci/tools/remap-checks.py --repo owner/name --ruleset <id> [--apply]

Without --apply it prints the remap and writes nothing (default: dry run).
A rollback copy of the original ruleset is always written next to the output.
"""

import argparse
import json
import pathlib
import subprocess
import sys

import yaml


def gh(*args, check=True):
    r = subprocess.run(["gh", *args], capture_output=True, text=True, check=False)
    if check and r.returncode != 0:
        sys.exit(f"gh {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


def called_workflows(wf_dir):
    """job name prefix -> set of job names that workflow defines."""
    ci = wf_dir / "ci.yml"
    if not ci.is_file():
        sys.exit(f"{ci} not found -- run this from the repo root after step 15")
    doc = yaml.safe_load(ci.read_text()) or {}
    prefixes = {}
    for job_id, job in (doc.get("jobs") or {}).items():
        uses = job.get("uses")
        if not isinstance(uses, str) or not uses.startswith("./"):
            continue
        member = pathlib.Path(uses.split("@")[0])
        member_doc = yaml.safe_load((wf_dir.parent.parent / member).read_text()) or {}
        # GitHub uses the caller job's `name:` when set, else the called
        # workflow's own top-level `name:`, else the caller's job id.
        prefix = job.get("name") or member_doc.get("name") or job_id
        for inner_id, inner in (member_doc.get("jobs") or {}).items():
            prefixes.setdefault(inner.get("name") or inner_id, prefix)
    return prefixes


def resolve(ctx, prefixes):
    """Find the caller prefix for one bare context.

    Exact match first. Failing that, a matrix job's `name:` is a template
    (`Build (${{ matrix.flavor }})`) that no static read can render, so the
    reported context cannot be matched literally; fall back to the longest
    declared name whose non-template leading text the context starts with.
    """
    if ctx in prefixes:
        return prefixes[ctx]
    best = None
    for name, prefix in prefixes.items():
        head = name.split("${{")[0].rstrip()
        if (
            "${{" in name
            and head
            and ctx.startswith(head)
            and (best is None or len(head) > best[0])
        ):
            best = (len(head), prefix, name)
    if best:
        print(f"    (matched {ctx!r} to template job {best[2]!r})")
        return best[1]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, metavar="owner/name")
    ap.add_argument("--ruleset", required=True, metavar="id")
    ap.add_argument("--workflows", default=".github/workflows", type=pathlib.Path)
    ap.add_argument("--out-dir", default=".", type=pathlib.Path)
    ap.add_argument(
        "--apply",
        action="store_true",
        help="PUT the remapped ruleset back (default: dry run)",
    )
    args = ap.parse_args()

    path = f"repos/{args.repo}/rulesets/{args.ruleset}"
    d = json.loads(gh("api", path))

    rollback = args.out_dir / f"ruleset-{args.ruleset}-before-remap.json"
    rollback.write_text(json.dumps(d, indent=2))
    print(f"rollback copy: {rollback}")

    prefixes = called_workflows(args.workflows)

    changed = 0
    for rule in d.get("rules", []):
        if rule["type"] != "required_status_checks":
            continue
        checks = rule["parameters"]["required_status_checks"]
        new = []
        for c in checks:
            ctx = c["context"]
            if " / " in ctx:
                print(f"  = {ctx}   (already prefixed)")
                new.append(c)
                continue
            prefix = resolve(ctx, prefixes)
            if prefix is None:
                sys.exit(
                    f"unmapped context {ctx!r}: no job of that name is reachable "
                    f"from ci.yml. Either the job was renamed (fix the name) or "
                    f"the check is not a ci.yml member (decide by hand)."
                )
            newctx = f"{prefix} / {ctx}"
            print(f"  + {ctx}  ->  {newctx}")
            new.append(dict(c, context=newctx))
            changed += 1
        assert len(new) == len(checks), "gate count changed"
        rule["parameters"]["required_status_checks"] = new

    print(f"\n{changed} context(s) need remapping")
    if not changed:
        return
    body = {
        k: d[k]
        for k in ("name", "target", "enforcement", "conditions", "rules")
        if k in d
    }
    body["bypass_actors"] = d.get("bypass_actors", [])

    out = args.out_dir / f"ruleset-{args.ruleset}-remapped.json"
    out.write_text(json.dumps(body, indent=2))
    print(f"wrote {out}")

    if not args.apply:
        print("dry run -- re-run with --apply to PUT it back")
        return
    gh("api", "-X", "PUT", path, "--input", str(out))
    print("applied")


if __name__ == "__main__":
    main()
