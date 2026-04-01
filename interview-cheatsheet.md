# Ride Sharing System Design - Interview Cheat Sheet 📝

## Quick Answer Template

> **Opening Statement:**
> "Uber/Ola is a ride-sharing platform connecting riders with drivers. Core flow: Rider requests → Geo-search nearby drivers → Zookeeper lock (prevent double assignment) → Driver accepts → WebSocket location tracking → Trip completion → Payment & Rating"

---

## 🎯 Key Numbers to Remember

| Metric | Value | Context |
|--------|-------|---------|
| Concurrent Rides | **100K** | Peak hours globally |
| Driver Location Updates | **Every 3-5 sec** | Via WebSocket |
| Driver Assignment Latency | **< 1 sec** | Geo-search + lock |
| Geospatial Query | **~10ms** | 1M drivers, GEORADIUS |
| Zookeeper Lock | **< 10ms** | Acquisition time |
| Session Timeout | **30 sec** | Ephemeral node TTL |
| Surge Recalculation | **Every 60 sec** | Per geohash area |
| Max Surge | **3.0×** | Price cap |
| Push Notification | **1-3 sec** | FCM/APN latency |
| WebSocket In-App | **< 100ms** | Real-time updates |

---

## ⚠️ Critical Interview Questions

### Q1: How do you prevent double assignment of a driver?

**Answer:**
```
Use Zookeeper distributed locking with ephemeral sequential nodes:

1. Request R1 creates /locks/drivers/D1/request_R1_seq0001
2. Concurrent R2 gets /locks/drivers/D1/request_R2_seq0002
3. Each checks if their node is LOWEST sequence
4. R1 (seq0001) → Lock acquired → Assigns driver
5. R2 (seq0002) → Lock failed → Tries next driver

Why Zookeeper?
- Strong consistency (CP system)
- Ephemeral nodes auto-delete on failure
- Atomic operations with ordering
- 30-sec session timeout for auto-cleanup
```

### Q2: How does real-time location tracking work?

**Answer:**
```
WebSocket bidirectional persistent connection:

Driver Side:
1. WS connect: /v1/driver/location
2. Every 3-5 sec: send {lat, lon, speed, timestamp}
3. Server: GEOADD drivers:available {lon} {lat} {id}
4. Server: PUBLISH to Pub/Sub for subscribers

Rider Side:
1. WS connect: /v1/trip/{tripId}/track
2. Subscribe to driver_location:{driverId} channel
3. Receive real-time updates → Update map marker

Why WebSocket > HTTP Polling?
- Polling: 100K riders × 20 req/min = 33K req/sec overhead
- WebSocket: Persistent, send only on change, 100x less traffic, <100ms latency
```

### Q3: How do you handle surge pricing?

**Answer:**
```
Real-time supply/demand balancing:

Every 60 sec per geohash area (5km × 5km):
1. Count available drivers: GEORADIUS drivers:available 5km
2. Count pending requests: DB query last 10 min
3. demand_ratio = pending / available

Multiplier Rules:
- < 1.2 → 1.0× (no surge)
- 1.2-2.0 → 1.2× (low)
- 2.0-3.0 → 1.5× (medium)
- 3.0-5.0 → 1.8× (high)
- >= 5.0 → 2.0-3.0× (max cap)

Smoothing: new = 0.7×old + 0.3×calculated
Store: SET surge_multiplier:{geohash} 1.8 EX 120
```

### Q4: How do you find nearby drivers efficiently?

**Answer:**
```
Redis Geospatial Index:

1. Store: GEOADD drivers:available {lon} {lat} {driver_id}
2. Search: GEORADIUS drivers:available {lon} {lat} 5 km WITHDIST ASC COUNT 10

Performance:
- O(log(N)) complexity
- ~10ms for 1M drivers
- Geohash encoding enables quick pruning

For vehicle type filtering:
- Maintain separate indexes: drivers:available:sedan, drivers:available:suv
- OR use SISMEMBER drivers:sedan {driver_id} to filter results
```

---

## 📊 Core Database Tables

```
RIDERS: rider_id, name, email, phone, payment_methods, avg_rating
DRIVERS: driver_id, name, vehicle_type, license_plate, status, avg_rating, current_location
TRIPS: trip_id, rider_id, driver_id, pickup/drop_location, status, fare, timestamps
RATINGS: rating_id, trip_id, driver_rating, rider_rating, feedback
PAYMENTS: payment_id, trip_id, amount, method, status, stripe_id
```

---

## 🔴 Redis Data Structures

| Key | Type | TTL | Purpose |
|-----|------|-----|---------|
| `drivers:available` | Geospatial | - | Proximity search |
| `driver:{id}:status` | String | 5 min | AVAILABLE/BUSY/OFFLINE |
| `location:{id}` | String (JSON) | 1 min | Current lat/lon |
| `trip:{id}:status` | String | 2 hr | MATCHED/IN_PROGRESS |
| `surge_multiplier:{geohash}` | String | 2 min | Surge value |
| `ride_request:{id}` | String (JSON) | 10 min | Pending request |

---

## 📬 Kafka Topics

| Topic | Producers | Consumers |
|-------|-----------|-----------|
| `ride.requested` | Ride Service | Driver Matching |
| `ride.matched` | Ride Service | Notification, Analytics |
| `trip.completed` | Ride Service | Notification, Analytics |
| `driver.location_updated` | Location Update Svc | Trip Update Consumer |

---

## 🏗️ Architecture Components

```
Clients → Load Balancer → API Gateway
          ↓
    ┌─────────────────────────────────┐
    │ Ride Service (fare calculation)  │
    │ Driver Matching (geo-proximity)  │
    │ Location Map Svc (Google Maps)   │
    │ Rating Service                   │
    │ Payment Service                  │
    └─────────────────────────────────┘
          ↓
    ┌─────────────────────────────────┐
    │ Redis (cache + geospatial)       │
    │ Zookeeper (driver locks)         │
    │ Kafka (event streaming)          │
    └─────────────────────────────────┘
          ↓
    PostgreSQL (persistent storage)
```

---

## 🎯 CAP Theorem Application

| Component | CAP Choice | Reason |
|-----------|------------|--------|
| User-facing reads | **AP** | Availability > Consistency |
| Driver assignment | **CP** | Consistency > Availability (prevent double booking) |
| Location tracking | **AP** | Eventual consistency OK |
| Payment processing | **CP** | Strong consistency required |

---

## 💡 Key Optimization Techniques

1. **Redis GEORADIUS** - Sub-10ms proximity search on 1M drivers
2. **Zookeeper Locking** - Ephemeral nodes prevent double assignment
3. **WebSocket** - 100x less traffic than HTTP polling
4. **Kafka** - Decouple services, 100K+ events/sec
5. **Database Sharding** - Shard by geohash (trips) or ID (drivers)
6. **Surge Smoothing** - EMA prevents sudden price jumps
7. **CDN** - 95% cache hit for static assets

---

## ❌ Common Mistakes to Avoid

1. **DON'T** trust Redis alone for driver availability - always validate in DB
2. **DON'T** skip Zookeeper for driver assignment - will cause double booking
3. **DON'T** use HTTP polling for location - use WebSocket
4. **DON'T** forget surge cap (3.0×) - price gouging concerns
5. **DON'T** ignore geofencing - detect driver arrival at 50m

---

## 📱 Notification Types

| Event | Recipients | Channel |
|-------|------------|---------|
| Ride Matched | Rider, Driver | Push + WebSocket |
| Driver Arrived | Rider | Push + WebSocket |
| Trip Started | Rider | Push |
| Trip Completed | Rider, Driver | Push |
| Payment Processed | Rider | Push + Email |
| Surge Active | Nearby Riders | Push |

---

## 🔄 Trip Status Flow

```
PENDING → MATCHED → DRIVER_ARRIVED → IN_PROGRESS → COMPLETED
    ↓         ↓            ↓
CANCELLED_BY_RIDER   CANCELLED_BY_DRIVER
```

---

## 📝 One-Line Summaries

- **Zookeeper**: Distributed locks with ephemeral nodes, 30-sec auto-cleanup
- **Redis Geo**: GEORADIUS for sub-10ms proximity search
- **WebSocket**: Persistent bidirectional connection for real-time updates
- **Kafka**: Event streaming, decouples services, 100K+ msg/sec
- **Surge**: demand_ratio = requests/drivers, recalc every 60s, max 3.0×
- **ETA**: Google Maps API every 30 sec, broadcast via WebSocket

---

## 🎤 Interview Closing Statement

> "The key challenges in ride-sharing are: (1) preventing double driver assignment using Zookeeper locks, (2) efficient geospatial queries using Redis GEORADIUS, (3) real-time tracking via WebSocket, and (4) dynamic surge pricing to balance supply and demand. The system prioritizes availability for user-facing reads but enforces strong consistency for driver assignment and payments."
