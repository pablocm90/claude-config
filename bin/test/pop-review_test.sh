#!/usr/bin/env bash
# Behaviour tests for review delivery: a stride's review must reach its own
# window exactly once, never another window's screen.
set -uo pipefail

CD="$(cd "$(dirname "$0")/.." && pwd)/claude-dev"
fails=0

assert_status() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected exit $3, got $2"; fails=$((fails + 1)); }
}
assert_file() {
  [ -e "$2" ] || { echo "FAIL: $1 — expected $2 to exist"; fails=$((fails + 1)); }
}
assert_no_file() {
  [ ! -e "$2" ] || { echo "FAIL: $1 — expected $2 to be gone"; fails=$((fails + 1)); }
}

# No TMUX in the environment: the popup itself is skipped, so the exit status
# reports the decision — 0 = this review is due, 1 = nothing to show.
run() { (unset TMUX TMUX_PANE; CLAUDE_DEV_ROOT="$1" bash "$CD" "${@:2}" >/dev/null 2>&1; echo "$?"); }

tmp=$(mktemp -d); dir="$tmp/.claude/reviews"; mkdir -p "$dir"

assert_status "no signalled stride — nothing to pop" "$(run "$tmp" pop-review my-task)" 1

assert_status "signalling a stride succeeds" "$(run "$tmp" ready my-task)" 0
assert_file "signalling leaves a ready flag" "$dir/my-task.ready"

assert_status "a signalled stride pops on arrival" "$(run "$tmp" pop-review my-task)" 0
assert_status "the same stride does not pop twice" "$(run "$tmp" pop-review my-task)" 1

# A skipped review keeps its ready flag, so the next stride must re-arm it
# rather than stay silent behind the previous pop.
assert_status "the next stride re-arms the pop" "$(run "$tmp" ready my-task)" 0
assert_status "the next stride pops again" "$(run "$tmp" pop-review my-task)" 0

# Reviews are per window: one window's stride never arms another's.
assert_status "another window is unaffected" "$(run "$tmp" pop-review other-task)" 1

# Approving through the review epilogue clears the flag entirely.
rm -f "$dir/my-task.ready"
assert_status "an approved stride has nothing left to pop" "$(run "$tmp" pop-review my-task)" 1
assert_no_file "approval leaves no ready flag" "$dir/my-task.ready"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "pop-review: all assertions passed"
exit "$fails"
