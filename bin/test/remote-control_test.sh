#!/usr/bin/env bash
# Behaviour tests for Remote Control: every Claude session a task window
# starts — new, resumed or cycled — is reachable from claude.ai and the
# mobile app under the task's name.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

assert_logged() {
  grep -qF -- "$2" "$LOG" || { echo "FAIL: $1 — no '$2' in the tmux calls"; fails=$((fails + 1)); }
}

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

# --- a new task opens its Claude session with Remote Control on -------------
: > "$LOG"
run task task1
assert_logged "a new task's session is remote-controllable under the task's name" \
  "send-keys -t alpha:task1 claude --remote-control task1 C-m"

# --- reopening a task keeps Remote Control on the resumed session -----------
: > "$LOG"
run task task1
assert_logged "a resumed task's session is remote-controllable under the task's name" \
  "send-keys -t alpha:task1 claude --remote-control task1 --resume C-m"

# --- cycling a task starts the fresh session with Remote Control on ---------
: > "$LOG"
FAKE_WINDOWS=task1 run cycle task1
assert_logged "a cycled task's fresh session is remote-controllable under the task's name" \
  "send-keys -t alpha:task1.1 claude --remote-control task1 Fresh"

rm -rf "$bin" "$tmp"
[ "$fails" -eq 0 ] && echo "remote-control: all passed"
exit "$fails"
