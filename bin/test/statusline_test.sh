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
export TMPDIR="$tmp"   # the turn-time cache keys on the transcript

# resets_at 0 is always past, so the countdown reads "now" and never drifts.
session() {
  jq -cn --arg tx "${1:--}" '{
    rate_limits: { five_hour: { used_percentage: 42, resets_at: 0 },
                   seven_day: { used_percentage: 8,  resets_at: 0 } },
    context_window: { used_percentage: 73 },
    model:    { display_name: "Opus 5 (1M context)" },
    effort:   { level: "high" },
    thinking: { enabled: true },
    workspace: { current_dir: "/src/project" },
    pr: { number: 42 },
    transcript_path: $tx
  }'
}
conf()  { printf '%b' "$1" > "$home/.claude/statusline.conf"; }
noconf() { rm -f "$home/.claude/statusline.conf"; }
raw()   { HOME="$home" bash "$SL" <<<"$(session "${1:-}")"; }
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

# --- the colour ramp --------------------------------------------------------
# Four colours, lowest band first. The default is daltonised on purpose, so a
# machine that reads colour differently is exactly who needs to change it.
conf 'segments ctx\nramp black red green yellow\n'
assert_contains "the top-but-one band takes the third colour named" \
  "$(raw)" "$(printf '\033[32m73%%')"

# One palette serves both ramps: the percentage one and the turn timer's.
tx="$tmp/spread.jsonl"
printf '%s\n' \
  '{"type":"user","promptId":"p1","timestamp":"2026-01-01T00:00:00.000Z"}' \
  '{"type":"assistant","timestamp":"2026-01-01T00:00:10.000Z"}' \
  '{"type":"user","promptId":"p2","timestamp":"2026-01-01T00:01:40.000Z"}' \
  '{"type":"assistant","timestamp":"2026-01-01T00:05:00.000Z"}' > "$tx"
conf 'segments turns\nramp black red green yellow\n'
assert_contains "and the turn timer draws from the same four" \
  "$(raw "$tx")" "$(printf '\033[32m3m20')"

# A ramp that cannot be read leaves the default standing rather than painting
# something arbitrary — the whole ramp reverting is what makes it noticeable.
conf 'segments ctx\nramp black red green\n'
assert_contains "three colours is not a ramp" "$(raw)" "$(printf '\033[33m73%%')"
conf 'segments ctx\nramp black red green chartreuse\n'
assert_contains "nor is one naming a colour nothing knows" \
  "$(raw)" "$(printf '\033[33m73%%')"

conf 'segments ctx\nramp black red green yellow chartreuse\n'
assert_contains "nor is one naming five, four of which are real" \
  "$(raw)" "$(printf '\033[33m73%%')"

# A directive is matched whole. Reading the first line that merely starts with
# a known name would hand the ramp whatever some future directive happens to
# say, which is the failure that only shows up long after it is introduced.
conf 'ramping black red green yellow\nsegments ctx\n'
assert_contains "a longer directive name is not the directive" \
  "$(raw)" "$(printf '\033[33m73%%')"

# --- explaining itself ------------------------------------------------------
# Anything else that wants to know what the statusline will do has to ask it,
# rather than parse this file a second time and drift. Fed no session at all:
# what it resolved does not depend on one.
explain() { HOME="$home" bash "$SL" --explain </dev/null; }

noconf
assert_eq "explains the default segments" "$(explain | grep '^segments')" \
  "segments 5h 7d ctx turns model where"
assert_eq "explains the default ramp" "$(explain | grep '^ramp')" "ramp 34 36 33 35"

conf 'segments ctx model\nramp black red green yellow\n'
assert_eq "explains configured segments" "$(explain | grep '^segments')" "segments ctx model"
assert_eq "explains a configured ramp as the codes it will use" \
  "$(explain | grep '^ramp')" "ramp 30 31 32 33"

# The directive it could not use is the whole point: statusline falls back in
# silence, and silence is what something else has to be able to see.
conf 'segments ctx\nramp black red green chartreuse\n'
assert_contains "names a directive it fell back on" "$(explain)" "ignored ramp"
assert_eq "and reports the ramp actually in force" "$(explain | grep '^ramp')" "ramp 34 36 33 35"

conf 'segments ctx\nramp black red green yellow\n'
assert_eq "with nothing ignored, it says nothing about it" \
  "$(explain | grep -c '^ignored')" "0"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "statusline: all assertions passed"
exit "$fails"
