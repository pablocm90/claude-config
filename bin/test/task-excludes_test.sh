#!/usr/bin/env bash
# Behaviour test: the folders claude-dev creates inside a product repo never
# show up as untracked files there, without anyone editing its .gitignore.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

bin=$(mktemp -d)
printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/tmux"
chmod +x "$bin/tmux"

tmp=$(mktemp -d); repo="$tmp/solo"
git init -q --bare -b master "$tmp/origin"
git clone -q "$tmp/origin" "$tmp/seed" 2>/dev/null
git -C "$tmp/seed" commit -q --allow-empty -m init
git -C "$tmp/seed" push -q origin master
git clone -q "$tmp/origin" "$repo" 2>/dev/null

task() {
  env -u TMUX PATH="$bin:$PATH" CLAUDE_DEV_ROOT="$repo" CLAUDE_DEV_CLAUDE_CMD=claude \
    bash "$CD" task "$@" >/dev/null 2>&1
}

task first --stride
task second --stride
untracked=$(git -C "$repo" status --porcelain --untracked-files=all)
[ -z "$untracked" ] ||
  { echo "FAIL: a task's worktree and handoff folders stay out of git status — got: $untracked"; fails=$((fails + 1)); }
[ "$(grep -c . "$repo/.git/info/exclude")" = "$(sort -u "$repo/.git/info/exclude" | grep -c .)" ] ||
  { echo "FAIL: a second task adds no duplicate exclude lines"; fails=$((fails + 1)); }
rm -rf "$tmp" "$bin"

[ "$fails" -eq 0 ] && echo "task-excludes: all assertions passed"
exit "$fails"
