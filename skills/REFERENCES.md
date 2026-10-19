# Architectural Skill References

Authoritative sources behind the skills. Each entry documents what was taken from the source and where it appears in our skills.

---

## Domain-Driven Design

### Eric Evans — "Domain-Driven Design: Tackling Complexity in the Heart of Software" (2003) — [DDD Reference (free PDF)](https://www.domainlanguage.com/ddd/reference/)
- **Ubiquitous language** → `domain-modeling` (glossary); `domain-driven-design` intro: names in code are glossary terms
- **Entities, value objects, aggregates** → `domain-driven-design`: "Modelling a concept" steps 2–4
- **Repositories as collection-like interfaces** → `domain-driven-design`: "Repositories"
- **Domain services** (logic spanning aggregates, stateless, expressed in domain language) → `domain-driven-design`: "Where code belongs"
- **Bounded contexts** → `domain-driven-design`: "Bounded contexts"
- **"Always-valid" entities** (invariants enforced at all times) → `domain-driven-design`: "Aggregate rules"

### Vaughn Vernon — ["Implementing Domain-Driven Design"](https://www.informit.com/store/implementing-domain-driven-design-9780321834577) (2013)
- **Aggregate design rules** (small aggregates, reference by ID, one per transaction) → `domain-driven-design`: "Aggregate rules"
- **Domain services vs application services distinction** → `domain-driven-design`: "Where code belongs" table

### Martin Fowler — [martinfowler.com](https://martinfowler.com)
- **Anemic domain model anti-pattern** → `domain-driven-design`: "Growing the model" (when a rule leaves the use case)
- **CQRS pattern** (separating read and write models) → `hexagonal-architecture`: "Reads versus writes"
- **Repository pattern** (collection-like semantics) → `domain-driven-design`: "Repositories"

### Khalil Stemmler — [khalilstemmler.com](https://khalilstemmler.com)
- **Value objects as plain types with factory functions** (functional approach) → `domain-driven-design`: "Functional style" (branded type with a parse constructor)
- **Module-based composition roots** (no DI container) → `hexagonal-architecture`: "Dependency injection"

### Microsoft — [.NET Architecture Guidance](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/)
- **Domain layer contents** (entities, value objects, aggregates, domain services — NOT read models) → `domain-driven-design`: "Where code belongs"
- **Purity is necessary but not sufficient for domain placement** → `domain-driven-design`: "Where code belongs", closing paragraph
- **Testing by layer** (unit for domain, integration for adapters) → `hexagonal-architecture`: "Testing"

### Scott Wlaschin — "Domain Modeling Made Functional" (2018) + [fsharpforfunandprofit.com](https://fsharpforfunandprofit.com/ddd/)
- **"Making Illegal States Unrepresentable"** — one shape per state with discriminated unions → `domain-driven-design`: "Modelling a concept" step 3, "Functional style"; Rust enums and typestate in `resources/rust.md`
- **Workflows as functions** whose input is a command and output is events → `domain-driven-design/resources/domain-events.md`
- **Validate at boundaries, trust inside** → `domain-driven-design`: "Functional style", last paragraph

### Jeremie Chassaing — ["Functional Event Sourcing Decider"](https://thinkbeforecoding.com/post/2021/12/17/functional-event-sourcing-decider) (2021)
- **Decider pattern** (`decide(command, state) → events[]`, `evolve(state, event) → state`) → `domain-driven-design/resources/domain-events.md`: "The decider pattern"

### Vladimir Khorikov — [Enterprise Craftsmanship](https://enterprisecraftsmanship.com)
- **Domain events add complexity** — "If all consumers reside within the same database transaction, domain events add very little value" → `domain-driven-design/resources/domain-events.md`: "When to use them"

### Greg Young — CQRS and Event Sourcing
- **CQRS is not event sourcing** → `hexagonal-architecture`: "Reads versus writes"; `domain-events.md`: a decider does not require event sourcing
- **"Current state is a left fold of previous events"** → `domain-driven-design/resources/domain-events.md`: `evolve` and `reduce`

### Udi Dahan — [Clarified CQRS](https://udidahan.com/2009/12/09/clarified-cqrs/)
- **CQRS-lite is sufficient** — separating reads from writes needs no separate database or async messaging → `hexagonal-architecture`: "Reads versus writes"

### Lev Gorodinski — ["Domain Services vs Application Services"](https://gorodinski.com/blog/2012/04/14/services-in-domain-driven-design-ddd/)
- **Domain services** (business rules, domain types only) vs **application services** (orchestration, infrastructure) → `domain-driven-design`: "Where code belongs" table

---

## Hexagonal Architecture

### Alistair Cockburn — ["Hexagonal Architecture"](https://alistair.cockburn.us/hexagonal-architecture/) (2005)
- **Core concept** (application as hexagon, ports on edges, adapters outside) → `hexagonal-architecture`: opening diagram
- **Primary (driving) vs secondary (driven) ports/adapters** → `hexagonal-architecture`: opening definitions
- **"Configurable Dependency"** — the hexagon declares needs via ports, a startup configurer wires adapters → `hexagonal-architecture`: composition root, "Dependency injection"
- **Port granularity** (a handful of ports, named by purpose, "For…") → `hexagonal-architecture`: "Port design"
- **Tests as just another driving adapter** → `hexagonal-architecture`: "Testing"

### Thomas Pierrain — "Outside-In Diamond TDD" + hexagonal architecture talks
- **"A good adapter is a pretty dumb adapter"** → `hexagonal-architecture`: "Adding behaviour that crosses the boundary" step 5

### Herberto Graca — ["DDD, Hexagonal, Onion, Clean, CQRS… How I put it all together"](https://herbertograca.com/2017/11/16/explicit-architecture-01-ddd-hexagonal-onion-clean-cqrs-how-i-put-it-all-together/)
- **Hex arch as the structural container, DDD as the model inside** → the split between `hexagonal-architecture` and `domain-driven-design`, and their cross-references

### Netflix Tech Blog — ["Ready for changes with Hexagonal Architecture"](https://netflixtechblog.com/ready-for-changes-with-hexagonal-architecture-b315ec967749) (2020)
- **Port design by business purpose, not technology**; swapping a data source adapter without touching the core → `hexagonal-architecture`: "Port design"

### Mark Seemann — "Dependency Injection in .NET" + [blog.ploeh.dk](https://blog.ploeh.dk)
- **"Functional architecture is ports and adapters"** and the **impureim sandwich** → `hexagonal-architecture`: "Dependency injection", prefer passing values
- **"Dependency rejection"** — pure domain functions take values, not injected abstractions → `hexagonal-architecture`: "Dependency injection"
- **Composition root; no DI container** → `hexagonal-architecture`: "Dependency injection"

### Valentina Jemuović (née Cupac) — [Optivem Journal](https://journal.optivem.com), [Tech Excellence](https://techexcellence.io)
- **Primary test boundary is the use case** — test by calling use cases with faked driven ports → `hexagonal-architecture`: "Testing"; `domain-driven-design`: "Testing"
- **Fakes over mocks** — "Fake data, not behavior. Test behavior, not calls." → `hexagonal-architecture`: "Testing"
- **Domain unit tests as complement** — complex pure rules tested directly → `hexagonal-architecture`: "Testing"; `domain-driven-design`: "Testing"
- **Narrow integration tests for driven adapters** → `hexagonal-architecture`: "Testing"
- Key articles:
  - ["TDD: Test the API, NOT the World"](https://journal.optivem.com/p/tdd-test-the-api-not-the-world)
  - ["Unit Testing Use Cases or Domain?"](https://journal.optivem.com/p/unit-testing-use-cases-or-domain)
  - ["Hexagonal Architecture: Do NOT Mock Everything"](https://journal.optivem.com/p/hexagonal-architecture-do-not-mock-everything)
  - ["Unit Tests Passed. The Bug Shipped Anyway."](https://journal.optivem.com/p/unit-tests-passed-the-bug-shipped-anyway)

---

## API and Interface Design

### Addy Osmani — [agent-skills/api-and-interface-design](https://github.com/addyosmani/agent-skills/blob/main/skills/api-and-interface-design/SKILL.md)
- **Original skill** adapted and extended for this codebase → API design skill: foundation for contract-first, error semantics, REST conventions, naming patterns
- Modified: `interface` → `type` with `readonly`, TypeScript patterns deferred to `typescript-strict` skill

### Hyrum Wright — [Hyrum's Law](https://www.hyrumslaw.com/)
- **"All observable behaviors will be depended on by somebody"** → API design skill: "Core Principles" section, design implications for what to expose

### Joshua Bloch — ["How to Design a Good API and Why it Matters"](https://www.youtube.com/watch?v=aAb7hSCtvGw) (2006, Google Tech Talk)
- **"When in doubt, leave it out"** — APIs should be as small as possible but no smaller → API design skill: contract-first development, intentional exposure
- **"APIs should be easy to use and hard to misuse"** → API design skill: overall design philosophy

### RFC 9457 — [Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457) (2023, IETF)
- **Standard error format** (`type`, `title`, `status`, `detail`, `instance`) → API design skill: "Consistent Error Semantics" section
- **Extension members** for forward-compatible error evolution → API design skill: validation error example with `errors` array
- **Security considerations (§5)** — error responses as information leak vectors → API design skill: security warnings on error design
- Updated from RFC 7807 (2016) with registry of common problem types and multi-problem guidance

### RFC 8594 — [The Sunset HTTP Header Field](https://www.rfc-editor.org/rfc/rfc8594) (2019, IETF)
- **Standard deprecation signaling** — programmatic detection of upcoming endpoint removal → `resources/api-evolution.md`: "Deprecation Signals"

### RFC 6585 — [Additional HTTP Status Codes](https://www.rfc-editor.org/rfc/rfc6585) (2012, IETF)
- **429 Too Many Requests** — proper status code for rate limiting → API design skill: "Rate Limiting" section

### IETF Draft — [RateLimit Header Fields for HTTP](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)
- **Standard rate limit headers** (`RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`) → API design skill: "Rate Limiting" section

### Brandur Leach (ex-Stripe) — [brandur.org](https://brandur.org/)
- **Idempotency keys** — definitive implementation guide for safe retries → API design skill: "Idempotency" section
- **API versioning at Stripe** — date-based version pinning, additive evolution → `resources/api-evolution.md`: "Date-Based Version Pinning"
- Key articles:
  - ["Idempotency Keys: How PayPal and Stripe Prevent Duplicate Payment"](https://brandur.org/idempotency-keys)

### OWASP — [API Security Top 10](https://owasp.org/API-Security/) (2023)
- **BOLA (#1)** — object-level authorization on every endpoint → `resources/api-security.md`: all 10 items covered with code examples
- **Mass assignment (#3)** — schema validation prevents accepting unauthorized fields → Aligns with `typescript-strict` skill's boundary validation

### Google — [API Design Guide](https://cloud.google.com/apis/design)
- **Resource-oriented design** — model as resource hierarchy with standard methods → API design skill: REST conventions
- **Standard error model** — `code`, `message`, `details` → Influenced error semantics section

### Microsoft — [REST API Guidelines](https://github.com/microsoft/api-guidelines)
- **Consistency across a large portfolio** — more valuable than optimizing any single API → API design skill: naming conventions table
- **Long-running operations pattern** — for async API operations

### Zalando — [RESTful API Guidelines](https://opensource.zalando.com/restful-api-guidelines/)
- **MUST/SHOULD/MAY classification** — makes guidelines actionable and auditable → API design skill: verification checklist approach
- **RFC 7807/9457 mandate** — standard error format across all services → API design skill: RFC 9457 section

### Phil Sturgeon — [apisyouwonthate.com](https://apisyouwonthate.com/)
- **"API Versioning Has No Right Answer"** — analysis of versioning tradeoffs → `resources/api-evolution.md`: versioning decision framework
- *Build APIs You Won't Hate* (2015) — practical, opinionated API design
- Key articles:
  - ["API Versioning Has No Right Answer"](https://apisyouwonthate.com/blog/api-versioning-has-no-right-answer)

### Arnaud Lauret ("The API Handyman") — [apihandyman.io](https://apihandyman.io/)
- *The Design of Web APIs* (Manning, 2019) — consumer-first design methodology
- **"Errors should be actionable"** — consumer knows what went wrong, why, and what to do → API design skill: error design philosophy

### Jon Postel — Robustness Principle (RFC 761)
- **"Be conservative in what you send, be liberal in what you accept"** → `resources/api-evolution.md`: foundation for additive API evolution

### Pact — [Consumer-Driven Contract Testing](https://pact.io/)
- **Consumer defines expectations, provider verifies** → `resources/api-evolution.md`: know what will break before you break it

### RFC 9205 (BCP 56) — [Building Protocols with HTTP](https://www.rfc-editor.org/rfc/rfc9205) (2022, IETF)
- **The cardinal rule** — don't redefine HTTP semantics → `resources/http-fundamentals.md`: core principle
- **URI schemes** — use HTTPS, avoid custom URI schemes → `resources/http-fundamentals.md`: "URI Schemes"
- **HTTP caching** — explicit freshness, Cache-Control directives, ETags, Vary → `resources/http-fundamentals.md`: "HTTP Caching" + API design skill: "HTTP Caching" section
- **Browser security for APIs** — security headers even for non-browser APIs → `resources/http-fundamentals.md` + `resources/api-security.md`: "Browser Security Headers"
- **Status code discipline** — don't map errors 1:1, use general codes → `resources/http-fundamentals.md`: "Status Code Discipline"

### RFC 8725 (BCP 225) — [JWT Best Current Practices](https://www.rfc-editor.org/rfc/rfc8725) (2020, IETF)
- **Algorithm allowlisting** — never let the token header dictate the algorithm → `resources/auth-security.md`: "Algorithm Allowlisting"
- **Claim validation** — validate iss, sub, aud, exp on every JWT → `resources/auth-security.md`: "Claim Validation"
- **Explicit typing** — use `typ` header to prevent cross-JWT confusion → `resources/auth-security.md`: "Explicit Typing"
- **Input sanitization** — kid as injection vector, jku/x5u as SSRF vector → `resources/auth-security.md`: "Input Sanitization"
- **Compression oracle** — don't compress before encryption → `resources/auth-security.md`: "Encoding and Compression"

### RFC 9700 (BCP 240) — [OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700) (2025, IETF)
- **Grant type selection** — Authorization Code + PKCE for all clients, no Implicit or ROPC → `resources/auth-security.md`: "Grant Type Selection"
- **PKCE enforcement** — mandatory for public clients, recommended for all → `resources/auth-security.md`: "PKCE"
- **Redirect URI validation** — exact string matching only → `resources/auth-security.md`: "Redirect URI Validation"
- **Token handling** — sender-constraining, audience restriction, no query params → `resources/auth-security.md`: "Token Handling"
- **CSRF defense** → `resources/auth-security.md`: "CSRF Defense"

### RFC 9325 (BCP 195) — [TLS Recommendations](https://www.rfc-editor.org/rfc/rfc9325) (2022, IETF) + RFC 8996 — [Deprecating TLS 1.0/1.1](https://www.rfc-editor.org/rfc/rfc8996) (2021)
- **TLS 1.2 minimum, TLS 1.3 preferred** → `resources/api-security.md`: "Transport Security"

### RFC 6648 (BCP 178) — [Deprecating the "X-" Prefix](https://www.rfc-editor.org/rfc/rfc6648) (2012, IETF)
- **Stop using X- prefixed headers** → API design skill: Resource Naming table

### RFC 6302 (BCP 162) — [Logging Recommendations for Internet-Facing Servers](https://www.rfc-editor.org/rfc/rfc6302) (2011, IETF)
- **What to log for internet-facing servers** — source/destination addresses and ports, timestamps, transport protocol → Twelve-factor skill: Factor XI (Logs)

---

## CLI Design

### Aanand Prasad, Ben Firshman, Carl Tashian, Eva Parish — [Command Line Interface Guidelines](https://clig.dev/) ([source](https://github.com/cli-guidelines/cli-guidelines))
- **The canonical modern CLI design guide** — philosophy, output design, composability, TTY detection, error handling, subcommands, flag naming, config precedence → CLI design skill: foundation for every section
- **stdout for data, stderr for messaging** → CLI design skill: "The Unix Stream Contract"
- **Three-tier output hierarchy** (default/`--plain`/`--json`) → CLI design skill: "Format Flag Contract"
- **TTY detection and color disable** (`NO_COLOR`, `TERM=dumb`, `--no-color`) → CLI design skill: "TTY Detection"
- **Config precedence** (flags > env > project > user > system) → CLI design skill: "Config Precedence"
- **Composability** (support `-` for stdin, detect interactive terminal) → CLI design skill: "Composability Patterns"
- **Signal handling** (Ctrl-C: exit fast, bounded cleanup, crash-only) → `resources/stream-contracts.md`

### Jeff Dickey (oclif creator) — ["12 Factor CLI Apps"](https://medium.com/@jdxcode/12-factor-cli-apps-dd3c227a0e46) (2018)
- **12 principles for CLI excellence** → CLI design skill: informed multiple sections
- **"Using stdout for informational messages makes utilities unusable for pipeable CLIs"** → CLI design skill: core principle
- **Prefer flags to args** (1 OK, 2 suspicious, 3+ never) → CLI design skill: "Input Design"
- **Target < 500ms startup** → CLI design skill: verification checklist
- **Error messages: code + title + description + fix + URL** → CLI design skill: "Error Design"
- **Follow XDG-spec** for config file locations → CLI design skill: "Config Precedence"

### Heroku Engineering — [Heroku CLI Style Guide](https://devcenter.heroku.com/articles/cli-style-guide)
- **stdout stability guarantee** — "commands must not change their stdout after GA in ways that break scripts" → CLI design skill: "Output Stability Contract"
- **Human output should be grep-parseable** (flat rows, no borders) → CLI design skill: `--plain` format
- **Color conventions** (red/yellow for errors/warnings, respect `NO_COLOR`) → CLI design skill: "TTY Detection"

### galligan — ["Console vs. Logger: Best Practices for CLI Tools & TypeScript Libraries"](https://gist.github.com/galligan/8caddedbdbd830c9731de03eb177e4fd)
- **Three-layer architecture** (presentation, handler, infrastructure) → CLI design skill: "Keep Handlers Pure"
- **Silent library principle** — zero output unless app configures logging → `resources/output-architecture.md`: logger interface
- **`--json` contract** — stdout only valid JSON, stderr continues, errors JSON too, schema versioned → CLI design skill: "Format Flag Contract"
- **noConsole lint rules per layer** → `resources/output-architecture.md`: lint configuration

### yogin16 — [better-cli](https://github.com/yogin16/better-cli)
- **17 rules** (P0/P1/P2 priority-ordered) and **8 anti-patterns** → CLI design skill: "Anti-Patterns" section, verification checklist
- **Agent-readiness checklist** (18 items) → CLI design skill: "Verification Checklist"
- **Exit code taxonomy** (0/1/2/3/4/5/75/78) including transient distinction → CLI design skill: "Exit Codes"
- **Error code taxonomy** (domain-prefixed: AUTH_EXPIRED, CONFIG_MISSING, etc.) → CLI design skill: "Error Design"
- **Token efficiency benchmarks** (full JSON 626K tokens → `--fields` 13K → `--quiet` 1.6K) → CLI design skill: anti-pattern #11

### steipete — [create-cli](https://github.com/openclaw/skills/blob/main/skills/steipete/create-cli/SKILL.md) (via openclaw/skills)
- **CLI spec template** — structured format for designing CLI surface area before implementation → CLI design skill: overall structure follows this template
- **Deliverables checklist** (command tree, flags table, I/O contract, exit codes, examples) → CLI design skill: "Verification Checklist"

### Liran Tal — [Node.js CLI Apps Best Practices](https://github.com/lirantal/nodejs-cli-apps-best-practices)
- **37 best practices** organized across 12 sections → `resources/output-architecture.md`, `resources/testing-cli.md`: Node.js-specific patterns
- **POSIX signal handling** (SIGINT, SIGTERM) → `resources/stream-contracts.md`: "Signal Handling"
- **Cross-platform etiquette** (path.join, double quotes, node prefix) → `resources/stream-contracts.md`
- **Graceful degradation** (detect TTY, skip prompts/colors when piped) → CLI design skill: "TTY Detection"

### Orhun Parmaksız — ["Why stdout is faster than stderr?"](https://blog.orhun.dev/stdout-vs-stderr/) (2023)
- **stdout ~2x faster than stderr** due to buffering: stdout is line-buffered (TTY) or block-buffered (pipe), stderr is unbuffered → `resources/stream-contracts.md`: "Buffering Behavior"
- **Performance difference is entirely userspace buffering** — raw write() syscalls perform identically → `resources/stream-contracts.md`
- **isatty() determines buffering strategy at program startup** → CLI design skill: "The Unix Stream Contract"

---

## Legacy Code

### Michael Feathers — *Working Effectively with Legacy Code* (2004)
- **Seam model** (Chapter 4) — a seam is a place where you can alter behavior without editing in that place; every seam has an enabling point → Finding seams skill: "Core Concept" + all seam types
- **Preprocessing seams, link seams, object seams** — three categories mapped to TypeScript equivalents (module seams, object seams, function parameter seams, configuration seams) → `finding-seams/resources/seam-types.md`
- **Dependency-breaking techniques** (Extract and Override Method, Parameterize Constructor/Method, Extract Interface, Introduce Instance Delegator, Replace Function with Function Pointer) → `finding-seams/resources/creating-seams.md`
- **Sensing vs separation** — the two reasons to break dependencies → Finding seams skill: used throughout technique examples
- **Characterization tests** (Chapter 13) — tests that document actual behavior, not intended behavior → Characterisation tests skill: "Core Concept" + algorithm
- **The 5-step algorithm** (use in harness, fail, observe, record, repeat) → Characterisation tests skill: "The Algorithm"
- **Heuristics for writing characterization tests** (coverage-guided, production behavior as spec, focus on change area) → Characterisation tests skill: "Heuristics"
- **Targeted testing** — after characterising, verify tests exercise paths you're about to change; type conversion traps → `characterisation-tests/resources/writing-process.md`
- **Pinch points** — narrowings in effect graphs where tests against few methods detect changes in many → `characterisation-tests/resources/writing-process.md`
- **The Method Use Rule** — before using a method in legacy code, check for tests; if none, write them → `characterisation-tests/resources/writing-process.md`
- **Legacy code definition** — "code without tests" → Characterisation tests skill: motivating context

### Martin Fowler — ["Legacy Seam"](https://martinfowler.com/bliki/LegacySeam.html)
- **Three uses of seams beyond testing** — breaking dependencies for testing (original), observability (monitoring probes), legacy displacement (redirecting flow to modern systems) → Finding seams skill: informed the broader perspective on seam utility

### Mike Pennisi (Bocoup) — ["Seams in JavaScript"](https://www.bocoup.com/blog/seams-in-javascript)
- **Four seam types adapted for JavaScript** — preprocessing, method, function parameter, module seams → `finding-seams/resources/seam-types.md`: JavaScript-specific seam taxonomy

### Mike Bland — ["Legacy Code, Seams, and the Most Important Design Guideline"](https://mike-bland.com/2023/08/23/legacy-code-seams-and-the-most-important-design-guideline.html) (2023)
- **Electrical outlet analogy** — well-designed seams define contracts, isolate components, include safety infrastructure, enable testability → Finding seams skill: design philosophy
- **"Testable interfaces inherently constitute good interfaces regardless of testing contexts"** → Finding seams skill: seams as design improvement, not just test scaffolding

### Nicolas Carlo (understandlegacycode.com) — ["Key Points of Working Effectively with Legacy Code"](https://understandlegacycode.com/blog/key-points-of-working-effectively-with-legacy-code/)
- **3-step characterization process under deadline pressure** (generate output, achieve coverage, verify with mutation testing) → `characterisation-tests/resources/writing-process.md`
- **Coverage-guided + mutation-verified characterisation** → `characterisation-tests/resources/modern-tooling.md`

---

## Cross-Cutting Patterns

### Dave Farley — "Modern Software Engineering" (2022)
- **Test behavior, not implementation** → Testing skill: "Core Principle"
- **Test properties** (8 properties of good tests) → Test design reviewer skill

### Kent Beck — "Test-Driven Development: By Example" (2002)
- **RED-GREEN-REFACTOR cycle** (original formulation) → TDD skill: core workflow foundation
- **Tests as documentation of behavior** → Testing skill: test naming guidance

### Eran Boudjnah — RED-GREEN-MUTATE-REFACTOR reordering
- **Mutation testing before refactoring** → TDD skill: cycle ordering. Insight: verify test strength *before* restructuring code, so you refactor with genuine confidence. Pointed out on LinkedIn that the original RED-GREEN-REFACTOR-MUTATE order means refactoring with unverified test effectiveness.

### Gary Bernhardt — ["Boundaries"](https://www.destroyallsoftware.com/talks/boundaries) (2012)
- **Functional core, imperative shell** — pure domain logic surrounded by impure adapters → `functional`: "Pure Functions"; `hexagonal-architecture`: "Dependency injection"
- **Testing pure core with unit tests, shell with integration tests** → `hexagonal-architecture`: "Testing"
