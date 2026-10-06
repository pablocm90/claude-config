# Reading a session transcript

A transcript is one JSON object per line; `type` is `user`, `assistant`, `system`, `attachment`, or bookkeeping (`ai-title`, `mode`, …).

The path is `~/.claude/projects/<slug>/<session-id>.jsonl`, where the slug is the launch directory with every `/` replaced by `-`. The current session's id is `$CLAUDE_CODE_SESSION_ID`. Select the file by that id: concurrent sessions write to the same directory, so the newest file may belong to another one.

```bash
T=~/.claude/projects/$(pwd | tr / -)/$CLAUDE_CODE_SESSION_ID.jsonl

# What the human typed: redirects and corrections live here
jq -r 'select(.type=="user" and (.isMeta | not)) | .message.content
  | if type=="string" then . else (map(select(.type=="text") | .text) | join(" ")) end
  | select(length > 0 and (startswith("<") | not))' "$T"

# Failed tool calls and hook refusals, first two lines each
jq -r 'select(.type=="user") | .message.content | arrays | .[]
  | select(.type=="tool_result" and .is_error==true) | .content
  | if type=="string" then . else (map(.text? // "") | join(" ")) end
  | split("\n")[0:2] | join(" | ")' "$T"
# A refusal inside a chained command exits 0 when a later command succeeds,
# so this list misses it: also grep the tool results for the hook's own words.

# Every tool call, in order
jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")
  | {name, input: (.input | tostring | .[0:120])}' "$T"

# Skills the agent loaded
jq -r 'select(.type=="assistant") | .message.content[]?
  | select(.type=="tool_use" and .name=="Skill") | .input.skill' "$T"
```
