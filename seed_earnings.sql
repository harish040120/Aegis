INSERT INTO orders (worker_id, lat, lon, earnings, timestamp) VALUES 
('W001', 13.0827, 80.2707, 120.50, NOW() - INTERVAL '2 hours'),
('W001', 13.0900, 80.2800, 95.00, NOW() - INTERVAL '4 hours'),
('W001', 13.0700, 80.2600, 150.00, NOW() - INTERVAL '6 hours'),
('W001', 13.1000, 80.2900, 80.00, NOW() - INTERVAL '1 day'),
('W001', 13.0500, 80.2400, 210.00, NOW() - INTERVAL '2 days');
