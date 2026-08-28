---
name: mmmss-stride
description: Many More Much Smaller Steps. Forces a human-in-the-loop cadence of small, committed strides so the human reviews every few minutes without notifications. Invoke by default at the start of every session unless the human explicitly rejects it (e.g. "no MMMSS this session", "just run TDD"). Overrides other workflow skills (notably `feature-dev:feature-dev`) when loaded.
---

# MMMSS — Many More Much Smaller Steps

The agent's job is to make progress in **strides**: short, ready-to-ready intervals that end on a green commit. At each stride boundary the agent commits the green stride, then runs `claude-dev ready --note`, which auto-pops the terminal review of that commit — opening with a short paragraph the agent writes to say what the stride was for. The human reviews there and says "continue" (approve) or "redirect" (a note that reaches the agent on its next turn via the review-notes hook).

This skill governs the cadence **between** strides. The `tdd` skill governs the work **inside** a stride. When both are loaded, this skill wins on stop-and-review behaviour.

Reference: GeePaw Hill, [Many More Much Smaller Steps](https://www.geepawhill.org/series/many-more-much-smaller-steps/).

---

## Principles

1. **Stride, not plan.** Pick the smallest next slice that moves toward the destination. Do not commit to a sequence of steps up front.
2. **Every stride ends green and committed.** A stride that doesn't end in a commit didn't happen.
3. **Stop after every commit.** After committing, signal the stride for review (`claude-dev ready --note`); the human reviews in the auto-popped terminal review and steers. No autopiloting through multiple strides.
4. **Interruptable, steerable, reversible.** Every commit is a clean abort point. The human can redirect at any boundary with zero loss.
5. **Smaller is the default — but explicit intent overrides.** When choosing slice size, prefer smaller. Exception: when the human or a review comment specifies the bigger fix as the ask, take that one. Don't fight explicit intent with the smaller-default heuristic.

---

## Stride size

**One behaviour: one test case, one commit, at most ~40 changed lines of production code across at most 3 files.** Test code does not count toward the line budget; neither do generated files or fixtures.

Wall-clock targets do not work here. The agent cannot perceive elapsed time, so a minute-based budget silently degrades into "one coherent change" — which is several times larger than a human's review appetite, and arrives as a diff too big to read carefully. A line budget is checkable: run `git diff --stat` before committing, and if production lines exceed it, the slice was too big. Split the commit; do not ship it and apologise.

The agent does not negotiate the budget mid-session.

**Declare the size before starting.** The stride opener names what the slice will cost — "1 test + ~15 lines in `X`" — so the human can veto an over-sized slice before the work rather than after the diff.

Three signals the slice is too big, in the order they appear:

- The RED test needs more than one behaviour to express it.
- A second production file has to change before the first test can pass.
- `git diff --stat` shows more than ~40 production lines at green.

On any of them: stop. Commit the safely-green subset, or revert and pick a smaller slice.

---

## Session-opening ceremony

The **first message** of every session must declare exactly five things, in this order:

1. **Destination** — one sentence describing where we're going.
2. **Done criterion** — the test or observable state that proves we got there.
3. **First step** — the smallest plausible action toward the destination.
4. **Size** — what the first step will cost, in tests and production lines.
5. **Skills** — the set you are about to load for this work, and what selected them. The human corrects it here, before it is in context.

Do **not** enumerate subsequent steps. Do **not** propose a different stride size (the budget is fixed). Do **not** start coding until the human confirms or redirects.

Template:

> **Destination:** _<one sentence>_
> **Done when:** _<the test / observable state>_
> **First step:** _<smallest plausible slice>_
> **Size:** _<what it will cost: e.g. 1 test + ~15 lines in `X`>_
> **Skills:** _<the set you are about to load, and the work type that chose them>_
>
> Proceeding on confirmation.

**On review-comment destinations:** When the destination is "PR releasable" or "comments resolved," resolution has three modes: (a) code fix lands and is pushed; (b) reply on the PR thread that the reviewer accepts; (c) implicit waive — the reviewer doesn't ask for a reply when offered, signalling acceptance. Don't force a reply when (c) applies.

---

## Inside a stride

Run TDD as usual (`tdd` skill): RED → GREEN → MUTATE → KILL MUTANTS → REFACTOR → CLEANUP. Apply project conventions (Rails / TypeScript / Ruby / etc.) as normal.

The only MMMSS-specific rules inside a stride:

- Keep the slice inside the size budget: one behaviour, one test case, ≤ ~40 production lines, ≤ 3 files.
- If the slice has outgrown the budget and is not green, **stop adding code**. Either revert to the last green or commit the smallest safely-green subset.
- Don't pre-emptively start the next stride's work just because the current one finished early. End the stride. Let the human steer.

---

## End-of-stride ceremony

When the stride is done:

1. **Clean up the stride.** Run the `cleanup` skill over the stride diff: print findings, fix them, reinspect, and loop until a pass is empty. A stride is committed cleaned, not cleaned later.
2. **Confirm green at stride scope.** Run the tests you wrote and touched plus their immediate neighbours (the file-scoped format/lint hook already ran on every edit). Do **not** run full repo gates (`bin/check`, full suites) per stride — that's the ship loop's and CI's job (see "Ship loop & CI"). A stride's green is *local* green.
3. **Commit the green stride.** The stride boundary is the approval point — commit directly (stage deliberately; never blind `git commit -a`). One short subject line; body only if a reader needs the *why*. One concern per commit.
4. **Signal for review — with the context the diff can't carry.** Run `claude-dev ready --note "<note>"`. It flags the task window and auto-pops the terminal review of the committed stride, opening with your note.

   The reviewer arrives cold and reads standing up, before the diff. Write a **headline line** — ≤ 15 words, no label, the one sentence someone who stops there still needs — then a blank line, then only the labels that have something to say, in this order:

   - `Where:` — the plan slice / stride, and the destination it moves toward.
   - `Why:` — the decision a reader can't infer from the diff: why this shape and not the obvious alternative.
   - `Look at:` — the hunk most worth their attention, or the judgement call you're least sure of.
   - `Not done:` — deferred work, so it isn't reported back as missing.
   - `Green:` — which tests ran, plus any live verification.

   **Budget: 120 words total, at most 25 per label** — `claude-dev ready` warns on stderr when a note is over, and never blocks; trim and re-signal rather than ignoring it. One label per line — the pane bolds each one, hangs its continuation lines in a column, and wraps to 80. Omit a label rather than pad it; four honest labels beat five where one is filler. Do not write connective prose ("worth your attention because…", "which I want to be explicit about…") — that tax is what made these notes a wall. A note that is all rationale and no headline still renders, but it is the shape this step exists to replace.

   Pipe anything multi-line: `claude-dev ready --note - <<'EOF' … EOF`. Signalling bare (`claude-dev ready`) degrades the review to the commit message — acceptable only when that message already carries all of the above. A note is written fresh per stride and cleared when omitted, so it always describes the diff on screen.
5. **Stop.** Yield to the human. They approve (continue) or leave a note (redirect) in the review; a note reaches you on your next turn via the review-notes hook. Do not start the next stride until that word arrives.

The handoff sentence should be short and concrete:

> Stride done — commit `<sha>`: _<one-line summary>_. Review popped. Waiting.

**On commit messages:** Many projects ban non-trivial code comments per their CLAUDE.md — the WHY belongs in commit messages and PR descriptions, not source. That puts extra weight on commit messages. Write them so a future reader can reconstruct the reasoning without the conversation context.

---

## Ship loop & CI (pipelined)

A stride is not a deploy. Three loops run at different frequencies, and the human's interaction cadence (the stride) is never blocked by the slower ones:

- **Stride (one behaviour):** TDD, targeted tests, commit at green, human steers. No pushes, no CI waits, no full gates.
- **Ship (every 2–4 strides, when a coherent slice exists):** pre-push gate → push → PR. The pre-push gate runs only the fast static checks whose failures are expensive to discover via CI lag — **the project's CLAUDE.md names the exact command**, and it runs bare, as the sole command in the call (a trailing pipe or echo masks the exit code). **Nothing else runs locally** — the full test suites, security scanners and dependency audits are CI's job. Running them on both sides is the double work this section exists to kill.
- **Observe (async):** CI results surface in the PR/CI status pane (`claude-dev-status`, hub window / prefix+D). A red check is simply the *next stride* ("fix Verify on #NNNN") — fix-forward, never idle-wait. While a slice bakes in CI, keep striding on the same task or interact in another task window.

**Merging is manual and human-only.** Green CI does not authorize a merge; the human clicking merge IS the deploy gate. Never run `gh pr merge` (including `--auto`) unprompted.

**After a merge/deploy — or whenever the session has grown long — cycle the session** (`handoff` skill): flush durables to memory/plan/PR, write the task handoff, and let the human restart the pane with `claude-dev cycle`. A fresh session with a tight handoff beats a long session with stale context.

- **Never `--no-verify`.** Repo-level hooks exist for a reason. If a hook fails, fix the underlying issue or stop and ask the human. Bypassing is not on the menu.
- **The stride boundary is the commit-approval point.** Commit each green stride directly, then run `claude-dev ready --note`; review and steering happen post-commit in the auto-popped terminal review, not in a pre-commit approval beat. Stage deliberately — never blind `git commit -a`.
- **Never claim "done" with a dirty tree.** If you can't reach green, revert to the last green commit, then stop and explain.
- **Never start a new stride without the human's word.** Even if the next step seems obvious. The whole point of the cadence is the human stays in the loop.
- **Never bundle two strides into one commit.** If you found yourself doing two things, that's two commits.

---

## Composition with other skills

- **`tdd`**: complementary. TDD governs the technique inside a stride; MMMSS governs the boundary between strides. The MUTATE / KILL-MUTANTS phases run inside the stride before the commit, and CLEANUP runs last, just before it.
- **`planning`**: complementary. A plan defines the destination, not the step sequence. Use a plan to anchor "where are we going," then MMMSS picks each step adaptively.
- **`feature-dev:feature-dev`** and other multi-agent / multi-step workflow skills: **MMMSS overrides.** Those skills assume long autonomous runs; that's exactly what this skill exists to prevent. If both are loaded, follow MMMSS.
- **`story-splitting`**: upstream of MMMSS. Split a large story into vertical slices first, then use MMMSS to walk one slice.
- **TaskCreate / harness task-tracking reminders**: don't fit MMMSS strides. A stride is single-task by definition; mirroring each in TaskCreate is bookkeeping overhead. If the harness emits reminders to use it, ignore them.

---

## Anti-patterns

- **"Let me also..."** — Adding a second concern to a stride because you're already in the file. No. New stride, new commit.
- **"I'll just keep going since the next step is obvious."** — No. Stop. The human's review window is the whole product.
- **Declaring a multi-step plan, ever.** — Not in the opening message, not in a recon-report summary, not in a stride handoff, not framed as "options for next time" or a "recommendation." Only the *next single stride* is on the table at any moment. If you wrote "Stride A / B / C…" anywhere — even as a closing summary or a "proposed plan" — delete B and C. The human picks them one at a time, and stealing that choice is the failure mode this skill exists to prevent.

  **Allowed exception:** declaring one stride and offering scope alternatives for THAT stride (e.g. "small fix or full discriminated union — your call"). One stride with branching scope ≠ a multi-step plan. The test: are you asking the human to pick the *size of this stride*, or which *next stride* to run? Picking size: fine. Picking next: forbidden.
- **Commits with `wip` / `progress` / `checkpoint` messages.** — Every commit ends a stride. Strides have outcomes. Write a real subject line.
- **Reverting silently when stuck.** — If you have to revert, say so. The revert itself is information the human needs.
