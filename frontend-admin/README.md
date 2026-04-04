# 🛡️ Admin Dashboard - React Enterprise Console

## Overview

The Admin Dashboard is a React 19 application that provides:
1. **System Overview**: KPIs, charts, real-time statistics
2. **Worker Management**: View and manage registered workers
3. **Payout Monitoring**: Live payout ledger and history
4. **Fraud Detection**: High-risk worker alerts and management
5. **Scenario Simulation**: Test environmental triggers via Data Hub

## Files

```
frontend-admin/
├── package.json          # Dependencies
├── vite.config.ts        # Vite configuration
├── index.html            # HTML template
├── README.md             # This file
├── public/               # Static assets
│   ├── logo.png
│   ├── main_logo.png
│   └── favicon.svg
└── src/
    ├── App.tsx           # Main router and sidebar
    ├── index.css         # Global styles
    ├── main.tsx          # React entry point
    ├── pages/            # Dashboard pages
    │   ├── SystemOverview.tsx
    │   ├── Workers.tsx
    │   ├── Payouts.tsx
    │   ├── Triggers.tsx
    │   ├── Fraud.tsx
    │   └── ...
    └── services/         # API integrations
```

## Running

```bash
cd frontend-admin
npm install
npm run dev -- --port 2000
```

Dashboard runs on port 2000.

## Navigation

- **1. System**: Overview, Workers, Financials
- **2. Operations**: Triggers, AI Predictions, Fraud, Payouts
- **3. Admin**: Policy Controls

## API Integration

The dashboard connects to the Model Backend (Python) at port 8010 for:
- Worker data
- Payout statistics
- Policy management
- Fraud alerts

And to the Data Hub (Node.js) at port 3015 for:
- Scenario simulation

## Tech Stack

- React 19
- Vite
- Tailwind CSS v4
- Lucide React (icons)
- TypeScript