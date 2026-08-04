# Prompt — adopt the myguard skeleton standard in an nginx module

Point a fresh session at this file and one module path. Nothing else is needed:

```text
Read /opt/myguard/labs/nginx-skeleton-module/ci/PROMPT.md and apply it to
<TARGET>.
```

`<TARGET>` is any nginx module checkout — ours or someone else's, with existing
CI or none. The reference implementation is
`/opt/myguard/labs/nginx-skeleton-module` (this repo). Written for an agent with
repo write access; reads as a checklist for a human.

## The job

Give the target the reference's **layout, gates, workflow set, badge row, linter
entry point and conventions**, expressed over the target's own code and tests.

**56 steps in 7 phases.** Steps are numbered 1–56 continuously and referenced by
number throughout. **A step is a grind unit, not a PR** — it is sized so a cheap
model can do it with this file and nothing else: one input set, one acceptance
check, one thing to hold in your head at a time. Several consecutive steps
usually land as one PR; the PR column below says how many.

| Phase | Steps | What it is | PRs |
|---|---|---|---|
| 1 | 1–3 | preconditions, inventory, baseline | none (read-only) |
| 2 | 4–6 | the decision seam — the one C refactor | 1 |
| 3 | 7–12 | layout and runner identity | 2 |
| 4 | 13–34 | workflows, tests, fuzzing, caching, linter, lanes | 8 |
| 5 | 35–42 | depth pass — would any of it catch anything? | 1–8 |
| 6 | 43–48 | close out: skeleton feedback, post-adoption checks, docs, report | 1–3 |
| 7 | 49–56 | aftermath — offered, not taken | 0 |

Phase 5 runs only after every phase-4 step has merged. Phase 7 is the only phase
that is not part of the job: it is offered at the end and done only if asked.

**Which steps share a PR** — the boundaries are fixed; do not merge a partial group:

| PR | Steps | Phase |
|---|---|---|
| 1 | 4–6 | seam: probe, extract, wire |
| 2 | 7–9 | `ci/` move, path climbs, `src/` |
| 3 | 10–12 | runner identity across three files, both probes |
| 4 | 13–18 | orchestrator demotion (13–15) + workflow set (16–18) |
| 5 | 19 | badges and the `## CI` table |
| 6 | 20–21 | unit tests + their mutation pass |
| 7 | 22–23 | runtime layer + its mutation pass |
| 8 | 24–26 | fuzzing and ASan, retargeted |
| 9 | 27 | coverage |
| 10 | 28–32 | caching and the linter gate |
| 11 | 33–34 | lane topology |
| 12+ | 35–42 | depth pass — one PR each, or one short series |
| — | 43 | the skeleton feedback PR (against the reference, not the target) |
| 13 | 44–45 | post-adoption checks |
| 14 | 46–48 | docs, memory, report |
| — | 49–56 | aftermath — offered as a multi-select, not taken |

**This is a merge, not an install.** Assume the target already has CI somebody
relies on. Measured across the eight derived modules on 2026-08-03: every one
has three to six workflows each carrying its own `pull_request:` trigger, not
one has a `ci.yml`, six have no `ci/`, two have no `src/`. An external adopter
is likelier still to have a suite predating any contact with this repo.

Three rules outrank every step:

1. **Adopt the convention, keep the content.** Layout, ordering, naming and
   entry points are the standard. The target's tests, thresholds, fuzz corpus,
   nginx compatibility range and linter selection are its own. A 1:1 copy is
   wrong by construction — the reference's tests test the reference's module.
2. **Never delete a gate the target already has.** Anything it checks that the
   reference does not survives, gets a badge and a table row, and goes back to
   the skeleton (step 43). A rollout that reduces coverage is a regression
   wearing a standardisation PR.
3. **Nothing self-hosted is portable.** `builder02` is a myguard machine and no
   linter here will tell an adopter they copied it. Step 7 settles it before any
   workflow is ported.

Standing constraints, all steps:

- **One PR per step that lands code**, in order, each independently revertible
  and independently green. Do not open the next until the previous merges —
  later ones move files the earlier ones edit.
- **Remote CI green before merge**, workflows enabled — see step 2 on what you
  may not do to get there.
- **Every gate must be seen red once, in the target.** A probe run against the
  reference is not evidence about the target: different paths, files and
  thresholds. Record the probe and its output in the PR body.
- **Never weaken a gate to make the target pass.** If it genuinely cannot meet a
  threshold, say so with the `file:line` that proves it and leave the gate at the
  honest value with a comment naming the reason.
- **Existing behaviour is not in scope.** You are moving CI, not rewriting the
  module. A real bug found on the way goes in `issues.md`; fix it only if it
  blocks the gate you came to install.
- Comments explain **why**, at the decision, in the target's voice. A rule with
  no recorded reason gets deleted by the next person who finds it inconvenient.
- **Keep the phase todo list live.** Step 3 writes it; every step after keeps it
  accurate — one item `in_progress`, items closed on merge, not on push.

## Work autonomously — record, do not ask

**Default to proceeding.** This job runs unattended. Almost everything that used
to be a stop is now a recorded finding: you write it down, degrade the affected
step honestly, and carry on with the remaining 53. A run that stops at step 3
with a question delivers nothing; a run that finishes 46 of 48 steps and hands
back a precise list of the 2 it could not do delivers almost everything.

Two files carry what you cannot act on. Create both at the start of step 1:

- **`$SCRATCH/adoption-findings.md`** — anything about the TARGET you could not
  fix: red baseline tests, a gate that will not go green, a behavioural bug, a
  missing secret. At step 47 this is merged into the target's `issues.md` and
  summarised in the report.
- **`$SCRATCH/skeleton-findings.md`** — anything about the REFERENCE: a bug in a
  ported script, a rule that could not be followed as written, a gate the target
  has that the skeleton lacks (rule 2), a step in this prompt that was wrong or
  ambiguous. Step 23 turns this into a PR against the skeleton.

`$SCRATCH` is the session scratchpad directory, or `$(mktemp -d)` if none.
One entry per finding: what, the `file:line`, what you did instead, and what a
human has to decide. An empty file at the end is a valid result; a finding you
kept in your head is not.

### Only these are hard stops

| Condition | Why it cannot be worked around |
|---|---|
| `<TARGET>` is not a git repository | nothing to branch, nothing to PR |
| No push access — `viewerPermission` is not `ADMIN`/`MAINTAIN`/`WRITE` (step 1) | cannot land anything |
| A fix requires deleting or weakening an existing gate | rule 2 — that is a coverage regression, and the point of the job is the opposite |

Everything else: record and continue. Explicitly, and against the old rules:

- **Dirty target tree** — do not stop, do not ask, do not `git stash`. Note the
  dirty paths in `adoption-findings.md`, branch off `HEAD`, and never `git add`
  a file you did not change. The dirt survives untouched.
- **Baseline suite already red** — record which tests, branch anyway, and state
  the pre-existing failure in every PR body so no later step inherits blame.
  Do not fix it unless it blocks the gate you came to install.
- **A gate red twice for reasons you cannot explain** — attempt it three times,
  then park that step: revert your branch, record the symptom and the three
  attempts, and move to the next step. Do not retry indefinitely and do not
  merge it red.
- **A step needs a behavioural change to the module** — do not make it. Land the
  rest of the step, record the required change with its `file:line`, and mark
  the gate thin in the PR body.
- **CI needs a secret or a runner the target lacks** — do not invent either.
  Degrade: hosted runner instead of self-hosted, the job omitted rather than
  broken, and a finding naming exactly what is missing.
- **A write outside `<TARGET>` seems necessary** — it is not. It goes in a
  findings file. The only writes to another *repository* are the two in step 2
  and step 43's skeleton PR; `$SCRATCH` is untracked working space and is not
  one of them.

**Never disable a failing check to make a PR mergeable.** Not `[skip ci]`, not
`continue-on-error`, not commenting out a step, not `gh workflow disable`, not
lowering a threshold to the observed value. A red gate you cannot fix is a
finding, and the honest end state of a step.

---

# Phase 1 — Establish what you are working with

Read-only. Three steps: prove you can work here, measure what is there, and
record the baseline everything downstream is compared against. Nothing is
committed in this phase.

## 1 — Set up the run

Create the two findings files and confirm the repo is workable.

```sh
cd <TARGET>
git status --porcelain            # dirty is FINE — record, do not stash
git rev-parse --abbrev-ref HEAD   # note it; this is the base to branch from
git remote -v                     # confirm you are where you think you are
gh auth status                    # authenticated at all?
gh repo view <owner>/<repo> --json viewerPermission -q .viewerPermission
```

The second command is the one that matters. `gh auth status` passes for a
read-only account, which then fails at the first push — six steps in, with a
branch already cut. `ADMIN`, `MAINTAIN` or `WRITE` continues; `READ`, `TRIAGE`
or an error is the hard stop.

Then:

```sh
SCRATCH=${SCRATCH:-$(mktemp -d)}
printf '# Adoption findings — <TARGET>\n\n' > "$SCRATCH/adoption-findings.md"
printf '# Skeleton findings — from <TARGET> adoption\n\n' > "$SCRATCH/skeleton-findings.md"
```

Record in `adoption-findings.md`: the base branch, and every dirty path from
`git status --porcelain` so a later diff cannot be blamed on you.

**Hard stop only if** the directory is not a git repo, or `gh` cannot
authenticate against this remote. Both are reported and the run ends. Anything
else found here is a finding.

**Acceptance:** both findings files exist; base branch recorded; you know the
remote.

## 2 — Scope, git safety, rollback

Read once, applies to every later step.

**One repo is writable: `<TARGET>`.** This reference, sibling modules and
`/opt/myguard/packages` are read-only for the whole job. Reading the reference is
the point; committing to it is not — except step 43's single skeleton PR, which
is opened from a branch and merged by review like any other.

Two writes outside the target are expected, and only these two:

- **The target's own memory mirror**, `memory/labs/<name>/` or
  `memory/eilandert/<name>/` — where the inventory, issues and lessons go.
- **The superrepo gitlink**, once per merged step, if `<TARGET>` is a myguard
  submodule. Submodule PR merges first, then the gitlink bump lands signed on the
  superrepo's `master`. An external target has no gitlink and no mirror; skip
  both and say so.

A dirty submodule or unrelated change in another tree is left exactly as found.
Do not commit it, revert it, or `git checkout` over it.

Git safety, non-negotiable:

- **Never `push --force` to a shared branch**, and never to the default branch
  under any circumstance. Rewriting a step branch you alone own, before review,
  is the only acceptable case — and `--force-with-lease`, never `--force`.
- **Never `git checkout .`, `git reset --hard`, or `git clean -fd`** to undo your
  own mistake. They erase whatever else was in the tree. Revert the specific file.
- **No secret ever enters a commit, a workflow, or a PR body** — no tokens, no
  PATs, no `Bearer` strings, not even revoked ones. Reference via
  `${{ secrets.X }}` or an env var. A workflow that needs a credential the target
  does not have is a finding, not a thing to invent.
- **The default branch is not a work surface.** Every step that lands code gets
  its own branch off the current default, merged by PR. Nothing is committed
  straight to `master`/`main`, including "trivial" doc fixes.
- One step per branch, named for it. Delete the branch after merge.

**Rollback.** Each step is one PR precisely so it can be reverted alone. If a
merged step turns out wrong, `git revert` the merge commit on its own branch and
PR that — do not force-push over history that others have pulled, and do not "fix
forward" by stacking a second broken change on the first.

**Acceptance:** nothing to produce; this step is read and obeyed.

## 3 — Inventory and baseline

The measurement everything downstream is planned from. Read-only.

```bash
cd <TARGET>
git remote get-url origin                                # who owns it
ls -d ci/t ci/tools ci/linter ci/fuzz src t tests fuzz 2>/dev/null
ls .github/workflows
grep -lE '^\s*pull_request:' .github/workflows/*.yml | wc -l   # entry points
grep -rn 'runs-on' .github/workflows/                    # whose machines?
ls src 2>/dev/null || ls *.c *.h                         # C at root?
ls src/*_scan.c src/*_scan.h *_scan.c 2>/dev/null        # decision seam? (step 4)
grep -ln 'ngx_http_request_t' src/*_scan.c *_scan.c 2>/dev/null  # expect no hits
grep -nE '!\[' README.md                                 # badge row + order
git log --oneline -10
gh run list -R <owner>/<module> --limit 20 \
   --json name,conclusion,startedAt,updatedAt,workflowName
```

**Is the target already standardised?** Score three markers: a full `ci/` layout
(`ci/t`, `ci/tools`, `ci/linter`, `ci/fuzz`); `ci.yml` as the sole
`pull_request` entry point; `ci/linter/run-all.sh` plus a tracked
`.githooks/pre-commit`. **3/3 → this is not the job**; skip to "Forwarding one
later change" at the end. Anything less → work the steps, taking only the ones
the target is missing.

Do not infer the score from the first marker you check. Two derived modules have
a `ci/` directory and still score 0/3 — `ci/` is the cheapest half of step 7 and
the most misleading signal in the set. **No `ci.yml` settles it on its own.**

Record in the memory mirror (`/opt/myguard/memory/labs/<module-name>/index.md`
for ours; an external target has no mirror — create one only if the work is
ongoing):

- current layout, whether `src/` exists, and **whether the decision seam exists**
  (step 4). Absent or nominal is the largest code change in the job — size it
  here, before planning anything downstream.
- workflows in three buckets: **matches** a reference workflow by purpose,
  **missing**, and **extra** — one the reference has no equivalent for. The
  third bucket is what rule 2 protects and what gets lost otherwise; every entry
  in it also goes to `skeleton-findings.md`.
- **every `pull_request:` entry point by name** — that count is the size of the
  steps 13–15 demotion, the riskiest edit in the job
- whose runners it currently uses
- **measured wall-clock per workflow** from `gh run list` — real numbers, needed
  for steps 33–34. Estimates are not acceptable there.
- current coverage number, if any tooling exists (usually none)
- gates it has that the reference lacks, and where they run

**Read the memory mirror first if the target is ours** — `index.md`,
`issues.md`, `lessons.md`. A trap recorded there outranks anything you infer
from the code.

**Baseline the target green.** Run whatever suite it has and record the result.
If it is already red, that is a finding for `adoption-findings.md` and a fact
every later PR body must state — otherwise step 5 inherits blame for a failure
that predates it. Do not stop; do not fix it.

**Emit the run plan as a todo list.** As the last act of step 3, call `TodoWrite`
once with **one item per PR group** from the table in "The job" — not one per
step (49 items is noise) and not one per phase (too coarse to show progress
through phase 4). Drop groups the 3/3 score has already settled. Phase 1 is marked
`completed` in the same call — it is done by the time you write it. Wording is
`PR<k>: steps <a>-<b> — <the work, in the target's own terms>`, so the list reads
as this run's plan and not as a copy of the table:

```text
[x] Steps 1-3 — findings files, inventory, baseline
[x] PR1: steps 4-6 — decision seam already clean, verified by mutation, no PR needed
[~] PR2: steps 7-9 — ci/ move + path climbs + src/ creation
[ ] PR3: steps 10-12 — runner identity (three files, both probes)
[ ] PR4: steps 13-18 — orchestrator demotion + workflow set
[ ] PR5-9: steps 19-27 — badges, test layers, fuzzing, coverage
[ ] PR10-11: steps 28-34 — caching, linter gate, lane topology
[ ] Steps 35-42 — depth pass with measurements
[ ] Steps 43-48 — skeleton feedback PR, post-adoption checks, docs and report
```

Collapsing several PR groups into one line (as PR5-9 above) is fine where they are
routine; split a line back out the moment one of them is where you actually are.

Keep it current for the rest of the run: exactly one item `in_progress`, each
flipped to `completed` when its PR merges — not when the branch is pushed. The
list is the only place the user sees how far along a 48-step job is; a stale one
is worse than none.

**Acceptance:** the 3/3 score with the evidence for each marker; the three
workflow buckets; the per-workflow wall-clock table; the baseline result. All in
the mirror (or the findings file, for an external target). Plus the todo list
written, with phase 1 already closed.

---

# Phase 2 — The decision seam

Three steps, one PR, alone in its phase because this is the only C refactor in the
job and every later gate links across it. A target that already has a clean seam
passes through 4 and stops; one that does not cannot produce a meaningful unit or
fuzz result until 5 and 6 land.

Phase 2 comes before the `ci/` move — the extraction is a C refactor independent
of where the test material lives, and everything downstream links across it.

## 4 — Probe: which of the three states is the target in?

Read-only, and it decides whether 5 and 6 run at all.

> **Decision logic goes in `*_scan.c`, taking `(u_char *, size_t)`. Only
> `ngx_http_request_t` plumbing stays in `*_module.c`.**

This is the one structural rule, and it comes before the test layers because
both of them link across it: `ci/tests/unit/test_scan.c` (step 20) and
`ci/fuzz/fuzz_scan.c` (step 24) compile the module's **real** decision source,
not a copy. Without the seam, step 20 tests a reimplementation and step 24 fuzzes
one — both green, both proving nothing about shipped code.

```sh
ls src/*_scan.c src/*_scan.h 2>/dev/null || ls *_scan.c *_scan.h
grep -n 'ngx_http_request_t\|r->\|ngx_http_' $(ls src/*_scan.c 2>/dev/null || ls *_scan.c)
grep -n '_scan\.c' ci/fuzz/build.sh ci/tests/unit/run.sh 2>/dev/null
git diff --stat HEAD~1 -- ci/fuzz/ngx_stubs.c               # did stubs grow?
```

Three states, and each has a different next move:

- **Seam exists and is clean** — no `ngx_http_request_t` in `*_scan.c`. **Skip
  step 5**; go straight to 6 and confirm the consumers point at it.
- **Seam is nominal** — `*_scan.c` exists but reaches for `r->`, allocates from
  `r->pool`, or logs through `r->connection->log`. It cannot be linked outside
  nginx, so the fuzz and unit builds either fail or quietly link a stubbed
  variant. **Growth in `ci/fuzz/ngx_stubs.c` is the tell** — every stub added
  beyond the reference's set is a dependency that should have been refactored out.
  Step 5 runs.
- **No seam** — decision logic is inline in `*_module.c`. Step 5 runs.

A fourth outcome is legitimate and must be stated rather than skipped silently:
the module genuinely has **no decision logic to separate**, a pure plumbing module
whose only work is `ngx_http_*` calls. Say so with the `file:line` that shows it,
record that steps 20 and 24 are correspondingly thin, and skip 5 and 6.

**Acceptance:** the state named, with the grep output that establishes it, and —
where the seam already exists — whether the fuzz and unit builds currently name it.

## 5 — Extract the seam

Only if step 4 found "nominal" or "no seam". This is a **move, not a rewrite**.

1. `*_scan.c` / `*_scan.h` take bytes and return a verdict. No nginx request
   types in the signature, no allocation from a request pool — pass a buffer in
   or take an explicit allocator argument.
2. `*_module.c` keeps the handler, directive parsing, config merging and every
   `ngx_http_*` call, and calls into the seam.

**Do not change behaviour while extracting.** The baseline suite from step 3 must
stay green across it — run it wherever it currently lives, since `ci/` does not
exist yet. A behavioural fix that rides along makes any later bisect ambiguous; a
real bug found while extracting goes to `adoption-findings.md`.

Paths here assume `src/`; a target that still keeps its C at the repo root
creates the seam **beside the existing `*_module.c`**, wherever that is, and it
moves under `src/` at step 9. Do not create `src/` here — that split would land
the same C in two commits.

**Acceptance:** no nginx request types inside `*_scan.c`; the module still builds;
and the step 3 baseline suite is **unchanged** — every test that passed at step 3
still passes, with no behavioural diff. A test that was already red at step 3
stays red and is named in the PR body; do not fix it here and do not treat it as
a reason to park the step.

## 6 — Wire the two consumers

Same PR as 5. The extraction is worthless until the things that link across it
name the real file.

```sh
grep -n '_scan\.c' ci/fuzz/build.sh ci/tests/unit/run.sh 2>/dev/null
```

Both `ci/tests/unit/run.sh` and `ci/fuzz/build.sh` must compile the target's real
`*_scan.c` — the same source, not a second copy. Whichever of the two the target
already has gets pointed at the seam in this PR; the rest follow the material into
`ci/` at step 7. If the target has **neither** yet, say so: the seam is verified by
build and grep here, and by steps 20 and 24 once its consumers exist.

The reference's `build-test.yml` asserts the seam file exists by name after a
rename. Confirm the target's equivalent names the **target's** file — a path that
no longer exists makes the assertion vacuous, not failing.

**Acceptance:** every consumer that exists names the target's real `*_scan.c`, by
grep; or an explicit line saying which consumers do not exist yet.

---

# Phase 3 — Layout and identity

Two things that must be settled before a single workflow is ported: where the
material lives, and whose machines it names. Six steps, two PRs — 7–9 are one PR,
10–12 are the other.

## 7 — Move CI material under `ci/`

Target layout, matching the reference:

```text
ci/
  t/                     Test::Nginx suite            (was t/ or tests/)
  tests/unit/            C unit tests of the decision core
  fuzz/                  libFuzzer targets, dict, corpus/, regressions/
  vendor/nginx-tests/    upstream suite submodule
  tools/                 ci-build.sh, nginx-tree.sh, test_runtime.py,
                         coverage.sh, max-port.sh, ci-hang-guard.sh, soak.sh
  linter/                local lint gate (steps 28–32)
```

- `git mv`, never copy-then-delete — blame must survive. Verify with
  `git log --follow` on one moved file before continuing; a move recorded as
  delete+add loses the history silently and cannot be repaired after merge.
- `git submodule update --init` still working after moving `ci/vendor/nginx-tests`
  is a required check — the `.gitmodules` `path:` must be edited, not just the
  directory moved.
- Run the suite after the move and before any workflow edit, so a failure is
  attributable to one thing: `TEST_NGINX_TIMEOUT=20 prove -v ci/t/`

**Acceptance:** local `prove` green, fuzz targets still build
(`ci/fuzz/build.sh`), `git log --follow` shows history on a moved file.

## 8 — Fix every path that climbed out

Same PR as step 7, separated here because it is the half that silently fails.

A directory move breaks **every relative path that climbs out of it**. Grep and
fix in this order:

1. nginx's module **`config` file** — it names every source path and is the one
   file whose breakage stops the module building at all
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

A missed climb compiles fine and silently tests the wrong tree.

**Acceptance:** no path outside `ci/` refers to `t/`, `tests/` or `fuzz/`; the
module still builds; `prove` still green.

## 9 — Create `src/` if the target has none

Same PR as 7 and 8. Skip if `src/` already exists — but check, do not assume: two
of eight derived modules keep `ngx_http_<name>_module.c` (sometimes plus
`<name>_core.c/.h`) at the repo root.

This is not cosmetic. Everything downstream is scoped to `src/` — `lint-c.sh`,
`lint-nginx.sh`, the gcovr filter, the CodeQL TU filter — and every one *passes*
on an empty selection rather than failing. A target with no `src/` gets a green
run out of every one of them while they check nothing.

Move the C under `src/` — including the seam files from steps 5–6 — and update
nginx's module `config` in the **same commit**, or the module stops building.

**Acceptance:** the empty-selection proof — a `malloc`/`strcpy` probe file where
the module's real C now lives must make `LINT_ONLY="c nginx"` exit 1. A green run
on that probe means the selection is still empty and the move did not take.

## 10 — Runner identity: rewrite every `runs-on`

Steps 10–12 are one PR, and they come before a single workflow is ported.
`builder02` is the label of **a physical machine myguard owns**, spread across
three files that must agree:

```sh
grep -rn 'builder02' \
    .github/workflows/ .github/actionlint.yaml ci/linter/workflow_policy.py
```

| File | What it holds | In the reference, 2026-08-03 |
|---|---|---|
| `.github/workflows/*.yml` | the `runs-on` fork ternary | 15 selectors in 7 workflows (`build-test` and `ci-deep` carry 5 each) |
| `.github/actionlint.yaml` | the declared label list | 3 mentions, one `self-hosted-runner:` block |
| `ci/linter/workflow_policy.py` | `TRUST_SPLITS`, the approved-selector set | 5 mentions, three label combinations |

23 sites; re-derive rather than trusting the number. `ci.yml`, `lint.yml` and
`codeql.yml` are already `ubuntu-latest`.

**Nothing in the toolchain catches a copied label.** actionlint validates runner
labels for a *literal* `runs-on` only, and every self-hosted selector here is a
`fromJSON(...)` ternary it stays silent on (measured 2026-08-02: `builder02` →
`buidler02` was invisible to it). zizmor has no idea which labels you are
entitled to. `lint-ci-runners.sh` compares against `TRUST_SPLITS` — which, if
copied unedited, **contains `builder02` and approves it by construction**. The
failure is not a red CI you fix; it is a green CI either queueing forever against
a label nobody answers, or dispatching to a runner you do not own.

**The rule: if the target does not own the pool, every job is `ubuntu-latest`
with no ternary at all.** The fork ternary answers one question — may this code
touch *our* build host? An adopter with no build host has no such question, and
an expression whose fallback arm names someone else's machine is a default-deny
that defaults to somebody else's hardware.

```yaml
# before (reference, myguard-owned pool)
runs-on: ${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || fromJSON('["self-hosted","builder02","lxc"]') }}

# after (any adopter without their own pool)
runs-on: ubuntu-latest
```

**Order matters and it is the reason this is three steps: workflows first (10),
the two policy files second (11), the probes last (12).** The gate is the last
thing to change, so its findings are about what remains.

This step is item 1 of that order: **every `runs-on` in `.github/workflows/`**.

Stated honestly so nobody optimises it back: the self-hosted pool is what makes
`ci-deep.yml`'s monthly matrix and the long fuzz runs affordable. On hosted
runners those are slower and bounded by the 6-hour job limit. That is a
scheduling problem, not a reason to point a `runs-on` at hardware you do not
control.

**If the target DOES own a pool**, self-hosted is opt-in and a separate commit —
never smuggled into the port. All three files change together with their own
labels, the fork arm stays the hosted runner, and the condition stays
`github.event.pull_request.head.repo.fork` — not `github.actor`, not a repo
variable, both of which a fork controls. Then read steps 33–34 in full.

**Acceptance:** no `runs-on` in `.github/workflows/` names a label the target does
not own; `actionlint` still parses every workflow.

## 11 — Runner identity: the two policy files

Same PR, after 10 and before 12. Two files, and the second is the one this whole
group exists for:

1. `.github/actionlint.yaml` — delete the `self-hosted-runner:` block entirely;
   declaring labels you never use trains the next person to add one.
2. `ci/linter/workflow_policy.py` — reduce `TRUST_SPLITS` to an empty frozenset.
   `HOSTED.fullmatch` covers every selector now, and an empty approved-set makes
   any future self-hosted selector a finding rather than a silent pass.

**Do this after 10, never before.** Emptying `TRUST_SPLITS` while the workflows
still carry self-hosted selectors produces one finding per selector: doing it in
the reference produced **16 findings** — the probe plus all 15 real selectors.
Expected intermediate state, and exactly the noise that buries the one finding you
are hunting at step 12.

**Acceptance:** `TRUST_SPLITS` is empty (or names only labels the target owns);
no `self-hosted-runner:` block survives in `actionlint.yaml`.

## 12 — Runner identity: verify, both directions

Same PR, last. A grep proving `builder02` is absent says nothing about whether the
*checker* still approves it.

```sh
# 1. no myguard runner identity survives anywhere
grep -rn 'builder02\|b02lxc' .github/ ci/linter/workflow_policy.py
#    -> expected: no hits for a hosted-only adopter

# 2. the checker actually rejects the reference's selector
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
LINT_ONLY=ci-runners ci/linter/run-all.sh   # MUST exit 1 in the target
rm .github/workflows/_probe.yml
```

**Probe 2 going green in the target is the bug this group exists for** — it means
`TRUST_SPLITS` was copied unedited. Go back to step 11 and fix
`workflow_policy.py`; do not delete the probe.

**In the unedited reference probe 2 exits 0, correctly** — `builder02` is an
approved selector *here*, in our repo, on our machine. The probe is a statement
about the TARGET. Running it in the reference to "check the probe works" proves
nothing.

**Acceptance:** probe 1 empty, probe 2 red, both outputs pasted in the PR body.

---

# Phase 4 — Adoption

Twenty-two steps, eight PRs. The bulk of the job: entry points, the workflow set,
badges, test layers, coverage, fuzzing, caching, the linter gate and lane
topology.

The demotion (13–15) is the highest-risk sequence in the job. It is three steps
because it is three *states of the repo*, each verified before the next — doing it
in one pass is how a repo ends up with no PR gate at all. Do the demotion before
adding any workflow: adding one to a repo that still has six triggers multiplies
the problem.

The target has N workflows each carrying `pull_request:` (measured: three to six,
with `workflow_call:` nowhere). End state after 15: exactly one `pull_request:`,
in `ci.yml`, everything else reachable only as a `workflow_call:` member.

## 13 — Add `workflow_call:` to every member

Add `workflow_call:` to each member **while leaving its `pull_request:` in
place**. It still runs standalone, so the target keeps working and this step
cannot break anything.

**Acceptance:** every member workflow carries both triggers; `actionlint` clean;
a PR run shows the same set of checks as before, no more and no fewer.

## 14 — Add `ci.yml` and prove the double-run

Add `ci.yml` calling every member. Verify **on a real PR** that each member runs
*twice* — once standalone, once called. Two runs is the expected intermediate
state and the proof the call graph is wired.

Skipping this proof is how a member ends up called by nobody: `ci.yml` references
a job name that does not exist, the call contributes nothing, and the suite looks
green because the check that would have failed never ran.

**Acceptance:** the run list showing every member twice, pasted in the PR body. A
member that ran once was never called — fix `ci.yml` and re-run before step 15.

## 15 — Remove `pull_request:` from every member

One commit. Now each member runs once.

**This is the point of no return**, and the only action in the job that can leave
the repo with *no* PR gate at all. Do not take it until step 14 showed **every**
member running twice — a member that ran once was never called, and removing its
own trigger silences it completely. If even one did not double-run, fix `ci.yml`
and repeat 14; do not proceed on the theory that it will resolve itself. Should
the merged result gate nothing, revert this PR first and diagnose after — an
ungated default branch is not a state to debug in place.

Two things that break a called workflow and not a standalone one:

- **`secrets: inherit` is not automatic.** A member that used a secret while
  standalone loses it when called unless the caller passes it.
- **Path filters do not work on a called workflow** — it cannot filter its own
  triggering. Gates move to a `changes` job in the orchestrator with an explicit
  job-level `if`. See step 34 rule 8.

A second entry point that is not `pull_request:` (a `schedule:`, a
`workflow_dispatch:`) is fine and normal — `bump.yml` and `ci-deep.yml` in the
reference are schedule-driven and not members of the PR lane.

**Acceptance:** exactly one workflow carrying `pull_request:`, proved by
`grep -lE '^\s*pull_request:' .github/workflows/*.yml`, and a PR run in which
every member ran exactly once.

## 16 — Port the workflow set

Same PR as 13–15, separate commit.

| Workflow | What it must gate in the target |
|---|---|
| `ci.yml` | orchestrator; the ONLY `pull_request` entry point |
| `lint.yml` | the `ci/linter/` gate (steps 28–32), hosted runner |
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
`.github/actions/build-cache/`, and `.github/actionlint.yaml` (subject to steps
10–12).

**Acceptance:** `actionlint` clean; every workflow in the table above either
present or explicitly accounted for as not applicable to this target.

## 17 — Triage the workflows the reference does not have

Same PR. Rule 2 lives here — this is the step that decides whether the rollout
reduces coverage.

**Workflows the target has and the reference does not survive.** One derived
module carries a `runtime-tests.yml` with no reference equivalent; two carry a
`bump.yml` the other six lack. For each, decide and write down which:

- **keep as-is** — it gates something real. Give it a `## CI` row and a badge at
  step 19, and add it to `skeleton-findings.md` for step 43.
- **fold into a reference workflow** — it duplicates a gate under another name.
  State what moved where.

Do not delete one on the grounds that the reference has "the same thing" until you
have compared the actual checks; a same-named workflow often gates less.

**Acceptance:** every extra workflow classified keep/fold with a written reason,
and every "keep" queued for a badge at step 19.

## 18 — Port bands

Same PR. Test::Nginx binds `TEST_NGINX_PORT`, default 1984, and nothing
arbitrates it. A self-hosted host runs several runner slots against one network,
so two jobs on the default collide and the loser dies with
`bind() to 127.0.0.1:1984 failed (98: Address already in use)` — which reads as a
module regression and is not one. Presence of `TEST_NGINX_PORT` is not the check;
the check is a **distinct job-level band** per workflow (the reference uses
`TEST_BASE_PORT` 19200 in `build-test.yml`, 19400 in `ci-deep.yml`), verified by
`ci/tools/max-port.sh` **before the first step that binds it** — which means
before `prove`, not merely before the runtime driver. The reference shipped this
in the wrong place until 2026-08-02; `fixtures/policy/verify-after-bind` is the
negative control that keeps it right. Read the target's step ORDER. A target
whose driver picks its own free port is already immune; leave it and say so.

**Acceptance:** each workflow that binds a port declares a distinct band, and
`max-port.sh` runs **before** the first step that binds — quote the step order
from the YAML, not the presence of the verify step.

## 19 — Badges and the `## CI` table

Own PR — small, and it is the one thing every reader sees first.

```text
Build&Test, Security Scanners, Fuzzing, Valgrind, CodeQL, A/UBSan, CI Deep
```

with Lint inserted where the `## CI` table puts it, and the two kept in lockstep.

The label text is part of the convention. Measured 2026-08-03: a derived module
had all seven badges in the correct order but wrote `Build & Test` for
`Build&Test` and `Security scanners` for `Security Scanners`. Match spelling and
capitalisation character for character, so a diff across modules shows real
differences only.

- badge row order == `## CI` table order == the list above
- an **extra** workflow kept at step 17 goes at the END of both lists, after CI
  Deep, so the shared prefix stays comparable across modules
- every badge must resolve to a workflow that exists — one for a deleted workflow
  renders a permanent grey "no status" and is worse than no badge
- **the URL owner/repo is the target's**, not `myguard-labs/nginx-skeleton-module`.
  A copied badge row pointing at the reference renders green while telling you
  nothing about the target, which is the worst failure available here.

**Acceptance:** every badge resolves to a real workflow in the target's own repo;
CI table and badge row in identical order and spelling; `lint-docs-drift.sh`
green in both directions.

## 20 — Unit tests over the real decision TU

First of the four test layers; one PR with step 21. **Reuse the reference's
harness; do not re-derive it.**

`ci/tests/unit/` — `run.sh` + `test_scan.c`. Links the target's REAL decision TU
and nginx's REAL `src/core/ngx_string.c`; no shimmed decoder, ever. A shim makes
the layer hermetic and worthless. Reuses `ci/fuzz/ngx_stubs.c`.

Push toward the maximum by targeting, in order: error paths, allocation failure,
malformed/truncated input, boundary values at every `MAX_*` constant,
cross-buffer seams, and the branches gcovr shows as never taken. 100% is not the
goal; every *reachable* branch having a meaningful assertion is.

**Rejected outright** (applies to every test written in steps 20–26):

- a test whose assertion holds in both the pass and fail state (tell: a captured
  variable never compared)
- a control that hardcodes the verdict instead of calling the real function
- asserting a *precondition* rather than the claim
- one shared counter asserted at N call sites — it pins none of them
- a test written from the same misunderstanding as the code
- excluding a hard file from the coverage config to lift the percentage
- tests that execute lines without asserting on the result

**Acceptance:** `run.sh` links the target's real `*_scan.c` (grep it, do not
assume); the suite is green; every branch you intended to cover has an assertion
on the result, not merely execution of the line.

## 21 — Mutation pass over the unit tests

Same PR as 20, and it is a separate step because it is the half that gets skipped
under time pressure. Until it runs, step 20 has produced tests of unknown value.

**Required per new test: a negative control.** Break the code the test claims to
guard (flip a comparison, delete a bound check, swap a constant), confirm the
test FAILS, restore. Note the mutation in the test's comment.

Three ways this goes wrong, all of which look like success:

- **The mutation survives.** That is itself the finding — the test guards nothing.
  Record it in `adoption-findings.md` with the reason, and either fix the test or
  say why it cannot be fixed.
- **The mutation does not cross the threshold.** Clearing a counter below the
  level the code acts on proves nothing; mutate past the boundary the assertion
  actually names.
- **A build-time guard masks it.** A `grep`-based build check that rejects the
  mutated source means the tests never ran against it. Confirm the mutated build
  actually compiled and executed.

**Acceptance:** one recorded mutation per new test, each shown to make that test
fail, with the mutation named in the test's own comment.

## 22 — The live-server layer

One PR with step 23. `ci/tools/test_runtime.py` — the live-server cases
Test::Nginx cannot express: concurrency, the chunk seam through the real body
handler, reload under load. Retarget the config and marker; keep the shape,
**including the baseline case that proves the module is loaded and blocking before
anything else runs**.

Step 20's rejected-test list applies unchanged.

**Acceptance:** the suite is green, and the baseline case exists and asserts the
module is loaded — its mutation is step 23's job.

## 23 — Mutation pass over the live-server layer

Same PR as 22. Same requirement as step 21, over a layer where it is easier to
fake: a runtime test can pass because the server came up at all.

- **The baseline case must fail when the module is not loaded.** Prove it by
  unloading the module, not by reasoning about the config.
- The concurrency and reload cases each need their own recorded mutation.
- Beware the shared counter: one counter asserted at N call sites pins none of
  them. If the mutation at site A is caught by an assertion that site B also
  satisfies, the test does not attribute anything.

**Acceptance:** the baseline case observed failing with the module unloaded; the
concurrency and reload cases each with a recorded mutation that made them fail.

## 24 — The fuzz target, corpus and dictionary

One PR with 25 and 26. Fuzzing is per-module work; a copied harness driving the
skeleton's rule table proves nothing about the target.

- The fuzz target must call the **real** decision function with
  `(const uint8_t *, size_t)`, not a reimplementation. That seam is steps 4–6's
  job and should already exist. If it was parked and does not, do not stop:
  record in `adoption-findings.md` that the real decision function is
  unreachable, mark this step degraded in the PR body, and continue with the
  parts that do not need it. **A fuzz target driving a reimplementation is worse
  than none, so do not build one** — everything measured against a copy is
  meaningless.
- Seed corpus from the module's actual domain: real headers/bodies/config values
  it parses, plus every past crash under `ci/fuzz/regressions/`.
- `fuzz.dict` with the module's real tokens. A dictionary of the skeleton's
  tokens actively misdirects the fuzzer.

**Acceptance:** the fuzz target builds and links the target's real `*_scan.c`, by
grep; corpus and dict derived from the target's domain, with their sizes stated.

## 25 — Replay order and the ASan soak

Same PR as 24. Two gates that are green by default and prove nothing by default.

- **Replay-then-fuzz order in `fuzzing.yml`**: recorded regressions first (fast,
  deterministic), then the time-boxed fresh run. A crash that returns must fail
  in seconds, not after the fresh budget.
- **The ASan soak (`asan.yml`) must drive the module's real request shape** — its
  directives enabled, its body path exercised — not a default config where the
  handler never runs. Verify it reaches the module with evidence: a counter, a
  log line, or coverage from the soak build.
- Keep the ASan build static (`--add-module`); a dynamic module under ASan loses
  interception on the parts that matter.

**Acceptance:** a deliberately reintroduced past bug is caught by the replay step
in seconds (verify once, then revert), and the evidence that the soak reaches the
module, quoted in the PR body.

## 26 — Adapt the three neighbours

Same PR as 24–25. Each is a file that keeps reporting success while pointed at the
wrong target:

- `valgrind.supp` — needs **target-specific** nginx-core suppressions. A copied
  one can suppress the module's own errors.
- `codeql.yml` — the TU filter needs the target's file names, or CodeQL analyses
  nothing and passes.
- `ci-deep.yml` — the matrix needs the target's nginx/angie compatibility range,
  not the reference's.

**Acceptance:** each of the three names the target's own paths/versions, shown by
grep; and for `codeql.yml`, the analysed-TU count from a real run is non-zero.

## 27 — Coverage as a report

Own PR. Fourth test layer.

`ci/tools/coverage.sh` + the `coverage` mode in `ci/tools/ci-build.sh` — a
distinct build tree, never a flag bolted onto `debug`, so a cached
non-instrumented tree cannot produce a 0% report that reads as a finding.
`gcovr` filtered to `src/` only; an unfiltered run drowns the module in 200k
lines of upstream nginx.

**Coverage is a REPORT, not a gate.** The cheapest way to move the number is
tests that touch lines and assert nothing, so a floor buys a metric and sells the
thing it proxied for. Publish from `ci-deep.yml`; gate on the mutations recorded
beside each suite. `COVERAGE_FAIL_UNDER` exists for a target that decides
otherwise.

**Acceptance:** the reported figure moves when a test is deleted (prove it, then
restore); the filter names the target's `src/`.

## 28 — Caching: `ci-build.sh` as the single chokepoint

Steps 28–32 are one PR. They ship together because the linter's speed budget
(step 32) is measured on the cached tree this step produces.

Every build goes through `ci/tools/ci-build.sh` as the single chokepoint; no
workflow duplicates cache logic. Layers, cheapest first: apt/packages, ccache
(`CCACHE_COMPILERCHECK=content`), mold (**skipped under ASan**), eatmydata (wrap
configure/install; never wrap something whose durability matters), build tree
(`.build/nginx-<ver>-<mode>`, keyed on mode + version +
`hashFiles(ci-build.sh, config, src/**)`), source tarball (keyed on version,
sha256 verified after restore).

Load-bearing rules:

- nginx's `configure` **ignores a bare `CC=`** — ccache must be wired through the
  configure argument the reference uses, not via env.
- ccache may use a `restore-keys` ladder (content-hashed; a partial hit cannot
  serve a wrong object). The **build-tree cache stays exact-match only** — do not
  "fix" that for consistency.
- Hybrid restore (on-disk warm dirs + `actions/cache` fallback) stays. Deleting
  the fallback because the runners are persistent is how this degrades silently
  the day they become ephemeral.
- GitHub scopes caches **by ref**: a PR run writes `refs/pull/N/merge` and cannot
  read a branch's entries. A cold PR run is not a bug.
- A cache must never serve a stale artifact into a green result. If a key cannot
  express what invalidates it, do not cache that layer.
- State the honest win in the README. If caching saves 5s on a 2.5-minute gate,
  say so.

**Acceptance:** a second identical build reports a non-zero ccache hit rate — a
0% hit rate on an identical rerun means ccache is not wired, whatever the log
says. Every layer's key names what invalidates it.

## 29 — Port `ci/linter/` and its installer

Same PR. Port `ci/linter/` and follow **[linter/README.md](linter/README.md)**
verbatim: `apt-get` first, then `pipx` for what Debian lacks, then `cpan` for
Perl, then upstream binary for actionlint. `install-linters.sh` is the single
installer; CI and a fresh clone use the same one.

- A missing tool exits 2 and BLOCKS. Never a silent skip.
- Relaxations live in `.yamllint` / `.perlcriticrc` with their reason. Fix
  pre-existing findings or record why — no blanket suppression.
- `lint.yml` runs the same `run-all.sh` on a hosted runner, so a clone that never
  enabled the hook still cannot land a regression.

**Acceptance:** `install-linters.sh` succeeds from a clean environment;
`run-all.sh` exits 0 clean, 1 on findings, 2 on a missing tool — observe all
three, the last by hiding a tool from `PATH`.

## 30 — The tracked hook and the threshold mirror

Same PR. Two things that make local-green predict remote-green:

- **Tracked hook at `.githooks/pre-commit`**, enabled with
  `git config core.hooksPath .githooks`. Lints STAGED files only.
- **Thresholds mirror `security-scanners.yml`.** Move one there, move it here in
  the same commit, or the two drift and the local gate stops meaning anything.

Watch the top-level exclude: a global exclude in `.pre-commit-config.yaml` runs
before every hook, so one broad pattern can blind every checker at once.

**Acceptance:** a staged file with a deliberate finding is blocked by the hook;
every threshold in `ci/linter/` matches its counterpart in
`security-scanners.yml`, listed pair by pair.

## 31 — The checker set is the target's

Same PR. **The checker SET is the target's; the entry point is the standard's.** The
convention is `run-all.sh` + `LINT_ONLY` + exit codes (`0` clean, `1` findings,
`2` tool missing) + the tracked hook. Behind it:

- a module with no Perl needs no `lint-perl.sh`; one with Lua or Rust needs a
  checker the reference lacks. Add `lint-<name>.sh` — `run-all.sh` picks it up by
  glob — and give it a row in the linter README. A checker the reference lacks
  also goes to `skeleton-findings.md`.
- **keep every checker the target already ran** (rule 2), behind the same entry
  point rather than dropped because the reference lacks it.
- the three **repo-policy** checks do not transfer unexamined: `ci-runners`
  depends on `TRUST_SPLITS` being rewritten (step 11), and `ci-ports` is
  meaningful only if the target binds a fixed band. A target whose driver picks
  its own port should say so in the README and skip it loudly, not carry a check
  that can never fire.
- `lint.yml`'s `LINT_ONLY` string diverges with the checker set. The reference
  runs `nginx sh python perl yaml spelling ci-runners ci-ports docs-drift`; that
  is not a constant to copy, and nothing cross-checks it against the scripts that
  exist.

**Acceptance:** every checker the target ran before still runs, behind
`run-all.sh`; `LINT_ONLY` in `lint.yml` matches `ls ci/linter/lint-*.sh` exactly;
every added or dropped checker has a written reason, and every added one is in
`skeleton-findings.md`.

## 32 — The speed budget

Same PR, and last in the group — it is measured against the finished checker set
on the cached tree from step 28.

**The whole hook under ~2s on a one-file commit.** A gate people
wait on is a gate people bypass with `--no-verify`. Over budget → scope the slow
checker, never drop one, never a default-on skip flag. Carry these three, each
measured:

- **`semgrep --metrics=off`** — the telemetry POST was 2.76s of a 2.76s scan.
- **`semgrep --jobs=1`** — a *correctness* flag. semgrep-core opens one io_uring
  ring per OCaml domain against the host's 8 MB `RLIMIT_MEMLOCK`, shared with
  every other job; when the runners are busy it aborts with
  `Unix_error: Cannot allocate memory io_uring_queue_init`, exit 2 — a red gate
  caused by a neighbouring job. Reproduced 3/3 busy, 0/3 idle, so an idle-box
  green tells you nothing. `security-scanners.yml` carries the same flags.
- **`run-all.sh` fans checkers out** (`LINT_JOBS`). Buffer each checker's output
  and replay it whole in fixed glob order — never interleaved: findings carry a
  `file:line` but not a checker name. Each child writes its exit status to a
  file; the reaping `wait` is collective, and a **missing** status file (child
  SIGKILLed) must count as a failure, never a pass.

Record your numbers and **check `/proc/loadavg` first** — on the build host at
load ~50 the same full-tree run varied 2.2s–12.4s over six attempts, a spread
wider than the whole improvement.

**Acceptance:** run every probe in the linter README's "Verify before trusting"
section against the target and observe each red — *after* the speed work.
`--jobs`/`--metrics` are exactly the flags that can silently turn a checker into
a no-op, so the semgrep probe in particular must still fire. Then run with two
checkers failing at once and confirm both appear and both are named in the
`== FAIL:` line.

## 33 — Measure the target's job durations

Steps 33–34 are one PR. CI wall-clock on a self-hosted host is dominated by jobs
QUEUEING for a label-matching slot. Ten simultaneous requests just means the tail
waits. **Hosted-only targets can skip both steps** — say so and move on.

This step produces numbers and nothing else. Measure the target, not the
reference:

```sh
gh run view <id> -R <owner>/<repo> --json jobs \
  -q '.jobs[] | [.name, .conclusion,
                 (((.completedAt|fromdate)-(.startedAt|fromdate))|tostring)+"s",
                 .startedAt, .completedAt] | @tsv'
```

Keep `startedAt`/`completedAt`, not just durations — the gaps show queueing.

Count the real slots too — `systemctl list-units | grep ci-ephemeral` (six on the
reference's host) — and check `/proc/loadavg` before trusting any timing: at load
~50 the same full-tree run varied 2.2s–12.4s over six attempts here.

**Acceptance:** a per-job table with `startedAt`/`completedAt`, the run ID and
date it came from, and the slot count. No lane changes in this step.

## 34 — Build the lanes

Same PR as 33, and it consumes 33's numbers. At most four lanes.

1. Identify the longest single **job**. That is the budget; no arrangement
   finishes sooner. Chain **nothing** behind it. Pairing the longest job with a
   follow-up "to keep the lane busy" is the most common way this gets worse — it
   is what put the reference's lane A at 348s against a 268s budget.
2. Build the **fewest lanes that fit**, four maximum, each a chain of `needs:`
   where a long job releases its slot to a shorter independent follow-up. No lane
   exceeds the budget. Three that fit beat four that also fit. Note the fullest
   lane's headroom in the comment.
3. Does not fit in four? Move a check out-of-band (monthly), time-box it, or put
   it on a hosted runner — not "add a fifth".
4. **A lane is not a slot.** Count real slots
   (`systemctl list-units | grep ci-ephemeral` — six on the reference's host),
   and remember a reusable workflow fans out: the reference's Build&Test is
   *five* jobs, so observed peak is 7 against 6 slots. Brief oversubscription at
   t=0 is acceptable; writing "caps peak at three" when it is seven is not.
5. Hosted jobs (lint, CodeQL) take no self-hosted slot and are **not laned at
   all** — no `needs:`, start immediately. Chaining one behind a self-hosted job
   conserves nothing and delays its result.
6. Follow-ups use `if: ${{ !cancelled() }}` so a failing first check does not
   suppress an unrelated second one, and so a chain survives an earlier job being
   *skipped* by a changed-files gate.
7. Concurrency groups must not collide. A called workflow inherits the caller's
   `github.workflow`/`github.ref`; an identical group string makes a member
   cancel its own caller and a whole lane dies before it starts. Prefix the
   orchestrator's group distinctly.
8. Path-gating a reusable workflow does not work. Gates move to a `changes` job
   in the orchestrator with an explicit job-level `if`. That diff job must **fail
   loudly** on an unusable diff, never fall through to "no relevant changes" —
   failing open skips the sanitizer on exactly the PRs that need it.

The orchestrator's header comment is the only place this design is written down,
so it is part of the deliverable: lane map, measured durations, the run ID and
date they came from, and the command to re-derive them. **Any lane change
rewrites that comment in the same commit** — a stale lane map reads as
measurement and gets trusted. Record it in the memory mirror too.

**Acceptance:** the lane map in the orchestrator header, with the run ID and date
its numbers came from.

---

# Phase 5 — Depth pass

Run after every phase-4 step has merged. Everything here is already green; the
question is whether it would catch anything. A soak that never reaches the
handler, a fuzzer driving a reimplementation and a coverage number computed over
nginx core all report success indefinitely.

Eight steps, 35–42. One PR each, or one short series — but each is answered with a
**measurement in the PR body**, not a reading of the YAML. Where an item cannot
be met, say so with the `file:line` and leave the honest value; "never weaken a
gate" still applies.

## 35 — Re-verify the decision seam

Steps 4–6 established it; everything below depends on it still holding, and it
decays quietly as handler code is added. Re-run step 4's probes:

```sh
grep -n 'ngx_http_request_t\|r->\|ngx_http_' src/*_scan.c   # -> expect no hits
grep -n '_scan\.c' ci/fuzz/build.sh ci/tests/unit/run.sh
git log --oneline -- ci/fuzz/ngx_stubs.c                    # stubs grown since 4?
```

A new stub in `ngx_stubs.c` is the signal that decision logic drifted back into
nginx types and someone stubbed around it rather than refactoring. Fix the seam,
not the stub. If step 4 was recorded as "no decision logic to separate", confirm that
is still true — a module grows parse surfaces.

**Acceptance:** unit and fuzz builds still compile the target's real `*_scan.c`
(same source, not a second copy), no nginx request types inside it, no stub
growth that is not justified in the PR body.

## 36 — ASan/UBSan: does the soak reach the module?

The failure is silent: a default config where the handler never runs produces a
clean ASan report forever.

- Prove reachability with evidence, not inspection — a counter, a log line, or
  coverage from the soak build showing the module's own translation unit
  executed. Put the number in the PR body.
- The soak must exercise the directives the module actually ships and its body
  path, at the shapes an attacker controls, not a single GET.
- Build stays static (`--add-module`); dynamic loses interception where it
  matters. mold stays skipped under ASan.
- UBSan: confirm the target's flags include the checks the module can actually
  trip (integer overflow, alignment, shift) and that it is **trapping or exiting
  non-zero** — a UBSan that only prints to stderr passes a red run.

**Acceptance:** reintroduce a known-bad access, watch it abort, revert. The abort
output goes in the PR body.

## 37 — Fuzzing: can the surface be widened?

The reference carries two targets (`fuzz_scan`, `fuzz_body`). One target on a
module with several parse surfaces is under-fuzzed by construction.

- Enumerate every function taking attacker-controlled bytes; each is a candidate
  target. Add the ones with a real seam, one per parse surface, and say in the PR
  which surfaces remain uncovered and why.
- `fuzz.dict` holds the **target's** tokens. Re-derive; the skeleton's dictionary
  misdirects.
- Corpus from the module's real domain plus every past crash under
  `ci/fuzz/regressions/`. Replay-then-fuzz order stays.
- Report corpus size, and coverage or feature count reached at the end of the
  time-boxed run. A fresh run that plateaus in seconds is a stuck target, not a
  clean one.

**Acceptance:** unchanged from steps 24–25 and it is a mutation test — reintroduce a
past bug, confirm replay catches it in seconds, revert.

## 38 — Coverage: measured over the module only

`ci/tools/coverage.sh` exists because an unfiltered `gcovr` reports ~1% — nginx
core is instrumented by the same configure run and swamps the module.

- Confirm the target's coverage filter names the target's `src/`, not the
  reference's, and that the reported figure moves when a test is deleted. A
  number that does not move is filtered wrong.
- **`--object-directory`, never `--gcov-object-directory`** — the latter arrived
  in gcovr 7.0 and is a hard argparse failure below it. The condition is the
  gcovr major version the job actually runs, not whether a pin exists.
- Raise coverage by adding boundary cases to `ci/tests/unit/test_scan.c` — the
  cap, the seam, the hold window, off-by-one on each — not by widening the filter
  or lowering `COVERAGE_FAIL_UNDER`. Uncovered lines that are genuinely
  unreachable get a comment naming why.

**Acceptance:** before/after numbers and which specific branches the new cases
reached.

## 39 — Valgrind, memcheck, helgrind

The reference splits these deliberately: `valgrind.yml` is a 60s memcheck lite on
the merge path; `ci-deep.yml` runs the 600s memcheck **and** helgrind soaks
monthly, both through `ci/tools/soak.sh` (`USE_VALGRIND` / `USE_HELGRIND`).

**Unconditional — these are grep-cheap and cost nothing on a quiet module:**

- Confirm both soaks exist and that **helgrind is actually invoked** — a copied
  `ci-deep.yml` that lost the helgrind job still shows a green CI Deep badge. A
  dormant module is exactly where a silently-missing job survives longest.
- `valgrind.supp` needs the **target's** nginx-core suppressions. An over-broad
  suppression silently covers the module's own errors: check each entry is scoped
  to a core frame, and that the file was regenerated rather than copied. This is
  independent of recent activity — a stale suppression hides today's bugs.
- Helgrind is only meaningful if the target has shared state across workers (shm,
  a timer, a resolver callback). If it has none, say so explicitly rather than
  running a soak that can never report.

**Running the soaks is conditional.** 600s memcheck plus helgrind on code that
has not moved since the last green deep run re-proves a known result. Skip if
**all** of the following are unchanged since that run:

```sh
LAST=<sha of the last green ci-deep run>
git diff --stat $LAST..HEAD -- src/ ci/ .github/versions.env
```

Anything there → run them. Note the deliberate inclusion of `versions.env`:
`bump.yml` bumps pins weekly and `ci-deep.yml` runs monthly, so a module with
**zero source commits can still be running against a new nginx**. Commit recency
in `src/` alone is the wrong clock. A submodule bump of `ci/vendor/nginx-tests`
counts the same way.

**Acceptance:** when run — the soak is under real load and reaches the module
(step 36's evidence applies), a deliberate leak is reported before you trust it,
and wall-clock per soak is stated. When skipped — the sha you compared against
and the empty diff, in the PR body. A silent skip is indistinguishable from a
soak that never existed.

## 40 — Re-audit caching

Steps 40–42 are three audits that all need numbers and all become wrong as the
workflow set grows. One PR, or one each.

Audit `ci/tools/ci-build.sh` as the single chokepoint; no workflow may duplicate
cache logic. Walk the layers cheapest-first and confirm each: apt/packages,
ccache (`CCACHE_COMPILERCHECK=content`), mold (skipped under ASan), eatmydata
(wraps configure/install only), build tree, source tarball (sha256 verified after
restore). `bear`/`compile_commands.json` where clang-tidy consumes it.

- **nginx's `configure` ignores a bare `CC=`** — confirm ccache is wired through
  the configure argument, then prove it: report the hit rate from a warm run. A
  0% hit rate on a second identical run means it is not wired, whatever the log
  says.
- ccache may use a `restore-keys` ladder; the **build-tree cache stays
  exact-match only**. Do not "fix" that for consistency.
- Keep the hybrid restore (warm on-disk dirs + `actions/cache` fallback).
- A cold PR run is not a bug: GitHub scopes caches by ref.
- The rule that outranks every speedup: **a cache must never serve a stale
  artifact into a green result.** Check each key includes what actually changes
  the output.

**Acceptance:** the warm-run ccache hit rate, and one key per layer with what
invalidates it.

## 41 — Does every checker still bite?

`zizmor`, `actionlint`, `yamllint`, `semgrep`, `codespell` and the three
repo-policy checks were installed at steps 29–31. This does not re-install them;
it asks whether each still fires. A checker that has become a no-op reports the
same clean line as one that passes.

- Re-run every probe in the linter README's **"Verify before trusting"** section
  against the target and observe each red. Then run with **two** checkers failing
  at once and confirm both appear and both are named in the `== FAIL:` line.
- **`semgrep` first.** `--jobs=1` and `--metrics=off` are exactly the flags that
  can silently turn it into a no-op, so its probe must still fire. `--jobs=1` is
  a correctness flag, not a speed one — see step 32.
- **`zizmor` findings drift with the workflow set.** Every workflow added since
  step 29 is new attack surface it now audits. Confirm the count of audited
  workflows matches the count in `.github/workflows/`, and that each
  `# zizmor: ignore[rule]` still names a reason that is still true. A suppression
  outlives the thing it suppressed.
- **`actionlint` remains blind to the `fromJSON` ternary** (step 10). Do not read
  a clean actionlint as evidence about runner labels; that is probe 2's job
  (step 12) and probe 2 only.
- Confirm `LINT_ONLY`'s string in `lint.yml` still matches the checkers that
  actually exist — it diverges as the set changes and nothing cross-checks it.
- `run-all.sh` reads `git ls-files`: a **new untracked file is invisible to the
  linter**. Stage before trusting a clean run.
- Re-time the hook against the ~2s budget, `/proc/loadavg` checked first.

**Acceptance:** every probe in the linter README observed red, plus the run with
two checkers failing at once in which both are named in the `== FAIL:` line.

## 42 — Re-measure the CI shape

Only with numbers from `gh run list`:

- Re-check step 34's lane topology against **measured** wall-clock, not the
  estimates in place when it was written. Lanes drift as tests are added.
- Confirm exactly one `pull_request:` entry point still holds, and that every
  member is reached — a member called by nobody keeps a stale-green badge and
  goes grey only when deleted. Re-run the double-run proof if anything moved.
- Check `/proc/loadavg` before timing anything: at load ~50 the same full-tree
  run varied 2.2s–12.4s over six attempts here, a spread wider than most wins.
- Optimise by moving work off the merge path into `ci-deep.yml`, never by
  deleting a check or widening a threshold.

**Acceptance for phase 5:** for each of steps 35–42, the measurement, and for
every gate the one sentence stating what it would now catch that it did not
before. A "verified correct" with no number attached is not an answer.

---

# Phase 6 — Close out

Docs, memory mirror, the anchor a future forward depends on, the feedback that
keeps the skeleton ahead of its clones, and the report.

## 43 — Hand the findings back to the skeleton

`$SCRATCH/skeleton-findings.md` is the deliverable of this step. It has been
accumulating since step 1: bugs in ported scripts, rules in this prompt that were
wrong or ambiguous, gates the target had that the skeleton lacks (rule 2),
checkers the reference does not carry.

Open **one PR against `myguard-labs/nginx-skeleton-module`** — the last write
outside the target in the whole job:

1. **Fix what you can fix in code.** A bug in `ci/tools/`, `ci/linter/`, a
   workflow or this `PROMPT.md` gets the actual change, with the target's
   `file:line` as the evidence in the PR body. That is the preferred form.
2. **Describe what you cannot.** Anything needing a decision, a measurement on
   hardware you do not have, or a change whose blast radius crosses every derived
   module goes in `ci/feedback/<target>-<YYYY-MM-DD>.md` in the same PR: what was
   found, where, what it cost, and the proposed change.
3. One PR, both kinds together. Remote CI green, no AI attribution, signed
   commits.

An empty `skeleton-findings.md` means no PR — say so in the report. Do not
manufacture a finding to have something to send.

**Acceptance:** either the PR URL, or an explicit "no skeleton findings" line in
the report.

## 44 — Unresolved bot replies across every PR you opened

Steps 44–45 are one PR. Both are only checkable once every earlier PR has merged,
and both produce fixes rather than sentences. Do them before writing the report,
so the report describes the finished state.

A review bot replies on its own schedule. CodeRabbit rate-limits per developer
(measured 2026-08-04: "next review available in 51 minutes"), so a review can
arrive **after** you merged, and a reply to your reply arrives later still. A
merged PR is not a closed conversation, and nothing notifies you.

Walk every PR this job opened:

```sh
for n in <the PR numbers>; do
  gh api repos/<owner>/<repo>/pulls/$n/comments --paginate \
    -q '.[] | select(.user.login|test("\\[bot\\]$")) | "\(.id)\t\(.in_reply_to_id // "-")\t\(.path):\(.line)"'
  gh api repos/<owner>/<repo>/issues/$n/comments \
    -q '.[] | select(.user.login|test("\\[bot\\]$")) | .body' | grep -iE 'limit reached|could not start'
done
```

Two things to look for, and they are different:

- **a finding you never answered** — a top-level bot comment with no reply from
  you. Verify it against the code like any other; fix, or refute with the
  `file:line` that disproves it.
- **a review that never ran** — a "review limit reached" or "could not start"
  notice means that commit was never examined at all. A green checks list does
  not distinguish this from a clean review. Say which commits were unreviewed in
  the report rather than implying coverage you did not get.

A confirmed finding that is a recurring *class* rather than a typo goes to the
narrowest matching `.claude/skills/audit-*/` reference, not only to memory — the
skill runs unprompted next time.

**Acceptance:** every bot finding answered or explicitly listed as unreviewed,
with the commits that were never examined named.

## 45 — Re-derive the linter set against the finished repo

Same PR as 44. Steps 29–31 ported `ci/linter/` and kept every checker the target
already ran. That was a merge decision made early; by now the file set has moved.
Re-derive it against what the repo actually contains:

```sh
git ls-files | sed -n 's/.*\.//p' | sort | uniq -c | sort -rn | head -20
ls ci/linter/lint-*.sh
grep -n 'LINT_ONLY' .github/workflows/lint.yml
```

Three failures, all of which report clean:

- **a language present with no checker** — Lua, Rust, Go, Python, a Dockerfile,
  a systemd unit. Add `lint-<name>.sh`; `run-all.sh` picks it up by glob. Also
  record it in `skeleton-findings.md`: a checker the reference lacks is exactly
  what step 43 sends back.
- **a checker whose language left the repo** — it passes on an empty selection
  forever. Remove it, or say why it stays.
- **`LINT_ONLY` in `lint.yml` naming a checker that does not exist**, or omitting
  one that does. Nothing cross-checks that string against the scripts on disk;
  it silently diverges every time the set changes.

**Acceptance:** `LINT_ONLY` matches `ls ci/linter/lint-*.sh`; every language with
more than a handful of tracked files has a checker or a stated reason not to.

## 46 — Docs

Steps 46–48 are one PR.

- README rewritten, not appended to: badge row, `## CI` table, layout tree,
  Requirements, and a Linting section linking `ci/linter/README.md`.
- `CONTRIBUTING.md` tells a contributor how to enable the hook.
- `CHANGES` entry describing the standardisation.

**Acceptance:** `lint-docs-drift.sh` green in both directions — every workflow has
a `## CI` row and every row a workflow.

## 47 — Memory mirror

Same PR. Skip only for an external target with no mirror, and say so.

- `index.md` — layout, lane map, measured times, **and the skeleton commit you
  adopted from**. That anchor is what the "Forwarding one later change" section at
  the end of this file depends on; without it the next session cannot tell a
  forward from a fresh adoption.
- `issues.md` — everything in `adoption-findings.md` that is still open.
- `lessons.md` — every trap that cost a red CI round-trip, `[RECURRING]` if it has
  bitten before.
- A trap that is a *class* rather than a typo goes into the matching
  `.claude/skills/audit-*/` reference, not only memory. The skill runs unprompted
  next time; memory does not.

**Acceptance:** the adopted skeleton commit SHA is written in `index.md`; every
open item from `adoption-findings.md` appears in `issues.md`.

## 48 — Report back

Same PR. Per step: what landed, what is red, what you left undone and why. Include
measured before/after wall-clock and coverage. Seven questions the report must
answer explicitly, because they are what a greenfield reading gets wrong:

1. **Entry points** — how many workflows carried `pull_request:` before, and
   confirmation exactly one does now.
2. **Runners** — which pool the target runs on. If any `self-hosted` selector
   survives, the output of probe 2 (step 12) proving the target's own gate rejects
   the reference's label. "Adapted the labels" is not an answer.
3. **Extra workflows and gates** — every check the target had that the reference
   lacks, and whether each was kept, folded, or sent upstream at step 43. If any
   was removed, what covers it now.
4. **Badges** — the final row, so order and spelling can be compared without
   opening the repo.
5. **Parked and degraded** — every step you could not complete: which one, the
   symptom, the three attempts, and what a human has to decide. Also every gate
   you degraded (hosted instead of self-hosted, a job omitted for a missing
   secret, a thin gate because a behavioural fix was out of scope). This replaces
   the old "stopped" answer: the run does not stop, so this is where the
   unfinished work is accounted for.
6. **Bot review coverage** — from step 44: every bot finding you answered, and
   every commit that was never reviewed because the bot was rate-limited or
   never ran. A green checks list does not distinguish the two, so state which
   you had.
7. **Anything left disabled, skipped or unverified** — a workflow not enabled, a
   soak skipped per step 39, a gate never seen red. Silence here reads as
   coverage that does not exist.

Do not report a step complete on a gate you never saw fail.

---

# Phase 7 — Aftermath

Everything above is done and reported. Steps 49–56 are **not** part of the
adoption, which is why they are offered rather than taken: each one either costs
real CI time or changes code this job deliberately did not touch.

**Ask once, as a single multi-select question, and do none of them unattended.**
Step 56 is the exception in one direction only: you *check* it unasked and report
what you find, because a missing gitlink bump is a defect in work already done.

Each is its own step because each is a separate session's worth of work with its
own tools — a code review and a coverage push have nothing in common but this
list.

## 49 — Recheck the implementation

Re-read this prompt against the merged result, step by step, and report which of
the 48 are genuinely done, which are partial, and which were skipped. Independent
of your own report at step 48 — the point is that it is a fresh reading, so do not
consult your own report while doing it.

## 50 — Set up linting as a commit hook

Install `.githooks/pre-commit`, wire `git config core.hooksPath .githooks`, and
ask whether to run it across the whole tree now. A first full-tree run on an
adopted module is usually red; that is findings, not failure.

## 51 — Review the changes

A diff review of every PR this job landed, one maintainer voice, regressions and
contract drift.

## 52 — Full code review

The module's own C, not just the CI: memory safety, parser boundaries, error
paths, concurrency. Out of scope for the adoption job, which is exactly why it is
offered here.

## 53 — Kick off and re-time the scheduled workflows

The scheduled lanes (`ci-deep.yml` monthly, `bump.yml` weekly) have not run yet on
a freshly adopted module, so nothing has proven they work outside the PR lane.
Offer to trigger them now (`gh workflow run`) rather than discovering a broken
cron in four weeks, and to re-check step 34's lane topology against the wall-clock
the merged suite actually produces.

**State the runner cost before starting**: a deep run is long, and on a
self-hosted pool it occupies slots other work needs.

## 54 — Broaden the dynamic analysis

Valgrind memcheck, helgrind and the fuzz targets were ported at their reference
shapes and verified to fire (steps 37 and 39). Widening them is separate work:
more fuzz targets for parse surfaces named but not covered, a longer time-box,
helgrind where the module has genuine cross-worker state, memcheck over request
shapes the soak does not currently reach.

Name the specific gaps you found rather than offering "more fuzzing" — an
unfocused increase in budget buys very little.

## 55 — Increase coverage

Report the current figure and the branches gcovr shows as never taken, then offer
to add cases for them. Coverage stays a report, not a gate (step 27): the offer is
more *meaningful assertions*, each with its negative control, never a higher
number.

If the honest answer is that the remaining uncovered lines are unreachable, say
that instead of offering.

## 56 — Anything left uncommitted or unpushed

Check this one **unasked** and report what you find either way; only the fixes are
offered rather than taken.

```sh
git -C <TARGET> status --porcelain          # untracked or modified
git -C <TARGET> log --branches --not --remotes --oneline   # committed, unpushed
git -C <TARGET> stash list                  # never yours, but say if one exists
```

Three classes, and only the first is yours to offer to fix:

- **work of yours that never landed** — a file written and never staged, a
  commit never pushed, a memory-mirror update made in the working tree only.
  `run-all.sh` reads `git ls-files`, so a new untracked file was also invisible
  to every linter that "passed" over it.
- **the dirt recorded at step 1** — it was there when you arrived. Confirm it
  is byte-identical to what you recorded and leave it alone. Do not offer to
  commit it; it is not yours and the owner cannot find it later if you do.
- **the superrepo gitlink**, if the target is a myguard submodule — every
  merged PR needs its bump on the superrepo's `master`. A missing one means the
  superrepo still points at the pre-adoption commit, which is invisible from
  inside the target and is the single easiest thing in this job to forget.

---

## Forwarding one later change into an adopted module

Once a target scores 3/3 at step 3 the job inverts: not adoption, but carrying
one later skeleton improvement across. One concern, one PR, one session.

**Establish the anchor first.** Without it you either re-land work the target has
or skip the commit that made the change work. In order of preference: a recorded
anchor in the mirror's `index.md`; a `vN` tag the target's `CHANGES` names; the
`CHANGES` entry describing its adoption; the merge commit of its adoption PR.
Then:

```bash
git -C /opt/myguard/labs/nginx-skeleton-module log --oneline <anchor>..HEAD
```

That is the candidate set; [CHANGES](../CHANGES) says what each was *for*.
**If none of the four resolves, there is no anchor** — the target never took a
documented adoption, so it is the 25-step job, not a forward. Do not invent one
from the first commit or from "HEAD minus the change I was handed"; both
manufacture a scope that was never true.

Take ONE concern. Before touching the target, write in the PR body what the gate
must prove in *behavioural* terms ("a job that starts the runtime driver without
declaring a port band fails the build"), what failure it would have caught in the
target, and whether the target can even reach that failure — a gate for a layer
it does not have is an adoption step, not a forward.

Then check the drift classes. **None is visible from a green run:**

- **Port bands** — see step 18. Read the target's step ORDER, not just the
  presence of a verify step.
- **Coverage option spelling** — `--gcov-object-directory` fails argparse on
  gcovr below 7.0. The condition is the gcovr major version the job actually
  runs, not whether a pin exists. `--object-directory` is accepted by both and is
  the portable choice for any runner whose gcovr you do not control.
- **`versions.env` consumers** — one that sources the file without validating it
  executes any line that is not a pin. Arriving for the first time? Ship the
  validating loader; there is no earlier copy to audit.
- **`workflow_policy.py` vintage** — older than the YAML-parse rewrite means it
  matches workflow YAML with regexes, and valid YAML makes all three policy
  checks silently vacuous (a `.yaml` extension, an inline `on: [pull_request]`, a
  comment after a job key). Ship the YAML-parse version and run
  `ci/linter/selftest.sh` plus `ci/linter/fixtures/policy/` in the target.
- **Runner identity** — steps 10–12. Any change touching a `runs-on`,
  `actionlint.yaml` or `TRUST_SPLITS` carries our pool with it. Run probe 2.
- **No `src/`** — step 9. Everything scoped to `src/` selects nothing and reports
  success.

Re-derive for the target rather than copying: module name and symbol prefix
(including inside fuzz targets, unit tests and grep patterns in scripts), paths,
runner expression, port bands, version pins. Keep the reference's thresholds
unless you record why not.

Two consistency gates that fail late otherwise: `lint-docs-drift` compares the
workflow set against the README's `## CI` table, so a new or renamed workflow
needs its row in the same commit; and `run-all.sh` reads `git ls-files`, so a
**new untracked file is invisible to the linter** — stage it before trusting a
clean run.

Verify the gate red in the target, run the local gate at the target's own
thresholds, then PR with workflows enabled. The body states: the anchor and how
you resolved it, the one concern, what the gate proves, the probe and what it
printed, and every deliberate divergence with its reason. Remote CI green on the
**current head** — re-check `headRefOid` before merging. Squash-merge, delete the
branch, bump the superrepo gitlink. Record the new anchor in `index.md`.

The phase-7 aftermath questions (steps 49–56) apply here too, scaled to one
concern.
