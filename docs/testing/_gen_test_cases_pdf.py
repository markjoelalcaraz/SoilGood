"""Generate SoilGood TS-01..TS-10 test cases PDF (happy + error per scenario).

Happy path tables use a blue Field|Details header (image 1).
Error path tables use a red Field|Details header (image 2).
"""

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch, mm
from reportlab.platypus import (
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

OUT = Path(__file__).with_name("SOILGOOD_TEST_CASES_TS01_TS10.pdf")

# Blue header (happy) / red header (error) — close to class template images
HEADER_HAPPY = colors.Color(0.16, 0.42, 0.72)  # steel blue
HEADER_ERROR = colors.Color(0.55, 0.14, 0.18)  # dark red
GRID = colors.Color(0.45, 0.45, 0.45)
LABEL_BG = colors.Color(0.96, 0.96, 0.96)

# Each case: path Happy Path | Error Path; pre/steps/expected use <br/> numbered lines.
CASES: list[dict[str, str]] = [
    # --- TS-01 Device claim ---
    {
        "id": "TC_DEVICE_001",
        "path": "Happy Path",
        "title": "Claim sensor with a valid unused sticker code",
        "scenario": "TS-01 – Verify that adding / claiming a new IoT soil sensor on the farm works correctly.",
        "pre": "1. The SoilGood app is installed and can reach Supabase.<br/>"
        "2. The farmer is signed in.<br/>"
        "3. Profile, farm location, and soil texture onboarding are complete.<br/>"
        "4. This farm has no linked device yet.<br/>"
        "5. An unclaimed kit with claim_code SG-7K2M exists (farm_id null).<br/>"
        "6. The user is on the Link your sensor screen.",
        "steps": "1. Confirm the Claim code field is empty.<br/>"
        "2. Tap the Claim code field.<br/>"
        "3. Enter SG-7K2M.<br/>"
        "4. Tap Link sensor.<br/>"
        "5. Wait until the button loading indicator stops.<br/>"
        "6. Check for an error banner.<br/>"
        "7. Confirm the app opens the main shell (Home).",
        "data": "Claim code: SG-7K2M",
        "expected": "1. The claim succeeds.<br/>"
        "2. No error banner is shown.<br/>"
        "3. The app opens the main shell / Home.<br/>"
        "4. The device farm_id is set to this farm.<br/>"
        "5. The farmer never sees ingest_token.",
    },
    {
        "id": "TC_DEVICE_002",
        "path": "Error Path",
        "title": "Reject claim when the sticker code was already used",
        "scenario": "TS-01 – Verify that adding / claiming a new IoT soil sensor on the farm works correctly.",
        "pre": "1. The farmer is signed in and on Link your sensor.<br/>"
        "2. Profile and farm onboarding are complete.<br/>"
        "3. This farm has no linked device yet.<br/>"
        "4. Claim code SG-USED1 was already claimed by another farm.",
        "steps": "1. Tap the Claim code field.<br/>"
        "2. Enter SG-USED1.<br/>"
        "3. Tap Link sensor.<br/>"
        "4. Wait for the response.<br/>"
        "5. Read the error banner.<br/>"
        "6. Confirm the user is still on the claim screen.",
        "data": "Invalid / edge data<br/>Claim code: SG-USED1",
        "expected": "1. The claim fails.<br/>"
        "2. Error banner shows: This claim code was already used.<br/>"
        "3. No device is linked to this farm.<br/>"
        "4. ingest_token is not shown.<br/>"
        "5. The user remains on Link your sensor.",
    },
    # --- TS-02 Auth ---
    {
        "id": "TC_AUTH_001",
        "path": "Happy Path",
        "title": "Successful login with valid credentials then logout",
        "scenario": "TS-02 – Verify that user registration, login, and logout work correctly.",
        "pre": "1. The SoilGood app is accessible on a supported device.<br/>"
        "2. A registered farmer account already exists.<br/>"
        "3. The user is currently logged out on the Welcome Back screen.<br/>"
        "4. Network is available.",
        "steps": "1. Tap the Email Address field.<br/>"
        "2. Enter a valid registered email.<br/>"
        "3. Tap the Password field.<br/>"
        "4. Enter the correct password.<br/>"
        "5. Tap Sign in / Login.<br/>"
        "6. Wait until navigation finishes (onboarding or app shell).<br/>"
        "7. Open Profile.<br/>"
        "8. Tap Logout / Sign out.<br/>"
        "9. Confirm the login screen is shown again.",
        "data": "Email: farmer@example.com<br/>Password: Farmpass1!",
        "expected": "1. The user is authenticated successfully.<br/>"
        "2. The app opens onboarding or the main shell.<br/>"
        "3. Logout returns to the login screen.<br/>"
        "4. The previous session can no longer open farm data without signing in again.",
    },
    {
        "id": "TC_AUTH_002",
        "path": "Error Path",
        "title": "Login failure with invalid password",
        "scenario": "TS-02 – Verify that user registration, login, and logout work correctly.",
        "pre": "1. The SoilGood app is accessible.<br/>"
        "2. A registered farmer account exists.<br/>"
        "3. The user is logged out on the login screen.<br/>"
        "4. Network is available.",
        "steps": "1. Tap Email Address and enter the valid farmer email.<br/>"
        "2. Tap Password and enter an incorrect password.<br/>"
        "3. Tap Sign in / Login.<br/>"
        "4. Wait for the response.<br/>"
        "5. Read the error banner.<br/>"
        "6. Confirm Home / shell did not open.",
        "data": "Invalid / edge data<br/>Email: farmer@example.com<br/>Password: WrongPass999!",
        "expected": "1. The login attempt fails.<br/>"
        "2. A visible error message is shown.<br/>"
        "3. The user remains on the login page.<br/>"
        "4. No session grants access to farm soil or device data.",
    },
    # --- TS-03 Onboarding ---
    {
        "id": "TC_ONB_001",
        "path": "Happy Path",
        "title": "Complete profile, farm pin, and soil texture onboarding",
        "scenario": "TS-03 – Verify that farm onboarding (profile, location pin, soil texture / soil series) works correctly.",
        "pre": "1. The farmer is newly signed in.<br/>"
        "2. Profile, farm location, and soil texture are not yet saved.<br/>"
        "3. Location permission can be granted when asked.<br/>"
        "4. Network is available.",
        "steps": "1. On Profile, enter first name and required fields.<br/>"
        "2. Tap Continue / Save.<br/>"
        "3. On Location, set the farm pin on the map (or use current location).<br/>"
        "4. Save the farm location.<br/>"
        "5. On Soil texture, select a texture and optional soil series.<br/>"
        "6. Save and continue to device claim (or shell if claim is later).",
        "data": "First name: Juan<br/>Soil texture: Clay Loam (or any listed value)<br/>Farm pin: valid lat/long in the Philippines",
        "expected": "1. Each onboarding step saves successfully.<br/>"
        "2. The farm row stores location and soil texture.<br/>"
        "3. The user can proceed to the next required step.<br/>"
        "4. No silent skip of required profile or pin.",
    },
    {
        "id": "TC_ONB_002",
        "path": "Error Path",
        "title": "Block continue when required onboarding fields are empty",
        "scenario": "TS-03 – Verify that farm onboarding (profile, location pin, soil texture / soil series) works correctly.",
        "pre": "1. The farmer is signed in on the Profile onboarding screen.<br/>"
        "2. Required profile fields are empty.<br/>"
        "3. Farm pin has not been set.",
        "steps": "1. Leave First name empty.<br/>"
        "2. Tap Continue / Save.<br/>"
        "3. Note any validation message.<br/>"
        "4. If Location can be opened, try to continue without a pin.<br/>"
        "5. Confirm the app does not treat the farm as fully onboarded into Home.",
        "data": "Invalid / edge data<br/>First name: (empty)<br/>Farm pin: (none)",
        "expected": "1. Validation errors appear for required fields.<br/>"
        "2. Onboarding does not complete.<br/>"
        "3. The user cannot enter the main shell as a fully set-up farm.<br/>"
        "4. No invented farm coordinates are saved.",
    },
    # --- TS-04 Ingest ---
    {
        "id": "TC_SOIL_001",
        "path": "Happy Path",
        "title": "Ingest a valid 8-in-1 soil reading into Supabase",
        "scenario": "TS-04 – Verify that ESP32 soil readings are correctly received, validated, and stored in Supabase.",
        "pre": "1. A claimed device exists with valid device_uid and ingest_token.<br/>"
        "2. The ingest_soil_reading RPC is deployed.<br/>"
        "3. Network between device/test client and Supabase is available.",
        "steps": "1. Call ingest_soil_reading with in-range 8-in-1 values.<br/>"
        "2. Wait for the RPC response.<br/>"
        "3. Open soil_readings in Supabase (or refresh Home).<br/>"
        "4. Confirm a new row exists for this device.<br/>"
        "5. Confirm stored fields match the payload.",
        "data": "moisture_percent: 45<br/>ph: 6.5<br/>salinity: 0.5<br/>validation_status: ok<br/>Valid device_uid + ingest_token",
        "expected": "1. The RPC succeeds.<br/>"
        "2. One new soil_readings row is stored for the device.<br/>"
        "3. Values match the sent payload.<br/>"
        "4. The reading can become the latest on Home.",
    },
    {
        "id": "TC_SOIL_002",
        "path": "Error Path",
        "title": "Reject ingest with invalid device credentials",
        "scenario": "TS-04 – Verify that ESP32 soil readings are correctly received, validated, and stored in Supabase.",
        "pre": "1. The ingest_soil_reading RPC is available.<br/>"
        "2. The tester can call the RPC with a wrong ingest_token.<br/>"
        "3. Sensor values in the payload are otherwise in range.",
        "steps": "1. Call ingest_soil_reading with a device_uid and wrong ingest_token.<br/>"
        "2. Use otherwise valid moisture/pH values.<br/>"
        "3. Observe the RPC error.<br/>"
        "4. Confirm no new accepted reading was created from this forged call.",
        "data": "Invalid / edge data<br/>device_uid: (any)<br/>ingest_token: wrong-token<br/>moisture_percent: 45",
        "expected": "1. The RPC fails (invalid device credentials or equivalent).<br/>"
        "2. No successful soil reading is stored for the forged call.<br/>"
        "3. Failure is visible to the tester/logs — not a silent accept.",
    },
    # --- TS-05 Home live truth ---
    {
        "id": "TC_HOME_001",
        "path": "Happy Path",
        "title": "Home shows the newest soil reading as live truth",
        "scenario": "TS-05 – Verify that Home shows the correct latest live soil condition and never silently shows fake or stale-as-fresh data.",
        "pre": "1. The farmer is signed in with a claimed device.<br/>"
        "2. At least two readings exist: older (moisture 20) and newer (moisture 42, pH 6.4).<br/>"
        "3. The user opens the Home tab.",
        "steps": "1. Open the Home tab.<br/>"
        "2. Wait for soil cards / latest reading to load.<br/>"
        "3. Note the moisture value shown.<br/>"
        "4. Note the timestamp or reading identity if shown.<br/>"
        "5. Confirm values match the newest reading, not the older one.",
        "data": "Older reading: moisture 20<br/>Newer reading: moisture 42, pH 6.4",
        "expected": "1. Home displays the newer reading (moisture 42).<br/>"
        "2. The older reading is not shown as current live truth.<br/>"
        "3. Live 8-in-1 values match the newest row.",
    },
    {
        "id": "TC_HOME_002",
        "path": "Error Path",
        "title": "Home empty or failed load never invents healthy soil values",
        "scenario": "TS-05 – Verify that Home shows the correct latest live soil condition and never silently shows fake or stale-as-fresh data.",
        "pre": "1. The farmer is signed in.<br/>"
        "2. The farm has a claimed device but zero soil_readings rows, or soil fetch is forced to fail.<br/>"
        "3. The user opens Home.",
        "steps": "1. Open the Home tab.<br/>"
        "2. Wait for first load to finish.<br/>"
        "3. Check whether moisture/pH show invented numbers presented as live OK.<br/>"
        "4. Check for empty or error messaging.<br/>"
        "5. Pull to refresh and confirm the same rule holds.",
        "data": "Invalid / edge data<br/>soil_readings: none<br/>Or simulated soil fetch failure",
        "expected": "1. A visible empty or error state is shown.<br/>"
        "2. No fake live moisture/pH is presented as normal healthy soil.<br/>"
        "3. Pull-to-refresh does not invent default healthy values.",
    },
    # --- TS-06 Water today ---
    {
        "id": "TC_WATER_001",
        "path": "Happy Path",
        "title": "Water today tip matches dry soil with low rain chance",
        "scenario": "TS-06 – Verify that irrigation / water today guidance is correct based on current soil + weather.",
        "pre": "1. The user is on Home with a latest soil reading.<br/>"
        "2. Moisture is in a dry or critical_dry band.<br/>"
        "3. Today rain probability is below the skip threshold (below 60%).<br/>"
        "4. Farm pin exists so Open-Meteo weather can load.<br/>"
        "5. Home Water today tip can load.",
        "steps": "1. Open Home and wait for soil, weather, and Water today tip.<br/>"
        "2. Note the moisture band / value.<br/>"
        "3. Note rain chance on the forecast strip if shown.<br/>"
        "4. Read the Water today / irrigation tip card.<br/>"
        "5. Confirm the tip tells the farmer to irrigate (or clear dry guidance).",
        "data": "Moisture band: dry or critical_dry<br/>Rain probability today: below 60%",
        "expected": "1. Water today recommends irrigating (or urgent water-today guidance).<br/>"
        "2. The tip is consistent with dry soil and low rain chance.<br/>"
        "3. Guidance is tied to the current soil + weather context.",
    },
    {
        "id": "TC_WATER_002",
        "path": "Error Path",
        "title": "Do not urge watering when soil is critically wet",
        "scenario": "TS-06 – Verify that irrigation / water today guidance is correct based on current soil + weather.",
        "pre": "1. The latest reading moisture is in critical_wet or wet band.<br/>"
        "2. The user is on Home with tips loaded.",
        "steps": "1. Open Home with the wet reading as latest.<br/>"
        "2. Wait for Water today / irrigation tip.<br/>"
        "3. Read the tip carefully.<br/>"
        "4. Confirm it does not tell the farmer to water today.",
        "data": "Invalid / edge condition<br/>Moisture band: critical_wet (or wet)",
        "expected": "1. Guidance says do not water / check drainage (or equivalent).<br/>"
        "2. The app must not recommend irrigating while critically wet.<br/>"
        "3. Wrong dry-day watering advice is not shown as current.",
    },
    # --- TS-07 Out-of-band alerts ---
    {
        "id": "TC_ALERT_001",
        "path": "Happy Path",
        "title": "Critical soil out-of-band reading creates a soil alert",
        "scenario": "TS-07 – Verify that nutrient and soil out-of-band alerts fire correctly for critical readings.",
        "pre": "1. The app shell is open so the notification evaluator can run.<br/>"
        "2. The latest reading has a critical pH or salinity (or similar) band.<br/>"
        "3. No soil_alert exists yet for this Manila day (first insert allowed).",
        "steps": "1. Ensure a latest reading with critical out-of-band soil facts is present.<br/>"
        "2. Allow the notification engine to evaluate.<br/>"
        "3. Open Notifications (or check farm_notifications).<br/>"
        "4. Confirm a soil_alert (or equivalent) appears.<br/>"
        "5. Confirm severity is urgent when the band is critical.",
        "data": "Example: ph_band critical_low<br/>Or salinity_band critical_high",
        "expected": "1. A soil out-of-band alert is created or shown.<br/>"
        "2. Title/body mention the soil issue.<br/>"
        "3. Critical bands use urgent severity.<br/>"
        "4. At most one of that type per farm per Manila day.",
    },
    {
        "id": "TC_ALERT_002",
        "path": "Error Path",
        "title": "Normal in-band reading does not create a false soil alert",
        "scenario": "TS-07 – Verify that nutrient and soil out-of-band alerts fire correctly for critical readings.",
        "pre": "1. The latest reading has ok bands for pH, temp, EC, salinity, and nutrients.<br/>"
        "2. The shell / evaluator can run.<br/>"
        "3. The reading is fresh.",
        "steps": "1. Load a fresh in-range reading with ok bands.<br/>"
        "2. Run or wait for notification evaluation.<br/>"
        "3. Check Notifications for soil_alert or nutrient_low.<br/>"
        "4. Confirm none of those false alerts appear for this reading.",
        "data": "Invalid / edge condition for false positive<br/>All soil/nutrient bands: ok<br/>Fresh recorded_at",
        "expected": "1. No soil_alert is raised for a fully ok reading.<br/>"
        "2. No nutrient_low alert is raised when N/P/K bands are ok.<br/>"
        "3. The farmer is not falsely alarmed.",
    },
    # --- TS-08 Device offline ---
    {
        "id": "TC_OFFLINE_001",
        "path": "Happy Path",
        "title": "Emit device_offline when latest reading is older than 2 hours",
        "scenario": "TS-08 – Verify that device-offline / no-new-reading detection works when the sensor stops sending.",
        "pre": "1. A claimed device exists.<br/>"
        "2. Latest soil reading recorded_at is more than 2 hours ago.<br/>"
        "3. The app shell is open.<br/>"
        "4. No device_offline alert yet for this Manila day.",
        "steps": "1. Confirm the latest reading timestamp is older than 2 hours.<br/>"
        "2. Allow notification evaluation to run.<br/>"
        "3. Open Notifications or inspect alert drafts.<br/>"
        "4. Confirm device_offline appears.",
        "data": "staleAfter: 2 hours<br/>recorded_at: now minus 3 hours",
        "expected": "1. A device_offline alert is shown or saved.<br/>"
        "2. Message indicates the sensor has not reported.<br/>"
        "3. Dedupe is once per farm per Manila day.",
    },
    {
        "id": "TC_OFFLINE_002",
        "path": "Error Path",
        "title": "Do not mark device offline when a fresh reading exists",
        "scenario": "TS-08 – Verify that device-offline / no-new-reading detection works when the sensor stops sending.",
        "pre": "1. Latest reading recorded_at is within the last 10 minutes.<br/>"
        "2. The evaluator can run.<br/>"
        "3. Soil bands may be ok.",
        "steps": "1. Confirm the latest reading is fresh (about 10 minutes old).<br/>"
        "2. Run notification evaluation.<br/>"
        "3. Check for device_offline.<br/>"
        "4. Confirm it is absent.",
        "data": "Invalid / edge condition for false offline<br/>recorded_at: now minus 10 minutes",
        "expected": "1. No device_offline alert is raised.<br/>"
        "2. Fresh data is not treated as sensor-down.<br/>"
        "3. The farmer is not told the device is offline incorrectly.",
    },
    # --- TS-09 Owner-only access ---
    {
        "id": "TC_RLS_001",
        "path": "Happy Path",
        "title": "Signed-in owner can see own farm soil on Home",
        "scenario": "TS-09 – Verify that only the authenticated farm owner can access their soil, farm, and device data.",
        "pre": "1. User A owns Farm A with a claimed device.<br/>"
        "2. At least one soil reading exists for that device.<br/>"
        "3. The active session is User A.",
        "steps": "1. Sign in as User A.<br/>"
        "2. Open Home.<br/>"
        "3. Confirm soil readings for Farm A appear.<br/>"
        "4. Confirm the owner is not blocked from their own data.",
        "data": "Session: User A<br/>Farm A soil reading present",
        "expected": "1. User A can view Farm A soil on Home.<br/>"
        "2. Device-linked readings for Farm A are visible.<br/>"
        "3. Access matches the authenticated owner session.",
    },
    {
        "id": "TC_RLS_002",
        "path": "Error Path",
        "title": "User B cannot see User A soil data",
        "scenario": "TS-09 – Verify that only the authenticated farm owner can access their soil, farm, and device data.",
        "pre": "1. User A has Farm A with soil readings.<br/>"
        "2. User B has a separate account and farm.<br/>"
        "3. The tester can sign in as User B.",
        "steps": "1. Sign in as User B.<br/>"
        "2. Open Home.<br/>"
        "3. Confirm User A moisture/readings are not shown.<br/>"
        "4. If any path accepts a farm id, attempt User A farm id and confirm deny or empty.",
        "data": "Invalid / edge data<br/>Session: User B<br/>Target: Farm A readings",
        "expected": "1. User B only sees own farm data (or empty).<br/>"
        "2. User A readings are not visible.<br/>"
        "3. No cross-farm data leak occurs.",
    },
    # --- TS-10 AI freshness ---
    {
        "id": "TC_AI_001",
        "path": "Happy Path",
        "title": "Reuse saved Home AI when soil and weather story are unchanged",
        "scenario": "TS-10 – Verify that AI recommendations are tied to the correct soil reading + weather snapshot and do not reuse outdated advice when inputs change.",
        "pre": "1. Home already has a saved kind=home assessment.<br/>"
        "2. It is tied to the current soil reading and weather fingerprint.<br/>"
        "3. valid_until is still in the future.<br/>"
        "4. The user is on Home.",
        "steps": "1. Open Home and note Condition / Water today / Nutrients tip text.<br/>"
        "2. Pull to refresh without changing soil or weather inputs.<br/>"
        "3. Confirm the same saved tips remain (no unnecessary regen required).<br/>"
        "4. Confirm tips still match the current reading / story.",
        "data": "Same soil_reading_id<br/>Same weather story<br/>Assessment still valid",
        "expected": "1. Saved Home AI is reused.<br/>"
        "2. Tips stay tied to the current reading and weather.<br/>"
        "3. No wrong tips from a different reading are shown as current.",
    },
    {
        "id": "TC_AI_002",
        "path": "Error Path",
        "title": "Do not keep old AI tips after a new soil reading changes the story",
        "scenario": "TS-10 – Verify that AI recommendations are tied to the correct soil reading + weather snapshot and do not reuse outdated advice when inputs change.",
        "pre": "1. Home shows tips for Reading Old (dry story).<br/>"
        "2. A new Reading New arrives with a different band story (e.g. wet).<br/>"
        "3. Home is open or refreshed so AI can recheck.",
        "steps": "1. Note tips while Reading Old is latest.<br/>"
        "2. Insert or receive Reading New with a different moisture story.<br/>"
        "3. Wait for Home AI recheck or pull to refresh.<br/>"
        "4. Confirm tips regenerate or update for Reading New.<br/>"
        "5. Confirm dry-water advice is not left as current when soil is now wet.",
        "data": "Invalid / edge condition<br/>Reading Old: dry<br/>Reading New: wet or critical_wet",
        "expected": "1. Outdated dry-water advice is not left as current.<br/>"
        "2. New tips match Reading New (or loading then new tips).<br/>"
        "3. AI is not stuck on the old soil_reading_id story.",
    },
]


def _header_color(path: str):
    return HEADER_HAPPY if path == "Happy Path" else HEADER_ERROR


def build_case_table(case: dict[str, str], styles) -> Table:
    label = styles["label"]
    body = styles["body"]
    header = styles["headerCell"]

    rows = [
        [Paragraph("Field", header), Paragraph("Details", header)],
        [Paragraph("Test Case ID", label), Paragraph(case["id"], body)],
        [Paragraph("Title", label), Paragraph(case["title"], body)],
        [Paragraph("Related Scenario", label), Paragraph(case["scenario"], body)],
        [Paragraph("Preconditions", label), Paragraph(case["pre"], body)],
        [Paragraph("Test Steps", label), Paragraph(case["steps"], body)],
        [Paragraph("Test Data", label), Paragraph(case["data"], body)],
        [Paragraph("Expected Result", label), Paragraph(case["expected"], body)],
    ]
    table = Table(rows, colWidths=[1.55 * inch, 5.25 * inch])
    hc = _header_color(case["path"])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), hc),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("BACKGROUND", (0, 1), (0, -1), LABEL_BG),
                ("BACKGROUND", (1, 1), (1, -1), colors.white),
                ("BOX", (0, 0), (-1, -1), 0.9, GRID),
                ("INNERGRID", (0, 0), (-1, -1), 0.6, GRID),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return table


def main() -> None:
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="headerCell",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=14,
            textColor=colors.white,
        )
    )
    styles.add(
        ParagraphStyle(
            name="label",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=13,
            textColor=colors.Color(0.1, 0.1, 0.1),
        )
    )
    styles.add(
        ParagraphStyle(
            name="body",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13,
            alignment=TA_LEFT,
        )
    )
    styles.add(
        ParagraphStyle(
            name="docTitle",
            parent=styles["Heading1"],
            fontSize=16,
            leading=20,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="caseHead",
            parent=styles["Heading2"],
            fontSize=11,
            leading=14,
            spaceBefore=2,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="scenarioLine",
            parent=styles["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=9,
            leading=12,
            textColor=colors.Color(0.25, 0.25, 0.25),
            spaceAfter=6,
        )
    )

    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=14 * mm,
        rightMargin=14 * mm,
        topMargin=14 * mm,
        bottomMargin=14 * mm,
        title="SoilGood Test Cases TS-01 to TS-10",
        author="SoilGood",
    )

    story: list = [
        Paragraph("SoilGood — Test Cases (TS-01 to TS-10)", styles["docTitle"]),
        Spacer(1, 10),
    ]

    for i, case in enumerate(CASES):
        block = [
            Paragraph(f"{case['id']} — {case['path']}", styles["caseHead"]),
            Paragraph(f"Related Scenario: {case['scenario']}", styles["scenarioLine"]),
            build_case_table(case, styles),
            Spacer(1, 10),
        ]
        story.append(KeepTogether(block))
        if (i + 1) % 2 == 0 and i != len(CASES) - 1:
            story.append(PageBreak())

    doc.build(story)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
