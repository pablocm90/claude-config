---
description: Show working-tree diff stats for the current folder and any subrepos
allowed-tools: Bash(git:*), Bash(ls:*), Bash(basename:*), Bash(printf:*), Bash(bash:*)
---

Working-tree status across all git repos under `$PWD`:

!`bash -c '
shopt -s nullglob
found=0
for d in "$PWD" "$PWD"/*/; do
  d="${d%/}"
  [ -e "$d/.git" ] || continue
  found=1
  printf "\n=== %s ===\n" "$(basename "$d")"
  git -C "$d" status -sb
  git -C "$d" diff --stat HEAD 2>/dev/null || true
done
if [ "$found" -eq 0 ]; then
  echo "(no git repos found in $PWD or its immediate subdirs)"
fi
'`
