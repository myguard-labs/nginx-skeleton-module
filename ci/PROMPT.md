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

**63 steps in 7 phases, landing through 4 PRs.** Steps are numbered 1–63
continuously and referenced by number throughout; the numbers are stable and
external references (README, `ci/feedback/`) depend on them. **A step is a unit of
work, never a PR boundary.**

| Phase | Steps | What it is | Lands in |
|---|---|---|---|
| 1 | 1–6 | preconditions, inventory, score, baseline | nothing (read-only) |
| 2 | 7–9 | the decision seam — the one C refactor | PR1 |
| 3 | 10–15 | layout and runner identity | PR1 |
| 4 | 16–38 | workflows, tests, fuzzing, caching, linter, lanes | PR1 (16–22), PR2 (23–38) |
| 5 | 39–48 | depth pass — would any of it catch anything? | PR3 |
| 6 | 49–54 | close out: skeleton feedback, post-adoption checks, docs, report | REF49 + PR3 |
| 7 | 55–63 | mandatory aftermath | PR4 |

**The four PRs.** Boundaries are fixed; do not split one into step PRs and do not
merge a partial one.

| PR | Steps | What it is |
|---|---|---|
| PR1 | 7–22 | seam, `ci/` layout, runner identity, entry-point demotion, workflow set, badges |
| PR2 | 23–38 | the four test layers with their mutation passes, fuzzing, coverage, caching, linter gate, lane topology |
| PR3 | 39–54 | depth pass, post-adoption checks, docs, memory mirror, prepared report |
| PR4 | 55–63 | aftermath: recheck, reviews, scheduled lanes, residue, gitlink |
| REF49 | 49 | the skeleton feedback PR — against the reference, not the target |

Phase 5 (PR3) opens only after PR2 has merged: it asks whether the gates PR1 and
PR2 installed would catch anything, and that question is meaningless against
unmerged work. Phase 7 (PR4) always runs after migration, forwarding, or a no-op.
An inapplicable aftermath step needs evidence; it is never skipped merely because
no full migration was required.

### Two barriers inside PR1

PR1 is large and contains the only two irreversible moves in the job. Both are
**hard barriers inside the branch** — the later steps do not begin until the
earlier evidence exists and is pasted into the PR body.

1. **Steps 13–15 (runner identity) complete before step 16.** Porting a workflow
   set before the `runs-on` question is settled means porting our pool into it.
2. **Step 17's double-run proof completes before step 18.** Step 18 removes
   `pull_request:` from every member and is the only action in the job that can
   leave the repo with no PR gate at all. It is taken only on a run list showing
   **every** member running twice. No proof, no step 18 — accumulate the rest of
   PR1 and record the block.

Because PR1 is one revert boundary, a revert also unwinds the seam extraction and
the `ci/` move. That is the accepted cost of the group; it is the reason both
barriers are stated as blocking rather than advisory. If the merged result gates
nothing, revert PR1 whole and diagnose outside the default branch — an ungated
default branch is not a state to debug in place.

### Model floor

Every step uses `[sonnet or a stronger model]` unless tagged `[opus]`. Do not
delegate any step to Haiku. The controller sends a worker only the execution
rules, current PR row, current step, target inventory, and prior result. The
controller, not the worker, owns the shared branch and PR.

Every run starts at step 1, including a full, partial, abandoned, or claimed
complete migration/import/adoption. After inventory, evaluate each PR's steps in
numeric order. Cross a PR off only when every step's Acceptance condition is
proven against the current tree; otherwise complete it through that one PR. Never
resume where an earlier attempt claimed it stopped.

**This is a merge, not an install.** Assume the target already has CI somebody
relies on. Measured across the eight derived modules on 2026-08-03: every one has
three to six workflows each carrying its own `pull_request:` trigger, not one has
a `ci.yml`, six have no `ci/`, two have no `src/`. An external adopter is likelier
still to have a suite predating any contact with this repo.

Three rules outrank every step:

1. **Adopt the convention, keep the content.** Layout, ordering, naming and entry
   points are the standard. The target's tests, thresholds, fuzz corpus, nginx
   compatibility range and linter selection are its own. A 1:1 copy is wrong by
   construction — the reference's tests test the reference's module.
2. **Never delete a gate the target already has.** Anything it checks that the
   reference does not survives, gets a badge and a table row, and goes back to the
   skeleton (step 49). A rollout that reduces coverage is a regression wearing a
   standardisation PR.
3. **Nothing self-hosted is portable.** `builder02` is a myguard machine and no
   linter here will tell an adopter they copied it — `TRUST_SPLITS` ships
   containing that label and **approves it by construction**, so a copied selector
   is green everywhere until it dispatches to hardware the target does not own, or
   queues forever against a label nobody answers. Step 3 records `POOL_OWNED`;
   step 13 settles it before any workflow is ported. The default is hosted-only,
   and an unfamiliar `origin` is always hosted-only.

Standing constraints, all steps:

- **One branch and at most one target PR per group, never per step.** Start the
  branch at its first applicable step; accumulate steps as independently
  reviewable commits; open/update one PR; merge only when every applicable step in
  it is complete. A group with no tracked target change records evidence and opens
  no empty PR. Step 49's reference PR and superrepo gitlink commits are the
  explicit cross-repo exceptions.
- **Remote CI green before merge**, workflows enabled — see step 2 on what you may
  not do to get there.
- **Every gate must be seen red once, in the target.** A probe run against the
  reference is not evidence about the target: different paths, files and
  thresholds. Record the probe and its output in the PR body.
- **Never weaken a gate to make the target pass.** If it genuinely cannot meet a
  threshold, say so with the `file:line` that proves it and leave the gate at the
  honest value with a comment naming the reason.
- **Existing behaviour is not in scope.** You are moving CI, not rewriting the
  module. A real bug found on the way goes in `issues.md`; fix it only if it blocks
  the gate you came to install.
- Comments explain **why**, at the decision, in the target's voice. A rule with no
  recorded reason gets deleted by the next person who finds it inconvenient.
- **Keep the todo list live.** Step 6 writes it; every step after keeps it accurate
  — one item `in_progress`, items closed on merge, not on push.

### The rejected-test list

Applies to every test written or ported in steps 23–29, and to every mutation
claim in steps 24, 26, 40, 41 and 61. Referenced by number from those steps rather
than repeated:

1. a test whose assertion holds in both the pass and fail state (tell: a captured
   variable never compared)
2. a control that hardcodes the verdict instead of calling the real function
3. asserting a *precondition* rather than the claim
4. one shared counter asserted at N call sites — it pins none of them
5. a test written from the same misunderstanding as the code
6. excluding a hard file from the coverage config to lift the percentage
7. tests that execute lines without asserting on the result

And three ways a mutation pass fails while looking like success:

8. **the mutation survives** — the test guards nothing. That is the finding.
9. **the mutation does not cross the threshold** — clearing a counter below the
   level the code acts on proves nothing; mutate past the boundary the assertion
   names.
10. **a build-time guard masks it** — a `grep`-based build check that rejects the
    mutated source means the tests never ran against it. Confirm the mutated build
    compiled and executed.

### The green-that-proves-nothing classes

Most of this job targets checks that pass while checking nothing. Stated once
here; individual steps name which class they close.

- **Empty selection.** No `src/` → `lint-c.sh`, `lint-nginx.sh`, the gcovr filter
  and the CodeQL TU filter all select nothing and *pass*. (step 12)
- **Wrong tree.** An unfiltered `gcovr` reports ~1% because nginx core swamps the
  module; a copied `valgrind.supp` suppresses the module's own errors; a copied
  CodeQL TU filter analyses nothing. (steps 29, 30, 42, 43)
- **Unreached code.** An ASan soak against a default config where the handler
  never runs is clean forever. (steps 28, 40)
- **A copy instead of the real thing.** A unit test or fuzz target compiled
  against a reimplementation rather than the module's real decision TU is green
  and meaningless. (steps 7–9, 23, 27, 39)
- **Pointing at the wrong repo.** A copied badge row resolves against
  `myguard-labs/nginx-skeleton-module` and renders green while telling you nothing
  about the target. (step 22)
- **Called by nobody.** A member workflow `ci.yml` never actually calls keeps a
  stale-green badge and goes grey only when deleted. (steps 17, 48)
- **A checker turned no-op.** `LINT_ONLY` naming scripts that do not exist, a
  semgrep flag that silently disables it, a suppression outliving its cause — each
  reports the same clean line as a passing checker. (steps 34, 46, 47)

## Work autonomously — record, do not ask

**Default to proceeding.** This job runs unattended. Almost everything that used
to be a stop is now a recorded finding: you write it down, degrade the affected
step honestly, and carry on. A run that stops at step 3 with a question delivers
nothing; a run that finishes 61 of 63 steps and hands back a precise list of the 2
it could not do delivers almost everything.

Two files carry what you cannot act on. Create both at the start of step 1:

- **`$SCRATCH/adoption-findings.md`** — anything about the TARGET you could not
  fix: red baseline tests, a gate that will not go green, a behavioural bug, a
  missing secret. At step 53 this is merged into the target's `issues.md` and
  summarised in the report.
- **`$SCRATCH/skeleton-findings.md`** — anything about the REFERENCE: a bug in a
  ported script, a rule that could not be followed as written, a gate the target
  has that the skeleton lacks (rule 2), a step in this prompt that was wrong or
  ambiguous. Step 49 turns this into a PR against the skeleton.

`$SCRATCH` is the session scratchpad directory, or `$(mktemp -d)` if none. One
entry per finding: what, the `file:line`, what you did instead, and what a human
has to decide. An empty file at the end is a valid result; a finding you kept in
your head is not.

### Only these are hard stops

| Condition | Why it cannot be worked around |
|---|---|
| `<TARGET>` is not a git repository | nothing to branch, nothing to PR |
| No push access — `viewerPermission` is not `ADMIN`/`MAINTAIN`/`WRITE` (step 1) | cannot land anything |
| A fix requires deleting or weakening an existing gate | rule 2 — that is a coverage regression, and the point of the job is the opposite |

Everything else: record and continue. Explicitly, and against the old rules:

- **Dirty target tree** — do not stop, do not ask, do not `git stash`. Note the
  dirty paths in `adoption-findings.md`, branch off `HEAD`, and never `git add` a
  file you did not change. The dirt survives untouched.
- **Baseline suite already red** — record which tests, branch anyway, and state the
  pre-existing failure in every PR body so no later step inherits blame. Do not fix
  it unless it blocks the gate you came to install.
- **A gate red twice for reasons you cannot explain** — attempt it three times,
  then park that step: revert its commits, record the symptom and the three
  attempts, and move to the next step. Do not retry indefinitely and do not merge
  it red.
- **A step needs a behavioural change to the module** — do not make it. Land the
  rest of the step, record the required change with its `file:line`, and mark the
  gate thin in the PR body.
- **CI needs a secret or a runner the target lacks** — do not invent either.
  Degrade: hosted runner instead of self-hosted, the job omitted rather than
  broken, and a finding naming exactly what is missing.
- **A write outside `<TARGET>` seems necessary** — it is not. It goes in a findings
  file. The only writes to another *repository* are the two in step 2 and step 49's
  skeleton PR; `$SCRATCH` is untracked working space and is not one of them.

**Never disable a failing check to make a PR mergeable.** Not `[skip ci]`, not
`continue-on-error`, not commenting out a step, not `gh workflow disable`, not
lowering a threshold to the observed value. A red gate you cannot fix is a
finding, and the honest end state of a step.

---

# Phase 1 — Establish what you are working with

Read-only, nothing committed. Six steps: prove you can work here, inventory and
score it, record the baseline and the run plan.

## 1 — Set up the run `[sonnet or a stronger model]`

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
you. The four snapshots preserve both the path set and contents; step 62
recreates and compares them. Keep them in `$SCRATCH`, never the target.

**Hard stop only if** the directory is not a git repo, or `gh` cannot authenticate
against this remote. Anything else found here is a finding.

**Acceptance:** both findings files and all four dirt snapshots exist; base branch
recorded; you know the remote.

## 2 — Scope, git safety, rollback `[sonnet or a stronger model]`

Read once, applies to every later step.

**One repo is writable: `<TARGET>`.** This reference, sibling modules and
`/opt/myguard/packages` are read-only for the whole job. Reading the reference is
the point; committing to it is not — except step 49's single skeleton PR.

Two writes outside the target are expected, and only these two:

- **The target's own memory mirror**, `memory/labs/<name>/` or
  `memory/eilandert/<name>/`.
- **The superrepo gitlink**, once per merged PR, if `<TARGET>` is a myguard
  submodule. The target PR merges first, then the gitlink bump lands signed on the
  superrepo's `master`. An external target has no gitlink and no mirror; skip both
  and say so.

A dirty submodule or unrelated change in another tree is left exactly as found. Do
not commit it, revert it, or `git checkout` over it.

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
  commits to that branch; they never create step branches or step PRs.

**Rollback.** Each PR is one revert boundary. Keep its step commits independently
reviewable, but revert a merged PR through one new PR. Do not force-push over
history others have pulled, and do not "fix forward" by stacking a second broken
change on the first.

**Acceptance:** nothing to produce; this step is read and obeyed.

## 3 — Run the inventory probes `[sonnet or a stronger model]`

Steps 3–6 are the measurement everything downstream is planned from. This one
collects raw output; 4 scores it, 5 records it, 6 baselines the suite and writes
the run plan.

```bash
cd <TARGET>
git remote get-url origin                                # who owns it
ls -d ci/t ci/tools ci/linter ci/fuzz src t tests fuzz 2>/dev/null
ls .github/workflows
grep -lE '^\s*pull_request:' .github/workflows/*.yml | wc -l   # entry points
grep -rn 'runs-on' .github/workflows/                    # whose machines?
ls src 2>/dev/null || ls *.c *.h                         # C at root?
ls src/*_scan.c src/*_scan.h *_scan.c 2>/dev/null        # decision seam? (step 7)
grep -ln 'ngx_http_request_t' src/*_scan.c *_scan.c 2>/dev/null  # expect no hits
grep -nE '!\[' README.md                                 # badge row + order
git log --oneline -10
gh run list -R <owner>/<module> --limit 20 \
   --json name,conclusion,startedAt,updatedAt,workflowName
```

**Read the memory mirror first if the target is ours** — `index.md`, `issues.md`,
`lessons.md`. A trap recorded there outranks anything you infer from the code.

### Record `POOL_OWNED` now — it binds every later step

The `origin` URL is the input to the only question that can put our hardware in
someone else's repository. Answer it once, here, in writing, before any workflow
is read:

```sh
git remote get-url origin
# myguard-labs/* or eilandert/*  -> POOL_OWNED=yes   (our machine, our pool)
# anything else                  -> POOL_OWNED=no    (hosted-only, no exceptions)
```

**`POOL_OWNED=no` is the default and the safe answer.** An unfamiliar remote, a
fork, a mirror, a local path, a detached checkout with no `origin` at all — every
one of those is `no`. Do not reason from the module's *name*: a repo called
`nginx-foo-module` under an unfamiliar owner is not ours, and the naming convention
is the thing an adopter copies first.

Under `POOL_OWNED=no`, these hold for the whole run and are not revisited:

- every `runs-on` is a bare `ubuntu-latest` — no ternary, no `fromJSON`, no
  `self-hosted` (step 13)
- `TRUST_SPLITS` is an empty frozenset and `.github/actionlint.yaml` declares no
  `self-hosted-runner:` block (step 14)
- no step may introduce a self-hosted selector "temporarily to measure something".
  Steps 36–38 become hosted-only scheduling work.

Write the value into the todo verbatim. A later step that finds `POOL_OWNED`
unrecorded stops and re-derives it rather than inferring from whatever the
workflows currently say — the workflows are the thing under suspicion.

**Acceptance:** every command above run, with its output kept — steps 4–6 all read
from it, and re-running against a moved tree gives different answers.

## 4 — Score the three markers `[sonnet or a stronger model]`

**Is the target already standardised?** Score three markers: a full `ci/` layout
(`ci/t`, `ci/tools`, `ci/linter`, `ci/fuzz`); `ci.yml` as the sole `pull_request`
entry point; `ci/linter/run-all.sh` plus a tracked `.githooks/pre-commit`.

A 3/3 score makes the target a forward candidate; it does not prove the migration
complete. Evaluate PR1's and PR2's steps in order. If any applicable Acceptance
condition is unmet, use the migration route. Only when all are proven already done
or not needed may the run use "Forwarding one later change" at the end. Anything
below 3/3 starts the migration route immediately.

Do not infer the score from the first marker you check. Two derived modules have a
`ci/` directory and still score 0/3 — `ci/` is the cheapest half of step 10 and the
most misleading signal in the set. **No `ci.yml` settles it on its own.**

**Acceptance:** the score, 0/3 to 3/3, with the evidence for each marker named
separately. A score asserted without three pieces of evidence is a guess.

## 5 — Record the inventory `[sonnet or a stronger model]`

Record in the memory mirror (`/opt/myguard/memory/labs/<module-name>/index.md` for
ours; an external target has no mirror — create one only if the work is ongoing):

- current layout, whether `src/` exists, and **whether the decision seam exists**
  (step 7). Absent or nominal is the largest code change in the job — size it here.
- workflows in three buckets: **matches** a reference workflow by purpose,
  **missing**, and **extra**. The third bucket is what rule 2 protects and what gets
  lost otherwise; every entry also goes to `skeleton-findings.md`.
- **every `pull_request:` entry point by name** — that count is the size of the
  steps 16–18 demotion, the riskiest edit in the job
- whose runners it currently uses
- **measured wall-clock per workflow** from `gh run list` — real numbers, needed for
  steps 36–37. Estimates are not acceptable there.
- current coverage number, if any tooling exists (usually none)
- gates it has that the reference lacks, and where they run

**Acceptance:** all seven items written down. The three workflow buckets and the
per-workflow wall-clock table are the two later steps cannot reconstruct once files
have moved.

## 6 — Baseline the suite, then write the run plan `[sonnet or a stronger model]`

**Baseline the target green.** Run whatever suite it has and record the result. If
it is already red, that is a finding and a fact every later PR body must state —
otherwise the first step that lands code inherits blame for a failure that predates
it. Do not stop; do not fix it.

**Emit the run plan as a todo list.** As the last act of this step, call `TodoWrite`
once with **exactly one item per PR** plus the barriers inside PR1 — not one per
step and not one per phase. Cross a PR off as `already done` or `not needed` only
when current-tree evidence proves every step in it; never infer completion from the
3/3 score alone.

```text
[x] Steps 1-6 — findings files, inventory, score, baseline
[~] PR1: steps 7-22 — seam, ci/ layout, runner identity, demotion, workflows, badges
      barrier A: steps 13-15 complete before step 16
      barrier B: step 17 double-run proof pasted before step 18
[ ] PR2: steps 23-38 — test layers + mutations, fuzz, coverage, caching, linter, lanes
[ ] REF49: step 49 — skeleton findings PR, or evidence-based no-op
[ ] PR3: steps 39-54 — depth pass, post-adoption checks, docs, memory, report
[ ] PR4: steps 55-63 — aftermath: recheck, reviews, scheduled lanes, residue, gitlink
```

Keep it current: exactly one PR is `in_progress`; flip it to `completed` only when
it merges, or when every step is evidence-proven already done/not needed and no PR
is required.

**Acceptance:** the baseline result recorded — pass, or the named failing tests —
and the todo list written with steps 1–6 already closed.

---

# Phase 2 — The decision seam

Three steps, the first of PR1. This is the only C refactor in the job and every
later gate links across it. A target that already has a clean seam records that
with evidence and moves to step 10; one that does not cannot produce a meaningful
unit or fuzz result until steps 8–9 land.

Phase 2 comes before the `ci/` move: the extraction is a C refactor independent of
where the test material lives.

## 7 — Probe: which of the four states is the target in? `[sonnet or a stronger model]`

Read-only, and it decides how steps 8–9 run.

> **Decision logic goes in `*_scan.c`, taking `(u_char *, size_t)`. Only
> `ngx_http_request_t` plumbing stays in `*_module.c`.**

This is the one structural rule, and it comes before the test layers because both
link across it: `ci/tests/unit/test_scan.c` (step 23) and `ci/fuzz/fuzz_scan.c`
(step 27) compile the module's **real** decision source, not a copy. Without the
seam, step 23 tests a reimplementation and step 27 fuzzes one — both green, both
proving nothing about shipped code.

```sh
ls src/*_scan.c src/*_scan.h 2>/dev/null || ls *_scan.c *_scan.h
grep -n 'ngx_http_request_t\|r->\|ngx_http_' $(ls src/*_scan.c 2>/dev/null || ls *_scan.c)
# ci/tests/unit/run.sh is the REFERENCE's entry point, not a given for the
# target. Fall back to whatever step 6's baseline proved is the target's real
# unit entry point (e.g. ci/fuzz/run.sh, a Makefile check target, a bare
# ci/tests/*.sh) — grepping a path the target never had is silent, not "no hit".
UNIT_ENTRY="$(ls ci/tests/unit/run.sh 2>/dev/null || echo '<baseline-proven entry point>')"
grep -n '_scan\.c' ci/fuzz/build.sh "$UNIT_ENTRY" 2>/dev/null
git diff --stat HEAD~1 -- ci/fuzz/ngx_stubs.c               # did stubs grow?
```

| State | Tell | Next move |
|---|---|---|
| **clean** | no `ngx_http_request_t` in `*_scan.c` | skip step 8, go to 9 |
| **clean via extraction script** | a `ci/fuzz/extract_*.sh` copies decision bytes into a generated `.inc`, cross-checked by `#define`/checksum so drift fails the build | skip step 8, go to 9 — the drift gate is what a hand-written seam gets for free. Confirm the drift check is exercised: a source change without touching the `.inc` must fail |
| **nominal** | `*_scan.c` exists but reaches for `r->`, allocates from `r->pool`, or logs via `r->connection->log`. **Growth in `ci/fuzz/ngx_stubs.c` is the tell** — every stub beyond the reference's set is a dependency that should have been refactored out | step 8 runs |
| **none** | decision logic inline in `*_module.c` | step 8 runs |

A fifth outcome is legitimate and must be stated rather than skipped silently: the
module genuinely has **no decision logic to separate**, a pure plumbing module
whose only work is `ngx_http_*` calls. Say so with the `file:line` that shows it,
record that steps 23 and 27 are correspondingly thin, and skip steps 8–9.

**Acceptance:** the state named, with the grep output that establishes it, and —
where the seam exists — whether the fuzz and unit builds currently name it.

## 8 — Extract the seam `[sonnet or a stronger model]`

Only if step 7 found "nominal" or "none". This is a **move, not a rewrite**.

1. `*_scan.c` / `*_scan.h` take bytes and return a verdict. No nginx request types
   in the signature, no allocation from a request pool — pass a buffer in or take
   an explicit allocator argument.
2. `*_module.c` keeps the handler, directive parsing, config merging and every
   `ngx_http_*` call, and calls into the seam.

**Do not change behaviour while extracting.** The step 6 baseline must stay green
across it — run it wherever it currently lives, since `ci/` does not exist yet. A
behavioural fix that rides along makes any later bisect ambiguous; a real bug found
while extracting goes to `adoption-findings.md`.

Paths here assume `src/`; a target that still keeps its C at the repo root creates
the seam **beside the existing `*_module.c`**, and it moves under `src/` at step 12.
Do not create `src/` here — that split would land the same C in two commits.

**Acceptance:** no nginx request types inside `*_scan.c`; the module still builds;
the step 6 baseline is **unchanged**. A test already red at step 6 stays red and is
named in the PR body; do not fix it here and do not treat it as a reason to park.

## 9 — Wire the two consumers `[sonnet or a stronger model]`

The extraction is worthless until the things that link across it name the real file.

```sh
# use step 7's UNIT_ENTRY if the target has no ci/tests/unit/run.sh
grep -n '_scan\.c' ci/fuzz/build.sh "${UNIT_ENTRY:-ci/tests/unit/run.sh}" 2>/dev/null
```

Both the target's real unit entry point and `ci/fuzz/build.sh` must compile the
target's real `*_scan.c` — the same source, not a second copy. Whichever of the two
the target already has gets pointed at the seam now; the rest follow the material
into `ci/` at step 10. If the target has **neither** yet, say so: the seam is
verified by build and grep here, and by steps 23 and 27 once its consumers exist.

The reference's `build-test.yml` asserts the seam file exists by name after a
rename. Confirm the target's equivalent names the **target's** file — a path that
no longer exists makes the assertion vacuous, not failing.

**Acceptance:** every consumer that exists names the target's real `*_scan.c`, by
grep; or an explicit line saying which consumers do not exist yet.

---

# Phase 3 — Layout and identity

Where the material lives, and whose machines it names. Both settled before a single
workflow is ported. **Steps 13–15 are barrier A: they complete before step 16.**

## 10 — Move CI material under `ci/` `[sonnet or a stronger model]`

```text
ci/
  t/                     Test::Nginx suite            (was t/ or tests/)
  tests/unit/            C unit tests of the decision core
  fuzz/                  libFuzzer targets, dict, corpus/, regressions/
  vendor/nginx-tests/    upstream suite submodule
  tools/                 ci-build.sh, nginx-tree.sh, test_runtime.py,
                         coverage.sh, max-port.sh, ci-hang-guard.sh, soak.sh
  linter/                local lint gate (steps 32–35)
```

- `git mv`, never copy-then-delete — blame must survive. Verify with
  `git log --follow` on one moved file before continuing; a move recorded as
  delete+add loses history silently and cannot be repaired after merge.
- `git submodule update --init` still working after moving `ci/vendor/nginx-tests`
  is a required check — the `.gitmodules` `path:` must be edited, not just the
  directory moved.
- Run the suite after the move and before any workflow edit, so a failure is
  attributable to one thing: `TEST_NGINX_TIMEOUT=20 prove -v ci/t/`

**Acceptance:** local `prove` green, fuzz targets still build (`ci/fuzz/build.sh`),
`git log --follow` shows history on a moved file.

## 11 — Fix every path that climbed out `[sonnet or a stronger model]`

The half that silently fails. A directory move breaks **every relative path that
climbs out of it**. Grep and fix in this order:

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

A missed climb compiles fine and silently tests the wrong tree.

**Acceptance:** no path outside `ci/` refers to `t/`, `tests/` or `fuzz/`; the
module still builds; `prove` still green.

## 12 — Create `src/` if the target has none `[sonnet or a stronger model]`

Skip if `src/` already exists — but check, do not assume: two of eight derived
modules keep `ngx_http_<name>_module.c` (sometimes plus `<name>_core.c/.h`) at the
repo root.

This is the empty-selection class, and it is not cosmetic. Everything downstream is
scoped to `src/` — `lint-c.sh`, `lint-nginx.sh`, the gcovr filter, the CodeQL TU
filter — and every one *passes* on an empty selection rather than failing.

Move the C under `src/` — including the seam files from steps 8–9 — and update
nginx's module `config` in the **same commit**, or the module stops building.

The linter is not ported until step 32. Do not call it here. Record the deferred
empty-selection probe in the todo: immediately after step 32, a `malloc`/`strcpy`
probe beside the module's real C must make `LINT_ONLY="c nginx" ci/linter/run-all.sh`
exit 1 before PR2 can merge.

**Acceptance now:** every module `.c`/`.h` is listed by `git ls-files 'src/*.[ch]'`,
nginx's module `config` resolves those paths, and a clean rebuild succeeds.
**Deferred acceptance at step 32:** the recorded probe exits 1; green means the
selection is still empty.

## 13 — Runner identity: rewrite every `runs-on` `[sonnet or a stronger model]`

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

**Start from what the target actually has, not from what the reference has:**

| The target's `runs-on` | What it means | What you do |
|---|---|---|
| fork ternary naming `builder02` | copied from us, or a former myguard repo | rewrite all to `ubuntu-latest`; the case this step was written for |
| a **bare list** — `[self-hosted, builder02, lxc]`, no ternary | worse than the ternary: no fork arm, so a fork PR runs on our host | same rewrite, and note it in the PR body — fork PRs have been reaching our pool |
| already `ubuntu-latest` everywhere | nothing to do here | confirm, record it, move to step 14 — do **not** add a ternary |

The third row is what an adopter gets wrong by following the reference too
faithfully: seeing the skeleton's ternary and reproducing it. A hosted-only target
that gains a ternary has gained a selector pointing at hardware it does not own,
from a step whose entire purpose was to remove one.

```yaml
# before (reference, myguard-owned pool)
runs-on: ${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || fromJSON('["self-hosted","builder02","lxc"]') }}

# after (any adopter without their own pool)
runs-on: ubuntu-latest
```

**Order matters: workflows first (13), the two policy files second (14), the probes
last (15).** The gate is the last thing to change, so its findings are about what
remains.

Stated honestly so nobody optimises it back: the self-hosted pool is what makes
`ci-deep.yml`'s monthly matrix and the long fuzz runs affordable. On hosted runners
those are slower and bounded by the 6-hour job limit. That is a scheduling problem,
not a reason to point a `runs-on` at hardware you do not control.

**Only under `POOL_OWNED=yes`** is self-hosted available at all, and then it is
opt-in and a separate commit — never smuggled into the port. All three files change
together with their own labels, the fork arm stays the hosted runner, and the
condition stays `github.event.pull_request.head.repo.fork` — not `github.actor`,
not a repo variable, both of which a fork controls. Then read steps 36–38 in full.

"The target is ours and shares our build host" is a claim about **hardware and
runner registration**, not about the GitHub org. A myguard-owned repo whose CI has
never been registered with the pool is still `ubuntu-latest`: a selector is answered
by a registered runner or by nothing, and "nothing" is a job queued forever on a
green-looking PR.

**Acceptance:** no `runs-on` names a label the target does not own; `actionlint`
still parses every workflow; the PR body states `POOL_OWNED` and, if `yes`, which
registered pool answers the labels.

## 14 — Runner identity: the two policy files `[sonnet or a stronger model]`

After 13 and before 15. Two files, and the second is what this sequence exists for:

1. `.github/actionlint.yaml` — if present, delete the `self-hosted-runner:` block;
   declaring labels you never use trains the next person to add one.
2. `ci/linter/workflow_policy.py` — if present, reduce `TRUST_SPLITS` to an empty
   frozenset. `HOSTED.fullmatch` covers every selector now, and an empty
   approved-set makes any future self-hosted selector a finding rather than a silent
   pass.

If either file does not exist, do not port the linter early. Record its hosted-only
state in the todo and apply it when step 32 creates the file.

**Do this after 13, never before.** Emptying `TRUST_SPLITS` while the workflows
still carry self-hosted selectors produces one finding per selector: doing it in the
reference produced **16 findings** — the probe plus all 15 real selectors. Expected
intermediate state, and exactly the noise that buries the finding you are hunting at
step 15.

**Acceptance:** each existing policy file has the target-owned state above; each
missing file has the same state recorded for step 32.

## 15 — Runner identity: verify, both directions `[sonnet or a stronger model]`

Last of barrier A. A grep proving `builder02` is absent says nothing about whether
the *checker* still approves it.

```sh
# 1. no myguard runner identity survives anywhere
grep -rn 'builder02\|b02lxc' .github/ ci/linter/workflow_policy.py 2>/dev/null
#    -> expected: no hits for a hosted-only adopter

# 1b. and no self-hosted selector survives under ANY spelling. Probe 1 greps our
#     CURRENT label; it cannot see `[self-hosted, lxc]`, a renamed pool, or a
#     ternary whose fallback arm was edited to a different machine. This one asks
#     the question by shape instead of by name, and needs no linter to exist yet.
grep -rnE 'runs-on:.*(self-hosted|fromJSON)' .github/workflows/
#    -> POOL_OWNED=no: MUST be empty. Any hit is a selector pointing at hardware
#       the target does not own, whatever it is called.

# 2. after step 32, the checker rejects the reference's selector
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

If `ci/linter/run-all.sh` does not exist yet, do not call it or port it early.
Record probe 2 as deferred and run it immediately after step 32, before PR2 merges.
Probe 1, probe 1b and `actionlint` are the barrier-A checks.

**Probe 2 going green in the target is the bug this sequence exists for** — it means
`TRUST_SPLITS` was copied unedited. Go back to step 14; do not delete the probe.

**In the unedited reference probe 2 exits 0, correctly** — `builder02` is an
approved selector *here*, on our machine. The probe is a statement about the TARGET.
Running it in the reference to "check the probe works" proves nothing.

**Acceptance now:** probes 1 and 1b empty and `actionlint` parses every edited
workflow. **Barrier A is now clear; step 16 may begin. Deferred acceptance at step
32:** probe 2 is red; paste both outputs in the PR body.

---

# Phase 4 — Adoption

Twenty-three steps. Steps 16–22 finish PR1; steps 23–38 are PR2.

The demotion (16–18) is the highest-risk sequence in the job. It is three steps
because it is three *states of the repo*, each verified before the next — doing it
in one pass is how a repo ends up with no PR gate at all. Do the demotion before
adding any workflow: adding one to a repo that still has six triggers multiplies the
problem.

The target has N workflows each carrying `pull_request:` (measured: three to six,
with `workflow_call:` nowhere). End state after 18: exactly one `pull_request:`, in
`ci.yml`, everything else reachable only as a `workflow_call:` member.

## 16 — Add `workflow_call:` to every member `[sonnet or a stronger model]`

Add `workflow_call:` to each member **while leaving its `pull_request:` in place**.
It still runs standalone, so the target keeps working and this step cannot break
anything.

**Acceptance:** every member carries both triggers; `actionlint` clean; a PR run
shows the same set of checks as before, no more and no fewer.

## 17 — Add `ci.yml` and prove the double-run `[sonnet or a stronger model]`

**This step is barrier B.** Add `ci.yml` calling every member. Verify **on a real
PR** that each member runs *twice* — once standalone, once called. Two runs is the
expected intermediate state and the proof the call graph is wired.

Skipping this proof is how a member ends up called by nobody: `ci.yml` references a
job name that does not exist, the call contributes nothing, and the suite looks green
because the check that would have failed never ran.

**Acceptance:** the run list showing every member twice, pasted in the PR body. A
member that ran once was never called — fix `ci.yml` and re-run. **Step 18 does not
begin until this evidence exists.**

## 18 — Remove `pull_request:` from every member `[sonnet or a stronger model]`

One commit. Now each member runs once.

**This is the point of no return**, and the only action in the job that can leave
the repo with *no* PR gate at all. Do not take it until step 17 showed **every**
member running twice — a member that ran once was never called, and removing its own
trigger silences it completely. If even one did not double-run, fix `ci.yml` and
repeat step 17; do not proceed on the theory that it will resolve itself.

Two things that break a called workflow and not a standalone one:

- **`secrets: inherit` is not automatic.** A member that used a secret while
  standalone loses it when called unless the caller passes it.
- **Path filters do not work on a called workflow** — it cannot filter its own
  triggering. Gates move to a `changes` job in the orchestrator with an explicit
  job-level `if`. See step 37 rule 8.

A second entry point that is not `pull_request:` (a `schedule:`, a
`workflow_dispatch:`) is fine and normal — `bump.yml` and `ci-deep.yml` in the
reference are schedule-driven and not members of the PR lane.

**Acceptance:** exactly one workflow carrying `pull_request:`, proved by
`grep -lE '^\s*pull_request:' .github/workflows/*.yml`, and a PR run in which every
member ran exactly once.

## 19 — Port the workflow set `[sonnet or a stronger model]`

| Workflow | What it must gate in the target |
|---|---|
| `ci.yml` | orchestrator; the ONLY `pull_request` entry point |
| `lint.yml` | the `ci/linter/` gate (steps 32–35), hosted runner |
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
13–15).

**Acceptance:** `actionlint` clean; every workflow above either present or
explicitly accounted for as not applicable to this target.

## 20 — Triage the workflows the reference does not have `[sonnet or a stronger model]`

Rule 2 lives here — this step decides whether the rollout reduces coverage.

**Workflows the target has and the reference does not survive.** One derived module
carries a `runtime-tests.yml` with no reference equivalent; two carry a `bump.yml`
the other six lack. For each, decide and write down which:

- **keep as-is** — it gates something real. Give it a `## CI` row and a badge at
  step 22, and add it to `skeleton-findings.md` for step 49.
- **fold into a reference workflow** — it duplicates a gate under another name.
  State what moved where.

Do not delete one on the grounds that the reference has "the same thing" until you
have compared the actual checks; a same-named workflow often gates less.

**Acceptance:** every extra workflow classified keep/fold with a written reason, and
every "keep" queued for a badge at step 22.

## 21 — Port bands `[sonnet or a stronger model]`

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

## 22 — Badges and the `## CI` table `[sonnet or a stronger model]`

Last step of PR1 — the one thing every reader sees first.

```text
Build&Test, Security Scanners, Fuzzing, Valgrind, CodeQL, A/UBSan, CI Deep
```

with Lint inserted where the `## CI` table puts it, and the two kept in lockstep.

The label text is part of the convention. Measured 2026-08-03: a derived module had
all seven badges in the correct order but wrote `Build & Test` for `Build&Test` and
`Security scanners` for `Security Scanners`. Match spelling and capitalisation
character for character, so a diff across modules shows real differences only.

- badge row order == `## CI` table order == the list above
- an **extra** workflow kept at step 20 goes at the END of both lists, after CI
  Deep, so the shared prefix stays comparable across modules
- every badge must resolve to a workflow that exists — one for a deleted workflow
  renders a permanent grey "no status" and is worse than no badge
- **the URL owner/repo is the target's**, not `myguard-labs/nginx-skeleton-module`.
  A copied badge row pointing at the reference renders green while telling you
  nothing about the target.

**Acceptance:** every badge resolves to a real workflow in the target's own repo; CI
table and badge row in identical order and spelling; `lint-docs-drift.sh` green in
both directions. **PR1 is now complete — merge it before opening PR2.**

## 23 — Unit tests over the real decision TU `[sonnet or a stronger model]`

**PR2 opens here.** First of the four test layers. **Reuse the reference's harness;
do not re-derive it.**

`ci/tests/unit/` — `run.sh` + `test_scan.c`. Links the target's REAL decision TU and
nginx's REAL `src/core/ngx_string.c`; no shimmed decoder, ever. A shim makes the
layer hermetic and worthless. Reuses `ci/fuzz/ngx_stubs.c`.

Push toward the maximum by targeting, in order: error paths, allocation failure,
malformed/truncated input, boundary values at every `MAX_*` constant, cross-buffer
seams, and the branches gcovr shows as never taken. 100% is not the goal; every
*reachable* branch having a meaningful assertion is.

The rejected-test list (items 1–7) applies.

**Acceptance:** `run.sh` links the target's real `*_scan.c` (grep it, do not assume);
the suite is green; every branch you intended to cover has an assertion on the
result, not merely execution of the line.

## 24 — Mutation pass over the unit tests `[sonnet or a stronger model]`

A separate step because it is the half that gets skipped under time pressure. Until
it runs, step 23 has produced tests of unknown value.

**Required per new test: a negative control.** Break the code the test claims to
guard (flip a comparison, delete a bound check, swap a constant), confirm the test
FAILS, restore. Note the mutation in the test's comment.

Rejected-test items 8–10 are the three ways this goes wrong while looking like
success. A surviving mutation is itself the finding: record it in
`adoption-findings.md` with the reason, and either fix the test or say why it cannot
be fixed.

**Acceptance:** one recorded mutation per new test, each shown to make that test
fail, with the mutation named in the test's own comment.

## 25 — The live-server layer `[sonnet or a stronger model]`

`ci/tools/test_runtime.py` — the live-server cases Test::Nginx cannot express:
concurrency, the chunk seam through the real body handler, reload under load.
Retarget the config and marker; keep the shape, **including the baseline case that
proves the module is loaded and blocking before anything else runs**.

The rejected-test list applies unchanged.

**Acceptance:** the suite is green, and the baseline case exists and asserts the
module is loaded — its mutation is step 26's job.

## 26 — Mutation pass over the live-server layer `[sonnet or a stronger model]`

Same requirement as step 24, over a layer where it is easier to fake: a runtime test
can pass because the server came up at all.

- **The baseline case must fail when the module is not loaded.** Prove it by
  unloading the module, not by reasoning about the config.
- The concurrency and reload cases each need their own recorded mutation.
- Beware rejected-test item 4, the shared counter: if the mutation at site A is
  caught by an assertion site B also satisfies, the test attributes nothing.

**Acceptance:** the baseline case observed failing with the module unloaded; the
concurrency and reload cases each with a recorded mutation that made them fail.

## 27 — The fuzz target, corpus and dictionary `[sonnet or a stronger model]`

Fuzzing is per-module work; a copied harness driving the skeleton's rule table
proves nothing about the target.

- The fuzz target must call the **real** decision function with
  `(const uint8_t *, size_t)`, not a reimplementation. That seam is steps 7–9's job
  and should already exist. If it was parked and does not, do not stop: record in
  `adoption-findings.md` that the real decision function is unreachable, mark this
  step degraded in the PR body, and continue with the parts that do not need it. **A
  fuzz target driving a reimplementation is worse than none, so do not build one.**
- Seed corpus from the module's actual domain: real headers/bodies/config values it
  parses, plus every past crash under `ci/fuzz/regressions/`.
- `fuzz.dict` with the module's real tokens, **derived from the target's own parse
  surface** — a dictionary of the skeleton's tokens actively misdirects the fuzzer.
  Re-derive it; do not edit the reference's copy down.
- **If the target's tokens live in a table in its source, GENERATE the dictionary
  from that table and gate the drift** — a script that extracts every literal, plus
  a `--check` mode wired into `ci/linter/`. A hand-listed dictionary goes stale
  silently: adding a signature and forgetting the dictionary does not fail the fuzz
  gate, because a merely incomplete dictionary still produces a green crash-only
  run. Hand-maintain it only when there is no table to derive from.
- **Do not judge that by edge coverage.** Measured downstream: deriving the
  dictionary moved `cov` not at all (199 on both arms) while signature reach went
  23 → 35 of 645 table literals actually driven through the differential oracle in
  60s from an empty corpus. A trie-walk scanner executes the same edges whichever
  literal arrives, so coverage is the wrong instrument here — the question is how
  much of the table the fuzzer ever reaches.

**Acceptance is conditional:** with a reachable seam, the fuzz target builds and
links the target's real `*_scan.c`, by grep, and the target-derived corpus and
dictionary sizes are stated. Without one, the finding names the unavailable seam, no
substitute fuzz target was created or ported, and the step is explicitly degraded;
only independently useful corpus/dictionary work continues.

## 28 — Replay order and the ASan soak `[sonnet or a stronger model]`

Two gates that are green by default and prove nothing by default.

- **Replay-then-fuzz order in `fuzzing.yml`**: recorded regressions first (fast,
  deterministic), then the time-boxed fresh run. A crash that returns must fail in
  seconds, not after the fresh budget.
- **The ASan soak (`asan.yml`) must drive the module's real request shape** — its
  directives enabled, its body path exercised — not a default config where the
  handler never runs. Verify it reaches the module with evidence: a counter, a log
  line, or coverage from the soak build.
- Keep the ASan build static (`--add-module`); a dynamic module under ASan loses
  interception on the parts that matter.

**Acceptance:** a deliberately reintroduced past bug is caught by the replay step in
seconds (verify once, then revert), and the evidence that the soak reaches the
module, quoted in the PR body.

## 29 — Adapt the three neighbours `[sonnet or a stronger model]`

Each is a file that keeps reporting success while pointed at the wrong target:

- `valgrind.supp` — needs **target-specific** nginx-core suppressions. A copied one
  can suppress the module's own errors.
- `codeql.yml` — the TU filter needs the target's file names, or CodeQL analyses
  nothing and passes.
- `ci-deep.yml` — the matrix needs the target's nginx/angie compatibility range, not
  the reference's.

**Acceptance:** each names the target's own paths/versions, shown by grep; and for
`codeql.yml`, the analysed-TU count from a real run is non-zero.

## 30 — Coverage as a report `[sonnet or a stronger model]`

Fourth test layer. `ci/tools/coverage.sh` + the `coverage` mode in
`ci/tools/ci-build.sh` — a distinct build tree, never a flag bolted onto `debug`, so
a cached non-instrumented tree cannot produce a 0% report that reads as a finding.
`gcovr` filtered to `src/` only; an unfiltered run drowns the module in 200k lines
of upstream nginx.

**Coverage is a REPORT, not a gate.** The cheapest way to move the number is tests
that touch lines and assert nothing, so a floor buys a metric and sells the thing it
proxied for. Publish from `ci-deep.yml`; gate on the mutations recorded beside each
suite. `COVERAGE_FAIL_UNDER` exists for a target that decides otherwise.

**Acceptance:** the reported figure moves when a test is deleted (prove it, then
restore); the filter names the target's `src/`.

## 31 — Caching: `ci-build.sh` as the single chokepoint `[sonnet or a stronger model]`

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
- State the honest win in the README. If caching saves 5s on a 2.5-minute gate, say
  so.

**Acceptance:** a second identical build reports a non-zero ccache hit rate — a 0%
hit rate on an identical rerun means ccache is not wired, whatever the log says.
Every layer's key names what invalidates it.

## 32 — Port `ci/linter/` and its installer `[sonnet or a stronger model]`

Follow **[linter/README.md](linter/README.md)** verbatim: `apt-get` first, then
`pipx` for what Debian lacks, then `cpan` for Perl, then upstream binary for
actionlint. `install-linters.sh` is the single installer; CI and a fresh clone use
the same one.

- A missing tool exits 2 and BLOCKS. Never a silent skip.
- Relaxations live in `.yamllint` / `.perlcriticrc` with their reason. Fix
  pre-existing findings or record why — no blanket suppression.
- `lint.yml` runs the same `run-all.sh` on a hosted runner, so a clone that never
  enabled the hook still cannot land a regression.

**Run the two deferred probes now, before PR2 merges:** step 12's empty-selection
probe (`LINT_ONLY="c nginx" ci/linter/run-all.sh` must exit 1 with a `malloc`/`strcpy`
planted beside the real C) and step 15's probe 2 (must exit 1).

**Acceptance:** `install-linters.sh` succeeds from a clean environment; `run-all.sh`
exits 0 clean, 1 on findings, 2 on a missing tool — observe all three, the last by
hiding a tool from `PATH`. Both deferred probes red, with output.

## 33 — The tracked hook and the threshold mirror `[sonnet or a stronger model]`

Two things that make local-green predict remote-green:

- **Tracked hook at `.githooks/pre-commit`**, enabled with
  `git config core.hooksPath .githooks`. Lints STAGED files only.
- **Thresholds mirror `security-scanners.yml`.** Move one there, move it here in the
  same commit, or the two drift and the local gate stops meaning anything.

Watch the top-level exclude: a global exclude in `.pre-commit-config.yaml` runs
before every hook, so one broad pattern can blind every checker at once.

**Acceptance:** a staged file with a deliberate finding is blocked by the hook; every
threshold in `ci/linter/` matches its counterpart in `security-scanners.yml`, listed
pair by pair.

## 34 — The checker set is the target's `[sonnet or a stronger model]`

**The checker SET is the target's; the entry point is the standard's.** The
convention is `run-all.sh` + `LINT_ONLY` + exit codes (`0` clean, `1` findings, `2`
tool missing) + the tracked hook. Behind it:

- a module with no Perl needs no `lint-perl.sh`; one with Lua or Rust needs a checker
  the reference lacks. Add `lint-<name>.sh` — `run-all.sh` picks it up by glob — and
  give it a row in the linter README. A checker the reference lacks also goes to
  `skeleton-findings.md`.
- **keep every checker the target already ran** (rule 2), behind the same entry point
  rather than dropped because the reference lacks it.
- the three **repo-policy** checks do not transfer unexamined: `ci-runners` depends
  on `TRUST_SPLITS` being rewritten (step 14), and `ci-ports` is meaningful only if
  the target binds a fixed band. A target whose driver picks its own port should say
  so in the README and skip it loudly, not carry a check that can never fire.
- `lint.yml`'s `LINT_ONLY` string diverges with the checker set. The reference runs
  `nginx sh python perl yaml spelling ci-runners ci-ports docs-drift`; that is not a
  constant to copy, and nothing cross-checks it against the scripts that exist.
  **Compare normalized sets:** strip the directory, `lint-` prefix and `.sh` suffix
  from every `ci/linter/lint-*.sh`; split `LINT_ONLY` on whitespace; sort both
  uniquely.

**Acceptance:** every checker the target ran before still runs, behind `run-all.sh`;
the normalized `LINT_ONLY` and checker-script sets match exactly; every added or
dropped checker has a written reason, and every added one is in
`skeleton-findings.md`.

## 35 — The speed budget `[sonnet or a stronger model]`

Measured against the finished checker set on the cached tree from step 31.

**The whole hook under ~2s on a one-file commit.** A gate people wait on is a gate
people bypass with `--no-verify`. Over budget → scope the slow checker, never drop
one, never a default-on skip flag. Carry these three, each measured:

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

Record your numbers and **check `/proc/loadavg` first** — on the build host at load
~50 the same full-tree run varied 2.2s–12.4s over six attempts, a spread wider than
the whole improvement.

**Acceptance:** run every probe in the linter README's "Verify before trusting"
section against the target and observe each red — *after* the speed work.
`--jobs`/`--metrics` are exactly the flags that can silently turn a checker into a
no-op, so the semgrep probe in particular must still fire. Then run with two checkers
failing at once and confirm both appear and both are named in the `== FAIL:` line.

## 36 — Measure the target's job durations `[sonnet or a stronger model]`

CI wall-clock on a self-hosted host is dominated by jobs QUEUEING for a
label-matching slot. **Hosted-only targets skip steps 36–38** — say so and move on.

This step produces numbers and nothing else. Measure the target, not the reference:

```sh
gh run view <id> -R <owner>/<repo> --json jobs \
  -q '.jobs[] | [.name, .conclusion,
                 (((.completedAt|fromdate)-(.startedAt|fromdate))|tostring)+"s",
                 .startedAt, .completedAt] | @tsv'
```

Keep `startedAt`/`completedAt`, not just durations — the gaps show queueing. Count
the real slots too — `systemctl list-units | grep ci-ephemeral` (six on the
reference's host) — and check `/proc/loadavg` before trusting any timing.

**Acceptance:** a per-job table with `startedAt`/`completedAt`, the run ID and date
it came from, and the slot count. No lane changes in this step.

## 37 — Build the lanes `[sonnet or a stronger model]`

Consumes 36's numbers. At most four lanes.

1. Identify the longest single **job**. That is the budget; no arrangement finishes
   sooner. Chain **nothing** behind it. Pairing the longest job with a follow-up "to
   keep the lane busy" is the most common way this gets worse — it is what put the
   reference's lane A at 348s against a 268s budget.
2. Build the **fewest lanes that fit**, four maximum, each a chain of `needs:` where
   a long job releases its slot to a shorter independent follow-up. No lane exceeds
   the budget. Three that fit beat four that also fit. Note the fullest lane's
   headroom in the comment.
3. Does not fit in four? Move a check out-of-band (monthly), time-box it, or put it
   on a hosted runner — not "add a fifth".
4. **A lane is not a slot.** Count real slots
   (`systemctl list-units | grep ci-ephemeral` — six on the reference's host), and
   remember a reusable workflow fans out: the reference's Build&Test is *five* jobs,
   so observed peak is 7 against 6 slots. Brief oversubscription at t=0 is
   acceptable; writing "caps peak at three" when it is seven is not.
5. Hosted jobs (lint, CodeQL) take no self-hosted slot and are **not laned at all** —
   no `needs:`, start immediately. Chaining one behind a self-hosted job conserves
   nothing and delays its result.
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

**Acceptance:** no lane exceeds the budget from step 36, and the fullest lane's
headroom is stated. Rules 4–8 each answered against the target's own YAML.

## 38 — Write the lane map into the orchestrator header `[sonnet or a stronger model]`

A deliverable rather than a note: the orchestrator's header comment is the **only**
place this design is written down. It carries the lane map, the measured durations,
the run ID and date they came from, and the command to re-derive them. **Any lane
change rewrites that comment in the same commit** — a stale lane map reads as
measurement and gets trusted. Record the same map in the memory mirror.

**Acceptance:** the header comment contains the lane map, the run ID and the date its
numbers came from, and the re-derive command actually reproduces them. **PR2 is now
complete — merge it before opening PR3.**

---

# Phase 5 — Depth pass

**PR3 opens here, after PR2 has merged.** Everything is already green; the question
is whether it would catch anything. A soak that never reaches the handler, a fuzzer
driving a reimplementation and a coverage number computed over nginx core all report
success indefinitely.

Each step is answered with a **measurement in the PR body**, not a reading of the
YAML. Where an item cannot be met, say so with the `file:line` and leave the honest
value; "never weaken a gate" still applies.

## 39 — Re-verify the decision seam `[sonnet or a stronger model]`

Steps 7–9 established it; everything below depends on it still holding, and it
decays quietly as handler code is added.

```sh
grep -n 'ngx_http_request_t\|r->\|ngx_http_' src/*_scan.c   # -> expect no hits
# UNIT_ENTRY does not carry over from step 7's session. Re-derive it: the
# target's real unit entry point per the baseline, or ci/tests/unit/run.sh
# only if the target actually has that file.
grep -n '_scan\.c' ci/fuzz/build.sh "$UNIT_ENTRY"
git log --oneline -- ci/fuzz/ngx_stubs.c                    # stubs grown since 7?
```

A new stub in `ngx_stubs.c` is the signal that decision logic drifted back into
nginx types and someone stubbed around it rather than refactoring. Fix the seam, not
the stub. If step 7 recorded "no decision logic to separate", confirm that is still
true — a module grows parse surfaces.

**Acceptance:** unit and fuzz builds still compile the target's real `*_scan.c` (same
source, not a second copy), no nginx request types inside it, no stub growth that is
not justified in the PR body.

## 40 — ASan/UBSan: does the soak reach the module? `[sonnet or a stronger model]`

The failure is silent: a default config where the handler never runs produces a clean
ASan report forever.

- Prove reachability with evidence, not inspection — a counter, a log line, or
  coverage from the soak build showing the module's own TU executed. Put the number
  in the PR body.
- The soak must exercise the directives the module actually ships and its body path,
  at the shapes an attacker controls, not a single GET.
- Build stays static (`--add-module`); dynamic loses interception where it matters.
  mold stays skipped under ASan.
- UBSan: confirm the target's flags include the checks the module can actually trip
  (integer overflow, alignment, shift) and that it is **trapping or exiting non-zero**
  — a UBSan that only prints to stderr passes a red run.

**Acceptance:** reintroduce a known-bad access, watch it abort, revert. The abort
output goes in the PR body.

## 41 — Fuzzing: can the surface be widened? `[sonnet or a stronger model]`

The reference carries two targets (`fuzz_scan`, `fuzz_body`). One target on a module
with several parse surfaces is under-fuzzed by construction.

- Enumerate every function taking attacker-controlled bytes; each is a candidate
  target. Add the ones with a real seam, one per parse surface, and say in the PR
  which surfaces remain uncovered and why.
- `fuzz.dict` holds the **target's** tokens. Re-derive; the skeleton's dictionary
  misdirects.
- Corpus from the module's real domain plus every past crash under
  `ci/fuzz/regressions/`. Replay-then-fuzz order stays.
- Report corpus size, and coverage or feature count reached at the end of the
  time-boxed run. A fresh run that plateaus in seconds is a stuck target, not a clean
  one.

**Acceptance:** unchanged from steps 27–28 and it is a mutation test — reintroduce a
past bug, confirm replay catches it in seconds, revert.

## 42 — Coverage: measured over the module only `[sonnet or a stronger model]`

`ci/tools/coverage.sh` exists because an unfiltered `gcovr` reports ~1% — nginx core
is instrumented by the same configure run and swamps the module.

- Confirm the target's coverage filter names the target's `src/`, not the
  reference's, and that the reported figure moves when a test is deleted. A number
  that does not move is filtered wrong.
- **`--object-directory`, never `--gcov-object-directory`** — the latter arrived in
  gcovr 7.0 and is a hard argparse failure below it. The condition is the gcovr major
  version the job actually runs, not whether a pin exists.
- Raise coverage by adding boundary cases to `ci/tests/unit/test_scan.c` — the cap,
  the seam, the hold window, off-by-one on each — not by widening the filter or
  lowering `COVERAGE_FAIL_UNDER`. Uncovered lines that are genuinely unreachable get
  a comment naming why.

**Acceptance:** before/after numbers and which specific branches the new cases
reached.

## 43 — Valgrind, memcheck, helgrind `[sonnet or a stronger model]`

The reference splits these deliberately: `valgrind.yml` is a 60s memcheck lite on the
merge path; `ci-deep.yml` runs the 600s memcheck **and** helgrind soaks monthly, both
through `ci/tools/soak.sh` (`USE_VALGRIND` / `USE_HELGRIND`).

**Unconditional — these are grep-cheap and cost nothing on a quiet module:**

- Confirm the memcheck soaks exist. If the module has shared state, also confirm that
  **helgrind is actually invoked** — a copied `ci-deep.yml` that lost the helgrind job
  still shows a green CI Deep badge. A dormant module is exactly where a
  silently-missing job survives longest.
- `valgrind.supp` needs the **target's** nginx-core suppressions. An over-broad
  suppression silently covers the module's own errors: check each entry is scoped to
  a core frame, and that the file was regenerated rather than copied. This is
  independent of recent activity — a stale suppression hides today's bugs.
- Helgrind is only meaningful if the target has shared state across workers (shm, a
  timer, a resolver callback). If it has none, record the evidence-based
  not-applicable result; do not add or require a soak that can never report.

**Acceptance:** memcheck confirmed present; every `valgrind.supp` entry shown scoped
to a core frame; and either helgrind confirmed invoked by grep when shared state
exists, or the evidence-based not-applicable result when it does not.

## 44 — Run the soaks, or prove they can be skipped `[sonnet or a stronger model]`

**Running the soaks is conditional** — this step is the decision plus whichever branch
it lands on. 600s memcheck plus helgrind on code that has not moved since the last
green deep run re-proves a known result. Skip if **all** of the following are
unchanged since that run:

```sh
LAST=$(gh run list --workflow ci-deep.yml --status success --limit 1 \
    --json headSha --jq '.[0].headSha // empty' 2>/dev/null || true)
if test -z "$LAST" || ! git cat-file -e "$LAST^{commit}"; then
    echo 'no valid last-green baseline: run applicable soaks'
else
    git diff --stat "$LAST"..HEAD -- config src/ ci/ .github/workflows/ \
        .github/versions.env
fi
```

No qualifying last-green SHA, a missing local commit, or anything in that diff → run
the applicable soaks. Workflow definitions are included because they own the commands,
runners and flags. Note the deliberate inclusion of `versions.env`: `bump.yml` bumps
pins weekly and `ci-deep.yml` runs monthly, so a module with **zero source commits can
still be running against a new nginx**. Commit recency in `src/` alone is the wrong
clock. A submodule bump of `ci/vendor/nginx-tests` counts the same way.

**Acceptance:** when run — each applicable soak is under real load and reaches the
module (step 40's evidence applies), a deliberate leak is reported before you trust
it, and wall-clock per soak is stated. When skipped — the sha you compared against is
proven to be a qualifying green `ci-deep` baseline and the full empty diff is in the
PR body. A silent skip is indistinguishable from a soak that never existed.

## 45 — Re-audit caching `[sonnet or a stronger model]`

Audit `ci/tools/ci-build.sh` as the single chokepoint; no workflow may duplicate cache
logic. Walk the layers cheapest-first and confirm each against step 31's rules, which
are not repeated here. `bear`/`compile_commands.json` where clang-tidy consumes it.

The two that need a number rather than a reading:

- **ccache is wired.** nginx's `configure` ignores a bare `CC=`. Report the hit rate
  from a warm run; 0% on a second identical run means it is not wired, whatever the
  log says.
- **Each key includes what actually changes the output.** The rule that outranks every
  speedup: a cache must never serve a stale artifact into a green result.

**Acceptance:** the warm-run ccache hit rate, and one key per layer with what
invalidates it.

## 46 — Does every checker still bite? `[sonnet or a stronger model]`

`zizmor`, `actionlint`, `yamllint`, `semgrep`, `codespell` and the three repo-policy
checks were installed at steps 32–34. This does not re-install them; it asks whether
each still fires. A checker that has become a no-op reports the same clean line as one
that passes.

- Re-run every probe in the linter README's **"Verify before trusting"** section
  against the target and observe each red. Then run with **two** checkers failing at
  once and confirm both appear and both are named in the `== FAIL:` line.
- **`semgrep` first.** `--jobs=1` and `--metrics=off` are exactly the flags that can
  silently turn it into a no-op, so its probe must still fire. `--jobs=1` is a
  correctness flag, not a speed one — see step 35.

**Acceptance:** every probe in the linter README observed red, plus the run with two
checkers failing at once in which both are named in the `== FAIL:` line.

## 47 — Audit drift classes `[sonnet or a stronger model]`

These are not probes — nothing fires red for any of them, which is why each needs an
explicit answer.

- **`zizmor` findings drift with the workflow set.** Every workflow added since step
  32 is new attack surface it now audits. Confirm the count of audited workflows
  matches the count in `.github/workflows/`, and that each `# zizmor: ignore[rule]`
  still names a reason that is still true. A suppression outlives the thing it
  suppressed.
- **`actionlint` remains blind to the `fromJSON` ternary** (step 13). Do not read a
  clean actionlint as evidence about runner labels; that is probe 2's job (step 15)
  and probe 2 only.
- Confirm `LINT_ONLY`'s string in `lint.yml` still matches the checkers that actually
  exist, using step 34's normalized comparison — it diverges as the set changes and
  nothing cross-checks it.
- `run-all.sh` reads `git ls-files`: a **new untracked file is invisible to the
  linter**. Stage before trusting a clean run.
- Re-time the hook against the ~2s budget, `/proc/loadavg` checked first.

**Acceptance:** an explicit answer to each bullet. "Checked, fine" is not one — each
needs the count, string, or timing it asked for.

## 48 — Re-measure the CI shape `[sonnet or a stronger model]`

Only with numbers from `gh run list`:

- Re-check step 37's lane topology against **measured** wall-clock, not the estimates
  in place when it was written. Lanes drift as tests are added.
- Confirm exactly one `pull_request:` entry point still holds, and that every member
  is reached — a member called by nobody keeps a stale-green badge and goes grey only
  when deleted. Re-run the double-run proof if anything moved.
- Check `/proc/loadavg` before timing anything.
- Optimise by moving work off the merge path into `ci-deep.yml`, never by deleting a
  check or widening a threshold.

**Acceptance for the depth pass:** for each of steps 39–48, the measurement, and for
every gate the one sentence stating what it would now catch that it did not before. A
"verified correct" with no number attached is not an answer.

---

# Phase 6 — Close out

Docs, memory mirror, the anchor a future forward depends on, the feedback that keeps
the skeleton ahead of its clones, and the report. Steps 50–54 continue PR3; step 49 is
its own PR against the reference.

## 49 — Hand the findings back to the skeleton `[sonnet or a stronger model]`

`$SCRATCH/skeleton-findings.md` is the deliverable. It has been accumulating since
step 1: bugs in ported scripts, rules in this prompt that were wrong or ambiguous,
gates the target had that the skeleton lacks (rule 2), checkers the reference does not
carry.

Open **one PR against `myguard-labs/nginx-skeleton-module`** — the only write to the
reference repository in the whole job:

1. **Fix what you can fix in code.** A bug in `ci/tools/`, `ci/linter/`, a workflow or
   this `PROMPT.md` gets the actual change, with the target's `file:line` as the
   evidence in the PR body. That is the preferred form.
2. **Describe what you cannot.** Anything needing a decision, a measurement on
   hardware you do not have, or a change whose blast radius crosses every derived
   module goes in `ci/feedback/<target>-<YYYY-MM-DD>.md` in the same PR: what was
   found, where, what it cost, and the proposed change.
3. One PR, both kinds together. Remote CI green, no AI attribution, signed commits.

An empty `skeleton-findings.md` means no PR — say so in the report. Do not manufacture
a finding to have something to send.

**Acceptance:** either the PR URL, or an explicit "no skeleton findings" line in the
report.

## 50 — Unresolved bot replies across every PR you opened `[sonnet or a stronger model]`

Only checkable once earlier PRs have merged, and it produces fixes rather than
sentences. Do it before writing the report, so the report describes the finished state.

A review bot replies on its own schedule. CodeRabbit rate-limits per developer
(measured 2026-08-04: "next review available in 51 minutes"), so a review can arrive
**after** you merged, and a reply to your reply arrives later still. A merged PR is
not a closed conversation, and nothing notifies you.

```sh
for n in <the PR numbers>; do
  gh api repos/<owner>/<repo>/pulls/$n/comments --paginate \
    -q '.[] | select(.user.login|test("\\[bot\\]$")) | "\(.id)\t\(.in_reply_to_id // "-")\t\(.path):\(.line)"'
  gh api repos/<owner>/<repo>/issues/$n/comments \
    -q '.[] | select(.user.login|test("\\[bot\\]$")) | .body' | grep -iE 'limit reached|could not start'
done
```

Two things to look for, and they are different:

- **a finding you never answered** — a top-level bot comment with no reply from you.
  Verify it against the code like any other; fix, or refute with the `file:line` that
  disproves it.
- **a review that never ran** — a "review limit reached" or "could not start" notice
  means that commit was never examined at all. A green checks list does not distinguish
  this from a clean review. Say which commits were unreviewed in the report rather than
  implying coverage you did not get.

A confirmed finding that is a recurring *class* rather than a typo goes to the
narrowest matching `.claude/skills/audit-*/` reference, not only to memory — the skill
runs unprompted next time.

**Acceptance:** every bot finding answered or explicitly listed as unreviewed, with the
commits that were never examined named.

## 51 — Re-derive the linter set against the finished repo `[sonnet or a stronger model]`

Steps 32–34 kept every checker the target already ran. That was a merge decision made
early; by now the file set has moved.

```sh
git ls-files | sed -n 's/.*\.//p' | sort | uniq -c | sort -rn | head -20
ls ci/linter/lint-*.sh
grep -n 'LINT_ONLY' .github/workflows/lint.yml
```

Three failures, all of which report clean:

- **a language present with no checker** — Lua, Rust, Go, Python, a Dockerfile, a
  systemd unit. Add `lint-<name>.sh`; `run-all.sh` picks it up by glob. Also record it
  in `skeleton-findings.md`.
- **a checker whose language left the repo** — it passes on an empty selection forever.
  Remove it, or say why it stays.
- **`LINT_ONLY` naming a checker that does not exist**, or omitting one that does.
  Nothing cross-checks that string against the scripts on disk.

**Acceptance:** the normalized `LINT_ONLY` and checker-script sets match per step 34;
every language with more than a handful of tracked files has a checker or a stated
reason not to.

## 52 — Docs `[sonnet or a stronger model]`

- README rewritten, not appended to: badge row, `## CI` table, layout tree,
  Requirements, and a Linting section linking `ci/linter/README.md`.
- `CONTRIBUTING.md` tells a contributor how to enable the hook.
- `CHANGES` entry describing the standardisation.

**Acceptance:** `lint-docs-drift.sh` green in both directions — every workflow has a
`## CI` row and every row a workflow.

## 53 — Memory mirror `[sonnet or a stronger model]`

Skip only for an external target with no mirror, and say so.

- `index.md` — layout, lane map, measured times, **and the skeleton commit you adopted
  from**. That anchor is what the "Forwarding one later change" section depends on;
  without it the next session cannot tell a forward from a fresh adoption.
- `issues.md` — everything in `adoption-findings.md` that is still open.
- `lessons.md` — every trap that cost a red CI round-trip, `[RECURRING]` if it has
  bitten before.
- A trap that is a *class* rather than a typo goes into the matching
  `.claude/skills/audit-*/` reference, not only memory.

**Acceptance:** the adopted skeleton commit SHA is written in `index.md`; every open
item from `adoption-findings.md` appears in `issues.md`.

## 54 — Prepare the completion report `[sonnet or a stronger model]`

Prepare, but do not send. Phase 7 updates and sends it after the aftermath. Per PR:
what landed, what is red, what remains and why. Include measured before/after
wall-clock and coverage. Seven questions the report must answer explicitly, because
they are what a greenfield reading gets wrong:

1. **Entry points** — how many workflows carried `pull_request:` before, and
   confirmation exactly one does now.
2. **Runners** — which pool the target runs on. If any `self-hosted` selector
   survives, the output of probe 2 (step 15) proving the target's own gate rejects the
   reference's label. "Adapted the labels" is not an answer.
3. **Extra workflows and gates** — every check the target had that the reference
   lacks, and whether each was kept, folded, or sent upstream at step 49. If any was
   removed, what covers it now.
4. **Badges** — the final row, so order and spelling can be compared without opening
   the repo.
5. **Parked and degraded** — every step you could not complete: which one, the symptom,
   the three attempts, and what a human has to decide. Also every gate you degraded
   (hosted instead of self-hosted, a job omitted for a missing secret, a thin gate
   because a behavioural fix was out of scope). The run does not stop, so this is where
   the unfinished work is accounted for.
6. **Bot review coverage** — from step 50: every bot finding you answered, and every
   commit never reviewed because the bot was rate-limited or never ran.
7. **Anything left disabled, skipped or unverified** — a workflow not enabled, a soak
   skipped per step 44, a gate never seen red. Silence here reads as coverage that does
   not exist.

Do not report a step complete on a gate you never saw fail. **PR3 is now complete —
merge it before opening PR4.**

---

# Phase 7 — Aftermath

**PR4.** All applicable prior PRs are merged or proven not needed. Steps 55–63 run in
order after migration, forwarding, or a no-op. Do not ask whether to run them. Record
evidence for every `not needed` result. One branch, one PR — never one per aftermath
step.

## 55 — Recheck the implementation `[sonnet or a stronger model]`

Re-read this prompt against the merged result, step by step, and report which of the 54
are genuinely done, which are partial, and which were skipped. Independent of your own
report at step 54 — the point is that it is a fresh reading, so do not consult your own
report while doing it.

## 56 — Set up linting as a commit hook `[sonnet or a stronger model]`

Install `.githooks/pre-commit`, wire `git config core.hooksPath .githooks`, and run both
gates across the whole tracked `HEAD` in a detached temporary worktree, so fixer hooks
cannot rewrite owner dirt:

```sh
AUDIT=$(mktemp -d); rmdir "$AUDIT"
cleanup() { git worktree remove --force "$AUDIT" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
git worktree add --detach "$AUDIT" HEAD
(cd "$AUDIT" || exit 2
 ci/linter/run-all.sh --all; lint_rc=$?
 pre-commit run --all-files; hook_rc=$?
 test "$lint_rc" -eq 0 && test "$hook_rc" -eq 0)
rc=$?
cleanup; trap - EXIT INT TERM
test "$rc" -eq 0
```

A first full-tree run on an adopted module may be red; record findings without
weakening the hook. Remove the temporary worktree even on failure.

## 57 — Review the changes `[opus]`

A diff review of every PR this job landed, one maintainer voice, regressions and
contract drift.

## 58 — Full code review `[opus]`

Audit the module's own C, not just the CI: memory safety, parser boundaries, error
paths, and concurrency. Put bounded fixes from steps 55–58 in PR4; park larger
independent changes with evidence rather than creating step PRs.

## 59 — Kick off and re-time the scheduled workflows `[sonnet or a stronger model]`

For each scheduled lane applicable at step 19 (`ci-deep.yml` monthly, `bump.yml`
weekly), verify that the workflow exists and `gh workflow view` reports it active, then
trigger it with `gh workflow run`. If a lane was proven not applicable, record that
evidence instead of inventing or invoking it. Re-check step 37's lane topology against
the wall-clock the merged suite actually produces.

**State the runner cost before starting**: a deep run is long, and on a self-hosted pool
it occupies slots other work needs.

## 60 — Broaden the dynamic analysis `[sonnet or a stronger model]`

Valgrind memcheck and reachable fuzz targets were ported at their reference shapes and
verified to fire (steps 41 and 43). Helgrind is included only when step 43 proved shared
cross-worker state; otherwise retain its evidence-based not-applicable result. Cover
concrete reachable gaps with the smallest useful target, corpus case, time-box,
applicable helgrind path, or memcheck request shape. Accumulate bounded changes in PR4,
not one PR per surface.

## 61 — Increase coverage `[sonnet or a stronger model]`

Report the current figure and the branches gcovr shows as never taken, then add
meaningful cases for reachable gaps, each with its negative control. Coverage stays a
report, not a gate (step 30); never chase a number alone.

If the honest answer is that the remaining uncovered lines are unreachable, say that
instead of offering.

## 62 — Anything left uncommitted or unpushed `[sonnet or a stronger model]`

Check this state and report what you find either way. Fix only this run's residue
through PR4; never touch owner dirt.

```sh
git -C <TARGET> status --porcelain          # untracked or modified
git -C <TARGET> log --branches --not --remotes --oneline   # committed, unpushed
git -C <TARGET> stash list                  # never yours, but say if one exists
```

Two classes, and only the first belongs to this run:

- **work of yours that never landed** — a file written and never staged, a commit never
  pushed, a memory-mirror update made in the working tree only. `run-all.sh` reads
  `git ls-files`, so a new untracked file was also invisible to every linter that
  "passed" over it.
- **the dirt recorded at step 1** — it was there when you arrived. Confirm it is
  byte-identical to what you recorded and leave it alone. Do not offer to commit it; it
  is not yours and the owner cannot find it later if you do.

Recreate step 1's status, worktree patch, index patch and sorted untracked hashes under
new `$SCRATCH` names, then compare each pair with `cmp`. Any mismatch is a finding and
is left untouched; a matching path list alone is insufficient.

**Acceptance:** each of the two classes reported with its paths, or an explicit
"nothing outstanding".

## 63 — The superrepo gitlink `[sonnet or a stronger model]`

Check this separately because it is invisible from inside the target, and every check in
step 62 can pass while the gitlink is wrong.

If the target is a myguard submodule, every merged PR needs its bump on the superrepo's
`master`. A missing one means the superrepo still points at the pre-adoption commit.

```sh
git -C /opt/myguard diff --submodule=short -- <path/to/target>
git -C /opt/myguard log --oneline -3 -- <path/to/target>
```

An external target has no gitlink — say so and skip.

**Acceptance:** the superrepo's gitlink resolves to the target's current default head,
shown by SHA, or an external-target skip is proven. Update the step-54 report with every
aftermath result, PR URL, remaining finding, and current target/gitlink SHA; then send
that final report.

---

## Forwarding one later change into an adopted module

Once a target scores 3/3 at step 4 **and every migration step is proven already done or
not needed**, the job inverts: carry one later skeleton improvement across. One concern,
one PR, one session; then phase 7 runs in full.

**Establish the anchor first.** Without it you either re-land work the target has or
skip the commit that made the change work. In order of preference: a recorded anchor in
the mirror's `index.md`; a `vN` tag the target's `CHANGES` names; the `CHANGES` entry
describing its adoption; the merge commit of its adoption PR. Then:

```bash
git -C /opt/myguard/labs/nginx-skeleton-module log --oneline <anchor>..HEAD
```

That is the candidate set; [CHANGES](../CHANGES) says what each was *for*. **If none of
the four resolves, there is no anchor** — the target never took a documented adoption,
so it uses the migration route, not a forward. Do not invent one from the first commit
or from "HEAD minus the change I was handed"; both manufacture a scope that was never
true.

Take ONE concern. Before touching the target, write in the PR body what the gate must
prove in *behavioural* terms ("a job that starts the runtime driver without declaring a
port band fails the build"), what failure it would have caught in the target, and
whether the target can even reach that failure — a gate for a layer it does not have is
an adoption step, not a forward.

Then check the drift classes. **None is visible from a green run:**

- **Port bands** — see step 21. Read the target's step ORDER, not just the presence of a
  verify step, and remember any binder counts, not only the runtime driver.
- **Coverage option spelling** — `--gcov-object-directory` fails argparse on gcovr below
  7.0. The condition is the gcovr major version the job actually runs, not whether a pin
  exists. `--object-directory` is accepted by both.
- **`versions.env` consumers** — one that sources the file without validating it
  executes any line that is not a pin. Arriving for the first time? Ship the validating
  loader; there is no earlier copy to audit.
- **`workflow_policy.py` vintage** — older than the YAML-parse rewrite means it matches
  workflow YAML with regexes, and valid YAML makes all three policy checks silently
  vacuous (a `.yaml` extension, an inline `on: [pull_request]`, a comment after a job
  key). Ship the YAML-parse version and run `ci/linter/selftest.sh` plus
  `ci/linter/fixtures/policy/` in the target.
- **Runner identity** — steps 13–15. Any change touching a `runs-on`, `actionlint.yaml`
  or `TRUST_SPLITS` carries our pool with it. Run probes 1b and 2. Probe 1b is a bare
  grep and always available; probe 2 needs the linter, so a sync landing before step 32
  is covered by 1b alone. A single-change sync is the likeliest way a self-hosted
  selector re-enters a target that step 13 already cleaned — the reference's copy is the
  source, and it is `POOL_OWNED=yes`.
- **No `src/`** — step 12. Everything scoped to `src/` selects nothing and reports
  success.

Re-derive for the target rather than copying: module name and symbol prefix (including
inside fuzz targets, unit tests and grep patterns in scripts), paths, runner expression,
port bands, version pins. Keep the reference's thresholds unless you record why not.

Two consistency gates that fail late otherwise: `lint-docs-drift` compares the workflow
set against the README's `## CI` table, so a new or renamed workflow needs its row in the
same commit; and `run-all.sh` reads `git ls-files`, so a **new untracked file is
invisible to the linter** — stage it before trusting a clean run.

Verify the gate red in the target, run the local gate at the target's own thresholds,
then PR with workflows enabled. The body states: the anchor and how you resolved it, the
one concern, what the gate proves, the probe and what it printed, and every deliberate
divergence with its reason. Remote CI green on the **current head** — re-check
`headRefOid` before merging. Squash-merge, delete the branch, bump the superrepo
gitlink. Record the new anchor in `index.md`.

Run the phase-7 aftermath (steps 55–63) after the forward PR or no-op.
