# API Integration — Open-Meteo Weather

Brief documentation for SoilGood’s external weather API integration.

## API name

**Open-Meteo** — free weather forecast API (no API key required).  
Docs: https://open-meteo.com/en/docs

## Why we use this API

Farm maintenance, monitoring, and crop choice are **not** based on soil condition alone. Weather also matters: rain, heat, humidity, and wind affect irrigation, crop suitability, and day-to-day field work.

SoilGood therefore fetches live weather for the farmer’s saved farm pin and shows it on Home (and related analytics). The app’s AI uses **both** weather and sensor findings when suggesting irrigation, soil/condition actions, and fertilization — so recommendations stay grounded in what is happening above the soil as well as in it.

## API endpoint(s) used

| Purpose | Endpoint |
|---|---|
| Current weather + short daily forecast (Home) | `https://api.open-meteo.com/v1/forecast` |
| Historical / date-range daily weather (Analytics) | `https://api.open-meteo.com/v1/forecast` (recent window) or `https://archive-api.open-meteo.com/v1/archive` (older dates) |

Example forecast request (farm pin):

```
https://api.open-meteo.com/v1/forecast?latitude=14.8885890855363&longitude=120.88365076675&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max&timezone=auto&forecast_days=4&wind_speed_unit=kmh
```

## Request method(s) implemented

| Method | Used? | Notes |
|---|---|---|
| **HTTP GET** | Yes | Retrieve current conditions and daily forecast JSON for the farm’s latitude/longitude |
| **HTTP POST** | Not applicable | Open-Meteo is a read-only weather data API; the app only retrieves weather (no create/update on this API) |

Implementation: `lib/features/weather/data/open_meteo_weather_service.dart` (`package:http` → `http.get`, then `jsonDecode`).

## Features added through API integration

- Live **current weather** on Home (temperature, humidity, precipitation, wind, condition)
- **Multi-day forecast** cards for planning field work and irrigation
- Weather tied to the farmer’s **saved map pin** (not a fixed city)
- Weather inputs for **AI suggestions** (irrigation, condition, fertilization) together with soil sensor data
- Graceful **loading** and **error** handling when the API fails or returns a non-OK response
- Analytics support via **daily weather over a date range** (forecast or archive endpoint)

## JSON handling

1. Send GET to Open-Meteo with farm `latitude` / `longitude`
2. Parse JSON (`current` + `daily` blocks)
3. Map into `WeatherSnapshot` / `DailyForecast`
4. Display on the UI; AI may use the same weather context with sensor readings
