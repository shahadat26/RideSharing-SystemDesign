# 04 — API List (Lead Backend Developer)

Based on [01_features_list.md](01_features_list.md), [02_system_design.md](02_system_design.md), [03_database_schema.md](03_database_schema.md).

- Base URL: `https://api.superapp.example/v1`
- Auth: `Authorization: Bearer <JWT>` unless noted.
- Idempotency: mutating requests SHOULD send `Idempotency-Key: <uuid>`.
- Tracing: `X-Request-Id`, `traceparent` propagated.
- Errors: RFC 7807 problem+json.

```json
// Standard error envelope
{
  "type": "https://api.superapp.example/errors/validation",
  "title": "Validation failed",
  "status": 400,
  "detail": "pickup.lat is required",
  "trace_id": "..."
}
```

---

## 1. REST API — Summary Table

### 1.1 Identity & Users

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/otp/request` | Public | Send OTP to phone |
| POST | `/auth/otp/verify`  | Public | Verify OTP → issue tokens |
| POST | `/auth/refresh`     | Refresh | Rotate access token |
| POST | `/auth/logout`      | Bearer | Revoke session |
| GET  | `/users/me`         | Bearer | Current user profile |
| PATCH| `/users/me`         | Bearer | Update profile |
| GET  | `/users/me/addresses` | Bearer | List addresses |
| POST | `/users/me/addresses` | Bearer | Add address |
| DELETE | `/users/me/addresses/{id}` | Bearer | Delete address |

### 1.2 Rides / Parcel (Trips)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/rides/estimate`   | Bearer | Fare + ETA estimate |
| POST | `/rides`            | Bearer | Request a ride (creates trip) |
| GET  | `/rides/{trip_id}`  | Bearer | Get trip state |
| POST | `/rides/{trip_id}/cancel` | Bearer | Cancel |
| POST | `/rides/{trip_id}/rate`   | Bearer | Rate driver |
| GET  | `/rides/history`    | Bearer | Past trips (paginated) |
| POST | `/parcels`          | Bearer | Request a parcel pickup |
| GET  | `/parcels/{trip_id}`| Bearer | Parcel trip state |

### 1.3 Food

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET  | `/food/stores`                | Bearer | Nearby stores (geo) |
| GET  | `/food/stores/{id}`           | Bearer | Store details |
| GET  | `/food/stores/{id}/menu`      | Bearer | Menu items |
| GET  | `/food/search?q=&lat=&lng=`   | Bearer | Search stores/items |
| POST | `/food/cart/validate`         | Bearer | Validate cart (price/stock) |
| POST | `/food/orders`                | Bearer | Place order |
| GET  | `/food/orders/{id}`           | Bearer | Order status |
| POST | `/food/orders/{id}/cancel`    | Bearer | Cancel if allowed |
| POST | `/food/orders/{id}/rate`      | Bearer | Rate |

### 1.4 Driver

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/driver/status`              | Driver | Set online/offline + capabilities |
| GET  | `/driver/offers/current`      | Driver | Currently offered trip (if any) |
| POST | `/driver/offers/{id}/accept`  | Driver | Accept offer |
| POST | `/driver/offers/{id}/reject`  | Driver | Reject |
| POST | `/driver/trips/{id}/arrived`  | Driver | Arrived at pickup |
| POST | `/driver/trips/{id}/start`    | Driver | Start trip |
| POST | `/driver/trips/{id}/complete` | Driver | Complete trip |
| GET  | `/driver/earnings?range=`     | Driver | Earnings summary |
| POST | `/driver/payouts`             | Driver | Request instant payout |

### 1.5 Restaurant Panel (Food vertical)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET  | `/restaurant/outlets/{id}/orders?status=`    | Restaurant | Incoming food orders |
| POST | `/restaurant/orders/{id}/accept`             | Restaurant | Accept (with prep-time) |
| POST | `/restaurant/orders/{id}/reject`             | Restaurant | Reject with reason |
| POST | `/restaurant/orders/{id}/ready`              | Restaurant | Mark ready for pickup |
| PATCH| `/restaurant/menu/items/{id}`                | Restaurant | Edit / toggle availability |
| POST | `/restaurant/menu/items`                     | Restaurant | Create menu item |
| PATCH| `/restaurant/outlets/{id}/hours`             | Restaurant | Update opening hours |
| POST | `/restaurant/outlets/{id}/toggle-open`       | Restaurant | Open/close outlet |
| GET  | `/restaurant/payouts?range=`                 | Restaurant | Payout history |
| GET  | `/restaurant/analytics/summary?range=`       | Restaurant | Top items, peak hours |

### 1.6 Merchant Panel (Parcel + Courier + Retail)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/merchant/shipments`                        | Merchant | Book single parcel/courier shipment |
| POST | `/merchant/shipments/bulk`                   | Merchant | Bulk upload (CSV/JSON) — returns batch id |
| GET  | `/merchant/shipments?status=&from=&to=&cursor=` | Merchant | List shipments |
| GET  | `/merchant/shipments/{awb_no}`               | Merchant | Shipment detail + scan history |
| POST | `/merchant/shipments/{awb_no}/cancel`        | Merchant | Cancel (only before pickup) |
| GET  | `/merchant/shipments/{awb_no}/label`         | Merchant | Get printable label (PDF A5/A6) |
| POST | `/merchant/pickups`                          | Merchant | Schedule pickup window |
| GET  | `/merchant/rates?origin=&dest=&kg=&tier=`    | Merchant | Rate card lookup |
| GET  | `/merchant/cod/remittance?range=`            | Merchant | COD remittance report |
| GET  | `/merchant/payouts?range=`                   | Merchant | Weekly payout statements |
| POST | `/merchant/api-keys`                         | Merchant | Issue API key |
| POST | `/merchant/webhooks`                         | Merchant | Register webhook URL (signed) |
| GET  | `/merchant/catalog/items`                    | Merchant | Retail catalog (if enabled) |
| POST | `/merchant/catalog/items`                    | Merchant | Add retail item |

### 1.7 Hub Panel (Courier operations)

All endpoints require `hub_staff` role bound to a specific `hub_id`; finance actions require `hub_finance` + MFA.

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/hub/scans`                                 | hub_clerk | Record a scan (see §2.6) — idempotent |
| POST | `/hub/scans/bulk`                            | hub_clerk | Offline queue flush |
| GET  | `/hub/shipments?status=&age=&cursor=`        | hub_clerk | Shipments currently at hub |
| GET  | `/hub/shipments/{awb_no}`                    | hub_clerk | Detail + legs + scans |
| POST | `/hub/manifests`                             | hub_supervisor | Create line-haul manifest |
| POST | `/hub/manifests/{id}/add-awb`                | hub_supervisor | Attach AWBs |
| POST | `/hub/manifests/{id}/dispatch`               | hub_supervisor | Seal + dispatch (driver, seal_no) |
| POST | `/hub/manifests/{id}/receive`                | hub_supervisor | Inbound scan of full manifest |
| POST | `/hub/manifests/{id}/reconcile`              | hub_supervisor | Mark reconciled (mismatches → exceptions) |
| POST | `/hub/shipments/{awb_no}/exception`          | hub_clerk | File an exception (damaged/missing/address) |
| POST | `/hub/shipments/{awb_no}/handover`           | hub_clerk | Hand to last-mile driver |
| GET  | `/hub/kpis?range=`                           | hub_supervisor | In/out, aging, SLA-breach counts |
| POST | `/hub/cod/close-driver-bag/{driver_id}`      | hub_finance | Close driver COD bag → ledger post |
| POST | `/hub/cod/deposit`                           | hub_finance | Record bank deposit of hub float |
| GET  | `/hub/cod/float`                             | hub_finance | Current hub cash float |

### 1.8 Courier (Rider-side tracking)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/courier/quote`                             | Bearer | Quote an inter-city shipment |
| POST | `/courier/shipments`                         | Bearer | Book courier (non-merchant rider) |
| GET  | `/courier/shipments/{awb_no}`                | Bearer | Current status + scan timeline |
| GET  | `/courier/track/{awb_no}`                    | Public (rate-limited) | Public tracking by AWB (limited fields) |
| POST | `/courier/shipments/{awb_no}/cancel`         | Bearer | Cancel (pre-pickup only) |

### 1.9 Merchant (legacy food use cases — superseded by 1.5)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET  | `/merchant/stores/{id}/orders?status=`       | Merchant | Deprecated: use `/restaurant/outlets/{id}/orders` |
| POST | `/merchant/orders/{id}/accept`               | Merchant | Deprecated |
| POST | `/merchant/orders/{id}/reject`               | Merchant | Deprecated |
| POST | `/merchant/orders/{id}/ready`                | Merchant | Deprecated |
| PATCH| `/merchant/menu/items/{id}`                  | Merchant | Deprecated |
| POST | `/merchant/menu/items`                       | Merchant | Deprecated |

### 1.6 Payments

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/payments/methods`                  | Bearer | Add payment method (tokenized) |
| GET  | `/payments/methods`                  | Bearer | List saved methods |
| DELETE | `/payments/methods/{id}`           | Bearer | Remove method |
| POST | `/payments/intents`                  | Bearer | Create payment intent |
| POST | `/payments/intents/{id}/confirm`     | Bearer | Confirm payment |
| POST | `/payments/webhooks/{provider}`      | Webhook sig | Provider callbacks |
| POST | `/wallet/topup`                      | Bearer | Top-up wallet |
| GET  | `/wallet`                            | Bearer | Wallet balance + txns |

### 1.7 Admin

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET  | `/admin/kyc/queue`                 | Admin | Pending KYC |
| POST | `/admin/kyc/{id}/approve`          | Admin | Approve |
| POST | `/admin/kyc/{id}/reject`           | Admin | Reject |
| GET  | `/admin/ops/live-map?city=`        | Admin | Snapshot of active trips/drivers |
| POST | `/admin/pricing/surge`             | Admin | Update surge config |
| POST | `/admin/users/{id}/suspend`        | Admin | Suspend account |

---

## 2. Critical Endpoints — Detailed Contracts

### 2.1 Ride Estimate

**`POST /rides/estimate`**

Request:
```json
{
  "pickup":  { "lat": 23.8103, "lng": 90.4125 },
  "dropoff": { "lat": 23.7806, "lng": 90.4193 },
  "vehicle_types": ["bike","car"],
  "promo_code": "NEW20"
}
```

Response `200`:
```json
{
  "request_id": "est_01HZ...",
  "estimates": [
    {
      "vehicle_type": "bike",
      "eta_pickup_s": 180,
      "distance_m": 3600,
      "duration_s": 780,
      "fare": { "amount": 140.00, "currency": "BDT",
                "breakdown": {"base":40,"per_km":80,"time":20}, "surge_x": 1.0 },
      "discount": 20.00
    },
    { "vehicle_type": "car", "eta_pickup_s": 240, "fare": { "amount": 260.00, "currency": "BDT","surge_x": 1.2 } }
  ],
  "expires_at": "2026-04-21T10:05:00Z"
}
```

### 2.2 Request a Ride

**`POST /rides`** — idempotent

Headers: `Idempotency-Key: <uuid>`

Request:
```json
{
  "estimate_id": "est_01HZ...",
  "vehicle_type": "car",
  "pickup":  { "lat": 23.8103, "lng": 90.4125, "address":"Banani, Dhaka" },
  "dropoff": { "lat": 23.7806, "lng": 90.4193, "address":"Gulshan, Dhaka" },
  "payment_method_id": "pm_01HZ...",
  "notes": "Second gate"
}
```

Response `202`:
```json
{
  "trip_id": "trp_01HZ...",
  "status": "requested",
  "subscribe": {
    "channel": "trip.trp_01HZ...",
    "ws_url":  "wss://rt.superapp.example/v1/ws"
  }
}
```

Errors: `400` validation, `402` payment_required, `409` active_trip_exists, `429` rate_limited.

### 2.3 Food Order Placement

**`POST /food/orders`** — idempotent

Request:
```json
{
  "store_id": "str_01HZ...",
  "items": [
    { "catalog_item_id":"itm_01HZ...","qty":2,
      "modifiers":{"Spice":"hot","Add-ons":["egg"]} }
  ],
  "delivery_address_id": "adr_01HZ...",
  "payment_method_id":   "pm_01HZ...",
  "promo_code": "FOOD10",
  "notes": "No onion"
}
```

Response `201`:
```json
{
  "order_id": "ord_01HZ...",
  "status":   "created",
  "totals":   {"subtotal":640,"delivery_fee":50,"discount":64,"total":626,"currency":"BDT"},
  "eta_delivery_s": 2100
}
```

### 2.4 Driver Accepts Offer

**`POST /driver/offers/{offer_id}/accept`**

Response `200`:
```json
{
  "trip_id": "trp_01HZ...",
  "pickup":  { "lat":23.81, "lng":90.41, "address":"..." },
  "dropoff": { "lat":23.78, "lng":90.42 },
  "customer": { "name":"Rahim", "phone_masked":"+8801XXXXXX123" },
  "navigation_url": "geo:23.81,90.41"
}
```

### 2.5 Payment Intent Confirm

**`POST /payments/intents/{id}/confirm`**

Response `200`:
```json
{
  "payment_id":"pay_01HZ...",
  "status":"captured",
  "amount":626.00,
  "currency":"BDT",
  "provider":"bkash",
  "captured_at":"2026-04-21T10:12:03Z"
}
```

### 2.6 Courier Booking (Merchant)

**`POST /merchant/shipments`** — idempotent

Headers: `Idempotency-Key`, `X-API-Key` (merchant server-to-server) or Bearer.

Request:
```json
{
  "service_tier": "express",
  "sender": {
    "name": "ACME Shop",
    "phone": "+8801XXXXXXXX",
    "address": "House 12, Road 7, Banani, Dhaka",
    "origin_hub_code": "DAC01"
  },
  "recipient": {
    "name": "Karim Uddin",
    "phone": "+8801YYYYYYYY",
    "address": "Lalkhan Bazar, Chattogram",
    "dest_hub_code": "CTG02"
  },
  "parcel": { "weight_kg": 1.2, "declared_value": 1500 },
  "cod": { "enabled": true, "amount": 1500, "currency": "BDT" },
  "reference": "ORD-98213"
}
```

Response `201`:
```json
{
  "shipment_id": "shp_01HZ...",
  "awb_no": "SA026JK8P41",
  "status": "created",
  "sla_deadline": "2026-04-23T18:00:00Z",
  "price": { "amount": 120.00, "currency": "BDT" },
  "label_url": "https://api.superapp.example/v1/merchant/shipments/SA026JK8P41/label"
}
```

### 2.7 Hub Scan (idempotent)

**`POST /hub/scans`**

Request:
```json
{
  "awb_no": "SA026JK8P41",
  "scan_type": "hub_inbound",
  "hub_id": "hub_01HZ...",
  "geo": { "lat": 22.3569, "lng": 91.7832 },
  "notes": "Bag #17",
  "client_scan_id": "local-uuid-for-offline-queue"
}
```

Response `200`:
```json
{
  "scan_id": "scn_01HZ...",
  "shipment_status": "at_dest_hub",
  "next_expected_scan": "out_for_delivery"
}
```

Idempotency: server dedupes on `(awb_no, hub_id, scan_type, minute-bucket)` plus `client_scan_id`.

### 2.8 Hub Manifest Dispatch

**`POST /hub/manifests/{id}/dispatch`**

Request:
```json
{
  "driver_id": "drv_01HZ...",
  "vehicle_id": "veh_01HZ...",
  "seal_no": "SEAL-334421"
}
```

Response `200`:
```json
{
  "manifest_id":"mft_01HZ...",
  "manifest_no":"MFT-20260421-007",
  "dest_hub_code":"CTG02",
  "total_awb_count": 182,
  "total_weight_kg": 240.6,
  "status":"dispatched",
  "dispatched_at":"2026-04-21T20:15:00Z"
}
```

### 2.9 Public Track (rate-limited)

**`GET /courier/track/{awb_no}`** — public, 20 req/min/IP

Response `200`:
```json
{
  "awb_no": "SA026JK8P41",
  "status": "in_transit",
  "eta": "2026-04-23T14:00:00Z",
  "timeline": [
    {"type":"pickup","at":"2026-04-21T12:10:00Z","city":"Dhaka"},
    {"type":"hub_inbound","at":"2026-04-21T14:20:00Z","hub":"DAC01"},
    {"type":"manifest_out","at":"2026-04-21T20:15:00Z","to":"CTG02"}
  ]
}
```

Only non-PII fields returned; sender/recipient names masked.

---

## 3. WebSocket API (Realtime Gateway)

**URL:** `wss://rt.superapp.example/v1/ws?token=<JWT>`

- TLS only; JWT passed as query or `Sec-WebSocket-Protocol: bearer,<jwt>`.
- Heartbeat: client sends `ping` every 20 s; server replies `pong`. Server closes idle > 45 s.
- All frames JSON with `type`, `ts`, `payload`.

### 3.1 Subscription Frames

Client → Server:
```json
{ "type":"subscribe", "channels":["trip.trp_01HZ...","driver.me"] }
{ "type":"unsubscribe", "channels":["trip.trp_01HZ..."] }
```

Server → Client on accept:
```json
{ "type":"subscribed", "channels":["trip.trp_01HZ..."], "ts":"..." }
```

### 3.2 Driver → Server: Location Update

Channel: `driver.location`

```json
{
  "type": "location",
  "ts":   "2026-04-21T10:12:05.120Z",
  "payload": {
    "lat": 23.8111, "lng": 90.4130,
    "speed_mps": 7.2, "heading": 87, "accuracy_m": 6,
    "trip_id": "trp_01HZ..."      // null if idle
  }
}
```

Server rate-limits to 1 msg / 2 s per driver; excess is dropped with `{type:"throttled"}`.

### 3.3 Server → Customer: Trip Updates

Channel: `trip.{trip_id}`

```json
{ "type":"trip.matched",
  "payload": {
     "trip_id":"trp_01HZ...",
     "driver":{"name":"Karim","rating":4.9,"vehicle":{"model":"Toyota Axio","plate":"DHA-1234","color":"white"},"phone_masked":"+8801XXX123"},
     "eta_pickup_s": 210
  }}

{ "type":"trip.driver_location",
  "payload": {"lat":23.81,"lng":90.41,"heading":87,"eta_pickup_s":180} }

{ "type":"trip.status",
  "payload": {"status":"started","at":"2026-04-21T10:15:00Z"} }

{ "type":"trip.completed",
  "payload": {"fare":260.00,"distance_m":3600,"duration_s":900,"payment_id":"pay_..."} }
```

### 3.4 Server → Driver: Offer

Channel: `driver.me`
```json
{ "type":"offer",
  "payload":{
    "offer_id":"ofr_01HZ...",
    "trip_id":"trp_01HZ...",
    "expires_in_s": 8,
    "pickup":{"lat":23.81,"lng":90.41,"address":"Banani"},
    "dropoff":{"lat":23.78,"lng":90.42},
    "est_fare":260.00,"distance_m":3600
  }}
```

### 3.5 Chat

Channel: `chat.{conversation_id}`
```json
{ "type":"message", "payload":{"sender_id":"usr_...","body":"I'm at gate 2","ts":"..."} }
```

---

## 4. Webhooks (Outbound to Merchants / Partners)

| Event | Payload keys |
|-------|--------------|
| `order.created` | order_id, store_id, items[], total |
| `order.accepted_by_store` | order_id, eta_ready_s |
| `order.picked_up` | order_id, driver_id |
| `order.delivered` | order_id, delivered_at |
| `payment.captured` | payment_id, ref_type, ref_id, amount |

All webhooks HMAC-signed: `X-Signature: t=...,v1=hex(hmac_sha256(secret, t+"."+body))`.

---

## 5. Rate Limits (defaults, per user)

| Scope | Limit |
|-------|-------|
| `/auth/otp/request` | 3/min/phone, 10/day/phone |
| `/rides/estimate`   | 30/min |
| `/rides` (POST)     | 5/min, 20/hr |
| `/food/search`      | 60/min |
| WS frames in        | 1/2 s per driver location |

---

## 6. Versioning & Deprecation

- URI version `/v1`, additive changes only within a major version.
- Breaking changes → `/v2`, with 6-month sunset on `/v1`, communicated via `Deprecation` and `Sunset` headers.
