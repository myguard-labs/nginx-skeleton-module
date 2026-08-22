# nginx-zstd-module adoption feedback (2026-08-22)

Four findings that need a decision or hardware this adopter does not have. The
other five from this adoption were fixed in code in the same PR: the
`install-linters.sh --check` fail-open, step 6's reference-only checkers, step
15's unobservable barrier B, and the two context-orphaning traps in steps 16 and
20 (plus `ci/tools/remap-checks.py` as the remedy for both).

## 1. Rule 2 has no route for a gate the ADOPTER has and the reference does not

- **What:** rule 2 asks the installer to be retargeted to the *target's* checker
  set, and step 6 makes `--check` list "every tool the finished set needs,
  including tools the reference has never heard of". In practice the adopter's
  `.pre-commit-config.yaml` gated on **gitleaks** (staged secret scan) and
  **ast-grep** (a vendored structural ruleset), neither in the reference's
  `APT_TOOLS`/`PIPX_TOOLS`/`--check`. The ported installer therefore neither
  installed nor reported them, and the hook exits non-zero on a fresh clone for
  a reason `--check` calls clean.
- **Where:** `ci/linter/install-linters.sh` `APT_TOOLS`/`PIPX_TOOLS` and its
  `--check` roster; the adopter's `.pre-commit-config.yaml`.
- **Cost:** a fresh-clone hook failure that `--check` reported as healthy. Caught
  while porting rather than by a CI round-trip, which is luck, not a gate.
- **Not a request to restore ast-grep.** `a90ea3a` (2026-08-13) removed it
  deliberately and the reasoning still holds — the promoted rules duplicate
  flawfinder/cppcheck/semgrep/clang-tidy/CodeQL over the same `src/`, and the
  refresh tool lives in the superrepo where a template user cannot reach it. It
  is cited here only as one instance of the shape.
- **Proposed change:** the gap is that adopter-only tools have nowhere to live.
  Give `install-linters.sh` a documented seam — an optional
  `ci/linter/install-linters.local.sh`, sourced when present, that can extend
  `APT_TOOLS`/`PIPX_TOOLS` and the `--check` roster — so an adopter satisfies
  step 6's acceptance without editing a skeleton-shared file that the next
  forwarding pass overwrites. A decision because it adds a supported extension
  point to a file every derived module inherits.
- **Trap worth carrying if any adopter installs ast-grep locally:** its release
  zip ships both `ast-grep` and an `sg` alias. **Debian already owns
  `/usr/bin/sg`** (shadow's setgid tool), so only the long name may go to
  `/usr/local/bin` — installing `sg` shadows a system binary on PATH order
  alone.

## 2. `ci-deep.yml`'s `scanners` job has the same two defects step 27 fixes in `security-scanners.yml`

- **What:** step 27 had this adopter re-diff `security-scanners.yml` against
  `ci/linter/lint-c.sh`, which surfaced two gates that were **green by
  construction**: flawfinder ran with no `--error-level` (findings printed, exit
  0 regardless of severity — `--minlevel` alone only controls what is PRINTED),
  and semgrep ran with no `--severity` gate behind `|| true`. `ci-deep.yml`'s own
  `scanners` job carries the identical `--minlevel=1` / `|| true` pattern and was
  outside step 27's slice.
- **Where:** `ci-deep.yml`, the `scanners` job. The adopter's fixed counterpart
  is its `security-scanners.yml`, now mirroring `lint-c.sh`'s five flags exactly.
- **Cost:** none yet — it is the monthly campaign, so nobody watches its exit
  code. That is precisely why it can stay broken indefinitely.
- **Proposed change:** either point step 27 at both files, or give `ci-deep.yml`
  the same threshold-mirroring requirement. A decision because the monthly lane's
  intended failure semantics are a judgement call: a campaign job that starts
  failing on pre-existing findings is a different policy from a PR gate.
- **Verified in the target with a planted `strcpy`:** the gate exits 1 where it
  previously exited 0. Note `set -o pipefail` on that step is load-bearing —
  `| tee flawfinder.log` otherwise swallows the status.

## 3. Step 29's lane budget understates real oversubscription, and the cross-workflow half has no fix within the step

- **What:** step 29 asks for a lane map against the pool's slot count. Measured
  here (run 32540884342): `build-test.yml`'s internal `needs:` graph fans out to
  7 self-hosted jobs right after `resolve` — already 1 over this pool's 6 real
  slots on its own. The larger problem is that `ci.yml`'s other self-hosted
  members (codeql, security-scanners, fuzzing, valgrind, asan) have **no
  `needs:` relationship to `build-test.yml` at all** and start at the same t=0,
  because **GitHub Actions has no job-level `needs:` that crosses a
  reusable-workflow-call boundary**. Real peak was **11 self-hosted jobs against
  6 slots at t=7s**, sustained for most of each job's 70-250s runtime — not the
  brief startup blip rule 4 tolerates, and worse than the reference's own
  documented "peak 7 against 6".
- **Where:** step 29 rule 4 and its lane-map acceptance; `ci.yml`'s member jobs.
- **Cost:** every PR pays queueing that the lane map claims was designed out. The
  map reads as satisfied while the property it asserts is false.
- **What is NOT a fix:** wiring `codeql: needs: build-test` at the `ci.yml` level.
  `needs:` on a `uses:` job blocks on that member's **entire** called workflow
  finishing, so it serializes codeql behind build-test's full 321s critical path
  instead of laning it — worse than the oversubscription it fixes.
- **Proposed change:** step 29 should state the call-boundary limitation
  explicitly, and require the lane map to report peak concurrency **across all
  `ci.yml` members**, not per-workflow. The two real remedies — fold the
  single-job members into `build-test.yml`'s job graph so `needs:` lanes can span
  them, or add pool slots — are both beyond a bounded lane-map item and cross
  every derived module.
- **Landed here as a partial:** `build-old-libzstd` now runs
  `needs: [resolve, validation]` with `if: ${{ !cancelled() }}`, taking
  validation's slot at t=149s and dropping `build-test.yml`'s own peak from 7 to
  6, under the 321s budget.

## 4. `valgrind.supp` ships as the generic circulated nginx file, and can mask the adopter's own errors

- **What:** step 30 asks whether `valgrind.supp` "names the target's own
  suppressions and does not suppress its errors". The shipped file cannot pass
  that test for anyone: all 28 blocks are unfilled
  `<insert_a_suppression_name_here>` placeholders, and they reference
  `ngx_http_lua_*` and `drizzle_state_connect` — symbols an adopting module will
  typically never link. A copied suppression file is not inert; it can silently
  mask the module's **own** memcheck errors.
- **Where:** `valgrind.supp` in the reference, inherited verbatim by the adopter.
- **Cost:** step 30's memcheck answer cannot be given honestly from
  configuration, which is all phase 6 is allowed to read. Deriving a real
  suppression file needs a genuine memcheck soak — phase 7 work, and explicitly
  outside routine scheduling.
- **Proposed change:** decide what the skeleton should ship. Either an **empty**
  `valgrind.supp` with a comment saying suppressions are derived per-module from
  a real soak (safe default — suppresses nothing, hides nothing), or a documented
  derivation step in phase 7 that generates one with `--gen-suppressions=all` and
  requires each block to be named and justified. Shipping the generic file is the
  one option that should not survive, because it looks configured while being
  both useless and actively unsafe. Blast radius crosses every derived module,
  which is why it is here rather than fixed in this PR.
