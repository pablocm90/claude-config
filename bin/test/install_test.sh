#!/usr/bin/env bash
# Behaviour tests for `bin/install`: wiring this checkout into a machine. The
# script is idempotent by contract — it is run on a fresh machine and again on
# one already set up — so every check here runs it twice and asserts the second
# run reports rather than repeats.
set -uo pipefail

INSTALL="$(cd "$(dirname "$0")/.." && pwd)/install"
fails=0

assert_reports() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL: $1 — expected a report of '$3', got: $2"; fails=$((fails + 1)) ;;
  esac
}
assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected '$3', got '$2'"; fails=$((fails + 1)); }
}
assert_silent_about() {
  case "$2" in
    *"$3"*) echo "FAIL: $1 — expected no mention of '$3', got: $2"; fails=$((fails + 1)) ;;
  esac
}

# Hermetic: HOME points at a scratch dir, because install wires symlinks into
# the home directory and must never reach the developer's own while testing.
tmp=$(mktemp -d)
home="$tmp/home"; mkdir -p "$home"

# A checkout as `git clone` leaves it: the guard's hooks are present, but
# nothing about this machine has been wired yet.
checkout() {
  local r="$tmp/$1"
  mkdir -p "$r/.githooks"
  git init -q "$r"
  printf '%s' "$r"
}
run() { (HOME="$home" CLAUDE_CONFIG_ROOT="$1" bash "$INSTALL" "${@:2}" 2>&1); }

# --- the commit guard -------------------------------------------------------
# This repo is public and a hook refuses any commit carrying a client name or a
# credential — but only once core.hooksPath points at it. Nothing enforces the
# setting, so a fresh clone commits with no guard at all and says nothing.
r=$(checkout guard)
assert_reports "an unset guard is wired" "$(run "$r")" "commit guard"
assert_eq "and core.hooksPath lands on the hooks" \
  "$(git -C "$r" config --local core.hooksPath)" ".githooks"

assert_reports "a second run reports it already wired" "$(run "$r")" "already"
assert_silent_about "and does not claim to have wired anything" \
  "$(run "$r")" "now .githooks"
assert_eq "and leaves the setting alone" \
  "$(git -C "$r" config --local core.hooksPath)" ".githooks"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "install: all assertions passed"
exit "$fails"
