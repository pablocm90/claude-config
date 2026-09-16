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

# --- delivery to the right terminal -----------------------------------------
# A popup is drawn on a client, not a session. With several workspaces open on
# one tmux server a client-less popup lands on whichever client tmux picks
# first — another project's terminal. These drive claude-dev against a fake
# tmux so the popup command it builds can be inspected.

fake_dir=$(mktemp -d)
cat > "$fake_dir/tmux" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_TMUX_LOG"
case "$1" in
  list-clients) printf '%s\n' "$FAKE_TMUX_CLIENTS" ;;
  show-environment) exit 1 ;;
esac
exit 0
FAKE
chmod +x "$fake_dir/tmux"

# session_for() derives the tmux session from the workspace basename, so the
# workspace must be named for the session that owns it.
ws_parent=$(mktemp -d); ws="$ws_parent/beta"; mkdir -p "$ws/.claude/reviews"
log="$ws_parent/tmux.log"

# Two workspaces open on one tmux server, each with its own attached terminal.
pop() {
  (
    export PATH="$fake_dir:$PATH" TMUX=/tmp/fake,1,0 FAKE_TMUX_LOG="$log" FAKE_TMUX_CLIENTS="$1"
    unset TMUX_PANE
    CLAUDE_DEV_ROOT="$ws" bash "$CD" pop-review my-task >/dev/null 2>&1
    echo "$?"
  )
}

: > "$ws/.claude/reviews/my-task.ready"
: > "$log"
pop '/dev/pts/0 alpha
/dev/pts/1 beta' > /dev/null
popup_cmd=$(grep -m1 'display-popup' "$log" || true)
popup_cmd=$(printf %s "$popup_cmd" | tr -d \\047)   # quoting is incidental; the client is not

case "$popup_cmd" in
  *"-c /dev/pts/1"*) ;;
  *) echo "FAIL: the review goes to its own workspace's client — got: ${popup_cmd:-<no popup fired>}"
     fails=$((fails + 1)) ;;
esac
case "$popup_cmd" in
  *"/dev/pts/0"*) echo "FAIL: the review must not reach another workspace's client — got: $popup_cmd"
     fails=$((fails + 1)) ;;
esac

# An auto-popped review is the stride just committed, not the whole branch.
case "$popup_cmd" in
  *--stride*) ;;
  *) echo "FAIL: a delivered review is narrowed to its stride — got: $popup_cmd"
     fails=$((fails + 1)) ;;
esac

# Nobody attached to this workspace: consuming the flag unseen loses the
# review for good, so an undeliverable review stays armed.
rm -f "$ws/.claude/reviews/my-task.popped"
: > "$log"
assert_status "an undeliverable review does not pop" "$(pop '/dev/pts/0 alpha')" 1
assert_no_file "an undeliverable review is not consumed" "$ws/.claude/reviews/my-task.popped"
assert_file "an undeliverable review stays armed" "$ws/.claude/reviews/my-task.ready"
if grep -q 'display-popup' "$log"; then
  echo "FAIL: nobody attached — no popup should have been fired"; fails=$((fails + 1))
fi


# prefix + r asks for a review on demand. It runs through the same client
# lookup: a key press knows its client, but the popup it builds does not.
: > "$log"
(
  export PATH="$fake_dir:$PATH" TMUX=/tmp/fake,1,0 FAKE_TMUX_LOG="$log"
  export FAKE_TMUX_CLIENTS='/dev/pts/0 alpha
/dev/pts/1 beta'
  unset TMUX_PANE
  CLAUDE_DEV_ROOT="$ws" bash "$CD" review-popup my-task >/dev/null 2>&1
)
on_demand=$(grep -m1 'display-popup' "$log" || true)
on_demand=$(printf %s "$on_demand" | tr -d \\047)

case "$on_demand" in
  *"-c /dev/pts/1"*) ;;
  *) echo "FAIL: an on-demand review goes to its own workspace's client — got: ${on_demand:-<no popup fired>}"
     fails=$((fails + 1)) ;;
esac
case "$on_demand" in
  *"claude-dev review my-task"*) ;;
  *) echo "FAIL: an on-demand review reviews the named window — got: $on_demand"
     fails=$((fails + 1)) ;;
esac
# On demand means the whole branch, not the last stride.
case "$on_demand" in
  *--stride*) echo "FAIL: an on-demand review is not narrowed to a stride — got: $on_demand"
     fails=$((fails + 1)) ;;
esac
rm -rf "$fake_dir" "$ws_parent"

[ "$fails" -eq 0 ] && echo "pop-review: all assertions passed"
exit "$fails"
