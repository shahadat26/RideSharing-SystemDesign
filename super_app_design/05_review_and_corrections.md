# 05 — Critical Review (Staff SRE & Security Auditor)

Scope of review: [01_features_list.md](01_features_list.md), [02_system_design.md](02_system_design.md), [03_database_schema.md](03_database_schema.md), [04_api_list.md](04_api_list.md).

Goal: identify bottlenecks, missing indexes, security vulnerabilities, and scaling issues — especially around real-time socket connections for tens of thousands of concurrent drivers.

---

## A. Architecture / Scaling Issues

1. **Realtime Gateway is a single tier** — no mention of sharding sockets by city/region or how reconnect storms are absorbed after a deploy. At 100k+ concurrent drivers a single AZ outage causes a thundering herd.
2. **Sticky sessions for WebSocket** described but no mention of **connection draining** or **graceful shutdown** on pod rotation. Rolling deploys will drop all sockets.
3. **Kafka partitioning by city** for `location.driver.updates` is good, but there is **no hot-partition mitigation** — megacities (e.g., Dhaka) will overwhelm a single partition. Need sub-partitioning by `city_id + hash(driver_id) % N`.
4. **Dispatch service uses in-memory index** but no described **leader election / state replication**. A pod crash mid-offer leaves trips stuck. Need Temporal/Redis-backed offer state.
5. **No backpressure path** from Dispatch → Location Service if Redis is slow. A Redis slowdown will cascade into socket timeouts.
6. **Single Redis cluster** for geo + sessions + idempotency + rate-limit is overloaded. Sessions and rate-limits should be on a separate Redis to avoid noisy-neighbor with geo writes at 100k/s.
7. **No circuit breakers / bulkheads** mentioned between BFF and downstream; one slow service (e.g., Pricing) can exhaust BFF thread pools.
8. **Multi-region strategy** says "active-active read, active-passive write" but does not address **split-brain for wallet/ledger** during failover. Need a regional write-home or global consensus for money movement.
9. **No explicit capacity for KYC docs / image CDN** — viral restaurant launches can saturate origin.
10. **Analytics CDC via Debezium** not protected — a long slot causes WAL bloat → Postgres disk pressure → full outage.

## B. Security Vulnerabilities

1. **JWT in WebSocket query string** (`?token=`) — leaks into proxy logs and browser history. Should use `Sec-WebSocket-Protocol` subprotocol or a short-lived ticket exchanged via REST.
2. **No IDOR protections documented** — endpoints like `GET /rides/{trip_id}` must verify ownership (rider or driver on trip). Should be stated as a policy plus enforced.
3. **OTP endpoint rate-limits are per-phone only** — attackers rotate numbers; also need **per-IP** and **global** ceilings, plus CAPTCHA after N failures and constant-time OTP compare.
4. **No device binding** for driver sessions — stolen refresh token → attacker becomes driver. Need device_id binding + mTLS client certs for driver app, or DPoP.
5. **Payments webhooks** need replay protection (timestamp window + nonce), not just HMAC; add allow-list of provider IPs.
6. **No mention of PII minimization in Kafka topics** — location events contain driver_id + lat/lng forever in retention. Add PII masking in topic schemas and shorter retention (<= 7 d).
7. **SOS button** has no dedicated, authenticated, always-on channel separate from main gateway — during an outage, safety feature dies with the app.
8. **Admin APIs** (`/admin/*`) not documented as requiring MFA + step-up auth + network restriction.
9. **Masked phone call** feature: no mention of **PIN / voucher expiration**, so numbers get harvested.
10. **PostgreSQL column-encryption via pgcrypto** is fine but key rotation and HSM-backed KEK are not specified; also search on encrypted columns (NID) is impossible — document blind-index approach if needed.
11. **CORS policy, CSP, HSTS preload** not stated for consumer web/admin console.
12. **No input size limits / JSON depth limits** at API gateway — susceptible to resource-exhaustion DoS.
13. **No mention of SSRF protection** for merchant webhook URLs if merchants register callbacks.

## C. Database Schema Issues

1. **`trips` partitioning key** is `created_at` only — active-trip lookups by `status` + `city_id` will scan many partitions. Add a covering partial index, or partition by `(city_id, created_at)` hash/list composite.
2. **Missing index on `trips(driver_id, status)`** for the critical "does driver have an active trip?" check. Current index is `(driver_id, created_at DESC)` which is not selective.
3. **`trips.payment_id`** has no FK, no index; reconciliation scans are expensive. Add `CREATE INDEX idx_trips_payment ON trips(payment_id) WHERE payment_id IS NOT NULL`.
4. **`food_orders.status`** no index — merchant dashboards filter by `store_id, status`; current composite starts with `store_id` and includes status ✓ but active-orders-by-driver has no index beyond `driver_id`.
5. **`ratings`** index only on `ratee_id` — computing `rating_avg` with recent-window filters needs `(ratee_id, created_at DESC)`.
6. **`ledger_entries`** missing invariant check at DB level. Provide a deferred trigger that ensures sum(D) = sum(C) per txn_id; also add `CHECK (direction IN ('D','C'))` already present, but no UNIQUE on `(txn_id, account_id, direction)` to block duplicate postings.
7. **`payments.idempotency_key`** is globally unique — collisions across services are possible; should be scoped to `(service, idempotency_key)`.
8. **`promo_codes`** no per-user usage tracking table — cannot enforce `per_user_cap`. Need `promo_redemptions(code, user_id, redeemed_at)` with UNIQUE partial index.
9. **`stores` search** relies on both PG + Elasticsearch with no documented sync mechanism; drift is guaranteed. Need CDC from PG/Mongo → ES with outbox.
10. **`location_history` TTL 90 d** but dispute windows may require 180 d+ for billing — verify with legal.
11. **`audit_log`** uses `BIGSERIAL` without partitioning → unbounded growth; partition by month and archive.
12. **No tenant isolation** on admin tables — single compromised admin can read everything. RLS policies not defined.
13. **Foreign keys across service boundaries** (e.g., `food_orders.store_id → stores`) violate microservice boundaries; ok if co-located, but document that or move to logical references.

## D. API Issues

1. **`GET /rides/history`** — no cursor-based pagination; offset-based will degrade. Must expose `cursor` + `limit`.
2. **No `If-Match` / ETag** for PATCH endpoints (profile, menu items); concurrent edits silently overwrite.
3. **Responses leak internal IDs** (ULID-style `trp_01HZ...`) which is fine, but trip IDs should not be guessable by sequence — confirm random/ULID and enforce authorization (IDOR, see B.2).
4. **`POST /rides` returns 202** but no `Location` header or polling spec — clients will hammer WS+REST.
5. **No `Retry-After`** in 429 responses.
6. **Webhook spec** doesn't mention at-least-once semantics, timeouts, or exponential backoff.
7. **`/payments/intents`** lacks **3-D Secure / SCA** challenge flow for card payments in applicable regions.
8. **No documented max payload size** or field length limits.
9. **`/admin/ops/live-map`** can return thousands of drivers — needs bounding box params + max cap + tile-based delivery (or stream via WS).
10. **OTP verify** response should not distinguish "wrong OTP" vs "unknown phone" to prevent enumeration.

## E. Operational Gaps

- No defined **SLOs/SLIs** per critical path (dispatch time, socket drop rate, payment success).
- No **runbook for Redis geo cluster failure** — dispatch is 100% dependent.
- **Chaos tests** mentioned but no listed scenarios (e.g., kill 30% of Realtime Gateway pods during surge).
- **Cost guardrails**: Cassandra for chat at 180 d might not be justified; evaluate TTL.

---

## Priority to Fix (Top 10)

1. Harden WebSocket auth (no JWT in URL) + ticket exchange.
2. Shard Realtime Gateway per city, add draining, and reconnect jitter.
3. Sub-partition Kafka `location.driver.updates` to avoid hot megacity partitions.
4. Separate Redis clusters: `geo`, `session/idem/ratelimit`, `cache`.
5. Add missing indexes: `trips(driver_id, status)`, `trips(payment_id)`, `ratings(ratee_id, created_at DESC)`, partition-aware active-trip index.
6. Scope `payments.idempotency_key` to `(service, key)`; add `promo_redemptions` table.
7. Add IDOR / authorization contract language to every resource endpoint + device-bound driver sessions.
8. Enforce OTP rate-limiting on phone + IP + global + CAPTCHA; constant-time compare.
9. Ledger double-entry invariant trigger + UNIQUE `(txn_id, account_id, direction)`.
10. Partition `audit_log`; add retention & archival.
