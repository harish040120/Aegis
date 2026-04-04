# 🛡️ Flutter Mobile Application

## Overview

The Flutter mobile app provides gig workers with:
1. **Onboarding**: Registration and KYC verification
2. **Plan Selection**: Choose insurance coverage plan
3. **Dashboard**: Trigger parametric analysis and view results
4. **Payouts**: View payout history
5. **AI Assistant**: Chat with Aegis AI for insurance help

## Files

```
Flutter/
├── pubspec.yaml              # Flutter configuration
├── README.md                 # This file
├── lib/
│   ├── main.dart             # App entry point
│   ├── theme/                # App theming
│   │   ├── app_theme.dart
│   │   └── theme.dart
│   ├── providers/            # State management
│   │   └── aegis_provider.dart
│   ├── screens/              # UI screens
│   │   ├── splash_screen.dart
│   │   ├── onboarding_screen.dart
│   │   ├── plan_screen.dart
│   │   ├── home_screen.dart
│   │   ├── dashboard_tab.dart
│   │   ├── payouts_tab.dart
│   │   ├── alerts_tab.dart
│   │   ├── coverage_tab.dart
│   │   ├── profile_screen.dart
│   │   └── chat_screen.dart
│   ├── services/             # API services
│   │   ├── api_service.dart
│   │   ├── location_service.dart
│   │   ├── risk_engine.dart
│   │   ├── chat_service.dart
│   │   └── notification_service.dart
│   ├── models/               # Data models
│   │   └── models.dart
│   └── widgets/              # Reusable widgets
│       ├── aegis_appbar.dart
│       ├── aegis_card.dart
│       ├── common_widgets.dart
│       └── fade_in.dart
├── linux/                    # Linux build files
├── android/                  # Android build files
└── ios/                     # iOS build files
```

## Running

```bash
cd Flutter
flutter pub get
flutter run -d linux
```

For other platforms:
```bash
flutter run -d android  # Android
flutter run -d ios     # iOS
```

## API Configuration

The app connects to:
- **Model Backend** (Python): Port 8010 - Main API
- **Data Hub** (Node.js): Port 3015 - Environmental data

Update in `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://localhost:8010';
static const String hubUrl = 'http://localhost:3015';
```

## Key Screens

1. **Splash Screen**: App loading with logo
2. **Onboarding**: Worker registration
3. **Plan**: Select insurance coverage
4. **Home**: Main container with bottom navigation
   - Dashboard: Trigger analysis button
   - Alerts: Notifications
   - Coverage: View active policy
   - Payouts: View payout history
5. **Chat**: AI Assistant conversation

## State Management

Uses `ChangeNotifierProvider` with `AegisProvider` for:
- Authentication state
- Worker profile
- Active policy
- Location tracking
- KYC status

## Tech Stack

- Flutter 3.x
- Provider (state management)
- http package (API calls)
- Google Fonts (typography)