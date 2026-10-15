# SoilGood — Features to Implement

## 1. Real-time Soil Monitoring
- Live display of ESP32 **8-in-1** sensor readings:
  - Soil moisture
  - pH
  - Temperature
  - Electrical conductivity (EC)
  - Salinity (ppt)
  - NPK (Nitrogen, Phosphorus, Potassium)
- Status indicators (e.g. low / optimal / high per parameter)

## 2. Weather Information
- Current weather conditions (**Open-Meteo**, free, no API key)
- Forecast data
- Used to support irrigation and crop management decisions

## 3. Historical Monitoring Records
Lives on the **Analytics** tab (not a 5th bottom-nav item).
- Past soil sensor readings with timestamps
- Past weather snapshots aligned with readings
- Browseable / filterable history: **7 days / 30 days** on the chart; tap a day for that day’s readings

## 4. AI-Assisted Recommendations
Analyzes soil + weather data. Split by page so Home and Analytics do not repeat the same tip:
- **Home (now):** Condition, Water today, Nutrients, and **Crop care** (phase chores only when planted) from Groq; Quick Insight is rule-based wording (not raw ppm)
- **Crops (planted):** rolling **7-day water plan** (rules engine — not 7 automatic waterings) + Mark watered Today only; Care insights = phase chores only
- **Analytics (over time):** Groq reads the **selected date window** — kalagayan of that range, then soil/crop betterment actions (not “irrigate tomorrow 6 AM”); also **logged watering counts** from Mark watered

## 5. Analytics (History + Trends + Period Averages)
Same Analytics tab as §3. Uses history to suggest what to do next — **not** a second live dashboard (no current 8-in-1 grid, no “now” weather tiles):
- **Trend analysis** — moisture, pH, temperature, EC, salinity, NPK over time
- **Irrigation patterns** — dry-day inference from history **plus** farmer Mark watered logs (`farm_actions`)
- **Nutrient depletion tracking** — N/P/K trends; when fertilization may be needed
- **Soil health score over time** — composite score from parameters
- **Weather vs soil correlation** — e.g. drying rate after rain; heat vs moisture
- **Seasonal crop suitability** — crops that fit historical soil conditions (not just one reading)
- **Predictive insights** — e.g. when moisture may hit a critical level

## 6. Notifications (engine first, inbox later)
- Classify the latest soil reading with the same `insights.json` bands as Home AI (0 Groq tokens).
- Alert types: irrigation (dry/wet + rain), low N/P/K, soil out of band, sensor error, device offline (>2h).
- Persist to `farm_notifications` at most **once per type per farm per Manila day**.
- Runs while the app shell is open (Realtime on new readings + cultivation phase). Bell shows unread count; Home/Crops nav get a red dot. Tapping that tab marks those alerts read. OS / FCM when the app is killed is later.
- SQL: [`supabase_notifications.sql`](supabase_notifications.sql). Page: [`../pages/notifications.md`](../pages/notifications.md).

## Future (not v1 UI)
Multi-sensor / zone-aware AI on one farm; SoftAP/BLE WiFi; QR for claim codes: [`FUTURE_ENHANCEMENTS_DEVICES.md`](FUTURE_ENHANCEMENTS_DEVICES.md). Claim-by-code (type sticker) is the current path — run [`supabase_device_claim.sql`](supabase_device_claim.sql).

**Soil beyond texture:** Optional curated **soil series** is in v1 (same onboarding step). DA **NCCAG** map lookup by farm pin + full province series keys — later. Tracked in [`FUTURE_ENHANCEMENTS_SOIL.md`](FUTURE_ENHANCEMENTS_SOIL.md). Research: [`SOIL_TEXTURE_CROP_FIT.md`](SOIL_TEXTURE_CROP_FIT.md), [`SOIL_SERIES_CROP_FIT.md`](SOIL_SERIES_CROP_FIT.md).

## Data Requirement (critical)
Store **timestamped sensor readings** and matching **weather snapshots** from day one. Analytics cannot work without historical data. Persist sensor rows about every **15 minutes**.

## UX / architecture (all screens)
See [ARCHITECTURE.md](ARCHITECTURE.md) and [UI_THEME.md](UI_THEME.md): app shell, cache, skeletons, optimistic UI, realtime streams, logic ≠ UI.

## Primary User Flows
1. Open app → **Home**: live soil + forecast → act today
2. Open **Analytics** → history chart + period averages → tap a day for readings → plan from trends
3. Open **Crops** → match catalog to the *latest* soil snapshot
4. Home AI = today; Analytics AI = trends (do not duplicate copy)
5. While the shell is open, soil alerts are saved to `farm_notifications` (inbox UI later)
