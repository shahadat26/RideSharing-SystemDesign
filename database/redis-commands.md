# Redis Commands Reference for Ride Sharing System

## 1. Geospatial Commands (Driver Location)

### Add Driver to Available Pool
```redis
# Add driver with location
GEOADD drivers:available -122.4194 37.7749 driver_123

# Add multiple drivers
GEOADD drivers:available -122.4194 37.7749 driver_123 -122.4094 37.7849 driver_456
```

### Find Nearby Drivers
```redis
# Find drivers within 5km radius, sorted by distance
GEORADIUS drivers:available -122.4194 37.7749 5 km WITHDIST ASC COUNT 10

# Response: [(driver_123, 0.8), (driver_456, 1.2), ...]

# Using newer GEOSEARCH command (Redis 6.2+)
GEOSEARCH drivers:available FROMMEMBER rider_location BYRADIUS 5 km ASC
```

### Get Driver Location
```redis
GEOPOS drivers:available driver_123
# Response: [[-122.4194, 37.7749]]
```

### Calculate Distance Between Two Points
```redis
GEODIST drivers:available driver_123 driver_456 km
# Response: "1.5"
```

### Remove Driver from Available Pool
```redis
ZREM drivers:available driver_123
```

---

## 2. Driver Status Management

### Set Driver Status (with TTL)
```redis
# AVAILABLE status with 5 min TTL (refreshed by heartbeat)
SET driver:driver_123:status AVAILABLE EX 300

# BUSY status when assigned to ride
SET driver:driver_123:status BUSY EX 900

# Possible values: AVAILABLE, BUSY, OFFLINE, IN_TRIP
```

### Get Driver Status
```redis
GET driver:driver_123:status
# Response: "AVAILABLE"
```

### Check If Driver Available
```redis
EXISTS driver:driver_123:status
# Response: 1 (exists) or 0 (offline/TTL expired)
```

### Refresh Heartbeat (Extend TTL)
```redis
EXPIRE driver:driver_123:status 300
```

---

## 3. Location Cache

### Store Driver Location (JSON)
```redis
SET location:driver_123 '{"lat":37.7749,"lon":-122.4194,"timestamp":1711929600,"speed":25}' EX 60
```

### Get Driver Location
```redis
GET location:driver_123
# Response: {"lat":37.7749,"lon":-122.4194,"timestamp":1711929600,"speed":25}
```

---

## 4. Trip Status

### Set Trip Status
```redis
# Status with 2 hour max trip duration
SET trip:trip_abc:status MATCHED EX 7200

# Possible values: PENDING, MATCHED, DRIVER_ARRIVED, IN_PROGRESS, COMPLETED
```

### Get Trip Status
```redis
GET trip:trip_abc:status
```

### Store Trip Details (Hash)
```redis
HSET trip:trip_abc:details \
  rider_id "rider_123" \
  driver_id "driver_456" \
  status "IN_PROGRESS" \
  eta_min 8 \
  last_updated 1711929600

# Set TTL on hash
EXPIRE trip:trip_abc:details 7200
```

### Get Trip Details
```redis
HGETALL trip:trip_abc:details
```

---

## 5. Surge Pricing

### Set Surge Multiplier for Area
```redis
# Area identified by geohash, 2 min TTL
SET surge_multiplier:9q8yy 1.8 EX 120
```

### Get Surge Multiplier
```redis
GET surge_multiplier:9q8yy
# Response: "1.8" (or nil if no surge)
```

### Batch Get Multiple Areas
```redis
MGET surge_multiplier:9q8yy surge_multiplier:9q8yw surge_multiplier:9q8yz
```

---

## 6. Ride Request Cache

### Store Ride Request
```redis
SET ride_request:req_123 '{"rider_id":"rider_456","pickup_lat":37.7749,"pickup_lon":-122.4194,"drop_lat":37.7849,"drop_lon":-122.4094,"vehicle_type":"sedan","estimated_fare":20.85}' EX 600

# 10 min TTL - expires if no driver found
```

### Get Ride Request
```redis
GET ride_request:req_123
```

### Check Request Exists
```redis
EXISTS ride_request:req_123
```

### Delete Request (when matched)
```redis
DEL ride_request:req_123
```

---

## 7. Fare Estimate Cache

### Store Fare Estimate
```redis
SET fare_estimate:est_abc '{"base_fare":2.5,"distance_fare":7.8,"time_fare":3.6,"surge":1.5,"total":20.85}' EX 300

# 5 min TTL - estimate valid for 5 minutes
```

### Get Fare Estimate
```redis
GET fare_estimate:est_abc
```

---

## 8. Driver Current Trip Reference

### Set Current Trip for Driver
```redis
SET driver:driver_123:current_trip trip_abc EX 7200
```

### Get Driver's Current Trip
```redis
GET driver:driver_123:current_trip
```

### Clear on Trip Complete
```redis
DEL driver:driver_123:current_trip
```

---

## 9. Pub/Sub for Real-Time Updates

### Publish Driver Location Update
```redis
PUBLISH driver_location:driver_123 '{"lat":37.7849,"lon":-122.4094,"timestamp":1711929600}'
```

### Subscribe to Driver Location
```redis
SUBSCRIBE driver_location:driver_123
```

### Publish User Notification
```redis
PUBLISH user:rider_456:notifications '{"type":"ride_matched","driver":"John","eta":5}'
```

### Pattern Subscribe (all drivers)
```redis
PSUBSCRIBE driver_location:*
```

---

## 10. Vehicle Type Filtering

### Separate Geospatial Index per Vehicle Type
```redis
# Add to type-specific index
GEOADD drivers:available:sedan -122.4194 37.7749 driver_123
GEOADD drivers:available:suv -122.4094 37.7849 driver_789

# Search only sedans within 5km
GEORADIUS drivers:available:sedan -122.4194 37.7749 5 km WITHDIST ASC
```

### Check if Driver is of Specific Type (Set)
```redis
# Add driver to vehicle type set
SADD drivers:sedan driver_123

# Check membership
SISMEMBER drivers:sedan driver_123
# Response: 1 (is sedan) or 0 (not sedan)
```

---

## 11. Rate Limiting

### Rider Request Rate Limit (10 requests/hour)
```redis
# Increment counter on each request
INCR rate_limit:rider:rider_123:ride_requests
# Set expiry if first request
EXPIRE rate_limit:rider:rider_123:ride_requests 3600

# Check current count
GET rate_limit:rider:rider_123:ride_requests
```

### Driver Location Update Rate Limit
```redis
# Using token bucket pattern
SET rate_limit:driver:driver_123:location_updates 20 EX 60
DECR rate_limit:driver:driver_123:location_updates
```

---

## 12. Hotspot Caching (High-Traffic Areas)

### Cache Top Drivers for Popular Pickup Points
```redis
# Airport, train station, etc.
SET nearby_drivers:9q8yy8 '["driver_1","driver_2","driver_3"]' EX 10

# Very short TTL (10 sec) - frequently refreshed
```

---

## 13. Session Management

### WebSocket Session Tracking
```redis
HSET ws_session:driver_123 \
  session_id "sess_abc" \
  server_id "ws_server_5" \
  connected_at 1711929600

EXPIRE ws_session:driver_123 300
```

---

## 14. Atomic Operations for Consistency

### Atomic Driver Assignment
```lua
-- Lua script for atomic driver status update
local key = KEYS[1]
local current = redis.call('GET', key)
if current == 'AVAILABLE' then
    redis.call('SET', key, 'BUSY', 'EX', 900)
    return 1
else
    return 0
end
```

### Execute Lua Script
```redis
EVAL "local key=KEYS[1] local current=redis.call('GET',key) if current=='AVAILABLE' then redis.call('SET',key,'BUSY','EX',900) return 1 else return 0 end" 1 driver:driver_123:status
```

---

## 15. Monitoring & Debugging

### Check Memory Usage
```redis
MEMORY USAGE drivers:available
INFO memory
```

### Count Drivers in Pool
```redis
ZCARD drivers:available
```

### Debug Geospatial Index
```redis
GEOHASH drivers:available driver_123
# Response: ["9q8yy8"]
```

### Check Key TTL
```redis
TTL driver:driver_123:status
# Response: 287 (seconds remaining)
```

---

## Key TTL Summary

| Key Pattern | TTL | Purpose |
|------------|-----|---------|
| `driver:{id}:status` | 300s (5 min) | Driver availability, refreshed by heartbeat |
| `location:{id}` | 60s (1 min) | Driver location cache, updated every 3-5s |
| `trip:{id}:status` | 7200s (2 hr) | Active trip status |
| `surge_multiplier:{geohash}` | 120s (2 min) | Surge pricing per area |
| `ride_request:{id}` | 600s (10 min) | Pending ride request |
| `fare_estimate:{id}` | 300s (5 min) | Fare estimate cache |
| `nearby_drivers:{geohash}` | 10s | Hotspot driver cache |
