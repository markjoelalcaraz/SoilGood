# SoilGood ESP32 — live soil → Supabase

Reads THE01888S over Modbus (MAX485), then HTTPS POST to `ingest_soil_reading`.

Credentials live in **Preferences (NVS)**. Compile-time `secrets.h` is bench fallback only. **Lab Flasher** writes NVS over USB serial (`SGCFG` protocol) after provisioning a kit.

## Setup

1. Run / re-run `docs/context/supabase_esp32_ingest.sql` in Supabase SQL Editor  
   (needed if salinity was limited to 50 — probe reports hundreds).
2. Run `docs/context/supabase_device_claim.sql` once (claim_code + `claim_device` RPC).
3. Run `docs/context/supabase_admin.sql` + promote admin; then `docs/context/supabase_lab_flash.sql`.
4. Arduino IDE: install **ArduinoJson** (v6.x), board **ESP32 Dev Module**.
5. Copy `secrets.h.example` → `secrets.h` (placeholders OK if you use Lab Flasher).
6. Upload `soilgood_heartbeat.ino` **once** (shared binary for all kits).
7. **Primary:** Admin Web (Chrome) → Devices → **Provision & Flash** (Web Serial).  
   **Backup:** [`tooling/lab_flasher`](../../../tooling/lab_flasher/) Windows app.  
   Then sticker claim code.
8. Wiring: 12V → sensor RED/BLACK; MAX485 A/B; ESP32 D16/D17/D4/D5/3V3/GND; USB for Serial.
9. Serial 115200: soil numbers + `POST 200` + UUID. After the farmer claims the code, Home shows live readings.

## SGCFG (Lab Flasher)

After boot the firmware prints `SGCFG_WAIT` and listens ~20s (also accepts config while running).

Host sends one line:

```text
SGCFG|{"device_uid":"...","ingest_token":"...","wifi_ssid":"...","wifi_password":"...","supabase_url":"...","supabase_anon":"..."}|
```

Board replies `SGCFG_OK` and restarts (or `SGCFG_ERR`). Close other serial monitors before flashing.

Interval: successful POST waits `POST_EVERY_MS` (~15 min). Modbus fail retries after `RETRY_FAIL_MS` (10s).
