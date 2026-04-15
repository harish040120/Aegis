const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3015;

const pool = new Pool({
    user: process.env.DB_USER || 'aegis_admin',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'aegis_intelligence',
    password: process.env.DB_PASSWORD || 'aegis_secure_pass',
    port: parseInt(process.env.DB_PORT) || 2003,
});

const WAQI_API_KEY = process.env.WAQI_API_KEY || "";
const WEATHER_API_KEY = process.env.WEATHER_API_KEY || "";

app.use(cors({ origin: ['http://localhost:2000', 'http://localhost:3000'], credentials: true }));
app.use(express.json());

// --- Simulation State ---
let activeWorkerId = "W001"; 

const SCENARIOS = {
    normal:        { orders_last_hour: 205, earnings_today: 1800, hours_worked_today: 7.5, traffic_index: 45, rain_override: 0, aqi_override: 45 },
    light_rain:    { orders_last_hour: 175, earnings_today: 1540, hours_worked_today: 5.5, traffic_index: 50, rain_override: 15, aqi_override: 30 },
    heavy_rain:    { orders_last_hour: 118, earnings_today: 1065, hours_worked_today: 4.0, traffic_index: 70, rain_override: 52, aqi_override: 20 },
    severe_flood:  { orders_last_hour: 85,  earnings_today: 750,  hours_worked_today: 1.5, traffic_index: 85, rain_override: 80, aqi_override: 15 },
    hazardous_aqi: { orders_last_hour: 92,  earnings_today: 830,  hours_worked_today: 3.5, traffic_index: 60, rain_override: 0, aqi_override: 185 },
    gps_fraud:     { orders_last_hour: 85,  earnings_today: 750,  hours_worked_today: 8.0, traffic_index: 45, rain_override: 0, aqi_override: 45 },
};

let customParams = {
    orders_last_hour: { value: 180, min: 0, max: 500 },
    earnings_today: { value: 1600, min: 0, max: 5000 },
    hours_worked_today: { value: 7.5, min: 0, max: 24 },
    traffic_index: { value: 45, min: 0, max: 100 },
    rain_override: { value: 0, min: 0, max: 100 },
    aqi_override: { value: 0, min: 0, max: 500 }
};

// --- API Routes ---
app.post('/api/scenario', (req, res) => {
    const { scenario_key, worker_id } = req.body;
    if (worker_id) activeWorkerId = worker_id;
    const s = SCENARIOS[scenario_key];
    if (s) {
        Object.entries(s).forEach(([k, v]) => { if (customParams[k]) customParams[k].value = v; });
    }
    res.json({ applied: scenario_key, worker_id: activeWorkerId, params: customParams });
});

app.get('/api/test-alerts', (req, res) => {
    const { worker_id } = req.query;
    const wId = worker_id || activeWorkerId;
    
    const alerts = [];
    const earningsBaseline = 1800;
    const currentEarnings = customParams.earnings_today.value;
    const earningsDrop = ((earningsBaseline - currentEarnings) / earningsBaseline) * 100;
    
    if (customParams.rain_override.value > 45) {
        alerts.push({
            type: 'heavy_rainfall',
            typeLabel: 'Heavy Rainfall Alert',
            severity: 'high',
            metric: customParams.rain_override.value,
            threshold: 45,
            trigger_pct: 0.80,
            payout_multiplier: 0.80,
            active: true
        });
    }
    
    if (customParams.aqi_override.value > 120) {
        alerts.push({
            type: 'hazardous_aqi',
            typeLabel: 'Hazardous AQI Alert',
            severity: 'high',
            metric: customParams.aqi_override.value,
            threshold: 120,
            trigger_pct: 0.80,
            payout_multiplier: 0.80,
            active: true
        });
    }
    
    if (earningsDrop > 45) {
        alerts.push({
            type: 'severe_income_loss',
            typeLabel: 'Severe Income Loss',
            severity: 'critical',
            metric: earningsDrop,
            threshold: 45,
            trigger_pct: 1.00,
            payout_multiplier: 1.00,
            active: true
        });
    }
    
    if (customParams.orders_last_hour.value < 100 && customParams.hours_worked_today.value > 7) {
        alerts.push({
            type: 'gps_fraud',
            typeLabel: 'GPS Fraud Detected',
            severity: 'critical',
            metric: 0.85,
            threshold: 0.7,
            trigger_pct: 0.0,
            payout_multiplier: 0.0,
            active: true,
            is_fraud: true
        });
    }
    
    if (alerts.length === 0) {
        alerts.push({
            type: 'normal',
            typeLabel: 'Normal Conditions',
            severity: 'low',
            metric: 0,
            threshold: 0,
            trigger_pct: 0.10,
            payout_multiplier: 0.10,
            active: false
        });
    }
    
    res.json({
        worker_id: wId,
        alerts: alerts,
        params: customParams,
        has_alerts: alerts.filter(a => a.active && !a.is_fraud).length > 0
    });
});

app.get('/api/risk-data', async (req, res) => {
    const { lat, lon, worker_id } = req.query;
    const uLat = parseFloat(lat) || 13.0827;
    const uLon = parseFloat(lon) || 80.2707;
    const wId = worker_id || activeWorkerId;

    const [realWeather, baselines] = await Promise.all([
        (async () => {
            try {
                const wRes = await axios.get(`https://api.openweathermap.org/data/2.5/weather?lat=${uLat}&lon=${uLon}&appid=${WEATHER_API_KEY}&units=metric`);
                const qRes = await axios.get(`https://api.waqi.info/feed/geo:${uLat};${uLon}/?token=${WAQI_API_KEY}`);
                return { w: wRes.data, q: qRes.data.data };
            } catch (e) { return null; }
        })(),
        pool.query('SELECT avg_earnings_12w, avg_orders_7d, target_daily_hours, zone FROM workers WHERE worker_id = $1', [wId])
            .catch(() => {
                console.warn(`[WARN] DB baseline fetch failed for ${wId}, using defaults`);
                return { rows: [] };
            })
    ]);

    const b = baselines.rows[0] || { avg_earnings_12w: 1800, avg_orders_7d: 14, target_daily_hours: 8.0, zone: "Chennai-Central" };
    const weather = realWeather ? {
        temp: realWeather.w.main.temp,
        feels_like: realWeather.w.main.feels_like,
        rain_1h: customParams.rain_override.value > 0 ? customParams.rain_override.value : (realWeather.w.rain ? (realWeather.w.rain['1h'] || 0) : 0),
        pm25: customParams.aqi_override.value > 0 ? customParams.aqi_override.value : (realWeather.q.iaqi?.pm25?.v || 45),
        pm10: realWeather.q.iaqi?.pm10?.v || 30,
        place_name: realWeather.w.name
    } : { temp: 32, feels_like: 32, rain_1h: customParams.rain_override.value, pm25: customParams.aqi_override.value || 45, pm10: 30, place_name: "Fallback" };

    const calculateDrop = (curr, base) => Math.min(100, Math.max(0, parseFloat(((base - curr) / base * 100).toFixed(2))));

    res.json({
        "worker_id": wId,
        "location": { "lat": uLat, "lon": uLon, "place_name": weather.place_name, "zone": b.zone },
        "external_disruption": {
            "weather": { 
                "temp": weather.temp, 
                "feels_like": weather.feels_like,
                "rain_1h": weather.rain_1h 
            },
            "air_quality": { 
                "pm25": weather.pm25,
                "pm10": weather.pm10
            },
            "traffic_index": customParams.traffic_index.value
        },
        "business_impact": {
            "metrics": {
                "order_drop_pct": calculateDrop(customParams.orders_last_hour.value, b.avg_orders_7d / 8.0),
                "earnings_drop_pct": calculateDrop(customParams.earnings_today.value, b.avg_earnings_12w),
                "activity_drop_pct": calculateDrop(customParams.hours_worked_today.value, b.target_daily_hours)
            },
            "current": { "hours_worked_today": customParams.hours_worked_today.value }
        }
    });
});

app.get('/api/params', (req, res) => res.json(customParams));
app.post('/api/params', (req, res) => {
    const { name, value } = req.body;
    if (customParams[name]) customParams[name].value = parseFloat(value);
    res.json(customParams);
});

app.get('/api/workers', async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT worker_id, name, zone FROM workers ORDER BY worker_id LIMIT 50"
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/current-alerts', (req, res) => {
    const { worker_id } = req.query;
    const wId = worker_id || activeWorkerId;
    
    const alerts = [];
    const earningsBaseline = 1800;
    const currentEarnings = customParams.earnings_today.value;
    const earningsDrop = ((earningsBaseline - currentEarnings) / earningsBaseline) * 100;
    
    if (customParams.rain_override.value > 45) {
        alerts.push({
            type: 'heavy_rainfall',
            typeLabel: 'Heavy Rainfall Alert',
            severity: 'high',
            metric: customParams.rain_override.value,
            threshold: 45,
            trigger_pct: 0.80,
            payout_multiplier: 0.80,
            active: true
        });
    }
    
    if (customParams.aqi_override.value > 120) {
        alerts.push({
            type: 'hazardous_aqi',
            typeLabel: 'Hazardous AQI Alert',
            severity: 'high',
            metric: customParams.aqi_override.value,
            threshold: 120,
            trigger_pct: 0.80,
            payout_multiplier: 0.80,
            active: true
        });
    }
    
    if (earningsDrop > 45) {
        alerts.push({
            type: 'severe_income_loss',
            typeLabel: 'Severe Income Loss',
            severity: 'critical',
            metric: earningsDrop,
            threshold: 45,
            trigger_pct: 1.00,
            payout_multiplier: 1.00,
            active: true
        });
    }
    
    if (customParams.orders_last_hour.value < 100 && customParams.hours_worked_today.value > 7) {
        alerts.push({
            type: 'gps_fraud',
            typeLabel: 'GPS Fraud Detected',
            severity: 'critical',
            metric: 0.85,
            threshold: 0.7,
            trigger_pct: 0.0,
            payout_multiplier: 0.0,
            active: true,
            is_fraud: true
        });
    }
    
    res.json({
        worker_id: wId,
        alerts: alerts,
        params: customParams,
        has_alerts: alerts.filter(a => a.active && !a.is_fraud).length > 0
    });
});

app.post('/api/trigger-payout', async (req, res) => {
    const { worker_id, alert_type, lat, lon, amount, risk_level, fraud_score, trigger_pct } = req.body;
    const wId = worker_id || activeWorkerId;
    
    try {
        const policyRes = await pool.query(
            `SELECT policy_id FROM policies WHERE worker_id=$1 AND status='ACTIVE' LIMIT 1`,
            [wId]
        );
        const policyId = policyRes.rows[0]?.policy_id || null;
        const payoutAmount = amount || 480;
        const result = await pool.query(
            `INSERT INTO payouts 
             (worker_id, policy_id, trigger_type, trigger_pct, amount, risk_level, 
              fraud_score, fraud_level, payout_status, gps_lat, gps_lng)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'APPROVED',$9,$10)
             RETURNING payout_id`,
            [wId, policyId, alert_type || 'Manual Trigger', 
             trigger_pct || 0.80, payoutAmount, 
             risk_level || 'HIGH', fraud_score || 0.05,
             fraud_score > 0.3 ? 'MODERATE' : 'LOW',
             lat || null, lon || null]
        );
        await pool.query(
            `INSERT INTO audit_log (event_type, entity_type, entity_id, worker_id, action_by, severity, message)
             VALUES ('PAYOUT_APPROVED','PAYOUT',$1,$2,'SYSTEM','INFO',$3)`,
            [result.rows[0].payout_id.toString(), wId, 
             `Auto payout ₹${payoutAmount} for ${alert_type}`]
        );
        res.json({ success: true, payout_id: result.rows[0].payout_id, amount: payoutAmount });
    } catch (err) {
        res.status(500).json({ 
            error: err.message,
            message: 'Failed to trigger payout'
        });
    }
});

app.get('/api/payout-exists/:workerId/:date', async (req, res) => {
    const { workerId, date } = req.params;
    try {
        const result = await pool.query(
            `SELECT COUNT(*) as cnt FROM payouts 
             WHERE worker_id = $1 
             AND DATE(triggered_at) = $2 
             AND payout_status IN ('APPROVED','PAID')`,
            [workerId, date]
        );
        res.json({ exists: parseInt(result.rows[0].cnt) > 0 });
    } catch (err) {
        res.status(500).json({ exists: false, error: err.message });
    }
});

app.listen(PORT, () => console.log(`🚀 Scenario Hub Port ${PORT}`));
