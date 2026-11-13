#!/usr/bin/env bash
# Behaviour tests for per-task MCP servers: a repo with a private config under
# ~/.claude/task-mcp/ gets its servers started at the task's worktree, not at
# the main checkout every task window's Claude is launched from.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

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

tmp=$(mktemp -d); ws="$tmp/alpha"; home="$tmp/home"
mkdir -p "$ws" "$home/.claude/task-mcp"
git init -q --bare -b master "$tmp/origin"
git clone -q "$tmp/origin" "$tmp/seed" 2>/dev/null
git -C "$tmp/seed" commit -q --allow-empty -m init
git -C "$tmp/seed" push -q origin master
git clone -q "$tmp/origin" "$ws/app"
echo .claude/worktrees/ >> "$ws/app/.git/info/exclude"

cat > "$home/.claude/task-mcp/app.json" <<'JSON'
{"mcpServers": {"graph": {"command": "graph-mcp", "args": ["--root", "{worktree}"]}}}
JSON

LOG="$tmp/tmux.log"
run() {
  env -u TMUX PATH="$bin:$PATH" HOME="$home" FAKE_TMUX_LOG="$LOG" CLAUDE_DEV_ROOT="$ws" \
    CLAUDE_DEV_CLAUDE_CMD=claude bash "$CD" "$@" >/dev/null 2>&1
}

# The Claude command line a send-keys to <target> typed, as its argv, one per line.
launched_argv() {
  local line cmd
  line=$(grep -F -- "send-keys -t $1 claude " "$LOG" | tail -1)
  cmd=${line#*"send-keys -t $1 "}
  eval "set -- $cmd"
  printf '%s\n' "$@"
}

# The --root a launched session's graph server starts with.
graph_root() {
  launched_argv "$1" | grep -A1 -x -- --mcp-config | tail -1 |
    jq -r '.mcpServers.graph.args[1]'
}

# --- a new task starts its repo's MCP servers at the task's worktree --------
: > "$LOG"
run task task1
[ "$(graph_root alpha:task1)" = "$ws/app/.claude/worktrees/task1" ] ||
  fail "a new task's graph server is rooted at its worktree (got '$(graph_root alpha:task1)')"

# --- a cycled session keeps its task's MCP servers --------------------------
: > "$LOG"
FAKE_WINDOWS=task1 run cycle task1
[ "$(graph_root alpha:task1.1)" = "$ws/app/.claude/worktrees/task1" ] ||
  fail "a cycled task's graph server is rooted at its worktree (got '$(graph_root alpha:task1.1)')"

# --- a repo the task leaves out starts no server ----------------------------
git clone -q "$tmp/origin" "$ws/lib"
echo .claude/worktrees/ >> "$ws/lib/.git/info/exclude"
cp "$home/.claude/task-mcp/app.json" "$home/.claude/task-mcp/lib.json"
: > "$LOG"
run task task2 app
[ "$(launched_argv alpha:task2 | grep -cx -- --mcp-config)" -eq 1 ] ||
  fail "a task restricted to app starts only app's MCP servers"

rm -rf "$bin" "$tmp"
[ "$fails" -eq 0 ] && echo "task-mcp: all passed"
exit "$fails"
