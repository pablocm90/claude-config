# TypeScript Fix Patterns

"After" examples for smells whose main catalog entry only shows the smell.

## Long Parameter List → Options Object

```typescript
type CreateInvoiceParams = {
  issueDate: string;
  dueDate: string;
  amount: number;
  vat: number;
  currency: string;
  reference: string;
  description: string;
  debtorId: number;
};

const createInvoice = (params: CreateInvoiceParams) => { ... };
```

## Data Clumps → Extracted Type

```typescript
type Address = {
  street: string;
  city: string;
  zipCode: string;
  country: string;
};

const formatAddress = (address: Address) => ...;
```

Use a Zod schema instead of a plain type when the clump crosses a trust boundary.

## Primitive Obsession → Branded Type via Zod

```typescript
const StructuredCommunicationSchema = z.string().regex(/^\d{12}$/);
type StructuredCommunication = z.infer<typeof StructuredCommunicationSchema>;
```

Validation/formatting logic now lives with the schema instead of being duplicated at every use site.
