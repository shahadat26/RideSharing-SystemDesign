# 01 — Features List (Product Architect Agent)

**Product:** Super App (Ride Sharing + Food Delivery + Parcel/Courier)
**Inspiration:** Pathao / Uber / Grab
**Author:** Senior Product Architect

---

## 1. User Roles

1. **Customer** — books rides, orders food, sends parcels.
2. **Driver / Rider** — fulfills rides, food deliveries, parcel deliveries (modes may be separate: Car, Bike, Truck).
3. **Merchant (Restaurant / Store Owner)** — manages menu/inventory and accepts/rejects orders.
4. **Admin / Operations** — platform governance, KYC, fraud, dispute resolution, pricing, analytics.

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
| C14 | Parcel: send package with pickup/drop | ✅ | Size/weight tiers |
| C15 | Promo codes & referrals | ✅ | |
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
| D9 | Accept multi-service (ride + food + parcel) | ✅ | Per driver capability |
| D10 | Document expiry reminders | ✅ | |
| D11 | Incentives / quest tracker | 🟡 | |
| D12 | Driver tiers & priority dispatch | 🟡 | |
| D13 | Training modules | 🟡 | |

### 2.3 Merchant (Restaurant / Store)

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| M1 | Merchant onboarding + KYC | ✅ | 🔒 |
| M2 | Menu/inventory CRUD + item availability toggle | ✅ | |
| M3 | Incoming order dashboard (tablet app) | ✅ | |
| M4 | Accept/reject + prep-time update | ✅ | |
| M5 | Auto-print receipt | ✅ | |
| M6 | Daily payout report | ✅ | |
| M7 | Promotions/coupons self-service | 🟡 | |
| M8 | Analytics (top items, peak hours) | 🟡 | |
| M9 | Loyalty/sub-brand pages | 🟡 | |

### 2.4 Admin / Ops

| # | Feature | Priority | Notes |
|---|---------|----------|-------|
| A1 | User/driver/merchant CRUD + suspend | ✅ | |
| A2 | KYC approval queue | ✅ | 🔒 |
| A3 | Live ops map (active drivers/orders) | ✅ | |
| A4 | Dispute/refund console | ✅ | |
| A5 | Fraud detection rules + alerts | ✅ | 🔒 |
| A6 | Pricing/surge config per city/zone | ✅ | |
| A7 | Zone & geo-fence management | ✅ | |
| A8 | Financial reconciliation & reports | ✅ | |
| A9 | Marketing/promo campaign console | 🟡 | |
| A10 | A/B experiment platform | 🟡 | |
| A11 | ML model monitoring (matching/ETA) | 🟡 | |

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
