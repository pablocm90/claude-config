# Rails / Minitest Testing Patterns

Companion to the `testing` skill for Ruby/Rails codebases using Minitest. All generic principles apply unchanged — behavior through public API, coverage through behavior, no 1:1 test/implementation mapping, coverage theater detection. This file covers only the Rails/Minitest idioms.

## Implementation-Detail Idioms to Avoid

The Ruby-specific ways of testing implementation instead of behavior:

```ruby
# ❌ Testing private methods via send
result = validator.send(:validate_cvv, "123")

# ❌ Testing internal state via instance_variable_get
assert processor.instance_variable_get(:@validated)

# ❌ Stubbing the method being tested — proves nothing
PaymentValidator.stub(:validate, true) do
  assert PaymentValidator.validate(payment)
end

# ❌ Minitest::Mock expect/verify as the only assertion — "was it called?" is not behavior
mock_processor.expect(:process, true, [payment])
handle_payment(payment)
mock_processor.verify
```

Instead, call the public method and assert on the returned result / observable outcome:

```ruby
test "rejects negative amounts" do
  result = process_payment(build_payment(amount: -100))
  assert_not result.success?
  assert_includes result.error, "Amount must be positive"
end
```

## Test Builder Pattern (Minitest)

The Rails counterpart of factory functions: builder methods with keyword-argument overrides, defined in a shared module included in test classes.

```ruby
# test/support/builders.rb
module Builders
  def build_user(**overrides)
    defaults = {
      name:       "Test User",
      email:      "test@example.com",
      role:       "user",
      active:     true,
      created_at: Time.zone.parse("2024-01-01"),
    }
    User.new(**defaults.merge(overrides))
  end

  def build_order(**overrides)
    defaults = {
      items:    [build_item],       # compose builders for nested objects
      customer: build_user,
      payment:  build_payment,
    }
    Order.new(**defaults.merge(overrides))
  end
end

# test/test_helper.rb
require_relative "support/builders"

class ActiveSupport::TestCase
  include Builders
end
```

```ruby
test "calculates total with multiple items" do
  order = build_order(items: [build_item(price: 100), build_item(price: 200)])
  assert_equal 300, calculate_total(order)
end
```

Build through the **real model** — real validations are the single source of truth. Never define a `FakeUser` class that reimplements `valid?`; that is the Ruby equivalent of redefining schemas in tests.

## `build_*` vs `create_*`

Use `build_*` (in-memory, `Model.new`) by default. Only use `create_*` (`Model.create!`, persisted) when the test genuinely needs persistence — it is much slower.

## No `setup` Instance Variables

`setup do @user = ... end` is the Minitest equivalent of `let`/`beforeEach` shared mutable state — one test mutating `@user` can break another depending on run order. Call builders fresh inside each test instead.

## Minitest Quick Reference

```ruby
# Equality
assert_equal expected, actual
assert_not_equal expected, actual

# Truthiness
assert value
assert_not value
assert_nil value
assert_not_nil value

# Membership / content
assert_includes collection, item
assert_not_includes collection, item

# Type
assert_instance_of ClassName, object
assert_kind_of ClassName, object

# Errors
assert_raises(ErrorClass) { risky_call }

# Delta (for floats)
assert_in_delta 0.15, result, 0.001

# Mocks (Minitest::Mock) — verify collaborator contracts, never as the sole assertion
mock = Minitest::Mock.new
mock.expect(:method_name, return_value, [arg1, arg2])
mock.verify
```

## RSpec → Minitest Migration Playbook

The repo migrates spec-by-spec whenever touched code has RSpec coverage. Battle-tested procedure (tier3–5 campaigns):

1. **Run the spec file first** — record example count and any pre-existing failures/skips. You migrate *behaviour*, and you can't preserve what you haven't seen pass.
2. **Read for intent, not structure.** Each `it` block's assertion set becomes one Minitest test method. Ignore RSpec's nesting — flatten `context` chains into descriptive method names (`test "returns unpaid invoices for a restricted user"`).
3. **Replace factories with fixtures or inline creation** — no new FactoryBot use. Tenant tests: inline tenant users (no users fixture), `CompanyDetail.first` for company detail. Lightweight invoices: `:normal`-equivalent attributes inline with `sent_to_debtor_at` set (see the sent_to_debtor gotcha).
4. **Port RSpec idioms:**
   - `let`/`let!` → local variables or private methods (eager `let!` → create in the test body)
   - `allow(...).to receive` → `Minitest::Mock`, a hand-rolled fake, or `Object#stub` (block-scoped)
   - `travel_to` works in both; `freeze_time` → `travel_to(Time.current)`
   - `with_advisory_lock` in service tests → **stub it** — the real lock escapes fixture rollback under CI's pool and poisons the whole suite
   - shared_examples → plain method extraction or duplicated tests (prefer duplication over a shared-example DSL port)
5. **Beware Postgres microsecond truncation** — timestamps round-trip through the DB lose sub-µs precision; compare with `assert_in_delta` on epoch or reload both sides.
6. **Run the new Minitest file + the old spec side by side** — both green, same behavioural coverage (mutation-check a sample if the spec looked weak).
7. **Delete the spec file in the same commit** as the new test — never leave both.
8. **Full `bundle exec standardrb`** before push — new test files aren't on `.standard_todo` waterlines, so file-scoped runs miss cops.

