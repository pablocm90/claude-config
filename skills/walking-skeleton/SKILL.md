---
name: walking-skeleton
description: Build the first slice as a thin end-to-end system that really runs — walking skeleton, tracer bullet, or steel thread. Use when starting a greenfield project, service, or subsystem; when the first slice must prove an architecture, integration, or deployment path rather than a feature; when integration risk, "will these pieces even talk to each other", or "we have no pipeline yet" is the dominant unknown; when threading a new capability through an existing legacy system; or when asked for a tracer bullet, steel thread, spanning application, zero-feature release, or "hello world through the whole stack".
---

# Walking Skeleton

A walking skeleton is **a tiny implementation of the system that performs a small end-to-end function**. It need not use the final architecture, but it should link together the main architectural components. Architecture and functionality then evolve in parallel.

The point is not the feature. The point is that a real request goes in one end of a real deployed system, crosses every boundary you are afraid of, and comes out the other end — with an automated test proving it, on infrastructure you can redeploy at will. **N% of the system, 100% real**, where N is as close to zero as you can make it while still touching every boundary.

## Attribution

- **Walking skeleton** — Alistair Cockburn, *Crystal Clear* (2004).
- **Tracer bullets** — Andy Hunt & Dave Thomas, *The Pragmatic Programmer* (1999).
- **Steel thread** — origin in systems/aerospace engineering; popularised for software by Jade Rubick.
- **First end-to-end test / build-deploy-test cycle** — Steve Freeman & Nat Pryce, *Growing Object-Oriented Software, Guided by Tests* (2009), ch. 4 & 10.
- **"Start with a Walking Skeleton"** — Clint Shank, *97 Things Every Software Architect Should Know*.
- **Cupcake** — Brandon Schauer, via Industrial Logic.

Load `resources/source-notes.md` for source-by-source provenance.

**Deep-dive resources** — load on demand:

| Resource | Load when... |
|----------|-------------|
| `resources/worked-examples.md` | You want concrete skeletons: Rails API service, TypeScript/React front end, third-party integration, data pipeline, and a brownfield steel thread through legacy code |
| `resources/source-notes.md` | You need provenance, want to teach the concepts, or need to justify the approach to a team |

## How This Fits With Other Skills

`story-splitting` answers *which* thin slice is worth building. This skill answers *what the first one owes you* and how to build it. Use `story-splitting` first when the input is an epic; come here when the chosen first slice's job is to prove the path exists.

The skeleton's first end-to-end test **is** the RED step. Run `tdd` inside the skeleton, not after it. `testing` and `front-end-testing` cover how to write the end-to-end test; `api-design` keeps the boundary you thread through coherent; `ci-debugging` when the pipeline you just built goes red.

For a skeleton through **untested legacy code**, load `finding-seams` and `characterisation-tests` first — you need a safe substitution point before threading anything new through it.

Then hand off: `planning` sequences the flesh, `find-gaps` checks the deferrals you wrote down were deliberate.

Under `mmmss-stride`, the skeleton is **not** one big first commit. See "Building It In Strides" below.

## The Terms, Distinguished

Teams use these words interchangeably and then argue past each other. They are not the same thing.

| Term | Thin in... | Real in... | Survives? | Primary risk it burns |
|---|---|---|---|---|
| **Walking skeleton** | Functionality | Architecture, deployment, tests | Yes — it becomes the system | Integration + deployment |
| **Tracer bullet** | Functionality | Everything it touches (error handling, structure, checks) | Yes — grows into the product | Aim: are we building toward the right target? |
| **Steel thread** | Breadth | One important use case, end to end | Yes | Complexity + integration in an existing system |
| **Spike** | Everything except the question | Nothing | **No** — delete it | One specific technical unknown |
| **Prototype** | Depth — all facade | Nothing behind it | **No** — throw it away | Design/UX viability |
| **MVP / cupcake** | Scope | The full user experience, tastefully finished | Yes | Product viability — will anyone want it? |

**Walking skeleton and tracer bullet are the same practice under two metaphors.** The skeleton metaphor stresses *structure* (bones connected, able to walk); the tracer metaphor stresses *feedback* (you can see where the round landed and correct your aim). Steel thread is the same idea aimed at one use case, and is the term that travels best in a brownfield system. Use whichever word your team already uses.

**The one that matters most:** a skeleton is *not* a prototype. Prototype code is facade — "like a town in a western movie." Skeleton code is production code that happens to do almost nothing. If you would be embarrassed to leave it in the repo, you built a prototype and called it a skeleton.

The cupcake distinction is worth keeping too: a skeleton proves the *infrastructure*; a cupcake proves the *product*. Neither substitutes for the other. A skeleton that ships to users without ever becoming a cupcake has proven a pipeline nobody wanted.

## Core Principles

### It Must Walk

"Runs on my machine" is a skeleton lying on the table. Walking means an automated build deploys it to a production-like environment and an automated test exercises it there. If deployment is manual, the deployment is the least-tested and highest-risk part of your system, and you have skipped it.

### It Must Be A Skeleton

Every major architectural component and every communication path between them is present and real. A skeleton missing one bone is exactly the bone that will break later — the boundary you skipped is the one you were most uncertain about, which is why you skipped it.

### The Functionality Should Be Boring On Purpose

Keep the application behaviour so simple that it is obvious and uninteresting. Its job is to be a payload, not a feature. If the first slice's *logic* is interesting, it will absorb the attention that belongs to the infrastructure, and you will end up with a well-tested calculation running nowhere.

Deliberately boring payloads: echo a constant, persist one field and read it back, forward one webhook, sum one column, return one row.

### It Is Production Code

Error handling, structure, logging, and tests are present. Not feature-complete; not shoddy. This is the whole difference between a tracer bullet and a prototype, and it is the rule teams break first.

### The Architecture Is Allowed To Be Wrong

Cockburn's wording is deliberate: *it need not use the final architecture*. The skeleton is how you find out the architecture is wrong while changing it is still cheap. Do not delay the skeleton until the design is settled — the skeleton is one of the instruments that settles it.

### Expose Uncertainty Early

Order the work so the scariest boundary is crossed first. The value of a skeleton is concentrated almost entirely in the moments it fails. A skeleton that goes green on the first run through familiar territory told you nothing; you should be mildly disappointed.

## Do You Actually Need One?

Build a walking skeleton when **most** of these hold:

- Greenfield project, service, or subsystem — there is no path yet.
- A boundary is unproven: a new datastore, queue, third-party API, auth scheme, runtime, or deployment target.
- No automated build/deploy/test cycle exists for this thing.
- Multiple teams or components must meet, and nobody has seen them meet.
- The architecture is a hypothesis and the cost of being wrong scales with how much you build first.

**Do not** build one when:

- The path already exists and is exercised daily. Adding a field to an existing Rails endpoint does not need a skeleton; it needs `tdd`.
- The unknown is a single technical question with a yes/no answer — that is a **spike**. Timebox it, learn, delete it.
- The unknown is whether users want the thing — that is a **cupcake/MVP**, and the answer comes from `story-splitting`.
- You are being asked to "set up the project properly" with no end-to-end function in mind. Scaffolding that never walks is not a skeleton.

## Workflow

### 1. Map The Boundaries

Draw the simplest possible picture — boxes for components, lines for the communication paths between them, and the outside world at each edge. Keep it small enough to fit on one screen. This picture is the specification of the skeleton: **every box and every line must exist in it.**

Mark each line with what you don't know about it. Those marks are your build order.

### 2. Choose The Thread

Pick the one end-to-end function that crosses the most marked lines with the least logic.

| Heuristic | Question |
|---|---|
| Crossing count | Which function touches the most components you are unsure about? |
| Payload triviality | Can the behaviour be stated in one boring sentence? |
| Observability | Can I see the result from outside the system without a debugger? |
| Reversibility | If the architecture is wrong, how much do I throw away? |
| Real-world honesty | Does it use the real datastore/queue/API, not an in-memory stand-in? |

If two candidates tie, choose the one whose failure would be most expensive to discover in three months.

### 3. Write The End-to-End Test First

This is the RED step and it is the hardest part of the whole exercise — deliberately so. Writing a test that drives the system from outside forces you to answer, on day one: how is this deployed, how is it configured, how is it started, how is it addressed, how is its state reset, and what does "correct" look like from the edge?

Every one of those questions is architecture. Answering them now is the payoff.

The test asserts the boring payload's observable outcome from outside the system. It must fail for the right reason — nothing deployed yet — not because of a typo in a URL.

### 4. Automate Build → Deploy → Test

Get to a single command that builds, deploys to a production-like environment, and runs the end-to-end test. Do this *before* the test passes, not after. Manual steps here become permanent; every one you leave is a boundary that stays untested for the life of the project.

### 5. Walk It

GREEN. The thinnest real implementation that makes the end-to-end test pass through real components. Stub nothing you were uncertain about. Then run the whole cycle again from a clean state to prove it repeats.

### 6. Build Sources Of Feedback

A skeleton that walks silently is only half useful. Add, at minimum: structured logging on each hop, a health/readiness check, and whatever error reporting the system will use forever. You are choosing the observability stack now, while there is one code path to instrument instead of two hundred.

### 7. Write Down The Deferrals, Then Grow Flesh

Record explicitly what the skeleton does *not* yet prove — the boundaries stubbed, the scale untested, the auth faked. Undocumented deferrals become assumed-solved problems.

Then hand off to `story-splitting` / `planning`. From here every feature is added by the same cycle: end-to-end test first, then units, keeping the system deployable at all times.

## What Goes In, What Stays Out

| Include — always | Exclude — until later |
|---|---|
| Every architectural component, connected | Real business rules beyond the boring payload |
| Real datastore, real queue, real transport | Performance, scale, and caching |
| Automated build, deploy, and end-to-end test | UI polish and design fidelity |
| Configuration and secrets handling | Alternate paths, error branches, edge cases |
| Authentication mechanism (even one hardcoded principal) | Authorization rules and roles |
| Structured logging and a health check | Dashboards, alerting thresholds, SLOs |
| Third-party integrations you have never called | Every endpoint of that third party — one call is enough |

The rule for a stub: **stub what is well understood, never what is uncertain.** Stubbing a third-party API because it is slow is fine only if you have already called it for real once in this skeleton. Stubbing it because you do not know how it authenticates defeats the entire exercise.

## Building It In Strides

Under `mmmss-stride` the skeleton is not one commit. Each stride ends green and committed:

1. Project boots + one unit test runs. Commit.
2. CI runs that test on push. Commit.
3. End-to-end test harness exists and fails for the right reason. Commit.
4. Deploy pipeline puts the app in a production-like environment. Commit.
5. One boundary crossed for real — repeat this stride per boundary, in descending order of fear. Commit each.
6. End-to-end test green through the whole chain. Commit.
7. Logging + health check. Commit.

Stride 5 is where you learn things. If it takes three attempts, that is the skill working, not failing.

## Sizing

A walking skeleton should be **days, not weeks**. If it is stretching, the thread is too thick — cut payload, not boundaries. Never cut boundaries to hit a timebox; a skeleton with a missing bone is worth less than no skeleton, because it produces confidence you have not earned.

## Definition Of Done

- [ ] One command builds, deploys, and end-to-end tests the system.
- [ ] The end-to-end test runs against a deployed, production-like environment — not localhost-only, not an in-process harness.
- [ ] Every box and every line on the boundary map is exercised for real.
- [ ] Nothing uncertain is stubbed.
- [ ] It has been deployed from a clean state at least twice.
- [ ] Someone other than the author can run the whole cycle from the README.
- [ ] The application behaviour is boring enough to describe in one sentence.
- [ ] The code is production quality — you would not delete it out of embarrassment.
- [ ] Deferrals are written down explicitly.
- [ ] At least one thing surprised you. If not, say so — you may have threaded only familiar ground.

## Failure Modes

| Anti-pattern | Looks like | Why it fails |
|---|---|---|
| **Skeleton that can't walk** | Components wired, deploy is manual | Deployment stays the least-tested part of the system |
| **Prototype in disguise** | No error handling, no tests, "we'll redo it properly" | You bought none of the de-risking and still owe the work |
| **Boil-the-ocean skeleton** | Weeks in, real features creeping in | Feedback arrives after the decisions it should have informed |
| **Missing bone** | The scary boundary stubbed "for now" | You skipped precisely the risk you set out to burn |
| **Localhost skeleton** | Green on a laptop, never deployed | Environment, config, and secrets remain unproven |
| **Mocked-boundary skeleton** | End-to-end test with the datastore in memory | Proves your mocks agree with themselves |
| **Skeleton that never grows flesh** | Shipped, then abandoned for a "real" build | The bones were the cheap part; the value was in growing them |
| **Scaffolding mistaken for skeleton** | Folders, configs, base classes, no end-to-end function | Nothing has walked, so nothing is proven |
| **Skeleton as architecture theatre** | Built to ratify a design already decided | If it cannot change the design, it is not feedback |

## Output Format

When asked to plan a walking skeleton, return:

```markdown
## System Under Skeleton
[One sentence: what system, greenfield or brownfield]

## Boundary Map
[Components and the communication paths between them; mark each unknown]

## The Thread
[One boring sentence: the end-to-end function]

Why this thread: [which unknowns it crosses]

## Real vs Stubbed
| Component | Real / Stubbed | Justification |
|---|---|---|

## End-to-End Test
[What it drives from outside, what it asserts, how state is reset]

## Strides
1. ... (each ends green and committed)

## Explicit Deferrals
[What this skeleton does NOT prove]

## Biggest Risk
[The boundary most likely to break, and when we cross it]
```

For a brownfield steel thread, a Rails or TypeScript skeleton, or an integration/pipeline example, load `resources/worked-examples.md`.
