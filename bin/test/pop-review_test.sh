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
  display-message) [ "$2" = -p ] && printf '%s\n' "${FAKE_TMUX_WINDOW:-}" ;;
  show-environment) exit 1 ;;
esac
exit 0
FAKE
cat > "$fake_dir/xdg-open" <<'FAKE'
#!/usr/bin/env bash
printf 'xdg-open %s\n' "$*" >> "$FAKE_TMUX_LOG"
exit "${FAKE_XDG_STATUS:-0}"
FAKE
cat > "$fake_dir/notify-send" <<'FAKE'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >> "$FAKE_TMUX_LOG"
exit 1   # as with no notification daemon running
FAKE
chmod +x "$fake_dir/tmux" "$fake_dir/xdg-open" "$fake_dir/notify-send"

# session_for() derives the tmux session from the workspace basename, so the
# workspace must be named for the session that owns it.
ws_parent=$(mktemp -d); ws="$ws_parent/beta"; mkdir -p "$ws/.claude/reviews"
log="$ws_parent/tmux.log"

# claude-dev inside the workspace, with the attached clients given first.
fake_run() {
  (
    export PATH="$fake_dir:$PATH" TMUX=/tmp/fake,1,0 FAKE_TMUX_LOG="$log" FAKE_TMUX_CLIENTS="$1"
    unset TMUX_PANE
    CLAUDE_DEV_ROOT="$ws" bash "$CD" "${@:2}" >/dev/null 2>&1
    echo "$?"
  )
}

# Two workspaces open on one tmux server, each with its own attached terminal.
both='/dev/pts/0 alpha
/dev/pts/1 beta'
pop() { fake_run "$1" pop-review my-task; }

: > "$ws/.claude/reviews/my-task.ready"
: > "$log"
pop "$both" > /dev/null
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

assert_status "a delivered review does not pop on the next switch" "$(pop "$both")" 1

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
fake_run "$both" review-popup my-task > /dev/null
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

# --- a finished until-PR run --------------------------------------------------
# The visual review page is built while the human may be on another window, so
# its opening is held back like a popup and delivered on arrival instead.
page="$ws_parent/visual-review.html"
: > "$log"
assert_status "a failed notification does not fail the finish" \
  "$(fake_run "$both" ready my-task --pr 42 --page "$page")" 0
# The human may be away from the terminal altogether.
notice=$(grep -m1 '^notify-send' "$log" || true)
case "$notice" in
  *"#42"*my-task*) ;;
  *) echo "FAIL: a finished run notifies the desktop with its PR and task — got: ${notice:-<no notification>}"
     fails=$((fails + 1)) ;;
esac
# Off the window, the status line says which PR is waiting there.
status_line=$(grep -m1 '^display-message -t beta ' "$log" || true)
case "$status_line" in
  *"PR #42"*my-task*) ;;
  *) echo "FAIL: the status line names the ready PR — got: ${status_line:-<no status message>}"
     fails=$((fails + 1)) ;;
esac
: > "$log"
assert_status "a held-back page is due on arrival" "$(pop "$both")" 0
grep -qx "xdg-open $page" "$log" ||
  { echo "FAIL: arriving opens the held-back page — got: $(cat "$log")"; fails=$((fails + 1)); }
if grep -q 'display-popup' "$log"; then
  echo "FAIL: a held-back page replaces the review popup"; fails=$((fails + 1))
fi
: > "$log"
assert_status "a second switch has nothing left to open" "$(pop "$both")" 1
if grep -q 'xdg-open' "$log"; then
  echo "FAIL: a second switch does not reopen the page"; fails=$((fails + 1))
fi

# A stride signalled after the run has no page of its own: the last one would
# show a stale review.
fake_run "$both" ready my-task > /dev/null
: > "$log"
pop "$both" > /dev/null
if grep -q 'xdg-open' "$log" || ! grep -q 'display-popup' "$log"; then
  echo "FAIL: a later plain stride gets the popup, not the stale page — got: $(cat "$log")"
  fails=$((fails + 1))
fi

# A page the browser failed to open was never seen: it waits for the next
# switch instead of being used up.
fake_run "$both" ready my-task --page "$page" > /dev/null
(export FAKE_XDG_STATUS=1; pop "$both") > /dev/null
: > "$log"
assert_status "a page that failed to open is due again" "$(pop "$both")" 0
grep -qx "xdg-open $page" "$log" ||
  { echo "FAIL: the next switch retries a page that failed to open — got: $(cat "$log")"; fails=$((fails + 1)); }

# Finishing while the human watches the task window: no switch is coming, so
# the page opens straight away.
: > "$log"
(export FAKE_TMUX_WINDOW=my-task; fake_run "$both" ready my-task --pr 43 --page "$page") > /dev/null
grep -qx "xdg-open $page" "$log" ||
  { echo "FAIL: finishing on the task window opens the page at once — got: $(cat "$log")"; fails=$((fails + 1)); }
# Watching the window in tmux does not mean being at the desk.
grep -q '^notify-send .*#43' "$log" ||
  { echo "FAIL: finishing on the task window still notifies the desktop — got: $(cat "$log")"; fails=$((fails + 1)); }

# The window can be current with nobody attached (driven over Remote
# Control): the page is armed for the next switch, so the signal succeeded.
assert_status "a finish with nobody attached still signals" \
  "$(export FAKE_TMUX_WINDOW=my-task; fake_run '/dev/pts/0 alpha' ready my-task --page "$page")" 0

rm -rf "$fake_dir" "$ws_parent"

[ "$fails" -eq 0 ] && echo "pop-review: all assertions passed"
exit "$fails"
