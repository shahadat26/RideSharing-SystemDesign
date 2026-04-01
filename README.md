# 🚗 Ride Sharing Application - Complete System Design
## Like UBER | OLA | Rapido | Lyft

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [System Panels](#system-panels)
3. [Business Logic & Features](#business-logic--features)
   - [Rider Panel Features](#-rider-panel-features)
   - [Driver Panel Features](#-driver-panel-features)
   - [Admin Panel Features](#-admin-panel-features)
4. [Complete API Documentation](#complete-api-documentation)
5. [Database Design](#database-design)
6. [System Architecture](#system-architecture)
7. [Core Workflows](#core-workflows)
8. [💰 Complete Payment System](#-complete-payment-system-like-uberola)
9. [🛡️ Fraud Detection System](#️-fraud-detection-system)
10. [🆘 Safety Features](#-safety-features)
11. [📍 Geo-Fencing System](#-geo-fencing-system)
12. [💬 In-Trip Chat System](#-in-trip-chat-system)
13. [📋 Audit & Compliance (GDPR)](#-audit--compliance-gdpr)
14. [Non-Functional Requirements](#non-functional-requirements)

---

## Project Overview

A complete ride-sharing platform connecting **Riders** with **Drivers**, managed by **Admins**. The system enables on-demand transportation services with real-time tracking, dynamic pricing, secure payments, and comprehensive analytics.

### Core Flow
```
Rider requests ride → System finds nearby drivers → Driver accepts → 
Real-time tracking → Trip completion → Payment processing → Ratings
```

### Three System Panels

| Panel | Users | Purpose |
|-------|-------|---------|
| **🧑 Rider App** | Passengers | Book rides, track drivers, make payments, rate trips |
| **🚗 Driver App** | Drivers | Accept rides, navigate, earn money, manage availability |
| **👨‍💼 Admin Dashboard** | Operations Team | Manage users, drivers, fares, analytics, support |

---

## System Panels

### Panel Architecture
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           RIDE SHARING PLATFORM                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐               │
│  │   RIDER APP      │  │   DRIVER APP     │  │  ADMIN DASHBOARD │               │
│  │   (Mobile)       │  │   (Mobile)       │  │  (Web)           │               │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤               │
│  │ • Book Rides     │  │ • Accept Rides   │  │ • User Mgmt      │               │
│  │ • Track Driver   │  │ • Navigate       │  │ • Driver Mgmt    │               │
│  │ • Make Payment   │  │ • Earn Money     │  │ • Fare Config    │               │
│  │ • Rate Trips     │  │ • View Earnings  │  │ • Analytics      │               │
│  │ • Ride History   │  │ • Go Online/Off  │  │ • Support        │               │
│  │ • Save Places    │  │ • Documents      │  │ • Promotions     │               │
│  │ • Promo Codes    │  │ • Ratings        │  │ • Reports        │               │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘               │
│           │                     │                     │                          │
│           └─────────────────────┼─────────────────────┘                          │
│                                 ▼                                                │
│                    ┌──────────────────────┐                                     │
│                    │   BACKEND SERVICES   │                                     │
│                    │   (API + Database)   │                                     │
│                    └──────────────────────┘                                     │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Business Logic & Features

---

## 🧑 Rider Panel Features

### 1. Authentication & Profile

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Sign Up** | Register via phone/email | OTP verification required, phone must be unique |
| **Login** | Phone OTP or Social login | JWT token issued, refresh token for session |
| **Profile Management** | Update name, photo, email | Email change requires verification |
| **Phone Change** | Update phone number | OTP verification on new number, invalidate old sessions |
| **Delete Account** | GDPR compliance | Soft delete, data retained 30 days, active rides blocked |

### 2. Home & Search

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Home Screen** | Map with current location | Request location permission, show nearby drivers |
| **Search Destination** | Autocomplete places search | Google Places API, recent searches cached |
| **Pick Location on Map** | Select pickup/drop on map | Reverse geocoding to get address |
| **Saved Places** | Home, Work, Favorites | Max 10 saved places per user |
| **Recent Locations** | Last 20 searches | Auto-cleared after 30 days |

### 3. Ride Booking

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Fare Estimation** | Show price before booking | `base_fare + (distance × rate) + (time × rate) × surge` |
| **Vehicle Selection** | Sedan, SUV, Bike, Auto, Pool | Different pricing per vehicle type |
| **Surge Pricing** | Dynamic pricing during demand | `surge = demand_ratio > threshold ? multiplier : 1.0` |
| **Schedule Ride** | Book for later (15min - 7days) | Pre-matching 10 min before pickup |
| **Ride Confirmation** | Confirm booking | Hold payment authorization, create ride request |
| **Promo Code** | Apply discount | Validate code, check usage limits, apply discount |

### 4. During Ride

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Driver Matching** | Find nearby available driver | GEORADIUS 5km, sorted by distance, Zookeeper lock |
| **Match Notification** | Driver assigned notification | Push notification with driver details |
| **Real-time Tracking** | Track driver on map | WebSocket location updates every 3-5 sec |
| **ETA Updates** | Arrival time estimation | Google Directions API, recalculated every 30 sec |
| **Driver Details** | Name, photo, rating, vehicle | Shown after match confirmation |
| **Contact Driver** | Call/Chat with driver | In-app calling, chat within ride context |
| **Share Trip** | Share live location | Generate shareable link, valid during trip |
| **SOS/Emergency** | Emergency alert | Notify emergency contacts + call local emergency |
| **Cancel Ride** | Cancel before/after match | Free <2 min, else cancellation fee applies |
| **Change Destination** | Modify drop location | Recalculate fare, driver notification |

### 5. Post-Ride

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Trip Summary** | Route, distance, fare breakdown | Shown after trip completion |
| **Payment** | Auto-charge or Cash | Deduct from saved card/wallet or cash to driver |
| **Add Tip** | Tip driver (optional) | 0%, 10%, 15%, 20%, Custom amount |
| **Rate Driver** | 1-5 stars + feedback | Required for next booking, affects driver ranking |
| **Report Issue** | Lost item, bad experience | Creates support ticket, refund if valid |
| **Receipt** | Email/SMS receipt | Auto-sent after payment completion |

### 6. Ride History & Payments

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Ride History** | All past rides | Paginated list, filter by date/status |
| **Ride Details** | View specific trip | Route, fare, driver, timestamps |
| **Rebook Ride** | Book same route again | Pre-fill pickup/drop from history |
| **Payment Methods** | Add/Remove cards, UPI, Wallet | PCI compliant storage via Stripe |
| **Wallet** | In-app wallet balance | Top-up, auto-debit, cashback credits |
| **Invoices** | Download trip invoices | PDF generation for business expenses |

### 7. Settings & Support

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Notification Settings** | Enable/disable notifications | Ride updates always on, promotions optional |
| **Language** | Multi-language support | Stored in user preferences |
| **Help Center** | FAQs, contact support | Categorized help articles |
| **Live Chat** | Chat with support | Integrated chat support |
| **Report Safety Issue** | Safety concerns | High-priority ticket, escalated to safety team |

---

## 🚗 Driver Panel Features

### 1. Registration & Onboarding

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Sign Up** | Register as driver | Phone OTP verification |
| **Document Upload** | License, RC, Insurance, Photo | Image validation, OCR extraction |
| **Vehicle Registration** | Add vehicle details | Verify against RTO database |
| **Background Check** | Identity verification | Third-party verification (7-day process) |
| **Bank Account** | Add payout account | Verify via micro-deposit |
| **Training Module** | Complete training videos | Must complete before going online |
| **Approval** | Admin approval required | Manual review by admin team |

### Documents Required
```
Required Documents:
├── Driver's License (valid)
├── Vehicle Registration Certificate (RC)
├── Vehicle Insurance (valid)
├── PAN Card / Aadhaar
├── Passport Size Photo
├── Vehicle Photos (4 angles)
├── Permit (if commercial)
└── Police Verification (optional)
```

### 2. Home & Availability

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Go Online/Offline** | Toggle availability | Update Redis status, add/remove from geo-index |
| **Auto Offline** | Inactive timeout | Offline after 30 min no response |
| **Heat Map** | See high-demand areas | Show surge zones, suggest relocation |
| **Earnings Dashboard** | Today's earnings summary | Real-time earnings update |
| **Trip Requests** | Incoming ride requests | Sound + vibration, 30 sec to respond |

### 3. Accepting Rides

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Ride Request Popup** | Show ride details | Pickup location, distance, estimated fare |
| **Accept Ride** | Accept the request | Acquire Zookeeper lock, update status to BUSY |
| **Decline Ride** | Skip this ride | Affects acceptance rate if <85% |
| **Auto Accept** | Enable auto-accept mode | Automatically accept suitable rides |
| **Cancel Reasons** | Pre-defined reasons | Customer no-show, safety concern, etc. |

### Acceptance Rate Logic
```
acceptance_rate = (accepted_rides / total_offered_rides) × 100

Rules:
- < 85% = Warning notification
- < 70% = Priority reduced for ride offers
- < 50% = Account review, possible suspension
```

### 4. During Ride

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Navigate to Pickup** | Turn-by-turn navigation | Google Maps integration |
| **Arrived at Pickup** | Mark arrival | Notify rider, start wait timer (5 min free) |
| **Start Trip** | Begin the ride | Start fare meter, location tracking |
| **Navigation** | Route to destination | Optimal route, traffic consideration |
| **Stops** | Multi-stop rides | Added wait time charges ($0.30/min) |
| **End Trip** | Complete the ride | Calculate final fare, collect payment |
| **Collect Cash** | Cash payment collection | Confirm cash received, mark paid |

### Wait Time Charges
```
Wait Time Calculation:
- First 5 minutes: FREE
- After 5 minutes: $0.30/minute
- Max wait before auto-cancel: 10 minutes
```

### 5. Earnings & Payouts

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Earnings Summary** | Daily/Weekly/Monthly | Breakdown by fare, tips, bonuses |
| **Trip Earnings** | Per-trip breakdown | Base fare - platform commission + tip |
| **Incentives** | Bonus for targets | Complete 20 rides = $50 bonus |
| **Surge Earnings** | Extra during surge | Driver gets 70-80% of surge amount |
| **Weekly Payout** | Bank transfer | Every Monday for previous week |
| **Instant Payout** | Immediate transfer | Small fee (1-2%) for instant access |
| **Earning Reports** | Download statements | Tax documents, monthly summaries |

### Commission Structure
```
Platform Commission: 20-25% of fare
Driver Earnings = Total Fare - Commission + Tips + Bonuses

Example:
- Trip Fare: $20.00
- Commission (20%): $4.00
- Driver Earnings: $16.00
- Tip: $3.00
- Total to Driver: $19.00
```

### 6. Ratings & Performance

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Rating Score** | Average rider ratings | Rolling average of last 100 trips |
| **Performance Metrics** | Acceptance, Cancellation rates | Tracked weekly |
| **Badges** | Achievement badges | Top Driver, 1000 Trips, 5-Star Week |
| **Deactivation Risk** | Low rating warning | < 4.5 = warning, < 4.2 = review, < 4.0 = suspend |

### Rating Impact
```
Rating Ranges:
├── 4.8 - 5.0 = Excellent (Priority for rides)
├── 4.5 - 4.8 = Good (Normal operation)
├── 4.2 - 4.5 = Warning (Improvement needed)
├── 4.0 - 4.2 = Review (Training required)
└── Below 4.0 = Suspension (Account review)
```

### 7. Settings & Support

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Update Documents** | Renew expired docs | Notification 30 days before expiry |
| **Vehicle Change** | Update vehicle | Requires re-verification |
| **Notification Preferences** | Sound, vibration settings | Ride requests always enabled |
| **Driver Support** | 24/7 helpline | Priority support for drivers |
| **Report Issue** | Safety or payment issues | Creates high-priority ticket |

---

## 👨‍💼 Admin Panel Features

### 1. Dashboard & Analytics

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Overview Dashboard** | Key metrics at glance | Total rides, revenue, active users |
| **Real-time Map** | Live view of all rides | Active trips, available drivers |
| **Revenue Analytics** | Income tracking | Daily/Weekly/Monthly revenue |
| **Growth Metrics** | User acquisition | New riders, drivers, retention rate |
| **Geographic Analytics** | Area-wise performance | Hotspots, underserved areas |

### Dashboard Metrics
```
Key Performance Indicators (KPIs):
├── Total Rides Today/Week/Month
├── Total Revenue
├── Active Riders / Drivers
├── Average Trip Duration
├── Average Trip Distance
├── Cancellation Rate
├── Average Rating
├── Peak Hour Analysis
└── Surge Pricing Frequency
```

### 2. User Management (Riders)

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **User List** | All registered riders | Search, filter, paginate |
| **User Details** | View user profile | Ride history, payment history, ratings given |
| **Block/Unblock** | Account suspension | Block immediately, requires reason |
| **Wallet Management** | Add/Deduct balance | Manual wallet adjustments with audit log |
| **Refund Processing** | Issue refunds | Full/partial refund to original payment method |
| **User Communications** | Send notifications | Push/SMS/Email to specific users or segments |

### 3. Driver Management

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Driver Applications** | New driver requests | Review documents, approve/reject |
| **Driver List** | All registered drivers | Filter by status, rating, vehicle type |
| **Driver Details** | Full driver profile | Trips, earnings, ratings, documents |
| **Document Verification** | Verify uploaded docs | Mark as verified/rejected |
| **Driver Approval** | Approve new drivers | Enable driver after all checks pass |
| **Suspend Driver** | Temporary suspension | With reason, review period |
| **Terminate Driver** | Permanent removal | Final action, requires approval |
| **Driver Communications** | Announcements | Bulk notifications to drivers |

### Driver Status Workflow
```
Application → Document Review → Background Check → Training → Approval → Active

Status Values:
├── PENDING - Application submitted
├── DOCUMENTS_UNDER_REVIEW - Docs uploaded
├── DOCUMENTS_REJECTED - Docs need reupload
├── BACKGROUND_CHECK - Verification in progress
├── TRAINING_PENDING - Must complete training
├── APPROVED - Can go online
├── ACTIVE - Currently online
├── SUSPENDED - Temporarily blocked
└── TERMINATED - Permanently removed
```

### 4. Ride Management

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Live Rides** | All ongoing rides | Real-time status, intervention if needed |
| **Ride History** | All past rides | Search by rider/driver, date range |
| **Ride Details** | Complete trip info | Route, fare breakdown, communications |
| **Cancel Ride** | Admin cancel | Emergency cancellations, no fee to rider |
| **Assign Driver** | Manual assignment | Override system matching |
| **Dispute Resolution** | Handle complaints | Review trip, refund decisions |

### 5. Fare Configuration

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Base Fare** | Fixed starting fare | Per vehicle type, per city |
| **Distance Rate** | Per km pricing | Varies by vehicle type |
| **Time Rate** | Per minute pricing | For traffic/wait time |
| **Minimum Fare** | Floor price | Minimum charge per ride |
| **Surge Configuration** | Dynamic pricing rules | Thresholds, multipliers, caps |
| **City Zones** | Zone-based pricing | Different rates for zones |
| **Airport Fees** | Special location fees | Fixed surcharge for airports |
| **Toll Configuration** | Toll handling | Auto-add estimated tolls |

### Fare Configuration Example
```
Vehicle: Sedan
├── Base Fare: $2.50
├── Per Kilometer: $1.50
├── Per Minute: $0.30
├── Minimum Fare: $5.00
├── Cancellation Fee: $5.00
├── Wait Time (after 5 min): $0.30/min
├── Booking Fee: $1.00
└── Surge Cap: 3.0x maximum

Airport:
├── Airport Pickup Fee: $5.00
├── Airport Drop Fee: $0.00
└── Airport Queue Priority: Enabled
```

### 6. Promotions & Discounts

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Promo Codes** | Create discount codes | Fixed or percentage, usage limits |
| **Referral Program** | Rider/Driver referrals | Reward both referrer and referee |
| **First Ride Discount** | New user offer | Percentage or fixed discount |
| **Loyalty Program** | Repeat user rewards | Points per ride, redeemable |
| **Driver Incentives** | Performance bonuses | Target-based extra earnings |
| **Campaign Management** | Time-based offers | Schedule campaigns |

### Promo Code Types
```
Promo Code Configuration:
├── Code: FIRST50
├── Type: Percentage
├── Value: 50%
├── Max Discount: $10.00
├── Min Trip Amount: $15.00
├── Usage Limit: 1000 total
├── Per User Limit: 1
├── Valid From: 2024-01-01
├── Valid Until: 2024-12-31
├── Vehicle Types: All
├── Cities: All
└── First Trip Only: Yes
```

### 7. Support & Ticketing

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Support Tickets** | All user/driver issues | Categorized, prioritized |
| **Ticket Assignment** | Assign to agents | Auto-route or manual assign |
| **Issue Resolution** | Resolve complaints | Actions: refund, credit, apology |
| **Lost & Found** | Item recovery | Connect rider and driver |
| **Safety Incidents** | Critical issues | Priority handling, escalation |
| **SLA Tracking** | Response time metrics | First response, resolution time |

### Ticket Priority
```
Priority Levels:
├── P0 - Safety/Emergency (15 min response)
├── P1 - Payment Issue (1 hour response)
├── P2 - Trip Issue (4 hour response)
├── P3 - General Query (24 hour response)
└── P4 - Feedback (48 hour response)
```

### 8. Reports & Exports

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Financial Reports** | Revenue, payouts, commissions | Daily/Weekly/Monthly |
| **Operational Reports** | Rides, cancellations, ratings | By city, time period |
| **Driver Reports** | Performance, earnings, compliance | Individual or aggregate |
| **User Reports** | Acquisition, retention, LTV | Cohort analysis |
| **Tax Reports** | GST, TDS reports | Compliance documents |
| **Export Data** | CSV/Excel downloads | Custom date ranges |

### 9. System Configuration

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **City Management** | Add/Edit cities | Service areas, pricing zones |
| **Vehicle Types** | Configure vehicle categories | Enable/disable by city |
| **Commission Settings** | Platform fee percentage | By city, vehicle type |
| **Rating Thresholds** | Min ratings for operation | Suspension triggers |
| **Radius Settings** | Driver search radius | Default 5km, configurable |
| **SOS Configuration** | Emergency contacts | Local emergency numbers |
| **Payment Gateways** | Payment provider settings | Stripe, Razorpay keys |
| **Notification Templates** | SMS/Push content | Customizable messages |

### 10. Staff Management

| Feature | Description | Business Logic |
|---------|-------------|----------------|
| **Admin Users** | Create admin accounts | Email + password login |
| **Roles & Permissions** | Role-based access | Super Admin, City Admin, Support Agent |
| **Activity Logs** | Audit trail | Who did what when |
| **Two-Factor Auth** | Security enhancement | TOTP or SMS verification |

### Admin Roles
```
Role Permissions:
├── Super Admin
│   └── Full access to all features
├── City Admin
│   ├── Manage city riders/drivers
│   ├── View city reports
│   └── Handle city support tickets
├── Finance Admin
│   ├── View/Export financial reports
│   ├── Process refunds
│   └── Configure fares
├── Support Agent
│   ├── View/Respond to tickets
│   ├── View user/driver details
│   └── Process refunds (limited)
└── Operations Manager
    ├── Monitor live rides
    ├── Manage drivers
    └── View operational reports
```

---

## Complete API Documentation

### Base URL
```
Production: https://api.rideshare.com/v1
Staging: https://staging-api.rideshare.com/v1
```

### Authentication
```
All APIs require JWT Bearer token in header:
Authorization: Bearer <access_token>

Refresh Token Endpoint:
POST /auth/refresh
```

---

### 🧑 Rider APIs

#### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/auth/rider/send-otp` | Send OTP to phone |
| `POST` | `/auth/rider/verify-otp` | Verify OTP and login |
| `POST` | `/auth/rider/social-login` | Google/Facebook/Apple login |
| `POST` | `/auth/refresh` | Refresh access token |
| `POST` | `/auth/logout` | Invalidate tokens |

#### Profile
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/rider/profile` | Get profile details |
| `PUT` | `/rider/profile` | Update profile |
| `POST` | `/rider/profile/photo` | Upload profile photo |
| `DELETE` | `/rider/profile` | Delete account |

#### Saved Places
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/rider/places` | List saved places |
| `POST` | `/rider/places` | Add saved place |
| `PUT` | `/rider/places/{placeId}` | Update saved place |
| `DELETE` | `/rider/places/{placeId}` | Delete saved place |

#### Ride Booking
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/ride/estimate` | Get fare estimation |
| `POST` | `/ride/request` | Book a ride |
| `POST` | `/ride/schedule` | Schedule future ride |
| `GET` | `/ride/{rideId}` | Get ride details |
| `PUT` | `/ride/{rideId}/destination` | Change destination |
| `POST` | `/ride/{rideId}/cancel` | Cancel ride |
| `POST` | `/ride/{rideId}/rate` | Rate completed ride |
| `POST` | `/ride/{rideId}/tip` | Add tip to driver |
| `GET` | `/ride/{rideId}/share-link` | Get trip share link |

#### Real-time Updates (WebSocket)
| Event | Direction | Description |
|-------|-----------|-------------|
| `driver_assigned` | Server → Client | Driver matched |
| `driver_location` | Server → Client | Driver location update |
| `driver_arrived` | Server → Client | Driver at pickup |
| `trip_started` | Server → Client | Trip began |
| `trip_completed` | Server → Client | Trip ended |
| `trip_cancelled` | Server → Client | Trip cancelled |

#### History & Payments
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/rider/rides` | Ride history (paginated) |
| `GET` | `/rider/rides/{rideId}/receipt` | Download receipt PDF |
| `GET` | `/rider/payment-methods` | List payment methods |
| `POST` | `/rider/payment-methods` | Add payment method |
| `DELETE` | `/rider/payment-methods/{id}` | Remove payment method |
| `GET` | `/rider/wallet` | Get wallet balance |
| `POST` | `/rider/wallet/topup` | Add money to wallet |

#### Promo & Support
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/promo/validate` | Validate promo code |
| `POST` | `/promo/apply` | Apply promo to ride |
| `GET` | `/support/faq` | Get FAQ list |
| `POST` | `/support/ticket` | Create support ticket |
| `GET` | `/support/tickets` | List my tickets |

---

### 🚗 Driver APIs

#### Registration & Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/auth/driver/send-otp` | Send OTP to phone |
| `POST` | `/auth/driver/verify-otp` | Verify OTP |
| `POST` | `/driver/register` | Submit registration |
| `POST` | `/driver/documents` | Upload documents |
| `GET` | `/driver/documents` | Get document status |

#### Profile & Vehicle
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/driver/profile` | Get profile |
| `PUT` | `/driver/profile` | Update profile |
| `GET` | `/driver/vehicle` | Get vehicle details |
| `PUT` | `/driver/vehicle` | Update vehicle |
| `POST` | `/driver/bank-account` | Add bank account |

#### Availability & Location
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/driver/go-online` | Start accepting rides |
| `POST` | `/driver/go-offline` | Stop accepting rides |
| `GET` | `/driver/status` | Get current status |
| `WS` | `/driver/location` | WebSocket: Send location updates |
| `GET` | `/driver/heatmap` | Get demand heatmap |

#### Ride Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/driver/ride/{requestId}/accept` | Accept ride request |
| `POST` | `/driver/ride/{requestId}/decline` | Decline ride request |
| `POST` | `/driver/ride/{rideId}/arrived` | Mark arrived at pickup |
| `POST` | `/driver/ride/{rideId}/start` | Start trip |
| `POST` | `/driver/ride/{rideId}/complete` | Complete trip |
| `POST` | `/driver/ride/{rideId}/cancel` | Cancel ride |
| `POST` | `/driver/ride/{rideId}/collect-cash` | Confirm cash payment |

#### Earnings & Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/driver/earnings/summary` | Earnings overview |
| `GET` | `/driver/earnings/daily` | Daily breakdown |
| `GET` | `/driver/earnings/weekly` | Weekly breakdown |
| `GET` | `/driver/earnings/trips` | Trip-wise earnings |
| `POST` | `/driver/earnings/instant-payout` | Request instant payout |
| `GET` | `/driver/payouts` | Payout history |

#### Performance & Support
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/driver/ratings` | Rating breakdown |
| `GET` | `/driver/performance` | Performance metrics |
| `GET` | `/driver/incentives` | Available incentives |
| `POST` | `/support/driver-ticket` | Create support ticket |

---

### 👨‍💼 Admin APIs

#### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/admin/auth/login` | Admin login |
| `POST` | `/admin/auth/logout` | Admin logout |
| `POST` | `/admin/auth/2fa/verify` | Verify 2FA |

#### Dashboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/dashboard/stats` | Overview statistics |
| `GET` | `/admin/dashboard/live-rides` | Active rides count |
| `GET` | `/admin/dashboard/revenue` | Revenue metrics |
| `GET` | `/admin/dashboard/charts` | Chart data |

#### User Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/riders` | List riders |
| `GET` | `/admin/riders/{riderId}` | Get rider details |
| `PUT` | `/admin/riders/{riderId}/block` | Block rider |
| `PUT` | `/admin/riders/{riderId}/unblock` | Unblock rider |
| `POST` | `/admin/riders/{riderId}/wallet` | Adjust wallet |
| `POST` | `/admin/riders/{riderId}/refund` | Process refund |

#### Driver Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/drivers` | List drivers |
| `GET` | `/admin/drivers/pending` | Pending approvals |
| `GET` | `/admin/drivers/{driverId}` | Get driver details |
| `PUT` | `/admin/drivers/{driverId}/approve` | Approve driver |
| `PUT` | `/admin/drivers/{driverId}/reject` | Reject application |
| `PUT` | `/admin/drivers/{driverId}/suspend` | Suspend driver |
| `PUT` | `/admin/drivers/{driverId}/activate` | Reactivate driver |
| `PUT` | `/admin/drivers/{driverId}/documents/verify` | Verify documents |

#### Ride Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/rides` | List all rides |
| `GET` | `/admin/rides/live` | Live rides |
| `GET` | `/admin/rides/{rideId}` | Get ride details |
| `POST` | `/admin/rides/{rideId}/cancel` | Admin cancel ride |
| `POST` | `/admin/rides/{rideId}/assign-driver` | Manual driver assignment |

#### Fare Configuration
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/fares` | Get fare config |
| `PUT` | `/admin/fares` | Update fare config |
| `GET` | `/admin/fares/surge` | Get surge config |
| `PUT` | `/admin/fares/surge` | Update surge config |
| `GET` | `/admin/fares/cities` | List city configs |
| `POST` | `/admin/fares/cities` | Add city |
| `PUT` | `/admin/fares/cities/{cityId}` | Update city config |

#### Promotions
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/promos` | List promo codes |
| `POST` | `/admin/promos` | Create promo code |
| `PUT` | `/admin/promos/{promoId}` | Update promo |
| `DELETE` | `/admin/promos/{promoId}` | Delete promo |
| `GET` | `/admin/promos/{promoId}/usage` | Promo usage stats |

#### Support
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/tickets` | List support tickets |
| `GET` | `/admin/tickets/{ticketId}` | Get ticket details |
| `PUT` | `/admin/tickets/{ticketId}/assign` | Assign to agent |
| `PUT` | `/admin/tickets/{ticketId}/resolve` | Resolve ticket |
| `POST` | `/admin/tickets/{ticketId}/reply` | Reply to ticket |

#### Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/reports/rides` | Ride reports |
| `GET` | `/admin/reports/revenue` | Revenue reports |
| `GET` | `/admin/reports/drivers` | Driver reports |
| `GET` | `/admin/reports/users` | User reports |
| `POST` | `/admin/reports/export` | Export report |

#### System Config
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/config/cities` | List cities |
| `GET` | `/admin/config/vehicle-types` | Vehicle types |
| `GET` | `/admin/config/settings` | System settings |
| `PUT` | `/admin/config/settings` | Update settings |

#### Staff Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/staff` | List admin users |
| `POST` | `/admin/staff` | Create admin user |
| `PUT` | `/admin/staff/{staffId}` | Update admin |
| `DELETE` | `/admin/staff/{staffId}` | Remove admin |
| `GET` | `/admin/staff/roles` | List roles |
| `GET` | `/admin/audit-log` | Activity log |

---

## Database Design

### Complete Schema Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DATABASE SCHEMA                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  CORE TABLES                        SUPPORTING TABLES                            │
│  ────────────                       ─────────────────                            │
│  ✓ riders                           ✓ ride_requests                              │
│  ✓ drivers                          ✓ ratings                                    │
│  ✓ trips                            ✓ payments                                   │
│  ✓ admin_users                      ✓ driver_payouts                             │
│                                     ✓ location_history                           │
│  CONFIGURATION TABLES               ✓ device_tokens                              │
│  ────────────────────               ✓ notifications                              │
│  ✓ cities                           ✓ support_tickets                            │
│  ✓ vehicle_types                    ✓ promo_codes                                │
│  ✓ fare_configs                     ✓ promo_usage                                │
│  ✓ surge_configs                    ✓ saved_places                               │
│                                     ✓ audit_logs                                 │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Entity Relationship Diagram

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│    RIDERS    │         │    TRIPS     │         │   DRIVERS    │
├──────────────┤         ├──────────────┤         ├──────────────┤
│ rider_id  PK │────┐    │ trip_id   PK │    ┌────│ driver_id PK │
│ phone        │    │    │ rider_id  FK │────┘    │ phone        │
│ email        │    └───▶│ driver_id FK │◀────────│ email        │
│ name         │         │ status       │         │ name         │
│ avg_rating   │         │ pickup_loc   │         │ vehicle_type │
│ wallet_bal   │         │ drop_loc     │         │ status       │
│ created_at   │         │ fare         │         │ avg_rating   │
└──────────────┘         │ surge_mult   │         │ is_verified  │
       │                 │ distance_km  │         └──────────────┘
       │                 │ duration_min │                │
       │                 │ created_at   │                │
       │                 └──────────────┘                │
       │                        │                        │
       │         ┌──────────────┼──────────────┐        │
       │         │              │              │        │
       │         ▼              ▼              ▼        │
       │  ┌───────────┐  ┌───────────┐  ┌───────────┐  │
       │  │  RATINGS  │  │ PAYMENTS  │  │ LOCATION  │  │
       │  ├───────────┤  ├───────────┤  │ _HISTORY  │  │
       │  │ rating_id │  │payment_id │  ├───────────┤  │
       │  │ trip_id   │  │ trip_id   │  │ id        │  │
       │  │ driver_   │  │ amount    │  │ driver_id │──┘
       │  │  rating   │  │ method    │  │ trip_id   │
       │  │ rider_    │  │ status    │  │ location  │
       │  │  rating   │  │ tip       │  │ timestamp │
       │  └───────────┘  └───────────┘  └───────────┘
       │
       │         ┌───────────────────────────────┐
       └────────▶│         SAVED_PLACES          │
                 ├───────────────────────────────┤
                 │ place_id, rider_id, name,     │
                 │ address, lat, lon, type       │
                 └───────────────────────────────┘
```

### Table Definitions

#### Core Tables

```sql
-- RIDERS TABLE
CREATE TABLE riders (
    rider_id          UUID PRIMARY KEY,
    phone             VARCHAR(20) UNIQUE NOT NULL,
    email             VARCHAR(255) UNIQUE,
    name              VARCHAR(255),
    profile_photo     VARCHAR(500),
    avg_rating        DECIMAL(3,2) DEFAULT 5.00,
    total_trips       INT DEFAULT 0,
    wallet_balance    DECIMAL(10,2) DEFAULT 0.00,
    referral_code     VARCHAR(20) UNIQUE,
    referred_by       UUID REFERENCES riders(rider_id),
    is_active         BOOLEAN DEFAULT TRUE,
    is_verified       BOOLEAN DEFAULT FALSE,
    language          VARCHAR(10) DEFAULT 'en',
    created_at        TIMESTAMP DEFAULT NOW(),
    updated_at        TIMESTAMP DEFAULT NOW()
);

-- DRIVERS TABLE
CREATE TABLE drivers (
    driver_id           UUID PRIMARY KEY,
    phone               VARCHAR(20) UNIQUE NOT NULL,
    email               VARCHAR(255),
    name                VARCHAR(255) NOT NULL,
    profile_photo       VARCHAR(500),
    
    -- Vehicle Info
    vehicle_type        VARCHAR(20) NOT NULL,
    vehicle_model       VARCHAR(100),
    vehicle_color       VARCHAR(50),
    license_plate       VARCHAR(20) NOT NULL,
    
    -- Status
    status              VARCHAR(20) DEFAULT 'PENDING',
    is_online           BOOLEAN DEFAULT FALSE,
    current_location    GEOGRAPHY(Point, 4326),
    current_trip_id     UUID,
    
    -- Metrics
    avg_rating          DECIMAL(3,2) DEFAULT 5.00,
    total_trips         INT DEFAULT 0,
    acceptance_rate     DECIMAL(5,2) DEFAULT 100.00,
    cancellation_rate   DECIMAL(5,2) DEFAULT 0.00,
    
    -- Documents
    license_number      VARCHAR(50),
    license_expiry      DATE,
    license_verified    BOOLEAN DEFAULT FALSE,
    rc_number           VARCHAR(50),
    rc_verified         BOOLEAN DEFAULT FALSE,
    insurance_expiry    DATE,
    
    -- Bank
    bank_account_number VARCHAR(50),
    bank_ifsc           VARCHAR(20),
    bank_verified       BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    approved_at         TIMESTAMP,
    last_online_at      TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

-- TRIPS TABLE
CREATE TABLE trips (
    trip_id               UUID PRIMARY KEY,
    rider_id              UUID NOT NULL REFERENCES riders(rider_id),
    driver_id             UUID REFERENCES drivers(driver_id),
    
    -- Locations
    pickup_location       GEOGRAPHY(Point, 4326) NOT NULL,
    pickup_address        VARCHAR(500),
    drop_location         GEOGRAPHY(Point, 4326) NOT NULL,
    drop_address          VARCHAR(500),
    actual_route          GEOGRAPHY(LineString, 4326),
    
    -- Status & Type
    status                VARCHAR(30) DEFAULT 'PENDING',
    vehicle_type          VARCHAR(20) NOT NULL,
    is_scheduled          BOOLEAN DEFAULT FALSE,
    scheduled_at          TIMESTAMP,
    
    -- Fare
    estimated_fare        DECIMAL(10,2),
    actual_fare           DECIMAL(10,2),
    base_fare             DECIMAL(10,2),
    distance_fare         DECIMAL(10,2),
    time_fare             DECIMAL(10,2),
    wait_fare             DECIMAL(10,2) DEFAULT 0,
    surge_multiplier      DECIMAL(3,2) DEFAULT 1.00,
    toll_amount           DECIMAL(10,2) DEFAULT 0,
    discount_amount       DECIMAL(10,2) DEFAULT 0,
    promo_code            VARCHAR(50),
    
    -- Metrics
    estimated_distance_km DECIMAL(10,2),
    actual_distance_km    DECIMAL(10,2),
    estimated_duration    INT,
    actual_duration       INT,
    wait_time_minutes     INT DEFAULT 0,
    
    -- Payment
    payment_method        VARCHAR(20),
    payment_status        VARCHAR(20) DEFAULT 'PENDING',
    
    -- Timestamps
    requested_at          TIMESTAMP DEFAULT NOW(),
    matched_at            TIMESTAMP,
    driver_arrived_at     TIMESTAMP,
    started_at            TIMESTAMP,
    completed_at          TIMESTAMP,
    cancelled_at          TIMESTAMP,
    cancellation_reason   VARCHAR(255),
    cancelled_by          VARCHAR(20)
);

-- ADMIN USERS TABLE
CREATE TABLE admin_users (
    admin_id          UUID PRIMARY KEY,
    email             VARCHAR(255) UNIQUE NOT NULL,
    password_hash     VARCHAR(255) NOT NULL,
    name              VARCHAR(255) NOT NULL,
    role              VARCHAR(50) NOT NULL,
    phone             VARCHAR(20),
    is_active         BOOLEAN DEFAULT TRUE,
    two_fa_enabled    BOOLEAN DEFAULT FALSE,
    two_fa_secret     VARCHAR(100),
    last_login_at     TIMESTAMP,
    created_at        TIMESTAMP DEFAULT NOW(),
    created_by        UUID REFERENCES admin_users(admin_id)
);
```

#### Supporting Tables

```sql
-- RATINGS TABLE
CREATE TABLE ratings (
    rating_id         UUID PRIMARY KEY,
    trip_id           UUID NOT NULL REFERENCES trips(trip_id),
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    driver_id         UUID NOT NULL REFERENCES drivers(driver_id),
    driver_rating     INT CHECK (driver_rating BETWEEN 1 AND 5),
    rider_rating      INT CHECK (rider_rating BETWEEN 1 AND 5),
    rider_feedback    TEXT,
    driver_feedback   TEXT,
    created_at        TIMESTAMP DEFAULT NOW()
);

-- PAYMENTS TABLE
CREATE TABLE payments (
    payment_id          UUID PRIMARY KEY,
    trip_id             UUID NOT NULL REFERENCES trips(trip_id),
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    amount              DECIMAL(10,2) NOT NULL,
    tip_amount          DECIMAL(10,2) DEFAULT 0,
    payment_method      VARCHAR(20) NOT NULL,
    status              VARCHAR(20) DEFAULT 'PENDING',
    gateway_txn_id      VARCHAR(255),
    gateway_response    JSONB,
    refund_amount       DECIMAL(10,2),
    refund_reason       VARCHAR(255),
    created_at          TIMESTAMP DEFAULT NOW(),
    completed_at        TIMESTAMP
);

-- DRIVER PAYOUTS TABLE
CREATE TABLE driver_payouts (
    payout_id           UUID PRIMARY KEY,
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    amount              DECIMAL(10,2) NOT NULL,
    period_start        DATE NOT NULL,
    period_end          DATE NOT NULL,
    total_trips         INT,
    total_earnings      DECIMAL(10,2),
    commission_amount   DECIMAL(10,2),
    bonus_amount        DECIMAL(10,2) DEFAULT 0,
    status              VARCHAR(20) DEFAULT 'PENDING',
    bank_reference      VARCHAR(100),
    processed_at        TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

-- SAVED PLACES TABLE
CREATE TABLE saved_places (
    place_id          UUID PRIMARY KEY,
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    name              VARCHAR(100) NOT NULL,
    place_type        VARCHAR(20) DEFAULT 'OTHER',
    address           VARCHAR(500) NOT NULL,
    location          GEOGRAPHY(Point, 4326) NOT NULL,
    created_at        TIMESTAMP DEFAULT NOW()
);

-- PROMO CODES TABLE
CREATE TABLE promo_codes (
    promo_id          UUID PRIMARY KEY,
    code              VARCHAR(50) UNIQUE NOT NULL,
    description       VARCHAR(255),
    discount_type     VARCHAR(20) NOT NULL,
    discount_value    DECIMAL(10,2) NOT NULL,
    max_discount      DECIMAL(10,2),
    min_trip_amount   DECIMAL(10,2) DEFAULT 0,
    max_uses          INT,
    max_uses_per_user INT DEFAULT 1,
    current_uses      INT DEFAULT 0,
    valid_from        TIMESTAMP DEFAULT NOW(),
    valid_until       TIMESTAMP,
    vehicle_types     VARCHAR[] DEFAULT '{}',
    city_ids          UUID[] DEFAULT '{}',
    first_trip_only   BOOLEAN DEFAULT FALSE,
    is_active         BOOLEAN DEFAULT TRUE,
    created_by        UUID REFERENCES admin_users(admin_id),
    created_at        TIMESTAMP DEFAULT NOW()
);

-- SUPPORT TICKETS TABLE
CREATE TABLE support_tickets (
    ticket_id         UUID PRIMARY KEY,
    ticket_number     VARCHAR(20) UNIQUE NOT NULL,
    user_type         VARCHAR(20) NOT NULL,
    user_id           UUID NOT NULL,
    trip_id           UUID REFERENCES trips(trip_id),
    category          VARCHAR(50) NOT NULL,
    priority          VARCHAR(10) DEFAULT 'P3',
    subject           VARCHAR(255) NOT NULL,
    description       TEXT,
    status            VARCHAR(20) DEFAULT 'OPEN',
    assigned_to       UUID REFERENCES admin_users(admin_id),
    resolution        TEXT,
    refund_amount     DECIMAL(10,2),
    created_at        TIMESTAMP DEFAULT NOW(),
    first_response_at TIMESTAMP,
    resolved_at       TIMESTAMP
);

-- NOTIFICATIONS TABLE
CREATE TABLE notifications (
    notification_id   UUID PRIMARY KEY,
    user_type         VARCHAR(20) NOT NULL,
    user_id           UUID NOT NULL,
    title             VARCHAR(255) NOT NULL,
    body              TEXT NOT NULL,
    data              JSONB,
    type              VARCHAR(50) NOT NULL,
    trip_id           UUID REFERENCES trips(trip_id),
    is_read           BOOLEAN DEFAULT FALSE,
    sent_at           TIMESTAMP DEFAULT NOW()
);

-- DEVICE TOKENS TABLE
CREATE TABLE device_tokens (
    id                BIGSERIAL PRIMARY KEY,
    user_type         VARCHAR(20) NOT NULL,
    user_id           UUID NOT NULL,
    device_token      VARCHAR(500) NOT NULL,
    platform          VARCHAR(20) NOT NULL,
    is_active         BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

-- AUDIT LOG TABLE
CREATE TABLE audit_logs (
    log_id            UUID PRIMARY KEY,
    admin_id          UUID REFERENCES admin_users(admin_id),
    action            VARCHAR(100) NOT NULL,
    entity_type       VARCHAR(50) NOT NULL,
    entity_id         UUID,
    old_values        JSONB,
    new_values        JSONB,
    ip_address        INET,
    user_agent        VARCHAR(500),
    created_at        TIMESTAMP DEFAULT NOW()
);
```

#### Configuration Tables

```sql
-- CITIES TABLE
CREATE TABLE cities (
    city_id           UUID PRIMARY KEY,
    name              VARCHAR(100) NOT NULL,
    state             VARCHAR(100),
    country           VARCHAR(100) NOT NULL,
    timezone          VARCHAR(50) NOT NULL,
    currency          VARCHAR(10) DEFAULT 'USD',
    is_active         BOOLEAN DEFAULT TRUE,
    boundaries        GEOGRAPHY(Polygon, 4326),
    created_at        TIMESTAMP DEFAULT NOW()
);

-- VEHICLE TYPES TABLE
CREATE TABLE vehicle_types (
    vehicle_type_id   UUID PRIMARY KEY,
    name              VARCHAR(50) NOT NULL,
    display_name      VARCHAR(100) NOT NULL,
    description       VARCHAR(255),
    icon_url          VARCHAR(500),
    max_passengers    INT DEFAULT 4,
    is_active         BOOLEAN DEFAULT TRUE,
    sort_order        INT DEFAULT 0,
    created_at        TIMESTAMP DEFAULT NOW()
);

-- FARE CONFIGS TABLE
CREATE TABLE fare_configs (
    config_id         UUID PRIMARY KEY,
    city_id           UUID NOT NULL REFERENCES cities(city_id),
    vehicle_type_id   UUID NOT NULL REFERENCES vehicle_types(vehicle_type_id),
    base_fare         DECIMAL(10,2) NOT NULL,
    per_km_rate       DECIMAL(10,2) NOT NULL,
    per_minute_rate   DECIMAL(10,2) NOT NULL,
    minimum_fare      DECIMAL(10,2) NOT NULL,
    booking_fee       DECIMAL(10,2) DEFAULT 0,
    cancellation_fee  DECIMAL(10,2) DEFAULT 0,
    wait_time_rate    DECIMAL(10,2) DEFAULT 0,
    wait_time_free    INT DEFAULT 5,
    airport_fee       DECIMAL(10,2) DEFAULT 0,
    is_active         BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMP DEFAULT NOW(),
    updated_at        TIMESTAMP DEFAULT NOW(),
    UNIQUE(city_id, vehicle_type_id)
);

-- SURGE CONFIGS TABLE
CREATE TABLE surge_configs (
    config_id         UUID PRIMARY KEY,
    city_id           UUID NOT NULL REFERENCES cities(city_id),
    demand_threshold  DECIMAL(5,2) DEFAULT 1.5,
    surge_levels      JSONB NOT NULL,
    max_surge         DECIMAL(3,2) DEFAULT 3.0,
    calculation_interval INT DEFAULT 60,
    is_active         BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMP DEFAULT NOW()
);

-- Example surge_levels JSON:
-- [
--   {"min_ratio": 1.5, "max_ratio": 2.0, "multiplier": 1.2},
--   {"min_ratio": 2.0, "max_ratio": 3.0, "multiplier": 1.5},
--   {"min_ratio": 3.0, "max_ratio": 5.0, "multiplier": 1.8},
--   {"min_ratio": 5.0, "max_ratio": null, "multiplier": 2.5}
-- ]
```

### Key Indexes

```sql
-- Geospatial Indexes
CREATE INDEX idx_drivers_location ON drivers USING GIST (current_location);
CREATE INDEX idx_trips_pickup ON trips USING GIST (pickup_location);
CREATE INDEX idx_saved_places_location ON saved_places USING GIST (location);

-- Status & Lookup Indexes
CREATE INDEX idx_drivers_online ON drivers(is_online, status) WHERE is_online = TRUE;
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_trips_rider ON trips(rider_id, requested_at DESC);
CREATE INDEX idx_trips_driver ON trips(driver_id, requested_at DESC);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_tickets_status ON support_tickets(status, priority);

-- Time-based Indexes
CREATE INDEX idx_trips_requested ON trips(requested_at DESC);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
```

---

## System Architecture

### High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                                    CLIENTS                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                          │
│  │  Rider App   │    │  Driver App  │    │ Admin Panel  │                          │
│  │  (Mobile)    │    │  (Mobile)    │    │   (Web)      │                          │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                          │
└─────────┼──────────────────┼────────────────────┼──────────────────────────────────┘
          │                  │                    │
          └──────────────────┼────────────────────┘
                             ▼
┌────────────────────────────────────────────────────────────────────────────────────┐
│                              CDN / CLOUDFLARE                                       │
│                         (Static Assets, DDoS Protection)                            │
└────────────────────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────────────────────────┐
│                        LOAD BALANCER (AWS ALB / Nginx)                              │
│                    (SSL Termination, Health Checks, Routing)                        │
└────────────────────────────────────────────────────────────────────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│  API Gateway   │  │  WebSocket     │  │   Admin API    │
│  (REST APIs)   │  │    Gateway     │  │   (Internal)   │
├────────────────┤  ├────────────────┤  ├────────────────┤
│ • Auth         │  │ • Location     │  │ • Dashboard    │
│ • Rate Limit   │  │   Updates      │  │ • Management   │
│ • Validation   │  │ • Trip Events  │  │ • Reports      │
└───────┬────────┘  └───────┬────────┘  └───────┬────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
┌────────────────────────────────────────────────────────────────────────────────────┐
│                            MICROSERVICES LAYER                                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │
│  │    Auth     │ │    Ride     │ │   Driver    │ │   Payment   │ │Notification │  │
│  │   Service   │ │   Service   │ │   Service   │ │   Service   │ │   Service   │  │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │
│  │   Pricing   │ │  Matching   │ │   Rating    │ │   Support   │ │  Analytics  │  │
│  │   Service   │ │   Service   │ │   Service   │ │   Service   │ │   Service   │  │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  │
└────────────────────────────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│     REDIS     │  │    KAFKA      │  │   ZOOKEEPER   │
│   (Cache +    │  │  (Events +    │  │ (Distributed  │
│  Geospatial)  │  │   Async)      │  │    Locks)     │
└───────────────┘  └───────────────┘  └───────────────┘
        │                   │
        └───────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────────────────────────────────────┐
│                           DATABASE LAYER                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                     PostgreSQL (Primary + Read Replicas)                     │   │
│  │                           + PostGIS Extension                                │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL SERVICES                                           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │
│  │ Google Maps │ │   Stripe    │ │   Twilio    │ │ Firebase    │ │    AWS      │  │
│  │     API     │ │  Payments   │ │  SMS/Voice  │ │  FCM/APN    │ │     S3      │  │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘  │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Mobile Apps** | React Native / Flutter | Cross-platform rider & driver apps |
| **Admin Panel** | React.js + TypeScript | Web dashboard |
| **API Gateway** | Node.js / Go | REST API, authentication |
| **WebSocket** | Socket.io / Go | Real-time location tracking |
| **Database** | PostgreSQL + PostGIS | Primary data store + geospatial |
| **Cache** | Redis | Sessions, geospatial queries, caching |
| **Message Queue** | Apache Kafka | Event streaming, async processing |
| **Coordination** | Apache Zookeeper | Distributed locks (driver assignment) |
| **Notifications** | Firebase FCM + APNs | Push notifications |
| **Maps** | Google Maps API | Geocoding, directions, ETA |
| **Payments** | Stripe / Razorpay | Payment processing |
| **Storage** | AWS S3 | Documents, images |
| **Hosting** | AWS / GCP | Cloud infrastructure |

---

## Core Workflows

### 1. Ride Booking Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           RIDE BOOKING WORKFLOW                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  RIDER                    SYSTEM                         DRIVER                  │
│    │                        │                              │                     │
│    │ 1. Enter destination   │                              │                     │
│    │─────────────────────▶  │                              │                     │
│    │                        │                              │                     │
│    │ 2. Fare estimate       │                              │                     │
│    │◀─────────────────────  │                              │                     │
│    │                        │                              │                     │
│    │ 3. Confirm booking     │                              │                     │
│    │─────────────────────▶  │                              │                     │
│    │                        │                              │                     │
│    │                        │ 4. Find nearby drivers       │                     │
│    │                        │    (GEORADIUS 5km)           │                     │
│    │                        │                              │                     │
│    │                        │ 5. Acquire lock (Zookeeper)  │                     │
│    │                        │                              │                     │
│    │                        │ 6. Send ride request         │                     │
│    │                        │────────────────────────────▶ │                     │
│    │                        │                              │                     │
│    │                        │ 7. Accept/Decline            │                     │
│    │                        │◀──────────────────────────── │                     │
│    │                        │                              │                     │
│    │ 8. Driver assigned     │                              │                     │
│    │◀─────────────────────  │                              │                     │
│    │                        │                              │                     │
│    │ 9. Real-time tracking  │  Location updates (WS)       │                     │
│    │◀───────────────────────│─────────────────────────────│                     │
│    │                        │                              │                     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2. Trip Lifecycle

```
      ┌─────────┐
      │ PENDING │ ──── Ride requested, finding driver
      └────┬────┘
           │
           ▼
      ┌─────────┐
      │ MATCHED │ ──── Driver assigned and accepted
      └────┬────┘
           │
           ▼
   ┌───────────────┐
   │DRIVER_ARRIVED │ ──── Driver reached pickup point
   └───────┬───────┘
           │
           ▼
    ┌─────────────┐
    │ IN_PROGRESS │ ──── Trip started, fare meter running
    └──────┬──────┘
           │
           ▼
     ┌───────────┐
     │ COMPLETED │ ──── Trip ended, payment processed
     └───────────┘

  CANCELLATION STATES:
  ─────────────────────
  ┌────────────────────┐   ┌─────────────────────┐
  │ CANCELLED_BY_RIDER │   │ CANCELLED_BY_DRIVER │
  └────────────────────┘   └─────────────────────┘
```

### 3. Fare Calculation

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           FARE CALCULATION FORMULA                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Fare = (Base Fare + Distance Fare + Time Fare + Wait Fare) × Surge            │
│         + Booking Fee + Tolls - Discount                                         │
│                                                                                  │
│  Where:                                                                          │
│  ─────────────────────────────────────────────────────────────────────────────  │
│  Base Fare     = Fixed starting charge (e.g., $2.50)                            │
│  Distance Fare = Distance (km) × Per-km rate (e.g., 10km × $1.50 = $15)         │
│  Time Fare     = Duration (min) × Per-min rate (e.g., 20min × $0.30 = $6)       │
│  Wait Fare     = Wait time after 5 min × Wait rate (e.g., 3min × $0.30 = $0.90) │
│  Surge         = Demand multiplier (1.0x to 3.0x)                               │
│  Booking Fee   = Platform fee (e.g., $1.00)                                     │
│  Tolls         = Estimated toll charges                                         │
│  Discount      = Promo code discount                                            │
│                                                                                  │
│  EXAMPLE:                                                                        │
│  ─────────────────────────────────────────────────────────────────────────────  │
│  Base Fare:      $2.50                                                          │
│  Distance:       10 km × $1.50 = $15.00                                         │
│  Time:           20 min × $0.30 = $6.00                                         │
│  Wait:           0 min = $0.00                                                  │
│  Subtotal:       $23.50                                                         │
│  Surge (1.5x):   $23.50 × 1.5 = $35.25                                          │
│  Booking Fee:    $1.00                                                          │
│  Tolls:          $2.00                                                          │
│  Discount:       -$5.00 (promo)                                                 │
│  ─────────────────────────────────────────────────────────────────────────────  │
│  TOTAL:          $33.25                                                         │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 💰 Complete Payment System (Like UBER/OLA)

This section covers the **exact payment model** used by Uber/Ola including:
- Rider wallet management
- Driver earnings tracking  
- Cash commission collection
- Digital payment settlement
- Payout system

---

### Payment Methods Supported

| Method | Description | Flow |
|--------|-------------|------|
| **Credit/Debit Card** | Saved via Stripe/Razorpay | Platform receives → splits to driver |
| **UPI** | Direct bank transfer | Platform receives → splits to driver |
| **In-App Wallet** | Pre-loaded balance | Deducted instantly → splits to driver |
| **Cash** | Driver collects from rider | Driver owes commission to platform |
| **Net Banking** | Online bank transfer | Platform receives → splits to driver |

---

### Payment Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         PAYMENT FLOW ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────┐                                        ┌─────────────┐         │
│  │   RIDER     │                                        │   DRIVER    │         │
│  │   WALLET    │                                        │   WALLET    │         │
│  │  ─────────  │                                        │  ─────────  │         │
│  │ • Balance   │                                        │• Available  │         │
│  │ • Cards     │                                        │  Balance    │         │
│  │ • UPI       │                                        │• Cash Owed  │         │
│  │ • History   │                                        │• Pending    │         │
│  └──────┬──────┘                                        └──────▲──────┘         │
│         │                                                      │                 │
│         │ PAYS                                          EARNS  │                 │
│         ▼                                                      │                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                         PAYMENT SERVICE                                   │   │
│  ├──────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                           │   │
│  │  DIGITAL PAYMENT                    CASH PAYMENT                          │   │
│  │  ─────────────────                  ────────────────                      │   │
│  │  1. Rider charged ₹100              1. Driver collects ₹100               │   │
│  │  2. Platform receives ₹100          2. System records ₹100 collected      │   │
│  │  3. Platform keeps ₹20 (20%)        3. Driver owes ₹20 commission         │   │
│  │  4. Driver earns ₹80                4. Deducted from next payout          │   │
│  │                                                                           │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                         PAYOUT SERVICE                                    │   │
│  ├──────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                           │   │
│  │  WEEKLY PAYOUT (Free)                INSTANT PAYOUT (1-2% Fee)           │   │
│  │  ────────────────────                ─────────────────────────           │   │
│  │  Every Monday                        Anytime on demand                    │   │
│  │  Net = Digital Earnings              Net = Balance - Fee                  │   │
│  │       - Cash Commission Owed         Transferred via IMPS/UPI            │   │
│  │                                                                           │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1. Digital Payment Flow (Card/UPI/Wallet)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     DIGITAL PAYMENT FLOW (Card/UPI/Wallet)                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  STEP 1: PRE-AUTHORIZATION (Before Trip)                                        │
│  ───────────────────────────────────────                                        │
│  • System holds estimated fare + buffer on rider's card                         │
│  • Amount: Estimated Fare + 20% buffer                                          │
│  • No actual charge yet                                                          │
│                                                                                  │
│  STEP 2: TRIP COMPLETION                                                        │
│  ───────────────────────────────────────                                        │
│  • Calculate actual fare based on distance + time + surge                       │
│  • Release pre-auth hold                                                        │
│  • Charge actual amount                                                          │
│                                                                                  │
│  STEP 3: MONEY FLOW                                                             │
│  ───────────────────────────────────────                                        │
│                                                                                  │
│     Rider Pays ₹100                                                             │
│          │                                                                       │
│          ▼                                                                       │
│     ┌─────────────────────────────┐                                             │
│     │    PLATFORM ACCOUNT         │                                             │
│     │    (Stripe/Razorpay)        │                                             │
│     └─────────────┬───────────────┘                                             │
│                   │                                                              │
│          ┌───────┴───────┐                                                       │
│          ▼               ▼                                                       │
│     ┌──────────┐   ┌──────────┐                                                 │
│     │ Platform │   │  Driver  │                                                 │
│     │ Keeps    │   │  Earns   │                                                 │
│     │  ₹20     │   │   ₹80    │                                                 │
│     │  (20%)   │   │  (80%)   │                                                 │
│     └──────────┘   └────┬─────┘                                                 │
│                         │                                                        │
│                         ▼                                                        │
│              ┌─────────────────────┐                                            │
│              │  DRIVER WALLET      │                                            │
│              │  Balance: +₹80      │                                            │
│              │  (Added instantly)  │                                            │
│              └─────────────────────┘                                            │
│                                                                                  │
│  STEP 4: DRIVER PAYOUT                                                          │
│  ──────────────────────                                                         │
│  • Weekly: Transfer all available balance to bank (FREE)                        │
│  • Instant: Transfer immediately (1-2% fee)                                     │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 2. Cash Payment Flow (CRITICAL - Like Uber/Ola)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            CASH PAYMENT FLOW                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  THE PROBLEM:                                                                    │
│  ────────────                                                                   │
│  When rider pays CASH, driver collects the FULL fare directly.                  │
│  Platform commission (20%) is WITH the driver, not the platform.                │
│                                                                                  │
│  THE SOLUTION (Uber/Ola Model):                                                 │
│  ───────────────────────────────                                                │
│  Track commission owed and deduct from future digital earnings.                 │
│                                                                                  │
│  EXAMPLE:                                                                        │
│  ────────                                                                       │
│  Trip Fare: ₹100                                                                │
│  Platform Commission: ₹20 (20%)                                                 │
│  Driver's Share: ₹80                                                            │
│                                                                                  │
│  WHAT HAPPENS:                                                                  │
│  ─────────────                                                                  │
│                                                                                  │
│    RIDER                          DRIVER                                        │
│      │                              │                                            │
│      │ Pays ₹100 CASH              │                                            │
│      │─────────────────────────────▶│                                            │
│      │                              │                                            │
│      │                              │ Confirms "Cash Collected"                  │
│      │                              │ in App                                     │
│      │                              │                                            │
│      │                              ▼                                            │
│      │                    ┌─────────────────────┐                               │
│      │                    │  DRIVER WALLET      │                               │
│      │                    │  ─────────────────  │                               │
│      │                    │  Cash Collected:    │                               │
│      │                    │    +₹100            │                               │
│      │                    │                     │                               │
│      │                    │  Cash Owed to       │                               │
│      │                    │  Platform: +₹20    │                               │
│      │                    │                     │                               │
│      │                    │  (Driver keeps ₹80) │                               │
│      │                    └─────────────────────┘                               │
│                                                                                  │
│  HOW PLATFORM COLLECTS THE ₹20:                                                 │
│  ───────────────────────────────                                                │
│                                                                                  │
│  Method 1: Deduct from Digital Earnings                                         │
│  ─────────────────────────────────────                                          │
│  Next digital trip: Driver earns ₹80                                            │
│  Cash commission owed: ₹20                                                      │
│  Net added to wallet: ₹80 - ₹20 = ₹60                                           │
│                                                                                  │
│  Method 2: Deduct from Weekly Payout                                            │
│  ────────────────────────────────────                                           │
│  Weekly digital earnings: ₹1000                                                 │
│  Cash commission owed: ₹200                                                     │
│  Payout to bank: ₹1000 - ₹200 = ₹800                                            │
│                                                                                  │
│  Method 3: Mandatory Settlement (if owed > threshold)                           │
│  ────────────────────────────────────────────────────                           │
│  If cash owed > ₹2000 → Driver must pay via UPI/Card before going online        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Weekly Payout Calculation

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       WEEKLY PAYOUT CALCULATION EXAMPLE                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  DRIVER: Ravi Kumar                                                             │
│  PERIOD: Week of Jan 15-21, 2024                                                │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  TRIP EARNINGS                                                          │    │
│  ├─────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                          │    │
│  │  DIGITAL TRIPS (Card/UPI/Wallet):                                       │    │
│  │  ─────────────────────────────────                                      │    │
│  │  Total Fares Collected by Platform:     ₹8,000                          │    │
│  │  Platform Commission (20%):             ₹1,600                          │    │
│  │  Driver Earnings:                       ₹6,400 ✓ Added to Wallet        │    │
│  │                                                                          │    │
│  │  CASH TRIPS:                                                            │    │
│  │  ───────────                                                            │    │
│  │  Total Cash Collected by Driver:        ₹5,000                          │    │
│  │  Commission Owed to Platform (20%):     ₹1,000 ← Must be deducted       │    │
│  │  Driver Keeps:                          ₹4,000 (already in pocket)      │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  ADDITIONAL EARNINGS                                                    │    │
│  ├─────────────────────────────────────────────────────────────────────────┤    │
│  │  Tips (100% to driver):                 ₹350                            │    │
│  │  Incentive Bonus (20 trips):            ₹500                            │    │
│  │  Surge Earnings:                        ₹800                            │    │
│  │                                         ──────                          │    │
│  │  Total Additional:                      ₹1,650                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  WEEKLY PAYOUT CALCULATION                                              │    │
│  ├─────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                          │    │
│  │  Wallet Balance (Digital Earnings):     ₹6,400                          │    │
│  │  Tips + Bonuses:                       +₹1,650                          │    │
│  │  ─────────────────────────────────────────────                          │    │
│  │  Gross Wallet Balance:                  ₹8,050                          │    │
│  │                                                                          │    │
│  │  DEDUCTIONS:                                                            │    │
│  │  Cash Commission Owed:                 -₹1,000                          │    │
│  │  ─────────────────────────────────────────────                          │    │
│  │                                                                          │    │
│  │  NET PAYOUT TO BANK:                    ₹7,050  ✓                       │    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  SUMMARY:                                                                        │
│  ────────                                                                       │
│  • Digital trips: Driver earned ₹6,400 (in wallet)                              │
│  • Cash trips: Driver kept ₹4,000 (in pocket), owed ₹1,000 to platform          │
│  • Bonuses: ₹1,650 added                                                        │
│  • Payout: ₹7,050 transferred to bank                                           │
│  • Total earned this week: ₹7,050 + ₹4,000 = ₹11,050                            │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 4. Driver Wallet Structure

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DRIVER WALLET STRUCTURE                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  driver_wallet TABLE:                                                           │
│  ────────────────────                                                           │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ driver_id:              UUID                                            │   │
│  │                                                                          │   │
│  │ ─── BALANCE COMPONENTS ───                                              │   │
│  │ available_balance:      ₹6,400    (Ready for payout)                    │   │
│  │ pending_balance:        ₹0        (Being processed)                     │   │
│  │                                                                          │   │
│  │ ─── CASH TRACKING (CRITICAL) ───                                        │   │
│  │ cash_collected:         ₹5,000    (Total cash from riders)              │   │
│  │ cash_owed_to_platform:  ₹1,000    (Commission from cash trips)          │   │
│  │                                                                          │   │
│  │ ─── LIFETIME STATS ───                                                  │   │
│  │ total_earnings:         ₹2,50,000                                       │   │
│  │ total_payouts:          ₹2,40,000                                       │   │
│  │ total_commission_paid:  ₹62,500                                         │   │
│  │ total_tips:             ₹12,000                                         │   │
│  │ total_bonuses:          ₹8,500                                          │   │
│  │                                                                          │   │
│  │ ─── BANK DETAILS ───                                                    │   │
│  │ bank_account_name:      "Ravi Kumar"                                    │   │
│  │ bank_account_number:    "XXXX1234"                                      │   │
│  │ bank_ifsc_code:         "HDFC0001234"                                   │   │
│  │ bank_verified:          TRUE                                            │   │
│  │ upi_id:                 "ravi@upi"                                      │   │
│  │                                                                          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 5. Driver Earnings Per Trip

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        DRIVER EARNINGS TABLE (Per Trip)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  driver_earnings TABLE:                                                         │
│  ───────────────────────                                                        │
│                                                                                  │
│  EXAMPLE: Trip #12345 (Digital Payment)                                         │
│  ───────────────────────────────────────                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ trip_fare:              ₹250.00      Total fare charged                 │   │
│  │ base_fare:              ₹50.00                                          │   │
│  │ distance_fare:          ₹140.00      (14 km × ₹10)                      │   │
│  │ time_fare:              ₹40.00       (20 min × ₹2)                      │   │
│  │ surge_fare:             ₹20.00       (1.2x surge applied)               │   │
│  │                                                                          │   │
│  │ commission_rate:        20.00%                                          │   │
│  │ commission_amount:      ₹50.00       Platform's cut                     │   │
│  │                                                                          │   │
│  │ driver_earnings:        ₹200.00      ← Trip fare - commission           │   │
│  │ tip_amount:             ₹30.00       ← 100% to driver                   │   │
│  │ bonus_amount:           ₹0.00                                           │   │
│  │ total_earnings:         ₹230.00      ← Added to driver wallet           │   │
│  │                                                                          │   │
│  │ payment_type:           CARD                                            │   │
│  │ is_cash_trip:           FALSE                                           │   │
│  │ added_to_wallet:        TRUE                                            │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  EXAMPLE: Trip #12346 (Cash Payment)                                            │
│  ───────────────────────────────────                                            │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ trip_fare:              ₹180.00                                         │   │
│  │ commission_rate:        20.00%                                          │   │
│  │ commission_amount:      ₹36.00                                          │   │
│  │                                                                          │   │
│  │ driver_earnings:        ₹144.00      (Theoretical share)                │   │
│  │ tip_amount:             ₹0.00                                           │   │
│  │ total_earnings:         ₹144.00                                         │   │
│  │                                                                          │   │
│  │ payment_type:           CASH                                            │   │
│  │ is_cash_trip:           TRUE                                            │   │
│  │ cash_collected:         ₹180.00      ← Full fare in pocket              │   │
│  │ cash_commission_owed:   ₹36.00       ← Must pay back to platform        │   │
│  │ is_settled:             FALSE        ← Not yet deducted                 │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 6. Instant Payout Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           INSTANT PAYOUT FLOW                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  USE CASE: Driver needs money immediately (not wait till Monday)                │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  DRIVER REQUESTS INSTANT PAYOUT                                         │   │
│  │  ─────────────────────────────────                                      │   │
│  │  Available Balance:         ₹5,000                                      │   │
│  │  Cash Commission Owed:      ₹800                                        │   │
│  │                             ──────                                      │   │
│  │  Eligible for Payout:       ₹4,200                                      │   │
│  │                                                                          │   │
│  │  Instant Payout Fee (2%):   ₹84                                         │   │
│  │                             ──────                                      │   │
│  │  Amount to Bank:            ₹4,116                                      │   │
│  │                                                                          │   │
│  │  Transfer Mode:             IMPS / UPI                                  │   │
│  │  Time:                      Within 30 minutes                           │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  AFTER INSTANT PAYOUT:                                                          │
│  ─────────────────────                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Available Balance:         ₹0.00                                       │   │
│  │  Cash Commission Owed:      ₹0.00      (Cleared)                        │   │
│  │  Pending Balance:           ₹0.00                                       │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 7. Rider Wallet System

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           RIDER WALLET SYSTEM                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  rider_wallet_transactions TABLE:                                               │
│  ─────────────────────────────────                                              │
│                                                                                  │
│  CREDIT TRANSACTIONS (Money In):                                                │
│  ────────────────────────────────                                               │
│  • TOP_UP           - Rider adds money via card/UPI                             │
│  • REFUND           - Trip refund credited                                      │
│  • CASHBACK         - Promotional cashback                                      │
│  • REFERRAL_BONUS   - ₹100 for referring friend                                 │
│  • PROMO_CREDIT     - Promotional credit                                        │
│                                                                                  │
│  DEBIT TRANSACTIONS (Money Out):                                                │
│  ─────────────────────────────────                                              │
│  • RIDE_PAYMENT     - Deducted for ride fare                                    │
│  • TIP_PAYMENT      - Tip to driver                                             │
│                                                                                  │
│  PAYMENT PRIORITY:                                                              │
│  ─────────────────                                                              │
│  When rider pays for a trip:                                                    │
│  1. First deduct from Wallet Balance                                            │
│  2. Remaining charged to Card/UPI                                               │
│                                                                                  │
│  EXAMPLE:                                                                        │
│  ────────                                                                       │
│  Trip Fare: ₹200                                                                │
│  Wallet Balance: ₹50                                                            │
│                                                                                  │
│  → Wallet Deducted: ₹50                                                         │
│  → Card Charged: ₹150                                                           │
│  → Total Paid: ₹200                                                             │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 8. Payment APIs

#### Rider Payment APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/rider/wallet` | Get wallet balance & transactions |
| `POST` | `/rider/wallet/topup` | Add money to wallet |
| `GET` | `/rider/payment-methods` | List saved cards/UPI |
| `POST` | `/rider/payment-methods` | Add new payment method |
| `DELETE` | `/rider/payment-methods/{id}` | Remove payment method |
| `POST` | `/rider/payment-methods/{id}/default` | Set as default |
| `POST` | `/ride/{rideId}/pay` | Process ride payment |
| `POST` | `/ride/{rideId}/tip` | Add tip after ride |
| `GET` | `/rider/transactions` | Payment history |
| `GET` | `/rider/transactions/{txnId}/receipt` | Download receipt |

#### Driver Payment APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/driver/wallet` | Get wallet balance |
| `GET` | `/driver/wallet/transactions` | Wallet transaction history |
| `GET` | `/driver/earnings` | Earnings summary |
| `GET` | `/driver/earnings/today` | Today's earnings |
| `GET` | `/driver/earnings/weekly` | This week's earnings |
| `GET` | `/driver/earnings/trips` | Per-trip earnings breakdown |
| `GET` | `/driver/earnings/cash-owed` | Cash commission owed |
| `POST` | `/driver/payout/instant` | Request instant payout |
| `GET` | `/driver/payouts` | Payout history |
| `GET` | `/driver/payouts/{payoutId}` | Payout details |
| `POST` | `/driver/bank-account` | Add/update bank account |
| `POST` | `/driver/bank-account/verify` | Verify bank account |

#### Admin Payment APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/admin/payments` | All payments (filtered) |
| `GET` | `/admin/payments/{paymentId}` | Payment details |
| `POST` | `/admin/payments/{paymentId}/refund` | Process refund |
| `GET` | `/admin/payouts` | All driver payouts |
| `POST` | `/admin/payouts/process-weekly` | Trigger weekly payout |
| `GET` | `/admin/payouts/{payoutId}` | Payout details |
| `POST` | `/admin/payouts/{payoutId}/retry` | Retry failed payout |
| `GET` | `/admin/commission/report` | Commission report |
| `GET` | `/admin/revenue/report` | Revenue report |
| `POST` | `/admin/driver/{driverId}/wallet/adjust` | Manual wallet adjustment |

---

### 9. Database Tables for Payment

```sql
-- Key tables for payment system (see schema.sql for full definitions)

-- RIDER WALLET TRANSACTIONS
CREATE TABLE rider_wallet_transactions (
    txn_id            UUID PRIMARY KEY,
    rider_id          UUID NOT NULL,
    amount            DECIMAL(10,2) NOT NULL,
    type              VARCHAR(20),      -- CREDIT / DEBIT
    category          VARCHAR(50),      -- TOP_UP, RIDE_PAYMENT, REFUND, etc.
    balance_before    DECIMAL(10,2),
    balance_after     DECIMAL(10,2),
    trip_id           UUID,
    created_at        TIMESTAMP
);

-- DRIVER WALLET
CREATE TABLE driver_wallet (
    driver_id             UUID PRIMARY KEY,
    available_balance     DECIMAL(10,2) DEFAULT 0,
    pending_balance       DECIMAL(10,2) DEFAULT 0,
    cash_collected        DECIMAL(10,2) DEFAULT 0,
    cash_owed_to_platform DECIMAL(10,2) DEFAULT 0,  -- CRITICAL!
    total_earnings        DECIMAL(12,2) DEFAULT 0,
    total_payouts         DECIMAL(12,2) DEFAULT 0,
    bank_account_number   VARCHAR(50),
    bank_ifsc_code        VARCHAR(20),
    bank_verified         BOOLEAN DEFAULT FALSE
);

-- DRIVER EARNINGS (Per Trip)
CREATE TABLE driver_earnings (
    earning_id            UUID PRIMARY KEY,
    driver_id             UUID NOT NULL,
    trip_id               UUID NOT NULL,
    trip_fare             DECIMAL(10,2),
    commission_rate       DECIMAL(5,2),
    commission_amount     DECIMAL(10,2),
    driver_earnings       DECIMAL(10,2),
    tip_amount            DECIMAL(10,2) DEFAULT 0,
    total_earnings        DECIMAL(10,2),
    payment_type          VARCHAR(20),
    is_cash_trip          BOOLEAN DEFAULT FALSE,
    cash_collected        DECIMAL(10,2) DEFAULT 0,
    cash_commission_owed  DECIMAL(10,2) DEFAULT 0,
    is_settled            BOOLEAN DEFAULT FALSE
);

-- DRIVER PAYOUTS
CREATE TABLE driver_payouts (
    payout_id              UUID PRIMARY KEY,
    driver_id              UUID NOT NULL,
    payout_type            VARCHAR(20),    -- WEEKLY / INSTANT
    gross_amount           DECIMAL(10,2),
    cash_commission_deducted DECIMAL(10,2),
    instant_payout_fee     DECIMAL(10,2),
    net_amount             DECIMAL(10,2),
    status                 VARCHAR(20),
    bank_reference         VARCHAR(255)
);
```

---

### 10. Commission Structure

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          PLATFORM COMMISSION STRUCTURE                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  STANDARD COMMISSION: 20-25% of trip fare                                       │
│  ──────────────────────────────────────────                                     │
│                                                                                  │
│  Trip Fare:        ₹100                                                         │
│  Commission (20%): ₹20   → Platform Revenue                                     │
│  Driver Share:     ₹80   → Driver Earnings                                      │
│                                                                                  │
│  COMMISSION VARIATIONS BY CITY:                                                 │
│  ───────────────────────────────                                                │
│  Metro Cities (Mumbai, Delhi):     20%                                          │
│  Tier-2 Cities:                    22%                                          │
│  New Markets:                      18% (promotional)                            │
│                                                                                  │
│  COMMISSION VARIATIONS BY VEHICLE TYPE:                                         │
│  ────────────────────────────────────────                                       │
│  Bike:                            20%                                           │
│  Auto:                            20%                                           │
│  Sedan:                           20%                                           │
│  SUV/XL:                          22%                                           │
│  Premium:                         25%                                           │
│                                                                                  │
│  WHAT'S NOT INCLUDED IN COMMISSION:                                             │
│  ─────────────────────────────────────                                          │
│  ✓ Tips (100% to driver)                                                        │
│  ✓ Tolls (passed through to rider)                                              │
│  ✓ Incentive Bonuses (fully to driver)                                          │
│  ✓ Surge earnings (commission applied to surge fare too)                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛡️ Fraud Detection System

### Overview
Real-time fraud detection system monitoring driver GPS, rider behavior, payment patterns, and device fingerprints to prevent abuse and protect both riders and drivers.

### Fraud Detection Types

| Type | Detection Method | Auto-Action |
|------|------------------|-------------|
| **GPS Spoofing** | Impossible speed, location jumps, mock location enabled | Block trip, flag driver |
| **Device Tampering** | Rooted/jailbroken device, emulator detection | Suspend account |
| **Multiple Accounts** | Same device fingerprint, duplicate phone/email | Block registration |
| **Promo Abuse** | Excessive promo usage, referral fraud patterns | Block promo, warning |
| **Fake Trips** | Short trips for incentives, circular routes | No payout, investigation |
| **Payment Fraud** | Stolen cards, chargeback history | Block payment method |
| **Rating Manipulation** | Driver-rider collusion, fake 5-star exchanges | Rating removed |
| **Collusion** | Same pickup/drop, repeated rider-driver pairs | Investigation |

### GPS Spoofing Detection

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         GPS FRAUD DETECTION FLOW                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   Driver Location Update                                                         │
│          │                                                                       │
│          ▼                                                                       │
│   ┌──────────────────┐                                                          │
│   │ Receive Location │──────────────────────────────────────────────────────┐   │
│   │ Lat, Lng, Speed, │                                                      │   │
│   │ Accuracy, Time   │                                                      │   │
│   └────────┬─────────┘                                                      │   │
│            │                                                                │   │
│            ▼                                                                │   │
│   ┌────────────────────────────────────────────────────────────────────────┐│   │
│   │                    FRAUD DETECTION CHECKS                              ││   │
│   ├────────────────────────────────────────────────────────────────────────┤│   │
│   │                                                                        ││   │
│   │  CHECK 1: Impossible Speed                                             ││   │
│   │  ────────────────────────────                                          ││   │
│   │  Calculate speed = distance / time between updates                     ││   │
│   │  Flag if speed > 200 km/h (impossible for road travel)                 ││   │
│   │                                                                        ││   │
│   │  CHECK 2: Location Teleportation                                       ││   │
│   │  ────────────────────────────────                                      ││   │
│   │  Distance jumped > 5km in < 30 seconds = TELEPORTATION                 ││   │
│   │                                                                        ││   │
│   │  CHECK 3: Accuracy Flip                                                ││   │
│   │  ──────────────────────────                                            ││   │
│   │  Accuracy suddenly changes from 5m to 500m = MOCK LOCATION             ││   │
│   │                                                                        ││   │
│   │  CHECK 4: Mock Location Flag                                           ││   │
│   │  ─────────────────────────────                                         ││   │
│   │  Android: Settings.Secure.ALLOW_MOCK_LOCATION                          ││   │
│   │  iOS: Check for location spoofing apps                                 ││   │
│   │                                                                        ││   │
│   │  CHECK 5: Stationary Movement                                          ││   │
│   │  ───────────────────────────                                           ││   │
│   │  Trip shows movement but driver hasn't moved (GPS stationary)          ││   │
│   │                                                                        ││   │
│   └────────────────────────────────────────────────────────────────────────┘│   │
│            │                                                                │   │
│            ▼                                                                │   │
│   ┌────────────────────┐   Yes   ┌────────────────────────────────────────┐│   │
│   │  Any Check Failed? │─────────│ CREATE FRAUD ALERT                     ││   │
│   └────────┬───────────┘         │ • Log evidence                         ││   │
│            │ No                  │ • Calculate confidence score           ││   │
│            ▼                     │ • Trigger auto-action                  ││   │
│   ┌────────────────────┐         │ • Notify fraud team                    ││   │
│   │ Update Location    │         └────────────────────────────────────────┘│   │
│   │ Normally           │                                                    │   │
│   └────────────────────┘                                                    │   │
│                                                                              │   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Device Fingerprinting

```
DEVICE FINGERPRINT COMPONENTS:
─────────────────────────────────
Device ID (ANDROID_ID / IDFV)
+ Device Model
+ OS Version
+ Screen Resolution
+ Installed Fonts
+ Battery Info
+ Sensor Data
= UNIQUE FINGERPRINT HASH (SHA-256)

RISK SCORING:
─────────────────────────
Base Score: 0
+ Rooted/Jailbroken:  +40
+ Emulator:           +50
+ Mock Location:      +30
+ VPN Detected:       +10
+ Multiple Accounts:  +20 per account
= Total Risk Score (0-100)

THRESHOLDS:
─────────────────────────
0-20:   LOW RISK     → Normal operation
21-50:  MEDIUM RISK  → Enhanced monitoring
51-80:  HIGH RISK    → Manual review required
81-100: CRITICAL     → Auto-suspend, investigation
```

### Fraud Rules Configuration

| Rule | Threshold | Period | Severity | Auto-Action |
|------|-----------|--------|----------|-------------|
| GPS Teleportation | 3 jumps | 1 hour | HIGH | Block current trip |
| Excessive Speed | 5 occurrences | 1 hour | MEDIUM | Warning |
| Promo Code Abuse | 10 codes | 30 days | HIGH | Block promos |
| Cancellation Pattern | 80% cancel after match | 1 week | MEDIUM | Warning |
| Short Trip Farming | 20 trips < 1km | 1 day | CRITICAL | Suspend + Investigation |
| Device Fingerprint Match | 2 accounts | - | HIGH | Second account blocked |

### Fraud Alert APIs

```
POST   /admin/fraud/rules                      # Create fraud detection rule
GET    /admin/fraud/rules                      # List all rules
PUT    /admin/fraud/rules/{rule_id}            # Update rule
DELETE /admin/fraud/rules/{rule_id}            # Delete rule (soft)

GET    /admin/fraud/alerts                     # List fraud alerts (filterable)
GET    /admin/fraud/alerts/{alert_id}          # Get alert details + evidence
PUT    /admin/fraud/alerts/{alert_id}/status   # Update status (investigating/resolved)
POST   /admin/fraud/alerts/{alert_id}/action   # Take action (warn, suspend, clear)

GET    /admin/fraud/users/{user_type}/{user_id}/score    # Get user fraud score
GET    /admin/fraud/users/{user_type}/{user_id}/history  # User fraud history

GET    /admin/fraud/devices                    # List flagged devices
POST   /admin/fraud/devices/{device_id}/block  # Block device
DELETE /admin/fraud/devices/{device_id}/block  # Unblock device

GET    /admin/fraud/analytics                  # Fraud statistics dashboard
GET    /admin/fraud/reports                    # Generate fraud reports
```

### Fraud Score Calculation

```
USER FRAUD SCORE CALCULATION:
────────────────────────────────────

                ┌─────────────────────┐
                │   OVERALL SCORE     │
                │   (0-100)           │
                └─────────┬───────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │   GPS    │    │ Payment  │    │ Behavior │
    │  Risk    │    │  Risk    │    │  Risk    │
    │  (40%)   │    │  (30%)   │    │  (30%)   │
    └──────────┘    └──────────┘    └──────────┘
          │               │               │
          ▼               ▼               ▼
    - Teleportation  - Chargebacks   - Cancellations
    - Mock location  - Failed pays   - Rating patterns
    - Impossible     - Card fraud    - Collusion
      speeds         - Promo abuse   - Trip patterns


SCORE IMPACTS:
────────────────────────────────────
Confirmed Fraud Alert:       +15-30 points
False Positive (cleared):    -5 points
Clean rides (per 100):       -2 points
Account age (per year):      -3 points (trust)
```

---

## 🆘 Safety Features

### Overview
Comprehensive safety system protecting riders and drivers with SOS alerts, trip sharing, emergency contacts, background checks, and real-time safety monitoring.

### Safety Components

| Component | Description | Trigger |
|-----------|-------------|---------|
| **SOS Button** | Instant emergency alert | User presses SOS (hold 3 sec) |
| **Trip Sharing** | Share live location with contacts | Before/during trip |
| **Emergency Contacts** | Pre-saved trusted contacts | SOS or manual share |
| **Safety Checks** | Auto-detect anomalies | Route deviation, long stop |
| **Background Checks** | Driver verification | Before approval |
| **Audio Recording** | Trip audio for disputes | On-demand or SOS |

### SOS Alert Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              SOS ALERT SYSTEM                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   User Presses SOS                                                               │
│   (Hold 3 seconds)                                                               │
│          │                                                                       │
│          ▼                                                                       │
│   ┌──────────────────┐        ┌────────────────────────────────────────────────┐│
│   │ SOS TRIGGERED    │        │ IMMEDIATELY COLLECTED:                         ││
│   │                  │───────▶│ • Current GPS location                         ││
│   │ Alert Type:      │        │ • Trip details (if active)                     ││
│   │ • MANUAL         │        │ • Driver/Rider info                            ││
│   │ • CRASH_DETECTED │        │ • Vehicle details                              ││
│   │ • ROUTE_DEVIATION│        │ • Time & date                                  ││
│   │ • SILENT         │        └────────────────────────────────────────────────┘│
│   └────────┬─────────┘                                                          │
│            │                                                                     │
│            ▼                                                                     │
│   ┌────────────────────────────────────────────────────────────────────────────┐│
│   │                         PARALLEL ACTIONS                                   ││
│   ├────────────────────────────────────────────────────────────────────────────┤│
│   │                                                                            ││
│   │   ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐          ││
│   │   │ NOTIFY SUPPORT  │  │ NOTIFY CONTACTS │  │ START AUDIO      │          ││
│   │   │ TEAM            │  │                 │  │ RECORDING        │          ││
│   │   ├─────────────────┤  ├─────────────────┤  ├──────────────────┤          ││
│   │   │ • Dashboard     │  │ • SMS with link │  │ • Auto-start     │          ││
│   │   │   alert         │  │ • Push notify   │  │ • Cloud upload   │          ││
│   │   │ • Priority      │  │ • Live location │  │ • Evidence       │          ││
│   │   │   queue         │  │   sharing       │  │   preservation   │          ││
│   │   └─────────────────┘  └─────────────────┘  └──────────────────┘          ││
│   │                                                                            ││
│   └────────────────────────────────────────────────────────────────────────────┘│
│            │                                                                     │
│            ▼                                                                     │
│   ┌────────────────────────────────────────────────────────────────────────────┐│
│   │                      SUPPORT TEAM ACTIONS                                  ││
│   ├────────────────────────────────────────────────────────────────────────────┤│
│   │                                                                            ││
│   │   1. Contact user immediately (call)                                       ││
│   │   2. Assess situation severity                                             ││
│   │   3. Contact emergency services if needed (Police: 100, Ambulance: 102)    ││
│   │   4. Track real-time location                                              ││
│   │   5. Document incident                                                     ││
│   │   6. Follow up after resolution                                            ││
│   │                                                                            ││
│   └────────────────────────────────────────────────────────────────────────────┘│
│            │                                                                     │
│            ▼                                                                     │
│   ┌─────────────────┐                                                           │
│   │ RESOLUTION      │                                                           │
│   ├─────────────────┤                                                           │
│   │ • Mark resolved │                                                           │
│   │ • Update notes  │                                                           │
│   │ • Follow-up     │                                                           │
│   │ • Report filed  │                                                           │
│   └─────────────────┘                                                           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Trip Sharing

```
LIVE TRIP SHARING:
──────────────────────────────────────────────────────────────────────

┌──────────────────┐     ┌──────────────────────────────────────────┐
│  RIDER STARTS    │     │         SHARE LINK CONTENT               │
│  TRIP SHARING    │     ├──────────────────────────────────────────┤
├──────────────────┤     │                                          │
│                  │     │  🚗 [Rider Name]'s Trip                  │
│ Share with:      │────▶│                                          │
│ • Saved contacts │     │  From: 123 Main Street                   │
│ • Enter phone    │     │  To: Airport Terminal 1                  │
│ • Enter email    │     │                                          │
│                  │     │  Driver: Rajesh K. ⭐ 4.8                 │
│                  │     │  Vehicle: White Swift DL-5C-1234         │
│                  │     │                                          │
└──────────────────┘     │  [LIVE MAP TRACKING]                     │
                         │                                          │
                         │  ETA: 25 mins                            │
                         │  Current Speed: 45 km/h                  │
                         │                                          │
                         │  [Call Rider] [Call Driver] [Emergency]  │
                         │                                          │
                         └──────────────────────────────────────────┘

LINK DETAILS:
─────────────────────────────────────
• Unique share token (64 chars)
• Expires 24 hours after trip end
• View count tracked
• No login required to view
• Emergency button for viewer
```

### Auto Safety Checks

| Check Type | Trigger | Threshold | Action |
|------------|---------|-----------|--------|
| **Route Deviation** | Driver off route | >500m for >3 min | Notify rider |
| **Unexpected Stop** | Vehicle stopped | >5 min unexpected | Notify rider |
| **Overspeeding** | Speed limit breach | >80 km/h in city | Log + alert if extreme |
| **No Movement** | GPS not updating | >10 min during trip | Contact driver |
| **Long Trip** | Trip duration | >3x ETA | Auto-check popup |
| **Driver Offline** | Connection lost | >2 min mid-trip | Alert support |

### Driver Background Checks

```
DRIVER VERIFICATION PROCESS:
────────────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────────────────┐
│                    VERIFICATION STAGES                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   STAGE 1: IDENTITY VERIFICATION                                     │
│   ─────────────────────────────────                                 │
│   • Aadhaar/PAN verification via DigiLocker                         │
│   • Face match with ID photo                                         │
│   • Liveness check (blink, smile)                                    │
│   • Address proof verification                                       │
│                                                                      │
│   STAGE 2: CRIMINAL BACKGROUND CHECK                                 │
│   ────────────────────────────────────                              │
│   • Police verification certificate                                  │
│   • Court records check (civil + criminal)                           │
│   • Sexual offender registry check                                   │
│   • Terrorist watchlist screening                                    │
│                                                                      │
│   STAGE 3: DRIVING HISTORY                                           │
│   ─────────────────────────────                                     │
│   • License validity check with RTO                                  │
│   • Traffic violation history                                        │
│   • Accident history check                                           │
│   • DUI/DWI records                                                  │
│                                                                      │
│   STAGE 4: VEHICLE VERIFICATION                                      │
│   ───────────────────────────────                                   │
│   • RC book verification                                             │
│   • Insurance validity (min 1 year)                                  │
│   • Fitness certificate                                              │
│   • Commercial permit (if required)                                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

CHECK VALIDITY:
─────────────────────────────
Identity:          Lifetime (re-check annually)
Criminal Record:   1 year validity
Driving History:   1 year validity
Vehicle Docs:      Until expiry date
```

### Safety APIs

```
# Emergency Contacts
POST   /rider/emergency-contacts               # Add emergency contact
GET    /rider/emergency-contacts               # List contacts
PUT    /rider/emergency-contacts/{id}          # Update contact
DELETE /rider/emergency-contacts/{id}          # Remove contact
POST   /rider/emergency-contacts/{id}/verify   # Verify contact phone

# Same APIs for drivers
POST   /driver/emergency-contacts
GET    /driver/emergency-contacts

# SOS
POST   /rider/sos                              # Trigger SOS alert
POST   /driver/sos                             # Trigger SOS alert
GET    /rider/sos/{sos_id}/status             # Check SOS status
PUT    /rider/sos/{sos_id}/cancel             # Cancel (if false alarm)

# Trip Sharing
POST   /rider/trips/{trip_id}/share           # Create share link
GET    /rider/trips/{trip_id}/share           # Get share details
DELETE /rider/trips/{trip_id}/share           # Stop sharing
GET    /public/trip/{share_token}             # View shared trip (no auth)

# Safety Incidents
POST   /rider/safety/report                    # Report safety issue
POST   /driver/safety/report                   # Report safety issue
GET    /rider/safety/incidents                 # My reported incidents
GET    /admin/safety/incidents                 # All incidents (admin)
PUT    /admin/safety/incidents/{id}            # Update incident status

# Background Checks (Admin)
POST   /admin/drivers/{id}/background-check    # Initiate check
GET    /admin/drivers/{id}/background-checks   # View check history
PUT    /admin/background-checks/{id}           # Manual review update
```

---

## 📍 Geo-Fencing System

### Overview
Location-based rules engine that manages special zones like airports, malls, restricted areas with custom pricing, pickup rules, and driver queues.

### Zone Types

| Zone Type | Purpose | Special Rules |
|-----------|---------|---------------|
| **Airport** | Airport terminal zones | Queue system, fixed pickup fee, designated spots |
| **Train Station** | Railway stations | Queue optional, pickup zones |
| **Mall** | Shopping centers | Pickup zones, waiting areas |
| **Event Venue** | Stadiums, concerts | Surge rules, restricted times |
| **Hospital** | Emergency zones | Priority access, no surge |
| **Restricted** | No-go areas | No pickup/drop allowed |
| **Pickup Only** | One-way zones | Drop not allowed |
| **Drop Only** | Arrival zones | Pickup not allowed |

### Airport Queue System

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          AIRPORT QUEUE SYSTEM                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│                           AIRPORT ZONE                                           │
│   ┌───────────────────────────────────────────────────────────────────────┐     │
│   │                                                                        │     │
│   │    ┌───────────┐    ┌────────────────────────────────────────────┐    │     │
│   │    │ TERMINAL  │    │        DRIVER QUEUE AREA                   │    │     │
│   │    │   1 & 2   │    ├────────────────────────────────────────────┤    │     │
│   │    │           │    │                                            │    │     │
│   │    │   [P]     │    │   Queue Position:                          │    │     │
│   │    │  Pickup   │    │   1. 🚗 Driver A (Sedan) - 45 min wait     │    │     │
│   │    │  Point    │    │   2. 🚗 Driver B (SUV) - 42 min wait       │    │     │
│   │    │           │    │   3. 🚗 Driver C (Sedan) - 38 min wait     │    │     │
│   │    │           │    │   4. 🚗 Driver D (Premium) - 35 min wait   │    │     │
│   │    │           │    │   5. 🚗 Driver E (Sedan) - 30 min wait     │    │     │
│   │    │           │    │   ...                                      │    │     │
│   │    │           │    │   25. 🚗 Driver Y (Sedan) - Just joined    │    │     │
│   │    │           │    │                                            │    │     │
│   │    └───────────┘    │   [Capacity: 50] [Current: 25]            │    │     │
│   │                     └────────────────────────────────────────────┘    │     │
│   │                                                                        │     │
│   └───────────────────────────────────────────────────────────────────────┘     │
│                                                                                  │
│   HOW IT WORKS:                                                                  │
│   ─────────────────────────────────────────────────────────────────────         │
│                                                                                  │
│   1. DRIVER ENTERS AIRPORT ZONE                                                  │
│      └── Auto-detected via GPS                                                   │
│      └── Prompted: "Join airport queue?"                                         │
│                                                                                  │
│   2. DRIVER JOINS QUEUE                                                          │
│      └── Assigned position based on vehicle type                                 │
│      └── Must stay within queue zone                                             │
│      └── Wait time tracked                                                       │
│                                                                                  │
│   3. RIDER REQUESTS PICKUP FROM AIRPORT                                          │
│      └── System assigns FIRST driver in queue (of matching vehicle type)         │
│      └── Driver has 60 seconds to accept                                         │
│      └── If declined/missed, goes to next in queue                               │
│      └── Declining driver moves to back of queue                                 │
│                                                                                  │
│   4. ASSIGNMENT COMPLETE                                                         │
│      └── Driver navigates to pickup point                                        │
│      └── Airport pickup fee (₹100) added to fare                                │
│      └── Must depart within 10 min of pickup                                     │
│                                                                                  │
│   QUEUE RULES:                                                                   │
│   ─────────────────────────────────────────────────────────────────────         │
│   • Leaving queue zone = Removed from queue                                      │
│   • Offline while in queue = Removed + penalty                                   │
│   • Declining 3 trips = 30 min re-queue cooldown                                 │
│   • Max wait time: 4 hours (then removed)                                        │
│   • Separate queues per vehicle type                                             │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Zone Rules Configuration

```json
{
  "zone": "Airport Terminal 1",
  "zone_type": "AIRPORT",
  "rules": {
    "pickup_allowed": true,
    "drop_allowed": true,
    "pickup_fee": 100.00,
    "drop_fee": 0.00,
    "surge_override": null,
    "require_queue": true,
    "queue_capacity": 50,
    "max_queue_wait_hours": 4,
    "vehicle_types_allowed": ["sedan", "suv", "premium"],
    "operating_hours": {
      "start": "00:00",
      "end": "23:59"
    },
    "pickup_instructions": "Proceed to Gate 5, Ground Floor",
    "driver_notification": "You're entering airport zone. Follow signs to waiting area."
  }
}
```

### Restricted Zone Handling

```
RESTRICTED ZONE BEHAVIOR:
─────────────────────────────────────────────────────────────────

     User tries to set pickup          User tries to set drop
     in restricted zone                in restricted zone
              │                                 │
              ▼                                 ▼
     ┌─────────────────┐               ┌─────────────────┐
     │  CHECK ZONE     │               │  CHECK ZONE     │
     │  RULES          │               │  RULES          │
     └────────┬────────┘               └────────┬────────┘
              │                                 │
              ▼                                 ▼
     ┌─────────────────┐               ┌─────────────────┐
     │  ZONE TYPE:     │               │  ZONE TYPE:     │
     │  RESTRICTED     │               │  DROP_ONLY      │
     │  or PICKUP_ONLY │               │                 │
     └────────┬────────┘               └────────┬────────┘
              │                                 │
              ▼                                 ▼
     ┌─────────────────────────────────────────────────────┐
     │  SHOW ERROR MESSAGE:                                │
     │  "Pickup/Drop not available in this area.           │
     │   Please select a location outside the marked zone"  │
     │                                                     │
     │  [Show zone boundary on map with red shading]       │
     │  [Suggest nearest allowed pickup/drop point]        │
     └─────────────────────────────────────────────────────┘

EXAMPLES OF RESTRICTED ZONES:
─────────────────────────────
• Government buildings
• Military areas
• Private properties
• Construction zones
• Flooded/unsafe roads
• Event-specific blocks (protesth
```

### Geo-Fencing APIs

```
# Zone Management (Admin)
POST   /admin/geo-zones                        # Create zone
GET    /admin/geo-zones                        # List all zones
GET    /admin/geo-zones/{zone_id}              # Get zone details
PUT    /admin/geo-zones/{zone_id}              # Update zone
DELETE /admin/geo-zones/{zone_id}              # Delete zone (soft)
POST   /admin/geo-zones/{zone_id}/activate     # Activate zone
POST   /admin/geo-zones/{zone_id}/deactivate   # Deactivate zone

# Zone Query (Public/Apps)
POST   /geo/check-location                     # Check if point is in any zone
GET    /geo/zones/nearby                       # Get zones near location
GET    /geo/zones/{zone_id}/rules              # Get zone rules

# Airport Queues
GET    /driver/airport-queue/status            # Current queue status
POST   /driver/airport-queue/join              # Join queue
DELETE /driver/airport-queue/leave             # Leave queue
GET    /driver/airport-queue/position          # My position in queue

# Admin Queue Management
GET    /admin/airport-queues                   # List all queues
GET    /admin/airport-queues/{zone_id}         # Queue details
POST   /admin/airport-queues/{zone_id}/clear   # Clear queue
PUT    /admin/airport-queues/entry/{id}        # Update entry

# Zone Analytics
GET    /admin/geo-zones/{zone_id}/analytics    # Zone usage stats
GET    /admin/geo-zones/heatmap                # Activity heatmap
```

### Zone Entry/Exit Events

```
ZONE DETECTION FLOW:
─────────────────────────────────────────────────────────

  Driver/Rider App                    Backend
       │                                │
       │   Location Update              │
       │   (lat, lng)                   │
       ├───────────────────────────────>│
       │                                │
       │                     ┌──────────┴──────────┐
       │                     │ Check against all   │
       │                     │ active geo_zones    │
       │                     │ using PostGIS       │
       │                     │ ST_Contains()       │
       │                     └──────────┬──────────┘
       │                                │
       │                     ┌──────────┴──────────┐
       │                     │ Zone state changed? │
       │                     │ (entered/exited)    │
       │                     └──────────┬──────────┘
       │                                │
       │         Yes                    │ No
       │    ┌────┴────┐                 │
       │    ▼         ▼                 │
       │  ENTER     EXIT                │
       │    │         │                 │
       │    ▼         ▼                 │
       │  Log entry  Log exit           │
       │  event      event              │
       │    │         │                 │
       │    ▼         ▼                 │
       │  Apply      Remove             │
       │  zone       zone               │
       │  rules      rules              │
       │                                │
       │<───────────────────────────────┤
       │   Zone notification            │
       │   (if configured)              │
       │                                │
```

---

## 💬 In-Trip Chat System

### Overview
Real-time messaging between riders and drivers during trips, supporting text, images, quick replies, and location sharing, with content moderation.

### Chat Features

| Feature | Description | Use Case |
|---------|-------------|----------|
| **Text Messages** | Free-form text | Specific instructions |
| **Quick Replies** | Pre-defined responses | Common messages |
| **Image Sharing** | Send photos | Building photos, landmarks |
| **Location Pin** | Share exact location | "I'm at this pin" |
| **Voice Messages** | Audio notes | When typing is difficult |
| **Read Receipts** | Message status | Delivered, Read |

### Quick Replies

```
RIDER QUICK REPLIES:
─────────────────────────────────
PICKUP PHASE:
• "I'm waiting at the pickup point"
• "I'm wearing a [color] shirt"
• "Look for [landmark]"
• "I'll be there in 5 minutes"
• "Please wait, I'm coming"

DURING TRIP:
• "Please turn on AC"
• "Can you drive slower?"
• "Change the route please"
• "Stop at the next safe spot"

PAYMENT:
• "I'll pay in cash"
• "I need a receipt"


DRIVER QUICK REPLIES:
─────────────────────────────────
ARRIVAL:
• "I have arrived"
• "I'm in a [color] car"
• "I'm parked at [location]"
• "Please come outside"
• "Unable to find you, please call"

DURING TRIP:
• "Heavy traffic ahead"
• "Taking alternate route"
• "ETA is approximately XX mins"

WAITING:
• "I'm waiting for you"
• "Please hurry, parking is limited"
```

### Chat Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CHAT SYSTEM ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│    ┌──────────────┐        ┌──────────────┐        ┌──────────────┐            │
│    │  Rider App   │◄──────►│  WebSocket   │◄──────►│  Driver App  │            │
│    │              │        │  Gateway     │        │              │            │
│    └──────────────┘        └──────┬───────┘        └──────────────┘            │
│                                   │                                             │
│                                   ▼                                             │
│                          ┌─────────────────┐                                    │
│                          │  Chat Service   │                                    │
│                          ├─────────────────┤                                    │
│                          │ • Message Store │                                    │
│                          │ • Delivery      │                                    │
│                          │ • Moderation    │                                    │
│                          │ • Quick Replies │                                    │
│                          └────────┬────────┘                                    │
│                                   │                                             │
│             ┌─────────────────────┼─────────────────────┐                       │
│             ▼                     ▼                     ▼                       │
│    ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐             │
│    │   PostgreSQL    │   │     Redis       │   │   S3/Storage    │             │
│    │   (Messages)    │   │   (Pub/Sub)     │   │   (Media)       │             │
│    └─────────────────┘   └─────────────────┘   └─────────────────┘             │
│                                                                                  │
│   MESSAGE FLOW:                                                                  │
│   ─────────────────────────────────────────────────────────────────             │
│                                                                                  │
│   1. Rider sends message via WebSocket                                          │
│   2. Chat Service validates & stores message                                     │
│   3. Message published to Redis channel (trip:{trip_id}:chat)                   │
│   4. Driver's WebSocket connection subscribed to same channel                   │
│   5. Driver receives message in real-time                                        │
│   6. Delivery status sent back to Rider                                          │
│   7. When Driver opens message, Read receipt sent                                │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Message Moderation

```
CONTENT MODERATION FLOW:
─────────────────────────────────────────────────────────

  Message Sent
       │
       ▼
  ┌─────────────────────────────────────────────────┐
  │             AUTOMATED CHECKS                     │
  ├─────────────────────────────────────────────────┤
  │  • Profanity filter (word list + ML model)      │
  │  • Phone number regex (privacy)                 │
  │  • External link detection                       │
  │  • Spam pattern detection                        │
  │  • Threat/harassment ML classifier              │
  └───────────────────────┬─────────────────────────┘
                          │
              ┌───────────┴───────────┐
              │                       │
         PASSED                   FLAGGED
              │                       │
              ▼                       ▼
       ┌────────────┐          ┌────────────────────┐
       │  Deliver   │          │  What was flagged? │
       │  Message   │          └─────────┬──────────┘
       └────────────┘                    │
                            ┌────────────┼────────────┐
                            │            │            │
                         Phone#      Profanity    Threat
                            │            │            │
                            ▼            ▼            ▼
                       ┌────────┐  ┌────────┐  ┌────────────┐
                       │ Block  │  │ Censor │  │ Block +    │
                       │ entire │  │ words  │  │ Report to  │
                       │ message│  │ with   │  │ Safety     │
                       │        │  │ ***    │  │ Team       │
                       └────────┘  └────────┘  └────────────┘

BLOCKED CONTENT:
─────────────────────────────
• Personal phone numbers
• Email addresses
• Social media handles
• Payment requests outside app
• Links to external sites
```

### Chat APIs

```
# Messages
GET    /trips/{trip_id}/messages               # Get chat history
POST   /trips/{trip_id}/messages               # Send message
PUT    /trips/{trip_id}/messages/{id}/read     # Mark as read
POST   /trips/{trip_id}/messages/image         # Upload & send image

# Quick Replies
GET    /chat/quick-replies                     # Get available quick replies
POST   /trips/{trip_id}/messages/quick-reply   # Send quick reply

# Call (Phone Masking)
POST   /trips/{trip_id}/call                   # Initiate masked call

# WebSocket
WS     /ws/chat?trip_id={trip_id}&token={jwt}  # Real-time connection

# Admin
GET    /admin/chat/flagged                     # Flagged messages
PUT    /admin/chat/messages/{id}/review        # Review flagged
GET    /admin/trips/{trip_id}/chat             # View trip chat (support)
```

### Phone Number Masking

```
PRIVACY-PRESERVING CALLS:
─────────────────────────────────────────────────────────

  Instead of exposing real phone numbers:

  RIDER: +91-98765-XXXXX (hidden)
  DRIVER: +91-98123-XXXXX (hidden)

  MASKED NUMBER: +91-11111-00123 (temporary)

  ┌─────────┐  Calls masked     ┌──────────────┐     Routes to     ┌─────────┐
  │  Rider  │  number           │  Telephony   │     real number   │ Driver  │
  │         │──────────────────►│  Provider    │──────────────────►│         │
  │         │                   │  (Exotel)    │                   │         │
  └─────────┘                   └──────────────┘                   └─────────┘
                                       │
                                       │ Call logs recorded
                                       │ (duration, timestamps)
                                       ▼
                                ┌──────────────┐
                                │   call_logs  │
                                │    table     │
                                └──────────────┘

  BENEFITS:
  • Real numbers never shared
  • Call history tracked
  • Works even after trip for disputes (limited time)
  • Auto-expires 24 hours after trip
```

---

## 📋 Audit & Compliance (GDPR)

### Overview
Comprehensive audit logging, data privacy controls, consent management, and compliance reporting for regulatory requirements including GDPR, and local data protection laws.

### Compliance Components

| Component | Purpose | Regulation |
|-----------|---------|------------|
| **Consent Management** | Track user permissions | GDPR Art. 7 |
| **Data Export** | Right to access | GDPR Art. 15 |
| **Data Deletion** | Right to be forgotten | GDPR Art. 17 |
| **Audit Logs** | Track all data access | General compliance |
| **Session Management** | Track login/security | Security + Privacy |
| **Policy Versioning** | T&C change tracking | Contract law |

### Consent Management

```
USER CONSENT TYPES:
─────────────────────────────────────────────────────────

┌───────────────────────────────────────────────────────┐
│                  CONSENT CATEGORIES                    │
├───────────────────────────────────────────────────────┤
│                                                        │
│  REQUIRED (Cannot use app without):                   │
│  ───────────────────────────────────                  │
│  ✓ Terms of Service                                   │
│  ✓ Privacy Policy                                     │
│  ✓ Location Tracking (core functionality)             │
│                                                        │
│  OPTIONAL (User can decline):                         │
│  ───────────────────────────────                      │
│  ○ Marketing Emails                                   │
│  ○ Marketing SMS                                      │
│  ○ Push Notifications (promos)                        │
│  ○ Data Sharing with partners                         │
│  ○ Personalized recommendations                       │
│                                                        │
└───────────────────────────────────────────────────────┘

CONSENT FLOW:
─────────────────────────────────────────────────────────

  New User Registration
         │
         ▼
  ┌─────────────────────────────┐
  │  CONSENT SCREEN             │
  │                             │
  │  Required:                  │
  │  ☑ I agree to Terms of     │
  │    Service                  │
  │  ☑ I agree to Privacy      │
  │    Policy                   │
  │  ☑ Allow location tracking │
  │                             │
  │  Optional:                  │
  │  ☐ Send me promotional     │
  │    offers via email         │
  │  ☐ Send me SMS updates     │
  │                             │
  │  [Continue]                 │
  │                             │
  └─────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────┐
  │  LOG CONSENT EVENT          │
  │  ─────────────────────      │
  │  timestamp, user_id,        │
  │  consent_type, action,      │
  │  policy_version, IP,        │
  │  device_info                │
  └─────────────────────────────┘
```

### Data Export (Right to Access)

```
DATA EXPORT FLOW:
─────────────────────────────────────────────────────────

  User requests data export
  (Settings → Privacy → Request my data)
         │
         ▼
  ┌─────────────────────────────┐
  │  SELECT DATA TYPES          │
  │  ─────────────────────      │
  │  ☑ Profile information     │
  │  ☑ Trip history            │
  │  ☑ Payment records         │
  │  ☑ Ratings given/received  │
  │  ☑ Messages                │
  │  ☑ Location history        │
  │  ☐ All data                │
  │                             │
  │  Format: [JSON ▼]           │
  │                             │
  │  [Request Export]           │
  └─────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────┐
  │  PROCESSING (Background)    │
  │  ─────────────────────      │
  │  • Query all selected data  │
  │  • Format as JSON/CSV       │
  │  • Compress (ZIP)           │
  │  • Upload to secure storage │
  │  • Generate signed URL      │
  │  • Set expiry (7 days)      │
  └─────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────┐
  │  NOTIFY USER                │
  │  ─────────────────────      │
  │  "Your data export is       │
  │   ready. Download within    │
  │   7 days."                  │
  │                             │
  │  [Download] (signed URL)    │
  └─────────────────────────────┘

PROCESSING TIME:
─────────────────────────────
< 1 year of data:  ~1 hour
1-3 years:         ~4 hours
> 3 years:         ~24 hours
```

### Data Deletion (Right to be Forgotten)

```
DATA DELETION FLOW:
─────────────────────────────────────────────────────────

  User requests deletion
  (Settings → Privacy → Delete my account)
         │
         ▼
  ┌─────────────────────────────┐
  │  CONFIRMATION               │
  │  ─────────────────────      │
  │  ⚠ This action cannot      │
  │    be undone                │
  │                             │
  │  Please type "DELETE" to    │
  │  confirm: [________]        │
  │                             │
  │  Reason (optional):         │
  │  [________________]         │
  │                             │
  │  [Cancel] [Delete Account]  │
  └─────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────────────────────────────┐
  │                    DELETION PROCESS                  │
  ├─────────────────────────────────────────────────────┤
  │                                                      │
  │  1. CHECK FOR BLOCKERS:                             │
  │     • Active trips → Cannot delete                  │
  │     • Pending payments → Cannot delete              │
  │     • Outstanding balance → Cannot delete           │
  │     • Legal hold → Deletion paused                  │
  │                                                      │
  │  2. IMMEDIATE ACTIONS:                              │
  │     • Deactivate account                            │
  │     • Invalidate all sessions                       │
  │     • Cancel scheduled rides                        │
  │                                                      │
  │  3. SCHEDULED DELETION (30 days):                   │
  │     • Hold period for recovery                      │
  │     • Legal compliance retention                    │
  │     • After 30 days: Permanent deletion             │
  │                                                      │
  │  4. DATA HANDLING:                                  │
  │     • Profile data: DELETED                         │
  │     • Trip history: ANONYMIZED (stats kept)         │
  │     • Payment records: RETAINED 7 years (legal)     │
  │     • Messages: DELETED                             │
  │     • Location history: DELETED                     │
  │     • Ratings: ANONYMIZED                           │
  │                                                      │
  │  5. NOTIFY USER:                                    │
  │     • Confirmation email                            │
  │     • 30-day recovery instructions                  │
  │                                                      │
  └─────────────────────────────────────────────────────┘

LEGAL RETENTION REQUIREMENTS:
─────────────────────────────
Payment records:     7 years (tax law)
Driver documents:    1 year after quit (labor law)
Safety incidents:    10 years (liability)
Fraud evidence:      10 years (legal)
```

### Audit Logging

```
AUDIT LOG COVERAGE:
─────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────┐
│                  WHAT WE LOG                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  USER ACTIONS:                                          │
│  ─────────────────────────                             │
│  • Login / Logout                                       │
│  • Profile changes                                      │
│  • Password changes                                     │
│  • Payment method changes                               │
│  • Location permission changes                          │
│  • Privacy settings changes                             │
│  • Data export requests                                 │
│  • Account deletion requests                            │
│                                                         │
│  ADMIN ACTIONS:                                         │
│  ─────────────────────────                             │
│  • User data access (who, what, when, why)             │
│  • Account modifications                                │
│  • Suspensions / Bans                                   │
│  • Refunds issued                                       │
│  • Settings changes                                     │
│  • Report exports                                       │
│                                                         │
│  SYSTEM EVENTS:                                         │
│  ─────────────────────────                             │
│  • API access (aggregated)                              │
│  • Failed login attempts                                │
│  • Security alerts                                      │
│  • Data migrations                                      │
│                                                         │
└─────────────────────────────────────────────────────────┘

AUDIT LOG ENTRY EXAMPLE:
─────────────────────────────
{
  "log_id": "uuid",
  "timestamp": "2024-01-15T10:30:00Z",
  "actor_type": "admin",
  "actor_id": "admin-uuid",
  "action": "VIEW_USER_DATA",
  "target_type": "rider",
  "target_id": "rider-uuid",
  "resource": "payment_methods",
  "reason": "Support ticket #12345",
  "ip_address": "203.0.113.45",
  "user_agent": "Chrome/120..."
}
```

### Session Management

```
SESSION SECURITY:
─────────────────────────────────────────────────────────

  LOGIN EVENT
       │
       ▼
  ┌─────────────────────────────┐
  │  CREATE SESSION             │
  │  ─────────────────────      │
  │  • Generate JWT token       │
  │  • Hash and store           │
  │  • Capture device info      │
  │  • Record IP + location     │
  │  • Set expiry (30 days)     │
  └─────────────────────────────┘
       │
       ▼
  ┌─────────────────────────────────────────────────────┐
  │               ACTIVE SESSION MONITORING              │
  ├─────────────────────────────────────────────────────┤
  │                                                      │
  │  TRACK:                                              │
  │  • Last active timestamp                             │
  │  • IP changes                                        │
  │  • Device changes                                    │
  │                                                      │
  │  ALERT IF:                                           │
  │  • Login from new device                             │
  │  • Login from new city/country                       │
  │  • Multiple simultaneous sessions                    │
  │  • Session used from suspicious IP                   │
  │                                                      │
  │  AUTO-TERMINATE IF:                                  │
  │  • Expired                                           │
  │  • User changed password                             │
  │  • Account suspended                                 │
  │  • Security breach detected                          │
  │                                                      │
  └─────────────────────────────────────────────────────┘

USER SESSION VIEW (Settings → Security):
─────────────────────────────────────────────────────────
┌─────────────────────────────────────────────────────────┐
│  ACTIVE SESSIONS                                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  📱 iPhone 14 Pro                          [Current]    │
│     Mumbai, India • Last active: Now                    │
│                                                         │
│  📱 Samsung Galaxy S22                     [Logout]     │
│     Delhi, India • Last active: 2 days ago              │
│                                                         │
│  💻 Chrome on Windows                      [Logout]     │
│     Mumbai, India • Last active: 1 week ago             │
│                                                         │
│  [Logout from all other devices]                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Compliance APIs

```
# User Privacy Controls
GET    /rider/privacy/consent                  # Get current consents
PUT    /rider/privacy/consent                  # Update consents
POST   /rider/privacy/data-export              # Request data export
GET    /rider/privacy/data-export/{id}         # Check export status
GET    /rider/privacy/data-export/{id}/download # Download export
POST   /rider/privacy/data-deletion            # Request account deletion
DELETE /rider/privacy/data-deletion/{id}       # Cancel deletion request

# Session Management
GET    /rider/security/sessions                # List active sessions
DELETE /rider/security/sessions/{id}           # Logout specific session
DELETE /rider/security/sessions                # Logout all sessions

# Same for drivers
GET    /driver/privacy/consent
PUT    /driver/privacy/consent
POST   /driver/privacy/data-export
...

# Admin Audit
GET    /admin/audit/logs                       # Search audit logs
GET    /admin/audit/logs/{log_id}              # Get log details
GET    /admin/audit/user/{type}/{id}           # User audit history
GET    /admin/audit/admin/{admin_id}           # Admin action history
POST   /admin/audit/export                     # Export audit logs

# Compliance Management
GET    /admin/compliance/deletion-requests     # Pending deletions
PUT    /admin/compliance/deletion-requests/{id} # Process deletion
GET    /admin/compliance/export-requests       # Pending exports
GET    /admin/compliance/consents              # Consent analytics
POST   /admin/compliance/reports               # Generate compliance report

# Policy Management
GET    /admin/policies                         # List policies
POST   /admin/policies                         # Create policy version
PUT    /admin/policies/{id}/activate           # Make current
GET    /public/policies/current                # Get current policies
```

---

## Non-Functional Requirements

### Performance

| Metric | Target |
|--------|--------|
| API Response Time | < 200ms (p95) |
| Driver Matching | < 1 second |
| Location Update | Every 3-5 seconds |
| Push Notification | < 3 seconds |
| System Availability | 99.9% uptime |

### Security

| Aspect | Implementation |
|--------|----------------|
| Authentication | JWT tokens, refresh tokens |
| API Security | Rate limiting, input validation |
| Data Encryption | TLS 1.3 in transit, AES-256 at rest |
| PCI Compliance | Payment data via Stripe (PCI DSS) |
| GDPR | Data deletion, export capabilities |

### Scalability

| Component | Scaling Strategy |
|-----------|------------------|
| API Servers | Horizontal auto-scaling |
| Database | Read replicas, sharding by city |
| Redis | Cluster mode with sharding |
| WebSocket | Sticky sessions, Redis Pub/Sub |
| Kafka | Partition by driver/rider ID |

---

## Quick Reference

### Status Codes
```
TRIP STATUS:
PENDING → MATCHED → DRIVER_ARRIVED → IN_PROGRESS → COMPLETED
                                                 → CANCELLED

DRIVER STATUS:
PENDING → DOCUMENTS_UNDER_REVIEW → APPROVED → ACTIVE → SUSPENDED

PAYMENT STATUS:
PENDING → COMPLETED / FAILED / REFUNDED
```

### Key Business Rules
```
1. Driver can only be assigned to ONE ride at a time (Zookeeper lock)
2. Rider can have only ONE active ride at a time
3. Cancellation fee applies after driver assigned (>2 min window)
4. Wait time charges start after 5 minutes at pickup
5. Driver acceptance rate below 85% triggers warnings
6. Driver rating below 4.0 may result in suspension
7. Surge pricing capped at 3.0x maximum
8. Promo codes validated at booking time
9. Instant payouts have 1-2% processing fee
10. Driver commission is 20-25% of fare
```

---

## Repository Structure
```
RideSharing_SystemDesign/
├── README.md                     # This documentation
├── database/
│   ├── schema.sql               # Complete database schema
│   └── redis-commands.md        # Redis data structures
├── diagrams/
│   └── system-diagrams.md       # Architecture diagrams
└── interview-cheatsheet.md      # Quick reference
```

---

## References

- [System Design - Interview With Bunny](https://www.interviewwithbunny.com/systemdesign)
- Google Maps Platform Documentation
- Apache Kafka Documentation
- Apache Zookeeper Documentation
- Redis Geospatial Commands
- Stripe API Documentation
