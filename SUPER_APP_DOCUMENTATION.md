# 🚀 Super App — Ride · Food · Parcel (City) · Courier (Country)

## Complete System Documentation — Six Panels

**Inspired by:** Uber · Pathao · Grab · Rapido · Lyft · Delhivery

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Six System Panels](#2-six-system-panels)
3. [Services & Vehicle Types](#3-services--vehicle-types)
4. Business Logic & Features
   - [🧑 Rider Panel](#4-rider-panel-features)
   - [🚗 Driver Panel](#5-driver-panel-features)
   - [🍴 Restaurant Panel](#6-restaurant-panel-features)
   - [🏪 Merchant Panel](#7-merchant-panel-features)
   - [🏭 Hub Panel](#8-hub-panel-features)
   - [👨‍💼 Admin Panel](#9-admin-panel-features)
5. [Complete API Documentation (per panel)](#10-complete-api-documentation)
6. [Real-time & WebSocket Contracts](#11-real-time--websocket-contracts)
7. [Core Workflows](#12-core-workflows)
8. [Courier Country-wide Pipeline](#13-courier-country-wide-pipeline)
9. [Payment · COD · Ledger](#14-payment--cod--ledger)
10. [Security, Safety & Compliance](#15-security-safety--compliance)
11. [Non-Functional Requirements](#16-non-functional-requirements)

---

## 1. Project Overview

A single platform connecting **six actors** — Riders, Drivers, Restaurants, Merchants, Hub staff, and Admins — to deliver four services: **intra-city rides**, **food delivery**, **intra-city parcels**, and **country-wide courier** with hub-based multi-leg routing.

### Core flows

```
Ride     : Rider → [pricing + dispatch] → Driver → Track → Complete → Pay → Rate
Food     : Rider → Restaurant (accept → prep → ready) → Driver (pickup → deliver) → Pay
Parcel   : Rider/Merchant → Driver (pickup → drop) → Pay
Courier  : Rider/Merchant → Driver(FM) → Origin Hub → Sort → Line-haul → Dest Hub → Driver(LM) → Deliver → COD reconciled
```

---

## 2. Six System Panels

| # | Panel | Users | Platform | Purpose |
|---|-------|-------|----------|---------|
| 1 | **🧑 Rider App** | Passengers / Food buyers / Parcel senders | Mobile (iOS, Android) | Book rides, order food, ship parcels/courier, track, pay, rate |
| 2 | **🚗 Driver App** | Drivers (Bike / Auto / Car / Truck) | Mobile (iOS, Android) | Accept jobs, navigate, collect COD, view earnings |
| 3 | **🍴 Restaurant Panel** | Restaurant owner / kitchen | Tablet (KDS) + Web | Menu CRUD, accept orders, prep-time, payouts |
| 4 | **🏪 Merchant Panel** | Shops, e-commerce sellers, bulk shippers | Web + API | Catalog, bulk parcel/courier booking, COD reports, payouts, API keys |
| 5 | **🏭 Hub Panel** | Hub clerks, supervisors, finance | Tablet + Web (scanner) | Scan-in/out, sort, manifest, line-haul dispatch, COD float |
| 6 | **👨‍💼 Admin Panel** | Operations, Finance, Safety, Support | Web | KYC, fraud, pricing, disputes, analytics, RBAC |

### Panel architecture

```
┌───────────────────────────────────────────────────────────────────────────┐
│                         SUPER APP PLATFORM                                │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  RIDER   DRIVER   RESTAURANT   MERCHANT    HUB         ADMIN              │
│  (app)   (app)    (KDS+web)    (web+API)   (tablet)    (web)              │
│    │        │          │            │         │          │                │
│    └────────┴──────────┴────────────┴─────────┴──────────┘                │
│                              │                                            │
│                     ┌────────▼─────────┐                                  │
│                     │   API Gateway    │  (auth, rate-limit, routing)     │
│                     └────────┬─────────┘                                  │
│                              │                                            │
│    ┌────────────┬────────────┼────────────┬────────────┬────────────┐    │
│    ▼            ▼            ▼            ▼            ▼            ▼    │
│  bff-     bff-driver    bff-          bff-         bff-hub      bff-     │
│  rider                  restaurant    merchant                   admin    │
│    │            │            │            │            │            │    │
│    └────────────┴────────────┴────── MICROSERVICES ────┴────────────┘    │
│                                                                           │
│  Identity · Ride · Food · Parcel · Courier · Hub · Restaurant · Merchant │
│  Location · Dispatch · Pricing · Payment · Wallet · COD/Remittance       │
│  Notification · Chat · Rating · Fraud · Search · Analytics · Admin       │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Services & Vehicle Types

| Service | Scope | Vehicle(s) | Fulfillment actors |
|---------|-------|------------|--------------------|
| **Ride** | Intra-city | Bike, Auto, Sedan, SUV | Rider ↔ Driver |
| **Food Delivery** | Intra-city | Bike | Rider ↔ Restaurant ↔ Driver |
| **Parcel (City)** | Intra-city, direct | Bike, Car | Rider/Merchant ↔ Driver |
| **Courier (Country)** | Inter-city, multi-leg | Bike (first/last mile) + Truck (line-haul) | Rider/Merchant ↔ Driver(FM) ↔ Hub ↔ Driver(LH) ↔ Hub ↔ Driver(LM) |

---

## 4. 🧑 Rider Panel Features

### 4.1 Authentication & Profile

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Sign up / Login** | Phone OTP + optional social | Unique phone, JWT + refresh token, 5-min access token |
| **Profile** | Name, photo, email, language | Email change requires verification |
| **Saved addresses** | Home, Work, Favorites | Max 10; geocoded; `GEOGRAPHY(POINT)` |
| **Wallet** | In-app balance | Top-up via card/MFS, used in any service |
| **Payment methods** | Card / bKash / Nagad / Wallet / Cash | Tokenized via provider vault (PCI-reduced) |
| **Delete account** | GDPR-compliant | Soft delete, 30-day recovery, blocked if active job |

### 4.2 Ride (intra-city)

| Feature | Description | Logic |
|---------|-------------|-------|
| **Fare estimate** | Distance × rate + time × rate + surge | `base + km*r_km + min*r_min)*surge + booking` |
| **Vehicle choice** | Bike / Auto / Sedan / SUV | Per-city availability |
| **Surge pricing** | Dynamic | Based on demand/supply ratio per zone |
| **Schedule ride** | 15 min – 7 days ahead | Pre-dispatch 10 min before pickup |
| **Live tracking** | WebSocket | ≤ 3 s driver-location interval |
| **Share trip** | Read-only live link | Expires at trip end |
| **SOS** | One-tap emergency | Dedicated safety channel + on-call contacts |
| **In-trip chat / masked call** | PII-masked number proxy | Expires 30 min after trip |
| **Rate & tip** | 1–5 stars + optional tip | Affects driver ranking; tip flows to ledger |

### 4.3 Food Delivery

| Feature | Description | Logic |
|---------|-------------|-------|
| **Discover restaurants** | Nearby list + search | Geo-filter + Elasticsearch |
| **Menu browse** | Items, modifiers, images | MongoDB + CDN |
| **Cart & checkout** | Subtotal + delivery fee + service fee − promo | Cart validated server-side before pay |
| **Live order status** | `created → accepted → preparing → ready → picked_up → delivered` | WebSocket + push |
| **Rate food + driver separately** | Two ratings per order | Aggregated into restaurant & driver scores |

### 4.4 Parcel (City) & Courier (Country)

| Feature | Description | Logic |
|---------|-------------|-------|
| **Send parcel (city)** | Pickup + drop, weight, declared value | Single-driver, no hub |
| **Send courier (country)** | Inter-city shipment | AWB generated, multi-leg |
| **AWB tracking** | Timeline of scans | Public read (rate-limited) |
| **Service tier** | Standard / Express / Same-day | Different SLA & price |
| **COD option** | Collect cash at delivery | Reconciled via ledger |
| **Recipient alerts** | SMS + optional push if app installed | Recipient does not need account |

### 4.5 Settings & Support

| Feature | Logic |
|---------|-------|
| Notification toggles | Order/safety always on; promos optional |
| Multi-language | BN / EN / others |
| Support tickets | Auto-categorized, priority-routed |

---

## 5. 🚗 Driver Panel Features

### 5.1 Onboarding & Documents

| Feature | Logic |
|---------|-------|
| Phone OTP + device-bound session | Device attestation (Play Integrity / App Attest) |
| Upload docs | NID, License, Vehicle RC, Insurance, Photo |
| Vehicle capability profile | Ride / Food / Parcel / Courier-FM / Courier-LH |
| Background check | Third-party, 7-day SLA |
| Bank / MFS account | Micro-deposit verification |
| Training | Mandatory videos before first online |

Documents required:
```
├── Driver's License (valid)
├── NID / Passport
├── Vehicle RC + Insurance
├── Photo (passport size)
├── Vehicle photos (4 angles)
├── Permit (commercial if truck)
└── Police verification (optional)
```

### 5.2 Availability & Job offers

| Feature | Logic |
|---------|-------|
| Online/offline toggle | Updates Redis geo-index & Kafka event |
| Heatmap of demand | Surge zones, idle-time suggestion |
| Offer popup | 8-sec timeout, accept/reject |
| Acceptance-rate rules | <85% warning, <70% priority reduced, <50% review |
| Auto-accept mode | Optional for high-volume drivers |

### 5.3 Ride / Food / Parcel flow

| Step | Action | Backend |
|------|--------|---------|
| Accept | `POST /driver/offers/{id}/accept` | Temporal workflow transitions |
| Navigate | Deep-link to Google/Apple Maps | — |
| Arrived | Marks arrival → notifies customer | Wait timer starts after 5 min free |
| Start | Fare meter + location stream | WebSocket |
| End | Completes trip → payment capture | Ledger post + rating prompt |
| Cash | Confirms cash received | Ledger: cash → driver float account |

### 5.4 Courier operations

| Feature | Logic |
|---------|-------|
| **First-mile pickup** | Scan parcel, confirm weight | Starts AWB lifecycle |
| **Line-haul truck driver** | Manifest scan, seal number, GPS trip | Offline-tolerant, long battery |
| **Last-mile delivery** | OTP/signature proof, photo | COD collection if applicable |
| **Reattempts & RTO** | Configurable (2–3 tries) | Exception codes recorded |

### 5.5 Earnings & Payouts

| Feature | Logic |
|---------|-------|
| Daily / Weekly / Monthly summary | Aggregated from ledger |
| Per-trip breakdown | Base − commission + tip + incentive |
| Weekly auto payout | Every Monday for previous week |
| Instant payout | 1–2% fee |
| Tax statement | Monthly + yearly downloads |

Commission:
```
Driver = Fare − Commission(20–25%) + Tip + Bonus
Surge:   Driver receives 70–80% of surge amount
```

### 5.6 Ratings & Performance

| Range | Status |
|-------|--------|
| 4.8 – 5.0 | Excellent — priority |
| 4.5 – 4.8 | Good — normal |
| 4.2 – 4.5 | Warning |
| 4.0 – 4.2 | Mandatory training |
| < 4.0 | Review / suspend |

---

## 6. 🍴 Restaurant Panel Features

### 6.1 Onboarding

| Feature | Logic |
|---------|-------|
| Owner signup + KYC | Trade license, FSSAI/food permit, tax ID (encrypted) |
| Outlet(s) creation | One brand → N outlets |
| Commission configured by admin | Default 20% per order |
| Bank account | Micro-deposit verified |

### 6.2 Menu Management

| Feature | Logic |
|---------|-------|
| Items + modifiers + combos | MongoDB documents |
| Price, images, tags | CDN-served images |
| Availability toggle | Instant; invalidates search index |
| Opening hours per day | `restaurant_hours` table |
| Multi-outlet sync | Master menu → selective outlet overrides |

### 6.3 Order handling (KDS)

| Feature | Logic |
|---------|-------|
| Incoming order alert | Sound + vibration, 60-sec accept window |
| Accept with prep-time | e.g. "25 min" — updates customer ETA |
| Reject with reason | Items out / closed / too busy |
| Mark "Ready" | Notifies dispatch — driver assigned if not yet |
| Auto-print receipt | ESC/POS thermal printer |
| Order history | Filter by status, date, dispute |

### 6.4 Analytics & Payouts

| Report | Granularity |
|--------|-------------|
| Top-selling items | Day / week / month |
| Peak hours | Hourly heatmap |
| Rejection reasons | Weekly trend |
| Average prep time | Rolling 30-day |
| Payout statements | Daily + weekly PDF |

### 6.5 Promotions

| Feature | Logic |
|---------|-------|
| Self-service discounts | % or flat, time-bounded |
| Combo bundles | Cross-item pricing |
| Happy-hour schedule | Auto-activate in date range |

---

## 7. 🏪 Merchant Panel Features

Merchant = non-food seller (retailer, e-commerce, bulk shipper).

### 7.1 Onboarding

| Feature | Logic |
|---------|-------|
| KYC (trade license, tax ID, GSTIN) | Encrypted at rest |
| Warehouse / pickup address book | Multiple allowed |
| Rate contract | Default rate card or negotiated slab pricing |
| API keys | Scoped (create-shipment / full); IP allow-list; rotatable |

### 7.2 Shipments (Parcel & Courier)

| Feature | Logic |
|---------|-------|
| **Single booking** | `POST /merchant/shipments` |
| **Bulk booking** | CSV/JSON, async batch job, returns `batch_id` |
| **Rate lookup** | Origin → Dest, kg, tier |
| **Label printing** | A5/A6 PDF, QR-encoded AWB |
| **Pickup scheduling** | Single or recurring |
| **Cancel** | Only before first-mile pickup |
| **Track** | By AWB or reference |

### 7.3 COD & Payouts

| Feature | Logic |
|---------|-------|
| **COD remittance report** | Per-day, per-shipment cash collected |
| **Weekly payout** | Σ(delivered COD) − commission − adjustments |
| **Invoice download** | GST / tax-compliant PDF |
| **Disputes** | Raise claim on lost/damaged; SLA response 48 h |

### 7.4 Catalog (optional retail storefront)

If merchant operates a consumer-facing storefront:

| Feature | Logic |
|---------|-------|
| Product CRUD | SKU, price, stock |
| Orders | Captured like food orders but with retail status flow |
| Customer returns | RTO handling + refund via ledger |

### 7.5 Webhooks & Integrations

Events pushed to merchant's registered URL (HMAC-signed, replay-protected):

| Event | Payload |
|-------|---------|
| `shipment.created` | awb_no, price, sla |
| `shipment.picked_up` | awb_no, driver, ts |
| `shipment.in_transit` | awb_no, current_hub |
| `shipment.out_for_delivery` | awb_no, driver |
| `shipment.delivered` | awb_no, cod_amount?, ts |
| `shipment.exception` | awb_no, code, notes |
| `shipment.rto` | awb_no, reason |

---

## 8. 🏭 Hub Panel Features

Hub = physical courier sorting facility. Panel runs on tablet with barcode scanner + a web console for supervisors.

### 8.1 Staff Roles (RBAC)

| Role | Powers |
|------|--------|
| `hub_clerk` | Scan, handover, file exception |
| `hub_supervisor` | Create manifest, dispatch, receive, reconcile, view KPIs |
| `hub_finance` | Close driver COD bag, record bank deposit (requires **MFA + device binding**) |
| `hub_manager` | All above + staff roster, capacity config |

### 8.2 Inbound & Sort

| Feature | Logic |
|---------|-------|
| **Scan-in** | Driver (first-mile) hands over parcels → each AWB scanned → `shipment_scans.scan_type='hub_inbound'` |
| **Sort** | Label's sort-code directs to correct bin/cage for destination hub |
| **Mark sorted** | Batch confirm — transitions shipment status |

### 8.3 Line-haul manifest

| Step | Action |
|------|--------|
| 1 | Supervisor creates manifest: origin hub, dest hub, vehicle, driver |
| 2 | Attaches AWBs (scan or bulk-select by dest) |
| 3 | Seal number recorded, manifest dispatched |
| 4 | Driver drives truck, GPS streamed |
| 5 | On arrival at dest hub: inbound scan of manifest |
| 6 | Each AWB individually verified; mismatches → exception |
| 7 | Manifest reconciled |

### 8.4 Handover to Last-mile

| Feature | Logic |
|---------|-------|
| Assign last-mile rider | System suggests based on coverage zone |
| Scan handover | Driver accepts bag with scan — custody transfers |
| Failed delivery | Scan back into hub with exception code |

### 8.5 Exceptions

Standard codes: `damaged`, `missing`, `address_wrong`, `recipient_unavailable`, `refused`, `weather`, `rto_requested`. Each exception attaches photo proof to S3.

### 8.6 COD at Hub

| Step | Action | Ledger |
|------|--------|--------|
| 1 | Last-mile driver returns with collected cash | — |
| 2 | `hub_finance` closes driver bag | Debit driver float, credit hub float |
| 3 | Hub deposits to bank | Debit hub float, credit platform clearing |
| 4 | Finance reconciles deposit vs deposits slip | Finalizes daily close |
| 5 | Merchant weekly payout | Debit clearing, credit merchant account |

### 8.7 KPIs

| Metric | Target |
|--------|--------|
| Scan latency | p95 < 500 ms |
| Inbound-to-sort time | < 30 min |
| Sort accuracy | > 99.5% |
| Manifest dispatch success | > 99.9% |
| COD reconciliation drift | < 0.1% daily |

### 8.8 Offline mode

Tablet app stores scans in IndexedDB; flushes to `/hub/scans/bulk` on reconnect. Server dedupes on `(awb_no, hub_id, scan_type, client_scan_id)` to tolerate replay.

---

## 9. 👨‍💼 Admin Panel Features

### 9.1 Dashboard

| Widget | Detail |
|--------|--------|
| Live ops map | Active drivers, trips, shipments |
| KPIs | Orders today, revenue, active users, acceptance rate |
| Alerts | Fraud signals, SLA breaches, hub capacity, SOS events |
| Funnels | Signup → first order, driver onboarding |

### 9.2 KYC approval queues (per panel)

- Rider: selfie + phone re-verification (rare, on suspect accounts)
- Driver: license, RC, insurance, background check
- Restaurant: trade license, food permit, tax ID
- Merchant: trade license, tax ID, GSTIN
- Hub staff: employment letter, photo, MFA enrollment

### 9.3 Pricing & Rate config

| Config | Scope |
|--------|-------|
| Base fare / per-km / per-min | City × vehicle type |
| Surge levels & caps | City × zone |
| Courier lane rates (slab) | Origin-hub × dest-hub |
| Commission % | Per vertical + per contract |
| Promo codes | Global / segmented |

### 9.4 Disputes & Refunds

- Unified inbox of tickets across panels
- Refund flows use idempotent ledger reversal
- 4-eyes approval for refunds above threshold
- Full audit trail in `audit_log`

### 9.5 Fraud & Risk

| Signal | Action |
|--------|--------|
| Rapid sign-ups same device | Block device fingerprint |
| Promo abuse | Per-user cap enforced at `promo_redemptions` |
| GPS spoofing | Mobility anomaly score → soft block |
| COD mismatch | Auto dispute + driver review |
| Multiple cancels by same rider | Risk score ↑ |

### 9.6 Staff management

- Create admin users with RBAC roles (Super, City, Finance, Support, Ops, Safety)
- Mandatory MFA (WebAuthn or TOTP)
- IP allow-list for production access
- Activity audit log (append-only)

### 9.7 Reports & exports

| Report | Format |
|--------|--------|
| Revenue (daily/weekly/monthly) | CSV / PDF |
| Driver earnings & payouts | CSV |
| Restaurant/merchant payouts | CSV |
| Courier SLA breach | CSV |
| Tax/GST reports | PDF |

---

## 10. Complete API Documentation

**Base URL:** `https://api.superapp.example/v1`
**Auth:** `Authorization: Bearer <JWT>` unless noted.
**Idempotency:** Mutating requests SHOULD pass `Idempotency-Key: <uuid>`.
**Errors:** RFC 7807 `application/problem+json`.
**Tracing:** `X-Request-Id`, `traceparent` propagated.

### 10.1 🧑 Rider APIs

#### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/rider/otp/request` | Send OTP |
| POST | `/auth/rider/otp/verify` | Verify OTP → tokens |
| POST | `/auth/rider/social` | Google/Apple/Facebook |
| POST | `/auth/refresh` | Rotate access token |
| POST | `/auth/logout` | Revoke session |

#### Profile
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/rider/profile` | Get profile |
| PATCH | `/rider/profile` | Update |
| POST | `/rider/profile/photo` | Upload photo |
| DELETE | `/rider/profile` | Delete (soft) |

#### Places
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/rider/places` | List |
| POST | `/rider/places` | Add |
| PATCH | `/rider/places/{id}` | Update |
| DELETE | `/rider/places/{id}` | Delete |

#### Ride
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/rides/estimate` | Fare + ETA quote |
| POST | `/rides` | Request ride (idempotent) |
| GET | `/rides/{id}` | Detail |
| PATCH | `/rides/{id}/destination` | Change drop |
| POST | `/rides/{id}/cancel` | Cancel |
| POST | `/rides/{id}/rate` | Rate driver |
| POST | `/rides/{id}/tip` | Add tip |
| GET | `/rides/{id}/share-link` | Shareable tracking URL |
| GET | `/rides/history?cursor=` | Paginated history |

#### Food
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/food/stores?lat=&lng=` | Nearby restaurants |
| GET | `/food/stores/{id}` | Store detail |
| GET | `/food/stores/{id}/menu` | Menu |
| GET | `/food/search?q=` | Search |
| POST | `/food/cart/validate` | Pre-checkout validation |
| POST | `/food/orders` | Place order (idempotent) |
| GET | `/food/orders/{id}` | Order status |
| POST | `/food/orders/{id}/cancel` | Cancel if allowed |
| POST | `/food/orders/{id}/rate` | Rate food + driver |

#### Parcel & Courier
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/parcels/quote` | Intra-city parcel quote |
| POST | `/parcels` | Book parcel |
| GET | `/parcels/{id}` | Status |
| POST | `/courier/quote` | Inter-city courier quote |
| POST | `/courier/shipments` | Book courier |
| GET | `/courier/shipments/{awb_no}` | Full detail + scans |
| POST | `/courier/shipments/{awb_no}/cancel` | Cancel pre-pickup |
| GET | `/courier/track/{awb_no}` | **Public** tracking (rate-limited, masked) |

#### Payments & Wallet
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/rider/payment-methods` | List |
| POST | `/rider/payment-methods` | Add (tokenized) |
| DELETE | `/rider/payment-methods/{id}` | Remove |
| POST | `/payments/intents` | Create intent |
| POST | `/payments/intents/{id}/confirm` | Confirm |
| GET | `/wallet` | Balance + transactions |
| POST | `/wallet/topup` | Top-up |

#### Promo & Support
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/promo/validate` | Validate code |
| POST | `/promo/apply` | Apply to current cart |
| POST | `/support/tickets` | Create ticket |
| GET | `/support/tickets` | List my tickets |

### 10.2 🚗 Driver APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/driver/otp/request` | OTP |
| POST | `/auth/driver/otp/verify` | Verify + device bind |
| POST | `/driver/register` | Registration |
| POST | `/driver/documents` | Upload docs |
| GET | `/driver/documents` | Status |
| GET | `/driver/profile` | Profile |
| PATCH | `/driver/profile` | Update |
| GET | `/driver/vehicle` | Vehicle |
| PATCH | `/driver/vehicle` | Update vehicle |
| POST | `/driver/bank-account` | Bank/MFS account |
| POST | `/driver/status` | Online/offline + capability |
| GET | `/driver/heatmap` | Demand heatmap |
| GET | `/driver/offers/current` | Current offer if any |
| POST | `/driver/offers/{id}/accept` | Accept |
| POST | `/driver/offers/{id}/reject` | Reject |
| POST | `/driver/trips/{id}/arrived` | Arrived at pickup |
| POST | `/driver/trips/{id}/start` | Start trip |
| POST | `/driver/trips/{id}/complete` | Complete |
| POST | `/driver/trips/{id}/cancel` | Cancel |
| POST | `/driver/trips/{id}/collect-cash` | Confirm cash |
| POST | `/driver/courier/first-mile/{awb}/pickup` | Courier pickup scan |
| POST | `/driver/courier/last-mile/{awb}/deliver` | Last-mile deliver (OTP/photo) |
| GET | `/driver/earnings?range=` | Summary |
| GET | `/driver/earnings/trips` | Per-trip |
| POST | `/driver/payouts` | Instant payout |
| GET | `/driver/payouts` | History |
| GET | `/driver/ratings` | Breakdown |
| GET | `/driver/performance` | Metrics |
| GET | `/driver/incentives` | Active quests |

### 10.3 🍴 Restaurant APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/restaurant/login` | Email + password + 2FA |
| GET | `/restaurant/outlets` | My outlets |
| PATCH | `/restaurant/outlets/{id}/hours` | Opening hours |
| POST | `/restaurant/outlets/{id}/toggle-open` | Open/close now |
| GET | `/restaurant/outlets/{id}/orders?status=` | Incoming |
| POST | `/restaurant/orders/{id}/accept` | Accept with prep_time_min |
| POST | `/restaurant/orders/{id}/reject` | Reject + reason |
| POST | `/restaurant/orders/{id}/ready` | Ready for pickup |
| GET | `/restaurant/menu/items` | List items |
| POST | `/restaurant/menu/items` | Create |
| PATCH | `/restaurant/menu/items/{id}` | Edit / toggle |
| DELETE | `/restaurant/menu/items/{id}` | Remove |
| POST | `/restaurant/promos` | Create promo |
| GET | `/restaurant/analytics/summary?range=` | KPIs |
| GET | `/restaurant/payouts?range=` | Payouts |

### 10.4 🏪 Merchant APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/merchant/login` | Login + 2FA |
| GET | `/merchant/account` | Profile |
| POST | `/merchant/api-keys` | Issue API key (secret shown once) |
| DELETE | `/merchant/api-keys/{id}` | Revoke |
| POST | `/merchant/webhooks` | Register URL + secret |
| GET | `/merchant/rates?origin=&dest=&kg=&tier=` | Rate lookup |
| POST | `/merchant/shipments` | Book single shipment (idempotent) |
| POST | `/merchant/shipments/bulk` | **Async** batch (CSV/JSON) |
| GET | `/merchant/shipments/bulk/{batch_id}` | Batch status |
| GET | `/merchant/shipments?status=&from=&to=&cursor=` | List |
| GET | `/merchant/shipments/{awb_no}` | Detail |
| POST | `/merchant/shipments/{awb_no}/cancel` | Cancel pre-pickup |
| GET | `/merchant/shipments/{awb_no}/label` | PDF label |
| POST | `/merchant/shipments/{awb_no}/request-rto` | Return to origin |
| POST | `/merchant/pickups` | Schedule pickup |
| GET | `/merchant/cod/remittance?range=` | COD report |
| GET | `/merchant/payouts?range=` | Payout statements |
| GET | `/merchant/catalog/items` | Retail catalog (optional) |
| POST | `/merchant/catalog/items` | Add item |

### 10.5 🏭 Hub APIs

All endpoints require `hub_staff` role scoped to a specific `hub_id`. Finance actions require **MFA + device binding**.

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| POST | `/auth/hub-staff/login` | Any | Email + MFA |
| GET | `/hub/shipments?status=&cursor=` | clerk | At-hub shipments |
| GET | `/hub/shipments/{awb_no}` | clerk | Detail |
| POST | `/hub/scans` | clerk | Single scan (idempotent) |
| POST | `/hub/scans/bulk` | clerk | Offline queue flush |
| POST | `/hub/shipments/{awb_no}/exception` | clerk | File exception |
| POST | `/hub/shipments/{awb_no}/handover` | clerk | Hand to last-mile |
| POST | `/hub/shipments/{awb_no}/rto` | supervisor | Initiate RTO |
| POST | `/hub/manifests` | supervisor | Create manifest |
| POST | `/hub/manifests/{id}/add-awb` | supervisor | Attach AWBs |
| POST | `/hub/manifests/{id}/dispatch` | supervisor | Seal + dispatch |
| POST | `/hub/manifests/{id}/receive` | supervisor | Inbound scan |
| POST | `/hub/manifests/{id}/reconcile` | supervisor | Reconcile |
| GET | `/hub/kpis?range=` | supervisor | Hub KPIs |
| POST | `/hub/cod/close-driver-bag/{driver_id}` | finance | Close COD bag |
| POST | `/hub/cod/deposit` | finance | Record bank deposit |
| GET | `/hub/cod/float` | finance | Current float |
| GET | `/hub/staff` | manager | Roster |

### 10.6 👨‍💼 Admin APIs

| Area | Endpoints |
|------|-----------|
| Auth | `POST /admin/auth/login`, `/admin/auth/2fa/verify`, `/admin/auth/logout` |
| Dashboard | `GET /admin/dashboard/{stats|live|revenue|charts}` |
| Riders | `GET /admin/riders`, `/admin/riders/{id}`, `PUT /{id}/block|unblock`, `POST /{id}/wallet`, `POST /{id}/refund` |
| Drivers | `GET /admin/drivers`, `/pending`, `/{id}`, `PUT /{id}/approve|reject|suspend|activate`, `/documents/verify` |
| Restaurants | `GET /admin/restaurants`, `/pending`, `PUT /{id}/approve|suspend`, `/commission` |
| Merchants | `GET /admin/merchants`, `/pending`, `PUT /{id}/approve|suspend`, `/rate-contract` |
| Hubs | `GET /admin/hubs`, `POST /admin/hubs`, `PUT /admin/hubs/{id}`, `POST /admin/hubs/{id}/staff`, `POST /admin/lanes` |
| Rides / Orders / Shipments | `GET /admin/{rides|orders|shipments}`, `/live`, `/{id}`, `POST /{id}/cancel`, `POST /rides/{id}/assign-driver` |
| Pricing | `GET|PUT /admin/fares`, `/surge`, `/cities`, `/courier-lanes` |
| Promos | CRUD `/admin/promos` + `/usage` |
| Support | CRUD `/admin/tickets` + `/assign`, `/reply`, `/resolve` |
| Fraud | `GET /admin/fraud/signals`, `POST /admin/fraud/rules` |
| Reports | `GET /admin/reports/{rides|revenue|drivers|users|merchants|courier-sla|tax}` |
| Config | `GET|PUT /admin/config/settings`, `/vehicle-types`, `/cities` |
| Staff RBAC | `GET|POST|PATCH|DELETE /admin/staff`, `/admin/staff/roles`, `GET /admin/audit-log` |

### 10.7 Detailed Payload Examples

#### Request ride — `POST /rides`
```json
// Request
{
  "estimate_id": "est_01HZ...",
  "vehicle_type": "car",
  "pickup":  { "lat": 23.8103, "lng": 90.4125, "address": "Banani" },
  "dropoff": { "lat": 23.7806, "lng": 90.4193, "address": "Gulshan" },
  "payment_method_id": "pm_01HZ...",
  "notes": "Second gate"
}

// Response 202
{
  "trip_id": "trp_01HZ...",
  "status": "requested",
  "subscribe": { "channel": "trip.trp_01HZ...", "ws_url": "wss://rt.superapp.example/v1/ws" }
}
```

#### Place food order — `POST /food/orders`
```json
{
  "store_id": "str_01HZ...",
  "items": [
    { "catalog_item_id":"itm_01HZ...", "qty":2,
      "modifiers": { "Spice":"hot", "Add-ons":["egg"] } }
  ],
  "delivery_address_id": "adr_01HZ...",
  "payment_method_id":   "pm_01HZ...",
  "promo_code": "FOOD10"
}
```

#### Book courier — `POST /merchant/shipments`
```json
// Request
{
  "service_tier": "express",
  "sender": {
    "name": "ACME Shop", "phone": "+8801XXXXXXXX",
    "address": "House 12, Road 7, Banani, Dhaka",
    "origin_hub_code": "DAC01"
  },
  "recipient": {
    "name": "Karim Uddin", "phone": "+8801YYYYYYYY",
    "address": "Lalkhan Bazar, Chattogram",
    "dest_hub_code": "CTG02"
  },
  "parcel":    { "weight_kg": 1.2, "declared_value": 1500 },
  "cod":       { "enabled": true, "amount": 1500, "currency": "BDT" },
  "reference": "ORD-98213"
}

// Response 201
{
  "shipment_id": "shp_01HZ...",
  "awb_no":      "SA026JK8P41",
  "status":      "created",
  "sla_deadline":"2026-04-23T18:00:00Z",
  "price":       { "amount": 120.00, "currency": "BDT" },
  "label_url":   "https://.../label"
}
```

#### Hub scan — `POST /hub/scans`
```json
// Request
{
  "awb_no":"SA026JK8P41",
  "scan_type":"hub_inbound",
  "hub_id":"hub_01HZ...",
  "geo":{"lat":22.3569,"lng":91.7832},
  "notes":"Bag #17",
  "client_scan_id":"offline-uuid"
}

// Response 200
{
  "scan_id":"scn_01HZ...",
  "shipment_status":"at_dest_hub",
  "next_expected_scan":"out_for_delivery"
}
```

#### Manifest dispatch — `POST /hub/manifests/{id}/dispatch`
```json
{ "driver_id":"drv_01HZ...", "vehicle_id":"veh_01HZ...", "seal_no":"SEAL-334421" }
```

#### Accept offer — `POST /driver/offers/{id}/accept`
```json
// Response 200
{
  "trip_id":"trp_01HZ...",
  "pickup": {"lat":23.81,"lng":90.41,"address":"..."},
  "dropoff":{"lat":23.78,"lng":90.42},
  "customer":{"name":"Rahim","phone_masked":"+8801XXXXXX123"},
  "navigation_url":"geo:23.81,90.41"
}
```

### 10.8 Rate Limits (defaults)

| Scope | Limit |
|-------|-------|
| `/auth/**/otp/request` | 3/min/phone, 10/day/phone, 100/hr/IP |
| `/rides` POST | 5/min, 20/hr per user |
| `/food/search` | 60/min |
| `/merchant/shipments` | 600/min per API key |
| `/merchant/shipments/bulk` | 10/hr per account |
| `/courier/track/{awb}` (public) | 20/min/IP, 30/min/AWB |
| `/hub/scans` | 300/min per device |
| WS driver location | 1 frame / 2 s per driver |

---

## 11. Real-time & WebSocket Contracts

**URL:** `wss://rt-<city>.superapp.example/v1/ws`
**Auth:** Single-use **ticket** obtained from `POST /realtime/ticket` (30-second TTL), passed via `Sec-WebSocket-Protocol: ticket.<value>`. JWT is **never** in URL.
**Heartbeat:** `ping` every 20 s; idle > 45 s → close.

### 11.1 Common frame shape
```json
{ "type": "<name>", "ts": "ISO-8601", "payload": { ... } }
```

### 11.2 Rider channels (`trip.{trip_id}`, `order.{id}`, `shipment.{awb}`)
| Event | Description |
|-------|-------------|
| `trip.matched` | Driver assigned (name, vehicle, ETA) |
| `trip.driver_location` | {lat,lng,heading,eta_pickup_s} |
| `trip.status` | started / completed / cancelled |
| `order.status` | created/accepted/preparing/ready/picked_up/delivered |
| `shipment.status` | status transitions + scan events |

### 11.3 Driver → Server
| Frame | Rate | Payload |
|-------|------|---------|
| `location` | 1/2s | lat, lng, speed, heading, accuracy, trip_id? |
| `ack_offer` | on-event | offer_id, decision |

### 11.4 Restaurant channel (`outlet.{outlet_id}`)
- `order.new` — with full payload, requires ack within 60s
- `order.cancelled_by_customer` — if still allowed

### 11.5 Hub channel (`hub.{hub_id}`)
- `manifest.incoming` — expected inbound truck
- `sla.breach` — shipment overdue alert
- `exception.flagged` — new exception needing review

### 11.6 Admin channel (`ops.global`, `ops.{city}`)
- Live map updates (batched 5s)
- Fraud alerts, SOS events

---

## 12. Core Workflows

### 12.1 Ride booking

```
Rider    System            Driver
  │ estimate  │               │
  │──────────▶│               │
  │◀──────────│               │
  │ request   │               │
  │──────────▶│ GEOSEARCH drivers
  │           │ score + offer │
  │           │──────────────▶│
  │           │   accept      │
  │           │◀──────────────│
  │ matched   │               │
  │◀──────────│               │
  │   WS: location updates    │
  │◀══════════│══════════════│
```

### 12.2 Food order lifecycle

```
created → accepted_by_store → preparing → ready → picked_up → delivered
   │           │                              │
   │           └─▶ rejected                   └─▶ cancelled (rules apply)
   └─▶ cancelled (pre-accept only)
```

### 12.3 Courier lifecycle (country)

```
created → picked_up → at_origin_hub → sorted → in_transit → at_dest_hub
                                                              │
                                                              ▼
                                                    out_for_delivery
                                                    │
                           ┌──────────────┬─────────┴──────────┐
                           ▼              ▼                    ▼
                       delivered     exception           rto_initiated
                           │              │                    │
                           ▼              ▼                    ▼
                      settled      reattempt/rto         rto_delivered
```

### 12.4 Fare calculation

```
base_fare
+ distance_km × per_km_rate
+ duration_min × per_min_rate
= subtotal
× surge_multiplier
+ booking_fee
+ airport/toll/night_surcharge
− promo_discount
= final_fare
```

Surge mapping (demand/supply ratio):
```
1.0–1.5 → 1.0x (none)
1.5–2.0 → 1.2x
2.0–3.0 → 1.5x
3.0–4.0 → 2.0x
≥ 4.0   → 2.5–3.0x (capped)
```

---

## 13. Courier Country-wide Pipeline

```
  [Rider / Merchant books]
            │
            ▼
    ┌──────────────────┐   courier.shipment.created
    │ Courier Service  │──────────────────────────────▶ Kafka
    └───────┬──────────┘
            │ AWB generated (e.g. SA026JK8P41)
            ▼
    Leg 1: FIRST-MILE PICKUP          (Bike driver)
            │ scan: pickup
            ▼
    ORIGIN HUB: SCAN-IN               (hub_clerk)
            │ scan: hub_inbound
            ▼
    SORT by destination hub           (sort-code on label)
            │ scan: sorted
            ▼
    Leg 2: LINE-HAUL                  (Truck driver, manifest+seal)
            │ scan: manifest_out (origin), manifest_in (dest)
            ▼
    DESTINATION HUB: INBOUND SCAN
            │
            ▼
    HANDOVER to LAST-MILE rider       (scan: handover)
            │
            ▼
    Leg 3: LAST-MILE DELIVERY
            │ scan: out_for_delivery → delivered
            ▼
    COD collected? ──▶ Remittance Service ──▶ Ledger
            │
            ▼
        Shipment settled
```

### 13.1 AWB numbering
- Format: `SA` + 2-digit year + 8 base32 chars = 12 chars total
- Globally unique via `awb_index(awb_no PRIMARY KEY, shipment_id, created_at)` table
- Customer-facing; used in public tracking URLs

### 13.2 Manifest (line-haul)
- Many AWBs travel as one manifest from origin hub to destination hub
- Attributes: `manifest_no`, `vehicle`, `driver`, `seal_no`, `total_weight`, `total_awb_count`
- Origin hub: `open → dispatched`
- Destination hub: `in_transit → received → reconciled`
- Mismatches between manifest AWBs and scanned AWBs create **exceptions** automatically

### 13.3 Exception codes

| Code | Meaning | Next step |
|------|---------|-----------|
| `damaged` | Parcel damaged at hub | Photo + dispute |
| `missing` | Not found during sort/manifest | Search + claim if not found 48h |
| `address_wrong` | Invalid address on last-mile | Recipient call + update |
| `recipient_unavailable` | Delivery failed | Reattempt (max 3) |
| `refused` | Recipient refused | Initiate RTO |
| `weather` | Natural cause delay | SLA extension |
| `rto_requested` | Sender requested return | Reverse flow through hubs |

---

## 14. Payment · COD · Ledger

### 14.1 Payment flow (prepaid)

```
checkout → create intent → user confirms (3DS/OTP) → provider authorizes
                                                      → captured
                                                      → ledger posts
```

All payment requests carry an `Idempotency-Key`; `payments` table enforces UNIQUE `(service, idempotency_key)`.

### 14.2 Double-entry ledger

Every money event posts **at least one debit + one credit** summing to zero per `txn_id`.

| Example | Debit | Credit |
|---------|-------|--------|
| Ride completed (prepaid) | Rider.payment-method | Platform.clearing |
| Driver earning | Platform.clearing | Driver.account |
| Commission | Driver.account | Platform.revenue |
| Tip | Rider.wallet | Driver.account |
| COD collected | Recipient.cash (notional) | Driver.cash-float |
| Driver closes bag at hub | Driver.cash-float | Hub.cash-float |
| Hub bank deposit | Hub.cash-float | Platform.clearing |
| Merchant payout | Platform.clearing | Merchant.account |
| Refund | Platform.clearing | Rider.payment-method |

Deferred trigger enforces balance invariant; UNIQUE `(txn_id, account_id, direction)` prevents duplicate postings.

### 14.3 COD aging & fraud

- Driver cash-float aging alert: held > 24h = warning, > 48h = freeze further COD jobs.
- Hub float aging alert: not deposited within 24h of cut-off = finance review.
- Mismatch between collected & deposited = auto dispute; `hub_finance` cannot self-approve.

### 14.4 Driver payouts

- **Weekly (auto)** — Monday 09:00 local for previous Mon–Sun.
- **Instant (on-demand)** — 1–2% fee; subject to daily caps.
- Payout method: bank or MFS (bKash / Nagad etc.).

### 14.5 Merchant payouts

- **Weekly** — T+2 after week close.
- `Σ(delivered COD) + Σ(prepaid captured) − Σ(commission) − Σ(refunds) − Σ(adjustments) = payout`
- Downloadable PDF invoice; tax compliant (GST/VAT fields).

---

## 15. Security, Safety & Compliance

### 15.1 Authentication

| Panel | Primary | MFA | Device binding |
|-------|---------|-----|----------------|
| Rider | Phone OTP | Optional TOTP | Recommended |
| Driver | Phone OTP | Enforced | **Mandatory** (Play Integrity / App Attest) |
| Restaurant | Email + password | Enforced (TOTP/WebAuthn) | Recommended |
| Merchant | Email + password | Enforced | Recommended + IP allow-list |
| Hub Staff | Email + password + biometric | **Mandatory** | **Mandatory** for finance role |
| Admin | Email + password | **Mandatory WebAuthn** | IP allow-list + VPN |

### 15.2 API security

- TLS 1.3 externally, **mTLS** internally (service mesh).
- Short-lived JWT (5 min access) + refresh rotation.
- **Ticket-based WebSocket auth** — never JWT in URL.
- Request size caps (256 KB body, JSON depth 16) at gateway.
- HSTS + preload, strict CSP for web panels, CORS origin allow-list.
- WAF with OWASP CRS + bot detection.

### 15.3 PII & encryption

- Column-level encryption (KMS-wrapped DEKs) for NID, license, tax ID, phone (masked in logs).
- **Blind indexes** (`HMAC_SHA256`) for searchable encrypted fields.
- Location history TTL 180 days; chat TTL 180 days; audit log retained 7 years.
- Kafka location events 72-hour retention (Cassandra is source of truth).

### 15.4 Safety (Rider)

- **SOS button** on a dedicated `sos.events` channel; falls back to direct HTTPS endpoint with offline retry.
- Share-trip link for trusted contacts.
- Masked phone proxy for rider ↔ driver (expires end of trip + 30 min).
- Post-incident playbook: freeze driver, notify authorities, evidence preservation.

### 15.5 Fraud controls

- Device fingerprint + velocity rules (many signups / device)
- Promo abuse via `promo_redemptions` table unique per (code, ref_id)
- GPS spoof detection (mobility anomaly)
- COD mismatch auto-dispute
- Cancellation pattern monitoring

### 15.6 Audit & GDPR

- Append-only `audit_log` (partitioned monthly; archived to S3 after 24 months, kept 7 years).
- **Right-to-export** endpoint per user (ZIP of personal data).
- **Right-to-erase** (soft-delete 30 days → hard anonymize). Active jobs block deletion.
- 4-eyes approval for refunds/suspensions over thresholds.
- DPA / DPIA maintained; quarterly privacy review.

---

## 16. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p99 API latency (non-geo) | < 250 ms |
| Location ingest throughput | 100k updates/sec peak |
| Matching SLA | < 3 s request → dispatch |
| Core availability | 99.95% |
| RPO / RTO | 5 min / 30 min |
| Payment idempotency | Exactly-once perceived |
| Hub scan latency | p95 < 500 ms |
| Socket drop rate | < 0.5% / 5-min window |
| Courier SLA breach | < 1% shipments/week |
| COD reconciliation drift | < 0.1% daily |

---

## 📂 Related Design Files

The granular multi-phase design package lives in [super_app_design/](super_app_design/):

| File | Purpose |
|------|---------|
| [01_features_list.md](super_app_design/01_features_list.md) | Feature matrix per panel (MVP/V2) |
| [02_system_design.md](super_app_design/02_system_design.md) | Microservices, protocols, scaling |
| [03_database_schema.md](super_app_design/03_database_schema.md) | PostgreSQL DDL, MongoDB, Redis, Cassandra |
| [04_api_list.md](super_app_design/04_api_list.md) | Full API & WebSocket contracts |
| [05_review_and_corrections.md](super_app_design/05_review_and_corrections.md) | SRE + Security audit with top-10 fixes |

---

*Document version: 1.0 — April 21, 2026*
