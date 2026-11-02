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

# Plans and handoffs live in ignored paths of the main checkout: a write there
# by a path relative to the repo the command moved into is allowed.
echo /plans/ >> "$tmp/acme-backend/.git/info/exclude"
mkdir -p "$tmp/acme-backend/plans" && touch "$tmp/acme-backend/plans/x.md"
for write in "cd acme-backend && cat >> plans/x.md" "cd acme-backend && sed -i s/a/b/ plans/x.md"; do
  assert_allowed "a relative write into an ignored path after cd by repo name ($write)" "$(guard_cmd "$tmp" "$SLUG" "$write")"
done

rm -rf "$tmp"

# --- A single-repo project ----------------------------------------------
# Outside a workspace, claude-dev's root is the repo itself, so the pane starts
# in its main checkout: a bare git mutation there lands on the wrong branch.
repo=$(mktemp -d)
git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$repo" worktree add -q -b "$SLUG" "$repo/.claude/worktrees/$SLUG" >/dev/null 2>&1
echo .claude/handoffs/ >> "$repo/.git/info/exclude"
mkdir -p "$repo/.claude/handoffs" "$repo/src"
touch "$repo/.claude/handoffs/$SLUG.md" "$repo/src/app.ts"
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
assert_allowed "single repo: editing an ignored file whose name a shell would expand" "$(guard_at "$repo" Edit "$repo/.claude/handoffs/notes[1].md")"
for write in "git diff > $repo/.claude/handoffs/$SLUG.patch" "mkdir -p $repo/.claude/handoffs" "tee $repo/.claude/handoffs/$SLUG.md" "rm $repo/.claude/handoffs/$SLUG.md" "cp /tmp/h.md $repo/.claude/handoffs/$SLUG.md" "sed -i s/a/b/ $repo/.claude/handoffs/$SLUG.md"; do
  assert_allowed "single repo: a file command into the ignored handoffs ($write)" "$(guard_at "$repo" Bash "$write")"
done
for write in "cd $repo && cat >> .claude/handoffs/$SLUG.md <<'EOF'" "cd $repo/.claude && cat >> handoffs/$SLUG.md" "cd $repo && sed -i 's/a*/b/' \".claude/handoffs/$SLUG.md\""; do
  assert_allowed "single repo: a relative write into the ignored handoffs after cd ($write)" "$(guard_at "$repo" Bash "$write")"
done
echo dist/ >> "$repo/.git/info/exclude"
assert_blocked "single repo: a file that only a directory pattern names is not ignored" "$(guard_at "$repo" Bash "touch $repo/dist")"
assert_blocked "single repo: a file command naming an ignored path and a tracked one" "$(guard_at "$repo" Bash "rm $repo/.claude/handoffs/$SLUG.md $repo/src/app.ts")"
in_place_spellings=(-i "'-i'" -Ei -bnsruzi "'--in-place'")
long=--in-place
for n in {3..10}; do in_place_spellings+=("${long:0:n}"); done
for flag in "${in_place_spellings[@]}"; do
  assert_blocked "single repo: an in-place edit of a tracked file ($flag)" "$(guard_at "$repo" Bash "cd $repo && sed $flag s/a/b/ src/app.ts")"
done
for write in "cd $repo && sed s#a#b# -i src/app.ts" "cd $repo && sed s/a/b/ src/app.ts --in-place" "cd $repo && sed s/a/b/ \$F --in-place" "cd $repo && sed 's/\$(/' -i src/app.ts 's/)//'" "cd $repo && sed s/a/b/ \`echo\` -i src/app.ts" "cd $repo && sed -'i' s/a/b/ src/app.ts" "cd $repo && sed \\-i s/a/b/ src/app.ts" "cd $repo && sed s/a/b/ \$(echo src/app.ts) -i" "cd $repo && sed \"\$(printf s/a/b/)\" -i src/app.ts" "cd $repo && sed s/a/b/ \`echo src/app.ts\` -i" "cd $repo && echo hi >.claude/handoffs/$SLUG.md>src/app.ts" "cd $repo && sed -i s/a/b/ .claude/handoffs/$SLUG.md src/app.ts" "cd $repo && sed -i s/a/b/ .claude/handoffs/$SLUG.md $repo/src/app.ts" "sed -i s/a/b/ $repo/.claude/handoffs/$SLUG.md src/app.ts"; do
  assert_blocked "single repo: an in-place edit of a tracked file alongside an ignored one ($write)" "$(guard_at "$repo" Bash "$write")"
done
touch "$repo/src/my file.ts" "$repo/src/a;b.ts"
for write in "sed -i s/a/b/ $repo/.claude/handoffs/$SLUG.md \"$repo/src/my file.ts\"" "cd $repo && sed -i s/a/b/ .claude/handoffs/$SLUG.md 'src/my file.ts'" "cd $repo && sed -i s/a/b/ .claude/handoffs/$SLUG.md 'src/a;b.ts'"; do
  assert_blocked "single repo: an in-place edit of a quoted tracked path the guard splits ($write)" "$(guard_at "$repo" Bash "$write")"
done
for script in "'s/a b/c/'" "\"s/it's/its/\""; do
  assert_allowed "single repo: an in-place edit whose quoted script holds a space or a quote ($script)" "$(guard_at "$repo" Bash "cd $repo && sed -i $script .claude/handoffs/$SLUG.md")"
done
# A relative cd the guard cannot place leaves operands with no known base.
echo /.claude/worktrees/ >> "$repo/.git/info/exclude"
mkdir -p "$wt/src" && touch "$wt/src/app.ts"
assert_allowed "single repo: an in-place edit of the handoff after cd into the worktree" "$(guard_at "$repo" Bash "cd $wt && sed -i s/a/b/ $repo/.claude/handoffs/$SLUG.md")"
assert_blocked "single repo: an in-place edit after a relative cd out of the worktree" "$(guard_at "$wt" Bash "cd ../../.. && sed -i s/a/b/ $repo/.claude/handoffs/$SLUG.md src/app.ts")"
# The shell expands a glob or a variable into files the guard never sees named.
for operand in 'src/*.ts' '$F' 'src/app.t?' 'src/[a]pp.ts' 'src/{app,x}.ts' '`echo src/app.ts`' '~/src/app.ts' 'src/app\.ts' "'src/'*'.ts'"; do
  write="cd $repo && sed -i s/a/b/ .claude/handoffs/$SLUG.md $operand"
  assert_blocked "single repo: an in-place edit through a shell expansion after cd ($write)" "$(guard_at "$repo" Bash "$write")"
done
echo '*.log' >> "$repo/.git/info/exclude"
touch "$repo/src/debug.log"
for flag in -i -Ei --in-place --in-pl; do
  assert_allowed "single repo: an in-place edit of a file ignored by name ($flag)" "$(guard_at "$repo" Bash "sed $flag s/a/b/ $repo/src/debug.log")"
done
for write in "sed -i.bak s/a/b/ $repo/src/debug.log" "cd $repo && sed -ie s/a/b/ src/debug.log" "sed --in-place=.bak s/a/b/ $repo/src/debug.log" "sed '-i.bak' s/a/b/ $repo/src/debug.log" "sed \"--in-place=.bak\" s/a/b/ $repo/src/debug.log" "sed --in-pl=.bak s/a/b/ $repo/src/debug.log" "sed --i=.bak s/a/b/ $repo/src/debug.log"; do
  assert_blocked "single repo: an in-place edit whose backup the ignore rule may not cover ($write)" "$(guard_at "$repo" Bash "$write")"
done
for write in "cd $repo && cat >> .claude/handoffs/\$F" "cat >> $repo/.claude/handoffs/\$F" "rm $repo/.claude/handoffs/\$F"; do
  assert_blocked "single repo: a write under an ignored path through a shell expansion ($write)" "$(guard_at "$repo" Bash "$write")"
done
for write in "cd $repo && cat >> .claude/handoffs/$SLUG.md 2> src/app.ts" "cat > $repo/.claude/handoffs/$SLUG.md 2> $repo/src/app.ts"; do
  assert_blocked "single repo: a redirect into a tracked file after one into the handoffs ($write)" "$(guard_at "$repo" Bash "$write")"
done
# The exemption covers where a write lands, not where a command runs from or what it moves away.
for write in "cd $repo/.claude/handoffs && git commit -am x" "cd $repo/.claude/handoffs && rm -rf ../../src" "mv $repo/src/app.ts $repo/.claude/handoffs/x.md"; do
  assert_blocked "single repo: an ignored path does not carry a write out of it ($write)" "$(guard_at "$repo" Bash "$write")"
done
for move in "(cd" "pushd" "builtin cd"; do
  for write in "echo x > app.ts" "sed -i s/a/b/ $repo/.claude/handoffs/$SLUG.md app.ts"; do
    assert_blocked "single repo: a write after a directory change the guard cannot follow ($move, $write)" "$(guard_at "$repo" Bash "cd $repo/.claude/handoffs && $move ../../src && $write")"
  done
done
assert_blocked "single repo: an in-place edit after a pushd from a pane in an ignored directory" "$(guard_at "$repo/.claude/handoffs" Bash "pushd ../../src && sed -i s/a/b/ $repo/.claude/handoffs/$SLUG.md app.ts")"
assert_blocked "single repo: branching off from the main checkout" "$(guard_at "$repo" Bash "git checkout -b docs/design")"
# After a merge the main checkout goes back to the default branch and pulls.
for sync in "git checkout main && git pull" "git fetch && git switch master" "git -C $repo switch main"; do
  assert_allowed "single repo: returning the main checkout to its default branch ($sync)" "$(guard_at "$repo" Bash "$sync")"
done
for write in "git checkout main -- src/app.ts" "git switch -c main" "git switch feature" "git commit -am x & git switch main" "git commit -m x # checkout main"; do
  assert_blocked "single repo: anything but returning to the default branch ($write)" "$(guard_at "$repo" Bash "$write")"
done
assert_blocked "single repo: committing from the main checkout" "$(guard_at "$repo/src" Bash "git commit -m x")"
assert_allowed "single repo: committing from the worktree" "$(guard_at "$wt" Bash "git commit -m x")"
assert_allowed "single repo: moving into the worktree first" "$(guard_at "$repo" Bash "cd $wt && git commit -m x")"
assert_allowed "single repo: moving into the worktree by a relative path" "$(guard_at "$repo" Bash "cd .claude/worktrees/$SLUG && git commit -m x")"
for stay in "cd ~+" "cd ~nobody/x"; do
  assert_blocked "single repo: committing after a cd the guard cannot place ($stay)" "$(guard_at "$repo" Bash "$stay && git commit -m x")"
done
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
for opener in "bash <<'EOF'" "sh <<'EOF'" "zsh <<'EOF'" "cat <<'EOF' | bash" "cat <<'EOF'|bash"; do
  assert_blocked "single repo: a heredoc body run by a shell ($opener)" "$(guard_at "$repo" Bash "$(printf "%s\ngit commit -m x\nEOF" "$opener")")"
done
for opener in "cat > /tmp/run.sh <<'EOF'" "cat <<'EOF' > shell.txt" "gh issue create --title fresh --body-file - <<'EOF'"; do
  assert_allowed "single repo: a heredoc body written to a file ($opener)" "$(guard_at "$repo" Bash "$(printf "%s\ngit commit -m x\nEOF" "$opener")")"
done
assert_blocked "single repo: a heredoc that never closes hides nothing" "$(guard_at "$repo" Bash "$(printf "cat <<'EOF'\ngit commit -m x")")"
assert_allowed "single repo: a write outside the repo" "$(guard_at "$repo" Bash "mkdir -p /tmp/scratch-x")"
for read in "git log --oneline -3" "cd $repo && sed -n 's/x/i/p' src/app.ts" "cd $repo && sed --quiet 1p src/app.ts" \
  "cd $repo && sed -n 's/ --include=.*//p' src/app.ts" "cd $repo && find src -exec sed -n 1p {} + -print" \
  "cd $repo && sed -n 1p \$(grep -ril foo src)" "cd $repo && sed -n 1p \`grep -ril foo src\`" "cd $repo && grep -ri foo src"; do
  assert_allowed "single repo: reading from the main checkout ($read)" "$(guard_at "$repo" Bash "$read")"
done
for unparsed in "$(printf "cd %s && gh pr create --title x --body \"\$(cat <<'EOF'\nIt's done.\nEOF\n)\"" "$repo")" \
  "cd $repo && echo \"used \\\"\"" "cd $repo && echo \"sedan \\\"\"" "cd $repo && echo \$'it\\'s'"; do
  assert_allowed "single repo: a command without sed that shlex cannot split ($unparsed)" "$(guard_at "$repo" Bash "$unparsed")"
done
rm -rf "$repo"

# --- A single repo whose name other repos' paths share --------------------
# ~/.claude is such a root: every repo has a .claude directory, and a write to
# one is not a write to the root's main checkout.
base=$(mktemp -d)
repo="$base/.claude"
mkdir -p "$repo" "$base/other/.claude/hooks"
git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$repo" worktree add -q -b "$SLUG" "$repo/.claude/worktrees/$SLUG" >/dev/null 2>&1
assert_allowed "repo named like a shared dir: a relative write in another repo" "$(guard_at "$repo" Bash "git -C $base/other rm .claude/hooks/x.sh")"
assert_allowed "repo named like a shared dir: an absolute write in another repo" "$(guard_at "$repo" Bash "rm $base/other/.claude/hooks/x.sh")"
assert_blocked "repo named like a shared dir: an absolute write in its main checkout" "$(guard_at "$repo" Bash "rm $repo/bin/x")"
assert_blocked "repo named like a shared dir: a write in its main checkout through ~" "$(HOME=$base guard_at "$repo" Bash 'rm ~/.claude/bin/x')"
echo /.claude/handoffs/ >> "$repo/.git/info/exclude"
assert_allowed "repo named like a shared dir: an ignored write after cd through ~" "$(HOME=$base guard_at "$repo" Bash 'cd ~/.claude && cat >> .claude/handoffs/x.md')"
assert_blocked "repo named like a shared dir: an in-place edit after a cd the guard cannot resolve" "$(HOME=$base guard_at "$repo" Bash 'cd ~/.claude && sed -i s/a/b/ bin/x')"
rm -rf "$base"

# --- A workspace root that is itself a repo -------------------------------
# The root ignores the nested repos it holds; a file in one is tracked or
# ignored by the nested repo alone.
repo=$(mktemp -d)
mkdir "$repo/acme-backend"
for dir in "$repo" "$repo/acme-backend"; do
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$dir" worktree add -q -b "$SLUG" "$dir/.claude/worktrees/$SLUG" >/dev/null 2>&1
done
echo /acme-backend/ >> "$repo/.git/info/exclude"
echo /plans/ >> "$repo/acme-backend/.git/info/exclude"
assert_blocked "root repo: a tracked file of a nested repo the root ignores" "$(guard_at "$repo" Write "$repo/acme-backend/app/x.rb")"
assert_allowed "root repo: a file the nested repo ignores" "$(guard_at "$repo" Write "$repo/acme-backend/plans/x.md")"
rm -rf "$repo"

[ "$fails" -eq 0 ] && echo "worktree-guard: all assertions passed"
exit "$fails"
