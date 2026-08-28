# Development Guidelines for Claude

> **About this file (v3.1.0):** Lean version optimized for context efficiency. Core principles here; detailed patterns loaded on-demand via skills.
>
> **Architecture:**
> - **CLAUDE.md** (this file): Core philosophy + quick reference (~150 lines, always loaded)
> - **Skills**: Detailed patterns loaded on-demand. See **Skill Map** below for the full tiered index.
> - **Agents**: Specialized subprocesses for verification and analysis
>
> **Previous versions:**
> - v3.0.0: Lean modular with skill index (no Skill Map yet)
> - v2.0.0: Modular with @docs/ imports (~3000+ lines always loaded)
> - v1.0.0: Single monolithic file (1,818 lines)

## Core Philosophy

**TEST-DRIVEN DEVELOPMENT IS NON-NEGOTIABLE.** Every single line of production code must be written in response to a failing test. No exceptions. This is not a suggestion or a preference - it is the fundamental practice that enables all other principles in this document.

I follow Test-Driven Development (TDD) with a strong emphasis on behavior-driven testing and functional programming principles. All work should be done in small, incremental changes that maintain a working state throughout development.

## Quick Reference

**Key Principles:**

- Write tests first (TDD)
- Test behavior, not implementation
- No `any` types or type assertions
- Immutable data only
- Small, pure functions
- TypeScript strict mode always
- Use real schemas/types in tests, never redefine them

**Preferred Tools:**

- **Language**: TypeScript (strict mode)
- **Testing**: Vitest (prefer Browser Mode for UI tests) + Testing Library
- **State Management**: Prefer immutable patterns

## Testing Principles

**Core principle**: Test behavior, not implementation. 100% coverage through business behavior.

**Quick reference:**
- Write tests first (TDD non-negotiable)
- Test through public API exclusively
- Use factory functions for test data (no `let`/`beforeEach`)
- Tests must document expected business behavior
- No 1:1 mapping between test files and implementation files

For detailed testing patterns and examples, load the `testing` skill.
For verifying test effectiveness through mutation analysis, load the `mutation-testing` skill.

## TypeScript Guidelines

**Core principle**: Strict mode always. Schema-first at trust boundaries, types for internal logic.

**Quick reference:**
- No `any` types - ever (use `unknown` if type truly unknown)
- No type assertions without justification
- Prefer `type` over `interface` for data structures
- Reserve `interface` for behavior contracts only
- Define schemas first, derive types from them (Zod/Standard Schema)
- Use schemas at trust boundaries, plain types for internal logic

For detailed TypeScript patterns and rationale, load the `typescript-strict` skill.
For API and interface design patterns, load the `api-design` skill.

## Code Style

**Core principle**: Functional programming with immutable data. Self-documenting code.

**Quick reference:**
- No data mutation - immutable data structures only
- Pure functions wherever possible
- No nested if/else - use early returns or composition
- No comments - code should be self-documenting
- Prefer options objects over positional parameters
- Use array methods (`map`, `filter`, `reduce`) over loops

For detailed patterns and examples, load the `functional` skill.

## Development Workflow

**Core principle**: RED-GREEN-MUTATE-KILL MUTANTS-REFACTOR-CLEANUP in small, known-good increments. TDD is the fundamental practice.

**Quick reference:**
- RED: Write failing test first (NO production code without failing test)
- GREEN: Write MINIMUM code to pass test
- MUTATE: Run mutation testing to verify test effectiveness, produce a report
- KILL MUTANTS: Address surviving mutants (ask human when value is ambiguous)
- REFACTOR: Assess improvement opportunities (only refactor if adds value)
- CLEANUP: Run the `cleanup` skill over the change — strip redundant transformations, back-compat shims, needless defensive code and dedup; loop until reinspection is empty
- **Wait for commit approval** before every commit (exception: when `mmmss-stride` is loaded, the stride boundary is the approval point — commit each green stride, then stop for review)
- Each increment leaves codebase in working state
**Canonical flow for non-trivial work:** `story-splitting` → `planning` → `tdd` (→ `mutation-testing` → `refactoring` → `cleanup`). Add `find-gaps` whenever a plan or AC set feels thin. Insert `walking-skeleton` before `planning` when the first slice's job is to prove a path exists (greenfield, unproven integration, no deploy pipeline).

### Mandatory first step — skill loading

Before planning, exploring, or writing a single line of code or test, classify the work and load the required skills. This is not optional.

**Announce the set before loading it.** State, in one line, which skills you are about to load and the work type that selected them — `Skills: tdd, testing, mutation-testing — production code change`. Name anything you are deliberately leaving out and why. The human corrects the set in the same beat they answer the opening question, before the wrong skills are in context; correcting afterwards costs a session restart. Under `mmmss-stride` this rides along in the session-opening ceremony and costs no extra round trip.

| Work type | Skills to load |
|---|---|
| Test work (any tests at all) | `tdd`, `testing`, `mutation-testing` |
| Production code changes | `tdd`, `testing`, `mutation-testing`, `refactoring`, `cleanup` |
| Structural / architectural changes | all of the above + `connascence`, `code-smells`, plus `oop` (Ruby) or `functional` + `typescript-strict` (TS) |
| Greenfield project, service, subsystem, or unproven integration | `walking-skeleton`, then `planning`, `tdd`, `testing`, `mutation-testing` |
| Significant / multi-step work | all of the above + `planning` |
| CI failure | `ci-debugging` |
| Modifying untested legacy code | `characterisation-tests`, `finding-seams`, then `tdd`, `testing` |
| API endpoint design/changes | `api-design`, then `tdd`, `testing`, `mutation-testing` |

Skills are generic; when a skill has a `resources/rails.md` or `resources/typescript.md`, also read the one matching the current repo's stack. If the nature of the work changes mid-task, load the additional skills at that point before continuing.

See **Skill Map** below for the full index.

**Project onboarding:** Run `/setup` in any new project to detect its tech stack and generate project-level CLAUDE.md, hooks, commands, and PR review agent in one shot. This replaces the need for `/init`.

**Project-level hooks:** Projects should add a PostToolUse hook in `.claude/settings.json` to auto-format/lint after Write/Edit. Per-file hooks do not replace the project's full pre-push gate.

## Skill Map

Skills are organised into four tiers. **Tier 1 is transversal** — it applies regardless of stack. Tier 2 is architecture/language-aware. Tier 3 is web/UX-specific. Tier 4 is project-scoped (auto-loaded inside the project).

### Tier 1 — Process & cross-cutting

| Skill | Use when |
|---|---|
| `story-splitting` | A large story / epic / feature / backlog item must be sliced into small end-to-end deliverables. Run **before** `planning`. |
| `walking-skeleton` | The first slice must prove an architecture, integration, or deployment path rather than a feature — greenfield project/service, an unproven boundary, no pipeline yet, or a steel thread through legacy. Also: tracer bullet, steel thread. |
| `planning` | Sequencing PR-sized slices with TDD execution details. Plans live in `plans/`. |
| `find-gaps` | Adversarially review a plan, AC set, or mock to surface missing states / edge cases / unverifiable language **before** coding. |
| `expectations` | Capture learnings, gotchas, ADRs after significant work. |
| `mmmss-stride` | Human-in-the-loop cadence: small strides, each ends green + committed, stop for review. Load by default for interactive coding sessions; overrides "wait for commit approval" (stride boundary = approval) and other workflow skills' pacing. |
| `tdd` | RED → GREEN → MUTATE → REFACTOR → CLEANUP. Non-negotiable for every code change. Governs work *inside* a stride when `mmmss-stride` is loaded. |
| `testing` | Behaviour-driven tests, factories, test file structure. |
| `mutation-testing` | Verifying test effectiveness; the MUTATE phase of `tdd`. |
| `test-design-reviewer` | Evaluate test quality against Farley's 8 properties. |
| `refactoring` | Assess improvements **after** mutation testing validates test strength. (the *how* — techniques) |
| `cleanup` | Last step of every change, after `refactoring` and before the commit: delete what the change made unnecessary; loop until reinspection finds nothing. |
| `code-smells` | Diagnostic catalog — recognise **what** needs refactoring. (the *what*) |
| `connascence` | Coupling taxonomy — decide **which direction** to refactor and **when to stop**. (the *axis*) |
| `finding-seams` | Make untestable legacy code testable without editing call sites. |
| `characterisation-tests` | Pin current behaviour of legacy code before changing it. |
| `ci-debugging` | Systematically diagnose CI / build / pipeline failures. |
| `handoff` | After a deploy/merge or when a session grows long: flush durables to memory/plan/PR, write the task handoff file, user restarts via `claude-dev cycle`. |

### Tier 2 — Architecture, language, contracts

| Skill | Use when |
|---|---|
| `api-design` | REST endpoints, module boundaries, prop interfaces, any public contract. |
| `typescript-strict` | Defining types/schemas, reviewing type safety, strict-mode flags. |
| `functional` | Logic / data transforms / mutation bugs. Don't over-apply heavy FP. |
| `oop` | Ruby/Rails OOP — SOLID, encapsulation, ActiveRecord, service/value objects, DI. Ruby codebases only; don't apply to functional TS. |

### Tier 3 — Web, frontend, UX

| Skill | Use when |
|---|---|
| `frontend-design` | Build distinctive, production-grade UI from scratch. |
| `front-end-testing` | UI / DOM tests (Vitest Browser Mode + DOM Testing Library). |
| `react-testing` | React components, hooks, context, forms. |

### Tier 4 — Project-scoped

Skills in a project's `.claude/skills/` are discovered only when the session is launched inside that project (discovery never descends into subdirectories). Genuinely single-project skills (e.g. a game's test harness) may still live in that project's `.claude/skills/`.

> **Plugin-provided skills** (`pr-review-toolkit:review-pr`, `feature-dev:feature-dev`, etc.) are namespaced with `plugin:name` and managed by their plugins — they are not in this map.

## Output Guardrails

- **Write to files, not chat** — When asked to produce a plan, document, or artifact, always persist it to a file. You may also present it inline for approval, but the file is the source of truth.
- **Plan-only mode** — When asked for a plan, design, or document only, produce ONLY that artifact. Do not write production code, test code, or make any implementation changes unless explicitly asked.
- **Incremental output** — When exploring a codebase, produce a first draft of output within 3-4 tool calls. Refine iteratively rather than front-loading all exploration before producing anything.

## Working with Claude

**Core principle**: Think deeply, follow TDD strictly, capture learnings while context is fresh.

**Quick reference:**
- ALWAYS FOLLOW TDD - no production code without failing test
- Assess refactoring after every green (but only if adds value)
- Update CLAUDE.md when introducing meaningful changes
- Ask "What do I wish I'd known at the start?" after significant changes
- Document gotchas, patterns, decisions, edge cases while context is fresh

For detailed TDD workflow, load the `tdd` skill.
For refactoring methodology, load the `refactoring` skill.
For detailed guidance on expectations and documentation, load the `expectations` skill.

## Browser Automation

Use the Playwright MCP tools (playwright plugin) for web automation: navigate → snapshot → interact via element refs → re-snapshot after page changes. Fall back to `WebFetch`/`curl` for simple content fetches.

## Resources and References

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [Testing Library Principles](https://testing-library.com/docs/guiding-principles)
- [Kent C. Dodds Testing JavaScript](https://testingjavascript.com/)
- [Functional Programming in TypeScript](https://gcanti.github.io/fp-ts/)

## Summary

The key is to write clean, testable, functional code that evolves through small, safe increments. Every change should be driven by a test that describes the desired behavior, and the implementation should be the simplest thing that makes that test pass. When in doubt, favor simplicity and readability over cleverness.
