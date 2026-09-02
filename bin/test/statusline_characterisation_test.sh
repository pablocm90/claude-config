#!/usr/bin/env bash
# CHARACTERISATION TESTS — these document what bin/statusline actually does,
# not what it ought to do. They exist because the statusline is about to grow a
# configuration surface (which segments show, which colours the ramp uses) and
# it has never had a test. They detect change; they assert nothing about
# correctness. Replace them with behaviour tests as the config surface lands.
set -uo pipefail

SL="$(cd "$(dirname "$0")/.." && pwd)/statusline"
fails=0

# The turn-time cache keys on the transcript, so keep it out of the real one.
tmp=$(mktemp -d); export TMPDIR="$tmp"

assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1"; echo "  expected: $3"; echo "  actual:   $2"; fails=$((fails + 1)); }
}
assert_contains() {
  case "$2" in
    *"$3"*) ;;
    *) echo "FAIL: $1 — expected to contain $(printf '%q' "$3"), got $(printf '%q' "$2")"
       fails=$((fails + 1)) ;;
  esac
}

# A session as Claude Code feeds it in, with any part overridden by a JSON
# fragment. resets_at 0 is always in the past, so the countdown reads "now"
# rather than drifting with the clock.
session() {
  local o=${1:-}; [ -n "$o" ] || o='{}'
  jq -cn --argjson o "$o" '{
    rate_limits: { five_hour: { used_percentage: 42, resets_at: 0 },
                   seven_day: { used_percentage: 8,  resets_at: 0 } },
    context_window: { used_percentage: 73 },
    model:    { display_name: "Opus 5 (1M context)" },
    effort:   { level: "high" },
    thinking: { enabled: true },
    workspace: { current_dir: "/src/project" },
    pr: { number: 42 },
    transcript_path: "-"
  } * $o'
}
raw()   { bash "$SL" <<<"$(session "${1:-}")"; }
plain() { raw "${1:-}" | sed 's/\x1b\[[0-9;]*m//g'; }

# --- the segments, and the order they come in -------------------------------
assert_eq "characterises a full line" "$(plain)" \
  "5h ▰▰▰▱▱ 42% ⟳now │ 7d ▰▱▱▱▱ 8% ⟳now │ ctx 73% │ Opus 5·high·think │ project #42"

# Anything the session does not carry drops its segment rather than showing a
# placeholder — the line is built from whichever parts answered.
assert_eq "characterises a session with no rate limits" \
  "$(plain '{"rate_limits":null}')" "ctx 73% │ Opus 5·high·think │ project #42"
assert_eq "characterises a session with no PR and no effort" \
  "$(plain '{"pr":null,"effort":null,"thinking":{"enabled":false}}')" \
  "5h ▰▰▰▱▱ 42% ⟳now │ 7d ▰▱▱▱▱ 8% ⟳now │ ctx 73% │ Opus 5 │ project"

# A worktree names the segment when there is one; otherwise it is the last
# path component of the working directory.
assert_eq "characterises a worktree taking over the location" \
  "$(plain '{"workspace":{"git_worktree":"fix-timezone"}}')" \
  "5h ▰▰▰▱▱ 42% ⟳now │ 7d ▰▱▱▱▱ 8% ⟳now │ ctx 73% │ Opus 5·high·think │ fix-timezone #42"

# The parenthesised suffix is stripped from the model name.
assert_contains "characterises the model suffix being dropped" "$(plain)" "Opus 5·high"

# A shape jq cannot read paints nothing at all rather than a broken line.
assert_eq "characterises unreadable input" "$(bash "$SL" <<<'not json')" ""

# --- the colour ramp --------------------------------------------------------
# Daltonised: blue → cyan → yellow → magenta, thresholds at 40 / 70 / 90, and
# deliberately no red/green axis.
ctx_at() { raw "{\"context_window\":{\"used_percentage\":$1}}"; }
hue_is() { assert_contains "characterises $3 at $2" "$(ctx_at "$2")" "$(printf "\033[%sm%s%%" "$1" "$2")"; }
# Each threshold is pinned from both sides: pinning only the value at the
# boundary leaves it free to move downwards without any test noticing.
hue_is 34 39 blue
hue_is 36 40 cyan
hue_is 36 69 cyan
hue_is 33 70 yellow
hue_is 33 89 yellow
hue_is 35 90 magenta

# --- the turn timer ---------------------------------------------------------
# Two answered prompts, thirty seconds and ninety. The line shows the last and
# the mean, which only differ once there is more than one turn to average —
# and its position, between ctx and the model, is only visible when it renders.
tx="$tmp/transcript.jsonl"
printf '%s\n' \
  '{"type":"user","promptId":"p1","timestamp":"2026-01-01T00:00:00.000Z"}' \
  '{"type":"assistant","timestamp":"2026-01-01T00:00:30.000Z"}' \
  '{"type":"user","promptId":"p2","timestamp":"2026-01-01T00:01:40.000Z"}' \
  '{"type":"assistant","timestamp":"2026-01-01T00:03:10.000Z"}' > "$tx"
assert_eq "characterises a line carrying turn times" \
  "$(plain "$(jq -cn --arg t "$tx" '{transcript_path:$t}')")" \
  "5h ▰▰▰▱▱ 42% ⟳now │ 7d ▰▱▱▱▱ 8% ⟳now │ ctx 73% │ ⏱ 1m30 ⌀ 1m00 │ Opus 5·high·think │ project #42"

# The timer is coloured by the last turn, not the average of them: ten
# seconds then two hundred puts the two in different bands of the ramp.
tx2="$tmp/spread.jsonl"
printf '%s\n' \
  '{"type":"user","promptId":"p1","timestamp":"2026-01-01T00:00:00.000Z"}' \
  '{"type":"assistant","timestamp":"2026-01-01T00:00:10.000Z"}' \
  '{"type":"user","promptId":"p2","timestamp":"2026-01-01T00:01:40.000Z"}' \
  '{"type":"assistant","timestamp":"2026-01-01T00:05:00.000Z"}' > "$tx2"
assert_contains "characterises the timer taking its colour from the last turn" \
  "$(raw "$(jq -cn --arg t "$tx2" '{transcript_path:$t}')")" "$(printf '\033[33m3m20')"

# Two and a half minutes sits between the 1m and 3m thresholds, which is the
# only place a move in either of them shows.
tx3="$tmp/midband.jsonl"
printf '%s\n' \
  '{"type":"user","promptId":"p1","timestamp":"2026-01-01T00:00:00.000Z"}' \
  '{"type":"assistant","timestamp":"2026-01-01T00:02:30.000Z"}' > "$tx3"
assert_contains "characterises the band between one and three minutes" \
  "$(raw "$(jq -cn --arg t "$tx3" '{transcript_path:$t}')")" "$(printf '\033[36m2m30')"

# --- the bar ----------------------------------------------------------------
# Five cells, filled by rounding up, so any non-zero usage shows at least one.
bar_at() { plain "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":$1,\"resets_at\":0}}}"; }
assert_contains "characterises an empty bar at zero"  "$(bar_at 0)"   "5h ▱▱▱▱▱ 0%"
assert_contains "characterises rounding up from 1"    "$(bar_at 1)"   "5h ▰▱▱▱▱ 1%"
assert_contains "characterises a full bar at 100"     "$(bar_at 100)" "5h ▰▰▰▰▰ 100%"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "statusline characterisation: all assertions passed"
exit "$fails"
