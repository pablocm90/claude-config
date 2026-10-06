---
name: retro
description: Retrospective on a coding session that proposes changes to the agent's environment (hooks, checks, steering files, memory, skills). Use when the user asks for a retro, or what to change in the setup after a session went sideways.
metadata:
  credits:
    author: Matt Pocock
    url: https://github.com/mattpocock/skills/blob/main/skills/engineering/retro/SKILL.md
    license: MIT
---

# Retro

A retro changes the **environment** the agent works in, not the code it wrote. Each finding answers one question: what would make this session's mistake impossible, or its slow part fast, for the next session?

## 1. Read the primary sources

- **The session**: the current one unless the user names another. Locate and mine its transcript with [resources/transcripts.md](resources/transcripts.md).
- **The environment it ran in**: every CLAUDE.md that loaded, the memory index, the hooks and permissions in user and project `settings.json`, and the skills it loaded.

Done when every point where the human redirected the agent, a tool call failed or a hook refused, or the agent spent many calls finding one thing is listed with the transcript line that shows it.

## 2. Classify each one

| Category | Ask | Typical fix |
|---|---|---|
| **Automated check** | Could a deterministic check have caught it? | Hook, permission rule, lint rule, CI job |
| **Steering** | Did a rule exist and fail, or was one missing? | Edit the CLAUDE.md line, memory or skill that should have steered |
| **Skill reach** | Should a skill have loaded and didn't, or loaded and changed nothing? | Sharpen its description or its work-type row |
| **Navigation** | Did finding a file or fact take many calls? | A one-line pointer where the agent looks first |
| **Tool economy** | Were calls expensive, repeated or needlessly prompting? | A script, an allowlist entry, a narrower command |
| **Information access** | Was a crucial fact out of reach? | Read-only access, teed logs, a doc |

**Mechanical beats prose.** A violation with a fixed shape (a command, a pattern, a path) gets a deterministic check, and the prose rule that described it is deleted. Prose is for judgement calls. Read the existing hooks and gates first: a check that exists but is unwired or broken is the finding.

A hook either asks or blocks: `permissionDecision: "ask"` for what needs the human's word, exit 2 for what is never right.

A standard that only matters at review time belongs in the reviewer's prompt, not in CLAUDE.md. The reviewer reads a diff with room to spare; the implementer's context is already crowded.

## 3. Prune the steering files the session loaded

- **No-ops**: lines telling the model what it already does.
- **Duplicates**: one meaning in two places.
- **Caches**: lines restating a config file or `--help`; they go stale.
- **Sediment**: rules about things that no longer exist.

## 4. Present, then wait

Rank by severity: a mistake that reached a commit, a push or an external system outranks wasted calls. For each finding give the evidence (transcript quote or `file:line`), its category, the proposed change, where the change lives, and what it lets you delete. Write the list where the project keeps plans, or inline if it keeps none.

Change nothing until the human picks. Each picked change is its own stride.
