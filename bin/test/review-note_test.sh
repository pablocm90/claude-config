#!/usr/bin/env bash
# Behaviour tests for review-note scaffolding: what the reviewer types in the
# editor must reach Claude, and nothing else must.
set -uo pipefail

. "$(cd "$(dirname "$0")/.." && pwd)/lib/review-note.sh"

fails=0
assert_eq() {
  [ "$2" = "$3" ] || {
    printf 'FAIL: %s\n  expected: %q\n  got:      %q\n' "$1" "$3" "$2"
    fails=$((fails + 1))
  }
}

tmp=$(mktemp -d)

cat > "$tmp/diff" <<'EOF'
diff --git a/src/useGroup.ts b/src/useGroup.ts
index 1234567..89abcde 100644
--- a/src/useGroup.ts
+++ b/src/useGroup.ts
@@ -10,3 +10,3 @@
 const before = 1
-  const g = data?.group
+  const g = data.group
 const after = 2
EOF

# --- the scaffold the reviewer is handed -------------------------------------
# The file is a diff, not markdown: every editor colours diff natively, while
# markdown fences are only coloured by editors that inject the fenced language
# (gedit's GtkSourceView does not). Git's own framing says nothing a reviewer
# acts on, so only the path survives, as a heading.
assert_eq "the scaffold is a plain diff under a file heading" \
  "$(note_scaffold < "$tmp/diff" | grep -v '^# ' | grep -v '^$')" \
  '## src/useGroup.ts
@@ -10,3 +10,3 @@
 const before = 1
-  const g = data?.group
+  const g = data.group
 const after = 2'

# --- what comes back ---------------------------------------------------------
# Nothing about a line decides whether it is the reviewer's — only whether it
# was in the scaffold they were handed. Every fixture below is therefore a real
# scaffold with lines typed into it, never a hand-written file that no editing
# session could have produced.
note_scaffold < "$tmp/diff" > "$tmp/scaffold"

# Commenting next to the line you mean is the natural thing to do, and the only
# place a reviewer can point precisely.
awk '{ print } /const g = data\.group/ { print "data is undefined while pending" }' \
  "$tmp/scaffold" > "$tmp/inside"

assert_eq "a comment typed inside a hunk is still the reviewer's" \
  "$(note_comments "$tmp/inside" "$tmp/scaffold")" \
  "## src/useGroup.ts
data is undefined while pending"

# A comment may start with any character at all, including the '-' of a bullet
# list, which a prefix rule would have swallowed as a deletion.
cp "$tmp/scaffold" "$tmp/bullet"
cat >> "$tmp/bullet" <<'EOF'
- data is undefined while pending
- placeholderData won't save you, it's pending-only
EOF

assert_eq "a comment may start with a diff character" \
  "$(note_comments "$tmp/bullet" "$tmp/scaffold")" \
  "## src/useGroup.ts
- data is undefined while pending
- placeholderData won't save you, it's pending-only"

# A remark written above the first heading is about the stride as a whole.
awk '/^## / && !seen { print "split this into two commits"; print ""; seen = 1 } { print }' \
  "$tmp/scaffold" > "$tmp/preamble"

assert_eq "a remark above the first heading has no heading" \
  "$(note_comments "$tmp/preamble" "$tmp/scaffold")" \
  "split this into two commits"

# The header is instructions, not content — but a '#' the reviewer types is
# theirs, whether it looks like the header or like a shebang.
cat > "$tmp/shell.diff" <<'EOF'
diff --git a/bin/thing.sh b/bin/thing.sh
index 1111111..2222222 100644
--- a/bin/thing.sh
+++ b/bin/thing.sh
@@ -1,1 +1,1 @@
-set -e
+set -uo pipefail
EOF
note_scaffold < "$tmp/shell.diff" > "$tmp/shell"
cp "$tmp/shell" "$tmp/hash"
cat >> "$tmp/hash" <<'EOF'
#!/usr/bin/env bash is missing from this file
EOF

assert_eq "a hash line the reviewer wrote is not the header" \
  "$(note_comments "$tmp/hash" "$tmp/shell")" \
  "## bin/thing.sh
#!/usr/bin/env bash is missing from this file"

# Only files the reviewer wrote under should come back: a heading they skipped
# is noise that would have Claude hunting for a comment that isn't there.
cat > "$tmp/two-files.diff" <<'EOF'
diff --git a/src/GroupClients.tsx b/src/GroupClients.tsx
index 2345678..9abcdef 100644
--- a/src/GroupClients.tsx
+++ b/src/GroupClients.tsx
@@ -41,1 +41,1 @@
-  if (!group?.id) return null
+  if (!group) return <Forbidden />
diff --git a/src/useGroup.ts b/src/useGroup.ts
index 1234567..89abcde 100644
--- a/src/useGroup.ts
+++ b/src/useGroup.ts
@@ -12,1 +12,1 @@
-  const g = data?.group
+  const g = data.group
EOF
note_scaffold < "$tmp/two-files.diff" > "$tmp/two-files"
awk '{ print } /return <Forbidden/ { print "this returns 403 for a groupless admin too" }' \
  "$tmp/two-files" > "$tmp/skipped"

assert_eq "only commented files come back" \
  "$(note_comments "$tmp/skipped" "$tmp/two-files")" \
  "## src/GroupClients.tsx
this returns 403 for a groupless admin too"

# Each commented file is named, or the second file's remarks arrive filed under
# the first one's heading and read as being about code they never mention.
awk '{ print }
  /return <Forbidden/ { print "this returns 403 for a groupless admin too" }
  /const g = data\.group/ { print "data is undefined while pending" }' \
  "$tmp/two-files" > "$tmp/both"

assert_eq "every commented file gets its own heading" \
  "$(note_comments "$tmp/both" "$tmp/two-files")" \
  "## src/GroupClients.tsx
this returns 403 for a groupless admin too
## src/useGroup.ts
data is undefined while pending"

# A heading with nothing but a stray newline under it is not a comment: it
# would send Claude hunting for feedback that was never written.
awk '{ print } /^## / { print "" }' "$tmp/scaffold" > "$tmp/blank"

assert_eq "a blank line under a heading is not a comment" \
  "$(note_comments "$tmp/blank" "$tmp/scaffold")" ""

# The two halves have to agree, for one file and for many: an untouched
# scaffold must carry nothing back, or the note arrives buried in the diff.
assert_eq "an untouched scaffold extracts to nothing" \
  "$(note_comments "$tmp/scaffold" "$tmp/scaffold")" ""
assert_eq "a two-file scaffold still extracts to nothing" \
  "$(note_comments "$tmp/two-files" "$tmp/two-files")" ""

# Trimming the lines they have nothing to say about is a reviewer editing their
# own file, not a comment. Only what they added comes back — which needs the
# two files aligned properly, not walked in lockstep from the deletion onwards.
grep -v 'const before = 1' "$tmp/scaffold" > "$tmp/trimmed"
cat >> "$tmp/trimmed" <<'EOF'
needs a pending guard
EOF

assert_eq "lines the reviewer deleted are not comments" \
  "$(note_comments "$tmp/trimmed" "$tmp/scaffold")" \
  "## src/useGroup.ts
needs a pending guard"

# --- naming the way out ------------------------------------------------------
# The reviewer is dropped into the editor by a popup rather than opening it
# themselves, so "how do I save this" is where a note gets abandoned. The hint
# has to survive an $EDITOR carrying flags, which gedit and code both need.
assert_eq "the hint reads through a flag-carrying editor" \
  "$(EDITOR='gedit --wait' save_hint)" "Save and close (Ctrl-S, Ctrl-W)"
assert_eq "an unknown editor still gets an instruction" \
  "$(EDITOR=acme save_hint)" "Save and close"

# VISUAL outranks EDITOR by long convention: it names the full-screen editor to
# use when there is a display, which is exactly this case.
assert_eq "VISUAL outranks EDITOR" \
  "$(VISUAL=nano EDITOR=vim save_hint)" "Save and quit (Ctrl-O, Enter, Ctrl-X)"

# The epilogue offers "[n]ote in <editor>", so it needs the name the reviewer
# would recognise — not the literal '$EDITOR', and not the flags or the path
# they happen to have configured around it.
assert_eq "the editor's name is its bare command" \
  "$(VISUAL= EDITOR=nano editor_name)" "nano"
assert_eq "a path and flags are not part of the name" \
  "$(VISUAL= EDITOR='/usr/bin/gedit --wait' editor_name)" "gedit"
assert_eq "with nothing set the name is the fallback" \
  "$(unset VISUAL EDITOR; editor_name)" "vi"

# --- handing it to the editor ------------------------------------------------
# The scaffold is edited in place, so the copy the note is read against has to
# be taken here, before the editor runs — no caller can produce it afterwards.
cat > "$tmp/fake-editor" <<'ED'
#!/usr/bin/env bash
# Only ever invoked as `fake-editor --flag <file>`, to pin the word splitting.
[ "$1" = "--flag" ] || { echo "lost the flag" >&2; exit 2; }
printf 'this drops the pending guard\n' >> "$2"
ED
chmod +x "$tmp/fake-editor"

note_scaffold < "$tmp/diff" > "$tmp/edited"
assert_eq "capture_note runs an editor that carries flags" \
  "$(EDITOR="$tmp/fake-editor --flag" capture_note "$tmp/edited")" \
  "## src/useGroup.ts
this drops the pending guard"

# Closing the editor without typing is how a reviewer changes their mind; it
# must not file an empty note and clear the ready flag as if they had spoken.
note_scaffold < "$tmp/diff" > "$tmp/unedited"
assert_eq "closing the editor untouched yields nothing" \
  "$(EDITOR=true capture_note "$tmp/unedited")" ""

# An editor that fails must not read as "the reviewer said nothing" — the note
# would vanish and the stride would clear as if it had been answered.
cat > "$tmp/broken-editor" <<'ED'
#!/usr/bin/env bash
printf 'half a thought\n' >> "$1"
exit 1
ED
chmod +x "$tmp/broken-editor"

note_scaffold < "$tmp/diff" > "$tmp/broken"
half=$(EDITOR="$tmp/broken-editor" capture_note "$tmp/broken" 2>/dev/null); rc=$?
assert_eq "a failing editor reports failure" "$rc" "1"
assert_eq "a failing editor files nothing" "$half" ""

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "review-note: all tests passed"
exit $((fails > 0))
