---
name: mmmss-stride
description: Many More Much Smaller Steps. Forces a human-in-the-loop cadence of small, committed strides so the human reviews every commit. Load when the human asks for strides ("stride mode", "review every commit") instead of the default `until-pr` rhythm. Overrides other workflow skills (notably `feature-dev:feature-dev`) when loaded.
---

# MMMSS — Many More Much Smaller Steps

The agent's job is to make progress in **strides**: short, ready-to-ready intervals that end on a green commit. At each stride boundary the agent commits the green stride, then runs `claude-dev ready --note`, which auto-pops the terminal review of that commit — opening with a short paragraph the agent writes to say what the stride was for. The human reviews there and says "continue" (approve) or "redirect" (a note that reaches the agent on its next turn via the review-notes hook).

This skill governs the cadence **between** strides. The `tdd` skill governs the work **inside** a stride. When both are loaded, this skill wins on stop-and-review behaviour. How each commit is sized and made, and how a branch ships, live in [resources/commits-and-shipping.md](resources/commits-and-shipping.md), shared with `until-pr`: read it before the first stride. A stride is one of its commits.

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

The budget is the shared commit size: one behaviour, one test case, ≤ ~40 production lines, ≤ 3 files.

**Declare the size before starting.** The stride opener names what the slice will cost and where its test goes — "1 test on `X#call` + ~15 lines in `X`" — so the human can veto an over-sized slice before the work rather than after the diff.

---

## Session-opening ceremony

The **first message** of every session must declare exactly five things, in this order:

1. **Destination** — one sentence describing where we're going.
2. **Done criterion** — the test or observable state that proves we got there.
3. **First step** — the smallest plausible action toward the destination.
4. **Size** — what the first step will cost, in tests and production lines, and the **seam** the test goes through (the public interface it exercises), so the human confirms where the test lands as well as what it costs.
5. **Skills** — the set you are about to load for this work, and what selected them. The human corrects it here, before it is in context.

Do **not** enumerate subsequent steps. Do **not** propose a different stride size (the budget is fixed). Do **not** start coding until the human confirms or redirects.

Template:

> **Destination:** _<one sentence>_
> **Done when:** _<the test / observable state>_
> **First step:** _<smallest plausible slice>_
> **Size:** _<what it will cost, and through which seam: e.g. 1 test on `Invoices::Settle#call` + ~15 lines in `X`>_
> **Skills:** _<the set you are about to load, and the work type that chose them>_
>
> Proceeding on confirmation.

**On review-comment destinations:** When the destination is "PR releasable" or "comments resolved," resolution has three modes: (a) code fix lands and is pushed; (b) reply on the PR thread that the reviewer accepts; (c) implicit waive — the reviewer doesn't ask for a reply when offered, signalling acceptance. Don't force a reply when (c) applies.

---

## Inside a stride

Work as *Inside a commit* in the shared file says. The one MMMSS-specific rule: don't pre-emptively start the next stride's work just because the current one finished early. End the stride. Let the human steer.

---

## End-of-stride ceremony

When the stride is done:

1. **Make the commit** as the shared file's *Making the commit* says. The stride boundary is the approval point, so commit directly.
2. **Signal for review — with the context the diff can't carry.** Run `claude-dev ready --note "<note>"`. It flags the task window and auto-pops the terminal review of the committed stride, opening with your note.

   The reviewer arrives cold and reads standing up, before the diff. Write a **headline line** — ≤ 15 words, no label, the one sentence someone who stops there still needs — then a blank line, then only the labels that have something to say, in this order:

   - `Where:` — the plan slice / stride, and the destination it moves toward.
   - `Why:` — the decision a reader can't infer from the diff: why this shape and not the obvious alternative.
   - `Look at:` — the hunk most worth their attention, or the judgement call you're least sure of.
   - `Not done:` — deferred work, so it isn't reported back as missing.
   - `Green:` — which tests ran, plus any live verification.

   **Budget: 120 words total, at most 25 per label** — `claude-dev ready` warns on stderr when a note is over, and never blocks; trim and re-signal rather than ignoring it. One label per line — the pane bolds each one, hangs its continuation lines in a column, and wraps to 80. Omit a label rather than pad it; four honest labels beat five where one is filler. Do not write connective prose ("worth your attention because…", "which I want to be explicit about…") — that tax is what made these notes a wall. A note that is all rationale and no headline still renders, but it is the shape this step exists to replace.

   Pipe anything multi-line: `claude-dev ready --note - <<'EOF' … EOF`. Signalling bare (`claude-dev ready`) degrades the review to the commit message — acceptable only when that message already carries all of the above. A note is written fresh per stride and cleared when omitted, so it always describes the diff on screen.
3. **Stop.** Yield to the human. They approve (continue) or leave a note (redirect) in the review; a note reaches you on your next turn via the review-notes hook. Do not start the next stride until that word arrives.

The handoff sentence should be short and concrete:

> Stride done — commit `<sha>`: _<one-line summary>_. Review popped. Waiting.

---

## Ship loop & CI (pipelined)

Ship as the shared file's *Shipping* says, every 2–4 strides, when a coherent slice exists. Strides never push, wait on CI or run full gates. Review findings and red checks each become a stride. Draft the PR description from the notes you wrote at each stride boundary; it is the stride note scaled up. While a slice bakes in CI, keep striding on the same task or interact in another task window.

**After a merge/deploy, or once the session's context passes 150k tokens, cycle at the next stride boundary** (`handoff` skill): flush durables to memory/plan/PR, write the task handoff, and let the human restart the pane with `claude-dev cycle`. Past 200k the handoff *is* the next stride: every call re-reads the whole conversation, and re-reading is most of what a session costs. The status line shows context in tokens, and a prompt hook adds a reminder once a session passes 200k.

- **The stride boundary is the commit-approval point.** Commit each green stride directly, then run `claude-dev ready --note`; review and steering happen post-commit in the auto-popped terminal review, not in a pre-commit approval beat.
- **Never start a new stride without the human's word.** Even if the next step seems obvious. The whole point of the cadence is the human stays in the loop.
- The shared file's *Guardrails* hold too.

---

## Composition with other skills

- **`tdd`**: complementary. TDD governs the technique inside a stride; MMMSS governs the boundary between strides. The MUTATE / KILL-MUTANTS phases run inside the stride before the commit, and CLEANUP runs last, just before it.
- **`until-pr`**: the other rhythm, and the default. A task runs one of the two.
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
