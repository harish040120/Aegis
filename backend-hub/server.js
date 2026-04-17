const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3015;

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    throw new Error('Missing Supabase credentials. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.');
}

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

const supabaseAdmin = supabaseServiceKey
    ? createClient(supabaseUrl, supabaseServiceKey, { auth: { persistSession: false } })
    : supabase;

const WAQI_API_KEY = process.env.WAQI_API_KEY || "";
const WEATHER_API_KEY = process.env.WEATHER_API_KEY || "";

app.use(cors({ origin: ['http://localhost:2000', 'http://localhost:3000'], credentials: true }));
app.use(express.json());

// --- Simulation State ---
let activeWorkerId = "W001";
let activeScenario = "normal";

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
    console.log('[SCENARIO] Applying:', scenario_key, 'to worker:', worker_id);
    if (worker_id) activeWorkerId = worker_id;
    const s = SCENARIOS[scenario_key];
    if (s) {
        activeScenario = scenario_key;
        console.log('[SCENARIO] Active scenario set to:', activeScenario);
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

    console.log(`[REQUEST] /api/risk-data called with worker_id=${wId}, activeScenario=${activeScenario}`);

    const [realWeather, baselineRes] = await Promise.all([
        (async () => {
            try {
                const wRes = await axios.get(`https://api.openweathermap.org/data/2.5/weather?lat=${uLat}&lon=${uLon}&appid=${WEATHER_API_KEY}&units=metric`);
                const qRes = await axios.get(`https://api.waqi.info/feed/geo:${uLat};${uLon}/?token=${WAQI_API_KEY}`);
                return { w: wRes.data, q: qRes.data.data };
            } catch (e) { return null; }
        })(),
        supabaseAdmin
            .from('workers')
            .select('avg_earnings_12w, avg_orders_7d, target_daily_hours, zone')
            .eq('worker_id', wId)
            .maybeSingle()
    ]);

    if (baselineRes?.error) {
        console.warn(`[WARN] Supabase baseline fetch failed for ${wId}, using defaults: ${baselineRes.error.message}`);
    }
    const b = baselineRes?.data || { avg_earnings_12w: 1800, avg_orders_7d: 14, target_daily_hours: 8.0, zone: "Chennai-Central" };
    const weather = realWeather ? {
        temp: realWeather.w.main.temp,
        feels_like: realWeather.w.main.feels_like,
        rain_1h: customParams.rain_override.value > 0 ? customParams.rain_override.value : (realWeather.w.rain ? (realWeather.w.rain['1h'] || 0) : 0),
        pm25: customParams.aqi_override.value > 0 ? customParams.aqi_override.value : (realWeather.q.iaqi?.pm25?.v || 45),
        pm10: realWeather.q.iaqi?.pm10?.v || 30,
        place_name: realWeather.w.name
    } : { temp: 32, feels_like: 32, rain_1h: customParams.rain_override.value, pm25: customParams.aqi_override.value || 45, pm10: 30, place_name: "Fallback" };

    const calculateDrop = (curr, base) => Math.min(100, Math.max(0, parseFloat(((base - curr) / base * 100).toFixed(2))));

    console.log('[RISK-DATA] activeScenario:', activeScenario);
    console.log('[RISK-DATA] customParams:', JSON.stringify(customParams));

    res.json({
        "worker_id": wId,
        "scenario": activeScenario,
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
        const { data, error } = await supabaseAdmin
            .from('workers')
            .select('worker_id, name, zone')
            .order('worker_id', { ascending: true })
            .limit(50);
        if (error) throw error;
        res.json(data || []);
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
        const policyRes = await supabaseAdmin
            .from('policies')
            .select('policy_id')
            .eq('worker_id', wId)
            .eq('status', 'ACTIVE')
            .order('coverage_end', { ascending: false })
            .limit(1);
        if (policyRes.error) throw policyRes.error;
        const policyId = policyRes.data?.[0]?.policy_id || null;
        const payoutAmount = amount || 480;
        const baseFraudScore = typeof fraud_score === 'number' ? fraud_score : 0.05;
        const { data: payoutRow, error: payoutError } = await supabaseAdmin
            .from('payouts')
            .insert([
                {
                    worker_id: wId,
                    policy_id: policyId,
                    trigger_type: alert_type || 'Manual Trigger',
                    trigger_pct: trigger_pct || 0.80,
                    amount: payoutAmount,
                    risk_level: risk_level || 'HIGH',
                    fraud_score: baseFraudScore,
                    fraud_level: baseFraudScore > 0.3 ? 'MODERATE' : 'LOW',
                    payout_status: 'APPROVED',
                    gps_lat: lat || null,
                    gps_lng: lon || null
                }
            ])
            .select('payout_id')
            .single();
        if (payoutError) throw payoutError;

        const payoutId = payoutRow?.payout_id;
        if (payoutId) {
            await supabaseAdmin.from('audit_log').insert([
                {
                    event_type: 'PAYOUT_APPROVED',
                    entity_type: 'PAYOUT',
                    entity_id: String(payoutId),
                    worker_id: wId,
                    action_by: 'SYSTEM',
                    severity: 'INFO',
                    message: `Auto payout ₹${payoutAmount} for ${alert_type || 'Manual Trigger'}`
                }
            ]);
        }

        res.json({ success: true, payout_id: payoutId, amount: payoutAmount });
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
        const start = new Date(date);
        const end = new Date(date);
        end.setDate(end.getDate() + 1);

        const { count, error } = await supabaseAdmin
            .from('payouts')
            .select('payout_id', { count: 'exact', head: true })
            .eq('worker_id', workerId)
            .in('payout_status', ['APPROVED', 'PAID'])
            .gte('triggered_at', start.toISOString())
            .lt('triggered_at', end.toISOString());

        if (error) throw error;
        res.json({ exists: (count || 0) > 0 });
    } catch (err) {
        res.status(500).json({ exists: false, error: err.message });
    }
});

app.listen(PORT, () => console.log(`🚀 Scenario Hub Port ${PORT}`));
