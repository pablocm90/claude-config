#!/usr/bin/env bash
# Behaviour tests for serve scoping: with several workspaces open on one tmux
# server, serving a task must touch only its own workspace — and must say so
# when half the stack has no worktree to start in.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0

assert_logged() {
  grep -qF -- "$2" "$LOG" || { echo "FAIL: $1 — no '$2' in the tmux calls"; fails=$((fails + 1)); }
}
assert_not_logged() {
  grep -qF -- "$2" "$LOG" && { echo "FAIL: $1 — '$2' should not have been called"; fails=$((fails + 1)); }
  return 0
}

bin=$(mktemp -d)
cat > "$bin/tmux" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_TMUX_LOG"
case "$*" in
  # the sweep: every pane in this session, whatever window
  "list-panes -s -t beta -F #{pane_id}"*)
    printf '%%2\tzsh\t%s/web/.claude/worktrees/task1\n' "$WS"
    printf '%%3\tzsh\t%s/api/.claude/worktrees\n' "$WS"
    printf '%%4\tpuma\t%s/web/.claude/worktrees/old\n' "$WS" ;;
  # every pane on the server: another workspace's server is in here too
  "list-panes -a -F #{pane_id}"*)
    printf '%%1\tpuma\t/elsewhere/.claude/worktrees/other\n'
    printf '%%2\tzsh\t%s/web/.claude/worktrees/task1\n' "$WS"
    printf '%%3\tzsh\t%s/api/.claude/worktrees\n' "$WS"
    printf '%%4\tpuma\t%s/web/.claude/worktrees/old\n' "$WS" ;;
  # the task window, for starting
  "list-panes -t beta:task1 -F"*)
    printf '%%2\t%s/web/.claude/worktrees/task1\tzsh\n' "$WS"
    printf '%%3\t%s/api/.claude/worktrees\tzsh\n' "$WS" ;;
  # who holds the port, for the status line
  "list-panes -s -t beta -F #{pane_pid}"*) printf '4242 task1\n' ;;
  "list-panes -a -F #{pane_pid}"*) printf '4242 task1\n' ;;
  "show-environment -t beta CLAUDE_DEV_ROOT") printf 'CLAUDE_DEV_ROOT=%s\n' "$WS" ;;
  # session options persist between calls, as they do on a real server
  "set -q -t beta @"*) printf '%s' "${6:-}" > "$FAKE_TMUX_OPTS/$5" ;;
  "show -qv -t beta @"*) cat "$FAKE_TMUX_OPTS/$5" 2>/dev/null ;;
esac
exit 0
FAKE
cat > "$bin/fuser" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_FUSER_LOG"
[ -n "${FAKE_FUSER:-}" ] || exit 1
printf ' %s\n' "$FAKE_FUSER"
FAKE
cat > "$bin/ss" <<'FAKE'
#!/usr/bin/env bash
case "$*" in *"sport = :3000") ;; *) exit 0 ;; esac
printf 'LISTEN 0 1024 127.0.0.1:3000 0.0.0.0:* uid:1000 ino:%s sk:1 <->\n' "$FAKE_LISTENER_INO"
FAKE
chmod +x "$bin/tmux" "$bin/fuser" "$bin/ss"

tmp=$(mktemp -d); export WS="$tmp/beta"
mkdir -p "$WS/web/.claude/worktrees/task1" "$WS/api/.claude/worktrees"
touch "$WS/web/.claude/worktrees/task1/package.json"
LOG="$tmp/tmux.log"
export FAKE_FUSER_LOG="$tmp/fuser.log" FAKE_TMUX_OPTS="$tmp/opts"
mkdir -p "$FAKE_TMUX_OPTS"

# --- serving one workspace leaves the others alone --------------------------
: > "$LOG"
err=$(
  export PATH="$bin:$PATH" TMUX=/tmp/fake,1,0 FAKE_TMUX_LOG="$LOG"
  unset TMUX_PANE
  CLAUDE_DEV_ROOT="$WS" bash "$CD" serve task1 2>&1 >/dev/null
)

assert_logged     "a stale server in this workspace is stopped"      "send-keys -t %4 C-c"
assert_not_logged "another workspace's server is left running"       "send-keys -t %1 C-c"
assert_logged     "the task's own worktree pane starts its server"   "send-keys -t %2 yarn start C-m"

# The frontend of a task whose worktree was pruned has nowhere to start: a
# serve that only reports success hides half the stack being down.
case "$err" in
  *api*) ;;
  *) echo "FAIL: a repo with no worktree for this task is reported — got: ${err:-<silence>}"
     fails=$((fails + 1)) ;;
esac

# Task1's pane holds the port, behind a listening socket with the given inode.
serving_with_listener() {
  local ino="$1"; shift
  (
    export PATH="$bin:$PATH" TMUX=/tmp/fake,1,0 FAKE_TMUX_LOG="$LOG" FAKE_FUSER=4242 FAKE_LISTENER_INO="$ino"
    unset TMUX_PANE CLAUDE_DEV_ROOT
    bash "$CD" serving --session beta "$@" 2>/dev/null
  )
}

# --- the status line publishes per workspace --------------------------------
: > "$LOG"
serving_with_listener 101 --refresh
assert_logged     "@serving is published on the session that asked" "-t beta @serving task1"
assert_not_logged "@serving is not a server-wide option"            "set -gq @serving"

# --- the status line scans for the port's owner only when the listener changes
scans() { wc -l < "$FAKE_FUSER_LOG" | tr -d ' '; }
assert_scans() {
  [ "$(scans)" -eq "$2" ] || { echo "FAIL: $1 — $(scans) scans, expected $2"; fails=$((fails + 1)); }
}

: > "$FAKE_FUSER_LOG"; rm -f "$FAKE_TMUX_OPTS"/*
serving_with_listener 101 --refresh
serving_with_listener 101 --refresh
assert_scans "an unchanged listener is not scanned again" 1
[ "$(cat "$FAKE_TMUX_OPTS/@serving" 2>/dev/null)" = task1 ] ||
  { echo "FAIL: an unchanged listener keeps its window lit"; fails=$((fails + 1)); }
serving_with_listener 202 --refresh
assert_scans "a restarted server is scanned again" 2

asked=$(serving_with_listener 202)
[ "$asked" = task1 ] ||
  { echo "FAIL: asking which window serves answers past the status line's cache — got: ${asked:-<nothing>}"; fails=$((fails + 1)); }

rm -rf "$bin" "$tmp"
[ "$fails" -eq 0 ] && echo "serve-scope: all assertions passed"
exit "$fails"
