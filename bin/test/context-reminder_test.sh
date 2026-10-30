#!/usr/bin/env bash
# Behaviour tests for the hook that reminds Claude to cycle: after a prompt
# once a session's context passes 200k tokens, and after a tool call once an
# until-pr task passes 150k.
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/context-reminder"
fails=0

assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1"; echo "  expected: $3"; echo "  actual:   $2"; fails=$((fails + 1)); }
}
assert_contains() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL: $1 — expected to contain '$3', got: $2"; fails=$((fails + 1)) ;;
  esac
}

tmp=$(mktemp -d)

# A claude-dev workspace whose task windows the hook can ask about.
ws="$tmp/alpha"; mkdir -p "$ws"
bin="$tmp/bin"; mkdir -p "$bin"
cat > "$bin/tmux" <<'FAKE'
#!/usr/bin/env bash
case "$*" in
  "display-message -p -t %1 #W") printf '%s\n' "$FAKE_WINDOW" ;;
esac
exit 0
FAKE
chmod +x "$bin/tmux"

# A transcript whose last call re-read `context` tokens, after an earlier,
# larger call: what counts is where the session is now, not where it peaked.
transcript_at() {
  local path="$tmp/$1.jsonl"
  {
    jq -cn '{type: "assistant", message: {usage: {input_tokens: 1, cache_creation_input_tokens: 0, cache_read_input_tokens: 400000}}}'
    jq -cn --argjson n "$2" '{type: "assistant", message: {usage: {input_tokens: 1000, cache_creation_input_tokens: 9000, cache_read_input_tokens: ($n - 10000)}}}'
    jq -cn '{type: "user", message: {content: "go"}}'
  } > "$path"
  printf '%s' "$path"
}
run() { jq -cn --arg tx "$1" '{hook_event_name: "UserPromptSubmit", transcript_path: $tx, prompt: "go"}' | bash "$HOOK"; }

assert_eq "a session under 200k gets no reminder" "$(run "$(transcript_at under 199999)")" ""

at_line=$(run "$(transcript_at at 200000)")
assert_eq "a session at 200k reminds Claude without blocking the prompt" \
  "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$at_line")" "UserPromptSubmit"
assert_contains "and the reminder names the size and the next move" \
  "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$at_line")" "200k tokens"
assert_contains "and tells you too" "$(jq -r '.systemMessage' <<<"$at_line")" "200k"
assert_eq "and never blocks it" "$(jq -r '.decision // "none"' <<<"$at_line")" "none"

after_tool() {
  jq -cn --arg tx "$2" '{hook_event_name: "PostToolUse", session_id: "s1", transcript_path: $tx, tool_name: "Bash"}' \
    | env PATH="$bin:$PATH" TMUX=fake TMUX_PANE=%1 FAKE_WINDOW="$1" CLAUDE_DEV_ROOT="$ws" bash "$HOOK"
}

assert_eq "a task just under 150k is not reminded after a tool call" \
  "$(after_tool task1 "$(transcript_at tool149 149999)")" ""

tool_line=$(after_tool task1 "$(transcript_at tool150 150000)")
assert_eq "an until-pr task at 150k is reminded after a tool call" \
  "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$tool_line")" "PostToolUse"
assert_contains "to cycle at the next green commit by itself" \
  "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$tool_line")" "run claude-dev cycle yourself"

mkdir -p "$ws/.claude/handoffs"; touch "$ws/.claude/handoffs/strided.stride"
assert_eq "a stride task past 150k is left to the prompt reminder" \
  "$(after_tool strided "$(transcript_at stride160 160000)")" ""

assert_eq "a missing transcript is silent" "$(run "$tmp/none.jsonl")" ""
assert_eq "and so is a session with no calls yet" \
  "$(printf '%s\n' '{"type":"user","message":{"content":"hi"}}' > "$tmp/new.jsonl"; run "$tmp/new.jsonl")" ""

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "context-reminder: all assertions passed"
exit "$fails"
