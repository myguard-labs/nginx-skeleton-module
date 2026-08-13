# Prompt — adopt the myguard skeleton standard in an nginx module

Point a fresh session at this file and one module path:

```text
Read /opt/myguard/labs/nginx-skeleton-module/ci/PROMPT.md and apply it to
<TARGET>.
```

`<TARGET>` is any nginx module checkout — ours or someone else's, with existing CI
or none. Reference implementation is `/opt/myguard/labs/nginx-skeleton-module`
(this repo). Written for an agent with repo write access; reads as a checklist for
a human.

## Read only the phase you are on

This file is ~1000 lines. **Do not read it whole.** Front matter (through "Only
these are hard stops") is always loaded; everything after is addressed by phase:

```sh
ci/tools/prompt-section.sh 3          # phase 3 only
ci/tools/prompt-section.sh 3 --steps  # its step headings only
```

Each phase is delimited by `<!-- phase:N -->`. A rule that binds across phases is
repeated in each phase that needs it — **duplicate warnings are deliberate**, so a
worker reading one phase never misses a rule parked in another. Do not dedupe them.

## The job

Give the target the reference's **layout, gates, workflow set, badge row, linter
entry point and conventions**, expressed over the target's own code and tests.

**42 steps in 8 phases, landing through 3 PRs.** Steps are numbered 1–42
continuously and referenced by number. **A step is a unit of work, never a PR
boundary.**

| Phase | Steps | What it is | Lands in |
|---|---|---|---|
| 0 | — | already adopted? re-alignment triage | nothing (read-only) |
| 1 | 1–5 | preconditions, inventory, score, baseline | nothing (read-only) |
| 2 | 6–7 | toolchain: linters, configs, hook | PR1 |
| 3 | 8–12 | the decision seam, layout, `src/` | PR1 |
| 4 | 13–16 | runner identity, long-runner demotion, orchestrator | PR1 |
| 5 | 17–29 | workflows, tests, fuzzing, caching, linter retarget, lanes | PR2 |
| 6 | 30–35 | depth pass, close out, docs, report | PR3 |
| 7 | 36–42 | aftermath: reviews, soaks, scheduled lanes, residue, gitlink | PR3 |

**The three PRs.** Boundaries are fixed; do not split one and do not merge a
partial one.

| PR | Steps | What it is |
|---|---|---|
| PR1 | 6–16 | toolchain, seam, `ci/` layout, runner identity, demotion, orchestrator |
| PR2 | 17–29 | workflow set, badges, test layers + mutations, fuzz, coverage, caching, linter retarget, lanes |
| PR3 | 30–42 | depth pass, close out, docs, memory, aftermath, gitlink |
| REF | 33 | skeleton feedback PR — against the reference, not the target |
| PR4 | — | optional, at most one: cleanup falling out of PR1–PR3 |

Phase 6 opens only after PR2 merges: it asks whether the gates PR1 and PR2
installed would catch anything, and that question is meaningless against unmerged
work. Phase 7 always runs — after migration, forwarding, or a no-op. An
inapplicable aftermath step needs evidence; it is never skipped merely because no
full migration was required.

### Two barriers inside PR1

PR1 contains the only two irreversible moves. Both are **hard barriers inside the
branch** — later steps do not begin until the earlier evidence exists and is pasted
into the PR body.

1. **Step 13 (runner identity) completes before step 14.** Porting or demoting a
   workflow set before the `runs-on` question is settled means porting our pool
   into it.
2. **Step 15's double-run proof completes before step 16.** Step 16 removes
   `pull_request:` from every member and is the only action in the job that can
   leave the repo with no PR gate at all. Taken only on a run list showing **every**
   member running twice. No proof, no step 16 — accumulate the rest and record the
   block.

PR1 is one revert boundary, so a revert unwinds the seam extraction and the `ci/`
move too. Accepted cost, and the reason both barriers block rather than advise. If
the merged result gates nothing, revert PR1 whole and diagnose outside the default
branch.

### Model floor

Every step runs on **sonnet or stronger**; steps 39 and 40 are tagged `[opus]`. Do
not delegate any step to Haiku. The controller sends a worker only the execution
rules, current PR row, current step, target inventory, and prior result. The
controller, not the worker, owns the shared branch and PR.

Every run starts at phase 0. After triage, evaluate each PR's steps in numeric
order. Cross a PR off only when every step's Acceptance condition is proven against
the current tree; otherwise complete it through that one PR. **Never resume where
an earlier attempt claimed it stopped.**

**This is a merge, not an install.** Assume the target already has CI somebody
relies on. Measured across eight derived modules 2026-08-03: every one has three to
six workflows each carrying its own `pull_request:` trigger, not one has a
`ci.yml`, six have no `ci/`, two have no `src/`. An external adopter is likelier
still to have a suite predating any contact with this repo.

Three rules outrank every step:

1. **Adopt the convention, keep the content.** Layout, ordering, naming and entry
   points are the standard. The target's tests, thresholds, fuzz corpus, nginx
   compatibility range and linter selection are its own. A 1:1 copy is wrong by
   construction — the reference's tests test the reference's module.
2. **Never delete a gate the target already has.** Anything it checks that the
   reference does not survives, gets a badge and a table row, and goes back to the
   skeleton (step 33). A rollout that reduces coverage is a regression wearing a
   standardisation PR.
3. **Nothing self-hosted is portable.** `builder02` is a myguard machine and no
   linter here will tell an adopter they copied it — `TRUST_SPLITS` ships
   containing that label and **approves it by construction**, so a copied selector
   is green everywhere until it dispatches to hardware the target does not own, or
   queues forever against a label nobody answers. Step 2 records `POOL_OWNED`; step
   13 settles it before any workflow is ported or demoted. Default is hosted-only,
   and an unfamiliar `origin` is always hosted-only.

Standing constraints, all steps:

- **One branch and at most one target PR per group, never per step.** Start the
  branch at its first applicable step; accumulate steps as independently reviewable
  commits; open/update one PR; merge only when every applicable step is complete. A
  group with no tracked target change records evidence and opens no empty PR. Step
  33's reference PR and superrepo gitlink commits are the explicit cross-repo
  exceptions.
- **Remote CI green before merge**, workflows enabled — see step 2.
- **Every gate must be seen red once, in the target.** A probe against the
  reference is not evidence about the target: different paths, files, thresholds.
  Record the probe and its output in the PR body.
- **Never weaken a gate to make the target pass.** If it genuinely cannot meet a
  threshold, say so with the `file:line` that proves it and leave the gate at the
  honest value with a comment naming the reason.
- **Existing behaviour is not in scope.** You are moving CI, not rewriting the
  module. A real bug found on the way goes in `issues.md`; fix it only if it blocks
  the gate you came to install.
- Comments explain **why**, at the decision, in the target's voice.
- **Keep the todo list live** — one item `in_progress`, items closed on merge, not
  on push.

### The rejected-test list

Applies to every test written or ported in steps 21–26, and every mutation claim in
steps 22, 24, 30 and 41:

1. a test whose assertion holds in both pass and fail state (tell: a captured
   variable never compared)
2. a control that hardcodes the verdict instead of calling the real function
3. asserting a *precondition* rather than the claim
4. one shared counter asserted at N call sites — it pins none of them
5. a test written from the same misunderstanding as the code
6. excluding a hard file from the coverage config to lift the percentage
7. tests that execute lines without asserting on the result

Three ways a mutation pass fails while looking like success:

8. **the mutation survives** — the test guards nothing. That is the finding.
9. **the mutation does not cross the threshold** — clearing a counter below the
   level the code acts on proves nothing; mutate past the boundary the assertion
   names.
10. **a build-time guard masks it** — a `grep`-based build check rejecting the
    mutated source means the tests never ran against it. Confirm the mutated build
    compiled and executed.

### The green-that-proves-nothing classes

Most of this job targets checks that pass while checking nothing:

- **Empty selection.** No `src/` → `lint-c.sh`, `lint-nginx.sh`, the gcovr filter
  and the CodeQL TU filter all select nothing and *pass*. (step 12)
- **Wrong tree.** An unfiltered `gcovr` reports ~1% because nginx core swamps the
  module; a copied `valgrind.supp` suppresses the module's own errors; a copied
  CodeQL TU filter analyses nothing. (steps 27, 28, 30)
- **Unreached code.** An ASan soak against a default config where the handler never
  runs is clean forever. (steps 26, 30)
- **A copy instead of the real thing.** A unit test or fuzz target compiled against
  a reimplementation rather than the module's real decision TU is green and
  meaningless. (steps 8–10, 21, 25, 30)
- **Pointing at the wrong repo.** A copied badge row resolves against
  `myguard-labs/nginx-skeleton-module` and renders green while telling you nothing
  about the target. (step 20)
- **Called by nobody.** A member workflow `ci.yml` never calls keeps a stale-green
  badge and goes grey only when deleted. (steps 15, 30)
- **A checker turned no-op.** `LINT_ONLY` naming scripts that do not exist, a
  semgrep flag that silently disables it, a suppression outliving its cause. (steps
  28, 30)

## Work autonomously — record, do not ask

**Default to proceeding.** This job runs unattended. Almost everything that used to
be a stop is a recorded finding: write it down, degrade the affected step honestly,
carry on. A run that stops at step 3 with a question delivers nothing; a run that
finishes 40 of 42 steps and hands back a precise list of the 2 it could not do
delivers almost everything.

Two files carry what you cannot act on. Create both at the start of step 1:

- **`$SCRATCH/adoption-findings.md`** — anything about the TARGET you could not
  fix: red baseline tests, a gate that will not go green, a behavioural bug, a
  missing secret. At step 35 this merges into the target's `issues.md`.
- **`$SCRATCH/skeleton-findings.md`** — anything about the REFERENCE: a bug in a
  ported script, a rule that could not be followed as written, a gate the target
  has that the skeleton lacks (rule 2), a step here that was wrong or ambiguous.
  Step 33 turns this into a PR against the skeleton.

`$SCRATCH` is the session scratchpad, or `$(mktemp -d)`. One entry per finding:
what, the `file:line`, what you did instead, what a human has to decide. An empty
file at the end is a valid result; a finding you kept in your head is not.

### How to run the job — pace, scope, spend

Nine rules on *how* the run is conducted. They constrain execution, never step
content: none licenses skipping a step, weakening a gate, or inventing a shortcut a
step forbids.

- **Do not run the heavy tooling by hand.** Valgrind, sanitizers, fuzzers, the
  coverage run, the soaks — you *install and wire* them; CI runs them. The evidence
  a step wants is the run URL and its conclusion, not a local transcript costing an
  hour of wall-clock. **Do not start a long run at all if you can avoid it, and
  never block on one.** Step 14 demotes every long-runner off the PR lane in phase
  4 precisely so that nothing mid-run waits on one; they are exercised in phase 7.
  If one must be kicked off early, dispatch it and carry straight on — no poll
  loops, and a pending long lane never holds a step, branch or PR that is otherwise
  complete. The exception is a step naming a local invocation (a red-probe, a
  mutation pass) — short, targeted, named in the step.
- **Three PRs, and not more — plus at most one optional fourth.** PR1–PR3 as
  tabled, plus the reference PR at step 33. Do not split a PR whose branch grew
  large, and do not open one for a group with no tracked change. Cleanup falling
  out of the run goes into **one** optional PR4, opened only if there is real
  tracked work. Anything that does not fit is a finding and an `issues.md` row.
- **Verify every change you make by reading it back.** After each step touching C
  or a workflow, re-read the changed hunk and confirm the shape you intended is
  the shape that landed. A grep miss proves the spelling is absent, not that the
  change is right — so confirm on the POSITIVE match, never on a silent zero.
- **Run any linter you see fit, whenever you see fit.** Lint beyond what a step
  names — `actionlint`/`shellcheck` on a workflow or script you touched,
  `clang-tidy`/`cppcheck`/`gcc -fanalyzer` on C you changed, `yamllint`, a secret
  scan. No permission and no step number needed. Findings are treated like any
  other: fix if inside the step you are on, else a findings file. A lint hit is
  never a reason to widen the diff or weaken a gate. Missing tool → install it,
  then record it. "Linters clean" is only true for the lenses that ran; name the
  ones that did not.
- **Use tooling wherever possible.** Deterministic work goes to a tool; your tokens
  are for judgement. Prefer a command that computes the answer over reading the
  tree, a structural query over a hand scan, `gh --json`/`jq` over eyeballing a run
  page, a script over the same edit made three times. About to do a mechanical
  thing more than twice → write the one-liner. Verify a bulk edit with
  `git diff --stat` plus a spot check, never by trusting the loop that made it.
- **Do not ask questions you can answer.** Ambiguity is resolved by this prompt,
  the target's tree, its memory mirror, or the safe default (`POOL_OWNED=no`,
  hosted runner, gate left honest). Ask only when proceeding under any assumption
  would be unsafe or waste the whole run.
- **Be token-frugal and fast.** Read only the phase you are on. Compute answers
  with a command instead of reading a tree: `rg -c` before `rg -l` before `rg -n`,
  `awk`/`jq`/`gh --json` over eyeballing output, bounded output on every
  exploratory command. Read a whole file when you are about to change it.
- **Neither overachieve nor slack.** The deliverable is the 42 steps over the
  target's own content — not a rewrite of its module, not an extra gate nobody
  asked for. Equally: a step marked done on a plausible-looking edit with no
  Acceptance evidence is not done.
- **Follow the prompt; do not out-argue it.** Where a step names an order, a
  barrier, a threshold or a file, use it. If a step is wrong or impossible for this
  target, that is a `skeleton-findings.md` entry and a degraded step — not a
  freelance redesign.

**Close by checking the integration point for point.** When finished, do not
summarise from memory. Walk steps 1–42 in numeric order and, for each, state the
Acceptance condition and the evidence it holds in the *current* tree — file path,
run URL, probe output, or the finding saying why it is degraded. A step whose
evidence you cannot produce is not done, whatever a commit message claimed.

### Only these are hard stops

| Condition | Why it cannot be worked around |
|---|---|
| `<TARGET>` is not a git repository | nothing to branch, nothing to PR |
| No push access — `viewerPermission` not `ADMIN`/`MAINTAIN`/`WRITE` (step 1) | cannot land anything |
| A fix requires deleting or weakening an existing gate | rule 2 — a coverage regression, the opposite of the point |

Everything else: record and continue.

- **Dirty target tree** — do not stop, do not ask, do not `git stash`. Note the
  dirty paths in `adoption-findings.md`, branch off `HEAD`, never `git add` a file
  you did not change. The dirt survives untouched.
- **Baseline suite already red** — record which tests, branch anyway, state the
  pre-existing failure in every PR body so no later step inherits blame.
- **A gate red twice for reasons you cannot explain** — attempt three times, then
  park: revert its commits, record the symptom and the attempts, move on. Do not
  retry indefinitely and do not merge it red.
- **A step needs a behavioural change to the module** — do not make it. Land the
  rest, record the required change with its `file:line`, mark the gate thin.
- **CI needs a secret or a runner the target lacks** — do not invent either.
  Degrade: hosted instead of self-hosted, the job omitted rather than broken, and a
  finding naming exactly what is missing.
- **A write outside `<TARGET>` seems necessary** — it is not. It goes in a findings
  file. The only writes to another *repository* are step 2's and step 33's skeleton
  PR; `$SCRATCH` is untracked working space and is not one of them.

**Never disable a failing check to make a PR mergeable.** Not `[skip ci]`, not
`continue-on-error`, not commenting out a step, not `gh workflow disable`, not
lowering a threshold to the observed value. A red gate you cannot fix is a finding,
and the honest end state of a step.

---

<!-- phase:0 -->

# Phase 0 — Already adopted? Re-alignment triage

**Read this before phase 1, always.** It decides whether the target needs the full
42 steps, a narrow re-alignment, or nothing. Cheap: three questions, no writes.

A module that adopted cleanly against an older revision of this prompt has no
business re-running 42 steps. Equally, a module that *looks* adopted may have
drifted in ways no green run reveals.

## The stamp

An adopted target carries `ci/.adopted`:

```text
prompt_version: <sha256 of this file's step bodies>
skeleton_sha:   <reference commit adopted from>
adopted_date:   <YYYY-MM-DD>
steps_degraded: <comma-separated step numbers, or none>
```

`prompt_version` hashes **step bodies only**, not the whole file — otherwise every
prose edit invalidates every adopter's stamp and forces needless re-alignment.
Compute with `ci/tools/prompt-section.sh --hash`.

## The three questions

```sh
cd <TARGET>
test -f ci/.adopted && cat ci/.adopted || echo "NO STAMP"
ci/tools/prompt-section.sh --hash          # in the REFERENCE checkout
```

1. **No stamp?** → full migration, phases 1–7. Step 34 writes the stamp. A target
   that scores 3/3 on phase 1's markers but has no stamp still takes the full
   route — the markers are cheap to fake and prove nothing about the steps behind
   them.

2. **Stamp present, `prompt_version` differs?** → **re-alignment**, the cheap path.
   Diff the two prompt revisions and work only the changed step ranges:

   ```sh
   cd /opt/myguard/labs/nginx-skeleton-module
   git diff <stamped_skeleton_sha>..HEAD -- ci/PROMPT.md | grep -E '^\+## [0-9]+'
   ```

   Those steps, plus the drift-class probes below, plus phase 7. Typically 3–8
   steps rather than 42. Record the new stamp at the end.

   **A target stamped against the 64-step numbering maps through this table.**
   That numbering ran until 2026-08-11; anything adopted before then cites steps
   that no longer mean what they say. Do not assume step N survived as step N.

   | Old (1–64) | New (1–42) | Note |
   |---|---|---|
   | 1, 2 | 1, 2 | unchanged |
   | 3, 4, 5 | 3 | merged: probe + score + record |
   | 6 | 4, 5 | split: harness install, then baseline |
   | 7–9 | 8–10 | seam, shifted by phase 2 |
   | 10, 11 | 11 | merged: the move and its path repair are one commit |
   | 12 | 12 | unchanged |
   | 13, 14, 15 | 13 | merged: one runner-identity step, probes included |
   | — | 14 | **new**: long-runner demotion, before the orchestrator |
   | 16, 17 | 15 | merged: `workflow_call:` + `ci.yml` + double-run proof |
   | 18 | 16 | trigger removal; its long-runner grep is now verification |
   | 19–22 | 17–20 | workflow set, triage, bands, badges |
   | 23, 24 | 21 | merged: unit tests carry their own mutation pass |
   | 25, 26 | 22 | merged: live-server layer carries its own mutation pass |
   | 27, 28, 29 | 23, 24, 25 | fuzz, replay/soak, neighbours |
   | 30 | 26 | coverage |
   | 32, 33, 34 | 6, 7, 27 | **split**: install+configs and the hook moved to phase 2; retargeting stayed |
   | 31, 35 | 28 | merged: caching and the speed budget |
   | 36, 37, 38 | 29 | merged: measure, lane, write the map |
   | 39–43 | 30 | merged: one depth audit, five subjects |
   | 45, 46, 47 | 31 | merged: the gates that drift |
   | 48 | 32 | CI shape |
   | 49 | 33 | skeleton feedback PR |
   | 52, 53 | 34 | merged, **plus** the new `ci/.adopted` stamp |
   | 54 | 35 | report |
   | 55 | 36 | recheck |
   | 51, 57 | 37 | merged: linter set re-derivation |
   | 60 | 38 | scheduled lanes, now dispatched early |
   | 58, 59 | 39, 40 | the two `[opus]` reviews |
   | 44, 61, 62 | 41 | merged: soak conclusions, dynamic analysis, coverage |
   | 50, 63, 64 | 42 | merged: bot replies, residue, gitlink, final report |
   | 56 | 7 | hook install moved into phase 2 |

3. **Stamp current?** → run the drift-class probes only, then phase 7. None of
   these is visible from a green run:

   - **Port bands** (step 19) — read the target's step ORDER, not merely the
     presence of a verify step. Any binder counts, not only the runtime driver.
   - **Coverage option spelling** — `--gcov-object-directory` fails argparse on
     gcovr below 7.0. The condition is the gcovr major version the job actually
     runs, not whether a pin exists. `--object-directory` is accepted by both.
   - **`versions.env` consumers** — one that sources the file without validating it
     executes any line that is not a pin. Arriving for the first time? Ship the
     validating loader.
   - **`workflow_policy.py` vintage** — older than the YAML-parse rewrite means it
     matches workflow YAML with regexes, and valid YAML makes all three policy
     checks silently vacuous (a `.yaml` extension, an inline `on: [pull_request]`,
     a comment after a job key). Ship the YAML-parse version and run
     `ci/linter/selftest.sh` plus `ci/linter/fixtures/policy/`.
   - **Runner identity** (step 13) — any change touching a `runs-on`,
     `actionlint.yaml` or `TRUST_SPLITS` carries our pool with it. Run probes 1b
     and 2. A single-change sync is the likeliest way a self-hosted selector
     re-enters a target step 13 already cleaned — the reference's copy is the
     source, and it is `POOL_OWNED=yes`.
   - **No `src/`** (step 12) — everything scoped to `src/` selects nothing and
     reports success.
   - **Long-runners back on the PR lane** (step 14) — re-run step 16's greps. A
     workflow added since adoption arrives with whatever triggers its author copied.

**Acceptance:** the route named — full / re-alignment / probes-only — with the
stamp contents (or its absence) and, for re-alignment, the list of changed steps.
A route asserted without the stamp diff is a guess.

## Forwarding one later change

Distinct from re-alignment: re-alignment carries *the prompt* forward, forwarding
carries *one skeleton improvement* across. Use it when the stamp is current and you
were handed a specific change to propagate.

**Establish the anchor first.** In order of preference: a recorded anchor in the
mirror's `index.md`; `ci/.adopted`'s `skeleton_sha`; a `vN` tag the target's
`CHANGES` names; the merge commit of its adoption PR. Then:

```bash
git -C /opt/myguard/labs/nginx-skeleton-module log --oneline <anchor>..HEAD
```

That is the candidate set; [CHANGES](../CHANGES) says what each was *for*. **If
none resolves, there is no anchor** — the target never took a documented adoption,
so it uses the migration route. Do not invent one from the first commit or from
"HEAD minus the change I was handed"; both manufacture a scope that was never true.

Take ONE concern. Before touching the target, write in the PR body what the gate
must prove in *behavioural* terms ("a job that starts the runtime driver without
declaring a port band fails the build"), what failure it would have caught in the
target, and whether the target can even reach that failure — a gate for a layer it
does not have is an adoption step, not a forward.

Then check the drift classes above. Re-derive for the target rather than copying:
module name and symbol prefix (including inside fuzz targets, unit tests and grep
patterns in scripts), paths, runner expression, port bands, version pins. Keep the
reference's thresholds unless you record why not.

Two consistency gates that fail late otherwise: `lint-docs-drift` compares the
workflow set against the README's `## CI` table, so a new or renamed workflow needs
its row in the same commit; and `run-all.sh` reads `git ls-files`, so a **new
untracked file is invisible to the linter** — stage it before trusting a clean run.

Verify the gate red in the target, run the local gate at the target's own
thresholds, then PR with workflows enabled. The body states: the anchor and how you
resolved it, the one concern, what the gate proves, the probe and what it printed,
and every deliberate divergence with its reason. Remote CI green on the **current
head** — re-check `headRefOid` before merging. Squash-merge, delete the branch,
bump the superrepo gitlink. Update `ci/.adopted` and record the new anchor in
`index.md`.

Run phase 7 after the forward PR or no-op.

---

<!-- phase:1 -->

# Phase 1 — Establish what you are working with

Five steps, read-only. Nothing here lands in a PR. This is the measurement
everything downstream is planned from.

## 1 — Set up the run

```sh
cd <TARGET>
git status --porcelain            # dirty is FINE — record, do not stash
git rev-parse --abbrev-ref HEAD   # note it; this is the base to branch from
git remote -v                     # confirm you are where you think you are
gh auth status                    # authenticated at all?
gh repo view <owner>/<repo> --json viewerPermission -q .viewerPermission
```

The last command is the one that matters. `gh auth status` passes for a read-only
account, which then fails at the first push — with a branch already cut. `ADMIN`,
`MAINTAIN` or `WRITE` continues; `READ`, `TRIAGE` or an error is the hard stop.

```sh
SCRATCH=${SCRATCH:-$(mktemp -d)}
printf '# Adoption findings — <TARGET>\n\n' > "$SCRATCH/adoption-findings.md"
printf '# Skeleton findings — from <TARGET> adoption\n\n' > "$SCRATCH/skeleton-findings.md"
git status --porcelain=v1 -z > "$SCRATCH/initial-status.z"
git diff --binary > "$SCRATCH/initial-worktree.patch"
git diff --cached --binary > "$SCRATCH/initial-index.patch"
git ls-files --others --exclude-standard -z | sort -z | xargs -0r sha256sum \
    > "$SCRATCH/initial-untracked.sha256"
```

Record the base branch and every dirty path, so a later diff cannot be blamed on
you. The four snapshots preserve both path set and contents; step 42 recreates and
compares them. Keep them in `$SCRATCH`, never the target.

**Hard stop only if** the directory is not a git repo, or `gh` cannot authenticate
against this remote. Anything else found here is a finding.

**Acceptance:** both findings files and all four dirt snapshots exist; base branch
recorded; you know the remote.

## 2 — Scope, git safety, rollback

Read once, applies to every later step.

**One repo is writable: `<TARGET>`.** This reference, sibling modules and
`/opt/myguard/packages` are read-only for the whole job. Reading the reference is
the point; committing to it is not — except step 33's single skeleton PR.

Two writes outside the target are expected, and only these two:

- **The target's own memory mirror**, `memory/labs/<name>/` or
  `memory/eilandert/<name>/`.
- **The superrepo gitlink**, once per merged PR, if `<TARGET>` is a myguard
  submodule. The target PR merges first, then the gitlink bump lands signed on the
  superrepo's `master`. An external target has no gitlink and no mirror; skip both
  and say so.

A dirty submodule or unrelated change in another tree is left exactly as found.

Git safety, non-negotiable:

- **Never `push --force` to a shared branch**, and never to the default branch
  under any circumstance. Rewriting a group branch you alone own, before review, is
  the only acceptable case — and `--force-with-lease`, never `--force`.
- **Never `git checkout .`, `git reset --hard`, or `git clean -fd`** to undo your
  own mistake. They erase whatever else was in the tree. Revert the specific file.
- **No secret ever enters a commit, a workflow, or a PR body** — no tokens, no
  PATs, no `Bearer` strings, not even revoked ones. Reference via
  `${{ secrets.X }}` or an env var. A workflow needing a credential the target does
  not have is a finding, not a thing to invent.
- **The default branch is not a work surface.** Nothing is committed straight to
  `master`/`main`, including "trivial" doc fixes.
- One group per branch, named for the group. Delete it after merge. Workers add
  commits to that branch; never step branches or step PRs.

**Rollback.** Each PR is one revert boundary. Keep its step commits independently
reviewable, but revert a merged PR through one new PR. Do not force-push over
history others have pulled, and do not "fix forward" by stacking a second broken
change on the first.

**Acceptance:** nothing to produce; this step is read and obeyed.

## 3 — Inventory: probe, score, record

One step, three outputs. Run the probes, score the markers, write the record — the
raw output is read once here rather than re-read by three separate steps.

```bash
cd <TARGET>
git remote get-url origin                                # who owns it
ls -d ci/t ci/tools ci/linter ci/fuzz src t tests fuzz 2>/dev/null
ls .github/workflows
grep -lE '^\s*pull_request:' .github/workflows/*.yml | wc -l   # entry points
grep -rn 'runs-on' .github/workflows/                    # whose machines?
ls src 2>/dev/null || ls *.c *.h                         # C at root?
ls src/*_scan.c src/*_scan.h *_scan.c 2>/dev/null        # decision seam? (step 8)
grep -ln 'ngx_http_request_t' src/*_scan.c *_scan.c 2>/dev/null  # expect no hits
grep -nE '!\[' README.md                                 # badge row + order
ls ci/t/*.t t/*.t tests/*.t 2>/dev/null | wc -l          # how many .t, and WHERE?
perl -MTest::Nginx::Socket -e1 && echo HARNESS-ok || echo HARNESS-MISSING
git log --oneline -10
gh run list -R <owner>/<module> --limit 20 \
   --json name,conclusion,startedAt,updatedAt,workflowName
```

**Read the memory mirror first if the target is ours** — `index.md`, `issues.md`,
`lessons.md`. A trap recorded there outranks anything you infer from the code.

### Record `POOL_OWNED` now — it binds every later step

The `origin` URL is the input to the only question that can put our hardware in
someone else's repository. Answer it once, here, in writing, before any workflow is
read:

```sh
git remote get-url origin
# myguard-labs/* or eilandert/*  -> POOL_OWNED=yes   (our machine, our pool)
# anything else                  -> POOL_OWNED=no    (hosted-only, no exceptions)
```

**`POOL_OWNED=no` is the default and the safe answer.** An unfamiliar remote, a
fork, a mirror, a local path, a detached checkout with no `origin` at all — every
one is `no`. Do not reason from the module's *name*: a repo called
`nginx-foo-module` under an unfamiliar owner is not ours, and the naming convention
is the thing an adopter copies first.

Under `POOL_OWNED=no`, these hold for the whole run and are not revisited:

- every `runs-on` is a bare `ubuntu-latest` — no ternary, no `fromJSON`, no
  `self-hosted` (step 13)
- `TRUST_SPLITS` is an empty frozenset and `.github/actionlint.yaml` declares no
  `self-hosted-runner:` block (step 13)
- no step may introduce a self-hosted selector "temporarily to measure something".
  Steps 28–29 become hosted-only scheduling work.

Write the value into the todo verbatim. A later step finding `POOL_OWNED`
unrecorded stops and re-derives it rather than inferring from whatever the
workflows currently say — the workflows are the thing under suspicion.

### Score the three markers

**Is the target already standardised?** Score three: a full `ci/` layout (`ci/t`,
`ci/tools`, `ci/linter`, `ci/fuzz`); `ci.yml` as the sole `pull_request` entry
point; `ci/linter/run-all.sh` plus a tracked `.githooks/pre-commit`.

A 3/3 score is **not** a route decision — phase 0's stamp is. Markers are cheap to
fake: two derived modules have a `ci/` directory and still score 0/3, `ci/` being
the cheapest half of step 11 and the most misleading signal in the set. Score it
for the record, then follow phase 0's route.

### Record the inventory

Write to the memory mirror (`/opt/myguard/memory/labs/<module-name>/index.md` for
ours; an external target has no mirror — create one only if work is ongoing):

- current layout, whether `src/` exists, and **whether the decision seam exists**
  (step 8). Absent or nominal is the largest code change in the job — size it here.
- workflows in three buckets: **matches** a reference workflow by purpose,
  **missing**, and **extra**. The third is what rule 2 protects and what gets lost
  otherwise; every entry also goes to `skeleton-findings.md`.
- **every `pull_request:` entry point by name** — that count is the size of the
  steps 15–16 demotion, the riskiest edit in the job
- **every long-runner workflow by name** (`valgrind|helgrind|drd|fuzz|soak|stress`)
  and which triggers each carries — step 14 demotes these, and it needs the list
- whose runners it currently uses
- **measured wall-clock per workflow** from `gh run list` — real numbers, needed
  for steps 28–29. Estimates are not acceptable there.
- current coverage number, if any tooling exists (usually none)
- gates it has that the reference lacks, and where they run
- **the test harness: how many `.t` files, in which directory, and whether
  `Test::Nginx` is installed at all**. All three, not just the last — "the harness
  is present" and "the suite it is supposed to run is present, where `prove` will
  look for it" are different facts, and step 5's baseline is meaningless without
  both.

**Acceptance:** every probe run with its output kept; the score 0/3–3/3 with
evidence named separately for each marker; all nine record items written. The three
workflow buckets, the long-runner list and the per-workflow wall-clock table are
what later steps cannot reconstruct once files have moved.

## 4 — Install the harness if it is missing

Step 5's baseline is meaningless without it, and the full linter install is step 6.

**`HARNESS-MISSING` from step 3?** Install it and say so:

```sh
perl -MTest::Nginx::Socket -e1 || sudo cpanm --notest --quiet Test::Nginx
```

(apt has no `libtest-nginx-perl` on every target release; CPAN always does.)

`Test::Nginx` **is** the openresty Perl test suite — the two names are one thing,
and there is no separately-named openresty package to hunt for. The dist is
`AGENT/Test-Nginx-*.tar.gz`, AGENT being agentzh, openresty's author; confirm with
`cpanm --info Test::Nginx`. In an installed tree the giveaway is the
`Test::Nginx::Socket::Lua*` modules, which only that dist ships.

**Acceptance:** `perl -MTest::Nginx::Socket -e1` succeeds, and whether it was
already present or installed here is recorded.

## 5 — Baseline the suite, then write the run plan

**Baseline the target green.** Run whatever suite it has and record the result. If
already red, that is a finding and a fact every later PR body must state —
otherwise the first step that lands code inherits blame for a failure predating it.
Do not stop; do not fix it.

**Zero `.t` files where you are about to point `prove`?** Then the baseline is not
green, it is absent. The target's suite may still be in `t/` or `tests/` (step 11
moves it), so `prove ci/t/` run before that move reports success having executed
nothing.

Both harness failure modes produce a result that looks like an answer, and only one
is loud. A missing harness at least fails visibly (`Result: FAIL`, "Failed to get
the version of the Nginx in PATH"). The quiet one is the empty directory: **`prove`
on a path with no `.t` files exits 0 with `Result: NOTESTS`** — verified, not
assumed. So record the test COUNT beside the verdict, check it against step 3's
count, and treat `NOTESTS` as "could not run", never as a pass. A baseline of zero
tests recorded as "green" makes every later comparison meaningless.

**Emit the run plan as a todo list.** As the last act of this step, call `TodoWrite`
once with **exactly one item per PR** plus the barriers inside PR1 — not one per
step and not one per phase.

```text
[x] Phase 0-1 — route, findings files, inventory, harness, baseline
[~] PR1: steps 6-16 — toolchain, seam, ci/ layout, identity, demotion, orchestrator
      barrier A: step 13 complete before step 14
      barrier B: step 15 double-run proof pasted before step 16
[ ] PR2: steps 17-29 — workflows, badges, test layers + mutations, fuzz, coverage,
      caching, linter retarget, lanes
[ ] REF: step 33 — skeleton findings PR, or evidence-based no-op
[ ] PR3: steps 30-42 — depth pass, close out, docs, memory, aftermath, gitlink
```

Keep it current: exactly one PR is `in_progress`; flip it to `completed` only when
it merges, or when every step is evidence-proven already done and no PR is needed.

**Acceptance:** the baseline result recorded — pass, or the named failing tests —
**with the number of tests that actually ran, matching step 3's `.t` count**; and
the todo list written with phases 0–1 closed.

---

<!-- phase:2 -->

# Phase 2 — Toolchain

**PR1 opens here.** Two steps, and they come first because everything after them is
checked by them. The linter *checkers* are retargeted later (step 27) — they select
on `src/`, which does not exist until step 12, and an empty selection passes green.
What lands here is target-independent: the installer, the configs, the structural
ruleset, the hook.

Doing this at the end instead — where it used to live — costs three things: the
baseline hand-rolls its own `cpanm` because the installer has not arrived; the
twenty-odd steps that edit C and workflows run with no checker set behind them;
and the configs arrive after the checkers, so the first run reports findings that
are not bugs. Measured on `nginx-cache-turbo-module`
2026-08-10: `.yamllint` missing → 22 findings; `.perlcriticrc` missing → 132;
`codespell-ignore.txt` missing → 149 of 151. That state is what trains everyone to
`--no-verify`.

## 6 — Install the linters and their configs

Follow **[linter/README.md](linter/README.md)** verbatim: `apt-get` first, then
`pipx` for what Debian lacks, then `cpan` for Perl, then upstream binary for
actionlint. `install-linters.sh` is the single installer; CI and a fresh clone use
the same one.

- A missing tool exits 2 and BLOCKS. Never a silent skip.
- **Port the CONFIG files with the checkers that read them** — `.yamllint`,
  `.perlcriticrc`, `ci/linter/codespell-ignore.txt`. The first two ship here; the
  third ships empty, as the documented seam for words correct in the target.
- Relaxations live in `.yamllint` / `.perlcriticrc` with their reason. Fix
  pre-existing findings or record why — no blanket suppression.
- **The installer is retargeted to the TARGET's checker set**, not only to the
  ported scripts. `--check` must list every tool the finished set needs, including
  tools the reference has never heard of. Rule 2 makes this concrete:
  `nginx-cache-turbo-module` gates its staged secret scan on `gitleaks`, which this
  repo does not use, so the ported `install-linters.sh` neither installed it nor
  reported it — on a fresh clone or hosted runner that gate would simply have been
  absent while `--check` said everything was fine. A tool present but absent from
  `--check` is invisible to `lint.yml`; a tool the target needs and the installer
  never heard of is worse.

**Acceptance:** `install-linters.sh` succeeds from a clean environment and `--check`
lists every tool the checker set needs; `.yamllint`, `.perlcriticrc` and
`codespell-ignore.txt` are present.

## 7 — The tracked hook

- **Tracked hook at `.githooks/pre-commit`**, enabled with
  `git config core.hooksPath .githooks`. Lints STAGED files only.
- The hook runs `run-all.sh`, so a checker installed but not selected by
  `run-all.sh`'s glob never fires from a commit.
- Watch the top-level exclude: a global exclude in `.pre-commit-config.yaml` runs
  before every hook, so one broad pattern can blind every checker at once.

A first full-tree run on an adopted module may be red. Record findings; never weaken
the hook to clear them. Thresholds mirror `security-scanners.yml` from step 27 — the
mirror is checked there, once both sides exist.

**Acceptance:** the hook is tracked and enabled; a staged file with a deliberate
finding is blocked. Language coverage per-language is step 27's job, once the tree
has moved.

---

<!-- phase:3 -->

# Phase 3 — The seam, the layout, `src/`

Five steps. The decision seam is the only C refactor in the job and every later gate
links across it. It comes before the `ci/` move: the extraction is independent of
where test material lives.

**Read back every C edit in this phase.** Confirm the shape that landed is the shape
you intended: the seam call site is the real TU's, no stray `ngx_http_request_t`
survived. A grep miss proves the spelling is absent, not that the change is right.

## 8 — Probe: which of the four states is the target in?

Read-only, and it decides how steps 9–10 run.

> **Decision logic goes in `*_scan.c`, taking `(u_char *, size_t)`. Only
> `ngx_http_request_t` plumbing stays in `*_module.c`.**

This is the one structural rule, and it comes before the test layers because both
link across it: `ci/tests/unit/test_scan.c` (step 21) and `ci/fuzz/fuzz_scan.c`
(step 25) compile the module's **real** decision source, not a copy. Without the
seam, step 21 tests a reimplementation and step 25 fuzzes one — both green, both
proving nothing about shipped code.

```sh
ls src/*_scan.c src/*_scan.h 2>/dev/null || ls *_scan.c *_scan.h
grep -n 'ngx_http_request_t\|r->\|ngx_http_' $(ls src/*_scan.c 2>/dev/null || ls *_scan.c)
# ci/tests/unit/run.sh is the REFERENCE's entry point, not a given for the target.
# Fall back to whatever step 5's baseline proved is the target's real unit entry
# point (e.g. ci/fuzz/run.sh, a Makefile check target, a bare ci/tests/*.sh) —
# grepping a path the target never had is silent, not "no hit".
UNIT_ENTRY="$(ls ci/tests/unit/run.sh 2>/dev/null || echo '<baseline-proven entry point>')"
grep -n '_scan\.c' ci/fuzz/build.sh "$UNIT_ENTRY" 2>/dev/null
git diff --stat HEAD~1 -- ci/fuzz/ngx_stubs.c               # did stubs grow?
```

**Record `UNIT_ENTRY` in the todo** — step 30 re-verifies the seam and needs it, and
it does not carry over between sessions.

| State | Tell | Next move |
|---|---|---|
| **clean** | no `ngx_http_request_t` in `*_scan.c` | skip step 9, go to 10 |
| **clean via extraction script** | a `ci/fuzz/extract_*.sh` copies decision bytes into a generated `.inc`, cross-checked by `#define`/checksum so drift fails the build | skip step 9, go to 10 — the drift gate is what a hand-written seam gets for free. Confirm it is exercised: a source change without touching the `.inc` must fail |
| **nominal** | `*_scan.c` exists but reaches for `r->`, allocates from `r->pool`, or logs via `r->connection->log`. **Growth in `ci/fuzz/ngx_stubs.c` is the tell** — every stub beyond the reference's set is a dependency that should have been refactored out | step 9 runs |
| **none** | decision logic inline in `*_module.c` | step 9 runs |

A fifth outcome is legitimate and must be stated rather than skipped silently: the
module genuinely has **no decision logic to separate**, a pure plumbing module whose
only work is `ngx_http_*` calls. Say so with the `file:line` that shows it, record
that steps 21 and 25 are correspondingly thin, and skip steps 9–10.

**Acceptance:** the state named, with the grep output that establishes it, and —
where the seam exists — whether the fuzz and unit builds currently name it.

## 9 — Extract the seam

Only if step 8 found "nominal" or "none". This is a **move, not a rewrite**.

1. `*_scan.c` / `*_scan.h` take bytes and return a verdict. No nginx request types
   in the signature, no allocation from a request pool — pass a buffer in or take an
   explicit allocator argument.
2. `*_module.c` keeps the handler, directive parsing, config merging and every
   `ngx_http_*` call, and calls into the seam.

**Do not change behaviour while extracting.** The step 5 baseline must stay green
across it — run it wherever it currently lives, since `ci/` does not exist yet. A
behavioural fix riding along makes any later bisect ambiguous; a real bug found while
extracting goes to `adoption-findings.md`.

Paths here assume `src/`; a target still keeping its C at the repo root creates the
seam **beside the existing `*_module.c`**, and it moves under `src/` at step 12. Do
not create `src/` here — that split would land the same C in two commits.

**Acceptance:** no nginx request types inside `*_scan.c`; the module still builds;
the step 5 baseline is **unchanged**. A test already red at step 5 stays red and is
named in the PR body.

## 10 — Wire the two consumers

The extraction is worthless until the things that link across it name the real file.

```sh
grep -n '_scan\.c' ci/fuzz/build.sh "${UNIT_ENTRY:-ci/tests/unit/run.sh}" 2>/dev/null
```

Both the target's real unit entry point and `ci/fuzz/build.sh` must compile the
target's real `*_scan.c` — the same source, not a second copy. Whichever the target
already has gets pointed at the seam now; the rest follow the material into `ci/` at
step 11. If the target has **neither** yet, say so: the seam is verified by build and
grep here, and by steps 21 and 25 once its consumers exist.

The reference's `build-test.yml` asserts the seam file exists by name after a rename.
Confirm the target's equivalent names the **target's** file — a path that no longer
exists makes the assertion vacuous, not failing.

**Acceptance:** every consumer that exists names the target's real `*_scan.c`, by
grep; or an explicit line saying which consumers do not exist yet.

## 11 — Move CI material under `ci/`, and fix every path that climbed out

One step, one atomic commit: a `git mv` whose relative paths are not fixed does not
build, so the move and the repair cannot be separated.

```text
ci/
  t/                     Test::Nginx suite            (was t/ or tests/)
  tests/unit/            C unit tests of the decision core
  fuzz/                  libFuzzer targets, dict, corpus/, regressions/
  vendor/nginx-tests/    upstream suite submodule
  tools/                 ci-build.sh, nginx-tree.sh, test_runtime.py,
                         coverage.sh, max-port.sh, ci-hang-guard.sh, soak.sh
  linter/                local lint gate (step 6, retargeted at step 27)
```

- `git mv`, never copy-then-delete — blame must survive. Verify with
  `git log --follow` on one moved file before continuing; a move recorded as
  delete+add loses history silently and cannot be repaired after merge.
- `git submodule update --init` still working after moving `ci/vendor/nginx-tests`
  is a required check — the `.gitmodules` `path:` must be edited, not just the
  directory moved.

**Then fix every relative path that climbed out.** This is the half that silently
fails. Grep and fix in this order:

1. nginx's module **`config` file** — names every source path; the one file whose
   breakage stops the module building at all
2. `../` in C `#include`s
3. `$PWD` / `dirname` logic in shell
4. `paths:` filters in workflows
5. `hashFiles()` keys
6. `prove` invocations
7. fuzz corpus paths
8. `.gitmodules` submodule paths
9. `.gitignore`
10. coverage exclude patterns
11. README references

A missed climb compiles fine and silently tests the wrong tree. **A checker moved
into `ci/` is a special case of the same bug:** `nginx-cache-turbo-module`'s
`ci/tools/lint-shm-lock.sh` did `cd "$(dirname "$0")/.."`, correct while it lived in
`tools/` at the repo root; this move made that land in `ci/`, where `src/*.c` matches
nothing. Bash leaves an unmatched glob as a literal, the `[ -f "$f" ] || continue`
guard skips it, and the loop printed `ok: invariant holds` having read ZERO files —
exit 0, in CI, for weeks.

Run the suite after the move and before any workflow edit, so a failure is
attributable to one thing: `TEST_NGINX_TIMEOUT=20 prove -v ci/t/`

**Acceptance:** local `prove` green with the same test count as step 5; fuzz targets
still build (`ci/fuzz/build.sh`); `git log --follow` shows history on a moved file;
no path outside `ci/` refers to `t/`, `tests/` or `fuzz/`; every moved checker
reports a non-zero selection count.

## 12 — Create `src/` if the target has none

Skip if `src/` already exists — but check, do not assume: two of eight derived
modules keep `ngx_http_<name>_module.c` (sometimes plus `<name>_core.c/.h`) at the
repo root.

This is the empty-selection class, and it is not cosmetic. Everything downstream is
scoped to `src/` — `lint-c.sh`, `lint-nginx.sh`, the gcovr filter, the CodeQL TU
filter — and every one *passes* on an empty selection rather than failing.

Move the C under `src/` — including the seam files from steps 9–10 — and update
nginx's module `config` in the **same commit**, or the module stops building.

The linter checkers are not retargeted until step 27. Record the deferred
empty-selection probe in the todo: immediately after step 27, a `malloc`/`strcpy`
probe beside the module's real C must make
`LINT_ONLY="c nginx" ci/linter/run-all.sh` exit 1 before PR2 can merge.

**Acceptance now:** every module `.c`/`.h` is listed by `git ls-files 'src/*.[ch]'`,
nginx's module `config` resolves those paths, and a clean rebuild succeeds.
**Deferred acceptance at step 27:** the recorded probe exits 1; green means the
selection is still empty.

---

<!-- phase:4 -->

# Phase 4 — Runner identity, demotion, orchestrator

Four steps, finishing PR1. Whose machines the workflows name, which workflows are
allowed on the PR lane at all, and the single entry point.

**Barrier A: step 13 completes before step 14.** **Barrier B: step 15's double-run
proof completes before step 16.** Both block, and both exist because the failures
they prevent are invisible in a green run.

## 13 — Runner identity: rewrite `runs-on`, fix the policy files, verify

One step, three ordered parts. The order matters: workflows first, policy files
second, probes last — the gate is the last thing to change, so its findings are
about what remains.

`builder02` is the label of **a physical machine myguard owns**, spread across three
files that must agree:

```sh
grep -rn 'builder02' \
    .github/workflows/ .github/actionlint.yaml ci/linter/workflow_policy.py
```

| File | What it holds | In the reference, 2026-08-03 |
|---|---|---|
| `.github/workflows/*.yml` | the `runs-on` fork ternary | 15 selectors in 7 workflows |
| `.github/actionlint.yaml` | the declared label list | 3 mentions, one `self-hosted-runner:` block |
| `ci/linter/workflow_policy.py` | `TRUST_SPLITS`, the approved-selector set | 5 mentions, three label combinations |

23 sites; re-derive rather than trusting the number.

**Nothing in the toolchain catches a copied label.** actionlint validates runner
labels for a *literal* `runs-on` only, and every self-hosted selector here is a
`fromJSON(...)` ternary it stays silent on (measured 2026-08-02: `builder02` →
`buidler02` was invisible to it). zizmor has no idea which labels you are entitled
to. `lint-ci-runners.sh` compares against `TRUST_SPLITS` — which, if copied
unedited, **contains `builder02` and approves it by construction**. The failure is
not a red CI you fix; it is a green CI either queueing forever against a label
nobody answers, or dispatching to a runner you do not own.

**The rule: under `POOL_OWNED=no` (step 3), every job is `ubuntu-latest` with no
ternary at all.** The fork ternary answers one question — may this code touch *our*
build host? An adopter with no build host has no such question, and an expression
whose fallback arm names someone else's machine is a default-deny that defaults to
somebody else's hardware.

**Start from what the target actually has:**

| The target's `runs-on` | What it means | What you do |
|---|---|---|
| fork ternary naming `builder02` | copied from us, or a former myguard repo | rewrite all to `ubuntu-latest` |
| a **bare list** — `[self-hosted, builder02, lxc]`, no ternary | worse: no fork arm, so a fork PR runs on our host | same rewrite, and note it in the PR body |
| already `ubuntu-latest` everywhere | nothing to do | confirm, record, move on — do **not** add a ternary |

The third row is what an adopter gets wrong by following the reference too
faithfully. A hosted-only target that gains a ternary has gained a selector pointing
at hardware it does not own, from a step whose entire purpose was to remove one.

```yaml
# before (reference, myguard-owned pool)
runs-on: ${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || fromJSON('["self-hosted","builder02","lxc"]') }}

# after (any adopter without their own pool)
runs-on: ubuntu-latest
```

**Then the two policy files**, after the workflows and never before:

1. `.github/actionlint.yaml` — delete the `self-hosted-runner:` block; declaring
   labels you never use trains the next person to add one.
2. `ci/linter/workflow_policy.py` — reduce `TRUST_SPLITS` to an empty frozenset.
   `HOSTED.fullmatch` covers every selector now, and an empty approved-set makes any
   future self-hosted selector a finding rather than a silent pass.

Emptying `TRUST_SPLITS` while the workflows still carry self-hosted selectors
produces one finding per selector: doing it in the reference produced **16
findings**. Expected intermediate state, and exactly the noise that buries the
finding you are hunting in the probes below.

**Then verify, both directions.** For a hosted-only adopter, a grep proving
`builder02` absent says nothing about whether the *checker* still approves it. For a
pool-owned adopter, the inverse mistake is just as bad. Test the branch selected by
`POOL_OWNED`:

```sh
# 1. no myguard runner identity survives in a hosted-only adopter
grep -rn 'builder02\|b02lxc' .github/ ci/linter/workflow_policy.py 2>/dev/null
#    -> POOL_OWNED=no: expected no hits
#    -> POOL_OWNED=yes: hits allowed only for the target's approved selectors

# 1b. and no self-hosted selector survives under ANY spelling. Probe 1 greps our
#     CURRENT label; it cannot see `[self-hosted, lxc]`, a renamed pool, or a
#     ternary whose fallback arm was edited to a different machine.
grep -rnE 'runs-on:.*(self-hosted|fromJSON)' .github/workflows/
#    -> POOL_OWNED=no: MUST be empty. Any hit is a selector pointing at hardware
#       the target does not own, whatever it is called.

# 2. the checker implements the ownership decision from step 3
cat > .github/workflows/_probe.yml <<'EOF'
name: probe
on:
  schedule:
    - cron: "0 4 * * 1"
jobs:
  p:
    runs-on: ${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || fromJSON('["self-hosted","builder02","lxc"]') }}
    steps:
      - run: echo probe
EOF
# POOL_OWNED=no: MUST exit 1; this target does not own the reference pool.
# POOL_OWNED=yes: MUST exit 0 when this is the target's approved selector.
LINT_ONLY=ci-runners ci/linter/run-all.sh

# Both branches must reject an unregistered selector.
sed -i 's/builder02/unregistered-probe/' .github/workflows/_probe.yml
LINT_ONLY=ci-runners ci/linter/run-all.sh   # MUST exit 1
rm .github/workflows/_probe.yml
```

Probe 2 needs `ci/linter/run-all.sh`, which step 6 installed — so unlike earlier
revisions of this prompt, it runs here rather than being deferred.

**Probe 2 going green for a hosted-only target, or red for a pool-owned target's
approved selector, is the bug this step exists for.** It means `TRUST_SPLITS` does
not match the ownership decision. Fix the policy file; do not delete the probe.

**In the unedited reference probe 2 exits 0, correctly** — `builder02` is an
approved selector *here*. The probe is a statement about the TARGET; running it in
the reference proves nothing.

Stated honestly so nobody optimises it back: the self-hosted pool is what makes
`ci-deep.yml`'s monthly matrix and long fuzz runs affordable. On hosted runners
those are slower and bounded by the 6-hour job limit. That is a scheduling problem,
not a reason to point a `runs-on` at hardware you do not control.

**Only under `POOL_OWNED=yes`** is self-hosted available at all, and then it is
opt-in and a separate commit — never smuggled into the port. All three files change
together with their own labels, the fork arm stays the hosted runner, and the
condition stays `github.event.pull_request.head.repo.fork` — not `github.actor`, not
a repo variable, both of which a fork controls. Then read steps 28–29 in full.

"The target is ours and shares our build host" is a claim about **hardware and
runner registration**, not about the GitHub org. A myguard-owned repo whose CI has
never been registered with the pool is still `ubuntu-latest`: a selector is answered
by a registered runner or by nothing, and "nothing" is a job queued forever on a
green-looking PR.

**Acceptance:** no `runs-on` names a label the target does not own; both policy
files carry the target-owned state; `actionlint` parses every edited workflow; for
`POOL_OWNED=no`, probes 1 and 1b are empty and probe 2 exits 1; for
`POOL_OWNED=yes`, every hit is a target-approved selector and probe 2 exits 0. The
unregistered selector is red in both branches. Paste all outputs in the PR body.
**Barrier A is now clear; step 14 may begin.**

## 14 — Demote every long-runner off the PR lane

**Do this before the orchestrator exists**, not after. Wiring `ci.yml` first and
removing long-runners later means every PR in this job — including PR1's own —
drags a soak behind it. Demoting first means the orchestrator is never built around
one.

**Bounded belongs in the PR lane; unbounded never does.** The split is the job's
*wall-clock bound*, not its tool name — "fuzzing.yml" says nothing about duration.

- **Bounded** — an explicit cap in the low minutes: a fuzz smoke run at
  `-max_total_time=120`, a targeted ASan/UBSan build, a Valgrind pass over one
  deterministic scenario. Legitimate PR-lane members. The reference runs fuzz and
  Valgrind this way, and that is correct — a two-minute libFuzzer pass catches the
  regression the PR just introduced, cheaply.
- **Unbounded** — a campaign, soak, stress run, or any job whose duration is set by
  "how long we let it run" rather than a budget: `schedule:` + `workflow_dispatch:`
  only. Never `pull_request:`, and never a member `ci.yml` invokes.

For every workflow on step 3's long-runner list, read the **actual bound** and act:

```sh
for w in $(grep -lEi 'valgrind|helgrind|drd|fuzz|soak|stress' .github/workflows/*.yml); do
  echo "== $w"; grep -nE 'max_total_time|runs=|-runs|iterations|timeout=|on:|schedule:|pull_request:' "$w"
done
```

`timeout-minutes:` is a ceiling, not a duration — it says when CI gives up, not what
the job costs. A 45-minute timeout on a 3-minute Valgrind pass is normal and is not
evidence of a long-runner. **No explicit bound = unbounded.**

Unbounded → `schedule:` + `workflow_dispatch:`, and it keeps its badge and `## CI`
table row. This does **not** weaken rule 2: the job is **moved, never deleted, never
`continue-on-error`'d**. Phase 7 is where it is exercised and its conclusions read.

The reason is throughput. An unbounded job returns its verdict long after the merge
decision it would inform, so parking one in the PR gate converts every merge into a
wait for information arriving too late to use. On the scheduled lane it keeps full
value — a finding becomes a tracked follow-up instead of a blocked PR.

Measured across the derived modules 2026-08-10: 36 of 41 long-runner workflows were
already `schedule`/`dispatch`/`call`-only. The 5 carrying `pull_request:` directly
(`coraza-nginx` asan+fuzzing+valgrind, `nginx-http-sentinel-module`
fuzzing+valgrind, `http-zstd` fuzzing+valgrind) are what this step prevents
recurring — check each against the bounded/unbounded split rather than assuming the
filename settles it.

**Acceptance:** every workflow on step 3's long-runner list classified bounded or
unbounded with its actual bound quoted; every unbounded one carrying only
`schedule:`/`workflow_dispatch:`; none deleted; each still holding its badge and
table row.

## 15 — Add `workflow_call:` to every member, add `ci.yml`, prove the double-run

**This step is barrier B.** Two edits and one proof, in one step because the
intermediate state between them is not independently observable.

First, add `workflow_call:` to each member **while leaving its `pull_request:` in
place**. It still runs standalone, so the target keeps working and this cannot break
anything.

Then add `ci.yml` calling every member. Verify **on a real PR** that each member
runs *twice* — once standalone, once called. Two runs is the expected intermediate
state and the proof the call graph is wired.

Skipping this proof is how a member ends up called by nobody: `ci.yml` references a
job name that does not exist, the call contributes nothing, and the suite looks green
because the check that would have failed never ran.

**One member can be unable to double-run, and it is not a `ci.yml` bug.** A called
workflow inherits the caller's `github.workflow`, so a member whose `concurrency:`
group interpolates it gets two distinct group strings and both runs survive. A member
whose group omits it — `codeql-${{ github.ref }}` rather than
`codeql-${{ github.workflow }}-${{ github.ref }}` — hashes both runs to the same
string, and the called run cancels the standalone one. That member shows one run and
a `cancelled` sibling no matter how correct the call graph is.

```sh
grep -A2 '^concurrency:' .github/workflows/*.yml | grep 'group:'
```

A member missing `github.workflow` gets it added here, then double-runs like the
rest. Where that cannot be changed, the reachability fact step 16 needs is the called
job appearing in the orchestrator run's job list with a real conclusion — record that
and the group string instead.

**Acceptance:** every member carries both triggers; `actionlint` clean; the run list
showing every member twice, pasted in the PR body. A member that ran once was never
called — fix `ci.yml` and re-run, unless its concurrency group is the cause above.
**Step 16 does not begin until this evidence exists.**

## 16 — Remove `pull_request:` and `push:` from every member

One commit. Now each member runs once.

**Both triggers go, not just `pull_request:`.** A member keeping `push:` runs again
on the merge commit, against a tree identical to the PR head that already passed. The
two runs get different concurrency keys, so `cancel-in-progress` cannot collapse
them, and both are green — the only symptoms are the bill and a README that no longer
describes what runs when. Measured on `nginx-cache-turbo-module` 2026-08-10: all six
members carried both.

**This is the point of no return**, and the only action in the job that can leave the
repo with *no* PR gate at all. Do not take it until step 15 showed **every** member
running twice. If even one did not double-run, fix `ci.yml` and repeat step 15; do
not proceed on the theory that it will resolve itself.

Two things that break a called workflow and not a standalone one:

- **`secrets: inherit` is not automatic.** A member that used a secret while
  standalone loses it when called unless the caller passes it.
- **Path filters do not work on a called workflow** — it cannot filter its own
  triggering. Gates move to a `changes` job in the orchestrator with an explicit
  job-level `if`. See step 29 rule 8.

A second entry point that is not `pull_request:` (a `schedule:`, a
`workflow_dispatch:`) is fine and normal.

**Acceptance:**

```sh
grep -lE '^\s*pull_request:' .github/workflows/*.yml   # -> ci.yml alone
grep -lE '^\s*push:' .github/workflows/*.yml           # -> empty

# no long-runner reachable from the PR lane, by either route. Step 14 demoted
# them; this proves none crept back. ci.yml and ci-deep.yml are excluded: the
# orchestrator NAMES its members, so a bare keyword grep matches it and reports
# itself.
grep -lEi 'valgrind|helgrind|drd|fuzz|soak|stress' .github/workflows/*.yml \
  | grep -vE '/(ci|ci-deep)\.yml$' \
  | xargs -r grep -lE '^\s*pull_request:'              # -> empty

# every long-runner-named member of the PR lane, with its actual bound. Not
# expected empty — the reference calls fuzzing.yml and valgrind.yml bounded.
for w in $(yq -r '.jobs[].uses // empty' .github/workflows/ci.yml \
           | grep -Ei 'valgrind|helgrind|drd|fuzz|soak|stress'); do
  echo "== $w"; grep -nE 'max_total_time|runs=|-runs|iterations|timeout=' "$w"
done
```

and a PR run in which every member ran exactly once. **PR1 is now complete — merge
it before opening PR2.**

---

<!-- phase:5 -->

# Phase 5 — Adoption

**PR2.** Thirteen steps: the workflow set, the four test layers with their mutation
passes, fuzzing, coverage, caching, the linter retarget, and lane topology.

Two rules from the front matter that bite hardest here, repeated because a worker
reading only this phase must not miss them:

- **Adopt the convention, keep the content.** A 1:1 copy is wrong by construction —
  the reference's tests test the reference's module.
- **Never delete a gate the target already has.** Anything it checks that the
  reference does not survives, gets a badge and a table row, and goes to
  `skeleton-findings.md` for step 33.

The **rejected-test list** (front matter) applies to every test written in steps
21–26 and every mutation claim in 22 and 24.

## 17 — Port the workflow set

| Workflow | What it must gate in the target |
|---|---|
| `ci.yml` | orchestrator; the ONLY `pull_request` entry point |
| `lint.yml` | the `ci/linter/` gate, hosted runner |
| `build-test.yml` | build, `.so` dlopens, bad config rejected, `-T` survives merged multi-context config, `-Werror`, Test::Nginx, ASan+UBSan |
| `asan.yml` | ASan/UBSan request-storm soak, static `--add-module` |
| `fuzzing.yml` | replay every past crash, then fresh fuzz |
| `valgrind.yml` | memcheck soak |
| `security-scanners.yml` | flawfinder ≥4 blocks, clang-tidy blocks, semgrep ≥WARNING |
| `codeql.yml` | CodeQL over the **module TU only** |
| `ci-deep.yml` | monthly: long fuzz, memcheck, helgrind, nginx mainline+stable+angie matrix |
| `bump.yml` | weekly pin bump + `ci/vendor/nginx-tests` submodule update |

Also port, adapting paths: `.github/versions.env` (single source of truth for
version **and sha256** pins — tarballs verified by digest, not version string),
`.github/scripts/{load-versions,compute-versions,fetch-verify}.sh`,
`.github/actions/build-cache/`, and `.github/actionlint.yaml` (subject to step 13).

**Anything newly ported that is unbounded goes straight to the scheduled lane** —
step 14's split applies to arrivals, not only to what the target already had.

**Acceptance:** `actionlint` clean; every workflow above either present or
explicitly accounted for as not applicable; step 16's greps still hold.

## 18 — Triage the workflows the reference does not have

Rule 2 lives here — this step decides whether the rollout reduces coverage.

**Workflows the target has and the reference does not survive.** One derived module
carries a `runtime-tests.yml` with no reference equivalent; two carry a `bump.yml`
the other six lack. For each, decide and write down which:

- **keep as-is** — it gates something real. Give it a `## CI` row and a badge at
  step 20, and add it to `skeleton-findings.md` for step 33.
- **fold into a reference workflow** — it duplicates a gate under another name.
  State what moved where.

Do not delete one on the grounds that the reference has "the same thing" until you
have compared the actual checks; a same-named workflow often gates less.

**Acceptance:** every extra workflow classified keep/fold with a written reason, and
every "keep" queued for a badge at step 20.

## 19 — Port bands

Test::Nginx binds `TEST_NGINX_PORT`, default 1984, and nothing arbitrates it. A
self-hosted host runs several runner slots against one network, so two jobs on the
default collide and the loser dies with
`bind() to 127.0.0.1:1984 failed (98: Address already in use)` — which reads as a
module regression and is not one.

Presence of `TEST_NGINX_PORT` is not the check. The check is a **distinct job-level
band** per workflow (the reference uses `TEST_BASE_PORT` 19200 in `build-test.yml`,
19400 in `ci-deep.yml`), verified by `ci/tools/max-port.sh` **before the first step
that binds it** — which means before `prove`, not merely before the runtime driver.
Any binder counts, not just the runtime driver: `prove` binds too. The reference
shipped this in the wrong place until 2026-08-02;
`fixtures/policy/verify-after-bind` is the negative control that keeps it right.

Read the target's step ORDER. A target whose driver picks its own free port is
already immune; leave it and say so.

**Acceptance:** each workflow that binds a port declares a distinct band, and
`max-port.sh` runs **before** the first step that binds — quote the step order from
the YAML, not the presence of the verify step.

## 20 — Badges and the `## CI` table

The one thing every reader sees first.

```text
Build&Test, Security Scanners, Fuzzing, Valgrind, CodeQL, A/UBSan, CI Deep
```

with Lint inserted where the `## CI` table puts it, and the two kept in lockstep.

The label text is part of the convention. Measured 2026-08-03: a derived module had
all seven badges in the correct order but wrote `Build & Test` for `Build&Test` and
`Security scanners` for `Security Scanners`. Match spelling and capitalisation
character for character, so a diff across modules shows real differences only.

- badge row order == `## CI` table order == the list above
- an **extra** workflow kept at step 18 goes at the END of both lists, after CI
  Deep, so the shared prefix stays comparable across modules
- every badge must resolve to a workflow that exists — one for a deleted workflow
  renders a permanent grey "no status" and is worse than no badge
- **the URL owner/repo is the target's**, not `myguard-labs/nginx-skeleton-module`.
  A copied badge row pointing at the reference renders green while telling you
  nothing about the target.

**Acceptance:** every badge resolves to a real workflow in the target's own repo; CI
table and badge row in identical order and spelling; `lint-docs-drift.sh` green in
both directions.

## 21 — Unit tests over the real decision TU, with their mutation pass

First of the test layers. **Reuse the reference's harness; do not re-derive it.**
The mutation pass is part of this step, not a separate one — until it runs, the
tests are of unknown value, and splitting it is how it gets skipped under time
pressure.

`ci/tests/unit/` — `run.sh` + `test_scan.c`. Links the target's REAL decision TU and
nginx's REAL `src/core/ngx_string.c`; no shimmed decoder, ever. A shim makes the
layer hermetic and worthless. Reuses `ci/fuzz/ngx_stubs.c`.

Push toward the maximum by targeting, in order: error paths, allocation failure,
malformed/truncated input, boundary values at every `MAX_*` constant, cross-buffer
seams, and the branches gcovr shows as never taken. 100% is not the goal; every
*reachable* branch having a meaningful assertion is.

**Required per new test: a negative control.** Break the code the test claims to
guard (flip a comparison, delete a bound check, swap a constant), confirm the test
FAILS, restore. Note the mutation in the test's comment. Rejected-test items 8–10
are the three ways this goes wrong while looking like success. A surviving mutation
is itself the finding: record it in `adoption-findings.md` and either fix the test
or say why it cannot be fixed.

**Acceptance:** `run.sh` links the target's real `*_scan.c` (grep it, do not
assume); the suite is green; every branch you intended to cover has an assertion on
the result, not merely execution of the line; one recorded mutation per new test,
each shown to make that test fail, named in the test's own comment.

## 22 — The live-server layer, with its mutation pass

`ci/tools/test_runtime.py` — the live-server cases Test::Nginx cannot express:
concurrency, the chunk seam through the real body handler, reload under load.
Retarget the config and marker; keep the shape, **including the baseline case that
proves the module is loaded and blocking before anything else runs**.

### What belongs here, and what belongs in `ci/t/`

The driver is the expensive layer: it owns a whole server, and its cases are
invisible to the harness's error-log and servroot assertions. Put a case here only
when Test::Nginx genuinely cannot express it. The line, measured rather than assumed
(2026-08-07):

- **Stays in the driver** — many requests *in flight at once* (concurrency), and
  anything driving a signal at the master while traffic runs (reload under load).
  Test::Nginx is one request at a time; neither shape survives the move.
- **Stays in the driver, less obviously** — a property asserted over *N separate
  requests that each need their own connection*, such as splitting a marker at every
  interior byte, one chunk per side. `--- raw_request` with an arrayref looks like
  it expresses this and does not: `Test::Nginx::Socket::get_req_from_block` turns an
  arrayref into **one** request split into packets, not N requests. A flattened list
  of N requests therefore sends one giant request, the first status line matches,
  and the file passes while asserting nothing. This was tried, went green against the
  `keep = 0` seam mutation that the driver catches, and was reverted.
  `--- pipelined_requests` is not the fix either — those share one connection, so no
  case in the batch can carry `Connection: close`.
- **Belongs in `ci/t/`** — a single request with a single verdict, including one
  hand-picked buffer straddle. Cheaper there, and it gets `--- error_log` for free.

So the migration to make is the reverse of the tempting one: do not move the seam
cases out of the driver. Do keep the driver's baseline/clean/off cases even though
`ci/t/01-modes.t` covers the same ground — they are this file's own
loaded-and-blocking control, and without them a module that failed to load reads as
a run of green allow-cases.

### Audit what you added — the driver accretes

The driver is the path of least resistance: plain Python, so a case that would have
been six lines of `ci/t/` DATA gets written here instead, then runs on every push
inside a private server nobody's error-log assertions can see. If the target arrived
with its own runtime driver, or you added cases, go through them once.

For each case, ask: **does it need more than one request in flight, a signal at the
master, or its own connection per assertion?** No to all three → it belongs in
`ci/t/`. Rewrite it there, confirm the test count went up by what you moved, and
delete the driver case in the same commit — a case left in both places is worse than
either, because the next person to change the behaviour fixes one and ships the
other still asserting the old contract.

Do not take a green as proof the move was faithful. Port a case, then break the
behaviour it covers and confirm the NEW location goes red.

### Cost

The driver runs on every push, so a fixed sleep is paid forever. Assert on an
**observed** event, not on a nap: wait for the master's `start worker process` lines
to reach the expected count rather than sleeping either side of a SIGHUP. In the
reference this cut `test_reload_under_load` from 5.01s to 0.12s *and* strengthened
it — the sleeping form never checked that a reload completed while requests were in
flight.

### The mutation pass

Same requirement as step 21, over a layer where it is easier to fake: a runtime test
can pass because the server came up at all.

- **The baseline case must fail when the module is not loaded.** Prove it by
  unloading the module, not by reasoning about the config.
- The concurrency and reload cases each need their own recorded mutation.
- Beware rejected-test item 4, the shared counter: if the mutation at site A is
  caught by an assertion site B also satisfies, the test attributes nothing.

**Acceptance:** the suite is green; every remaining driver case is justified by one
of the three exemptions, with anything else moved to `ci/t/` and its move proved by
a red in the new location; the baseline case observed failing with the module
unloaded; the concurrency and reload cases each with a recorded mutation that made
them fail.

## 23 — The fuzz target, corpus and dictionary

Fuzzing is per-module work; a copied harness driving the skeleton's rule table
proves nothing about the target.

- The fuzz target must call the **real** decision function with
  `(const uint8_t *, size_t)`, not a reimplementation. That seam is steps 8–10's job
  and should already exist. If it was parked and does not, do not stop: record in
  `adoption-findings.md` that the real decision function is unreachable, mark this
  step degraded in the PR body, and continue with the parts that do not need it. **A
  fuzz target driving a reimplementation is worse than none, so do not build one.**
- Seed corpus from the module's actual domain: real headers/bodies/config values it
  parses, plus every past crash under `ci/fuzz/regressions/`.
- `fuzz.dict` with the module's real tokens, **derived from the target's own parse
  surface** — a dictionary of the skeleton's tokens actively misdirects the fuzzer.
- **If the target's tokens live in a table in its source, GENERATE the dictionary
  from that table and gate the drift** — a script extracting every literal, plus a
  `--check` mode wired into `ci/linter/`. A hand-listed dictionary goes stale
  silently: adding a signature and forgetting the dictionary does not fail the fuzz
  gate, because a merely incomplete dictionary still produces a green crash-only run.
- **Do not judge that by edge coverage.** Measured downstream: deriving the
  dictionary moved `cov` not at all (199 on both arms) while signature reach went
  23 → 35 of 645 table literals actually driven through the differential oracle in
  60s from an empty corpus. A trie-walk scanner executes the same edges whichever
  literal arrives, so coverage is the wrong instrument — the question is how much of
  the table the fuzzer ever reaches.

**Keep the fresh-fuzz run bounded** (step 14): a `-max_total_time` in the low
minutes on the PR lane, the campaign on `ci-deep.yml`.

**Acceptance is conditional:** with a reachable seam, the fuzz target builds and
links the target's real `*_scan.c`, by grep, and the target-derived corpus and
dictionary sizes are stated. Without one, the finding names the unavailable seam, no
substitute fuzz target was created, and the step is explicitly degraded.

## 24 — Replay order and the ASan soak

Two gates that are green by default and prove nothing by default.

- **Replay-then-fuzz order in `fuzzing.yml`**: recorded regressions first (fast,
  deterministic), then the time-boxed fresh run. A crash that returns must fail in
  seconds, not after the fresh budget.
- **The ASan soak (`asan.yml`) must drive the module's real request shape** — its
  directives enabled, its body path exercised — not a default config where the
  handler never runs. Verify it reaches the module with evidence: a counter, a log
  line, or coverage from the soak build. This is the unreached-code class: a soak
  against a config the handler never sees is clean forever.
- Keep the ASan build static (`--add-module`); a dynamic module under ASan loses
  interception on the parts that matter.
- The soak itself runs on the scheduled lane (step 14). What this step proves is
  that it is **configured to reach the module**, not that it has finished. Phase 7
  reads its conclusion.

**Acceptance:** a deliberately reintroduced past bug is caught by the replay step in
seconds (verify once, then revert), and the evidence that the soak reaches the
module, quoted in the PR body.

## 25 — Adapt the three neighbours

Each is a file that keeps reporting success while pointed at the wrong target:

- `valgrind.supp` — needs **target-specific** nginx-core suppressions. A copied one
  can suppress the module's own errors.
- `codeql.yml` — the TU filter needs the target's file names, or CodeQL analyses
  nothing and passes.
- `ci-deep.yml` — the matrix needs the target's nginx/angie compatibility range, not
  the reference's.

**Acceptance:** each names the target's own paths/versions, shown by grep; and for
`codeql.yml`, the analysed-TU count from a real run is non-zero.

## 26 — Coverage as a report

Fourth test layer. `ci/tools/coverage.sh` + the `coverage` mode in
`ci/tools/ci-build.sh` — a distinct build tree, never a flag bolted onto `debug`, so
a cached non-instrumented tree cannot produce a 0% report that reads as a finding.
`gcovr` filtered to `src/` only; an unfiltered run drowns the module in 200k lines
of upstream nginx.

**Coverage is a REPORT, not a gate.** The cheapest way to move the number is tests
that touch lines and assert nothing, so a floor buys a metric and sells the thing it
proxied for. Publish from `ci-deep.yml`; gate on the mutations recorded beside each
suite. `COVERAGE_FAIL_UNDER` exists for a target that decides otherwise.

Watch the option spelling: `--gcov-object-directory` fails argparse on gcovr below
7.0. The condition is the gcovr major version the job actually runs, not whether a
pin exists. `--object-directory` is accepted by both.

**Acceptance:** the reported figure moves when a test is deleted (prove it, then
restore); the filter names the target's `src/`.

## 27 — Retarget the linter checkers to the target

Step 6 installed the tooling. This step points it at the target — it waits until
here because the checkers select on `src/`, which step 12 created, and because
promotion is a measurement over the target's post-seam C.

**Every linter is RETARGETED to the module, not copied.** A checker carried over
verbatim runs against the reference's paths, symbol names and thresholds, and
reports clean because it matched nothing. Walk the whole set — `ci/linter/lint-*.sh`
and `.pre-commit-config.yaml` — and for each, adapt then prove it can still fail:

| What is reference-specific | Retarget to | Prove it |
|---|---|---|
| file selectors (`^src/.*\.[ch]$`, `ci/t/*.t`) | the target's real layout | the checker reports a non-zero file count |
| `lint-nginx.sh` conventions | the target's prefix (`ngx_http_<mod>_`), include order, column limit | plant a violation, see it blocked |
| thresholds in `lint-c.sh` | whatever `security-scanners.yml` uses **in the target** — move one, move both | list the pairs |
| `LINT_ONLY` in `lint.yml` | the target's checker set | `selftest.sh` set-equality case |

A threshold is a measurement, not a copy. Where a checker offers a severity tier,
gate the tier whose findings were confirmed real on the target's own code and leave
the noisy tier advisory — a gate that lands a repo red on arrival trains everyone to
`--no-verify`, which costs more than the findings were worth.

**The checker SET is the target's; the entry point is the standard's.** The
convention is `run-all.sh` + `LINT_ONLY` + exit codes (`0` clean, `1` findings, `2`
tool missing) + the tracked hook. Behind it:

- a module with no Perl needs no `lint-perl.sh`; one with Lua or Rust needs a
  checker the reference lacks. Add `lint-<name>.sh` — `run-all.sh` picks it up by
  glob — and give it a row in the linter README. A checker the reference lacks also
  goes to `skeleton-findings.md`.
- **keep every checker the target already ran** (rule 2), behind the same entry
  point rather than dropped because the reference lacks it.
- `c` is absent from `LINT_ONLY` and that is not an oversight to "correct":
  `security-scanners.yml` already runs flawfinder/cppcheck/semgrep over `src/` at the
  same thresholds, so running them again per PR buys only queue time. Every OTHER
  checker must be listed — one no workflow runs gates the hook and never a PR.
- the **repo-policy** checks do not transfer unexamined: `ci-runners` depends on
  `TRUST_SPLITS` being rewritten (step 13), and `ci-ports` is meaningful only if the
  target binds a fixed band. `ci-cadence` assumes the single-orchestrator topology of
  steps 15–16, so it is live only now. `ci-secrets` is **vacuously green on a target
  that declares no secrets**, which is most of them and is the correct state — say
  which half applies rather than reporting it as covered. `sync-stamp`'s value is
  entirely in the OTHER direction: it tells the reference which adopter drifted.
- `lint.yml`'s `LINT_ONLY` string diverges with the checker set, and it is not a
  constant to copy — read the reference's current value rather than any string quoted
  in a document, this one included. **Compare normalized sets:** strip the directory,
  `lint-` prefix and `.sh` suffix from every `ci/linter/lint-*.sh`; split `LINT_ONLY`
  on whitespace; sort both uniquely. The allowlist is narrower than the glob
  `run-all.sh` discovers, so a checker missing from it runs locally and in the hook
  while being **absent from every PR**. Not hypothetical: `lint-ci-cadence.sh`
  shipped here 2026-08-06 and had never run remotely when it was noticed. Port the
  `selftest.sh` case, not just the current string.

**Every checker states what it selected, and an empty selection is exit 2.** This
applies to the target's OWN checkers as much as the ported ones. Every checker in
`ci/linter/` prints a count (`lint-c: 7 file(s)`) and that is why none of them could
hide the way step 11's moved checker did.

**Thresholds mirror `security-scanners.yml`** — move one there, move it here in the
same commit, or the two drift and the local gate stops meaning anything.

**Run the deferred probe now, before PR2 merges:** step 12's empty-selection probe
(`LINT_ONLY="c nginx" ci/linter/run-all.sh` must exit 1 with a `malloc`/`strcpy`
planted beside the real C).

**Acceptance:** `run-all.sh` exits 0 clean, 1 on findings, 2 on a missing tool —
observe all three, the last by hiding a tool from `PATH`. A staged file with a deliberate finding is
blocked by the hook — **one per language present in the target**, each shown blocked.
`LINT_ONLY=ci-cadence ci/linter/run-all.sh` green. The normalized `LINT_ONLY` and
checker-script sets match exactly. Every threshold matches its
`security-scanners.yml` counterpart, listed pair by pair. Step 12's probe exits 1.

## 28 — Caching, and the speed budget

Every build goes through `ci/tools/ci-build.sh`; no workflow duplicates cache logic.
Layers, cheapest first: apt/packages, ccache (`CCACHE_COMPILERCHECK=content`), mold
(**skipped under ASan**), eatmydata (wrap configure/install; never wrap something
whose durability matters), build tree (`.build/nginx-<ver>-<mode>`, keyed on mode +
version + `hashFiles(ci-build.sh, config, src/**)`), source tarball (keyed on
version, sha256 verified after restore).

Load-bearing rules:

- nginx's `configure` **ignores a bare `CC=`** — ccache must be wired through the
  configure argument the reference uses, not via env.
- ccache may use a `restore-keys` ladder (content-hashed; a partial hit cannot serve
  a wrong object). The **build-tree cache stays exact-match only** — do not "fix"
  that for consistency.
- Hybrid restore (on-disk warm dirs + `actions/cache` fallback) stays. Deleting the
  fallback because the runners are persistent is how this degrades silently the day
  they become ephemeral.
- GitHub scopes caches **by ref**: a PR run writes `refs/pull/N/merge` and cannot
  read a branch's entries. A cold PR run is not a bug.
- A cache must never serve a stale artifact into a green result. If a key cannot
  express what invalidates it, do not cache that layer.

**The speed budget: the whole hook under ~2s on a one-file commit.** A gate people
wait on is a gate people bypass with `--no-verify`. Over budget → scope the slow
checker, never drop one, never a default-on skip flag. Three, each measured:

- **`semgrep --metrics=off`** — the telemetry POST was 2.76s of a 2.76s scan.
- **`semgrep --jobs=1`** — a *correctness* flag. semgrep-core opens one io_uring ring
  per OCaml domain against the host's 8 MB `RLIMIT_MEMLOCK`, shared with every other
  job; when the runners are busy it aborts with
  `Unix_error: Cannot allocate memory io_uring_queue_init`, exit 2 — a red gate
  caused by a neighbouring job. Reproduced 3/3 busy, 0/3 idle, so an idle-box green
  tells you nothing. `security-scanners.yml` carries the same flags.
- **`run-all.sh` fans checkers out** (`LINT_JOBS`). Buffer each checker's output and
  replay it whole in fixed glob order — never interleaved: findings carry a
  `file:line` but not a checker name. Each child writes its exit status to a file;
  the reaping `wait` is collective, and a **missing** status file (child SIGKILLed)
  must count as a failure, never a pass.

**Check `/proc/loadavg` first** — on the build host at load ~50 the same full-tree
run varied 2.2s–12.4s over six attempts, a spread wider than the whole improvement.

**Acceptance:** a second identical build reports a non-zero ccache hit rate — 0% on
an identical rerun means ccache is not wired, whatever the log says. Every layer's
key names what invalidates it. Every probe in the linter README's "Verify before
trusting" section observed red *after* the speed work — `--jobs`/`--metrics` are
exactly the flags that can silently turn a checker into a no-op. Then run with two
checkers failing at once and confirm both appear and both are named in the
`== FAIL:` line.

## 29 — Measure durations, build the lanes, write the map

CI wall-clock on a self-hosted host is dominated by jobs QUEUEING for a
label-matching slot. **Hosted-only targets skip the lane work** — say so and record
the measurements anyway.

```sh
gh run view <id> -R <owner>/<repo> --json jobs \
  -q '.jobs[] | [.name, .conclusion,
                 (((.completedAt|fromdate)-(.startedAt|fromdate))|tostring)+"s",
                 .startedAt, .completedAt] | @tsv'
```

Keep `startedAt`/`completedAt`, not just durations — the gaps show queueing. Count
the real slots too — `systemctl list-units | grep ci-ephemeral` (six on the
reference's host) — and check `/proc/loadavg` before trusting any timing.

**Then build the lanes.** At most four.

1. Identify the longest single **job**. That is the budget; no arrangement finishes
   sooner. Chain **nothing** behind it. Pairing the longest job with a follow-up "to
   keep the lane busy" is the most common way this gets worse — it is what put the
   reference's lane A at 348s against a 268s budget.
2. Build the **fewest lanes that fit**, four maximum, each a chain of `needs:` where
   a long job releases its slot to a shorter independent follow-up. No lane exceeds
   the budget. Three that fit beat four that also fit.
3. Does not fit in four? Move a check out-of-band (monthly), time-box it, or put it
   on a hosted runner — not "add a fifth".
4. **A lane is not a slot.** Count real slots, and remember a reusable workflow fans
   out: the reference's Build&Test is *five* jobs, so observed peak is 7 against 6
   slots. Brief oversubscription at t=0 is acceptable; writing "caps peak at three"
   when it is seven is not.
5. Hosted jobs (lint, CodeQL) take no self-hosted slot and are **not laned at all** —
   no `needs:`, start immediately.
6. Follow-ups use `if: ${{ !cancelled() }}` so a failing first check does not
   suppress an unrelated second one, and so a chain survives an earlier job being
   *skipped* by a changed-files gate.
7. Concurrency groups must not collide. A called workflow inherits the caller's
   `github.workflow`/`github.ref`; an identical group string makes a member cancel
   its own caller and a whole lane dies before it starts. Prefix the orchestrator's
   group distinctly.
8. Path-gating a reusable workflow does not work. Gates move to a `changes` job in
   the orchestrator with an explicit job-level `if`. That diff job must **fail
   loudly** on an unusable diff, never fall through to "no relevant changes" —
   failing open skips the sanitizer on exactly the PRs that need it.

**Write the lane map into the orchestrator header.** A deliverable, not a note: the
header comment is the **only** place this design is written down. It carries the lane
map, the measured durations, the run ID and date they came from, and the command to
re-derive them. **Any lane change rewrites that comment in the same commit** — a
stale lane map reads as measurement and gets trusted. Record the same map in the
memory mirror.

**Acceptance:** a per-job table with `startedAt`/`completedAt`, the run ID and date,
and the slot count; no lane exceeds the budget; the fullest lane's headroom stated;
rules 4–8 each answered against the target's own YAML; the header comment contains
the map, run ID and date, and the re-derive command reproduces them. **PR2 is now
complete — merge it before opening PR3.**

---

<!-- phase:6 -->

# Phase 6 — Depth pass and close out

**PR3 opens here.** Six steps. Phase 5 installed the gates; this phase asks whether
any of them would catch anything, then closes the job out.

**This phase reads configuration and evidence — it does not run soaks.** Every
long-runner was demoted to the scheduled lane at step 14 and is exercised in phase 7,
where the steps that read its conclusions live. A depth-pass step that starts a
campaign is doing phase 7's job at phase 6's cost.

## 30 — The depth audit: does each gate reach the module?

One step, five subjects, one question each. All five are the same failure — a gate
pointed somewhere the module is not — and all five are answered from configuration
plus step 26's coverage report, not from a run you start here.

| Subject | The question | The evidence |
|---|---|---|
| **the seam** | do the unit and fuzz builds still compile the target's real `*_scan.c`? | grep both entry points. Re-derive `UNIT_ENTRY` from step 8's todo record — it does not carry over between sessions, and grepping a path the target never had is silent, not "no hit" |
| **ASan/UBSan** | does the soak's config reach the module? | the directives enabled in the soak config, plus step 26's coverage showing the handler's lines executed. Not a soak run |
| **fuzzing** | can the surface be widened? | the corpus and dictionary against the target's parse surface; which table literals are reachable |
| **coverage** | is it measured over the module only? | the gcovr filter names the target's `src/`; the figure is not ~1% (which means nginx core is in the denominator) |
| **valgrind / helgrind** | is memcheck pointed at the module, and is helgrind applicable at all? | `valgrind.supp` names the target's own suppressions and does not suppress its errors. **Helgrind is applicable only if the module has shared cross-worker state** — prove it either way with the `file:line` of the shared structure, or its absence |

For each: state what it would now catch that it did not before. A "verified correct"
with no evidence attached is not an answer.

**Acceptance:** all five answered with the evidence named; helgrind's applicability
settled with a `file:line`; no long run started by this step.

## 31 — Re-audit the gates that drift

Six things that no run reports red, which is why each needs an explicit answer.

- **Caching.** Audit `ci-build.sh` as the single chokepoint; no workflow duplicates
  cache logic. Report the ccache hit rate from a warm run; 0% on a second identical
  run means it is not wired, whatever the log says.
- **`zizmor` findings drift with the workflow set.** Every workflow added since step
  6 is new attack surface it now audits. Confirm the count of audited workflows
  matches `.github/workflows/`, and that each `# zizmor: ignore[rule]` still names a
  reason that is still true. A suppression outlives the thing it suppressed.
- **`actionlint` remains blind to the `fromJSON` ternary** (step 13). Do not read a
  clean actionlint as evidence about runner labels; that is probe 2's job and probe
  2 only.
- **`LINT_ONLY` still matches the checkers that exist**, using step 27's normalized
  comparison. If the `selftest.sh` case was ported this is a re-run; if not, say why,
  because the set diverges every time a checker is added and the gap is invisible
  from a green run.
- **`run-all.sh` reads `git ls-files`** — a new untracked file is invisible to the
  linter. Stage before trusting a clean run.
- **Re-time the hook** against the ~2s budget, `/proc/loadavg` checked first.

**Acceptance:** an explicit answer to each. "Checked, fine" is not one — each needs
the count, string, rate or timing it asked for.

## 32 — Re-measure the CI shape

Only with numbers from `gh run list`:

- Re-check step 29's lane topology against **measured** wall-clock, not the estimates
  in place when it was written. Lanes drift as tests are added.
- Confirm exactly one `pull_request:` entry point still holds, and that every member
  is reached — a member called by nobody keeps a stale-green badge and goes grey only
  when deleted. Re-run the double-run proof if anything moved.
- Confirm step 14's demotion still holds: re-run step 16's long-runner greps. A
  workflow added during phase 5 arrives with whatever triggers its author copied.
- Check `/proc/loadavg` before timing anything.
- Optimise by moving work off the merge path into `ci-deep.yml`, never by deleting a
  check or widening a threshold.

**Acceptance:** the measurement for each bullet, and for every gate the one sentence
stating what it would now catch that it did not before.

## 33 — Hand the findings back to the skeleton

`$SCRATCH/skeleton-findings.md` is the deliverable. It has accumulated since step 1:
bugs in ported scripts, rules here that were wrong or ambiguous, gates the target had
that the skeleton lacks (rule 2), checkers the reference does not carry.

Open **one PR against `myguard-labs/nginx-skeleton-module`** — the only write to the
reference repository in the whole job:

1. **Fix what you can fix in code.** A bug in `ci/tools/`, `ci/linter/`, a workflow
   or this `PROMPT.md` gets the actual change, with the target's `file:line` as
   evidence in the PR body. That is the preferred form.
2. **Describe what you cannot.** Anything needing a decision, a measurement on
   hardware you do not have, or a change whose blast radius crosses every derived
   module goes in `ci/feedback/<target>-<YYYY-MM-DD>.md` in the same PR: what was
   found, where, what it cost, and the proposed change.
3. One PR, both kinds together. Remote CI green, no AI attribution, signed commits.

An empty `skeleton-findings.md` means no PR — say so in the report. Do not
manufacture a finding to have something to send.

**Acceptance:** either the PR URL, or an explicit "no skeleton findings" line.

## 34 — Docs, memory mirror, and the adoption stamp

Three records, one step. All three are what a future session reads instead of
re-deriving.

**Docs.**

- README rewritten, not appended to: badge row, `## CI` table, layout tree,
  Requirements, and a Linting section linking `ci/linter/README.md`.
- `CONTRIBUTING.md` tells a contributor how to enable the hook.
- `CHANGES` entry describing the standardisation.

**Memory mirror.** Skip only for an external target with no mirror, and say so.

- `index.md` — layout, lane map, measured times, **and the skeleton commit you
  adopted from**. That anchor is what phase 0's forwarding route depends on.
- `issues.md` — everything in `adoption-findings.md` that is still open.
- `lessons.md` — every trap that cost a red CI round-trip, `[RECURRING]` if it has
  bitten before.
- A trap that is a *class* rather than a typo goes into the matching
  `.claude/skills/audit-*/` reference, not only memory.

**The stamp.** Write `ci/.adopted` — this is what makes phase 0 cheap next time:

```text
prompt_version: <ci/tools/prompt-section.sh --hash, from the reference>
skeleton_sha:   <reference commit adopted from>
adopted_date:   <YYYY-MM-DD>
steps_degraded: <comma-separated step numbers, or none>
```

Without it, the next session cannot tell a completed adoption from an abandoned one
and re-runs all 42 steps.

**Acceptance:** `lint-docs-drift.sh` green in both directions — every workflow has a
`## CI` row and every row a workflow; the adopted skeleton SHA is in `index.md`;
every open item from `adoption-findings.md` appears in `issues.md`; `ci/.adopted`
exists with all four fields.

## 35 — Prepare the completion report

Prepare, but do not send. Phase 7 updates and sends it after the aftermath. Per PR:
what landed, what is red, what remains and why. Include measured before/after
wall-clock and coverage. Seven questions it must answer explicitly, because they are
what a greenfield reading gets wrong:

1. **Entry points** — how many workflows carried `pull_request:` before, and
   confirmation exactly one does now.
2. **Runners** — which pool the target runs on. If any `self-hosted` selector
   survives, the output of probe 2 (step 13) proving the target's own gate rejects
   the reference's label. "Adapted the labels" is not an answer.
3. **Long-runners** — every workflow demoted at step 14, its bound, and where it
   runs now. A soak silently left on the PR lane is the failure this job exists to
   prevent.
4. **Extra workflows and gates** — every check the target had that the reference
   lacks, and whether each was kept, folded, or sent upstream at step 33. If any was
   removed, what covers it now.
5. **Badges** — the final row, so order and spelling can be compared without opening
   the repo.
6. **Parked and degraded** — every step you could not complete: which one, the
   symptom, the three attempts, and what a human has to decide. Also every gate you
   degraded. The run does not stop, so this is where unfinished work is accounted for.
7. **Anything left disabled, skipped or unverified** — a workflow not enabled, a soak
   whose conclusion phase 7 has not read yet, a gate never seen red. Silence here
   reads as coverage that does not exist.

Do not report a step complete on a gate you never saw fail.

**Acceptance:** the report exists, unsent, with all seven answered.

---

<!-- phase:7 -->

# Phase 7 — Aftermath

**Continues PR3.** Steps 36–42 run in order after migration, forwarding, or a no-op.
Do not ask whether to run them. Record evidence for every `not needed` result.

**This is where the long-runners are exercised.** Step 14 demoted them to the
scheduled lane so no mid-run step waited on one; here their conclusions are read,
once, by the steps that need them. Dispatch them early in the phase (step 38) so they
run while steps 39–41 proceed — but never sit in a poll loop.

## 36 — Recheck the implementation

Re-read this prompt against the merged result, step by step, and report which of the
35 prior steps are genuinely done, which are partial, and which were skipped.
Independent of your own report at step 35 — a fresh reading, so do not consult it
while doing this.

## 37 — Check linter coverage: languages and rules

Verify the linter set actually covers what the tree contains, and that each linter
runs with the rules it needs. This is the post-move re-derivation: steps 6 and 27
kept every checker the target ran, but by now the file set has moved.

- **Languages.** Enumerate tracked files with their paths intact. The linter
  inventory selects on paths, not extensions, so an extension histogram cannot tell
  `.github/workflows/*.yml` from any other YAML and drops extensionless files such as
  `.githooks/pre-commit`, `Dockerfile` and `config` entirely:

  ```sh
  git ls-files | awk -F/ '{ b = $NF; e = (b ~ /\./) ? b : "(none)"; sub(/.*\./, "", e);
                            print e "\t" $0 }' | sort | uniq -c | sort -rn
  ```

  Classify extensionless basenames by content (`file`, or the shebang), not by name.
  Map each group to the linter that reads it. Every group with a meaningful share and
  no linter is a gap: install the tool, register it in `run-all.sh` and the
  pre-commit config, or record why it is genuinely not applicable.

  Three failures, all of which report clean: **a language present with no checker**;
  **a checker whose language left the repo** (it passes on an empty selection
  forever — remove it or say why it stays); **`LINT_ONLY` naming a checker that does
  not exist**, or omitting one that does.
- **Rules.** For each configured linter, compare the enabled rule set against the
  tool's full set — the default profile is usually a subset. Enable the security,
  correctness and portability rules the module needs; justify each deliberate
  suppression inline rather than blanket-disabling a category.
- **Blind spots.** A linter present but never reaching a path is not coverage.
  Confirm each one's file selection matches the paths it guards, including
  untracked-then-added files and vendored dirs excluded on purpose.

**Acceptance:** a table of file type → linter → rule profile, with every gap either
closed in PR3 or carrying its evidence-based not-applicable result; the normalized
`LINT_ONLY` and checker-script sets match per step 27.

## 38 — Kick off the scheduled workflows

Start these **now**, at the top of the phase, so they run while steps 39–41 proceed.
Dispatch and move on — do not poll.

For each scheduled lane (`ci-deep.yml` monthly, `bump.yml` weekly, plus every
long-runner demoted at step 14), verify the workflow exists and reports itself active
(`gh workflow view`), then trigger it (`gh workflow run`). If a lane was proven not
applicable, record that evidence instead of inventing or invoking it.

**State the runner cost before starting**: a deep run is long, and on a self-hosted
pool it occupies slots other work needs.

**Acceptance:** every scheduled lane dispatched with its run URL recorded, or its
not-applicable evidence. Conclusions are read at step 41.

## 39 — Review the changes `[opus]`

A diff review of every PR this job landed, one maintainer voice, regressions and
contract drift.

## 40 — Full code review `[opus]`

Audit the module's own C, not just the CI: memory safety, parser boundaries, error
paths, and concurrency. Put bounded fixes from steps 36–40 in PR3; park larger
independent changes with evidence rather than creating step PRs.

## 41 — Read the soak conclusions, broaden coverage and dynamic analysis

Step 38's runs should be finished or close to it. This is the only step that reads
their conclusions, and the only place a soak result is required.

**Which soaks are applicable.** Step 30 settled helgrind: no shared cross-worker
state, record the evidence-based not-applicable result. The same rule governs
memcheck, keyed on the request surface instead. A soak is applicable if the module
registers anything on the request path — a content or access handler, a header or
body filter, or a phase handler installed at `postconfiguration`. Nearly every module
does; if this one clearly does, say so in one line.

Claiming a soak is **not** applicable is the exclusionary case and needs the same
evidence step 30 demands: the `file:line` proving the module registers no such
callback. "No request surface" is a statement about code, so it is checkable, and it
has already been claimed and been false. A real adoption asserted it for a module
whose `nla_upstream.c` registers phase handlers, filters and a CORS content handler,
with `ci/t/*_e2e.*` driving it over live HTTP the whole time; the claim came from
reading the directives and not the registrations. Narrowing the soak set on that
assumption is the same failure as skipping it: the report is clean because nothing
ran.

**Whether a re-run can be skipped.** If step 38's dispatch is still running and the
code has not moved since a previous green deep run, the earlier result stands:

```sh
LAST=$(gh run list --workflow ci-deep.yml --status success --limit 1 \
    -R <owner>/<repo> --json headSha --jq '.[0].headSha // empty' 2>/dev/null || true)
if test -z "$LAST" || ! git cat-file -e "$LAST^{commit}"; then
    echo 'no valid last-green baseline: wait for step 38 dispatch'
else
    git diff --stat "$LAST"..HEAD -- config src/ ci/ .github/workflows/ \
        .github/versions.env
fi
```

Workflow definitions are included because they own the commands, runners and flags.
Note the deliberate inclusion of `versions.env`: `bump.yml` bumps pins weekly and
`ci-deep.yml` runs monthly, so a module with **zero source commits can still be
running against a new nginx**. Commit recency in `src/` alone is the wrong clock. A
submodule bump of `ci/vendor/nginx-tests` counts the same way.

**Then broaden.** Valgrind memcheck and reachable fuzz targets were ported at their
reference shapes and verified to reach the module (step 30). Cover concrete reachable
gaps with the smallest useful target, corpus case, time-box, applicable helgrind
path, or memcheck request shape.

**And coverage.** Report the current figure and the branches gcovr shows as never
taken, then add meaningful cases for reachable gaps, each with its negative control.
Coverage stays a report, not a gate (step 26); never chase a number alone. If the
honest answer is that the remaining uncovered lines are unreachable, say that instead
of offering.

**Acceptance:** the applicable soak set stated either way — one line when the module
plainly has a request surface, the `file:line` of the absent registration when
excluded; each applicable soak's conclusion read with its wall-clock, or the proven
qualifying green baseline it stands on; the coverage figure with the branches added
and their negative controls. A silent skip is indistinguishable from a soak that
never existed, and a silent narrowing is indistinguishable from a silent skip.

## 42 — Residue, gitlink, and the final report

**Anything left uncommitted or unpushed.** Report either way.

```sh
git -C <TARGET> status --porcelain          # untracked or modified
git -C <TARGET> log --branches --not --remotes --oneline   # committed, unpushed
git -C <TARGET> stash list                  # never yours, but say if one exists
```

Two classes, and only the first belongs to this run:

- **work of yours that never landed** — a file written and never staged, a commit
  never pushed, a memory-mirror update made in the working tree only. `run-all.sh`
  reads `git ls-files`, so a new untracked file was also invisible to every linter
  that "passed" over it.
- **the dirt recorded at step 1** — it was there when you arrived. Confirm it is
  byte-identical to what you recorded and leave it alone. Do not offer to commit it;
  it is not yours and the owner cannot find it later if you do.

Recreate step 1's status, worktree patch, index patch and sorted untracked hashes
under new `$SCRATCH` names, then compare each pair with `cmp`. Any mismatch is a
finding and is left untouched; a matching path list alone is insufficient.

**Unresolved bot replies across every PR you opened.** A review bot replies on its
own schedule. CodeRabbit rate-limits per developer (measured 2026-08-04: "next review
available in 51 minutes"), so a review can arrive **after** you merged, and a reply to
your reply arrives later still. A merged PR is not a closed conversation, and nothing
notifies you. Enumerate every bot comment on each PR number, both the review-comment
and issue-comment endpoints, filtering on a `[bot]` login and looking for
`limit reached` / `could not start` notices.

Two things to look for, and they differ: **a finding you never answered** — a
top-level bot comment with no reply from you; verify it against the code like any
other, fix or refute with the `file:line` that disproves it. **A review that never
ran** — a "review limit reached" or "could not start" notice means that commit was
never examined at all. A green checks list does not distinguish this from a clean
review. Say which commits were unreviewed rather than implying coverage you did not
get. A confirmed finding that is a recurring *class* rather than a typo goes to the
narrowest matching `.claude/skills/audit-*/` reference — the skill runs unprompted
next time.

**Load `/pr-create` before writing any of those replies** — a reply to a bot is PR
writing, however small it feels, and the skill is mandatory for it.

**The superrepo gitlink.** Check separately, because it is invisible from inside the
target and every other check can pass while the gitlink is wrong.

```sh
git -C /opt/myguard diff --submodule=short -- <path/to/target>
git -C /opt/myguard log --oneline -3 -- <path/to/target>
```

If the target is a myguard submodule, every merged PR needs its bump on the
superrepo's `master`. A missing one means the superrepo still points at the
pre-adoption commit. An external target has no gitlink — say so and skip.

**Acceptance:** both residue classes reported with their paths, or an explicit
"nothing outstanding"; every bot finding answered or listed as unreviewed with the
unexamined commits named; the superrepo's gitlink resolving to the target's current
default head, shown by SHA, or an external-target skip proven. Update the step-35
report with every aftermath result, PR URL, remaining finding, and current
target/gitlink SHA; then send that final report.
