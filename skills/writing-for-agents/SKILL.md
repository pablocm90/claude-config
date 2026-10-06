---
name: writing-for-agents
description: Writing what an agent reads to decide how to act — skills, agent prompts, CLAUDE.md, memory files, and the pointers to them. Use when creating, editing or pruning any of those.
metadata:
  credits:
    author: Matt Pocock
    url: https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md
    license: MIT
---

# Writing for agents

A skill, an agent prompt, a CLAUDE.md, a memory file, and the index line that points at one are all written with the same levers. The aim is not identical output; it is the agent taking the same *process* on every run.

For what is specific to skills and agents (frontmatter, who can invoke them, the index that routes to them), read [resources/mechanics.md](resources/mechanics.md).

## Pointers

A **pointer** is an always-loaded line that names material outside the context and the condition for reaching it: a skill or agent description, a CLAUDE.md line naming a doc, a memory index line. Its *wording*, not its target, decides when the agent reaches the material. A must-have target behind a weak pointer is a reliability bug: sharpen the wording before inlining the material.

A pointer says what the material is and lists the **branches** that should reach it: distinct cases, not synonyms. Every word of it is paid on every turn, so:

- Front-load the trigger word.
- Give one trigger per branch. Synonyms for one branch are that branch written twice.
- Cut what the body already says.

## The two loads

- **Context load**: always-loaded text (CLAUDE.md, descriptions, the memory index) costs tokens and attention every turn, whether or not it fires.
- **Cognitive load**: the human remembering what exists and when to reach for it.

Material behind a pointer pays only for the pointer. Material with no pointer rides entirely on the human's memory.

## Hierarchy and disclosure

A document holds **steps** (what to do, in order) and **reference** (rules and facts consulted on demand). Rank each piece by how soon the agent needs it:

1. In-file step.
2. In-file reference.
3. Disclosed reference: a separate file behind a pointer, loaded only when the pointer fires.

Inline what every branch needs; disclose what only some branches reach. Reference left inline among steps buries the steps. Keep a concept's definition, rules and caveats under one heading rather than scattered.

**Sprawl** is a document too long even when every line is live: attention thins across it. Cure it by disclosure and by splitting along branches, not by trimming words.

## Steps end on completion criteria

Every step ends on a condition that tells the agent it is done.

- **Clear**: a vague bound ("understanding reached") invites stopping early, pulled by the steps still ahead. Sharpen the bound first. Only when it stays fuzzy and you see the rush, hide the later steps by splitting the sequence across a real context boundary (a handoff, a subagent); an inline call leaves them in view.
- **Demanding**: "every modified model accounted for" drives legwork that "produce a change list" does not.

The strongest criteria are checkable and exhaustive.

## Leading words

A **leading word** is a compact concept the model already knows (*tight*, *red*, *tracer bullet*, *one-way door*), repeated as a token. It anchors a region of behaviour in the fewest words. Collapse a phrase spelled out at several sites into one ("fast, deterministic, low-overhead" becomes *tight*). Prefer an existing word to a coined one: a coined word recruits no priors and costs its definition.

## State the target, not the ban

A prohibition puts the banned behaviour into context and makes it more available. Write the behaviour you want ("return a new copy" rather than "don't mutate"). Keep a prohibition only as a hard guardrail with no positive phrasing, and pair it with the target. A rule with a fixed shape (a command, a pattern, a path) belongs in a hook, where it cannot be ignored, not in prose.

## Pruning

- **Single source**: each meaning lives in one place. Duplication costs tokens and inflates a meaning's rank.
- **Cache vs environment**: restating a config file, a script or `--help` is a cache that goes stale. Write down what cannot be looked up: the unwritten convention, the reason behind a choice, the gotcha no config confesses.
- **Relevance**: a line that no longer bears on what the document does is sediment, and sediment builds because adding feels safe and removing feels risky.
- **No-ops**: a sentence the model already obeys by default says nothing. Judge it against the model's default, not a reader's intuition, and delete the whole sentence. A word too weak to beat the default (*be thorough*) is a no-op too; reach for a stronger one (*relentless*).

## Done when

Every pointer you touched names its branches behind a front-loaded trigger, every step you wrote ends on a criterion, and a read-through of the lines you changed finds no no-op, duplicate, cache, or ban that should be a positive target or a hook. A wider sweep of the file is a separate change the human picks.
