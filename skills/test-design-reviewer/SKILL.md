---
name: test-design-reviewer
description: Review tests for what should go as well as what is missing — redundant, framework-testing and over-mocked tests, then Dave Farley's eight properties. Use before committing tests, when assessing a test file or suite, or when asked whether tests are too many, too verbose or too weak.
context: fork
agent: general-purpose
model: sonnet
---

# Test Design Reviewer

Review tests as executable specifications and as code someone must maintain. The review reports; it edits nothing. Coding agents over-generate tests — near-duplicates that differ by one value, tests that re-verify the framework, mocks asserted instead of outcomes — and a review that only hunts gaps makes that worse. This one reads both ways.

Read the tests in full before the implementation, so their public story stands on its own. Then read the production boundary they exercise and the project's test conventions (its CLAUDE.md).

## Step 1: What should go

For every test in scope, ask: **what bug does this catch that no other test catches?** Judge the answer against the `testing` skill — What Not to Test, One Test per Branch, One Layer per Behaviour, Mock Only at System Boundaries, the factory principles — and against these:

- A test that would still pass with all the project's own code deleted is testing the framework.
- A test that fails only when the mock is removed is testing the mock.
- A snapshot earns its place only when the serialised output is itself the contract and small enough to read; an unread snapshot approves itself.
- A test that reproduces a production incident — named in its title or the commit that added it — is justified by the incident: keep it, even when another test overlaps. A suspected incident is a question for the human, not a reason to keep.

Each finding names the test (`path:line`), the rule, and the smallest fix: merge into a table (rows that each take a different branch), delete (a test that repeats a branch another already takes), move to the owning layer, trim setup, or narrow the assertion. Done when every test in scope has been asked the question.

## Step 2: What is weak or missing

Rate each of Farley's properties `Strong`, `Mixed`, `Weak` or `Not assessed`, with `path:line` evidence:

| Property | Strong evidence |
|---|---|
| Understandable | The behaviour, and what a failure would mean, are clear without reading the implementation |
| Maintainable | A behaviour-preserving refactor rewrites no unrelated test |
| Repeatable | Time, randomness, network and shared resources are controlled; parallel runs agree |
| Atomic | A test runs alone, and its failure points at one behaviour |
| Necessary | Removing the test removes evidence no other test gives — judged in Step 1 |
| Granular | Assertions describe one coherent outcome; related assertions stay together |
| Fast | Fast enough for its feedback loop, on measured evidence |
| First | A captured RED run or the history shows the test failed for the right reason first |

- No aggregate score: unequal risks make a weighted number falsely precise.
- **First** and **Fast** stay `Not assessed` without evidence; static shape proves neither chronology nor speed.
- Ask for the smallest change that strengthens observable behaviour — never one assertion per test or a test per file.
- Name a missing case only for a branch with no case, or a threshold with no case on it, and propose it as a row in an existing table where one exists.
- A reported surviving mutant is answered on the `mutation-testing` Step 4 ladder.

Done when every property has a rating.

## Output

```markdown
## Test design review: [scope]

### Delete or merge
- `path:line` "[test name]" — [rule] → [delete / merge into … / move to … / trim / narrow]

### Properties
| Property | Rating | Evidence |
|---|---|---|
| Understandable | Strong/Mixed/Weak/Not assessed | `path:line` and reason |

### Findings
1. **[severity] [problem]** (`path:line`) — Impact: [risk]. Smallest fix: [action].

### Not assessed
- [property or claim, and the evidence it would need]
```

"Delete or merge" is always present; "none — every test catches something no other test does" is a valid entry. No findings is a valid result: do not invent work to fill a section.

## Attribution

The eight properties are Dave Farley's [Properties of Good Tests](https://www.linkedin.com/pulse/tdd-properties-good-tests-dave-farley-iexge/). The rating approach is adapted from the `test-design-reviewer` skill in [citypaul/.dotfiles](https://github.com/citypaul/.dotfiles), and the Step 1 checks from `test-guard` in [amelnagdy/guard-skills](https://github.com/amelnagdy/guard-skills); both MIT, notices in `LICENSE`.
