#!/usr/bin/env bash
# Behaviour tests for `claude-dev doctor`: the workspace contract the rest of
# the tool assumes. Every one of these facts fails silently in normal use —
# a missing marker or an undiscoverable repo produces no error, just a tool
# that quietly operates on the wrong directory. Doctor is where they speak.
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
stub=$(mktemp -d); printf '#!/bin/sh\nexit 0\n' > "$stub/tmux"; chmod +x "$stub/tmux"

out() { (unset TMUX TMUX_PANE; PATH="$stub:$PATH" CLAUDE_DEV_ROOT="$1" bash "$CD" "${@:2}" 2>&1); }
status() { (unset TMUX TMUX_PANE; PATH="$stub:$PATH" CLAUDE_DEV_ROOT="$1" bash "$CD" "${@:2}" >/dev/null 2>&1; echo "$?"); }

tmp=$(mktemp -d)

# --- the root marker --------------------------------------------------------
# hoist_root keys the whole workspace on a CLAUDE.md beside the repos. Without
# it a task window silently operates on the repo instead of the workspace.
bare="$tmp/unmarked"; mkdir -p "$bare"
assert_reports "a root without CLAUDE.md is named" "$(out "$bare" doctor)" "CLAUDE.md"
assert_status "and doctor reports failure" "$(status "$bare" doctor)" 1

wired="$tmp/marked"; mkdir -p "$wired"; touch "$wired/CLAUDE.md"
assert_silent_about "a marked root raises nothing" "$(out "$wired" doctor)" "CLAUDE.md"
assert_reports "and says so, rather than passing in silence" "$(out "$wired" doctor)" "wired"
assert_reports "and names the root it diagnosed, which hoisting can move" \
  "$(out "$wired" doctor)" "$wired"
assert_status "and doctor reports success" "$(status "$wired" doctor)" 0

rm -rf "$tmp" "$stub"
[ "$fails" -eq 0 ] && echo "doctor: all assertions passed"
exit "$fails"
