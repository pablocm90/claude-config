#!/usr/bin/env bash
# Behaviour tests for `claude-dev du`: the disk every task worktree takes,
# across all projects in a projects folder, totalled per project and overall.
#
# Projects come in two shapes, and both must be found: a single repo
# (<project>/.claude/worktrees/<slug>) and a workspace of repos
# (<project>/<repo>/.claude/worktrees/<slug>). A leftover folder under
# .claude/worktrees still takes disk, so it counts like any other.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0

assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected '$3', got '$2'"; fails=$((fails + 1)); }
}

stub=$(mktemp -d); printf '#!/bin/sh\nexit 0\n' > "$stub/tmux"; chmod +x "$stub/tmux"
run() { (unset TMUX TMUX_PANE; PATH="$stub:$PATH" bash "$CD" "$@" 2>&1); }

tmp=$(mktemp -d)

# A worktree holding <mb> MiB of real (non-sparse) data.
worktree_of() {
  mkdir -p "$tmp/$1"
  head -c $(( $2 * 1048576 )) /dev/zero > "$tmp/$1/blob"
}

worktree_of "side project/.claude/worktrees/big" 2
worktree_of "side project/.claude/worktrees/small" 1
worktree_of "shop/api/.claude/worktrees/seed" 3
worktree_of "shop/web/.claude/worktrees/seed" 1
mkdir -p "$tmp/leftover/.claude/worktrees/stale"; echo x > "$tmp/leftover/.claude/worktrees/stale/f"
mkdir -p "$tmp/untouched/src"

got=$(run du "$tmp")

# Each row's size is its last field; the label is everything before it.
size_of() { awk -v want="$1" '{ s = $NF; $NF = ""; sub(/^ +/, ""); sub(/ +$/, ""); if ($0 == want) print s }' <<<"$got"; }
outline() { awk '{ $NF = ""; sub(/^ +/, ""); sub(/ +$/, ""); print }' | paste -sd'|' -; }

assert_eq "a worktree reports the disk it takes" "$(size_of big)" "2.0M"
assert_eq "a project totals its worktrees across its repos" "$(size_of shop)" "4.0M"
assert_eq "a small leftover reports in kilobytes" "$(size_of stale | grep -c 'K$')" "1"
assert_eq "the total sums every worktree of every project" \
  "$(size_of "total: 5 worktrees in 3 projects")" "7.0M"
assert_eq "biggest project first, biggest worktree first within it; no worktree, no row" \
  "$(outline <<<"$got")" \
  "shop|api/seed|web/seed|side project|big|small|leftover|stale|total: 5 worktrees in 3 projects"

assert_eq "the projects folder defaults to CLAUDE_DEV_PROJECTS" \
  "$(CLAUDE_DEV_PROJECTS="$tmp" run du | tail -1)" "$(tail -1 <<<"$got")"

# --here scopes the report to the project the shell is in, from however deep.
assert_eq "--here inside a workspace worktree reports only that workspace" \
  "$(cd "$tmp/shop/web/.claude/worktrees/seed" && run du --here "$tmp" | outline)" \
  "shop|api/seed|web/seed|total: 2 worktrees in 1 projects"
assert_eq "--here in a project without worktrees names that project" \
  "$(cd "$tmp/untouched/src" && run du --here "$tmp")" "no worktrees under $tmp/untouched"
links=$(mktemp -d); ln -s "$tmp" "$links/projects"
assert_eq "--here finds the project when the shell entered it through a symlink" \
  "$(cd "$links/projects/shop" && run du --here "$tmp" | tail -1 | outline)" \
  "total: 2 worktrees in 1 projects"
assert_eq "--here outside any project is an error" \
  "$(cd "$tmp" && run du --here "$tmp" >/dev/null; echo "exit $?")" "exit 1"

empty=$(mktemp -d); mkdir -p "$empty/quiet"
assert_eq "a folder without worktrees says so, and that is no error" \
  "$(run du "$empty"; echo "exit $?")" "$(printf 'no worktrees under %s\nexit 0' "$empty")"

# Two projects of the same total size must not interleave their rows.
twins=$(mktemp -d)
for p in alpha beta; do
  mkdir -p "$twins/$p/.claude/worktrees/heavy" "$twins/$p/.claude/worktrees/light"
  head -c 9000 /dev/zero > "$twins/$p/.claude/worktrees/heavy/f"
  echo x > "$twins/$p/.claude/worktrees/light/f"
done
assert_eq "projects of equal size each keep their worktrees together" \
  "$(run du "$twins" | outline)" \
  "alpha|heavy|light|beta|heavy|light|total: 4 worktrees in 2 projects"

rm -rf "$tmp" "$empty" "$twins" "$links" "$stub"
[ "$fails" -eq 0 ] && echo "du: all assertions passed"
exit "$fails"
