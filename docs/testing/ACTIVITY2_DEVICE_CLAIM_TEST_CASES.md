# Activity 2 — Convert Scenario into Test Cases (3 cases)

Chosen scenario: TS-01 – Verify that adding / claiming a new IoT soil sensor on the farm works correctly.

App: SoilGood

Typical components used below: Test Case ID · Title · Preconditions · Test Steps · Test Data · Expected Result · Actual Result & Status.

Execution note: Actual results below are from automated runs (flutter test test/critical/ — unit + UI E2E harness) on 2026-09-17. Harness uses the real claim screen UI with fake claim backend (no live Supabase for these runs).

---

## TC_DEVICE_001 — Positive / Happy Path

| Field | Content |
|---|---|
| Test Case ID | TC_DEVICE_001 |
| Title / Description | Claim sensor with a valid unused sticker code |
| Related Scenario | TS-01 – Adding / claiming a new IoT soil sensor on the farm |
| Preconditions | User is signed in. Farm onboarding (profile, location, soil texture) is complete. Farm has no linked sensor yet. Unclaimed kit with code SG-7K2M exists. User is on the Link your sensor screen. |
| Test Steps | 1. Look at the Claim code field and confirm it is empty. 2. Tap the Claim code field. 3. Type SG-7K2M. 4. Tap Link sensor. 5. Wait until the loading indicator on the button stops. 6. Check whether an error banner appeared. 7. Check whether the app left the claim screen and opened the main app (Home / shell). 8. Optionally confirm in Supabase that the device farm_id is now this farm. |
| Test Data | Claim code: SG-7K2M |
| Expected Result | Claim succeeds. No error banner. App opens the main shell. Device is linked to the farm. Farmer never sees ingest_token. |
| Actual Result | After typing SG-7K2M and tapping Link sensor, no error banner appeared. App left the claim screen and opened the Home (E2E) soil panel. Latest moisture shown as 42% (seeded post-claim Home). ingest_token was not shown. |
| Status | Pass |

---

## TC_DEVICE_002 — Negative / Error Path

| Field | Content |
|---|---|
| Test Case ID | TC_DEVICE_002 |
| Title / Description | Reject claim when the sticker code was already used |
| Related Scenario | TS-01 – Adding / claiming a new IoT soil sensor on the farm |
| Preconditions | User is signed in and on Link your sensor. Farm has no linked sensor. Code SG-USED1 was already claimed by another farm. |
| Test Steps | 1. Tap the Claim code field. 2. Type SG-USED1. 3. Tap Link sensor. 4. Wait for the response. 5. Read the error banner text carefully. 6. Confirm you are still on the claim screen (not inside Home via a successful claim). 7. Try to continue only after changing the code (optional retry check). |
| Test Data | Claim code: SG-USED1 |
| Expected Result | Claim fails. Error banner shows: This claim code was already used. Device is not linked to this farm. No ingest_token is shown. |
| Actual Result | Error banner showed exactly: This claim code was already used. Home screen did not open. User remained on the claim screen. No ingest_token shown. |
| Status | Pass |

---

## TC_DEVICE_003 — Boundary / Edge Case

| Field | Content |
|---|---|
| Test Case ID | TC_DEVICE_003 |
| Title / Description | Accept claim code typed with spaces and lowercase letters |
| Related Scenario | TS-01 – Adding / claiming a new IoT soil sensor on the farm |
| Preconditions | User is signed in and on Link your sensor. Farm has no linked sensor. Unclaimed kit SG-7K2M exists. |
| Test Steps | 1. Tap the Claim code field. 2. Type two spaces, then sg-7k2m, then two spaces (  sg-7k2m  ). 3. Do not manually delete the spaces. 4. Tap Link sensor. 5. Wait until loading finishes. 6. Check for error banner. 7. Check if the app opened the main shell (success) the same way as an exact SG-7K2M claim. |
| Test Data | Claim code input:   sg-7k2m   (normalizes to SG-7K2M) |
| Expected Result | App trims and uppercases the code. Claim succeeds like the happy path. No error banner. Device is linked. |
| Actual Result | Input   sg-7k2m   was accepted. Code normalized to SG-7K2M. Claim succeeded; Home (E2E) opened with moisture 42%. No error banner. |
| Status | Pass |

---

## Coverage (Activity 2 — 3 paths)

| Type | Test Case ID |
|---|---|
| Positive / Happy | TC_DEVICE_001 |
| Negative / Error | TC_DEVICE_002 |
| Boundary / Edge | TC_DEVICE_003 |
