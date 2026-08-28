---
description: Write the task handoff and respawn this pane with a fresh Claude session
---

Task window: !`tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null || echo '(not in tmux)'`

Working tree: !`git status --short 2>/dev/null | head -20`

Cycle this session — the whole point is that the human does not have to exit and reopen.

1. Load the `handoff` skill and follow its **sending side** procedure: flush durable knowledge to memory, the plan and the PR, then write `<workspace>/.claude/handoffs/<slug>.md` for the task window named above.
2. Print the handoff's **Position** and **Next stride** lines so the human sees what the next session will start from.
3. Respawn: run `claude-dev cycle`. It kills this pane and launches a fresh session prompted to read the handoff. The command that runs it does not survive it, so say everything you need to say first — anything after that call is never delivered.

## Constraints

- Do **not** ask for confirmation before respawning. The human invoked `/cycle` precisely to avoid the extra beat.
- **Stop instead of cycling** if the working tree is dirty in a way the handoff cannot explain, or if you cannot determine the task slug. A cycle with a wrong handoff costs the next session more than not cycling.
- Never start new work — cycling is the last act of the session.
- `claude-dev cycle` refuses to cycle the `hub` window. If that is where you are, say so and stop.
