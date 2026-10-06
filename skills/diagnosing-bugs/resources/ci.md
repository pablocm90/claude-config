# CI failures

The CI branch of `diagnosing-bugs`.

## The loop is the exact failing command

Rung 1 for CI: run the **exact** command the job ran, locally, not a close equivalent. Read the job's config for it rather than guessing.

- Red locally: you have the loop. Continue at Phase 2.
- Green locally: the difference between the two environments **is** the bug. Narrow it until the local run goes red.

| Factor | Check |
|--------|-------|
| Runtime version | CI config vs `node -v` / `ruby -v` locally |
| OS and architecture | Linux CI vs local; arm vs x86 for native gems and binaries |
| Dependency resolution | Fresh install vs cached `node_modules` / bundle |
| Env vars and credentials | CI secrets and config vs local `.env` |
| Parallelism and test order | Workers, seeds, shared database or tmp paths |
| Memory and CPU | Runners are often smaller |
| Network | CI may block external calls |
| File system | Case sensitivity, paths that exist only locally |
| Clock | Frozen or fixture dates that a real "today" has moved past |

## Read the full log

Start from the top of the failing job, not the last line. Earlier warnings and the first failure usually carry the cause, and later errors often cascade from it.

## Proving a flake

A failure is flaky only with evidence: identical environments giving different results across independent runs, **and** a named source of non-determinism (race, clock, ordering, external service). Without both, it is a real bug. Re-running hides it, and retries or sleeps mask the race instead of fixing it.
