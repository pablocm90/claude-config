---
name: front-end-testing
description: UI testing for React components, hooks, forms and pages with Vitest and Testing Library — the environment to pick, how to query and wait, and which UI tests not to write. Use when writing or reviewing any test that renders UI or a hook.
---

# Front-End Testing

`testing` holds the rules for every test: name the break, what not to test, one test per branch, one layer per behaviour, mocks at boundaries. This skill adds what is specific to UI. Before the first test, read the project's CLAUDE.md for its test environment, render helper and global mocks; they win over this file.

## The Cheapest Environment That Exercises the Behaviour

- jsdom by default, and a node environment for pure logic.
- A real browser only when the behaviour depends on layout, real CSS or a browser API jsdom lacks: a popover that must stay on screen, a drag, a resize observer.
- Appearance — copy, colour, spacing, font size, alignment — is verified live and not tested (`tdd`, "Behaviour, not appearance"). Running in a real browser is no reason to assert on computed styles.

## What a UI Test Asserts

What a user can see or do, and what leaves the component: visible text and accessible state, the request sent, the route navigated to, the callback fired and its payload. Never component state, the props a child received, hook call order or class names. When a style is the only trace of a rule (the hovered segment's legend row lights up), the rule needs an accessible handle — `aria-current`, `aria-selected`, `aria-pressed` — and its absence is design feedback, not licence to assert the colour.

Reach these through something else, or leave them untested:

- That a prop renders as text, or that a library component behaves as documented (a disabled button ignores clicks, a modal traps focus).
- A hook that one component uses: test it through that component. A hook earns its own tests when it is a shared module with rules of its own; its consumers then mock it at that seam and assert only what they pass in and what they do with its result.
- A data hook's schema, field by field: test the request it sends and the transform it applies, with a payload row for each field the server really sends as null.
- A provider tree rebuilt in each test: providers come from the project's render helper, or once from the file's `renderX`.

## Fewer, Longer Tests

A UI test follows a user through one workflow and asserts along the way; several assertions describing one flow belong in one test (Kent C. Dodds, "Write fewer, longer tests"). The next red step is often the next interaction and assertion in an existing test, not a new test that repeats its render.

- A file-level `renderX(overrides)` returns the rendered scene. No `beforeEach` render, no nested `describe`: a flat file reads top to bottom.
- Assert the cell, label or value the test's name claims, not a whole row's or a whole component's text.

## Queries

- Role and accessible name first, then label, then text; a test id only when nothing accessible exists. Never `querySelector` or class names.
- Finding an element by its visible text is a query, not a copy test: use the shortest substring that identifies it, and let no test exist only to check wording.
- `findBy*` (or a retrying `expect.element`) for what appears asynchronously, `getBy*` once it is there.
- `userEvent` over `fireEvent`.

## Waiting Without Noise

- No `act()` around Testing Library calls and no manual `cleanup()`: the library does both.
- One render barrier — await the first element the test needs — then synchronous assertions.
- `waitFor` holds one assertion and no side effects, and never wraps a `findBy*`.

## Absence Is the Trap

An assertion that something is *not* there passes whenever the query could never have found it: text that lives inside an input, a render not yet committed, copy the component transforms before showing it. Trust an absence assertion only when the same query is shown finding the element elsewhere (the line before, a sibling test), or replace it with an assertion on what should be there instead. Confirm it by deleting the guard and watching it go red.

## Mocks in UI Tests

The network is the boundary: MSW handlers set per test, and assertions on what the UI does with the response. Mock your own modules only at the seam the project chose, such as a data hook under a page.
