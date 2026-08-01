# Prompt — bring an existing nginx module up to myguard skeleton standard

Copy the whole file into a fresh session, replace `<TARGET>` with the module
path, and run it. It is written to be executed by an agent with repo write
access, but it reads as a checklist for a human too.

The reference implementation is `/opt/myguard/labs/nginx-skeleton-module`
(this repo). **Read the reference before changing the target** — the point is
not to make the target look similar, it is to give it the same *gates*.

---

## Context you are given

- **Target module:** `<TARGET>` (e.g. `/opt/myguard/labs/nginx-http-shield-module`)
- **Reference:** `/opt/myguard/labs/nginx-skeleton-module`
- **Memory mirror:** `/opt/myguard/memory/labs/<module-name>/` — read
  `index.md`, `issues.md`, `lessons.md` FIRST. A trap already recorded there
  outranks anything you infer from the code.
- Owner is the `myguard-labs` org; verify with
  `git -C <TARGET> remote get-url origin`, never from a list.

## Ground rules

1. **One PR per phase**, in the phase order below. Each PR is independently
   revertible and independently green. Do not open the next phase's PR until
   the previous is merged — later phases move files the earlier ones edit.
2. **Remote CI green before merge.** No `[skip ci]`, no disabled workflows.
3. **Never weaken a gate to make it pass.** If the target genuinely cannot meet
   a threshold, say so in the PR body with the file:line that proves it, and
   leave the gate at the honest value with a comment naming the reason.
4. **Every gate must be seen red once.** A check you never observed failing is
   a check you have not verified. Record the probe you used, in a comment or
   the PR body. This applies to coverage, to fuzz harnesses and to linters.
5. **Existing behaviour is not in scope.** You are moving CI, not rewriting the
   module. If you find a real bug, file it in the memory mirror's `issues.md`
   and keep going; fix it only if it blocks a gate.
6. Comments explain **why**, at the decision, in the target's existing voice.
   A rule with no recorded reason gets deleted by the next person.

---

## Phase 0 — inventory and baseline (no changes)

Produce a short written baseline before touching anything:

```bash
cd <TARGET>
ls -d t tests fuzz ci src scripts .githooks 2>/dev/null
ls .github/workflows
git log --oneline -10
gh run list -R myguard-labs/<module-name> --limit 20 \
   --json name,conclusion,startedAt,updatedAt,workflowName
```

Record, in the memory mirror's `index.md`:

- current layout (which of `t/`, `tests/`, `fuzz/`, `ci/` exist)
- current workflow list and which of the reference's (Phase 2 table) are missing
- **measured wall-clock per workflow** from `gh run list` — you need real
  numbers for the lane work in Phase 7. Estimates are not acceptable there.
- current coverage number, if any tooling exists (usually none)

Layouts seen across the org, so you know what you are walking into:
`t/` + `fuzz/` at the root (most modules), `tests/` + `fuzz/` (autocert),
already-migrated `ci/` (cache-turbo, label-autoconf).

---

## Phase 1 — move all CI material under `ci/`

Target layout, matching the reference exactly:

```text
ci/
  t/                     Test::Nginx suite            (was t/ or tests/)
  tests/unit/            C unit tests of the decision core (was unit/ or tests/)
  fuzz/                  libFuzzer targets, dict, corpus/, regressions/
  vendor/nginx-tests/    upstream suite submodule
  tools/                 ci-build.sh, nginx-tree.sh, test_runtime.py,
                         coverage.sh, max-port.sh, ci-hang-guard.sh, soak.sh
  linter/                local lint gate (Phase 6)
```

Rules:

- `git mv`, never copy-then-delete — blame must survive.
- A directory move breaks **every relative path that climbs out of it**. After
  the move, grep for and fix, in this order: `../` in C `#include`s, `$PWD`/
  `dirname` logic in shell, `paths:` filters in workflows, `hashFiles()` keys,
  `prove` invocations, fuzz corpus paths, `.gitmodules` submodule paths,
  `.gitignore`, coverage exclude patterns, README references.
  A missed climb compiles fine and silently tests the wrong tree.
- `git submodule update --init` still working after moving
  `ci/vendor/nginx-tests` is a required check — the `.gitmodules` `path:` must
  be edited, not just the directory moved.
- Run the suite locally after the move and before the workflow edits, so a
  failure is attributable to the move and not to both at once:
  `TEST_NGINX_TIMEOUT=20 prove -v ci/t/`
- Leave a dated pointer line in the memory mirror if any note references an old
  path.

**Acceptance:** local `prove` green, fuzz targets still build
(`ci/fuzz/build.sh`), no path outside `ci/` refers to `t/`, `tests/` or `fuzz/`.

---

## Phase 2 — workflows and badges

Bring the target to the reference's workflow set, listed below. Do not copy
blindly: each one carries reference-specific paths and pins that must be
re-derived for the target.

| Workflow | What it must gate in the target |
|---|---|
| `ci.yml` | orchestrator; the ONLY `pull_request` entry point |
| `lint.yml` | the `ci/linter/` gate (Phase 6), hosted runner |
| `build-test.yml` | build, `.so` dlopens, bad config rejected, `-T` survives merged multi-context config, `-Werror`, Test::Nginx, ASan+UBSan |
| `asan.yml` | ASan/UBSan request-storm soak, static `--add-module` |
| `fuzzing.yml` | replay every past crash, then fresh fuzz |
| `valgrind.yml` | memcheck soak |
| `security-scanners.yml` | flawfinder ≥4 blocks, clang-tidy blocks, semgrep ≥WARNING |
| `codeql.yml` | CodeQL over the **module TU only** |
| `ci-deep.yml` | monthly: long fuzz, memcheck, helgrind, nginx mainline+stable+angie matrix |
| `bump.yml` | weekly pin bump + `ci/vendor/nginx-tests` submodule update |

Also port, adapting paths:

- `.github/versions.env` — single source of truth for version **and sha256**
  pins. Tarballs verified by digest, not just version string.
- `.github/scripts/{load-versions,compute-versions,fetch-verify}.sh`
- `.github/actions/build-cache/` composite action
- `.github/actionlint.yaml` — declares the self-hosted runner labels, otherwise
  actionlint flags every `runs-on` and the lint step becomes noise people skip.

Members are `workflow_call:`-only; only `ci.yml` has `pull_request:`. Two entry
points run everything twice per PR and defeat the laning.

**Badges:** README badge block must list the workflows in the SAME ORDER as the
`## CI` table in that README, and both must match reality — a badge for a
workflow that no longer exists renders a permanent grey "no status" and is
worse than no badge. Order used by the reference README:
Build&Test, Security Scanners, Fuzzing, Valgrind, CodeQL, A/UBSan, CI Deep —
insert Lint where the CI table puts it, and keep the two lists in lockstep.

**Acceptance:** `actionlint` clean; every badge resolves to a real workflow
file; the CI table and the badge row are in identical order.

---

## Phase 3 — the four test layers, then coverage

The reference now ships all four. **Reuse them; do not re-derive.**

- `ci/tests/unit/` — `run.sh` + `test_scan.c`. Links the target's REAL decision
  TU and nginx's REAL `src/core/ngx_string.c`; no shimmed decoder, ever. A shim
  makes the layer hermetic and worthless — it would assert that the private copy
  is self-consistent. Reuses `ci/fuzz/ngx_stubs.c` rather than a second copy.
- `ci/tools/test_runtime.py` — the live-server cases Test::Nginx cannot express:
  concurrency, the chunk seam through the real body handler, reload under load.
  Retarget the config and the marker; keep the shape, including the baseline
  case that proves the module is loaded and blocking before anything else runs.
- `ci/tools/coverage.sh` + the `coverage` mode in `ci/tools/ci-build.sh` — a
  distinct build tree, never a flag bolted onto `debug`, so a cached
  non-instrumented tree cannot produce a 0% report that reads as a finding.
  `gcovr` filtered to `src/` only: an unfiltered run drowns the module's numbers
  in 200k lines of upstream nginx.

**Coverage is a REPORT, not a gate.** Earlier revisions of this document told you
to enforce a floor "achieved minus a couple of points". That advice is withdrawn:
the cheapest way to move the number is to write tests that touch lines and assert
nothing, so a floor buys a metric and sells the thing it was proxying for. Publish
the report from `ci-deep.yml`; gate on the mutations recorded beside each suite.
`COVERAGE_FAIL_UNDER` exists for a target that decides otherwise.

**"Without cheating" is the hard part. These are rejected outright:**

- a test whose assertion holds in both the pass and the fail state
  (tell: a captured variable that is never compared)
- a control that hardcodes the verdict instead of calling the real function
- asserting a *precondition* rather than the claim
- one shared counter asserted at N call sites — it pins none of them
- a test written from the same misunderstanding as the code
- excluding a hard file from the coverage config to lift the percentage
- tests that only execute lines without asserting on the result

**Required per new test:** a negative control. Break the code the test claims
to guard (flip a comparison, delete the bound check, swap a constant), confirm
the test FAILS, restore. A test that passes against the mutated code guards
nothing. Note the mutation you used in the test's comment.

Push toward the maximum by targeting, in order: error paths, allocation
failure, malformed/truncated input, boundary values at every `MAX_*` constant,
cross-buffer seams, and the branches your gcovr report shows as never taken.
100% is not a goal; every *reachable* branch having a meaningful assertion is.

**Acceptance:** all four layers present and running in CI, the coverage report
uploaded as an artifact, and each added test observed failing against a stated
mutation that is written down next to it — including any mutation that SURVIVES,
with the reason. An honest recorded limit is worth more than an unchecked claim.

---

## Phase 4 — ASan and fuzzing, retargeted to this module

Fuzzing is per-module work; a copied harness that drives the skeleton's rule
table proves nothing about the target.

- The fuzz target must call the **real** decision function with
  `(const uint8_t *, size_t)`, not a reimplementation. If the target module has
  no such seam — decision logic entangled with `ngx_http_request_t` — extract
  it first (the reference's "one structural rule"). That refactor is in scope
  here; it is what makes everything else measurable.
- Seed corpus from the module's actual domain: real headers/bodies/config
  values it parses, plus every past crash under `ci/fuzz/regressions/`.
- `fuzz.dict` with the module's real tokens — separators, markers, keywords.
  A dictionary of the skeleton's tokens actively misdirects the fuzzer.
- Replay-then-fuzz order in `fuzzing.yml`: every recorded regression first
  (fast, deterministic), then the time-boxed fresh run. A crash that returns
  must fail in seconds, not after the fresh budget.
- ASan soak (`asan.yml`) must drive the module's real request shape — its
  directives enabled, its body path exercised — not a default config where the
  handler never runs. Verify by checking the soak actually reaches the module
  (a counter, a log line, or coverage from the soak build).
- Keep the ASan build static (`--add-module`); a dynamic module under ASan
  loses interception on the parts that matter.
- Adapt the neighbours as needed: `valgrind.supp` needs target-specific
  nginx-core suppressions; `codeql.yml`'s TU filter needs the target's file
  names; `ci-deep.yml`'s matrix needs the target's nginx/angie compatibility
  range.

**Acceptance:** fuzz target links against production code, replays all
regressions, and a deliberately reintroduced past bug is caught by the replay
step (verify once, then revert).

---

## Phase 5 — caching, all layers

Every build goes through `ci/tools/ci-build.sh` as the single chokepoint; no
workflow duplicates cache logic. `.github/actions/build-cache` restores caches
for one mode. Layers, cheapest first:

| Layer | Saves | Keyed on |
|---|---|---|
| **apt / packages** | package install per job | package set hash; on self-hosted, prefer a pre-baked runner image over re-installing |
| **ccache** | recompilation | content (`CCACHE_COMPILERCHECK=content`) |
| **mold** | link time | used when present; **skipped under ASan** |
| **eatmydata** | `configure` + apt fsync stalls | wrap the configure/install steps; never wrap something whose durability matters |
| **build tree** (`.build/nginx-<ver>-<mode>`) | `./configure` | mode + version + `hashFiles(ci-build.sh, config, src/**)` |
| **source tarball** | the download | version (+ sha256 verified after restore) |

Rules that are load-bearing:

- nginx's `configure` **ignores a bare `CC=`** — ccache must be wired through
  the configure argument the reference uses, not via env.
- ccache may use a `restore-keys` fallback ladder (content-hashed, a partial
  hit cannot serve a wrong object). The **build-tree cache must stay
  exact-match only** — do not "fix" that for consistency.
- Hybrid restore (on-disk warm dirs + `actions/cache` fallback) stays. Deleting
  the fallback because the runners are persistent is how this silently degrades
  the day they become ephemeral.
- GitHub scopes caches **by ref**: a PR run writes `refs/pull/N/merge` and
  cannot read a branch's entries. A cold PR run is not a bug.
- A cache must never be able to serve a stale artifact into a green result. If
  a key cannot express what invalidates it, do not cache that layer.
- State the honest win in the README. If caching saves 5s on a 2.5-minute gate,
  say so — the reason to keep it is the heavier module that comes later.

---

## Phase 6 — pre-commit linters

Port `ci/linter/` from the reference and follow its README verbatim:
**[ci/linter/README.md](linter/README.md)** — per-tool `apt-get` (preferred),
then `pipx` for what Debian lacks, then `cpan` for Perl modules, then upstream
binary for actionlint. `ci/linter/install-linters.sh` is the single installer;
CI and a fresh clone use the same one.

- Tracked hook at `.githooks/pre-commit`, enabled with
  `git config core.hooksPath .githooks`. It lints STAGED files only.
- Checkers: C (flawfinder ≥4, cppcheck, semgrep ≥WARNING), nginx conventions
  (libc vs `ngx_*`, tabs, 80 cols, include order), shell (shellcheck
  `-S warning`), Python (ruff), Perl (`perl -c` + perlcritic ≥4), YAML
  (yamllint + actionlint).
- Thresholds **mirror `security-scanners.yml`**. Move one there, move it here
  in the same commit, or local-green stops predicting remote-green.
- A missing tool exits 2 and BLOCKS. Never a silent skip.
- Relaxations live in `.yamllint` / `.perlcriticrc` at the repo root, each with
  its reason. If the target has pre-existing warning-level findings, fix them
  or record why — do not add a blanket suppression.
- `lint.yml` runs the same `run-all.sh` on a hosted runner, so a clone that
  never enabled the hook still cannot land a regression.

### Speed budget: the whole hook under ~2s on a one-file commit

A commit gate people wait on is a commit gate people bypass with `--no-verify`.
Measure it (`time ci/linter/run-all.sh <one file>`), and if it is over budget
the fix is scoping the slow checker — **never** dropping one, and never a
default-on skip flag.

Carry these three from the reference; each was measured, not assumed:

- **`semgrep --metrics=off`.** The end-of-scan telemetry POST to semgrep.dev
  was 2.76s of a 2.76s scan; without it, 1.27s. More than half the gate was
  upload.
- **`semgrep --jobs=1`** — a *correctness* flag, not a speed one. semgrep-core
  defaults to one OCaml domain per core and each domain opens its own io_uring
  ring against the host's `RLIMIT_MEMLOCK` (8 MB on builder02, shared with
  every other job). When the runners are busy it exhausts and semgrep-core
  aborts with `Unix_error: Cannot allocate memory io_uring_queue_init`, exit 2
  — a red gate caused by a *neighbouring* job, on a scan of three files where
  the parallelism bought nothing. Reproduced 3/3 busy, 0/3 idle, so an idle-box
  green tells you nothing here. The same flags go in `security-scanners.yml`:
  same host, same crash, and the two must stay in sync anyway.
- **`run-all.sh` fans the checkers out** (`LINT_JOBS`, default one slot per
  checker, `LINT_JOBS=1` to bisect a hang). Two requirements that are easy to
  get wrong:
  - Buffer each checker's output to its own file and replay it whole, in fixed
    glob order — **never stream them interleaved.** Findings carry a
    `file:line` but not a checker name, so interleaved output cannot be
    attributed, which is the entire reason to buffer. Fixed order also makes
    two runs of the same dirty tree byte-comparable.
  - Each child writes its exit status to a file. The reaping `wait` is
    collective, so per-child statuses are not otherwise recoverable, and a
    **missing** status file (child SIGKILLed) must count as a failure, never as
    a pass.

Reference measurements, whole checkout: 3.8s → 1.45s, one C file 2.9s → 1.31s.
Yours will differ; record yours — **and check `/proc/loadavg` before you take
them.** The build host also runs the self-hosted CI slots; at load ~50 the same
full-tree run varied 2.2s–12.4s over six back-to-back attempts, a spread wider
than the whole improvement. A busy-box A/B measures the neighbouring jobs. This
is the same shared-resource contention as the semgrep memlock crash above, and
it is why every number in this phase has to say what the box was doing.

**Acceptance:** run every probe in the linter README's "Verify before trusting"
section against the target and observe each one red — *after* the speed work,
not before. `--jobs`/`--metrics` are exactly the kind of flag that can silently
turn a checker into a no-op, so the semgrep probe in particular must still
fire (`insecure-use-string-copy-fn` on the malloc/strcpy file). Then run
`run-all.sh` with two different checkers failing at once and confirm both
appear in the output and both are named in the `== FAIL:` line.

---

## Phase 7 — runner topology: lanes, at most four

The reference lanes the suite so peak self-hosted use stays bounded — CI
wall-clock on builder02 is dominated by jobs QUEUEING for a label-matching
slot, not by the jobs themselves. Ten simultaneous requests just means the tail
waits.

**Measure first, and measure the target, not the reference.** Take real per-job
durations from a recent green run:

```sh
gh run list -R myguard-labs/<repo> --workflow=ci.yml --limit 5 \
  --json databaseId,headSha,conclusion
gh run view <id> -R myguard-labs/<repo> --json jobs \
  -q '.jobs[] | [.name, .conclusion,
                 (((.completedAt|fromdate)-(.startedAt|fromdate))|tostring)+"s",
                 .startedAt, .completedAt] | @tsv'
```

Keep `startedAt`/`completedAt`, not just the durations — the gaps are what show
you queueing, and which lane is actually the critical path.

Then:

1. Identify the longest single **job**. That is the budget: no arrangement can
   finish sooner. Chain **nothing** behind it — every second added there is a
   second on the suite's critical path, whereas the same job appended to a
   shorter lane is free. Pairing the longest job with a follow-up "to keep the
   lane busy" is the single most common way this gets worse; it is what put the
   reference's lane A at 348s against a 268s budget.
2. Build the **fewest lanes that fit**, four maximum, each a chain of `needs:`
   where a long job releases its slot to a shorter, independent follow-up. No
   lane's total may exceed the budget. Three lanes that all fit beat four that
   also fit — fewer chains, fewer `!cancelled()` edges to reason about. Note
   the headroom of the fullest lane in the comment, so the next person knows
   how much a job can grow before the shape stops holding.
3. If it does not fit in four, the honest fixes are: move a check out-of-band
   (monthly), time-box it, or put it on a hosted runner — not "add a fifth".
4. **A lane is not a slot.** Count the target's real slots
   (`systemctl list-units | grep ci-ephemeral` on the runner host — six on
   builder02), and remember a reusable workflow can fan out into many
   concurrent jobs: the reference's Build&Test is *five*, so the observed peak
   is 7 against 6 slots. Brief oversubscription at t=0 is acceptable; writing
   "caps peak runner use at three" when it is seven is not.
5. Hosted jobs (lint, CodeQL) take no self-hosted slot, so they are **not laned
   at all** — no `needs:`, start immediately, fastest feedback. Chaining a
   hosted job behind a self-hosted one to "conserve a slot" conserves nothing
   and just delays its result.
6. Follow-ups use `if: ${{ !cancelled() }}` so a failing first check does not
   suppress an unrelated second one. A red ASan should still tell you whether
   Valgrind is clean. It is also what keeps a chain alive when an earlier job
   is *skipped* by a changed-files gate, which a bare `needs:` would not.
7. Concurrency groups must not collide. A called workflow inherits the caller's
   `github.workflow`/`github.ref`, so an identical group string makes a member
   cancel its own caller and a whole lane dies before it starts. Prefix the
   orchestrator's group distinctly.
8. Path-gating a reusable workflow does not work — a called workflow cannot
   filter its own triggering. Gates move to a `changes` job in the orchestrator
   with an explicit job-level `if`. That diff job must **fail loudly** on an
   unusable diff, never fall through to "no relevant changes" — failing open
   skips the sanitizer on exactly the PRs that need it.

The orchestrator's header comment is the only place this design is written
down, so it is part of the deliverable, not documentation of it. It must carry
the lane map, the measured durations, the run ID and date they came from, and
the command above to re-derive them. **Any lane change rewrites that comment in
the same commit** — a stale lane map reads as measurement and gets trusted.
Also record the lane map and timings in the memory mirror.

---

## Phase 8 — self-hosted runner exposure

Applies whenever `runs-on` includes `self-hosted`. A self-hosted runner
executing untrusted code is arbitrary code execution on the build host.

Required:

- **Fork routing.** Every self-hosted job uses the reference's expression:
  `runs-on: ${{ github.event.pull_request.head.repo.fork && 'ubuntu-latest' || fromJSON('["self-hosted","builder02","lxc"]') }}`
  A fork PR never reaches the build host.
- **No `pull_request_target`**, ever, in a repo with self-hosted runners. It
  runs with a writable token in the base-repo context; combined with a fork's
  code it is a full compromise. If something seems to need it, it does not.
- **Least-privilege tokens.** `permissions: contents: read` at workflow level;
  widen per-job only where genuinely needed (`security-events: write` for
  CodeQL). Never `write-all`.
- `persist-credentials: false` on every checkout, so a later step cannot reuse
  the token.
- **Pin every third-party action to a full commit SHA**, with the version in a
  trailing comment. A tag is mutable.
- Pin every downloaded tool version (semgrep, actionlint, nginx tarballs) and
  verify tarballs by sha256. This is code executing on a persistent host.
- Never expose secrets to a job that can run untrusted code. Prefer no secrets
  at all in the PR lane; `bump.yml`-style writers run only from the default
  branch on a schedule.
- Repo settings (check with `gh api`, fix or report): require approval for
  first-time-contributor workflow runs, restrict which actions may run,
  branch protection with required checks, and no self-hosted runner registered
  at org level where a public repo can grab it.
- Runner containers are LXC/incus and persistent: assume a job can see the
  previous job's leftovers. Nothing sensitive may be left in `$HOME` or the
  work dir, and cleanup must not depend on a job succeeding.

- **`zizmor --persona=pedantic --offline`** over `.github/workflows/`, already
  wired into the reference's `ci/linter/lint-yaml.sh` and therefore into both
  the hook and `lint.yml`. It mechanises most of this section: template
  injection, dangerous triggers, `artipacked`, `unpinned-uses`,
  `excessive-permissions`, plus a `self-hosted-runner` audit. Port it with the
  rest of the linter dir; expect the target to be red on first run and fix
  each finding rather than ignoring it. `# zizmor: ignore[rule]` at the line,
  with a reason, is the only acceptable suppression.
- `${{ }}` interpolation of any attacker-controlled field (PR title, branch
  name, body) directly into a `run:` block is template injection. Pass through
  `env:` and quote. The same shape is required for `matrix.*` even though it is
  repo-controlled — the safe form costs nothing and stops the unsafe one being
  copied somewhere it matters.

---

## Finishing

- README rewritten, not appended to: badge row, `## CI` table, layout tree,
  Requirements, and a Linting section linking `ci/linter/README.md`.
- `CONTRIBUTING.md` tells a contributor how to enable the hook.
- `CHANGES` entry describing the standardisation.
- Memory mirror updated: `index.md` (layout, lane map, measured times),
  `issues.md` (anything found and not fixed), `lessons.md` (every trap that
  cost you a red CI round-trip — `[RECURRING]` if it has bitten before).
- Any trap that is a *class* rather than a typo goes into the matching
  `.claude/skills/audit-*/` reference, not only into memory. The skill is what
  runs unprompted next time.
- Improvements you made that the skeleton lacks (coverage tooling, eatmydata)
  get a PR back to `nginx-skeleton-module`. The template is only
  worth keeping if it stays ahead of its clones.

## Report back

State plainly, per phase: what landed, what is red, what you left undone and
why. Include the measured before/after wall-clock and the coverage
before/after. Do not report a phase complete on a gate you never saw fail.
