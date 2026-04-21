# 03 — Database Schema (Enterprise DBA)

Cross-references: [01_features_list.md](01_features_list.md), [02_system_design.md](02_system_design.md).

---

## 1. Polyglot Persistence Mapping

| Service | Database | Why |
|---------|----------|-----|
| Identity, User Profile, Driver, Merchant | **PostgreSQL** | ACID, strong relational model, row-level security |
| Trip Orchestrator, Food Order, Parcel | **PostgreSQL** (partitioned by `created_at` month + `city_id`) | Strong transactions + reporting |
| Payment Ledger & Wallet | **PostgreSQL** (double-entry) | Correctness > throughput |
| Catalog (menus/items/modifiers) | **MongoDB** | Flexible nested documents, per-merchant variability |
| Active drivers / geo index | **Redis** (GEO) | Sub-ms proximity queries |
| Sessions, rate limits, idempotency | **Redis** | TTL native |
| Ride/location history, chat messages | **Cassandra** | Write-heavy, time-series |
| Restaurant & item search | **Elasticsearch** | Text + filters + geo |
| Event log | **Kafka** (not a DB; source-of-truth for events) | Replayable |
| KYC docs, receipts | **S3** + metadata in Postgres | Cheap blob store |
| Analytics | **Snowflake / BigQuery** (CDC from PG) | OLAP |

---

## 2. PostgreSQL — Core Relational Schema

Conventions: `snake_case`, UUID v7 primary keys (time-ordered), `created_at`/`updated_at` on every table, soft-delete via `deleted_at`.

### 2.1 Identity & Users

```sql
CREATE TABLE users (
    user_id          UUID PRIMARY KEY,
    phone_e164       VARCHAR(16) UNIQUE NOT NULL,
    email            VARCHAR(255) UNIQUE,
    full_name        VARCHAR(120),
    password_hash    TEXT,                 -- argon2id
    status           VARCHAR(20) NOT NULL DEFAULT 'active', -- active|suspended|deleted
    locale           VARCHAR(8)  DEFAULT 'en',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at       TIMESTAMPTZ
);
CREATE INDEX idx_users_phone ON users(phone_e164);
CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL;

CREATE TABLE user_addresses (
    address_id   UUID PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    label        VARCHAR(40),         -- Home, Work
    line1        TEXT NOT NULL,
    city         VARCHAR(80),
    country      VARCHAR(2),
    lat          DOUBLE PRECISION NOT NULL,
    lng          DOUBLE PRECISION NOT NULL,
    geog         GEOGRAPHY(POINT,4326) GENERATED ALWAYS AS (ST_MakePoint(lng,lat)::geography) STORED,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_user_addresses_user ON user_addresses(user_id);
CREATE INDEX idx_user_addresses_geog ON user_addresses USING GIST (geog);

CREATE TABLE auth_sessions (
    session_id   UUID PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users(user_id),
    refresh_hash TEXT NOT NULL,
    device_id    TEXT,
    ip_inet      INET,
    expires_at   TIMESTAMPTZ NOT NULL,
    revoked_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sessions_user ON auth_sessions(user_id) WHERE revoked_at IS NULL;
```

### 2.2 Drivers & Vehicles

```sql
CREATE TABLE drivers (
    driver_id         UUID PRIMARY KEY REFERENCES users(user_id),
    nid_number_enc    BYTEA,                     -- encrypted (pgcrypto/KMS)
    license_number_enc BYTEA,
    kyc_status        VARCHAR(20) DEFAULT 'pending', -- pending|approved|rejected
    rating_avg        NUMERIC(3,2) DEFAULT 0,
    total_trips       INTEGER DEFAULT 0,
    home_city_id      INTEGER,
    capabilities      TEXT[] DEFAULT '{}',       -- {ride_bike,ride_car,food,parcel}
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_drivers_kyc ON drivers(kyc_status);
CREATE INDEX idx_drivers_city ON drivers(home_city_id);

CREATE TABLE vehicles (
    vehicle_id   UUID PRIMARY KEY,
    driver_id    UUID NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE,
    type         VARCHAR(20) NOT NULL,   -- bike|car|suv|truck
    plate_no     VARCHAR(20) NOT NULL,
    model        VARCHAR(80),
    color        VARCHAR(30),
    doc_expiry   DATE,
    active       BOOLEAN DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (plate_no)
);
CREATE INDEX idx_vehicles_driver ON vehicles(driver_id);
```

### 2.3 Merchants & Stores

```sql
CREATE TABLE merchants (
    merchant_id   UUID PRIMARY KEY,
    owner_user_id UUID REFERENCES users(user_id),
    legal_name    VARCHAR(160) NOT NULL,
    tax_id_enc    BYTEA,
    kyc_status    VARCHAR(20) DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stores (
    store_id     UUID PRIMARY KEY,
    merchant_id  UUID NOT NULL REFERENCES merchants(merchant_id) ON DELETE CASCADE,
    name         VARCHAR(160) NOT NULL,
    cuisine_tags TEXT[],
    lat          DOUBLE PRECISION NOT NULL,
    lng          DOUBLE PRECISION NOT NULL,
    geog         GEOGRAPHY(POINT,4326) GENERATED ALWAYS AS (ST_MakePoint(lng,lat)::geography) STORED,
    is_open      BOOLEAN DEFAULT FALSE,
    prep_time_min INTEGER DEFAULT 20,
    rating_avg   NUMERIC(3,2) DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_stores_merchant ON stores(merchant_id);
CREATE INDEX idx_stores_geog ON stores USING GIST (geog);
CREATE INDEX idx_stores_open ON stores(is_open) WHERE is_open;
```

### 2.4 Trips (Ride / Parcel)

Partitioned monthly by `created_at` (declarative partitioning).

```sql
CREATE TABLE trips (
    trip_id         UUID NOT NULL,
    service_type    VARCHAR(10) NOT NULL,   -- ride|parcel
    rider_id        UUID NOT NULL,          -- customer
    driver_id       UUID,
    vehicle_type    VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL,   -- requested|matched|accepted|started|completed|cancelled
    pickup_lat      DOUBLE PRECISION NOT NULL,
    pickup_lng      DOUBLE PRECISION NOT NULL,
    dropoff_lat     DOUBLE PRECISION NOT NULL,
    dropoff_lng     DOUBLE PRECISION NOT NULL,
    city_id         INTEGER NOT NULL,
    distance_m      INTEGER,
    duration_s      INTEGER,
    fare_amount     NUMERIC(12,2),
    fare_currency   CHAR(3),
    surge_x         NUMERIC(4,2) DEFAULT 1.0,
    payment_id      UUID,
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    matched_at      TIMESTAMPTZ,
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    cancel_reason   VARCHAR(80),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (trip_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_trips_rider ON trips(rider_id, created_at DESC);
CREATE INDEX idx_trips_driver ON trips(driver_id, created_at DESC);
CREATE INDEX idx_trips_status_city ON trips(city_id, status) WHERE status IN ('requested','matched','accepted','started');
```

### 2.5 Food Orders

```sql
CREATE TABLE food_orders (
    order_id       UUID NOT NULL,
    customer_id    UUID NOT NULL,
    store_id       UUID NOT NULL,
    driver_id      UUID,
    status         VARCHAR(24) NOT NULL, -- created|accepted_by_store|preparing|ready|picked_up|delivered|cancelled
    subtotal       NUMERIC(12,2) NOT NULL,
    delivery_fee   NUMERIC(12,2) NOT NULL,
    service_fee    NUMERIC(12,2) DEFAULT 0,
    discount       NUMERIC(12,2) DEFAULT 0,
    total          NUMERIC(12,2) NOT NULL,
    currency       CHAR(3) NOT NULL,
    delivery_addr_id UUID NOT NULL,
    payment_id     UUID,
    placed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivered_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (order_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_food_orders_customer ON food_orders(customer_id, created_at DESC);
CREATE INDEX idx_food_orders_store ON food_orders(store_id, status);
CREATE INDEX idx_food_orders_driver ON food_orders(driver_id) WHERE driver_id IS NOT NULL;

CREATE TABLE food_order_items (
    item_id      UUID PRIMARY KEY,
    order_id     UUID NOT NULL,
    order_created_at TIMESTAMPTZ NOT NULL,
    catalog_item_id TEXT NOT NULL,          -- references Mongo _id
    name_snapshot TEXT NOT NULL,
    qty          INTEGER NOT NULL,
    unit_price   NUMERIC(12,2) NOT NULL,
    modifiers    JSONB,
    FOREIGN KEY (order_id, order_created_at) REFERENCES food_orders(order_id, created_at)
);
CREATE INDEX idx_food_items_order ON food_order_items(order_id);
```

### 2.6 Payments (Double-Entry Ledger)

```sql
CREATE TABLE payments (
    payment_id     UUID PRIMARY KEY,
    user_id        UUID NOT NULL,
    ref_type       VARCHAR(20) NOT NULL,  -- trip|food_order|parcel|wallet_topup
    ref_id         UUID NOT NULL,
    method         VARCHAR(20) NOT NULL,  -- card|mfs|wallet|cash
    provider       VARCHAR(30),           -- stripe|bkash|nagad|...
    provider_ref   TEXT,
    amount         NUMERIC(12,2) NOT NULL,
    currency       CHAR(3) NOT NULL,
    status         VARCHAR(20) NOT NULL,  -- authorized|captured|failed|refunded
    idempotency_key TEXT UNIQUE NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    captured_at    TIMESTAMPTZ
);
CREATE INDEX idx_payments_user ON payments(user_id, created_at DESC);
CREATE INDEX idx_payments_ref ON payments(ref_type, ref_id);

CREATE TABLE ledger_accounts (
    account_id  UUID PRIMARY KEY,
    owner_type  VARCHAR(20) NOT NULL,     -- user|driver|merchant|platform
    owner_id    UUID,
    currency    CHAR(3) NOT NULL,
    balance     NUMERIC(18,2) NOT NULL DEFAULT 0,
    UNIQUE (owner_type, owner_id, currency)
);

CREATE TABLE ledger_entries (
    entry_id    UUID PRIMARY KEY,
    txn_id      UUID NOT NULL,            -- groups debit+credit
    account_id  UUID NOT NULL REFERENCES ledger_accounts(account_id),
    direction   CHAR(1) NOT NULL CHECK (direction IN ('D','C')),
    amount      NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    ref_type    VARCHAR(20),
    ref_id      UUID,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ledger_entries_account ON ledger_entries(account_id, created_at DESC);
CREATE INDEX idx_ledger_entries_txn ON ledger_entries(txn_id);
```

### 2.7 Ratings, Promos, Admin

```sql
CREATE TABLE ratings (
    rating_id   UUID PRIMARY KEY,
    ref_type    VARCHAR(20) NOT NULL, -- trip|food_order
    ref_id      UUID NOT NULL,
    rater_id    UUID NOT NULL,
    ratee_id    UUID NOT NULL,
    score       SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (ref_type, ref_id, rater_id)
);
CREATE INDEX idx_ratings_ratee ON ratings(ratee_id);

CREATE TABLE promo_codes (
    code         VARCHAR(40) PRIMARY KEY,
    type         VARCHAR(20) NOT NULL,    -- percent|flat
    value        NUMERIC(10,2) NOT NULL,
    max_uses     INTEGER,
    per_user_cap INTEGER DEFAULT 1,
    valid_from   TIMESTAMPTZ NOT NULL,
    valid_to     TIMESTAMPTZ NOT NULL,
    service_scope TEXT[] DEFAULT '{ride,food,parcel}',
    active       BOOLEAN DEFAULT TRUE
);
CREATE INDEX idx_promo_active ON promo_codes(active, valid_to);

CREATE TABLE audit_log (
    audit_id    BIGSERIAL PRIMARY KEY,
    actor_id    UUID,
    actor_role  VARCHAR(20),
    action      VARCHAR(60) NOT NULL,
    target_type VARCHAR(40),
    target_id   TEXT,
    payload     JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_actor ON audit_log(actor_id, created_at DESC);
CREATE INDEX idx_audit_target ON audit_log(target_type, target_id);
```

---

## 3. MongoDB — Catalog Service

### 3.1 `menu_items` collection

```json
{
  "_id": "itm_01HZX...",
  "store_id": "uuid-of-store",
  "name": { "en": "Chicken Biryani", "bn": "চিকেন বিরিয়ানি" },
  "description": "Fragrant basmati rice with chicken",
  "category": "Main Course",
  "price": { "amount": 320.00, "currency": "BDT" },
  "images": ["https://cdn.../biryani.jpg"],
  "modifiers": [
    { "group": "Spice",      "required": true,  "options": [
        {"code":"mild","name":"Mild","price_delta":0},
        {"code":"hot","name":"Hot","price_delta":0}]},
    { "group": "Add-ons",    "required": false, "multi": true, "options": [
        {"code":"egg","name":"Boiled Egg","price_delta":30}]}
  ],
  "tags": ["halal","bestseller"],
  "available": true,
  "prep_time_min": 20,
  "updated_at": "2026-04-01T10:00:00Z"
}
```

Indexes: `{store_id:1, available:1}`, `{tags:1}`, text index on `name.*`, `description`.

### 3.2 `store_profiles` collection (rich merchant-facing content)

```json
{
  "_id": "store-uuid",
  "banner_url": "...",
  "opening_hours": [
    {"day":"MON","open":"10:00","close":"23:00"}
  ],
  "promo_banners": [ { "text":"20% off", "valid_to":"2026-05-01" } ],
  "updated_at": "2026-04-01T10:00:00Z"
}
```

---

## 4. Redis — Key Namespaces

| Key pattern | Type | Purpose | TTL |
|-------------|------|---------|-----|
| `drivers:geo:{city}` | GEO (sorted set) | Latest driver positions for dispatch | refreshed on update; member TTL via companion key |
| `driver:status:{driver_id}` | HASH `{status, capabilities, last_seen}` | Online/offline, service mode | 60 s sliding |
| `session:{session_id}` | STRING (JWT meta) | Session validation | matches refresh TTL |
| `idem:{service}:{key}` | STRING | Idempotency response | 24 h |
| `surge:{city}:{zone}` | STRING (multiplier) | Dynamic pricing | 60 s |
| `ratelimit:{route}:{user}` | INCR + EXPIRE | Per-user rate limit | 60 s |
| `otp:{phone}` | STRING | OTP code hash | 5 min |
| `presence:chat:{user_id}` | STRING | Online presence | 30 s |

---

## 5. Cassandra — High-Volume Time Series

### 5.1 `location_history`

```cql
CREATE TABLE location_history (
    driver_id   uuid,
    bucket_day  date,
    ts          timestamp,
    lat         double,
    lng         double,
    speed_mps   float,
    heading     smallint,
    trip_id     uuid,
    PRIMARY KEY ((driver_id, bucket_day), ts)
) WITH CLUSTERING ORDER BY (ts DESC)
  AND default_time_to_live = 7776000; -- 90 days
```

### 5.2 `chat_messages`

```cql
CREATE TABLE chat_messages (
    conversation_id uuid,
    ts              timeuuid,
    sender_id       uuid,
    body_enc        blob,
    PRIMARY KEY (conversation_id, ts)
) WITH CLUSTERING ORDER BY (ts DESC);
```

---

## 6. Elasticsearch — Search Indexes

### 6.1 `stores` index (simplified mapping)

```json
{
  "mappings": {
    "properties": {
      "store_id":   { "type": "keyword" },
      "name":       { "type": "text", "analyzer": "standard" },
      "cuisine_tags": { "type": "keyword" },
      "rating_avg": { "type": "float" },
      "is_open":    { "type": "boolean" },
      "location":   { "type": "geo_point" },
      "city_id":    { "type": "integer" },
      "prep_time_min": { "type": "integer" }
    }
  }
}
```

### 6.2 `menu_items` index

Fields: `item_id`, `store_id`, `name_en`, `name_bn`, `tags`, `price`, `available`, `location` (denormalized from store), `popularity_score`.

---

## 7. Indexing & Performance Notes

- Geo columns use **PostGIS GIST** indexes; for Redis geo the key is city-scoped to bound set size.
- Trips and food_orders are **range-partitioned monthly** — old partitions detached and archived to S3 (Parquet) after 6 months.
- Hot-path queries (active ride by driver/rider) covered by partial indexes on `status`.
- Payments guarded by **UNIQUE(idempotency_key)**.
- Ledger invariant enforced by DB trigger: `SUM(D) = SUM(C)` per `txn_id` (deferred constraint).
- Read replicas for heavy read endpoints (history, receipts); writes only to primary.
- Connection pooling via **PgBouncer** in transaction mode.

---

## 8. Data Security & Privacy

- Column-level encryption (pgcrypto + KMS envelope) for NID, tax_id, license numbers.
- PII masking in logs.
- Row-level security policies for admin multi-tenant console.
- Retention: location_history 90 d, chat 180 d, audit_log 7 y (compliance).

---

## 9. Post-Review Revisions (applied from 05_review_and_corrections.md)

> This section supersedes conflicting earlier DDL. All changes are additive migrations.

### 9.1 Missing / refined indexes

```sql
-- Critical: "does this driver have an active trip?"
CREATE INDEX idx_trips_driver_active
    ON trips(driver_id)
    WHERE status IN ('matched','accepted','started');

-- Payments reconciliation
CREATE INDEX idx_trips_payment
    ON trips(payment_id)
    WHERE payment_id IS NOT NULL;

-- Active food orders by driver
CREATE INDEX idx_food_orders_driver_active
    ON food_orders(driver_id)
    WHERE status IN ('picked_up','ready');

-- Ratings time-window queries
CREATE INDEX idx_ratings_ratee_time
    ON ratings(ratee_id, created_at DESC);
```

### 9.2 Payments: service-scoped idempotency

```sql
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_idempotency_key_key;
ALTER TABLE payments ADD COLUMN service VARCHAR(30) NOT NULL DEFAULT 'unknown';
ALTER TABLE payments
    ADD CONSTRAINT payments_idem_uq UNIQUE (service, idempotency_key);
```

### 9.3 Ledger invariants (double-entry integrity)

```sql
-- Block duplicate postings
ALTER TABLE ledger_entries
    ADD CONSTRAINT ledger_entries_txn_acct_dir_uq
        UNIQUE (txn_id, account_id, direction);

-- Enforce sum(D)=sum(C) per txn at commit time
CREATE OR REPLACE FUNCTION check_ledger_balanced() RETURNS trigger AS $$
DECLARE d NUMERIC(18,2); c NUMERIC(18,2);
BEGIN
    SELECT COALESCE(SUM(CASE WHEN direction='D' THEN amount END),0),
           COALESCE(SUM(CASE WHEN direction='C' THEN amount END),0)
    INTO d, c FROM ledger_entries WHERE txn_id = NEW.txn_id;
    IF d <> c THEN
        RAISE EXCEPTION 'Ledger unbalanced for txn %: D=% C=%', NEW.txn_id, d, c;
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_ledger_balanced
    AFTER INSERT ON ledger_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION check_ledger_balanced();
```

### 9.4 Promo per-user enforcement (missing table)

```sql
CREATE TABLE promo_redemptions (
    redemption_id UUID PRIMARY KEY,
    code          VARCHAR(40) NOT NULL REFERENCES promo_codes(code),
    user_id       UUID NOT NULL,
    ref_type      VARCHAR(20) NOT NULL,   -- trip|food_order|parcel
    ref_id        UUID NOT NULL,
    redeemed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- enforce per_user_cap in application logic; DB prevents duplicate redemption per ref
CREATE UNIQUE INDEX uq_promo_redemption_ref
    ON promo_redemptions(code, ref_type, ref_id);
CREATE INDEX idx_promo_redemption_user ON promo_redemptions(code, user_id);
```

### 9.5 Audit log — partitioned & retention-bound

```sql
-- Convert audit_log to monthly range-partitioned by created_at
-- (performed as migration: create new partitioned table, backfill, swap)
CREATE TABLE audit_log_p (
    audit_id    BIGSERIAL,
    actor_id    UUID,
    actor_role  VARCHAR(20),
    action      VARCHAR(60) NOT NULL,
    target_type VARCHAR(40),
    target_id   TEXT,
    payload     JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (audit_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_audit_p_actor  ON audit_log_p(actor_id, created_at DESC);
CREATE INDEX idx_audit_p_target ON audit_log_p(target_type, target_id);
-- Partitions older than 24 months detached and archived to S3 (Parquet), kept 7 y for compliance.
```

### 9.6 Trip partition-aware active index

Earlier index `idx_trips_status_city` is replaced by a **local partial index on each partition** (created automatically on partitioned table) plus the new `idx_trips_driver_active` (9.1). Active-trip lookups now hit a small, current-month partition.

### 9.7 Catalog ↔ Search sync (was undocumented)

- PostgreSQL/Mongo writes emit **outbox events** → Debezium → Kafka `catalog.changed` → ES indexer consumer. Indexer is idempotent (doc version = `updated_at` epoch).
- Drift reconciler job nightly diffs PG/Mongo vs ES and repairs.

### 9.8 Encrypted-column searchability

- Blind-index columns added for exact-match lookups on encrypted fields:

```sql
ALTER TABLE drivers  ADD COLUMN nid_bidx       BYTEA;  -- HMAC_SHA256(nid, pepper)
ALTER TABLE merchants ADD COLUMN tax_id_bidx   BYTEA;
CREATE INDEX idx_drivers_nid_bidx    ON drivers(nid_bidx);
CREATE INDEX idx_merchants_taxid_bidx ON merchants(tax_id_bidx);
```

- KEK rotated in KMS/HSM; DEK re-wrapped without re-encrypting ciphertext.

### 9.9 Retention adjustments

- `location_history` TTL raised to **180 d** (billing dispute window).
- Kafka location topic retention cut to **72 h** (Cassandra is source of truth).

### 9.10 Summary of what changed

- §2.4/§2.5/§2.7 indexes updated (9.1, 9.6).
- §2.6 Payments idempotency scoped and ledger invariant enforced (9.2, 9.3).
- §2.7 Promo redemption table added (9.4); audit_log partitioned (9.5).
- §6 Catalog↔ES sync via outbox/CDC (9.7).
- §8 Blind indexes + KEK rotation noted (9.8).
- Retention policies updated (9.9).
