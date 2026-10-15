# SoilGood — Future enhancements: ESP32 claim & multi-sensor

> SoftAP/BLE WiFi and multi-sensor remain later. **Claim-by-code (Enhancement A) is the current product path** — SQL: [`supabase_device_claim.sql`](supabase_device_claim.sql).
> Related: [DATA_MODEL.md](DATA_MODEL.md), [BACKEND.md](BACKEND.md), [../pages/onboarding.md](../pages/onboarding.md).

## Current v1 (claim code)

- **App rule:** 1 farm per user. **Several ESP32 kits** can share that farm. Each kit is placed on the current crop. The farmer-facing name is the sticker code: `Sensor (SG-7K2M)`.
- **Claim:** lab pre-provisions `devices` (`farm_id` null, `claim_code`, `ingest_token` burned in firmware). The first kit is claimed in onboarding with no plot yet. Later kits are added from **Profile → Sensors** or from the selected crop on the Farm tab: type the code, and the app places the kit on that crop. **Never** show `ingest_token` in the app.
- **WiFi:** still set in `secrets.h` at flash time (SoftAP/BLE = separate, later).
- **Schema:** `devices.farm_id` + `soil_readings.device_id` already support **N devices per farm** once the app allows it (Enhancement B).

### Lab checklist (per kit)

1. **Lab Flasher** (Windows) → **Provision & Flash** (or Admin Web provision + manual secrets) → sticker claim code.
2. Flash ESP32 (`DEVICE_UID`, `INGEST_TOKEN`, WiFi, Supabase anon URL/key) via USB + Arduino IDE.
3. Write `claim_code` on tape/card on the box.
4. Hand kit to farmer → onboarding types the code → Home shows readings when online.

---

## Enhancement A — Real device claim (pre-provision + code/QR) — implemented (type-only)

### Goal
Farmer proves they own a physical SoilGood kit without flashing firmware or copying secrets.

### Ops model (QR does **not** come from the ESP32 chip)

Espressif boards have no built-in product QR. **We** create the claim label when we provision:

```text
Lab / team
  1. Flash ESP32 (device_uid + ingest_token burned in — farmer never sees token)
  2. Insert devices row: status = unclaimed, farm_id = null, claim_code = SG-XXXX
  3. Print sticker or card (short code; QR optional later) → stick on enclosure / box
  4. Hand kit to farmer

Farmer
  1. Open app → Type claim_code
  2. RPC claim_device links device to their farm → status = active
  3. Home shows live readings / last_seen_at → confirmation it is theirs
```

| Proof | Meaning |
|---|---|
| Physical sticker / card | Possession of that unit |
| One-time `claim_code` | Cannot be claimed by another account |
| `farm_id` + RLS | Only their account sees the data |
| Live soil + `last_seen_at` | That hardware is talking |

- **QR** = convenience later (encode claim URL or code).
- **Short code only** is the v1 path.
- Farmer-facing UI must **not** show `ingest_token`.

### Schema / backend (shipped)

| Change | Why |
|---|---|
| `devices.farm_id` **nullable** until claimed | Pre-provision rows without a farm |
| `devices.claim_code` (unique, short) | What farmer types |
| `claimed_at` | Audit / support |
| RPC `claim_device(claim_code)` | Atomic: only if unclaimed → set `farm_id`, `status = active` |
| No farmer INSERT on `devices` | Lab SQL only; app cannot mint tokens |

Ingest path (`device_uid` + `ingest_token` → `ingest_soil_reading`) stays the same.

### Optional later: SoftAP / BLE WiFi setup

**Orthogonal to claim** — answers “which WiFi?” not “whose account?”. After claim (or on install day), phone configures farm WiFi on the ESP32. Nice for field install; not required for claim-code ownership. No extra hardware beyond ESP32’s built-in WiFi/BLE radio. Plan separately after claim is stable.

---

## Enhancement B — several sensors on one crop (sticker code)

Shipped for the **current crop**: Profile → Sensors, or Add sensor on the selected plot. The kit is named by its sticker code (`Sensor (SG-7K2M)`), not by a place nickname. Home and alerts say **Sensor (code) area is low** for the kit that is actually dry. A second crop at the same time is still one active planting — place the kits on that crop.

Place nicknames (“Malapit sa balon”) and a multi-plot picture grid are later. Do **not** average sensors for irrigation.

### Still later

- Place nicknames instead of the sticker code
- Several crops on the farm map at once
- AI that names the sticker code in the recommendation, not only in the alert

The alert already says which code is low. Do not average those readings into one farm number.

### Schema vs UI — what actually changes?

**Mostly UI + app logic + AI prompts.** Core tables already fit:

- `devices` → many rows per `farm_id`
- `soil_readings.device_id` → knows which ESP32 wrote the row
- `devices.name` → can hold zone labels (“Malapit sa balon”)

| Layer | Multi-sensor work |
|---|---|
| **Schema** | Little/none for “N devices”; optional `zone_label` if you want name ≠ zone |
| **Claim (Enhancement A)** | Done once; scales to N claims when UI unlocks |
| **App** | Remove 1-device cap; device list; Add sensor; zone naming |
| **Home / Analytics** | Zone picker or multi-zone cards; history filter by `device_id` |
| **AI / notifications** | Pass zone names + per-device latest readings; alerts can say which zone |

v1 stays **1 sensor** in the UI so Home/AI stay simple for thesis. Unlock multi-device when zone naming + summary UX exist.

---

## Suggested order

1. **Enhancement A** — claim_code (done; QR optional later). Admin Web: [`../pages/admin_devices.md`](../pages/admin_devices.md). Lab Flasher: [`../pages/lab_flasher.md`](../pages/lab_flasher.md).
2. Keep **v1 UI** at 1 active device.
3. SoftAP/BLE WiFi (optional field polish).
4. **v1.5** — Add sensor + zone labels + zone-aware Home/AI.

## Out of scope here

- Multi-farm accounts
- OS push (FCM) when the app is killed
- Paid device registries / commercial IoT platforms
