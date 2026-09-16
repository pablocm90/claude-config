# Scaffolding for editor-written review notes, shared by claude-dev-review and
# its tests.
#
# The terminal review runs in a tmux display-popup, which has no copy-mode: a
# drag falls through to the pane behind it, and the epilogue's one-line `read`
# leaves nowhere to say anything anchored. So [n]ote hands the reviewer a file
# instead — their own editor, their own keybindings, the diff quoted inline
# under a heading per changed file — and this library defines what that file
# looks like going out and what counts as theirs coming back.

# Everything the reviewer did not write is '>'-quoted, so extraction needs no
# knowledge of diff syntax: strip the quotes and the blanks, and keep a file
# heading only when something was actually written under it. A heading with no
# comment is noise that sends Claude hunting for feedback that isn't there.
note_comments() {
  awk '
    /^>/ { next }
    /^## / { heading = $0; shown = 0; next }
    /^[[:space:]]*$/ { next }
    {
      if (!shown && heading != "") { print heading; shown = 1 }
      print
    }
  ' "$1"
}
