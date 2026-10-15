# SoilGood Lab Flasher (Windows) — **backup**

Desktop backup for **Provision & Flash**. **Primary path:** Admin Web on Chrome → Devices → Provision & Flash (Web Serial).

Same Supabase RPCs + SGCFG protocol as the website.

## Prerequisites

1. Run SQL (in order if not already):  
   `supabase_device_claim.sql` → `supabase_admin.sql` → promote your admin email → **`supabase_lab_flash.sql`**
2. Upload base firmware once per board (Arduino IDE): `firmware/esp32/soilgood_heartbeat/`  
   - Install library **ArduinoJson** (v6)  
   - `secrets.h` can be placeholders; Lab Flasher overwrites NVS
3. Windows PC with ESP32 USB driver (CH340 / CP210x)
4. Close Arduino Serial Monitor before flashing (port exclusive)

## Setup

```bash
cd tooling/lab_flasher
copy .env.example .env
# Fill SUPABASE_* and WIFI_SSID / WIFI_PASSWORD (2.4 GHz lab/test WiFi)
flutter pub get
flutter run -d windows
```

You can also put `WIFI_SSID` / `WIFI_PASSWORD` in the **repo-root** `.env`; the app loads `../../.env` when run from this folder.

## Flow

1. Sign in as **admin**
2. Plug one ESP32 (or pick port if multiple)
3. Optional label → **Provision & Flash**
4. Write the big **claim code** on the box → farmer claims in the phone app

If flash fails after provision: claim code stays on screen → **Retry flash only** (does not create a second device).

## Protocol

Line sent at 115200 8N1:

```text
SGCFG|{"device_uid":"...","ingest_token":"...","wifi_ssid":"...","wifi_password":"...","supabase_url":"...","supabase_anon":"..."}|
```

Board replies `SGCFG_OK` and restarts (or `SGCFG_ERR`). After reset, firmware prints `SGCFG_WAIT` for ~20s — press EN if the window was missed.

## Out of scope (this version)

- Full esptool binary + NVS partition generate
- Web Serial in Chrome Admin
- SoftAP/BLE WiFi provisioning
