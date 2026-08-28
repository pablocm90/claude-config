#!/usr/bin/env bash
# Behaviour tests for serve configuration: what `claude-dev serve` starts in a
# worktree, and which ports it treats as workspace-global. Both must be
# answerable by a project that is neither Rails nor yarn.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0

assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected '$3', got '$2'"; fails=$((fails + 1)); }
}
assert_status() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected exit $3, got $2"; fails=$((fails + 1)); }
}

# Hermetic: no TMUX, and a no-op tmux on PATH so an unrecognised subcommand
# falling through to the hub cannot spawn a session on the developer's machine.
stub=$(mktemp -d); printf '#!/bin/sh\nexit 0\n' > "$stub/tmux"; chmod +x "$stub/tmux"

out() { (unset TMUX TMUX_PANE; PATH="$stub:$PATH" CLAUDE_DEV_ROOT="$1" bash "$CD" "${@:2}" 2>/dev/null); }
status() { (unset TMUX TMUX_PANE; PATH="$stub:$PATH" CLAUDE_DEV_ROOT="$1" bash "$CD" "${@:2}" >/dev/null 2>&1; echo "$?"); }

tmp=$(mktemp -d)

# --- serve-cmd: detection is the zero-config default ------------------------
rails="$tmp/api"; mkdir -p "$rails/bin"; touch "$rails/bin/rails"; chmod +x "$rails/bin/rails"
assert_eq "a rails checkout starts rails" "$(out "$tmp" serve-cmd "$rails")" "bin/rails s"

node="$tmp/web"; mkdir -p "$node"; touch "$node/package.json"
assert_eq "a node checkout starts yarn" "$(out "$tmp" serve-cmd "$node")" "yarn start"

# --- serve-cmd: config is what makes the tool portable ----------------------
py="$tmp/svc"; mkdir -p "$py/.claude"
assert_status "an unrecognised stack has no command" "$(status "$tmp" serve-cmd "$py")" 1
echo 'uv run fastapi dev --port 8000' > "$py/.claude/serve"
assert_eq "a configured command needs no detection" \
  "$(out "$tmp" serve-cmd "$py")" "uv run fastapi dev --port 8000"

mkdir -p "$rails/.claude"
printf '# what this repo serves\n\nbin/rails s -p 3000 -b 0.0.0.0\n' > "$rails/.claude/serve"
assert_eq "config overrides detection, past comments and blanks" \
  "$(out "$tmp" serve-cmd "$rails")" "bin/rails s -p 3000 -b 0.0.0.0"

# The pane sits in the worktree, but the config was written once in the repo.
wt="$rails/.claude/worktrees/some-slug"; mkdir -p "$wt/bin"; touch "$wt/bin/rails"; chmod +x "$wt/bin/rails"
assert_eq "a worktree inherits its repo's command" \
  "$(out "$tmp" serve-cmd "$wt")" "bin/rails s -p 3000 -b 0.0.0.0"

# --- cmd_serve itself must survive `set -u` ---------------------------------
# The ports are resolved in the same function that expands them; when the two
# drifted apart, serve died on an unbound variable before reaching any pane.
# Use a port nobody serves on: `serve` KILLS whatever holds the workspace ports.
safe="$tmp/safe-ws"; mkdir -p "$safe/.claude"; echo 59999 > "$safe/.claude/ports"
err() { (unset TMUX TMUX_PANE; PATH="$stub:$PATH" CLAUDE_DEV_ROOT="$safe" bash "$CD" "$@") 2>&1 >/dev/null; }

serve_err=$(err serve some-slug)
case "$serve_err" in
  *"nothing started"*) ;;
  *) echo "FAIL: serve must reach its own error, got: $serve_err"; fails=$((fails + 1)) ;;
esac
case "$serve_err" in
  *"unbound variable"*|*"command not found"*|*": line "*)
    echo "FAIL: serve died on a shell error, not a domain one"; fails=$((fails + 1)) ;;
esac
assert_eq "serve --stop completes" "$(out "$safe" serve --stop some-slug)" "servers stopped"

# --- serve-ports: the workspace-global ports are not universally 3000/4000 --
assert_eq "ports default to the historical pair" "$(out "$tmp" serve-ports)" "3000 4000"

mkdir -p "$tmp/.claude"
printf '# this workspace serves elsewhere\n8000\n8080\n' > "$tmp/.claude/ports"
assert_eq "configured ports replace the default" "$(out "$tmp" serve-ports)" "8000 8080"

printf '5173, 4000\n' > "$tmp/.claude/ports"
assert_eq "any separator reads as a port list" "$(out "$tmp" serve-ports)" "5173 4000"

rm -rf "$tmp" "$stub"
[ "$fails" -eq 0 ] && echo "serve-config: all assertions passed"
exit "$fails"
