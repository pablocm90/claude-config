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

# --- what comes back ---------------------------------------------------------
# Only files the reviewer wrote under should come back: a heading they skipped
# is noise that would have Claude hunting for a comment that isn't there.
cat > "$tmp/skipped" <<'EOF'
<!-- Write comments under the file they are about. -->

## src/GroupClients.tsx

```diff
@@ -41,7 +41,7 @@
-  if (!group?.id) return null
+  if (!group) return <Forbidden />
```

this returns 403 for a groupless admin too

## src/useGroup.ts

```diff
@@ -12,3 +12,3 @@
-  const g = data?.group
+  const g = data.group
```
EOF

assert_eq "only commented files come back" \
  "$(note_comments "$tmp/skipped")" \
  "## src/GroupClients.tsx
this returns 403 for a groupless admin too"

# A comment worth writing is usually longer than one line. The heading names
# the file once; repeating it per line would read as separate findings.
cat > "$tmp/multiline" <<'EOF'
## src/useGroup.ts

```diff
-  const g = data?.group
+  const g = data.group
```

data is undefined while the query is pending.
placeholderData won't save you here — it's pending-only.
EOF

assert_eq "a multi-line comment keeps one heading" \
  "$(note_comments "$tmp/multiline")" \
  "## src/useGroup.ts
data is undefined while the query is pending.
placeholderData won't save you here — it's pending-only."

# Not every remark is about a file. A note written above the first heading is
# about the stride as a whole, and must arrive without a heading of its own.
cat > "$tmp/preamble" <<'EOF'
<!-- Write comments under the file they are about. -->

split this into two commits

## src/useGroup.ts

```diff
+  const g = data.group
```
EOF

assert_eq "a remark above the first heading has no heading" \
  "$(note_comments "$tmp/preamble")" \
  "split this into two commits"

# A diff line that looks like prose must stay inside the fence. Without fence
# tracking, a removed markdown heading in the diff would arrive as a comment.
cat > "$tmp/lookalike" <<'EOF'
## README.md

```diff
-## Installation
-run the thing
```

keep the install section
EOF

assert_eq "diff content that looks like prose stays quoted" \
  "$(note_comments "$tmp/lookalike")" \
  "## README.md
keep the install section"

# --- the scaffold the reviewer is handed -------------------------------------
# Git's own framing (index/---/+++ lines) says nothing a reviewer acts on and
# pushes the hunks off the first screen. The diff goes in a ```diff fence so the
# editor colours it, under the file name as a heading they can write beneath.
cat > "$tmp/diff" <<'EOF'
diff --git a/src/useGroup.ts b/src/useGroup.ts
index 1234567..89abcde 100644
--- a/src/useGroup.ts
+++ b/src/useGroup.ts
@@ -12,3 +12,3 @@
-  const g = data?.group
+  const g = data.group
EOF

assert_eq "the scaffold fences each file's hunks under its name" \
  "$(note_scaffold < "$tmp/diff" | grep -v '^$' | grep -v '^<!--')" \
  '## src/useGroup.ts
```diff
@@ -12,3 +12,3 @@
-  const g = data?.group
+  const g = data.group
```'

# The header has to say how to leave the editor — the reviewer is dropped into
# it by a popup, and "how do I save this" is where the note gets abandoned.
assert_eq "the header names the save keys for this editor" \
  "$(EDITOR=nano note_scaffold < "$tmp/diff" | grep -c 'Ctrl-O')" "1"
assert_eq "an unknown editor still gets an instruction" \
  "$(EDITOR=acme note_scaffold < "$tmp/diff" | grep -c 'Save and close')" "1"

# The two halves have to agree: whatever the scaffold writes must be invisible
# to extraction, or the note arrives buried in a copy of the diff.
note_scaffold < "$tmp/diff" > "$tmp/roundtrip"
assert_eq "an untouched scaffold extracts to nothing" \
  "$(note_comments "$tmp/roundtrip")" ""

# --- handing it to the editor ------------------------------------------------
cat > "$tmp/fake-editor" <<'ED'
#!/usr/bin/env bash
printf 'this drops the pending guard\n' >> "$1"
ED
chmod +x "$tmp/fake-editor"

note_scaffold < "$tmp/diff" > "$tmp/edited"
assert_eq "capture_note returns what the editor left behind" \
  "$(EDITOR="$tmp/fake-editor" capture_note "$tmp/edited")" \
  "## src/useGroup.ts
this drops the pending guard"

# Closing the editor without typing is how a reviewer changes their mind; it
# must not file an empty note and clear the ready flag as if they had spoken.
note_scaffold < "$tmp/diff" > "$tmp/unedited"
assert_eq "closing the editor untouched yields nothing" \
  "$(EDITOR=true capture_note "$tmp/unedited")" ""

# An editor that fails must not read as "the reviewer said nothing" — the note
# would vanish and the stride would clear as if it had been answered. This is
# also how :cq cancels out of vim.
cat > "$tmp/broken-editor" <<'ED'
#!/usr/bin/env bash
printf 'half a thought\n' >> "$1"
exit 1
ED
chmod +x "$tmp/broken-editor"

note_scaffold < "$tmp/diff" > "$tmp/broken"
EDITOR="$tmp/broken-editor" capture_note "$tmp/broken" >/dev/null 2>&1
assert_eq "a failing editor reports failure" "$?" "1"

# Most strides touch more than one file, and each file opens a fence. Unless the
# previous one is closed first, the second ```diff toggles the fence shut and
# that file's entire diff arrives as if the reviewer had typed it.
cat > "$tmp/two-files" <<'EOF'
diff --git a/src/useGroup.ts b/src/useGroup.ts
index 1234567..89abcde 100644
--- a/src/useGroup.ts
+++ b/src/useGroup.ts
@@ -12,3 +12,3 @@
-  const g = data?.group
+  const g = data.group
diff --git a/src/GroupClients.tsx b/src/GroupClients.tsx
index 2345678..9abcdef 100644
--- a/src/GroupClients.tsx
+++ b/src/GroupClients.tsx
@@ -41,7 +41,7 @@
-  if (!group?.id) return null
+  if (!group) return <Forbidden />
EOF

note_scaffold < "$tmp/two-files" > "$tmp/two-roundtrip"
assert_eq "a two-file scaffold still extracts to nothing" \
  "$(note_comments "$tmp/two-roundtrip")" ""

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "review-note: all tests passed"
exit $((fails > 0))
