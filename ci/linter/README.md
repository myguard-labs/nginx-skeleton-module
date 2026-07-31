# ci/linter — local lint gate

Mirrors the cheap half of remote CI so a push does not burn a round-trip on a
finding shellcheck could have named in two seconds. Every script is standalone;
`run-all.sh` runs them all and `.githooks/pre-commit` runs `run-all.sh --staged`.

## Layout

| Script | Covers | Gate |
|---|---|---|
| `lint-c.sh` | `src/*.[ch]` | flawfinder ≥4, cppcheck (warning/performance/portability), semgrep ≥WARNING (`p/c`, `p/security-audit`) |
| `lint-nginx.sh` | `src/*.[ch]` | nginx conventions: libc alloc/str/num/io instead of `ngx_*`, hard tabs, >80 columns, trailing whitespace, `ngx_config.h` include order |
| `lint-sh.sh` | `*.sh`, `*.bash`, `.githooks/*` | shellcheck `-S warning` |
| `lint-python.sh` | `*.py` | `ruff check` + `ruff format --check` |
| `lint-perl.sh` | `ci/t/*.t`, `*.pl`, `*.pm` | `perl -c` + perlcritic severity ≥4 |
| `lint-yaml.sh` | `*.yml`, `*.yaml` | yamllint (errors block, warnings visible), actionlint + zizmor (`--persona=pedantic`) on `.github/workflows/` |
| `run-all.sh` | all of the above | runs every check, reports once |
| `install-linters.sh` | — | apt-get → pipx → cpan → upstream binary |
| `lib.sh` | — | sourced helpers (file selection, missing-tool failure) |

Rule config lives at the repo root so editors and these scripts agree:
`.yamllint` (workflow-shaped YAML), `.perlcriticrc` (Test::Nginx-shaped Perl).
Both carry the reason for every relaxation; read them before adding another.

Thresholds deliberately match `.github/workflows/security-scanners.yml`. Move
one there and move it here **in the same commit**, or local-green stops
predicting remote-green — the only reason this directory exists.

`clang-tidy` is **CI-only**: it needs `ngx_auto_config.h`, which exists only in
a configured nginx tree. A hook cannot assume one, and a check that skips
itself when the tree is missing is a vacuous gate.

## 1. Install the linters

```sh
ci/linter/install-linters.sh          # install what is missing
ci/linter/install-linters.sh --check  # report only
```

Preference order, and why each tool lands where it does:

**apt-get (preferred — distro-managed, no PEP 668 fight)**

```sh
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    shellcheck cppcheck flawfinder yamllint clang-tidy \
    libperl-critic-perl perl pipx cpanminus
```

**pip / pipx (Python tools Debian does not carry at the needed version)**

Use `pipx`, not `pip3`: Debian 12+ marks the system interpreter
externally-managed, so a bare `pip3 install` fails and
`--break-system-packages` is a worse answer than a venv per tool.

```sh
pipx install ruff
pipx install 'semgrep==1.169.0'     # pinned to the CI version on purpose
```

`semgrep` is pinned because an unpinned upgrade changes findings under you and
local stops matching CI. Bump it here and in `security-scanners.yml` together.

**cpan (Perl modules apt does not carry on every target release)**

```sh
sudo cpanm --notest Test::Nginx::Socket   # also what makes `perl -c` work on ci/t/*.t
sudo cpanm --notest Perl::Critic          # only if libperl-critic-perl was unavailable
```

`--notest`: Test::Nginx's own suite wants a live nginx and a free port, which
an install step has no business demanding.

```sh
pipx install zizmor                 # GitHub Actions security audit
```

`zizmor` is deliberately **not** pinned, unlike semgrep: its rule set is the
whole point, and a frozen security scanner stops finding what it was added for.
A new rule going red is a finding to triage, not drift to suppress.

**upstream binary (no apt/pip/cpan source)**

```sh
ver=1.7.7
sha=023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757
curl -fsSL -o actionlint.tgz \
  "https://github.com/rhysd/actionlint/releases/download/v${ver}/actionlint_${ver}_linux_amd64.tar.gz"
echo "$sha  actionlint.tgz" | sha256sum -c -   # must pass before the next line
tar -xzf actionlint.tgz actionlint && sudo install -m0755 actionlint /usr/local/bin/
```

Do not pipe the tarball straight into `tar`: that installs whatever the network
returned. The digest is from the release's `actionlint_${ver}_checksums.txt` and
is pinned beside the version in `install-linters.sh` too — bump both together.

Make sure `~/.local/bin` is on `PATH` for the pipx-installed tools.

## 2. Enable the pre-commit hook

The hook is tracked at `.githooks/pre-commit` so a change to the gate arrives
as a reviewable diff. Git does not use it until you point `core.hooksPath` at
the directory — once per clone:

```sh
git config core.hooksPath .githooks
```

Verify it is live:

```sh
git config --get core.hooksPath     # -> .githooks
```

Bypass in an emergency with `git commit --no-verify`.

**This replaces the `pre-commit` framework hook.** `core.hooksPath` makes git
ignore `.git/hooks/` entirely, including the hook `pre-commit install` writes
there. The repo's `.pre-commit-config.yaml` still exists and covers overlapping
ground (whitespace fixers, private-key detection, flawfinder, semgrep,
shellcheck, actionlint). Pick one:

- `git config core.hooksPath .githooks` — this directory: also covers Perl,
  Python and the nginx conventions, no Python framework needed.
- `pipx install pre-commit && pre-commit install` — the framework: also runs
  the whitespace/EOF fixers and `detect-private-key`, but not `lint-nginx.sh`
  or `lint-perl.sh`. Then leave `core.hooksPath` unset.

Running both means running flawfinder and semgrep twice per commit.

## 3. Use it

```sh
ci/linter/run-all.sh                 # every tracked file
ci/linter/run-all.sh --staged        # what the hook runs
ci/linter/run-all.sh src/foo.c       # named files
LINT_ONLY="c nginx" ci/linter/run-all.sh
LINT_SKIP_SEMGREP=1 ci/linter/run-all.sh   # loud opt-out of the slowest pass
LINT_JOBS=1 ci/linter/run-all.sh           # serial, for bisecting a hang
ci/linter/run-all.sh --list
```

Exit codes: `0` clean, `1` findings, `2` a linter is missing.

### Speed, and why it is shaped this way

Measured 2026-07-31 on builder02 (i9-14900HX, 32 threads) with **no CI job
running** — see the caveat below before comparing against your own numbers:

| | before | after |
|---|---|---|
| full tree | 3.8s | **1.45s** |
| one C file | 2.9s | **1.31s** |
| full tree, `LINT_JOBS=1` | 3.2s | 2.57s |

Re-measure on an idle box or not at all. This host also runs six self-hosted CI
runner slots, and at load average ~50 the same full-tree run took 2.2s to 12.4s
across six back-to-back attempts — the run-to-run spread is wider than the
entire improvement, so a busy-box A/B measures the neighbours, not the change.
Check `/proc/loadavg` first.

Two changes, only one of which is really about speed:

- **`semgrep --metrics=off`.** The end-of-scan POST to semgrep.dev was 2.76s of
  a 2.76s scan; without it the same scan is 1.27s. More than half the hook's
  wall clock was telemetry.
- **`semgrep --jobs=1`.** A *correctness* fix. semgrep-core defaults to one
  OCaml domain per core and each domain opens its own io_uring ring against
  this host's 8 MB `RLIMIT_MEMLOCK`, which is shared with the self-hosted CI
  runners. When the runners are busy it exhausts and semgrep-core aborts with
  `Unix_error: Cannot allocate memory io_uring_queue_init`, exit 2 — a red
  commit gate caused by neighbouring load, not by the diff. Reproduced 3/3 on a
  busy box, 0/3 on an idle one. `src/` is three files, so nothing was gained by
  the parallelism in the first place. `security-scanners.yml` carries the same
  two flags; they run on the same host and must stay in sync.
- **`run-all.sh` fans the checkers out** (`LINT_JOBS`, default one slot per
  checker). Each checker's output is buffered and replayed whole in glob order,
  never streamed: findings carry a `file:line` but not a checker name, so
  interleaved output is unattributable. Fixed order also keeps two runs of the
  same dirty tree byte-comparable.

The floor is now semgrep's own startup. If this creeps back over ~2s, scope
semgrep — do not drop a checker.

Suppress one justified `lint-nginx.sh` finding with a trailing
`/* NOLINT-nginx */` on that line. Whole-rule suppression is deliberately not
supported: the exception belongs next to the code that needs it, where review
can see the reason.

## Verify before trusting

A green gate proves nothing until it has been seen red. Every probe below was
run against this tree and observed failing; re-run them after changing a
threshold.

```sh
# shell: SC2164 + SC2115 -> exit 1
printf '#!/bin/bash\ncd /tmp/x\nrm -rf "${B}/"*\n' > _p.sh
LINT_ONLY=sh ci/linter/run-all.sh _p.sh ; rm _p.sh

# C + nginx conventions: malloc/strcpy -> exit 1 from both lint-c and lint-nginx
printf '#include <ngx_core.h>\nvoid f(void){char*p=malloc(4);strcpy(p,"ab");}\n' > src/_probe.c
LINT_ONLY="c nginx" ci/linter/run-all.sh src/_probe.c ; rm src/_probe.c

# python: unused import -> exit 1
printf 'import os\nx=1\n' > _p.py
LINT_ONLY=python ci/linter/run-all.sh _p.py ; rm _p.py

# perl: string eval + interpolated system() -> exit 1
printf 'my $x = 1;\nsystem("ls $x");\neval "1";\n' > _p.pl
LINT_ONLY=perl ci/linter/run-all.sh _p.pl ; rm _p.pl

# yaml: unterminated flow sequence -> exit 1
printf 'a: [1,\n' > _p.yml
LINT_ONLY=yaml ci/linter/run-all.sh _p.yml ; rm _p.yml

# workflow security: zizmor -> exit 1 on template-injection, artipacked,
# unpinned-uses and excessive-permissions, all from these seven lines
cat > .github/workflows/_probe.yml <<'EOF'
name: probe
on: [pull_request]
jobs:
  p:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "${{ github.event.pull_request.title }}"
EOF
LINT_ONLY=yaml ci/linter/run-all.sh .github/workflows/_probe.yml
rm .github/workflows/_probe.yml

# missing tool -> exit 2, never a silent skip
printf 'x = 1\n' > _p.py
PATH="$(echo "$PATH" | tr : '\n' | grep -v "$HOME/.local/bin" | paste -sd:)" \
    LINT_ONLY=python ci/linter/run-all.sh _p.py ; rm _p.py

# the hook itself blocks the commit
printf '#!/bin/bash\ncd /tmp/x\n' > _bad.sh && git add _bad.sh
git commit -m probe        # -> blocked
git reset -q HEAD _bad.sh && rm _bad.sh
```

Note SC2086 is INFO and correctly does **not** trip `lint-sh.sh`; probe with a
warning-severity finding or you will misread the gate.

### Workflow security (zizmor)

`actionlint` reads a workflow as syntax; `zizmor` reads it as an attack
surface — template injection into `run:`, `pull_request_target`, credentials
persisted by `actions/checkout`, actions pinned to a mutable tag, over-broad
`permissions:`. On a repo with **self-hosted runners** that class of mistake is
arbitrary code execution on the build host, which is why it is a gate and not
advice.

Run at `--persona=pedantic`: the default persona already passes on this tree,
so gating on it could never go red. Pedantic is what caught the `matrix.*`
interpolations in `ci-deep.yml` (now passed through `env:`) and the
undocumented CodeQL permissions.

`--offline`, so a commit hook never needs a token. The online audits only add
repo-settings context; that belongs in a periodic review.

Inapplicable finding → `# zizmor: ignore[rule]` on the line, with the reason.
Never a blanket disable in a `zizmor.yml`.

## In CI

`.github/workflows/lint.yml` runs `install-linters.sh` then
`LINT_ONLY="nginx sh python perl yaml" run-all.sh` — the same entry point as
the hook, so a clone that never enabled `core.hooksPath` still cannot land a
regression. It is wired into the `ci.yml` orchestrator and runs on
`ubuntu-latest`, taking no self-hosted slot.

The `c` checker is left out there because `security-scanners.yml` already runs
flawfinder/clang-tidy/semgrep over `src/` at the same thresholds. That is also
why `lint-c.sh` must be edited in the same commit as that workflow.

## Extending

- New file type: drop a `ci/linter/lint-<name>.sh` in place — `run-all.sh`
  picks it up by glob. Keep "no files of this kind" exiting 0, and fail with
  exit 2 (via `need`) when the tool is absent.
- New nginx convention: one more `rule <name> <ere> <message>` call in
  `lint-nginx.sh`.
- New dependency: add it to `install-linters.sh` **and** to the apt/pip/cpan
  lists above, so a fresh clone is one command from armed.
