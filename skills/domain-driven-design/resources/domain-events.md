# Domain events

A **domain event** records that something the business cares about happened (`OrderPlaced`, `AccountClosed`), named in the past tense in glossary words.

## When to use them

Use an event when something **outside the current transaction** must react: another bounded context, a separate process, a notification sent after commit. When every reaction happens in the same transaction, return the result directly and let the use case act on it: an event there adds indirection and nothing else.

## The decider pattern

The functional shape for an aggregate that emits events:

```ts
type Decider<Command, State, Event, Rejection> = {
  readonly initialState: State;
  readonly decide: (command: Command, state: State) => Result<readonly Event[], Rejection>;
  readonly evolve: (state: State, event: Event) => State;
};
```

- `decide` holds every business rule: given the current state, accept the command as events or reject it. Pure.
- `evolve` applies one event to the state. Pure, and it never rejects: the event already happened.
- Current state is `events.reduce(evolve, initialState)`.

The use case loads state, calls `decide`, saves the events (or the evolved state), and publishes the events after commit. Tests read as *given events, when command, then events*:

```ts
const given = (events: readonly Event[]) => events.reduce(order.evolve, order.initialState);

expect(order.decide({ kind: "place", now }, given([lineAdded()]))).toEqual(ok([orderPlaced({ at: now })]));
```

A decider does not require event sourcing. Storing the evolved state and publishing the events through an outbox table is enough.

## Publishing reliably

Saving state and publishing to a broker are two writes; one can fail after the other succeeds. Write events to an outbox table in the same transaction as the state, and let a separate relay publish them. The outbox is a driven adapter concern; the domain only returns events.
