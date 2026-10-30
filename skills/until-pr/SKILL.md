---
name: until-pr
description: Until-PR, the default rhythm for a coding task. The human approves the destination and done criterion once; the agent then commits green steps without stopping until a PR is open and its visual review is in front of them. Load at the start of every coding session unless the human asks for strides (`mmmss-stride`). Overrides "wait for commit approval" and other workflow skills' pacing while loaded.
---

# Until-PR

The human reviews a finished PR, through its visual review, not each commit. Between the approved destination and that review the agent commits green steps back to back, and stops early only on the triggers below.

Every commit is sized, made and shipped as `mmmss-stride`'s [resources/commits-and-shipping.md](../mmmss-stride/resources/commits-and-shipping.md) says: read that file before the first commit. Read the file, not the `mmmss-stride` skill, whose rhythm stops after every commit.

## Opening

The first message declares three things, then waits for the human to confirm or redirect:

> **Destination:** _<one sentence>_
> **Done when:** _<the test / observable state that proves it>_
> **Skills:** _<the set you are about to load, and the work type that chose them>_
>
> Running until the PR on confirmation.

The path is yours to pick. The human sees it at the visual review.

A session started by `claude-dev cycle` states the same three, taken from the handoff, plus the handoff's next step, and carries on without waiting: the destination was approved before the cycle.

## The run

Repeat until the done criterion holds:

1. Pick the smallest next step toward the destination.
2. Make it as *Inside a commit* and *Making the commit* say.
3. Check the early stops. If none fires, go to 1.

There is no stop between commits, and `claude-dev ready` runs only at the finish. A choice that isn't the human's (naming, structure inside the destination, test shape) goes in the commit message's body with its reason, where the reviewer reads it.

The run is done when the done criterion you declared holds, observably.

## Early stops

Stop, name the trigger, ask one question with your recommended answer, and wait:

- **A decision is the human's**: a product, domain or architecture choice the destination does not settle, such as a new glossary term, a new port, or a change to a public contract; or a surviving mutant whose value is ambiguous.
- **Stuck red**: a gate is still red after a `diagnosing-bugs` loop.
- **Scope grows**: reaching the done criterion needs work outside the destination. Propose the split.
- **Branch too big**: after a commit, `git diff --shortstat <base>...HEAD` shows more than 30 files *and* more than 800 changed lines. Propose how to split the PR.

## Context

After a merge, once context passes 150k tokens, when a context reminder arrives, or when the human asks: at the next green commit, run the `handoff` skill, then `claude-dev cycle` yourself. The handoff's next stride is the next step toward the destination.

## Finish

When the done criterion holds:

1. **Ship** as *Shipping* says: review subagents, pre-push gate, push, PR. A project's own pre-PR question (such as `seed-and-demo-data`) is the one stop at the finish.
2. **Run the `visual-review` skill on the PR number, through its notes step; leave the opening to `claude-dev`.** Then, when `claude-dev mode` answers, run `claude-dev ready --pr <n> --page <page path>`: it notifies the desktop and opens the page on the task window, now if the human is there, or when they next switch to it. Done when `ready` exits 0. When `mode` says *not in a task window*, open the page as `visual-review` does instead; done when the opener has returned.
3. **Report and stop**: the PR link and one sentence on what it does. Then wait.

## Follow-up

The human's reply to the review is a new destination on the same PR. Restate it in one line as destination and done criterion, then run again with the same early stops and context rule. The run ends with a push and a fresh visual review of the PR. The task ends when the human approves or merges.

## Composition with other skills

- **`tdd`**: governs the work inside each commit. This skill governs the pacing between them.
- **`mmmss-stride`**: the other rhythm. A task runs one of the two. When the human asks for strides mid-task, run `claude-dev task <slug> --stride` so cycled sessions keep them, then load `mmmss-stride` and follow it from the next commit.
- **`feature-dev:feature-dev`** and other multi-step workflow skills: this skill sets the pacing when both are loaded.
