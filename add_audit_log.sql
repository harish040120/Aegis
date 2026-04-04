CREATE TABLE IF NOT EXISTS audit_log (
    log_id       SERIAL PRIMARY KEY,
    action       VARCHAR(100) NOT NULL,
    target_type  VARCHAR(50),
    target_id    VARCHAR(50),
    old_value    TEXT,
    new_value    TEXT,
    performed_by VARCHAR(50) DEFAULT 'admin',
    created_at   TIMESTAMP DEFAULT NOW()
);
