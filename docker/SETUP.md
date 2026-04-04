# 🛡️ AEGIS AIOS - Complete Setup Guide

## Prerequisites

Install Docker on your machine:
- **Windows/Mac**: Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
- **Linux**: `sudo apt install docker.io && sudo systemctl start docker`

---

## Quick Start (Backend + Frontend Only)

### Step 1: Get the Code
```bash
# Clone or copy the aegis folder to your machine
cd aegis/docker
```

### Step 2: Configure Environment (Optional)
```bash
# Copy environment file
cp .env.example .env

# Add your API keys (optional - works with demo keys)
# Get free keys from:
# - OpenWeatherMap: https://openweathermap.org/api
# - WAQI: https://aqicn.org/data-api/token/
# - Google Gemini: https://aistudio.google.com/app/apikey
```

### Step 3: Run All Services
```bash
docker compose up -d --build
```

### Step 4: Verify
```bash
docker compose ps
```

### Step 5: Access Services

| Service | URL |
|---------|-----|
| Admin Dashboard | http://localhost:2000 |
| API Documentation | http://localhost:8010/docs |
| Data Hub API | http://localhost:3015/api/risk-data |

---

## Service Details

| Service | Container | Port | Technology |
|---------|-----------|------|------------|
| PostgreSQL | aegis-db | 2003 | Database |
| Data Hub | aegis-backend-hub | 3015 | Node.js |
| Model Backend | aegis-model-backend | 8010 | Python/FastAPI |
| Admin Dashboard | aegis-admin-dashboard | 2000 | React |

---

## Flutter Mobile App (Web)

The Flutter app requires native SDK and runs **locally** (not in Docker).

### Option 1: Run Flutter Locally

```bash
# 1. Install Flutter SDK
# Download from: https://docs.flutter.dev/get-started/install

# 2. Navigate to Flutter folder
cd aegis/Flutter

# 3. Update API URL to connect to Docker backend
# Edit lib/services/api_service.dart
# Change the URLs to point to your Docker host IP:
# baseUrl = 'http://192.168.x.x:8010'
# hubUrl = 'http://192.168.x.x:3015'

# 4. Build and run
flutter pub get
flutter run -d linux
```

### Option 2: Build Flutter Web & Serve

```bash
cd aegis/Flutter

# Update API URLs first
nano lib/services/api_service.dart

# Build for web
flutter build web --release

# Serve the built files
# You can use any web server, e.g., Python:
cd build/web
python3 -m http.server 8080

# Or use nginx - copy build/web/* to nginx html folder
```

### Option 3: Connect Flutter to Docker

Edit `Flutter/lib/services/api_service.dart`:
```dart
class ApiService {
  // Change to your Docker host IP (e.g., 192.168.1.100)
  static String get baseUrl => 'http://YOUR_IP:8010';
  static String get hubUrl => 'http://YOUR_IP:3015';
}
```

Then run locally:
```bash
flutter run -d linux
```

---

## Useful Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Stop and remove data volumes
docker compose down -v

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f backend-hub
docker compose logs -f model-backend

# Rebuild specific service
docker compose up -d --build backend-hub
```

---

## Access from Other Devices

Use your machine's IP instead of localhost:

```bash
# Find your IP
hostname -I | awk '{print $1}'

# Then access:
# http://192.168.x.x:2000   (Admin)
# http://192.168.x.x:8010   (API)
# http://192.168.x.x:3015   (Data Hub)
```

---

## Troubleshooting

### Port Already in Use
```bash
lsof -i :2003 -i :3015 -i :8010 -i :2000
kill <PID>
```

### Database Not Connected
```bash
docker compose logs database
docker compose down -v
docker compose up -d
```

### API Not Working
```bash
docker compose logs model-backend
```

---

## Default Data

The database comes pre-seeded with 5 workers:

| ID | Name | Platform | Zone |
|----|------|----------|------|
| W001 | Shiva Kumar | ZOMATO | Chennai-Central |
| W002 | Anand Rajan | SWIGGY | Chennai-South |
| W003 | Karthik Selvan | ZOMATO | Chennai-North |
| W004 | Murugan Pillai | BOTH | Chennai-East |
| W005 | Priya Lakshmi | SWIGGY | Coimbatore-Central |

---

## Quick Test Commands

```bash
# Test Data Hub
curl http://localhost:3015/api/risk-data

# Test API Health
curl http://localhost:8010/health

# Test Admin
curl http://localhost:2000 | head -c 100
```

---

## System Requirements

- **RAM**: 4GB minimum (8GB recommended)
- **Disk**: 10GB free space
- **OS**: Windows 10+, macOS 10.15+, Ubuntu 20.04+