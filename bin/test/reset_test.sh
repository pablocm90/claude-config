#!/usr/bin/env bash
# Behaviour tests for `claude-dev reset`: after a task's PR merges, its
# worktree starts over from the default branch, but only when nothing on it
# would be lost.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# A workspace with one repo, cloned from a local origin, holding a worktree
# for task1 whose PR has been merged into master, and master has moved on.
merged_workspace() {
  local ws="$1"
  git init -q --bare -b master "$ws.origin"
  git clone -q "$ws.origin" "$ws.seed" 2>/dev/null
  git -C "$ws.seed" commit -q --allow-empty -m init
  git -C "$ws.seed" push -q origin master
  touch "$ws/CLAUDE.md"
  git clone -q "$ws.origin" "$ws/app"
  echo .claude/worktrees/ >> "$ws/app/.git/info/exclude"
  git -C "$ws/app" worktree add -q -b task1 "$ws/app/.claude/worktrees/task1" origin/master 2>/dev/null
  git -C "$ws/app/.claude/worktrees/task1" commit -q --allow-empty -m "task work"
  git -C "$ws/app/.claude/worktrees/task1" push -q origin task1
  git -C "$ws.seed" fetch -q origin
  git -C "$ws.seed" merge -q --no-ff origin/task1 -m "Merge task1"
  git -C "$ws.seed" commit -q --allow-empty -m "someone else's work"
  git -C "$ws.seed" push -q origin master
}

reset() { CLAUDE_DEV_ROOT="$1" bash "$CD" reset "${@:2}" >/dev/null 2>&1; }

ws=$(mktemp -d)
merged_workspace "$ws"
wt="$ws/app/.claude/worktrees/task1"
reset "$ws" task1
[ "$(git -C "$wt" rev-parse HEAD)" = "$(git -C "$ws.origin" rev-parse master)" ] ||
  { echo "FAIL: a merged task's worktree starts over from the latest master"; fails=$((fails + 1)); }
[ "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" = task1 ] ||
  { echo "FAIL: the worktree stays on the branch named after its task"; fails=$((fails + 1)); }
# Started from origin/master, the branch would otherwise track it, and a bare
# `git push` from the task would aim at master.
[ "$(git -C "$wt" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)" != origin/master ] ||
  { echo "FAIL: the reset branch does not track the default branch"; fails=$((fails + 1)); }
rm -rf "$ws" "$ws.origin" "$ws.seed"

# Uncommitted work would be thrown away by the checkout.
ws=$(mktemp -d)
merged_workspace "$ws"
wt="$ws/app/.claude/worktrees/task1"
before=$(git -C "$wt" rev-parse HEAD)
echo "half done" > "$wt/notes.txt"
reset "$ws" task1 && { echo "FAIL: reset reports success on a dirty worktree"; fails=$((fails + 1)); }
[ "$(git -C "$wt" rev-parse HEAD)" = "$before" ] && [ -f "$wt/notes.txt" ] ||
  { echo "FAIL: a dirty worktree is left exactly as it was"; fails=$((fails + 1)); }
rm -rf "$ws" "$ws.origin" "$ws.seed"

# A commit that reached no remote exists only here; resetting would lose it.
ws=$(mktemp -d)
merged_workspace "$ws"
wt="$ws/app/.claude/worktrees/task1"
git -C "$wt" commit -q --allow-empty -m "follow-up, never pushed"
before=$(git -C "$wt" rev-parse HEAD)
reset "$ws" task1 && { echo "FAIL: reset reports success with an unpushed commit"; fails=$((fails + 1)); }
[ "$(git -C "$wt" rev-parse HEAD)" = "$before" ] ||
  { echo "FAIL: a branch with an unpushed commit is left where it was"; fails=$((fails + 1)); }
rm -rf "$ws" "$ws.origin" "$ws.seed"

ws=$(mktemp -d)
merged_workspace "$ws"
wt="$ws/app/.claude/worktrees/task1"
out=$(CLAUDE_DEV_ROOT="$ws" bash "$CD" reset task1 2>&1)
case "$out" in *"$wt"*) ;; *) echo "FAIL: a reset names the worktree it moved — got: $out"; fails=$((fails + 1)) ;; esac
# Outside a task window there is no slug to fall back on.
main_before=$(git -C "$ws/app" rev-parse HEAD)
out=$(unset TMUX; CLAUDE_DEV_ROOT="$ws" bash "$CD" reset 2>&1) && { echo "FAIL: reset without a slug reports success"; fails=$((fails + 1)); }
case "$out" in *usage*) ;; *) echo "FAIL: reset without a slug says how to call it — got: $out"; fails=$((fails + 1)) ;; esac
[ "$(git -C "$ws/app" rev-parse --abbrev-ref HEAD)" = master ] && [ "$(git -C "$ws/app" rev-parse HEAD)" = "$main_before" ] ||
  { echo "FAIL: reset without a slug leaves the main checkout alone"; fails=$((fails + 1)); }
reset "$ws" no-such-task && { echo "FAIL: reset of a task with no worktree reports success"; fails=$((fails + 1)); }
rm -rf "$ws" "$ws.origin" "$ws.seed"

# A leftover folder where a worktree used to be is not a checkout of its own:
# git would resolve it upward to the main checkout and reset that instead.
ws=$(mktemp -d)
merged_workspace "$ws"
mkdir -p "$ws/app/.claude/worktrees/gone"
main_before=$(git -C "$ws/app" rev-parse HEAD)
reset "$ws" gone && { echo "FAIL: reset of a folder that is no worktree reports success"; fails=$((fails + 1)); }
[ "$(git -C "$ws/app" rev-parse --abbrev-ref HEAD)" = master ] && [ "$(git -C "$ws/app" rev-parse HEAD)" = "$main_before" ] ||
  { echo "FAIL: a leftover worktree folder leaves the main checkout alone"; fails=$((fails + 1)); }
rm -rf "$ws" "$ws.origin" "$ws.seed"

# Inside a task window the slug is the window's name.
ws=$(mktemp -d)
merged_workspace "$ws"
wt="$ws/app/.claude/worktrees/task1"
bin=$(mktemp -d)
printf '#!/usr/bin/env bash\n[ "$*" = "display-message -p -t %%7 #W" ] && echo task1\n' > "$bin/tmux"
chmod +x "$bin/tmux"
PATH="$bin:$PATH" TMUX=fake TMUX_PANE=%7 CLAUDE_DEV_ROOT="$ws" bash "$CD" reset >/dev/null 2>&1
[ "$(git -C "$wt" rev-parse HEAD)" = "$(git -C "$ws.origin" rev-parse master)" ] ||
  { echo "FAIL: reset with no slug resets the task window's own worktree"; fails=$((fails + 1)); }
rm -rf "$ws" "$ws.origin" "$ws.seed" "$bin"

# A clone that never recorded origin's default branch still has master.
ws=$(mktemp -d)
merged_workspace "$ws"
wt="$ws/app/.claude/worktrees/task1"
git -C "$ws/app" remote set-head origin -d
reset "$ws" task1
[ "$(git -C "$wt" rev-parse HEAD)" = "$(git -C "$ws.origin" rev-parse master)" ] ||
  { echo "FAIL: without origin/HEAD, reset falls back to origin/master"; fails=$((fails + 1)); }
rm -rf "$ws" "$ws.origin" "$ws.seed"

[ "$fails" -eq 0 ] && echo "reset: all assertions passed"
exit "$fails"
