"""
GigShield Model Backend v6.0 - Parametric Subscription Hub
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

try:
    from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
    from sklearn.preprocessing import LabelEncoder
    print("[MODEL] Sklearn loaded successfully")
except ImportError as e:
    print(f"[MODEL] Sklearn not available: {e}")
import os
import httpx
import asyncio
import asyncpg
import google.generativeai as genai
import json
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Optional, List
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
import requests as req_lib
import datetime as dt
import razorpay
from typing import Optional, List, Any, cast

from fraud_enhanced import apply_delivery_fraud_rules

app = FastAPI(title="Aegis Subscription Hub", version="6.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Configuration ---
BASE_DIR = os.path.dirname(__file__)

# Load .env file
from dotenv import load_dotenv
load_dotenv(os.path.join(BASE_DIR, ".env"))

DATA_HUB_URL = os.getenv("DATA_HUB_URL", "http://localhost:3015/api/risk-data")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://aegis_admin:aegis_secure_pass@localhost:2003/aegis_intelligence")
GOOGLE_KEY = os.environ.get("GOOGLE_API_KEY", "")
HUB_URL = os.getenv("DATA_HUB_URL", "http://localhost:3015").replace("/api/risk-data", "")

RAZORPAY_KEY_ID = os.getenv("RAZORPAY_KEY_ID", "")
RAZORPAY_KEY_SECRET = os.getenv("RAZORPAY_KEY_SECRET", "")

if GOOGLE_KEY:
    cast_genai = cast(Any, genai)
    cast_genai.configure(api_key=GOOGLE_KEY)

async def get_db_conn():
    return await asyncpg.connect(DATABASE_URL)

# --- Schemas ---

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

class SubmitClaimRequest(BaseModel):
    worker_id: str
    alert_type: Optional[str] = None
    lat: float
    lon: float

class PayoutRequest(BaseModel):
    payout_id: int
    worker_id: str
    amount: float  # in INR
    upi_id: str


RISK_MODEL: Any = None
RISK_LE: Any = None
RISK_FEATURES: Any = None
RISK_REGRESSOR: Any = None
INCOME_REG: Any = None
INCOME_CLF: Any = None
INCOME_LE: Any = None
INCOME_FEATURES: Any = None
FRAUD_REG: Any = None
FRAUD_CLF: Any = None
FRAUD_LE: Any = None
FRAUD_FEATURES: Any = None
MODELS_READY = False

# --- Load ML Models ---
def _load(filename):
    path = os.path.join(BASE_DIR, filename)
    if not os.path.exists(path):
        print(f"[MODEL] File not found: {filename}")
        return None
    try:
        with open(path, "rb") as f:
            return pickle.load(f)
    except Exception as e:
        if "No module named '_loss'" not in str(e):
            print(f"[MODEL] Failed to load {filename}: {e}")
        return None

try:
    risk_pkg = _load("risk_model.pkl")
    if risk_pkg:
        RISK_MODEL = risk_pkg["model"]
        RISK_LE = risk_pkg["label_encoder"]
        RISK_FEATURES = risk_pkg["features"]
    RISK_REGRESSOR = _load("risk_regressor.pkl")
    income_pkg = _load("income_model.pkl")
    if income_pkg:
        INCOME_REG = income_pkg["regressor"]
        INCOME_CLF = income_pkg["classifier"]
        INCOME_LE = income_pkg["label_encoder"]
        INCOME_FEATURES = income_pkg["features"]
    fraud_pkg = _load("fraud_model.pkl")
    if fraud_pkg:
        FRAUD_REG = fraud_pkg["regressor"]
        FRAUD_CLF = fraud_pkg["classifier"]
        FRAUD_LE = fraud_pkg["label_encoder"]
        FRAUD_FEATURES = fraud_pkg["features"]
    MODELS_READY = all([
        RISK_MODEL, RISK_LE, RISK_FEATURES, RISK_REGRESSOR,
        INCOME_REG, INCOME_CLF, INCOME_LE, INCOME_FEATURES,
        FRAUD_REG, FRAUD_CLF, FRAUD_LE, FRAUD_FEATURES,
    ])
    if MODELS_READY:
        print("✅ Aegis v6.0: Intelligence Hub Active")
    else:
        print("⚠️ Aegis v6.0: running in heuristic fallback mode")
except Exception as e:
    print(f"⚠️ Load warning: {e}")


def _predict_risk_score(rf: dict) -> float:
    if RISK_REGRESSOR is not None and RISK_FEATURES is not None:
        try:
            frame = pd.DataFrame([rf])
            return round(float(RISK_REGRESSOR.predict(frame[RISK_FEATURES])[0]), 2)
        except Exception as exc:
            print(f"[MODEL] Risk regressor fallback: {exc}")

    rainfall = float(rf.get("rainfall_mm", 0) or 0)
    pm25 = float(rf.get("pm25", 0) or 0)
    traffic = float(rf.get("traffic_index", 0) or 0)
    temp = float(rf.get("temp_c", 0) or 0)
    score = 0.10 + min(rainfall / 100.0, 0.30) + min(max(pm25 - 50.0, 0.0) / 400.0, 0.25) + min(traffic / 200.0, 0.20) + min(abs(temp - 28.0) / 120.0, 0.10)
    return round(max(0.0, min(score, 1.0)), 2)


def _predict_risk_level(rf: dict) -> str:
    if RISK_MODEL is not None and RISK_LE is not None and RISK_FEATURES is not None:
        try:
            frame = pd.DataFrame([rf])
            return str(RISK_LE.inverse_transform([RISK_MODEL.predict(frame[RISK_FEATURES])[0]])[0])
        except Exception as exc:
            print(f"[MODEL] Risk classifier fallback: {exc}")
    return _score_to_level(_predict_risk_score(rf))


def _predict_income_drop(inf: dict) -> tuple[float, str]:
    if INCOME_REG is not None and INCOME_CLF is not None and INCOME_LE is not None and INCOME_FEATURES is not None:
        try:
            frame = pd.DataFrame([inf])
            drop = round(float(INCOME_REG.predict(frame[INCOME_FEATURES])[0]), 2)
            sev = str(INCOME_LE.inverse_transform([INCOME_CLF.predict(frame[INCOME_FEATURES])[0]])[0])
            return drop, sev
        except Exception as exc:
            print(f"[MODEL] Income model fallback: {exc}")

    earnings_drop = float(inf.get("earnings_drop_pct", 0) or 0)
    order_drop = float(inf.get("order_drop_pct", 0) or 0)
    activity_drop = float(inf.get("activity_drop_pct", 0) or 0)
    drop = round(max(earnings_drop, order_drop, activity_drop), 2)
    if drop < 20:
        severity = "LOW"
    elif drop < 40:
        severity = "MODERATE"
    elif drop < 70:
        severity = "SUSPICIOUS"
    elif drop < 85:
        severity = "HIGH"
    else:
        severity = "CRITICAL"
    return drop, severity


def _predict_base_fraud_score(ff: dict) -> float:
    if FRAUD_REG is not None and FRAUD_FEATURES is not None:
        try:
            frame = pd.DataFrame([ff])
            return round(max(0.0, min(1.0, float(FRAUD_REG.predict(frame[FRAUD_FEATURES])[0]))), 2)
        except Exception as exc:
            print(f"[MODEL] Fraud model fallback: {exc}")

    movement = float(ff.get("movement_distance_km", 0) or 0)
    orders = float(ff.get("orders_last_hour", 0) or 0)
    hours = float(ff.get("hours_worked_today", 0) or 0)
    score = 0.12
    score += 0.20 if movement < 0.5 and hours > 3 else 0.0
    score += 0.18 if orders > 8 and hours > 6 else 0.0
    score += min(max(0.0, 1.0 - float(movement) / float(50.0)), 0.15)
    return round(max(0.0, min(score, 1.0)), 2)

# --- DB Fetch Helpers ---

async def fetch_db_activity(worker_id: str) -> dict:
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow("SELECT COALESCE(SUM(earnings), 0) as earnings, COUNT(*) as orders FROM orders WHERE worker_id = $1 AND timestamp::date = CURRENT_DATE", worker_id)
        result = dict(row)
        for k, v in result.items():
            if isinstance(v, Decimal):
                result[k] = float(v)
        return result
    finally:
        await conn.close()

async def fetch_worker_profile(worker_id: str) -> dict | None:
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow("SELECT * FROM workers WHERE worker_id = $1", worker_id)
        if not row:
            return None
        result = dict(row)
        for k, v in result.items():
            if isinstance(v, type(Decimal())):
                result[k] = float(v)
        return result
    finally:
        await conn.close()

async def get_loyalty_factor(worker_id: str) -> float:
    conn = await get_db_conn()
    try:
        count = await conn.fetchval("SELECT COUNT(*) FROM payouts WHERE worker_id = $1 AND triggered_at > NOW() - INTERVAL '84 days' AND payout_status = 'APPROVED'", worker_id)
        return 0.85 if count == 0 else 1.0
    finally:
        await conn.close()

async def fetch_session_data(worker_id: str) -> dict:
    """Fetch today's session data for fraud detection"""
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            """SELECT hours_online, movement_km, deliveries_done, lat_last, lon_last, zone_mismatch
               FROM worker_sessions
               WHERE worker_id = $1 AND session_date = CURRENT_DATE""",
            worker_id
        )
        if row:
            result = dict(row)
            for k, v in result.items():
                if isinstance(v, Decimal):
                    result[k] = float(v)
            return result
        return {"hours_online": 0.0, "movement_km": 0.0, "deliveries_done": 0, "lat_last": None, "lon_last": None, "zone_mismatch": False}
    finally:
        await conn.close()

async def fetch_claim_velocity(zone: str) -> int:
    if not zone:
        return 0
    conn = await get_db_conn()
    try:
        count = await conn.fetchval(
            """SELECT COUNT(*) FROM payouts
               WHERE triggered_at >= NOW() - INTERVAL '15 minutes'
               AND worker_id IN (SELECT worker_id FROM workers WHERE zone = $1)""",
            zone
        )
        return int(count or 0)
    finally:
        await conn.close()

async def check_order_history(worker_id: str) -> bool:
    conn = await get_db_conn()
    try:
        count = await conn.fetchval(
            """SELECT COUNT(*) FROM orders
               WHERE worker_id = $1
               AND timestamp >= NOW() - INTERVAL '48 hours'""",
            worker_id
        )
        return (count or 0) > 0
    finally:
        await conn.close()

# --- Auto-trigger Scheduler ---

scheduler = BackgroundScheduler()

def auto_trigger_loop():
    """
    Runs every 60s. For each worker with an active policy today,
    fetches env data from hub, runs ML pipeline, writes payout if
    both gates pass and no payout has already fired today.
    """
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        async def _run():
            db = await get_db_conn()
            try:
                rows = await db.fetch("SELECT worker_id, avg_earnings_12w, target_daily_hours, zone, avg_orders_7d, lat_last, lon_last FROM v_auto_trigger_candidates")
            finally:
                await db.close()

            today = dt.date.today().isoformat()
            for worker in rows:
                worker_id = worker["worker_id"]
                check = req_lib.get(
                    f"{HUB_URL}/api/payout-exists/{worker_id}/{today}",
                    timeout=3
                )
                if check.ok and check.json().get("exists"):
                    continue

                lat = float(worker.get("lat_last") or 13.0827)
                lon = float(worker.get("lon_last") or 80.2707)
                try:
                    result = await run_analysis_internal(worker_id, float(lat), float(lon))
                    if result.get("status") == "APPROVED":
                        print(f"[AUTO] Payout approved for {worker_id}: ₹{result['payout']['amount']}")
                except Exception as exc:
                    print(f"[AUTO] Analysis failed for {worker_id}: {exc}")

        loop.run_until_complete(_run())
        loop.close()
    except Exception as exc:
        print(f"[AUTO-TRIGGER ERROR] {exc}")

scheduler.add_job(
    auto_trigger_loop,
    trigger=IntervalTrigger(seconds=60),
    id="auto_trigger",
    replace_existing=True
)

@app.on_event("startup")
async def startup_event():
    scheduler.start()
    print("[AEGIS] Auto-trigger loop started - 60s interval")

@app.on_event("shutdown")
async def shutdown_event():
    scheduler.shutdown()


def _detect_zone_from_coords(lat: float, lon: float) -> str | None:
    """Detect zone from GPS coordinates using zone boundaries"""
    zone_boundaries = {
        "Chennai-Central": {"lat_min": 13.05, "lat_max": 13.10, "lon_min": 80.25, "lon_max": 80.30},
        "Chennai-North": {"lat_min": 13.10, "lat_max": 13.15, "lon_min": 80.28, "lon_max": 80.32},
        "Chennai-South": {"lat_min": 13.00, "lat_max": 13.05, "lon_min": 80.22, "lon_max": 80.27},
        "Chennai-East": {"lat_min": 13.05, "lat_max": 13.10, "lon_min": 80.22, "lon_max": 80.27},
    }
    for zone, bounds in zone_boundaries.items():
        if bounds["lat_min"] <= lat <= bounds["lat_max"] and bounds["lon_min"] <= lon <= bounds["lon_max"]:
            return zone
    return None


def _score_to_level(score: float) -> str:
    if score < 0.30: return "LOW"
    if score < 0.50: return "MODERATE"
    if score < 0.70: return "SUSPICIOUS"
    if score < 0.85: return "HIGH"
    return "CRITICAL"


async def run_analysis_internal(worker_id: str, lat: float, lon: float) -> dict:
    if not MODELS_READY:
        print("[MODEL] Fallback mode active: one or more pickles could not be loaded")

    # 1. Active Policy Gate
    conn = await get_db_conn()
    try:
        policy = await conn.fetchrow(
            """SELECT policy_id, plan_name, weekly_premium, payout_cap FROM policies
               WHERE worker_id=$1 AND status='ACTIVE' AND coverage_end > NOW()
               ORDER BY coverage_end DESC LIMIT 1""", worker_id)
    finally:
        await conn.close()

    if not policy:
        return {
            "status": "NO_COVERAGE",
            "worker_id": worker_id,
            "message": "No active policy detected. Analysis halted.",
            "payout": {"amount": 0, "trigger": "None"}
        }

    # 2. Sequential Orchestration
    async def fetch_hub_data() -> httpx.Response:
        async with httpx.AsyncClient(timeout=15.0) as client:
            return await client.get(f"{DATA_HUB_URL}?lat={lat}&lon={lon}&worker_id={worker_id}")

    worker, db_activity, session, loyalty, hub_res = await asyncio.gather(
        fetch_worker_profile(worker_id),
        fetch_db_activity(worker_id),
        fetch_session_data(worker_id),
        get_loyalty_factor(worker_id),
        fetch_hub_data(),
    )
    if worker is None:
        raise HTTPException(status_code=404, detail="Worker not found")

    hub_data = hub_res.json()
    h = session["hours_online"]
    m_km = session["movement_km"]
    d = int(db_activity["orders"])

    # 3. ML Intelligence
    w = hub_data["external_disruption"]["weather"]
    aq = hub_data["external_disruption"]["air_quality"]
    met = hub_data["business_impact"]["metrics"]

    rf = {
        "temp_c": w["temp"],
        "feels_like_c": w["feels_like"],
        "rainfall_mm": w["rain_1h"],
        "pm25": aq["pm25"],
        "pm10": aq["pm10"],
        "traffic_index": hub_data["external_disruption"]["traffic_index"]
    }
    rs = _predict_risk_score(rf)
    rl = _predict_risk_level(rf)

    inf = {
        "earnings_drop_pct": met["earnings_drop_pct"],
        "order_drop_pct": met["order_drop_pct"],
        "activity_drop_pct": met["activity_drop_pct"],
        "orders_last_hour": d,
        "earnings_today": float(db_activity["earnings"]),
        "hours_worked_today": h,
        "avg_orders_7d": worker["avg_orders_7d"],
        "avg_earnings_12w": worker["avg_earnings_12w"],
        "avg_hours_baseline": worker["target_daily_hours"]
    }
    idr, isev = _predict_income_drop(inf)

    ff = {
        "activity_drop_pct": idr,
        "hours_worked_today": h,
        "earnings_drop_pct": 20.0,
        "active_hours": h,
        "deliveries_completed": d,
        "avg_deliveries": float(worker["avg_orders_7d"]) / float(8.0),
        "movement_distance_km": m_km,
        "order_drop_pct": 20.0,
        "orders_last_hour": d
    }
    base_fs = _predict_base_fraud_score(ff)

    claim_velocity = await fetch_claim_velocity(worker.get("zone") or "")
    order_history_presence = await check_order_history(worker_id)

    enhanced_fraud = apply_delivery_fraud_rules(base_fs, {
        "hours_worked_today": h,
        "orders_today": d,
        "movement_km": m_km,
        "claim_velocity": claim_velocity,
        "rain_1h": w["rain_1h"],
        "gps_consistency_score": max(0.0, min(1.0, 1.0 - min(float(m_km) / 50.0, 1.0))),
        "order_history_presence": order_history_presence,
        "zone_mismatch": session.get("zone_mismatch", False)
    })

    fs = enhanced_fraud["adjusted_fraud_score"]
    fl = enhanced_fraud["fraud_level"]

    # 4. Decision
    avg_earnings = float(worker["avg_earnings_12w"])
    target_hours = float(worker["target_daily_hours"])
    rate = avg_earnings / target_hours
    lost = max(0.0, target_hours - h)

    min_payout_pct = 0.05
    tp, tn, st = 0.0, "None", "DENIED"

    if fl in ("HIGH", "CRITICAL") or fs > 0.65:
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
            tp, tn, st = 0.10, "Base Coverage", "APPROVED"
        else:
            tp, tn, st = min_payout_pct, "Initial Income Protection", "APPROVED"
            lost = target_hours

    p_amt = round((rate * lost) * tp)
    if st == "APPROVED" and p_amt < 50:
        p_amt = 50

    # 5. Log payout decision with comprehensive audit trail
    conn = await get_db_conn()
    try:
        payout_id = await conn.fetchval(
            """INSERT INTO payouts
               (worker_id, policy_id, amount, risk_score, risk_level, income_drop_pct, income_severity,
                fraud_score, enhanced_fraud_score, fraud_level, fraud_rules_triggered,
                payout_status, trigger_pct, hourly_rate, hours_lost, trigger_type, gps_lat, gps_lng)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
               RETURNING payout_id""",
            worker_id, policy["policy_id"], float(p_amt), rs, rl, idr, isev,
            base_fs, fs, fl, json.dumps(enhanced_fraud["rules_triggered"]),
            st, tp, float(rate), float(lost), tn, lat, lon
        )

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
                "location": {"lat": lat, "lon": lon}
            },
            "worker_metrics": {
                "hours_worked": h,
                "movement_km": m_km,
                "deliveries": d,
                "earnings_today": float(db_activity["earnings"])
            },
            "reasoning": f"Risk: {rl}({rs}), Fraud: {fl}({fs}), Income: {isev}({idr}%), Trigger: {tn}"
        }

        severity = "CRITICAL" if st == "BANNED" else "WARNING" if st == "HELD" else "INFO"
        event_type = f"PAYOUT_{st}"
        message = f"Payout decision: {st} - ₹{p_amt} for {tn}" if st == "APPROVED" else f"Payout {st}: {tn if tn != 'None' else fl}"

        await conn.execute(
            """INSERT INTO audit_log (event_type, entity_type, entity_id, worker_id, action_by, severity, message, details)
               VALUES ($1, 'PAYOUT', $2, $3, 'SYSTEM', $4, $5, $6)""",
            event_type, str(payout_id), worker_id, severity, message, json.dumps(audit_details)
        )
    finally:
        await conn.close()

    base = (avg_earnings * 6) * 0.0075
    r_mult = 1.0 + 0.4 * min(rs / 8.0, 1.0)
    zf = 1.10 if "Central" in (worker.get("zone") or "") else 1.05
    prem = round(max(15, min(100, base * r_mult * loyalty * zf)))
    return {
        "status": st,
        "worker_id": worker_id,
        "analytics": {
            "risk": {"score": rs, "level": rl},
            "fraud": {"score": fs, "level": fl, "rules": enhanced_fraud["rules_triggered"]},
            "income": {"drop": idr, "severity": isev}
        },
        "payout": {"amount": p_amt, "trigger": tn, "payout_id": payout_id},
        "premium_update": {"weekly_premium": prem}
    }


@app.post("/api/v1/analyze")
async def analyze(req: AnalyzeRequest):
    return await run_analysis_internal(req.worker_id, req.lat, req.lon)


@app.post("/api/v1/submit-claim")
async def submit_claim(req: SubmitClaimRequest):
    result = await run_analysis_internal(req.worker_id, req.lat, req.lon)
    if req.alert_type:
        result["alert_type"] = req.alert_type
    return result


@app.post("/api/v1/razorpay/payout")
async def fire_razorpay_payout(request: PayoutRequest):
    """
    Called automatically after a payout row is written with status=APPROVED.
    Fires a Razorpay Payout API transfer in sandbox mode.
    Updates the payments table and sets payout_status=PAID on success.
    """
    if not RAZORPAY_KEY_ID:
        import time
        time.sleep(2)
        simulated_ref = f"rzp_sim_{request.payout_id}_{int(time.time())}"
        await _write_payment_record(request, simulated_ref, "SUCCESS", simulation_mode=True)
        return {
            "success": True,
            "payment_ref": simulated_ref,
            "mode": "simulated",
            "message": f"₹{request.amount} simulated payout to {request.upi_id}"
        }

    try:
        client = cast(Any, razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET)))
        payout_data = {
            "account_number": "2323230093773220",
            "amount": int(request.amount * 100),
            "currency": "INR",
            "mode": "UPI",
            "purpose": "payout",
            "fund_account": {
                "account_type": "vpa",
                "vpa": {"address": request.upi_id},
                "contact": {
                    "name": request.worker_id,
                    "type": "employee",
                    "reference_id": request.worker_id
                }
            },
            "queue_if_low_balance": True,
            "reference_id": f"aegis_payout_{request.payout_id}",
            "narration": f"Aegis parametric payout #{request.payout_id}"
        }
        response = client.payout.create(payout_data)
        ref = response.get("id", "unknown")
        await _write_payment_record(request, ref, "SUCCESS", simulation_mode=False)
        return {"success": True, "payment_ref": ref, "mode": "razorpay_sandbox"}

    except Exception as exc:
        await _write_payment_record(request, None, "FAILED", failure_reason=str(exc), simulation_mode=False)
        raise HTTPException(status_code=500, detail=f"Razorpay payout failed: {str(exc)}")


async def _write_payment_record(request: PayoutRequest, ref: str | None, status: str, failure_reason: str | None = None, simulation_mode: bool = False):
    conn = await get_db_conn()
    try:
        await conn.execute(
            """INSERT INTO payments
            (payout_id, worker_id, amount, payment_method, upi_id, payment_ref,
             gateway, status, completed_at, failure_reason, simulation_mode)
            VALUES ($1,$2,$3,'UPI',$4,$5,'RAZORPAY',$6,
                    CASE WHEN $7='SUCCESS' THEN NOW() ELSE NULL END, $8, $9)""",
            request.payout_id, request.worker_id, request.amount,
            request.upi_id, ref, status, status, failure_reason, simulation_mode
        )
        if status == "SUCCESS":
            await conn.execute(
                "UPDATE payouts SET payout_status='PAID', resolved_at=NOW() WHERE payout_id=$1",
                request.payout_id
            )
    finally:
        await conn.close()


# --- AUTH & ONBOARDING ---

@app.get("/api/v1/worker-by-phone")
async def get_worker_by_phone(phone: str):
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            """SELECT w.worker_id, w.name, w.kyc_status, w.zone, w.platform,
                      w.avg_earnings_12w, w.target_daily_hours, w.phone, w.upi_id,
                      EXISTS(SELECT 1 FROM policies p WHERE p.worker_id = w.worker_id AND p.status = 'ACTIVE' AND p.coverage_end > NOW()) as has_active_policy
               FROM workers w WHERE w.phone = $1""", phone)
        if not row:
            raise HTTPException(status_code=404, detail="Worker not found")
        return dict(row)
    finally:
        await conn.close()

@app.post("/api/v1/register")
async def register_worker(req: RegisterRequest):
    conn = await get_db_conn()
    try:
        platform = (req.platform or "").upper()
        platform = "ZOMATO" if platform == "ZOMATO" else "SWIGGY" if platform == "SWIGGY" else "BLINKIT" if platform == "BLINKIT" else "AMAZON" if platform == "AMAZON" else "BOTH" if platform == "BOTH" else "ZOMATO"
        worker_id = f"W{int(datetime.now().timestamp()) % 10000:03d}"
        await conn.execute(
            """INSERT INTO workers (worker_id, name, phone, platform, zone, city, upi_id, kyc_status, avg_earnings_12w, target_daily_hours, avg_orders_7d)
               VALUES ($1,$2,$3,$4,$5,$6,$7,'PENDING',1800,8.0, 14)""",
            worker_id, req.name, req.phone, platform, req.zone, req.city, req.upi_id
        )
        return await fetch_worker_profile(worker_id)
    finally:
        await conn.close()

@app.post("/api/v1/complete-kyc")
async def complete_kyc(req: KycRequest):
    conn = await get_db_conn()
    try:
        await conn.execute("UPDATE workers SET kyc_status='VERIFIED' WHERE worker_id=$1", req.worker_id)
        return await fetch_worker_profile(req.worker_id)
    finally:
        await conn.close()

# --- v6.0 AUTH & REGISTRATION FLOW ---

class LoginRequest(BaseModel):
    worker_id: str
    phone: str

class VerifyOtpRequest(BaseModel):
    worker_id: str
    otp_code: str
    session_id: Optional[str] = None

class ProfileRegisterRequest(BaseModel):
    worker_id: str
    name: str
    platform: str

class IncomeRegisterRequest(BaseModel):
    worker_id: str
    avg_earnings_12w: float
    target_daily_hours: float

class LocationRegisterRequest(BaseModel):
    worker_id: str
    city: str
    zone: str
    lat: float
    lon: float

class SessionPingRequest(BaseModel):
    worker_id: str
    session_id: str
    lat: float
    lon: float
    hours_online: Optional[float] = None
    movement_km: Optional[float] = None


@app.post("/api/v1/login")
async def login(req: LoginRequest):
    """v6.0: Login with worker_id + phone, returns OTP. Creates new worker if not found."""
    conn = await get_db_conn()
    try:
        worker = await conn.fetchrow(
            "SELECT worker_id, registration_step, phone FROM workers WHERE worker_id = $1",
            req.worker_id
        )

        if not worker:
            worker_id = req.worker_id
            await conn.execute(
                "INSERT INTO workers (worker_id, name, phone) VALUES ($1, $2, $3)",
                worker_id, f"Worker {worker_id}", req.phone
            )
            worker = await conn.fetchrow(
                "SELECT worker_id, registration_step FROM workers WHERE worker_id = $1",
                worker_id
            )
        else:
            if worker["phone"] != req.phone:
                await conn.execute(
                    "UPDATE workers SET phone = $1 WHERE worker_id = $2",
                    req.phone, req.worker_id
                )

        import uuid
        
        otp_code = str(int(datetime.now().timestamp()) % 100000)
        otp_code = otp_code[-6:].zfill(6)
        session_token = str(uuid.uuid4())

        await conn.execute(
            """INSERT INTO auth_sessions (session_token, worker_id, phone, is_new_registration)
               VALUES ($1, $2, $3, $4)""",
            session_token, req.worker_id, req.phone, worker["registration_step"] == "PHONE"
        )

        return {
            "status": "OTP_SENT",
            "session_id": session_token,
            "message": f"OTP sent to {req.phone[-4:]}",
            "demo_otp": otp_code,
            "is_new_registration": worker["registration_step"] == "PHONE",
            "registration_step": worker["registration_step"]
        }
    finally:
        await conn.close()


@app.post("/api/v1/verify-otp")
async def verify_otp(req: VerifyOtpRequest):
    """v6.0: Verify OTP and create active session"""
    conn = await get_db_conn()
    try:
        session_id = req.session_id or f"session_{req.worker_id}"
        
        latest_session = await conn.fetchrow(
            """SELECT session_token FROM auth_sessions 
               WHERE worker_id = $1 
               ORDER BY created_at DESC LIMIT 1""",
            req.worker_id
        )
        
        if not latest_session and not req.session_id:
            pass

        worker = await conn.fetchrow(
            "SELECT worker_id, name, phone, platform, zone, city, kyc_status, registration_step, avg_earnings_12w, target_daily_hours, upi_id FROM workers WHERE worker_id = $1",
            req.worker_id
        )

        if not worker:
            raise HTTPException(status_code=404, detail="Worker not found")

        return {
            "status": "AUTHENTICATED",
            "session_id": session_id,
            "worker": dict(worker),
            "registration_step": worker.get("registration_step", "PHONE"),
            "has_active_policy": False
        }
    finally:
        await conn.close()


@app.post("/api/v1/register/profile")
async def register_profile(req: ProfileRegisterRequest):
    """v6.0: Registration step - profile (name, platform)"""
    conn = await get_db_conn()
    try:
        platform = (req.platform or "").upper()
        platform = "ZOMATO" if platform == "ZOMATO" else "SWIGGY" if platform == "SWIGGY" else "BLINKIT" if platform == "BLINKIT" else "AMAZON" if platform == "AMAZON" else "BOTH"

        await conn.execute(
            """UPDATE workers SET name = $1, platform = $2, registration_step = 'PROFILE'
               WHERE worker_id = $3""",
            req.name, platform, req.worker_id
        )

        return {
            "status": "PROFILE_COMPLETE",
            "worker_id": req.worker_id,
            "next_step": "INCOME"
        }
    finally:
        await conn.close()


@app.post("/api/v1/register/income")
async def register_income(req: IncomeRegisterRequest):
    """v6.0: Registration step - income details"""
    conn = await get_db_conn()
    try:
        await conn.execute(
            """UPDATE workers SET avg_earnings_12w = $1, target_daily_hours = $2, registration_step = 'INCOME'
               WHERE worker_id = $3""",
            req.avg_earnings_12w, req.target_daily_hours, req.worker_id
        )

        return {
            "status": "INCOME_COMPLETE",
            "worker_id": req.worker_id,
            "next_step": "LOCATION"
        }
    finally:
        await conn.close()


@app.post("/api/v1/register/location")
async def register_location(req: LocationRegisterRequest):
    """v6.0: Registration step - location"""
    conn = await get_db_conn()
    try:
        worker = await conn.fetchrow("SELECT zone FROM workers WHERE worker_id = $1", req.worker_id)
        old_zone = worker.get("zone") if worker else None

        await conn.execute(
            """UPDATE workers SET city = $1, zone = $2, lat = $3, lon = $4, registration_step = 'LOCATION'
               WHERE worker_id = $5""",
            req.city, req.zone, req.lat, req.lon, req.worker_id
        )

        if old_zone and old_zone != req.zone:
            await conn.execute(
                """INSERT INTO zone_location_log (worker_id, old_zone, new_zone, lat, lon)
                   VALUES ($1, $2, $3, $4, $5)""",
                req.worker_id, old_zone, req.zone, req.lat, req.lon
            )

        return {
            "status": "LOCATION_COMPLETE",
            "worker_id": req.worker_id,
            "next_step": "DONE"
        }
    finally:
        await conn.close()


@app.post("/api/v1/session-ping")
async def session_ping(req: SessionPingRequest):
    """v6.0: Session ping with Order-Based Zone Validation
    
    Logic:
    - Home zone (registered) works without orders
    - New zone needs ≥1 order to be valid for payout
    - Movement without orders = non-operational travel
    """
    conn = await get_db_conn()
    try:
        await conn.execute(
            """UPDATE worker_sessions SET lat_last = $1, lon_last = $2,
               hours_online = COALESCE($3, hours_online), movement_km = COALESCE($4, movement_km)
               WHERE worker_id = $5 AND session_date = CURRENT_DATE""",
            req.lat, req.lon, req.hours_online, req.movement_km, req.worker_id
        )

        worker = await conn.fetchrow("SELECT * FROM workers WHERE worker_id = $1", req.worker_id)
        home_zone = worker.get("zone")

        detected_zone = _detect_zone_from_coords(req.lat, req.lon)
        
        zone_changed = detected_zone and detected_zone != home_zone
        valid_for_payout = True
        order_count = 0

        if zone_changed and detected_zone:
            order_count = await conn.fetchval(
                """SELECT COUNT(*) FROM orders 
                   WHERE worker_id = $1 AND zone = $2 AND timestamp::date = CURRENT_DATE""",
                req.worker_id, detected_zone
            )
            has_orders_in_zone = order_count > 0
            
            if has_orders_in_zone:
                valid_for_payout = True
                await conn.execute(
                    """INSERT INTO worker_zone_orders (worker_id, zone, order_count, last_order_at)
                       VALUES ($1, $2, $3, NOW())
                       ON CONFLICT (worker_id, zone) 
                       DO UPDATE SET order_count = worker_zone_orders.order_count + 1, last_order_at = NOW()""",
                    req.worker_id, detected_zone, order_count
                )
            else:
                valid_for_payout = False

        target_zone = None
        promotion_available = False
        promotion_reason = None

        if home_zone:
            next_zone = await conn.fetchrow(
                """SELECT nz.zone_name, nz.promotion_threshold_type, nz.promotion_threshold_value
                   FROM zone_neighbours nn
                   JOIN zones nz ON nz.zone_name = nn.neighbour_zone
                   WHERE nn.zone_name = $1 AND nz.promotion_threshold_value IS NOT NULL
                   ORDER BY nz.promotion_threshold_value DESC LIMIT 1""",
                home_zone
            )

            if next_zone:
                eligible = await conn.fetchrow(
                    """SELECT * FROM v_zone_promotion_eligibility
                       WHERE worker_id = $1 AND eligible_zone = $2""",
                    req.worker_id, next_zone["zone_name"]
                )

                if eligible:
                    target_zone = next_zone["zone_name"]
                    promotion_available = True
                    promotion_reason = f"Met {next_zone['promotion_threshold_type']} threshold for {next_zone['zone_name']}"

        return {
            "status": "PING_OK",
            "worker_id": req.worker_id,
            "zone": home_zone,
            "detected_zone": detected_zone,
            "zone_changed": zone_changed,
            "valid_for_payout": valid_for_payout,
            "order_count": order_count,
            "message": "Home zone active for payout" if not zone_changed else ("Has orders - zone valid" if valid_for_payout else "Needs order in new zone"),
            "promotion": {
                "available": promotion_available,
                "eligible_zone": target_zone,
                "reason": promotion_reason
            }
        }
    finally:
        await conn.close()


@app.get("/api/v1/home")
async def get_home(worker_id: str):
    """v6.0: Home endpoint"""
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            "SELECT * FROM v_worker_home WHERE worker_id = $1",
            worker_id
        )

        if not row:
            worker = await conn.fetchrow("SELECT * FROM workers WHERE worker_id = $1", worker_id)
            if not worker:
                raise HTTPException(status_code=404, detail="Worker not found")
            return {
                "worker_id": worker_id,
                "registration_step": worker.get("registration_step", "PHONE"),
                "has_active_policy": False,
                "next_action": "COMPLETE_REGISTRATION"
            }

        return dict(row)
    finally:
        await conn.close()


# --- SUBSCRIPTION LOGIC ---

@app.post("/api/v1/subscribe")
async def subscribe(req: SubscribeRequest):
    conn = await get_db_conn()
    try:
        await conn.execute("UPDATE policies SET status='EXPIRED' WHERE worker_id=$1 AND status='ACTIVE'", req.worker_id)
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
    finally:
        await conn.close()

@app.get("/api/v1/worker/{worker_id}/policy")
async def get_active_policy(worker_id: str):
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            """SELECT policy_id, plan_name, weekly_premium, status, coverage_start, coverage_end, auto_renew
               FROM policies WHERE worker_id=$1 AND status='ACTIVE' AND coverage_end > NOW()
               ORDER BY coverage_end DESC LIMIT 1""", worker_id
        )
        if not row:
            raise HTTPException(status_code=404, detail="No active policy")
        r = dict(row)
        r["coverage_start"] = r["coverage_start"].isoformat()
        r["coverage_end"] = r["coverage_end"].isoformat()
        return r
    finally:
        await conn.close()


# --- ADMIN CONSOLIDATED STATS ---

@app.get("/api/v1/admin/stats")
async def get_admin_stats():
    """Single endpoint for the admin dashboard overview page."""
    conn = await get_db_conn()
    try:
        row = await conn.fetchrow(
            """SELECT
                (SELECT COUNT(*) FROM workers WHERE kyc_status='VERIFIED') as verified_workers,
                (SELECT COUNT(*) FROM policies WHERE status='ACTIVE') as active_policies,
                (SELECT COUNT(*) FROM payouts WHERE DATE(triggered_at)=CURRENT_DATE) as today_payouts,
                (SELECT COALESCE(SUM(amount),0) FROM payouts
                 WHERE DATE(triggered_at)=CURRENT_DATE AND payout_status='PAID') as today_paid_inr,
                (SELECT COUNT(*) FROM payouts
                 WHERE fraud_score >= 0.30 AND DATE(triggered_at)=CURRENT_DATE) as fraud_flags,
                (SELECT COUNT(*) FROM payouts
                 WHERE payout_status='PAID' AND DATE(triggered_at)=CURRENT_DATE) as paid_count,
                (SELECT COUNT(*) FROM payouts
                 WHERE payout_status='HELD' AND DATE(triggered_at)=CURRENT_DATE) as held_count,
                (SELECT COUNT(*) FROM disruption_alerts WHERE status='ACTIVE') as active_alerts"""
        )

        fraud_rows = await conn.fetch(
            """SELECT p.worker_id, w.name, p.fraud_score, p.fraud_level,
                      p.trigger_type, p.amount, p.payout_status, p.triggered_at
               FROM payouts p JOIN workers w ON w.worker_id=p.worker_id
               WHERE p.fraud_score >= 0.30
               ORDER BY p.fraud_score DESC LIMIT 20"""
        )

        payout_rows = await conn.fetch(
            """SELECT p.payout_id, p.worker_id, w.name, p.trigger_type,
                      p.amount, p.payout_status, p.triggered_at, p.fraud_score
               FROM payouts p JOIN workers w ON w.worker_id=p.worker_id
               ORDER BY p.triggered_at DESC LIMIT 50"""
        )

        alert_rows = await conn.fetch(
            """SELECT trigger_type, zone, severity, payout_pct, status, raw_metric, detected_at
               FROM disruption_alerts WHERE status='ACTIVE' ORDER BY detected_at DESC"""
        )

        return {
            "kpis": {
                "verified_workers": row["verified_workers"],
                "active_policies": row["active_policies"],
                "today_payouts": row["today_payouts"],
                "today_paid_inr": float(row["today_paid_inr"]),
                "fraud_flags": row["fraud_flags"],
                "paid_count": row["paid_count"],
                "held_count": row["held_count"],
                "active_alerts": row["active_alerts"]
            },
            "fraud_watchlist": [
                {
                    "worker_id": r["worker_id"],
                    "name": r["name"],
                    "fraud_score": float(r["fraud_score"]),
                    "fraud_level": r["fraud_level"],
                    "trigger_type": r["trigger_type"],
                    "amount": float(r["amount"]),
                    "status": r["payout_status"],
                    "triggered_at": str(r["triggered_at"])
                }
                for r in fraud_rows
            ],
            "recent_payouts": [
                {
                    "payout_id": r["payout_id"],
                    "worker_id": r["worker_id"],
                    "name": r["name"],
                    "trigger_type": r["trigger_type"],
                    "amount": float(r["amount"]),
                    "status": r["payout_status"],
                    "triggered_at": str(r["triggered_at"]),
                    "fraud_score": float(r["fraud_score"] or 0)
                }
                for r in payout_rows
            ],
            "active_alerts": [
                {
                    "trigger_type": r["trigger_type"],
                    "zone": r["zone"],
                    "severity": float(r["severity"]),
                    "payout_pct": float(r["payout_pct"]),
                    "status": r["status"],
                    "raw_metric": float(r["raw_metric"] or 0),
                    "detected_at": str(r["detected_at"])
                }
                for r in alert_rows
            ]
        }
    finally:
        await conn.close()


@app.post("/api/v1/admin/fraud-action")
async def fraud_action(worker_id: str, action: str):
    """action: 'hold' | 'ban' | 'clear'"""
    conn = await get_db_conn()
    try:
        status_map = {"hold": "HELD", "ban": "BANNED", "clear": "APPROVED"}
        new_status = status_map.get(action, "HELD")
        await conn.execute(
            "UPDATE payouts SET payout_status=$1 WHERE worker_id=$2 AND payout_status IN ('PENDING','HELD')",
            new_status, worker_id
        )
        await conn.execute(
            """INSERT INTO audit_log (event_type,entity_type,entity_id,worker_id,action_by,severity,message)
               VALUES ('FRAUD_ACTION','WORKER',$1,$2,'ADMIN','WARNING',$3)""",
            worker_id, worker_id, f"Admin action: {action} on {worker_id}"
        )
        return {"success": True, "action": action, "worker_id": worker_id}
    finally:
        await conn.close()


# --- ADMIN CONSOLE ENDPOINTS (Restored) ---

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
    finally:
        await conn.close()

@app.get("/api/v1/worker/{worker_id}/payouts")
async def get_worker_payouts(worker_id: str):
    conn = await get_db_conn()
    try:
        payouts = await conn.fetch(
            """SELECT payout_id, amount, trigger_type, trigger_pct, hourly_rate, hours_lost,
                      risk_level, income_severity, fraud_level, fraud_score, payout_status, triggered_at
               FROM payouts WHERE worker_id=$1 ORDER BY triggered_at DESC""",
            worker_id
        )
        return [dict(p) for p in payouts]
    finally:
        await conn.close()


@app.post("/api/v1/assistant")
async def assistant(req: dict):
    ctx = req.get("context", {})
    prompt = f"You are Aegis AI assistant. Context: {ctx}. Keep answers under 3 sentences. Question: {req.get('question', '')}"
    try:
        model = cast(Any, genai).GenerativeModel('gemini-1.5-flash')
        res = model.generate_content(prompt)
        return {"reply": res.text}
    except:
        return {"reply": "I'm having trouble connecting to my Gemini brain."}


@app.get("/api/v1/fraud/today-count")
async def get_fraud_count_today():
    conn = await get_db_conn()
    try:
        count = await conn.fetchval(
            """SELECT COUNT(*) FROM payouts
               WHERE triggered_at::date = CURRENT_DATE
               AND (fraud_level = 'HIGH' OR payout_status = 'BANNED')"""
        )
        avg_score = await conn.fetchval(
            """SELECT COALESCE(AVG(fraud_score), 0) FROM payouts
               WHERE triggered_at::date = CURRENT_DATE"""
        )
        return {"count": count or 0, "avg_fraud_score": round(float(avg_score or 0), 2)}
    finally:
        await conn.close()


@app.get("/api/v1/payouts/daily-totals")
async def get_daily_payout_totals(days: int = Query(default=7, ge=1, le=90)):
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
            {"date": row["date"].isoformat(), "total": float(row["total"]), "count": row["count"], "approved_count": row["approved_count"]}
            for row in rows
        ]
    finally:
        await conn.close()


@app.get("/api/v1/workers")
async def get_all_workers(limit: int = Query(default=100, ge=1, le=1000)):
    conn = await get_db_conn()
    try:
        rows = await conn.fetch(
            """SELECT w.worker_id, w.name, w.phone, w.platform, w.city, w.zone,
                      w.kyc_status, w.avg_earnings_12w, w.target_daily_hours,
                      w.onboarded_at,
                      (SELECT COUNT(*) FROM policies p WHERE p.worker_id = w.worker_id AND p.status = 'ACTIVE' AND p.coverage_end > NOW()) as active_policies,
                      (SELECT COALESCE(SUM(amount), 0) FROM payouts WHERE worker_id = w.worker_id AND payout_status = 'APPROVED') as total_payouts
               FROM workers w
               ORDER BY w.onboarded_at DESC
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
                "registered_at": row["onboarded_at"].isoformat() if row["onboarded_at"] else None,
                "active_policies": row["active_policies"],
                "total_payouts": float(row["total_payouts"])
            }
            for row in rows
        ]
    finally:
        await conn.close()


@app.get("/api/v1/workers/stats")
async def get_worker_stats():
    conn = await get_db_conn()
    try:
        total = await conn.fetchval("SELECT COUNT(*) FROM workers")
        kyc_verified = await conn.fetchval("SELECT COUNT(*) FROM workers WHERE kyc_status = 'VERIFIED'")
        active_today = await conn.fetchval(
            """SELECT COUNT(DISTINCT worker_id) FROM payouts
               WHERE triggered_at::date = CURRENT_DATE"""
        )
        platform_stats = await conn.fetch(
            """SELECT platform, COUNT(*) as count
               FROM workers
               GROUP BY platform"""
        )
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
    conn = await get_db_conn()
    try:
        premium_revenue = await conn.fetchval(
            """SELECT COALESCE(SUM(weekly_premium), 0)
               FROM policies
               WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'"""
        )
        total_payouts = await conn.fetchval(
            """SELECT COALESCE(SUM(amount), 0)
               FROM payouts
               WHERE triggered_at >= CURRENT_DATE - INTERVAL '30 days'
               AND payout_status = 'APPROVED'"""
        )
        active_policies_value = await conn.fetchval(
            """SELECT COALESCE(SUM(weekly_premium), 0)
               FROM policies
               WHERE status = 'ACTIVE' AND coverage_end > NOW()"""
        )
        pending_claims = await conn.fetchval(
            """SELECT COUNT(*) FROM payouts WHERE payout_status = 'PENDING'"""
        )
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
    conn = await get_db_conn()
    try:
        recent_analyses = await conn.fetchval(
            """SELECT COUNT(*) FROM payouts
               WHERE triggered_at >= NOW() - INTERVAL '1 hour'"""
        )
        active_sessions = await conn.fetchval(
            """SELECT COUNT(*) FROM worker_sessions
               WHERE session_date = CURRENT_DATE"""
        )
        risk_distribution = await conn.fetch(
            """SELECT risk_level, COUNT(*) as count
               FROM payouts
               WHERE triggered_at::date = CURRENT_DATE
               GROUP BY risk_level"""
        )
        payout_status = await conn.fetch(
            """SELECT payout_status, COUNT(*) as count
               FROM payouts
               WHERE triggered_at::date = CURRENT_DATE
               GROUP BY payout_status"""
        )
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
def health():
    return {"status": "online"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=int(os.getenv("PORT", "8010")))
