#!/usr/bin/env bash
# Behaviour tests for `claude-dev doctor`: the workspace contract the rest of
# the tool assumes. Every fact it checks fails silently in normal use — an
# unmarked root, an invisible repo, an unignored worktree directory. None of
# them raises an error anywhere; they just leave the tool behaving oddly.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0

assert_reports() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL: $1 — expected a report of '$3', got: $2"; fails=$((fails + 1)) ;;
  esac
}
assert_silent_about() {
  case "$2" in
    *"$3"*) echo "FAIL: $1 — expected no mention of '$3', got: $2"; fails=$((fails + 1)) ;;
  esac
}
assert_status() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected exit $3, got $2"; fails=$((fails + 1)); }
}

# Hermetic: no TMUX, and a no-op tmux on PATH so an unrecognised subcommand
# falling through to the hub cannot spawn a session on the developer's machine.
# HOME and XDG_CONFIG_HOME point at that same empty dir so a global gitignore
# on the developer's machine cannot answer the ignore checks on a repo's behalf.
# The cwd is pinned too: doctor runs git against the repos it finds, and an
# invoking cwd that happens to be a repo can answer in their place.
stub=$(mktemp -d); printf '#!/bin/sh\nexit 0\n' > "$stub/tmux"; chmod +x "$stub/tmux"

env_of() { unset TMUX TMUX_PANE; export PATH="$stub:$PATH" HOME="$stub" XDG_CONFIG_HOME="$stub"; cd "$stub"; }
out() { (env_of; CLAUDE_DEV_ROOT="$1" bash "$CD" "${@:2}" 2>&1); }
status() { (env_of; CLAUDE_DEV_ROOT="$1" bash "$CD" "${@:2}" >/dev/null 2>&1; echo "$?"); }

# A repo wired the way doctor expects: discoverable, and ignoring its own
# worktrees. Each workspace below breaks exactly one of those, so the finding
# count it reports stays legible.
wired_repo() {
  git init -q "$1"
  git -C "$1" remote add origin "git@example.com:o/$(basename "$1").git"
  printf '.claude/worktrees/\n' > "$1/.gitignore"
}

tmp=$(mktemp -d)

# --- the root marker --------------------------------------------------------
# hoist_root keys the whole workspace on a CLAUDE.md beside the repos. Without
# it a task window silently operates on the repo instead of the workspace.
bare="$tmp/unmarked"; mkdir -p "$bare"
assert_reports "a root without CLAUDE.md is named" "$(out "$bare" doctor)" "CLAUDE.md"
assert_reports "with a remedy beside it" "$(out "$bare" doctor)" "fix:"
assert_status "and doctor reports failure" "$(status "$bare" doctor)" 1

wired="$tmp/marked"; mkdir -p "$wired"; touch "$wired/CLAUDE.md"
assert_silent_about "a marked root raises nothing" "$(out "$wired" doctor)" "CLAUDE.md"
assert_reports "and says so, rather than passing in silence" "$(out "$wired" doctor)" "wired"
assert_reports "and names the root it diagnosed, which hoisting can move" \
  "$(out "$wired" doctor)" "$wired"
assert_status "and doctor reports success" "$(status "$wired" doctor)" 0

# --- repo discoverability ---------------------------------------------------
# list_repos counts a subdirectory only when it carries an origin remote. A
# repo without one is not flagged as misconfigured anywhere — it is simply
# absent from every listing, and `claude-dev task` cannot cut a worktree in it.
ws="$tmp/ws"; mkdir -p "$ws"; touch "$ws/CLAUDE.md"
wired_repo "$ws/api"
wired_repo "$ws/web"; git -C "$ws/web" remote remove origin

assert_reports "a remote-less repo is named" "$(out "$ws" doctor)" "web"
assert_silent_about "a discoverable repo is not" "$(out "$ws" doctor)" "api"
assert_reports "and offers a remedy, not just a verdict" "$(out "$ws" doctor)" "fix:"
assert_status "and doctor reports failure" "$(status "$ws" doctor)" 1

# A repo whose path prefixes a discoverable one must not inherit its visibility.
pfx="$tmp/pfx"; mkdir -p "$pfx"; touch "$pfx/CLAUDE.md"
wired_repo "$pfx/web-admin"
wired_repo "$pfx/web"; git -C "$pfx/web" remote remove origin
assert_reports "a prefix of a discoverable repo is still reported" \
  "$(out "$pfx" doctor)" "$pfx/web has no origin"

# --- worktrees are gitignored -----------------------------------------------
# `task` cuts worktrees at <repo>/.claude/worktrees/<slug>. A repo that does
# not ignore that path reports every worktree as untracked, in every status the
# developer reads, forever. Both pattern spellings must satisfy the check: a
# trailing slash matches paths inside the directory, never the directory itself.
ign="$tmp/ign"; mkdir -p "$ign"; touch "$ign/CLAUDE.md"
wired_repo "$ign/slash"
wired_repo "$ign/bare"; printf '.claude/worktrees\n' > "$ign/bare/.gitignore"
wired_repo "$ign/none"; rm "$ign/none/.gitignore"

assert_reports "a repo ignoring nothing is named" \
  "$(out "$ign" doctor)" "$ign/none does not ignore"
assert_silent_about "a trailing-slash pattern satisfies it" \
  "$(out "$ign" doctor)" "$ign/slash does not ignore"
assert_silent_about "and so does a bare pattern" \
  "$(out "$ign" doctor)" "$ign/bare does not ignore"
assert_reports "and the remedy names the pattern to add" \
  "$(out "$ign" doctor)" "fix:"
assert_status "and doctor reports failure" "$(status "$ign" doctor)" 1

rm -rf "$tmp" "$stub"
[ "$fails" -eq 0 ] && echo "doctor: all assertions passed"
exit "$fails"
