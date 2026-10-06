# Skill and agent mechanics

The skill- and agent-specific branch of `writing-for-agents`. The rest of the writing is the same.

## Who can invoke it

- **Model-invoked** (the default): the description stays loaded, so the agent or another skill can reach it. Permanent context load, bought for reach.
- **User-invoked** (`disable-model-invocation: true`): no description in context. Only a human typing its name reaches it, and no other skill can.

Decide on evidence, not on how often you think the skill is needed. Make a skill user-invoked only if the human actually types it: a skill nobody types simply stops loading. Session transcripts show who loaded what (`retro`'s `resources/transcripts.md` has the recipes). Reference shared by several user-invoked skills goes in a plain file they all point at, since none of them can reach another.

## Splitting

Split a skill in two when a distinct trigger should reach part of it on its own, or another skill must reach it. The new description is paid every turn, so that independent reach has to earn it.

## The index routes

An always-loaded index (a CLAUDE.md skill map, a work-type table) routes the agent to skills. A skill missing from it is reached only through its own description; a stale name in it routes to nothing. Change the index in the same commit as the skill, and grep for the old name when renaming or deleting one.

## New agents register late

An agent file written mid-session may not be spawnable until the harness reloads, sometimes not before the next session. To test its brief now, run a general-purpose agent told to follow the file.
