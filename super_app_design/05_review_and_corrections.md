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

---

## F. Six-Panel & Courier/Hub Additions — Second Review Pass

Scope of this pass: Restaurant, Merchant, Hub panels and country-wide Courier pipeline added in `01` §1, `02` §14, `03` §2.3b/c and §2.5b, `04` §1.5–1.9 and §2.6–2.9.

### F.1 Architecture / Scaling

1. **Bulk shipment API `/merchant/shipments/bulk` is synchronous in spec** — will time out on 10k-row CSVs. Must be **async with batch-id + status polling** (or server-sent events) and write via Kafka + workers.
2. **Hub scan fan-out** — every scan touches `courier_shipments.status`. At peak (100+ scans/sec per mega-hub) the row-level hotspot on a single shipment causes lock contention across sort/manifest stages. Move status to an **append-only events + materialized latest-status view** (CDC-refreshed) or use advisory locks per `awb_no`.
3. **Manifest dispatch is a multi-row transaction** (manifest + N AWBs + N shipment_legs). Needs to be idempotent at the manifest level with `Idempotency-Key` and bounded in size (chunk > 5000 AWBs into sub-manifests).
4. **Offline hub-app queue** — if a hub loses connectivity for hours, replay of thousands of scans at reconnect can overwhelm the backend. Need **server-side rate limiting per device** and client-side batch endpoints (`/hub/scans/bulk`) with 1 MB cap and exponential backoff.
5. **Public tracking endpoint `/courier/track/{awb}`** is the classic target of scraping / enumeration. Need heavy caching (CDN with 60 s TTL), AWB obfuscation length ≥ 11 chars (already ok), per-IP + per-AWB rate limits, and bot detection.
6. **Hub cut-off logic** is per-hub but no clear clock source — clock-skew across hubs will create edge-case booking disputes. Use server-authoritative `Asia/Dhaka` time and cache cut-offs in Redis with short TTL.
7. **No topology diagram** for cross-region courier (if countries expand). Document assumption: single-country deployment; multi-country deferred to V2.

### F.2 Security / Fraud

1. **COD endpoints are money-movement** and currently only require role. Must require **MFA + step-up** and **device-bound session** for `hub_finance`, plus **4-eyes approval** for deposits above threshold.
2. **Driver COD bag** is a cash custody object — need anti-fraud checks: collected ≠ delivered reconciliation, aging alerts (cash held > 24h triggers review), and a dispute log.
3. **Merchant API keys** — lifecycle undefined. Need scopes (create-shipment only vs full), rotation, IP allow-list, and rate limits **per key** (not per account).
4. **Webhook URLs registered by merchants** — document SSRF protection (private IP/cloud metadata blocklist, DNS pinning), max body size, HMAC signing, and allow `X-Signature-Version` for future algorithm migration.
5. **Recipient PII on courier labels** — printed labels contain phone & full address. Labels should use a masked phone (masking proxy number) and a QR for full-address lookup only by authorized hub staff.
6. **Cross-panel authorization** — `/hub/shipments/{awb}` must check `staff.hub_id ∈ {shipment.origin_hub, shipment.dest_hub, shipment.current_leg.hub}`; otherwise any hub clerk can read any shipment (IDOR across hubs).
7. **Restaurant / Merchant login reuse** — if they share the same `users` table, document that a user can hold multiple roles but role elevation (becoming hub_finance) requires a separate onboarding + MFA.

### F.3 Schema

1. `courier_shipments.awb_no` **UNIQUE** is scoped per-partition (`UNIQUE (awb_no, created_at)`) — queries by AWB alone won't be unique at index level; the `idx_courier_awb` is BTREE but not unique. Add a **global unique constraint** via a separate non-partitioned `awb_index(awb_no PRIMARY KEY, shipment_id, created_at)` table that is written in the same transaction, so lookups by AWB are O(log n) and truly unique.
2. `shipment_scans` unique constraint `(awb_no, hub_id, scan_type, scanned_at)` uses exact timestamp — offline devices will send slightly different timestamps for the same logical event. Better: bucket by minute (`date_trunc('minute', scanned_at)`) **or** include `client_scan_id` in the unique constraint.
3. `shipment_legs` FK to partitioned parent works but inserts require knowing `shipment_created_at` — document that API must always carry it or indirect via `awb_index`.
4. No index on `courier_shipments(status, sla_deadline)` for the SLA-breach report used by Hub KPIs. Add:
   ```sql
   CREATE INDEX idx_courier_sla_breach ON courier_shipments(sla_deadline)
       WHERE status IN ('created','picked_up','at_origin_hub','in_transit','at_dest_hub','out_for_delivery');
   ```
5. `cod_collections.status` is a workflow on money — add a **CHECK** constraint and a state-transition trigger to prevent `deposited → collected` regressions.
6. `hubs.cutoff_time` is a single `TIME` but hubs may have multiple service tiers with different cut-offs. Consider `hub_cutoffs(hub_id, service_tier, cutoff_time)` for future-proofing.
7. `courier_lanes` rate is flat per-kg; real carriers have **slab pricing** (0–1 kg flat, 1–5 kg rate, etc.). Model as `courier_lane_slabs` child table.

### F.4 API

1. `/merchant/shipments` request does not specify **max weight / dimensions** validation or service-tier eligibility — overweight bookings must be rejected at API with a typed error (`shipment.overweight`).
2. `/hub/scans` lacks **last-write-wins tie-breaker** when offline replay collides; add `client_scan_id` to spec (already added, but mark as **required**).
3. Public `/courier/track/{awb}` should return **stable, minimal status vocabulary** ("Booked / In Transit / Out for Delivery / Delivered / Returned") — not internal enum values — to avoid coupling customers to internal states.
4. `/merchant/api-keys` missing scopes + secret echoed only on creation; document one-time-secret pattern.
5. No pagination contract defined for `/hub/shipments` beyond `cursor=`; spec should state opaque base64 cursor with embedded sort key.
6. Missing endpoint: **RTO (return-to-origin)** initiation — add `POST /hub/shipments/{awb}/rto`, `POST /merchant/shipments/{awb}/request-rto`.

### F.5 Operational

- Need **SLOs for hub operations**: scan latency < 500 ms p95, manifest-dispatch success > 99.9%, COD reconciliation drift < 0.1% daily.
- Hub printer/scanner hardware drift: define firmware/OS baseline for tablet + printer compatibility matrix.
- Line-haul vehicle GPS: spec assumes driver app runs on truck; confirm battery/networking for multi-hour trips on intercity routes.

---

## Priority to Fix (Top 10) — Updated

1. Harden WebSocket auth (no JWT in URL) + ticket exchange.
2. Shard Realtime Gateway per city, add draining, and reconnect jitter.
3. Sub-partition Kafka `location.driver.updates` + add `courier.*` topic partitioning by `origin_hub_id`.
4. Separate Redis clusters: `geo`, `session/idem/ratelimit`, `cache`.
5. Missing indexes: `trips(driver_id) active`, `trips(payment_id)`, `ratings(ratee_id, created_at DESC)`, `courier_shipments(status, sla_deadline)`, plus global `awb_index` for AWB uniqueness.
6. Scope `payments.idempotency_key` to `(service, key)`; add `promo_redemptions`, `cod_collections` state-transition guard.
7. IDOR / authorization on every resource — incl. hub-staff cross-hub read, merchant API-key scopes, RBAC for Hub Panel.
8. MFA + step-up + 4-eyes for `hub_finance` COD deposits; device binding for driver & hub-finance sessions.
9. Async bulk shipment booking (`/merchant/shipments/bulk`) + bounded offline hub-scan replay.
10. Ledger double-entry invariant trigger + COD reconciliation with aging alerts + partitioned `audit_log`.
