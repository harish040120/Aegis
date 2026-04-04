# 🛡️ AEGIS AIOS - Parametric Insurance Platform

## Overview

Aegis AIOS is a high-density, parametric intelligence operating system for gig-worker insurance. It integrates real-time environmental sensors, behavioral forensics, and GradientBoosting ML models to automate financial protection for gig workers.

## Project Structure

```
/aegis/
├── backend-hub/              # Node.js Data Orchestration Server (Port 3015)
│   ├── .env                  # API keys and database configuration
│   ├── package.json
│   ├── server.js             # Main Express server
│   └── public/               # UI for scenario simulation
│
├── model-backend/            # Python ML Pipeline & API Server (Port 8010)
│   └── backend/
│       ├── .env              # API keys and database configuration
│       ├── main.py           # FastAPI application with ML logic
│       ├── requirements.txt  # Python dependencies
│       └── *.pkl             # Pre-trained ML models
│
├── frontend-admin/           # React Admin Dashboard (Port 2000)
│   ├── package.json
│   ├── src/
│   │   ├── App.tsx           # Main router and sidebar
│   │   ├── pages/            # Dashboard pages
│   │   └── services/          # API integrations
│   └── public/               # Static assets
│
├── Flutter/                  # Mobile Application
│   ├── lib/
│   │   ├── main.dart         # App entry point
│   │   ├── providers/       # State management
│   │   ├── screens/          # UI screens
│   │   ├── services/         # API services
│   │   └── models/           # Data models
│   └── pubspec.yaml
│
├── init_db.sql               # PostgreSQL database schema
├── seed_workers.sql          # Sample worker data
├── seed_data_phase2.sql      # Additional seed data
├── seed_earnings.sql         # Earnings data
├── add_audit_log.sql         # Audit log table
├── cleanup_db.sql            # Database cleanup scripts
└── .env                      # Main environment configuration
```

## Architecture

| Layer | Port | Technology | Purpose |
|-------|------|------------|---------|
| Admin Console | 2000 | React 19, Tailwind v4 | Enterprise dashboard |
| Data Hub | 3015 | Node.js, Express | Environmental data & scenario simulation |
| ML Pipeline | 8010 | Python, FastAPI | ML inference & business logic |
| Database | 2003 | PostgreSQL | Persistent storage |

## Tech Stack

- **Mobile**: Flutter (Dart)
- **Backend Hub**: Node.js, Express
- **ML Pipeline**: Python, FastAPI, scikit-learn
- **Admin**: React 19, Vite, Tailwind CSS
- **Database**: PostgreSQL

## Quick Start

### 1. Start Database
```bash
docker start aegis-db
```

### 2. Initialize Database
```bash
cat init_db.sql seed_workers.sql | docker exec -i aegis-db psql -U aegis_admin -d aegis_intelligence
```

### 3. Configure API Keys
Edit each `.env` file:
- `backend-hub/.env` - Weather & WAQI API keys
- `model-backend/backend/.env` - Google Gemini API key
- `Flutter/.env` (if created) - Server URLs

### 4. Start Data Hub (Node.js)
```bash
cd backend-hub && node server.js
```

### 5. Start ML Pipeline (Python)
```bash
cd model-backend/backend && uvicorn main:app --host 0.0.0.0 --port 8010
```

### 6. Start Admin Dashboard (React)
```bash
cd frontend-admin && npm run dev -- --port 2000
```

### 7. Run Mobile App (Flutter)
```bash
cd Flutter && flutter run -d linux
```

## Key Features

1. **Parametric Payouts**: Automated payout calculation based on environmental triggers
2. **ML-Powered Fraud Detection**: GradientBoosting models for risk, income, and fraud assessment
3. **Real-time Environmental Data**: Integration with OpenWeatherMap and WAQI
4. **Scenario Simulation**: Test different environmental conditions via admin dashboard
5. **Mobile App**: Workers can trigger analysis and view payout history

## Security Notes

- All API keys are stored in `.env` files (not committed to version control)
- Database credentials should be changed in production
- The Flutter app uses localhost URLs for development - change for production deployment
- CORS is currently open (`allow_origins=["*"]`) - restrict in production