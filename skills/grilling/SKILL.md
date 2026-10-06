---
name: grilling
description: "Grilling: interview the user relentlessly about an idea, plan or decision, one question at a time, until every branch of its design tree is resolved. Use before an idea becomes stories or a plan, or when the user asks to be grilled or to stress-test their thinking."
metadata:
  credits:
    author: Matt Pocock
    url: https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md
    license: MIT
---

# Grilling

Interview the user until you share one understanding of the idea, with nothing left silently assumed. Map it as a **design tree**: every decision opens the decisions that hang off it.

## The frontier

The **frontier** is every open decision whose prerequisites are settled: what you can ask now without guessing at an answer you have not heard. Each turn, take the frontier question whose answer unblocks the most and ask it alone, with your **recommended answer** and the reason for it. Each answer reshapes the tree; recompute the frontier before the next question.

Ask with structure when the options are the value, and in free text when the user's own words are (domain terms, wording). `find-gaps`, "Asking with Structure", has the rules.

## Facts are yours, decisions are theirs

Anything the environment can answer (the code, the schema, a config, a doc) you look up, dispatching a subagent for a wide search. A question waiting on a lookup is off the frontier until the lookup lands; ask the others meanwhile. Every decision goes to the user, and you wait for it.

When a term the project's glossary defines differently, or a word doing two jobs, comes up, follow that thread with `domain-modeling`.

## Capture as you go

Write each decision down the moment it lands, in the plan in `plans/`; when there is none yet, start `plans/<yyyy-mm-dd>-<slug>.md` and write it there. A decision that lives only in the conversation is lost at the next handoff.

## Done when

The frontier is empty: every branch visited, every decision written down, nothing assumed. Read the decisions back, and move on (usually to `story-splitting` or `planning`) only once the user confirms that is the shared understanding.
