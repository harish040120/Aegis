"""
fraud_enhanced.py
Post-model rule layer for delivery-specific fraud detection.
Called after fraud_model.pkl scores the base signals.
Returns adjusted fraud_score and a list of triggered rules.
"""

def apply_delivery_fraud_rules(base_fraud_score: float, features: dict) -> dict:
    """
    features dict keys expected:
    - hours_worked_today: float (from session)
    - orders_today: int (from orders table today)
    - movement_km: float (from worker_sessions)
    - claim_velocity: int (claims from same zone in last 15min)
    - rain_1h: float (from weather API)
    - gps_consistency_score: float (0-1, from ML model input)
    - order_history_presence: bool
    """
    rules_triggered = []
    adjusted_score = base_fraud_score

    # Rule 1: GPS spoofing pattern
    # Real delivery worker in 42mm rain has movement.
    # Perfect GPS static + high rain claim = spoofing.
    if (features.get('rain_1h', 0) > 20 and
        features.get('movement_km', 99) < 0.5 and
        features.get('hours_worked_today', 0) > 3):
        adjusted_score = max(adjusted_score, 0.45)
        rules_triggered.append("GPS_STATIC_DURING_DISRUPTION")

    # Rule 2: No orders in zone before disruption window
    # Spoofers open the app only when a disruption is declared.
    if (not features.get('order_history_presence', True) and
        features.get('rain_1h', 0) > 15):
        adjusted_score = max(adjusted_score, 0.40)
        rules_triggered.append("NO_ORDERS_BEFORE_DISRUPTION")

    # Rule 3: Coordinated ring detection
    # >20 claims from same zone in 15 minutes = coordinated fraud
    if features.get('claim_velocity', 0) > 20:
        adjusted_score = max(adjusted_score, 0.65)
        rules_triggered.append("HIGH_CLAIM_VELOCITY_RING")

    # Rule 4: Income paradox
    # Claims severe income loss but had normal order count
    if (features.get('orders_today', 0) > 8 and
        features.get('hours_worked_today', 0) > 6):
        # Worker was actually active - income drop claim is suspicious
        adjusted_score = max(adjusted_score, 0.35)
        rules_triggered.append("ACTIVE_WORKER_INCOME_CLAIM")

    # Rule 5: Historical GPS anchor mismatch
    # Worker's zone in DB doesn't match claimed GPS zone
    # (This fires when zone from DB != zone detected from lat/lon)
    # Passed in as a pre-computed flag
    if features.get('zone_mismatch', False):
        adjusted_score = max(adjusted_score, 0.50)
        rules_triggered.append("ZONE_MISMATCH_DETECTED")

    return {
        "adjusted_fraud_score": round(adjusted_score, 4),
        "base_fraud_score": round(base_fraud_score, 4),
        "rules_triggered": rules_triggered,
        "fraud_level": _score_to_level(adjusted_score)
    }


def _score_to_level(score: float) -> str:
    if score < 0.30: return "LOW"
    if score < 0.50: return "MODERATE"
    if score < 0.70: return "SUSPICIOUS"
    if score < 0.85: return "HIGH"
    return "CRITICAL"
