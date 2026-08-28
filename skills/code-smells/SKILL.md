---
name: code-smells
description: Code smell catalog — the diagnostic layer for recognizing what needs refactoring. Load when assessing code quality, during REFACTOR phase, or when doing structural/architectural work. Concepts apply to any language; examples in TypeScript and Ruby. Pairs with the `refactoring` skill (techniques) and `connascence` skill (coupling taxonomy).
---

# Code Smells

Code smells are the **diagnostic layer** — they help you *recognize* that something needs refactoring before you decide *how* to fix it.

**Reference**: Martin Fowler's [Refactoring](https://refactoring.com/) and [refactoring.com/catalog](https://refactoring.com/catalog/). For coupling analysis, load the `connascence` skill. For refactoring techniques, load the `refactoring` skill.

Concepts are language-agnostic. Examples shown in TypeScript and Ruby — pick whichever reads clearer to you.

Expanded TypeScript "after" examples (options object, extracted type, Zod branded type): `resources/typescript.md`.

---

## Bloaters

Things that have grown too large to handle effectively.

### Long Function / Long Method

A function or method that does too much. Suspect anything over 10–20 lines.

```typescript
// Smell: function does fetching, transforming, validating, and persisting
const processInvoice = (rawData: RawInvoiceData) => {
  const customer = fetchCustomer(rawData.customerId);
  if (!customer) return null;
  const amount = Number(rawData.amount);
  const vat = amount * 0.21;
  const total = amount + vat;
  // ... 20 more lines of transformation and persistence
};
```

```ruby
# Smell: method does fetching, transforming, validating, and persisting
def process_invoice(raw_data)
  customer = fetch_customer(raw_data[:customer_id])
  return unless customer
  amount = raw_data[:amount].to_d
  vat = amount * 0.21
  total = amount + vat
  # ... 20 more lines
end
```

**Fix**: Extract Function / Extract Method. Each step becomes a named function/method.

### Large Module / Large Class / God Hook

A module, class, or custom hook with too many responsibilities. In React, fat hooks and god components are the usual suspects. In Rails, fat models and god services.

```typescript
// Smell: hook mixing data fetching, transformation, formatting, side effects
const useClientDashboard = (clientId: string) => {
  const balance = useLoadDebtorBalance(clientId);
  const invoices = useLoadInvoices(clientId);
  const payments = useLoadPayments(clientId);
  // ... 50 lines of derived state, formatting, event handlers
  return { /* 15+ values */ };
};
```

```ruby
# Smell: ExactClient mixing HTTP, auth, data transformation, reconciliation, PDF
class ExactClient < Exact::Base
  def fetch_invoices = ...
  def new_resource_hash = ...
  def pdf_file_hash = ...
  def batch_reconciliation = ...
end
```

**Fix**: Extract Class / split into focused hooks — one per concern. **Connascence**: often reveals CoE (execution order between extracted responsibilities).

### Long Parameter List

More than 3 parameters signal the function is doing too much or the parameters belong together.

```typescript
// Smell
const createInvoice = (
  issueDate: string,
  dueDate: string,
  amount: number,
  vat: number,
  currency: string,
  reference: string,
  description: string,
  debtorId: number,
) => { ... };
```

```ruby
# Smell
def create_invoice(issue_date, due_date, amount, vat, currency, reference, description, debtor_id)
```

**Fix**: Introduce options object (TS) or keyword arguments (Ruby). **Connascence**: CoP (Position) → CoN (Name).

### Data Clumps

Groups of data that travel together across functions.

```typescript
// Smell: street, city, zipCode, country always appear together
const formatAddress = (street: string, city: string, zipCode: string, country: string) => ...;
const validateAddress = (street: string, city: string, zipCode: string, country: string) => ...;
const geocode = (street: string, city: string, zipCode: string, country: string) => ...;
```

```ruby
# Smell: same group travels everywhere
def format_address(street, city, zip_code, country) = ...
def validate_address(street, city, zip_code, country) = ...
def geocode(street, city, zip_code, country) = ...
```

**Fix**: Extract a type / value object (or Zod schema at trust boundaries). **Connascence**: CoM (Meaning) — the group's relationship is implicit.

### Primitive Obsession

Using primitives (strings, numbers) for domain concepts that deserve their own type.

```typescript
// Smell: structured communication is just a string everywhere
invoice.structuredCommunication  // "123456789002"
formatCommunication(comm);
isValidCommunication(comm);
```

```ruby
# Smell: same primitive masquerading as a domain concept
invoice.structured_communication  # "123456789002"
ApplicationHelper.display_structured_communication(comm)
ImportHelper.valid_structured_communication?(comm)
```

**Fix**: Branded type / Zod schema (TS) or value object (Ruby). **Connascence**: CoA (Algorithm) — validation/formatting logic duplicated wherever the primitive is used.

---

## Misused Abstractions (a.k.a. Object-Orientation Abusers)

Patterns that misuse or underuse language features.

### Switch Statements / Repeated Conditionals

The same `switch`/`case`/`if` chain appearing in multiple places, switching on the same value.

```typescript
// Smell
switch (payment.modality) {
  case 'exact': return ...;
  case 'horus': return ...;
  case 'manual': return ...;
}
```

```ruby
# Smell
case payment.modality
when "exact" then ...
when "horus" then ...
when "manual" then ...
end
```

**Fix (TS)**: Record lookup or strategy pattern. **Fix (Ruby)**: Replace Conditional with Polymorphism. **Connascence**: CoM (Meaning).

```typescript
const paymentHandlers: Record<PaymentModality, (p: Payment) => Result> = {
  exact: handleExact,
  horus: handleHorus,
  manual: handleManual,
};

const result = paymentHandlers[payment.modality](payment);
```

### Refused Bequest *(OO-specific)*

A subclass inherits methods it doesn't need or doesn't use.

```ruby
# Smell: Square inherits width= and height= but can't use them independently
class Square < Rectangle
```

**Fix**: Replace Inheritance with Delegation, or extract a shared interface/module.

### Temporary Variable / Temporary Field

Variables or instance fields that are only set in some code paths, leaving them undefined/nil in others.

```typescript
// Smell: intermediate state only meaningful during a loop
let currentInvoice: Invoice | undefined;
let currentBalance: number | undefined;

data.forEach(item => {
  currentInvoice = item;
  currentBalance = computeBalance(item);
  // methods below read these variables
});
```

```ruby
# Smell: @receivable, @exact_invoice only set during process_invoices iteration
def process_invoices(list)
  list.each do |receivable|
    @receivable = receivable
    @exact_invoice = fetch_entry(receivable)
    # methods below read these ivars
  end
end
```

**Fix**: Pass data as function parameters. Use `map`/`reduce` instead of `forEach`/iteration with mutable state. **Connascence**: CoE (Execution).

---

## Change Preventers

Patterns that make changes expensive — touching one thing forces changes elsewhere.

### Divergent Change

One module/class changes for multiple unrelated reasons.

```typescript
// Smell: shared/utils/index.ts changes when HTTP handling changes, when date
// formatting changes, when currency formatting changes, when feature flags change
```

```ruby
# Smell: ExactClient changes when HTTP handling changes, when invoice format changes,
# when debtor format changes, when reconciliation rules change
```

**Fix**: Split / Extract Class — one module per reason to change (SRP).

### Shotgun Surgery

One change requires editing many files.

```typescript
// Smell: changing how amounts are formatted requires updating
// BalanceSummaryPanel, InvoiceRow, CreditNoteRow, PaymentRow,
// ExportCsv, PdfDocument, EmailTemplate...
```

```ruby
# Smell: changing how structured communications are formatted requires updating
# ApplicationHelper, TemplateToHtml, ThirdPartyPayment, serializers, letter content...
```

**Fix**: Consolidate the scattered logic into one place (e.g., a shared formatter component, hook, or value object).

---

## Dispensables

Things that can be removed without loss.

### Dead Code

Code that is never executed. Unreachable branches, unused exports, commented-out code.

**Fix**: Delete it. Version control has the history.

### Speculative Generality

Abstractions built for hypothetical future requirements.

```typescript
// Smell: generic AbstractDataProvider with only one implementation
type DataProvider<T, Q, R> = {
  fetch: (query: Q) => Promise<R>;
  transform: (raw: R) => T;
  validate: (data: T) => boolean;
};
// Only ever used as DataProvider<Invoice, InvoiceQuery, RawInvoice>
```

```ruby
# Smell: AbstractInvoiceProcessor with only one subclass
class AbstractInvoiceProcessor
  def process = raise NotImplementedError
end
```

**Fix**: Use the concrete type/class directly (Collapse Hierarchy). Add abstraction when a second use case demands it.

### Lazy Module / Lazy Class

A module, function, or class that doesn't do enough to justify its existence.

**Fix**: Inline it — move its logic to the caller.

### Duplicate Code

Same code structure in multiple places. Note: DRY applies to *knowledge* (business concepts), not *code* (structural similarity). Two functions that look alike but represent different business concepts should stay separate.

**Fix**: Extract Function/Method (same module) or shared utility (different modules). Only extract if the duplication represents the same business knowledge.

---

## Couplers

Patterns that create excessive coupling between modules.

### Feature Envy

A function/method that uses more data from another module than its own.

```typescript
// Smell: this function is more about the invoice than the report
const buildInvoiceSummary = (invoice: Invoice) =>
  `${invoice.reference}: ${formatAmount(invoice.totalTvac)} (due ${dayjs(invoice.dueDate).format('DD/MM/YYYY')})`;
```

```ruby
# Smell: this method is more about the invoice than the report
class Report
  def invoice_summary(invoice)
    "#{invoice.reference}: #{invoice.total_tvac} (due #{invoice.due_date})"
  end
end
```

**Fix**: Move the function/method to the module whose data it uses. **Connascence**: CoN at high degree.

### Inappropriate Intimacy

Two modules that know too much about each other's internals.

```typescript
// Smell: reaching into another module's internal structure
const receivableId = invoice.accountingInvoice.additionalParameters['receivable_list_hid'];
```

```ruby
# Smell: poking at private state
debtor.instance_variable_get(:@custom_variables)
invoice.accounting_invoice.additional_parameters["receivable_list_hid"]
```

**Fix**: Expose the needed data through a proper function/method on the owning module. **Connascence**: CoI or CoA across boundaries.

### Message Chains *(OO-specific)*

Long chains of calls reaching deep into object graphs.

```ruby
# Smell
invoice.debtor.address.country.alpha2
```

**Fix**: Hide Delegate — add a method at the appropriate level. But avoid creating a Middle Man (below).

### Middle Man *(OO-specific)*

A class that delegates almost everything to another class.

```ruby
# Smell: every method just forwards
class InvoiceService
  def total(invoice) = invoice.total_tvac
  def due_date(invoice) = invoice.due_date
  def reference(invoice) = invoice.reference
end
```

**Fix**: Remove Middle Man — let callers talk to the delegate directly.

### Barrel Export Chains *(JS/TS-specific)*

Deep re-export chains that pull in unrelated dependencies.

```typescript
// Smell: importing one utility pulls in the entire app dependency graph
// shared/utils/index.ts re-exports environment.ts, currency.ts (which imports init/),
// view.ts (which imports store/), etc.
import { extractNumber } from 'shared/utils'; // pulls in pdfjs, redux, auth...
```

**Fix**: Import directly from the specific file, or restructure the barrel to avoid side-effect-heavy re-exports. **Connascence**: CoI — everything shares the same module graph.

### Prop Drilling *(React-specific)*

Data passed through many component layers that don't use it.

```typescript
// Smell: Parent → Layout → Sidebar → Content → DeepChild all passing `userId`
const Layout = ({ userId }: { userId: string }) => (
  <Sidebar userId={userId}>
    <Content userId={userId} />
  </Sidebar>
);
```

**Fix**: React context, Jotai/Zustand atoms, or React Query for shared state. Only drill props through 1–2 levels.

---

## Quick Reference

| Smell | Category | Typical Fix | Connascence |
|-------|----------|------------|-------------|
| Long Function / Method | Bloater | Extract Function/Method | — |
| Large Module / Class / God Hook | Bloater | Split / Extract Class | CoE |
| Long Parameter List | Bloater | Options object / keyword args | CoP → CoN |
| Data Clumps | Bloater | Extract type / value object | CoM |
| Primitive Obsession | Bloater | Branded type / value object | CoA |
| Switch Statements | Misused Abstraction | Record lookup / polymorphism | CoM |
| Refused Bequest *(OO)* | Misused Abstraction | Delegation / extract interface | — |
| Temporary Variable / Field | Misused Abstraction | Function parameter / `map` | CoE |
| Divergent Change | Change Preventer | Split module (SRP) | — |
| Shotgun Surgery | Change Preventer | Consolidate logic | — |
| Dead Code | Dispensable | Delete | — |
| Speculative Generality | Dispensable | Use concrete type | — |
| Duplicate Code | Dispensable | Extract (if same knowledge) | CoA |
| Feature Envy | Coupler | Move function/method | CoN (high degree) |
| Inappropriate Intimacy | Coupler | Encapsulate | CoI / CoA |
| Message Chains *(OO)* | Coupler | Hide Delegate | — |
| Middle Man *(OO)* | Coupler | Remove Middle Man | — |
| Barrel Export Chains *(JS/TS)* | Coupler | Direct imports | CoI |
| Prop Drilling *(React)* | Coupler | Context / atoms / query | — |
