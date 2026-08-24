# SoilGood — Future enhancements: ESP32 claim & multi-sensor

> Not in v1 scope. Keeps product direction clear so we do not paint ourselves into a corner.
> Related: [DATA_MODEL.md](DATA_MODEL.md), [BACKEND.md](BACKEND.md), [../pages/onboarding.md](../pages/onboarding.md).

## Current v1 (locked)

- **App rule:** 1 farm + 1 ESP32 per user (enforced in UI / onboarding, not a hard DB UNIQUE).
- **Claim today:** farmer types a `device_uid` → app inserts/links `devices` → shows `ingest_token` for firmware `secrets.h`.
- **Why it feels wrong for farmers:** typing invents identity; `ingest_token` is a developer secret; no proof they hold the physical unit.
- **Schema already flexible:** `devices.farm_id` + `soil_readings.device_id` support **N devices per farm** once the app allows it.

---

## Enhancement A — Real device claim (pre-provision + code/QR)

### Goal
Farmer proves they own a physical SoilGood kit without flashing firmware or copying secrets.

### Ops model (QR does **not** come from the ESP32 chip)

Espressif boards have no built-in product QR. **We** create the claim label when we provision:

```text
Lab / team
  1. Flash ESP32 (device_uid + ingest_token burned in — farmer never sees token)
  2. Insert devices row: status = unclaimed, farm_id = null, claim_code = SG-XXXX
  3. Print sticker or card (QR and/or short code) → stick on enclosure / box
  4. Hand kit to farmer

Farmer
  1. Open app → Scan QR or type claim_code
  2. RPC links device to their farm → status = active
  3. Home shows live readings / last_seen_at → confirmation it is theirs
```

| Proof | Meaning |
|---|---|
| Physical sticker / card | Possession of that unit |
| One-time `claim_code` | Cannot be claimed by another account |
| `farm_id` + RLS | Only their account sees the data |
| Live soil + `last_seen_at` | That hardware is talking |

- **QR** = convenience (encode claim URL or code).
- **Short code only** is enough for thesis/demo if printing QR is noisy.
- Farmer-facing UI must **not** show `ingest_token`.

### Likely schema / backend tweaks (small)

| Change | Why |
|---|---|
| `devices.farm_id` **nullable** until claimed | Pre-provision rows without a farm |
| `devices.claim_code` (unique, short) | What farmer scans/types |
| Optional `claimed_at` | Audit / support |
| RPC `claim_device(claim_code)` | Atomic: only if unclaimed → set `farm_id`, `status = active` |

Ingest path (`device_uid` + `ingest_token` → `ingest_soil_reading`) stays the same.

### Optional later: SoftAP / BLE WiFi setup

Separate from ownership: after claim, phone configures farm WiFi on the ESP32. Nice for field install; not required to ship claim-code ownership.

---

## Enhancement B — v1.5 multi-sensor / multi-ESP32 (same farm)

### Goal
One farm, several ESP32 units (zones). AI and Home can say **where** it is dry, not only that the farm is dry.

```text
Farm "Bukid ni Juan"
  ├── Device A — name/zone: "Malapit sa balon"
  ├── Device B — name/zone: "Gitna ng taniman"
  └── Device C — name/zone: "Dulo / drainage"
```

### Farmer flow

1. Claim first device (onboarding) — same as Enhancement A.
2. Profile / Devices → **Add sensor** → scan/type another `claim_code`.
3. Prompt for zone label (maps to `devices.name` or a dedicated `zone_label`).
4. Home: pick zone **or** farm summary; AI uses labeled readings.

### AI behavior (zone-aware)

| Stage | What AI says |
|---|---|
| v1 (1 sensor) | Farm-wide: e.g. “Patubigan ngayon” |
| v1.5 (N sensors + names) | Zone-aware: e.g. “Dry sa **Malapit sa balon**; OK sa gitna” |

Do **not** blindly average all sensors for irrigation — a dry patch can hide inside an average. Prefer per-zone status + one farm summary action (“irrigate the balon side first”).

### Schema vs UI — what actually changes?

**Mostly UI + app logic + AI prompts.** Core tables already fit:

- `devices` → many rows per `farm_id`
- `soil_readings.device_id` → knows which ESP32 wrote the row
- `devices.name` → can hold zone labels (“Malapit sa balon”)

| Layer | Multi-sensor work |
|---|---|
| **Schema** | Little/none for “N devices”; optional `zone_label` if you want name ≠ zone |
| **Claim (Enhancement A)** | Small columns + RPC (see above) — do this once; scales to N claims |
| **App** | Remove 1-device cap; device list; Add sensor; zone naming |
| **Home / Analytics** | Zone picker or multi-zone cards; history filter by `device_id` |
| **AI / notifications** | Pass zone names + per-device latest readings; alerts can say which zone |

v1 stays **1 sensor** in the UI so Home/AI stay simple for thesis. Unlock multi-device when zone naming + summary UX exist.

---

## Suggested order

1. **Enhancement A** — pre-provision + claim_code (QR optional) — real ownership.
2. Keep **v1 UI** at 1 active device.
3. **v1.5** — Add sensor + zone labels + zone-aware Home/AI.

## Out of scope here

- Multi-farm accounts
- OS push (FCM) when app is killed
- Paid device registries / commercial IoT platforms
