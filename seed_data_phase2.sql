-- seed_sessions.sql
INSERT INTO worker_sessions (worker_id, session_date, first_online, last_ping, hours_online, movement_km, deliveries_done, lat_last, lon_last, zone)
VALUES
('W001', CURRENT_DATE, NOW() - INTERVAL '7 hours', NOW() - INTERVAL '30 minutes', 6.5, 42.3, 9, 13.0830, 80.2705, 'Chennai-Central'),
('W002', CURRENT_DATE, NOW() - INTERVAL '6 hours', NOW() - INTERVAL '1 hour',     5.0, 28.1, 3, 13.0360, 80.2455, 'Chennai-South'),
('W003', CURRENT_DATE, NOW() - INTERVAL '5 hours', NOW() - INTERVAL '45 minutes', 4.2, 31.5, 3, 13.1100, 80.2970, 'Chennai-North'),
('W004', CURRENT_DATE, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '20 minutes', 2.8,  3.2, 1, 13.0678, 80.2356, 'Chennai-East'),
('W005', CURRENT_DATE, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '1 hour',     3.8, 22.6, 2, 11.0180, 76.9570, 'Coimbatore-Central')
ON CONFLICT (worker_id, session_date) DO UPDATE SET
    hours_online = EXCLUDED.hours_online,
    movement_km = EXCLUDED.movement_km,
    deliveries_done = EXCLUDED.deliveries_done;

-- seed_orders_realistic.sql
INSERT INTO orders (worker_id, lat, lon, earnings, timestamp) VALUES
('W001', 13.0827, 80.2707, 185.00, NOW() - INTERVAL '7 hours'),
('W001', 13.0850, 80.2720, 210.00, NOW() - INTERVAL '6 hours'),
('W001', 13.0800, 80.2690, 175.00, NOW() - INTERVAL '5 hours'),
('W001', 13.0860, 80.2730, 195.00, NOW() - INTERVAL '4 hours'),
('W001', 13.0820, 80.2700, 200.00, NOW() - INTERVAL '3 hours'),
('W001', 13.0840, 80.2710, 185.00, NOW() - INTERVAL '2 hours 30 minutes'),
('W001', 13.0810, 80.2695, 170.00, NOW() - INTERVAL '2 hours'),
('W001', 13.0870, 80.2740, 155.00, NOW() - INTERVAL '1 hour 30 minutes'),
('W001', 13.0830, 80.2705, 165.00, NOW() - INTERVAL '1 hour');

-- seed_policies.sql
INSERT INTO policies (worker_id, plan_name, weekly_premium, coverage_start, coverage_end, status, payment_ref)
VALUES
('W001', 'STANDARD', 34.00, NOW() - INTERVAL '3 days', NOW() + INTERVAL '4 days', 'ACTIVE', 'pay_test_001'),
('W002', 'STANDARD', 31.00, NOW() - INTERVAL '2 days', NOW() + INTERVAL '5 days', 'ACTIVE', 'pay_test_002'),
('W003', 'STANDARD', 32.00, NOW() - INTERVAL '1 day',  NOW() + INTERVAL '6 days', 'ACTIVE', 'pay_test_003'),
('W004', 'BASIC',    18.00, NOW() - INTERVAL '4 days', NOW() + INTERVAL '3 days', 'ACTIVE', 'pay_test_004'),
('W005', 'STANDARD', 25.00, NOW() - INTERVAL '5 days', NOW() + INTERVAL '2 days', 'ACTIVE', 'pay_test_005');
