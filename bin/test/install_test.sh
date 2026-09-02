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
assert_status() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected exit $3, got $2"; fails=$((fails + 1)); }
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
  printf '{ "skillOverrides": { "diagrams": "off" } }\n' > "$m/checkout/settings.json"
  git init -q "$m/checkout"
  printf '%s' "$m"
}
run() { (HOME="$1/home" CLAUDE_CONFIG_ROOT="$1/checkout" bash "$INSTALL" "${@:2}" 2>&1); }
run_status() { (HOME="$1/home" CLAUDE_CONFIG_ROOT="$1/checkout" bash "$INSTALL" "${@:2}" >/dev/null 2>&1; echo "$?"); }

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

# --- skills turned off ------------------------------------------------------
# settings.json ships with a few skills off. That is a preference rather than
# a wiring fault, but it is invisible: nothing announces that `diagrams` will
# not load, and the answer lives in a file you have no reason to open.
sk=$(machine skills)
printf '{ "skillOverrides": { "diagrams": "off", "testing": "on", "find-skills": "off" } }\n' \
  > "$sk/checkout/settings.json"
assert_reports "a skill turned off is named" "$(run "$sk")" "diagrams"
assert_reports "and so is the next one" "$(run "$sk")" "find-skills"
assert_silent_about "while one left on is not" "$(run "$sk")" "testing"

# install is what runs on a fresh machine, so the reader it needs may not be
# there yet. Saying so beats dying with half the machine wired.
nojq="$tmp/nojq"; mkdir -p "$nojq"
for c in bash git ln mkdir readlink rm cat sed; do
  ln -s "$(command -v "$c")" "$nojq/$c" 2>/dev/null || true
done
nojq_out() { (HOME="$1/home" CLAUDE_CONFIG_ROOT="$1/checkout" PATH="$nojq" bash "$INSTALL" 2>&1); }
nojq_status() { (HOME="$1/home" CLAUDE_CONFIG_ROOT="$1/checkout" PATH="$nojq" bash "$INSTALL" >/dev/null 2>&1; echo "$?"); }

# Assert the message install means to print, not the word "jq" — bash's own
# "jq: command not found" carries that too, and would pass with no guard here.
assert_reports "a machine without jq is told the reader is missing" \
  "$(nojq_out "$sk")" "jq is not installed"
assert_status "and the run still finishes cleanly" "$(nojq_status "$sk")" 0
assert_reports "having done everything that did not need jq" \
  "$(nojq_out "$sk")" "tmux.conf"

# Nothing turned off is a state worth naming, not an empty line to squint at.
none=$(machine all-skills-on)
printf '{ "skillOverrides": {} }\n' > "$none/checkout/settings.json"
assert_reports "a machine with nothing turned off says so" "$(run "$none")" "none"

# The same courtesy when the file itself is not there to read.
ns=$(machine no-settings); rm "$ns/checkout/settings.json"
assert_reports "a checkout with no settings.json says so" \
  "$(run "$ns")" "no settings.json"
assert_status "and still finishes cleanly" "$( (run "$ns" >/dev/null 2>&1); echo "$?" )" 0

# --- turning a skill on and off ---------------------------------------------
# The overrides live in settings.json, which is tracked, because that is the
# only user-level settings file Claude Code reads — ~/.claude/settings.local.json
# is not one, so a toggle written there would be gitignored and inert.
tg=$(machine toggle)
mkdir -p "$tg/checkout/skills/diagrams"
printf '{ "theme": "dark-daltonized", "skillOverrides": { "diagrams": "off" } }\n' \
  > "$tg/checkout/settings.json"

assert_reports "turning one on reports it" "$(run "$tg" --skill diagrams=on)" "diagrams"
assert_eq "and the override is gone, leaving the default" \
  "$(jq -r '.skillOverrides.diagrams // "absent"' "$tg/checkout/settings.json")" "absent"
assert_reports "a second run reports it already on" \
  "$(run "$tg" --skill diagrams=on)" "already on"
assert_eq "and the rest of settings.json survives the rewrite" \
  "$(jq -r .theme "$tg/checkout/settings.json")" "dark-daltonized"

assert_reports "turning it off reports it" "$(run "$tg" --skill diagrams=off)" "turned off"
assert_eq "and the override is recorded" \
  "$(jq -r .skillOverrides.diagrams "$tg/checkout/settings.json")" "off"

# A typo must not quietly record an override for a skill that does not exist:
# it would be gitignored by nothing, read by everything, and mean nothing.
assert_status "an unknown skill is refused" "$(run_status "$tg" --skill diagrmas=on)" 2
assert_reports "and said so" "$(run "$tg" --skill diagrmas=on)" "no skill named"
assert_status "a value that is neither on nor off is refused" \
  "$(run_status "$tg" --skill diagrams=yes)" 2
# --skill =on would otherwise pass the skills-directory check, because the
# skills directory itself exists, and record an override under an empty name.
assert_status "a --skill with no skill in it is refused" \
  "$(run_status "$tg" --skill =on)" 2
assert_eq "and nothing was written" \
  "$(jq -r .skillOverrides.diagrams "$tg/checkout/settings.json")" "off"

# settings.json is tracked, so a toggle has to diff only the toggle: a rewrite
# that reformatted the file would bury a one-line intent in whole-file noise.
fmt=$(machine format)
mkdir -p "$fmt/checkout/skills/diagrams"
cat > "$fmt/checkout/settings.json" <<'JSON'
{
  "theme": "dark-daltonized",
  "skillOverrides": {
    "diagrams": "off",
    "accessibility": "off"
  }
}
JSON
cp "$fmt/checkout/settings.json" "$fmt/before.json"
run "$fmt" --skill diagrams=on >/dev/null
assert_eq "a toggle changes exactly one line of settings.json" \
  "$(diff "$fmt/before.json" "$fmt/checkout/settings.json" | grep -c '^[<>]')" "1"
assert_eq "and the skill beside it is untouched" \
  "$(jq -r .skillOverrides.accessibility "$fmt/checkout/settings.json")" "off"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "install: all assertions passed"
exit "$fails"
