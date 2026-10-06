---
name: architecture-survey
description: "Architecture survey: find where shallow modules cost the most, scoped to the code that changes most, and report deepening candidates for the user to pick from. Use when asked to survey or review the architecture of a codebase or an area, or where its design causes friction."
metadata:
  credits:
    author: Matt Pocock
    url: https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md
    license: MIT
---

# Architecture survey

A survey finds **deepening candidates**: clusters of shallow modules that would buy leverage, locality and testability if merged behind a smaller interface. It reports; it does not refactor. Its vocabulary is the `refactoring` skill's `resources/deep-modules.md`: read it first and use its terms exactly.

## 1. Scope

Take the area the user named. Otherwise find the **hot spots**: the files changed most over the last few months (`git log --since="3 months ago" --name-only --format=`, counted), crossed with the project's complexity tool when it has one. Deepening pays back on code that keeps changing, so stable code stays out; when nothing stands out, widen the window. Then read the project glossary, whose words name good seams, and the ADRs covering the area (`docs/adr/` unless the project keeps them elsewhere), which record decisions not to re-litigate.

Done when the area is fixed: the one the user named, or a hot spot you can show in churn numbers.

## 2. Explore

Dispatch a subagent to walk the area and note where it causes friction:

- understanding one concept means bouncing between many small modules;
- an interface is nearly as complex as its implementation;
- logic was extracted into pure functions to be testable, while the bugs live in how they are called;
- coupling leaks across a seam;
- behaviour is untested, or testable only past the interface.

Apply the deletion test to every suspect, and name smells and connascence where they fit.

Done when every candidate has its files, its friction, and its deletion-test verdict.

## 3. Report

Write `plans/<yyyy-mm-dd>-architecture-survey-<area>.md`. For each candidate:

- **Files** and **Problem**: the friction, in the glossary's words.
- **Deepened shape**: what would sit behind the new interface, in plain words. Interfaces come later.
- **Benefits**, in leverage, locality, and which tests get simpler.
- **Before / after**: a Mermaid diagram of the two shapes.
- **Strength**: Strong, Worth exploring, or Speculative.

A candidate that contradicts an ADR appears only when its friction justifies reopening that decision, and says so. End with the candidate you recommend, and why. The candidates are alternative destinations, not a sequence of strides: ask which one to explore, and the one picked is planned and built in strides like any other work.

## 4. Explore the chosen candidate

Run `grilling` on it: its constraints, its dependencies by kind, the deepened module's shape, what sits behind the seam, which tests survive. When the interface's shape is open, use "design it twice" from `deep-modules.md`. Use `domain-modeling` when the deepened module needs a name the glossary lacks, or when the user rejects a candidate for a reason the next survey must know: offer an ADR, so it is not suggested again.

## Done when

The user has picked a candidate and its decisions are in the plan, or has declined each one with the reason recorded.
