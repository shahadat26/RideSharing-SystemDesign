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
12. [Notifications & Communications](#17-notifications--communications)
13. [Support Operations](#18-support-operations)
14. [Localization & Multi-Tenancy](#19-localization--multi-tenancy)
15. [Observability, Reliability & DR](#20-observability-reliability--dr)
16. [Mobile Platform Concerns](#21-mobile-platform-concerns)
17. [Production Readiness Checklist](#22-production-readiness-checklist)
18. [Algorithms & Engines](#23-algorithms--engines)
19. [Event Taxonomy (Kafka Topic Catalog)](#24-event-taxonomy-kafka-topic-catalog)
20. [Error Code Catalog & API Versioning](#25-error-code-catalog--api-versioning)
21. [Deployment, CI/CD & SRE Runbooks](#26-deployment-cicd--sre-runbooks)
22. [Integrations & Compliance Matrix](#27-integrations--compliance-matrix)
23. [Capacity, Cost & Scale Model](#28-capacity-cost--scale-model)
24. [Panel Design Diagrams (one per panel)](#29-panel-design-diagrams)

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
| App update enforcement | Force-upgrade flag served by config service |
| Maintenance banner | Per-city advisory pushed via remote config |

### 4.6 Power Rider Features (Uber/Pathao parity)

| Feature | Description | Logic |
|---------|-------------|-------|
| **Multi-stop ride** | Up to 3 intermediate stops | Re-prices on each stop add/remove; route re-optimised |
| **Ride for someone else** | Book on behalf of contact | Recipient gets SMS w/ live link + driver call masked |
| **Scheduled / recurring** | One-shot or weekly recurring | Pre-dispatch 10 min before; auto-cancel if no driver in 5 min |
| **Favorite / blocked drivers** | Per-rider lists | Affects offer eligibility filter |
| **Pickup PIN** | 4-digit code shared by app | Driver must enter to start trip; mitigates wrong-pickup |
| **Fare split** | Split bill across riders | Each pays their share via own payment method |
| **Ride preferences** | Quiet ride, AC, music off, pet-friendly | Hint passed to driver; not enforced |
| **Lost & Found** | Report item from past trip | Routes to driver via masked call + support ticket |
| **Trip insurance** | Per-trip optional cover | Underwritten by 3rd party; receipt attached |
| **Outstation / rental** | Hourly or city-to-city packages | Different pricing engine + driver pool |
| **Receipts & invoices** | PDF per trip + monthly statement | Email + in-app download; GST/VAT compliant |
| **Subscription pass** | E.g. Uber One / Pathao Pro | Discounts, free delivery threshold, priority dispatch |
| **Loyalty / rewards** | Points per spend | Redeem for ride credits; tier badges |
| **Referral program** | Referrer + referee credits | Anti-abuse via device + payment-method graph |
| **Corporate / business profile** | Switch personal ↔ business | Bills to org; manager approval workflow; SSO supported |
| **Family / Teen account** | Linked dependent accounts | Live tracking + spend cap shared with primary |
| **Voice notes in chat** | 30-s clips | Stored 7 days; auto-transcribed for safety review |
| **Annotated pickup spot** | Drop a precise pin + photo | Reduces pickup confusion; cached per address |

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

### 5.7 Driver Quality-of-Life & Production Features

| Feature | Description | Logic |
|---------|-------------|-------|
| **Quest / Streak bonuses** | "Complete 30 trips this week → +500" | Tracked in incentives service; ledger credit on completion |
| **Long-pickup compensation** | Pickup > X km auto-pays extra | Calculated at trip start |
| **Wait-time charges** | After 5-min free → per-min charge | Auto-added to fare; capped per city |
| **Cancellation fee** | Charged to rider after grace period | Split with driver per policy |
| **Toll auto-detection** | Geofence + lane data | Added to fare with receipt |
| **Document expiry alerts** | License/Insurance/RC expiry T-30 / T-7 / T-1 | Push + email; soft-block on expiry |
| **Vehicle inspection reminders** | Annual or per-N-trips | Photo upload, hub-staff sign-off |
| **In-trip safety** | Trip recording (audio, opt-in), speed alert, fatigue warning | Audio encrypted on-device, uploaded only on dispute |
| **Earnings goal tracker** | Daily target + progress bar | Local computation + summary |
| **Fuel / EV charging perks** | Partner discounts | Static partner list + redemption code |
| **Driver chat / community** | In-app feed, support FAQ | Read-only feed by ops |
| **Driver-to-driver referral** | Bonus on referee's first 50 trips | Referral table; anti-fraud graph |
| **Vehicle swap / second driver** | One vehicle, two drivers | Active session per device; KYC per driver |
| **Earnings withdrawal limits** | Daily/weekly caps + KYC tier | Anti-money-laundering |
| **Tax / TIN management** | Annual statement, withholding | Country-specific |
| **Roadside assistance** | One-tap from in-trip menu | Routes to partner; cost flagged |

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

### 6.6 Restaurant Production Features

| Feature | Description | Logic |
|---------|-------------|-------|
| **86 list (out of stock)** | One-tap mark item unavailable | Invalidates search index + cart re-validation |
| **Stock count per item** | Optional inventory | Auto-86 on zero; manual reset |
| **Order modification mid-prep** | Customer adds/removes item before "preparing" | Restaurant accept/decline; price diff posted to ledger |
| **Multi-printer routing** | Kitchen vs bar vs packing | Configurable per category |
| **Self-delivery mode** | Restaurant uses own riders | Skips dispatch; commission tier differs |
| **Sponsored listings / ads** | Pay-per-click placement | Ad service + budget cap |
| **Customer review reply** | Public reply to ratings | Auto-moderation + 1 reply per review |
| **Refund issuance** | Partial/full at restaurant | 4-eyes if > threshold; ledger reversal |
| **Tax invoice config** | GST/VAT number on receipts | Per outlet |
| **Store-level KPIs** | Acceptance %, prep time, rejection % | Affects search ranking |
| **Force-close / break mode** | Pause incoming for 15-60 min | Visible to customer with ETA-back-online |
| **Tablet device management** | Tablet provisioning, remote wipe, OTA | MDM-lite; heartbeat every 60 s |
| **Holiday calendar** | Closed-day schedule | Honoured by search filter |
| **Image moderation** | Auto + human for menu photos | Blocks nudity/violations |

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

Webhook delivery: at-least-once with **exponential backoff** (1m, 5m, 30m, 2h, 12h, 24h × 3); dead-letter queue after 7 days; merchant can replay from dashboard.

### 7.6 Merchant Production Features

| Feature | Description | Logic |
|---------|-------------|-------|
| **Pickup address book** | Multiple warehouses CRUD | Default flagged; geocoded |
| **Reverse pickup (returns)** | Customer-to-warehouse | Reverse AWB lifecycle |
| **Per-shipment insurance** | Opt-in cover up to declared value | Premium added to price |
| **Fragile / DG declaration** | Restricted goods list | Blocks line-haul if not eligible |
| **Bulk label print** | One PDF for batch | Async, downloadable |
| **Postpaid invoicing** | Credit limit + monthly invoice | Credit-check + auto-suspend on overdue |
| **COD pincode allow-list** | Per-merchant serviceability | Block at booking if not allowed |
| **API sandbox** | Test environment + dummy webhooks | Separate keyspace |
| **Plugin integrations** | Shopify / WooCommerce / Magento | OAuth + per-store mapping |
| **Sub-user accounts** | Ops, Finance, Viewer roles | Scoped permissions, audit |
| **Brand customization** | Logo on label, on tracking page | Approved by admin |
| **Custom packaging request** | Fragile wrap, branded box | Surcharge per shipment |
| **Pickup SLA** | Time-window booking with auto-cancel | Driver assigned in window |
| **Manifest export** | Daily handed-over PDF | For sender's records |
| **Disputes / claims** | Lost/damaged/short COD | SLA 48 h; ledger reversal on approval |

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

### 8.9 Hub Production Features

| Feature | Description | Logic |
|---------|-------------|-------|
| **Bag-level scanning** | Bag → many AWBs | Hierarchical scan; bag QR enables 1-scan handover |
| **Cage / location map** | Bin assignments by destination | Auto sort suggestion |
| **Capacity & occupancy** | Real-time hub fill % | Alerts at 80% / 95%; blocks new inbound |
| **Dock scheduling** | Truck arrival/departure slots | Avoids congestion; visible to line-haul drivers |
| **Gate pass (in/out)** | Vehicle entry log | Security desk + CCTV cross-ref |
| **Cross-docking** | Skip storage, direct transfer | Auto-flagged when transit time short |
| **Damage assessment** | Photo + severity grade | Triggers claim workflow |
| **Cycle count / stock take** | Periodic full audit | Reports discrepancies |
| **Chain of custody log** | Every scan = custody transfer | Append-only; used in disputes |
| **CCTV reference** | Camera ID + timestamp linked to scan | For claims/dispute review |
| **Returns processing** | RTO inbound, sort, hand to merchant | Separate cage |
| **Cut-off times** | Per lane daily cut-off | Late shipments roll to next manifest |
| **Hub roster / shift mgmt** | Staff schedule, attendance | Affects KPI baselines |
| **Power & connectivity SLA** | UPS + dual ISP requirement | Health-check to admin |
| **Hub-to-hub transfer slip** | Reconciliation doc per manifest | Signed by both supervisors |

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

### 9.8 Admin Production Features

| Feature | Description | Logic |
|---------|-------------|-------|
| **Feature flags / experiments** | Per-city, per-cohort rollouts | LaunchDarkly-style; A/B with stat-sig guardrails |
| **Geofence / zone editor** | Polygon drawing for zones, surge, no-go | Versioned; activates via remote config |
| **City onboarding wizard** | Activate new city: tariff, hubs, zones, ops staff | One-page workflow |
| **Holiday / curfew calendar** | Service blackouts, special tariffs | Auto-applied to pricing engine |
| **Notification campaigns** | Push / SMS / email broadcast | Segmentation + frequency caps |
| **Surge override** | Manual emergency surge / cap | Audited; expires automatically |
| **Tariff calendar** | Festival / event pricing | Effective-from / effective-to |
| **Document templates** | T&C, privacy, driver agreement versions | User must re-accept on update |
| **Help center CMS** | FAQ, articles, in-app help | Localized |
| **Block-list management** | Devices, IPs, payment instruments, BIN | Linked to fraud signals |
| **Compliance dashboard** | KYC age, doc-expiry, tax filings | Regulatory readiness |
| **Driver / restaurant tier program** | Bronze/Silver/Gold by score | Visible benefits + auto-tiering |
| **Live ops war room** | Multi-screen, on-call staff | Filter by city/incident |
| **Audit log viewer** | Search by actor, entity, action | Tamper-evident (signed/append-only) |
| **Data exports & lake sync** | Daily warehouse load (Snowflake/BigQuery) | PII redaction by role |
| **Bulk operations** | Bulk approve/reject/refund (with limits) | 4-eyes + audit |

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

## 17. Notifications & Communications

A dedicated **Notification Service** fans out events to the right channel based on user preferences and message criticality.

### 17.1 Channels

| Channel | Provider examples | Use cases |
|---------|-------------------|-----------|
| **Push (APNs / FCM / HMS)** | Apple, Google, Huawei | Order/trip status, offers, safety |
| **SMS** | Twilio, MessageBird, local aggregators | OTP, recipient alerts, fallback |
| **Voice / IVR** | Twilio, Exotel | OTP fallback, masked calls |
| **Email** | SES, SendGrid | Receipts, invoices, weekly summaries |
| **WhatsApp Business** | Meta Cloud API | Order updates, support replies |
| **In-app inbox** | Internal | Persistent message history |
| **Webhook** | Merchant URLs | B2B event streams |

### 17.2 Categories & priority

| Category | Examples | User opt-out? | Channel rules |
|----------|----------|---------------|---------------|
| **Critical / safety** | SOS ack, account compromise | No | All channels, retry until ack |
| **Transactional** | OTP, order/trip status, payment | No | Push first, SMS fallback in 30s |
| **Operational** | Driver doc expiry, payout sent | Limited | Push + email |
| **Marketing** | Promos, recommendations | Yes | Frequency-capped (max 3/week) |

### 17.3 Engineering controls

- **Template service** with localized variants and approval workflow
- **Idempotent send** keyed on `(user_id, template_id, dedup_key)` (15-min window)
- **Quiet hours** per user (default 22:00–07:00 local) — marketing only
- **Push token registry** with platform, app version, last-seen; auto-prune after 60d inactive
- **Deep link / universal link** routing for every notification
- **Bounce / unsubscribe handling** synced from providers
- **Throughput**: 50k push/sec, 5k SMS/sec sustained per region
- **Cost guardrails**: per-campaign budget caps; per-user spend ceiling (anti-bombing)

---

## 18. Support Operations

### 18.1 Support stack

| Layer | Detail |
|-------|--------|
| **In-app help** | Self-serve articles, FAQ, contextual help by screen |
| **Bot triage** | LLM-assisted intent classification + canned answers |
| **Live chat** | Tier-1 agents, in-app and WhatsApp |
| **Voice support** | Premium / safety incidents; recorded for QA |
| **Specialist queues** | Safety, Payments, KYC, Hub, Merchant API |
| **Field ops** | Hub disputes, driver onsite issues |

### 18.2 Ticket lifecycle

```
open → assigned → in_progress → waiting_customer → resolved → closed
                              └▶ escalated → tier2/specialist
```

### 18.3 SLAs (defaults)

| Priority | First response | Resolution |
|----------|---------------|------------|
| P0 (safety / outage) | < 5 min | < 1 h |
| P1 (payment, COD) | < 30 min | < 8 h |
| P2 (general) | < 4 h | < 48 h |
| P3 (info) | < 24 h | < 5 d |

### 18.4 Tooling

- 360° user view (trips, orders, payments, devices, prior tickets)
- One-click compensation (capped, audited)
- Macros + saved replies, multi-language
- CSAT survey on close, agent QA scorecard
- PII access redaction by agent role (e.g., NID hidden unless reason recorded)

---

## 19. Localization & Multi-Tenancy

### 19.1 City / country configuration

Every city is a **first-class config** with isolated overrides:

| Knob | Example |
|------|---------|
| Currency | BDT, INR, USD |
| Timezone | Asia/Dhaka |
| Languages | bn, en |
| Vehicle types | bike, auto, sedan, suv |
| Tariff cards | base, per-km, per-min, surcharges |
| Payment methods | bKash, Nagad, card, cash |
| Regulatory IDs | GST, VAT, NID format |
| Working hours / curfews | per city |
| Service eligibility | Ride ✅ / Food ✅ / Parcel ✅ / Courier hubs |

### 19.2 i18n

- All user-facing strings keyed; ICU MessageFormat
- RTL support (future markets)
- Number/date/currency formatted by locale
- App-side translation bundles delivered via remote config; OTA-updatable
- Push templates & SMS texts localized per recipient preference

### 19.3 Data residency

- Region-pinned writes for money movement (no cross-border ledger writes)
- Data export tools to satisfy local DPA / DPDPA / GDPR

---

## 20. Observability, Reliability & DR

### 20.1 Telemetry

| Pillar | Stack |
|--------|-------|
| **Metrics** | Prometheus + Thanos / Grafana Mimir |
| **Logs** | OpenTelemetry → Loki / Elastic |
| **Traces** | OpenTelemetry → Tempo / Jaeger |
| **RUM (mobile/web)** | Sentry / Firebase Performance |
| **Synthetic checks** | Per-region probes for critical APIs + WS |

### 20.2 SLOs (rollup)

| Service | SLO | Error budget |
|---------|-----|--------------|
| Identity / Auth | 99.95% successful auth | 22 min/month |
| Ride dispatch | 99.9% match < 3 s | 43 min/month |
| Payments | 99.99% successful capture | 4 min/month |
| Hub scan API | 99.9% p95 < 500 ms | 43 min/month |
| WS realtime | < 0.5% drops / 5-min | rolling |

### 20.3 Reliability tactics

- **Cell-based deploys** per city; blast radius = one cell
- **Bulkheaded thread-pools / connection-pools**
- **Circuit breakers + retries with jitter** at clients
- **Outbox pattern** for DB → Kafka (no dual-writes)
- **Idempotency keys** required on all state-changing endpoints
- **Backpressure**: shed marketing pushes first under load
- **Chaos engineering**: monthly game-day per critical service

### 20.4 Disaster recovery

| Tier | RPO | RTO | Strategy |
|------|-----|-----|----------|
| Payments / Ledger | < 1 min | < 15 min | Sync replica + cross-region failover |
| Trips / Orders | 5 min | 30 min | Async replica + region failover |
| Location / Cache | Best-effort | Reconstructible | Rebuild from device telemetry |
| Reports / Lake | 24 h | 24 h | Daily snapshot |

- Quarterly **DR drills**; documented runbooks per service
- **Backup encryption** with separate KMS key; periodic restore validation
- **On-call rotations** with PagerDuty/Opsgenie; primary + secondary; sev-1 page < 5 min

---

## 21. Mobile Platform Concerns

### 21.1 Lifecycle

- **Force-upgrade** when minimum supported version surpassed
- **Soft-upgrade** banner with "remind me later" (capped at N reminders)
- **Remote config** with safe defaults — apps must never crash on missing keys
- **Feature flag SDK** with offline cache + last-known-good
- **Crash & ANR reporting** (Crashlytics / Sentry); crash-free user > 99.5%

### 21.2 Offline-first

| Concern | Approach |
|---------|----------|
| Driver app | Queue location frames, scans, offer-accepts; replay with `client_id` dedupe |
| Hub app | IndexedDB scan queue, conflict-free replay |
| Rider app | Last known order / trip cached for tracking screen |
| Maps | Pre-fetched tile cache for active route |

### 21.3 Performance budgets

- Cold start < 2.0 s on mid-tier Android
- Screen TTI < 1.5 s for top 5 screens
- App size: rider < 60 MB, driver < 80 MB (with on-demand modules)
- Battery: < 6%/hour while driver online (background location)

### 21.4 Security on device

- Keychain / Keystore for refresh tokens; never plain disk
- Root / jailbreak detection (warn, not block, except finance flows)
- Certificate pinning for API + payment endpoints
- Screenshot / overlay protection on payment & OTP screens
- Tamper detection (Play Integrity / App Attest)

---

## 22. Production Readiness Checklist

Before a city / service goes live:

- [ ] Capacity plan reviewed; load test at **3× peak** passed
- [ ] All endpoints have rate limits and abuse controls
- [ ] All mutating endpoints accept `Idempotency-Key`
- [ ] All money flows go through the double-entry ledger (no direct balance updates)
- [ ] PII encrypted at rest + masked in logs; blind indexes for searchable PII
- [ ] WebSocket uses ticket auth; no JWT in URLs
- [ ] mTLS enforced inside the mesh
- [ ] WAF + bot mitigation active at edge
- [ ] Backups verified by restore drill within 90 days
- [ ] DR drill in last 90 days; runbook updated
- [ ] On-call rotation defined; pager test green
- [ ] Dashboards & alerts mapped to SLOs (page on burn rate)
- [ ] Feature flags enable safe rollback
- [ ] Privacy review (DPIA) signed off
- [ ] T&C / Privacy / Driver Agreement localized & accepted
- [ ] Tax / invoice formats validated by finance
- [ ] KYC vendors integrated with SLAs
- [ ] Payment provider failover tested
- [ ] Push, SMS, email deliverability monitored per region
- [ ] Help-center articles + in-app help published
- [ ] Support agents trained; macros and SLAs configured
- [ ] Hub physical readiness: power, connectivity, CCTV, scanners, signage
- [ ] Driver onboarding pipeline tested end-to-end
- [ ] Merchant onboarding & sandbox tested end-to-end
- [ ] Restaurant KDS hardware staged & tested
- [ ] Admin RBAC reviewed; least-privilege enforced
- [ ] Audit log retention & immutability validated
- [ ] Compliance: regulatory licenses for ride / courier / payments in force

---

## 23. Algorithms & Engines

### 23.1 Dispatch / matching

**Goal:** assign the best driver to a trip/order in < 3 s while keeping utilisation high and bias low.

**Candidate retrieval**
1. `GEOSEARCH` in `redis-geo-<city>` for drivers within radius R (default 3 km; expand to 5, 8, 12 km if empty).
2. Filter: online, `capability` matches service, not on another job, vehicle type allowed, not on rider's block-list, doc not expired.

**Scoring (lower = better)**

```
score = w1 * eta_to_pickup_s
      + w2 * (1 - acceptance_rate_7d)
      + w3 * (1 - rating_norm)         // rating_norm = (rating-4.0)/1.0 clamped
      + w4 * idle_time_penalty         // reward idle drivers
      + w5 * detour_cost               // if driver on chained job
      - w6 * tier_bonus                // gold/silver boost
      + w7 * pickup_km_penalty_over_X
      + w8 * fairness_jitter           // small random to break ties
```

Weights stored in config, A/B-tested per city.

**Offer strategy**
- **Single-offer** for rides (fastest for rider); **batched-offer to top-K** if acceptance is low (K=3, first-come wins, others get "missed" with small comp).
- Offer TTL = 8 s; on reject/expire, re-score excluding the driver for 60 s.
- Starvation guard: any driver online > 20 min with no offer gets a +bias for next round.
- Global re-dispatch if unmatched after 3 rounds or 30 s → widens radius + surges zone.

**Food dispatch** differs: waits until restaurant ETA minus pickup-travel-time; picks driver who arrives just after food is ready (minimises wait).

**Fairness & bias**
- No rider demographic used in scoring.
- Surge pay is transparent to drivers pre-accept.
- Audit trail: every offer logged with score components for after-the-fact review.

### 23.2 Surge / dynamic pricing

```
demand   = active_requests_5min(zone)
supply   = available_drivers(zone)
raw      = demand / max(supply, 1)
smoothed = EMA(raw, alpha=0.3)          // hysteresis
multiplier = lookup(smoothed)           // see surge table §12.4
```

- **Zone** = hex-H3 level 8 (≈ 460 m edge) or city-defined polygon.
- Update interval 60 s; change capped at +0.3x per tick (avoid shock).
- City-level cap (e.g. 3.0x) + regulatory cap where required.
- Driver-visible heatmap uses same multiplier; published only when delta > 0.1x.
- Shadow-mode: pricing v2 runs in parallel for 2 weeks before cutover.

### 23.3 ETA & routing

- **Router:** OSRM or Valhalla self-hosted; Mapbox/Google as failover per city.
- **Distance type:** road-distance for fare, straight-line only as fallback with +20% fudge.
- **Traffic:** provider-fed where available; internally aggregated travel times from recent trips (per edge, rolling 15 min) override static.
- **ETA output:** `{distance_m, duration_s, polyline}`; cached 60 s per O-D pair in `redis-cache`.
- **ETA confidence:** model outputs p50 & p90; UI shows p50, dispatch uses p50, SLA check uses p90.

### 23.4 Pricing engine (tariff resolution)

```
resolve_tariff(city, service, vehicle, now, zone)
  → effective_tariff = base_card
                      ⊕ city_override
                      ⊕ zone_override
                      ⊕ time_window (holiday, festival, night)
                      ⊕ surge_multiplier
                      ⊕ promo (applied last, capped)
```

- Tariff rows versioned, `effective_from / effective_to`; audit log on change.
- Every computed fare persists `tariff_version_id` + the full calc breakdown for receipts/disputes.

### 23.5 Fraud model

**Feature classes**
- Identity: device fingerprint, SIM change velocity, IP/ASN, account age
- Behaviour: cancel rate, short-trip rate, same origin/destination cluster
- Geo: GPS jump (km/s impossible speed), spoofing signature (mock provider, root, emulator)
- Money: COD-vs-deposit delta, refund/chargeback rate, promo-per-account ratio

**Pipeline**
- Rule engine (Drools-like) for hard blocks (explainable, regulated).
- Gradient-boosted model (shadow for 4 weeks before activation) for risk score 0–100.
- Decisions: `allow`, `challenge` (step-up auth), `review` (manual), `block`.
- All decisions written to `fraud_decisions` with reason codes; appealable via support.

### 23.6 Search & ranking (food / merchant catalog)

- **Store search:** Elasticsearch index `stores_<city>`; fields `name^3, cuisine^2, tags, menu_preview`.
- **Ranking:**
  ```
  rank = bm25(query)
       + 0.4 * proximity_score(distance_m)
       + 0.3 * popularity_30d(orders / impressions)
       + 0.2 * rating_norm
       + 0.1 * personalised_cf_score
       * open_now_boost(1.3 if open)
       * sponsored_boost (paid; max 20% of top 10)
  ```
- **Index updates:** CDC from Mongo menu + Postgres outlet_hours → Kafka → ES within 30 s.
- **Freshness:** ranked boost for items added in last 30 days; new stores get "cold-start" boost for 14 days capped.

### 23.7 Location pipeline

```
Driver device (1 frame / 2 s) → WS ingest gateway
  → Redis geo-index (latest only, per driver)
  → Kafka `location.driver.updates.<city>` (72 h retention)
  → Cassandra `location_history` (180 d TTL, bucketed by hour)
  → Downsampler → Parquet on S3 (1 Hz daily roll-up, 2 y retention)
```

- **Smoothing:** Kalman filter client-side; server drops points with accuracy > 100 m.
- **Snap-to-road** on ingestion for trips only (not idle cruise).
- **Backpressure:** if Kafka lag > 30 s, drop every other frame for idle drivers first.

### 23.8 WebSocket fan-out & scale

- **Per-city WS cluster**; sticky routing by `user_id` hash.
- Connection budget: 50k concurrent/pod, 500k/city.
- **Fan-out pub/sub:** Redis streams per channel; consumer coalesces location frames (max 1/sec per viewer).
- **Graceful drain:** on deploy, broadcast `reconnect` hint; clients rejoin via ticket.

---

## 24. Event Taxonomy (Kafka Topic Catalog)

All events use CloudEvents envelope + Avro/Protobuf payload, registered in a schema registry. Topic keys drive partitioning for ordering within an entity.

| Topic | Key | Producers | Consumers | Retention |
|-------|-----|-----------|-----------|-----------|
| `identity.user.created` | user_id | identity | fraud, notification, lake | 30 d |
| `identity.user.updated` | user_id | identity | lake, search | 7 d |
| `driver.status.changed` | driver_id | driver | dispatch, ops | 7 d |
| `location.driver.updates.<city>` | driver_id | ingest | dispatch, location-history | 72 h |
| `ride.requested` | trip_id | ride | dispatch, pricing, fraud | 30 d |
| `ride.matched` | trip_id | dispatch | notification, rider, driver | 30 d |
| `ride.started` / `ride.completed` | trip_id | ride | payment, rating, lake | 30 d |
| `ride.cancelled` | trip_id | ride | notification, fraud, lake | 30 d |
| `food.order.placed` | order_id | food | restaurant, dispatch, fraud | 30 d |
| `food.order.status.changed` | order_id | food | rider WS, lake | 30 d |
| `courier.shipment.created` | shipment_id | courier | hub, notification, lake | 90 d |
| `courier.scan.recorded` | shipment_id | hub | courier, merchant webhooks | 90 d |
| `courier.manifest.dispatched` / `.received` | manifest_id | hub | courier, SLA monitor | 90 d |
| `cod.collected` | shipment_id | courier | remittance, ledger | 2 y |
| `remittance.driver.closed` | bag_id | hub | ledger, finance | 7 y |
| `remittance.hub.deposited` | deposit_id | hub | ledger, finance | 7 y |
| `payment.intent.created` / `.captured` / `.failed` | intent_id | payment | ledger, fraud, notification | 30 d |
| `ledger.entry.posted` | txn_id | ledger | analytics | 7 y (compact) |
| `merchant.shipment.webhook.queued` | shipment_id | courier | webhook-dispatcher | 7 d |
| `fraud.signal.raised` | subject_id | fraud | admin, notification | 180 d |
| `sos.events` | user_id | safety | on-call, ops | 2 y |
| `audit.events` | entity_id | all | lake | 7 y (compact) |

- Partition count sized for 3x current peak throughput; rebalance runbook in §26.
- **Compaction** enabled where the key's latest state is the useful view (`ledger.entry.posted`, `audit.events`).
- **Schema evolution:** backward-compatible; breaking change requires new topic suffix `-v2`.

---

## 25. Error Code Catalog & API Versioning

### 25.1 Error envelope (RFC 7807)

```json
{
  "type":   "https://errors.superapp.example/ride/no-drivers-nearby",
  "title":  "No drivers available",
  "status": 503,
  "detail": "No eligible drivers within 12 km for vehicle_type=car",
  "instance": "/v1/rides",
  "code":   "RIDE_NO_DRIVERS",
  "request_id": "req_01HZ...",
  "trace_id":   "0af7651916cd43dd..."
}
```

### 25.2 Canonical codes (excerpt)

| Domain | Code | HTTP | Retry? |
|--------|------|------|--------|
| Auth | `AUTH_OTP_INVALID` | 401 | No |
| Auth | `AUTH_OTP_THROTTLED` | 429 | After Retry-After |
| Auth | `AUTH_DEVICE_UNTRUSTED` | 403 | No |
| Ride | `RIDE_NO_DRIVERS` | 503 | Yes, with backoff |
| Ride | `RIDE_NOT_CANCELLABLE` | 409 | No |
| Ride | `RIDE_INVALID_VEHICLE` | 400 | No |
| Food | `FOOD_STORE_CLOSED` | 409 | No |
| Food | `FOOD_ITEM_UNAVAILABLE` | 409 | No (refresh cart) |
| Courier | `COURIER_LANE_UNSUPPORTED` | 400 | No |
| Courier | `COURIER_AWB_DUPLICATE` | 409 | Idempotency replay ok |
| Hub | `HUB_SCAN_OUT_OF_ORDER` | 409 | No |
| Payment | `PAY_DECLINED` | 402 | No |
| Payment | `PAY_IDEMPOTENCY_CONFLICT` | 409 | No (same key, diff body) |
| Payment | `PAY_PROVIDER_TIMEOUT` | 504 | Yes, same Idempotency-Key |
| Generic | `RATE_LIMITED` | 429 | After Retry-After |
| Generic | `VALIDATION_FAILED` | 422 | No |
| Generic | `INTERNAL` | 500 | Yes, bounded |

Full list maintained in a machine-readable YAML alongside the OpenAPI spec.

### 25.3 API versioning & deprecation

- URL-based major version: `/v1/...`, `/v2/...` when breaking.
- Additive changes on same major (new fields, new endpoints) do **not** bump.
- `Sunset` header on deprecated endpoints with date (RFC 8594).
- Minimum **6-month** overlap between versions; clients notified via dashboard + email.
- Contract tests (Pact) in CI for critical consumer-producer pairs.
- Mobile apps negotiate via `X-Client-Version`; gateway may serve shims.

---

## 26. Deployment, CI/CD & SRE Runbooks

### 26.1 Topology

- **Kubernetes** on managed cloud (EKS / GKE) + bare-metal hub edge boxes.
- Namespaces: `platform-*` (shared), `svc-*` (per microservice), `bff-*`, `data-*`, `ops-*`.
- **Cells:** each city gets an isolated data-plane cell (own WS cluster, own Redis-geo, own DB read-replicas); control-plane shared.
- **Service mesh:** Istio with mTLS STRICT, AuthorizationPolicies per service.
- **Ingress:** Kong at the edge; Envoy sidecars internally.
- Node pools: `general`, `memory` (cache), `cpu-burst` (ingest), `spot` (batch/ETL).
- **HPA** on CPU + custom (Kafka lag, WS connections). **PDBs** ≥ 1 for every Deployment. **PodAntiAffinity** across zones.

### 26.2 Environments

| Env | Purpose | Data |
|-----|---------|------|
| dev | feature branches | ephemeral, synthetic |
| staging | pre-prod integ | anonymised prod snapshot (opt-in) |
| canary | 1% prod traffic | real |
| prod | full traffic | real |
| dr | warm standby in second region | replicated |

### 26.3 CI/CD

- **CI:** GitHub Actions / GitLab — lint, unit, integration, container build, SBOM, CVE scan (Trivy), signed image (Cosign/Sigstore).
- **CD:** ArgoCD GitOps; Helm charts per service; Kustomize overlays per env.
- **Release strategy:**
  1. Canary 1% → 5% → 25% → 100% with SLO burn-rate gates (auto-rollback on regression).
  2. Feature flags gate product changes independent of deploy.
- **DB migrations:** expand-contract; online; gated by `MIGRATION_SAFE=true` in CI; never destructive in same release as code.
- **Rollback SLA:** < 10 min to full previous version via ArgoCD.

### 26.4 Secrets & keys

- **Vault** (HashiCorp) or cloud KMS + Secrets Manager. Apps pull via sidecar (no file secrets).
- **Rotation:** JWT signing 90 d, DB passwords 90 d, API keys (merchant) on-demand, KMS DEKs versioned.
- **Break-glass:** two-person sealed envelope + Vault root tokens audited.

### 26.5 Load & chaos testing

- **Load:** k6 + Gatling; baseline and peak scenarios per service monthly.
- Scenarios: Friday-rush ride surge, festival food burst, merchant bulk upload, hub cut-off rush, payment provider slow-down.
- **Pass/fail:** p99 within NFR, error rate < 0.1%, no DB connection exhaustion.
- **Chaos:** Litmus/Gremlin; monthly game-day; failure modes: node drain, AZ down, DB failover, Redis eviction, Kafka broker loss, payment provider 500s.

### 26.6 Runbooks (titles)

Every runbook in Git with ownership, on-call escalation, diagnostic queries, mitigation steps.

| ID | Title |
|----|-------|
| RB-01 | Payment provider outage — failover to secondary |
| RB-02 | Dispatch match rate drop / scoring drift |
| RB-03 | Redis-geo cluster failure (per city) |
| RB-04 | WS mass-disconnect / reconnect storm |
| RB-05 | Kafka consumer lag spike |
| RB-06 | Ledger invariant violation detected |
| RB-07 | COD drift > 0.1% daily |
| RB-08 | Hub offline — paper fallback & sync |
| RB-09 | Map provider quota exhaustion |
| RB-10 | Surge runaway / price cap breach |
| RB-11 | OTP provider failure — switch aggregator |
| RB-12 | KYC vendor outage — grace-period policy |
| RB-13 | Data-plane region failover |
| RB-14 | Mass password/token compromise response |
| RB-15 | Fraud model false-positive spike |
| RB-16 | Mobile push notification storm |

---

## 27. Integrations & Compliance Matrix

### 27.1 Third-party integrations

| Area | Primary | Secondary | Notes |
|------|---------|-----------|-------|
| Payments | bKash, Nagad, Rocket | Stripe / Adyen | Tokenized; 3DS where applicable; settlement file reconciled daily |
| Cards | Network (Visa/MC) via Adyen | Local PG | PCI-DSS SAQ-A via tokenization |
| Maps & geocoding | Google Maps | Mapbox, HERE | Per-city failover; client-side + server-side quotas |
| Routing / ETA | OSRM self-hosted | Valhalla | Mapbox Directions for edge cases |
| SMS | Twilio | MessageBird, local aggregator | OTP deliverability > 99% target |
| Voice/IVR | Twilio | Exotel | Masked call proxy |
| Push | APNs, FCM, HMS | — | HMS required for Huawei markets |
| Email | SES | SendGrid | DKIM/SPF/DMARC enforced |
| WhatsApp | Meta Cloud API | 360dialog | Template approval pipeline |
| KYC (ID + liveness) | Onfido / SumSub | HyperVerge | PEP + sanctions screening |
| Background checks | Checkr equivalent | Local vendor | 7-day SLA for driver onboarding |
| Fraud signals | Sift / Forter | Internal | Shadow mode before enforcement |
| Device attestation | Play Integrity, App Attest | — | Required for driver/hub finance |
| Analytics | Amplitude / Mixpanel | Internal lake | PII redaction at SDK layer |
| Crash / RUM | Sentry, Crashlytics | — | Source maps, ProGuard mappings uploaded |
| CRM / marketing | Braze / CleverTap | — | Governed by consent service |
| Tax / invoicing | Local tax API | Manual fallback | GST/VAT compliant PDFs |
| Ad-tech (sponsored) | Internal | — | Budget caps, IAB transparency |

Each integration requires: contract, SLA, credentials in Vault, failover runbook, usage dashboard, cost alert.

### 27.2 Regulatory / compliance matrix (per country)

| Axis | Bangladesh | India | UAE | Generic |
|------|-----------|-------|-----|---------|
| Ride-hailing license | BRTA permit | State transport dept | RTA | Local transport regulator |
| Courier license | Postal regulator | India Post / state | TDRA | National postal/logistics regulator |
| Payments | Bangladesh Bank PSO/PSP | RBI PA/PG | CBUAE | Local central bank |
| Data protection | DSA law / DPA draft | DPDP Act 2023 | UAE PDPL | GDPR analogue |
| Tax | VAT 15% / TIN | GST (CGST/SGST/IGST) | VAT 5% | Local |
| Driver classification | contractor (default) | contractor / Platform workers code | contractor | Country-specific legal review |
| Insurance | 3rd-party motor | Motor + passenger | RTA mandated | Commercial motor + rider cover |
| KYC tier | NID + selfie | Aadhaar + PAN tiered | Emirates ID | Per local FIU |
| Storage residency | In-country preferred | In-country (sensitive) | In-country | Regional |

### 27.3 Legal registers maintained

- Processor records (Art. 30 GDPR analogue)
- Sub-processor list (public page)
- Data Processing Agreements with every processor
- DPIAs for high-risk flows (driver onboarding, fraud scoring, location history)
- Breach notification playbook (< 72 h where required)
- T&C / Privacy / Driver Agreement versioning with re-accept enforcement

### 27.4 Accessibility

- **WCAG 2.1 AA** target for all web panels (Admin, Merchant, Restaurant, public tracking page).
- Mobile: Dynamic Type, TalkBack/VoiceOver labels, 44x44 dp tap targets, contrast ≥ 4.5:1.
- Quarterly audit; issues tracked as P1 if blocking.

### 27.5 Content moderation

- Chat / voice notes: automated toxicity + abusive-language filter; human review queue for safety flags.
- Reviews: auto-reject profanity; owner reply with 1 edit.
- Menu / store images: provider auto-moderation (NSFW, violence) + human sampling.
- Appeals process documented; SLA 48 h.

---

## 28. Capacity, Cost & Scale Model

### 28.1 Reference scale (illustrative — first-year plan)

| Metric | Target |
|--------|--------|
| MAU (rider) | 10 M |
| DAU (rider) | 1.2 M |
| Active drivers (daily) | 120 k |
| Trips / day (ride) | 900 k |
| Food orders / day | 500 k |
| Courier shipments / day | 250 k (peak festival 1 M) |
| Concurrent WS connections | 400 k peak |
| Location frames / sec | 60 k sustained, 100 k peak |
| Payment txns / sec | 400 peak |
| Hub scans / sec | 1.5 k peak (festival) |

### 28.2 Data growth

| Store | Daily write | 1 y size (est.) |
|-------|-------------|-----------------|
| Postgres (trips/orders/shipments partitioned) | 30 GB | 10 TB + indexes |
| MongoDB (menu, catalog) | 1 GB | 300 GB |
| Redis geo + session + cache | RAM-sized | 200–500 GB RAM |
| Cassandra location_history | 400 GB | 60 TB (180 d TTL) |
| Cassandra chat | 20 GB | 3.5 TB |
| Elasticsearch | 15 GB | 3 TB hot, roll to warm |
| S3 (images, docs, scans, exports) | 200 GB | 60 TB |
| Kafka | ~1 TB retained rolling | — |

### 28.3 Node / pod sizing (rule-of-thumb per cell)

| Service | Replicas | CPU | Mem |
|---------|---------:|----:|----:|
| api-gateway (Kong) | 8 | 2 | 2 Gi |
| bff-rider / driver | 8 / 12 | 1 | 1 Gi |
| identity | 6 | 1 | 1 Gi |
| ride | 8 | 2 | 2 Gi |
| food / courier / hub | 6 each | 2 | 2 Gi |
| dispatch (Temporal workers) | 20 | 2 | 4 Gi |
| location-ingest | 12 | 2 | 2 Gi |
| ws-gateway | 16 | 2 | 4 Gi |
| payment | 6 | 1 | 2 Gi |
| ledger | 4 | 2 | 4 Gi |
| notification | 8 | 1 | 1 Gi |
| search (ES client) | 4 | 1 | 2 Gi |

Autoscaling: min = 50% peak, max = 200% peak, scale-up aggressive (60 s), scale-down gradual (5 min).

### 28.4 Cost control

- **Per-service monthly budget** with alert at 70% / 90%.
- Spot/pre-emptible nodes for batch, ETL, ML training (never on critical path).
- Cache-first API design to reduce DB / 3rd-party cost (maps, SMS).
- CDN for images, receipts, public tracking pages.
- Daily FinOps review; showback per team; kill-switch on runaway campaigns.
- Provider cost caps: maps quota per city/day, SMS spend per campaign, push fan-out per user.

### 28.5 Headroom

- All clusters provisioned at **2×** current peak; horizontal scale rehearsed quarterly.
- DB sharding plan drafted (by city then by user-id range) — activated when single-region write load > 60% ceiling.

---

## 29. Panel Design Diagrams

One diagram per panel, each showing: **(A)** user screens/flows, **(B)** what the panel calls in the backend, **(C)** which data stores and events are touched, **(D)** who it talks to in real time.

Legend used in every diagram:
```
[UI]         = app / tablet / web screen
(API)        = REST endpoint hit
<WS>         = WebSocket channel
{{Service}}  = microservice
[[Store]]    = database / cache
«Kafka»      = event topic
→            = synchronous call
⇝            = async / event
```

---

### 29.1 🧑 Rider Panel — how it works

**Who:** passengers / food buyers / parcel senders. **Device:** mobile app.
**Mental model:** "I open the app → pick a service → book → watch it happen live → pay → rate."

```
┌──────────────────────────────  RIDER APP (iOS / Android)  ────────────────────────────┐
│                                                                                         │
│  [Home]──[Search/Discover]──[Cart]──[Checkout]──[Live Track]──[Rate/Pay]──[History]    │
│     │         │               │        │             │           │         │        │
│     │ services tabs                                                                   │
│     ├── 🚗 Ride   → (POST /rides/estimate) → (POST /rides)                            │
│     ├── 🍴 Food   → (GET /food/stores) → (POST /food/orders)                           │
│     ├── 📦 Parcel → (POST /parcels/quote) → (POST /parcels)                            │
│     └── 🚚 Courier→ (POST /courier/quote) → (POST /courier/shipments)                 │
│                                                                                         │
│   Live tracking:  <WS trip.{id}> | <WS order.{id}> | <WS shipment.{awb}>                │
│   Safety:         [SOS] → (POST /safety/sos) ⇝ «sos.events»                             │
│   Wallet/Pay:     (POST /payments/intents) → provider 3DS → capture                    │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
                                          │ HTTPS + WSS (ticket auth)
                                          ▼
                         ┌─────────────────────────────────┐
                         │   API Gateway ───── bff-rider  │
                         └──────────┬──────────────┬─────────┘
                                    │                │
       ┌─────────────┬────────────┴─────────────────┴──────────────────────┐
       ▼             ▼                 ▼                  ▼                        ▼
  {{Identity}}   {{Ride}}→«ride.*»   {{Food}}→«food.*»   {{Courier}}→«courier.*»     {{Payment}}
                 ↓                   ↓                   ↓                        ↓
            {{Dispatch}}          {{Restaurant}}        {{Hub}}                {{Wallet/Ledger}}
                 ↓                   ↓                   ↓                        ↓
            [[Redis-geo]]         [[Mongo menu]]     [[PG courier_*]]           [[PG ledger]]
            [[PG trips]]                                                       + {{Fraud}}
```

**Happy path — request a ride:**
1. Rider picks pickup + drop → app calls `POST /rides/estimate` → gets price & ETA.
2. Rider confirms → `POST /rides` with `Idempotency-Key` → `Ride Service` writes `trips` row, emits `ride.requested`.
3. `Dispatch` reads Redis-geo, scores drivers, offers the best one (see §23.1).
4. Rider app opens `<WS trip.{id}>`; receives `trip.matched` then `trip.driver_location` every 2 s.
5. Trip ends → `Payment` captures prepaid or driver collects cash → `Ledger` posts → rider rates.

---

### 29.2 🚗 Driver Panel — how it works

**Who:** bike / auto / car / truck drivers. **Device:** mobile app (device-bound).
**Mental model:** "I go online → I get an offer → I accept → I navigate & deliver → I get paid."

```
┌─────────────────────────────  DRIVER APP (device-attested)  ────────────────────────┐
│                                                                                         │
│  [Onboarding/KYC]──[Online toggle]──[Heatmap]──[Offer popup]                           │
│           │                │             │            │ accept/reject (8s)            │
│           │                │             │            ▼                               │
│           │                │             │     [Nav → Arrived → Start → End]            │
│           │                │             │            │                               │
│           │                │             │     [Collect cash? OTP? Photo proof?]        │
│           │                │             │            │                               │
│           │                │             │     [Earnings → Payouts → Ratings]          │
│                                                                                         │
│  (POST /driver/status)  → online/offline                                                │
│  <WS location> @ 1 frame / 2 s  → ingest → «location.driver.updates.<city>»             │
│  <WS offers>   → "offer" frame (TTL 8 s) → (POST /driver/offers/{id}/accept)            │
│  (POST /driver/trips/{id}/{arrived|start|complete|cancel|collect-cash})                 │
│  Courier:  /driver/courier/first-mile/{awb}/pickup + /last-mile/{awb}/deliver           │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼  API Gateway ─── bff-driver
        ┌─────────────────────────────────────────────────────────────────┐
        │                                                                               │
        ▼                  ▼                 ▼                    ▼                    ▼
   {{Location          {{Dispatch}}        {{Ride/Food        {{Courier}}           {{Payout}}
     Ingest}}              ↓               /Parcel}}              ↓                    ↓
        ↓             [[Redis-geo]]            ↓           {{Hub}} handover      {{Ledger}}
  [[Cassandra          [[PG trips]]        «ride.completed»   [[PG shipments]]
  location_history]]                                          [[PG scans]]
```

**Happy path — accept & run a ride:**
1. Driver goes online → `POST /driver/status` → added to `redis-geo-<city>`.
2. App opens `<WS>` and starts streaming location frames.
3. Dispatch scores & sends an offer → driver accepts within 8 s.
4. App walks through Arrived → Start → End; fare meter + location updates go to rider WS.
5. If cash: driver taps **Collect cash** → ledger posts cash → driver.float.
6. Daily/weekly earnings aggregated; auto payout on Monday.

---

### 29.3 🍴 Restaurant Panel — how it works

**Who:** restaurant owner + kitchen staff. **Device:** tablet with KDS + web for owner.
**Mental model:** "Order lands → I accept with prep time → I cook → I mark ready → driver picks up."

```
┌───────────────────────────  RESTAURANT PANEL  ──────────────────────────────────┐
│                                                                                         │
│   KDS (tablet)                              Web console (owner)                         │
│  ┌─────────────────────────────────┐    ┌───────────────────────────────┐           │
│  │ New order 🔔 (60-s accept window) │    │ Menu CRUD / 86-list / stock │           │
│  │  ├ Accept  → prep_time_min       │    │ Outlets / hours / holidays  │           │
│  │  ├ Reject  → reason              │    │ Promos / sponsored ads      │           │
│  │  └ Ready   → notifies dispatch   │    │ Analytics / payouts         │           │
│  └─────────────────────────────────┘    └───────────────────────────────┘           │
│       │ <WS outlet.{outlet_id}>                                                          │
│       └─ order.new / order.cancelled_by_customer                                        │
│                                                                                         │
│  (POST /restaurant/orders/{id}/accept | reject | ready)                                 │
│  (POST /restaurant/menu/items, PATCH /{id})  (POST /restaurant/promos)                   │
│  (POST /restaurant/outlets/{id}/toggle-open)   auto-print ESC/POS receipt               │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼   API Gateway ─── bff-restaurant
  ┌────────────────────────────────────────────────────────────────────┐
  │  {{Restaurant}}     {{Food}}    {{Dispatch}}   {{Search/ES}}   {{Ads}}          │
  │        │                 │            │              │             │          │
  │   [[PG restaurants]]  «food.*»   offers drivers   index:stores   budget cap   │
  │   [[Mongo menu]]                                                               │
  └────────────────────────────────────────────────────────────────────┘
```

**Happy path — accept an order:**
1. Customer places order → `food.order.placed` → outlet's KDS receives `order.new` on WS with sound/vibration.
2. Staff taps **Accept**, enters prep time (e.g. 25 min) → dispatch times driver arrival for pickup.
3. On "Ready" → driver notified → picks up → delivered → payout added to weekly statement.

---

### 29.4 🏪 Merchant Panel — how it works

**Who:** retailers, e-commerce sellers, bulk shippers. **Device:** web dashboard + REST API.
**Mental model:** "I print labels for my orders, a rider picks them up, they arrive, COD money comes back."

```
┌─────────────────────────────  MERCHANT PANEL (Web + API)  ───────────────────────────┐
│                                                                                         │
│  [Dashboard]   [Shipments]   [Bulk Upload CSV]   [COD Reports]   [Payouts]   [API Keys] │
│      │             │                │                  │             │          │    │
│  Book single:   Async batch:        Track:             Remittance:      Weekly:         │
│  (POST /merchant/shipments)         (GET /merchant/shipments/{awb})    (GET /payouts)   │
│  (POST /merchant/shipments/bulk) → batch_id → (GET /bulk/{id})                          │
│  (GET  /merchant/shipments/{awb}/label) → PDF (A5/A6, QR)                                │
│                                                                                         │
│  Integrations:  Shopify / WooCommerce / Magento plugins (OAuth)                         │
│  Webhooks to merchant URL:  shipment.created / picked_up / delivered / exception / rto  │
│                 (HMAC-signed; retry 1m,5m,30m,2h,12h,24h × 3 → DLQ)                     │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
      │  Bearer JWT  /  API key (IP allow-list)
      ▼
   API Gateway ─── bff-merchant
      │
      ├─▶ {{Courier}} ──├─▶ {{Pricing}} (rate card + slab)
      │                ├─▶ [[PG courier_shipments]] + awb_index
      │                └⇝ «courier.shipment.created»
      ├─▶ {{Hub}}     ── pickup assignment / first-mile
      ├─▶ {{Payment/Ledger}} ── COD remittance + weekly payout
      └─▶ {{Webhook-dispatcher}} ⇝ merchant URL (signed)

Lifecycle a merchant sees:
  created → picked_up → at_origin_hub → in_transit → at_dest_hub
         → out_for_delivery → delivered (COD?)  → settled / paid out
```

**Happy path — e-commerce seller with 50 orders:**
1. Seller uploads CSV → `POST /merchant/shipments/bulk` → batch_id.
2. Async worker creates 50 shipments, emits `courier.shipment.created × 50`, generates AWBs.
3. Seller downloads bulk label PDF, sticks on parcels, schedules pickup.
4. First-mile driver picks up → hub scan-in → line-haul → delivery.
5. Webhooks fire at each milestone; COD collected → merchant weekly payout.

---

### 29.5 🏭 Hub Panel — how it works

**Who:** hub clerk, supervisor, finance, manager. **Device:** rugged tablet with scanner + web console.
**Mental model:** "Parcels come in → I scan → I sort → I manifest them onto a truck → they arrive at dest hub → last-mile rider delivers → cash comes back → I deposit."

```
┌──────────────────────────  HUB PANEL (tablet + web)  ───────────────────────────────┐
│ Login (email + MFA)  |  Role: clerk | supervisor | finance | manager                   │
│                                                                                         │
│   CLERK                SUPERVISOR                 FINANCE (MFA+device)                 │
│  [Scan-in bag] ▶   [Create manifest]          [Close driver COD bag]                   │
│  [Sort to cage] ▶   [Add AWBs to manifest]    [Record bank deposit]                    │
│  [Hand over to LM] ▶ [Dispatch (seal #)]       [Reconcile vs slip]                     │
│  [File exception]    [Receive inbound truck]    [View hub float]                        │
│       📏 damage photo  [Reconcile manifest]                                              │
│                                                                                         │
│ Offline-first:  scans queue in IndexedDB → flush (POST /hub/scans/bulk)                 │
│                                                                                         │
│ Real-time channel <WS hub.{hub_id}>:                                                    │
│   manifest.incoming  •  sla.breach  •  exception.flagged                                │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
                │  API Gateway ── bff-hub
                ▼
          {{Hub Service}} ── {{Courier}} ── {{COD/Remittance}} ── {{Ledger}}
                │                                   │
          [[PG scans (partitioned)]]           [[PG cod_collections]]
          [[PG manifests]]                     [[PG ledger_entries]]
          ⇝ «courier.scan.recorded»           ⇝ «remittance.*»
          ⇝ «courier.manifest.dispatched»
          ⇝ «courier.manifest.received»

Physical ↔ digital mapping:
  [TRUCK+MANIFEST+SEAL]  ↔  manifests row (open → dispatched → received → reconciled)
  [BAG QR]               ↔  bag_id linking many AWBs (1-scan handover)
  [CAGE #17]             ↔  sort-code on label + cage/location map
  [CCTV cam-08 @ 09:13]  ↔  scan.cctv_ref on every scan (for disputes)
```

**Happy path — a shipment transits Dhaka → Chattogram:**
1. First-mile driver hands bag to clerk → clerk scans AWBs (`scan_type=hub_inbound`).
2. Sort step: label's sort-code maps to cage for DAC→CTG line-haul.
3. Supervisor creates manifest, attaches AWBs, records truck + seal, dispatches.
4. Destination hub receives truck, scans seal + each AWB; mismatches → exception.
5. Last-mile rider takes handover scan → delivers → returns cash → finance closes bag → hub deposits to bank (ledger entries at every step).

---

### 29.6 👨‍💼 Admin Panel — how it works

**Who:** operations, finance, safety, support, compliance. **Device:** web, VPN + MFA.
**Mental model:** "I see everything live, I approve/block, I tune pricing and rules, I resolve disputes, I run the business."

```
┌─────────────────────────────  ADMIN PANEL (Web, VPN, WebAuthn)  ─────────────────────┐
│                                                                                         │
│  [Dashboard / Live Ops Map]    [KYC queues]         [Fraud signals]                    │
│   • active drivers/trips        • Driver / Rest./   • velocity / device / GPS          │
│   • SLA & hub capacity           Merchant / Hub-staff • rules + ML shadow/enforced      │
│   • SOS alerts 🚨                                                                         │
│                                                                                         │
│  [Pricing & Zones]   [Promos]    [Support inbox]     [Disputes / Refunds]              │
│   • fares/surge/lanes   % / flat   • tickets P0–P3     • 4-eyes above threshold          │
│   • geofence editor     • segmented • 360° user view    • ledger reversal                │
│                                                                                         │
│  [Reports / Exports]  [Config]     [Staff RBAC]    [Audit Log]    [Feature Flags / A/B]│
│                                                                                         │
│  Real-time <WS ops.global / ops.{city}>:  live map, fraud alerts, SOS                   │
│  All writes audited: audit_log (append-only, signed, 7-y retention)                    │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
     │   API Gateway ── bff-admin  (role-scoped; city-scoped where applicable)
     ▼
 ┌─────────────────────────────────────────────────────────────────────────┐
 │ Read-only fan-out across ALL services to compose 360° views:                            │
 │ {{Identity}} {{Ride}} {{Food}} {{Courier}} {{Hub}} {{Payment/Ledger}} {{Fraud}} ...    │
 │                                                                                        │
 │ Writes are narrow & audited:                                                           │
 │  • KYC approve/reject    →  {{Identity}} / {{Driver}} / {{Merchant}} / {{Restaurant}}   │
 │  • Suspend / unblock    →  target service + audit                                      │
 │  • Refund / wallet adj. →  {{Ledger}} (idempotent reversal, 4-eyes > threshold)         │
 │  • Pricing / surge      →  {{Config/Pricing}} (versioned, effective_from)                │
 │  • Feature flags        →  {{Config}} (per-city / cohort)                                │
 └─────────────────────────────────────────────────────────────────────────┘

Every admin write emits «audit.events» → compacted topic → lake, 7-year retention.
```

**Happy path — approve a new driver:**
1. Ops opens KYC queue → reviews docs + background check result → **Approve**.
2. Admin API calls `{{Driver}}` to flip status; change logged in `audit_log` with actor, IP, reason.
3. Driver receives push notification; can now go online in their app.

**Another path — city surge runaway:**
1. Alert on dashboard: surge > 2.5x for > 30 min in a zone.
2. Ops opens **Pricing** → applies **Surge override** (temporary cap) with expiry 60 min.
3. Config versioned; pricing engine picks up at next 60-s tick; audit log records the change.

---

### 29.7 Cross-panel interaction map (one picture)

So everyone can see who talks to whom at runtime:

```
  🧑 Rider          🚗 Driver         🍴 Restaurant      🏪 Merchant      🏭 Hub         👨‍💼 Admin
     │                 │                 │                │              │               │
     │ request ride    │                 │                │              │               │
     ───────────────▶ offered ─────▶                 │              │               │
     │                 │                 │                │              │               │
     │ order food ──────────────────────────▶ accept + prep ───────────────────────────▶
     │                 │                 │ ready          │              │               │
     │                 ◀─ pickup offer ──┤                │              │               │
     │ delivered ◀─────┤                 │                │              │               │
     │                 │                 │                │              │               │
     │                 │                 │  bulk label ───▶ PDF         │               │
     │                 ◀─ first-mile  ─────────────────◀ pickup    ─▶ scan-in      │
     │                 │                 │                │              ├─ manifest     │
     │                 │                 │                │              │   line-haul   │
     │                 ◀─ last-mile ───────────────────────────◀ handover    │
     │ delivered + COD → ledger ────────────────▶ payout    ◀ cash close  ─▶ KPIs         │
     │                 │                 │                │              │               │
     └───────────────── support ticket ticket ───────────────────────────────▶ resolve
                        │                                                        │
                        └─ doc expiry / fraud signal / SLA breach ──────────────▶ action

Everything passes through: API Gateway → BFF → Service → (DB | Cache | Kafka event).
```

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

*Document version: 1.3 — April 21, 2026 — added §29 Panel Design Diagrams: one ASCII diagram per panel (Rider, Driver, Restaurant, Merchant, Hub, Admin) showing screens, API calls, services, stores, events and real-time channels, plus a cross-panel interaction map.*
