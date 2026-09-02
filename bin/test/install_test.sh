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
assert_silent_about() {
  case "$2" in
    *"$3"*) echo "FAIL: $1 — expected no mention of '$3', got: $2"; fails=$((fails + 1)) ;;
  esac
}
assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected '$3', got '$2'"; fails=$((fails + 1)); }
}

tmp=$(mktemp -d)

# A machine as install finds it before running: an empty home, and a checkout
# as `git clone` leaves it — the hooks and the tools are there, but nothing on
# the machine has been wired to them. Each block below takes its own, because
# install's whole subject is state that accumulates in a home directory.
machine() {
  local m="$tmp/$1" t
  mkdir -p "$m/home" "$m/checkout/.githooks" "$m/checkout/bin" "$m/checkout/dotfiles"
  printf 'set -g prefix C-a\n' > "$m/checkout/dotfiles/tmux.conf"
  for t in claude-dev claude-dev-review claude-dev-status; do
    printf '#!/bin/sh\n' > "$m/checkout/bin/$t"
  done
  git init -q "$m/checkout"
  printf '%s' "$m"
}
run() { (HOME="$1/home" CLAUDE_CONFIG_ROOT="$1/checkout" bash "$INSTALL" "${@:2}" 2>&1); }

# --- the commit guard -------------------------------------------------------
# This repo is public and a hook refuses any commit carrying a client name or a
# credential — but only once core.hooksPath points at it. Nothing enforces the
# setting, so a fresh clone commits with no guard at all and says nothing.
g=$(machine guard)
assert_reports "an unset guard is wired" "$(run "$g")" "commit guard"
assert_eq "and core.hooksPath lands on the hooks" \
  "$(git -C "$g/checkout" config --local core.hooksPath)" ".githooks"

assert_reports "a second run reports it already wired" "$(run "$g")" "already"
assert_silent_about "and does not claim to have wired anything" \
  "$(run "$g")" "now .githooks"
assert_eq "and leaves the setting alone" \
  "$(git -C "$g/checkout" config --local core.hooksPath)" ".githooks"

# --- the tools on PATH ------------------------------------------------------
# claude-dev and its two companions are invoked by name — from a shell, from
# the tmux bindings, from Claude. Nothing else finds them, so a clone that was
# never linked answers "command not found" and nothing explains why.
b=$(machine bins)
assert_reports "the directory they went to is stated once" "$(run "$b")" "bin dir"
assert_reports "the tools are linked" "$(run "$b")" "claude-dev-review"
assert_eq "and the link resolves into the checkout" \
  "$(readlink -f "$b/home/.local/bin/claude-dev")" \
  "$(readlink -f "$b/checkout/bin/claude-dev")"
assert_reports "a second run reports them already linked" "$(run "$b")" "already linked"

# Whatever is already on the machine outranks this checkout: a name that is
# taken is reported and left, never replaced.
c=$(machine clash)
mkdir -p "$c/home/.local/bin"
printf 'someone else\n' > "$c/home/.local/bin/claude-dev-status"
assert_reports "a name already taken is named" "$(run "$c")" "not ours"
assert_eq "and what was there survives" \
  "$(cat "$c/home/.local/bin/claude-dev-status")" "someone else"
assert_reports "while its companions still get linked" "$(run "$c")" "claude-dev-review"

# A link left behind by an older checkout at a different path is not ours
# either. Taking a symlink on trust because of its name would report a wired
# machine that runs whatever the old path holds.
s=$(machine stale)
mkdir -p "$s/home/.local/bin"
ln -s "$tmp/older/bin/claude-dev" "$s/home/.local/bin/claude-dev"
assert_silent_about "a link into another checkout is not taken for ours" \
  "$(run "$s")" "already linked"
assert_reports "it is named instead" "$(run "$s")" "not ours"
assert_eq "and left pointing where it pointed" \
  "$(readlink "$s/home/.local/bin/claude-dev")" "$tmp/older/bin/claude-dev"

# --- the tmux config --------------------------------------------------------
# The prefix, the review popup, the serve button and the window tabs all live
# in dotfiles/tmux.conf, and none of them exist until ~/.tmux.conf points at
# it. tmux reports no error for a config it was never told about.
tc=$(machine tmux)
assert_reports "the home it is linked into is stated" "$(run "$tc")" "home:"
assert_reports "an absent config is linked" "$(run "$tc")" "tmux.conf"
assert_eq "and resolves into the checkout" \
  "$(readlink -f "$tc/home/.tmux.conf")" \
  "$(readlink -f "$tc/checkout/dotfiles/tmux.conf")"
assert_reports "a second run reports it already linked" "$(run "$tc")" "already linked"

# Someone else's tmux config is theirs. Replacing it to install a prefix key
# would be the rudest thing this script could do, so it names the one line
# that adds ours on top and stops there.
own=$(machine own-tmux)
printf 'set -g mouse off\n' > "$own/home/.tmux.conf"
assert_reports "an existing config is left alone" "$(run "$own")" "not ours"
assert_reports "and the line that adds ours is printed" \
  "$(run "$own")" "source $own/checkout/dotfiles/tmux.conf"
assert_eq "and their config survives" \
  "$(cat "$own/home/.tmux.conf")" "set -g mouse off"

# A ~/.tmux.conf symlinked into the machine owner's own dotfiles repo is the
# usual arrangement, and it is still theirs — a symlink is not ours because it
# is a symlink, only because of where it resolves.
sym=$(machine sym-tmux)
mkdir -p "$sym/home/dotfiles"
printf 'set -g mouse off\n' > "$sym/home/dotfiles/tmux.conf"
ln -s "$sym/home/dotfiles/tmux.conf" "$sym/home/.tmux.conf"
assert_silent_about "a link into their own dotfiles is not taken for ours" \
  "$(run "$sym")" "already linked"
assert_reports "it is named instead" "$(run "$sym")" "not ours"
assert_eq "and still points at their file" \
  "$(readlink "$sym/home/.tmux.conf")" "$sym/home/dotfiles/tmux.conf"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "install: all assertions passed"
exit "$fails"
