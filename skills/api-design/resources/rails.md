# Rails API Patterns

Rails/Ruby implementations of the main `api-design` skill's patterns. Principles live in SKILL.md; this file only maps them to Rails idioms.

## Naming Conventions (override SKILL.md's camelCase table)

Rails APIs use snake_case throughout — the SKILL.md naming table reflects JS/TS conventions.

| Pattern | Convention | Example |
|---------|-----------|---------|
| Query params | snake_case | `?sort_by=created_at&per_page=20` |
| Response fields | snake_case | `{ created_at:, invoice_id: }` |
| Enum values | snake_case | `"in_progress"`, `"completed"` |
| Pagination params | `page` / `per_page` | `?page=1&per_page=20` |

## Contract First

Define the endpoint contract as a spec before writing controller code:

```ruby
# POST /api/v1/tasks
# Request:  { title: String (required), description: String (optional), priority: "low"|"medium"|"high" (optional) }
# Response: { id: Integer, title: String, description: String|null, priority: String, created_at: ISO8601, updated_at: ISO8601 }
# Errors:   422 with validation errors
```

## Input/Output Separation

Strong parameters are the input contract; the serializer is the output contract. The serializer IS the documentation — define it first. Strong params handle input filtering; model validations handle business rules — keep them separate.

```ruby
def invoice_params
  params.require(:invoice).permit(:amount, :due_date, :description)
end
```

Render timestamps with `.iso8601` in serializers.

## Error Rendering

RFC 9457 as a controller concern:

```ruby
module ProblemDetails
  def render_problem(type:, title:, status:, detail:, **extensions)
    render json: { type:, title:, status:, detail:, **extensions },
      status: status, content_type: "application/problem+json"
  end
end
```

Simpler internal shape:

```ruby
render json: { error: "INVOICE_NOT_FOUND", message: "Invoice not found" }, status: :not_found
```

## Idempotency

Idempotency keys backed by an ActiveRecord cache, scoped to the user:

```ruby
def create
  idempotency_key = request.headers["Idempotency-Key"]
  return render_error("Missing Idempotency-Key header", :bad_request) unless idempotency_key

  cached = IdempotencyCache.find_by(key: idempotency_key, user: current_user)
  return render json: cached.response_body, status: cached.response_status if cached

  payment = PaymentService.create(payment_params)
  IdempotencyCache.create!(key: idempotency_key, user: current_user,
    response_body: PaymentSerializer.new(payment).to_json, response_status: 201)
  render json: PaymentSerializer.new(payment), status: :created
end
```

Idempotent DELETE:

```ruby
def destroy
  task = current_user.tasks.find_by(id: params[:id])
  task&.destroy
  head :no_content  # 204 whether it existed or not
end
```

## Rate Limiting

Use `rack-attack` middleware. Ensure `RateLimit-*` headers on every response and `Retry-After` on 429s.

## Versioning

URL path versioning maps to namespaced controllers:

```ruby
namespace :api do
  namespace :v1 do
    resources :invoices
  end
end
```

## Deprecation Headers

```ruby
response.headers["Sunset"] = "Sat, 01 Sep 2029 00:00:00 GMT"
response.headers["Link"] = '<https://api.example.com/docs/migration>; rel="sunset"'
```

## HTTP Caching

```ruby
def show
  invoice = current_company.invoices.find(params[:id])
  render json: InvoiceSerializer.new(invoice) if stale?(invoice)  # conditional GET via ETag
end

def index
  expires_in 5.minutes, public: false
end

response.headers["Cache-Control"] = "no-store"  # sensitive data
```

## Security (OWASP → Rails)

- **BOLA**: scope queries through the owning association — `current_company.invoices.find(params[:id])`, never `Invoice.find(params[:id])`
- **Mass assignment**: strong parameters on every create/update; never permit privilege fields (`:role`, `:admin`)
- **Function-level auth**: `before_action :require_admin!, only: [:destroy, :update_role]`
- **SSRF**: `uri = URI.parse(params[:callback_url])`; block `localhost` and `IPAddr.new(uri.host).private?`
- **Misconfiguration**: `config.consider_all_requests_local = false` in production; CORS via `rack-cors`; security headers via the `secure_headers` gem or an `after_action` in `ApplicationController`

## JWT

```ruby
# WRONG -- library picks algorithm from token header
payload = JWT.decode(token, key)

# CORRECT -- caller specifies accepted algorithms
payload = JWT.decode(token, key, true, algorithms: ["ES256"])
```
