# SoilGood ESP32 — live soil → Supabase

Reads THE01888S over Modbus (MAX485), then HTTPS POST to `ingest_soil_reading`.

1. Run / re-run `docs/context/supabase_esp32_ingest.sql` in Supabase SQL Editor  
   (needed if salinity was limited to 50 — probe reports hundreds).
2. Keep `secrets.h` filled (WiFi, DEVICE_UID, INGEST_TOKEN, anon key — never service_role).
3. Wiring: 12V → sensor RED/BLACK; MAX485 A/B; ESP32 D16/D17/D4/D5/3V3/GND; USB for Serial.
4. Upload `soilgood_heartbeat.ino` (ESP32 Dev Module).
5. Serial 115200: soil numbers + `POST 200` + UUID. Home should show live moisture/temp/EC.

Interval: successful POST waits `POST_EVERY_MS` (~15 min). Modbus fail retries after `RETRY_FAIL_MS` (10s).
