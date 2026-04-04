-- ============================================================
-- Aegis Intelligence — Complete Schema v2.0
-- ============================================================

-- WORKERS
CREATE TABLE IF NOT EXISTS workers (
    worker_id           VARCHAR(50) PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    phone               VARCHAR(15),
    upi_id              VARCHAR(100),
    kyc_status          VARCHAR(20) DEFAULT 'PENDING',
    platform            VARCHAR(20) DEFAULT 'ZOMATO',
    zone                VARCHAR(50),
    avg_orders_7d       INT DEFAULT 12,
    avg_earnings_12w    FLOAT DEFAULT 1650,  -- DAILY average earnings (INR)
    avg_hours_baseline  FLOAT DEFAULT 8.0,   -- DAILY target working hours
    target_daily_hours  FLOAT DEFAULT 8.0,
    onboarded_at        TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

-- ORDERS (real-time delivery activity)
CREATE TABLE IF NOT EXISTS orders (
    order_id    SERIAL PRIMARY KEY,
    worker_id   VARCHAR(50) NOT NULL REFERENCES workers(worker_id),
    lat         FLOAT,
    lon         FLOAT,
    earnings    FLOAT NOT NULL,
    timestamp   TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_orders_worker_date ON orders(worker_id, timestamp);

-- POLICIES (weekly insurance subscriptions)
CREATE TABLE IF NOT EXISTS policies (
    policy_id       SERIAL PRIMARY KEY,
    worker_id       VARCHAR(50) NOT NULL REFERENCES workers(worker_id),
    plan_name       VARCHAR(20) NOT NULL DEFAULT 'STANDARD',
    weekly_premium  FLOAT NOT NULL,
    coverage_start  TIMESTAMP NOT NULL DEFAULT NOW(),
    coverage_end    TIMESTAMP NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    payment_ref     VARCHAR(100),
    auto_renew      BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_policies_worker ON policies(worker_id);

-- CLAIMS (full lifecycle)
CREATE TABLE IF NOT EXISTS claims (
    claim_id        SERIAL PRIMARY KEY,
    worker_id       VARCHAR(50) NOT NULL REFERENCES workers(worker_id),
    policy_id       INT REFERENCES policies(policy_id),
    trigger_type    VARCHAR(50) NOT NULL,
    trigger_pct     FLOAT NOT NULL,
    claimed_amount  FLOAT NOT NULL,
    approved_amount FLOAT,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    fraud_score     FLOAT,
    fraud_level     VARCHAR(20),
    risk_score      FLOAT,
    lat             FLOAT,
    lon             FLOAT,
    weather_snapshot JSONB,
    created_at      TIMESTAMP DEFAULT NOW(),
    resolved_at     TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_claims_worker ON claims(worker_id);
CREATE INDEX IF NOT EXISTS idx_claims_status ON claims(status);

-- PAYOUTS (approved disbursements)
CREATE TABLE IF NOT EXISTS payouts (
    payout_id       SERIAL PRIMARY KEY,
    worker_id       VARCHAR(50) NOT NULL REFERENCES workers(worker_id),
    claim_id        INT REFERENCES claims(claim_id),
    amount          FLOAT NOT NULL,
    trigger_type    VARCHAR(50),
    trigger_pct     FLOAT,
    hourly_rate     FLOAT,
    hours_lost      FLOAT,
    risk_level      VARCHAR(20),
    income_severity VARCHAR(20),
    fraud_level     VARCHAR(20),
    payout_status   VARCHAR(20) DEFAULT 'PENDING',
    triggered_at    TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payouts_worker ON payouts(worker_id);

-- WORKER SESSIONS (daily activity for fraud detection)
CREATE TABLE IF NOT EXISTS worker_sessions (
    session_id      SERIAL PRIMARY KEY,
    worker_id       VARCHAR(50) NOT NULL REFERENCES workers(worker_id),
    session_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    first_online    TIMESTAMP,
    last_ping       TIMESTAMP,
    hours_online    FLOAT DEFAULT 0.0,
    movement_km     FLOAT DEFAULT 0.0,
    deliveries_done INT DEFAULT 0,
    lat_last        FLOAT,
    lon_last        FLOAT,
    zone            VARCHAR(50),
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(worker_id, session_date)
);

-- TRANSACTIONS (comprehensive financial event logging)
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id  SERIAL PRIMARY KEY,
    worker_id       VARCHAR(50) NOT NULL REFERENCES workers(worker_id),
    claim_id        INT REFERENCES claims(claim_id),
    payout_id       INT REFERENCES payouts(payout_id),
    transaction_type VARCHAR(30) NOT NULL, -- 'PREMIUM_DEBIT', 'PAYOUT_CREDIT', 'CLAIM_HOLD', 'CLAIM_RELEASE'
    amount          FLOAT NOT NULL,
    balance_before  FLOAT,
    balance_after   FLOAT,
    upi_ref         VARCHAR(100),
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'COMPLETED', 'FAILED'
    metadata        JSONB,
    created_at      TIMESTAMP DEFAULT NOW(),
    completed_at    TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_transactions_worker ON transactions(worker_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);

-- AUDIT_LOG (comprehensive system event tracking)
CREATE TABLE IF NOT EXISTS audit_log (
    log_id          SERIAL PRIMARY KEY,
    event_type      VARCHAR(50) NOT NULL, -- 'CLAIM_SUBMITTED', 'PAYOUT_APPROVED', 'FRAUD_DETECTED', 'ANALYSIS_RUN'
    entity_type     VARCHAR(30), -- 'WORKER', 'CLAIM', 'PAYOUT', 'POLICY'
    entity_id       VARCHAR(100),
    worker_id       VARCHAR(50) REFERENCES workers(worker_id),
    action_by       VARCHAR(50) DEFAULT 'SYSTEM', -- 'SYSTEM', 'ADMIN', 'ML_MODEL'
    severity        VARCHAR(20) DEFAULT 'INFO', -- 'INFO', 'WARNING', 'ERROR', 'CRITICAL'
    message         TEXT,
    details         JSONB, -- JSON payload with full context (risk scores, triggers, reasoning)
    ip_address      VARCHAR(50),
    created_at      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_worker ON audit_log(worker_id);
CREATE INDEX IF NOT EXISTS idx_audit_event ON audit_log(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_severity ON audit_log(severity);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(created_at);
