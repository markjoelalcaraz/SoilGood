# Graph Report - Elect4  (2026-08-24)

## Corpus Check
- 118 files · ~56,306 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1527 nodes · 1916 edges · 104 communities (99 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `96633067`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- crops_page.dart
- login_page.dart
- home_page.dart
- profile_onboarding_page.dart
- notifications_page.dart
- daily_soil_bucket.dart
- soil_reading.dart
- farm_notification.dart
- location_onboarding_page.dart
- device_onboarding_page.dart
- crop_catalog.dart
- app_shell.dart
- analytics_page.dart
- .application
- ui_primitives.dart
- day_readings_page.dart
- auth_scaffold.dart
- app_env.dart
- manifest.json
- MainActivity.kt
- @example
- SoilGood — Data Model
- planting.dart
- Page: Signup & Onboarding
- crop_match.dart
- Page: Home Dashboard
- SoilGood — Backend
- SoilGood — Project Overview
- Checklist
- Page: \<Page Name\>
- SoilGood — Architecture
- SoilGood — Features to Implement
- SoilGood — UI Theme
- crop_plan_page.dart
- app_colors.dart
- package:google_fonts/google_fonts.dart
- auth_primary_button.dart
- period_assessment.dart
- crop_band_classify.dart
- SoilGood
- StatelessWidget
- manila_time.dart
- soilgood_heartbeat/README.md
- LaunchImage.imageset/README.md
- analytics_period.dart
- SoilGood — AI insights config
- CustomPainter
- auth_text_field.dart
- auth_gate.dart
- API Integration — Open-Meteo Weather
- analytics_filters.dart
- String?
- app_validators.dart
- app_content_width.dart
- index.ts
- profile_page.dart
- crop_timeline.dart
- analytics_stats.dart
- weather_models.dart
- crops_care_ai_client.dart
- notification_controller.dart
- insights_config.dart
- List
- home_ai_story.dart
- Page: Notifications
- NotificationController
- main.dart
- SoilGood — Crop ranges (research v1)
- ai_json_parse.dart
- signup_page.dart
- farm_location_repository.dart
- password_rules_checklist.dart
- Page: Analytics
- soil_history_repository.dart
- soil_readings_repository.dart
- NotificationsPage
- notification_evaluator.dart
- home_ai_regen.dart
- notifications_repository.dart
- period_weather.dart
- ../../core/theme/app_colors.dart
- SignupPage
- SoilGood — Future enhancements: ESP32 claim & multi-sensor
- period_weather_repository.dart
- AnalyticsPage
- package:flutter/material.dart
- crops_repository.dart
- groq_period_ai_client.dart
- open_meteo_weather_service.dart
- core/supabase/supabase_bootstrap.dart
- period_ai_regen.dart
- Page: Crops
- refresh_timeout.dart
- Page: Profile
- app_map_tiles.dart
- groq_chat_client.dart
- metric_chart_style.dart
- ../../../core/ai/saved_assessment.dart

## God Nodes (most connected - your core abstractions)
1. `SoilGood — Backend` - 12 edges
2. `SoilGood — Data Model` - 12 edges
3. `Tables & fields` - 12 edges
4. `Page: Home Dashboard` - 12 edges
5. `Page: Signup & Onboarding` - 12 edges
6. `SoilGood — Features to Implement` - 11 edges
7. `Page: Analytics` - 11 edges
8. `Page: Crops` - 11 edges
9. `SoilGood — Crop ranges (research v1)` - 10 edges
10. `SoilGood — Project Overview` - 10 edges

## Surprising Connections (you probably didn't know these)
- `_openDay` --navigates--> `DayReadingsPage`  [EXTRACTED]
  lib/features/analytics/presentation/analytics_page.dart → lib/features/analytics/presentation/day_readings_page.dart
- `_openSignup` --navigates--> `SignupPage`  [EXTRACTED]
  lib/features/auth/presentation/login_page.dart → lib/features/auth/presentation/signup_page.dart
- `NotificationScope` --references--> `NotificationController`  [EXTRACTED]
  lib/features/notifications/logic/notification_scope.dart → lib/features/notifications/logic/notification_controller.dart
- `build` --navigates--> `NotificationsPage`  [EXTRACTED]
  lib/features/shell/app_shell.dart → lib/features/notifications/presentation/notifications_page.dart

## Import Cycles
- None detected.

## Communities (104 total, 5 thin omitted)

### Community 0 - "crops_page.dart"
Cohesion: 0.05
Nodes (44): ../../../core/ai/saved_assessment_repository.dart, crop_plan_page.dart, ../data/crops_repository.dart, accent, _actionError, _aiError, _aiLoading, _aiRepo (+36 more)

### Community 1 - "login_page.dart"
Cohesion: 0.12
Nodes (16): _authController, build, createState, dispose, _emailController, _formKey, initState, _obscurePassword (+8 more)

### Community 2 - "home_page.dart"
Cohesion: 0.03
Nodes (60): ../data/soil_readings_repository.dart, _actionTone, active, _aiBusy, _aiError, _aiLoading, _aiQueued, _aiRepo (+52 more)

### Community 3 - "profile_onboarding_page.dart"
Cohesion: 0.11
Nodes (18): _barangay, build, _city, _continue, createState, dispose, _error, _firstName (+10 more)

### Community 4 - "notifications_page.dart"
Cohesion: 0.09
Nodes (22): dart:async, ../data/notifications_repository.dart, _actionError, _AlertCard, build, _cached, createState, dispose (+14 more)

### Community 5 - "daily_soil_bucket.dart"
Cohesion: 0.05
Nodes (37): avgEc, avgMoisture, avgNitrogen, avgOf, avgPh, avgPhosphorus, avgPotassium, avgSalinity (+29 more)

### Community 6 - "soil_reading.dart"
Cohesion: 0.12
Nodes (15): double?, ec, fromJson, id, moisturePercent, nitrogen, ph, phosphorus (+7 more)

### Community 7 - "farm_notification.dart"
Cohesion: 0.07
Nodes (28): bool get, info,
  warning,, body, copyWith, createdAt, dedupeKey, farmerLabel, farmId (+20 more)

### Community 8 - "location_onboarding_page.dart"
Cohesion: 0.11
Nodes (17): device_onboarding_page.dart, LatLng, build, _confirm, createState, _detectGps, _error, _gpsNote (+9 more)

### Community 9 - "device_onboarding_page.dart"
Cohesion: 0.12
Nodes (15): ../../auth/presentation/widgets/auth_error_banner.dart, ../../auth/presentation/widgets/auth_primary_button.dart, ../../auth/presentation/widgets/auth_text_field.dart, ../data/onboarding_repository.dart, FormState, build, _claim, createState (+7 more)

### Community 10 - "crop_catalog.dart"
Cohesion: 0.07
Nodes (28): int?, days, daysToMaturity, ecMax, ecMin, fromJson, growingSeason, id (+20 more)

### Community 11 - "app_shell.dart"
Cohesion: 0.07
Nodes (28): ../analytics/presentation/analytics_page.dart, ../crops/presentation/crops_page.dart, ../home/presentation/home_page.dart, InheritedWidget, AppShell, _AppShellState, createState, dispose (+20 more)

### Community 12 - "analytics_page.dart"
Cohesion: 0.04
Nodes (48): analytics_filters.dart, ../data/period_ai_repository.dart, ../data/period_weather_repository.dart, day_readings_page.dart, _aiError, _aiLoading, _aiRepo, _assessment (+40 more)

### Community 13 - ".application"
Cohesion: 0.15
Nodes (10): Any, Bool, Flutter, FlutterAppDelegate, AppDelegate, RunnerTests, UIApplication, UIKit (+2 more)

### Community 14 - "ui_primitives.dart"
Cohesion: 0.10
Nodes (19): build, child, color, first, gap, icon, isNarrowPhone, label (+11 more)

### Community 15 - "day_readings_page.dart"
Cohesion: 0.13
Nodes (15): ../data/soil_history_repository.dart, build, createState, DayReadingsPage, _DayReadingsPageState, _done, _error, initState (+7 more)

### Community 16 - "auth_scaffold.dart"
Cohesion: 0.18
Nodes (10): Color, AuthScaffold, build, color, footer, form, _OrganicGlow, subtitle (+2 more)

### Community 17 - "app_env.dart"
Cohesion: 0.18
Nodes (10): _anonKey, AppEnv, load, _require, supabaseAnonKey, supabaseUrl, _urlKey, package:flutter_dotenv/flutter_dotenv.dart (+2 more)

### Community 18 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 25 - "SoilGood — Data Model"
Cohesion: 0.08
Nodes (24): `ai_assessments`, `ai_recommendations`, `crops` (reference), Device claim flow, `devices`, Entity relationship, ESP32 → cloud → app, `farm_actions` (+16 more)

### Community 26 - "planting.dart"
Cohesion: 0.15
Nodes (12): DateTime, CropCatalogEntry, crop, cropId, _dateOnly, expectedHarvestAt, farmId, fromJson (+4 more)

### Community 27 - "Page: Signup & Onboarding"
Cohesion: 0.14
Nodes (14): Data & sources, Farm location (GPS + draggable pin), Flow overview (split into steps), Functions, Implemented, Optimistic UI, Page logic flowchart, Page: Signup & Onboarding (+6 more)

### Community 28 - "crop_match.dart"
Cohesion: 0.05
Nodes (37): _airTempC, bad, checks, considered, crop, CropMatch, CropRainFit, days (+29 more)

### Community 29 - "Page: Home Dashboard"
Cohesion: 0.17
Nodes (12): AI voice (locked), Data & sources, Functions, In / out (locked), Optimistic UI, Page: Home Dashboard, Page logic flowchart, Purpose / goal (+4 more)

### Community 30 - "SoilGood — Backend"
Cohesion: 0.17
Nodes (12): Data requirements, Decisions (locked), Development without hardware, ESP32 write path (locked), Farm notifications (local alerts), Flutter env (client), Free / cost policy, Groq (all generated AI insights) (+4 more)

### Community 31 - "SoilGood — Project Overview"
Cohesion: 0.20
Nodes (10): App Name, Hardware (IoT), Problem, Project Objectives, Related docs, SDG Alignment, Software Stack, SoilGood — Project Overview (+2 more)

### Community 32 - "Checklist"
Cohesion: 0.20
Nodes (10): Authentication, Checklist, Device (ESP32), Out of scope for early development, Principles (fit for now), Row Level Security (RLS), Secrets, SoilGood — Security (+2 more)

### Community 33 - "Page: \<Page Name\>"
Cohesion: 0.20
Nodes (10): Data & sources, Functions, Optimistic UI, Page logic flowchart, Page: \<Page Name\>, Purpose / goal, Related, Status (+2 more)

### Community 35 - "SoilGood — Architecture"
Cohesion: 0.22
Nodes (9): App shell (persistent chrome), Design source of truth, Documentation required per page, Folder conventions, Goals, Navigation transitions, Page UX conventions, Separation of concerns (+1 more)

### Community 36 - "SoilGood — Features to Implement"
Cohesion: 0.18
Nodes (11): 1. Real-time Soil Monitoring, 2. Weather Information, 3. Historical Monitoring Records, 4. AI-Assisted Recommendations, 5. Analytics (History + Trends + Period Averages), 6. Notifications (engine first, inbox later), Data Requirement (critical), Future (not v1) (+3 more)

### Community 37 - "SoilGood — UI Theme"
Cohesion: 0.29
Nodes (7): Brand direction, Colors, Implementation notes (when coding), Shell & layout, SoilGood — UI Theme, Type details, Typography

### Community 38 - "crop_plan_page.dart"
Cohesion: 0.05
Nodes (38): AiRecommendation, description, farmId, fromJson, generatedAt, id, kind, modelName (+30 more)

### Community 39 - "app_colors.dart"
Cohesion: 0.11
Nodes (18): AppColors, background, error, errorContainer, outline, primary, primaryContainer, primarySoft (+10 more)

### Community 40 - "package:google_fonts/google_fonts.dart"
Cohesion: 0.40
Nodes (4): app_colors.dart, AppTheme, _border, package:google_fonts/google_fonts.dart

### Community 41 - "auth_primary_button.dart"
Cohesion: 0.29
Nodes (6): AuthPrimaryButton, build, isLoading, label, onPressed, VoidCallback?

### Community 42 - "period_assessment.dart"
Cohesion: 0.09
Nodes (21): description, farmId, fromJson, generatedAt, id, modelName, overview, _parseDate (+13 more)

### Community 43 - "crop_band_classify.dart"
Cohesion: 0.04
Nodes (54): ../../features/crops/data/crop_catalog.dart, classifyEcBand, classifyMoistureBand, classifyPhBand, classifySalinityBand, classifyTempBand, CropBandRanges, dryDown (+46 more)

### Community 44 - "SoilGood"
Cohesion: 0.33
Nodes (6): Context, Documentation (read these first), Pages, Run, SoilGood, Stack

### Community 45 - "StatelessWidget"
Cohesion: 0.08
Nodes (26): _AdviceCard, _AnalyticsFirstLoadSkeleton, _CaptionStat, _PeriodAiBlock, _PeriodWeatherCard, _SensorAvgGrid, _SensorAvgTile, _SourceErrorCard (+18 more)

### Community 46 - "manila_time.dart"
Cohesion: 0.09
Nodes (21): d, day, kManilaOffset, m, manila, manilaCalendarDate, manilaDayEndUtc, manilaIsoDate (+13 more)

### Community 49 - "analytics_period.dart"
Cohesion: 0.11
Nodes (17): AnalyticsPeriod, AnalyticsPeriodKind, customMonth, customWeek, dayCount, end, formatManilaRange, kind (+9 more)

### Community 50 - "SoilGood — AI insights config"
Cohesion: 0.22
Nodes (9): Deploy (one-time), Does one JSON file save tokens?, Home tips (v4), Next (locked), Production API, Prompt versions, SoilGood — AI insights config, Storage (+1 more)

### Community 51 - "CustomPainter"
Cohesion: 0.67
Nodes (3): CustomPainter, _OverlayChartPainter, _TrendChartPainter

### Community 52 - "auth_text_field.dart"
Cohesion: 0.12
Nodes (16): IconData?, Iterable, AuthTextField, autofillHints, build, controller, hint, icon (+8 more)

### Community 53 - "auth_gate.dart"
Cohesion: 0.06
Nodes (30): AuthState, ../config/app_env.dart, dart:math, Future, bootstrapSupabase, initialize, supabase, AuthGate (+22 more)

### Community 54 - "API Integration — Open-Meteo Weather"
Cohesion: 0.25
Nodes (7): API endpoint(s) used, API Integration — Open-Meteo Weather, API name, Features added through API integration, JSON handling, Request method(s) implemented, Why we use this API

### Community 55 - "analytics_filters.dart"
Cohesion: 0.05
Nodes (47): AnalyticsPeriod get, AnalyticsFilterBar, build, _calMonth, createState, current, _Dow, _draft (+39 more)

### Community 56 - "String?"
Cohesion: 0.17
Nodes (11): ChangeNotifier, ../data/auth_repository.dart, AuthController, errorMessage, isLoading, _repository, _run, signIn (+3 more)

### Community 57 - "app_validators.dart"
Cohesion: 0.09
Nodes (22): AppValidators, confirmPassword, _digit, email, _emailPattern, _hasDigit, _hasLetter, _hasMinLength (+14 more)

### Community 58 - "app_content_width.dart"
Cohesion: 0.25
Nodes (7): AppContentWidth, build, child, kAppContentMaxWidth, kAuthContentMaxWidth, maxWidth, Widget

### Community 59 - "index.ts"
Cohesion: 0.31
Nodes (9): cors, handlePost(), hasLiveInput(), insights, jobs, jsonResponse(), promptAt(), requireUser() (+1 more)

### Community 60 - "profile_page.dart"
Cohesion: 0.15
Nodes (12): ../../auth/data/auth_repository.dart, build, createState, _displayName, initState, _loadDone, _loadError, _loadProfile (+4 more)

### Community 61 - "crop_timeline.dart"
Cohesion: 0.10
Nodes (20): ../data/crop_catalog.dart, CropPhase, crop, CropTimeline, current, currentIndex, currentPhaseStart, cursor (+12 more)

### Community 62 - "analytics_stats.dart"
Cohesion: 0.12
Nodes (16): average, avgs, b, bucketsToPromptJson, dayCount, formatMetric, inferredDryDayCount, max (+8 more)

### Community 63 - "weather_models.dart"
Cohesion: 0.12
Nodes (16): conditionLabel, daily, DailyForecast, date, fetchedAt, humidityPercent, latitude, longitude (+8 more)

### Community 64 - "crops_care_ai_client.dart"
Cohesion: 0.21
Nodes (11): ../../../core/ai/ai_json_parse.dart, ../../../core/ai/crop_band_classify.dart, ../../../core/ai/groq_chat_client.dart, ../../../core/ai/insights_config.dart, ../data/planting.dart, ../data/soil_reading.dart, _chat, CropsCareAiClient (+3 more)

### Community 65 - "notification_controller.dart"
Cohesion: 0.08
Nodes (23): ../../crops/data/crops_repository.dart, ../../crops/logic/crop_timeline.dart, ../../home/data/soil_readings_repository.dart, _closed, _cropsRepo, dispose, _evaluator, _farmRepo (+15 more)

### Community 67 - "insights_config.dart"
Cohesion: 0.12
Nodes (16): crop_band_classify.dart, _bands, _cached, classifiedFacts, cropsCacheHours, homeCacheHours, InsightsConfig, load (+8 more)

### Community 68 - "List"
Cohesion: 0.25
Nodes (7): app_content_width.dart, EdgeInsetsGeometry, AppRefreshScroll, build, children, padding, List

### Community 69 - "home_ai_story.dart"
Cohesion: 0.11
Nodes (17): body, buildHomeStoryFingerprint, daily, decodeHomeOverview, displayHomeOverview, encodeHomeOverviewWithFingerprint, facts, homeRainAdviceLabel (+9 more)

### Community 70 - "Page: Notifications"
Cohesion: 0.18
Nodes (10): Data & sources, Functions, Optimistic UI, Page logic flowchart, Page: Notifications, Purpose / goal, Related, Status (+2 more)

### Community 71 - "NotificationController"
Cohesion: 0.67
Nodes (3): InheritedNotifier, NotificationController, NotificationScope

### Community 72 - "main.dart"
Cohesion: 0.22
Nodes (8): core/config/app_env.dart, core/theme/app_theme.dart, features/auth/presentation/auth_gate.dart, bootstrapSupabase, build, load, main, SoilGoodApp

### Community 73 - "SoilGood — Crop ranges (research v1)"
Cohesion: 0.20
Nodes (10): 8-in-1 baselines (summary), Apply in Supabase, Fallback ladder (locked), Global extreme floors (no crop / always), Honesty, Hydro classes (mapped moisture %), Key sources, Phase timelines (+2 more)

### Community 74 - "ai_json_parse.dart"
Cohesion: 0.15
Nodes (11): groq_chat_client.dart, _allowedPriority, overview, parseAiInsightJson, recRaw, recs, fetchLatest, save (+3 more)

### Community 75 - "signup_page.dart"
Cohesion: 0.12
Nodes (16): _authController, build, _confirmController, createState, dispose, _emailController, _formKey, initState (+8 more)

### Community 76 - "farm_location_repository.dart"
Cohesion: 0.25
Nodes (7): FarmCoordinates, farmId, FarmLocationRepository, getPrimaryFarmCoordinates, getPrimaryFarmId, latitude, longitude

### Community 77 - "password_rules_checklist.dart"
Cohesion: 0.25
Nodes (7): ../../../../core/validation/app_validators.dart, build, label, met, password, PasswordRulesChecklist, _RuleRow

### Community 78 - "Page: Analytics"
Cohesion: 0.18
Nodes (11): Data & sources, Functions, In / out (locked), Optimistic UI, Page: Analytics, Page logic flowchart, Purpose / goal, Related (+3 more)

### Community 79 - "soil_history_repository.dart"
Cohesion: 0.22
Nodes (8): daily_soil_bucket.dart, ../../home/data/soil_reading.dart, fetchActiveCropName, fetchDaily, fetchForDay, fetchPrimaryFarmId, _ownedDeviceIds, SoilHistoryRepository

### Community 80 - "soil_readings_repository.dart"
Cohesion: 0.33
Nodes (5): fetchLatest, _ownedDeviceIds, SoilReadingsRepository, watchLatest, soil_reading.dart

### Community 81 - "NotificationsPage"
Cohesion: 0.33
Nodes (6): _openDay, NotificationsPage, _NotificationsPageState, _openEdit, build, AppPageRoutes.slideFromRight

### Community 82 - "notification_evaluator.dart"
Cohesion: 0.14
Nodes (13): ../data/farm_notification.dart, Duration, _addBandIssue, evaluate, _fmt, _irrigation, _joinList, _manilaYmd (+5 more)

### Community 83 - "home_ai_regen.dart"
Cohesion: 0.29
Nodes (6): home_ai_story.dart, false, savedFp, shouldRegenHomeAi, until, return

### Community 84 - "notifications_repository.dart"
Cohesion: 0.18
Nodes (10): farm_notification.dart, fetchRecent, insertIfNew, insertNewDrafts, markAllRead, markRead, markTypesRead, NotificationsRepository (+2 more)

### Community 85 - "period_weather.dart"
Cohesion: 0.18
Nodes (10): double get, int get, _avg, avgTempMaxC, avgTempMinC, days, PeriodWeather, rainyDayCount (+2 more)

### Community 86 - "../../core/theme/app_colors.dart"
Cohesion: 0.40
Nodes (4): ../../core/theme/app_colors.dart, AuthErrorBanner, build, message

### Community 87 - "SignupPage"
Cohesion: 0.67
Nodes (3): _openSignup, SignupPage, _SignupPageState

### Community 88 - "SoilGood — Future enhancements: ESP32 claim & multi-sensor"
Cohesion: 0.14
Nodes (14): AI behavior (zone-aware), Current v1 (locked), Enhancement A — Real device claim (pre-provision + code/QR), Enhancement B — v1.5 multi-sensor / multi-ESP32 (same farm), Farmer flow, Goal, Goal, Likely schema / backend tweaks (small) (+6 more)

### Community 89 - "period_weather_repository.dart"
Cohesion: 0.22
Nodes (8): fetchRange, _location, PeriodWeatherRepository, _weather, OpenMeteoWeatherService, period_weather.dart, ../../weather/data/farm_location_repository.dart, ../../weather/data/open_meteo_weather_service.dart

### Community 91 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (7): maybeOf, notification_controller.dart, package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:soil_sense/core/validation/app_validators.dart, main, main

### Community 92 - "crops_repository.dart"
Cohesion: 0.20
Nodes (9): ../../analytics/logic/manila_time.dart, crop_catalog.dart, CropsRepository, endPlanting, fetchActivePlanting, fetchCatalog, selectCrop, _ymd (+1 more)

### Community 93 - "groq_period_ai_client.dart"
Cohesion: 0.18
Nodes (10): analytics_period.dart, analytics_stats.dart, ../data/period_weather.dart, _allowedPriority, _allowedTypes, _chat, GroqPeriodAiClient, message (+2 more)

### Community 94 - "open_meteo_weather_service.dart"
Cohesion: 0.18
Nodes (10): dart:convert, _base, fetch, fetchDailyRange, _isoDate, _numAt, weatherCodeIcon, weatherCodeLabel (+2 more)

### Community 95 - "core/supabase/supabase_bootstrap.dart"
Cohesion: 0.17
Nodes (10): core/supabase/supabase_bootstrap.dart, fetchLatest, PeriodAiRepository, save, AuthRepository, signIn, signOut, signUp (+2 more)

### Community 96 - "period_ai_regen.dart"
Cohesion: 0.18
Nodes (10): ../data/period_assessment.dart, end, false, generatedDay, kPeriodAiPromptVersion, last, shouldRegenPeriodAi, start (+2 more)

### Community 97 - "Page: Crops"
Cohesion: 0.18
Nodes (11): Data & sources, Functions, In / out (locked), Optimistic UI, Page: Crops, Page logic flowchart, Purpose / goal, Related (+3 more)

### Community 98 - "refresh_timeout.dart"
Cohesion: 0.18
Nodes (9): Exception, GroqChatException, GroqPeriodAiException, kRefreshTimeout, RefreshTimeoutException, timeout, toString, AppPageRoutes (+1 more)

### Community 99 - "Page: Profile"
Cohesion: 0.20
Nodes (10): Data & sources, Functions, Optimistic UI, Page logic flowchart, Page: Profile, Purpose / goal, Related, Status (+2 more)

### Community 100 - "app_map_tiles.dart"
Cohesion: 0.20
Nodes (9): AppMapTiles, attribution, layer, subdomains, urlTemplate, userAgentPackageName, package:flutter_map/flutter_map.dart, package:flutter/widgets.dart (+1 more)

### Community 101 - "groq_chat_client.dart"
Cohesion: 0.22
Nodes (8): _asMap, completeJson, GroqChatClient, kGroqModel, kInsightsFunction, message, _messageFrom, toString

### Community 102 - "metric_chart_style.dart"
Cohesion: 0.25
Nodes (7): ../data/daily_soil_bucket.dart, hi, lo, metricChartColor, metricOverlayBand, metricOverlayUnit, v

### Community 103 - "../../../core/ai/saved_assessment.dart"
Cohesion: 0.33
Nodes (5): ../../../core/ai/saved_assessment.dart, crop_timeline.dart, false, shouldRegenCropsCareAi, until

## Knowledge Gaps
- **1084 isolated node(s):** `XCTest`, `_allowedPriority`, `overview`, `recRaw`, `recs` (+1079 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `GroqChatClient` connect `groq_chat_client.dart` to `crops_care_ai_client.dart`, `groq_period_ai_client.dart`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `SoilMetric` connect `daily_soil_bucket.dart` to `analytics_page.dart`, `analytics_filters.dart`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `MetricPeriodStats` connect `analytics_stats.dart` to `analytics_page.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `XCTest`, `_allowedPriority`, `overview` to the rest of the system?**
  _1084 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `crops_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.045454545454545456 - nodes in this community are weakly interconnected._
- **Should `login_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.11764705882352941 - nodes in this community are weakly interconnected._
- **Should `home_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.03278688524590164 - nodes in this community are weakly interconnected._