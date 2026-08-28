---
name: refactoring
description: Refactoring assessment and patterns. Use after mutation testing validates test strength (MUTATE phase) to assess improvement opportunities. Ruby/Rails idioms in resources/rails.md.
---

# Refactoring

Refactoring is the final step of TDD. After mutation testing confirms test strength, assess if refactoring adds value.

**Reference**: The full catalog of refactoring techniques is at [refactoring.com/catalog](https://refactoring.com/catalog/). For Ruby/Rails idioms of these techniques, see [resources/rails.md](resources/rails.md).

## When to Refactor

- Always assess after mutation testing confirms test strength
- Only refactor if it improves the code
- **Commit working code BEFORE refactoring** (critical safety net)

### Commit Before Refactoring - WHY

Having a working baseline before refactoring:
- Allows reverting if refactoring breaks things
- Provides safety net for experimentation
- Makes refactoring less risky
- Shows clear separation in git history

**Workflow:**
1. GREEN: Tests pass
2. MUTATE: Verify test effectiveness
3. KILL MUTANTS: Address surviving mutants
4. COMMIT: Save working code with strong tests
5. REFACTOR: Improve structure
6. COMMIT: Save refactored code

## Four Rules of Simple Design (Kent Beck)

The REFACTOR phase ends when all four rules are satisfied. Apply in order — earlier rules take priority.

| Rule | Question | When violated |
|------|----------|--------------|
| 1. Tests pass | Do all tests still pass? | Never refactor with failing tests |
| 2. Reveals intent | Can a reader understand what this does without asking? | Rename, extract method, replace primitive with value object |
| 3. No knowledge duplication | Is every business concept expressed in exactly one place? | Extract shared concept (DRY applies to *knowledge*, not code — see below) |
| 4. Fewest elements | Can anything be removed without violating rules 1-3? | Delete unused code, collapse unnecessary abstractions, inline single-use helpers |

Rule 3 trumps Rule 4: don't remove something that eliminates duplication just because it adds an element. Rule 4 is YAGNI — if no test demands it and no rule above requires it, delete it.

**Stopping criterion:** If all four rules are satisfied, stop. Don't refactor further.

## Diagnostic Tools

When deciding *what* to refactor and *which direction*:

- Load the `connascence` skill for a coupling taxonomy that maps to refactoring priorities (stronger connascence → higher priority)
- Load the `code-smells` skill to name the problem before reaching for a technique

## Priority Classification

| Priority | Action | Examples |
|----------|--------|----------|
| Critical | Fix now | Mutations, knowledge duplication, >3 levels nesting |
| High | This session | Magic numbers, unclear names, >30 line functions |
| Nice | Later | Minor naming, single-use helpers |
| Skip | Don't change | Already clean code |

## DRY = Knowledge, Not Code

**Abstract when**:
- Same business concept (semantic meaning)
- Would change together if requirements change
- Obvious why grouped together

**Keep separate when**:
- Different concepts that look similar (structural)
- Would evolve independently
- Coupling would be confusing

## Example Assessment

```typescript
// After MUTATE + KILL MUTANTS:
const processOrder = (order: Order): ProcessedOrder => {
  const itemsTotal = order.items.reduce((sum, item) => sum + item.price, 0);
  const shipping = itemsTotal > 50 ? 0 : 5.99;
  return { ...order, total: itemsTotal + shipping, shippingCost: shipping };
};

// ASSESSMENT:
// ⚠️ High: Magic numbers 50, 5.99 → extract constants
// ✅ Skip: Structure is clear enough
// DECISION: Extract constants only
```

## Speculative Code is a TDD Violation

If code isn't driven by a failing test, don't write it.

**Key lesson**: Every line must have a test that demanded its existence.

❌ **Speculative code examples:**
- "Just in case" logic
- Features not yet needed
- Code written "for future flexibility"
- Untested error handling paths

✅ **Correct approach**: Delete speculative code. If the behavior is needed, write a failing test that demands it, then implement.

```typescript
// ❌ WRONG - Speculative error handling (no test demands this)
if (items.length === 0) {
  throw new Error('Empty cart'); // No test for this path!
}

// ✅ CORRECT - Test-driven error handling
// First: write a test that expects this behavior
// Then: implement the guard clause to make it pass
```

---

## When NOT to Refactor

Don't refactor when:

- ❌ Code works correctly (no bug to fix)
- ❌ No test demands the change (speculative refactoring)
- ❌ Would change behavior (that's a feature, not refactoring)
- ❌ Premature optimization
- ❌ Code is "good enough" for current phase
- ❌ **Extracting purely for testability** — if the only reason to move code into a separate file is "so we can unit test it", keep it inline. The consuming function already has behavioral tests that cover this code. Extract for readability, DRY (same knowledge used in multiple places — see "DRY = Knowledge, Not Code" above), or separation of concerns, never for testability alone.

**Remember**: Refactoring should improve code structure without changing behavior.

---

## Commit Messages for Refactoring

```
refactor: extract scenario validation logic
refactor: simplify error handling flow
refactor: rename ambiguous parameter names
```

**Format**: `refactor: <what was changed>`

**Note**: Refactoring commits should NOT be mixed with feature commits.

---

## Refactoring Checklist

**This checklist is a gate for the commit decision — apply it BEFORE committing, not after.**

- [ ] All tests pass without modification
- [ ] No new public APIs added
- [ ] Code more readable than before
- [ ] Committed separately from features
- [ ] Committed BEFORE refactoring (safety net)
- [ ] No speculative code added
- [ ] Behavior unchanged (tests prove this)
