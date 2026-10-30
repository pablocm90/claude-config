# Commits and shipping

How each commit is sized and made, and how a branch ships. Both rhythms use it: `mmmss-stride` stops after every commit, `until-pr` keeps going until the PR is open. Neither one changes anything here.

## Commit size

**One behaviour: one test case, one commit, at most ~40 changed lines of production code across at most 3 files.** Test code does not count toward the line budget; neither do generated files or fixtures.

Wall-clock targets do not work here. The agent cannot perceive elapsed time, so a minute-based budget silently degrades into "one coherent change" — which is several times larger than a human's review appetite, and arrives as a diff too big to read carefully. A line budget is checkable: run `git diff --stat` before committing, and if production lines exceed it, the slice was too big. Split the commit; do not ship it and apologise.

The agent does not negotiate the budget mid-session.

Three signals the slice is too big, in the order they appear:

- The RED test needs more than one behaviour to express it.
- A second production file has to change before the first test can pass.
- `git diff --stat` shows more than ~40 production lines at green.

On any of them: stop. Commit the safely-green subset, or revert and pick a smaller slice.

## Inside a commit

Run TDD as usual (`tdd` skill): RED → GREEN → MUTATE → KILL MUTANTS → REFACTOR → CLEANUP. Apply project conventions (Rails / TypeScript / Ruby / etc.) as normal.

- Keep the slice inside the size budget: one behaviour, one test case, ≤ ~40 production lines, ≤ 3 files.
- If the slice has outgrown the budget and is not green, **stop adding code**. Either revert to the last green or commit the smallest safely-green subset.

## Making the commit

1. **Clean up.** Run the `cleanup` skill over the diff: print findings, fix them, reinspect, and loop until a pass is empty. A commit is made cleaned, not cleaned later.
2. **Confirm green at commit scope.** Run the tests you wrote and touched plus their immediate neighbours (the file-scoped format/lint hook already ran on every edit). Do **not** run full repo gates (`bin/check`, full suites) per commit — that's the ship loop's and CI's job. A commit's green is *local* green.
3. **Commit.** Stage deliberately; never blind `git commit -a`. One short subject line; body only if a reader needs the *why*. One concern per commit.

**On commit messages:** Many projects ban non-trivial code comments per their CLAUDE.md — the WHY belongs in commit messages and PR descriptions, not source. That puts extra weight on commit messages. Write them so a future reader can reconstruct the reasoning without the conversation context.

## Shipping

A commit is not a deploy, and the slower loops never block the next commit:

- **Ship (when a coherent slice exists):** review → pre-push gate → push → PR. **Review** each slice before it is pushed, with two parallel subagents on the slice diff: `plan-conformance` (the plan's acceptance criteria against the diff) and `pr-review-toolkit:code-reviewer` briefed on regressions (what worked on the default branch and behaves differently here). Their findings become commits before the push, and the PR's `Green` line names both. The pre-push gate runs only the fast static checks whose failures are expensive to discover via CI lag — **the project's CLAUDE.md names the exact command**, and it runs bare, as the sole command in the call (a trailing pipe or echo masks the exit code). **Nothing else runs locally** — the full test suites, security scanners and dependency audits are CI's job. Running them on both sides is the double work this section exists to kill. The PR description is headline, then `Where / Why / Ship / Look at / Not done / Green` as bullets, 150 words; the `tdd` skill's *Pull Request Requirements* holds the format. Draft it from what each commit was for, not from the diff, and fold any evidence a reviewer might still want into one collapsed `<details>` block.
- **Observe (async):** CI results surface in the PR/CI status pane (`claude-dev-status`, hub window / prefix+D). A red check is simply the next commit ("fix Verify on #NNNN") — fix-forward, never idle-wait.

**Merging is manual and human-only.** Green CI does not authorize a merge; the human clicking merge IS the deploy gate. Never run `gh pr merge` (including `--auto`) unprompted.

## Guardrails

- **Never `--no-verify`.** Repo-level hooks exist for a reason. If a hook fails, fix the underlying issue or stop and ask the human. Bypassing is not on the menu.
- **Never claim "done" with a dirty tree.** If you can't reach green, revert to the last green commit, then stop and explain.
- **Never bundle two behaviours into one commit.** If you found yourself doing two things, that's two commits.
- **Every commit has an outcome in its subject line**, never `wip` / `progress` / `checkpoint`.
- **Say so when you revert.** The revert itself is information the human needs.
