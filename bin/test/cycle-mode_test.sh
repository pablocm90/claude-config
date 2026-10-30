#!/usr/bin/env bash
# Behaviour tests for a task's rhythm across a cycle: a task runs until-pr
# unless it was made with --stride, and the fresh session `cycle` starts is
# told to carry on (until-pr) or to propose and wait (mmmss-stride).
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

bin=$(mktemp -d)
cat > "$bin/tmux" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_TMUX_LOG"
case "$*" in
  "list-windows -t alpha -F #W") printf '%s\n' ${FAKE_WINDOWS:-} ;;
esac
exit 0
FAKE
chmod +x "$bin/tmux"

tmp=$(mktemp -d); ws="$tmp/alpha"
mkdir -p "$ws"
git init -q --bare -b master "$tmp/origin"
git clone -q "$tmp/origin" "$tmp/seed" 2>/dev/null
git -C "$tmp/seed" commit -q --allow-empty -m init
git -C "$tmp/seed" push -q origin master
git clone -q "$tmp/origin" "$ws/app"
echo .claude/worktrees/ >> "$ws/app/.git/info/exclude"

LOG="$tmp/tmux.log"
run() {
  env -u TMUX PATH="$bin:$PATH" FAKE_TMUX_LOG="$LOG" CLAUDE_DEV_ROOT="$ws" \
    CLAUDE_DEV_CLAUDE_CMD=claude bash "$CD" "$@" >/dev/null 2>&1
}

cycle_prompt() {
  : > "$LOG"
  FAKE_WINDOWS="$1" run cycle "$1"
  grep -F 'send-keys' "$LOG" | tr -d '\\'
}

write_handoff() {
  mkdir -p "$ws/.claude/handoffs"
  touch "$ws/.claude/handoffs/$1.md"
}

assert_prompt() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL: $1 — no '$3' in: $2"; fails=$((fails + 1)) ;;
  esac
}

# --- a task made with --stride proposes its next stride and waits ------------
run task strided --stride
write_handoff strided
assert_prompt "a task made with --stride waits after a cycle" \
  "$(cycle_prompt strided)" "load the mmmss-stride skill, then give a one-line status plus the handoff's proposed next stride, and wait"

# --- a task made without a flag carries on after a cycle ---------------------
run task plain
write_handoff plain
assert_prompt "a task made without a flag carries on after a cycle" \
  "$(cycle_prompt plain)" "load the until-pr skill and carry on"

# --- a stride task cycled before its first handoff still proposes and waits --
run task unhanded --stride
assert_prompt "a task with no handoff proposes and waits, whatever its rhythm" \
  "$(cycle_prompt unhanded)" "propose the next stride, and wait"

# --- a slug reused after `done` starts over in until-pr ----------------------
run task reused --stride
run done reused
run task reused
write_handoff reused
assert_prompt "a task made again without a flag after done carries on" \
  "$(cycle_prompt reused)" "load the until-pr skill and carry on"

rm -rf "$bin" "$tmp"
[ "$fails" -eq 0 ] && echo "cycle-mode: all passed"
exit "$fails"
