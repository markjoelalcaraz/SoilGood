# SoilGood — Project Overview

## App Name
**SoilGood** (IoT and AI-assisted mobile application for farmers)

## Problem
Many farmers in the Philippines still rely on experience and visual observation for irrigation, nutrient management, and crop selection. Changing weather and varying soil conditions make these decisions harder. Without real-time soil and weather data, farmers often estimate instead of measuring, leading to inefficient water use, improper nutrient management, and poorly matched crop selection.

## Solution
SoilGood continuously monitors key soil parameters via IoT sensors and combines them with weather data. An AI-assisted module generates recommendations for irrigation, soil/nutrient management, and crop suitability. An analytics layer uses historical data to guide future farming decisions.

## Hardware (IoT)
- **ESP32** microcontroller
- Sensors: soil moisture, pH, temperature, electrical conductivity (EC), NPK
- **Persist interval:** ~every **15 minutes** (live UI can refresh more often in memory; history writes at this pace)

## Software Stack
- **Mobile app:** Flutter
- **Backend:** Supabase (Postgres + Realtime) — **Free plan**
- **Weather API:** current + forecast via **Open-Meteo** (free, no key)
- **AI recommendations:** Module that analyzes soil + weather data (prefer free / free-tier services)
- **Cost policy:** Prefer free tiers for APIs and services; document rate limits

## Target Users
Farmers, farm owners, and agricultural practitioners

## SDG Alignment
**SDG 2 – Zero Hunger**, Target 2.4 — sustainable food production and resilient agricultural practices.

## Project Objectives
1. Build an IoT soil monitoring device (ESP32 + moisture, pH, temperature, EC, NPK).
2. Develop a real-time monitoring module (soil readings, weather, historical records).
3. Integrate a weather API (current conditions + forecast).
4. Develop an AI-assisted recommendation module (soil assessment, irrigation advice, management actions, crop recommendations).
5. Develop an analytics module (trends and future-oriented insights from historical data).

## Related docs
- [FEATURES.md](FEATURES.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [BACKEND.md](BACKEND.md)
- [DATA_MODEL.md](DATA_MODEL.md)
- [SECURITY.md](SECURITY.md)
- [UI_THEME.md](UI_THEME.md)
- Per-page docs: [../pages/_TEMPLATE.md](../pages/_TEMPLATE.md)
