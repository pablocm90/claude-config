# Ruby / Rails Seam Patterns

Ruby-specific mechanics only. Concepts (enabling points, sensing vs separation, granularity, scaffolding vs permanent) are in the main skill and other resources -- they apply unchanged.

## The Progression for Ruby

In Ruby the default seam is **constructor injection**, not function parameters:

1. **Constructor injection** -- `def initialize(tax_resolver: TaxApi)` with production default (permanent, **default choice**)
2. **Method parameter with default** -- `def call(cache: Rails.cache)` when a single method needs the dependency; avoids polluting the constructor
3. **Configuration injection** -- `def initialize(api_key: ENV.fetch("STRIPE_KEY"))` instead of reading `ENV` inline; or Rails `class_attribute`
4. **Extract and Override** -- pull the call into a private method, override in a test subclass (temporary; Ruby subclasses can override private methods)
5. **Module prepend / stubbing** -- `TaxApi.prepend(SkipExternalCalls)` or `stub` (**scaffolding only** -- mutates the class globally, needs cleanup, migrate to constructor injection)

## Inline Fakes (No Mocking Framework)

Duck typing makes fakes one-liners -- any object responding to the message works:

```ruby
# Separation
fake_tax = Class.new { def fetch_rate(_region) = 0.08 }.new
ProcessOrder.new(tax_resolver: fake_tax).call(order)

# Sensing -- plain recording object
class RecordingMailer
  attr_reader :sent
  def initialize = @sent = []
  def send_receipt(invoice) = @sent << invoice
end
```

## Rails-Specific Enabling Points

- **`class_attribute`** is a built-in configuration seam, overridable per test or per instance:

  ```ruby
  class ExternalSync
    class_attribute :client_class, default: ExactOnlineClient
  end
  # Test
  ExternalSync.new.tap { |s| s.client_class = FakeClient }.sync(company)
  ```

- **Time as a parameter beats `travel_to`** when only one method needs it: `def generate(company:, now: Time.current)` -- no global time state.
- **Wide SDKs** (`Aws::S3::Client`, `Stripe`) -- wrap in a thin adapter class exposing one narrow method; the duck-typed fake implements just that method.
- **Extract and Override** in Ruby: extract to a `private` method, override it in the test subclass (no-op for separation, `@calls << args` for sensing).

## Code Smell → Technique (Ruby)

| You see this in the code | Technique | Example |
|--------------------------|-----------|---------|
| `SomeService.new.call` inside a method | Constructor injection | Accept the service via `initialize` |
| `ENV["X"]` read directly | Wrap in config | `def initialize(api_key: ENV.fetch("API_KEY"))` |
| `ExternalApi.post(...)` class method call | Constructor injection or method param | Pass the client as a dependency |
| `Rails.cache.fetch(...)` directly | Method parameter | `def call(cache: Rails.cache)` |
| `Time.current` / `Date.today` | Method parameter or `travel_to` | `def call(now: Time.current)` |
| Can't change method signature yet | Extract and Override | Extract to private method, subclass in test |

## Ruby-Specific Mistakes

| Mistake | Fix |
|---------|-----|
| `allow(...).to receive` as permanent architecture | Stubs create implicit coupling. Migrate to constructor injection once tests exist. |
| `any_instance_of` | A sign you need a real seam -- inject the dependency instead |
| `prepend` without teardown | Mutates the class globally; leaks into other tests. Scaffolding only. |
