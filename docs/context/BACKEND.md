# SoilGood — Backend

## Decisions (locked)
| Item | Choice |
|---|---|
| Backend | **Supabase** (Postgres + Auth + Realtime) |
| Plan | **Free** tier preferred |
| Sensor persist interval | ~**15 minutes** |
| Realtime | Supabase Realtime + Flutter **listener** (not a paid “subscription”) |
| Weather / other APIs | **Open-Meteo** (free, no API key) + prefer free tiers |
| Generated AI insights | **Groq** (`llama-3.3-70b-versatile`) via Edge Function `soilgood-insights` |
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
- Timestamped **soil readings** (moisture, pH, temperature, EC, salinity, NPK).
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

## ESP32 write path (locked)
ESP32 uses the **anon** key only — never **service_role**.

1. Farmer claims a `device_uid` in the app.
2. Row in `devices` gets a secret `ingest_token`.
3. ESP32 `POST`s HTTPS to ` /rest/v1/rpc/ingest_soil_reading` with `device_uid` + `ingest_token` + readings.
4. Postgres `SECURITY DEFINER` function checks the token, inserts `soil_readings`, updates `last_seen_at`.
5. Flutter Realtime on `soil_readings` updates Home.

SQL: [supabase_esp32_ingest.sql](supabase_esp32_ingest.sql)  
Sketch: `firmware/esp32/soilgood_heartbeat/`

## Groq (all generated AI insights)
- Flutter calls Edge Function `soilgood-insights` with the user JWT (`supabase.functions.invoke`). It never holds `GROQ_API_KEY`.
- The function attaches a **page slice** of [`insights.json`](../../supabase/functions/soilgood-insights/insights.json) and calls Groq. No soil data → `no_reading`, Groq is **not** called.
- Model: `llama-3.3-70b-versatile`. **Only** model for generated insight text (Home today, Crops care, Analytics period).
- Jobs: Home = one urgent action today; Crops = care for the selected planting/phase; Analytics = kalagayan of the **selected date window**. Catalog scores and phase days are local, not Groq.
- Results saved in `ai_assessments` (`kind` + optional `period_start` / `period_end` / `planting_id`) + `ai_recommendations`. Analytics lookup is by start+end, not a generic 7/30. Regen only when the page’s cache rules say so.
- Free-tier rate limits apply (TPM/RPM on Groq’s dashboard). Fail visibly on the AI block only.
- SQL: [supabase_analytics.sql](supabase_analytics.sql), [supabase_crops_home_ai.sql](supabase_crops_home_ai.sql)
- Deploy + secrets: [AI_INSIGHTS.md](AI_INSIGHTS.md)

## Farm notifications (local alerts)
- Flutter classifies the latest reading with `insights.json` bands and inserts `farm_notifications` (RLS = farm owner).
- Dedup: one row per `type` per farm per Asia/Manila day so ~15-min ESP32 writes do not spam.
- No Groq and no service_role. Inbox is a pushed page from the bell. OS/FCM when the app is killed is later.
- SQL: [supabase_notifications.sql](supabase_notifications.sql).

## Open decisions
- **Next:** strengthen AI rules in [`insights.json`](../../supabase/functions/soilgood-insights/insights.json) — [AI_INSIGHTS.md](AI_INSIGHTS.md).
- Persist Open-Meteo snapshots into `weather_snapshots` on a schedule (Analytics currently fetches the selected window live).
- AgroMonitoring / satellite NDVI as optional future enhancement (not required for v1).
- OS / FCM delivery when SoilGood is not running.
