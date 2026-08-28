# Refactoring — Ruby / Rails Idioms

Ruby/Rails expressions of the techniques in [Fowler's catalog](https://refactoring.com/catalog/). Load alongside SKILL.md when working in a Ruby/Rails codebase.

**Priority note**: Ruby community norm is stricter than the generic table — methods >10 lines are High priority (not >30).

## Extracting

**Extract Method** — give each step a name.

```ruby
# ❌ Before
def process_order(order)
  items_total = order.items.sum(&:price)
  shipping = items_total > FREE_SHIPPING_THRESHOLD ? 0 : STANDARD_SHIPPING_COST
  tax = items_total * 0.21
  order.merge(total: items_total + shipping + tax)
end

# ✅ After
def process_order(order)
  items_total = order.items.sum(&:price)
  order.merge(total: items_total + shipping_cost(items_total) + tax(items_total))
end

private

def shipping_cost(items_total)
  items_total > FREE_SHIPPING_THRESHOLD ? 0 : STANDARD_SHIPPING_COST
end

def tax(items_total)
  items_total * TAX_RATE
end
```

**Extract Class / Extract Service Object** — split a model doing too much into focused objects, with collaborators injected via keyword arguments.

```ruby
# ❌ Before — logic buried in the model
class Order < ApplicationRecord
  def finalise!
    update!(status: :complete)
    UserMailer.confirmation(self).deliver_later
    InventoryService.decrement(items)
  end
end

# ✅ After — single-responsibility service object
class FinaliseOrderService
  def initialize(order:, mailer: UserMailer, inventory: InventoryService)
    @order     = order
    @mailer    = mailer
    @inventory = inventory
  end

  def call
    @order.update!(status: :complete)
    @mailer.confirmation(@order).deliver_later
    @inventory.decrement(@order.items)
  end
end
```

**Extract Superclass** — pull shared HTTP/auth/token infrastructure into a base class, leaving business logic in the subclass.

```ruby
# ❌ Before — monolith mixing HTTP, auth, and business logic
class ExactClient
  def rest_request(...) = ...
  def setup_tokens = ...
  def fetch_invoices = ...
end

# ✅ After
class Exact::Base
  def rest_request(...) = ...
  def setup_tokens = ...
end

class ExactClient < Exact::Base
  def fetch_invoices = ...
end
```

## Simplifying Conditionals

**Replace Nested Conditional with Guard Clauses**

```ruby
# ✅ Early returns over nesting
def process_payment(payment)
  return unless payment
  return unless payment.amount.positive?
  return unless user_verified?(payment.user_id)

  execute(payment)
end
```

**Replace Conditional with Polymorphism** — objects instead of `case`/`if` chains.

```ruby
# ❌ Before
def discount_for(customer_type, total)
  case customer_type
  when :vip    then total * 0.2
  when :member then total * 0.1
  else 0
  end
end

# ✅ After — each type is an object
class VipDiscount
  def calculate(total) = total * 0.2
end

class MemberDiscount
  def calculate(total) = total * 0.1
end
```

## Organizing Data

**Replace Primitive with Object** — value objects for domain concepts; endless methods keep predicates terse.

```ruby
# ❌ Before — raw hash
def calculate_shipping(address)
  if address[:country] == "BE" && address[:postcode].start_with?("1")
    # ...
  end
end

# ✅ After
class Address
  attr_reader :country, :postcode

  def initialize(country:, postcode:)
    @country  = country
    @postcode = postcode
  end

  def domestic? = country == "BE"
  def brussels? = domestic? && postcode.start_with?("1")
end
```

**Introduce Parameter Object** — group long parameter lists.

```ruby
class InvoiceSearchCriteria
  attr_reader :start_date, :end_date, :status, :currency

  def initialize(start_date:, end_date:, status: nil, currency: nil)
    @start_date = start_date
    @end_date = end_date
    @status = status
    @currency = currency
  end
end

def search_invoices(criteria)
  # ...
end
```

## Refactoring APIs

**Remove Flag Argument** — keyword arguments over positional booleans.

```ruby
# ❌ Before
def rest_request(type, endpoint, params = nil, bypass_base_url = false, raw_response = false)

# ✅ After
def api_request(method:, endpoint:, params: nil, full_url: false, raw_response: false)
```

**Deprecated Passthrough for Incremental Migration** — when changing a method's interface, keep the old method delegating to the new one to avoid a flag-day rewrite of all callers.

```ruby
# @deprecated Use {#api_request} with named parameters instead
def rest_request(type, endpoint, params = nil, bypass_base_url = false, raw_response = false)
  api_request(method: type, endpoint: endpoint, params: params, full_url: bypass_base_url, raw_response: raw_response)
end
```

## Functional Patterns

**Replace Loop with Pipeline**

```ruby
# ❌ Before
results = []
orders.each do |order|
  next unless order.paid?
  results << order.total if order.total > 100
end

# ✅ After
results = orders.select(&:paid?).map(&:total).select { |t| t > 100 }
```

## Ruby Refactoring Hazards

### Removing `attr_reader` Can Break Error Paths

Rescue clauses may still call the reader by name — and error paths are often untested.

```ruby
# ❌ NoMethodError lurks in the rescue
class Base
  # attr_reader :resp_headers  # REMOVED for encapsulation

  def request
    @resp_headers = response.headers
  rescue => e
    process_error(headers: resp_headers)  # method no longer exists
  end
end

# ✅ Pass data through local scope
def request
  response = nil
  begin
    response = execute_request
  rescue => e
    process_error(headers: response&.headers)  # nil if never assigned
  end
end
```

### `retry` Re-Runs the Entire `begin` Block

Variables set before the `begin` (or at the top of a method body with no explicit `begin`) are re-initialized on `retry`. Keep retry counters as locals declared outside the `begin`.

```ruby
# ❌ BUG — @retries resets to 0 on every retry (infinite loop)
def request
  @retries = 0
  response = execute
rescue Unauthorized
  @retries += 1       # Always 1
  retry if @retries < 2
end

# ✅ CORRECT
def request
  retries = 0
  begin
    response = execute
  rescue Unauthorized
    retries += 1
    retry if retries < 2
  end
end
```

**Checklist addition for Ruby**: before committing a refactor, check rescue clauses and error paths for breakage.
