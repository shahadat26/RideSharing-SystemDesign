-- ============================================================================
-- RIDE SHARING APPLICATION - DATABASE SCHEMA
-- (Like UBER | OLA | Rapido | Lyft)
-- ============================================================================

-- Enable PostGIS extension for geospatial data
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- RIDERS TABLE
-- ============================================================================
CREATE TABLE riders (
    rider_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(255) NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    phone           VARCHAR(20) UNIQUE NOT NULL,
    profile_photo   VARCHAR(500),
    payment_methods JSONB DEFAULT '[]',  -- [{type: 'card', last4: '1234', stripe_customer_id: 'cus_xxx'}]
    default_payment_method_id VARCHAR(100),
    avg_rating      DECIMAL(3,2) DEFAULT 5.00 CHECK (avg_rating >= 1.00 AND avg_rating <= 5.00),
    total_trips     INT DEFAULT 0,
    total_ratings   INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    is_verified     BOOLEAN DEFAULT FALSE,
    language        VARCHAR(10) DEFAULT 'en',
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_riders_email ON riders(email);
CREATE INDEX idx_riders_phone ON riders(phone);
CREATE INDEX idx_riders_active ON riders(is_active) WHERE is_active = TRUE;

-- ============================================================================
-- DRIVERS TABLE
-- ============================================================================
CREATE TYPE driver_status AS ENUM ('AVAILABLE', 'BUSY', 'OFFLINE', 'IN_TRIP');
CREATE TYPE vehicle_type AS ENUM ('sedan', 'suv', 'bike', 'auto', 'pool');

CREATE TABLE drivers (
    driver_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name              VARCHAR(255) NOT NULL,
    email             VARCHAR(255) UNIQUE NOT NULL,
    phone             VARCHAR(20) NOT NULL,
    profile_photo     VARCHAR(500),
    
    -- Vehicle Details
    vehicle_type      vehicle_type NOT NULL,
    vehicle_model     VARCHAR(100),           -- e.g., 'Toyota Camry 2020'
    vehicle_color     VARCHAR(50),
    license_plate     VARCHAR(20) NOT NULL,
    vehicle_photo     VARCHAR(500),
    
    -- Status & Current Trip
    status            driver_status DEFAULT 'OFFLINE',
    current_trip_id   UUID,                   -- FK added after trips table
    current_location  GEOGRAPHY(Point, 4326),
    
    -- Ratings & Stats
    avg_rating        DECIMAL(3,2) DEFAULT 5.00 CHECK (avg_rating >= 1.00 AND avg_rating <= 5.00),
    total_trips       INT DEFAULT 0,
    total_ratings     INT DEFAULT 0,
    acceptance_rate   DECIMAL(5,2) DEFAULT 100.00 CHECK (acceptance_rate >= 0 AND acceptance_rate <= 100),
    cancellation_rate DECIMAL(5,2) DEFAULT 0.00 CHECK (cancellation_rate >= 0 AND cancellation_rate <= 100),
    
    -- Documents & Verification
    is_verified       BOOLEAN DEFAULT FALSE,
    is_active         BOOLEAN DEFAULT TRUE,
    driver_license_number VARCHAR(50),
    driver_license_expiry DATE,
    insurance_number  VARCHAR(50),
    insurance_expiry  DATE,
    
    -- Activity Tracking
    last_online_at    TIMESTAMP WITH TIME ZONE,
    last_location_update TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_vehicle_type ON drivers(vehicle_type);
CREATE INDEX idx_drivers_current_trip ON drivers(current_trip_id);
CREATE INDEX idx_drivers_location ON drivers USING GIST (current_location);
CREATE INDEX idx_drivers_active_available ON drivers(status) WHERE is_active = TRUE AND status = 'AVAILABLE';

-- ============================================================================
-- TRIPS/RIDES TABLE
-- ============================================================================
CREATE TYPE trip_status AS ENUM (
    'PENDING',           -- Ride requested, waiting for driver match
    'MATCHED',           -- Driver assigned and accepted
    'DRIVER_ARRIVED',    -- Driver reached pickup location
    'IN_PROGRESS',       -- Trip started
    'COMPLETED',         -- Trip completed successfully
    'CANCELLED_BY_RIDER',
    'CANCELLED_BY_DRIVER',
    'NO_DRIVERS_AVAILABLE'
);

CREATE TYPE payment_status AS ENUM ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED');

CREATE TABLE trips (
    trip_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Participants
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    driver_id         UUID REFERENCES drivers(driver_id),
    
    -- Locations (PostGIS geography for accurate distance calculations)
    pickup_location   GEOGRAPHY(Point, 4326) NOT NULL,
    pickup_address    VARCHAR(500),
    drop_location     GEOGRAPHY(Point, 4326) NOT NULL,
    drop_address      VARCHAR(500),
    
    -- Actual route (for completed trips)
    actual_route      GEOGRAPHY(LineString, 4326),
    
    -- Trip Details
    status            trip_status DEFAULT 'PENDING',
    vehicle_type      vehicle_type NOT NULL,
    
    -- Fare Information
    estimated_fare    DECIMAL(10,2),
    actual_fare       DECIMAL(10,2),
    base_fare         DECIMAL(10,2),
    distance_fare     DECIMAL(10,2),
    time_fare         DECIMAL(10,2),
    surge_multiplier  DECIMAL(3,2) DEFAULT 1.00,
    currency          VARCHAR(3) DEFAULT 'USD',
    
    -- Trip Metrics
    estimated_distance_km DECIMAL(10,2),
    actual_distance_km    DECIMAL(10,2),
    estimated_duration_min INT,
    actual_duration_min    INT,
    
    -- Payment
    payment_status    payment_status DEFAULT 'PENDING',
    payment_method    VARCHAR(20),
    
    -- Timestamps
    requested_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    matched_at        TIMESTAMP WITH TIME ZONE,
    driver_arrived_at TIMESTAMP WITH TIME ZONE,
    start_time        TIMESTAMP WITH TIME ZONE,
    end_time          TIMESTAMP WITH TIME ZONE,
    cancelled_at      TIMESTAMP WITH TIME ZONE,
    
    -- Cancellation Details
    cancellation_reason VARCHAR(255),
    cancellation_fee   DECIMAL(10,2) DEFAULT 0,
    
    -- Metadata
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign key to drivers table (circular reference)
ALTER TABLE drivers ADD CONSTRAINT fk_driver_current_trip 
    FOREIGN KEY (current_trip_id) REFERENCES trips(trip_id);

-- Indexes for trips
CREATE INDEX idx_trips_rider ON trips(rider_id, created_at DESC);
CREATE INDEX idx_trips_driver ON trips(driver_id, created_at DESC);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_trips_pending_location ON trips USING GIST (pickup_location) WHERE status = 'PENDING';
CREATE INDEX idx_trips_in_progress ON trips(status) WHERE status = 'IN_PROGRESS';
CREATE INDEX idx_trips_requested_at ON trips(requested_at DESC);

-- ============================================================================
-- RIDE REQUESTS TABLE (for pending requests before driver assignment)
-- ============================================================================
CREATE TABLE ride_requests (
    request_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    
    -- Locations
    pickup_location   GEOGRAPHY(Point, 4326) NOT NULL,
    pickup_address    VARCHAR(500),
    drop_location     GEOGRAPHY(Point, 4326) NOT NULL,
    drop_address      VARCHAR(500),
    
    -- Request Details
    vehicle_type      vehicle_type NOT NULL,
    estimated_fare    DECIMAL(10,2),
    surge_multiplier  DECIMAL(3,2) DEFAULT 1.00,
    
    -- Status
    status            VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'MATCHED', 'EXPIRED', 'CANCELLED')),
    
    -- Matching attempts
    drivers_notified  UUID[] DEFAULT '{}',
    drivers_declined  UUID[] DEFAULT '{}',
    match_attempts    INT DEFAULT 0,
    
    -- Timestamps
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at        TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '10 minutes'),
    matched_at        TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_ride_requests_status ON ride_requests(status);
CREATE INDEX idx_ride_requests_rider ON ride_requests(rider_id);
CREATE INDEX idx_ride_requests_pending ON ride_requests USING GIST (pickup_location) WHERE status = 'PENDING';

-- ============================================================================
-- RATINGS TABLE
-- ============================================================================
CREATE TABLE ratings (
    rating_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id           UUID UNIQUE NOT NULL REFERENCES trips(trip_id),
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    driver_id         UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Ratings (1-5 stars)
    driver_rating     INT CHECK (driver_rating BETWEEN 1 AND 5),   -- Rider rates driver
    rider_rating      INT CHECK (rider_rating BETWEEN 1 AND 5),    -- Driver rates rider
    
    -- Feedback
    rider_feedback    TEXT,         -- Rider's feedback about driver
    driver_feedback   TEXT,         -- Driver's feedback about rider
    
    -- Rating Categories (optional detailed ratings)
    driver_cleanliness_rating    INT CHECK (driver_cleanliness_rating BETWEEN 1 AND 5),
    driver_safety_rating         INT CHECK (driver_safety_rating BETWEEN 1 AND 5),
    driver_navigation_rating     INT CHECK (driver_navigation_rating BETWEEN 1 AND 5),
    
    -- Metadata
    driver_rated_at   TIMESTAMP WITH TIME ZONE,
    rider_rated_at    TIMESTAMP WITH TIME ZONE,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Note: Anonymous - drivers see aggregated ratings, not individual rider identity
CREATE INDEX idx_ratings_driver ON ratings(driver_id);
CREATE INDEX idx_ratings_rider ON ratings(rider_id);
CREATE INDEX idx_ratings_trip ON ratings(trip_id);

-- ============================================================================
-- PAYMENTS TABLE
-- ============================================================================
CREATE TYPE payment_method_type AS ENUM ('card', 'wallet', 'cash', 'upi', 'net_banking');

CREATE TABLE payments (
    payment_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id             UUID UNIQUE NOT NULL REFERENCES trips(trip_id),
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    
    -- Amount
    amount              DECIMAL(10,2) NOT NULL,
    currency            VARCHAR(3) DEFAULT 'USD',
    
    -- Payment Details
    payment_method      payment_method_type NOT NULL,
    stripe_payment_id   VARCHAR(255),         -- External payment gateway reference
    stripe_customer_id  VARCHAR(255),
    
    -- Breakdown
    base_fare           DECIMAL(10,2),
    distance_fare       DECIMAL(10,2),
    time_fare           DECIMAL(10,2),
    surge_fare          DECIMAL(10,2),
    taxes               DECIMAL(10,2) DEFAULT 0,
    discount            DECIMAL(10,2) DEFAULT 0,
    tip                 DECIMAL(10,2) DEFAULT 0,
    
    -- Status
    status              payment_status DEFAULT 'PENDING',
    failure_reason      VARCHAR(255),
    
    -- Refund info
    refund_amount       DECIMAL(10,2),
    refund_reason       VARCHAR(255),
    refunded_at         TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_payments_trip ON payments(trip_id);
CREATE INDEX idx_payments_rider ON payments(rider_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created ON payments(created_at DESC);

-- ============================================================================
-- DRIVER PAYOUTS TABLE
-- ============================================================================
CREATE TABLE driver_payouts (
    payout_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Payout Amount
    amount              DECIMAL(10,2) NOT NULL,
    currency            VARCHAR(3) DEFAULT 'USD',
    
    -- Period
    period_start        DATE NOT NULL,
    period_end          DATE NOT NULL,
    
    -- Details
    total_trips         INT DEFAULT 0,
    total_earnings      DECIMAL(10,2),
    platform_fee        DECIMAL(10,2),      -- Platform's commission
    bonuses             DECIMAL(10,2) DEFAULT 0,
    
    -- Status
    status              VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')),
    
    -- Bank Details (reference)
    bank_account_id     VARCHAR(100),
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at        TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_driver_payouts_driver ON driver_payouts(driver_id);
CREATE INDEX idx_driver_payouts_status ON driver_payouts(status);

-- ============================================================================
-- LOCATION HISTORY TABLE (for analytics & fraud detection)
-- ============================================================================
CREATE TABLE location_history (
    id              BIGSERIAL PRIMARY KEY,
    driver_id       UUID NOT NULL REFERENCES drivers(driver_id),
    trip_id         UUID REFERENCES trips(trip_id),
    
    -- Location
    location        GEOGRAPHY(Point, 4326) NOT NULL,
    
    -- Metadata
    speed           DECIMAL(5,2),           -- km/h
    accuracy        DECIMAL(5,2),           -- meters
    heading         DECIMAL(5,2),           -- degrees (0-360)
    altitude        DECIMAL(8,2),           -- meters
    
    -- Timestamps
    recorded_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Partition by month for better performance on historical data
CREATE INDEX idx_location_history_driver ON location_history(driver_id, recorded_at DESC);
CREATE INDEX idx_location_history_trip ON location_history(trip_id) WHERE trip_id IS NOT NULL;
CREATE INDEX idx_location_history_recorded ON location_history(recorded_at DESC);

-- ============================================================================
-- SURGE PRICING TABLE (historical tracking)
-- ============================================================================
CREATE TABLE surge_pricing (
    id              BIGSERIAL PRIMARY KEY,
    geohash         VARCHAR(12) NOT NULL,   -- Geohash of area
    
    -- Metrics
    surge_multiplier DECIMAL(3,2) NOT NULL,
    available_drivers INT,
    pending_requests  INT,
    demand_ratio      DECIMAL(5,2),
    
    -- Area Info
    center_lat       DECIMAL(10,7),
    center_lon       DECIMAL(10,7),
    
    -- Timestamps
    calculated_at    TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    valid_until      TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_surge_pricing_geohash ON surge_pricing(geohash, calculated_at DESC);
CREATE INDEX idx_surge_pricing_calculated ON surge_pricing(calculated_at DESC);

-- ============================================================================
-- FARE ESTIMATES TABLE (cache for fare estimates)
-- ============================================================================
CREATE TABLE fare_estimates (
    estimate_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    
    -- Locations
    pickup_location   GEOGRAPHY(Point, 4326) NOT NULL,
    drop_location     GEOGRAPHY(Point, 4326) NOT NULL,
    
    -- Estimate Details
    vehicle_type      vehicle_type NOT NULL,
    estimated_fare    DECIMAL(10,2) NOT NULL,
    base_fare         DECIMAL(10,2),
    distance_fare     DECIMAL(10,2),
    time_fare         DECIMAL(10,2),
    surge_multiplier  DECIMAL(3,2) DEFAULT 1.00,
    
    -- Route Info
    distance_km       DECIMAL(10,2),
    duration_min      INT,
    
    -- Validity
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at        TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '5 minutes')
);

CREATE INDEX idx_fare_estimates_rider ON fare_estimates(rider_id);
CREATE INDEX idx_fare_estimates_expiry ON fare_estimates(expires_at);

-- ============================================================================
-- DEVICE TOKENS TABLE (for push notifications)
-- ============================================================================
CREATE TABLE device_tokens (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL,
    user_type       VARCHAR(10) NOT NULL CHECK (user_type IN ('rider', 'driver')),
    
    -- Device Info
    device_token    VARCHAR(500) NOT NULL,
    platform        VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    device_id       VARCHAR(255),
    device_model    VARCHAR(100),
    app_version     VARCHAR(20),
    
    -- Status
    is_active       BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_used_at    TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(user_id, device_token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id, user_type);
CREATE INDEX idx_device_tokens_active ON device_tokens(user_id) WHERE is_active = TRUE;

-- ============================================================================
-- NOTIFICATIONS TABLE (notification history)
-- ============================================================================
CREATE TABLE notifications (
    notification_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           UUID NOT NULL,
    user_type         VARCHAR(10) NOT NULL CHECK (user_type IN ('rider', 'driver')),
    
    -- Notification Content
    title             VARCHAR(255) NOT NULL,
    body              TEXT NOT NULL,
    data              JSONB,                  -- Additional data payload
    
    -- Reference
    trip_id           UUID REFERENCES trips(trip_id),
    notification_type VARCHAR(50) NOT NULL,   -- ride_matched, trip_started, payment_completed, etc.
    
    -- Delivery Status
    status            VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'READ')),
    sent_at           TIMESTAMP WITH TIME ZONE,
    delivered_at      TIMESTAMP WITH TIME ZONE,
    read_at           TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user ON notifications(user_id, user_type);
CREATE INDEX idx_notifications_trip ON notifications(trip_id) WHERE trip_id IS NOT NULL;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ============================================================================
-- PROMO CODES TABLE
-- ============================================================================
CREATE TABLE promo_codes (
    promo_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code              VARCHAR(50) UNIQUE NOT NULL,
    
    -- Discount Details
    discount_type     VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value    DECIMAL(10,2) NOT NULL,
    max_discount      DECIMAL(10,2),          -- Max discount for percentage type
    min_trip_amount   DECIMAL(10,2) DEFAULT 0,
    
    -- Usage Limits
    max_uses          INT,
    max_uses_per_user INT DEFAULT 1,
    current_uses      INT DEFAULT 0,
    
    -- Validity
    valid_from        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    valid_until       TIMESTAMP WITH TIME ZONE,
    
    -- Restrictions
    vehicle_types     vehicle_type[],         -- NULL = all types
    user_ids          UUID[],                  -- NULL = all users
    first_trip_only   BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_active         BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_promo_codes_code ON promo_codes(code);
CREATE INDEX idx_promo_codes_active ON promo_codes(is_active, valid_until);

-- ============================================================================
-- USER PROMO USAGE TABLE
-- ============================================================================
CREATE TABLE promo_usage (
    id              BIGSERIAL PRIMARY KEY,
    promo_id        UUID NOT NULL REFERENCES promo_codes(promo_id),
    rider_id        UUID NOT NULL REFERENCES riders(rider_id),
    trip_id         UUID REFERENCES trips(trip_id),
    
    discount_applied DECIMAL(10,2),
    
    used_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_promo_usage_rider ON promo_usage(rider_id);
CREATE INDEX idx_promo_usage_promo ON promo_usage(promo_id);

-- ============================================================================
-- AUDIT LOG TABLE (for tracking important changes)
-- ============================================================================
CREATE TABLE audit_log (
    id              BIGSERIAL PRIMARY KEY,
    table_name      VARCHAR(50) NOT NULL,
    record_id       UUID NOT NULL,
    action          VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values      JSONB,
    new_values      JSONB,
    changed_by      UUID,
    changed_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_log_table ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_changed_at ON audit_log(changed_at DESC);

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_riders_updated_at BEFORE UPDATE ON riders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update driver average rating
CREATE OR REPLACE FUNCTION update_driver_avg_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE drivers 
    SET avg_rating = (
        SELECT COALESCE(AVG(driver_rating), 5.00)
        FROM ratings 
        WHERE driver_id = NEW.driver_id AND driver_rating IS NOT NULL
    ),
    total_ratings = (
        SELECT COUNT(*)
        FROM ratings 
        WHERE driver_id = NEW.driver_id AND driver_rating IS NOT NULL
    )
    WHERE driver_id = NEW.driver_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_driver_rating_trigger AFTER INSERT OR UPDATE ON ratings
    FOR EACH ROW EXECUTE FUNCTION update_driver_avg_rating();

-- Function to update rider average rating
CREATE OR REPLACE FUNCTION update_rider_avg_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE riders 
    SET avg_rating = (
        SELECT COALESCE(AVG(rider_rating), 5.00)
        FROM ratings 
        WHERE rider_id = NEW.rider_id AND rider_rating IS NOT NULL
    ),
    total_ratings = (
        SELECT COUNT(*)
        FROM ratings 
        WHERE rider_id = NEW.rider_id AND rider_rating IS NOT NULL
    )
    WHERE rider_id = NEW.rider_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_rider_rating_trigger AFTER INSERT OR UPDATE ON ratings
    FOR EACH ROW EXECUTE FUNCTION update_rider_avg_rating();

-- Function to increment trip count on completion
CREATE OR REPLACE FUNCTION update_trip_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'COMPLETED' AND (OLD.status IS NULL OR OLD.status != 'COMPLETED') THEN
        UPDATE riders SET total_trips = total_trips + 1 WHERE rider_id = NEW.rider_id;
        UPDATE drivers SET total_trips = total_trips + 1 WHERE driver_id = NEW.driver_id;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_trip_counts_trigger AFTER INSERT OR UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION update_trip_counts();

-- ============================================================================
-- SAMPLE QUERIES
-- ============================================================================

-- Find available drivers within 5km (similar to Redis GEORADIUS)
-- SELECT driver_id, name, vehicle_type,
--     ST_Distance(current_location, ST_MakePoint(-122.4194, 37.7749)::geography) as distance_meters
-- FROM drivers
-- WHERE status = 'AVAILABLE'
--     AND is_active = TRUE
--     AND ST_DWithin(current_location, ST_MakePoint(-122.4194, 37.7749)::geography, 5000)
-- ORDER BY distance_meters
-- LIMIT 10;

-- Get trip statistics for a driver
-- SELECT 
--     COUNT(*) as total_trips,
--     AVG(actual_fare) as avg_fare,
--     SUM(actual_distance_km) as total_distance,
--     AVG(driver_rating) as avg_rating
-- FROM trips t
-- LEFT JOIN ratings r ON t.trip_id = r.trip_id
-- WHERE t.driver_id = 'driver-uuid-here'
--     AND t.status = 'COMPLETED'
--     AND t.end_time >= CURRENT_DATE - INTERVAL '30 days';

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
