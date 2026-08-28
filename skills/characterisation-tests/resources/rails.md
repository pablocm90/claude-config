# Rails / Minitest Characterisation

Ruby/Rails-specific tooling and patterns for the characterisation workflow. See the main `characterisation-tests` skill for the process and heuristics; `modern-tooling.md` is the TypeScript/Vitest counterpart.

## Naming and Placement

Use a dedicated directory instead of a file suffix, and `Characterisation` in the class name:

```
test/characterisation/                      # characterisation tests (temporary)
test/models/                                # behavior-driven tests (permanent)
```

```ruby
# test/characterisation/discount_calculator_test.rb

# CHARACTERISATION TESTS -- documenting actual behavior, NOT asserting correctness.
# Replace with behavior-driven tests as the code is refactored.
class DiscountCalculatorCharacterisationTest < ActiveSupport::TestCase
  test "characterises premium customer discount for < 5 years" do
    assert_equal 150.0, DiscountCalculator.call(amount: 1000, customer_type: "premium", years: 3)
  end
end
```

## Test-Framework Migration

When migrating RSpec specs to Minitest, characterise the code's behavior first, then rewrite the tests. The characterisation suite guards the port: if the Minitest version passes the same pins, the migration preserved coverage.

## Minitest Assertions for Characterisation

Minitest has no snapshot support -- the `"PLACEHOLDER"` dummy-assertion algorithm does the same job:

```ruby
# Let failure tell you the value
assert_equal "PLACEHOLDER", subject.calculate

# Pin object state after an operation
invoice.process!
assert_equal "processed", invoice.status
assert_not_nil invoice.processed_at

# Pin raised exceptions
error = assert_raises(ArgumentError) { service.call(bad_input) }
assert_equal "Amount must be positive", error.message

# Pin callback side effects
assert_difference("AuditLog.count", 1) { invoice.approve! }

# Pin query results (scopes)
assert_equal 3, Invoice.overdue.count
assert_includes Invoice.overdue.pluck(:id), invoices(:overdue_one).id
```

## Fixture-Based Characterisation

Use fixtures to characterise behavior against known data states -- fast, stable baseline:

```ruby
test "characterises overdue scope with fixture data" do
  overdue_ids = Invoice.overdue.pluck(:id).sort
  assert_equal "PLACEHOLDER", overdue_ids  # failure shows which fixtures are overdue
end
```

**Caution:** fixture-dependent characterisation tests break when fixtures change. That is intentional -- the test detects the change -- but keep the fixture dependency explicit in the test name.

**Key pattern:** use fixtures for existing data, inline creation for testing creation behavior. Do not create new FactoryBot factories in characterisation tests.

## Handling Non-Determinism

```ruby
# Dates and timestamps: travel_to (Rails built-in)
test "characterises invoice due date calculation" do
  travel_to Time.zone.parse("2026-01-15 10:00:00") do
    invoice = Invoice.create!(valid_attrs)
    assert_equal Date.parse("2026-02-14"), invoice.due_date
  end
end

# Random values / UUIDs: stub the source
test "characterises reference number generation" do
  SecureRandom.stub(:hex, "abc123") do
    invoice = Invoice.create!(valid_attrs)
    assert_equal "INV-ABC123", invoice.reference
  end
end

# External services: WebMock
test "characterises payment gateway response handling" do
  stub_request(:post, "https://api.stripe.com/v1/charges")
    .to_return(status: 200, body: { id: "ch_123", status: "succeeded" }.to_json)

  result = PaymentGateway.charge(amount: 1000, currency: "eur")
  assert_equal "ch_123", result.id
end
```

## Characterising ActiveRecord Models

Models often have complex callback chains, validations, and scopes. Characterise through the public interface:

```ruby
class InvoiceCharacterisationTest < ActiveSupport::TestCase
  test "characterises status after creation" do
    invoice = Invoice.create!(valid_invoice_attrs)
    assert_equal "draft", invoice.status
  end

  test "characterises what happens when marking as sent" do
    invoice = invoices(:basic)
    invoice.mark_as_sent!
    assert invoice.sent_to_debtor?
    assert_not_nil invoice.sent_to_debtor_at
  end

  test "characterises validation on negative amounts -- SUSPICIOUS" do
    # No validation exists -- negative amounts are accepted silently.
    invoice = Invoice.new(valid_invoice_attrs.merge(amount: -100))
    assert invoice.valid?
  end
end
```

## Characterising Service Objects / Interactors

Interactor-style services need both success and failure paths pinned:

```ruby
test "characterises successful payment" do
  result = CreatePayment.call(invoice: invoices(:unpaid), amount: 100)
  assert result.success?
  assert_not_nil result.payment
end

test "characterises failure when invoice already paid" do
  result = CreatePayment.call(invoice: invoices(:paid), amount: 100)
  assert result.failure?
  assert_includes result.errors, "Invoice already paid"
end
```

## Approval Testing Pattern

No `approvals`-style package needed -- hand-roll the golden-master step:

```ruby
test "characterises report output" do
  report = ReportGenerator.call(company: companies(:acme))
  approved_path = Rails.root.join("test/fixtures/approved/acme_report.txt")

  if approved_path.exist?
    assert_equal approved_path.read, report.to_s, "Report output changed -- review and re-approve"
  else
    approved_path.dirname.mkpath
    approved_path.write(report.to_s)
    flunk "New baseline created at #{approved_path} -- review and re-run"
  end
end
```

## Combination Testing Without Snapshots

Build a results array and let one failing `assert_equal "PLACEHOLDER", results` show every combination; paste the actual array back as the expected value:

```ruby
test "characterises discount across all customer types and year ranges" do
  results = [100, 1000, 10_000].flat_map do |amount|
    %w[standard premium business].flat_map do |type|
      [0, 3, 5, 7].map { |y| "#{type}/#{amount}/#{y} -> #{DiscountCalculator.call(amount:, customer_type: type, years: y)}" }
    end
  end
  assert_equal "PLACEHOLDER", results
end
```

Same trade-off as the Vitest version: broad but undocumenting -- replace with focused tests as you understand the code.

## Coverage

`bin/rails test` with SimpleCov plays the role of `vitest --coverage` in the coverage-guided loop (see `modern-tooling.md` for the loop itself).
