-- ============================================================================
-- RIDE SHARING APPLICATION - COMPLETE DATABASE SCHEMA
-- (Like UBER | OLA | Rapido | Lyft)
-- ============================================================================
-- This schema includes complete payment system with:
-- - Rider wallet management
-- - Driver earnings tracking
-- - Driver wallet & balance (cash owed, available balance)
-- - Commission collection from cash trips
-- - Payout management (weekly/instant)
-- ============================================================================

-- Enable Extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ENUMS
-- ============================================================================
CREATE TYPE driver_status AS ENUM ('AVAILABLE', 'BUSY', 'OFFLINE', 'IN_TRIP');
CREATE TYPE vehicle_type AS ENUM ('sedan', 'suv', 'bike', 'auto', 'pool', 'premium', 'xl');
CREATE TYPE trip_status AS ENUM (
    'PENDING',
    'MATCHED',
    'DRIVER_ARRIVED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED_BY_RIDER',
    'CANCELLED_BY_DRIVER',
    'NO_DRIVERS_AVAILABLE'
);
CREATE TYPE payment_status AS ENUM ('PENDING', 'AUTHORIZED', 'COMPLETED', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED');
CREATE TYPE payment_method_type AS ENUM ('card', 'wallet', 'cash', 'upi', 'net_banking');
CREATE TYPE payout_status AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');
CREATE TYPE driver_document_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED');
CREATE TYPE ticket_status AS ENUM ('OPEN', 'IN_PROGRESS', 'WAITING_ON_CUSTOMER', 'RESOLVED', 'CLOSED');
CREATE TYPE ticket_priority AS ENUM ('P0', 'P1', 'P2', 'P3', 'P4');

-- ============================================================================
-- CITIES TABLE (Service Areas)
-- ============================================================================
CREATE TABLE cities (
    city_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name              VARCHAR(100) NOT NULL,
    state             VARCHAR(100),
    country           VARCHAR(100) NOT NULL DEFAULT 'India',
    timezone          VARCHAR(50) NOT NULL DEFAULT 'Asia/Kolkata',
    currency          VARCHAR(10) DEFAULT 'INR',
    is_active         BOOLEAN DEFAULT TRUE,
    boundaries        GEOGRAPHY(Polygon, 4326),
    commission_rate   DECIMAL(5,2) DEFAULT 20.00,  -- Platform commission %
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- VEHICLE TYPES TABLE
-- ============================================================================
CREATE TABLE vehicle_types (
    vehicle_type_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name              VARCHAR(50) NOT NULL UNIQUE,
    display_name      VARCHAR(100) NOT NULL,
    description       VARCHAR(255),
    icon_url          VARCHAR(500),
    max_passengers    INT DEFAULT 4,
    is_active         BOOLEAN DEFAULT TRUE,
    sort_order        INT DEFAULT 0,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- FARE CONFIGS TABLE (Per City, Per Vehicle Type Pricing)
-- ============================================================================
CREATE TABLE fare_configs (
    config_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_id           UUID NOT NULL REFERENCES cities(city_id),
    vehicle_type      vehicle_type NOT NULL,
    
    -- Fare Components
    base_fare         DECIMAL(10,2) NOT NULL DEFAULT 50.00,
    per_km_rate       DECIMAL(10,2) NOT NULL DEFAULT 12.00,
    per_minute_rate   DECIMAL(10,2) NOT NULL DEFAULT 2.00,
    minimum_fare      DECIMAL(10,2) NOT NULL DEFAULT 50.00,
    booking_fee       DECIMAL(10,2) DEFAULT 10.00,
    cancellation_fee  DECIMAL(10,2) DEFAULT 50.00,
    
    -- Wait Time
    wait_time_free_minutes INT DEFAULT 5,
    wait_time_rate    DECIMAL(10,2) DEFAULT 2.00,  -- Per minute after free wait
    
    -- Special Fees
    airport_pickup_fee DECIMAL(10,2) DEFAULT 100.00,
    airport_drop_fee   DECIMAL(10,2) DEFAULT 0.00,
    night_charge_multiplier DECIMAL(3,2) DEFAULT 1.25,  -- 11PM - 5AM
    
    is_active         BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(city_id, vehicle_type)
);

-- ============================================================================
-- SURGE CONFIGS TABLE
-- ============================================================================
CREATE TABLE surge_configs (
    config_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_id             UUID NOT NULL REFERENCES cities(city_id),
    demand_threshold    DECIMAL(5,2) DEFAULT 1.5,       -- Demand/Supply ratio to trigger surge
    max_surge           DECIMAL(3,2) DEFAULT 3.0,       -- Maximum surge multiplier
    calculation_interval_seconds INT DEFAULT 60,        -- How often to recalculate
    
    -- Surge Levels: [{"min_ratio": 1.5, "max_ratio": 2.0, "multiplier": 1.2}, ...]
    surge_levels        JSONB NOT NULL DEFAULT '[
        {"min_ratio": 1.5, "max_ratio": 2.0, "multiplier": 1.2},
        {"min_ratio": 2.0, "max_ratio": 3.0, "multiplier": 1.5},
        {"min_ratio": 3.0, "max_ratio": 4.0, "multiplier": 2.0},
        {"min_ratio": 4.0, "max_ratio": null, "multiplier": 2.5}
    ]',
    
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- RIDERS TABLE
-- ============================================================================
CREATE TABLE riders (
    rider_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone             VARCHAR(20) UNIQUE NOT NULL,
    email             VARCHAR(255) UNIQUE,
    name              VARCHAR(255),
    profile_photo     VARCHAR(500),
    
    -- Ratings
    avg_rating        DECIMAL(3,2) DEFAULT 5.00 CHECK (avg_rating >= 1.00 AND avg_rating <= 5.00),
    total_trips       INT DEFAULT 0,
    total_ratings     INT DEFAULT 0,
    
    -- Wallet
    wallet_balance    DECIMAL(10,2) DEFAULT 0.00,
    
    -- Referral
    referral_code     VARCHAR(20) UNIQUE,
    referred_by       UUID REFERENCES riders(rider_id),
    
    -- Status
    is_active         BOOLEAN DEFAULT TRUE,
    is_verified       BOOLEAN DEFAULT FALSE,
    is_blocked        BOOLEAN DEFAULT FALSE,
    blocked_reason    VARCHAR(255),
    
    -- Preferences
    language          VARCHAR(10) DEFAULT 'en',
    default_payment_method VARCHAR(50),
    
    -- Timestamps
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_ride_at      TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_riders_phone ON riders(phone);
CREATE INDEX idx_riders_email ON riders(email);
CREATE INDEX idx_riders_active ON riders(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_riders_referral ON riders(referral_code);

-- ============================================================================
-- RIDER WALLET TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE rider_wallet_transactions (
    txn_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    
    -- Transaction Details
    amount            DECIMAL(10,2) NOT NULL,
    type              VARCHAR(20) NOT NULL CHECK (type IN ('CREDIT', 'DEBIT')),
    category          VARCHAR(50) NOT NULL,  -- TOP_UP, RIDE_PAYMENT, REFUND, CASHBACK, REFERRAL_BONUS, PROMO_CREDIT
    
    -- Balance Tracking
    balance_before    DECIMAL(10,2) NOT NULL,
    balance_after     DECIMAL(10,2) NOT NULL,
    
    -- References
    trip_id           UUID,
    payment_id        UUID,
    reference_id      VARCHAR(255),  -- External reference (payment gateway, etc.)
    
    -- Metadata
    description       VARCHAR(500),
    metadata          JSONB,
    
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_rider_wallet_txn_rider ON rider_wallet_transactions(rider_id, created_at DESC);
CREATE INDEX idx_rider_wallet_txn_trip ON rider_wallet_transactions(trip_id) WHERE trip_id IS NOT NULL;

-- ============================================================================
-- RIDER PAYMENT METHODS TABLE
-- ============================================================================
CREATE TABLE rider_payment_methods (
    method_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    
    -- Method Details
    type              payment_method_type NOT NULL,
    is_default        BOOLEAN DEFAULT FALSE,
    
    -- Card Details (tokenized/encrypted)
    card_last_four    VARCHAR(4),
    card_brand        VARCHAR(20),  -- VISA, MASTERCARD, RUPAY
    card_expiry_month INT,
    card_expiry_year  INT,
    
    -- UPI Details
    upi_id            VARCHAR(100),
    
    -- External References
    stripe_payment_method_id VARCHAR(255),
    stripe_customer_id       VARCHAR(255),
    razorpay_token           VARCHAR(255),
    
    -- Status
    is_active         BOOLEAN DEFAULT TRUE,
    verified_at       TIMESTAMP WITH TIME ZONE,
    
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_rider_payment_methods_rider ON rider_payment_methods(rider_id);

-- ============================================================================
-- SAVED PLACES TABLE
-- ============================================================================
CREATE TABLE saved_places (
    place_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id          UUID NOT NULL REFERENCES riders(rider_id),
    
    name              VARCHAR(100) NOT NULL,  -- "Home", "Work", etc.
    place_type        VARCHAR(20) DEFAULT 'OTHER' CHECK (place_type IN ('HOME', 'WORK', 'OTHER')),
    address           VARCHAR(500) NOT NULL,
    location          GEOGRAPHY(Point, 4326) NOT NULL,
    
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_saved_places_rider ON saved_places(rider_id);

-- ============================================================================
-- DRIVERS TABLE
-- ============================================================================
CREATE TABLE drivers (
    driver_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone             VARCHAR(20) UNIQUE NOT NULL,
    email             VARCHAR(255),
    name              VARCHAR(255) NOT NULL,
    profile_photo     VARCHAR(500),
    date_of_birth     DATE,
    gender            VARCHAR(10),
    
    -- City Assignment
    city_id           UUID REFERENCES cities(city_id),
    
    -- Vehicle Details
    vehicle_type      vehicle_type NOT NULL,
    vehicle_make      VARCHAR(50),            -- Toyota, Honda, etc.
    vehicle_model     VARCHAR(100),           -- Camry, City, etc.
    vehicle_year      INT,
    vehicle_color     VARCHAR(50),
    license_plate     VARCHAR(20) NOT NULL,
    vehicle_photos    VARCHAR[] DEFAULT '{}',
    
    -- Operational Status
    status            driver_status DEFAULT 'OFFLINE',
    is_online         BOOLEAN DEFAULT FALSE,
    current_location  GEOGRAPHY(Point, 4326),
    current_trip_id   UUID,
    last_location_update TIMESTAMP WITH TIME ZONE,
    
    -- Approval Status
    application_status VARCHAR(30) DEFAULT 'PENDING' CHECK (application_status IN (
        'PENDING', 'DOCUMENTS_UNDER_REVIEW', 'DOCUMENTS_REJECTED', 
        'BACKGROUND_CHECK', 'TRAINING_PENDING', 'APPROVED', 'SUSPENDED', 'TERMINATED'
    )),
    is_verified       BOOLEAN DEFAULT FALSE,
    is_active         BOOLEAN DEFAULT TRUE,
    approved_at       TIMESTAMP WITH TIME ZONE,
    suspended_reason  VARCHAR(255),
    
    -- Ratings & Performance
    avg_rating        DECIMAL(3,2) DEFAULT 5.00 CHECK (avg_rating >= 1.00 AND avg_rating <= 5.00),
    total_trips       INT DEFAULT 0,
    total_ratings     INT DEFAULT 0,
    acceptance_rate   DECIMAL(5,2) DEFAULT 100.00,
    cancellation_rate DECIMAL(5,2) DEFAULT 0.00,
    
    -- Documents (Reference IDs - actual docs in separate table)
    license_number    VARCHAR(50),
    license_expiry    DATE,
    
    -- Preferences
    language          VARCHAR(10) DEFAULT 'en',
    auto_accept_rides BOOLEAN DEFAULT FALSE,
    
    -- Activity
    last_online_at    TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_drivers_phone ON drivers(phone);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_location ON drivers USING GIST (current_location);
CREATE INDEX idx_drivers_online ON drivers(is_online, status) WHERE is_online = TRUE AND status = 'AVAILABLE';
CREATE INDEX idx_drivers_city ON drivers(city_id);
CREATE INDEX idx_drivers_application_status ON drivers(application_status);

-- ============================================================================
-- DRIVER DOCUMENTS TABLE
-- ============================================================================
CREATE TABLE driver_documents (
    document_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id         UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Document Details
    document_type     VARCHAR(50) NOT NULL,  -- DRIVING_LICENSE, RC, INSURANCE, PAN, AADHAAR, PHOTO, VEHICLE_FRONT, etc.
    document_number   VARCHAR(100),
    document_url      VARCHAR(500) NOT NULL,  -- S3 URL
    expiry_date       DATE,
    
    -- Verification
    status            driver_document_status DEFAULT 'PENDING',
    verified_by       UUID,  -- Admin who verified
    verified_at       TIMESTAMP WITH TIME ZONE,
    rejection_reason  VARCHAR(255),
    
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_driver_documents_driver ON driver_documents(driver_id);
CREATE INDEX idx_driver_documents_status ON driver_documents(status);

-- ============================================================================
-- DRIVER WALLET / BALANCE TABLE
-- ============================================================================
CREATE TABLE driver_wallet (
    driver_id             UUID PRIMARY KEY REFERENCES drivers(driver_id),
    
    -- Balance Components
    available_balance     DECIMAL(10,2) DEFAULT 0.00,  -- Ready for payout
    pending_balance       DECIMAL(10,2) DEFAULT 0.00,  -- Being processed
    
    -- Cash Commission Tracking (VERY IMPORTANT FOR UBER MODEL)
    cash_collected        DECIMAL(10,2) DEFAULT 0.00,  -- Total cash from riders
    cash_owed_to_platform DECIMAL(10,2) DEFAULT 0.00,  -- Commission owed from cash trips
    
    -- Lifetime Stats
    total_earnings        DECIMAL(12,2) DEFAULT 0.00,
    total_payouts         DECIMAL(12,2) DEFAULT 0.00,
    total_commission_paid DECIMAL(12,2) DEFAULT 0.00,
    total_tips            DECIMAL(12,2) DEFAULT 0.00,
    total_bonuses         DECIMAL(12,2) DEFAULT 0.00,
    
    -- Bank Account Details
    bank_account_name     VARCHAR(255),
    bank_account_number   VARCHAR(50),
    bank_ifsc_code        VARCHAR(20),
    bank_name             VARCHAR(100),
    bank_verified         BOOLEAN DEFAULT FALSE,
    
    -- UPI for instant payout
    upi_id                VARCHAR(100),
    
    -- Settings
    auto_payout_enabled   BOOLEAN DEFAULT TRUE,
    min_payout_amount     DECIMAL(10,2) DEFAULT 100.00,
    
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- DRIVER EARNINGS TABLE (Per-Trip Earnings)
-- ============================================================================
CREATE TABLE driver_earnings (
    earning_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id             UUID NOT NULL REFERENCES drivers(driver_id),
    trip_id               UUID NOT NULL,
    
    -- Trip Fare Breakdown
    trip_fare             DECIMAL(10,2) NOT NULL,       -- Total fare charged to rider
    base_fare             DECIMAL(10,2) DEFAULT 0,
    distance_fare         DECIMAL(10,2) DEFAULT 0,
    time_fare             DECIMAL(10,2) DEFAULT 0,
    wait_fare             DECIMAL(10,2) DEFAULT 0,
    surge_fare            DECIMAL(10,2) DEFAULT 0,      -- Extra from surge
    toll_amount           DECIMAL(10,2) DEFAULT 0,
    
    -- Platform Commission
    commission_rate       DECIMAL(5,2) NOT NULL,        -- e.g., 20.00 for 20%
    commission_amount     DECIMAL(10,2) NOT NULL,       -- Platform's cut
    
    -- Driver Earnings
    driver_earnings       DECIMAL(10,2) NOT NULL,       -- trip_fare - commission
    tip_amount            DECIMAL(10,2) DEFAULT 0,      -- 100% to driver
    bonus_amount          DECIMAL(10,2) DEFAULT 0,      -- Incentives
    total_earnings        DECIMAL(10,2) NOT NULL,       -- driver_earnings + tip + bonus
    
    -- Payment Type
    payment_type          payment_method_type NOT NULL,
    
    -- Settlement Status (Important for CASH payments)
    is_cash_trip          BOOLEAN DEFAULT FALSE,
    cash_collected        DECIMAL(10,2) DEFAULT 0,      -- If cash, full fare
    cash_commission_owed  DECIMAL(10,2) DEFAULT 0,      -- If cash, commission owed
    is_settled            BOOLEAN DEFAULT FALSE,        -- Cash commission collected?
    settled_at            TIMESTAMP WITH TIME ZONE,
    settled_in_payout_id  UUID,
    
    -- Digital Payment Status
    added_to_wallet       BOOLEAN DEFAULT FALSE,
    added_to_wallet_at    TIMESTAMP WITH TIME ZONE,
    
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_driver_earnings_driver ON driver_earnings(driver_id, created_at DESC);
CREATE INDEX idx_driver_earnings_trip ON driver_earnings(trip_id);
CREATE INDEX idx_driver_earnings_unsettled ON driver_earnings(driver_id, is_settled) WHERE is_cash_trip = TRUE AND is_settled = FALSE;
CREATE INDEX idx_driver_earnings_not_in_wallet ON driver_earnings(driver_id, added_to_wallet) WHERE is_cash_trip = FALSE AND added_to_wallet = FALSE;

-- ============================================================================
-- DRIVER WALLET TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE driver_wallet_transactions (
    txn_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Transaction Details
    amount              DECIMAL(10,2) NOT NULL,
    type                VARCHAR(20) NOT NULL CHECK (type IN ('CREDIT', 'DEBIT')),
    category            VARCHAR(50) NOT NULL,
    -- Categories: TRIP_EARNING, TIP, BONUS, INCENTIVE, PAYOUT, CASH_COMMISSION_DEDUCTION, 
    --             ADJUSTMENT, REFERRAL_BONUS, INSTANT_PAYOUT_FEE
    
    -- Balance Tracking
    balance_before      DECIMAL(10,2) NOT NULL,
    balance_after       DECIMAL(10,2) NOT NULL,
    
    -- References
    trip_id             UUID,
    earning_id          UUID REFERENCES driver_earnings(earning_id),
    payout_id           UUID,
    
    -- Metadata
    description         VARCHAR(500),
    metadata            JSONB,
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_driver_wallet_txn_driver ON driver_wallet_transactions(driver_id, created_at DESC);

-- ============================================================================
-- DRIVER PAYOUTS TABLE
-- ============================================================================
CREATE TABLE driver_payouts (
    payout_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Payout Type
    payout_type         VARCHAR(20) NOT NULL CHECK (payout_type IN ('WEEKLY', 'INSTANT', 'MANUAL')),
    
    -- Period (for weekly payouts)
    period_start        DATE,
    period_end          DATE,
    
    -- Earnings Breakdown
    total_trips         INT DEFAULT 0,
    trip_earnings       DECIMAL(10,2) DEFAULT 0,
    tip_earnings        DECIMAL(10,2) DEFAULT 0,
    bonus_earnings      DECIMAL(10,2) DEFAULT 0,
    gross_amount        DECIMAL(10,2) NOT NULL,         -- Total before deductions
    
    -- Deductions
    cash_commission_deducted DECIMAL(10,2) DEFAULT 0,   -- Commission from cash trips
    instant_payout_fee  DECIMAL(10,2) DEFAULT 0,        -- Fee for instant payout
    other_deductions    DECIMAL(10,2) DEFAULT 0,
    deduction_notes     VARCHAR(500),
    
    -- Net Payout
    net_amount          DECIMAL(10,2) NOT NULL,         -- Final amount to bank
    currency            VARCHAR(10) DEFAULT 'INR',
    
    -- Status
    status              payout_status DEFAULT 'PENDING',
    failure_reason      VARCHAR(255),
    retry_count         INT DEFAULT 0,
    
    -- Bank Transfer Details
    bank_reference      VARCHAR(255),
    bank_account_last4  VARCHAR(4),
    transfer_mode       VARCHAR(20),  -- NEFT, IMPS, UPI
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processing_at       TIMESTAMP WITH TIME ZONE,
    completed_at        TIMESTAMP WITH TIME ZONE,
    
    -- Admin
    created_by          UUID,
    notes               VARCHAR(500)
);

CREATE INDEX idx_driver_payouts_driver ON driver_payouts(driver_id, created_at DESC);
CREATE INDEX idx_driver_payouts_status ON driver_payouts(status);
CREATE INDEX idx_driver_payouts_period ON driver_payouts(period_start, period_end);

-- ============================================================================
-- TRIPS TABLE
-- ============================================================================
CREATE TABLE trips (
    trip_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Participants
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    driver_id           UUID REFERENCES drivers(driver_id),
    
    -- City
    city_id             UUID REFERENCES cities(city_id),
    
    -- Locations
    pickup_location     GEOGRAPHY(Point, 4326) NOT NULL,
    pickup_address      VARCHAR(500),
    drop_location       GEOGRAPHY(Point, 4326) NOT NULL,
    drop_address        VARCHAR(500),
    actual_route        GEOGRAPHY(LineString, 4326),
    
    -- Trip Details
    status              trip_status DEFAULT 'PENDING',
    vehicle_type        vehicle_type NOT NULL,
    is_scheduled        BOOLEAN DEFAULT FALSE,
    scheduled_at        TIMESTAMP WITH TIME ZONE,
    
    -- Fare Estimation
    estimated_fare      DECIMAL(10,2),
    estimated_distance_km DECIMAL(10,2),
    estimated_duration_min INT,
    
    -- Actual Fare Breakdown (Final)
    actual_fare         DECIMAL(10,2),
    base_fare           DECIMAL(10,2),
    distance_fare       DECIMAL(10,2),
    time_fare           DECIMAL(10,2),
    wait_fare           DECIMAL(10,2) DEFAULT 0,
    surge_multiplier    DECIMAL(3,2) DEFAULT 1.00,
    surge_fare          DECIMAL(10,2) DEFAULT 0,
    toll_amount         DECIMAL(10,2) DEFAULT 0,
    booking_fee         DECIMAL(10,2) DEFAULT 0,
    taxes               DECIMAL(10,2) DEFAULT 0,
    
    -- Discounts
    discount_amount     DECIMAL(10,2) DEFAULT 0,
    promo_code          VARCHAR(50),
    
    -- Final Amount
    final_amount        DECIMAL(10,2),  -- What rider pays
    
    -- Actual Metrics
    actual_distance_km  DECIMAL(10,2),
    actual_duration_min INT,
    wait_time_minutes   INT DEFAULT 0,
    
    -- Payment
    payment_method      payment_method_type,
    payment_status      payment_status DEFAULT 'PENDING',
    
    -- Timestamps
    requested_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    matched_at          TIMESTAMP WITH TIME ZONE,
    driver_arrived_at   TIMESTAMP WITH TIME ZONE,
    started_at          TIMESTAMP WITH TIME ZONE,
    completed_at        TIMESTAMP WITH TIME ZONE,
    cancelled_at        TIMESTAMP WITH TIME ZONE,
    
    -- Cancellation
    cancellation_reason VARCHAR(255),
    cancelled_by        VARCHAR(20), -- 'rider', 'driver', 'system'
    cancellation_fee    DECIMAL(10,2) DEFAULT 0,
    
    -- OTP Verification (for rider safety)
    ride_otp            VARCHAR(6),
    otp_verified        BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add FK to drivers table
ALTER TABLE drivers ADD CONSTRAINT fk_driver_current_trip 
    FOREIGN KEY (current_trip_id) REFERENCES trips(trip_id);

CREATE INDEX idx_trips_rider ON trips(rider_id, requested_at DESC);
CREATE INDEX idx_trips_driver ON trips(driver_id, requested_at DESC);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_trips_pending ON trips USING GIST (pickup_location) WHERE status = 'PENDING';
CREATE INDEX idx_trips_city ON trips(city_id, requested_at DESC);

-- ============================================================================
-- PAYMENTS TABLE
-- ============================================================================
CREATE TABLE payments (
    payment_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id             UUID NOT NULL REFERENCES trips(trip_id),
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    driver_id           UUID REFERENCES drivers(driver_id),
    
    -- Amount Details
    amount              DECIMAL(10,2) NOT NULL,
    currency            VARCHAR(10) DEFAULT 'INR',
    
    -- Payment Method
    payment_method      payment_method_type NOT NULL,
    payment_method_id   UUID REFERENCES rider_payment_methods(method_id),
    
    -- Breakdown
    trip_fare           DECIMAL(10,2),
    surge_amount        DECIMAL(10,2) DEFAULT 0,
    toll_amount         DECIMAL(10,2) DEFAULT 0,
    booking_fee         DECIMAL(10,2) DEFAULT 0,
    taxes               DECIMAL(10,2) DEFAULT 0,
    discount            DECIMAL(10,2) DEFAULT 0,
    wallet_deducted     DECIMAL(10,2) DEFAULT 0,  -- Portion paid from wallet
    card_charged        DECIMAL(10,2) DEFAULT 0,  -- Portion charged to card
    
    -- Tip (added post-trip)
    tip_amount          DECIMAL(10,2) DEFAULT 0,
    tip_paid_at         TIMESTAMP WITH TIME ZONE,
    
    -- Status
    status              payment_status DEFAULT 'PENDING',
    failure_reason      VARCHAR(255),
    
    -- Gateway Details
    gateway             VARCHAR(50),          -- stripe, razorpay
    gateway_payment_id  VARCHAR(255),
    gateway_order_id    VARCHAR(255),
    gateway_response    JSONB,
    
    -- Authorization (pre-auth before trip)
    authorization_id    VARCHAR(255),
    authorized_amount   DECIMAL(10,2),
    authorized_at       TIMESTAMP WITH TIME ZONE,
    
    -- Capture (actual charge after trip)
    captured_at         TIMESTAMP WITH TIME ZONE,
    
    -- Refund
    refund_amount       DECIMAL(10,2),
    refund_reason       VARCHAR(255),
    refund_id           VARCHAR(255),
    refunded_at         TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_payments_trip ON payments(trip_id);
CREATE INDEX idx_payments_rider ON payments(rider_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_gateway ON payments(gateway, gateway_payment_id);

-- ============================================================================
-- RATINGS TABLE
-- ============================================================================
CREATE TABLE ratings (
    rating_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id             UUID UNIQUE NOT NULL REFERENCES trips(trip_id),
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Ratings (1-5 stars)
    driver_rating       INT CHECK (driver_rating BETWEEN 1 AND 5),
    rider_rating        INT CHECK (rider_rating BETWEEN 1 AND 5),
    
    -- Feedback
    rider_feedback      TEXT,
    driver_feedback     TEXT,
    
    -- Feedback Tags (predefined)
    rider_feedback_tags VARCHAR[] DEFAULT '{}',  -- ['Clean Car', 'Good Navigation', 'Professional']
    driver_feedback_tags VARCHAR[] DEFAULT '{}', -- ['Polite', 'Ready on Time']
    
    -- Timestamps
    driver_rated_at     TIMESTAMP WITH TIME ZONE,
    rider_rated_at      TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ratings_driver ON ratings(driver_id);
CREATE INDEX idx_ratings_rider ON ratings(rider_id);

-- ============================================================================
-- RIDE REQUESTS TABLE (Active matching)
-- ============================================================================
CREATE TABLE ride_requests (
    request_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    trip_id             UUID REFERENCES trips(trip_id),
    
    -- Request Details
    pickup_location     GEOGRAPHY(Point, 4326) NOT NULL,
    pickup_address      VARCHAR(500),
    drop_location       GEOGRAPHY(Point, 4326) NOT NULL,
    drop_address        VARCHAR(500),
    vehicle_type        vehicle_type NOT NULL,
    
    -- Fare
    estimated_fare      DECIMAL(10,2),
    surge_multiplier    DECIMAL(3,2) DEFAULT 1.00,
    
    -- Matching Status
    status              VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'MATCHING', 'MATCHED', 'EXPIRED', 'CANCELLED')),
    
    -- Driver Matching Attempts
    drivers_notified    UUID[] DEFAULT '{}',
    drivers_declined    UUID[] DEFAULT '{}',
    current_driver_id   UUID REFERENCES drivers(driver_id),
    match_attempts      INT DEFAULT 0,
    max_radius_km       DECIMAL(5,2) DEFAULT 5.0,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at          TIMESTAMP WITH TIME ZONE,
    matched_at          TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_ride_requests_status ON ride_requests(status);
CREATE INDEX idx_ride_requests_pending ON ride_requests USING GIST (pickup_location) WHERE status = 'PENDING';

-- ============================================================================
-- PROMO CODES TABLE
-- ============================================================================
CREATE TABLE promo_codes (
    promo_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code                VARCHAR(50) UNIQUE NOT NULL,
    description         VARCHAR(255),
    
    -- Discount Details
    discount_type       VARCHAR(20) NOT NULL CHECK (discount_type IN ('PERCENTAGE', 'FIXED')),
    discount_value      DECIMAL(10,2) NOT NULL,
    max_discount        DECIMAL(10,2),          -- Cap for percentage
    min_trip_amount     DECIMAL(10,2) DEFAULT 0,
    
    -- Usage Limits
    max_uses            INT,
    max_uses_per_user   INT DEFAULT 1,
    current_uses        INT DEFAULT 0,
    
    -- Validity
    valid_from          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    valid_until         TIMESTAMP WITH TIME ZONE,
    
    -- Restrictions
    vehicle_types       vehicle_type[] DEFAULT '{}',  -- Empty = all
    city_ids            UUID[] DEFAULT '{}',
    first_trip_only     BOOLEAN DEFAULT FALSE,
    new_users_only      BOOLEAN DEFAULT FALSE,
    
    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    
    -- Admin
    created_by          UUID,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_promo_codes_code ON promo_codes(code);
CREATE INDEX idx_promo_codes_active ON promo_codes(is_active, valid_until);

-- ============================================================================
-- PROMO USAGE TABLE
-- ============================================================================
CREATE TABLE promo_usage (
    id                  BIGSERIAL PRIMARY KEY,
    promo_id            UUID NOT NULL REFERENCES promo_codes(promo_id),
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    trip_id             UUID REFERENCES trips(trip_id),
    
    discount_applied    DECIMAL(10,2),
    
    used_at             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_promo_usage_rider ON promo_usage(rider_id);
CREATE INDEX idx_promo_usage_promo ON promo_usage(promo_id);

-- ============================================================================
-- DRIVER INCENTIVES TABLE
-- ============================================================================
CREATE TABLE driver_incentives (
    incentive_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Targeting
    city_id             UUID REFERENCES cities(city_id),
    vehicle_types       vehicle_type[] DEFAULT '{}',
    
    -- Incentive Details
    name                VARCHAR(100) NOT NULL,
    description         VARCHAR(500),
    type                VARCHAR(20) NOT NULL CHECK (type IN ('TRIP_COUNT', 'EARNINGS_TARGET', 'ACCEPTANCE_RATE', 'PEAK_HOURS')),
    
    -- Target & Reward
    target_value        DECIMAL(10,2) NOT NULL,   -- e.g., 20 trips or ₹5000 earnings
    bonus_amount        DECIMAL(10,2) NOT NULL,
    
    -- Validity
    valid_from          TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until         TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    
    created_by          UUID,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- DRIVER INCENTIVE PROGRESS TABLE
-- ============================================================================
CREATE TABLE driver_incentive_progress (
    id                  BIGSERIAL PRIMARY KEY,
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    incentive_id        UUID NOT NULL REFERENCES driver_incentives(incentive_id),
    
    current_value       DECIMAL(10,2) DEFAULT 0,
    is_completed        BOOLEAN DEFAULT FALSE,
    completed_at        TIMESTAMP WITH TIME ZONE,
    bonus_credited      BOOLEAN DEFAULT FALSE,
    bonus_credited_at   TIMESTAMP WITH TIME ZONE,
    
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(driver_id, incentive_id)
);

-- ============================================================================
-- SUPPORT TICKETS TABLE
-- ============================================================================
CREATE TABLE support_tickets (
    ticket_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_number       VARCHAR(20) UNIQUE NOT NULL,
    
    -- User Details
    user_type           VARCHAR(20) NOT NULL CHECK (user_type IN ('rider', 'driver')),
    user_id             UUID NOT NULL,
    
    -- Related Trip
    trip_id             UUID REFERENCES trips(trip_id),
    
    -- Ticket Details
    category            VARCHAR(50) NOT NULL,  -- PAYMENT, TRIP_ISSUE, SAFETY, LOST_ITEM, REFUND, DRIVER_BEHAVIOR, etc.
    sub_category        VARCHAR(50),
    priority            ticket_priority DEFAULT 'P3',
    
    subject             VARCHAR(255) NOT NULL,
    description         TEXT,
    
    -- Status
    status              ticket_status DEFAULT 'OPEN',
    
    -- Assignment
    assigned_to         UUID,
    assigned_at         TIMESTAMP WITH TIME ZONE,
    
    -- Resolution
    resolution          TEXT,
    resolution_type     VARCHAR(50),  -- REFUND_ISSUED, CREDITED_WALLET, EXPLAINED, ESCALATED, etc.
    refund_amount       DECIMAL(10,2),
    
    -- SLA
    sla_response_due    TIMESTAMP WITH TIME ZONE,
    sla_resolution_due  TIMESTAMP WITH TIME ZONE,
    first_response_at   TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at         TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_support_tickets_user ON support_tickets(user_type, user_id);
CREATE INDEX idx_support_tickets_status ON support_tickets(status, priority);
CREATE INDEX idx_support_tickets_trip ON support_tickets(trip_id);
CREATE INDEX idx_support_tickets_assigned ON support_tickets(assigned_to) WHERE status NOT IN ('RESOLVED', 'CLOSED');

-- ============================================================================
-- SUPPORT TICKET MESSAGES TABLE
-- ============================================================================
CREATE TABLE support_ticket_messages (
    message_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id           UUID NOT NULL REFERENCES support_tickets(ticket_id),
    
    sender_type         VARCHAR(20) NOT NULL CHECK (sender_type IN ('user', 'agent', 'system')),
    sender_id           UUID,
    
    message             TEXT NOT NULL,
    attachments         VARCHAR[] DEFAULT '{}',
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ticket_messages_ticket ON support_ticket_messages(ticket_id, created_at);

-- ============================================================================
-- ADMIN USERS TABLE
-- ============================================================================
CREATE TABLE admin_users (
    admin_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email               VARCHAR(255) UNIQUE NOT NULL,
    password_hash       VARCHAR(255) NOT NULL,
    name                VARCHAR(255) NOT NULL,
    phone               VARCHAR(20),
    
    -- Role
    role                VARCHAR(50) NOT NULL CHECK (role IN (
        'SUPER_ADMIN', 'CITY_ADMIN', 'FINANCE_ADMIN', 'SUPPORT_AGENT', 'OPERATIONS_MANAGER'
    )),
    
    -- City Access (for City Admin)
    city_ids            UUID[] DEFAULT '{}',
    
    -- Permissions (detailed)
    permissions         JSONB DEFAULT '{}',
    
    -- Security
    is_active           BOOLEAN DEFAULT TRUE,
    two_fa_enabled      BOOLEAN DEFAULT FALSE,
    two_fa_secret       VARCHAR(100),
    
    -- Activity
    last_login_at       TIMESTAMP WITH TIME ZONE,
    last_login_ip       INET,
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by          UUID REFERENCES admin_users(admin_id)
);

CREATE INDEX idx_admin_users_email ON admin_users(email);
CREATE INDEX idx_admin_users_role ON admin_users(role);

-- ============================================================================
-- AUDIT LOGS TABLE
-- ============================================================================
CREATE TABLE audit_logs (
    log_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Who
    admin_id            UUID REFERENCES admin_users(admin_id),
    
    -- What
    action              VARCHAR(100) NOT NULL,
    entity_type         VARCHAR(50) NOT NULL,
    entity_id           UUID,
    
    -- Changes
    old_values          JSONB,
    new_values          JSONB,
    
    -- Context
    ip_address          INET,
    user_agent          VARCHAR(500),
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_admin ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- ============================================================================
-- DEVICE TOKENS TABLE
-- ============================================================================
CREATE TABLE device_tokens (
    id                  BIGSERIAL PRIMARY KEY,
    user_type           VARCHAR(20) NOT NULL CHECK (user_type IN ('rider', 'driver', 'admin')),
    user_id             UUID NOT NULL,
    
    device_token        VARCHAR(500) NOT NULL,
    platform            VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    device_id           VARCHAR(255),
    
    is_active           BOOLEAN DEFAULT TRUE,
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, device_token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id, user_type, is_active);

-- ============================================================================
-- NOTIFICATIONS TABLE
-- ============================================================================
CREATE TABLE notifications (
    notification_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_type           VARCHAR(20) NOT NULL,
    user_id             UUID NOT NULL,
    
    title               VARCHAR(255) NOT NULL,
    body                TEXT NOT NULL,
    data                JSONB,
    
    notification_type   VARCHAR(50) NOT NULL,
    trip_id             UUID REFERENCES trips(trip_id),
    
    status              VARCHAR(20) DEFAULT 'PENDING',
    sent_at             TIMESTAMP WITH TIME ZONE,
    read_at             TIMESTAMP WITH TIME ZONE,
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user ON notifications(user_id, user_type, created_at DESC);

-- ============================================================================
-- LOCATION HISTORY TABLE
-- ============================================================================
CREATE TABLE location_history (
    id                  BIGSERIAL PRIMARY KEY,
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    trip_id             UUID REFERENCES trips(trip_id),
    
    location            GEOGRAPHY(Point, 4326) NOT NULL,
    speed               DECIMAL(5,2),
    heading             DECIMAL(5,2),
    accuracy            DECIMAL(5,2),
    
    recorded_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_location_history_driver ON location_history(driver_id, recorded_at DESC);
CREATE INDEX idx_location_history_trip ON location_history(trip_id) WHERE trip_id IS NOT NULL;

-- ============================================================================
-- SURGE PRICING HISTORY TABLE
-- ============================================================================
CREATE TABLE surge_pricing (
    id                  BIGSERIAL PRIMARY KEY,
    city_id             UUID REFERENCES cities(city_id),
    geohash             VARCHAR(12) NOT NULL,
    
    surge_multiplier    DECIMAL(3,2) NOT NULL,
    available_drivers   INT,
    pending_requests    INT,
    demand_ratio        DECIMAL(5,2),
    
    calculated_at       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    valid_until         TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_surge_pricing_geohash ON surge_pricing(geohash, calculated_at DESC);
CREATE INDEX idx_surge_pricing_city ON surge_pricing(city_id, calculated_at DESC);

-- ============================================================================
-- REFERRALS TABLE
-- ============================================================================
CREATE TABLE referrals (
    referral_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Referrer
    referrer_type       VARCHAR(20) NOT NULL CHECK (referrer_type IN ('rider', 'driver')),
    referrer_id         UUID NOT NULL,
    referral_code       VARCHAR(20) NOT NULL,
    
    -- Referee
    referee_type        VARCHAR(20) NOT NULL CHECK (referee_type IN ('rider', 'driver')),
    referee_id          UUID NOT NULL,
    
    -- Status
    status              VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED', 'EXPIRED', 'INVALID')),
    
    -- Rewards
    referrer_reward     DECIMAL(10,2),
    referee_reward      DECIMAL(10,2),
    referrer_rewarded   BOOLEAN DEFAULT FALSE,
    referee_rewarded    BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_referrals_referrer ON referrals(referrer_type, referrer_id);
CREATE INDEX idx_referrals_referee ON referrals(referee_type, referee_id);
CREATE INDEX idx_referrals_code ON referrals(referral_code);

-- ============================================================================
-- ============================================================================
--                    PRODUCTION FEATURES - UBER GRADE
-- ============================================================================
-- ============================================================================

-- ############################################################################
-- #                       1. FRAUD DETECTION SYSTEM                          #
-- ############################################################################

-- ============================================================================
-- FRAUD ALERT TYPES
-- ============================================================================
CREATE TYPE fraud_alert_type AS ENUM (
    'GPS_SPOOFING',           -- Fake location detected
    'DEVICE_TAMPERING',       -- Rooted/jailbroken device
    'MULTIPLE_ACCOUNTS',      -- Same device, multiple accounts
    'PROMO_ABUSE',           -- Excessive promo code usage
    'FAKE_TRIP',             -- Trips that don't make sense
    'PAYMENT_FRAUD',         -- Stolen cards, chargebacks
    'RATING_MANIPULATION',   -- Fake ratings
    'COLLUSION',             -- Driver-rider collusion
    'VELOCITY_ABUSE',        -- Too many actions too fast
    'IDENTITY_FRAUD'         -- Fake documents
);

CREATE TYPE fraud_severity AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE fraud_status AS ENUM ('DETECTED', 'INVESTIGATING', 'CONFIRMED', 'FALSE_POSITIVE', 'RESOLVED', 'ESCALATED');

-- ============================================================================
-- FRAUD RULES TABLE (Configurable fraud detection rules)
-- ============================================================================
CREATE TABLE fraud_rules (
    rule_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Rule Definition
    rule_name           VARCHAR(100) NOT NULL UNIQUE,
    rule_type           fraud_alert_type NOT NULL,
    description         TEXT,
    
    -- Rule Configuration (JSON for flexibility)
    conditions          JSONB NOT NULL,
    -- Example: {"max_speed_kmh": 200, "min_accuracy_meters": 500, "check_interval_seconds": 5}
    
    -- Thresholds
    threshold_count     INT DEFAULT 1,              -- Number of violations to trigger
    threshold_period    INTERVAL DEFAULT '1 hour',  -- Time window for counting
    
    -- Actions
    severity            fraud_severity DEFAULT 'MEDIUM',
    auto_action         VARCHAR(50),                -- WARN, BLOCK_TRIP, SUSPEND_USER, NONE
    notify_admin        BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by          UUID
);

-- ============================================================================
-- FRAUD ALERTS TABLE (Detected fraud incidents)
-- ============================================================================
CREATE TABLE fraud_alerts (
    alert_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Who
    user_type           VARCHAR(20) NOT NULL CHECK (user_type IN ('rider', 'driver')),
    user_id             UUID NOT NULL,
    
    -- What
    alert_type          fraud_alert_type NOT NULL,
    rule_id             UUID REFERENCES fraud_rules(rule_id),
    severity            fraud_severity NOT NULL,
    
    -- Context
    trip_id             UUID,
    evidence            JSONB NOT NULL,             -- All collected evidence
    -- Example evidence: {
    --   "location_jumps": [{"from": {...}, "to": {...}, "distance_km": 50, "time_seconds": 2}],
    --   "device_info": {"is_rooted": true, "mock_location_enabled": true},
    --   "pattern": "5 trips in last hour, all cancelled after 90% completion"
    -- }
    
    -- Auto-detection info
    detection_method    VARCHAR(50),                -- REALTIME, BATCH, MANUAL
    confidence_score    DECIMAL(5,2),               -- 0-100
    
    -- Status & Resolution
    status              fraud_status DEFAULT 'DETECTED',
    auto_action_taken   VARCHAR(50),
    
    -- Investigation
    investigated_by     UUID,
    investigation_notes TEXT,
    resolution          VARCHAR(50),                -- ACCOUNT_SUSPENDED, WARNING_ISSUED, NO_ACTION, etc.
    resolved_at         TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    detected_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_fraud_alerts_user ON fraud_alerts(user_type, user_id);
CREATE INDEX idx_fraud_alerts_status ON fraud_alerts(status) WHERE status NOT IN ('RESOLVED', 'FALSE_POSITIVE');
CREATE INDEX idx_fraud_alerts_type ON fraud_alerts(alert_type, detected_at DESC);
CREATE INDEX idx_fraud_alerts_trip ON fraud_alerts(trip_id) WHERE trip_id IS NOT NULL;

-- ============================================================================
-- DEVICE FINGERPRINTS TABLE (Track unique devices)
-- ============================================================================
CREATE TABLE device_fingerprints (
    fingerprint_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Device Identification
    device_id           VARCHAR(255) NOT NULL,      -- Unique device identifier
    fingerprint_hash    VARCHAR(64) NOT NULL,       -- SHA256 of device attributes
    
    -- Device Attributes
    platform            VARCHAR(20) NOT NULL,       -- ios, android
    os_version          VARCHAR(50),
    app_version         VARCHAR(20),
    device_model        VARCHAR(100),
    device_manufacturer VARCHAR(100),
    screen_resolution   VARCHAR(20),
    
    -- Security Flags
    is_rooted           BOOLEAN DEFAULT FALSE,
    is_emulator         BOOLEAN DEFAULT FALSE,
    mock_location       BOOLEAN DEFAULT FALSE,
    vpn_detected        BOOLEAN DEFAULT FALSE,
    
    -- Associated Users
    user_ids            UUID[] DEFAULT '{}',
    user_types          VARCHAR[] DEFAULT '{}',
    
    -- Risk Assessment
    risk_score          INT DEFAULT 0,              -- 0-100
    is_blocked          BOOLEAN DEFAULT FALSE,
    blocked_reason      VARCHAR(255),
    blocked_at          TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    first_seen_at       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_seen_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(device_id)
);

CREATE INDEX idx_device_fingerprints_hash ON device_fingerprints(fingerprint_hash);
CREATE INDEX idx_device_fingerprints_blocked ON device_fingerprints(is_blocked) WHERE is_blocked = TRUE;
CREATE INDEX idx_device_fingerprints_risk ON device_fingerprints(risk_score DESC);

-- ============================================================================
-- USER FRAUD SCORES TABLE (Running fraud risk for each user)
-- ============================================================================
CREATE TABLE user_fraud_scores (
    id                  BIGSERIAL PRIMARY KEY,
    user_type           VARCHAR(20) NOT NULL,
    user_id             UUID NOT NULL,
    
    -- Risk Scores (0-100)
    overall_score       INT DEFAULT 0,
    gps_risk_score      INT DEFAULT 0,
    payment_risk_score  INT DEFAULT 0,
    behavior_risk_score INT DEFAULT 0,
    
    -- Counts
    total_alerts        INT DEFAULT 0,
    active_alerts       INT DEFAULT 0,
    false_positives     INT DEFAULT 0,
    
    -- Actions
    warnings_issued     INT DEFAULT 0,
    suspensions         INT DEFAULT 0,
    
    -- Status
    is_flagged          BOOLEAN DEFAULT FALSE,
    is_under_review     BOOLEAN DEFAULT FALSE,
    reviewer_id         UUID,
    
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_type, user_id)
);

CREATE INDEX idx_user_fraud_scores_flagged ON user_fraud_scores(is_flagged) WHERE is_flagged = TRUE;
CREATE INDEX idx_user_fraud_scores_score ON user_fraud_scores(overall_score DESC);

-- ============================================================================
-- GPS ANOMALIES TABLE (Track location inconsistencies)
-- ============================================================================
CREATE TABLE gps_anomalies (
    anomaly_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    trip_id             UUID REFERENCES trips(trip_id),
    
    -- Anomaly Type
    anomaly_type        VARCHAR(50) NOT NULL,
    -- Types: TELEPORTATION, IMPOSSIBLE_SPEED, ACCURACY_FLIP, MOCK_DETECTED, STATIONARY_MOVEMENT
    
    -- Location Data
    location_before     GEOGRAPHY(Point, 4326),
    location_after      GEOGRAPHY(Point, 4326),
    distance_meters     DECIMAL(10,2),
    time_diff_seconds   INT,
    calculated_speed    DECIMAL(10,2),              -- km/h
    
    -- Context
    accuracy_before     DECIMAL(5,2),
    accuracy_after      DECIMAL(5,2),
    mock_location_flag  BOOLEAN,
    
    -- Severity
    severity            fraud_severity,
    is_suspicious       BOOLEAN DEFAULT TRUE,
    
    detected_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gps_anomalies_driver ON gps_anomalies(driver_id, detected_at DESC);
CREATE INDEX idx_gps_anomalies_trip ON gps_anomalies(trip_id) WHERE trip_id IS NOT NULL;

-- ############################################################################
-- #                         2. SAFETY FEATURES                               #
-- ############################################################################

-- ============================================================================
-- EMERGENCY CONTACTS TABLE
-- ============================================================================
CREATE TABLE emergency_contacts (
    contact_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Owner
    user_type           VARCHAR(20) NOT NULL CHECK (user_type IN ('rider', 'driver')),
    user_id             UUID NOT NULL,
    
    -- Contact Info
    name                VARCHAR(100) NOT NULL,
    phone               VARCHAR(20) NOT NULL,
    email               VARCHAR(255),
    relationship        VARCHAR(50),                -- FAMILY, FRIEND, SPOUSE, OTHER
    
    -- Settings
    is_primary          BOOLEAN DEFAULT FALSE,
    notify_on_trip      BOOLEAN DEFAULT FALSE,      -- Auto-share all trips
    notify_on_sos       BOOLEAN DEFAULT TRUE,
    
    -- Status
    is_verified         BOOLEAN DEFAULT FALSE,
    verified_at         TIMESTAMP WITH TIME ZONE,
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_emergency_contacts_user ON emergency_contacts(user_type, user_id);

-- ============================================================================
-- SOS ALERTS TABLE
-- ============================================================================
CREATE TYPE sos_status AS ENUM ('ACTIVE', 'RESPONDING', 'RESOLVED', 'FALSE_ALARM', 'ESCALATED_TO_POLICE');

CREATE TABLE sos_alerts (
    sos_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Who triggered
    triggered_by_type   VARCHAR(20) NOT NULL CHECK (triggered_by_type IN ('rider', 'driver')),
    triggered_by_id     UUID NOT NULL,
    
    -- Context
    trip_id             UUID REFERENCES trips(trip_id),
    location            GEOGRAPHY(Point, 4326) NOT NULL,
    address             VARCHAR(500),
    
    -- Alert Details
    alert_type          VARCHAR(50) DEFAULT 'MANUAL',
    -- Types: MANUAL, AUTO_CRASH_DETECTED, AUTO_ROUTE_DEVIATION, AUTO_LONG_STOP, SILENT_ALERT
    
    status              sos_status DEFAULT 'ACTIVE',
    
    -- Actions Taken
    emergency_contacted BOOLEAN DEFAULT FALSE,
    police_notified     BOOLEAN DEFAULT FALSE,
    police_case_number  VARCHAR(50),
    contacts_notified   UUID[] DEFAULT '{}',        -- emergency_contact IDs notified
    
    -- Response
    responded_by        UUID,                       -- Admin who responded
    response_notes      TEXT,
    resolution          VARCHAR(100),
    
    -- Audio/Evidence
    audio_recording_url VARCHAR(500),
    
    -- Timestamps
    triggered_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    responded_at        TIMESTAMP WITH TIME ZONE,
    resolved_at         TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_sos_alerts_active ON sos_alerts(status) WHERE status IN ('ACTIVE', 'RESPONDING');
CREATE INDEX idx_sos_alerts_trip ON sos_alerts(trip_id);
CREATE INDEX idx_sos_alerts_triggered ON sos_alerts(triggered_at DESC);

-- ============================================================================
-- TRIP SAFETY CHECKS TABLE (Background monitoring during trip)
-- ============================================================================
CREATE TABLE trip_safety_checks (
    check_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id             UUID NOT NULL REFERENCES trips(trip_id),
    
    -- Check Type
    check_type          VARCHAR(50) NOT NULL,
    -- Types: ROUTE_DEVIATION, UNEXPECTED_STOP, OVERSPEEDING, NO_MOVEMENT, DRIVER_OFFLINE, LONG_TRIP
    
    -- Details
    severity            VARCHAR(20) DEFAULT 'LOW',
    description         TEXT,
    location            GEOGRAPHY(Point, 4326),
    
    -- Auto-action taken
    auto_action         VARCHAR(50),                -- NOTIFY_RIDER, NOTIFY_SUPPORT, TRIGGER_SOS
    action_taken        BOOLEAN DEFAULT FALSE,
    
    -- Resolution
    is_acknowledged     BOOLEAN DEFAULT FALSE,
    acknowledged_by     VARCHAR(20),                -- rider, driver, system
    
    detected_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_trip_safety_checks_trip ON trip_safety_checks(trip_id);

-- ============================================================================
-- TRIP SHARE TABLE (Live location sharing)
-- ============================================================================
CREATE TABLE trip_shares (
    share_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id             UUID NOT NULL REFERENCES trips(trip_id),
    rider_id            UUID NOT NULL REFERENCES riders(rider_id),
    
    -- Share Details
    share_token         VARCHAR(64) UNIQUE NOT NULL,
    share_url           VARCHAR(500),
    
    -- Recipients
    shared_with_contacts UUID[] DEFAULT '{}',       -- emergency_contact IDs
    shared_with_phones  VARCHAR[] DEFAULT '{}',     -- ad-hoc phone numbers
    shared_with_emails  VARCHAR[] DEFAULT '{}',
    
    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at          TIMESTAMP WITH TIME ZONE,
    
    -- Tracking
    view_count          INT DEFAULT 0,
    last_viewed_at      TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_trip_shares_trip ON trip_shares(trip_id);
CREATE INDEX idx_trip_shares_token ON trip_shares(share_token);

-- ============================================================================
-- DRIVER BACKGROUND CHECKS TABLE
-- ============================================================================
CREATE TYPE background_check_status AS ENUM ('PENDING', 'IN_PROGRESS', 'PASSED', 'FAILED', 'EXPIRED', 'REQUIRES_REVIEW');

CREATE TABLE driver_background_checks (
    check_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Check Type
    check_type          VARCHAR(50) NOT NULL,
    -- Types: IDENTITY_VERIFICATION, CRIMINAL_RECORD, DRIVING_HISTORY, ADDRESS_VERIFICATION, REFERENCE_CHECK
    
    -- Provider
    provider            VARCHAR(100),               -- Third-party verification service
    provider_reference  VARCHAR(255),
    
    -- Results
    status              background_check_status DEFAULT 'PENDING',
    result_summary      TEXT,
    result_details      JSONB,
    risk_flags          VARCHAR[] DEFAULT '{}',
    
    -- Validity
    valid_from          DATE,
    valid_until         DATE,
    
    -- Review (if manual review needed)
    reviewed_by         UUID,
    review_notes        TEXT,
    
    -- Timestamps
    initiated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_background_checks_driver ON driver_background_checks(driver_id);
CREATE INDEX idx_background_checks_status ON driver_background_checks(status);
CREATE INDEX idx_background_checks_expiry ON driver_background_checks(valid_until);

-- ============================================================================
-- SAFETY INCIDENTS TABLE (Reported safety issues)
-- ============================================================================
CREATE TABLE safety_incidents (
    incident_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Reporter
    reported_by_type    VARCHAR(20) NOT NULL,
    reported_by_id      UUID NOT NULL,
    
    -- Reported Party
    against_type        VARCHAR(20),
    against_id          UUID,
    
    -- Context
    trip_id             UUID REFERENCES trips(trip_id),
    
    -- Incident Details
    incident_type       VARCHAR(50) NOT NULL,
    -- Types: HARASSMENT, UNSAFE_DRIVING, PHYSICAL_ALTERCATION, INTOXICATED_DRIVER, 
    --        VEHICLE_SAFETY, ROUTE_DEVIATION, INAPPROPRIATE_BEHAVIOR, THEFT, OTHER
    
    severity            VARCHAR(20) NOT NULL,       -- LOW, MEDIUM, HIGH, CRITICAL
    description         TEXT NOT NULL,
    
    -- Evidence
    evidence_urls       VARCHAR[] DEFAULT '{}',     -- Photos, screenshots
    audio_recording_url VARCHAR(500),
    
    -- Location
    incident_location   GEOGRAPHY(Point, 4326),
    incident_address    VARCHAR(500),
    incident_time       TIMESTAMP WITH TIME ZONE,
    
    -- Status
    status              VARCHAR(30) DEFAULT 'REPORTED',
    -- Statuses: REPORTED, UNDER_INVESTIGATION, ACTION_TAKEN, CLOSED, ESCALATED_TO_LAW
    
    -- Investigation
    assigned_to         UUID REFERENCES admin_users(admin_id),
    investigation_notes TEXT,
    
    -- Actions
    action_taken        VARCHAR(100),
    action_details      TEXT,
    
    -- Police
    police_reported     BOOLEAN DEFAULT FALSE,
    police_report_number VARCHAR(50),
    
    -- Timestamps
    reported_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at         TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_safety_incidents_reporter ON safety_incidents(reported_by_type, reported_by_id);
CREATE INDEX idx_safety_incidents_against ON safety_incidents(against_type, against_id);
CREATE INDEX idx_safety_incidents_status ON safety_incidents(status) WHERE status NOT IN ('CLOSED');
CREATE INDEX idx_safety_incidents_trip ON safety_incidents(trip_id);

-- ############################################################################
-- #                         3. GEO-FENCING SYSTEM                            #
-- ############################################################################

-- ============================================================================
-- GEO ZONES TABLE (Define special zones)
-- ============================================================================
CREATE TYPE geo_zone_type AS ENUM (
    'AIRPORT',
    'TRAIN_STATION',
    'BUS_TERMINAL',
    'MALL',
    'EVENT_VENUE',
    'HOSPITAL',
    'RESTRICTED',          -- No pickups/drops allowed
    'SURGE_ZONE',          -- Special surge rules
    'PICKUP_ONLY',         -- Only pickups, no drops
    'DROP_ONLY',           -- Only drops, no pickups
    'QUEUE_ZONE',          -- Driver queue area (airports)
    'GEOFENCE_ALERT'       -- Just trigger notification
);

CREATE TABLE geo_zones (
    zone_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_id             UUID NOT NULL REFERENCES cities(city_id),
    
    -- Zone Definition
    name                VARCHAR(100) NOT NULL,
    zone_type           geo_zone_type NOT NULL,
    description         TEXT,
    
    -- Geography
    boundary            GEOGRAPHY(Polygon, 4326) NOT NULL,
    center_point        GEOGRAPHY(Point, 4326),
    radius_meters       DECIMAL(10,2),              -- If circular zone
    
    -- Rules
    rules               JSONB DEFAULT '{}',
    -- Example rules:
    -- {
    --   "pickup_allowed": true,
    --   "drop_allowed": true,
    --   "surge_multiplier_override": 1.5,
    --   "fixed_pickup_fee": 50.00,
    --   "require_queue": true,
    --   "max_wait_minutes": 30,
    --   "operating_hours": {"start": "06:00", "end": "23:00"},
    --   "vehicle_types_allowed": ["sedan", "premium"],
    --   "notify_message": "You are entering airport zone"
    -- }
    
    -- Fees
    pickup_fee          DECIMAL(10,2) DEFAULT 0,
    drop_fee            DECIMAL(10,2) DEFAULT 0,
    
    -- Queue settings (for airports)
    has_queue           BOOLEAN DEFAULT FALSE,
    queue_capacity      INT,
    
    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_geo_zones_city ON geo_zones(city_id);
CREATE INDEX idx_geo_zones_type ON geo_zones(zone_type);
CREATE INDEX idx_geo_zones_boundary ON geo_zones USING GIST (boundary);

-- ============================================================================
-- AIRPORT QUEUES TABLE (Driver queue at airports)
-- ============================================================================
CREATE TABLE airport_queues (
    queue_entry_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id             UUID NOT NULL REFERENCES geo_zones(zone_id),
    driver_id           UUID NOT NULL REFERENCES drivers(driver_id),
    
    -- Queue Position
    queue_position      INT NOT NULL,
    vehicle_type        vehicle_type NOT NULL,
    
    -- Status
    status              VARCHAR(20) DEFAULT 'WAITING',
    -- Statuses: WAITING, NEXT_UP, ASSIGNED, LEFT_QUEUE, EXPIRED
    
    -- Location
    entry_location      GEOGRAPHY(Point, 4326),
    current_location    GEOGRAPHY(Point, 4326),
    
    -- Timestamps
    entered_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    assigned_at         TIMESTAMP WITH TIME ZONE,
    left_at             TIMESTAMP WITH TIME ZONE,
    
    -- Assigned Trip
    trip_id             UUID REFERENCES trips(trip_id),
    
    -- Penalties (for leaving queue)
    penalty_applied     BOOLEAN DEFAULT FALSE,
    penalty_amount      DECIMAL(10,2)
);

CREATE INDEX idx_airport_queues_zone ON airport_queues(zone_id, queue_position) WHERE status = 'WAITING';
CREATE INDEX idx_airport_queues_driver ON airport_queues(driver_id);

-- ============================================================================
-- ZONE ENTRY LOGS TABLE (Track when users enter/exit zones)
-- ============================================================================
CREATE TABLE zone_entry_logs (
    log_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id             UUID NOT NULL REFERENCES geo_zones(zone_id),
    
    -- User
    user_type           VARCHAR(20) NOT NULL,
    user_id             UUID NOT NULL,
    
    -- Event
    event_type          VARCHAR(20) NOT NULL CHECK (event_type IN ('ENTER', 'EXIT')),
    
    -- Context
    trip_id             UUID REFERENCES trips(trip_id),
    location            GEOGRAPHY(Point, 4326) NOT NULL,
    
    -- Timestamp
    logged_at           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_zone_entry_logs_zone ON zone_entry_logs(zone_id, logged_at DESC);
CREATE INDEX idx_zone_entry_logs_user ON zone_entry_logs(user_type, user_id, logged_at DESC);

-- ############################################################################
-- #                         4. CHAT SYSTEM                                   #
-- ############################################################################

-- ============================================================================
-- TRIP MESSAGES TABLE (In-trip chat between rider and driver)
-- ============================================================================
CREATE TABLE trip_messages (
    message_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id             UUID NOT NULL REFERENCES trips(trip_id),
    
    -- Sender
    sender_type         VARCHAR(20) NOT NULL CHECK (sender_type IN ('rider', 'driver', 'system')),
    sender_id           UUID,
    
    -- Message Content
    message_type        VARCHAR(20) DEFAULT 'TEXT',
    -- Types: TEXT, IMAGE, AUDIO, LOCATION, QUICK_REPLY, SYSTEM
    
    content             TEXT,
    media_url           VARCHAR(500),
    quick_reply_id      UUID,
    
    -- For location sharing
    location            GEOGRAPHY(Point, 4326),
    
    -- Status
    status              VARCHAR(20) DEFAULT 'SENT',
    -- Statuses: SENT, DELIVERED, READ, FAILED
    
    delivered_at        TIMESTAMP WITH TIME ZONE,
    read_at             TIMESTAMP WITH TIME ZONE,
    
    -- Moderation
    is_flagged          BOOLEAN DEFAULT FALSE,
    flag_reason         VARCHAR(100),
    
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_trip_messages_trip ON trip_messages(trip_id, created_at);
CREATE INDEX idx_trip_messages_flagged ON trip_messages(is_flagged) WHERE is_flagged = TRUE;

-- ============================================================================
-- CHAT QUICK REPLIES TABLE (Pre-defined responses)
-- ============================================================================
CREATE TABLE chat_quick_replies (
    reply_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Reply Details
    category            VARCHAR(50) NOT NULL,
    -- Categories: PICKUP, ETA, LOCATION, DELAY, SAFETY, PAYMENT, GENERAL
    
    message             VARCHAR(255) NOT NULL,
    
    -- Localization
    language            VARCHAR(10) DEFAULT 'en',
    
    -- Usage
    user_type           VARCHAR(20),                -- rider, driver, or null for both
    trip_status         trip_status,                -- When to show, null for all
    
    -- Ordering
    display_order       INT DEFAULT 0,
    
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_chat_quick_replies_category ON chat_quick_replies(category, user_type);

-- ============================================================================
-- CALL LOGS TABLE (Track calls between rider and driver)
-- ============================================================================
CREATE TABLE call_logs (
    call_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id             UUID NOT NULL REFERENCES trips(trip_id),
    
    -- Parties
    caller_type         VARCHAR(20) NOT NULL,
    caller_id           UUID NOT NULL,
    receiver_type       VARCHAR(20) NOT NULL,
    receiver_id         UUID NOT NULL,
    
    -- Call Details
    call_type           VARCHAR(20) DEFAULT 'VOICE',
    -- Types: VOICE, VOIP
    
    status              VARCHAR(20) NOT NULL,
    -- Statuses: INITIATED, RINGING, ANSWERED, MISSED, DECLINED, FAILED
    
    duration_seconds    INT,
    
    -- Masking (privacy)
    masked_number_used  VARCHAR(20),
    
    -- Timestamps
    initiated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    answered_at         TIMESTAMP WITH TIME ZONE,
    ended_at            TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_call_logs_trip ON call_logs(trip_id);

-- ############################################################################
-- #                    5. AUDIT & COMPLIANCE SYSTEM                          #
-- ############################################################################

-- ============================================================================
-- USER SESSIONS TABLE (Track all login sessions)
-- ============================================================================
CREATE TABLE user_sessions (
    session_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- User
    user_type           VARCHAR(20) NOT NULL,
    user_id             UUID NOT NULL,
    
    -- Session Details
    token_hash          VARCHAR(64),                -- Hash of JWT/session token
    device_fingerprint  UUID REFERENCES device_fingerprints(fingerprint_id),
    
    -- Device Info
    device_id           VARCHAR(255),
    platform            VARCHAR(20),
    app_version         VARCHAR(20),
    
    -- Network Info
    ip_address          INET,
    ip_country          VARCHAR(2),
    ip_city             VARCHAR(100),
    
    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_active_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at          TIMESTAMP WITH TIME ZONE,
    logged_out_at       TIMESTAMP WITH TIME ZONE,
    logout_reason       VARCHAR(50)                 -- USER_ACTION, TOKEN_EXPIRED, FORCE_LOGOUT, SUSPICIOUS
);

CREATE INDEX idx_user_sessions_user ON user_sessions(user_type, user_id, is_active);
CREATE INDEX idx_user_sessions_token ON user_sessions(token_hash);

-- ============================================================================
-- CONSENT LOGS TABLE (GDPR/Privacy consent tracking)
-- ============================================================================
CREATE TABLE consent_logs (
    consent_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- User
    user_type           VARCHAR(20) NOT NULL,
    user_id             UUID NOT NULL,
    
    -- Consent Details
    consent_type        VARCHAR(50) NOT NULL,
    -- Types: TERMS_OF_SERVICE, PRIVACY_POLICY, MARKETING_EMAILS, MARKETING_SMS, 
    --        LOCATION_TRACKING, DATA_SHARING, PUSH_NOTIFICATIONS, COOKIES
    
    version             VARCHAR(20),                -- Policy version consented to
    
    -- Action
    action              VARCHAR(20) NOT NULL CHECK (action IN ('GRANTED', 'REVOKED', 'UPDATED')),
    
    -- Context
    ip_address          INET,
    device_info         JSONB,
    
    -- Timestamps
    consented_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_consent_logs_user ON consent_logs(user_type, user_id, consent_type);

-- ============================================================================
-- DATA EXPORT REQUESTS TABLE (GDPR Right to Access)
-- ============================================================================
CREATE TABLE data_export_requests (
    request_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Requester
    user_type           VARCHAR(20) NOT NULL,
    user_id             UUID NOT NULL,
    
    -- Request Details
    data_types          VARCHAR[] NOT NULL,
    -- Types: PROFILE, TRIPS, PAYMENTS, RATINGS, MESSAGES, LOCATIONS, ALL
    
    format              VARCHAR(20) DEFAULT 'JSON',
    
    -- Status
    status              VARCHAR(20) DEFAULT 'PENDING',
    -- Statuses: PENDING, PROCESSING, READY, DOWNLOADED, EXPIRED, FAILED
    
    -- Result
    download_url        VARCHAR(500),
    file_size_bytes     BIGINT,
    expires_at          TIMESTAMP WITH TIME ZONE,
    download_count      INT DEFAULT 0,
    
    -- Processing
    processed_by        VARCHAR(100),               -- System or admin
    error_message       TEXT,
    
    -- Timestamps
    requested_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at        TIMESTAMP WITH TIME ZONE,
    downloaded_at       TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_data_export_requests_user ON data_export_requests(user_type, user_id);
CREATE INDEX idx_data_export_requests_status ON data_export_requests(status);

-- ============================================================================
-- DATA DELETION REQUESTS TABLE (GDPR Right to be Forgotten)
-- ============================================================================
CREATE TABLE data_deletion_requests (
    request_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Requester
    user_type           VARCHAR(20) NOT NULL,
    user_id             UUID NOT NULL,
    user_email          VARCHAR(255),
    user_phone          VARCHAR(20),
    
    -- Request Details
    reason              VARCHAR(100),
    additional_notes    TEXT,
    
    -- Scope
    deletion_scope      VARCHAR(20) DEFAULT 'FULL',
    -- Scopes: FULL, PARTIAL (keep for legal), ANONYMIZE
    
    -- Legal Hold
    legal_hold          BOOLEAN DEFAULT FALSE,
    legal_hold_reason   VARCHAR(255),
    legal_hold_until    DATE,
    
    -- Status
    status              VARCHAR(20) DEFAULT 'PENDING',
    -- Statuses: PENDING, APPROVED, PROCESSING, COMPLETED, REJECTED, ON_HOLD
    
    -- Approval
    approved_by         UUID REFERENCES admin_users(admin_id),
    approval_notes      TEXT,
    
    -- Execution
    executed_by         VARCHAR(100),
    data_deleted        JSONB,                      -- Record of what was deleted
    
    -- Timestamps
    requested_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_at         TIMESTAMP WITH TIME ZONE,
    completed_at        TIMESTAMP WITH TIME ZONE,
    
    -- Legal requirement: Keep record of deletion for X years
    record_expires_at   DATE
);

CREATE INDEX idx_data_deletion_requests_user ON data_deletion_requests(user_type, user_id);
CREATE INDEX idx_data_deletion_requests_status ON data_deletion_requests(status);

-- ============================================================================
-- SENSITIVE DATA ACCESS LOG TABLE
-- ============================================================================
CREATE TABLE sensitive_data_access_logs (
    log_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Who Accessed
    accessor_type       VARCHAR(20) NOT NULL,       -- admin, system, api
    accessor_id         UUID,
    
    -- What Was Accessed
    data_type           VARCHAR(50) NOT NULL,
    -- Types: PAYMENT_DETAILS, FULL_PHONE, FULL_EMAIL, ID_DOCUMENTS, TRIP_ROUTE, LOCATION_HISTORY, MESSAGES
    
    target_user_type    VARCHAR(20),
    target_user_id      UUID,
    record_id           UUID,
    
    -- Access Details
    access_reason       VARCHAR(100),               -- SUPPORT_TICKET, FRAUD_INVESTIGATION, DATA_EXPORT
    reference_id        VARCHAR(255),               -- Ticket ID, etc.
    
    -- Context
    ip_address          INET,
    
    accessed_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sensitive_access_logs_accessor ON sensitive_data_access_logs(accessor_type, accessor_id);
CREATE INDEX idx_sensitive_access_logs_target ON sensitive_data_access_logs(target_user_type, target_user_id);
CREATE INDEX idx_sensitive_access_logs_time ON sensitive_data_access_logs(accessed_at DESC);

-- ============================================================================
-- COMPLIANCE REPORTS TABLE (Scheduled reports for regulators)
-- ============================================================================
CREATE TABLE compliance_reports (
    report_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Report Details
    report_type         VARCHAR(50) NOT NULL,
    -- Types: SAFETY_SUMMARY, FRAUD_SUMMARY, DATA_REQUESTS, INCIDENT_REPORT, DRIVER_COMPLIANCE
    
    report_period_start DATE NOT NULL,
    report_period_end   DATE NOT NULL,
    
    -- Content
    report_data         JSONB NOT NULL,
    report_file_url     VARCHAR(500),
    
    -- Status
    status              VARCHAR(20) DEFAULT 'GENERATED',
    
    -- Submission (if required by regulator)
    submitted_to        VARCHAR(100),
    submitted_at        TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    generated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    generated_by        UUID
);

CREATE INDEX idx_compliance_reports_type ON compliance_reports(report_type, report_period_end DESC);

-- ============================================================================
-- POLICY VERSIONS TABLE (Track T&C / Privacy Policy versions)
-- ============================================================================
CREATE TABLE policy_versions (
    policy_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Policy Details
    policy_type         VARCHAR(50) NOT NULL,
    -- Types: TERMS_OF_SERVICE, PRIVACY_POLICY, DRIVER_AGREEMENT, COOKIE_POLICY
    
    version             VARCHAR(20) NOT NULL,
    
    -- Content
    content_url         VARCHAR(500) NOT NULL,
    summary_changes     TEXT,
    
    -- Status
    is_current          BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    effective_from      TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by          UUID,
    
    UNIQUE(policy_type, version)
);

CREATE INDEX idx_policy_versions_current ON policy_versions(policy_type, is_current) WHERE is_current = TRUE;

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

-- Apply triggers
CREATE TRIGGER tr_riders_updated_at BEFORE UPDATE ON riders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_trips_updated_at BEFORE UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_driver_wallet_updated_at BEFORE UPDATE ON driver_wallet
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update driver rating
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

CREATE TRIGGER tr_update_driver_rating AFTER INSERT OR UPDATE ON ratings
    FOR EACH ROW EXECUTE FUNCTION update_driver_avg_rating();

-- Function to update rider rating
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

CREATE TRIGGER tr_update_rider_rating AFTER INSERT OR UPDATE ON ratings
    FOR EACH ROW EXECUTE FUNCTION update_rider_avg_rating();

-- Function to generate ticket number
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    new_number VARCHAR(20);
BEGIN
    new_number := 'TKT' || TO_CHAR(CURRENT_DATE, 'YYMMDD') || '-' || 
                  LPAD(NEXTVAL('ticket_number_seq')::TEXT, 5, '0');
    NEW.ticket_number := new_number;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE SEQUENCE IF NOT EXISTS ticket_number_seq START 1;

CREATE TRIGGER tr_generate_ticket_number BEFORE INSERT ON support_tickets
    FOR EACH ROW EXECUTE FUNCTION generate_ticket_number();

-- ============================================================================
-- SAMPLE DATA FOR INITIAL SETUP
-- ============================================================================

-- Insert default cities
INSERT INTO cities (city_id, name, state, country, timezone, currency, commission_rate) VALUES
(uuid_generate_v4(), 'Mumbai', 'Maharashtra', 'India', 'Asia/Kolkata', 'INR', 20.00),
(uuid_generate_v4(), 'Delhi', 'Delhi', 'India', 'Asia/Kolkata', 'INR', 20.00),
(uuid_generate_v4(), 'Bangalore', 'Karnataka', 'India', 'Asia/Kolkata', 'INR', 20.00),
(uuid_generate_v4(), 'Hyderabad', 'Telangana', 'India', 'Asia/Kolkata', 'INR', 20.00),
(uuid_generate_v4(), 'Chennai', 'Tamil Nadu', 'India', 'Asia/Kolkata', 'INR', 20.00);

-- Insert vehicle types
INSERT INTO vehicle_types (name, display_name, description, max_passengers, sort_order) VALUES
('bike', 'Bike', 'Motorcycle ride for 1 passenger', 1, 1),
('auto', 'Auto', 'Auto rickshaw for up to 3 passengers', 3, 2),
('sedan', 'Sedan', 'Comfortable sedan car', 4, 3),
('suv', 'SUV/XL', 'Spacious SUV for groups', 6, 4),
('premium', 'Premium', 'Luxury vehicle experience', 4, 5);

-- Insert default admin
INSERT INTO admin_users (email, password_hash, name, role) VALUES
('admin@rideshare.com', '$2a$10$placeholder_hash', 'Super Admin', 'SUPER_ADMIN');

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
