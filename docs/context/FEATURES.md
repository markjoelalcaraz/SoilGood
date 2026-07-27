# SoilGood — Features to Implement

## 1. Real-time Soil Monitoring
- Live display of ESP32 sensor readings:
  - Soil moisture
  - pH
  - Temperature
  - Electrical conductivity (EC)
  - NPK (Nitrogen, Phosphorus, Potassium)
- Status indicators (e.g. low / optimal / high per parameter)

## 2. Weather Information
- Current weather conditions (**Open-Meteo**, free, no API key)
- Forecast data
- Used to support irrigation and crop management decisions

## 3. Historical Monitoring Records
- Past soil sensor readings with timestamps
- Past weather snapshots aligned with readings
- Browseable / filterable history (day / week / month)

## 4. AI-Assisted Recommendations
Analyzes soil + weather data to provide:
- Soil condition assessment
- Irrigation recommendations (whether / when water is needed)
- Soil and nutrient management actions
- Crop recommendations compatible with monitored soil conditions

## 5. Analytics (Future-Oriented Insights)
Uses history to suggest what to do next:
- **Trend analysis** — moisture, pH, temperature, EC, NPK over time
- **Irrigation patterns** — how often soil goes dry; typical dry periods
- **Nutrient depletion tracking** — N/P/K trends; when fertilization may be needed
- **Soil health score over time** — composite score from parameters
- **Weather vs soil correlation** — e.g. drying rate after rain; heat vs moisture
- **Seasonal crop suitability** — crops that fit historical soil conditions (not just one reading)
- **Predictive insights** — e.g. when moisture may hit a critical level

## Data Requirement (critical)
Store **timestamped sensor readings** and matching **weather snapshots** from day one. Analytics cannot work without historical data. Persist sensor rows about every **15 minutes**.

## UX / architecture (all screens)
See [ARCHITECTURE.md](ARCHITECTURE.md) and [UI_THEME.md](UI_THEME.md): app shell, cache, skeletons, optimistic UI, realtime streams, logic ≠ UI.

## Primary User Flows
1. Open app → see live soil + weather status
2. Review history → understand past field conditions
3. Read AI recommendations → act on irrigation / nutrients / crops
4. Open analytics → plan ahead based on trends and predictions
