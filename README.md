# Ride Sharing Application System Design
## (Like UBER | OLA | Rapido | Lyft)

---

## Table of Contents
1. [Overview](#overview)
2. [Functional Requirements](#functional-requirements)
3. [Non-Functional Requirements](#non-functional-requirements)
4. [Core Entities](#core-entities)
5. [API Design](#api-design)
6. [High Level Design (HLD)](#high-level-design-hld)
7. [Low Level Design (LLD)](#low-level-design-lld)
8. [Database Schema](#database-schema)
9. [Scaling & Optimization](#scaling--optimization)
10. [Key Interview Tips](#key-interview-tips)

---

## Overview

**Core Flow:**
> Rider requests → Geo-search nearby drivers → Zookeeper lock (prevent double assignment) → Driver accepts → WebSocket location tracking → Trip completion → Payment & Rating

---

## Functional Requirements

| # | Feature | Description |
|---|---------|-------------|
| 1 | Fare Estimation | Riders should be able to get fare estimation based on start location and destination |
| 2 | Ride Request | Riders should be able to request for a ride based on the estimated fare |
| 3 | Vehicle Categories | Riders should be able to request different categories of car (Sedan, SUV, Bike, Auto) |
| 4 | Real-time Driver View | Rider can see available drivers nearby in real-time on map |
| 5 | Driver Matching | Upon request, riders should be matched with a nearby driver (geo-proximity matching) |
| 6 | Real-time Tracking | Get real-time tracking of driver & user location during trip |
| 7 | Rating & Payment | After trip ends, rider should be able to rate their ride and make payment |
| 8 | Driver Status | Drivers should be able to accept/deny ride requests and update their status |

---

## Non-Functional Requirements

### Scale
| Metric | Target |
|--------|--------|
| Users & Drivers | Millions globally |
| Concurrent Rides | Hundreds of thousands at peak hours |

### Performance & Consistency
| Aspect | Requirement |
|--------|-------------|
| CAP Theorem | Availability >> Consistency (users) BUT Consistency >> Availability (driver assignment) |
| Ride Matching | Prevent any driver from being assigned multiple rides simultaneously (strong consistency) |
| Latency | <1 sec for driver assignment, real-time location updates every 3-5 seconds |

---

## Core Entities

### Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│   RIDER     │       │    TRIP     │       │   DRIVER    │
├─────────────┤       ├─────────────┤       ├─────────────┤
│ rider_id    │───────│ rider_id    │───────│ driver_id   │
│ name        │       │ driver_id   │       │ name        │
│ email       │       │ trip_id     │       │ vehicle_type│
│ phone       │       │ pickup_loc  │       │ vehicle_model│
│ payment_    │       │ drop_loc    │       │ license_plate│
│  methods    │       │ status      │       │ status      │
│ avg_rating  │       │ fare        │       │ avg_rating  │
│ current_loc │       │ timestamps  │       │ current_loc │
└─────────────┘       └─────────────┘       └─────────────┘
                             │
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
       ┌───────────┐  ┌───────────┐  ┌───────────┐
       │  RATING   │  │  PAYMENT  │  │   FARE    │
       ├───────────┤  ├───────────┤  ├───────────┤
       │ rating_id │  │payment_id │  │ fare_id   │
       │ trip_id   │  │ trip_id   │  │ base_fare │
       │ driver_   │  │ amount    │  │ distance_ │
       │  rating   │  │ method    │  │  fare     │
       │ rider_    │  │ status    │  │ time_fare │
       │  rating   │  └───────────┘  │ surge_mult│
       │ feedback  │                 │ total     │
       └───────────┘                 └───────────┘
```

---

## API Design

### User/Rider APIs

| Method | Endpoint | Description | Request/Response |
|--------|----------|-------------|------------------|
| `POST` | `/v1/api/fare/estimate` | Get fare estimation with Request ID | `{pickup, drop, vehicleType}` → fare breakdown |
| `POST` | `/v1/api/ride/request` | Request a ride | `{pickup, drop, vehicleType}` → `rideId` with driver details |
| `GET` | `/v1/api/ride/history` | Get ride history for user | Returns array of past rides |
| `POST` | `/v1/api/ride/{rideId}/cancel` | Cancel ride request | `{reason}` → status |
| `POST` | `/v1/api/ride/{rideId}/rate` | Rate driver after trip | `{rating, feedback}` |

### Driver APIs

| Method | Endpoint | Description | Request/Response |
|--------|----------|-------------|------------------|
| `WS` | `/v1/driver/location` | WebSocket: Update location continuously | `{lat, lon}` every 3-5 sec |
| `POST` | `/v1/api/ride/rides` | Accept/deny ride request | `{requestId, accept/deny}` → `rideId` |
| `POST` | `/v1/api/ride/{rideId}/start` | Mark trip as started | Triggers fare meter |
| `POST` | `/v1/api/ride/{rideId}/complete` | Mark trip as completed | Triggers payment |

---

## High Level Design (HLD)

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              CLIENTS                                          │
│  ┌─────────────┐                                      ┌─────────────┐        │
│  │  Rider App  │                                      │ Driver App  │        │
│  └──────┬──────┘                                      └──────┬──────┘        │
└─────────┼────────────────────────────────────────────────────┼───────────────┘
          │                                                    │
          ▼                                                    ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                    LOAD BALANCER + API GATEWAY                                  │
│         (Authentication, Authorization, Rate Limiting, Traffic Distribution)    │
└────────────────────────────────────────────────────────────────────────────────┘
          │
          ├───────────────┬───────────────┬──────────────┬───────────────┐
          ▼               ▼               ▼              ▼               ▼
┌─────────────────┐ ┌─────────────┐ ┌───────────────┐ ┌─────────────┐ ┌─────────────┐
│  Ride Service   │ │ Driver      │ │ Location Map  │ │   Rating    │ │  Payment    │
│  (Fare Calc)    │ │ Matching    │ │ Service       │ │  Service    │ │  Service    │
│                 │ │ Service     │ │ (GMaps/Apple) │ │             │ │             │
└────────┬────────┘ └──────┬──────┘ └───────────────┘ └──────┬──────┘ └──────┬──────┘
         │                 │                                  │              │
         │                 │                                  ▼              ▼
         │                 │                          ┌─────────────┐ ┌─────────────┐
         │                 │                          │ Rating DB   │ │ Payment DB  │
         │                 │                          │ (PostgreSQL)│ │ (PostgreSQL)│
         │                 │                          └─────────────┘ └─────────────┘
         │                 │
         ▼                 ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              REDIS CLUSTER                                        │
│  ┌─────────────────────┐  ┌──────────────────┐  ┌────────────────────────────┐   │
│  │ Driver Availability │  │ Driver Locations │  │ Surge Multipliers          │   │
│  │ Status (TTL: 5min)  │  │ (Geospatial)     │  │ (TTL: 2min)                │   │
│  └─────────────────────┘  └──────────────────┘  └────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              ZOOKEEPER CLUSTER                                    │
│                        (Distributed Locks - Driver Assignment)                    │
│                        Ephemeral Nodes: /locks/drivers/{driver_id}                │
└──────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                              KAFKA CLUSTER                                        │
│   Topics: ride.requested | ride.matched | trip.started | trip.completed          │
│           driver.ride_offered | driver.location_updated                          │
└──────────────────────────────────────────────────────────────────────────────────┘
          │                                                    │
          ▼                                                    ▼
┌─────────────────────┐                              ┌─────────────────────┐
│ Notification Service│                              │ Trip Update Consumer│
│ (FCM + APN)         │                              │ (Analytics/History) │
└─────────────────────┘                              └─────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DATABASES (PostgreSQL)                              │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│   │  Riders DB  │    │  Drivers DB │    │   Ride DB   │    │  Payments DB│      │
│   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘      │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Component Descriptions

| Component | Responsibility New |
|-----------|---------------|
| **Load Balancer + API Gateway** | Authentication, authorization, rate limiting, traffic distribution |
| **Ride Service** | Calculates estimated fare based on pickup/drop distance, surge pricing, vehicle type |
| **Driver Matching Service** | Geo-proximity search to find nearby available drivers, assigns driver to ride request |
| **Location Map Service** | Provides mapping, routing, ETA calculations via Google Maps/Apple Maps |
| **Rating Service** | Stores and retrieves rider/driver ratings and feedback |
| **Payment Service** | Processes payments via payment gateway (Stripe/Razorpay), handles refunds |
| **Location Update Service** | WebSocket server - ingests driver location pings every 3-5 seconds, updates Redis |
| **Redis** | Driver availability status (TTL), driver locations (geospatial index), ride request status |
| **Zookeeper** | Distributed lock for driver assignment - prevents double assignment, ephemeral nodes |
| **Notification Service** | FCM (Firebase Cloud Messaging) + APN (Apple Push Notification) for real-time notifications |
| **Kafka** | Event streaming for trip updates, location history, analytics, notifications |
| **Trip Update Consumer** | Consumes Kafka events, persists location history, generates analytics |

---

## Low Level Design (LLD)

### Step 1: Fare Estimation (Surge Calculator)

```
┌────────────┐    POST /v1/api/fare/estimate    ┌──────────────┐
│ Rider App  │─────────────────────────────────▶│ Ride Service │
└────────────┘   {pickup, drop, vehicle_type}   └───────┬──────┘
                                                        │
                                                        ▼
                                               ┌──────────────────┐
                                               │ Location Map Svc │
                                               │ (Google Maps API)│
                                               └────────┬─────────┘
                                                        │
                                               {distance: 5.2km, duration: 12min}
                                                        │
                                                        ▼
                                               ┌──────────────────┐
                                               │ Surge Calculator │
                                               │ (Redis lookup)   │
                                               └────────┬─────────┘
                                                        │
                                               surge_multiplier: 1.5x
                                                        │
                                                        ▼
┌────────────┐    {fare: $20.85, breakdown}    ┌──────────────────┐
│ Rider App  │◀────────────────────────────────│ Ride Service     │
└────────────┘                                 └──────────────────┘
```

**Fare Calculation:**
```
Base Fare      = $2.50 (flat charge)
Distance Fare  = 5.2 km × $1.50/km = $7.80
Time Fare      = 12 min × $0.30/min = $3.60
Subtotal       = $2.50 + $7.80 + $3.60 = $13.90
Surge (1.5×)   = $13.90 × 1.5 = $20.85
```

### Step 2: Ride Request & Driver Matching (Geo-search)

```
┌────────────┐  POST /v1/api/ride/request  ┌──────────────┐
│ Rider App  │───────────────────────────▶│ Ride Service │
└────────────┘                             └───────┬──────┘
                                                   │
                                                   ▼
                                          ┌────────────────────┐
                                          │ Validate & Create  │
                                          │ Ride Request       │
                                          └─────────┬──────────┘
                                                    │
                                                    ▼ Kafka: ride.requested
                                          ┌────────────────────┐
                                          │ Driver Matching    │
                                          │ Service            │
                                          └─────────┬──────────┘
                                                    │
              GEORADIUS drivers:available           │
              {pickup_lon} {pickup_lat} 5km         │
                                                    ▼
                                          ┌────────────────────┐
                                          │      REDIS         │
                                          │  (Geospatial)      │
                                          └─────────┬──────────┘
                                                    │
              Results: [{D1, 0.8km}, {D2, 1.2km}, {D3, 2.5km}]
                                                    │
                                                    ▼
                                          ┌────────────────────┐
                                          │ Zookeeper Lock     │
                                          │ (Prevent double    │
                                          │  assignment)       │
                                          └────────────────────┘
```

### Step 3: Driver Locking with Zookeeper (CRITICAL)

**Purpose:** Prevent double assignment - ensure one driver assigned to only one ride at a time.

```
Zookeeper Structure:
/locks/drivers/{driver_id}/{request_id}  (ephemeral sequential node)

┌─────────────────────────────────────────────────────────────────┐
│                        ZOOKEEPER                                 │
│                                                                  │
│  /locks/drivers/                                                 │
│       │                                                          │
│       ├── D1/                                                    │
│       │    ├── request_R1_seq0001  ← Lock Acquired (lowest seq) │
│       │    ├── request_R2_seq0002  ← Lock Failed (try next)     │
│       │    └── request_R3_seq0003  ← Lock Failed (try next)     │
│       │                                                          │
│       ├── D2/                                                    │
│       │    └── request_R2_seq0001  ← Lock Acquired              │
│       │                                                          │
│       └── D3/                                                    │
│            └── (empty - available)                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Lock Acquisition Flow:**
```
1. Create ephemeral node: CREATE /locks/drivers/D1/{request_id} (ephemeral, sequence)
2. Get all children: GET_CHILDREN /locks/drivers/D1 ORDER BY sequence
3. If our node is first → Lock acquired
4. If another node with lower sequence → Lock failed, try next driver
```

**Session Timeout:** 30 seconds - if service crashes or driver doesn't respond → Zookeeper auto-deletes node → lock released

### Step 4: Driver Accept/Decline

```
┌────────────────┐   POST /v1/api/ride/rides   ┌──────────────────┐
│  Driver App    │────────────────────────────▶│   Ride Service   │
└────────────────┘   {requestId, 'accept'}     └────────┬─────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────────┐
                                              │ Validate Zookeeper   │
                                              │ lock still held      │
                                              └──────────┬───────────┘
                                                         │
                                                         ▼
                                              ┌──────────────────────┐
                                              │ BEGIN TRANSACTION    │
                                              │ - INSERT trip        │
                                              │ - UPDATE ride_request│
                                              │ - UPDATE driver      │
                                              │ COMMIT               │
                                              └──────────┬───────────┘
                                                         │
                                                         ▼
                                              ┌──────────────────────┐
                                              │ Update Redis         │
                                              │ - trip:{id}:status   │
                                              │ - DEL ride_request   │
                                              └──────────┬───────────┘
                                                         │
                                                         ▼
                                              ┌──────────────────────┐
                                              │ Release Zookeeper    │
                                              │ Lock                 │
                                              └──────────┬───────────┘
                                                         │
                                                         ▼ Kafka: ride.matched
┌────────────────┐                            ┌──────────────────────┐
│  Rider App     │◀───────────────────────────│ Notification Service │
└────────────────┘    Push: "Driver assigned!" └──────────────────────┘
```

### Step 5: Real-Time Location Tracking (WebSocket)

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                         REAL-TIME LOCATION TRACKING                            │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌────────────┐    WS /v1/driver/location    ┌────────────────────────┐       │
│  │ Driver App │═══════════════════════════════│ Location Update Service│       │
│  └────────────┘   {lat, lon} every 3-5 sec   │    (WebSocket Server)  │       │
│                                               └───────────┬────────────┘       │
│                                                           │                    │
│                    ┌──────────────────────────────────────┼───────────────┐   │
│                    │                      │               │               │   │
│                    ▼                      ▼               ▼               ▼   │
│           ┌──────────────┐      ┌──────────────┐  ┌─────────────┐  ┌────────┐│
│           │ Redis        │      │ Redis Pub/Sub│  │   KAFKA     │  │ Notify ││
│           │ GEOADD       │      │ PUBLISH      │  │ location    │  │ if     ││
│           │ location     │      │ driver_loc   │  │ .updated    │  │ arrived││
│           └──────────────┘      └──────┬───────┘  └─────────────┘  └────────┘│
│                                        │                                      │
│                                        ▼                                      │
│                               ┌──────────────────┐                            │
│                               │  WebSocket GW    │                            │
│                               │  (subscribes to  │                            │
│                               │   Pub/Sub)       │                            │
│                               └────────┬─────────┘                            │
│                                        │                                      │
│                                        ▼                                      │
│  ┌────────────┐    WS /v1/trip/{id}/track    ┌────────────────────────┐      │
│  │ Rider App  │◀═════════════════════════════│ {driver_loc, eta: 4min}│      │
│  └────────────┘                              └────────────────────────┘      │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Step 6-7: Trip Start & Completion

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           TRIP LIFECYCLE                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  TRIP START                                                                   │
│  ┌────────────┐   POST /v1/api/ride/{id}/start   ┌────────────────────┐      │
│  │ Driver App │─────────────────────────────────▶│    Ride Service    │      │
│  └────────────┘                                  └─────────┬──────────┘      │
│                                                            │                  │
│                UPDATE trips SET status='IN_PROGRESS'       │                  │
│                Start fare meter                            │                  │
│                                                            ▼                  │
│  ┌────────────┐      Push: "Trip started!"       ┌────────────────────┐      │
│  │ Rider App  │◀─────────────────────────────────│ Notification Svc   │      │
│  └────────────┘                                  └────────────────────┘      │
│                                                                               │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                               │
│  TRIP COMPLETION                                                              │
│  ┌────────────┐   POST /v1/api/ride/{id}/complete  ┌────────────────────┐   │
│  │ Driver App │───────────────────────────────────▶│    Ride Service    │   │
│  └────────────┘                                    └─────────┬──────────┘   │
│                                                              │               │
│                                                              ▼               │
│                                                    ┌──────────────────────┐  │
│                                                    │ Calculate Final Fare │  │
│                                                    │ - Total distance     │  │
│                                                    │ - Total time         │  │
│                                                    │ - Apply surge        │  │
│                                                    └──────────┬───────────┘  │
│                                                               │              │
│                                                               ▼              │
│                                                    ┌──────────────────────┐  │
│                                                    │   Payment Service    │  │
│                                                    │   (Stripe/Razorpay)  │  │
│                                                    └──────────┬───────────┘  │
│                                                               │              │
│  ┌────────────┐    Receipt + Payment confirmation  ┌─────────▼──────────┐   │
│  │ Rider App  │◀───────────────────────────────────│ Notification Svc   │   │
│  └────────────┘                                    └────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step 8: Surge Pricing Algorithm

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        SURGE PRICING CALCULATOR                               │
│                        (Runs every 60 seconds per geohash area)               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  1. Query Available Drivers:                                                  │
│     GEORADIUS drivers:available {area_center} 5 km → count = 15              │
│                                                                               │
│  2. Query Pending Requests (last 10 min):                                    │
│     SELECT COUNT(*) FROM ride_requests WHERE status='PENDING' → count = 45   │
│                                                                               │
│  3. Calculate Ratio:                                                          │
│     demand_ratio = 45 / 15 = 3.0                                             │
│                                                                               │
│  4. Determine Multiplier:                                                     │
│     ┌─────────────────────────────────────────────────────────────────┐      │
│     │  Demand Ratio    │  Surge Level    │  Multiplier                │      │
│     ├───────────────────┼─────────────────┼───────────────────────────┤      │
│     │  < 1.2           │  No Surge       │  1.0×                      │      │
│     │  1.2 - 2.0       │  Low            │  1.2×                      │      │
│     │  2.0 - 3.0       │  Medium         │  1.5×                      │      │
│     │  3.0 - 5.0       │  High           │  1.8×                      │      │
│     │  >= 5.0          │  Very High      │  2.0× - 3.0× (max cap)     │      │
│     └─────────────────────────────────────────────────────────────────┘      │
│                                                                               │
│  5. Store in Redis:                                                           │
│     SET surge_multiplier:{geohash} 1.8 EX 120  (2 min TTL)                   │
│                                                                               │
│  6. Smoothing (prevent sudden jumps):                                         │
│     new_surge = 0.7 × old_surge + 0.3 × calculated_surge                     │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Database Schema

### Riders Table (PostgreSQL)

```sql
CREATE TABLE riders (
    rider_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    phone           VARCHAR(20) UNIQUE NOT NULL,
    payment_methods JSONB DEFAULT '[]',  -- [{type: 'card', last4, stripe_customer_id}]
    avg_rating      DECIMAL(3,2) DEFAULT 5.00,
    total_trips     INT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_riders_email ON riders(email);
CREATE INDEX idx_riders_phone ON riders(phone);
```

### Drivers Table (PostgreSQL)

```sql
CREATE TABLE drivers (
    driver_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    phone           VARCHAR(20) NOT NULL,
    vehicle_type    VARCHAR(20) CHECK (vehicle_type IN ('sedan', 'suv', 'bike', 'auto')),
    vehicle_model   VARCHAR(100),           -- e.g., 'Toyota Camry 2020'
    license_plate   VARCHAR(20) NOT NULL,
    status          VARCHAR(20) DEFAULT 'OFFLINE' CHECK (status IN ('AVAILABLE', 'BUSY', 'OFFLINE', 'IN_TRIP')),
    current_trip_id UUID REFERENCES trips(trip_id),
    avg_rating      DECIMAL(3,2) DEFAULT 5.00,
    total_trips     INT DEFAULT 0,
    acceptance_rate DECIMAL(5,2) DEFAULT 100.00,
    last_online_at  TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_vehicle_type ON drivers(vehicle_type);
CREATE INDEX idx_drivers_current_trip ON drivers(current_trip_id);
```

### Trips/Rides Table (PostgreSQL with PostGIS)

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE trips (
    trip_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id         UUID NOT NULL REFERENCES riders(rider_id),
    driver_id        UUID REFERENCES drivers(driver_id),
    pickup_location  GEOGRAPHY(Point, 4326) NOT NULL,
    drop_location    GEOGRAPHY(Point, 4326) NOT NULL,
    status           VARCHAR(30) DEFAULT 'PENDING' CHECK (status IN (
                        'PENDING', 'MATCHED', 'DRIVER_ARRIVED', 
                        'IN_PROGRESS', 'COMPLETED', 
                        'CANCELLED_BY_RIDER', 'CANCELLED_BY_DRIVER'
                     )),
    vehicle_type     VARCHAR(20) NOT NULL,
    estimated_fare   DECIMAL(10,2),
    actual_fare      DECIMAL(10,2),
    surge_multiplier DECIMAL(3,2) DEFAULT 1.00,
    distance_km      DECIMAL(10,2),
    duration_min     INT,
    requested_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    matched_at       TIMESTAMP,
    start_time       TIMESTAMP,
    end_time         TIMESTAMP,
    payment_status   VARCHAR(20) DEFAULT 'PENDING' CHECK (payment_status IN (
                        'PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'
                     )),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_trips_rider ON trips(rider_id, created_at);
CREATE INDEX idx_trips_driver ON trips(driver_id, created_at);
CREATE INDEX idx_trips_status_location ON trips USING GIST (pickup_location) WHERE status = 'PENDING';
```

### Ratings Table (PostgreSQL)

```sql
CREATE TABLE ratings (
    rating_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id         UUID UNIQUE NOT NULL REFERENCES trips(trip_id),
    rider_id        UUID NOT NULL REFERENCES riders(rider_id),
    driver_id       UUID NOT NULL REFERENCES drivers(driver_id),
    driver_rating   INT CHECK (driver_rating BETWEEN 1 AND 5),   -- Rider rates driver
    rider_rating    INT CHECK (rider_rating BETWEEN 1 AND 5),    -- Driver rates rider
    rider_feedback  TEXT,
    driver_feedback TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Note: Anonymous - drivers see rating but not rider identity in aggregated form
CREATE INDEX idx_ratings_driver ON ratings(driver_id);
CREATE INDEX idx_ratings_rider ON ratings(rider_id);
```

### Payments Table (PostgreSQL)

```sql
CREATE TABLE payments (
    payment_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id           UUID UNIQUE NOT NULL REFERENCES trips(trip_id),
    amount            DECIMAL(10,2) NOT NULL,
    currency          VARCHAR(3) DEFAULT 'USD',
    payment_method    VARCHAR(20) CHECK (payment_method IN ('card', 'wallet', 'cash', 'upi')),
    stripe_payment_id VARCHAR(255),  -- External payment gateway reference
    status            VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN (
                        'PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'
                      )),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at      TIMESTAMP
);

CREATE INDEX idx_payments_trip ON payments(trip_id);
CREATE INDEX idx_payments_status ON payments(status);
```

### Location History Table (for Analytics)

```sql
CREATE TABLE location_history (
    id          BIGSERIAL PRIMARY KEY,
    driver_id   UUID NOT NULL REFERENCES drivers(driver_id),
    trip_id     UUID REFERENCES trips(trip_id),
    location    GEOGRAPHY(Point, 4326) NOT NULL,
    speed       DECIMAL(5,2),  -- km/h
    accuracy    DECIMAL(5,2),  -- meters
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Partition by month for historical data
CREATE INDEX idx_location_history_driver ON location_history(driver_id, recorded_at);
CREATE INDEX idx_location_history_trip ON location_history(trip_id);
```

### Redis Data Structures

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              REDIS DATA STRUCTURES                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  GEOSPATIAL INDEX (Driver Locations & Availability)                             │
│  ──────────────────────────────────────────────────                             │
│  Key: drivers:available                                                          │
│  Type: GEOSPATIAL INDEX                                                          │
│  Commands: GEOADD, GEORADIUS, GEOREM                                             │
│  Usage: GEORADIUS drivers:available {lon} {lat} 5 km WITHDIST ASC               │
│                                                                                  │
│  ─────────────────────────────────────────────────────────────────────────────  │
│                                                                                  │
│  DRIVER STATUS                                                                   │
│  ──────────────                                                                  │
│  Key: driver:{driverId}:status                                                   │
│  Type: STRING                                                                    │
│  Value: AVAILABLE | BUSY | OFFLINE                                               │
│  TTL: 300 seconds (5 min) - refreshed by heartbeat                              │
│                                                                                  │
│  ─────────────────────────────────────────────────────────────────────────────  │
│                                                                                  │
│  DRIVER LOCATION CACHE                                                           │
│  ─────────────────────                                                           │
│  Key: location:{driverId}                                                        │
│  Type: STRING (JSON)                                                             │
│  Value: {lat, lon, timestamp}                                                    │
│  TTL: 60 seconds (1 min) - updated every 3-5 sec via WebSocket                  │
│                                                                                  │
│  ─────────────────────────────────────────────────────────────────────────────  │
│                                                                                  │
│  TRIP STATUS                                                                     │
│  ───────────                                                                     │
│  Key: trip:{tripId}:status                                                       │
│  Type: STRING                                                                    │
│  Value: MATCHED | IN_PROGRESS | COMPLETED                                        │
│  TTL: 7200 seconds (2 hour max trip)                                            │
│                                                                                  │
│  ─────────────────────────────────────────────────────────────────────────────  │
│                                                                                  │
│  SURGE MULTIPLIER                                                                │
│  ────────────────                                                                │
│  Key: surge_multiplier:{geohash}                                                 │
│  Type: STRING                                                                    │
│  Value: decimal (e.g., 1.5)                                                      │
│  TTL: 120 seconds (2 min) - recalculated every 60 sec                           │
│                                                                                  │
│  ─────────────────────────────────────────────────────────────────────────────  │
│                                                                                  │
│  RIDE REQUEST CACHE                                                              │
│  ──────────────────                                                              │
│  Key: ride_request:{requestId}                                                   │
│  Type: STRING (JSON)                                                             │
│  Value: {rider_id, pickup, drop, vehicle_type, estimated_fare}                  │
│  TTL: 600 seconds (10 min) - expires if no driver found                         │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Kafka Topics

| Topic | Description | Producers | Consumers |
|-------|-------------|-----------|-----------|
| `ride.requested` | Ride request created | Ride Service | Driver Matching Service |
| `driver.ride_offered` | Driver selected for matching | Driver Matching Service | Notification Service |
| `ride.matched` | Driver accepted ride | Ride Service | Notification Service, Analytics |
| `trip.started` | Driver picked up rider | Ride Service | Notification Service, Analytics |
| `trip.completed` | Trip ended, payment processed | Ride Service | Notification Service, Analytics |
| `driver.location_updated` | Real-time location ping (100K+ msg/sec) | Location Update Service | Trip Update Consumer |

### Zookeeper Structure (Driver Locks)

```
/locks/
└── drivers/
    ├── {driver_id_1}/
    │   └── {request_id}_seq0001  (ephemeral sequential node)
    ├── {driver_id_2}/
    │   └── {request_id}_seq0001
    └── {driver_id_3}/
        └── (empty - available)

Session timeout: 30 seconds
Purpose: Prevent double assignment - only one request can lock a driver at a time
```

---

## Scaling & Optimization

### Key Techniques

| Technique | Description | Performance |
|-----------|-------------|-------------|
| **Redis Geospatial** | GEORADIUS for proximity search | O(log(N)), ~10ms for 1M drivers |
| **Zookeeper Locking** | Ephemeral nodes prevent double assignment | <10ms lock acquisition |
| **WebSocket** | Persistent connections vs HTTP polling | 100x less traffic |
| **Kafka Streaming** | Decouples services, 100K+ events/sec | Async processing |
| **Database Sharding** | Shard by geohash (trips) or driver_id | Horizontal scaling |
| **CDN** | Static assets (photos, map tiles) | 95% cache hit rate |

### Caching Strategy

| Data | TTL | Refresh |
|------|-----|---------|
| Driver Status | 5 min | Heartbeat every 30 sec |
| Driver Location | 1 min | WebSocket every 3-5 sec |
| Surge Multiplier | 2 min | Recalculated every 60 sec |
| Fare Estimate | 5 min | N/A (estimate valid for 5 min) |
| Ride Request | 10 min | Expires if no driver found |

### Performance Targets

| Metric | Target |
|--------|--------|
| Driver Assignment | <1 second |
| Geospatial Query (1M drivers) | ~10ms |
| Lock Acquisition | <10ms |
| Push Notification Latency | 1-3 seconds |
| WebSocket In-App Latency | <100ms |

---

## Key Interview Tips

### Critical Points

⚠️ **MUST use Zookeeper distributed locking for driver assignment**
- Without lock, multiple ride requests can assign same driver simultaneously
- Double booking → terrible UX + revenue loss
- Ephemeral nodes ensure automatic lock release on failure

⭐ **How to prevent double assignment?**
- Zookeeper ephemeral sequential nodes
- Request R1 creates `/locks/drivers/D1/request_R1_seq0001`
- Concurrent request R2 gets seq0002 → sees seq0001 exists → lock failed → tries next driver

💡 **Redis Geospatial optimization**
- Use `GEORADIUS` for sub-10ms proximity search on 1M drivers
- Maintain separate indexes per vehicle type: `drivers:available:sedan`, `drivers:available:suv`

⭐ **WebSocket vs HTTP polling**
- Polling: 100K riders × 20 req/min = 33K req/sec overhead
- WebSocket: Persistent connection, send only when location changes, 100x less traffic

⚠️ **NEVER trust Redis alone for driver availability**
- Redis is cache with TTL (ephemeral)
- Always validate driver status in DB before final assignment

💡 **Surge pricing smoothing**
- Use exponential moving average: `new_surge = 0.7×old + 0.3×calculated`
- Prevents sudden jumps, feels fairer to users
- Max cap at 3.0× prevents price gouging

---

## Quick Reference Numbers

| Category | Metric | Value |
|----------|--------|-------|
| **Scale** | Concurrent Rides | 100K at peak |
| **Scale** | Location Updates | Every 3-5 sec |
| **Latency** | Driver Assignment | <1 sec |
| **Latency** | Geospatial Query | ~10ms |
| **Lock** | Session Timeout | 30 sec |
| **Pricing** | Surge Calculation | Every 60 sec |
| **Pricing** | Max Surge | 3.0× |
| **Cache** | Driver Status TTL | 5 min |
| **Cache** | Location TTL | 1 min |
| **Push** | Notification Latency | 1-3 sec |
| **WebSocket** | In-App Latency | <100ms |

---

## References

- [System Design Complete Course - Interview With Bunny](https://www.interviewwithbunny.com/systemdesign)
- Google Maps Distance Matrix API
- Redis Geospatial Commands
- Apache Zookeeper Documentation
- Apache Kafka Documentation
