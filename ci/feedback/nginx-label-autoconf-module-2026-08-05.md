# nginx-label-autoconf-module — 2026-08-05

Six findings carried from the label-autoconf adoption
(`memory/labs/nginx-label-autoconf-module/HANDOFF-skeleton-adoption.md`, "Carry
into card 51"). Each verified against this repo's *current* source before
acting — two were already fixed here, one never applied as described, and three
were confirmed and are fixed in this PR.

## 1. `concurrency.group` collapse under `workflow_call` (`github.workflow`)

**Verdict: already fixed.** The finding assumed the skeleton had the same bug
the target had before its own fix — a bare
`group: ${{ github.workflow }}-${{ github.ref }}` that collapses every
`workflow_call`-ed member into the caller's group, since `github.workflow`
resolves to the *caller's* name under `workflow_call`, not the member's own.

**Evidence.** Current source already gives every member a unique literal
prefix ahead of `${{ github.workflow }}-${{ github.ref }}`:
`.github/workflows/asan.yml:31`, `build-test.yml:24`, `codeql.yml:35`,
`valgrind.yml:30`, `security-scanners.yml:40`, `lint.yml:28`,
`fuzzing.yml:25`. `build-test.yml:22-24` carries a comment explaining exactly
this hazard and why the prefix defuses it — `github.workflow` is constant
across all members under one `workflow_call` tree, so a unique prefix alone
makes every group string distinct regardless of what `github.workflow`
resolves to. `codeql.yml` sidesteps it differently (`codeql-${{ github.ref }}`,
no `github.workflow` at all). Same effect as the target's fix
(`nginx-label-autoconf-module/.github/workflows/*.yml`, prefixed groups), just
landed here earlier.

**Disposition.** No edit — the described bug is not present.

## 2. Hardcoded `libpcre3-dev`

**Verdict: not applicable — never present as described.** The finding (marked
"likely" in the source handoff, i.e. unverified) claims the skeleton hardcodes
the dead `libpcre3-dev` package name. Grepping every workflow
(`.github/workflows/{asan,fuzzing,valgrind,security-scanners,codeql,ci-deep,build-test}.yml`)
and `README.md:331` shows the opposite: this repo has only ever hardcoded
`libpcre2-dev`, the *current* package name. There is no `libpcre3-dev` string
anywhere in the tree.

**What the target actually has that this repo doesn't.** The target added a
runtime fallback — `"$(apt-cache show libpcre2-dev >/dev/null 2>&1 && echo
libpcre2-dev || echo libpcre3-dev)"` — for portability to distros old enough
that only `libpcre3-dev` exists. That is a real, separate hardening the
skeleton lacks (a hardcoded-newest-name gate has no fallback for an older
runner image), but it is not the bug the finding describes, and adding a
distro-compat fallback to a *reference* skeleton whose CI pins known-current
Ubuntu images is a scope/support-matrix decision, not a bounded fix.

**Disposition.** No edit. Recommend, if the skeleton ever targets
older-than-`libpcre2-dev` runner images, porting the target's fallback
expression verbatim (`apt-cache show libpcre2-dev || echo libpcre3-dev`) —
decision-heavy (support matrix), left for the owner.

## 3. `ci/PROMPT.md` grep recipe hardcodes `ci/tests/unit/run.sh`

**Verdict: confirmed present.** Steps 7, 9 and 39 all grepped the literal path
`ci/tests/unit/run.sh` as *the* unit entry point
(pre-fix: `ci/PROMPT.md:384`, `:440`, `:1195`/`:1210`). The target has no
`ci/tests/unit/` directory at all (`find ci -iname run.sh` in
`nginx-label-autoconf-module` returns only `ci/fuzz/run.sh`) — its unit
coverage lives entirely under `ci/fuzz/` via the extraction-script idiom (see
finding 4). Grepping a path the target never had returns nothing and reads as
"no consumer wires it", which is a false negative on a target whose test layer
was standing all along.

**Disposition.** Fixed in this PR. Step 7 now derives `UNIT_ENTRY` from
whatever step 6's baseline actually proved is the target's real unit entry
point, falling back to the reference's own path only when the target has one
at that location; steps 9 and 39 reuse `$UNIT_ENTRY` instead of the literal.

## 4. No classification for the extraction-script + drift-gated shim idiom

**Verdict: confirmed present.** Step 7's three-state taxonomy (clean / nominal
/ no seam, pre-fix `ci/PROMPT.md:390-398`) had no branch for a target whose
"seam" is a `ci/fuzz/extract_*.sh` that copies the real decision bytes into a
generated `.inc`, cross-checked against a `#define`/checksum so that editing
the source without regenerating the copy fails the build
(`nginx-label-autoconf-module/ci/fuzz/extract_redis_decode.sh`,
`extract_redis_frame.sh`). Absent its own bullet, an adopter following the
taxonomy verbatim would file this as "nominal" (a copy exists, is it really
the same source?) even though the drift gate gives it the same guarantee a
hand-written clean seam gets from having no nginx types in the signature.

**Disposition.** Fixed in this PR. Added a fourth bullet to step 7's taxonomy
classifying the extraction-script + drift-gated shim as CLEAN, with the same
"skip step 8, go to step 9" disposition as a hand-written clean seam, plus an
instruction to confirm the drift check itself is exercised (a PR that edits the
source without regenerating the `.inc` must fail the build).

## 5. Bare `workflow_call: {}` — no `secrets:` block

**Verdict: confirmed present — decision-heavy, not fixed here.** Every
`workflow_call` member in this repo (`asan.yml:28`, `build-test.yml:19`,
`codeql.yml:28`, `fuzzing.yml:22`, `valgrind.yml:27`,
`security-scanners.yml:37`, `lint.yml:25`) declares `workflow_call: {}` with no
`secrets:` stanza. A member that starts needing a secret — the target needed
`GH_SUBMODULE_TOKEN` for a private submodule checkout
(`nginx-label-autoconf-module/.github/workflows/{asan,build-test,security-scanners,runtime-tests}.yml`,
each with a typed `secrets: GH_SUBMODULE_TOKEN: {required: true}` block, wired
from `ci.yml:113/121/129/137` via `secrets: ${{ secrets.GH_SUBMODULE_TOKEN }}`)
gets nothing under the skeleton's current shape: the called run silently lacks
the secret rather than failing loudly, because an undeclared `workflow_call`
input to `secrets:` is simply not passed.

This is a security-posture question, not a bounded syntax fix: whether the
skeleton should (a) require every member to declare its needed secrets by name
(typed, `required: true`, matching the target's pattern — explicit but a
per-secret edit to every consuming member), or (b) document a
`secrets: inherit`-at-the-caller convention (less boilerplate, but widens every
member's blast radius to the full secret set of the calling workflow, including
ones it doesn't need). Changing the skeleton's stance here changes what every
future adopter's members can silently fail to receive.

**Disposition.** Not fixed in this PR — flagged for the owner. Recommendation:
option (a), matching the target's already-proven pattern, since it fails loudly
(`required: true`) rather than silently, and keeps each member's secret surface
visible and minimal at the member itself rather than implicit at the caller.

## 6. `valgrind.yml`/`ci-deep.yml` soak boilerplate said to excuse a missing `soak.sh`

**Verdict: not applicable — not present as described.** The finding describes
skeleton boilerplate that justifies the *absence* of `ci/tools/soak.sh` with
"no HTTP request surface". Grepping the current tree for that phrase and for
any soak-skip justification (`grep -rn "no HTTP request surface\|does not
need\|N/A" ci/PROMPT.md .github/workflows/*.yml`) finds nothing: `soak.sh`
exists (`ci/tools/soak.sh`) and is invoked from both `valgrind.yml:71` and
`ci-deep.yml:308/346`; step 44 (`ci/PROMPT.md`, pre-fix `:1288-1310`) is the
only place that discusses skipping the soak, and its sole skip path already
requires evidence — a sha and an empty `git diff --stat` against the last green
deep run, not a standing claim about the module's surface. There is no
"declare no HTTP surface, skip permanently" escape hatch in the current prompt
for an adopter to copy.

The underlying risk the finding points at is real and forward-looking rather
than a bug to patch here: nothing currently stops an *adopter* from informally
reasoning "my module has no HTTP surface" and skipping the soak outside the
step-44 diff-based path, the way the target's own history shows happened before
it was caught (this was false there — `nla_upstream.c` registers phase
handlers, filters and a CORS content handler, and `ci/t/*_e2e.*` drives it over
live HTTP).

**Disposition.** No edit — nothing in current source matches the description.
Recommend (decision-heavy — changes what step 44 requires of every future
adopter): require that any claim of "no request surface, soak not applicable"
be a *measured* statement (the file:line of the module's registered handlers,
or their absence) in the PR body, not an assumption — closing the gap the
target hit before the diff-based skip path is reached.

## Summary

| # | Verdict | Disposition |
|---|---|---|
| 1 | already fixed | none |
| 2 | not applicable (never present as described) | none; distro-fallback recommended if support matrix widens |
| 3 | confirmed | fixed here (`ci/PROMPT.md` steps 7, 9, 39) |
| 4 | confirmed | fixed here (`ci/PROMPT.md` step 7, new taxonomy bullet) |
| 5 | confirmed | decision-heavy, flagged for owner |
| 6 | not applicable (never present as described) | recommendation only, decision-heavy |
