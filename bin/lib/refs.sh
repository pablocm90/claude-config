#!/usr/bin/env bash
# Reference heuristics for the review's map: given a changed file, which files
# reference it, and which modules it reaches for. Fast greps only — madge builds
# the real TypeScript graph and the --html report prefers it where available,
# but a terminal review cannot wait ~30s for it.
#
# Dispatch is on the file's language, never on where the project keeps it. The
# earlier `app/*.rb|lib/*.rb` and `src/*.ts` cases silently returned nothing for
# a Rails engine, a monorepo package, or a bare scripts directory.

# Directories that dwarf the source around them. .claude matters most: a main
# checkout carries every task worktree under .claude/worktrees, so a repo-wide
# grep would otherwise report each hit once per open task.
REFS_SKIP=(--exclude-dir=.git --exclude-dir=.claude --exclude-dir=node_modules
           --exclude-dir=vendor --exclude-dir=.venv --exclude-dir=__pycache__
           --exclude-dir=tmp --exclude-dir=log --exclude-dir=coverage
           --exclude-dir=dist --exclude-dir=build --exclude-dir=.next)

# repo, extended-regex, include-globs...
refs_grep() {
  local repo="$1" pattern="$2"; shift 2
  local includes=() g
  for g in "$@"; do includes+=(--include="$g"); done
  grep -rlE "${REFS_SKIP[@]}" "${includes[@]}" -- "$pattern" "$repo" 2>/dev/null
}

# Absolute hits on stdin -> repo-relative, never the file itself, capped.
refs_report() {
  local repo="$1" self="$2"
  sed "s|^${repo}/||" | grep -vxF "$self" | head -10
}

ruby_const_for() {
  # app/models/foo/bar_baz.rb -> BarBaz (leaf constant, good grep token)
  basename "$1" .rb | awk -F_ '{ for (i=1; i<=NF; i++) printf toupper(substr($i,1,1)) substr($i,2) }'
}

ruby_dependents() {
  local repo="$1" file="$2" const
  const=$(ruby_const_for "$file")
  [ -n "$const" ] || return 0
  refs_grep "$repo" "\\b${const}\\b" '*.rb' '*.rake' '*.erb' | refs_report "$repo" "$file"
}

# Matches both `from '../thing'` and `require('./thing')`, with or without the
# extension the importer chose to write.
ts_dependents() {
  local repo="$1" file="$2" stem
  stem=$(basename "$file" | sed 's/\.[cm]\?[jt]sx\?$//')
  [ -n "$stem" ] || return 0
  refs_grep "$repo" "(from|require\\()[[:space:]]*['\"]([^'\"]*/)?${stem}(\\.[cm]?[jt]sx?)?['\"]" \
    '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' | refs_report "$repo" "$file"
}

ts_imports() {
  grep -oE "from ['\"][^'\"]+['\"]" "$1" 2>/dev/null \
    | sed "s/from ['\"]//; s/['\"]$//" | grep -v '^[a-z@]' | head -10
}

# Anchored to an import statement: a module name is an ordinary English word
# often enough that a bare grep would report every comment that mentions it.
py_dependents() {
  local repo="$1" file="$2" stem
  stem=$(basename "$file" .py)
  [ -n "$stem" ] || return 0
  refs_grep "$repo" "^[[:space:]]*(from|import)[[:space:]]+[[:alnum:]_.]*\\b${stem}\\b" '*.py' \
    | refs_report "$repo" "$file"
}

py_imports() {
  grep -oE "^[[:space:]]*(from|import)[[:space:]]+[[:alnum:]_.]+" "$1" 2>/dev/null \
    | sed -E 's/^[[:space:]]*(from|import)[[:space:]]+//' | head -10
}

# What references this file. Languages whose imports do not name the file --
# Go, Rust, Java -- are absent on purpose: a filename-stem grep would answer
# with noise, and an empty column is a truer answer than a wrong one.
dependents_for() {
  local repo="$1" file="$2"
  case "$file" in
    *.rb|*.rake) ruby_dependents "$repo" "$file" ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ts_dependents "$repo" "$file" ;;
    *.py) py_dependents "$repo" "$file" ;;
  esac
}

# What this file reaches for. Only first-party targets: a list of every stdlib
# and package import is noise the reviewer already knows.
imports_for() {
  local repo="$1" file="$2"
  [ -f "$repo/$file" ] || return 0
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ts_imports "$repo/$file" ;;
    *.py) py_imports "$repo/$file" ;;
  esac
}
