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
@@ -12,1 +12,1 @@
-  const g = data?.group
+  const g = data.group
EOF

# --- the scaffold the reviewer is handed -------------------------------------
# The file is a diff, not markdown: every editor colours diff natively, while
# markdown fences are only coloured by editors that inject the fenced language
# (gedit's GtkSourceView does not). Git's own framing says nothing a reviewer
# acts on, so only the path survives, as a heading.
assert_eq "the scaffold is a plain diff under a file heading" \
  "$(note_scaffold < "$tmp/diff" | grep -v '^# ' | grep -v '^$')" \
  '## src/useGroup.ts
@@ -12,1 +12,1 @@
-  const g = data?.group
+  const g = data.group'

# --- what comes back ---------------------------------------------------------
# A hunk declares its own length, so the end of the diff body is known exactly.
# That is what lets a comment start with any character at all — including the
# '-' of a bullet list, which a prefix rule would have swallowed as a deletion.
cat > "$tmp/bullet" <<'EOF'
## src/useGroup.ts
@@ -12,1 +12,1 @@
-  const g = data?.group
+  const g = data.group
- data is undefined while pending
- placeholderData won't save you, it's pending-only
EOF

assert_eq "a comment may start with a diff character" \
  "$(note_comments "$tmp/bullet")" \
  "## src/useGroup.ts
- data is undefined while pending
- placeholderData won't save you, it's pending-only"

# A hunk header without counts means one line each; miscounting it would eat
# the reviewer's first sentence.
cat > "$tmp/nocount" <<'EOF'
## src/useGroup.ts
@@ -12 +12 @@
-  const g = data?.group
+  const g = data.group
this needs a pending guard
EOF

assert_eq "a countless hunk header means one line each" \
  "$(note_comments "$tmp/nocount")" \
  "## src/useGroup.ts
this needs a pending guard"

# Only files the reviewer wrote under should come back: a heading they skipped
# is noise that would have Claude hunting for a comment that isn't there.
cat > "$tmp/skipped" <<'EOF'
# Write your comments under the file they are about.

## src/GroupClients.tsx
@@ -41,1 +41,1 @@
-  if (!group?.id) return null
+  if (!group) return <Forbidden />
this returns 403 for a groupless admin too

## src/useGroup.ts
@@ -12,1 +12,1 @@
-  const g = data?.group
+  const g = data.group
EOF

assert_eq "only commented files come back" \
  "$(note_comments "$tmp/skipped")" \
  "## src/GroupClients.tsx
this returns 403 for a groupless admin too"

# The header is instructions, not content — but only at the top. After a file
# heading a '#' line is the reviewer writing about a shell script or a comment.
cat > "$tmp/hash" <<'EOF'
# Write your comments under the file they are about.

## bin/thing.sh
@@ -1,1 +1,1 @@
-set -e
+set -uo pipefail
#!/usr/bin/env bash is missing from this file
EOF

assert_eq "a hash line after a heading is the reviewer's" \
  "$(note_comments "$tmp/hash")" \
  "## bin/thing.sh
#!/usr/bin/env bash is missing from this file"

# A remark written above the first heading is about the stride as a whole.
cat > "$tmp/preamble" <<'EOF'
# Write your comments under the file they are about.

split this into two commits

## src/useGroup.ts
@@ -12,1 +12,1 @@
-  const g = data?.group
+  const g = data.group
EOF

assert_eq "a remark above the first heading has no heading" \
  "$(note_comments "$tmp/preamble")" \
  "split this into two commits"

# The two halves have to agree, for one file and for many: an untouched
# scaffold must carry nothing back, or the note arrives buried in the diff.
note_scaffold < "$tmp/diff" > "$tmp/roundtrip"
assert_eq "an untouched scaffold extracts to nothing" \
  "$(note_comments "$tmp/roundtrip")" ""

cat > "$tmp/two-files" <<'EOF'
diff --git a/src/useGroup.ts b/src/useGroup.ts
index 1234567..89abcde 100644
--- a/src/useGroup.ts
+++ b/src/useGroup.ts
@@ -12,1 +12,1 @@
-  const g = data?.group
+  const g = data.group
diff --git a/src/GroupClients.tsx b/src/GroupClients.tsx
index 2345678..9abcdef 100644
--- a/src/GroupClients.tsx
+++ b/src/GroupClients.tsx
@@ -41,1 +41,1 @@
-  if (!group?.id) return null
+  if (!group) return <Forbidden />
EOF

note_scaffold < "$tmp/two-files" > "$tmp/two-roundtrip"
assert_eq "a two-file scaffold still extracts to nothing" \
  "$(note_comments "$tmp/two-roundtrip")" ""

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

# --- handing it to the editor ------------------------------------------------
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
EDITOR="$tmp/broken-editor" capture_note "$tmp/broken" >/dev/null 2>&1
assert_eq "a failing editor reports failure" "$?" "1"

# Real hunks are longer than one line and mostly context. Taking the declared
# length seriously is what keeps the count honest across them; treating every
# hunk as one line would hand back the rest of the diff as the reviewer's.
cat > "$tmp/context" <<'EOF'
## src/useGroup.ts
@@ -10,3 +10,3 @@
 const before = 1
-  const g = data?.group
+  const g = data.group
 const after = 2
needs a pending guard
EOF

assert_eq "context lines are counted on both sides" \
  "$(note_comments "$tmp/context")" \
  "## src/useGroup.ts
needs a pending guard"

# Git emits the no-newline marker after the last line of a hunk, by which point
# the declared counts are spent — so it has to be recognised on its own, or it
# arrives as the reviewer's opening sentence.
cat > "$tmp/nonewline" <<'EOF'
## src/thing.txt
@@ -1,1 +1,1 @@
-old line
+new line
\ No newline at end of file
this file wants a trailing newline
EOF

assert_eq "the no-newline marker is not a comment" \
  "$(note_comments "$tmp/nonewline")" \
  "## src/thing.txt
this file wants a trailing newline"

# A hunk that adds lines declares different counts for its two sides, which is
# what most commits look like. Reading them in the wrong order runs the count
# past the end of the hunk and swallows the comment underneath.
cat > "$tmp/asymmetric" <<'EOF'
## src/useGroup.ts
@@ -10,1 +10,3 @@
 const before = 1
+  const a = 1
+  const b = 2
this could be one destructure
EOF

assert_eq "the two hunk counts are not interchangeable" \
  "$(note_comments "$tmp/asymmetric")" \
  "## src/useGroup.ts
this could be one destructure"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "review-note: all tests passed"
exit $((fails > 0))
