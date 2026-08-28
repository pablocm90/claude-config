---
name: handoff
description: End-of-cycle session handoff — flush durable knowledge to memory/plan/PR, write a compact handoff file for the task, and hand the user a one-command restart (claude-dev cycle). Use after a deploy/merge, when a session has grown long, or when the user says "handoff", "cycle", "fresh session/chat", "wrap up this session".
---

# Session Handoff (cycle)

Long sessions accumulate stale context; a task doesn't need the whole conversation — it needs the live thread. After a deploy/merge, or whenever the session drags, hand off to a fresh chat. **Durable knowledge goes where it already persists; the handoff file carries only what a fresh session can't reconstruct.**

## Procedure (writing side — the old session)

1. **Flush durable knowledge to its real home first:**
   - Learnings/gotchas worth keeping beyond this task → memory files (normal memory rules).
   - Plan progress → update the plan doc in `plans/` (living document).
   - Anything a reviewer needs → the PR description.
   The handoff must never be the only home of a durable fact.
2. **Write the handoff** to `<workspace>/.claude/handoffs/<slug>.md` — slug = the task's window/worktree name; ask if you can't infer it. Overwrite any previous handoff for the slug. Template:

   ```markdown
   # Handoff: <slug> — <date>
   **Destination**: <one sentence — where this task is going>
   **Done criterion**: <observable state that proves completion>
   **Plan**: plans/<file>.md (<which step we're at>)
   **Branch / PRs**: <branch>, PR #<n> (<CI/review/merge state>)
   **Position**: <last completed stride; what is green / committed / pushed / deployed>
   **Next stride**: <ONE stride — the MMMSS rule applies to handoffs too>
   **Live context**: <in-flight decisions, tricky state, ephemeral gotchas not worth memory>
   ```

   Keep it under ~40 lines. If it wants to be longer, the overflow belongs in the plan or memory — move it there instead.
3. **Hand over**: if the human invoked `/cycle`, run `claude-dev cycle` yourself — that is what they asked for. Otherwise tell them the handoff is written and that `/cycle`, or `claude-dev cycle <slug>` from the task window's shell pane, will respawn the pane with a fresh session. Then stop — do not start new work.

## Procedure (receiving side — the fresh session)

A session launched by `claude-dev cycle` is prompted to read the handoff. Read it plus the plan it references, then open with the MMMSS ceremony sourced from the handoff: destination, done criterion, and the handoff's next stride as the proposed first step. One-line status, then wait for the human.

## Rules

- ONE next stride in the handoff — never a step list (the human picks strides one at a time).
- Never cycle with a dirty working tree unless the handoff's Position section says exactly what is dirty and why.
- The handoff is transient state (gitignored) — memory and plans are the archives.
