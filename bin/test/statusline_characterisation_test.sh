#!/usr/bin/env bash
# CHARACTERISATION TESTS — these document what bin/statusline actually does,
# not what it ought to do. They exist because the statusline is about to grow a
# configuration surface (which segments show, which colours the ramp uses) and
# it has never had a test. They detect change; they assert nothing about
# correctness. Replace them with behaviour tests as the config surface lands.
set -uo pipefail

SL="$(cd "$(dirname "$0")/.." && pwd)/statusline"
fails=0

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

# --- the bar ----------------------------------------------------------------
# Five cells, filled by rounding up, so any non-zero usage shows at least one.
bar_at() { plain "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":$1,\"resets_at\":0}}}"; }
assert_contains "characterises an empty bar at zero"  "$(bar_at 0)"   "5h ▱▱▱▱▱ 0%"
assert_contains "characterises rounding up from 1"    "$(bar_at 1)"   "5h ▰▱▱▱▱ 1%"
assert_contains "characterises a full bar at 100"     "$(bar_at 100)" "5h ▰▰▰▰▰ 100%"

[ "$fails" -eq 0 ] && echo "statusline characterisation: all assertions passed"
exit "$fails"
