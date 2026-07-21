# nginx-skeleton-module

[![Build&Test](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/build-test.yml/badge.svg)](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/build-test.yml)
[![Security Scanners](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/security-scanners.yml/badge.svg)](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/security-scanners.yml)
[![Fuzzing](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/fuzzing.yml/badge.svg)](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/fuzzing.yml)
[![Valgrind](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/valgrind.yml/badge.svg)](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/valgrind.yml)
[![CodeQL](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/codeql.yml/badge.svg)](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/codeql.yml)
[![A/UBSan](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/asan.yml/badge.svg)](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/asan.yml)
[![CI Deep](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/ci-deep.yml/badge.svg)](https://github.com/myguard-labs/nginx-skeleton-module/actions/workflows/ci-deep.yml)

Skeleton from [deb.myguard.nl](https://deb.myguard.nl). Free to use. As shipped
it does nothing but burn CI minutes — clone it, rename it, and replace the scan
logic with your own before it's useful for anything.

It's a working nginx dynamic HTTP module plus the CI harness that the modules
in this org converged on — the build, the tests, the fuzzer and eight workflows
are already wired.

The point of the skeleton is not the ~350 lines of C. It is that the *gates* are
already correct: the traps below took several modules and several red-herring CI
reds to discover, and they are baked in here so the next module starts past them.

See [CHANGES](CHANGES) for what shipped in this skeleton over time. Tag a release
(`vN`) when the scan/module API changes in a way a cloned-and-renamed downstream
module would need to know about — not on every commit.

## Use it

```bash
git clone git@github.com:myguard-labs/nginx-skeleton-module.git nginx-foo-module
cd nginx-foo-module
rm -rf .git && git init

ci/tools/rename-module.sh foo      # skel -> foo everywhere, then delete the script

bash ci/tools/ci-build.sh nginx 1.31.2
TEST_NGINX_TIMEOUT=20 prove -v ci/t/
```

Then replace the rule table in `src/ngx_http_foo_scan.c` with whatever the
module actually does, and keep `ci/t/03-fp-negative.t` honest as you go.

## What's here

```text
config                     nginx addon config (both .c files + the header dep)
src/
  ngx_http_skel_module.c   nginx plumbing: conf, phases, body read, handler
  ngx_http_skel_scan.{c,h} the DECISION LOGIC — no nginx request state
ci/                        everything that only exists to test/build the module
  t/                       Test::Nginx: modes, scan, false-positive negatives
  fuzz/                    libFuzzer target + dict + seed corpus + regressions/
  vendor/nginx-tests/      upstream nginx/nginx-tests submodule (lib/Test/Nginx.pm)
  tools/
    ci-build.sh            build nginx|angie × debug|asan|module
    soak.sh                sustained matching/benign storm under valgrind/ASan
    valgrind.supp          nginx-core-only suppressions
    rename-module.sh       skel -> your name (delete after use)
.github/workflows/         eight workflows, see below
```

`ci/t/` uses the same `Test::Nginx::Socket` framework as upstream nginx's own
[nginx-tests](https://github.com/nginx/nginx-tests) suite (vendored read-only
as a submodule at `ci/vendor/nginx-tests/` — `git submodule update --init` after
clone). If you've debugged upstream nginx tests before, the same env vars work
here: `TEST_NGINX_VERBOSE=1` for verbose Test::Nginx output, `TEST_NGINX_LEAVE=1`
to keep the temp server root around after a failing test for inspection.

### The one structural rule

**Decision logic goes in `*_scan.c`, taking `(u_char *, size_t)`. Only
`ngx_http_request_t` plumbing stays in `*_module.c`.**

That split is why `ci/fuzz/fuzz_scan.c` can link and drive the *real* code path
rather than a reimplementation of it. A fuzzer that tests a copy of the parser
tests nothing; it just drifts from production quietly and reports green.

## CI

Eight workflows. A failure surfaces as a red run plus the uploaded artifact — no
chat notifications wired.

| Workflow | Trigger | Gates |
|---|---|---|
| `build-test.yml` | PR + push | shellcheck/cppcheck/actionlint, build, **.so dlopens**, **bad config is rejected**, **`-T` survives merged multi-context config**, `-Werror` strict compile, Test::Nginx, ASan+UBSan, **rename smoke** |
| `asan.yml` | PR + push (path-gated: `src/` + build/soak harness) | 60s ASan/UBSan request-storm soak (static `--add-module`) |
| `fuzzing.yml` | PR + push | replay every past crash, then 120s fresh fuzz |
| `valgrind.yml` | PR + push | 60s memcheck soak |
| `security-scanners.yml` | PR + push | flawfinder (≥4 blocks), clang-tidy (blocks), semgrep (advisory) |
| `codeql.yml` | PR + push + monthly | CodeQL, **module TU only** |
| `ci-deep.yml` | monthly + dispatch | 4h fuzz, 600s memcheck, 600s helgrind, **nginx mainline+stable+angie build & test matrix** |
| `bump.yml` | weekly + dispatch | checks nginx.org/angie.software for newer pins, updates `ci/vendor/nginx-tests` submodule, commits+pushes to main if anything moved |

PR-time jobs are the fast half; the slow half is deliberately out-of-band so the
merge path stays quick. That split is the whole design.

### Caching

Every build goes through `ci/tools/ci-build.sh`, which is the single chokepoint
where caching lives — so all eight workflows inherit it and none of them duplicate
cache logic. `.github/actions/build-cache` is the composite action that restores
the caches for one mode.

Four layers, cheapest first:

| Layer | What it saves | Keyed on |
|---|---|---|
| **ccache** | recompilation | content (`CCACHE_COMPILERCHECK=content`) |
| **mold** | link time | — (used when present; skipped under ASan) |
| **build tree** (`.build/nginx-<ver>-<mode>`) | `./configure` | mode + version + `hashFiles(ci-build.sh, config, src/**)` |
| **source tarball** | the download | version |

ccache tolerates a `restore-keys` fallback ladder (content-hashed, so a partial
hit can never serve a wrong object). The build-tree cache deliberately does not —
exact-match only, see `.github/actions/build-cache/action.yml` — don't "fix" that
for consistency, it's intentional.

On the skeleton itself the win is small and honestly stated: a cold build is ~7s
(≈5s of *serial* `configure`, ≈2s of compile across 127 objects on 32 cores), and
a warm one is ~0s. **Caching is not why the PR gate is fast** — the gate is
already ~2.5 min wall-clock, and its two slowest jobs are *time-boxed by design*
(120s fuzz, 60s memcheck soak), so no cache can shorten them by a second.

It is here because this is a **template**. A real module's scan core is far
heavier than the skeleton's, and the layer that costs nothing today is the one
that pays as soon as you drop real code into `src/`. Note which cache does the
work: on this codebase `configure` dominates compilation, and ccache *cannot*
touch `configure` — the build-tree cache is what actually matters.

`NO_CACHE=1 bash ci/tools/ci-build.sh …` forces a from-scratch build (release
verification) without editing anything.

Runners are **persistent** incus containers today, so the on-disk caches are
already warm and `actions/cache` is close to a no-op. It is wired anyway, as the
fallback for hosted runners (`codeql.yml` uses `ubuntu-latest`) and for the day
the [ephemeral conversion](https://github.com/myguard-labs) lands. Deleting it
"because the runners are persistent" is how this silently degrades to a cold
build per job.

### Traps baked in

Each of these is a bug that shipped, or a red that wasted a session, in a real
module here. Change them only on purpose.

**`TEST_NGINX_TIMEOUT: "20"`** — Test::Nginx's client read timeout defaults to
~2s. On the shared `builder02` LXC a live request under normal build-host load
routinely takes longer, and the suite then fails as a *contiguous sweep of
`client socket timed out` with zero assertion failures*. That shape means the
harness, not the module. Export it locally too, or clean tests "fail".

**ASan mode is a static build** (`--add-module`, not `--add-dynamic-module`). A
sanitizer runtime has to be linked into the executable. A `.so` loaded by a plain
nginx has no ASan runtime, and the job passes while checking nothing.

**A cached build tree can silently disarm the sanitizer job — one tree per
mode, and no `restore-keys` on it.** `debug`, `asan` and `module` compile the
same sources with *incompatible* flags. They used to share one `.build/nginx-<ver>`
tree and got away with it only because `./configure` re-ran unconditionally every
time — i.e. correctness was an accident of *not* caching. Cache that tree and the
accident becomes a bug: a restored debug `objs/` in the ASan job links
non-instrumented objects, the tests still pass (tests pass on an uninstrumented
binary too), and you get a **green sanitizer job that verified nothing** — strictly
worse than a slow build. Hence: mode is in the tree path *and* in the cache key,
the build-tree cache is **exact-match only** (a prefix match could hand you a tree
built from other flags; worst case must be a cold build, never a wrong one), and
`build-test.yml` asserts with `nm` that the ASan/UBSan runtimes are actually linked
into the binary under test. That assert is the only thing that fails *loudly* when
the plumbing lies — do not delete it, and do not add `restore-keys` to the tree
cache to "improve the hit rate".

**ccache must be wired via `--with-cc`, not `CC=`.** nginx's `configure` ignores a
bare `CC=` env var, so the usual `CC="ccache cc"` incantation silently does
nothing and you get a cache that never records a single hit — all of the
complexity, none of the benefit.

**A cache miss on a PR is usually not a bug — GitHub scopes caches by ref.** A PR
run reads/writes `refs/pull/N/merge`; a branch run uses `refs/heads/<branch>`.
Neither can see the other, and only caches on the **default branch** are inherited
by every ref. So the *first* run of a new PR always misses (correct and expected),
and comparing a PR run against a branch-dispatch run compares two different scopes
and shows a phantom miss. Confirmed here: two runs with a byte-identical
`buildtree` key missed each other purely because of ref scope; re-running on the
same ref hit and the build step went **8s → 0s**. Check the ref before you
"fix" the key.

**CodeQL builds `module` mode only.** For compiled languages CodeQL builds its DB
from what the traced build *compiles* — `paths-ignore` is silently ignored.
Tracing a full nginx build floods the Security tab with alerts against upstream
code. `make modules` alone keeps the DB to our translation unit.

**Valgrind/Memcheck is not redundant with ASan, but it doesn't see INTO pools
either without help.** nginx hand-suballocates from pools; Memcheck sits under
malloc/mmap and tracks the underlying block, so it catches a use-after-free of
the pool's own backing allocation (freed after `ngx_destroy_pool()`). A logical
use-after-free of one sub-allocation *within* a still-live pool block is a
different case: the backing malloc'd block is still addressable, so Memcheck
has nothing to flag unless the code emits Valgrind client-request annotations
describing the pool sub-allocations (`VALGRIND_MEMPOOL_ALLOC`/`_FREE`), which
this module does not do. Treat Memcheck here as covering pool-lifetime bugs,
not sub-allocation-lifetime bugs inside a live pool.

**Helgrind here validates "no crash under a race detector," not multi-worker
correctness.** `soak.sh --tool=helgrind` runs nginx with a single worker
(`master_process off`), and HTTP request concurrency inside one worker's event
loop does not create OS threads — Helgrind has no second thread to race
against. It stays wired in (`ci-deep.yml`) so that the day this module gains
real shared state (a shm zone, a counter, a cache) across actual threads or
workers, the gate is already in place; until then, expect it to report
"no errors" by construction, not as proof of thread-safety.

**The soak asserts both branches ran.** `soak.sh` fails unless it observed ≥1
block *and* ≥1 pass. A soak that only checks "didn't crash" keeps passing after
the module stops being reached at all — which is how a gate rots into a no-op.

**Handlers run at PRECONTENT, so tests need `empty_gif`.** `return 200` finalizes
in REWRITE, *before* PRECONTENT — the handler never runs and every test passes
vacuously.

**Never suppress a valgrind stack through your own code.** `ci/tools/valgrind.supp`
is nginx-core noise only. A suppression over module frames turns the gate green
permanently.

## Requirements

Build: `build-essential curl libpcre2-dev zlib1g-dev`
Tests: `cpanminus` + `cpanm Test::Nginx`
Fuzz: `clang` (needs `-fsanitize=fuzzer`)
Soak: `valgrind`

## Contributing

Bugs, feature requests, PRs: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

BSD-2-Clause (same terms as nginx and Angie) — see [LICENSE](LICENSE).

Vendored third-party code keeps its own license: `ci/vendor/nginx-tests/` is the
upstream nginx test suite, BSD-2-Clause (Copyright (C) 2008-2011 Maxim Dounin,
Copyright (C) Nginx, Inc.).
