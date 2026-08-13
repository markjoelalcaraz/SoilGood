# SoilGood ESP32 heartbeat

Sends a dummy `soil_readings` row so Home can show the ESP32 is alive. Soil Modbus is not required.

1. Run `docs/context/supabase_esp32_ingest.sql` in Supabase SQL Editor.
2. Claim a device in the app (copy `DEVICE_UID` + `INGEST_TOKEN`).
3. Copy `secrets.h.example` → `secrets.h` and fill WiFi + anon key (never service_role).
4. Open `soilgood_heartbeat.ino` in Arduino IDE, board **ESP32 Dev Module**, upload.
5. Serial Monitor 115200: `POST 200` and a UUID. Home should get a new reading (moisture 0).

JSON body uses `p_device_uid` / `p_ingest_token` (Postgres arg names).
