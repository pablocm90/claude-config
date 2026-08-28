# Mutation Testing — Ruby / Rails Specifics

Read alongside SKILL.md. Only Ruby/Rails/Minitest/RSpec material here — the process, metrics, equivalent mutants, and generic operator tables live in SKILL.md.

## Identifying Changed Code

```bash
git diff master...HEAD --name-only | grep -E '\.rb$' | grep -v '_test\.rb' | grep -v '_spec\.rb'
git diff master...HEAD -- app/ lib/
```

Run mutants against the narrowest relevant test set:

```bash
bin/rails test test/path/to_test.rb        # Minitest (preferred)
bin/rails test test/path/to_test.rb:42     # single test by line
bundle exec rspec spec/path/to_spec.rb     # RSpec (legacy)
```

## Ruby Method Expression Mutations

| Original | Mutated | Test Should Verify |
|----------|---------|-------------------|
| `start_with?` | `end_with?` | Correct string position |
| `upcase` | `downcase` | Case transformation |
| `any?` | `all?` | Partial vs full match |
| `all?` | `any?` | Full vs partial match |
| `select` | (removed) | Filtering is necessary |
| `reject` | (removed) | Exclusion is necessary |
| `reverse` / `sort` | (removed) | Order matters |
| `min` | `max` | Correct extremum |
| `strip` | `lstrip` / `rstrip` | Correct whitespace handling |
| `first` | `last` | Correct element selected |
| `present?` | `blank?` | Correct presence check (Rails) |
| `nil?` | `!nil?` | Nil check inverted |
| `positive?` | `negative?` | Correct sign check |
| `a.equal?(b)` | `!a.equal?(b)` | Object identity cases |

## Nil / Safe Navigation Mutations

| Original | Mutated | Test Should Verify |
|----------|---------|-------------------|
| `foo&.bar` | `foo.bar` | Nil handling |
| `foo \|\| default` | `foo && default` | Fallback behaviour |

Kill these by covering both the nil path and a real object:

```ruby
def test_returns_user_name
  assert_equal "Alice", display_name(user)
end

def test_returns_nil_when_user_is_nil
  assert_nil display_name(nil)
end
```

## Ruby-Flavoured Red Flags

- `assert_nothing_raised` / `expect { ... }.not_to raise_error` almost never kills mutants on its own — an empty method body also doesn't raise
- `assert user.method` on non-boundary values (`adult?(25)` kills nothing for `>=` vs `>`)
- Identity values in Ruby terms: `0`, `1`, `""`, `[]`, `{}`, `nil` alone

## Verifying Side Effects

Minitest: `Minitest::Mock` with `.expect(:save, true, [order])` then `.verify`. RSpec: `have_received(:save).with(order)` / `hash_including(...)`. A block-removal mutant (`def x; end`) survives any test that doesn't assert on a side effect or return value.
