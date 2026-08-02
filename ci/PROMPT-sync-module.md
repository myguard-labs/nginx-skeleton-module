# Prompt — forward one skeleton change into an already-standardised module

Copy the whole file into a fresh session, replace `<TARGET>` with the module
path and `<CHANGE>` with the skeleton improvement you are forwarding, and run
it. Written to be executed by an agent with repo write access; it reads as a
checklist for a human too.

The reference implementation is `/opt/myguard/labs/nginx-skeleton-module` (this
repo). **Read the reference change and the target's current version of the same
file before editing anything** — the job is not to make the two files match, it
is to give the target the same *gate*, expressed in the target's own paths,
names and pins.

## Scope — is this the right document?

This is the **recurring** job: a module that already carries this CI shape, and
one later skeleton improvement that has to reach it. One concern, one PR, one
session.

If the target has **never** been standardised, this document is the wrong size
for the job — use [PROMPT-standardize-module.md](PROMPT-standardize-module.md),
which is the eight-phase, eight-PR first-time bring-up.

Tell which you are looking at. A standardised target has all three of:

- a `ci/` layout (`ci/t/`, `ci/tools/`, `ci/linter/`, `ci/fuzz/`),
- `ci.yml` as its **sole** `pull_request` entry point, with the other workflows
  as `workflow_call` members,
- `ci/linter/run-all.sh` and a tracked `.githooks/pre-commit`.

Two of three means a partial bring-up: forward the change with this document,
and open a separate PR for the missing phase using the bring-up prompt. Do not
smuggle a missing phase into a sync PR — they have different blast radii and a
reviewer cannot separate them after the fact.

## Context you are given

- **Target module:** `<TARGET>` (e.g. `/opt/myguard/labs/nginx-<name>-module`)
- **Reference:** `/opt/myguard/labs/nginx-skeleton-module`
- **The change:** `<CHANGE>` — a commit, a PR number, or a described behaviour
  in the reference
- **Memory mirror:** `/opt/myguard/memory/labs/<module-name>/` — read
  `index.md`, `issues.md`, `lessons.md` FIRST. A trap already recorded there
  outranks anything you infer from the code, and the anchor from the last sync
  is recorded in `index.md` if there was one.
- Owner is the `myguard-labs` org; verify with
  `git -C <TARGET> remote get-url origin`, never from a list.

## Ground rules

1. **One concern per PR.** A sync PR carrying four unrelated skeleton commits
   is not independently revertible, and a red run in it does not tell you which
   of the four broke. If the change you were handed decomposes, forward the
   pieces in separate PRs and say which is which.
2. **Re-derive, never copy blind.** Every workflow, script and comment in the
   reference carries reference-specific paths, module names, runner labels,
   port bands and version pins. A file copied verbatim compiles, runs, and
   gates the wrong thing — silently, and green.
3. **Every gate must be seen red once, in the target.** A gate that has only
   ever passed is a gate you have not verified. The reference's own probe is
   not evidence about the target: different paths, different files, different
   thresholds. Record the probe in the PR body.
4. **Never weaken a gate to make the target pass.** If the target genuinely
   cannot meet a threshold, say so in the PR body with the `file:line` that
   proves it, and leave the gate at the honest value with a comment naming the
   reason and the ledger row.
5. **Existing behaviour is not in scope.** You are forwarding a gate, not
   rewriting the module. A real bug you find on the way goes in the mirror's
   `issues.md`; fix it only if it blocks the gate you came to install.
6. **Remote CI green before merge.** No `[skip ci]`, no disabled workflows.
   A docs-only sync may take the repository's trivial-PR exception; anything
   touching a workflow, a script, a port band or a threshold does not.
7. Comments explain **why**, at the decision, in the *target's* voice. A rule
   arriving from the reference with no recorded reason gets deleted by the next
   person who finds it inconvenient.

---

## Step 0 — establish the anchor (no changes)

**Without an anchor you are guessing at scope**, and a sync session that guesses
either re-lands work the target already has or silently skips the commit that
made the change work.

The anchor is whatever the target last took from the reference, in this order of
preference:

1. a recorded anchor in the mirror's `index.md` (previous sync wrote it there),
2. a `vN` tag of the reference, if the target's `CHANGES` names one,
3. the target's `CHANGES` entry describing its standardisation or last sync,
4. the merge commit of the target's standardisation PR — the floor, and always
   available.

Then, in the reference:

```bash
git -C /opt/myguard/labs/nginx-skeleton-module log --oneline <anchor>..HEAD
```

That is the candidate set. [CHANGES](../CHANGES) says what each one was *for*,
which the subject lines often do not.

Write the anchor you resolved, and how, into the PR body. The next session reads
it.

## Step 1 — select ONE concern, and state what it must prove

From the candidate set, take one. Before touching the target, write down — in
the PR body, not just in your head:

- **what the gate must prove**, in behavioural terms ("a job that starts the
  runtime driver without declaring a port band fails the build"), not in file
  terms ("copy `lint-ci-ports.sh`"),
- **what failure it would have caught** in the target, concretely,
- **whether the target can even reach that failure** — a gate for a layer the
  target does not have is not a sync, it is a bring-up phase.

The Phase 2 table in [PROMPT-standardize-module.md](PROMPT-standardize-module.md)
is the reference for what each gate is *for*. Read the row before you port the
file.

## Step 2 — read the target's current state, then check the drift classes

Read the target's version of every file the change touches, plus its `ci.yml`
lane map. Then check the drift classes below. **None is visible from a green
run** and each has bitten a module here, so a target that looks healthy tells
you nothing about them.

### 2a. Port bands

Test::Nginx binds `TEST_NGINX_PORT`, default 1984, and nothing arbitrates it. A
self-hosted host runs several runner slots against one network, so two jobs on
the default collide and the loser dies with
`bind() to 127.0.0.1:1984 failed (98: Address already in use)` — which reads as
a module regression and is not one.

Presence of `TEST_NGINX_PORT` is **not** the check. The check is:

- a **distinct job-level band** per workflow (the reference uses
  `TEST_BASE_PORT` 19200 in `build-test.yml` and 19400 in `ci-deep.yml`),
- verified free and non-ephemeral with `ci/tools/max-port.sh`
  **before the first step that binds it**,
- enforced by `ci/linter/lint-ci-ports.sh`, which fails the build when a job
  starts the runtime driver without declaring a band.

"Before the first step that binds" is the part that gets copied wrong. A verify
step placed above the *runtime* suite looks right and guards nothing if a
`prove` step binds the same band earlier — which is what `build-test.yml` itself
shipped until 2026-08-02. Read the target's step ORDER, not just the presence of
the step.

A target whose test driver picks its own free port is already immune; leave it
alone and say so.

### 2b. Coverage option spelling

`--gcov-object-directory` in `ci/tools/coverage.sh` fails argparse on gcovr
below 7.0 — the `--gcov-`-prefixed spelling arrived with the 7.0 prefix
standardisation. The condition is the **gcovr major version the job actually
runs**, not whether a pin exists in the repo. `--object-directory` is accepted by
both and is the portable choice for any job whose runner gcovr you do not
control, which includes the fork arm's hosted runner.

### 2c. `versions.env` consumers

A `.github/versions.env` consumer that sources the file without validating it
executes any line that is not a pin. If the target is receiving `versions.env`
for the first time in this sync, it receives the validating loader — the version
you hand over is the one that has to be correct, because there is no earlier copy
to audit.

### 2d. `workflow_policy.py` vintage

A `ci/linter/workflow_policy.py` older than the YAML-parse rewrite matches
workflow YAML with regexes. Valid YAML then makes all three policy checks
silently vacuous: a `.yaml` extension, an inline `on: [pull_request]`, or a
comment after a job key. Same note as 2c — if it arrives with this sync, ship
the YAML-parse version, and run `ci/linter/selftest.sh` plus the fixtures under
`ci/linter/fixtures/policy/` in the target to prove the checks go red.

### What a survey of the derived modules found (2026-08-01, read-only)

Nine targets. Not one carried a `.github/versions.env` or a
`ci/linter/workflow_policy.py`, so 2c and 2d could not exist in any of them —
those files arrive *with* a rollout. Seven of the nine ran `prove` on a
self-hosted label with no `TEST_NGINX_PORT` at all; of the remaining two, one
picked a free port from its own driver and one had no `prove` workflow. The
coverage option turned up in a single module and was not breaking there.

Counts, not a standing fact — re-derive against the targets you actually have.

## Step 3 — port the change, re-derived

Rewrite for the target rather than copying:

- **module name and symbol prefix** — `skel`/`ngx_http_skel_*` in the reference
  is the target's own prefix everywhere, including in fuzz targets, unit tests
  and grep patterns inside scripts,
- **paths** — the target may keep tests at `t/` or `tests/` rather than `ci/t/`,
- **runner labels and fork routing** — take the target's existing expression,
  not the reference's literal,
- **port bands** — a band that does not collide with the target's *other* jobs,
- **version pins** — the target's nginx/angie/tool versions, not the
  reference's,
- **thresholds** — keep the reference's, unless rule 4 applies and you record
  why.

Then check the two consistency gates the reference enforces on itself, because
they will fail late otherwise:

- `lint-docs-drift` compares the **workflow set** against the README's `## CI`
  table. A new or renamed workflow needs the README row in the same commit.
- `ci/linter/run-all.sh` reads `git ls-files`, so a **new untracked file is
  invisible to the linter**. Stage it before you trust a clean run.

## Step 4 — verify the gate red in the target

Break the thing the gate exists to catch, watch it fail, put it back. Then run
the suite clean.

The probe is per gate; state the one you used. Shapes that work:

- **a policy linter** — drop the offending construct into a scratch workflow
  under `.github/workflows/_probe.yml`, run with `LINT_ONLY=<checker>`, delete
  it. The fixtures under `ci/linter/fixtures/policy/` are the maintained version
  of this,
- **a port-band gate** — a job that starts the runtime driver with no band
  declared,
- **a test layer** — mutate the code under test so the assertion must fail. An
  unapplied mutation is a hypothesis, not evidence; if the mutation *survives*,
  you have found a vacuous test, and that is the finding.

Two traps that make a probe lie:

- a check that never ran reports the same as a check that passed. An empty
  selection, a missing file type, a path gate that did not match — read the
  linter's own "no files to check" lines before calling a run clean,
- an assertion about the OUTPUT of a command that deliberately exits non-zero
  fails under `set -o pipefail` no matter what the output says. Capture into a
  variable first.

## Step 5 — run the local gate at the target's own thresholds

```bash
cd <TARGET>
ci/linter/run-all.sh                      # or --staged, what the hook runs
bash ci/tools/ci-build.sh nginx <version>
TEST_NGINX_TIMEOUT=20 prove -v ci/t/
```

Local green only predicts remote green when the **thresholds and the tool
versions match**. A locally-installed linter one minor behind the repo's pin can
be missing the exact rule CI gates on. Check the pin before believing a clean
local run, and remember `TEST_NGINX_TIMEOUT` — the ~2s default fails as a
contiguous sweep of `client socket timed out` with zero assertion failures,
which is the harness, not the module.

Measurement caveat: a build host running other jobs is not a valid timing
environment. Check the load before any before/after number goes in the PR body.

## Step 6 — PR, CI, merge

- Open the PR against the target's `main`, workflows **enabled**.
- Body states: the anchor and how you resolved it, the one concern, what the
  gate proves, the probe you ran and what it printed, and every deliberate
  divergence from the reference with its reason.
- Remote CI green on the **current head** — re-check `headRefOid` against the
  green run's head before merging; a run that was green on an earlier commit is
  not evidence about this one.
- Read a bot review if one has arrived. Advisory, never a merge gate; verify
  each finding against the code before acting, and refute with a `file:line`
  when it is wrong.
- Squash-merge, delete the remote branch, then bump the superrepo gitlink for
  that checkout.

## Step 7 — record the anchor and the traps

In `/opt/myguard/memory/labs/<module-name>/`:

- `index.md` — **the anchor you synced to.** Without it the next session
  re-derives it from scratch, or guesses.
- `issues.md` — anything found and not fixed, including a drift class you
  confirmed present but out of this PR's concern.
- `lessons.md` — every trap that cost a red CI round-trip (`[RECURRING]` if it
  has bitten before).

A trap that is a *class* rather than a typo also goes into the matching
`.claude/skills/audit-*/` reference, not only into memory. The skill is what
runs unprompted next time; memory alone does not.

## Step 8 — send improvements back

A fix or a layer the target grew that the reference lacks gets a PR **to the
skeleton**. Same for a divergence you had to invent here that the next sync will
also need. The template is only worth keeping if it stays ahead of its clones.

## Report back

State plainly: the anchor, the one concern, what landed, the probe and its
output, what you deliberately left diverging and why, what you left undone and
why. Do not report a gate installed on a probe you never ran.
