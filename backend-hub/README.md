# 🛡️ Data Hub - Environmental Data & Scenario Simulation

## Overview

The Data Hub is a Node.js/Express server that provides:
1. Real-time weather and air quality data from external APIs
2. Scenario simulation for testing different environmental conditions
3. Geospatial zone detection for workers

## Files

```
backend-hub/
├── .env                  # Environment variables (API keys, DB config)
├── package.json          # Node.js dependencies
├── server.js             # Main Express application
├── README.md             # This file
└── public/               # Static files
    ├── index.html        # Scenario simulation UI
    └── script.js         # Client-side logic
```

## Configuration

Create a `.env` file with:

```
WEATHER_API_KEY=your_openweathermap_api_key
WAQI_API_KEY=your_waqi_api_key
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your_supabase_anon_or_publishable_key
PORT=3015
```

## API Keys

- **OpenWeatherMap**: Get from https://openweathermap.org/api
- **WAQI**: Get from https://aqicn.org/data-api/token/

## Running

```bash
cd backend-hub
npm install
node server.js
```

Server runs on port 3015 (or PORT from .env).

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/risk-data` | GET | Get environmental risk data |
| `/api/scenario` | POST | Apply scenario simulation |
| `/api/params` | GET/POST | Get/set simulation parameters |

## Scenarios

Available scenarios for testing:
- `normal` - Regular conditions
- `light_rain` - Light rainfall
- `heavy_rain` - Heavy rainfall
- `severe_flood` - Flood conditions
- `hazardous_aqi` - Poor air quality
- `gps_fraud` - GPS anomaly detection

## Database

Connects to PostgreSQL to fetch worker baseline data (earnings, zone, etc.).
