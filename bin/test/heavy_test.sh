#!/usr/bin/env bash
# Behaviour tests for heavy: one memory-hungry job at a time on this machine,
# whichever session starts it. A second job waits for the first, and says
# what it is waiting for.
set -uo pipefail

HEAVY="$(cd "$(dirname "$0")/.." && pwd)/heavy"
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
export HEAVY_LOCK="$tmp/heavy.lock"

# --- alone, it is the command -----------------------------------------------
assert_eq "it runs the command with its arguments" \
  "$("$HEAVY" printf '%s-%s' one two)" "one-two"
"$HEAVY" sh -c 'exit 7'
assert_eq "and exits with the command's status" "$?" "7"

# --- a second job waits its turn --------------------------------------------
log="$tmp/order.log"
"$HEAVY" sh -c "sleep 1; echo first-done >> '$log'" &
first=$!
sleep 0.3
waiting=$("$HEAVY" sh -c "echo second-starts >> '$log'" 2>&1 >/dev/null)
wait "$first"
assert_eq "a second job starts only once the first has finished" \
  "$(tr '\n' ' ' < "$log")" "first-done second-starts "
assert_contains "and while waiting it names the job it waits for" \
  "$waiting" "sleep 1; echo first-done"

: > "$log"
"$HEAVY" sh -c "echo third-alone >> '$log'" 2>"$tmp/quiet.err"
assert_eq "a job with the machine to itself says nothing" "$(cat "$tmp/quiet.err")" ""

# --- without a command ------------------------------------------------------
"$HEAVY" 2>"$tmp/usage.err"
assert_eq "no command is a usage error" "$?" "2"
assert_contains "that says how to call it" "$(cat "$tmp/usage.err")" "usage: heavy"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "heavy: all assertions passed"
exit "$fails"
