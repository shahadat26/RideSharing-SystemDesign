# 02 — System Design (Principal Systems Architect)

**Scope:** High-availability, horizontally-scalable microservices architecture for the super app defined in [01_features_list.md](01_features_list.md).

---

## 1. Architectural Principles

- **Domain-driven microservices** — one service owns one bounded context and its data.
- **Async-first for events, sync for queries** — Kafka for durable events, gRPC for internal RPC, REST/GraphQL at the edge.
- **Cell-based deployment per region/city cluster** for blast-radius isolation.
- **Stateless services** behind horizontal autoscalers; state in managed data stores.
- **Idempotency everywhere** (request-id header, dedup tables).
- **Defense in depth** — mTLS between services, OAuth2/OIDC at edge, short-lived JWTs.

---

## 2. High-Level Topology

```
                 ┌──────────────────────────────────────┐
  Mobile Apps →  │           Edge / CDN (CloudFront)    │
  Merchant Web → │   WAF + DDoS + TLS termination       │
                 └──────────────┬───────────────────────┘
                                │
                 ┌──────────────▼───────────────┐
                 │  API Gateway (Kong/Envoy)    │  ← Authn, rate-limit, routing
                 └───────┬──────────────────┬───┘
                         │(REST/GraphQL)    │(WebSocket/MQTT)
        ┌────────────────▼─────┐   ┌────────▼────────────────┐
        │  BFF: Customer/Driver│   │  Realtime Gateway       │
        │  /Merchant/Admin     │   │  (sticky sessions)      │
        └───────┬──────────────┘   └────────┬────────────────┘
                │ gRPC                       │ pub/sub
        ┌───────▼───────────────────────────▼────────────────────────────┐
        │                     Service Mesh (Istio/Linkerd, mTLS)          │
        └───┬────────┬────────┬─────────┬─────────┬─────────┬─────────┬──┘
            │        │        │         │         │         │         │
         User    Ride-     Location  Dispatch  Order    Payment   Notification
         Svc     Match     Tracking  /Match-   /Food/   /Ledger   Svc
                 Svc       Svc       making    Parcel
                                     Svc       Svc
            │        │        │         │         │         │         │
        PostgreSQL Redis   Redis Geo   Kafka   MongoDB   PostgreSQL  Kafka
        (users)  (cache) +Cassandra   topics  (menus)   (ledger)    + FCM/APNs
                         (history)
```

---

## 3. Microservice Catalog

| # | Service | Responsibility | Primary Store | Key Tech |
|---|---------|----------------|---------------|----------|
| 1 | **API Gateway** | Authn, rate limit, routing, request shaping | — | Kong / Envoy |
| 2 | **BFF (per client)** | Client-shaped aggregation | — | Node.js / Go |
| 3 | **Identity Service** | Sign-up, OTP, OAuth, sessions, RBAC | PostgreSQL + Redis | Go |
| 4 | **User Profile Service** | Profile, addresses, preferences | PostgreSQL | Go/Java |
| 5 | **Driver Service** | Driver profile, KYC, vehicle, status | PostgreSQL + S3 (docs) | Java |
| 6 | **Merchant Service** | Retail merchant accounts, storefronts, API keys, webhooks | PostgreSQL | Java |
| 6b | **Restaurant Service** | Food-vertical merchant (restaurant) profile, outlets, opening hours, prep-time | PostgreSQL | Java |
| 6c | **Hub Service** | Courier hub network, capacity, cut-off times, staff roster | PostgreSQL | Go |
| 7 | **Catalog Service** | Menus/items/availability (food) + retail catalog | MongoDB + Elasticsearch | Node.js |
| 8 | **Location Tracking Service** | Ingest driver location stream | Redis (GEOADD) + Kafka + Cassandra (history) | Go |
| 9 | **Ride-Matching / Dispatch Service** | Match request ↔ best driver | Redis + in-mem index | Go |
| 10 | **Pricing Service** | Fare estimate, surge, promos | Redis + PostgreSQL | Python/Go |
| 11 | **Trip/Order Orchestrator** | State machine of a trip or order (Saga) | PostgreSQL + Kafka | Java (Temporal/Camunda) |
| 12 | **Food-Order Service** | Food-specific order flow | PostgreSQL + MongoDB | Node.js |
| 13 | **Parcel Service** | Intra-city parcel flow (single-leg, direct) | PostgreSQL | Go |
| 13b | **Courier Service** | Inter-city / country-wide courier with multi-leg hub routing (AWB, manifest, sort, line-haul, last-mile) | PostgreSQL (partitioned) + Kafka | Go/Java |
| 13c | **COD / Remittance Service** | Tracks COD collection per shipment, driver bag, hub float; reconciles to ledger | PostgreSQL (ledger) | Java |
| 14 | **Payment Service** | Charges, refunds, payout, ledger | PostgreSQL (double-entry ledger) | Java |
| 15 | **Wallet Service** | In-app wallet balance & topup | PostgreSQL | Java |
| 16 | **Notification Service** | Push/SMS/Email/In-app | Kafka consumer; FCM/APNs/Twilio | Go |
| 17 | **Chat Service** | Masked in-app chat | Cassandra + Redis presence | Elixir/Go |
| 18 | **Review/Rating Service** | Ratings & reviews | PostgreSQL | Node.js |
| 19 | **Promo/Loyalty Service** | Coupons, referrals, tiers | PostgreSQL + Redis | Go |
| 20 | **Fraud & Risk Service** | Rule + ML scoring on events | Kafka + Feature Store | Python |
| 21 | **Search Service** | Restaurant/item search | Elasticsearch/OpenSearch | — |
| 22 | **Admin/Ops Service** | Back-office APIs | PostgreSQL | Java |
| 23 | **Analytics / DWH pipeline** | CDC → Kafka → S3 → Snowflake/BigQuery | — | Debezium |
| 24 | **Realtime Gateway** | WebSocket/MQTT fan-out to apps | Redis pub/sub | Go/Elixir |

---

## 4. Communication Protocols

| Flow | Protocol | Rationale |
|------|----------|-----------|
| Client ↔ Gateway (commands/queries) | **HTTPS REST / GraphQL** | Broad client support |
| Client ↔ Realtime Gateway (driver location, ride status) | **WebSocket** (fallback MQTT over TLS on driver app) | Persistent, low-overhead |
| Service ↔ Service (sync RPC) | **gRPC (HTTP/2) with Protobuf** over mTLS | Low latency, typed contracts |
| Service ↔ Service (async events) | **Apache Kafka** | Durable, replayable event log |
| Transactional fan-out | **Kafka + Outbox pattern** (Debezium CDC) | Avoid dual-write |
| Short-lived work queues (retries, payouts, notifications) | **RabbitMQ** or SQS | Better per-message ack semantics |
| Service discovery | **Kubernetes DNS / Istio** | — |

### 4.1 Key Kafka Topics

- `location.driver.updates` (partitioned by city)
- `ride.requested`, `ride.matched`, `ride.accepted`, `ride.completed`, `ride.cancelled`
- `order.food.created`, `order.food.status_changed`
- `order.parcel.*`
- `payment.authorized`, `payment.captured`, `payment.failed`
- `user.kyc.updated`
- `fraud.signal`
- `notification.outbound`

---

## 5. Realtime Location & Matchmaking

### 5.1 Location ingest

1. Driver app emits GPS every **2–5 s** over a persistent WebSocket to the **Realtime Gateway**.
2. Gateway validates JWT + driver session → forwards to **Location Tracking Service** via gRPC stream.
3. Location Service writes the **latest** position to **Redis** (`GEOADD drivers:<city>`) with 30 s TTL, and publishes a compact event to Kafka `location.driver.updates`.
4. A **Cassandra** sink consumes Kafka for historical trails (for billing disputes, heatmaps).
5. Consumers (Heatmap, ETA, Dispatch) subscribe only to what they need.

### 5.2 Matchmaking (Dispatch Service)

- On `ride.requested`, Dispatch queries Redis `GEOSEARCH` for candidate drivers within an expanding radius (500 m → 1 km → 3 km).
- Scores candidates: `score = w1·ETA + w2·driverRating + w3·acceptanceRate − w4·idleTime`.
- Sends offer to top-N drivers **sequentially** with a timeout (e.g., 8 s each) or broadcast-and-first-accept (configurable).
- State machine driven by **Temporal** for reliability (retries, timeouts, compensations).

---

## 6. API Gateway & Edge

- **API Gateway (Kong/Envoy)**: TLS, OIDC token validation, per-route rate limits, request size caps, schema validation, circuit breaking.
- **WAF (AWS WAF / Cloudflare)** in front: OWASP rules, bot management, geo-blocking if needed.
- **CDN**: static assets + signed URLs for restaurant images.
- **Global load balancing**: Route53 + regional ALBs; latency-based routing.

---

## 7. Caching Strategy

| Cache | Purpose | TTL |
|-------|---------|-----|
| Redis (hot) | Sessions, driver geo-index, fare estimates, idempotency keys | 30 s – 15 min |
| Redis cluster (pricing) | Surge multipliers per zone | 1 min |
| CDN | Menu images, static assets | long |
| Read-replica DBs | Heavy read endpoints | — |
| Elasticsearch | Restaurant & item search | rebuild nightly + live updates |

Cache invalidation via **event-driven busting** on write topics.

---

## 8. Data Layer Summary (details in 03)

- **PostgreSQL** (sharded by user_id or city_id where needed) — users, trips, orders, payments, ledger.
- **MongoDB** — menu/catalog documents.
- **Redis** — geo index, sessions, rate limits, hot caches.
- **Cassandra** — high-volume append-only (location history, chat).
- **Elasticsearch / OpenSearch** — search, logs.
- **S3 / object store** — KYC documents, invoices, trip receipts.
- **Snowflake / BigQuery** — warehouse for analytics.

---

## 9. Observability

- **Logs**: structured JSON → Fluent Bit → Elasticsearch/Loki.
- **Metrics**: Prometheus + Grafana; RED/USE dashboards per service.
- **Tracing**: OpenTelemetry → Jaeger/Tempo; trace_id propagated via gateway.
- **Business KPIs**: trip acceptance rate, dispatch time, order fulfillment SLA.

---

## 10. Security

- mTLS (service mesh) internally, TLS 1.3 externally.
- OAuth2/OIDC + short-lived JWT (5 min) + refresh tokens.
- Secret management via Vault/KMS; no secrets in code.
- PII encryption at rest (column-level for phone/NID); tokenized card data — provider-hosted PCI vault.
- Rate limiting + bot detection at gateway.
- Role-based access for admin console; full audit log → immutable store (WORM S3).

---

## 11. Reliability & Deployment

- **Kubernetes (EKS/GKE)** multi-AZ, multi-region active-active for read, active-passive for write per region.
- **Canary + blue/green** deploys via Argo Rollouts.
- **Chaos engineering** (GameDay) monthly.
- **Backups**: PITR for PostgreSQL, snapshot for Cassandra, cross-region replication for S3.
- **DR**: RPO 5 min / RTO 30 min for core.

---

## 12. Scalability Tactics

- **Sharding**: Location service per city; PostgreSQL partitioned by time/city.
- **Autoscaling**: HPA on CPU + custom metrics (Kafka lag).
- **Backpressure**: rate-limit driver location to 1 update/2 s server-side if overloaded.
- **Connection fan-out**: Realtime Gateway uses epoll/kqueue; Elixir/Go for 100k+ concurrent sockets per node.
- **Read scaling**: replicas + CQRS for read-heavy endpoints.

---

## 13. Post-Review Revisions (applied from 05_review_and_corrections.md)

> Changes highlighted here supersede earlier sections. See the review file for rationale.

### 13.1 Realtime Gateway — sharded & drain-safe (changes §5.1, §12)

- **City-sharded fleet:** `rt-gw-{city}` StatefulSet per major city; DNS `rt-<city>.superapp.example`. Clients obtain the correct shard via `/realtime/resolve` REST call returning `{ws_url, ticket, ttl_s}`.
- **Ticket-based WS auth (NEW):** clients exchange JWT for a **single-use, 30-second WebSocket ticket** at `POST /realtime/ticket`. JWT is **never** placed in the WS query string. The WS handshake passes the ticket via `Sec-WebSocket-Protocol: ticket.<value>`.
- **Graceful shutdown:** pods receive `SIGTERM` → stop accepting new connections → send `{type:"drain", resume_after_s}` → close sockets after 30 s. Client SDK reconnects with **full jitter backoff** (base 1 s, cap 30 s) + randomized per-pod stagger to prevent thundering herds.
- **Reconnect storm control:** edge applies a global token bucket on `/realtime/ticket` (per city) and a shed rule on the gateway itself.
- **Per-region SOS fast path (NEW):** SOS frames published to a dedicated `sos.events` topic with a separate, minimally-dependent consumer (Ops paging) that does **not** share infrastructure with dispatch; fallback direct HTTPS endpoint `POST /safety/sos` with offline retry on driver app.

### 13.2 Kafka partitioning — hot-partition mitigation (changes §4.1)

- `location.driver.updates` key becomes `hash(driver_id) % SUB_PARTITIONS_PER_CITY` with topic names `location.driver.updates.<city>` (N partitions sized to peak megacity load).
- Consumer groups scale per topic; cross-city fan-out removed.
- PII minimization: event schema strips `accuracy_m` and user-agent; retention reduced to **72 h** on Kafka (long-term trail lives in Cassandra with TTL).

### 13.3 Dispatch Service durability (changes §5.2)

- Offer state is persisted via **Temporal** workflow (one workflow per trip request). Dispatch pods are stateless workers; a crash mid-offer is resumed by another worker.
- Offer TTL enforced by Temporal timer (not in-memory), guaranteeing timeout even during partial outages.
- **Circuit breakers & bulkheads**: BFF and Dispatch wrap Pricing/Location calls with per-dependency thread pools and a fail-fast circuit (e.g., resilience4j / Envoy outlier detection).

### 13.4 Redis topology — split clusters (changes §7)

| Cluster | Purpose |
|---------|---------|
| `redis-geo-<city>` | Driver geo index only. Write-heavy, tuned with AOF everysec. |
| `redis-session` | Sessions, idempotency keys, OTP codes. |
| `redis-cache` | Pricing cache, surge, rate limits, chat presence. |

Noisy-neighbor risk between geo writes and auth traffic is eliminated.

### 13.5 Multi-region write correctness (changes §11)

- Wallet / ledger: **region-pinned writes** (a user's wallet has a home region; all writes route there). Cross-region failover of money movement requires explicit break-glass with reconciliation job — **never automatic** — to avoid split-brain.
- Non-financial stores (profile, catalog): active-active with last-writer-wins + CRDT where viable.

### 13.6 Observability & reliability additions

- **SLOs defined:** dispatch-time p95 < 6 s; socket drop rate < 0.5% / 5 min; payment success > 99.5%; live-map API p99 < 400 ms.
- **Chaos scenarios** (scheduled): kill 30% RT-GW pods during peak; Redis-geo AZ failure; Debezium slot stall; Kafka broker loss.
- **Debezium CDC guardrails:** slot lag monitor + automatic slot drop-and-reseed runbook; WAL disk alert at 60%.

### 13.7 Security hardening (changes §10)

- **WS auth:** ticket model (see 13.1). JWT removed from URL everywhere.
- **Driver device binding:** refresh tokens bound to `device_id` + attested device key (Android Play Integrity / iOS App Attest). Stolen refresh tokens are unusable on another device.
- **Admin:** MFA (TOTP/WebAuthn) + IP allow-list + step-up auth for destructive actions; full audit trail with 4-eyes approval for suspend/refund > threshold.
- **Webhook replay protection:** signature now includes `t=<unix>`; accepted window ±5 min; server maintains nonce cache. Providers also allow-listed by source IP.
- **Edge hardening:** WAF rules for JSON depth & size caps (256 KB body, depth 16); CORS locked to app origins; `Strict-Transport-Security` with `preload`; CSP for web.
- **Masked comms:** phone mask PINs expire at trip-end + 30 min; merchant webhook URLs validated against SSRF rules (no private ranges / metadata IPs).

### 13.8 Summary of what changed

- §5.1 Realtime ingest rewritten with sharded gateway, drain, ticket auth, SOS fast path.
- §5.2 Dispatch moved to Temporal-backed durable workflow; bulkheads/circuit breakers added.
- §4.1 Kafka topics sub-partitioned per city with shorter retention and PII minimization.
- §7 Redis split into three clusters.
- §10 Security section expanded (WS tickets, device binding, admin MFA, webhook replay, edge hardening).
- §11 Multi-region write model clarified for financial data.

---

## 14. Six-Panel Model & Courier Pipeline

### 14.1 Panel → BFF → Service map

| Panel | BFF | Core services touched |
|-------|-----|------------------------|
| **Rider App** | `bff-rider` | Identity, User Profile, Pricing, Dispatch, Trip Orchestrator, Food-Order, Parcel, Courier, Payment, Notification, Chat, Rating |
| **Driver App** | `bff-driver` | Identity, Driver, Location, Dispatch, Trip Orchestrator, Payment (payout), Notification, Chat, COD/Remittance |
| **Restaurant Panel** | `bff-restaurant` | Identity, Restaurant, Catalog, Food-Order, Payment (payout), Notification |
| **Merchant Panel** | `bff-merchant` | Identity, Merchant, Catalog, Parcel, Courier, COD/Remittance, Payment (payout), Notification |
| **Hub Panel** | `bff-hub` | Identity (staff RBAC), Hub, Courier, COD/Remittance, Notification |
| **Admin Dashboard** | `bff-admin` | All services (read + privileged write), Admin/Ops, Fraud, Analytics, Audit |

Each BFF is a separate deployment with its own OIDC client and rate-limit profile.

### 14.2 Courier (country-wide) pipeline

Multi-leg shipment lifecycle orchestrated by the **Trip/Order Orchestrator** (Temporal) using domain events on Kafka:

```
  [Merchant/Rider books]
          │
          ▼
  ┌─────────────────┐   courier.shipment.created
  │ Courier Service │ ─────────────────────────────▶ Kafka
  └───────┬─────────┘
          │  AWB (barcode) generated
          ▼
   Leg 1: FIRST-MILE PICKUP  (Driver / Bike)
          │  courier.leg.picked_up
          ▼
   Origin Hub: SCAN-IN         (Hub staff — Hub Panel)
          │  courier.hub.scan_in
          ▼
   SORT by destination hub    (Sort-code on label)
          │  courier.hub.sorted
          ▼
   Leg 2: LINE-HAUL  (Truck driver, manifest + seal)
          │  courier.manifest.dispatched
          ▼
   Destination Hub: INBOUND SCAN
          │  courier.hub.scan_in (inbound)
          ▼
   Handover to last-mile rider
          │  courier.leg.handover
          ▼
   Leg 3: LAST-MILE DELIVERY  (Driver / Bike)
          │  courier.leg.delivered  (+ optional COD collected)
          ▼
   Reconcile COD → Ledger
```

Key design points:

- **AWB (Air-Waybill number)** is the stable ID across all legs; customer tracking uses AWB, not internal UUIDs.
- **Idempotent scan events** keyed by `(awb, hub_id, scan_type)` to tolerate repeat scans at hubs.
- **Hub capacity** & **cut-off time** per hub published in Redis; Courier Service refuses bookings after cut-off for same-day dispatch.
- **Line-haul manifest** is a first-class aggregate: `manifest_id`, `origin_hub`, `dest_hub`, `vehicle_id`, `seal_no`, list of AWBs; reconciled on inbound scan (mismatches create exceptions).
- **Exceptions** (damaged / missing / address-issue / RTO) are a separate state machine — never silently lost.
- **Failure compensation:** Saga rolls back payment authorization if pickup never happens within N hours; refunds COD float if lost.

### 14.3 COD (Cash-on-Delivery) flow

1. Last-mile driver marks `delivered + cod_collected` with photo proof.
2. Driver end-of-day closes bag at a hub/office → **Remittance Service** debits driver float account, credits hub cash-float account (double-entry ledger in [03_database_schema.md](03_database_schema.md#26-payments-double-entry-ledger)).
3. Hub deposits to bank → ledger posts final transfer to platform clearing account.
4. Merchant weekly payout = Σ(delivered COD) − commission − adjustments.
5. All transitions are ledger entries; no floating cash state outside the ledger.

### 14.4 Kafka topics added

- `courier.shipment.*` (created, cancelled, delivered, exception)
- `courier.leg.*` (picked_up, handover, delivered)
- `courier.hub.*` (scan_in, sorted, manifest_dispatched, manifest_received)
- `remittance.*` (driver_closed, hub_deposited, merchant_payout_ready)

Partitioning key: `origin_hub_id` (high-throughput hubs sub-partitioned by `hash(awb)`).

### 14.5 Hub Panel app specifics

- **Tablet / PC web app** with barcode-scanner input focus mode.
- Works offline for ≥ 15 min (IndexedDB queue) — scans flushed to server when online; backend dedupes on `(awb, hub_id, scan_type, scan_ts_bucket)`.
- Hub staff identity is **separate from driver/merchant identity**; staff assigned to a specific hub with RBAC (`hub_clerk`, `hub_supervisor`, `hub_finance`).
- Device binding + MFA enforced on hub-finance role (COD handling).
