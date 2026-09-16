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

# The scaffold hands the reviewer quoted diff under a heading per changed file.
# Only files they actually wrote under should come back: a heading they skipped
# is noise that would have Claude hunting for a comment that isn't there.
cat > "$tmp/skipped" <<'EOF'
> Write comments under the file they belong to. Quoted lines are ignored.

## src/GroupClients.tsx
> @@ -41,7 +41,7 @@
> -  if (!group?.id) return null
> +  if (!group) return <Forbidden />
this returns 403 for a groupless admin too

## src/useGroup.ts
> @@ -12,3 +12,3 @@
> -  const g = data?.group
> +  const g = data.group
EOF

assert_eq "only commented files come back" \
  "$(note_comments "$tmp/skipped")" \
  "## src/GroupClients.tsx
this returns 403 for a groupless admin too"

# A comment worth writing is usually longer than one line. The heading names
# the file once; repeating it per line would read as three separate findings.
cat > "$tmp/multiline" <<'EOF'
## src/useGroup.ts
> -  const g = data?.group
> +  const g = data.group
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
> Write comments under the file they belong to.

split this into two commits

## src/useGroup.ts
> +  const g = data.group
EOF

assert_eq "a remark above the first heading has no heading" \
  "$(note_comments "$tmp/preamble")" \
  "split this into two commits"

rm -rf "$tmp"
[ "$fails" -eq 0 ] && echo "review-note: all tests passed"
exit $((fails > 0))
