# SoilGood — Critical Test Cases (Top 5)

High-severity scenarios only. Each scenario has:

- **Template A** — Positive / Happy Path (`…_001`)
- **Template B** — Negative / Error Path (`…_002`)

**Automation plan (locked for this batch):** Unit tests first.  
Tag legend: `Unit` = automate now · `Widget` / `E2E` = later.

Related product docs: [FEATURES.md](../context/FEATURES.md), [SECURITY.md](../context/SECURITY.md), [DATA_MODEL.md](../context/DATA_MODEL.md), ingest SQL [`supabase_esp32_ingest.sql`](../context/supabase_esp32_ingest.sql), claim SQL [`supabase_device_claim.sql`](../context/supabase_device_claim.sql).

---

## Scenarios (Critical)

| ID | Scenario | Why Critical |
|---|---|---|
| **TS-01** | Device claim (link ESP32 to farm) | No device → no soil truth |
| **TS-02** | Soil ingest + range validation | Bad/lost readings corrupt the system |
| **TS-03** | Live Home soil truth | Wrong “live” data → wrong field decisions |
| **TS-04** | Auth / RLS farm boundary | Farmer must never see another farm’s data |
| **TS-05** | Critical alerts (sensor error / device offline) | Missed danger or offline sensor |

---

## TS-01 — Device claim

### TC_DEVICE_001 — Template A (Happy Path)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_DEVICE_001` |
| **Title** | Claim unclaimed kit with valid sticker code |
| **Related Scenario** | TS-01 – Device claim (link ESP32 to farm) |
| **Automation** | `Unit` (claim-code normalize + error mapping); `E2E` later |
| **Preconditions** | User signed in; farm location saved; lab row exists with `claim_code = SG-7K2M`, `farm_id` null, status unclaimed; farm has no linked device yet |
| **Test Steps** | 1. Open device onboarding (claim) screen. 2. Enter claim code `sg-7k2m` (lowercase / spaces OK). 3. Submit claim. 4. Confirm RPC `claim_device` succeeds. 5. Confirm device now has this farm’s `farm_id` and farmer never receives `ingest_token`. |
| **Test Data** | Claim code: `SG-7K2M` (input may be `sg-7k2m`); farm with lat/long set |
| **Expected Result** | Device linked to farm; success continues onboarding / into shell; `ingest_token` not shown; friendly success path (no raw PostgREST error) |

---

### TC_DEVICE_002 — Template B (Negative / Error)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_DEVICE_002` |
| **Title** | Reject already-used or unknown claim code |
| **Related Scenario** | TS-01 – Device claim (link ESP32 to farm) |
| **Automation** | `Unit` (`_friendlyClaimError` / empty-code guard) |
| **Preconditions** | User signed in; farm exists; code `SG-USED1` already claimed by another farm **or** code does not exist |
| **Test Steps** | 1. Open claim screen. 2. Enter invalid / used code. 3. Submit. 4. Observe rejection (no partial link). |
| **Test Data** | Empty: `""` · Unknown: `SG-XXXX` · Used: `SG-USED1` · Farm already has sensor (second claim attempt) |
| **Expected Result** | Claim fails; device `farm_id` unchanged for unknown/used cases. Farmer sees one of: `Enter the claim code from your sensor box` · `Claim code not found. Check the code on your box` · `This claim code was already used` · `This farm already has a sensor linked` — never raw stack / never `ingest_token` |

---

## TS-02 — Soil ingest + validation

### TC_SOIL_001 — Template A (Happy Path)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_SOIL_001` |
| **Title** | Ingest valid 8-in-1 reading via `ingest_soil_reading` |
| **Related Scenario** | TS-02 – Soil ingest + range validation |
| **Automation** | `Unit` (range rules mirrored from SQL); SQL/RPC check in CI later |
| **Preconditions** | Device claimed; valid `device_uid` + `ingest_token`; farm_id set |
| **Test Steps** | 1. Call `ingest_soil_reading` with in-range payload. 2. Confirm row inserted into `soil_readings`. 3. Confirm `recorded_at` / device link correct. 4. Confirm Home can treat it as latest. |
| **Test Data** | moisture `45`, pH `6.5`, soil_temp `28`, EC in catalog-safe band, salinity `0.5`, N/P/K typical seed values (see [`supabase_seed_soil_reading.sql`](../context/supabase_seed_soil_reading.sql)) |
| **Expected Result** | One new `soil_readings` row; validation accepts; reading becomes latest for that farm/device |

---

### TC_SOIL_002 — Template B (Negative / Error)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_SOIL_002` |
| **Title** | Reject out-of-range sensor values (no silent accept) |
| **Related Scenario** | TS-02 – Soil ingest + range validation |
| **Automation** | `Unit` (range predicates); matches ingest SQL raises |
| **Preconditions** | Valid device credentials available for RPC call |
| **Test Steps** | 1. Attempt ingest with out-of-range field. 2. Confirm RPC raises. 3. Confirm no new “good” reading row (or status is visibly failed — never silent normal). 4. Repeat for bad credentials. |
| **Test Data** | moisture `-1` or `101` → `moisture out of range` · pH `-0.1` or `14.1` → `ph out of range` · salinity above allowed max → `salinity out of range` · wrong `ingest_token` → `invalid device credentials` |
| **Expected Result** | Ingest rejected; farmer-facing path shows sensor error / visible failure; values never treated as normal soil guidance |

---

## TS-03 — Live Home soil truth

### TC_HOME_001 — Template A (Happy Path)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_HOME_001` |
| **Title** | Home shows latest valid reading as current soil truth |
| **Related Scenario** | TS-03 – Live Home soil truth |
| **Automation** | `Unit` (latest-row selection / mapping); `Widget` later |
| **Preconditions** | Claimed device; at least two readings — older stale + newer valid; user on Home |
| **Test Steps** | 1. Load Home with seeded readings. 2. Confirm UI/model binds to **newest** `recorded_at`. 3. Confirm 8-in-1 fields match that row. 4. Confirm timestamp shown is that reading’s time. |
| **Test Data** | Reading A: `recorded_at` = now−3h, moisture `20` · Reading B: now−5m, moisture `42`, pH `6.4` (B must win) |
| **Expected Result** | Home displays Reading B only as live truth; older row not shown as current |

---

### TC_HOME_002 — Template B (Negative / Error)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_HOME_002` |
| **Title** | Empty / failed / stale reading never looks like fresh healthy soil |
| **Related Scenario** | TS-03 – Live Home soil truth |
| **Automation** | `Unit` (empty + stale flags); `Widget` later for banners |
| **Preconditions** | Cases: (a) no readings, (b) fetch error, (c) latest reading older than freshness policy used by UI/alerts |
| **Test Steps** | 1. Open Home with no readings. 2. Open Home with soil fetch failure. 3. Open Home with only a very old reading. 4. Confirm no fake defaults presented as live OK. |
| **Test Data** | Empty list · network/timeout error · reading `recorded_at` = now−5h (stale vs 2h offline policy) |
| **Expected Result** | Visible empty / error / stale state; no invented moisture/pH; no silent “all good” dashboard |

---

## TS-04 — Auth / RLS farm boundary

### TC_AUTH_001 — Template A (Happy Path)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_AUTH_001` |
| **Title** | Signed-in owner can read own farm soil and device |
| **Related Scenario** | TS-04 – Auth / RLS farm boundary |
| **Automation** | `Unit` (repo filters by session user); full RLS = Supabase policy test later |
| **Preconditions** | User A owns Farm A + claimed device + soil rows; session is User A |
| **Test Steps** | 1. Sign in as User A. 2. Fetch latest soil / device for session. 3. Confirm Farm A rows returned. |
| **Test Data** | User A email/session; Farm A id; soil row belonging to A’s device |
| **Expected Result** | Own farm data returned; app can render Home for A |

---

### TC_AUTH_002 — Template B (Negative / Error)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_AUTH_002` |
| **Title** | User B cannot read User A’s soil, device, or claim A’s kit |
| **Related Scenario** | TS-04 – Auth / RLS farm boundary |
| **Automation** | `Unit` (client must not bypass with forged farm_id); RLS/SQL later |
| **Preconditions** | User A and User B exist; Farm A has soil; User B signed in |
| **Test Steps** | 1. As User B, query soil/device for Farm A id (if client allows parameter). 2. Attempt claim of a code already owned / not visible. 3. Confirm deny. |
| **Test Data** | User B session; Farm A UUID; User A soil reading ids; foreign `claim_code` |
| **Expected Result** | Empty / permission error; no cross-farm rows; claim cannot steal linked device; anon client never uses `service_role` |

---

## TS-05 — Critical alerts

### TC_ALERT_001 — Template A (Happy Path)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_ALERT_001` |
| **Title** | Emit `device_offline` when latest reading exceeds stale window |
| **Related Scenario** | TS-05 – Critical alerts (sensor error / device offline) |
| **Automation** | `Unit` (`NotificationEvaluator`, `staleAfter = 2h`) |
| **Preconditions** | Shell open / evaluator runs; farm has device; latest reading older than 2 hours; no `device_offline` yet today (Manila day dedupe) |
| **Test Steps** | 1. Feed evaluator a reading with `recorded_at` = now−3h. 2. Run evaluate. 3. Confirm alert type `device_offline`. 4. Confirm dedupe key once per farm per Manila day. |
| **Test Data** | `staleAfter`: 2 hours · `recorded_at`: now−3h · type: `device_offline` |
| **Expected Result** | One `device_offline` notification persisted (or returned by evaluator); unread path can badge; not spammed same Manila day |

---

### TC_ALERT_002 — Template B (Negative / Error)

| Field | Content |
|---|---|
| **Test Case ID** | `TC_ALERT_002` |
| **Title** | Out-of-range / sensor_error path; no offline alert when reading is fresh |
| **Related Scenario** | TS-05 – Critical alerts (sensor error / device offline) |
| **Automation** | `Unit` (`NotificationEvaluator`) |
| **Preconditions** | Evaluator available; cases for sensor_error vs fresh OK reading |
| **Test Steps** | 1. Feed invalid/out-of-band reading flagged as sensor error → expect `sensor_error`. 2. Feed fresh in-range reading (now−10m) → expect **no** `device_offline`. 3. Re-run same offline condition twice same day → second must dedupe (no duplicate spam). |
| **Test Data** | sensor_error payload / validation failure · fresh reading now−10m · duplicate evaluate same YMD |
| **Expected Result** | `sensor_error` when appropriate; no false `device_offline` on fresh data; at most one of each type per farm per Manila day |

---

## Unit automation map

| TC | Status | Unit target | Test file |
|---|---|---|---|
| `TC_DEVICE_001` / `002` | **Done** | `normalizeClaimCode` + `friendlyClaimError` | `test/critical/tc_device_002_claim_reject_test.dart` |
| `TC_SOIL_001` / `002` | **Done** | `validateSoilIngestRanges` | `test/critical/tc_soil_002_range_reject_test.dart` |
| `TC_HOME_001` / `002` | **Done** | `pickLatestReading` / `classifyLiveSoilTruth` | `test/critical/tc_home_001_latest_reading_test.dart` |
| `TC_AUTH_001` / `002` | **Done** (client scope) | `session_access_rules` ownership + strip token | `test/critical/tc_auth_001_session_boundary_test.dart` |
| `TC_ALERT_001` / `002` | **Done** | `NotificationEvaluator` | `test/critical/tc_alert_001_device_offline_test.dart` |

Run: `flutter test test/critical/`

Production helpers:

- `lib/features/onboarding/logic/device_claim_rules.dart`
- `lib/core/soil/soil_ingest_ranges.dart`
- `lib/features/home/logic/live_soil_truth.dart`
- `lib/features/auth/logic/session_access_rules.dart`

**Note:** `TC_AUTH_*` unit-tests the **client ownership filter** (same shape as `SoilReadingsRepository`). Postgres RLS policies remain an integration/SQL check later.

---

## E2E automation (UI harness)

Drives **real widgets** with typed claim codes and taps. Uses fake claim + seeded readings (no live Supabase) via [`lib/testing/critical_e2e_host.dart`](../../lib/testing/critical_e2e_host.dart).

| Flow | Status | File |
|---|---|---|
| Claim empty / used / valid → Home | **Done** | `test/critical/e2e_critical_flows_test.dart` |
| Home latest / empty / stale+offline alert | **Done** | same |
| Device-bound `integration_test/` | Scaffold ready | `integration_test/critical_flows_e2e_test.dart` (needs Android emulator; web unsupported) |

Run harness E2E:

```bash
flutter test test/critical/e2e_critical_flows_test.dart
```

All critical unit + E2E harness:

```bash
flutter test test/critical/
```

`DeviceOnboardingPage` accepts optional `claimDevice` / `onClaimSuccess` for this harness; production path unchanged (still uses `OnboardingRepository` + `AppShell`).

---

## Out of scope for this batch

Profile edit, logout, Analytics browse, crop catalog browse, payment (N/A), full Groq E2E, FCM when app killed.
