---
name: connascence
description: Connascence coupling taxonomy for evaluating and improving code quality. Use during REFACTOR phase to decide what to refactor, which direction to move, and when to stop. Covers the full spectrum from weak (cheap) to strong (expensive) connascence with TypeScript and Ruby examples — concepts apply to any language. Pairs with the `refactoring` skill (the *how*) and the `code-smells` skill (the *what*).
---

# Connascence — Coupling Taxonomy

Connascence gives precise vocabulary for coupling. Instead of "these are coupled," say *how* and *how expensive*.

**Origin**: Meilir Page-Jones (*What Every Programmer Should Know About Object-Oriented Design*), later championed by Jim Weirich and Kevin Rutherford.

**Core rule**: Always refactor from stronger connascence toward weaker forms. Never the reverse.

Concepts in this skill are language-agnostic. Examples are shown in TypeScript and Ruby. Pick whichever reads clearly to you — the taxonomy is what matters.

---

## Three Axes of Evaluation

Before acting on connascence, evaluate it along three axes:

| Axis | Question | Implication |
|------|----------|-------------|
| **Strength** | How expensive is this type of coupling? | Stronger → higher priority to fix |
| **Degree** | How many components are involved? | More components → more expensive |
| **Locality** | Are the coupled components close together? | Across module/class boundaries → more expensive than within one |

**Key insight**: Strong connascence *within* a single component (function or class) is often acceptable. Weak connascence *across* module boundaries can still be expensive if the degree is high.

---

## The Spectrum: Weak → Strong

### Static Connascence (detectable by reading code)

#### Connascence of Name (CoN) — Weakest

Multiple components must agree on the name of something.

The weakest and most desirable form. All well-structured code has CoN — it's the baseline cost of components communicating.

```typescript
invoice.markAsSent();
user.email;
items.reduce((sum, item) => sum + item.price, 0);
```

```ruby
invoice.mark_as_sent!
user.email
order.items.sum(&:price)
```

**Refactoring target**: You're done. This is where you want to end up.

---

#### Connascence of Type (CoT)

Multiple components must agree on the type of something.

```typescript
// CoT — function expects a specific shape
const applyDiscount = (order: Order, discount: number): number =>
  order.total - discount;
```

```ruby
# CoT — method expects a specific type
def apply_discount(order, discount)
  raise ArgumentError unless discount.is_a?(Numeric)
  order.total - discount
end
```

**Language notes:**
- **TypeScript**: the type system enforces CoT at compile time, making it cheap. CoT becomes a compile-time check rather than a runtime surprise — one of TS's main strengths over JS.
- **Ruby**: duck typing naturally weakens CoT. Prefer responding to messages over checking types: `discount.to_d` rather than `discount.is_a?(Numeric)`.

---

#### Connascence of Meaning (CoM) / Connascence of Convention

Multiple components must agree on the meaning of a value. Magic numbers and magic strings are the classic symptom.

```typescript
// ❌ CoM — what does 2 mean? Both sides must agree
const processInvoice = (invoice: Invoice) => {
  if (invoice.status === 2) return; // "cancelled"
};

const isExportable = (invoice: Invoice) =>
  invoice.status !== 2; // same magic number, same implicit agreement
```

```typescript
// ✅ Refactored to CoN — union type makes the meaning the value
type InvoiceStatus = 'draft' | 'sent' | 'cancelled' | 'paid';

const processInvoice = (invoice: Invoice) => {
  if (invoice.status === 'cancelled') return; // type-checked, no magic
};
```

```ruby
# ❌ CoM — what does 2 mean? Both sides must agree
def process(invoice)
  return if invoice.status == 2  # "cancelled"
end
```

```ruby
# ✅ Refactored to CoN — Rails enum gives you predicate methods
class Invoice < ApplicationRecord
  enum :status, { draft: 0, sent: 1, cancelled: 2 }
end

def process(invoice)
  return if invoice.cancelled?
end
```

---

#### Connascence of Position (CoP)

Multiple components must agree on the order of values.

```typescript
// ❌ CoP — callers must remember the order
const createAddress = (
  street: string,
  city: string,
  postcode: string,
  country: string,
) => { ... };

createAddress('Rue de la Loi 1', 'Brussels', '1000', 'BE');
// Was it (street, city, postcode, country) or (street, postcode, city, country)?
```

```typescript
// ✅ Refactored to CoN — options object
type AddressParams = {
  street: string;
  city: string;
  postcode: string;
  country: string;
};

const createAddress = (params: AddressParams) => { ... };

createAddress({ street: 'Rue de la Loi 1', city: 'Brussels', postcode: '1000', country: 'BE' });
```

```ruby
# ❌ CoP — callers must remember the order
def create_address(street, city, postcode, country)
  # ...
end
```

```ruby
# ✅ Refactored to CoN — keyword arguments
def create_address(street:, city:, postcode:, country:)
  # ...
end

create_address(street: "Rue de la Loi 1", city: "Brussels", postcode: "1000", country: "BE")
```

This is why most modern style guides prefer options objects / keyword arguments over positional ones.

---

#### Connascence of Algorithm (CoA)

Multiple components must agree on a particular algorithm.

```typescript
// ❌ CoA — both sides must use the same encoding/decoding
const encodeToken = (payload: Record<string, unknown>): string =>
  btoa(JSON.stringify(payload));

const decodeToken = (token: string): Record<string, unknown> =>
  JSON.parse(atob(token));
```

```typescript
// ✅ Refactored — single source of truth via Zod schema
const TokenSchema = z.object({ userId: z.string(), exp: z.number() });

const encodeToken = (payload: z.infer<typeof TokenSchema>): string =>
  btoa(JSON.stringify(TokenSchema.parse(payload)));

const decodeToken = (token: string): z.infer<typeof TokenSchema> =>
  TokenSchema.parse(JSON.parse(atob(token)));
```

```ruby
# ❌ CoA — encoder and decoder must agree on the algorithm
class TokenEncoder
  def encode(payload)
    Base64.strict_encode64(payload.to_json)
  end
end

class TokenDecoder
  def decode(token)
    JSON.parse(Base64.strict_decode64(token))
  end
end
```

```ruby
# ✅ Refactored — single object owns the algorithm
class TokenCodec
  def encode(payload)
    Base64.strict_encode64(payload.to_json)
  end

  def decode(token)
    JSON.parse(Base64.strict_decode64(token))
  end
end
```

**Language note (TypeScript):** Zod schemas (or any Standard Schema) are the natural home for CoA in TS projects — one schema is the single source of truth for validation, parsing, and type derivation.

---

### Dynamic Connascence (detectable only at runtime)

Dynamic connascence is always stronger than static. If you spot it across module boundaries, refactor aggressively.

#### Connascence of Execution (CoE)

The order of execution matters.

```typescript
// ❌ CoE — must call setAuthToken before fetchInvoices
const client = createApiClient();
client.setAuthToken(token);
client.fetchInvoices(); // fails if setAuthToken not called first
```

```typescript
// ✅ Refactored — encapsulate the ordering
const createAuthenticatedClient = (token: string) => {
  const client = createApiClient();
  client.setAuthToken(token);
  return client; // returned client is always authenticated
};
```

```ruby
# ❌ CoE — must call setup_tokens before rest_request
client = ExactClient.new
client.setup_tokens
client.rest_request(:get, "/invoices")
```

```ruby
# ✅ Refactored — encapsulate the ordering
class ExactClient
  def fetch_invoices
    ensure_authenticated!
    rest_request(:get, "/invoices")
  end

  private

  def ensure_authenticated!
    setup_tokens unless authenticated?
  end
end
```

**Language note (React):** hooks have inherent CoE (rules of hooks, dependency arrays). This is managed by the framework — but custom hooks that require specific call ordering are a smell.
Concrete hook-ordering example: `resources/typescript.md`.

---

#### Connascence of Timing (CoTi)

The timing of execution matters.

```typescript
// ❌ CoTi — race condition between async operations
const fetchAndCache = async () => {
  fetchExchangeRate().then(rate => cache.set('rate', rate));
  const amount = price * cache.get('rate'); // may read before write
};
```

```typescript
// ✅ Refactored — remove timing dependency
const fetchAndConvert = async (price: number) => {
  const rate = await fetchExchangeRate();
  return price * rate;
};
```

```ruby
# ❌ CoTi — race condition; both threads must coordinate timing
Thread.new { cache.write("rate", fetch_exchange_rate) }
Thread.new { amount * cache.read("rate") }  # may read before write completes
```

```ruby
# ✅ Refactored — remove timing dependency
rate = fetch_exchange_rate
converted = amount * rate
```

**Language note (React):** `useEffect` cleanup races and stale closure bugs are common CoTi symptoms.

---

#### Connascence of Value (CoV)

Multiple components must agree on particular values (not just types or names) — typically a multi-field invariant.

```typescript
// ❌ CoV — width and height must maintain rectangle invariant
type Rectangle = {
  top: number;
  bottom: number;
  left: number;
  right: number;
};
// Callers must ensure (right - left) and (bottom - top) are consistent
```

```typescript
// ✅ Refactored — enforce the constraint through the type
type Rectangle = {
  origin: { x: number; y: number };
  width: number;
  height: number;
};
```

```ruby
# ❌ CoV — rectangle invariant: opposite sides must be equal
class Rectangle
  attr_accessor :top, :bottom, :left, :right

  def valid?
    (right - left) == width && (bottom - top) == height
  end
end
```

```ruby
# ✅ Refactored — enforce the constraint through the interface
class Rectangle
  attr_reader :origin, :width, :height

  def initialize(origin:, width:, height:)
    @origin = origin
    @width = width
    @height = height
  end
end
```

---

#### Connascence of Identity (CoI) — Strongest

Multiple components must reference the same object instance (not just an equal one).

```typescript
// ❌ CoI — multiple components depend on the same singleton
const config = AppConfig.getInstance();
// Used in ApiClient, AuthService, FeatureFlags... all must share THE SAME instance
```

```typescript
// ✅ Refactored — inject the dependency, weaken to CoN
const createApiClient = (config: AppConfig) => { ... };
const createAuthService = (config: AppConfig) => { ... };

// Caller decides whether to share the instance
const config = loadConfig();
const api = createApiClient(config);
const auth = createAuthService(config);
```

```ruby
# ❌ CoI — multiple components must share the exact same instance
class OrderProcessor
  def initialize
    @shared_config = AppConfig.instance  # singleton dependency
  end
end

class PaymentGateway
  def initialize
    @shared_config = AppConfig.instance  # must be THE SAME instance
  end
end
```

```ruby
# ✅ Refactored — inject the dependency, weaken to CoN
class OrderProcessor
  def initialize(config:)
    @config = config
  end
end

class PaymentGateway
  def initialize(config:)
    @config = config
  end
end

# Caller decides whether to share the instance
config = AppConfig.new
OrderProcessor.new(config: config)
PaymentGateway.new(config: config)
```

**Language note (React):** shared identity often lives in context providers or Jotai/Zustand atoms — these are *managed* CoI, which is acceptable because the framework controls the sharing.

---

## Connascence as a Refactoring Guide

### Decision Framework

During the REFACTOR phase, use connascence to prioritize:

1. **Identify** the form of connascence
2. **Evaluate** using the three axes (strength, degree, locality)
3. **Decide** whether to act:

| Situation | Action |
|-----------|--------|
| Strong connascence across module/class boundaries | Refactor — high priority |
| Strong connascence within a single component | Acceptable if degree is low |
| Weak connascence across boundaries | Acceptable unless degree is very high |
| Weak connascence within a component | Leave it — this is normal |

### Refactoring Direction

Always move **down** the spectrum (strong → weak):

```
Identity → Value → Timing → Execution → Algorithm → Position → Meaning → Type → Name
strongest                                                                      weakest
```

Common transformations:

| From | To | Technique |
|------|----|-----------|
| CoM (magic values) | CoN (union types / constants / enums) | Replace Magic Literal |
| CoP (positional args) | CoN (options object / keyword args) | Use options object |
| CoA (duplicated algorithm) | CoN (shared schema / function / class) | Extract to single source |
| CoE (call ordering) | CoN (encapsulated function / method) | Encapsulate sequence |
| CoI (shared singleton) | CoN (injected dependency / context) | Dependency injection |

### The DRY Tradeoff

Reducing connascence sometimes means tolerating duplication — and that's OK.

```typescript
// Two hooks with similar-looking validation — but different business reasons
const useOrderValidation = (order: Order) =>
  order.total > 0 && order.items.length > 0;

const useRefundValidation = (refund: Refund) =>
  refund.amount > 0 && refund.items.length > 0;
```

```ruby
# Two services with similar-looking validation — but different business reasons
class OrderValidator
  def valid?(order)
    order.total.positive? && order.items.any?
  end
end

class RefundValidator
  def valid?(refund)
    refund.amount.positive? && refund.items.any?
  end
end
```

These look like duplication, but they represent different business concepts that will evolve independently. Extracting a shared `validate` would create Connascence of Meaning — both must agree on what "valid" means, even though their rules will diverge.

**Rule**: DRY applies to *knowledge* (business concepts), not to code structure. See the `refactoring` skill for more on this.

---

## Quick Reference

| Form | Static/Dynamic | Strength | Symptom | Fix |
|------|---------------|----------|---------|-----|
| Name | Static | Weakest | — (baseline) | — |
| Type | Static | Weak | `as` casts, `any`, `is_a?` | Proper types / duck typing |
| Meaning | Static | Moderate | Magic numbers/strings | Union types, constants, enums |
| Position | Static | Moderate | Positional arguments | Options object / keyword args |
| Algorithm | Static | Moderate | Duplicated parse/format/codec | Single source of truth |
| Execution | Dynamic | Strong | "Must call A before B" | Encapsulate sequence |
| Timing | Dynamic | Strong | Race conditions, stale closures | Await / cleanup / remove dep |
| Value | Dynamic | Strong | Coordinated value constraints | Enforce through type/interface |
| Identity | Dynamic | Strongest | Singleton, shared instance | DI / framework-managed context |

---

## Checklist

When assessing connascence during REFACTOR:

- [ ] Identified the form(s) of connascence present
- [ ] Evaluated strength, degree, and locality
- [ ] Strong connascence across boundaries → refactored toward weaker form
- [ ] Strong connascence within a component → acceptable if low degree
- [ ] Did NOT introduce stronger connascence to reduce duplication
- [ ] Refactoring direction is always strong → weak, never the reverse
