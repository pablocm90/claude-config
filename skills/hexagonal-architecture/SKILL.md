---
name: hexagonal-architecture
description: "Hexagonal architecture (ports and adapters): keep the application core free of infrastructure, talking to the outside only through ports it owns. Use when adding a use case, a port or an adapter, wiring dependencies at a composition root, deciding whether code belongs in the core or an adapter, or when a framework, SQL or HTTP type leaks into the core."
---

# Hexagonal architecture

The application is the **inside**: domain and use cases. Everything else is **outside**: HTTP, CLI, database, queues, clocks, other services, tests. The inside talks to the outside only through **ports**, contracts the inside declares in its own language. **Adapters** implement or call those ports and translate to one technology.

```
 driving adapters          ┌───────────────────────┐          driven adapters
 (call the app)            │        INSIDE         │          (the app calls them)
 HTTP handler ──▶ driving  │  use cases ─▶ domain  │  driven ◀── Postgres adapter
 CLI command  ──▶  port    │                       │   port  ◀── in-memory fake
 test         ──▶          └───────────────────────┘         ◀── SMTP adapter
                         every source dependency points inward
```

- **Port**: one purposeful conversation between the app and something outside, named for that purpose, not a technology.
- **Driving port**: what the app offers: a conversation (`ForManagingOrders`), here with one operation per use case (`place`, `cancel`). Driving adapters call it.
- **Driven port**: what the app needs (`ForStoringOrders`). The inside declares it; driven adapters implement it.
- **Dependency rule**: adapters depend on the inside; the inside names no adapter, framework or driver. This is the one rule everything else serves.
- **Composition root**: the single place, at the entry point, that picks concrete adapters and wires them in. Tests are another composition root.

Hexagonal says nothing about how the inside is modelled or packaged; for that, load `domain-driven-design`. For Rust (traits as ports, one crate per Module) read [resources/rust.md](resources/rust.md).

## Adding behaviour that crosses the boundary

Follow `tdd` throughout; these steps give the shape the tests drive towards.

1. **Write the use case's test first**, calling it through its driving port. The test names the use case in domain words, as an operation from a command to a result. Add that operation to the driving port whose conversation it joins: the same outside party with the same goal joins, and a new party or goal starts a new port. Done when the test is red and the use case's input, output and error types hold only domain or plain types: no request object, status code, row or driver error.
2. **Name each driven port the test needs by purpose**: `ForStoringOrders`, `ForNotifyingCustomers`, `ForReadingTheClock`, not `OrderRepositoryPostgres`, and plug an in-memory fake into it. Done when every method takes and returns domain types, and each fake fits in a few lines.
3. **Make the use case pass** against the fakes. Done when the test is green without a database, network or framework running.
4. **Write the real adapter** against a contract suite shared with the fake (see *Testing*). Done when both pass the same suite.
5. **Keep the adapter dumb**: it parses, maps and translates errors, nothing else. Done when no branch in it decides a business rule.
6. **Wire it at the composition root**. Done when a search for the adapter's name finds it only in the root and its own tests.

## Port design

- **Owned by the inside**: the port lives with the use cases, in their language. An adapter that forces its shape onto the port (`query(sql)`, ORM entities, `Response`) has turned the dependency around.
- **Few, one per conversation**: this skill's choice, stricter than the source. Cockburn counts ports across a whole application, usually one per outside party, and favours two to four. Of one port per use case and of merging everything into two, he says "Neither extreme appears optimal", but also that a wrong count does no "particular damage" and that it is largely taste. We group use cases because, on a wide application, one port each widens what callers and the composition root must name; one per table or class is an ORM wearing a hexagon.
- **Domain errors out**: a driven port reports `OrderNotFound`, not `RowNotFound` or a status code. The adapter maps.
- **One driven-port call is one transaction**, owned by the adapter. When a use case needs two writes to succeed or fail together, that is one port method taking both, or the aggregate is drawn wrong (`domain-driven-design`, *Aggregate rules*).
- **Time, randomness and ids are driven ports too**, or plain values passed in. A use case that reads the system clock cannot be tested deterministically.

## Dependency injection

Pass dependencies in as parameters (an options object, a struct of ports, generic parameters). No container: the composition root is ordinary code.

```ts
interface ForStoringOrders {
  save(order: Order): Promise<void>;
  byId(id: OrderId): Promise<Order | undefined>;
}

interface ForManagingOrders {
  place(command: PlaceOrder): Promise<Result<Order, OrderRejected>>;
  cancel(command: CancelOrder): Promise<Result<Order, CancelRejected>>;
}

const makeOrderManagement = ({
  orders,
  clock,
}: {
  orders: ForStoringOrders;
  clock: () => Date;
}): ForManagingOrders => ({
  place: async (command) => {
    const decision = decidePlacement({ command, now: clock() });
    if (!decision.ok) return decision;
    await orders.save(decision.value);
    return decision;
  },
  cancel: async (command) => { /* … */ },
});
```

**Prefer passing values to injecting ports.** Where a use case can gather what it needs first, act on it last, and keep the decision pure in between (the *impureim sandwich*), the domain function takes only values and needs no port at all. Inject a port only where the core must talk to the outside mid-decision.

## Testing

The **use case is the primary test boundary**: call it through its driving port, with in-memory **fakes** for driven ports. A fake holds state (`save` then `byId` returns it); assert on that state and on the use case's result, not on which methods were called. This is the "seam the project chose between layers" of `testing`'s *Mock Only at System Boundaries*.

- **Contract tests keep fakes honest**: one suite written against the port, run against the fake and the real adapter. A fake that passes and an adapter that fails is a bug found before production.

  ```ts
  const forStoringOrdersContract = (name: string, make: () => Promise<ForStoringOrders>) =>
    describe(`${name} stores orders`, () => {
      it("returns a saved order by id", async () => {
        const orders = await make();
        const order = anOrder();
        await orders.save(order);
        expect(await orders.byId(order.id)).toEqual(order);
      });
    });

  forStoringOrdersContract("in-memory", async () => inMemoryOrders());
  forStoringOrdersContract("postgres", async () => postgresOrders(await testDatabase()));
  ```

- **Driven adapters** get narrow integration tests against the real technology: the contract suite plus mapping edge cases (constraint violations, nulls, encoding).
- **Driving adapters** get a few tests of translation: request to command, result and errors to response. The rule's cases stay at the use case.
- **Pure domain rules** with many cases are tested directly as functions; simple ones are covered through the use case.

## Reads versus writes

A write goes through the use case and the domain model so invariants hold. A read that only shows data can use a separate read port returning a view shape straight from the adapter: loading aggregates to render a list buys nothing. Same database, same process; this is *CQRS-lite*, not event sourcing.

## Packaging

The pattern prescribes no packages and no layers inside the hexagon: only the dependency rule. Package by Module (`domain-driven-design`, *Modules*): what a concept needs, adapters included, sits together, and the dependency rule holds between its files. A package per layer makes the rule cheap to check and spreads a change across several of them. Packaging adapters with their Module is this skill's choice (`domain-driven-design`, *Modules*).

Technical plumbing several Modules share, such as the clock or a connection pool, has no concept of its own: keep it in a small shared package that holds no business rule.

In a codebase already packaged by layer, or whose CLAUDE.md names its ports differently, follow what is there and name the mismatch to the human. The project's CLAUDE.md wins, and moving to Modules is a separate refactor they agree to.

Giving each Module its own driving port is this skill's extension: Cockburn's article mostly describes one application, and comes closest in a known use that connects sub-applications through adapters. Whether other Modules must go through that port is a project's rule (`domain-driven-design`, *Modules*).

## Enforcing the dependency rule

The rule has a fixed shape, so check it with tooling rather than review: features and the crate graph in Rust (see `resources/rust.md`), `dependency-cruiser` or ESLint `no-restricted-imports` in TypeScript.

## When it is overhead

A thin CRUD service with no rules of its own, a one-off script, or a spike gains little: the core would be empty. Start with the boundary at the one place that already hurts (usually the database or a third-party API) and grow from there.

## Done when

Every new use case is an operation on the driving port of its conversation, unless the project's CLAUDE.md names ports differently, and is tested through it with fakes, every driven port with a real adapter has a contract suite run against both the fake and that adapter, no core type names an infrastructure type, and the composition root is the only code that names concrete adapters.
