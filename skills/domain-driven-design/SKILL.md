---
name: domain-driven-design
description: "Domain-driven design, tactical patterns: model value objects, entities, aggregates and domain services so business invariants always hold. Use when modelling a new domain concept, deciding which aggregate or layer owns a rule, when business rules sit in use cases or handlers over raw strings, or when a type can hold an invalid state."
---

# Domain-driven design

The domain model is where business rules live, expressed in the business's own words, in types that cannot hold a state the business calls impossible. This skill is the tactical half: how to shape the code inside the hexagon. Where the boundary goes is `hexagonal-architecture`; what the words mean is `domain-modeling`, which owns the glossary. Names in code are glossary terms: when a concept has no settled name, settle it there first.

For Rust (newtypes, enums, private fields) read [resources/rust.md](resources/rust.md). For domain events and the decider pattern read [resources/domain-events.md](resources/domain-events.md), only when something outside the transaction must react to a change.

## Modelling a concept

1. **State the invariants**: each thing that must always be true, as one sentence in glossary words ("an account's email is unique within the system", "an order's total is the sum of its lines"). Done when every rule the change touches is written down.
2. **Value object or entity.** If two instances with the same attributes are interchangeable, it is a **value object**: immutable, compared by value (`EmailAddress`, `Money`, `DateRange`). If it keeps an identity while its attributes change, it is an **entity** (`Account`, `Order`). Done when each concept is one or the other.
3. **Make illegal states unrepresentable.** Every value object has one constructor that parses raw input and returns a result: valid value or a domain error. Lifecycle states are a union with one shape per state, so a `Draft` order has no `shippedAt` field to forget. Done when no code path outside the module can build an invalid instance.
4. **Draw the aggregate.** An **aggregate** is the smallest cluster of entities and values that must be consistent at the end of one transaction; its root is the only entry point. Done when every invariant from step 1 has exactly one enforcer: one aggregate; or, for a rule over a whole set (uniqueness), a constraint behind the repository port that surfaces as a domain error; or, for a rule spanning aggregates that may lag, a named eventually consistent process.
5. **Place each rule** with the table below. Done when every rule sits at the lowest row that can hold it.

## Where code belongs

| Code | Belongs in | Ask |
|---|---|---|
| A rule about one value (format, range) | Value object constructor | Can it be decided from that value alone? |
| A rule about one aggregate's consistency | Aggregate (functions on its type) | Does it need only the aggregate's own state? |
| A rule spanning several aggregates, still pure | Domain service: a function taking domain types | No IO, only domain types in and out |
| Orchestration: load, decide, save, notify | Use case (application service) | It calls ports, holds no business rule |
| Translation to a technology | Adapter | See `hexagonal-architecture` |

Purity is necessary but not sufficient for the domain: a pure function that formats a page or builds a query is presentation or infrastructure. A function is domain when a business expert would recognise its rule.

## Aggregate rules

- **Small**: one root plus what must change atomically with it. A large aggregate serialises unrelated writes and loads data nobody needs.
- **Reference other aggregates by id**, never by holding the object.
- **One aggregate per transaction.** When a use case must change two, ask whether the business really needs both at once; usually one changes now and the other follows.
- **Always valid**: every function on an aggregate takes a valid aggregate and returns a valid one or a domain error. No setters followed by a `validate()`.

## Functional style

Model with immutable data and functions, not mutable objects:

```ts
type Order =
  | { readonly status: "draft"; readonly id: OrderId; readonly lines: readonly Line[] }
  | { readonly status: "placed"; readonly id: OrderId; readonly lines: readonly Line[]; readonly placedAt: Date };

const placeOrder = (order: Order, now: Date): Result<Order, OrderRejected> => {
  if (order.status !== "draft") return err({ kind: "already-placed" });
  if (order.lines.length === 0) return err({ kind: "empty" });
  return ok({ ...order, status: "placed", placedAt: now });
};
```

A value object is a branded type whose only constructor is a parse function: the single type assertion in the codebase for that brand lives inside it.

```ts
type EmailAddress = string & { readonly __brand: "EmailAddress" };

const parseEmailAddress = (raw: string): Result<EmailAddress, InvalidEmail> => {
  const email = raw.trim().toLowerCase();
  return EMAIL_PATTERN.test(email) ? ok(email as EmailAddress) : err({ kind: "invalid-email", raw });
};
```

Parse at the edge of the inside, then trust the types: a use case parses its command into value objects first, and everything after takes `EmailAddress`, never `string`.

## Repositories

A repository is a driven port per aggregate with collection semantics: get the whole aggregate by id, save the whole aggregate. It never returns half an aggregate or takes query fragments. Reads that only display data go through a separate read port (`hexagonal-architecture`, *Reads versus writes*).

## Bounded contexts

When one word means different things to different parts of the business ("account" for billing and for sign-in), those parts are separate **bounded contexts**, each with its own model of the word. Translate where they meet rather than growing one type to serve both. `domain-modeling` keeps a glossary per context.

## Growing the model

A rule may start in a use case over plain values while it has one caller. Move it into a value object or aggregate when a second caller needs it, when the use case starts branching on domain state, or when a test has to repeat the rule's cases at more than one layer. Moving it is a refactor under green tests, not a rewrite.

## Testing

Test the use case first, through its driving port with fakes (`hexagonal-architecture`, *Testing*); that pins the business path end to end. Add direct tests of a value object or aggregate function when its rule has many cases, and then stop repeating those cases at the use case (`testing`, *One Layer per Behaviour*).

## Done when

Every invariant the change touches is written in glossary words and enforced in exactly one place, no value object can be built invalid from outside its module, every rule sits at the lowest row of the placement table that holds it, and each use case changes at most one aggregate per transaction.
