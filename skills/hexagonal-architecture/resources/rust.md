# Hexagonal architecture in Rust

## Crates follow Modules

Crates are Rust's strongest boundary, so spend them on what changes together: one crate per Module (`domain-driven-design`, *Modules*), with its layers as Rust modules inside.

```
crates/orders/src/
  lib.rs         the surface: the driving port and its implementation, the domain types, each feature's adapter
  domain.rs
  use_cases.rs   ForManagingOrders and its implementation
  ports.rs       driven port traits
  postgres.rs    behind the feature "postgres"
  http.rs        behind the feature "http"
  cli.rs         behind the feature "cli"
```

This shape is a choice, not the pattern's, and its checks are not yet proven on a real project, so see each one fail on purpose the first time:

| Rule | Check |
|---|---|
| The core names no framework or adapter | Adapters are optional features; CI builds the crate with none, and `cargo tree -p orders -e normal --no-default-features` lists nothing infrastructural |
| Adapters do not depend on each other | `cargo hack check --each-feature` |
| `domain` does not depend on `use_cases`, and neither names an adapter or an adapter feature | A small test over each file's `use` lines and `cfg` attributes |
| Dependencies between Modules point one way, as the project draws them | `deny.toml` |

Cargo refuses a cycle between crates, so Modules that use each other in both directions need a shared concept moved or found (`domain-driven-design`, *Modules*).

The alternative is a crate per layer (`domain`, `application`, one per adapter). Cargo then enforces the rule for free, but each change spreads: on one project, single-topic PRs touched 3.9 crates on average and the application crate's root held about 124 names. It suits adapters that ship separately.

Async runtimes belong in `[dev-dependencies]` unless an adapter feature needs one.

## Ports are traits

```rust
pub trait ForStoringAccounts {
    fn create(&self, account: NewAccount) -> impl Future<Output = Result<(), CreateAccountError>> + Send;
}

#[derive(Debug, PartialEq)]
pub enum CreateAccountError {
    EmailTaken,
    Unavailable,
}

pub trait ForManagingAccounts {
    fn sign_up(&self, request: SignUpRequest) -> impl Future<Output = Result<Account, SignUpError>> + Send;
    fn sign_in(&self, request: SignInRequest) -> impl Future<Output = Result<Session, SignInError>> + Send;
}

pub struct AccountManagement<A: ForStoringAccounts, H: ForHashingPasswords> {
    accounts: A,
    hasher: H,
}
```

- **Generics by default.** Native `async fn` / `impl Future` in traits (stable since 1.75) works with generic parameters and costs nothing at runtime, but those traits are not dyn-compatible. Reach for `Box<dyn …>` (with `async-trait` or boxed futures) only when the adapter must be chosen at runtime from config.
- **Errors are domain enums**, not `Box<dyn Error>` or a driver error. The adapter maps `diesel::result::Error::DatabaseError(UniqueViolation, _)` to `CreateAccountError::EmailTaken`; anything it cannot map becomes `Unavailable`, with the detail logged in the adapter. A boxed error lets driver text cross into the core and out through driving adapters.
- **Name by purpose**: a port called `DatabaseHealth` names the technology. Ask what the app needs (`ForCheckingReadiness`) and let the database be one answer.

## Fakes and contract tests

An inline `#[cfg(test)]` fake is invisible to `tests/` and to other crates, so an integration test cannot run the same suite against it. Once a port has a real adapter, move the fake and the contract suite somewhere both can reach:

- a `test-support` feature on the Module's crate exposing `fakes` and `contracts` modules, enabled only from `[dev-dependencies]`, or
- a small testing crate depending on it, when another crate's adapter must run the suite.

```rust
// behind feature "test-support"
pub async fn stores_accounts<A: ForStoringAccounts>(make: impl AsyncFn() -> A) {
    let accounts = make().await;
    accounts.create(an_account("a@example.com")).await.unwrap();
    assert_eq!(
        accounts.create(an_account("a@example.com")).await,
        Err(CreateAccountError::EmailTaken),
    );
}

// tests/postgres_accounts.rs
#![cfg(feature = "postgres")]

#[tokio::test]
async fn postgres_accounts_honour_the_contract() {
    accounts::contracts::stores_accounts(async || PostgresAccounts::new(test_db().await)).await;
}
```

Run each contract test in its own rolled-back transaction or fresh schema so the real adapter's runs stay independent.

## Driving adapters

A driving adapter owns all of its framework: argument parsing (clap) lives in the CLI adapter, request extraction and status codes in the HTTP adapter. The binary only builds adapters and hands them over. What the root passes in is use cases and plain configuration values (a `String` origin, not an `axum::http::HeaderValue`); the adapter parses them. What the adapter hands back may be its framework's runnable, such as an `axum::Router` for the root to serve.

## The composition root

`main` (or a `run` it calls) reads configuration, builds each driven adapter, builds the use cases with them, and gives the use cases to the driving adapters. Operational commands such as running migrations may call an adapter's inherent method directly from the root: they are wiring, not application behaviour.
