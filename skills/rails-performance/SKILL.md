---
name: rails-performance
description: Rails/PostgreSQL performance work — diagnosing slow endpoints, N+1 queries, EXPLAIN and indexing, aggregation/dashboard queries, and safe migrations on large tables. Use when something is slow, when adding indexes or heavy queries, or when a migration touches a big table. Measure first; never optimize on intuition.
---

# Rails / PostgreSQL Performance

## Core principle

**Measure, change one thing, measure again.** An optimization without a before/after number is a guess. The database is almost always the bottleneck in a Rails app — look there before touching Ruby.

## Diagnosis order

1. **Find the slow thing** — production logs (request time, `db_runtime`), or reproduce locally with realistic data volume. A query that's instant on 100 dev rows can be the whole problem on 10M production rows.
2. **Count the queries** — log the SQL in the console (`ActiveRecord::Base.logger = Logger.new($stdout)`) or run the request in a test with `assert_queries_count` / query counting. Many fast queries (N+1) beat one slow query as the most common cause.
3. **EXPLAIN the slow query** — `puts relation.explain(:analyze, :buffers)`. Read for: Seq Scan on large tables, rows estimated vs actual (bad stats), Sort/Hash spilling to disk, nested loops over large sets.
4. Only then change something.

## N+1 queries

- `includes`/`preload` for associations used in loops; `eager_load` when you also filter on the association (single LEFT JOIN query).
- `strict_loading` on a relation (or model-wide in dev) turns lazy loads into errors — use it to *prevent regressions* after fixing, not just to find.
- Serializer/JBuilder loops are the classic hiding spot: the controller looks clean, the view triggers the N+1. Count queries at the request level, not the model level.
- Counter caches (`counter_cache: true`) or a grouped `COUNT` query (`.group(:x).count` into a hash, then look up per row) replace per-row counts.

## Indexing

- Index what you filter/join/order on **together**: a composite index `(tenant_id, status, due_date)` serves `WHERE tenant_id = ? AND status = ?` ordered by `due_date`; three single-column indexes do not.
- Column order matters: equality columns first, then range/sort columns.
- Partial indexes for hot subsets: `WHERE deleted_at IS NULL`, `WHERE status = 'open'` — smaller, faster, cheaper to maintain.
- `EXPLAIN` proves whether the index is used; PostgreSQL ignores indexes with low selectivity or stale statistics (`ANALYZE table` after big data changes).
- Every index slows writes and takes disk — don't shotgun them. Remove unused ones (`pg_stat_user_indexes.idx_scan = 0`).

## Aggregations & dashboards

- Push aggregation into SQL (`group`, `sum`, window functions) — never load rows into Ruby to sum them.
- One round-trip beats many: build a single grouped query returning all buckets, not one query per kanban column / chart segment.
- For expensive recurring aggregates: materialize (a summary table maintained by jobs, or a materialized view refreshed on schedule) and serve reads from that.
- Beware `.count` on a relation you already loaded (`.size` uses the loaded array) and `SELECT COUNT(*)` on huge tables in a request path — estimate or materialize.
- Empty-relation short-circuits (`.none`) skip SQL entirely and can hide column errors in GROUP BY branches — run aggregate code against non-empty data in tests.

## Safe migrations on large tables

PostgreSQL locks are the danger, not the SQL. On a busy table:

- **Adding an index** → `algorithm: :concurrently` + `disable_ddl_transaction!` in the migration. A plain `add_index` takes a write lock for the whole build.
- **Adding a column with a default/NOT NULL** → add the column (fast, metadata-only on PG11+), backfill in batches (`in_batches.update_all`, throttled, in a job or rake task — never in the migration transaction), then add the constraint with `validate: false` + separate `validate_constraint`.
- **Set `lock_timeout`/`statement_timeout`** around DDL so a blocked migration fails fast instead of queueing every other query behind its lock request.
- **Renaming/dropping columns** → two-deploy dance: make code ignore the column (`ignored_columns`), deploy, then drop. Never rename in place.
- Batched backfills: fixed-size batches by primary key, sleep between batches, idempotent (safe to re-run from anywhere).

## Rails-side habits

- `find_each`/`in_batches` for any loop over unbounded rows; never `.all.each`.
- `pluck`/`pick` when you need values, not models; `select` to trim wide rows (careful: partially-loaded models raise on missing attributes).
- `exists?` beats `present?`/`any?` on unloaded relations (no row transfer).
- Cache expensive computed values with clear invalidation (updated_at-keyed fragment/Rails.cache) — but only after measuring; caching is a debt, not a default.
- Background anything slower than ~200ms that the user doesn't need synchronously (Sidekiq) — but make the job idempotent first.

## Checklist before calling it done

- [ ] Before/after numbers recorded (query count + wall time at realistic volume)
- [ ] `EXPLAIN (ANALYZE)` confirms the intended plan (index used, no seq scan on the big table)
- [ ] `strict_loading` or a query-count assertion pins the fix against regression
- [ ] Any new migration is safe under load (concurrent index, batched backfill, timeouts)
- [ ] No speculative caching or indexing "while we're here"
