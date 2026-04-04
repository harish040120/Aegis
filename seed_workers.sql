-- seed_workers.sql
INSERT INTO workers (worker_id, name, phone, upi_id, kyc_status, platform, zone, avg_orders_7d, avg_earnings_12w, avg_hours_baseline, target_daily_hours)
VALUES
('W001', 'Shiva Kumar',     '9876543210', 'shiva@upi',     'VERIFIED', 'ZOMATO',  'Chennai-Central', 14, 1800.0, 8.0, 8.0),
('W002', 'Anand Rajan',     '9876543211', 'anand@upi',     'VERIFIED', 'SWIGGY',  'Chennai-South',   13, 1750.0, 7.5, 7.5),
('W003', 'Karthik Selvan',  '9876543212', 'karthik@upi',   'VERIFIED', 'ZOMATO',  'Chennai-North',   14, 1780.0, 7.0, 7.0),
('W004', 'Murugan Pillai',  '9876543213', 'murugan@upi',   'VERIFIED', 'BOTH',    'Chennai-East',    9,  1200.0, 5.0, 5.0),
('W005', 'Priya Lakshmi',   '9876543214', 'priya@upi',     'VERIFIED', 'SWIGGY',  'Coimbatore-Central', 10, 1500.0, 6.0, 6.0)
ON CONFLICT (worker_id) DO UPDATE SET
    name = EXCLUDED.name,
    phone = EXCLUDED.phone,
    upi_id = EXCLUDED.upi_id,
    kyc_status = EXCLUDED.kyc_status,
    zone = EXCLUDED.zone,
    avg_orders_7d = EXCLUDED.avg_orders_7d,
    avg_earnings_12w = EXCLUDED.avg_earnings_12w,
    avg_hours_baseline = EXCLUDED.avg_hours_baseline,
    target_daily_hours = EXCLUDED.target_daily_hours;
