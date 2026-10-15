# SoilGood

IoT and AI-assisted Flutter app for real-time soil monitoring, weather-aware decisions, AI recommendations, and historical analytics for farmers.

## Documentation (read these first)

### Context
- [PROJECT_OVERVIEW.md](docs/context/PROJECT_OVERVIEW.md)
- [SYSTEM_FLOWCHART.md](docs/context/SYSTEM_FLOWCHART.md) — master Mermaid process maps
- [FEATURES.md](docs/context/FEATURES.md)
- [ARCHITECTURE.md](docs/context/ARCHITECTURE.md)
- [BACKEND.md](docs/context/BACKEND.md)
- [DATA_MODEL.md](docs/context/DATA_MODEL.md)
- [SECURITY.md](docs/context/SECURITY.md)
- [UI_THEME.md](docs/context/UI_THEME.md)
- Supabase SQL: [docs/context/supabase_schema.sql](docs/context/supabase_schema.sql)

### Pages
- Template: [docs/pages/_TEMPLATE.md](docs/pages/_TEMPLATE.md)
- Admin Devices (web): [docs/pages/admin_devices.md](docs/pages/admin_devices.md)
- Admin Analytics (web ops): [docs/pages/admin_analytics.md](docs/pages/admin_analytics.md)
- Lab Flasher (Windows USB): [docs/pages/lab_flasher.md](docs/pages/lab_flasher.md) · app: [tooling/lab_flasher](tooling/lab_flasher)

## Run

```bash
flutter pub get
flutter run
```

Lab Flasher (Windows, admin USB station):

```bash
cd tooling/lab_flasher
copy .env.example .env   # add SUPABASE_* + WIFI_*
flutter pub get
flutter run -d windows
```

## Stack

- Flutter 3.38+ / Dart 3.10+
- Supabase (Free) + Edge Function `soilgood-insights` (Groq) + prefer free APIs
- Platforms: Android, iOS, Web
- Package name: `soil_sense` (technical); display name: **SoilGood**
