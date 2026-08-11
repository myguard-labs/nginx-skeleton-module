# Adoption feedback

Findings sent back here by modules that adopted this skeleton — the half of
[step 33](../PROMPT.md) that could not be fixed in code.

The skeleton is only worth keeping if it stays ahead of its clones, and an
adopter is the only party who ever runs it against an unfamiliar module. What
they hit is the evidence; without somewhere to put it, it stays in one session's
scratch file and the next adopter hits it too.

## What belongs here

Anything an adopter found about the **reference** that needs a decision, a
measurement on hardware they do not have, or a change whose blast radius crosses
every derived module. Ambiguous or wrong instructions in `PROMPT.md` count.

**What does not:** anything fixable in code. A bug in `ci/tools/`, `ci/linter/`,
a workflow or `PROMPT.md` gets the actual change in the same PR — that is the
preferred form, and a file here describing a fix that could have been made is a
worse outcome than the fix. Findings about the *target* stay with the target;
they belong in its own `issues.md`.

## At most one file per adoption

```text
ci/feedback/<target-module>-<YYYY-MM-DD>.md
```

`<target-module>` is the adopting repo's name, `<YYYY-MM-DD>` the date the
adoption finished. An adoption that found nothing writes no file at all; one that
found something writes exactly one, never appending to an earlier run's. A second
run against the same module gets its own dated file, so what was true at each
adoption stays readable.

Two adoptions of the same module finishing on the same day would collide. That
has not happened and the fix is trivial when it does — suffix the second with
`-2`, or the PR number. Do not preemptively encode a run ID into every filename
to prevent it; the directory is meant to be readable by name.

Each finding in it states:

- **what** was found
- **where** — the `file:line` in this repo, and the target's `file:line` as
  evidence
- **what it cost** — a red CI round-trip, a parked step, a wrong measurement
- **the proposed change**, and what makes it a decision rather than a fix

## Reading these

A finding here is an open question, not a ledger entry: it has no owner and no
status field. Acting on one means opening a normal PR against the affected file
and deleting the entry in the same commit — a file that outlives the thing it
describes reads as a live problem forever.

Do not manufacture a finding to have something to send. An empty directory after
an adoption is a real result about the skeleton, and a fabricated entry destroys
it.
