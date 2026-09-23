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

# The editor the reviewer expects, as a word-split command. VISUAL outranks
# EDITOR by long convention: it names the full-screen editor to use when there
# is a display, which is what a review is. Either may carry flags — gedit and
# code both need one to block instead of returning the moment they hand the
# file to an already-running instance.
review_editor() {
  printf '%s' "${VISUAL:-${EDITOR:-vi}}"
}

# The name the reviewer would recognise, with the path and any flags stripped.
# The epilogue offers "[n]ote in <editor>": printing the literal '$EDITOR' there
# tells someone who has never set it nothing at all, and someone who has set it
# to a path or a flagged command the wrong thing.
editor_name() {
  local cmd
  cmd=$(review_editor)
  basename "${cmd%% *}"
}

# How to leave that editor, in its own idiom. The reviewer is dropped into it
# by a popup rather than opening it themselves, so "how do I save this" is
# exactly where a note gets abandoned.
save_hint() {
  case "$(editor_name)" in
    vi|vim|nvim|view)  printf 'Save and quit (:wq, or :cq to cancel)' ;;
    nano|pico)         printf 'Save and quit (Ctrl-O, Enter, Ctrl-X)' ;;
    emacs|emacsclient) printf 'Save and quit (C-x C-s, C-x C-c)' ;;
    micro)             printf 'Save and quit (Ctrl-S, Ctrl-Q)' ;;
    gedit|gnome-text-editor) printf 'Save and close (Ctrl-S, Ctrl-W)' ;;
    code|codium|subl)  printf 'Save, then close the tab' ;;
    *)                 printf 'Save and close' ;;
  esac
}

# Turn a diff into the file the reviewer writes in. It stays a diff, and is
# saved under a .diff name, because diff is the one syntax every editor
# highlights natively — a markdown fence is only coloured by editors that
# inject the fenced language, and GtkSourceView (gedit, gnome-text-editor)
# does not. Git's own framing (index, ---/+++, mode and rename lines) says
# nothing a reviewer acts on and pushes the first hunk off the opening screen,
# so only the path survives, as a heading. Reads a diff on stdin.
note_scaffold() {
  printf '# Write your comments anywhere under the file they are about.\n'
  printf '# %s to send them to Claude. An untouched file sends nothing.\n' "$(save_hint)"
  awk '
    /^diff --git / {
      path = $0
      sub(/^diff --git a\//, "", path)
      sub(/ b\/.*$/, "", path)
      printf "\n## %s\n", path
      next
    }
    /^(index |--- |\+\+\+ |old mode |new mode |new file |deleted file |similarity |rename |Binary )/ { next }
    { print }
  '
}

# Extract the reviewer's own lines, by comparing the file they saved with the
# scaffold they were handed.
#
# Nothing about a line decides whether it is theirs — only whether it was in
# the scaffold. That is what lets a comment look like anything at all: the '-'
# of a bullet list, a '#' of its own, and above all a sentence typed inside a
# hunk, directly under the line it is about. Reading the hunk headers instead
# ended the hunk early on exactly that comment and handed back the diff lines
# it had displaced. A heading with nothing written under it is dropped — it
# would send Claude hunting for feedback that isn't there.
note_comments() {
  local saved="$1" scaffold="$2" theirs
  theirs=$(diff --unchanged-line-format= --old-line-format= \
                --new-line-format='%dn ' "$scaffold" "$saved") || true
  awk -v theirs="$theirs" '
    BEGIN { n = split(theirs, line, " "); for (i = 1; i <= n; i++) wrote[line[i]] = 1 }
    /^## / { heading = $0; shown = 0 }
    !(FNR in wrote) { next }
    /^[[:space:]]*$/ { next }
    {
      if (!shown && heading != "") { print heading; shown = 1 }
      print
    }
  ' "$saved"
}

# Hand the scaffold to the reviewer's editor and return only what they wrote.
# The pristine copy is taken here rather than asked of the caller: the scaffold
# is edited in place, so by the time anyone could compare, the only untouched
# copy is one made before the editor ran.
#
# Inside the popup this runs downstream of the pager, so stdin is not the
# terminal; an editor given that opens on a closed input and exits at once.
# /dev/tty is the way back to the keyboard — except under a test or a pipeline
# that has none, where the editor is a stub that needs no terminal at all.
# A non-zero exit is the reviewer cancelling (vim's :cq) or a broken editor;
# either way it must not read as "they had nothing to say".
capture_note() {
  local scaffold="$1" pristine rc=0
  local -a ed
  pristine=$(mktemp)
  cp "$scaffold" "$pristine"
  read -r -a ed <<< "$(review_editor)"
  if { : >/dev/tty; } 2>/dev/null; then
    "${ed[@]}" "$scaffold" </dev/tty >/dev/tty 2>&1 || rc=1
  else
    "${ed[@]}" "$scaffold" || rc=1
  fi
  [ "$rc" -eq 0 ] && note_comments "$scaffold" "$pristine"
  rm -f "$pristine"
  return "$rc"
}
