# Ride Sharing System Design Diagrams

## 1. High Level Architecture Diagram

```mermaid
flowchart TB
    subgraph Clients
        RA[Rider App]
        DA[Driver App]
    end

    subgraph API_Layer["API Layer"]
        LB[Load Balancer]
        AG["API Gateway - Auth/Rate Limit"]
    end

    subgraph Core_Services["Core Services"]
        RS["Ride Service - Fare Calc"]
        DMS["Driver Matching Service"]
        LMS["Location Map Service"]
        RTS[Rating Service]
        PS[Payment Service]
        NS["Notification Service"]
    end

    subgraph Real_Time["Real-Time Layer"]
        WS["WebSocket Server"]
    end

    subgraph Messaging["Message Queue"]
        KAFKA[Apache Kafka]
    end

    subgraph Caching["Caching Layer"]
        REDIS[("Redis Cluster")]
    end

    subgraph Coordination["Distributed Coordination"]
        ZK["Zookeeper - Driver Locks"]
    end

    subgraph Databases["Persistent Storage"]
        PG_RIDERS[(Riders DB)]
        PG_DRIVERS[(Drivers DB)]
        PG_TRIPS[(Trips DB)]
        PG_PAYMENTS[(Payments DB)]
    end

    subgraph External["External Services"]
        MAPS[Google Maps API]
        FCM[Firebase FCM]
        APN[Apple APN]
        STRIPE[Stripe/Razorpay]
    end

    RA --> LB
    DA --> LB
    DA <-.-> WS

    LB --> AG
    AG --> RS
    AG --> DMS
    AG --> RTS
    AG --> PS

    RS --> LMS
    RS --> REDIS
    DMS --> REDIS
    DMS --> ZK
    DMS --> KAFKA

    WS --> REDIS
    WS --> KAFKA

    KAFKA --> NS
    KAFKA --> TUC[Trip Update Consumer]

    NS --> FCM
    NS --> APN

    RS --> PG_TRIPS
    PS --> PG_PAYMENTS
    PS --> STRIPE
    RTS --> PG_TRIPS
    DMS --> PG_DRIVERS
    LMS --> MAPS

    TUC --> PG_TRIPS

    style REDIS fill:#ff6b6b,color:#fff
    style ZK fill:#4ecdc4,color:#fff
    style KAFKA fill:#f39c12,color:#fff
```

## 2. Ride Request Flow Sequence Diagram

```mermaid
sequenceDiagram
    participant R as Rider App
    participant AG as API Gateway
    participant RS as Ride Service
    participant REDIS as Redis
    participant DMS as Driver Matching
    participant ZK as Zookeeper
    participant D as Driver App
    participant NS as Notification

    R->>AG: POST /v1/api/ride/request
    AG->>RS: Forward request
    RS->>REDIS: GET fare_estimate:{requestId}
    REDIS-->>RS: Fare details
    RS->>RS: Validate & create ride request
    RS->>REDIS: SET ride_request:{id}
    RS->>DMS: Kafka: ride.requested

    DMS->>REDIS: GEORADIUS drivers:available 5km
    REDIS-->>DMS: [{D1, 0.8km}, {D2, 1.2km}]
    
    loop For each driver (closest first)
        DMS->>ZK: CREATE /locks/drivers/{D1}/seq
        alt Lock acquired (lowest sequence)
            ZK-->>DMS: Lock success
            DMS->>REDIS: SET driver:{D1}:status BUSY
            DMS->>REDIS: GEOREM drivers:available {D1}
            DMS->>NS: Kafka: driver.ride_offered
            NS->>D: Push: "New ride request!"
            
            alt Driver Accepts
                D->>AG: POST /v1/api/ride/rides {accept}
                AG->>RS: Forward acceptance
                RS->>ZK: Verify lock
                RS->>RS: Create trip in DB
                RS->>ZK: DELETE lock
                RS->>REDIS: Update status
                RS->>NS: Kafka: ride.matched
                NS->>R: Push: "Driver assigned!"
            else Driver Declines
                D->>AG: POST /v1/api/ride/rides {decline}
                AG->>RS: Forward decline
                RS->>ZK: DELETE lock
                RS->>REDIS: SET driver:status AVAILABLE
                DMS->>DMS: Try next driver
            end
        else Lock failed
            ZK-->>DMS: Lock failed (already locked)
            DMS->>DMS: Try next driver
        end
    end
```

## 3. Real-Time Location Tracking Flow

```mermaid
sequenceDiagram
    participant D as Driver App
    participant WS as WebSocket Server
    participant REDIS as Redis
    participant PS as Pub/Sub
    participant KAFKA as Kafka
    participant R as Rider App

    D->>WS: WS Connect /v1/driver/location
    WS->>WS: Authenticate JWT

    loop Every 3-5 seconds
        D->>WS: {lat, lon, speed, timestamp}
        WS->>REDIS: GEOADD drivers:available
        WS->>REDIS: SET location:{driverId}
        WS->>PS: PUBLISH driver_location:{driverId}
        WS->>KAFKA: driver.location_updated
    end

    R->>WS: WS Connect /v1/trip/{tripId}/track
    WS->>PS: SUBSCRIBE driver_location:{driverId}
    
    PS-->>WS: Location update
    WS->>R: {driver_location, eta}
    R->>R: Update map marker + ETA
```

## 4. Surge Pricing Algorithm Flow

```mermaid
flowchart TD
    subgraph Surge_Calculator["Surge Calculator - Every 60 sec"]
        A[Start] --> B[Get Geohash Area]
        B --> C["Query Redis: GEORADIUS"]
        C --> D[Count Available Drivers]
        D --> E["Query DB: Pending requests"]
        E --> F[Calculate demand_ratio]
        
        F --> G{"demand_ratio < 1.2?"}
        G -->|Yes| H["surge = 1.0x"]
        G -->|No| I{"1.2-2.0?"}
        I -->|Yes| J["surge = 1.2x"]
        I -->|No| K{"2.0-3.0?"}
        K -->|Yes| L["surge = 1.5x"]
        K -->|No| M{"3.0-5.0?"}
        M -->|Yes| N["surge = 1.8x"]
        M -->|No| O["surge = 2.0-3.0x max"]
        
        H --> P["Apply Smoothing"]
        J --> P
        L --> P
        N --> P
        O --> P
        
        P --> Q["Store in Redis TTL 120s"]
        Q --> R[Notify users in area]
    end

    style Surge_Calculator fill:#f5f5f5
```

## 5. Database Entity Relationship Diagram

```mermaid
erDiagram
    RIDERS ||--o{ TRIPS : requests
    RIDERS ||--o{ RATINGS : gives
    RIDERS ||--o{ PAYMENTS : makes
    RIDERS ||--o{ DEVICE_TOKENS : has
    
    DRIVERS ||--o{ TRIPS : drives
    DRIVERS ||--o{ RATINGS : receives
    DRIVERS ||--o{ LOCATION_HISTORY : generates
    DRIVERS ||--o{ DEVICE_TOKENS : has
    
    TRIPS ||--|| RATINGS : has
    TRIPS ||--|| PAYMENTS : has
    TRIPS ||--o{ LOCATION_HISTORY : tracks
    
    RIDERS {
        uuid rider_id PK
        string name
        string email UK
        string phone UK
        jsonb payment_methods
        decimal avg_rating
        int total_trips
    }
    
    DRIVERS {
        uuid driver_id PK
        string name
        string email UK
        enum vehicle_type
        string license_plate
        enum status
        uuid current_trip_id FK
        decimal avg_rating
        geography current_location
    }
    
    TRIPS {
        uuid trip_id PK
        uuid rider_id FK
        uuid driver_id FK
        geography pickup_location
        geography drop_location
        enum status
        decimal estimated_fare
        decimal actual_fare
        decimal surge_multiplier
        timestamp start_time
        timestamp end_time
    }
    
    RATINGS {
        uuid rating_id PK
        uuid trip_id FK
        uuid rider_id FK
        uuid driver_id FK
        int driver_rating
        int rider_rating
        text feedback
    }
    
    PAYMENTS {
        uuid payment_id PK
        uuid trip_id FK
        decimal amount
        enum payment_method
        enum status
        string stripe_payment_id
    }
    
    LOCATION_HISTORY {
        bigint id PK
        uuid driver_id FK
        uuid trip_id FK
        geography location
        decimal speed
        timestamp recorded_at
    }
```

## 6. Zookeeper Driver Locking Mechanism

```mermaid
flowchart LR
    subgraph Concurrent_Requests["3 Concurrent Requests for Driver D1"]
        R1[Request R1]
        R2[Request R2]
        R3[Request R3]
    end

    subgraph Zookeeper["Zookeeper /locks/drivers/D1/"]
        direction TB
        N1["seq0001 - Lock Acquired"]
        N2["seq0002 - Lock Failed"]
        N3["seq0003 - Lock Failed"]
    end

    subgraph Result["Outcome"]
        direction TB
        O1[R1: Assigns D1 ✅]
        O2[R2: Try Driver D2 →]
        O3[R3: Try Driver D3 →]
    end

    R1 --> N1
    R2 --> N2
    R3 --> N3
    
    N1 --> O1
    N2 --> O2
    N3 --> O3

    style N1 fill:#4CAF50,color:#fff
    style N2 fill:#f44336,color:#fff
    style N3 fill:#f44336,color:#fff
```

## 7. Trip State Machine

```mermaid
stateDiagram-v2
    [*] --> PENDING: Rider requests ride
    
    PENDING --> MATCHED: Driver accepts
    PENDING --> NO_DRIVERS: No drivers available
    PENDING --> CANCELLED_BY_RIDER: Rider cancels
    
    MATCHED --> DRIVER_ARRIVED: Driver at pickup
    MATCHED --> CANCELLED_BY_RIDER: Rider cancels
    MATCHED --> CANCELLED_BY_DRIVER: Driver cancels
    
    DRIVER_ARRIVED --> IN_PROGRESS: Trip started
    DRIVER_ARRIVED --> CANCELLED_BY_RIDER: Rider no-show
    DRIVER_ARRIVED --> CANCELLED_BY_DRIVER: Driver cancels
    
    IN_PROGRESS --> COMPLETED: Trip completed
    
    COMPLETED --> [*]
    CANCELLED_BY_RIDER --> [*]
    CANCELLED_BY_DRIVER --> [*]
    NO_DRIVERS --> [*]
```

## 8. Notification Flow

```mermaid
flowchart TB
    subgraph Events["Kafka Events"]
        E1[ride.matched]
        E2[trip.started]
        E3[trip.completed]
        E4[driver.ride_offered]
    end

    subgraph NS["Notification Service"]
        C[Kafka Consumer]
        B[Build Payload]
        R[Route to Channel]
    end

    subgraph Channels["Delivery Channels"]
        FCM["Firebase FCM - Android"]
        APN["Apple APN - iOS"]
        WS["WebSocket - In-App"]
        SMS["SMS Fallback"]
    end

    subgraph Devices["User Devices"]
        AD[Android App]
        IP[iPhone App]
    end

    E1 --> C
    E2 --> C
    E3 --> C
    E4 --> C
    
    C --> B
    B --> R
    
    R --> FCM
    R --> APN
    R --> WS
    R -.-> SMS
    
    FCM --> AD
    APN --> IP
    WS --> AD
    WS --> IP

    style FCM fill:#4CAF50,color:#fff
    style APN fill:#000,color:#fff
```

## 9. Redis Data Structure Overview

```mermaid
flowchart TB
    subgraph Redis_Cluster["Redis Cluster"]
        subgraph Geo["Geospatial Index"]
            G1["drivers:available - GEOADD"]
            G2["drivers:available:sedan"]
        end
        
        subgraph Status["Driver Status TTL: 5min"]
            S1["driver:id:status"]
        end
        
        subgraph Location["Location Cache TTL: 1min"]
            L1["location:id - lat/lon"]
        end
        
        subgraph Trip["Trip Cache TTL: 2hr"]
            T1["trip:id:status"]
        end
        
        subgraph Surge["Surge TTL: 2min"]
            SR1["surge_multiplier:geohash"]
        end
        
        subgraph Request["Ride Request TTL: 10min"]
            RQ1["ride_request:id"]
        end
        
        subgraph PubSub["Pub/Sub Channels"]
            PS1["driver_location:id"]
            PS2["user:id:notifications"]
        end
    end

    style Geo fill:#e74c3c,color:#fff
    style Status fill:#3498db,color:#fff
    style Location fill:#2ecc71,color:#fff
    style Surge fill:#f39c12,color:#fff
```

## 10. Scaling Architecture

```mermaid
flowchart TB
    subgraph Users["Global Users"]
        US[US Users]
        EU[EU Users]
        APAC[APAC Users]
    end

    subgraph CDN["CDN Layer"]
        CF["CloudFront/Cloudflare"]
    end

    subgraph Regional["Regional Deployments"]
        subgraph US_Region["US Region"]
            US_LB[Load Balancer]
            US_API[API Servers x10]
            US_WS[WebSocket x20]
            US_REDIS[(Redis Cluster)]
            US_DB[(PostgreSQL)]
        end
        
        subgraph EU_Region["EU Region"]
            EU_LB[Load Balancer]
            EU_API[API Servers x10]
            EU_WS[WebSocket x20]
            EU_REDIS[(Redis Cluster)]
            EU_DB[(PostgreSQL)]
        end
    end

    subgraph Global["Global Services"]
        KAFKA["Kafka Cluster 100+ partitions"]
        ZK["Zookeeper 5-node ensemble"]
        ANALYTICS["Analytics - Spark/Flink"]
    end

    US --> CF --> US_Region
    EU --> CF --> EU_Region
    APAC --> CF --> US_Region
    
    US_Region --> KAFKA
    EU_Region --> KAFKA
    KAFKA --> ANALYTICS
    
    US_Region --> ZK
    EU_Region --> ZK
```

---

## Key Metrics Summary

| Component | Metric | Value |
|-----------|--------|-------|
| Redis GEORADIUS | 1M drivers search | ~10ms |
| Zookeeper Lock | Acquisition time | <10ms |
| WebSocket | Concurrent connections/instance | 10K |
| Kafka | Events/second | 100K+ |
| Driver Assignment | End-to-end latency | <1 sec |
| Push Notification | Delivery latency | 1-3 sec |
| WebSocket Update | In-app latency | <100ms |

---

## 11. Database Schema (PostgreSQL + PostGIS)

### Complete Entity Relationship Diagram

```mermaid
erDiagram
    RIDERS ||--o{ TRIPS : "requests"
    RIDERS ||--o{ RATINGS : "gives"
    RIDERS ||--o{ PAYMENTS : "makes"
    RIDERS ||--o{ RIDE_REQUESTS : "creates"
    RIDERS ||--o{ FARE_ESTIMATES : "requests"
    RIDERS ||--o{ PROMO_USAGE : "uses"
    
    DRIVERS ||--o{ TRIPS : "drives"
    DRIVERS ||--o{ RATINGS : "receives"
    DRIVERS ||--o{ LOCATION_HISTORY : "generates"
    DRIVERS ||--o{ DRIVER_PAYOUTS : "receives"
    
    TRIPS ||--o| RATINGS : "has"
    TRIPS ||--o| PAYMENTS : "has"
    TRIPS ||--o{ LOCATION_HISTORY : "tracks"
    TRIPS ||--o{ NOTIFICATIONS : "triggers"
    
    PROMO_CODES ||--o{ PROMO_USAGE : "applied"
    
    RIDERS {
        uuid rider_id PK
        varchar name
        varchar email UK
        varchar phone UK
        varchar profile_photo
        jsonb payment_methods
        decimal avg_rating
        int total_trips
        boolean is_active
        boolean is_verified
        timestamp created_at
    }
    
    DRIVERS {
        uuid driver_id PK
        varchar name
        varchar email UK
        varchar phone
        enum vehicle_type
        varchar vehicle_model
        varchar license_plate
        enum status
        uuid current_trip_id FK
        geography current_location
        decimal avg_rating
        decimal acceptance_rate
        boolean is_verified
        timestamp last_online_at
    }
    
    TRIPS {
        uuid trip_id PK
        uuid rider_id FK
        uuid driver_id FK
        geography pickup_location
        geography drop_location
        enum status
        enum vehicle_type
        decimal estimated_fare
        decimal actual_fare
        decimal surge_multiplier
        enum payment_status
        timestamp requested_at
        timestamp start_time
        timestamp end_time
    }
    
    RIDE_REQUESTS {
        uuid request_id PK
        uuid rider_id FK
        geography pickup_location
        geography drop_location
        enum vehicle_type
        decimal estimated_fare
        varchar status
        uuid[] drivers_notified
        timestamp expires_at
    }
    
    RATINGS {
        uuid rating_id PK
        uuid trip_id FK
        uuid rider_id FK
        uuid driver_id FK
        int driver_rating
        int rider_rating
        text rider_feedback
        text driver_feedback
        timestamp created_at
    }
    
    PAYMENTS {
        uuid payment_id PK
        uuid trip_id FK
        uuid rider_id FK
        decimal amount
        enum payment_method
        varchar stripe_payment_id
        enum status
        decimal tip
        timestamp completed_at
    }
    
    LOCATION_HISTORY {
        bigint id PK
        uuid driver_id FK
        uuid trip_id FK
        geography location
        decimal speed
        decimal accuracy
        timestamp recorded_at
    }
    
    DRIVER_PAYOUTS {
        uuid payout_id PK
        uuid driver_id FK
        decimal amount
        date period_start
        date period_end
        decimal platform_fee
        varchar status
        timestamp processed_at
    }
    
    SURGE_PRICING {
        bigint id PK
        varchar geohash
        decimal surge_multiplier
        int available_drivers
        int pending_requests
        timestamp calculated_at
    }
    
    FARE_ESTIMATES {
        uuid estimate_id PK
        uuid rider_id FK
        geography pickup_location
        geography drop_location
        enum vehicle_type
        decimal estimated_fare
        timestamp expires_at
    }
    
    DEVICE_TOKENS {
        bigint id PK
        uuid user_id
        varchar user_type
        varchar device_token
        varchar platform
        boolean is_active
    }
    
    NOTIFICATIONS {
        uuid notification_id PK
        uuid user_id
        varchar user_type
        varchar title
        text body
        uuid trip_id FK
        varchar status
        timestamp sent_at
    }
    
    PROMO_CODES {
        uuid promo_id PK
        varchar code UK
        varchar discount_type
        decimal discount_value
        int max_uses
        boolean is_active
        timestamp valid_until
    }
    
    PROMO_USAGE {
        bigint id PK
        uuid promo_id FK
        uuid rider_id FK
        uuid trip_id FK
        decimal discount_applied
        timestamp used_at
    }
```

### Table Summary

| Table | Description | Key Columns |
|-------|-------------|-------------|
| **riders** | User accounts | rider_id, email, phone, payment_methods, avg_rating |
| **drivers** | Driver profiles | driver_id, vehicle_type, status, current_location, avg_rating |
| **trips** | All ride records | trip_id, rider_id, driver_id, status, fare, timestamps |
| **ride_requests** | Pending requests before matching | request_id, expires_at, drivers_notified |
| **ratings** | Trip ratings (anonymous) | rating_id, driver_rating, rider_rating |
| **payments** | Payment records | payment_id, amount, stripe_payment_id, status |
| **location_history** | Driver GPS tracking | driver_id, trip_id, location, speed |
| **driver_payouts** | Driver earnings | payout_id, amount, period_start/end |
| **surge_pricing** | Historical surge data | geohash, surge_multiplier, demand_ratio |
| **fare_estimates** | Cached fare estimates | estimate_id, estimated_fare, expires_at (5 min) |
| **device_tokens** | Push notification tokens | user_id, device_token, platform |
| **notifications** | Notification history | notification_id, type, status, sent_at |
| **promo_codes** | Discount codes | code, discount_type, max_uses |

### Key Indexes

```sql
-- Geospatial Indexes (GIST)
CREATE INDEX idx_drivers_location ON drivers USING GIST (current_location);
CREATE INDEX idx_trips_pending_location ON trips USING GIST (pickup_location) WHERE status = 'PENDING';

-- Status & Lookup Indexes
CREATE INDEX idx_drivers_active_available ON drivers(status) WHERE is_active = TRUE AND status = 'AVAILABLE';
CREATE INDEX idx_trips_rider ON trips(rider_id, created_at DESC);
CREATE INDEX idx_trips_driver ON trips(driver_id, created_at DESC);

-- Time-based Indexes
CREATE INDEX idx_location_history_recorded ON location_history(recorded_at DESC);
CREATE INDEX idx_surge_pricing_geohash ON surge_pricing(geohash, calculated_at DESC);
```

### Enums

```sql
-- Driver Status
CREATE TYPE driver_status AS ENUM ('AVAILABLE', 'BUSY', 'OFFLINE', 'IN_TRIP');

-- Vehicle Types
CREATE TYPE vehicle_type AS ENUM ('sedan', 'suv', 'bike', 'auto', 'pool');

-- Trip Status
CREATE TYPE trip_status AS ENUM (
    'PENDING', 'MATCHED', 'DRIVER_ARRIVED', 
    'IN_PROGRESS', 'COMPLETED', 
    'CANCELLED_BY_RIDER', 'CANCELLED_BY_DRIVER'
);

-- Payment Status
CREATE TYPE payment_status AS ENUM ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED');

-- Payment Method
CREATE TYPE payment_method_type AS ENUM ('card', 'wallet', 'cash', 'upi', 'net_banking');
```

### Key Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DATABASE RELATIONSHIPS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  RIDERS ──────┬──────────────────────────────────────┐                      │
│       │       │                                       │                      │
│       │       ▼                                       ▼                      │
│       │   TRIPS ◄───────────────────────────── DRIVERS                      │
│       │       │                                       │                      │
│       │       ├──────────┬──────────┬────────────────┤                      │
│       │       │          │          │                │                      │
│       │       ▼          ▼          ▼                ▼                      │
│       │   RATINGS    PAYMENTS   NOTIFICATIONS   LOCATION_HISTORY            │
│       │                                                                      │
│       └──► RIDE_REQUESTS ──► (becomes) ──► TRIPS                            │
│       │                                                                      │
│       └──► FARE_ESTIMATES (TTL: 5 min)                                      │
│       │                                                                      │
│       └──► PROMO_USAGE ◄──── PROMO_CODES                                    │
│                                                                              │
│  DRIVERS ──► DRIVER_PAYOUTS (weekly/bi-weekly settlements)                  │
│                                                                              │
│  (Analytics) SURGE_PRICING ──► Historical demand/supply tracking            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```
