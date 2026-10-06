---
name: diagnosing-bugs
description: Diagnose a bug, regression, flaky test, CI failure or slowdown by first building a loop that goes red on it. Use when something is broken, throwing, failing, flaky or slow, locally or in CI, or the user says "debug" or "diagnose".
metadata:
  credits:
    author: Matt Pocock
    url: https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnosing-bugs/SKILL.md
    license: MIT
---

# Diagnosing Bugs

A bug is found by a loop, not by reading code. Build a **red** loop first (one command that fails on *this* bug) and the rest is mechanical. Work the phases in order; skip one only by saying why.

## Redact

Redact everything you show (commands, output, captured payloads): `<REDACTED>` in place of secrets, tokens, credentials and customer data (names, emails, IBANs). Keep credentials in env vars so they never appear in the loop's text. Quote only the lines that carry the signal.

## Phase 1: Build a red loop

Spend disproportionate effort here. For a CI failure, read [resources/ci.md](resources/ci.md) first. Otherwise climb the ladder in order and take the first rung that reaches the bug:

1. **Failing test** at the seam that reaches the bug (`bin/rails test path:LINE`, `yarn vitest run path`).
2. **HTTP script** against the dev server: curl with the real request.
3. **Script against the dev database** (`bin/rails runner`, a node script) calling the code path with the bug's data shape.
4. **Headless browser script** (Playwright) asserting on DOM, console or network.
5. **Replay a captured payload**: a webhook body, an API response or a job's arguments saved to a scratch file and fed through the code path.
6. **Throwaway harness**: the smallest slice of the system that runs the path with one call.
7. **Property loop**: many generated inputs, for "sometimes wrong".
8. **Bisection**: `git bisect run <loop>` when it broke between two known states.
9. **Differential loop**: the same input through old and new versions (or two configs), diffing the output.
10. **Human in the loop**: last resort. Ask for one precise action and its exact output, and script it the moment you can.

Production is never a rung. When no rung reproduces the bug, say so, list what you tried, and ask the human for a redacted artifact (error event, log excerpt, HAR, the shape of the row) to rebuild the case in dev, or for permission to add temporary instrumentation.

### Tighten it

Make it faster (narrow the scope, skip unrelated setup), sharper (assert the user's exact symptom, not "didn't crash") and deterministic (pin time, seed randomness, freeze network). A flaky bug needs a higher reproduction rate, not a clean repro: loop the trigger, add load and narrow timing windows until it fails often enough to debug.

### Done when

You can name **one command**, already run with its output shown, that is:

- [ ] **Red** on the user's exact symptom, and able to go green once fixed
- [ ] **Deterministic**, or failing at a pinned, high rate
- [ ] **Fast**: seconds, not minutes
- [ ] **Agent-runnable**, unattended

Reading code to build a theory before this command exists is the failure this skill prevents: go back to the ladder.

## Phase 2: Reproduce and minimise

Run the loop and confirm it fails with the symptom the user described, not a nearby one. Then cut inputs, data, config and steps one at a time, re-running after each cut, until every remaining element is load-bearing: removing any one turns the loop green.

## Phase 3: Hypothesise

Write 3–5 ranked hypotheses, each falsifiable: "if X is the cause, changing Y makes the bug disappear." A hypothesis without a prediction is discarded. Show the ranked list to the user and wait; they often re-rank it in one line ("we deployed a change to #3 yesterday").

## Phase 4: Instrument

Each probe tests one prediction, changing one variable at a time. Reach for a debugger or REPL first, then targeted logs at the boundaries that separate the hypotheses. Tag every temporary log `[DEBUG-<4 hex>]` so cleanup is one grep.

For slowness, measure a baseline first (timing harness, APM trace, query plan), then bisect. Logs rarely find a performance bug.

## Phase 5: Fix with a regression test

Turn the minimised case into a failing test at a **correct seam**: one where the test exercises the bug as it happens at the real call site. Then run the `tdd` cycle from RED: watch it fail, fix, watch it pass.

When the only reachable seam is too shallow to replay the real chain, that absence is the finding. Record it in the plan or PR as a candidate for architecture work.

## Phase 6: Clean up

- [ ] The Phase 1 loop, on the original un-minimised case, no longer reproduces
- [ ] The regression test passes, or the missing seam is recorded
- [ ] `grep -rn 'DEBUG-'` finds nothing you added
- [ ] Scratch scripts and harnesses live outside the repo or are deleted
- [ ] The commit or PR names the hypothesis that proved true, so the next debugger learns it
