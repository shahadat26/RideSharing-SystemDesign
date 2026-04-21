# 01 — Features List (Product Architect Agent)

**Product:** Super App (Ride Sharing + Food Delivery + Parcel City + Courier Country)
**Inspiration:** Pathao / Uber / Grab
**Author:** Senior Product Architect

---

## 1. User Roles (Six Panels)

| # | Panel | Actor | Scope |
|---|-------|-------|-------|
| 1 | **Rider App** | Customer (passenger / food buyer / parcel sender) | Books rides, orders food, sends intra-city parcels, ships inter-city courier |
| 2 | **Driver App** | Driver / Rider (Car, Bike, Auto, Truck) | Fulfills rides, food deliveries, intra-city parcels, and first-/last-mile courier legs |
| 3 | **Restaurant Panel** | Restaurant/kitchen operator | Menu, live order KDS, prep-time, payouts |
| 4 | **Merchant Panel** | Non-food seller / shop owner | Storefront catalog, bulk parcel & courier shipments, payouts |
| 5 | **Hub Panel** | Courier hub / warehouse staff | Scan-in/out, sort, manifest, line-haul dispatch, country-wide courier routing |
| 6 | **Admin Dashboard** | Operations / Finance / Safety / Support | KYC, fraud, pricing, disputes, analytics, staff RBAC |

### 1.1 Service Types

| Service | Scope | Typical vehicle | Owner panels involved |
|---------|-------|-----------------|-----------------------|
| **Ride** | Intra-city | Bike, Auto, Sedan, SUV | Rider, Driver, Admin |
| **Food Delivery** | Intra-city | Bike | Rider, Restaurant, Driver, Admin |
| **Parcel (City)** | Intra-city point-to-point | Bike, Car | Rider, Merchant, Driver, Admin |
| **Courier (Country)** | Inter-city, multi-leg, hub-routed | Bike (pickup/last-mile) + Truck (line-haul) | Rider/Merchant, Driver, Hub, Admin |

---

## 2. Feature Matrix — MVP vs V2

Legend: ✅ MVP · 🟡 V2 · 🔒 Compliance/Trust

### 2.1 Customer

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| C1 | Phone/OTP sign-up & login | ✅ | SMS + email fallback |
| C2 | Profile & multiple saved addresses | ✅ | Home/Work, geocoded |
| C3 | Book ride (Bike / Car / Premium) | ✅ | Real-time ETA & fare estimate |
| C4 | Live driver tracking on map | ✅ | WebSocket, ≤ 3s update |
| C5 | Fare estimate & surge/dynamic pricing | ✅ | Transparent breakdown |
| C6 | In-app chat & masked-number call | ✅ | 🔒 PII masking |
| C7 | Cashless payment (card, wallet, MFS) | ✅ | bKash/Nagad/Stripe |
| C8 | Cash payment option | ✅ | |
| C9 | Ride history & e-receipt | ✅ | |
| C10 | Rate & review driver | ✅ | |
| C11 | SOS / emergency button | ✅ | 🔒 Safety |
| C12 | Food: browse restaurants, search, filter | ✅ | |
| C13 | Food: cart, checkout, live order status | ✅ | |
| C14 | Parcel (city): send package intra-city with pickup/drop | ✅ | Size/weight tiers |
| C15 | Courier (country): inter-city shipment with hub routing | ✅ | AWB/tracking no., SLA tiers (Std/Express) |
| C16 | COD (Cash-on-Delivery) option for parcel/courier | ✅ | 🔒 Cash reconciliation |
| C17 | Promo codes & referrals | ✅ | |
| C16 | Schedule a ride | 🟡 | |
| C17 | Multi-stop ride | 🟡 | |
| C18 | Subscription / pass (Uber One-style) | 🟡 | |
| C19 | Group order / split bill | 🟡 | |
| C20 | Loyalty points & tiered rewards | 🟡 | |
| C21 | In-app wallet with top-up | 🟡 | |
| C22 | Live shopping / grocery | 🟡 | |

### 2.2 Driver / Rider

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| D1 | Driver onboarding + KYC (NID, license, vehicle docs) | ✅ | 🔒 |
| D2 | Online/Offline toggle | ✅ | |
| D3 | Receive matched requests (accept/reject in N sec) | ✅ | Matchmaking |
| D4 | Turn-by-turn navigation (embedded/linked) | ✅ | |
| D5 | Earnings dashboard (daily/weekly) | ✅ | |
| D6 | Instant payout to bank/MFS | ✅ | Configurable |
| D7 | Heatmap of demand | ✅ | |
| D8 | In-app chat/call with customer | ✅ | Masked |
| D9 | Accept multi-service (ride + food + parcel + courier first/last mile) | ✅ | Per driver capability |
| D10 | Courier line-haul mode (truck driver, hub-to-hub manifest scan) | ✅ | Separate role flag |
| D11 | COD collection + end-of-day remittance at hub/office | ✅ | 🔒 |
| D12 | Document expiry reminders | ✅ | |
| D11 | Incentives / quest tracker | 🟡 | |
| D12 | Driver tiers & priority dispatch | 🟡 | |
| D13 | Training modules | 🟡 | |

### 2.3 Restaurant Panel (Food vertical)

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| R1 | Restaurant onboarding + KYC (trade license, FSSAI/food permit, tax ID) | ✅ | 🔒 |
| R2 | Menu / modifier / combo CRUD + item availability toggle | ✅ | |
| R3 | Kitchen Display System (KDS) tablet app with sound alerts | ✅ | |
| R4 | Accept/reject + live prep-time update | ✅ | |
| R5 | Auto-print receipt (ESC/POS printer) | ✅ | |
| R6 | Live order status broadcast to customer | ✅ | |
| R7 | Daily payout report + commission statement | ✅ | |
| R8 | Self-service discounts / combos / happy-hour | 🟡 | |
| R9 | Analytics (top items, peak hours, rejection reasons) | 🟡 | |
| R10 | Multi-outlet management under one brand | 🟡 | |
| R11 | Ingredient-level stock sync | 🟡 | |

### 2.4 Merchant Panel (Parcel / Courier / Non-food retail)

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| MC1 | Merchant onboarding + KYC (trade license, tax ID, GSTIN) | ✅ | 🔒 |
| MC2 | Storefront / catalog CRUD for retail items | ✅ | |
| MC3 | Bulk parcel booking (CSV / API) | ✅ | City & country |
| MC4 | Address book of recipients | ✅ | |
| MC5 | Pickup scheduling window (single & recurring) | ✅ | |
| MC6 | Live shipment tracking dashboard | ✅ | |
| MC7 | Cash-on-Delivery (COD) remittance report | ✅ | 🔒 |
| MC8 | Weekly payout + invoice download | ✅ | |
| MC9 | API keys + webhooks for ERP/OMS integration | ✅ | |
| MC10 | Return / RTO (Return-to-Origin) handling | ✅ | |
| MC11 | Label printing (A5/A6 thermal) | ✅ | |
| MC12 | Rate card simulator & contract pricing | 🟡 | |
| MC13 | Multi-warehouse support | 🟡 | |

### 2.5 Hub Panel (Courier country-wide operations)

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| H1 | Hub staff login + role-scoped access | ✅ | 🔒 |
| H2 | Parcel **scan-in** (pickup arrival) via barcode/QR | ✅ | |
| H3 | Sort by destination hub / zone | ✅ | Sort-code on label |
| H4 | **Manifest creation** for line-haul / air / rail leg | ✅ | |
| H5 | Line-haul dispatch + seal number + driver assignment | ✅ | |
| H6 | Inbound manifest reconciliation (scan-in of incoming bag) | ✅ | |
| H7 | Handover to last-mile rider | ✅ | |
| H8 | Exception handling: damaged, missing, reattempt | ✅ | 🔒 |
| H9 | COD cash reconciliation at hub | ✅ | 🔒 Finance |
| H10 | Live hub KPIs (in/out, aging, SLA breach) | ✅ | |
| H11 | Hub capacity & cut-off time configuration | ✅ | |
| H12 | CCTV / photo-proof attachment on exceptions | 🟡 | |
| H13 | Shift roster & attendance | 🟡 | |

### 2.6 Admin / Ops Dashboard

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| A1 | User/driver/restaurant/merchant/hub CRUD + suspend | ✅ | |
| A2 | KYC approval queues (per panel) | ✅ | 🔒 |
| A3 | Live ops map (drivers, orders, trips, shipments) | ✅ | |
| A4 | Dispute/refund console | ✅ | |
| A5 | Fraud detection rules + alerts | ✅ | 🔒 |
| A6 | Pricing / surge / rate-card config per city/zone/lane | ✅ | |
| A7 | Zone, service-area & hub-network management | ✅ | |
| A8 | Financial reconciliation (rider, driver, restaurant, merchant, hub, COD float) | ✅ | |
| A9 | Marketing / promo campaign console | 🟡 | |
| A10 | A/B experiment platform | 🟡 | |
| A11 | ML model monitoring (matching/ETA/fraud) | 🟡 | |
| A12 | Staff RBAC + 2FA + audit trail | ✅ | 🔒 |

---

## 3. Cross-Cutting Themes (First-Class)

- **Real-time tracking** — location stream ≤ 3s latency; offline buffering on driver app.
- **Matchmaking** — geo-radius + driver score + ETA + supply/demand surge.
- **Payments** — multiple gateways, idempotent, ledger-based, PCI-DSS scope reduced via tokenization.
- **Safety & Trust** — SOS, share-trip, trip recording metadata, masked comms.
- **Observability** — full tracing of a trip/order across services.
- **Internationalization** — BN/EN, multi-currency ready.
- **Accessibility** — WCAG 2.1 AA for consumer apps.

---

## 4. Non-Functional Requirements (MVP)

| NFR | Target |
|-----|--------|
| p99 API latency (non-geo) | < 250 ms |
| Location ingest throughput | 100k updates/sec peak |
| Matching SLA | < 3 s from request to dispatch |
| Availability | 99.95% core services |
| RPO / RTO | 5 min / 30 min |
| Payment idempotency | Exactly-once perceived |
