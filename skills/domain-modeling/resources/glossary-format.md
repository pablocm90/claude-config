# Glossary format

```md
# {Context name}

{One or two sentences: what this context is and why it exists.}

## Language

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: bill, payment request

**Customer**:
A person or organisation that is invoiced.
_Avoid_: account
_In code_: `Client`

## Relationships

- A **customer** receives many **invoices**; each invoice belongs to one customer.

## Flagged ambiguities

- "account" meant both the Customer and the login. Resolved: the login is the **User**; "account" is no longer a domain term.
```

## Rules

- **Be opinionated.** Where several words name one concept, pick the best one and list the others under `_Avoid_`.
- **Define what it is**, not what it does, in one or two sentences.
- **Only this project's terms.** General programming concepts stay out, however often the project uses them.
- **No implementation detail** beyond an optional `_In code_` line naming the class or table the term maps to. Keep it when the code name differs from the domain word, since that mismatch is what misleads. Paths, behaviour and gotchas belong in docs or memory.
- **Group terms under subheadings** once natural clusters appear.
- **Relationships** holds how terms connect (who gets which surface, what owns what), one line each, so definitions stay about what a term is.
- **Flagged ambiguities** records each overloaded word and how it was resolved, so it is not reintroduced.

## Several contexts

When the repo holds several bounded contexts, a `GLOSSARY-MAP.md` at the root lists each context's glossary and how they relate. Infer from the topic which one applies; ask when it is unclear.
