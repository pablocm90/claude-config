---
name: cleanup
description: Clean up the design of a change after it is green — remove redundant transformations, back-compat shims, unnecessary defensive code, deduplication that shouldn't have been needed, and tests the change made redundant. Run as the last step of every change, looping until reinspection finds nothing. Use after REFACTOR, before the stride commit.
license: CC0-1.0
---

# Cleanup

> Adapted from [mkanat/skills](https://github.com/mkanat/skills/blob/main/skills/cleanup/SKILL.md) (CC0-1.0).

Look over the current change (or the whole codebase if there is no current
change) and look for:

In production code:

- Any transformations or indexes that are redundant with data structures or
  relationships already known earlier in the whole-program data flow.
- Any backwards-compatibility shims, unnecessary defensive code, or unnecessary
  deduplication.
- For any deduplication added in this change, ask yourself: could these objects
  have arrived here inherently deduplicated?

In test code — the tests the change added or touched, read against the tests
already there. Narrow wide assertions first; only then judge what dominates what.

- **Assertions wider than the test's name.** A whole row asserted where one cell
  is the claim.
- **Dominated tests.** Every claim the test makes, another test at the same layer
  also makes on the same path: typically the narrow test from an early RED step
  that a later, broader test now covers.
- **The same claim at a second layer.** A rule asserted where it lives (query,
  service, pure function) and again above it (endpoint, hook, page): the owning
  layer keeps the rule's cases; the higher layer keeps only what it adds —
  wiring, rendering, authorisation — through one representative case. When the
  higher test sits outside the change, keep the owner's test and print the other
  as a finding.
- **Near-duplicates.** Tests that share arrange and assert and differ only in
  data: one table test (`test.for` / `it.each`, or a Minitest loop that defines
  one named test per row). A table that needs new helpers to express its rows
  belongs in REFACTOR.
- **Setup no assertion reads.** Overrides, fixtures, handlers and mocks the
  claims do not depend on. The factory itself stays complete and schema-valid;
  what shrinks is what the test body passes to it. A mock that keeps the test
  from tripping a real side effect stays.
- **Change detectors and ghosts.** Assertions only an intentional decision can
  fail — static copy, styling, layout, a constant's value — and tests that
  something this change removed stays removed, unless the absence is a
  requirement (`tdd`, "Behaviour, not appearance"). Ask the human when you
  cannot tell.

Before deleting a test that catches a behaviour break, name the break and the
remaining test that catches it too. When you cannot name that test, apply the
mutant the deleted test was written for and watch another test fail, or keep it.
Change detectors and ghosts catch no behaviour break, so they need no such pair.

Print out your findings, if any. Then, fix any findings you found.

After fixing your findings, look over the code again: now that we have done that
cleanup, are there any other cleanups available? Print out your new findings.
Then fix them.

Continue to do that in a loop (look over the code again, find any new cleanups
that are visible now that you've fixed the last ones, print them out, and fix
them if you find any) until you find no more cleanups to do upon reinspection.

## Placement in the loop

Cleanup is the last step of a change, after REFACTOR and before the commit:

RED → GREEN → MUTATE → KILL MUTANTS → REFACTOR → **CLEANUP** → commit

- Scope it to the current change by default. Reach for the whole codebase only when
  explicitly asked, or when there is no change in flight.
- Tests must be green before cleanup and green again after each fix. A cleanup that
  turns the suite red is a revert, not a finding.
- Deleting code is the expected outcome. If a "cleanup" adds abstraction, it belongs
  in REFACTOR (`refactoring` skill), not here.
- Under `mmmss-stride`, this runs inside the end-of-stride ceremony, before confirming
  green and committing — so each stride is committed already cleaned.
- Do not delete a public method on grep evidence alone (console/operator tools), and
  do not remove a defensive guard that a test or a documented gotcha pins.
