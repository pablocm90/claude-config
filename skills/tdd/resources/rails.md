# TDD in Ruby / Rails / Minitest

Stack-specific companion to the main `tdd` skill. Same workflow; these are the Rails mechanics.

## RED-GREEN Example

```ruby
# 1. RED — test/models/user_test.rb
class UserTest < ActiveSupport::TestCase
  test "rejects empty user names" do
    user = User.new(id: "user-123", name: "")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end
end
# rails test test/models/user_test.rb  ❌ fails — no validation yet

# 2. GREEN — app/models/user.rb
class User < ApplicationRecord
  validates :name, presence: true
end
# rails test test/models/user_test.rb  ✅ passes
```

## Running Tests

```bash
rails test                              # full Minitest suite
rails test test/models/user_test.rb     # single file
rails test test/models/user_test.rb:12  # single test by line number
rails test --parallel                   # parallel on multi-core
rerun --pattern 'app/**/*.rb' -- rails test  # watch mode (rerun/guard gem)
```

## Rails-Flavoured Anti-Patterns

- ❌ Stubbing private methods (implementation-detail testing)
- ❌ `setup` / instance variables for test data when fixtures or inline creation is clearer
- ❌ Test evidence without lint: run the repo's lint/quality gate (standardrb/rubocop, or a bundled gate like `bin/check`) before requesting commit approval

## Refactoring Threshold

Ruby convention: methods >10 lines are a High-priority refactor candidate (vs >30 for TypeScript functions).
