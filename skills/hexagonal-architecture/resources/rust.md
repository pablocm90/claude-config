# Hexagonal architecture in Rust

## Crates are the boundary

Put the inside and each adapter in its own workspace crate, so the dependency rule is enforced by `Cargo.toml` rather than review:

```
domain            no internal dependencies
application       domain                          use cases + driven port traits
http-adapter      application, domain, axum       driving
cli-adapter       application, domain             driving
postgres-adapter  application, diesel/sqlx        driven
<binary>          everything                      composition root
```

`domain` and `application` list no framework, driver or serialisation crate. An adapter never depends on another adapter. Check with `cargo tree -p application -e normal`: anything infrastructural in that output is a leak. Async runtimes belong in `[dev-dependencies]` of the core crates, for tests only.

## Ports are traits

```rust
pub trait ForStoringAccounts {
    fn create(&self, account: NewAccount) -> impl Future<Output = Result<(), EmailTaken>> + Send;
}

pub struct SignUp<A: ForStoringAccounts, H: ForHashingPasswords> {
    accounts: A,
    hasher: H,
}
```

- **Generics by default.** Native `async fn` / `impl Future` in traits (stable since 1.75) works with generic parameters and costs nothing at runtime, but those traits are not dyn-compatible. Reach for `Box<dyn …>` (with `async-trait` or boxed futures) only when the adapter must be chosen at runtime from config.
- **Errors are domain enums**, not `Box<dyn Error>` or a driver error. The adapter maps `diesel::result::Error::DatabaseError(UniqueViolation, _)` to `EmailTaken`; anything it cannot map becomes an opaque `Unavailable` variant, logged in the adapter. A boxed error lets driver text cross into the core and out through driving adapters.
- **Name by purpose**: a port called `DatabaseHealth` names the technology. Ask what the app needs (`ForCheckingReadiness`) and let the database be one answer.

## Fakes and contract tests

An inline `#[cfg(test)]` fake is invisible to other crates, so the real adapter's tests cannot run the same suite against it. Once a port has a real adapter, move the fake and the contract suite somewhere both can reach:

- a `test-support` feature on `application` exposing `fakes` and `contracts` modules, enabled only from `[dev-dependencies]`, or
- a small `application-testing` crate depending on `application`.

```rust
// application, behind feature "test-support"
pub async fn stores_accounts<A: ForStoringAccounts>(make: impl AsyncFn() -> A) {
    let accounts = make().await;
    accounts.create(an_account("a@example.com")).await.unwrap();
    assert_eq!(accounts.create(an_account("a@example.com")).await, Err(EmailTaken));
}

// postgres-adapter/tests/accounts.rs
#[tokio::test]
async fn postgres_accounts_honour_the_contract() {
    application::contracts::stores_accounts(async || PostgresAccounts::new(test_db().await)).await;
}
```

Run each contract test in its own rolled-back transaction or fresh schema so the real adapter's runs stay independent.

## Driving adapters

A driving adapter owns all of its framework: argument parsing (clap) lives in the CLI adapter, request extraction and status codes in the HTTP adapter. The binary only builds adapters and hands them over. Framework types (`axum::http::HeaderValue`, `clap::ArgMatches`) stay in the adapter's internals rather than its public signature, so the composition root passes plain configuration values.

## The composition root

`main` (or a `run` it calls) reads configuration, builds each driven adapter, builds the use cases with them, and gives the use cases to the driving adapters. Operational commands such as running migrations may call an adapter's inherent method directly from the root: they are wiring, not application behaviour.
