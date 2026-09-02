#!/usr/bin/env bash
# Behaviour tests for the statusline's configuration surface. Which segments
# the line carries is a per-machine preference, so it is read from an
# untracked ~/.claude/statusline.conf rather than from the tracked checkout.
set -uo pipefail

SL="$(cd "$(dirname "$0")/.." && pwd)/statusline"
fails=0

assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1"; echo "  expected: $3"; echo "  actual:   $2"; fails=$((fails + 1)); }
}
assert_contains() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL: $1 — expected to contain '$3', got: $2"; fails=$((fails + 1)) ;;
  esac
}

tmp=$(mktemp -d)
home="$tmp/home"; mkdir -p "$home/.claude"

# resets_at 0 is always past, so the countdown reads "now" and never drifts.
session() {
  jq -cn '{
    rate_limits: { five_hour: { used_percentage: 42, resets_at: 0 },
                   seven_day: { used_percentage: 8,  resets_at: 0 } },
    context_window: { used_percentage: 73 },
    model:    { display_name: "Opus 5 (1M context)" },
    effort:   { level: "high" },
    thinking: { enabled: true },
    workspace: { current_dir: "/src/project" },
    pr: { number: 42 },
    transcript_path: "-"
  }'
}
conf()  { printf '%b' "$1" > "$home/.claude/statusline.conf"; }
noconf() { rm -f "$home/.claude/statusline.conf"; }
plain() { HOME="$home" bash "$SL" <<<"$(session)" | sed 's/\x1b\[[0-9;]*m//g'; }

# --- no config is the line as it has always been ----------------------------
noconf
assert_eq "an unconfigured machine keeps the whole line" "$(plain)" \
  "5h ▰▰▰▱▱ 42% ⟳now │ 7d ▰▱▱▱▱ 8% ⟳now │ ctx 73% │ Opus 5·high·think │ project #42"

# --- segments selects, and the order it lists is the order shown ------------
conf 'segments ctx model\n'
assert_eq "only the named segments are built" "$(plain)" "ctx 73% │ Opus 5·high·think"

conf 'segments model ctx\n'
assert_eq "and they come in the order they were named" "$(plain)" \
  "Opus 5·high·think │ ctx 73%"

# Comments and blank lines are the house style for these little config files.
conf '# what I want to see\n\nsegments where\n'
assert_eq "comments and blanks are skipped" "$(plain)" "project #42"

conf 'segments where  # and nothing else\n'
assert_eq "a comment after the names is not read as names" "$(plain)" "project #42"

# A directive naming nothing leaves the default alone rather than blanking the
# line — an empty statusline looks identical to a broken one.
conf 'segments\n'
assert_contains "an empty segments line falls back" "$(plain)" "ctx 73%"

# --- a name nothing answers to ----------------------------------------------
# A typo would otherwise drop a segment silently, and a missing segment is
# indistinguishable from one whose data was absent this turn.
conf 'segments ctx cxt\n'
assert_contains "an unknown segment is visible, not dropped" "$(plain)" "?cxt"
assert_contains "and the segments around it still render" "$(plain)" "ctx 73%"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "statusline: all assertions passed"
exit "$fails"
