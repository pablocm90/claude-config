# Walking Skeleton — Worked Examples

Five shapes. Each shows the boundary map, the boring thread, what is real vs stubbed, and the first end-to-end test. Adapt, don't copy.

---

## 1. Greenfield Rails API service

**Boundary map**

```
HTTP client ──▶ Rails router ──▶ controller ──▶ service ──▶ Postgres
                                      │
                                      └──▶ Sidekiq ──▶ Redis
                        deploy: CI ──▶ container ──▶ hosting platform
```

Unknowns marked: hosting platform + secrets (never deployed this app), Sidekiq/Redis wiring (new), auth scheme (new).

**Thread:** `POST /v1/pings` persists a `Ping` row with one field; a background job stamps `processed_at`; `GET /v1/pings/:id` returns it.

Boring on purpose — no domain logic at all, but it crosses HTTP, auth, controller, DB write, queue, worker, DB update, DB read, serialization.

**Real vs stubbed**

| Component | Real? | Why |
|---|---|---|
| Postgres | Real | The migration, connection pooling, and DB provisioning are unproven |
| Sidekiq + Redis | Real | Queue wiring is a marked unknown; an inline job proves nothing |
| Auth | Real mechanism, one hardcoded principal | Prove the token flow; defer roles to Pundit policies later |
| Hosting deploy | Real | The whole reason the skeleton exists |
| Any third-party API | Not in the skeleton | Not on the critical path for this thread — defer explicitly |

**First end-to-end test** (Minitest, driving the deployed app over HTTP):

```ruby
class PingSkeletonTest < ActionDispatch::IntegrationTest
  test "a ping is accepted, processed in the background, and read back" do
    post "/v1/pings", params: { ping: { label: "skeleton" } },
                      headers: auth_headers, as: :json
    assert_response :created
    id = response.parsed_body["data"]["id"]

    perform_enqueued_jobs

    get "/v1/pings/#{id}", headers: auth_headers, as: :json
    assert_response :success
    assert_equal "skeleton", response.parsed_body["data"]["attributes"]["label"]
    assert response.parsed_body["data"]["attributes"]["processed_at"].present?
  end
end
```

Run this same assertion against the **deployed** environment as a smoke test in the pipeline. The in-process version is the fast feedback loop; the deployed version is what makes the skeleton walk.

**Strides:** boot + one unit test → CI green on push → integration test failing for the right reason → deploy pipeline reaches a live URL → auth crossed → DB write/read crossed → Sidekiq/Redis crossed → smoke test green against deployed env → logging + `/health`.

**Deferrals to write down:** authorization rules, error paths, pagination, rate limiting, any real domain object.

---

## 2. Greenfield TypeScript / React front end

**Boundary map**

```
browser ──▶ router ──▶ page ──▶ query hook ──▶ HTTP ──▶ API
                                    │
   build ──▶ typecheck ──▶ bundle ──▶ static host ──▶ CDN
```

Unknowns: hosting + env-var injection at build time, auth token handoff, API CORS, the query-client cache boundary.

**Thread:** one route renders one value fetched from one real API endpoint, with a loading state and an error state.

The loading and error states are not scope creep — they are the two states that prove the data boundary is real rather than a hardcoded constant.

**Real vs stubbed**

| Component | Real? | Why |
|---|---|---|
| API call | Real, against a deployed API | CORS, auth header, and env config are the unknowns |
| Query client | Real | Its config (retries, staleness) is an architectural choice made once |
| Auth token | Real acquisition, one test user | Token handoff between host and app is a classic late-discovered break |
| Component library theme | Real setup, no design work | Theming is a one-time architectural decision |
| Routing | Real | Deep-link + refresh behaviour on the static host is frequently broken |

**First end-to-end test** (Vitest Browser Mode — accessible queries, never CSS selectors):

```ts
test("the dashboard shows the value fetched from the API", async () => {
  const screen = render(<App />)

  await expect.element(screen.getByRole("status", { name: /loading/i })).toBeInTheDocument()
  await expect.element(screen.getByRole("heading", { name: /skeleton/i })).toBeInTheDocument()
})
```

Plus one deployed smoke check that the built bundle loads, the route deep-links, and a hard refresh does not 404 — the failures a component test cannot see.

**Deferrals:** every other route, real design, optimistic updates, offline, i18n.

---

## 3. Third-party integration

The highest-value skeleton shape, because integration unknowns cluster in exactly the places documentation is vaguest.

**Thread:** authenticate against the sandbox, make the single cheapest real call, persist the response, surface one field.

**Rules specific to this shape**

- Call the real API at least once in the skeleton. A skeleton built entirely on recorded fixtures proves your fixtures agree with themselves.
- Prove **credential rotation and sandbox↔production switching**, not just a working call. The credential story is what breaks at launch.
- Record the real response as your fixture on the way through — that is the byproduct that makes the fixture trustworthy.
- Cross the error path once: an expired or wrong token. How the third party signals failure is part of the boundary.
- Prove the timeout and retry policy exists, even if the values change later.

**Deferrals:** the other 40 endpoints, webhook ingestion, reconciliation, backfills.

---

## 4. Data pipeline / batch job

**Boundary map**

```
source ──▶ extract ──▶ transform ──▶ load ──▶ warehouse ──▶ consumer
             scheduler ──▶ runner ──▶ logs/alerts
```

**Thread:** one row, from real source to real warehouse, visible to one real consumer query, triggered by the real scheduler.

**Rules specific to this shape**

- One row, not one file. Volume is a later slice; the path is this one.
- The **scheduler must fire it**. A pipeline you only ever run by hand has an untested trigger, which is where these fail.
- Include the idempotency decision now — re-run the skeleton twice and assert the consumer sees one row, not two. Retrofitting idempotency into a pipeline is expensive.
- Include one observability signal: rows in, rows out, duration.

**Deferrals:** volume, backfill, schema evolution, late-arriving data, partial failure recovery.

---

## 5. Brownfield: a steel thread through a legacy system

The common case in a mature codebase. You are not building a skeleton for the whole system — that system already walks. You are threading **one new capability** through it and proving the unfamiliar segments.

**Method**

1. **Trace the existing path first.** Read, or instrument, the real route a comparable request takes today. Do not design against the architecture diagram; design against what the code does. If the path is untested, load `characterisation-tests` and pin the current behaviour before touching it.
2. **Mark only the unfamiliar segments.** The parts of the path exercised daily by production traffic are already proven. Your thread's job is the new segments and the joints where new meets old.
3. **Find the seam.** Where the thread must pass through untestable code, load `finding-seams` and create a substitution point *without editing the call site*.
4. **Thread the boring payload through, behind a flag.** Feature-flagged and off by default is the brownfield equivalent of "deployed but under-featured" — it lets the skeleton reach production without exposure.
5. **Exercise it in production, safely.** One internal account, one flagged request. This is the step that finds the environment differences no staging environment reproduces.
6. **Then grow it** via `story-splitting` / `planning`.

**What to be careful of**

- **The joint is the risk, not the new code.** Where your thread meets an existing model, transaction, callback chain, or background job is where assumptions collide. Thread *through* the joint in the skeleton; do not stop just short of it.
- **A shared signature you change is a fleet-wide change.** Grep app-wide for callers and run their tests — a thread that quietly widens an existing method is not thin.
- **Don't let the flag become permanent.** Record its removal as a follow-up in the deferrals section.

**Definition of done differs:** you are not proving build/deploy/test — those exist. You are proving *this path*, *in production*, *reversibly*.
