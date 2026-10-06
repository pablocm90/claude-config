---
name: domain-modeling
description: "Domain modeling: keep the project's glossary and ADRs true as decisions land: challenge terms against the glossary, pin a fuzzy or overloaded word to one canonical term, record hard-to-reverse choices. Use when a domain term is new, contested or used two ways, or the user wants a term or decision written down."
metadata:
  credits:
    author: Matt Pocock
    url: https://github.com/mattpocock/skills/blob/main/skills/engineering/domain-modeling/SKILL.md
    license: MIT
---

# Domain modeling

The glossary is the project's shared language: one canonical word per concept, so the human, the agent and the code say the same thing. This skill is the *active* discipline of changing it; reading the glossary for vocabulary is a habit, not this skill.

## Where it lives

The project's CLAUDE.md names the glossary file. Without such a pointer, use `GLOSSARY.md` at the repo root; create it when the first term settles, and add the pointer to CLAUDE.md in the same change. ADRs live where the project already keeps them, `docs/adr/` by default.

## During the conversation

- **Challenge against the glossary**: when the user uses a term the glossary defines differently, say so at once: "the glossary defines *X* as …, and you seem to mean …: which is it?"
- **Sharpen fuzzy words**: when a word is vague or does two jobs, propose one canonical term per job.
- **Stress-test with a scenario**: invent a concrete edge case that forces the boundary between two concepts into the open.
- **Check the code**: when the user states how something works, read whether the code agrees, and surface any contradiction.
- **Write it when it settles**: update the glossary right then, in the format of [resources/glossary-format.md](resources/glossary-format.md). Terms batched for the end get lost.

The user decides every definition. You propose, check and write.

## ADRs

Offer one only for a decision that is hard to reverse (or easy to undo by mistake), a real trade-off, and surprising without context: the `adr` agent's bar. A paragraph of context, decision and reason is enough; list rejected alternatives only when the rejection is non-obvious.

## Done when

Every term settled in the conversation is in the glossary in the format, every contradiction with the code went to the user, and every ADR offered was written or declined.
