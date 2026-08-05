# nginx-http-shield-module — 2026-08-05

Adoption run against a target that was already at 3/3 markers with anchor
`872fc33`. The forward path found no candidate (every commit since the anchor
touches only `ci/PROMPT.md`, `ci/feedback/README.md` and this repo's own
`README.md`), so the findings below are all of the shape "the target has a gate
this repo does not".

Each is a *port*, not a fix to an existing file, which is why they are here
rather than as a code change in this PR: dropping three new checkers into
`ci/linter/` and `ci/tools/` changes the gate set of every module that adopts
this skeleton next, and two of the three need a decision about scope before that
is right.

## 1. No gate ties the self-hosted runner ban to the TRIGGER

**What.** `check_runners` in `ci/linter/workflow_policy.py:201` validates a
`runs-on` selector against an allowlist of approved label sets
(`TRUST_SPLITS`, `ci/linter/workflow_policy.py:87`). The stated reason the
split matters is trigger-shaped — `workflow_policy.py:78-80`: "a
`pull_request`-triggered job checks out and EXECUTES scripts from the PR head."
But the check never reads the trigger. It only asks whether the selector has an
approved *shape*.

The consequence is that the property being defended is not the property being
tested. A workflow that carries `pull_request:` and a bare
`["self-hosted", "builder02", "lxc"]` passes, because that label set is in
`TRUST_SPLITS`. The fork-ternary arm is what makes the set safe, and a selector
that omits the ternary but reuses an approved label list is accepted by the
membership test.

**Where.**

- this repo: `ci/linter/workflow_policy.py:243` (`runner in TRUST_SPLITS`),
  policy set at `:87-95`, rationale at `:75-86`
- target: `ci/tools/check-workflow-runners.sh` (64 lines) — parses each
  workflow, asks "does this have a `pull_request` trigger", and fails if such a
  workflow names a self-hosted runner at all. Label-set independent.

**What it cost.** Nothing on this run — shield passes both. The target's own
memory has carried "worth a PR upstream to the skeleton, not done" across
several sessions, which is how it reached a third adoption still unported.

**Proposed change.** Port the trigger-based assertion as a second, independent
check rather than replacing `check_runners`. The two catch different failures:
the allowlist catches a typo'd or unknown label, the trigger check catches an
approved label used on a fork-reachable trigger. Keeping both means neither can
be defeated by satisfying the other.

**Why a decision, not a fix.** The target's version fails closed when it finds
zero workflows (`check-workflow-runners.sh:26-30`). That is correct there and
would be correct here, but it makes the gate newly capable of failing a repo
that is mid-bootstrap with an empty `.github/workflows/`, and this repo is the
thing people bootstrap *from*. Whether it lands as a `workflow_policy.py`
subcommand (consistent with `runners`/`ports`/`docs`, `:460`) or as a standalone
`ci/tools/` script (the target's shape) is also a call for the owner — the
subcommand form gets `LINT_ONLY` selection for free, the standalone form is
copyable into a module that has no `workflow_policy.py`.

## 2. Nothing enforces that a PR member carries no `push:`

**What.** No workflow in this repo carries a `push:` trigger, and no check
requires that. The property holds by construction and by nobody having copied a
workflow that had one.

`workflow_call` does not suppress a member's own `push:`. A member called by
`ci.yml` that also carries `push: branches: [main]` runs twice per change: once
on the PR, once on the merge commit, against a tree identical to the PR head
that already passed. The two runs use different concurrency keys, so
`cancel-in-progress` does not collapse them. Both are green. The only symptom is
the bill and a README that no longer describes what the workflows do.

**Where.**

- this repo: `ci/linter/workflow_policy.py:460` — `COMMANDS` is
  `{runners, ports, docs}`; there is no cadence check. No `lint-ci-cadence.sh`
  in `ci/linter/`.
- target: `ci/linter/lint-ci-cadence.sh` (42 lines) plus a `cadence` subcommand
  in its `workflow_policy.py`.

**What it cost.** Not on this run. On the target it cost 5 stray post-merge runs
before it was caught in review on their PR #101 (2026-08-04); six of their seven
PR members carried the trigger, and `asan.yml` was correct only because it
happened not to have been copied from one of the others.

**Proposed change.** Add a `cadence` subcommand asserting that a
`workflow_call` member has neither `push:` nor a second `pull_request:` entry
point, with `schedule` explicitly allowed.

**Why a decision, not a fix.** The rule as the target writes it assumes the
single-orchestrator topology this skeleton mandates, so it is safe here — but it
would fire on any adopted module that deliberately keeps a member on `push:` for
a branch this repo has no opinion about. Whether the skeleton wants to make that
shape unrepresentable, or merely warn, is the decision.

## 3. `ci/fuzz/fuzz.dict` is hand-maintained with no drift gate

**What.** The dictionary is a tracked artifact edited by hand, and nothing ties
it to the strings the fuzz target actually looks for. It goes stale silently:
adding a signature to the scanned set and forgetting the dictionary costs
nothing visible, because a dictionary that is merely incomplete still produces a
green fuzz run.

**Where.**

- this repo: `ci/fuzz/fuzz.dict`, no generator, no checker
- target: `ci/tools/gen-fuzz-dict.py` extracts every signature literal from the
  pattern table; `ci/linter/lint-fuzz-dict.sh` runs `--check` and is picked up
  by `run-all.sh`'s glob with no registration step. 31 hand-written tokens
  became 652 derived.

**What it cost.** Nothing here. Worth recording from the target's run: deriving
the dictionary did **not** move edge coverage (`cov: 199` on both arms), and
that is the correct result rather than a disappointing one — their scan engine
is an Aho-Corasick trie walk, so the same edges execute whichever literal
arrives. What it bought was signature *reach*: 23 → 35 of 645 distinct table
literals actually driven through the differential oracle in 60s from an empty
corpus. An adopter who ports this and then judges it by edge coverage will
conclude it did nothing.

**Proposed change.** None proposed for this repo directly. The skeleton's
dictionary is small and its patterns are illustrative, so a generator here would
be scaffolding for a table that does not exist yet.

**Why it is here anyway.** The *instruction* is the gap, not the file.
`PROMPT.md` step 27 tells an adopter to "use target tokens in the dictionary"
and step 41 to "rederive corpus and dictionary", neither of which suggests
deriving it mechanically from the source of truth or gating the drift. A module
whose signatures live in a compiled table can generate it, and the prompt is
where that would reach an adopter. Consider a sentence in step 27 to the effect
that a dictionary derivable from a table in the target should be generated and
drift-gated rather than hand-listed — and, if it is worth the words, that edge
coverage is the wrong measure of whether it worked.
