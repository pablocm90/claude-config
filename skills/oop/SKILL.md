---
name: oop
description: Object-oriented programming patterns for Ruby and Ruby on Rails. Use when designing classes, modeling domain entities, implementing service objects, implementing design patterns, or encountering coupling and cohesion issues. Covers SOLID principles, encapsulation, mixins vs inheritance, ActiveRecord best practices, service objects, value objects, and dependency injection in Ruby. Do NOT over-apply heavy OOP abstractions (deep inheritance trees, abstract factories) unless the project genuinely requires them.
---

# Object-Oriented Patterns — Ruby / Rails

## Core Principles

- **Encapsulation** — hide internal state and implementation details
- **Single Responsibility** — each class does one thing well
- **Composition over inheritance** — prefer mixins and delegation over deep hierarchies
- **Program to duck types** — depend on behaviour, not class names
- **Immutable by default** — prefer value objects and `freeze` where possible
- **No comments** — code should be self-documenting

---

## Connascence

Encapsulation is fundamentally about managing connascence — the degree of coupling between components. For a detailed taxonomy of connascence types and refactoring guidance, load the `connascence` skill.

---

## Why Encapsulation Matters

Internal state should only be changed through well-defined methods that enforce invariants.

```ruby
# ❌ WRONG - Exposed state allows inconsistent mutations
class BankAccount
  attr_accessor :balance, :transactions
end

account = BankAccount.new
account.balance = -999          # Invalid state — no validation
account.transactions = []       # Silently wipes history
```

```ruby
# ✅ CORRECT - Encapsulated state enforces invariants
class BankAccount
  attr_reader :balance

  def initialize(initial_balance)
    raise ArgumentError, "Balance cannot be negative" if initial_balance < 0

    @balance = initial_balance
    @transactions = []
  end

  def deposit(amount)
    raise ArgumentError, "Amount must be positive" unless amount.positive?

    @balance += amount
    @transactions << { type: :deposit, amount: amount }
  end

  def transactions
    @transactions.dup.freeze
  end
end
```

---

## OOP Light

We follow pragmatic OOP — practical patterns without over-engineering:

**What we DO:**
- Encapsulation and information hiding
- Duck typing for flexible interfaces
- Mixins for shared behaviour
- SOLID principles as guidelines (not laws)

**What we DON'T do:**
- Deep inheritance hierarchies (3+ levels)
- Metaprogramming magic that obscures intent
- Design patterns for their own sake
- God classes/modules that know everything

```ruby
# ✅ GOOD - Simple and clear
class EmailNotifier
  def send_message(to:, body:)
    # implementation
  end
end

# ❌ OVER-ENGINEERED - Unnecessary abstraction for a single use case
module AbstractNotifierStrategyFactory
  def self.build_notifier_strategy_for(context)
    NotifierStrategyBuilder.new(context).build
  end
end
```

---

## SOLID Principles

### S — Single Responsibility

Each class should have exactly one reason to change.

```ruby
# ❌ WRONG - Class doing too many things
class UserManager
  def create(data) = ...
  def send_welcome_email(user) = ...
  def save_to_database(user) = ...
  def generate_report(users) = ...
end
```

```ruby
# ✅ CORRECT - Focused classes
class UserFactory
  def create(data) = ...
end

class UserRepository
  def save(user) = ...
  def find_all = ...
end

class WelcomeEmailService
  def call(user) = ...
end
```

---

### O — Open/Closed

Open for extension, closed for modification. Add behaviour without changing existing code.

```ruby
# ❌ WRONG - Adding new types requires modifying existing logic
class DiscountCalculator
  def calculate(order)
    case order.customer_type
    when :vip    then order.total * 0.2
    when :member then order.total * 0.1
    else 0
    end
  end
end
```

```ruby
# ✅ CORRECT - New discount types are added without touching existing code
class VipDiscount
  def calculate(order) = order.total * 0.2
end

class MemberDiscount
  def calculate(order) = order.total * 0.1
end

class NoDiscount
  def calculate(_order) = 0
end

class DiscountCalculator
  def initialize(strategy)
    @strategy = strategy
  end

  def calculate(order)
    @strategy.calculate(order)
  end
end
```

---

### L — Liskov Substitution

Subclasses must be usable wherever their parent is used. If a subclass breaks a parent's contract, the inheritance is wrong.

```ruby
# ❌ WRONG - Square breaks Rectangle's contract
class Rectangle
  attr_accessor :width, :height

  def area = width * height
end

class Square < Rectangle
  def width=(val)
    @width = val
    @height = val  # ❌ Caller doesn't expect height to change
  end
end
```

```ruby
# ✅ CORRECT - Share a duck type instead
class Rectangle
  def initialize(width:, height:)
    @width = width
    @height = height
  end

  def area = @width * @height
end

class Square
  def initialize(side:)
    @side = side
  end

  def area = @side ** 2
end

# Both respond to #area — that's the duck type that matters
```

---

### I — Interface Segregation

In Ruby there are no formal interfaces, but the principle still applies: don't force objects to respond to methods they don't need. Use focused modules.

```ruby
# ❌ WRONG - One bloated module
module Worker
  def work   = raise NotImplementedError
  def eat    = raise NotImplementedError
  def sleep  = raise NotImplementedError
  def attend_meeting = raise NotImplementedError
end

class Robot
  include Worker

  def eat   = raise "Robots don't eat"   # ❌ Forced to handle this
  def sleep = raise "Robots don't sleep"
end
```

```ruby
# ✅ CORRECT - Focused modules
module Workable
  def work = raise NotImplementedError
end

module Biological
  def eat   = raise NotImplementedError
  def sleep = raise NotImplementedError
end

module MeetingAttendee
  def attend_meeting = raise NotImplementedError
end

class Robot
  include Workable
  include MeetingAttendee
end

class Employee
  include Workable
  include Biological
  include MeetingAttendee
end
```

---

### D — Dependency Inversion

Depend on duck types and inject dependencies rather than instantiating them inside a class.

```ruby
# ❌ WRONG - Hard-coded dependencies
class OrderService
  def initialize
    @mailer = SendGridMailer.new      # ❌ Hard-coded
    @repository = PostgresRepository.new
  end

  def place_order(order)
    @repository.save(order)
    @mailer.send_message(to: order.customer_email, body: "Order confirmed")
  end
end
```

```ruby
# ✅ CORRECT - Dependencies injected from outside
class OrderService
  def initialize(repository:, mailer:)
    @repository = repository
    @mailer = mailer
  end

  def place_order(order)
    @repository.save(order)
    @mailer.send_message(to: order.customer_email, body: "Order confirmed")
  end
end

# Production
OrderService.new(repository: PostgresRepository.new, mailer: SendGridMailer.new)

# Tests
OrderService.new(repository: FakeRepository.new, mailer: FakeMailer.new)
```

---

## Mixins vs Inheritance

Prefer mixins and delegation for code reuse. Reserve inheritance for genuine `is-a` relationships.

```ruby
# ❌ WRONG - Using inheritance just to share methods
class Animal
  def breathe = ...
end

class FlyingAnimal < Animal
  def fly = ...
end

class Duck < FlyingAnimal
  # Duck also swims — but we can't inherit from two classes
end
```

```ruby
# ✅ CORRECT - Compose behaviour with modules
module Flyable
  def fly = "flapping wings"
end

module Swimmable
  def swim = "paddling"
end

class Duck
  include Flyable
  include Swimmable
end

class Penguin
  include Swimmable
end
```

**When inheritance IS appropriate:**
- True `is-a` relationships (e.g., `SavingsAccount < BankAccount`)
- You control both base and subclass
- Hierarchy is shallow — 2 levels max
- Favour `super` sparingly; template method hooks are often cleaner

---

## Service Objects

Extract complex multi-step operations into service objects with a single public `#call` method.

```ruby
# ❌ WRONG - Business logic bloating the controller
class OrdersController < ApplicationController
  def create
    order = Order.new(order_params)
    order.total = order.items.sum(&:price)
    order.status = :pending
    order.save!
    UserMailer.order_confirmation(order).deliver_later
    InventoryService.decrement(order.items)
    redirect_to order
  end
end
```

```ruby
# ✅ CORRECT - Thin controller, focused service object
class PlaceOrderService
  def initialize(order_params:, mailer: UserMailer, inventory: InventoryService)
    @order_params = order_params
    @mailer = mailer
    @inventory = inventory
  end

  def call
    order = build_order
    order.save!
    @mailer.order_confirmation(order).deliver_later
    @inventory.decrement(order.items)
    order
  end

  private

  def build_order
    Order.new(@order_params).tap do |o|
      o.total = o.items.sum(&:price)
      o.status = :pending
    end
  end
end

# Controller becomes trivial
class OrdersController < ApplicationController
  def create
    order = PlaceOrderService.new(order_params: order_params).call
    redirect_to order
  end
end
```

---

## Value Objects

Use immutable value objects for domain concepts. Two value objects with the same data are equal.

```ruby
# ❌ WRONG - Primitive obsession
def create_order(amount, currency, email)
  # Is 100 cents or dollars? Which email format is valid?
end

create_order(100, "USD", "test@example.com")
```

```ruby
# ✅ CORRECT - Expressive value objects
class Money
  attr_reader :amount, :currency

  def initialize(amount, currency)
    raise ArgumentError, "Amount cannot be negative" if amount.negative?

    @amount = amount.freeze
    @currency = currency.freeze
    freeze
  end

  def +(other)
    raise ArgumentError, "Currency mismatch" unless currency == other.currency

    Money.new(amount + other.amount, currency)
  end

  def ==(other)
    other.is_a?(Money) && amount == other.amount && currency == other.currency
  end
end

class Email
  attr_reader :value

  def initialize(raw)
    raise ArgumentError, "Invalid email" unless raw.include?("@")

    @value = raw.downcase.strip.freeze
    freeze
  end

  def ==(other)
    other.is_a?(Email) && value == other.value
  end
end
```

---

## ActiveRecord Best Practices

ActiveRecord models should stay focused on persistence concerns. Business logic belongs in service objects or domain objects.

```ruby
# ❌ WRONG - Fat model with mixed responsibilities
class User < ApplicationRecord
  def self.send_weekly_digest
    all.each { |u| UserMailer.digest(u).deliver_now }
  end

  def generate_pdf_report
    # 50 lines of PDF generation...
  end

  def sync_to_crm
    CrmClient.new.upsert(self)
  end
end
```

```ruby
# ✅ CORRECT - Slim model; behaviour extracted to focused objects
class User < ApplicationRecord
  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  # Scopes
  scope :active, -> { where(deactivated_at: nil) }
  scope :admins, -> { where(role: :admin) }

  # Simple domain methods that belong on the model
  def full_name = "#{first_name} #{last_name}"
  def active?   = deactivated_at.nil?
end

# Complex behaviour extracted
class WeeklyDigestService
  def call = User.active.find_each { |u| UserMailer.digest(u).deliver_later }
end

class UserReportGenerator
  def initialize(user) = @user = user
  def call = # PDF logic...
end
```

**ActiveRecord guidelines:**
- Validations and scopes ✅ belong on the model
- Simple predicate/formatting methods ✅ belong on the model
- Multi-step operations, external calls, complex queries ❌ extract to service objects
- Callbacks (`after_create`, `after_save`) for side effects ❌ — use service objects or event listeners instead; callbacks are hidden and make testing painful

---

## Encapsulation Violations Catalog

```ruby
# ❌ Public attr_accessor for everything
class User
  attr_accessor :name, :email, :role  # All writable — no validation
end
# ✅ Use attr_reader; update via explicit methods
class User
  attr_reader :name, :email

  def update_email(new_email)
    raise ArgumentError, "Invalid email" unless valid_email?(new_email)
    @email = new_email
  end
end

# ❌ Returning internal mutable state
class Cart
  def items = @items  # Caller can mutate @items directly!
end
# ✅ Return a frozen copy
def items = @items.dup.freeze

# ❌ Unnecessary instance variable for request-scoped state
class ApiClient
  def request
    @resp_headers = response.headers  # Why instance variable? Only used in this method
  end
end
# ✅ Use local scope — don't promote data to instance state unless needed across methods
class ApiClient
  def request
    response = nil
    begin
      response = execute
    rescue => e
      log_error(headers: response&.headers)  # Local scope, safe with &.
    end
  end
end

# ❌ Anaemic model — just a data bag with setters
class Product
  def set_name(name)   = @name = name
  def set_price(price) = @price = price
end
# ✅ Behaviour-rich class
class Product
  def restock(quantity) = ...
  def apply_discount(percent) = ...
  def discontinue! = ...
end
```

---

## No Comments / Self-Documenting Code

```ruby
# ❌ WRONG
def chk(u, p)
  # loop through perms and find
  u.p.each { |x| return true if x == p }
  false
end
```

```ruby
# ✅ CORRECT
def user_has_permission?(user, permission)
  user.permissions.include?(permission)
end
```

**Exception**: YARD/RDoc for public APIs in gems or shared libraries.

---

## Early Returns Over Nesting

```ruby
# ❌ WRONG
def process_payment(payment)
  if payment
    if payment.amount.positive?
      if user_verified?(payment.user_id)
        if sufficient_funds?(payment)
          execute(payment)
        end
      end
    end
  end
end
```

```ruby
# ✅ CORRECT
def process_payment(payment)
  raise ArgumentError,      "Payment is required"      unless payment
  raise ArgumentError,      "Amount must be positive"  unless payment.amount.positive?
  raise UnauthorizedError                               unless user_verified?(payment.user_id)
  raise InsufficientFundsError                          unless sufficient_funds?(payment)

  execute(payment)
end
```

---

## Summary Checklist

When writing Ruby/Rails OOP code, verify:

- [ ] Fields accessed via `attr_reader`; `attr_accessor` only when genuinely needed
- [ ] Classes and modules have a single, clear responsibility
- [ ] Behaviour lives on the class — no anaemic domain models
- [ ] `initialize` validates inputs and leaves objects in a valid state
- [ ] Mixins and delegation used for code reuse; inheritance only for true `is-a` (max 2 levels)
- [ ] Dependencies are injected, not instantiated inside the class
- [ ] Internal collections returned as frozen copies (`dup.freeze`)
- [ ] Value objects used for domain concepts (Money, Email, DateRange) with `freeze`
- [ ] Complex operations extracted to service objects with a `#call` interface
- [ ] ActiveRecord models stay slim — validations, scopes, simple predicates only
- [ ] No callbacks for side effects — use service objects instead
- [ ] No comments — names and structure communicate intent
- [ ] No deep nesting — guard clauses and early returns instead
