# Contributing

Thank you for contributing — genuinely. Small modules like this live or die
on people who show up with a patch, a bug report, or an awkward question.
You are welcome here.

That said: this document is not decoration. Every rule below exists because
someone (usually us) broke something in a way that took a weekend to clean
up. Read it once before your first PR and you will save us both a round
trip. Break the rules and CI will catch you anyway — the robots are
patient, but they do not negotiate.

If anything here is unclear, **ask**. Asking early is a sign you're doing it
right, not that you're slow. Open an issue, open a draft PR, or mail
**github@myguard.nl**. We answer, and we mentor — everyone who works on
this code started by not knowing nginx internals either.

This repo is a **template** — the skeleton other modules in the org are
cloned from (see `ci/tools/rename-module.sh`). If you're improving the skeleton
itself, keep changes generic: anything specific to one module's logic
belongs in that module's own fork, not here.

## TL;DR checklist

- [ ] One feature or fix per PR — no stacked PRs, no drive-by refactors.
- [ ] Code follows nginx style and matches the code around it.
- [ ] Every new feature or bugfix ships a test in the same PR.
- [ ] README updated in the same PR if behaviour changed.
- [ ] All CI checks green. No skipping, no "it works on my machine".
- [ ] Commit messages: imperative subject, body explains *why*.
      No AI co-author trailers.

## How CI works here

Every push and every PR runs six short gates (one, A/UBSan, is path-gated to
code changes). They exist to catch the classes of bugs that C code in a web
server cannot afford:

- **Build & Test** (`build-test.yml`) — shellcheck/cppcheck/actionlint,
  builds the module against current nginx, asserts the `.so` actually
  dlopens and a bad config is rejected, `-Werror` strict compile, then
  Test::Nginx under **ASan/UBSan**. AddressSanitizer and
  UndefinedBehaviorSanitizer are compiler instrumentation that make memory
  bugs (use-after-free, buffer overflows, signed overflow) crash loudly at
  the exact line instead of corrupting memory silently. If ASan complains,
  the bug is real — fix it, don't suppress it.
- **A/UBSan** (`asan.yml`) — a dedicated 60-second ASan/UBSan request-storm
  soak against a static `--add-module` build (path-gated to `src/` and the
  build/soak harness, so docs-only PRs skip it). Complements Build & Test's
  ASan run of the test suite: this one drives sustained concurrent traffic.
- **Security scanners** (`security-scanners.yml`) — flawfinder, clang-tidy
  (`cert-*`, `clang-analyzer-security.*`) and semgrep over the module
  sources. Static analysis: it reads the code without running it and
  flags dangerous patterns.
- **Fuzzing** (`fuzzing.yml`) — replays every past crash regression, then a
  ~120-second libFuzzer run over the module's input parsers. Fuzzing feeds
  a parser millions of mutated inputs and watches for crashes. Short on
  PRs so feedback stays fast.
- **Valgrind** (`valgrind.yml`) — a 60-second Memcheck soak. Valgrind
  executes the code in an emulated CPU and reports every invalid
  read/write and every leaked byte. Catches a use-after-free of a pool's
  underlying malloc'd block after the pool is destroyed; it does NOT see a
  logical use-after-free of one sub-allocation inside a still-live pool
  block without Valgrind mempool client-request annotations, which this
  module does not add — see the README's "Traps baked in" for detail.
- **CodeQL** (`codeql.yml`) — builds the module translation unit only (not
  the full nginx core CodeQL would otherwise flood with upstream alerts)
  and runs GitHub's semantic analysis over it.

The expensive versions of these — a 4-hour fuzz run, a 600-second Memcheck
**and** Helgrind (thread-race detection) soak — run monthly and on manual
dispatch in `ci-deep.yml`, not on your PR.

Your PR merges when **all** checks are green. If a gate fails and you
believe the gate is wrong, say so in the PR — with evidence, not vibes.
The [README's "Traps baked in"](README.md#traps-baked-in) section documents
every non-obvious CI gotcha already discovered here — read it before
touching `.github/workflows/` or `ci/tools/ci-build.sh`.

## Coding conventions

- **nginx style.** This is an nginx module: follow the
  [nginx style guide](https://nginx.org/en/docs/dev/development_guide.html#code_style)
  — 4-space indents, `ngx_` types (`ngx_int_t`, `ngx_str_t`, …), K&R-ish
  bracing as used by nginx core, `/* comments */`.
- **Match the surrounding code.** When in doubt, the file you are editing
  is the style guide. A patch that reads like the code around it is a
  patch we can review quickly.
- **The one structural rule:** decision logic goes in `*_scan.c`, taking
  `(u_char *, size_t)` — no `ngx_http_request_t` in that file. Only nginx
  plumbing (conf, phases, body read, handler) stays in `*_module.c`. That
  split is why `ci/fuzz/fuzz_scan.c` can link and drive the *real* code path
  instead of a reimplementation that quietly drifts from production.
- **Memory comes from pools.** Allocate from the request/config pool
  (`ngx_palloc`) unless you have a documented reason not to. If you
  `malloc`, you own the cleanup handler.
- **Handle every error path.** nginx runs for months; "can't happen"
  happens. Check return values, log with `ngx_log_error`, fail closed.
- **Comments explain *why*, not *what*.** A surprising nginx-internals
  fact, a footgun, a rejected alternative — write it down at the call
  site or in the README. No undocumented behaviour ships.

## Tests

Every function and every feature gets a test **in the same PR** that adds
it. Not a follow-up PR. Not "later". Same PR.

- New parser or handler → a `ci/t/*.t` Test::Nginx test exercising it,
  including the ugly inputs (empty, oversized, malformed, truncated).
- Bug fix → a regression test that **fails before the fix and passes
  after**. That's the proof the test actually tests something.
- New match rule → a false-positive negative in `ci/t/03-fp-negative.t`, in the
  same commit. A rule with no negative is one nobody has proved is safe to
  ship.
- New input parser → a libFuzzer target in `ci/fuzz/`.

Look at the existing tests in `ci/t/` and put yours next to them. A PR that
adds code without a test will not be merged, and yes, we check.

## Pull requests

- **One feature or issue per PR.** The title says what it does. If a PR
  grows a second concern, split it.
- **No stacked PRs.** Every PR branches from and targets the default
  branch independently. Stacks fall over the moment PR #1 gets review
  changes, and untangling them costs more than the stacking saved.
- **Open an issue first** for anything non-trivial; the PR references it
  (`Closes #N`).
- **Keep it reviewable in one sitting.** Small PRs merge fast; 2000-line
  PRs grow moss while we find an afternoon to do them justice.
- **Update the README in the same PR** when behaviour, directives, or
  defaults change. The README must never lag the default branch.
- The default branch is protected by convention: changes land via PR with
  green CI, not direct push.

## Commits

- Imperative subject line ("add X", "fix Y"), ≤ 72 chars.
- Body explains *why* — the design choice made and what was rejected.
- No AI co-author trailers. None.

## Ask for help

Stuck on nginx internals? Not sure where a test belongs? Fuzzer output
looks like hieroglyphics? Ask. Open a draft PR with what you have and say
what you're unsure about — a draft PR full of questions is a perfectly
good contribution. We would much rather spend ten minutes pointing you in
the right direction than review a week of effort aimed at the wrong wall.

## Contact

Questions, security reports, or anything that doesn't fit an issue:
**github@myguard.nl**
