#!/usr/bin/env bash
# Behaviour tests for task-context.sh — the SessionStart hook that tells Claude
# which worktrees the current task window owns.
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/task-context"
fails=0

fixture_root() {
  local root="$1" repo branch
  for spec in "$2" "$3"; do
    repo="${spec%%:*}"; branch="${spec#*:}"
    mkdir -p "$root/$repo"
    git -C "$root/$repo" init -q
    git -C "$root/$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    [ "$branch" = "-" ] && continue
    git -C "$root/$repo" worktree add -q -b "$branch" "$root/$repo/.claude/worktrees/$SLUG" >/dev/null 2>&1
  done
}

run() { CLAUDE_PROJECT_DIR="$1" CLAUDE_TASK_SLUG="$2" bash "$HOOK" 2>/dev/null; }

assert_contains() {
  case "$2" in *"$3"*) ;; *) echo "FAIL: $1 — expected to contain: $3"; fails=$((fails + 1)) ;; esac
}
assert_empty() {
  [ -z "${2//[[:space:]]/}" ] || { echo "FAIL: $1 — expected no output, got: $2"; fails=$((fails + 1)); }
}

# A window whose worktrees exist in both repos names each path and its real
# branch — the branch may drift from the directory slug, and that must show.
tmp=$(mktemp -d); SLUG=fixes-at-risk
fixture_root "$tmp" "acme-backend:fixes-at-risk" "acme-frontend:feat/other-name"
out=$(run "$tmp" "$SLUG")
assert_contains "backend path" "$out" "$tmp/acme-backend/.claude/worktrees/fixes-at-risk"
assert_contains "backend branch" "$out" "fixes-at-risk"
assert_contains "frontend path" "$out" "$tmp/acme-frontend/.claude/worktrees/fixes-at-risk"
assert_contains "drifted branch is visible" "$out" "feat/other-name"
rm -rf "$tmp"

# A window with no worktrees of its own has nothing to say.
tmp=$(mktemp -d); SLUG=no-worktree-here
fixture_root "$tmp" "acme-backend:-" "acme-frontend:-"
assert_empty "no worktrees" "$(run "$tmp" "$SLUG")"
rm -rf "$tmp"

# Outside a task window (hub, or no window at all) the hook stays silent.
tmp=$(mktemp -d); SLUG=hub
fixture_root "$tmp" "acme-backend:hub" "acme-frontend:-"
assert_empty "hub window" "$(run "$tmp" hub)"
assert_empty "no slug" "$(run "$tmp" "")"
rm -rf "$tmp"

# A single-repo project is its own root: its worktree is named too.
tmp=$(mktemp -d); SLUG=solo-task
git -C "$tmp" init -q
git -C "$tmp" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$tmp" worktree add -q -b "$SLUG" "$tmp/.claude/worktrees/$SLUG" >/dev/null 2>&1
assert_contains "single repo worktree" "$(run "$tmp" "$SLUG")" "$tmp/.claude/worktrees/$SLUG"
rm -rf "$tmp"

[ "$fails" -eq 0 ] && echo "task-context: all assertions passed"
exit "$fails"
