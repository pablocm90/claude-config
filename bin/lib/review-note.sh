# Scaffolding for editor-written review notes, shared by claude-dev-review and
# its tests.
#
# The terminal review runs in a tmux display-popup, which has no copy-mode: a
# drag falls through to the pane behind it and selects that instead. The
# epilogue's one-line `read` then leaves nowhere to say anything anchored to a
# file, which is why every note in .claude/reviews is a bare "approved". So
# [n]ote hands the reviewer a file instead — their own editor, their own
# keybindings — and this library defines what that file looks like going out
# and what counts as theirs coming back.

# How to leave the editor, in its own idiom. The reviewer is dropped into it by
# a popup rather than opening it themselves, so "how do I save this" is exactly
# where a note gets abandoned. An unrecognised editor gets the generic form.
save_hint() {
  case "$(basename "${EDITOR:-vi}")" in
    vi|vim|nvim|view)  printf 'Save and quit (:wq, or :cq to cancel)' ;;
    nano|pico)         printf 'Save and quit (Ctrl-O, Enter, Ctrl-X)' ;;
    emacs|emacsclient) printf 'Save and quit (C-x C-s, C-x C-c)' ;;
    micro)             printf 'Save and quit (Ctrl-S, Ctrl-Q)' ;;
    code|codium|subl)  printf 'Save, then close the tab' ;;
    *)                 printf 'Save and close' ;;
  esac
}

# Turn a diff into the file the reviewer writes in. Git's own framing (index,
# ---/+++, mode and rename lines) says nothing a reviewer acts on and pushes the
# first hunk off the opening screen, so only the path survives, as a heading.
# The hunks go in a ```diff fence: every markdown-aware editor colours embedded
# diff, which is the difference between reading this and skimming it.
# Reads a diff on stdin.
note_scaffold() {
  printf '<!-- Write your comments under the file they are about. -->\n'
  printf '<!-- %s to send them to Claude. An untouched file sends nothing. -->\n' "$(save_hint)"
  awk '
    /^diff --git / {
      path = $0
      sub(/^diff --git a\//, "", path)
      sub(/ b\/.*$/, "", path)
      if (open) printf "```\n"
      printf "\n## %s\n\n```diff\n", path
      open = 1
      next
    }
    /^(index |--- |\+\+\+ |old mode |new mode |new file |deleted file |similarity |rename |Binary )/ { next }
    { print }
    END { if (open) printf "```\n" }
  '
}

# Extract the reviewer's own lines. Fence tracking is what makes this safe on a
# diff of prose: a removed markdown heading would otherwise arrive looking like
# a comment about a file that was never touched. A heading with nothing written
# under it is dropped — it would send Claude hunting for feedback that isn't
# there.
note_comments() {
  awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^<!--/ { next }
    /^## / { heading = $0; shown = 0; next }
    /^[[:space:]]*$/ { next }
    {
      if (!shown && heading != "") { print heading; shown = 1 }
      print
    }
  ' "$1"
}

# Hand the scaffold to the reviewer's editor and return only what they wrote.
# Inside the popup this runs downstream of the pager, so stdin is not the
# terminal; an editor given that opens on a closed input and exits at once.
# /dev/tty is the way back to the keyboard — except under a test or a pipeline
# that has none, where the editor is a stub that needs no terminal at all.
# A non-zero exit is the reviewer cancelling (vim's :cq) or a broken $EDITOR;
# either way it must not read as "they had nothing to say".
capture_note() {
  local scaffold="$1"
  if { : >/dev/tty; } 2>/dev/null; then
    "${EDITOR:-vi}" "$scaffold" </dev/tty >/dev/tty 2>&1 || return 1
  else
    "${EDITOR:-vi}" "$scaffold" || return 1
  fi
  note_comments "$scaffold"
}
