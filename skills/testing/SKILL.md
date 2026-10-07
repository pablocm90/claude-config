---
name: testing
description: Testing patterns for behavior-driven tests. Use when writing tests, creating test factories, structuring test files, or deciding what to test and what not to. Includes Rails/Minitest patterns (resources/rails.md). Do NOT use for UI-specific testing (see front-end-testing or react-testing skills).
---

# Testing Patterns

For verifying test effectiveness through mutation analysis, load the `mutation-testing` skill. For evaluating test quality against Dave Farley's properties, load the `test-design-reviewer` skill.

Examples below use TypeScript/Vitest. For Rails/Minitest-specific idioms (builder modules, `build_*` vs `create_*`, table tests, assertion reference), see [resources/rails.md](resources/rails.md).

## Core Principle

**Test as little as possible to reach a given level of confidence** (Kent Beck). Each test names the break it catches — a production change someone would call a bug — and no other test catches it. Tests are code, and code is a liability: a test that catches nothing new costs maintenance forever.

**Test behavior, not implementation.** Every business behaviour is tested through the public API, not through implementation details.

---

## What Not to Test

Test the logic your code adds, and reach everything else through it:

- **Framework and library guarantees.** That a prop renders, a route resolves, a schema rejects the wrong type, a query cache caches, a stock ORM association or validation works. A test that would still pass with all your own code deleted is testing the framework. Your declarations on top of it are behaviour where real input depends on them: a field the server really sends as null is a row in the payload table.
- **Constructors, getters, constants and pass-through code.** Assert the first consumer-visible result that depends on them, unless they validate, normalise, default, derive or enforce something. A constant's value is a decision; a relation between constants (every monitored integration has a job that runs it) is behaviour.
- **What the type checker already forbids.** No test that a function rejects an argument its signature cannot receive.
- **Static copy, styling and layout.** Verified live (`tdd`, "Behaviour, not appearance").

---

## One Test per Branch, Not per Input

Before adding a test that differs from a neighbour only in an input value, confirm the production code branches on that difference. A second input down the same branch catches nothing the first did not.

- One case per branch or partition, and one decision per case: two decisions riding on one row hide which one broke.
- At a threshold, one case on it and one just past it: that pair is what tells `>` from `>=`. Write it as a literal; a test that fails on an off-by-one is no change detector, even though moving the threshold fails it too.
- Cases that share arrange and assert and differ only in data are **one table test**, with literal rows:

```typescript
test.for([
  { reason: 'a negative amount', overrides: { amount: -100 }, error: 'Amount must be positive' },
  { reason: 'an amount over the limit', overrides: { amount: 10_001 }, error: 'Amount over limit' },
  { reason: 'a two-digit CVV', overrides: { cvv: '12' }, error: 'Invalid CVV' },
])('rejects $reason', ({ overrides, error }) => {
  expect(processPayment(getMockPayment(overrides))).toEqual({ success: false, error });
});

test('processes a payment exactly at the limit', () => {
  expect(processPayment(getMockPayment({ amount: 10_000 })).success).toBe(true);
});
```

The accepted case sits on the threshold, so it also kills the `>` → `>=` mutant. Separate tests are right when the setup, the assertion or the scenario genuinely differs.

---

## One Layer per Behaviour

Each rule is tested at the layer that owns it: the query, service or pure function that decides it. A layer above asserts only what it adds — wiring, rendering, authorisation — through one representative case, not the rule's cases again.

---

## Test Through Public API Only

Never test implementation details. Test behavior through public APIs.

**Why this matters:**
- Tests remain valid when refactoring
- Tests document intended behavior
- Tests catch real bugs, not implementation changes

**When you discover a method is private (or should be):** Make it private if not already, then test through the public method that calls it. This is a refactoring opportunity, not an obstacle.

❌ **WRONG - Testing implementation:**
```typescript
// ❌ Testing HOW (implementation detail)
it('calls validateAmount', () => {
  const spy = jest.spyOn(validator, 'validateAmount');
  processPayment(payment);
  expect(spy).toHaveBeenCalled(); // Tests HOW, not WHAT
});

// ❌ Testing private methods
it('validates CVV format', () => {
  const result = validator._validateCVV('123'); // Private method!
  expect(result).toBe(true);
});

// ❌ Testing internal state
it('sets isValidated flag', () => {
  processPayment(payment);
  expect(processor.isValidated).toBe(true); // Internal state
});
```

✅ **CORRECT:** the table above — `processPayment`'s results, with no reference to the validator inside it.

---

## Mock Only at System Boundaries

Replace only what the test cannot control: the network (MSW in the browser), the clock, randomness, third-party SDKs, the filesystem. Your own modules and domain objects stay real, built with a factory; inside your code, mock only at a seam the project chose between layers (a data hook under a page). Assert what the code does with the mock's response, not that the mock was called: a test that fails only when the mock is removed is testing the mock.

---

## Tests as Design Feedback (Listening to Tests)

When a test is hard to write, that's not a testing problem — it's a **design signal**. The test is telling you something about the production code.

| What you experience | What it means | Likely smell |
|---------------------|--------------|-------------|
| Complex setup (many objects, deep chains) | Too many dependencies | SRP violation — class is doing too much |
| Need to mock/stub many collaborators | Tight coupling | Feature Envy or missing abstraction |
| Test name won't fit in one sentence | Method does too much | Long Method, needs Extract Method |
| Can't test without hitting DB/network | Side effects mixed with pure logic | Needs extraction into a pure function/object |
| Tests break when refactoring internals | Tests coupled to implementation | Connascence of Algorithm or Position |

**What to do:** Don't fight the test. Step back and ask "what's wrong with the design?" Then fix the design first — the test will become easy to write.

For the vocabulary of design problems, load the `code-smells` skill. For coupling analysis, load the `connascence` skill.

---

## Don't Extract for Testability

Never extract a function into its own file purely to give it its own unit test. Extract for readability (a descriptive name clarifies intent), for DRY (same **knowledge** used in multiple places — see the `refactoring` skill's "DRY = Knowledge, Not Code" rule), or for separation of concerns. Not for testability.

If code is inline in a function, it is tested through that function's behavioral tests.

The anti-pattern is creating a 1:1 mapping between extracted helpers and test files (see "No 1:1 Mapping" below). The extracted helper is an implementation detail of its consumer. Test the consumer's behavior.

❌ **WRONG — Extracted single-use helper with its own test file:**
```typescript
// prepare-participant-data.ts (new file, one caller)
export const prepareParticipantData = (items: Item[]) => ({
  yourClaims: items.filter(i => i.isClaimed && i.isClaimedByCurrentUser),
  available: items.filter(i => !i.isClaimedByCurrentUser),
});

// prepare-participant-data.test.ts (tests the helper directly)
it('filters claims', () => { ... });
```

✅ **CORRECT — Inline in the consuming function, tested through its behavior:**
```typescript
// load-participant-view.ts
export const loadParticipantView = async (db, eventId, userId) => {
  const items = await getItems(db, eventId);
  const yourClaims = items.filter(i => i.isClaimed && i.isClaimedByCurrentUser);
  const available = items.filter(i => !i.isClaimedByCurrentUser);
  return { yourClaims, available };
};

// The behavioral test for loadParticipantView covers the filtering:
it('returns claimed gifts in yourClaims and unclaimed in available', () => {
  const result = await loadParticipantView(db, eventId, userId);
  expect(result.yourClaims).toHaveLength(1);
  expect(result.available).toHaveLength(2);
});
```

**When extraction IS justified (DRY):** If the same logic serves several consumers with the same business meaning, extract it. It is now a module with its own public API and owns its rules: test their cases there, once. Each consumer asserts only its wiring, through one representative case (see "One Layer per Behaviour").

---

## Test Factory Pattern

For test data, use factory functions with optional overrides.

### Core Principles

1. **The factory is complete; the test body is not.** The factory returns a complete, valid object with sensible defaults. The test passes only the overrides its assertion reads — everything else is the factory's business.
2. Accept `Partial<T>` overrides for customization
3. Validate with real schemas (don't redefine)
4. Fresh state per test: call the factory inside the test, not in `let`/`beforeEach`
5. **A scene several tests share is a setup function, not a pasted literal.** A file-level `renderCard(overrides)` or `buildScene(overrides)` returns it fresh on every call. The same literal pasted into a second test is the cue.

### Basic Pattern

```typescript
import { UserSchema } from '@/schemas/user'; // Import the real schema, never redefine it

const getMockUser = (overrides?: Partial<User>): User => {
  return UserSchema.parse({
    id: 'user-123',
    name: 'Test User',
    email: 'test@example.com',
    role: 'user',
    ...overrides,
  });
};

// Usage: the override is the claim
it('lowercases the email', () => {
  const user = createUser(getMockUser({ email: 'Ann@Example.com' }));
  expect(user.email).toBe('ann@example.com');
});
```

**Why validate with schema?**
- Ensures test data is valid according to production schema
- Catches breaking changes early (schema changes fail tests)
- Single source of truth (no schema redefinition)

**Tip:** For factories where only a subset of fields are relevant, use `Pick<T, 'field1' | 'field2'>` for the overrides parameter to constrain what callers can customize.

### Factory Composition

For nested objects, compose factories:

```typescript
const getMockOrder = (overrides?: Partial<Order>): Order => {
  return OrderSchema.parse({
    id: 'order-1',
    items: [getMockItem()],      // ✅ Compose factories
    customer: getMockCustomer(),
    payment: getMockPayment(),
    ...overrides,
  });
};

it('calculates total with multiple items', () => {
  const order = getMockOrder({
    items: [getMockItem({ price: 100 }), getMockItem({ price: 200 })],
  });
  expect(calculateTotal(order)).toBe(300);
});
```

### Anti-Pattern: Shared Mutable State

❌ **WRONG: Using `let` and `beforeEach`**
```typescript
let user: User;
beforeEach(() => {
  user = { id: 'user-123', name: 'Test User', ... };  // Shared mutable state!
});

it('test 1', () => {
  user.name = 'Modified User';  // Mutates shared state
});

it('test 2', () => {
  expect(user.name).toBe('Test User');  // Fails! Modified by test 1
});
```

✅ **CORRECT:** each test calls `getMockUser(...)` for its own fresh object.

---

## Coverage Theater Detection

Watch for these patterns that execute code without checking it:

### Pattern 1: Mock the function being tested

❌ **WRONG** - Executes the code but tests nothing:
```typescript
it('calls validator', () => {
  const spy = jest.spyOn(validator, 'validate');
  validate(payment);
  expect(spy).toHaveBeenCalled(); // Meaningless assertion
});
```

✅ **CORRECT** - Assert what `validate` returns for an input that matters.

### Pattern 2: Test only that function was called

❌ **WRONG** - No behavior validation:
```typescript
it('processes payment', () => {
  const spy = jest.spyOn(processor, 'process');
  handlePayment(payment);
  expect(spy).toHaveBeenCalledWith(payment); // So what?
});
```

✅ **CORRECT** - Verify the outcome:
```typescript
it('returns a transaction id for a processed payment', () => {
  const result = handlePayment(getMockPayment());
  expect(result).toEqual({ success: true, transactionId: 'txn-1' });
});
```

### Pattern 3: Only the happy path

One test of the happy path leaves every rejecting branch unchecked. Give each branch one case — see "One Test per Branch, Not per Input" for the table.

### Pattern 4: Tautological expected value

The expected value is computed the way the code computes it, so the test passes by construction and can never disagree with the code.

❌ **WRONG** - Recomputes the answer:
```typescript
it('sums line items', () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((sum, i) => sum + i.price, 0);
  expect(calculateTotal(items)).toBe(expected);
});
```

✅ **CORRECT** - An independent, known literal:
```typescript
it('sums line items', () => {
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
});
```

The same holds when the expected value comes from calling a production helper the code also uses: a bug in that helper moves both sides together. Expected values come from a worked example, the spec, or a literal.

---

## No 1:1 Mapping Between Tests and Implementation

Don't create test files that mirror implementation files.

❌ **WRONG:**
```
src/
  payment-validator.ts
  payment-processor.ts
  payment-formatter.ts
tests/
  payment-validator.test.ts  ← 1:1 mapping
  payment-processor.test.ts  ← 1:1 mapping
  payment-formatter.test.ts  ← 1:1 mapping
```

✅ **CORRECT:**
```
src/
  payment-validator.ts
  payment-processor.ts
  payment-formatter.ts
tests/
  process-payment.test.ts  ← Tests behavior, not implementation files
```

**Why:** Implementation details can be refactored without changing tests. Tests verify behavior remains correct regardless of how code is organized internally.

---

## Summary Checklist

When writing tests, verify:

- [ ] Each test names a break that no other test catches
- [ ] Testing behavior through public API (not implementation details, private methods or internal state)
- [ ] Mocks only at system boundaries or a chosen layer seam; never the function being tested
- [ ] No tests of framework guarantees, trivial code, type-checked inputs, or appearance
- [ ] One case per branch; inputs down the same branch share one table test; a threshold has a case on it and one just past it
- [ ] Each rule asserted at the one layer that owns it
- [ ] Test bodies pass only the overrides their assertions read; complete factories, validated by real schemas, hold the rest
- [ ] Fresh state per test (no `let`/`beforeEach`)
- [ ] Tests would pass even if implementation is refactored
- [ ] No 1:1 mapping between test files and implementation files
