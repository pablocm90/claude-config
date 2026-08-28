#!/usr/bin/env bash
# Behaviour tests for the publish guard. This repo is public: a commit that
# names a client, carries a personal address or a session id, or contains a
# credential must not be committable by accident.
set -uo pipefail

GUARD="$(cd "$(dirname "$0")/.." && pwd)/preflight"
fails=0
[ -x "$GUARD" ] || { echo "FAIL: $GUARD is not executable"; exit 1; }

assert_status() {
  [ "$2" = "$3" ] || { echo "FAIL: $1 — expected exit $3, got $2"; fails=$((fails + 1)); }
}
assert_mentions() {
  case "$2" in *"$3"*) ;; *) echo "FAIL: $1 — output did not mention '$3'"; echo "  got: $2"; fails=$((fails + 1)) ;; esac
}

repo=$(mktemp -d); git init -q "$repo"; cd "$repo"
git config user.email t@t; git config user.name T
stage() { printf '%s\n' "$2" > "$1"; git add "$1"; }
run() { (cd "$repo" && bash "$GUARD" "$@" 2>&1); }
status() { (cd "$repo" && bash "$GUARD" "$@" >/dev/null 2>&1; echo "$?"); }

# --- clean content passes -------------------------------------------------
stage notes.md "A generic note about Rails testing."
assert_status "clean staged content passes" "$(status)" 0

# --- a client name is the thing this exists to catch ----------------------
stage notes.md "The gate in recovr-backend is bin/check."
assert_status "a client name is refused" "$(status)" 1
assert_mentions "the refusal names the file" "$(run)" "notes.md"
assert_mentions "the refusal names what it found" "$(run)" "recovr"

stage notes.md "Chift import flakes on CI."
assert_status "a vendor name is refused" "$(status)" 1
stage notes.md "See RECOVR-BACKEND for details."
assert_status "matching ignores case" "$(status)" 1

# --- personal identifiers -------------------------------------------------
stage notes.md "Run it from /home/pablo/Code."
assert_status "a personal home path is refused" "$(status)" 1
stage notes.md "Mail pablocm90@gmail.com about it."
assert_status "a personal address is refused" "$(status)" 1

# --- credentials ----------------------------------------------------------
stage notes.md "token: ghp_0123456789abcdefghijklmnopqrstuvwxyz"
assert_status "a token is refused" "$(status)" 1
stage notes.md "-----BEGIN RSA PRIVATE KEY-----"
assert_status "a private key is refused" "$(status)" 1

# --- commit messages are scanned too --------------------------------------
stage notes.md "A generic note."
msg="$repo/msg.txt"
printf 'Add a thing\n\nClaude-Session: https://claude.ai/code/session_01Abc\n' > "$msg"
assert_status "a session trailer in the message is refused" "$(status --message "$msg")" 1
printf 'Add a thing\n\nSpotted while working in recovr-backend.\n' > "$msg"
assert_status "a client name in the message is refused" "$(status --message "$msg")" 1
printf 'Add a thing\n\nPlain reasoning, nothing identifying.\n' > "$msg"
assert_status "a clean message passes" "$(status --message "$msg")" 0

# --- the guard must not trip over its own pattern list --------------------
mkdir -p bin; cp "$GUARD" bin/preflight; git add bin/preflight
assert_status "the guard does not flag itself" "$(status)" 0

# --- only added lines matter ----------------------------------------------
git commit -qm "baseline"
printf 'A generic note.\nrecovr appears here\n' > notes.md; git add notes.md
assert_status "an added line is caught after a baseline commit" "$(status)" 1
git checkout -q -- . 2>/dev/null || true

rm -rf "$repo"
[ "$fails" -eq 0 ] && echo "preflight: all assertions passed"
exit "$fails"
