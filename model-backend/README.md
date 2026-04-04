# 🛡️ Model Backend - ML Pipeline & API Server

## Overview

The Model Backend is a Python FastAPI application that handles:
1. **ML Inference**: Runs GradientBoosting models for risk, income, and fraud detection
2. **Business Logic**: Parametric payout calculation, policy management
3. **AI Assistant**: Integration with Google Gemini for contextual help

## Files

```
model-backend/backend/
├── .env                  # Environment variables (API keys, DB URL)
├── main.py               # FastAPI application
├── requirements.txt      # Python dependencies
├── README.md             # This file
├── risk_model.pkl        # Risk classification model
├── risk_regressor.pkl    # Risk score regressor
├── income_model.pkl      # Income drop prediction model
└── fraud_model.pkl       # Fraud detection model
```

## Configuration

Create a `.env` file with:

```
GOOGLE_API_KEY=your_google_gemini_api_key
DATABASE_URL=postgresql://user:password@host:port/database
DATA_HUB_URL=http://localhost:3015/api/risk-data
PORT=8010
```

## API Keys

- **Google Gemini**: Get from https://aistudio.google.com/app/apikey

## Running

```bash
cd model-backend/backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8010
```

Server runs on port 8010 (or PORT from .env).

## Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/analyze` | POST | Main trigger - run parametric analysis |
| `/api/v1/register` | POST | Register new worker |
| `/api/v1/subscribe` | POST | Purchase/renew policy |
| `/api/v1/worker/{id}/payouts` | GET | Get payout history |
| `/api/v1/assistant` | POST | AI Assistant (Gemini) |
| `/health` | GET | Health check |

## ML Models

1. **Risk Model**: Predicts environmental risk level (LOW/MEDIUM/HIGH/CRITICAL)
2. **Income Model**: Predicts income drop percentage and severity
3. **Fraud Model**: Detects suspicious activity patterns

## Database

PostgreSQL database at port 2003 containing:
- workers (worker profiles)
- orders (delivery transactions)
- policies (insurance subscriptions)
- payouts (disbursement records)
- worker_sessions (daily activity)
- audit_log (system events)

## Trigger Logic

When a worker triggers analysis:
1. Check active policy exists
2. Fetch environmental data from Data Hub
3. Fetch worker profile and today's activity
4. Run ML models (Risk → Income → Fraud)
5. Evaluate triggers (Heavy Rain >45mm, AQI >120, Income Drop >45%)
6. Calculate payout using highest trigger
7. Save to database and return to app