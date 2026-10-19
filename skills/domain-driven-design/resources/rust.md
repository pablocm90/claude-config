# Domain-driven design in Rust

## Value objects are newtypes with private fields

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct EmailAddress(String);

impl EmailAddress {
    pub fn parse(raw: &str) -> Result<Self, InvalidEmail> {
        let email = raw.trim().to_lowercase();
        if is_valid(&email) { Ok(Self(email)) } else { Err(InvalidEmail) }
    }

    pub fn as_str(&self) -> &str { &self.0 }
}
```

The field is private, so `parse` is the only way in from outside the module: an invalid `EmailAddress` cannot exist. Implement `TryFrom<&str>` too when callers expect it, delegating to `parse`. Give read access (`as_str`, `Display`) rather than `pub` fields or `DerefMut`.

## States are enums

```rust
pub enum Order {
    Draft { id: OrderId, lines: Vec<Line> },
    Placed { id: OrderId, lines: NonEmpty<Line>, placed_at: Timestamp },
}

impl Order {
    pub fn place(self, now: Timestamp) -> Result<Order, OrderRejected> { … }
}
```

Taking `self` by value and returning the next state makes a stale reference to the old state impossible. Where each state has different operations, separate types per state (typestate: `DraftOrder::place(self) -> PlacedOrder`) let the compiler reject calling `ship` on a draft.

## Domain errors are enums

One `enum` per operation's failure modes, named in domain words (`OrderRejected::Empty`, `OrderRejected::AlreadyPlaced`). Derive `PartialEq` so tests compare errors directly. `thiserror` is acceptable in `domain` for `Display` and `Error` impls: it adds no runtime coupling.

## Keep the domain crate dependency-free

`domain` depends on the standard library and, at most, small pure crates (`thiserror`, a non-empty collection). Serialisation is an adapter concern: rather than `#[derive(Serialize)]` on domain types, the HTTP adapter defines its own DTOs and maps, so the wire format and the model can change independently. Time arrives as a value passed in, not a `SystemTime::now()` call.
