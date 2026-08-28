---
name: cleanup
description: Clean up the design of a change after it is green — remove redundant transformations, back-compat shims, unnecessary defensive code, and deduplication that shouldn't have been needed. Run as the last step of every change, looping until reinspection finds nothing. Use after REFACTOR, before the stride commit.
license: CC0-1.0
---

# Cleanup

> Adapted from [mkanat/skills](https://github.com/mkanat/skills/blob/main/skills/cleanup/SKILL.md) (CC0-1.0).

Look over the current change (or the whole codebase if there is no current
change) and look for:

- Any transformations or indexes that are redundant with data structures or
  relationships already known earlier in the whole-program data flow.
- Any backwards-compatibility shims, unnecessary defensive code, or unnecessary
  deduplication.
- For any deduplication added in this change, ask yourself: could these objects
  have arrived here inherently deduplicated?

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
