"""
GigShield Model Backend v6.0 — Parametric Subscription Hub
- Enforces: Active Policy Gate (Analyze requires active coverage).
- Implements: /api/v1/subscribe (7-day rolling coverage).
- Restored: All Admin and Mobile endpoints.
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pickle
import numpy as np
import pandas as pd
import os
import httpx
import asyncio
import asyncpg
import google.generativeai as genai
import json
from datetime import datetime, timedelta
from typing import Optional, List

app = FastAPI(title="Aegis Subscription Hub", version="6.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Configuration ────────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(__file__)

# Load .env file
from dotenv import load_dotenv
load_dotenv(os.path.join(BASE_DIR, ".env"))

DATA_HUB_URL = os.getenv("DATA_HUB_URL", "http://localhost:3015/api/risk-data")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://aegis_admin:aegis_secure_pass@localhost:2003/aegis_intelligence")
GOOGLE_KEY = os.environ.get("GOOGLE_API_KEY", "")

if GOOGLE_KEY:
    genai.configure(api_key=GOOGLE_KEY)

async def get_db_conn():
    return await asyncpg.connect(DATABASE_URL)

# ─── Schemas ──────────────────────────────────────────────────────────────────

class SubscribeRequest(BaseModel):
    worker_id: str
    plan_name: str        # BASIC / STANDARD / PREMIUM
    weekly_premium: float
    payment_ref: str = "demo_payment"

class RegisterRequest(BaseModel):
    name: str; phone: str; platform: str; city: str; zone: str; upi_id: str

class KycRequest(BaseModel):
    worker_id: str; aadhaar_number: str

class AnalyzeRequest(BaseModel):
    lat: float; lon: float; worker_id: str = "W001"
    hours_worked_today: Optional[float] = None
    movement_distance_km: Optional[float] = None
    deliveries_completed_today: Optional[int] = None

# ─── Load ML Models ───────────────────────────────────────────────────────────
def _load(filename):
    path = os.path.join(BASE_DIR, filename)
    if not os.path.exists(path): return None
    with open(path, "rb") as f: return pickle.load(f)

try:
    risk_pkg = _load("risk_model.pkl")
    RISK_MODEL = risk_pkg["model"]; RISK_LE = risk_pkg["label_encoder"]; RISK_FEATURES = risk_pkg["features"]; RISK_REGRESSOR = _load("risk_regressor.pkl")
    income_pkg = _load("income_model.pkl")
    INCOME_REG = income_pkg["regressor"]; INCOME_CLF = income_pkg["classifier"]; INCOME_LE = income_pkg["label_encoder"]; INCOME_FEATURES = income_pkg["features"]
    fraud_pkg = _load("fraud_model.pkl")
    FRAUD_REG = fraud_pkg["regressor"]; FRAUD_CLF = fraud_pkg["classifier"]; FRAUD_LE = fraud_pkg["label_encoder"]; FRAUD_FEATURES = fraud_pkg["features"]
    print("✅ Aegis v6.0: Intelligence Hub Active")
except Exception as e:
    print(f"⚠️ Load warning: {e}")

# ─── DB Fetch Helpers ─────────────────────────────────────────────────────────

async def fetch_db_activity(worker_id: str) -> dict:
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow("SELECT COALESCE(SUM(earnings), 0) as earnings, COUNT(*) as orders FROM orders WHERE worker_id = $1 AND timestamp::date = CURRENT_DATE", worker_id)
        return dict(row)
    finally: await conn.close()

async def fetch_worker_profile(worker_id: str) -> dict | None:
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow("SELECT * FROM workers WHERE worker_id = $1", worker_id)
        return dict(row) if row else None
    finally: await conn.close()

async def get_loyalty_factor(worker_id: str) -> float:
    conn = await get_db_conn()
    try:
        count = await conn.fetchval("SELECT COUNT(*) FROM payouts WHERE worker_id = $1 AND triggered_at > NOW() - INTERVAL '84 days' AND payout_status = 'APPROVED'", worker_id)
        return 0.85 if count == 0 else 1.0
    finally: await conn.close()

async def fetch_session_data(worker_id: str) -> dict:
    """Fetch today's session data for fraud detection"""
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            """SELECT hours_online, movement_km, deliveries_done 
               FROM worker_sessions 
               WHERE worker_id = $1 AND session_date = CURRENT_DATE""", 
            worker_id
        )
        if row:
            return dict(row)
        else:
            # Return defaults if no session data exists
            return {"hours_online": 0.0, "movement_km": 0.0, "deliveries_done": 0}
    finally: 
        await conn.close()

# ─── AUTH & ONBOARDING ───────────────────────────────────────────────────────

@app.get("/api/v1/worker-by-phone")
async def get_worker_by_phone(phone: str):
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            """SELECT w.worker_id, w.name, w.kyc_status, w.zone, w.platform,
                      w.avg_earnings_12w, w.target_daily_hours, w.phone, w.upi_id,
                      EXISTS(SELECT 1 FROM policies p WHERE p.worker_id = w.worker_id AND p.status = 'ACTIVE' AND p.coverage_end > NOW()) as has_active_policy
               FROM workers w WHERE w.phone = $1""", phone)
        if not row: raise HTTPException(status_code=404, detail="Worker not found")
        return dict(row)
    finally: await conn.close()

@app.post("/api/v1/register")
async def register_worker(req: RegisterRequest):
    conn = await get_db_conn()
    try:
        worker_id = f"W{int(datetime.now().timestamp()) % 10000:03d}"
        # Set optimal base values for demo: 1800/day salary, 8h target
        await conn.execute(
            """INSERT INTO workers (worker_id, name, phone, platform, zone, city, upi_id, kyc_status, avg_earnings_12w, target_daily_hours, avg_orders_7d)
               VALUES ($1,$2,$3,$4,$5,$6,$7,'PENDING',1800,8.0, 14)""",
            worker_id, req.name, req.phone, req.platform, req.zone, req.city, req.upi_id
        )
        return await fetch_worker_profile(worker_id)
    finally: await conn.close()

@app.post("/api/v1/complete-kyc")
async def complete_kyc(req: KycRequest):
    conn = await get_db_conn()
    try:
        await conn.execute("UPDATE workers SET kyc_status='VERIFIED' WHERE worker_id=$1", req.worker_id)
        return await fetch_worker_profile(req.worker_id)
    finally: await conn.close()

# ─── SUBSCRIPTION LOGIC ───────────────────────────────────────────────────────

@app.post("/api/v1/subscribe")
async def subscribe(req: SubscribeRequest):
    conn = await get_db_conn()
    try:
        # 1. Cancel existing
        await conn.execute("UPDATE policies SET status='EXPIRED' WHERE worker_id=$1 AND status='ACTIVE'", req.worker_id)
        
        # 2. Insert new 7-day policy
        row = await conn.fetchrow(
            """INSERT INTO policies (worker_id, plan_name, weekly_premium, status, 
                                   coverage_start, coverage_end, payment_ref, auto_renew)
               VALUES ($1, $2, $3, 'ACTIVE', NOW(), NOW() + INTERVAL '7 days', $4, TRUE)
               RETURNING policy_id, coverage_start, coverage_end""",
            req.worker_id, req.plan_name, req.weekly_premium, req.payment_ref
        )
        return {
            "status": "ACTIVE",
            "policy_id": row["policy_id"],
            "plan_name": req.plan_name,
            "weekly_premium": req.weekly_premium,
            "coverage_start": row["coverage_start"].isoformat(),
            "coverage_end": row["coverage_end"].isoformat()
        }
    finally: await conn.close()

@app.get("/api/v1/worker/{worker_id}/policy")
async def get_active_policy(worker_id: str):
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            """SELECT policy_id, plan_name, weekly_premium, status, coverage_start, coverage_end, auto_renew
               FROM policies WHERE worker_id=$1 AND status='ACTIVE' AND coverage_end > NOW()
               ORDER BY coverage_end DESC LIMIT 1""", worker_id
        )
        if not row: raise HTTPException(status_code=404, detail="No active policy")
        r = dict(row)
        r["coverage_start"] = r["coverage_start"].isoformat()
        r["coverage_end"] = r["coverage_end"].isoformat()
        return r
    finally: await conn.close()

# ─── MAIN PIPELINE ────────────────────────────────────────────────────────────

@app.post("/api/v1/analyze")
async def analyze(req: AnalyzeRequest):
    # 1. Active Policy Gate
    conn = await get_db_conn()
    try:
        policy = await conn.fetchrow(
            """SELECT policy_id, plan_name, weekly_premium FROM policies 
               WHERE worker_id=$1 AND status='ACTIVE' AND coverage_end > NOW()
               ORDER BY coverage_end DESC LIMIT 1""", req.worker_id)
    finally: await conn.close()

    if not policy:
        return {
            "status": "NO_COVERAGE",
            "worker_id": req.worker_id,
            "message": "No active policy detected. Analysis halted.",
            "payout": {"amount": 0, "trigger": "None"}
        }

    # 2. Sequential Orchestration
    hub_task = httpx.AsyncClient().get(f"{DATA_HUB_URL}?lat={req.lat}&lon={req.lon}&worker_id={req.worker_id}", timeout=15.0)
    hub_res, worker, db_activity, session, loyalty = await asyncio.gather(
        hub_task, fetch_worker_profile(req.worker_id), fetch_db_activity(req.worker_id), fetch_session_data(req.worker_id), get_loyalty_factor(req.worker_id)
    )
    if worker is None: raise HTTPException(status_code=404, detail="Worker not found")
    hub_data = hub_res.json(); h = req.hours_worked_today if req.hours_worked_today is not None else session["hours_online"]; m_km = req.movement_distance_km if req.movement_distance_km is not None else session["movement_km"]; d = req.deliveries_completed_today if req.deliveries_completed_today is not None else int(db_activity["orders"])
    
    # 3. ML Intelligence
    w = hub_data["external_disruption"]["weather"]; aq = hub_data["external_disruption"]["air_quality"]; met = hub_data["business_impact"]["metrics"]
    rf = {"temp_c": w["temp"], "feels_like_c": w["feels_like"], "rainfall_mm": w["rain_1h"], "pm25": aq["pm25"], "pm10": aq["pm10"], "traffic_index": hub_data["external_disruption"]["traffic_index"]}
    rs = round(float(RISK_REGRESSOR.predict(pd.DataFrame([rf])[RISK_FEATURES])[0]), 2); rl = str(RISK_LE.inverse_transform([RISK_MODEL.predict(pd.DataFrame([rf])[RISK_FEATURES])[0]])[0])
    inf = {"earnings_drop_pct": met["earnings_drop_pct"], "order_drop_pct": met["order_drop_pct"], "activity_drop_pct": met["activity_drop_pct"], "orders_last_hour": d, "earnings_today": float(db_activity["earnings"]), "hours_worked_today": h, "avg_orders_7d": worker["avg_orders_7d"], "avg_earnings_12w": worker["avg_earnings_12w"], "avg_hours_baseline": worker["target_daily_hours"]}
    idr = round(float(INCOME_REG.predict(pd.DataFrame([inf])[INCOME_FEATURES])[0]), 2); isev = str(INCOME_LE.inverse_transform([INCOME_CLF.predict(pd.DataFrame([inf])[INCOME_FEATURES])[0]])[0])
    ff = {"activity_drop_pct": idr, "hours_worked_today": h, "earnings_drop_pct": 20.0, "active_hours": h, "deliveries_completed": d, "avg_deliveries": worker["avg_orders_7d"] / 8.0, "movement_distance_km": m_km, "order_drop_pct": 20.0, "orders_last_hour": d}
    fs = round(max(0.0, min(1.0, float(FRAUD_REG.predict(pd.DataFrame([ff])[FRAUD_FEATURES])[0]))), 2); fl = str(FRAUD_LE.inverse_transform([FRAUD_CLF.predict(pd.DataFrame([ff])[FRAUD_FEATURES])[0]])[0])

    # 4. Decision
    rate = worker["avg_earnings_12w"] / worker["target_daily_hours"]
    lost = max(0.0, worker["target_daily_hours"] - h)
    
    # Ensure minimum payout even if worked full day - based on risk level
    min_payout_pct = 0.05  # 5% minimum for any analysis
    
    tp, tn, st = 0.0, "None", "DENIED"
    if fl == "HIGH" or fs > 0.65: 
        st = "BANNED"
    elif fs > 0.3: 
        st = "HELD"
    else:
        cands = []
        if w["rain_1h"] > 45: 
            cands.append((0.80, "Heavy Rainfall"))
        if aq["pm25"] > 120: 
            cands.append((0.80, "Hazardous AQI"))
        if idr > 45: 
            cands.append((1.00, "Severe Income Loss (ML)"))
        
        if cands: 
            tp, tn = max(cands, key=lambda x: x[0])
            st = "APPROVED"
        elif d > 0 and lost > 0:
            # Has activity and lost some hours - give base coverage
            tp, tn, st = 0.10, "Base Coverage", "APPROVED"
        else:
            # New user or no lost hours - give initial income protection
            tp, tn, st = min_payout_pct, "Initial Income Protection", "APPROVED"
            lost = worker["target_daily_hours"]  # Full day for initial calculation

    p_amt = round((rate * lost) * tp)
    
    # Ensure minimum payout of ₹50 for any approved status
    if st == "APPROVED" and p_amt < 50:
        p_amt = 50
    
    # 5. Log payout decision with comprehensive audit trail
    conn = await get_db_conn()
    try:
        # Insert payout record
        payout_id = await conn.fetchval(
            """INSERT INTO payouts (worker_id, amount, risk_level, income_severity, fraud_level, fraud_score, payout_status, trigger_pct, hourly_rate, hours_lost, trigger_type) 
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING payout_id""",
            req.worker_id, float(p_amt), rl, isev, fl, fs, st, tp, rate, lost, tn)
        
        # Create audit log entry with full decision context
        audit_details = {
            "payout_id": payout_id,
            "decision": st,
            "amount": float(p_amt),
            "trigger": tn,
            "trigger_pct": tp,
            "hourly_rate": rate,
            "hours_lost": lost,
            "analytics": {
                "risk_score": rs,
                "risk_level": rl,
                "fraud_score": fs,
                "fraud_level": fl,
                "income_drop": idr,
                "income_severity": isev
            },
            "environment": {
                "temp": w["temp"],
                "rainfall": w["rain_1h"],
                "aqi_pm25": aq["pm25"],
                "location": {"lat": req.lat, "lon": req.lon}
            },
            "worker_metrics": {
                "hours_worked": h,
                "movement_km": m_km,
                "deliveries": d,
                "earnings_today": float(db_activity["earnings"])
            },
            "reasoning": f"Risk: {rl}({rs}), Fraud: {fl}({fs}), Income: {isev}({idr}%), Trigger: {tn}"
        }
        
        # Determine severity based on decision
        severity = "CRITICAL" if st == "BANNED" else "WARNING" if st == "HELD" else "INFO"
        event_type = f"PAYOUT_{st}"
        message = f"Payout decision: {st} - ₹{p_amt} for {tn}" if st == "APPROVED" else f"Payout {st}: {tn if tn != 'None' else fl}"
        
        # If approved, create transaction record
        if st == "APPROVED" and p_amt > 0:
            metadata_str = '{"trigger": "' + str(tn) + '", "trigger_pct": ' + str(tp) + ', "risk_level": "' + str(rl) + '", "fraud_level": "' + str(fl) + '"}'
            await conn.execute(
                """INSERT INTO transactions (worker_id, payout_id, transaction_type, amount, status, metadata)
                   VALUES ($1, $2, $3, $4, $5, $6)""",
                req.worker_id, payout_id, "PAYOUT_CREDIT", float(p_amt), "PENDING",
                metadata_str)
    finally: 
        await conn.close()

    base = (worker["avg_earnings_12w"] * 6) * 0.0075; r_mult = 1.0 + 0.4 * min(rs / 8.0, 1.0); zf = 1.10 if "Central" in worker["zone"] else 1.05; prem = round(max(15, min(100, base * r_mult * loyalty * zf)))
    return {"status": st, "worker_id": req.worker_id, "analytics": {"risk": {"score": rs, "level": rl}, "fraud": {"score": fs, "level": fl}, "income": {"drop": idr, "severity": isev}}, "payout": {"amount": p_amt, "trigger": tn}, "premium_update": {"weekly_premium": prem}}

# ─── ADMIN CONSOLE ENDPOINTS (Restored) ───────────────────────────────────────

@app.get("/api/v1/workers/count")
async def get_worker_count():
    conn = await get_db_conn(); c = await conn.fetchval("SELECT COUNT(*) FROM workers"); await conn.close(); return {"count": c}

@app.get("/api/v1/policies/active-count")
async def get_active_policy_count():
    conn = await get_db_conn(); c = await conn.fetchval("SELECT COUNT(*) FROM policies WHERE status='ACTIVE' AND coverage_end > NOW()"); await conn.close(); return {"count": c}

@app.get("/api/v1/payouts/today-summary")
async def get_payouts_today():
    conn = await get_db_conn(); d = await conn.fetchrow("SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count FROM payouts WHERE triggered_at::date = CURRENT_DATE"); await conn.close(); return {"total": d["total"], "count": d["count"]}

@app.get("/api/v1/worker/{worker_id}/summary")
async def get_worker_summary_mobile(worker_id: str):
    conn = await get_db_conn()
    try:
        worker = await conn.fetchrow("SELECT * FROM workers WHERE worker_id=$1", worker_id)
        payouts = await conn.fetch("SELECT amount, payout_status, triggered_at, trigger_pct FROM payouts WHERE worker_id=$1 ORDER BY triggered_at DESC LIMIT 5", worker_id)
        total_paid = await conn.fetchval("SELECT COALESCE(SUM(amount), 0) FROM payouts WHERE worker_id=$1 AND payout_status='APPROVED' AND triggered_at > NOW() - INTERVAL '30 days'", worker_id)
        return {"worker": dict(worker), "total_paid_this_month": float(total_paid), "recent_payouts": [dict(p) for p in payouts]}
    finally: await conn.close()

@app.get("/api/v1/worker/{worker_id}/payouts")
async def get_worker_payouts(worker_id: str):
    """Get all payouts for a specific worker"""
    conn = await get_db_conn()
    try:
        payouts = await conn.fetch(
            """SELECT payout_id, amount, trigger_type, trigger_pct, hourly_rate, hours_lost,
                      risk_level, income_severity, fraud_level, fraud_score, payout_status, triggered_at
               FROM payouts WHERE worker_id=$1 ORDER BY triggered_at DESC""", 
            worker_id
        )
        return [dict(p) for p in payouts]
    finally: await conn.close()

@app.post("/api/v1/submit-claim")
async def submit_claim(req: dict):
    """Submit a new claim and trigger automatic payout calculation"""
    conn = await get_db_conn()
    try:
        worker_id = req.get("worker_id")
        alert_type = req.get("alert_type", "Manual Claim")
        lat = req.get("lat", 0.0)
        lon = req.get("lon", 0.0)
        
        # Get active policy
        policy = await conn.fetchrow(
            """SELECT policy_id FROM policies 
               WHERE worker_id=$1 AND status='ACTIVE' AND coverage_end > NOW()
               ORDER BY coverage_end DESC LIMIT 1""", worker_id
        )
        
        if not policy:
            raise HTTPException(status_code=400, detail="No active policy found")
        
        # Get worker info for analysis
        worker = await conn.fetchrow("SELECT * FROM workers WHERE worker_id=$1", worker_id)
        if not worker:
            raise HTTPException(status_code=404, detail="Worker not found")
        
        # Get hub data for analysis
        async with httpx.AsyncClient() as client:
            try:
                hub_res = await client.get(f"{DATA_HUB_URL}?lat={lat}&lon={lon}&worker_id={worker_id}", timeout=15.0)
                hub_data = hub_res.json() if hub_res.status_code == 200 else {}
            except:
                hub_data = {}
        
        # Get session data
        session = await conn.fetchrow(
            """SELECT hours_online, movement_km, deliveries_done 
               FROM worker_sessions 
               WHERE worker_id = $1 AND session_date = CURRENT_DATE""", 
            worker_id
        )
        session = session or {"hours_online": 0.0, "movement_km": 0.0, "deliveries_done": 0}
        
        # Get DB activity
        db_activity = await conn.fetchrow(
            """SELECT COALESCE(SUM(earnings), 0) as earnings, COUNT(*) as orders 
               FROM orders WHERE worker_id = $1 AND timestamp::date = CURRENT_DATE""", 
            worker_id
        )
        
        # Run ML Analysis
        h = session["hours_online"]
        m_km = session["movement_km"]
        d = session["deliveries_done"]
        
        w = hub_data.get("external_disruption", {}).get("weather", {})
        aq = hub_data.get("external_disruption", {}).get("air_quality", {})
        met = hub_data.get("business_impact", {}).get("metrics", {})
        
        rf = {"temp_c": w.get("temp", 30), "feels_like_c": w.get("feels_like", 30), 
              "rain_1h": w.get("rain_1h", 0), "pm25": aq.get("pm25", 45), 
              "pm10": aq.get("pm10", 30), "traffic_index": hub_data.get("external_disruption", {}).get("traffic_index", 45)}
        
        rs = 5.0
        rl = "LOW"
        if RISK_REGRESSOR and RISK_MODEL:
            try:
                rs = float(RISK_REGRESSOR.predict(pd.DataFrame([rf])[RISK_FEATURES])[0])
                rl = str(RISK_LE.inverse_transform([RISK_MODEL.predict(pd.DataFrame([rf])[RISK_FEATURES])[0]])[0])
            except:
                pass
        
        inf = {"earnings_drop_pct": met.get("earnings_drop_pct", 0), "order_drop_pct": met.get("order_drop_pct", 0),
               "activity_drop_pct": met.get("activity_drop_pct", 0), "orders_last_hour": d,
               "earnings_today": float(db_activity["earnings"]) if db_activity else 0,
               "hours_worked_today": h, "avg_orders_7d": worker["avg_orders_7d"] if worker else 14,
               "avg_earnings_12w": worker["avg_earnings_12w"] if worker else 1800,
               "avg_hours_baseline": worker["target_daily_hours"] if worker else 8.0}
        
        idr = 20.0
        isev = "LOW"
        if INCOME_REG and INCOME_CLF:
            try:
                idr = float(INCOME_REG.predict(pd.DataFrame([inf])[INCOME_FEATURES])[0])
                isev = str(INCOME_LE.inverse_transform([INCOME_CLF.predict(pd.DataFrame([inf])[INCOME_FEATURES])[0]])[0])
            except:
                pass
        
        ff = {"activity_drop_pct": idr, "hours_worked_today": h, "earnings_drop_pct": 20.0,
              "active_hours": h, "deliveries_completed": d, "avg_deliveries": (worker["avg_orders_7d"] if worker else 14) / 8.0,
              "movement_distance_km": m_km, "order_drop_pct": 20.0, "orders_last_hour": d}
        
        fs = 0.1
        fl = "LOW"
        if FRAUD_REG and FRAUD_CLF:
            try:
                fs = float(FRAUD_REG.predict(pd.DataFrame([ff])[FRAUD_FEATURES])[0])
                fl = str(FRAUD_LE.inverse_transform([FRAUD_CLF.predict(pd.DataFrame([ff])[FRAUD_FEATURES])[0]])[0])
            except:
                pass
        
        # Decision logic
        rate = (worker["avg_earnings_12w"] / worker["target_daily_hours"]) if worker else 225
        lost = max(0.0, (worker["target_daily_hours"] if worker else 8.0) - h)
        
        # Initial income protection for new users (no activity)
        initial_income_pct = 0.10
        
        tp, tn, st = 0.0, "None", "DENIED"
        
        if fl == "HIGH" or fs > 0.65:
            st = "BANNED"
        elif fs > 0.3:
            st = "HELD"
        else:
            cands = []
            if w.get("rain_1h", 0) > 45:
                cands.append((0.80, "Heavy Rainfall"))
            if aq.get("pm25", 0) > 120:
                cands.append((0.80, "Hazardous AQI"))
            if idr > 45:
                cands.append((1.00, "Severe Income Loss (ML)"))
            if cands:
                tp, tn = max(cands, key=lambda x: x[0])
                st = "APPROVED"
            elif d > 0:
                tp, tn, st = 0.10, "Base Coverage", "APPROVED"
            else:
                # No activity - new user gets initial income protection
                tp, tn, st = initial_income_pct, "Initial Income Protection", "APPROVED"
                lost = worker["target_daily_hours"] if worker else 8.0
        
        p_amt = round((rate * lost) * tp)
        
        # Insert payout record
        payout_id = await conn.fetchval(
            """INSERT INTO payouts (worker_id, amount, risk_level, income_severity, fraud_level, fraud_score, payout_status, trigger_pct, hourly_rate, hours_lost, trigger_type) 
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING payout_id""",
            worker_id, float(p_amt), rl, isev, fl, fs, st, tp, rate, lost, tn
        )
        
        # Create transaction if approved
        if st == "APPROVED" and p_amt > 0:
            metadata_str = '{"trigger": "' + str(tn) + '", "trigger_pct": ' + str(tp) + ', "risk_level": "' + str(rl) + '", "fraud_level": "' + str(fl) + '"}'
            await conn.execute(
                """INSERT INTO transactions (worker_id, payout_id, transaction_type, amount, status, metadata)
                   VALUES ($1, $2, $3, $4, $5, $6)""",
                worker_id, payout_id, "PAYOUT_CREDIT", float(p_amt), "PENDING", metadata_str
            )
        
        # Create claim
        claim_id = await conn.fetchval(
            """INSERT INTO claims 
               (worker_id, policy_id, trigger_type, trigger_pct, claimed_amount, status, lat, lon)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
               RETURNING claim_id""",
            worker_id, policy["policy_id"], alert_type, tp, float(p_amt), st, lat, lon
        )
        
        return {
            "claim_id": claim_id, 
            "status": st, 
            "payout_id": payout_id,
            "payout_amount": p_amt,
            "message": f"Claim submitted. Payout: ₹{p_amt} ({st})"
        }
    finally:
        await conn.close()

@app.post("/api/v1/assistant")
async def assistant(req: dict):
    ctx = req.get("context", {}); prompt = f"You are Aegis AI assistant. Context: {ctx}. Keep answers under 3 sentences. Question: {req.get('question', '')}"
    try:
        model = genai.GenerativeModel('gemini-1.5-flash'); res = model.generate_content(prompt); return {"reply": res.text}
    except: return {"reply": "I'm having trouble connecting to my Gemini brain."}

@app.get("/api/v1/fraud/today-count")
async def get_fraud_count_today():
    """Get count of fraudulent activity detected today"""
    conn = await get_db_conn()
    try:
        # Count payouts with HIGH fraud level or BANNED status
        count = await conn.fetchval(
            """SELECT COUNT(*) FROM payouts 
               WHERE triggered_at::date = CURRENT_DATE 
               AND (fraud_level = 'HIGH' OR payout_status = 'BANNED')"""
        )
        
        # Get total fraud score for trending
        avg_score = await conn.fetchval(
            """SELECT COALESCE(AVG(fraud_score), 0) FROM payouts 
               WHERE triggered_at::date = CURRENT_DATE"""
        )
        
        return {
            "count": count or 0,
            "avg_fraud_score": round(float(avg_score or 0), 2)
        }
    finally:
        await conn.close()

@app.get("/api/v1/payouts/daily-totals")
async def get_daily_payout_totals(days: int = Query(default=7, ge=1, le=90)):
    """Get daily payout totals for the last N days"""
    conn = await get_db_conn()
    try:
        rows = await conn.fetch(
            """SELECT triggered_at::date as date,
                      COALESCE(SUM(amount), 0) as total,
                      COUNT(*) as count,
                      COUNT(CASE WHEN payout_status = 'APPROVED' THEN 1 END) as approved_count
               FROM payouts
               WHERE triggered_at >= CURRENT_DATE - $1 * INTERVAL '1 day'
               GROUP BY triggered_at::date
               ORDER BY date DESC""",
            days
        )
        
        return [
            {
                "date": row["date"].isoformat(),
                "total": float(row["total"]),
                "count": row["count"],
                "approved_count": row["approved_count"]
            }
            for row in rows
        ]
    finally:
        await conn.close()

@app.get("/api/v1/workers")
async def get_all_workers(limit: int = Query(default=100, ge=1, le=1000)):
    """Get all workers with their details"""
    conn = await get_db_conn()
    try:
        rows = await conn.fetch(
            """SELECT w.worker_id, w.name, w.phone, w.platform, w.city, w.zone,
                      w.kyc_status, w.avg_earnings_12w, w.target_daily_hours,
                      w.registered_at,
                      (SELECT COUNT(*) FROM policies p WHERE p.worker_id = w.worker_id AND p.status = 'ACTIVE' AND p.coverage_end > NOW()) as active_policies,
                      (SELECT COALESCE(SUM(amount), 0) FROM payouts WHERE worker_id = w.worker_id AND payout_status = 'APPROVED') as total_payouts
               FROM workers w
               ORDER BY w.registered_at DESC
               LIMIT $1""",
            limit
        )
        
        return [
            {
                "worker_id": row["worker_id"],
                "name": row["name"],
                "phone": row["phone"],
                "platform": row["platform"],
                "city": row["city"],
                "zone": row["zone"],
                "kyc_status": row["kyc_status"],
                "avg_earnings_12w": float(row["avg_earnings_12w"]),
                "target_daily_hours": float(row["target_daily_hours"]),
                "registered_at": row["registered_at"].isoformat() if row["registered_at"] else None,
                "active_policies": row["active_policies"],
                "total_payouts": float(row["total_payouts"])
            }
            for row in rows
        ]
    finally:
        await conn.close()

@app.get("/api/v1/workers/stats")
async def get_worker_stats():
    """Get comprehensive worker statistics"""
    conn = await get_db_conn()
    try:
        # Get various worker statistics
        total = await conn.fetchval("SELECT COUNT(*) FROM workers")
        kyc_verified = await conn.fetchval("SELECT COUNT(*) FROM workers WHERE kyc_status = 'VERIFIED'")
        active_today = await conn.fetchval(
            """SELECT COUNT(DISTINCT worker_id) FROM payouts 
               WHERE triggered_at::date = CURRENT_DATE"""
        )
        
        # Platform breakdown
        platform_stats = await conn.fetch(
            """SELECT platform, COUNT(*) as count 
               FROM workers 
               GROUP BY platform"""
        )
        
        # Zone breakdown
        zone_stats = await conn.fetch(
            """SELECT zone, COUNT(*) as count 
               FROM workers 
               GROUP BY zone"""
        )
        
        return {
            "total_workers": total,
            "kyc_verified": kyc_verified,
            "active_today": active_today,
            "by_platform": {row["platform"]: row["count"] for row in platform_stats},
            "by_zone": {row["zone"]: row["count"] for row in zone_stats}
        }
    finally:
        await conn.close()

@app.get("/api/v1/financials/summary")
async def get_financial_summary():
    """Get comprehensive financial summary"""
    conn = await get_db_conn()
    try:
        # Revenue from premiums
        premium_revenue = await conn.fetchval(
            """SELECT COALESCE(SUM(weekly_premium), 0) 
               FROM policies 
               WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'"""
        )
        
        # Total payouts
        total_payouts = await conn.fetchval(
            """SELECT COALESCE(SUM(amount), 0) 
               FROM payouts 
               WHERE triggered_at >= CURRENT_DATE - INTERVAL '30 days'
               AND payout_status = 'APPROVED'"""
        )
        
        # Active policies value
        active_policies_value = await conn.fetchval(
            """SELECT COALESCE(SUM(weekly_premium), 0) 
               FROM policies 
               WHERE status = 'ACTIVE' AND coverage_end > NOW()"""
        )
        
        # Claims pending
        pending_claims = await conn.fetchval(
            """SELECT COUNT(*) FROM claims WHERE status = 'PENDING'"""
        )
        
        # Today's metrics
        today_premium = await conn.fetchval(
            """SELECT COALESCE(SUM(weekly_premium), 0) 
               FROM policies 
               WHERE created_at::date = CURRENT_DATE"""
        )
        
        today_payouts = await conn.fetchval(
            """SELECT COALESCE(SUM(amount), 0) 
               FROM payouts 
               WHERE triggered_at::date = CURRENT_DATE
               AND payout_status = 'APPROVED'"""
        )
        
        return {
            "monthly": {
                "premium_revenue": float(premium_revenue or 0),
                "total_payouts": float(total_payouts or 0),
                "net_revenue": float((premium_revenue or 0) - (total_payouts or 0)),
                "loss_ratio": round(float(total_payouts or 0) / float(premium_revenue or 1) * 100, 2)
            },
            "today": {
                "premium_revenue": float(today_premium or 0),
                "total_payouts": float(today_payouts or 0)
            },
            "active_policies_value": float(active_policies_value or 0),
            "pending_claims": pending_claims or 0
        }
    finally:
        await conn.close()

@app.get("/api/v1/operations/live-stats")
async def get_live_operations_stats():
    """Get live operational statistics"""
    conn = await get_db_conn()
    try:
        # Recent activity (last hour)
        recent_analyses = await conn.fetchval(
            """SELECT COUNT(*) FROM payouts 
               WHERE triggered_at >= NOW() - INTERVAL '1 hour'"""
        )
        
        # Active sessions today
        active_sessions = await conn.fetchval(
            """SELECT COUNT(*) FROM worker_sessions 
               WHERE session_date = CURRENT_DATE"""
        )
        
        # Current risk distribution
        risk_distribution = await conn.fetch(
            """SELECT risk_level, COUNT(*) as count 
               FROM payouts 
               WHERE triggered_at::date = CURRENT_DATE
               GROUP BY risk_level"""
        )
        
        # Payout status breakdown today
        payout_status = await conn.fetch(
            """SELECT payout_status, COUNT(*) as count 
               FROM payouts 
               WHERE triggered_at::date = CURRENT_DATE
               GROUP BY payout_status"""
        )
        
        # Average processing metrics
        avg_payout = await conn.fetchval(
            """SELECT COALESCE(AVG(amount), 0) 
               FROM payouts 
               WHERE triggered_at::date = CURRENT_DATE
               AND payout_status = 'APPROVED'"""
        )
        
        return {
            "recent_analyses": recent_analyses or 0,
            "active_sessions_today": active_sessions or 0,
            "risk_distribution": {row["risk_level"]: row["count"] for row in risk_distribution},
            "payout_status": {row["payout_status"]: row["count"] for row in payout_status},
            "avg_payout_amount": round(float(avg_payout or 0), 2),
            "timestamp": datetime.now().isoformat()
        }
    finally:
        await conn.close()

@app.get("/health")
def health(): return {"status": "online"}
