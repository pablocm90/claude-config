#!/usr/bin/env bash
# Behaviour tests for worktree-guard.sh — the PreToolUse hook that refuses
# writes into a product main checkout when this task window owns a worktree.
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/worktree-guard"
SLUG=fixes-at-risk
fails=0

# A workspace with a backend worktree for this window and a frontend without one.
fixture_root() {
  local root="$1"
  for repo in acme-backend acme-frontend; do
    mkdir -p "$root/$repo/app"
    git -C "$root/$repo" init -q
    git -C "$root/$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  done
  git -C "$root/acme-backend" worktree add -q -b "$SLUG" \
    "$root/acme-backend/.claude/worktrees/$SLUG" >/dev/null 2>&1
}

# Returns the hook's exit status; 2 means "blocked".
guard() {
  local root="$1" slug="$2" path="$3"
  jq -n --arg p "$path" '{tool_name: "Edit", tool_input: {file_path: $p}}' \
    | CLAUDE_PROJECT_DIR="$root" CLAUDE_TASK_SLUG="$slug" bash "$HOOK" 2>/dev/null
  echo "$?"
}

assert_blocked() {
  [ "$2" = 2 ] || { echo "FAIL: $1 — expected block (2), got $2"; fails=$((fails + 1)); }
}
assert_allowed() {
  [ "$2" = 0 ] || { echo "FAIL: $1 — expected allow (0), got $2"; fails=$((fails + 1)); }
}

tmp=$(mktemp -d)
fixture_root "$tmp"

assert_blocked "edit in the main checkout of a repo this window has a worktree for" \
  "$(guard "$tmp" "$SLUG" "$tmp/acme-backend/app/models/invoice.rb")"

assert_allowed "edit inside this window's own worktree" \
  "$(guard "$tmp" "$SLUG" "$tmp/acme-backend/.claude/worktrees/$SLUG/app/models/invoice.rb")"

# Blocking a repo the window has no worktree for would leave nowhere to work.
assert_allowed "edit in a repo with no worktree for this window" \
  "$(guard "$tmp" "$SLUG" "$tmp/acme-frontend/src/app.tsx")"

# Another window's worktree is still not this window's business, but the guard
# only knows about its own — a sibling worktree is not a main checkout.
assert_allowed "edit in a sibling window's worktree" \
  "$(guard "$tmp" "$SLUG" "$tmp/acme-backend/.claude/worktrees/other-task/app/x.rb")"

assert_allowed "edit outside the product repos entirely" \
  "$(guard "$tmp" "$SLUG" "$tmp/plans/2026-08-18-notes.md")"

assert_allowed "no task window — nothing is protected" \
  "$(guard "$tmp" "" "$tmp/acme-backend/app/models/invoice.rb")"

# The block must name the path to use instead, or it just costs a retry.
msg=$(jq -n --arg p "$tmp/acme-backend/app/models/invoice.rb" \
        '{tool_name: "Write", tool_input: {file_path: $p}}' \
      | CLAUDE_PROJECT_DIR="$tmp" CLAUDE_TASK_SLUG="$SLUG" bash "$HOOK" 2>&1 >/dev/null)
case "$msg" in
  *".claude/worktrees/$SLUG/app/models/invoice.rb"*) ;;
  *) echo "FAIL: block names the corrected worktree path — got: $msg"; fails=$((fails + 1)) ;;
esac

rm -rf "$tmp"

# --- Bash commands -------------------------------------------------------
# The pane's cwd is the workspace root, so a bare repo name in a command means
# the main checkout. Mutations there must be refused; reads must not be.
guard_cmd() {
  local root="$1" slug="$2" cmd="$3"
  jq -n --arg c "$cmd" '{tool_name: "Bash", tool_input: {command: $c}}' \
    | CLAUDE_PROJECT_DIR="$root" CLAUDE_TASK_SLUG="$slug" bash "$HOOK" 2>/dev/null
  echo "$?"
}

tmp=$(mktemp -d)
fixture_root "$tmp"
WT="$tmp/acme-backend/.claude/worktrees/$SLUG"

assert_blocked "git commit against the main checkout by -C" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C acme-backend commit -m x")"
assert_blocked "git commit against the main checkout by absolute -C" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C $tmp/acme-backend commit -m x")"
assert_blocked "cd into the main checkout, then a bare git write" \
  "$(guard_cmd "$tmp" "$SLUG" "cd acme-backend && git commit -m x")"
assert_blocked "git add against the main checkout" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C acme-backend add app/models/invoice.rb")"
assert_blocked "in-place sed on a main-checkout file" \
  "$(guard_cmd "$tmp" "$SLUG" "sed -i 's/a/b/' acme-backend/app/models/invoice.rb")"
assert_blocked "redirect into a main-checkout file" \
  "$(guard_cmd "$tmp" "$SLUG" "cat > acme-backend/app/models/invoice.rb <<EOF")"
assert_blocked "redirect into a relative path after cd" \
  "$(guard_cmd "$tmp" "$SLUG" "cd acme-backend && cat > app/models/invoice.rb <<EOF")"
assert_blocked "rm of a main-checkout file" \
  "$(guard_cmd "$tmp" "$SLUG" "rm acme-backend/app/models/invoice.rb")"

assert_allowed "git commit against this window's worktree" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C $WT commit -m x")"
assert_allowed "cd into the worktree, then a bare git write" \
  "$(guard_cmd "$tmp" "$SLUG" "cd $WT && git commit -m x")"
assert_allowed "reading the main checkout with grep" \
  "$(guard_cmd "$tmp" "$SLUG" "grep -rn foo acme-backend/app 2>/dev/null")"
assert_allowed "git log against the main checkout" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C acme-backend log --oneline -5")"
# Probe scripts legitimately run against the main checkout — they only read.
assert_allowed "rails runner probe from the main checkout" \
  "$(guard_cmd "$tmp" "$SLUG" "cd acme-backend && bin/rails runner plans/data/probe.rb")"
assert_allowed "a mutation elsewhere in the same command line" \
  "$(guard_cmd "$tmp" "$SLUG" "rm /tmp/scratch && grep -rn foo acme-backend/app")"
assert_allowed "mutating a repo this window has no worktree for" \
  "$(guard_cmd "$tmp" "$SLUG" "sed -i 's/a/b/' acme-frontend/src/app.tsx")"
assert_allowed "no task window — nothing is protected" \
  "$(guard_cmd "$tmp" "" "git -C acme-backend commit -m x")"

# A repo name is not always a path. It appears in GitHub slugs, in commit and
# PR text, and inside sed replacements — none of which write to the checkout.
assert_allowed "gh reading a repo by slug, redirected outside the workspace" \
  "$(guard_cmd "$tmp" "$SLUG" "gh pr view 42 --repo acme/acme-backend --json body > /tmp/pr.md")"
assert_allowed "sed writing outside, with the repo name only in the replacement" \
  "$(guard_cmd "$tmp" "$SLUG" "sed -i 's/acme-backend#1/acme-backend#2/g' /tmp/pr.md")"
assert_allowed "commit message mentioning the repo, in the worktree" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C $WT commit -m 'sync with acme-backend master'")"
# Running from the main checkout is fine as long as the write lands elsewhere.
assert_allowed "cd into the main checkout, redirecting to an absolute path outside it" \
  "$(guard_cmd "$tmp" "$SLUG" "cd acme-backend && bin/rails runner probe.rb > /tmp/out.txt")"

# The repo name can sit deeper than the head of a path, so a token shaped like
# a path is searched through. A bare word is not: that is the slug shape.
assert_blocked "git write against a main checkout reached through a variable" \
  "$(guard_cmd "$tmp" "$SLUG" 'git -C $PWD/acme-backend commit -m x')"
assert_blocked "git write against a main checkout given as a --flag=path" \
  "$(guard_cmd "$tmp" "$SLUG" "git --git-dir=acme-backend/.git commit -m x")"
assert_blocked "redirect into a main checkout named by an absolute path" \
  "$(guard_cmd "$tmp" "$SLUG" "cat > $tmp/acme-backend/app/models/invoice.rb")"

# Copying out of a main checkout reads it; only the destination is a write.
assert_allowed "copying a file out of the main checkout" \
  "$(guard_cmd "$tmp" "$SLUG" "cp acme-backend/config/database.yml /tmp/")"
assert_blocked "copying a file into the main checkout" \
  "$(guard_cmd "$tmp" "$SLUG" "cp /tmp/database.yml acme-backend/config/database.yml")"

# Starting another task means a new worktree, cut where the conventions put it.
# That writes the repo's worktree metadata, not the main checkout's files.
assert_allowed "adding a worktree for another task under .claude/worktrees" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C $tmp/acme-backend worktree add $tmp/acme-backend/.claude/worktrees/bump-gem -b bump-gem origin/master")"
assert_allowed "adding a worktree by its relative path from inside the main checkout" \
  "$(guard_cmd "$tmp" "$SLUG" "cd acme-backend && git worktree add .claude/worktrees/bump-gem -b bump-gem origin/master")"
assert_allowed "adding a worktree with the branch flag before the path" \
  "$(guard_cmd "$tmp" "$SLUG" "git -C acme-backend worktree add -b bump-gem acme-backend/.claude/worktrees/bump-gem origin/master")"
assert_blocked "adding a worktree that would land in the main checkout's files" \
  "$(guard_cmd "$tmp" "$SLUG" "cd acme-backend && git worktree add tmp/bump-gem -b bump-gem origin/master")"

rm -rf "$tmp"

# --- A single-repo project ----------------------------------------------
# Outside a workspace, claude-dev's root is the repo itself, so the pane starts
# in its main checkout: a bare git mutation there lands on the wrong branch.
repo=$(mktemp -d)
git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$repo" worktree add -q -b "$SLUG" "$repo/.claude/worktrees/$SLUG" >/dev/null 2>&1
echo .claude/handoffs/ >> "$repo/.git/info/exclude"
wt="$repo/.claude/worktrees/$SLUG"

guard_at() {
  local cwd="$1" tool="$2" arg="$3"
  jq -n --arg c "$cwd" --arg t "$tool" --arg a "$arg" \
    '{cwd: $c, tool_name: $t, tool_input: (if $t == "Bash" then {command: $a} else {file_path: $a} end)}' \
    | CLAUDE_PROJECT_DIR="$repo" CLAUDE_TASK_SLUG="$SLUG" bash "$HOOK" 2>/dev/null
  echo "$?"
}

assert_blocked "single repo: edit in the main checkout" "$(guard_at "$repo" Edit "$repo/src/app.ts")"
assert_allowed "single repo: edit in this window's worktree" "$(guard_at "$repo" Edit "$wt/src/app.ts")"
# The handoff lives in the main checkout's .claude/handoffs, ignored by git.
assert_allowed "single repo: writing the ignored handoff" "$(guard_at "$repo" Write "$repo/.claude/handoffs/$SLUG.md")"
assert_allowed "single repo: redirecting into the ignored handoffs" "$(guard_at "$repo" Bash "git diff > $repo/.claude/handoffs/$SLUG.patch")"
assert_blocked "single repo: branching off from the main checkout" "$(guard_at "$repo" Bash "git checkout -b docs/design")"
assert_blocked "single repo: committing from the main checkout" "$(guard_at "$repo/src" Bash "git commit -m x")"
assert_allowed "single repo: committing from the worktree" "$(guard_at "$wt" Bash "git commit -m x")"
assert_allowed "single repo: moving into the worktree first" "$(guard_at "$repo" Bash "cd $wt && git commit -m x")"
assert_allowed "single repo: moving into the worktree by a relative path" "$(guard_at "$repo" Bash "cd .claude/worktrees/$SLUG && git commit -m x")"
assert_allowed "single repo: committing elsewhere after leaving the repo" "$(guard_at "$repo" Bash "cd /tmp && git commit -m x")"
# task-context tells the agent to aim git with -C; the -C target, not the
# pane's cwd, says which checkout the command touches.
assert_allowed "single repo: git aimed at a worktree with -C" "$(guard_at "$repo" Bash 'git -C "$WT" commit -m x')"
assert_allowed "single repo: moving into the worktree through a variable" "$(guard_at "$repo" Bash 'cd "$WT" && git commit -m x')"
assert_allowed "single repo: a PR title that mentions git" "$(guard_at "$repo" Bash 'gh pr create --title "Block git add in main"')"
assert_allowed "single repo: a commit-message line that mentions git" "$(guard_at "$repo" Bash 'Stop the git push from main')"
heredoc_commit=$(printf "cd %s && git -C %s commit -F - <<'EOF'\nfix: stop git push from main\nEOF" "$repo" "$wt")
assert_allowed "single repo: a heredoc body that mentions git" "$(guard_at "$repo" Bash "$heredoc_commit")"
assert_blocked "single repo: committing in the main checkout after a heredoc" "$(guard_at "$repo" Bash "$heredoc_commit
git commit -m x")"
for opener in "bash <<'EOF'" "sh <<'EOF'" "zsh <<'EOF'" "cat <<'EOF' | bash"; do
  assert_blocked "single repo: a heredoc body run by a shell ($opener)" "$(guard_at "$repo" Bash "$(printf "%s\ngit commit -m x\nEOF" "$opener")")"
done
for opener in "cat > /tmp/run.sh <<'EOF'" "cat <<'EOF' > shell.txt"; do
  assert_allowed "single repo: a heredoc body written to a file ($opener)" "$(guard_at "$repo" Bash "$(printf "%s\ngit commit -m x\nEOF" "$opener")")"
done
assert_blocked "single repo: a heredoc that never closes hides nothing" "$(guard_at "$repo" Bash "$(printf "cat <<'EOF'\ngit commit -m x")")"
assert_allowed "single repo: a write outside the repo" "$(guard_at "$repo" Bash "mkdir -p /tmp/scratch-x")"
assert_allowed "single repo: reading from the main checkout" "$(guard_at "$repo" Bash "git log --oneline -3")"
rm -rf "$repo"

[ "$fails" -eq 0 ] && echo "worktree-guard: all assertions passed"
exit "$fails"
