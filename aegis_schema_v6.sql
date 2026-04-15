-- ============================================================
-- AEGIS - Prototype Schema v6.0
-- Guidewire DEVTrails 2026 - Team Zero Noise Crew
--
-- Changes from v5.0:
--   workers           + registration_step now includes 'LOCATION' step
--                       (PHONE → OTP → PROFILE → INCOME → LOCATION → DONE)
--                     + Comment updated: upi_id and avg_earnings_12w are
--                       collected in the INCOME step (not PROFILE)
--   auth_sessions     + login_worker_id column: the worker_id the user typed
--                       at the login screen (before OTP verification).
--                       Allows matching worker_id + phone together at login.
--   payment_trigger_notifications
--                     + POLICY_RENEWED notification type added
--   v_worker_home     + hours_lost added to the view
--   ID_STANDARDS      See ID_STANDARDS.md for naming conventions
-- ============================================================

-- 0. CLEAN SLATE
DROP TABLE IF EXISTS payment_trigger_notifications  CASCADE;
DROP TABLE IF EXISTS worker_latest_analysis         CASCADE;
DROP TABLE IF EXISTS zone_location_log              CASCADE;
DROP TABLE IF EXISTS zone_neighbours                CASCADE;
DROP TABLE IF EXISTS auth_sessions                  CASCADE;
DROP TABLE IF EXISTS audit_log                      CASCADE;
DROP TABLE IF EXISTS payments                       CASCADE;
DROP TABLE IF EXISTS payouts                        CASCADE;
DROP TABLE IF EXISTS disruption_alerts              CASCADE;
DROP TABLE IF EXISTS worker_sessions                CASCADE;
DROP TABLE IF EXISTS orders                         CASCADE;
DROP TABLE IF EXISTS policies                       CASCADE;
DROP TABLE IF EXISTS otps                           CASCADE;
DROP TABLE IF EXISTS workers                        CASCADE;
DROP FUNCTION IF EXISTS touch_updated_at() CASCADE;


-- ============================================================
-- 1. WORKERS
-- ============================================================
CREATE TABLE workers (
    worker_id           VARCHAR(20)   PRIMARY KEY,
    name                VARCHAR(100)  NOT NULL,
    phone               VARCHAR(15)   NOT NULL UNIQUE,
    upi_id              VARCHAR(100),
    kyc_status          VARCHAR(20)   NOT NULL DEFAULT 'PENDING'
                            CHECK (kyc_status IN ('PENDING','VERIFIED','REJECTED')),
    kyc_complete        BOOLEAN       NOT NULL DEFAULT FALSE,
    platform            VARCHAR(20)   NOT NULL DEFAULT 'ZOMATO'
                            CHECK (platform IN ('ZOMATO','SWIGGY','BLINKIT','AMAZON','BOTH')),
    zone                VARCHAR(60),
    city                VARCHAR(60),

    -- Home-base coordinates (set at LOCATION step; updated only on zone-promotion)
    lat                 NUMERIC(10,6),
    lon                 NUMERIC(10,6),
    -- Live position (updated every POST /api/v1/session-ping call)
    lat_last            NUMERIC(10,6),
    lon_last            NUMERIC(10,6),

    avg_orders_7d       INT           NOT NULL DEFAULT 12,
    avg_earnings_12w    NUMERIC(10,2) NOT NULL DEFAULT 1650.00,
    avg_hours_baseline  NUMERIC(5,2)  NOT NULL DEFAULT 8.00,
    target_daily_hours  NUMERIC(5,2)  NOT NULL DEFAULT 8.00,

    plan_tier           VARCHAR(20)   NOT NULL DEFAULT 'STANDARD'
                            CHECK (plan_tier IN ('BASIC','STANDARD','PREMIUM')),
    weekly_premium      NUMERIC(8,2)  NOT NULL DEFAULT 34.00,
    subscribed          BOOLEAN       NOT NULL DEFAULT FALSE,

    aadhaar_hash        VARCHAR(64),

    registration_step   VARCHAR(20)   NOT NULL DEFAULT 'PHONE'
                            CHECK (registration_step IN
                                ('PHONE','OTP','PROFILE','INCOME','LOCATION','DONE')),

    onboarded_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workers_phone    ON workers(phone);
CREATE INDEX idx_workers_zone     ON workers(zone);
CREATE INDEX idx_workers_kyc      ON workers(kyc_status);
CREATE INDEX idx_workers_active   ON workers(subscribed) WHERE subscribed = TRUE;
CREATE INDEX idx_workers_step     ON workers(registration_step)
    WHERE registration_step <> 'DONE';


CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_workers_updated
    BEFORE UPDATE ON workers
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();


-- ============================================================
-- 2. OTPS
-- ============================================================
CREATE TABLE otps (
    id          SERIAL       PRIMARY KEY,
    phone       VARCHAR(15)  NOT NULL,
    otp         VARCHAR(6)   NOT NULL,
    expires_at  TIMESTAMPTZ  NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
    used        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otps_phone  ON otps(phone);
CREATE INDEX idx_otps_active ON otps(phone, expires_at) WHERE used = FALSE;


-- ============================================================
-- 3. AUTH SESSIONS
-- ============================================================
CREATE TABLE auth_sessions (
    session_token       VARCHAR(128)  PRIMARY KEY,
    worker_id           VARCHAR(20)   REFERENCES workers(worker_id) ON DELETE CASCADE,
    login_worker_id     VARCHAR(20),
    phone               VARCHAR(15)   NOT NULL,
    is_new_registration BOOLEAN       NOT NULL DEFAULT FALSE,
    resumed_step        VARCHAR(20)   CHECK (resumed_step IN
                            ('PHONE','OTP','PROFILE','INCOME','LOCATION','DONE')),
    is_valid            BOOLEAN       NOT NULL DEFAULT TRUE,
    device_info         TEXT,
    ip_address          INET,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ   NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    last_used_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auth_worker   ON auth_sessions(worker_id);
CREATE INDEX idx_auth_phone    ON auth_sessions(phone);
CREATE INDEX idx_auth_valid    ON auth_sessions(session_token) WHERE is_valid = TRUE;
CREATE INDEX idx_auth_expiry   ON auth_sessions(expires_at)    WHERE is_valid = TRUE;
CREATE INDEX idx_auth_login_id ON auth_sessions(login_worker_id)
    WHERE login_worker_id IS NOT NULL;


-- ============================================================
-- 4. POLICIES
-- ============================================================
CREATE TABLE policies (
    policy_id       SERIAL        PRIMARY KEY,
    worker_id       VARCHAR(20)   NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    plan_name       VARCHAR(20)   NOT NULL DEFAULT 'STANDARD'
                        CHECK (plan_name IN ('BASIC','STANDARD','PREMIUM')),
    weekly_premium  NUMERIC(8,2)  NOT NULL,
    payout_cap      NUMERIC(10,2) NOT NULL DEFAULT 480.00,
    coverage_start  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    coverage_end    TIMESTAMPTZ   NOT NULL,
    status          VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','EXPIRED','CANCELLED')),
    payment_ref     VARCHAR(120),
    auto_renew      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_policies_worker ON policies(worker_id);
CREATE INDEX idx_policies_status ON policies(status);
CREATE INDEX idx_policies_end    ON policies(coverage_end) WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX idx_policies_one_active
    ON policies(worker_id) WHERE status = 'ACTIVE';


-- ============================================================
-- 5. ORDERS
-- ============================================================
CREATE TABLE orders (
    order_id    SERIAL        PRIMARY KEY,
    worker_id   VARCHAR(20)   NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    lat         NUMERIC(10,6),
    lon         NUMERIC(10,6),
    earnings    NUMERIC(8,2)  NOT NULL CHECK (earnings >= 0),
    platform    VARCHAR(20),
    zone        VARCHAR(60),
    timestamp   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_worker_ts   ON orders(worker_id, timestamp DESC);
CREATE INDEX idx_orders_zone_today  ON orders(zone, timestamp DESC);
CREATE INDEX idx_orders_worker_zone ON orders(worker_id, zone, timestamp DESC);


-- ============================================================
-- 6. WORKER SESSIONS
-- ============================================================
CREATE TABLE worker_sessions (
    session_id      SERIAL        PRIMARY KEY,
    worker_id       VARCHAR(20)   NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    session_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
    first_online    TIMESTAMPTZ,
    last_ping       TIMESTAMPTZ,
    hours_online    NUMERIC(5,2)  NOT NULL DEFAULT 0.00,
    movement_km     NUMERIC(8,3)  NOT NULL DEFAULT 0.000,
    deliveries_done INT           NOT NULL DEFAULT 0,
    lat_last        NUMERIC(10,6),
    lon_last        NUMERIC(10,6),
    zone            VARCHAR(60),
    zone_mismatch   BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (worker_id, session_date)
);

CREATE INDEX idx_sessions_worker ON worker_sessions(worker_id);
CREATE INDEX idx_sessions_date   ON worker_sessions(session_date);


-- ============================================================
-- 7. ZONE NEIGHBOURS
-- ============================================================
CREATE TABLE zone_neighbours (
    id              SERIAL        PRIMARY KEY,
    zone            VARCHAR(60)   NOT NULL,
    neighbour_zone  VARCHAR(60)  NOT NULL,
    distance_km     NUMERIC(6,2),
    UNIQUE (zone, neighbour_zone)
);

CREATE INDEX idx_zn_zone      ON zone_neighbours(zone);
CREATE INDEX idx_zn_neighbour ON zone_neighbours(neighbour_zone);


-- ============================================================
-- 8. ZONE LOCATION LOG
-- ============================================================
CREATE TABLE zone_location_log (
    log_id              BIGSERIAL     PRIMARY KEY,
    worker_id           VARCHAR(20)   NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    from_zone           VARCHAR(60),
    to_zone             VARCHAR(60)   NOT NULL,
    from_lat            NUMERIC(10,6),
    from_lon            NUMERIC(10,6),
    to_lat              NUMERIC(10,6),
    to_lon              NUMERIC(10,6),
    orders_in_new_zone  INT           NOT NULL DEFAULT 0,
    promoted_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_zll_worker ON zone_location_log(worker_id);
CREATE INDEX idx_zll_ts     ON zone_location_log(promoted_at DESC);


-- ============================================================
-- 9. DISRUPTION ALERTS
-- ============================================================
CREATE TABLE disruption_alerts (
    id              SERIAL        PRIMARY KEY,
    worker_id       VARCHAR(20)   REFERENCES workers(worker_id) ON DELETE SET NULL,
    trigger_type    VARCHAR(50)   NOT NULL,
    zone            VARCHAR(60)   NOT NULL,
    city            VARCHAR(60),
    severity        NUMERIC(4,2)  NOT NULL DEFAULT 0.00
                        CHECK (severity BETWEEN 0 AND 10),
    payout_pct      NUMERIC(5,2)  NOT NULL DEFAULT 0.00
                        CHECK (payout_pct BETWEEN 0 AND 1),
    status          VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','RESOLVED','EXPIRED')),
    raw_metric      NUMERIC(10,3),
    threshold_used  NUMERIC(10,3),
    detected_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE INDEX idx_alerts_zone   ON disruption_alerts(zone);
CREATE INDEX idx_alerts_status ON disruption_alerts(status);
CREATE INDEX idx_alerts_type   ON disruption_alerts(trigger_type);
CREATE INDEX idx_alerts_worker ON disruption_alerts(worker_id) WHERE worker_id IS NOT NULL;
CREATE INDEX idx_alerts_active ON disruption_alerts(detected_at DESC) WHERE status = 'ACTIVE';


-- ============================================================
-- 10. PAYOUTS
-- ============================================================
CREATE TABLE payouts (
    payout_id               SERIAL        PRIMARY KEY,
    worker_id               VARCHAR(20)   NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    policy_id               INT           REFERENCES policies(policy_id),
    alert_id                INT           REFERENCES disruption_alerts(id),

    trigger_type            VARCHAR(60)   NOT NULL,
    trigger_pct             NUMERIC(5,4)  NOT NULL DEFAULT 0.00
                                CHECK (trigger_pct BETWEEN 0 AND 1),

    hourly_rate             NUMERIC(8,2),
    hours_lost              NUMERIC(5,2),
    amount                  NUMERIC(10,2) NOT NULL DEFAULT 0.00,

    risk_score              NUMERIC(5,2),
    risk_level              VARCHAR(20),
    income_drop_pct         NUMERIC(6,2),
    income_severity         VARCHAR(20),

    fraud_score             NUMERIC(5,4),
    enhanced_fraud_score    NUMERIC(5,4),
    fraud_level             VARCHAR(20),
    fraud_rules_triggered   JSONB         NOT NULL DEFAULT '[]'::JSONB,

    gps_lat                 NUMERIC(10,6),
    gps_lng                 NUMERIC(10,6),
    zone_at_claim           VARCHAR(60),

    payout_status           VARCHAR(20)   NOT NULL DEFAULT 'PENDING'
                                CHECK (payout_status IN
                                    ('PENDING','APPROVED','DENIED','HELD','BANNED','PAID','FAILED')),
    review_note             TEXT,
    triggered_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    resolved_at             TIMESTAMPTZ
);

CREATE INDEX idx_payouts_worker  ON payouts(worker_id);
CREATE INDEX idx_payouts_status  ON payouts(payout_status);
CREATE INDEX idx_payouts_ts      ON payouts(triggered_at DESC);
CREATE INDEX idx_payouts_alert   ON payouts(alert_id);
CREATE INDEX idx_payouts_fraud   ON payouts(enhanced_fraud_score DESC)
    WHERE enhanced_fraud_score >= 0.30;
CREATE INDEX idx_payouts_today   ON payouts(worker_id, triggered_at);


-- ============================================================
-- 11. PAYMENTS
-- ============================================================
CREATE TABLE payments (
    payment_id      SERIAL        PRIMARY KEY,
    payout_id       INT           NOT NULL REFERENCES payouts(payout_id) ON DELETE CASCADE,
    worker_id       VARCHAR(20)   NOT NULL REFERENCES workers(worker_id),
    amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    currency        CHAR(3)       NOT NULL DEFAULT 'INR',
    payment_method  VARCHAR(30)   NOT NULL DEFAULT 'UPI'
                        CHECK (payment_method IN ('UPI','BANK_TRANSFER','WALLET')),
    upi_id          VARCHAR(100),
    payment_ref     VARCHAR(150),
    gateway         VARCHAR(30)   NOT NULL DEFAULT 'RAZORPAY',
    simulation_mode BOOLEAN       NOT NULL DEFAULT FALSE,
    status          VARCHAR(20)   NOT NULL DEFAULT 'INITIATED'
                        CHECK (status IN ('INITIATED','PROCESSING','SUCCESS','FAILED','REFUNDED')),
    initiated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    failure_reason  TEXT
);

CREATE INDEX idx_payments_payout ON payments(payout_id);
CREATE INDEX idx_payments_worker ON payments(worker_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_ref    ON payments(payment_ref) WHERE payment_ref IS NOT NULL;


-- ============================================================
-- 12. WORKER LATEST ANALYSIS
-- ============================================================
CREATE TABLE worker_latest_analysis (
    worker_id               VARCHAR(20)   PRIMARY KEY
                                REFERENCES workers(worker_id) ON DELETE CASCADE,
    risk_score              NUMERIC(5,2),
    risk_level              VARCHAR(20),
    income_drop_pct         NUMERIC(6,2),
    income_severity         VARCHAR(20),
    trigger_type            VARCHAR(60),
    hours_online            NUMERIC(5,2),
    hours_lost              NUMERIC(5,2),
    earnings_today          NUMERIC(10,2),
    fraud_score             NUMERIC(5,4),
    enhanced_fraud_score    NUMERIC(5,4),
    fraud_level             VARCHAR(20),
    fraud_rules_triggered   JSONB         NOT NULL DEFAULT '[]'::JSONB,
    payout_triggered        BOOLEAN       NOT NULL DEFAULT FALSE,
    payout_id               INT           REFERENCES payouts(payout_id),
    analysis_payout_status  VARCHAR(20),
    last_analysis_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wla_risk     ON worker_latest_analysis(risk_level);
CREATE INDEX idx_wla_fraud    ON worker_latest_analysis(fraud_level)
    WHERE fraud_level NOT IN ('LOW');
CREATE INDEX idx_wla_ts       ON worker_latest_analysis(last_analysis_at DESC);


-- ============================================================
-- 13. PAYMENT TRIGGER NOTIFICATIONS
-- ============================================================
CREATE TABLE payment_trigger_notifications (
    notif_id            SERIAL        PRIMARY KEY,
    worker_id           VARCHAR(20)   NOT NULL REFERENCES workers(worker_id) ON DELETE CASCADE,
    payout_id           INT           REFERENCES payouts(payout_id) ON DELETE SET NULL,
    notification_type   VARCHAR(40)   NOT NULL
                            CHECK (notification_type IN (
                                'ANALYSIS_STARTED',
                                'PAYOUT_APPROVED',
                                'PAYOUT_PAID',
                                'PAYOUT_DENIED',
                                'PAYOUT_HELD',
                                'PAYOUT_FAILED',
                                'POLICY_EXPIRING',
                                'POLICY_RENEWED'
                            )),
    title               VARCHAR(120)  NOT NULL,
    body                TEXT          NOT NULL,
    amount              NUMERIC(10,2),
    upi_id              VARCHAR(100),
    delivery_status     VARCHAR(20)   NOT NULL DEFAULT 'QUEUED'
                            CHECK (delivery_status IN ('QUEUED','SENT','FAILED','READ')),
    fcm_message_id      VARCHAR(200),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    sent_at             TIMESTAMPTZ,
    read_at             TIMESTAMPTZ
);

CREATE INDEX idx_notif_worker   ON payment_trigger_notifications(worker_id);
CREATE INDEX idx_notif_payout   ON payment_trigger_notifications(payout_id)
    WHERE payout_id IS NOT NULL;
CREATE INDEX idx_notif_unread   ON payment_trigger_notifications(worker_id, created_at DESC)
    WHERE delivery_status IN ('SENT','QUEUED');
CREATE INDEX idx_notif_type     ON payment_trigger_notifications(notification_type);


-- ============================================================
-- 14. AUDIT LOG
-- ============================================================
CREATE TABLE audit_log (
    log_id      BIGSERIAL     PRIMARY KEY,
    event_type  VARCHAR(60)   NOT NULL,
    entity_type VARCHAR(30),
    entity_id   VARCHAR(40),
    worker_id   VARCHAR(20)   REFERENCES workers(worker_id) ON DELETE SET NULL,
    action_by   VARCHAR(50)   NOT NULL DEFAULT 'SYSTEM',
    severity    VARCHAR(20)   NOT NULL DEFAULT 'INFO'
                    CHECK (severity IN ('INFO','WARNING','ERROR','CRITICAL')),
    message     TEXT,
    details     JSONB,
    ip_address  INET,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_worker   ON audit_log(worker_id);
CREATE INDEX idx_audit_event    ON audit_log(event_type);
CREATE INDEX idx_audit_severity ON audit_log(severity);
CREATE INDEX idx_audit_ts       ON audit_log(created_at DESC);
CREATE INDEX idx_audit_critical ON audit_log(created_at DESC) WHERE severity = 'CRITICAL';
CREATE INDEX idx_audit_details  ON audit_log USING GIN (details) WHERE details IS NOT NULL;


-- ============================================================
-- VIEWS
-- ============================================================

-- v_active_coverage
CREATE OR REPLACE VIEW v_active_coverage AS
SELECT
    w.worker_id, w.name, w.phone, w.upi_id, w.platform, w.zone, w.city,
    w.lat, w.lon, w.lat_last, w.lon_last,
    w.avg_earnings_12w, w.avg_hours_baseline, w.target_daily_hours,
    w.avg_orders_7d, w.registration_step,
    p.policy_id, p.plan_name, p.weekly_premium, p.payout_cap,
    p.coverage_start, p.coverage_end,
    (p.coverage_end - NOW()) AS time_remaining
FROM workers w
JOIN policies p ON p.worker_id = w.worker_id AND p.status = 'ACTIVE'
AND NOW() BETWEEN p.coverage_start AND p.coverage_end;


-- v_auto_trigger_candidates
CREATE OR REPLACE VIEW v_auto_trigger_candidates AS
SELECT
    w.worker_id, w.avg_earnings_12w, w.target_daily_hours, w.zone,
    w.avg_orders_7d, w.upi_id, w.lat, w.lon,
    p.policy_id, p.payout_cap,
    s.lat_last, s.lon_last, s.hours_online, s.movement_km,
    COALESCE(s.zone_mismatch, FALSE) AS zone_mismatch
FROM v_active_coverage w
JOIN policies p ON p.worker_id = w.worker_id AND p.status = 'ACTIVE'
LEFT JOIN worker_sessions s ON s.worker_id = w.worker_id AND s.session_date = CURRENT_DATE
WHERE w.registration_step = 'DONE'
AND NOT EXISTS (SELECT 1 FROM payouts px WHERE px.worker_id = w.worker_id AND px.payout_status IN ('PAID','APPROVED') AND px.triggered_at >= CURRENT_DATE)
AND NOT EXISTS (SELECT 1 FROM payouts pb WHERE pb.worker_id = w.worker_id AND pb.payout_status = 'BANNED');


-- v_today_payouts
CREATE OR REPLACE VIEW v_today_payouts AS
SELECT
    COUNT(*) AS total_count,
    COUNT(*) FILTER (WHERE payout_status = 'APPROVED') AS approved_count,
    COUNT(*) FILTER (WHERE payout_status = 'PAID') AS paid_count,
    COUNT(*) FILTER (WHERE payout_status = 'HELD') AS held_count,
    COUNT(*) FILTER (WHERE payout_status = 'BANNED') AS banned_count,
    COUNT(*) FILTER (WHERE payout_status = 'DENIED') AS denied_count,
    COALESCE(SUM(amount) FILTER (WHERE payout_status IN ('PAID','APPROVED')),0) AS total_approved_inr,
    COALESCE(SUM(amount) FILTER (WHERE payout_status = 'PAID'),0) AS total_paid_inr,
    COALESCE(AVG(enhanced_fraud_score),0) AS avg_fraud_score,
    COALESCE(AVG(risk_score),0) AS avg_risk_score,
    COALESCE(AVG(income_drop_pct),0) AS avg_income_drop
FROM payouts
WHERE triggered_at >= CURRENT_DATE;


-- v_fraud_watchlist
CREATE OR REPLACE VIEW v_fraud_watchlist AS
SELECT
    p.payout_id, p.worker_id, w.name, w.zone, p.zone_at_claim,
    (w.zone <> p.zone_at_claim) AS zone_changed_since_claim,
    w.platform, p.fraud_score AS base_fraud_score,
    p.enhanced_fraud_score, p.fraud_level, p.fraud_rules_triggered,
    p.trigger_type, p.amount, p.risk_score, p.income_drop_pct,
    p.payout_status, p.triggered_at
FROM payouts p
JOIN workers w ON w.worker_id = p.worker_id
WHERE GREATEST(COALESCE(p.enhanced_fraud_score,0), COALESCE(p.fraud_score,0)) >= 0.30
ORDER BY GREATEST(COALESCE(p.enhanced_fraud_score,0), COALESCE(p.fraud_score,0)) DESC, p.triggered_at DESC;


-- v_worker_home
CREATE OR REPLACE VIEW v_worker_home AS
SELECT
    w.worker_id, w.name, w.zone, w.city, w.platform, w.plan_tier, w.subscribed,
    w.upi_id, w.registration_step,
    p.plan_name, p.payout_cap, p.coverage_end,
    (p.coverage_end - NOW()) AS coverage_remaining,
    la.risk_score, la.risk_level, la.income_drop_pct, la.income_severity,
    la.trigger_type AS last_trigger_type,
    la.hours_online, la.hours_lost, la.earnings_today,
    la.payout_triggered, la.payout_id, la.analysis_payout_status, la.last_analysis_at,
    (SELECT COUNT(*) FROM payment_trigger_notifications n
     WHERE n.worker_id = w.worker_id AND n.delivery_status IN ('SENT','QUEUED') AND n.read_at IS NULL) AS unread_notifications
FROM workers w
LEFT JOIN policies p ON p.worker_id = w.worker_id AND p.status = 'ACTIVE'
LEFT JOIN worker_latest_analysis la ON la.worker_id = w.worker_id;


-- v_zone_promotion_eligibility
CREATE OR REPLACE VIEW v_zone_promotion_eligibility AS
SELECT
    w.worker_id, w.zone AS registered_zone, w.lat AS registered_lat, w.lon AS registered_lon,
    s.zone AS current_session_zone, s.lat_last AS current_lat, s.lon_last AS current_lon,
    zn.distance_km AS zone_distance_km, s.session_date
FROM workers w
JOIN worker_sessions s ON s.worker_id = w.worker_id AND s.session_date = CURRENT_DATE
JOIN zone_neighbours zn ON zn.zone = w.zone AND zn.neighbour_zone = s.zone
WHERE w.zone IS NOT NULL AND s.zone IS NOT NULL AND w.zone <> s.zone AND w.registration_step = 'DONE';


-- v_admin_stats
CREATE OR REPLACE VIEW v_admin_stats AS
SELECT
    (SELECT COUNT(*) FROM workers WHERE kyc_status = 'VERIFIED') AS verified_workers,
    (SELECT COUNT(*) FROM workers WHERE subscribed = TRUE) AS subscribed_workers,
    (SELECT COUNT(*) FROM workers WHERE registration_step <> 'DONE') AS incomplete_registrations,
    (SELECT COUNT(*) FROM policies WHERE status = 'ACTIVE') AS active_policies,
    (SELECT COUNT(*) FROM disruption_alerts WHERE status = 'ACTIVE') AS active_alerts,
    (SELECT COALESCE(SUM(amount) FILTER (WHERE payout_status = 'PAID'), 0) FROM payouts WHERE triggered_at >= CURRENT_DATE) AS today_paid_inr,
    (SELECT COUNT(*) FROM payouts WHERE triggered_at >= CURRENT_DATE) AS today_total_payouts,
    (SELECT COUNT(*) FROM payouts WHERE payout_status = 'PAID' AND triggered_at >= CURRENT_DATE) AS today_paid_count,
    (SELECT COUNT(*) FROM payouts WHERE payout_status = 'HELD' AND triggered_at >= CURRENT_DATE) AS today_held_count,
    (SELECT COUNT(*) FROM payouts WHERE payout_status = 'BANNED' AND triggered_at >= CURRENT_DATE) AS today_banned_count,
    (SELECT COUNT(*) FROM payouts WHERE GREATEST(COALESCE(enhanced_fraud_score,0), COALESCE(fraud_score,0)) >= 0.30 AND triggered_at >= CURRENT_DATE) AS today_fraud_flags,
    (SELECT COALESCE(SUM(weekly_premium), 0) FROM policies WHERE status = 'ACTIVE') AS weekly_premium_pool_inr,
    (SELECT COUNT(*) FROM payment_trigger_notifications WHERE delivery_status = 'QUEUED' AND created_at >= NOW() - INTERVAL '1 hour') AS pending_notifications;


-- v_loss_ratio
CREATE OR REPLACE VIEW v_loss_ratio AS
SELECT
    p.plan_name,
    COUNT(DISTINCT p.policy_id) AS policy_count,
    COALESCE(SUM(p.weekly_premium), 0) AS total_premiums_inr,
    COALESCE(SUM(py.amount) FILTER (WHERE py.payout_status IN ('PAID','APPROVED')), 0) AS total_payouts_inr,
    ROUND(COALESCE(SUM(py.amount) FILTER (WHERE py.payout_status IN ('PAID','APPROVED')), 0) / NULLIF(SUM(p.weekly_premium), 0) * 100, 1) AS loss_ratio_pct,
    COUNT(py.payout_id) FILTER (WHERE py.payout_status IN ('PAID','APPROVED')) AS paid_claims,
    COALESCE(AVG(py.risk_score), 0) AS avg_risk_score
FROM policies p
LEFT JOIN payouts py ON py.worker_id = p.worker_id AND py.triggered_at >= DATE_TRUNC('week', NOW())
WHERE p.status = 'ACTIVE'
GROUP BY p.plan_name
ORDER BY p.plan_name;


-- ============================================================
-- SEED DATA
-- ============================================================

INSERT INTO workers (
    worker_id, name, phone, upi_id,
    kyc_status, kyc_complete, platform, zone, city,
    lat, lon, lat_last, lon_last,
    avg_orders_7d, avg_earnings_12w, avg_hours_baseline, target_daily_hours,
    plan_tier, weekly_premium, subscribed, registration_step
) VALUES
('W001','Shiva Kumar',    '9876543210','shiva@upi',
 'VERIFIED',TRUE,'ZOMATO','Chennai-Central','Chennai',
 13.0827,80.2707, 13.0830,80.2705,
 14,1800.00,8.00,8.00,'STANDARD',34.00,TRUE,'DONE'),

('W002','Anand Rajan',    '9876543211','anand@upi',
 'VERIFIED',TRUE,'SWIGGY','Chennai-South','Chennai',
 13.0340,80.2440, 13.0360,80.2455,
 13,1750.00,7.50,7.50,'STANDARD',32.00,TRUE,'DONE'),

('W003','Karthik Selvan', '9876543212','karthik@upi',
 'VERIFIED',TRUE,'ZOMATO','Chennai-North','Chennai',
 13.1100,80.2970, 13.1100,80.2970,
 14,1780.00,7.00,7.00,'PREMIUM',49.00,TRUE,'DONE'),

('W004','Murugan Pillai', '9876543213','murugan@upi',
 'VERIFIED',TRUE,'BOTH','Chennai-East','Chennai',
 13.0680,80.2350, 13.0678,80.2356,
 9,1200.00,5.00,5.00,'BASIC',18.00,TRUE,'DONE'),

('W005','Priya Lakshmi',  '9876543214','priya@upi',
 'VERIFIED',TRUE,'SWIGGY','Coimbatore-Central','Coimbatore',
 11.0168,76.9558, 11.0180,76.9570,
 10,1500.00,6.00,6.00,'STANDARD',28.00,TRUE,'DONE')
ON CONFLICT (worker_id) DO NOTHING;


INSERT INTO policies
    (worker_id, plan_name, weekly_premium, payout_cap,
     coverage_start, coverage_end, status, payment_ref)
VALUES
('W001','STANDARD',34.00,480.00,
 NOW()-INTERVAL '3 days',NOW()+INTERVAL '4 days','ACTIVE','rzp_test_pay_001'),
('W002','STANDARD',32.00,480.00,
 NOW()-INTERVAL '2 days',NOW()+INTERVAL '5 days','ACTIVE','rzp_test_pay_002'),
('W003','PREMIUM', 49.00,800.00,
 NOW()-INTERVAL '1 day', NOW()+INTERVAL '6 days','ACTIVE','rzp_test_pay_003'),
('W004','BASIC',   18.00,400.00,
 NOW()-INTERVAL '4 days',NOW()+INTERVAL '3 days','ACTIVE','rzp_test_pay_004'),
('W005','STANDARD',28.00,480.00,
 NOW()-INTERVAL '5 days',NOW()+INTERVAL '2 days','ACTIVE','rzp_test_pay_005')
ON CONFLICT DO NOTHING;


INSERT INTO worker_sessions
    (worker_id, session_date, first_online, last_ping,
     hours_online, movement_km, deliveries_done,
     lat_last, lon_last, zone, zone_mismatch)
VALUES
('W001',CURRENT_DATE,NOW()-INTERVAL '7h',NOW()-INTERVAL '30m',
 6.5,42.3,9, 13.0830,80.2705,'Chennai-Central',FALSE),
('W002',CURRENT_DATE,NOW()-INTERVAL '6h',NOW()-INTERVAL '1h',
 5.0,28.1,3, 13.0360,80.2455,'Chennai-South',FALSE),
('W003',CURRENT_DATE,NOW()-INTERVAL '5h',NOW()-INTERVAL '45m',
 4.2,31.5,3, 13.1100,80.2970,'Chennai-North',FALSE),
('W004',CURRENT_DATE,NOW()-INTERVAL '3h',NOW()-INTERVAL '20m',
 2.8,3.2,1,  13.0678,80.2356,'Chennai-East',FALSE),
('W005',CURRENT_DATE,NOW()-INTERVAL '4h',NOW()-INTERVAL '1h',
 3.8,22.6,2, 11.0180,76.9570,'Coimbatore-Central',FALSE)
ON CONFLICT (worker_id, session_date) DO UPDATE SET
    hours_online = EXCLUDED.hours_online,
    movement_km = EXCLUDED.movement_km,
    deliveries_done = EXCLUDED.deliveries_done,
    last_ping = EXCLUDED.last_ping,
    lat_last = EXCLUDED.lat_last,
    lon_last = EXCLUDED.lon_last,
    zone_mismatch = EXCLUDED.zone_mismatch;


INSERT INTO orders (worker_id, lat, lon, earnings, platform, zone, timestamp) VALUES
('W001',13.0827,80.2707,185.00,'ZOMATO','Chennai-Central',NOW()-INTERVAL '7h'),
('W001',13.0850,80.2720,210.00,'ZOMATO','Chennai-Central',NOW()-INTERVAL '6h'),
('W001',13.0800,80.2690,175.00,'ZOMATO','Chennai-Central',NOW()-INTERVAL '5h'),
('W001',13.0860,80.2730,195.00,'ZOMATO','Chennai-Central',NOW()-INTERVAL '4h'),
('W001',13.0820,80.2700,200.00,'ZOMATO','Chennai-Central',NOW()-INTERVAL '3h'),
('W002',13.0345,80.2442,160.00,'SWIGGY','Chennai-South',  NOW()-INTERVAL '5h'),
('W002',13.0360,80.2455,140.00,'SWIGGY','Chennai-South',  NOW()-INTERVAL '4h'),
('W002',13.0380,80.2470,175.00,'SWIGGY','Chennai-South',  NOW()-INTERVAL '3h'),
('W003',13.1100,80.2970,210.00,'ZOMATO','Chennai-North',  NOW()-INTERVAL '4h'),
('W003',13.1120,80.2990,225.00,'ZOMATO','Chennai-North',  NOW()-INTERVAL '3h'),
('W005',11.0180,76.9570,130.00,'SWIGGY','Coimbatore-Central',NOW()-INTERVAL '3h'),
('W005',11.0200,76.9590,150.00,'SWIGGY','Coimbatore-Central',NOW()-INTERVAL '2h');


INSERT INTO zone_neighbours (zone, neighbour_zone, distance_km) VALUES
('Chennai-Central','Chennai-North',   8.50),
('Chennai-Central','Chennai-South',   7.20),
('Chennai-Central','Chennai-East',    6.80),
('Chennai-Central','Chennai-West',    9.10),
('Chennai-North',  'Chennai-Central', 8.50),
('Chennai-North',  'Chennai-East',    10.20),
('Chennai-North',  'Chennai-West',    11.50),
('Chennai-South',  'Chennai-Central', 7.20),
('Chennai-South',  'Chennai-East',    9.40),
('Chennai-South',  'Chennai-West',    8.80),
('Chennai-East',   'Chennai-Central', 6.80),
('Chennai-East',   'Chennai-North',   10.20),
('Chennai-East',   'Chennai-South',   9.40),
('Chennai-West',   'Chennai-Central', 9.10),
('Chennai-West',   'Chennai-North',   11.50),
('Chennai-West',   'Chennai-South',   8.80),
('Coimbatore-Central','Coimbatore-North', 7.00),
('Coimbatore-Central','Coimbatore-South', 6.50),
('Coimbatore-Central','Coimbatore-East',  5.80),
('Coimbatore-Central','Coimbatore-West',  6.20)
ON CONFLICT (zone, neighbour_zone) DO NOTHING;


INSERT INTO disruption_alerts
    (trigger_type, zone, city, severity, payout_pct, status,
     raw_metric, threshold_used, detected_at)
VALUES
('Heavy Rainfall','Chennai-Central','Chennai',
 8.20, 0.80, 'ACTIVE', 52.0, 45.0, NOW()-INTERVAL '2h'),
('Heavy Rainfall','Chennai-South','Chennai',
 7.50, 0.70, 'ACTIVE', 47.5, 45.0, NOW()-INTERVAL '2h'),
('Heavy Rainfall','Chennai-East','Chennai',
 8.00, 0.80, 'ACTIVE', 50.2, 45.0, NOW()-INTERVAL '2h');


INSERT INTO payouts (
    worker_id, policy_id, trigger_type, trigger_pct,
    hourly_rate, hours_lost, amount,
    risk_score, risk_level, income_drop_pct, income_severity,
    fraud_score, enhanced_fraud_score, fraud_level, fraud_rules_triggered,
    gps_lat, gps_lng, zone_at_claim,
    payout_status, triggered_at
)
SELECT
    'W001',
    (SELECT policy_id FROM policies WHERE worker_id='W001' AND status='ACTIVE'),
    'Heavy Rainfall', 0.8000,
    225.00, 2.00, 480.00,
    7.4, 'CRITICAL', 62.10, 'SEVERE',
    0.0410, 0.0410, 'LOW', '[]'::JSONB,
    13.0830, 80.2705, 'Chennai-Central',
    'APPROVED',
    NOW()-INTERVAL '30m';


INSERT INTO payouts (
    worker_id, policy_id, trigger_type, trigger_pct,
    hourly_rate, hours_lost, amount,
    risk_score, risk_level, income_drop_pct, income_severity,
    fraud_score, enhanced_fraud_score, fraud_level, fraud_rules_triggered,
    gps_lat, gps_lng, zone_at_claim,
    payout_status, triggered_at, resolved_at
)
SELECT
    'W002',
    (SELECT policy_id FROM policies WHERE worker_id='W002' AND status='ACTIVE'),
    'Heavy Rainfall', 0.8000,
    233.00, 2.50, 480.00,
    7.8, 'CRITICAL', 72.30, 'SEVERE',
    0.0620, 0.0620, 'LOW', '[]'::JSONB,
    13.0345, 80.2442, 'Chennai-South',
    'PAID',
    NOW()-INTERVAL '1 day 2h',
    NOW()-INTERVAL '1 day 2h'+INTERVAL '8 minutes';


INSERT INTO payments (
    payout_id, worker_id, amount, upi_id, payment_ref,
    gateway, simulation_mode, status, initiated_at, completed_at
)
SELECT
    currval('payouts_payout_id_seq'), 'W002', 480.00, 'anand@upi',
    'rzp_sim_'||currval('payouts_payout_id_seq')||'_'||EXTRACT(EPOCH FROM NOW())::BIGINT,
    'RAZORPAY', TRUE, 'SUCCESS',
    NOW()-INTERVAL '1 day 2h'+INTERVAL '1 minute',
    NOW()-INTERVAL '1 day 2h'+INTERVAL '8 minutes';


INSERT INTO payouts (
    worker_id, policy_id, trigger_type, trigger_pct,
    hourly_rate, hours_lost, amount,
    risk_score, risk_level, income_drop_pct, income_severity,
    fraud_score, enhanced_fraud_score, fraud_level, fraud_rules_triggered,
    gps_lat, gps_lng, zone_at_claim, payout_status, triggered_at
)
SELECT
    'W004',
    (SELECT policy_id FROM policies WHERE worker_id='W004' AND status='ACTIVE'),
    'Heavy Rainfall', 0.8000,
    150.00, 5.00, 400.00,
    8.1, 'CRITICAL', 68.50, 'SEVERE',
    0.1800, 0.4800, 'MODERATE',
    '["GPS_STATIC_DURING_DISRUPTION","NO_ORDERS_BEFORE_DISRUPTION"]'::JSONB,
    13.0678, 80.2356, 'Chennai-East',
    'HELD',
    NOW()-INTERVAL '3h';


INSERT INTO payouts (
    worker_id, policy_id, trigger_type, trigger_pct,
    hourly_rate, hours_lost, amount,
    risk_score, risk_level, income_drop_pct, income_severity,
    fraud_score, enhanced_fraud_score, fraud_level, fraud_rules_triggered,
    gps_lat, gps_lng, zone_at_claim, payout_status, triggered_at
)
SELECT
    'W003',
    (SELECT policy_id FROM policies WHERE worker_id='W003' AND status='ACTIVE'),
    'Base Coverage', 0.1000,
    255.00, 3.80, 0.00,
    6.2, 'HIGH', 18.50, 'MILD',
    0.0450, 0.0450, 'LOW', '[]'::JSONB,
    13.1100, 80.2970, 'Chennai-North',
    'DENIED',
    NOW()-INTERVAL '5h';


INSERT INTO worker_latest_analysis (
    worker_id, risk_score, risk_level, income_drop_pct, income_severity,
    trigger_type, hours_online, hours_lost, earnings_today,
    fraud_score, enhanced_fraud_score, fraud_level, fraud_rules_triggered,
    payout_triggered, analysis_payout_status, last_analysis_at
) VALUES
('W001', 7.4,'CRITICAL', 62.10,'SEVERE',  'Heavy Rainfall',   6.5, 2.0,  965.00,
 0.0410, 0.0410,'LOW','[]'::JSONB, TRUE,  'APPROVED', NOW()-INTERVAL '30m'),
('W002', 7.8,'CRITICAL', 72.30,'SEVERE',  'Heavy Rainfall',   5.0, 2.5,  480.00,
 0.0620, 0.0620,'LOW','[]'::JSONB, TRUE,  'PAID',     NOW()-INTERVAL '1 day 2h'),
('W003', 6.2,'HIGH',     18.50,'MILD',    'Base Coverage',    4.2, 2.8, 1215.00,
 0.0450, 0.0450,'LOW','[]'::JSONB, FALSE, 'DENIED',   NOW()-INTERVAL '5h'),
('W004', 8.1,'CRITICAL', 68.50,'SEVERE',  'Heavy Rainfall',   2.8, 2.2,  480.00,
 0.1800, 0.4800,'MODERATE',
 '["GPS_STATIC_DURING_DISRUPTION","NO_ORDERS_BEFORE_DISRUPTION"]'::JSONB,
 TRUE,  'HELD',     NOW()-INTERVAL '3h'),
('W005', 5.1,'HIGH',     32.40,'MODERATE','Heavy Rainfall',   3.8, 2.2,  780.00,
 0.0320, 0.0320,'LOW','[]'::JSONB, FALSE, NULL,       NOW()-INTERVAL '2h')
ON CONFLICT (worker_id) DO UPDATE SET
    risk_score = EXCLUDED.risk_score,
    risk_level = EXCLUDED.risk_level,
    income_drop_pct = EXCLUDED.income_drop_pct,
    income_severity = EXCLUDED.income_severity,
    trigger_type = EXCLUDED.trigger_type,
    hours_online = EXCLUDED.hours_online,
    hours_lost = EXCLUDED.hours_lost,
    earnings_today = EXCLUDED.earnings_today,
    fraud_score = EXCLUDED.fraud_score,
    enhanced_fraud_score = EXCLUDED.enhanced_fraud_score,
    fraud_level = EXCLUDED.fraud_level,
    fraud_rules_triggered = EXCLUDED.fraud_rules_triggered,
    payout_triggered = EXCLUDED.payout_triggered,
    analysis_payout_status = EXCLUDED.analysis_payout_status,
    last_analysis_at = EXCLUDED.last_analysis_at,
    updated_at = NOW();


INSERT INTO payment_trigger_notifications
    (worker_id, notification_type, title, body, amount, upi_id, delivery_status, sent_at)
VALUES
('W002','PAYOUT_PAID',
 '₹480 sent to your UPI!',
 'Your claim for Heavy Rainfall disruption has been processed. ₹480 sent to anand@upi.',
 480.00,'anand@upi','READ', NOW()-INTERVAL '1 day 2h'+INTERVAL '8 minutes'),
('W004','PAYOUT_HELD',
 'Claim under review',
 'Your claim is being reviewed by our team. We will update you within 24 hours.',
 NULL,NULL,'SENT', NOW()-INTERVAL '3h'+INTERVAL '2 minutes'),
('W003','PAYOUT_DENIED',
 'Not eligible this time',
 'Your claim did not meet the income drop threshold for this disruption event.',
 NULL,NULL,'SENT', NOW()-INTERVAL '5h'+INTERVAL '1 minute');


INSERT INTO audit_log
    (event_type, entity_type, entity_id, worker_id, action_by, severity, message, details)
VALUES
('AUTO_TRIGGER_RUN',NULL,NULL,NULL,'SYSTEM','INFO',
 'Scheduler cycle - 5 workers evaluated, 1 approved, 1 denied, 1 held',
 '{"workers_evaluated":5,"approved":1,"denied":1,"held":1,"skipped_already_paid":1,"cycle_duration_ms":3240}'::JSONB),

('PAYOUT_APPROVED','PAYOUT',NULL,'W001','SYSTEM','INFO',
 'Payout INR 480 approved - Heavy Rainfall, risk 7.4, income drop 62.1%',
 '{"amount":480,"trigger":"Heavy Rainfall","trigger_pct":0.8,"risk_score":7.4,"income_drop":62.1,"fraud_score":0.041}'::JSONB),

('PAYOUT_PAID','PAYMENT',NULL,'W002','SYSTEM','INFO',
 'Razorpay simulation SUCCESS for W002 - INR 480',
 '{"simulation_mode":true,"amount":480,"upi_id":"anand@upi","duration_seconds":8}'::JSONB),

('FRAUD_DETECTED','PAYOUT',NULL,'W004','ML_MODEL','WARNING',
 'Fraud rules triggered for W004 - GPS static, no prior orders',
 '{"base_fraud":0.18,"enhanced_fraud":0.48,"rules":["GPS_STATIC_DURING_DISRUPTION","NO_ORDERS_BEFORE_DISRUPTION"],"movement_km":3.2,"orders_before_disruption":0}'::JSONB),

('PAYOUT_DENIED','PAYOUT',NULL,'W003','SYSTEM','INFO',
 'Denied W003 - Gate 2 not met (income drop 18.5% < 25% threshold)',
 '{"risk_score":6.2,"income_drop":18.5,"income_severity":"MILD","gate1":true,"gate2":false}'::JSONB);
