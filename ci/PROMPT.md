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
Eight checkpoints, below, one PR each.

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
   linter here will tell an adopter they copied it. Checkpoint 2 settles it
   before any workflow is ported.

Standing constraints, all checkpoints:

- **One PR per checkpoint**, in order, each independently revertible and
  independently green. Do not open the next until the previous merges — later
  ones move files the earlier ones edit.
- **Remote CI green before merge.** No `[skip ci]`, no disabled workflows.
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

## 0 — Inventory and baseline (no changes)

```bash
cd <TARGET>
git remote get-url origin                                # who owns it
ls -d ci/t ci/tools ci/linter ci/fuzz src t tests fuzz 2>/dev/null
ls .github/workflows
grep -lE '^\s*pull_request:' .github/workflows/*.yml | wc -l   # entry points
grep -rn 'runs-on' .github/workflows/                    # whose machines?
ls src 2>/dev/null || ls *.c *.h                         # C at root?
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
1 and the most misleading signal in the set. **No `ci.yml` settles it on its
own.**

Record in the memory mirror (`/opt/myguard/memory/labs/<module-name>/index.md`
for ours; an external target has no mirror — create one only if the work is
ongoing):

- current layout, and whether `src/` exists
- workflows in three buckets: **matches** a reference workflow by purpose,
  **missing**, and **extra** — one the reference has no equivalent for. The
  third bucket is what rule 2 protects and what gets lost otherwise.
- **every `pull_request:` entry point by name** — that count is the size of the
  checkpoint 3 demotion, the riskiest edit in the job
- whose runners it currently uses
- **measured wall-clock per workflow** from `gh run list` — real numbers, needed
  for checkpoint 7. Estimates are not acceptable there.
- current coverage number, if any tooling exists (usually none)
- gates it has that the reference lacks, and where they run

**Read the memory mirror first if the target is ours** — `index.md`,
`issues.md`, `lessons.md`. A trap recorded there outranks anything you infer
from the code.

**Baseline the target green.** Run whatever suite it has and record the result.
If it is already red, that is a finding for `issues.md` and a fact the first PR
body must state — otherwise checkpoint 1 inherits blame for a failure that
predates it.

---

## 1 — Move CI material under `ci/`

Target layout, matching the reference:

```text
ci/
  t/                     Test::Nginx suite            (was t/ or tests/)
  tests/unit/            C unit tests of the decision core
  fuzz/                  libFuzzer targets, dict, corpus/, regressions/
  vendor/nginx-tests/    upstream suite submodule
  tools/                 ci-build.sh, nginx-tree.sh, test_runtime.py,
                         coverage.sh, max-port.sh, ci-hang-guard.sh, soak.sh
  linter/                local lint gate (checkpoint 6)
```

- `git mv`, never copy-then-delete — blame must survive.
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
- **No `src/`? Creating one is part of this checkpoint.** Two of eight derived
  modules keep `ngx_http_<name>_module.c` (sometimes plus `<name>_core.c/.h`) at
  the repo root. Everything downstream is scoped to `src/` — `lint-c.sh`,
  `lint-nginx.sh`, the gcovr filter, the CodeQL TU filter — and every one
  *passes* on an empty selection rather than failing. Move the C under `src/`
  and update `config` in the same commit. Prove it: a `malloc`/`strcpy` probe
  file where the module's real C lives must make `LINT_ONLY="c nginx"` exit 1.
- Run the suite after the move and before any workflow edit, so a failure is
  attributable to one thing: `TEST_NGINX_TIMEOUT=20 prove -v ci/t/`

**Acceptance:** local `prove` green, fuzz targets still build
(`ci/fuzz/build.sh`), no path outside `ci/` refers to `t/`, `tests/` or `fuzz/`.

---

## 2 — Runner identity is not portable

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
variable, both of which a fork controls. Then read checkpoint 8 in full.

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

## 3 — Workflows, badges, and ONE entry point

Do this in two commits: the demotion first, then the missing workflows. Adding a
workflow to a repo that still has six triggers multiplies the problem.

### 3a. Demote to a single orchestrator

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

Skipping step 2 is how a member ends up called by nobody: `ci.yml` references a
job name that does not exist, the call contributes nothing, and the suite looks
green because the check that would have failed never ran.

Two things that break a called workflow and not a standalone one:

- **`secrets: inherit` is not automatic.** A member that used a secret while
  standalone loses it when called unless the caller passes it.
- **Path filters do not work on a called workflow** — it cannot filter its own
  triggering. Gates move to a `changes` job in the orchestrator with an explicit
  job-level `if`. See checkpoint 7 rule 8.

A second entry point that is not `pull_request:` (a `schedule:`, a
`workflow_dispatch:`) is fine and normal — `bump.yml` and `ci-deep.yml` in the
reference are schedule-driven and not members of the PR lane.

### 3b. The workflow set

| Workflow | What it must gate in the target |
|---|---|
| `ci.yml` | orchestrator; the ONLY `pull_request` entry point |
| `lint.yml` | the `ci/linter/` gate (checkpoint 6), hosted runner |
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
checkpoint 2).

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

### 3c. Badges — same order, same text

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

## 4 — The four test layers, then coverage

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

## 5 — ASan and fuzzing, retargeted

Fuzzing is per-module work; a copied harness driving the skeleton's rule table
proves nothing about the target.

- The fuzz target must call the **real** decision function with
  `(const uint8_t *, size_t)`, not a reimplementation. No such seam — decision
  logic entangled with `ngx_http_request_t`? Extract it first. That refactor is
  in scope here; it is what makes everything else measurable.
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

## 6 — Caching and the linter gate

### 6a. Caching

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

### 6b. The linter gate

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
  depends on `TRUST_SPLITS` being rewritten (checkpoint 2), and `ci-ports` is
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

## 7 — Runner topology: lanes, at most four

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

## 8 — Self-hosted runner exposure

Applies whenever `runs-on` includes `self-hosted`. **Hosted-only target?** This
is one line in the PR body: "no self-hosted runners; checkpoint 8 N/A except the
token, checkout and action-pinning bullets" — those still apply, being about the
GitHub token and supply chain rather than the runner.

A self-hosted runner executing untrusted code is arbitrary code execution on the
build host. Required:

- **Fork routing** with the adopter's OWN labels (checkpoint 2), never
  `builder02`:
  `runs-on: ${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || fromJSON('["self-hosted","<runner-label>","lxc"]') }}`
- **`TRUST_SPLITS` and `.github/actionlint.yaml` list the adopter's labels and
  nothing else**, edited in the same commit as the workflows. Probe it red per
  checkpoint 2 before claiming this.
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

- **Port bands** — see checkpoint 3b. Read the target's step ORDER, not just the
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
- **Runner identity** — checkpoint 2. Any change touching a `runs-on`,
  `actionlint.yaml` or `TRUST_SPLITS` carries our pool with it. Run probe 2.
- **No `src/`** — checkpoint 1. Everything scoped to `src/` selects nothing and
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
