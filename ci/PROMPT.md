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
Eleven checkpoints (0–10) grouped into six phases; each lands one PR, except
checkpoint 0, which is read-only. Phases −1 and 4 carry no checkpoint — they are
the preconditions you read first and the close-out you finish with:

| Phase | Checkpoints | What it is |
|---|---|---|
| −1 | — | preconditions, scope jail, stop conditions — read first |
| 0 | 0 | inventory and baseline, read-only |
| 1 | 1 | the decision seam — the one C refactor |
| 2 | 2–9 | adoption: layout, runners, entry point, tests, caching, lanes |
| 3 | 10 | depth pass — would any of it catch anything? |
| 4 | — | close out: docs, memory mirror, report |

Checkpoints are numbered continuously and referenced by number throughout; the
phases group them. Phase 3 runs only after every phase-2 checkpoint has merged.

**This is a merge, not an install.** Assume the target already has CI somebody
relies on. Measured across the eight derived modules on 2026-08-03: every one
has three to six workflows each carrying its own `pull_request:` trigger, not
one has a `ci.yml`, six have no `ci/`, two have no `src/`. An external adopter
is likelier still to have a suite predating any contact with this repo.

Three rules outrank every checkpoint:

1. **Adopt the convention, keep the content.** Layout, ordering, naming and
   entry points are the standard. The target's tests, thresholds, fuzz corpus,
   nginx compatibility range and linter selection are its own. A 1:1 copy is
   wrong by construction — the reference's tests test the reference's module.
2. **Never delete a gate the target already has.** Anything it checks that the
   reference does not survives, gets a badge and a table row, and goes back to
   the skeleton as a PR. A rollout that reduces coverage is a regression wearing
   a standardisation PR.
3. **Nothing self-hosted is portable.** `builder02` is a myguard machine and no
   linter here will tell an adopter they copied it. Checkpoint 3 settles it
   before any workflow is ported.

Standing constraints, all checkpoints:

- **One PR per checkpoint**, in order, each independently revertible and
  independently green. Do not open the next until the previous merges — later
  ones move files the earlier ones edit.
- **Remote CI green before merge**, workflows enabled — see phase −1 on what you
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

---

# Phase −1 — Before you touch anything

Ten PRs against someone's live repo — checkpoints 1–10; checkpoint 0 is read-only
and lands nothing. These are preconditions, not advice: if one cannot be
satisfied, stop and report rather than working around it.

## Scope

**One repo is writable: `<TARGET>`.** This reference, sibling modules and
`/opt/myguard/packages` are read-only for the whole job, memory mirrors included.
Reading the reference is the point; committing to it is not.

Two writes outside it are expected, and only these two:

- **The target's own memory mirror**, `memory/labs/<name>/` or
  `memory/eilandert/<name>/` — where the inventory, issues and lessons go.
- **The superrepo gitlink**, once per merged checkpoint, if `<TARGET>` is a
  myguard submodule. Submodule PR merges first, then the gitlink bump lands
  signed on the superrepo's `master`. An external target has no gitlink and no
  mirror; skip both and say so.

Rule 2's upstream PR (a gate the target has and the skeleton lacks) is a
**separate session** after the rollout, not a commit slipped in while here.
- A dirty submodule or unrelated change in another tree is left exactly as
  found. Do not commit it, revert it, or `git checkout` over it.
- Writing to `memory/` for the target's own mirror is expected; writing to
  another module's mirror is not.

## Preconditions

```sh
cd <TARGET>
git status --porcelain          # -> MUST be empty
git rev-parse --abbrev-ref HEAD # note it; this is the base to branch from
git remote -v                   # confirm you are where you think you are
gh auth status                  # can you actually open a PR here?
```

- **Uncommitted changes → stop.** They are not yours; you do not know what they
  were for. Ask. Never `git stash` to get a clean tree — a stash the user did not
  ask for is data they cannot find later.
- **Not a git repo, or no push access → stop and say so.** Do not initialise one,
  do not fork as a workaround.
- **The default branch is not a work surface.** Every checkpoint gets its own
  branch off the current default, merged by PR. Nothing is committed straight to
  `master`/`main`, including "trivial" doc fixes.

## Git safety

- **Never `push --force` to a shared branch**, and never to the default branch
  under any circumstance. Rewriting a checkpoint branch you alone own, before
  review, is the only acceptable case — and `--force-with-lease`, never `--force`.
- **Never `git checkout .`, `git reset --hard`, or `git clean -fd`** to undo your
  own mistake. They erase whatever else was in the tree. Revert the specific file.
- **No secret ever enters a commit, a workflow, or a PR body** — no tokens, no
  PATs, no `Bearer` strings, not even revoked ones. Reference via `${{ secrets.X }}`
  or an env var. A workflow that needs a credential the target does not have is a
  finding, not a thing to invent.
- One checkpoint per branch, named for it. Delete the branch after merge.

## Stop conditions

Stop, report, and wait for a human on any of these. None is a judgement call:

| Condition | Why |
|---|---|
| Target tree dirty at start | not your changes |
| The same gate red twice for reasons you cannot explain | you are guessing |
| A checkpoint needs a behavioural change to the module | out of scope by rule |
| CI needs a secret or a runner the target lacks | cannot be invented |
| A fix requires deleting or weakening an existing gate | rule 2 |
| The target's tests were already red at baseline | fix ownership is unclear |
| A write outside `<TARGET>`, its mirror or the gitlink seems necessary | scope jail |

**Never disable a failing check to make a PR mergeable.** Not `[skip ci]`, not
`continue-on-error`, not commenting out a step, not `gh workflow disable`, not
lowering a threshold to the observed value. A red gate you cannot fix is a
finding to report, and the honest end state of a checkpoint.

## Rollback

Each checkpoint is one PR precisely so it can be reverted alone. If a merged
checkpoint turns out wrong, `git revert` the merge commit on its own branch and
PR that — do not force-push over history that others have pulled, and do not
"fix forward" by stacking a second broken change on the first.

---

# Phase 0 — Establish what you are working with

Read-only. Decides whether there is a job at all, and sizes the one code change
that everything downstream depends on.

## 0 — Inventory and baseline (no changes)

```bash
cd <TARGET>
git remote get-url origin                                # who owns it
ls -d ci/t ci/tools ci/linter ci/fuzz src t tests fuzz 2>/dev/null
ls .github/workflows
grep -lE '^\s*pull_request:' .github/workflows/*.yml | wc -l   # entry points
grep -rn 'runs-on' .github/workflows/                    # whose machines?
ls src 2>/dev/null || ls *.c *.h                         # C at root?
ls src/*_scan.c src/*_scan.h *_scan.c 2>/dev/null        # decision seam? (cp 1)
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
later change" at the end. Anything less → work the checkpoints, taking only the
ones the target is missing.

Do not infer the score from the first marker you check. Two derived modules have
a `ci/` directory and still score 0/3 — `ci/` is the cheapest half of checkpoint
2 and the most misleading signal in the set. **No `ci.yml` settles it on its
own.**

Record in the memory mirror (`/opt/myguard/memory/labs/<module-name>/index.md`
for ours; an external target has no mirror — create one only if the work is
ongoing):

- current layout, whether `src/` exists, and **whether the decision seam exists**
  (checkpoint 1). Absent or nominal is the largest code change in the job —
  size it here, before planning anything downstream.
- workflows in three buckets: **matches** a reference workflow by purpose,
  **missing**, and **extra** — one the reference has no equivalent for. The
  third bucket is what rule 2 protects and what gets lost otherwise.
- **every `pull_request:` entry point by name** — that count is the size of the
  checkpoint 4 demotion, the riskiest edit in the job
- whose runners it currently uses
- **measured wall-clock per workflow** from `gh run list` — real numbers, needed
  for checkpoint 8. Estimates are not acceptable there.
- current coverage number, if any tooling exists (usually none)
- gates it has that the reference lacks, and where they run

**Read the memory mirror first if the target is ours** — `index.md`,
`issues.md`, `lessons.md`. A trap recorded there outranks anything you infer
from the code.

**Baseline the target green.** Run whatever suite it has and record the result.
If it is already red, that is a finding for `issues.md` and a fact the first PR
body must state — otherwise checkpoint 2 inherits blame for a failure that
predates it.

---

# Phase 1 — The decision seam

One checkpoint, alone in its own phase because it is the only C refactor in the
job and every later gate links across it. A target that already has a clean seam
passes through in a single commit; one that does not cannot produce a meaningful
unit or fuzz result until this lands.

## 1 — The decision seam

First, and before the `ci/` move — the extraction is a C refactor independent of
where the test material lives, and everything downstream links across it. Own PR.

> **Decision logic goes in `*_scan.c`, taking `(u_char *, size_t)`. Only
> `ngx_http_request_t` plumbing stays in `*_module.c`.**

This is the one structural rule, and it comes before the test layers because
both of them link across it: `ci/tests/unit/test_scan.c` (checkpoint 5) and
`ci/fuzz/fuzz_scan.c` (checkpoint 6) compile the module's **real** decision
source, not a copy. Without the seam, checkpoint 5 tests a reimplementation and
checkpoint 6 fuzzes one — both green, both proving nothing about shipped code.

Three states, from the checkpoint 0 probe:

- **Seam exists and is clean** — no `ngx_http_request_t` in `*_scan.c`. Nothing
  to do; record it and move on.
- **Seam is nominal** — `*_scan.c` exists but reaches for `r->`, allocates from
  `r->pool`, or logs through `r->connection->log`. It cannot be linked outside
  nginx, so the fuzz and unit builds either fail or quietly link a stubbed
  variant. **Growth in `ci/fuzz/ngx_stubs.c` is the tell** — every stub added
  beyond the reference's set is a dependency that should have been refactored out.
- **No seam** — decision logic is inline in `*_module.c`. Extract it here.

The extraction, when needed:

1. `*_scan.c` / `*_scan.h` take bytes and return a verdict. No nginx request
   types in the signature, no allocation from a request pool — pass a buffer in
   or take an explicit allocator argument.
2. `*_module.c` keeps the handler, directive parsing, config merging and every
   `ngx_http_*` call, and calls into the seam.
3. Wire both consumers: `ci/tests/unit/run.sh` and `ci/fuzz/build.sh` compile the
   target's real `*_scan.c` — the same source, not a second copy.

**Do not change behaviour while extracting.** This is a move, and the baseline
suite from checkpoint 0 must stay green across it — run it wherever it currently
lives, since `ci/` does not exist yet. A behavioural fix that rides along makes
any later bisect ambiguous; a real bug found while extracting goes to
`issues.md`.

If the module genuinely has no decision logic to separate — a pure plumbing
module whose only work is `ngx_http_*` calls — say so with the `file:line` that
shows it, and note that checkpoints 5 and 6 are correspondingly thin. That is a
legitimate outcome, but state it rather than skipping silently.

Paths below assume `src/`; a target that still keeps its C at the repo root
creates the seam **beside the existing `*_module.c`**, wherever that is, and it
moves under `src/` with everything else at checkpoint 2. Do not create `src/`
here — that split would land the same C in two commits.

```sh
ls src/*_scan.c src/*_scan.h 2>/dev/null || ls *_scan.c *_scan.h
grep -n 'ngx_http_request_t\|r->\|ngx_http_' $(ls src/*_scan.c 2>/dev/null || ls *_scan.c)
grep -n '_scan\.c' ci/fuzz/build.sh ci/tests/unit/run.sh 2>/dev/null
git diff --stat HEAD~1 -- ci/fuzz/ngx_stubs.c               # did stubs grow?
```

The reference's `build-test.yml` asserts the seam file exists by name after a
rename. Confirm the target's equivalent names the **target's** file — a path
that no longer exists makes the assertion vacuous, not failing.

**Acceptance:** no nginx request types inside `*_scan.c`; the module still builds
and the checkpoint 0 baseline suite is still green, with no behavioural diff.

Wiring the unit and fuzz builds to compile that source is checkpoint 2's job —
whichever of `build.sh` / `run.sh` the target already has gets pointed at the
seam in this PR; the rest follow the material into `ci/`. If the target has
neither yet, say so: the seam is verified by build and grep here, and by
checkpoints 5 and 6 once its consumers exist.

---

# Phase 2 — Adoption

Eight checkpoints, one PR each, in order. This is the bulk of the job: layout,
runner identity, entry points, test layers, sanitizers, caching, lanes and
self-hosted hardening.

## 2 — Move CI material under `ci/`

Target layout, matching the reference:

```text
ci/
  t/                     Test::Nginx suite            (was t/ or tests/)
  tests/unit/            C unit tests of the decision core
  fuzz/                  libFuzzer targets, dict, corpus/, regressions/
  vendor/nginx-tests/    upstream suite submodule
  tools/                 ci-build.sh, nginx-tree.sh, test_runtime.py,
                         coverage.sh, max-port.sh, ci-hang-guard.sh, soak.sh
  linter/                local lint gate (checkpoint 7)
```

- `git mv`, never copy-then-delete — blame must survive. Verify with
  `git log --follow` on one moved file before continuing; a move recorded as
  delete+add loses the history silently and cannot be repaired after merge.
- A directory move breaks **every relative path that climbs out of it**. Grep
  and fix in this order: nginx's module **`config` file** (it names every source
  path and is the one file whose breakage stops the module building at all),
  `../` in C `#include`s, `$PWD`/`dirname` logic in shell, `paths:` filters in
  workflows, `hashFiles()` keys, `prove` invocations, fuzz corpus paths,
  `.gitmodules` submodule paths, `.gitignore`, coverage exclude patterns, README
  references. A missed climb compiles fine and silently tests the wrong tree.
- `git submodule update --init` still working after moving `ci/vendor/nginx-tests`
  is a required check — the `.gitmodules` `path:` must be edited, not just the
  directory moved.
- **No `src/`? Creating one is part of this checkpoint** — and the seam files
  from checkpoint 1 move with the rest of the C. Two of eight derived modules
  keep `ngx_http_<name>_module.c` (sometimes plus `<name>_core.c/.h`) at the
  repo root. Everything downstream is scoped to `src/` — `lint-c.sh`,
  `lint-nginx.sh`, the gcovr filter, the CodeQL TU filter — and every one
  *passes* on an empty selection rather than failing. Move the C under `src/`
  and update `config` in the same commit. Prove it: a `malloc`/`strcpy` probe
  file where the module's real C lives must make `LINT_ONLY="c nginx"` exit 1.
- Run the suite after the move and before any workflow edit, so a failure is
  attributable to one thing: `TEST_NGINX_TIMEOUT=20 prove -v ci/t/`

**Acceptance:** local `prove` green, fuzz targets still build
(`ci/fuzz/build.sh`), no path outside `ci/` refers to `t/`, `tests/` or `fuzz/`.

---

## 3 — Runner identity is not portable

Settle this before porting a single workflow. `builder02` is the label of **a
physical machine myguard owns**, spread across three files that must agree:

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
failure is not a red CI you fix; it is a green CI either queueing forever
against a label nobody answers, or dispatching to a runner you do not own.

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

Same commit, **workflows first and the checker last**, so the gate is the last
thing to change and its findings are about what remains:

1. every `runs-on` in `.github/workflows/`,
2. `.github/actionlint.yaml` — delete the `self-hosted-runner:` block entirely;
   declaring labels you never use trains the next person to add one,
3. `ci/linter/workflow_policy.py` — reduce `TRUST_SPLITS` to an empty frozenset.
   `HOSTED.fullmatch` covers every selector now, and an empty approved-set makes
   any future self-hosted selector a finding rather than a silent pass.

Stated honestly so nobody optimises it back: the self-hosted pool is what makes
`ci-deep.yml`'s monthly matrix and the long fuzz runs affordable. On hosted
runners those are slower and bounded by the 6-hour job limit. That is a
scheduling problem, not a reason to point a `runs-on` at hardware you do not
control.

**If the target DOES own a pool**, self-hosted is opt-in and a separate commit —
never smuggled into the port. All three files change together with their own
labels, the fork arm stays the hosted runner, and the condition stays
`github.event.pull_request.head.repo.fork` — not `github.actor`, not a repo
variable, both of which a fork controls. Then read checkpoint 9 in full.

### Verify, both directions

A grep proving `builder02` is absent says nothing about whether the *checker*
still approves it.

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

**Probe 2 going green in the target is the bug this checkpoint exists for** — it
means `TRUST_SPLITS` was copied unedited. Fix `workflow_policy.py`; do not
delete the probe. Two things about it, both verified against the reference on
2026-08-03:

- **In the unedited reference it exits 0, correctly** — `builder02` is an
  approved selector *here*, in our repo, on our machine. The probe is a
  statement about the TARGET. Running it in the reference to "check the probe
  works" proves nothing.
- **Empty `TRUST_SPLITS` before rewriting the workflows and you get one finding
  per selector.** Doing that in the reference produced **16 findings** — the
  probe plus all 15 real selectors. Expected intermediate state, and the reason
  the order above is workflows first: reverse it and the one finding you are
  hunting is buried in fifteen you already know about.

---

## 4 — Workflows, badges, and ONE entry point

Do this in two commits: the demotion first, then the missing workflows. Adding a
workflow to a repo that still has six triggers multiplies the problem.

### 4a. Demote to a single orchestrator

The highest-risk edit in the job. The target has N workflows each carrying
`pull_request:` (measured: three to six, with `workflow_call:` nowhere). End
state: exactly one `pull_request:`, in `ci.yml`, everything else reachable only
as a `workflow_call:` member.

1. Add `workflow_call:` to each member **while leaving its `pull_request:` in
   place**. It still runs standalone, so the target keeps working.
2. Add `ci.yml` calling every member. Verify on a real PR that each member runs
   *twice* — once standalone, once called. Two runs is the expected intermediate
   state and the proof the call graph is wired.
3. Remove `pull_request:` from every member in one commit. Now each runs once.

**Step 3 is the point of no return**, and the only step in the job that can leave
the repo with *no* PR gate at all. Do not take it until step 2 showed **every**
member running twice — a member that ran once was never called, and removing its
own trigger silences it completely. If even one did not double-run, fix `ci.yml`
and repeat step 2; do not proceed on the theory that it will resolve itself.
Should the merged result gate nothing, revert this PR first and diagnose after —
an ungated default branch is not a state to debug in place.

Skipping step 2 is how a member ends up called by nobody: `ci.yml` references a
job name that does not exist, the call contributes nothing, and the suite looks
green because the check that would have failed never ran.

Two things that break a called workflow and not a standalone one:

- **`secrets: inherit` is not automatic.** A member that used a secret while
  standalone loses it when called unless the caller passes it.
- **Path filters do not work on a called workflow** — it cannot filter its own
  triggering. Gates move to a `changes` job in the orchestrator with an explicit
  job-level `if`. See checkpoint 8 rule 8.

A second entry point that is not `pull_request:` (a `schedule:`, a
`workflow_dispatch:`) is fine and normal — `bump.yml` and `ci-deep.yml` in the
reference are schedule-driven and not members of the PR lane.

### 4b. The workflow set

| Workflow | What it must gate in the target |
|---|---|
| `ci.yml` | orchestrator; the ONLY `pull_request` entry point |
| `lint.yml` | the `ci/linter/` gate (checkpoint 7), hosted runner |
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
`.github/actions/build-cache/`, and `.github/actionlint.yaml` (subject to
checkpoint 3).

**Workflows the target has and the reference does not:** rule 2 — they survive.
One derived module carries a `runtime-tests.yml` with no reference equivalent;
two carry a `bump.yml` the other six lack. For each, decide and write down
which: **keep as-is** (it gates something real — give it a `## CI` row and a
badge, and open a PR back to the skeleton), or **fold into a reference
workflow** (it duplicates a gate under another name — state what moved where).
Do not delete one on the grounds that the reference has "the same thing" until
you have compared the actual checks; a same-named workflow often gates less.

**Port bands.** Test::Nginx binds `TEST_NGINX_PORT`, default 1984, and nothing
arbitrates it. A self-hosted host runs several runner slots against one network,
so two jobs on the default collide and the loser dies with
`bind() to 127.0.0.1:1984 failed (98: Address already in use)` — which reads as
a module regression and is not one. Presence of `TEST_NGINX_PORT` is not the
check; the check is a **distinct job-level band** per workflow (the reference
uses `TEST_BASE_PORT` 19200 in `build-test.yml`, 19400 in `ci-deep.yml`),
verified by `ci/tools/max-port.sh` **before the first step that binds it** —
which means before `prove`, not merely before the runtime driver. The reference
shipped this in the wrong place until 2026-08-02; `fixtures/policy/verify-after-bind`
is the negative control that keeps it right. Read the target's step ORDER. A
target whose driver picks its own free port is already immune; leave it and say so.

### 4c. Badges — same order, same text

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
- an **extra** workflow kept above goes at the END of both lists, after CI Deep,
  so the shared prefix stays comparable across modules
- every badge must resolve to a workflow that exists — one for a deleted
  workflow renders a permanent grey "no status" and is worse than no badge
- **the URL owner/repo is the target's**, not `myguard-labs/nginx-skeleton-module`.
  A copied badge row pointing at the reference renders green while telling you
  nothing about the target, which is the worst failure available here.

**Acceptance:** `actionlint` clean; exactly one workflow carries
`pull_request:`; every badge resolves to a real workflow in the target's own
repo; CI table and badge row in identical order and spelling;
`lint-docs-drift.sh` green in both directions.

---

## 5 — The four test layers, then coverage

The reference ships all four. **Reuse them; do not re-derive.**

- `ci/tests/unit/` — `run.sh` + `test_scan.c`. Links the target's REAL decision
  TU and nginx's REAL `src/core/ngx_string.c`; no shimmed decoder, ever. A shim
  makes the layer hermetic and worthless. Reuses `ci/fuzz/ngx_stubs.c`.
- `ci/tools/test_runtime.py` — the live-server cases Test::Nginx cannot express:
  concurrency, the chunk seam through the real body handler, reload under load.
  Retarget the config and marker; keep the shape, including the baseline case
  that proves the module is loaded and blocking before anything else runs.
- `ci/tools/coverage.sh` + the `coverage` mode in `ci/tools/ci-build.sh` — a
  distinct build tree, never a flag bolted onto `debug`, so a cached
  non-instrumented tree cannot produce a 0% report that reads as a finding.
  `gcovr` filtered to `src/` only; an unfiltered run drowns the module in 200k
  lines of upstream nginx.

**Coverage is a REPORT, not a gate.** The cheapest way to move the number is
tests that touch lines and assert nothing, so a floor buys a metric and sells
the thing it proxied for. Publish from `ci-deep.yml`; gate on the mutations
recorded beside each suite. `COVERAGE_FAIL_UNDER` exists for a target that
decides otherwise.

**Rejected outright:**

- a test whose assertion holds in both the pass and fail state (tell: a captured
  variable never compared)
- a control that hardcodes the verdict instead of calling the real function
- asserting a *precondition* rather than the claim
- one shared counter asserted at N call sites — it pins none of them
- a test written from the same misunderstanding as the code
- excluding a hard file from the coverage config to lift the percentage
- tests that execute lines without asserting on the result

**Required per new test: a negative control.** Break the code the test claims to
guard (flip a comparison, delete a bound check, swap a constant), confirm the
test FAILS, restore. Note the mutation in the test's comment. A test that passes
against mutated code guards nothing — and a mutation that SURVIVES is itself the
finding; record it with the reason.

Push toward the maximum by targeting, in order: error paths, allocation failure,
malformed/truncated input, boundary values at every `MAX_*` constant,
cross-buffer seams, and the branches gcovr shows as never taken. 100% is not the
goal; every *reachable* branch having a meaningful assertion is.

---

## 6 — ASan and fuzzing, retargeted

Fuzzing is per-module work; a copied harness driving the skeleton's rule table
proves nothing about the target.

- The fuzz target must call the **real** decision function with
  `(const uint8_t *, size_t)`, not a reimplementation. That seam is checkpoint
  1's job and should already exist; if it does not, stop and land 1 first —
  everything measured here is meaningless without it.
- Seed corpus from the module's actual domain: real headers/bodies/config values
  it parses, plus every past crash under `ci/fuzz/regressions/`.
- `fuzz.dict` with the module's real tokens. A dictionary of the skeleton's
  tokens actively misdirects the fuzzer.
- Replay-then-fuzz order in `fuzzing.yml`: recorded regressions first (fast,
  deterministic), then the time-boxed fresh run. A crash that returns must fail
  in seconds, not after the fresh budget.
- ASan soak (`asan.yml`) must drive the module's real request shape — its
  directives enabled, its body path exercised — not a default config where the
  handler never runs. Verify it reaches the module (a counter, a log line, or
  coverage from the soak build).
- Keep the ASan build static (`--add-module`); a dynamic module under ASan loses
  interception on the parts that matter.
- Adapt neighbours: `valgrind.supp` needs target-specific nginx-core
  suppressions; `codeql.yml`'s TU filter needs the target's file names;
  `ci-deep.yml`'s matrix needs the target's nginx/angie compatibility range.

**Acceptance:** fuzz target links against production code, replays all
regressions, and a deliberately reintroduced past bug is caught by the replay
step (verify once, then revert).

---

## 7 — Caching and the linter gate

### 7a. Caching

Every build goes through `ci/tools/ci-build.sh` as the single chokepoint; no
workflow duplicates cache logic. Layers, cheapest first: apt/packages, ccache
(`CCACHE_COMPILERCHECK=content`), mold (**skipped under ASan**), eatmydata
(wrap configure/install; never wrap something whose durability matters), build
tree (`.build/nginx-<ver>-<mode>`, keyed on mode + version +
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

### 7b. The linter gate

Port `ci/linter/` and follow **[linter/README.md](linter/README.md)** verbatim:
`apt-get` first, then `pipx` for what Debian lacks, then `cpan` for Perl, then
upstream binary for actionlint. `install-linters.sh` is the single installer;
CI and a fresh clone use the same one.

- Tracked hook at `.githooks/pre-commit`, enabled with
  `git config core.hooksPath .githooks`. Lints STAGED files only.
- Thresholds **mirror `security-scanners.yml`**. Move one there, move it here in
  the same commit, or local-green stops predicting remote-green.
- A missing tool exits 2 and BLOCKS. Never a silent skip.
- Relaxations live in `.yamllint` / `.perlcriticrc` with their reason. Fix
  pre-existing findings or record why — no blanket suppression.
- `lint.yml` runs the same `run-all.sh` on a hosted runner, so a clone that
  never enabled the hook still cannot land a regression.

**The checker SET is the target's; the entry point is the standard's.** The
convention is `run-all.sh` + `LINT_ONLY` + exit codes (`0` clean, `1` findings,
`2` tool missing) + the tracked hook. Behind it:

- a module with no Perl needs no `lint-perl.sh`; one with Lua or Rust needs a
  checker the reference lacks. Add `lint-<name>.sh` — `run-all.sh` picks it up
  by glob — and give it a row in the linter README.
- **keep every checker the target already ran** (rule 2), behind the same entry
  point rather than dropped because the reference lacks it.
- the three **repo-policy** checks do not transfer unexamined: `ci-runners`
  depends on `TRUST_SPLITS` being rewritten (checkpoint 3), and `ci-ports` is
  meaningful only if the target binds a fixed band. A target whose driver picks
  its own port should say so in the README and skip it loudly, not carry a check
  that can never fire.
- `lint.yml`'s `LINT_ONLY` string diverges with the checker set. The reference
  runs `nginx sh python perl yaml spelling ci-runners ci-ports docs-drift`; that
  is not a constant to copy, and nothing cross-checks it against the scripts
  that exist.

**Speed budget: the whole hook under ~2s on a one-file commit.** A gate people
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

---

## 8 — Runner topology: lanes, at most four

CI wall-clock on a self-hosted host is dominated by jobs QUEUEING for a
label-matching slot. Ten simultaneous requests just means the tail waits.
**Hosted-only targets can skip this** — say so and move on.

Measure the target, not the reference:

```sh
gh run view <id> -R <owner>/<repo> --json jobs \
  -q '.jobs[] | [.name, .conclusion,
                 (((.completedAt|fromdate)-(.startedAt|fromdate))|tostring)+"s",
                 .startedAt, .completedAt] | @tsv'
```

Keep `startedAt`/`completedAt`, not just durations — the gaps show queueing.

1. Identify the longest single **job**. That is the budget; no arrangement
   finishes sooner. Chain **nothing** behind it. Pairing the longest job with a
   follow-up "to keep the lane busy" is the most common way this gets worse — it
   is what put the reference's lane A at 348s against a 268s budget.
2. Build the **fewest lanes that fit**, four maximum, each a chain of `needs:`
   where a long job releases its slot to a shorter independent follow-up. No
   lane exceeds the budget. Three that fit beat four that also fit. Note the
   fullest lane's headroom in the comment.
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
   suppress an unrelated second one, and so a chain survives an earlier job
   being *skipped* by a changed-files gate.
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

---

## 9 — Self-hosted runner exposure

Applies whenever `runs-on` includes `self-hosted`. **Hosted-only target?** This
is one line in the PR body: "no self-hosted runners; checkpoint 9 N/A except the
token, checkout and action-pinning bullets" — those still apply, being about the
GitHub token and supply chain rather than the runner.

A self-hosted runner executing untrusted code is arbitrary code execution on the
build host. Required:

- **Fork routing** with the adopter's OWN labels (checkpoint 3), never
  `builder02`:
  `runs-on: ${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || fromJSON('["self-hosted","<runner-label>","lxc"]') }}`
- **`TRUST_SPLITS` and `.github/actionlint.yaml` list the adopter's labels and
  nothing else**, edited in the same commit as the workflows. Probe it red per
  checkpoint 3 before claiming this.
- **No `pull_request_target`**, ever, in a repo with self-hosted runners. It runs
  with a writable token in the base-repo context; combined with a fork's code it
  is a full compromise. If something seems to need it, it does not.
- **Least-privilege tokens.** `permissions: contents: read` at workflow level;
  widen per-job only where genuinely needed (`security-events: write` for
  CodeQL). Never `write-all`.
- `persist-credentials: false` on every checkout.
- **Pin every third-party action to a full commit SHA**, version in a trailing
  comment. A tag is mutable.
- Pin every downloaded tool version and verify tarballs by sha256.
- Never expose secrets to a job that can run untrusted code. Prefer no secrets in
  the PR lane; `bump.yml`-style writers run only from the default branch.
- Repo settings (check with `gh api`, fix or report): require approval for
  first-time-contributor runs, restrict which actions may run, branch protection
  with required checks, no self-hosted runner registered at org level where a
  public repo can grab it.
- Runner containers are LXC/incus and persistent: assume a job can see the
  previous job's leftovers. Nothing sensitive in `$HOME` or the work dir, and
  cleanup must not depend on a job succeeding.
- **`zizmor --persona=pedantic --offline`** over `.github/workflows/`, already
  wired into `lint-yaml.sh`. It mechanises most of this section. Expect the
  target red on first run; fix each finding. `# zizmor: ignore[rule]` at the
  line, with a reason, is the only acceptable suppression.
- `${{ }}` interpolation of any attacker-controlled field (PR title, branch name,
  body) into a `run:` block is template injection. Pass through `env:` and quote.
  Required for `matrix.*` too even though it is repo-controlled — the safe form
  costs nothing and stops the unsafe one being copied somewhere it matters.

---

# Phase 3 — Depth pass

Run after every phase-2 checkpoint has merged. Everything here is already green;
the question is whether it would catch anything.

## 10 — Depth pass: is each gate as strong as it looks?

Run this **after checkpoints 0–9 have merged**, as its own PR or a short
series. Everything here is about a gate that is already green: the question is
not "does it run" but "would it catch anything". A soak that never reaches the
handler, a fuzzer driving a reimplementation and a coverage number computed over
nginx core all report success indefinitely.

Each item below is answered with a measurement, in the PR body, not a reading of
the YAML. Where an item cannot be met, say so with the `file:line` and leave the
honest value — rule "never weaken a gate" still applies.

### 10a. The decision seam — re-verify first

Checkpoint 1 established it; everything below depends on it still holding, and
it decays quietly as handler code is added. Re-run 1's probes:

```sh
grep -n 'ngx_http_request_t\|r->\|ngx_http_' src/*_scan.c   # -> expect no hits
grep -n '_scan\.c' ci/fuzz/build.sh ci/tests/unit/run.sh
git log --oneline -- ci/fuzz/ngx_stubs.c                    # stubs grown since 1?
```

A new stub in `ngx_stubs.c` is the signal that decision logic drifted back into
nginx types and someone stubbed around it rather than refactoring. Fix the seam,
not the stub. If 1 was skipped as "no decision logic to separate", confirm that
is still true — a module grows parse surfaces.

**Acceptance:** unit and fuzz builds still compile the target's real `*_scan.c`
(same source, not a second copy), no nginx request types inside it, no stub
growth that is not justified in the PR body.

### 10b. ASan/UBSan — does the soak reach the module?

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
  trip (integer overflow, alignment, shift) and that it is **trapping or
  exiting non-zero** — a UBSan that only prints to stderr passes a red run.
- Verify once by reintroducing a known-bad access, watching it abort, reverting.

### 10c. Fuzzing — can the surface be widened?

The reference carries two targets (`fuzz_scan`, `fuzz_body`). One target on a
module with several parse surfaces is under-fuzzed by construction.

- Enumerate every function taking attacker-controlled bytes; each is a candidate
  target. Add the ones with a real seam, one per parse surface, and say in the
  PR which surfaces remain uncovered and why.
- `fuzz.dict` holds the **target's** tokens. Re-derive; the skeleton's dictionary
  misdirects.
- Corpus from the module's real domain plus every past crash under
  `ci/fuzz/regressions/`. Replay-then-fuzz order stays.
- Report corpus size, and coverage or feature count reached at the end of the
  time-boxed run. A fresh run that plateaus in seconds is a stuck target, not a
  clean one.
- **Acceptance is unchanged from checkpoint 6 and is a mutation test:** reintroduce
  a past bug, confirm replay catches it in seconds, revert.

### 10d. Coverage — measured over the module only

`ci/tools/coverage.sh` exists because an unfiltered `gcovr` reports ~1% — nginx
core is instrumented by the same configure run and swamps the module.

- Confirm the target's coverage filter names the target's `src/`, not the
  reference's, and that the reported figure moves when a test is deleted. A
  number that does not move is filtered wrong.
- **`--object-directory`, never `--gcov-object-directory`** — the latter arrived
  in gcovr 7.0 and is a hard argparse failure below it. Condition is the gcovr
  major version the job actually runs, not whether a pin exists.
- Raise coverage by adding boundary cases to `ci/tests/unit/test_scan.c` — the
  cap, the seam, the hold window, off-by-one on each — not by widening the
  filter or lowering `COVERAGE_FAIL_UNDER`. Uncovered lines that are genuinely
  unreachable get a comment naming why.
- Report before/after and which specific branches the new cases reached.

### 10e. Valgrind, memcheck, helgrind — right tool, right length

The reference splits these deliberately: `valgrind.yml` is a 60s memcheck lite on
the merge path; `ci-deep.yml` runs the 600s memcheck **and** helgrind soaks
monthly, both through `ci/tools/soak.sh` (`USE_VALGRIND` / `USE_HELGRIND`).

**Unconditional — these are grep-cheap and cost nothing on a quiet module:**

- Confirm both soaks exist and that **helgrind is actually invoked** — a copied
  `ci-deep.yml` that lost the helgrind job still shows a green CI Deep badge.
  A dormant module is exactly where a silently-missing job survives longest.
- `valgrind.supp` needs the **target's** nginx-core suppressions. An over-broad
  suppression silently covers the module's own errors: check each entry is scoped
  to a core frame, and that the file was regenerated rather than copied. This is
  independent of recent activity — a stale suppression hides today's bugs.
- Helgrind is only meaningful if the target has shared state across workers
  (shm, a timer, a resolver callback). If it has none, say so explicitly rather
  than running a soak that can never report.

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

- When run: verify the soak is under real load and reaches the module (10b's
  evidence applies here too), and that a deliberate leak is reported before you
  trust it. Report wall-clock per soak and where each runs.
- When skipped: say so in the PR body with the sha you compared against and the
  empty diff. A silent skip is indistinguishable from a soak that never existed.

### 10f. Caching — right layers, no stale-green

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
- Keep the hybrid restore (warm on-disk dirs + `actions/cache` fallback). Deleting
  the fallback because the runners are persistent is how this degrades silently
  the day they become ephemeral.
- A cold PR run is not a bug: GitHub scopes caches by ref, so a PR writes
  `refs/pull/N/merge` and cannot read a branch's entries.
- The rule that outranks every speedup: **a cache must never serve a stale
  artifact into a green result.** If a key cannot express what invalidates it, do
  not cache that layer. Check each key includes what actually changes the output.
- State the honest win in the README. If it saves 5s on a 2.5-minute gate, say so.

### 10g. The linter gate — does every checker still bite?

`zizmor`, `actionlint`, `yamllint`, `semgrep`, `codespell` and the three
repo-policy checks were installed at checkpoint 7b and used at checkpoint 9. This
item does not re-install them; it asks whether each still fires. A checker that
has become a no-op reports the same clean line as one that passes.

- Re-run every probe in the linter README's **"Verify before trusting"** section
  against the target and observe each red. Then run with **two** checkers failing
  at once and confirm both appear and both are named in the `== FAIL:` line.
- **`semgrep` first.** `--jobs=1` and `--metrics=off` are exactly the flags that
  can silently turn it into a no-op, so its probe must still fire. `--jobs=1` is a
  correctness flag, not a speed one — see 7b.
- **`zizmor` findings drift with the workflow set.** Every workflow added since
  7b is new attack surface it now audits. Confirm the count of audited workflows
  matches the count in `.github/workflows/`, and that each `# zizmor: ignore[rule]`
  still names a reason that is still true. A suppression outlives the thing it
  suppressed.
- **`actionlint` remains blind to the `fromJSON` ternary** (checkpoint 3). Do not
  read a clean actionlint as evidence about runner labels; that is probe 2's job
  and probe 2 only.
- Confirm `LINT_ONLY`'s string in `lint.yml` still matches the checkers that
  actually exist — it diverges as the set changes and nothing cross-checks it.
- `run-all.sh` reads `git ls-files`: a **new untracked file is invisible to the
  linter**. Stage before trusting a clean run.
- Re-time the hook against the ~2s budget, `/proc/loadavg` checked first. Over
  budget → scope the slow checker, never drop one, never a default-on skip flag.

### 10h. CI shape — re-measure, then optimise

Only after the above, and only with numbers from `gh run list`:

- Re-check checkpoint 8's lane topology against **measured** wall-clock, not the
  estimates in place when it was written. Lanes drift as tests are added.
- Confirm exactly one `pull_request:` entry point still holds, and that every
  member is reached — a member called by nobody keeps a stale-green badge and
  goes grey only when deleted. Re-run the double-run proof if anything moved.
- Check `/proc/loadavg` before timing anything: at load ~50 the same full-tree
  run varied 2.2s–12.4s over six attempts here, a spread wider than most wins.
- Optimise by moving work off the merge path into `ci-deep.yml`, never by
  deleting a check or widening a threshold.

**Report back for this section:** for each of 10a–10h, the measurement, and for
every gate the one sentence stating what it would now catch that it did not
before. A "verified correct" with no number attached is not an answer.

---

# Phase 4 — Close out

Docs, memory mirror, the anchor a future forward depends on, and the report.

## Finishing

- README rewritten, not appended to: badge row, `## CI` table, layout tree,
  Requirements, and a Linting section linking `ci/linter/README.md`.
- `CONTRIBUTING.md` tells a contributor how to enable the hook.
- `CHANGES` entry describing the standardisation.
- Memory mirror updated: `index.md` (layout, lane map, measured times, **and the
  skeleton commit you adopted from** — the next session needs that anchor),
  `issues.md` (found and not fixed), `lessons.md` (every trap that cost a red CI
  round-trip, `[RECURRING]` if it has bitten before).
- A trap that is a *class* rather than a typo goes into the matching
  `.claude/skills/audit-*/` reference, not only memory. The skill runs
  unprompted next time; memory does not.
- Improvements the target grew that the skeleton lacks get a PR **back to the
  skeleton**. The template is only worth keeping if it stays ahead of its clones.

## Report back

Per checkpoint: what landed, what is red, what you left undone and why. Include
measured before/after wall-clock and coverage. Four questions the report must
answer explicitly, because they are what a greenfield reading gets wrong:

1. **Entry points** — how many workflows carried `pull_request:` before, and
   confirmation exactly one does now.
2. **Runners** — which pool the target runs on. If any `self-hosted` selector
   survives, the output of probe 2 proving the target's own gate rejects the
   reference's label. "Adapted the labels" is not an answer.
3. **Extra workflows and gates** — every check the target had that the reference
   lacks, and whether each was kept, folded, or sent upstream. If any was
   removed, what covers it now.
4. **Badges** — the final row, so order and spelling can be compared without
   opening the repo.

Plus, whenever either applies:

5. **Stopped** — which phase −1 condition fired, at which checkpoint, and what a
   human has to decide. A job that stopped early is a legitimate outcome; one
   reported as finished when it stopped is not.
6. **Anything left disabled, skipped or unverified** — a workflow not enabled, a
   soak skipped per 10e, a gate never seen red. Silence here reads as coverage
   that does not exist.

Do not report a checkpoint complete on a gate you never saw fail.

---

## Forwarding one later change into an adopted module

Once a target scores 3/3 the job inverts: not adoption, but carrying one later
skeleton improvement across. One concern, one PR, one session.

**Establish the anchor first.** Without it you either re-land work the target
has or skip the commit that made the change work. In order of preference: a
recorded anchor in the mirror's `index.md`; a `vN` tag the target's `CHANGES`
names; the `CHANGES` entry describing its adoption; the merge commit of its
adoption PR. Then:

```bash
git -C /opt/myguard/labs/nginx-skeleton-module log --oneline <anchor>..HEAD
```

That is the candidate set; [CHANGES](../CHANGES) says what each was *for*.
**If none of the four resolves, there is no anchor** — the target never took a
documented adoption, so it is a checkpoint job, not a forward. Do not invent one
from the first commit or from "HEAD minus the change I was handed"; both
manufacture a scope that was never true.

Take ONE concern. Before touching the target, write in the PR body what the gate
must prove in *behavioural* terms ("a job that starts the runtime driver without
declaring a port band fails the build"), what failure it would have caught in
the target, and whether the target can even reach that failure — a gate for a
layer it does not have is a checkpoint, not a forward.

Then check the drift classes. **None is visible from a green run:**

- **Port bands** — see checkpoint 4b. Read the target's step ORDER, not just the
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
- **Runner identity** — checkpoint 3. Any change touching a `runs-on`,
  `actionlint.yaml` or `TRUST_SPLITS` carries our pool with it. Run probe 2.
- **No `src/`** — checkpoint 2. Everything scoped to `src/` selects nothing and
  reports success.

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
**current head** — re-check `headRefOid` before merging. Squash-merge, delete
the branch, bump the superrepo gitlink. Record the new anchor in `index.md`.
