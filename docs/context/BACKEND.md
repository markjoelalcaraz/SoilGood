# SoilGood — Backend

## Decisions (locked)
| Item | Choice |
|---|---|
| Backend | **Supabase** (Postgres + Auth + Realtime) |
| Plan | **Free** tier preferred |
| Sensor persist interval | ~**15 minutes** |
| Realtime | Supabase Realtime + Flutter **listener** (not a paid “subscription”) |
| Weather / other APIs | **Open-Meteo** (free, no API key) + prefer free tiers |
| Map tiles | **Carto Voyager** via `flutter_map` (free; OSM attribution) |

## Why Supabase
- Strong for **analytics** (SQL aggregations on historical readings).
- Realtime is available on Free and is enough for ~15-min writes + a few devices.
- Firestore-style live UI is still achievable via Realtime channels/streams.

## How realtime works (no payment)
1. ESP32 (or pipeline) **writes** a row to Supabase.
2. Supabase Realtime **broadcasts** the change.
3. Flutter **listens** (stream/channel) and updates the content area.
4. Local **cache** still used for fast first paint / weak connectivity.

## Data requirements
- Timestamped **soil readings** (moisture, pH, temperature, EC, NPK).
- Matching **weather snapshots** when readings are stored (needed for analytics and irrigation advice).
- Full schema: [DATA_MODEL.md](DATA_MODEL.md)
- SQL to create tables: [supabase_schema.sql](supabase_schema.sql)

## Flutter env (client)
- Copy [`.env.example`](../../.env.example) → `.env` (gitignored).
- Use **legacy anon JWT** (`eyJ...`) as `SUPABASE_ANON_KEY` — verified with Data API.
- Never put **service_role** / secret keys in `.env` or the app.
- Bootstrap: `lib/core/config/app_env.dart` + `lib/core/supabase/supabase_bootstrap.dart`.

## Development without hardware
- UI/workspace can proceed **before** ESP32 is ready.
- Use **mock/seed** `soil_readings` (and later weather) to build pages.
- Device claim + real ESP32 insert come later.

## Free / cost policy
- Prefer free APIs and free tiers.
- Document rate limits and quotas when a service is chosen.
- Do not assume paid plans during development.

## Open decisions
- Exact ESP32 → Supabase write path (direct insert with constrained key vs Edge Function).
- Persist Open-Meteo snapshots into `weather_snapshots` on a schedule (recommended next).
- AgroMonitoring / satellite NDVI as optional future enhancement (not required for v1).
