# Page: Signup & Onboarding

> Covers account signup + first-run onboarding (profile, farm location, device claim).

## Status
- [ ] Planned
- [x] In progress
- [ ] Done

### Implemented
- Login + signup UI + Supabase auth
- **Forgot password** — email a reset link; opening it in the same browser asks for a new password (same strength rules as signup)
- Session-aware `AuthGate` routed by onboarding status
- **Step 1 Profile** — saves to `profiles`
- **Step 2 Farm location** — GPS + map pin (tap to move), **Carto Voyager** tiles, saves to `farms`
- **Step 3 Soil texture** — farmer picks texture class; saves to `farms.soil_texture`
- **Step 4 Device claim** — sticker `claim_code` → RPC `claim_device` (skippable); **never** shows `ingest_token`
- App shell with Home / Analytics / Crops / Profile
- **Live soil readings** on Home via Supabase stream (empty state if none)

### Still pending
- QR scan for claim code (type-only is enough for v1)
- SoftAP / BLE WiFi setup (orthogonal; after claim)
- Reverse-geocoding address from pin (optional)
- **Soil texture + optional series** — farmer selects texture (required); optional BSWM/PhilRice series under same step. Curated series overrides texture in crop match. Research: [`../context/SOIL_TEXTURE_CROP_FIT.md`](../context/SOIL_TEXTURE_CROP_FIT.md), [`../context/SOIL_SERIES_CROP_FIT.md`](../context/SOIL_SERIES_CROP_FIT.md). NCCAG = future: [`../context/FUTURE_ENHANCEMENTS_SOIL.md`](../context/FUTURE_ENHANCEMENTS_SOIL.md).

### Won’t do (v1)
- Profile / onboarding copy of `ingest_token` — lab-only secret

## Purpose / goal
Get a new farmer from zero to a ready account: create login, capture name, set the farm location (for weather), and link their ESP32 — without overwhelming them in one giant form.

## Flow overview (split into steps)
1. **Signup** — email format, password strength (8+ chars, letter, number, symbol), confirm-password match. Live checklist under the password field. Login only checks that email/password are present and email looks valid (does not re-check strength).
2. **Onboarding** (separate screens after first login):
   1. Profile — first name, last name, address (barangay / municipality / province)
   2. Farm location — GPS auto-detect + **draggable map pin** to correct
   3. **Soil texture** — pick farm texture (feel hints); optional curated **soil series** (Skip / Other). Series overrides texture in crop match when curated.
   4. Device claim — type `claim_code` from the kit sticker (lab must have pre-provisioned the row)

Splitting keeps each step light and makes it obvious where a user gets stuck.

## User flow
- Farmer opens app → not logged in → **Login** screen with “Create account”.
- Signup: email + password → account created → session active.
- First login with incomplete profile/farm/device → routed into **onboarding**.
- After onboarding complete → main app shell (dashboard).

## Farm location (GPS + draggable pin)
- On the location step, app requests **location permission** and reads current GPS.
- Show a **map with a pin** at detected coordinates + readable address if available.
- Farmer can **drag the pin** (or move the map) to the real farm location — typical detect-then-correct pattern.
- Requires an explicit **“Use this location”** confirm; do **not** auto-save silently (wrong location breaks weather).
- Save final `latitude`, `longitude` (+ address text) to `farms`.

## Data & sources
- **Auth:** Supabase Auth (`signUp`, `signInWithPassword`).
- **Profile:** `profiles` row auto-created by DB trigger on signup; onboarding **updates** it.
- **Farm:** insert one row in `farms` (owner_id = auth.uid()), with lat/long from map.
- **Device:** RPC `claim_device(p_claim_code)` links a pre-provisioned `devices` row (`farm_id` null → farm; `status = active`). Kits are created by **Admin Web** ([`admin_devices.md`](admin_devices.md)) or SQL. SQL claim: [`../context/supabase_device_claim.sql`](../context/supabase_device_claim.sql).
- **GPS:** `geolocator`; map tiles: **Carto Voyager** (free, via `AppMapTiles`) — not default OSM “ugly” raster.
- Cached: current onboarding progress so a reopen resumes at the right step.

## UI states
| State | What the user sees |
|---|---|
| Skeleton | Form scaffold while checking session / permissions |
| Cached | Previously entered values if returning mid-onboarding |
| Live | Map pin updates as GPS resolves / pin is dragged |
| Empty | Clear prompts on each field |
| Error | Visible errors: invalid email, weak password, permission denied, bad/used claim code, farm already has a sensor, network fail (no silent fallback) |

## Optimistic UI
| Action | Optimistic change | On failure |
|---|---|---|
| Save profile step | Advance to next step immediately | Rollback to step + visible error |
| Save farm location | Show “saved” + proceed | Rollback + error, stay on map |
| Claim device | Show device as linked | Rollback + error (code not found / already used / farm already linked) |

Signup itself is **not** optimistic — wait for real auth result before proceeding.

## Functions
| Function | What it does | When called |
|---|---|---|
| `signUpWithEmail()` | Create auth account (email+password) | Signup submit |
| `signInWithEmail()` | Log in existing user | Login submit |
| `sendPasswordReset()` | Email a Supabase reset link | Forgot password submit |
| `updatePassword()` | Save the new password on the recovery session | Reset link opened |
| `AuthGate` | React to Supabase session changes and swap login/authenticated content | App startup and auth changes |
| `loadOnboardingStatus()` | Check what’s missing (profile/farm/device) | After login |
| `saveProfile()` | Update `profiles` name + address | Profile step |
| `detectLocation()` | Read current GPS coordinates | Location step open |
| `updatePinLocation()` | Update coords when pin dragged | Pin drag / map move |
| `saveFarmLocation()` | Insert/update `farms` lat/long + address | Location confirm |
| `saveSoilTexture()` | *(replaced)* use `saveSoilPhysicalProfile` | — |
| `saveSoilPhysicalProfile()` | Update `farms.soil_texture` + optional `soil_series` / `soil_series_other` | Soil texture step |
| `claimDevice(claimCode)` | RPC `claim_device` — link sticker code to farm | Device step submit |

## Page logic flowchart
```mermaid
flowchart TD
  A[Open app] --> B{Logged in?}
  B -->|No| C[Login / Signup]
  C --> D[signUp or signIn]
  D --> E{Onboarding complete?}
  B -->|Yes| E
  E -->|Profile missing| F[Profile step -> saveProfile]
  F --> G[Location step]
  E -->|Farm missing| G[Location step: GPS + draggable pin]
  G --> H{User confirms location?}
  H -->|No| G
  H -->|Yes| I[saveFarmLocation]
  I --> J[Soil texture step]
  J --> K2[saveSoilTexture]
  K2 --> L[Device step: enter claim_code]
  E -->|Soil texture missing| J
  E -->|Device missing| L
  L --> K{claim_code valid and unclaimed?}
  K -->|No| M[Show error, stay]
  K -->|Yes| N[claim_device RPC -> active]
  N --> O[Enter main app shell / dashboard]
  E -->|All complete| O
```

## Related
- Shared widgets: themed text fields, primary button, map picker, step header.
- Connects to: main app shell / dashboard (after completion).
- Data model: `profiles`, `farms`, `devices` in [../context/DATA_MODEL.md](../context/DATA_MODEL.md).
- Device ops: [../context/FUTURE_ENHANCEMENTS_DEVICES.md](../context/FUTURE_ENHANCEMENTS_DEVICES.md).
- Open decisions:
  - Whether address text is reverse-geocoded (free service) or typed manually.
  - Confirm-email ON/OFF for development.
