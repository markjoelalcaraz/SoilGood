"""
SoilGood 5-chapter project documentation generator (revised).

Changes from previous revision:
- Database Design: schema tables per entity (Field | Type | Description),
  no ERD diagram.
- Use Case Diagram: stickman style (generated separately by build_use_case.py).
- Chapter 3 (Tools, Development Process): narrative + bulleted sub-sections,
  no tables.
- System Features: "Feature N: Name / Description" narrative, no table.
- Functional Testing: simplified test case titles, three-column table.
- Evaluation: Strengths and Weaknesses bullet lists.

Run:  python docs/paper/build_paper.py
"""

from pathlib import Path

from docx import Document
from docx.enum.table import WD_ALIGN_VERTICAL
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
FIGURES = HERE / "figures"
OUT = HERE / "SoilGood_System_Paper.docx"

# ---------------------------------------------------------------------------
# Style constants
# ---------------------------------------------------------------------------
BODY_FONT = "Times New Roman"
BODY_SIZE = Pt(12)
LINE_SPACING = 1.5

GREEN = RGBColor(0x4A, 0x7C, 0x59)   # SoilGood primary
GREEN_HEX = "4A7C59"
DARK = RGBColor(0x24, 0x30, 0x28)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)


# ---------------------------------------------------------------------------
# Run / paragraph helpers
# ---------------------------------------------------------------------------
def set_run(run, *, bold=False, italic=False, size=None, color=None,
            font=BODY_FONT):
    """Apply font/size/color/bold/italic to a run."""
    run.font.name = font
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        rfonts.set(qn(attr), font)
    if size is not None:
        run.font.size = size
    if color is not None:
        run.font.color.rgb = color
    run.bold = bold
    run.italic = italic


def set_paragraph_spacing(p, *, line=LINE_SPACING, space_after=Pt(6),
                          space_before=Pt(0)):
    fmt = p.paragraph_format
    fmt.line_spacing = line
    fmt.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    fmt.space_after = space_after
    fmt.space_before = space_before


def add_body(doc, text, *, indent_first=True, align=WD_ALIGN_PARAGRAPH.JUSTIFY):
    """Add a justified body paragraph."""
    p = doc.add_paragraph()
    p.alignment = align
    set_paragraph_spacing(p, space_after=Pt(6))
    if indent_first:
        p.paragraph_format.first_line_indent = Cm(1.27)
    run = p.add_run(text)
    set_run(run, size=BODY_SIZE, color=DARK)
    return p


def add_centered(doc, text, *, bold=False, size=Pt(12), color=DARK,
                 space_after=Pt(6), space_before=Pt(0)):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    set_paragraph_spacing(p, space_after=space_after,
                          space_before=space_before)
    run = p.add_run(text)
    set_run(run, bold=bold, size=size, color=color)
    return p


def add_chapter_title(doc, chapter_label, chapter_title):
    add_page_break(doc)
    add_centered(doc, chapter_label, bold=True, size=Pt(16), color=GREEN,
                 space_after=Pt(4))
    add_centered(doc, chapter_title, bold=True, size=Pt(16), color=DARK,
                 space_after=Pt(18))


def add_heading(doc, text, *, level=1):
    """Section heading styled, kept in Word's heading styles for TOC."""
    p = doc.add_paragraph(style=f"Heading {level}")
    set_paragraph_spacing(p,
                          space_before=Pt(14) if level == 1 else Pt(10),
                          space_after=Pt(6))
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = p.add_run(text)
    size = Pt(14) if level == 1 else Pt(12)
    set_run(run, bold=True, size=size, color=GREEN)
    return p


def add_sub_label(doc, text):
    """Bold narrative sub-label (used inside Chapter 3 sections).

    Not a Heading style — just a visually grouped sub-section marker that
    does not break paragraph flow and does not appear in the TOC.
    """
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    set_paragraph_spacing(p, space_before=Pt(10), space_after=Pt(2))
    run = p.add_run(text)
    set_run(run, bold=True, size=BODY_SIZE, color=DARK)
    return p


def add_feature_block(doc, name, description):
    """Narrative 'Feature N: Name / Description:' block (no table)."""
    # Name line (bold, dark)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    set_paragraph_spacing(p, space_before=Pt(10), space_after=Pt(2))
    run = p.add_run(name)
    set_run(run, bold=True, size=BODY_SIZE, color=GREEN)

    # "Description:" label
    p2 = doc.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.LEFT
    set_paragraph_spacing(p2, space_after=Pt(2))
    run2 = p2.add_run("Description:")
    set_run(run2, bold=True, size=BODY_SIZE, color=DARK)

    # Description paragraph
    add_body(doc, description, indent_first=False)


def add_numbered(doc, items):
    for item in items:
        p = doc.add_paragraph(style="List Number")
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        set_paragraph_spacing(p, space_after=Pt(4))
        run = p.add_run(item)
        set_run(run, size=BODY_SIZE, color=DARK)


def add_bullets(doc, items):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        set_paragraph_spacing(p, space_after=Pt(4))
        run = p.add_run(item)
        set_run(run, size=BODY_SIZE, color=DARK)


def add_figure(doc, image_path, caption, *, width_inches=5.5):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    set_paragraph_spacing(p, space_before=Pt(10), space_after=Pt(4))
    run = p.add_run()
    run.add_picture(str(image_path), width=Inches(width_inches))

    cap = doc.add_paragraph()
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    set_paragraph_spacing(cap, space_after=Pt(12))
    run = cap.add_run(caption)
    set_run(run, italic=True, size=Pt(11), color=DARK)


def add_page_break(doc):
    p = doc.add_paragraph()
    p.add_run().add_break(WD_BREAK.PAGE)


def add_table_caption(doc, text):
    """Italic centered caption placed above a table."""
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    set_paragraph_spacing(p, space_before=Pt(10), space_after=Pt(4))
    run = p.add_run(text)
    set_run(run, italic=True, size=Pt(11), color=DARK)


def add_toc(doc):
    """Insert Word's auto TOC field (populate with F9 inside Word)."""
    p = doc.add_paragraph()
    run = p.add_run()
    fld_begin = OxmlElement("w:fldChar")
    fld_begin.set(qn("w:fldCharType"), "begin")

    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = r'TOC \o "1-2" \h \z \u'

    fld_sep = OxmlElement("w:fldChar")
    fld_sep.set(qn("w:fldCharType"), "separate")

    placeholder = OxmlElement("w:t")
    placeholder.text = (
        "Right-click here and choose 'Update Field' to build the Table of "
        "Contents."
    )

    fld_end = OxmlElement("w:fldChar")
    fld_end.set(qn("w:fldCharType"), "end")

    r_el = run._element
    r_el.append(fld_begin)
    r_el.append(instr)
    r_el.append(fld_sep)
    r_el.append(placeholder)
    r_el.append(fld_end)


# ---------------------------------------------------------------------------
# Table helpers
# ---------------------------------------------------------------------------
def shade_cell(cell, hex_color):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_color)
    tc_pr.append(shd)


def set_cell_text(cell, text, *, bold=False, color=DARK, size=Pt(11),
                  align=WD_ALIGN_PARAGRAPH.LEFT):
    cell.text = ""
    p = cell.paragraphs[0]
    p.alignment = align
    set_paragraph_spacing(p, line=1.15, space_after=Pt(2), space_before=Pt(2))
    cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
    run = p.add_run(text)
    set_run(run, bold=bold, size=size, color=color)


def add_table(doc, headers, rows, *, col_widths=None):
    """Add a bordered table with a green header row."""
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_ALIGN_PARAGRAPH.CENTER

    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        shade_cell(cell, GREEN_HEX)
        set_cell_text(cell, h, bold=True, color=WHITE,
                      align=WD_ALIGN_PARAGRAPH.CENTER)

    for r, row in enumerate(rows, start=1):
        for c, val in enumerate(row):
            cell = table.rows[r].cells[c]
            align = WD_ALIGN_PARAGRAPH.LEFT
            bold = False
            header_lower = headers[c].strip().lower()
            if header_lower in ("status", "result"):
                align = WD_ALIGN_PARAGRAPH.CENTER
                bold = val.strip().lower() in ("passed", "pass")
            elif header_lower in ("type", "field"):
                # Monospace-ish feel via bold for field names only
                bold = True if header_lower == "field" else False
            set_cell_text(cell, val, align=align, bold=bold)

    if col_widths:
        for row in table.rows:
            for i, cell in enumerate(row.cells):
                cell.width = col_widths[i]

    p = doc.add_paragraph()
    set_paragraph_spacing(p, space_after=Pt(10))
    return table


def add_schema_table(doc, table_name, rows):
    """Render a per-entity schema table: 'Table: <name>' heading then
    a 3-column (Field / Type / Description) grid.
    """
    # Table-name label (bold black, matches the user's reference style)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    set_paragraph_spacing(p, space_before=Pt(12), space_after=Pt(4))
    run = p.add_run(f"Table: {table_name}")
    set_run(run, bold=True, size=Pt(12), color=DARK)

    add_table(doc, ["Field", "Type", "Description"], rows,
              col_widths=[Inches(2.0), Inches(1.4), Inches(3.1)])


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def build():
    doc = Document()

    # Page margins: 1 inch
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    normal = doc.styles["Normal"]
    normal.font.name = BODY_FONT
    normal.font.size = BODY_SIZE
    normal.font.color.rgb = DARK

    # ---------------- COVER PAGE ----------------
    add_centered(doc, "", space_after=Pt(100))
    add_centered(doc, "SOILGOOD", bold=True, size=Pt(26), color=GREEN,
                 space_after=Pt(10))
    add_centered(doc, "An IoT and AI-Based Soil Monitoring and Crop "
                      "Recommendation System for Smart Farming",
                 bold=True, size=Pt(15), color=DARK, space_after=Pt(80))

    add_centered(doc, "Final Project Documentation",
                 bold=True, size=Pt(13), color=DARK, space_after=Pt(60))

    add_centered(doc, "Course Code: CTELEC4L — Elective 4",
                 size=Pt(12), color=DARK, space_after=Pt(4))
    add_centered(doc, "Instructor: Mr. Paul John DC Cabance",
                 size=Pt(12), color=DARK, space_after=Pt(4))
    add_centered(doc, "Section: ITE232",
                 size=Pt(12), color=DARK, space_after=Pt(50))

    add_centered(doc, "Submitted by:", size=Pt(12), color=DARK,
                 space_after=Pt(4))
    add_centered(doc, "Mark Joel Alcaraz", bold=True, size=Pt(13), color=DARK,
                 space_after=Pt(50))

    add_centered(doc, "October 2026", size=Pt(12), color=DARK)

    # ---------------- TABLE OF CONTENTS ----------------
    add_page_break(doc)
    add_centered(doc, "TABLE OF CONTENTS", bold=True, size=Pt(14), color=GREEN,
                 space_after=Pt(12))
    add_toc(doc)

    # =================================================================
    # CHAPTER 1 — PROJECT OVERVIEW
    # =================================================================
    add_chapter_title(doc, "CHAPTER 1", "PROJECT OVERVIEW")

    # 1.1 Introduction
    add_heading(doc, "Introduction", level=1)
    add_body(doc,
        "Agriculture remains one of the most critical sectors in the "
        "Philippines, yet many smallholder farmers continue to rely on "
        "traditional practices and personal experience when making decisions "
        "about irrigation, fertilization, and crop selection. Without "
        "reliable soil and weather data, these decisions are often based on "
        "guesswork, which can lead to over- or under-watering, improper "
        "nutrient application, and the planting of crops that are not "
        "compatible with current soil conditions. The result is reduced "
        "yield, wasted inputs, and avoidable losses — challenges that weigh "
        "heavily on farmers whose livelihoods depend directly on the health "
        "of their land.")
    add_body(doc,
        "The emergence of low-cost Internet of Things (IoT) devices and "
        "cloud-based artificial intelligence (AI) services has opened new "
        "opportunities for data-driven farming. Soil sensors can now capture "
        "detailed, real-time information about soil condition, while AI "
        "models can translate this data into practical, farmer-friendly "
        "recommendations. These technologies, however, are often locked "
        "behind expensive commercial platforms or presented through complex "
        "dashboards that are difficult for ordinary farmers to use.")
    add_body(doc,
        "This project responds to that gap by developing SoilGood, an IoT "
        "and AI-assisted mobile application that supports farmers in "
        "irrigation, nutrient management, and crop management through "
        "real-time soil monitoring and intelligent recommendations. The "
        "system uses an ESP32 microcontroller integrated with an 8-in-1 "
        "soil sensor (moisture, pH, temperature, electrical conductivity, "
        "salinity, and NPK) to collect readings every fifteen minutes. "
        "These readings are sent to a Supabase cloud backend, combined with "
        "weather information from the Open-Meteo API, and interpreted by an "
        "AI model through a Supabase edge function. A Flutter-based mobile "
        "application then presents live soil data, weather information, "
        "historical records, and AI-assisted recommendations in a form that "
        "farmers can act on directly in the field.")

    # 1.2 Project Objectives
    add_heading(doc, "Project Objectives", level=1)
    add_heading(doc, "General Objective", level=2)
    add_body(doc,
        "To develop SoilGood, an IoT and AI-assisted mobile application "
        "that supports farmers in irrigation, nutrient management, and crop "
        "management through real-time soil monitoring and intelligent "
        "recommendations.")

    add_heading(doc, "Specific Objectives", level=2)
    add_body(doc, "Specifically, the project aims to:", indent_first=False)
    add_numbered(doc, [
        "Build an IoT-based soil monitoring device using an ESP32 integrated "
        "with soil moisture, pH, temperature, electrical conductivity (EC), "
        "salinity, and NPK sensors to collect real-time soil data.",
        "Develop a real-time monitoring module that displays soil sensor "
        "readings, weather information, and historical monitoring records.",
        "Integrate a weather API that provides current weather conditions "
        "and forecast data to support irrigation and crop management "
        "decisions.",
        "Develop an AI-assisted recommendation module that analyzes soil "
        "sensor readings and weather data to assess soil conditions, "
        "generate irrigation recommendations, identify appropriate soil "
        "management actions, and recommend crops that are compatible with "
        "the monitored soil conditions.",
    ])

    # 1.3 Scope of the Project
    add_heading(doc, "Scope of the Project", level=1)
    add_body(doc,
        "This project covers the design and development of SoilGood, an IoT "
        "and AI-assisted mobile application that supports farmers, farm "
        "owners, and agricultural practitioners in irrigation, nutrient "
        "management, and crop-related decisions. The system uses ESP32 "
        "devices with an 8-in-1 soil sensor to collect moisture, pH, "
        "temperature, EC, salinity, and NPK readings, and allows multiple "
        "sensors under one farm account for different planting plots or "
        "zones. A Flutter-based mobile application presents live soil data, "
        "weather information, historical records, and AI-assisted "
        "recommendations. Weather data from a weather API is combined with "
        "soil readings to assess soil conditions, suggest irrigation needs, "
        "identify soil management actions, and recommend compatible crops. "
        "The project focuses on SoilGood as a decision-support tool and "
        "does not aim to fully automate farm operations or replace the "
        "judgment of the farmer.")

    # 1.4 Limitations
    add_heading(doc, "Limitations", level=1)
    add_body(doc,
        "The system depends on a stable internet connection for real-time "
        "updates, cloud storage, weather retrieval, and AI-generated "
        "recommendations, so weak or unavailable connectivity may delay "
        "live monitoring and AI outputs. The application is limited to "
        "farms and devices registered within SoilGood and does not cover "
        "multi-farm accounts under one user, large-scale commercial farm "
        "platforms, or national agricultural information systems. Soil "
        "readings reflect only the conditions at each sensor's installation "
        "point, so areas without a device remain unmeasured, and results "
        "may be affected by sensor placement, calibration, or environmental "
        "interference.")
    add_body(doc,
        "Device Wi-Fi configuration is handled during laboratory setup and "
        "flashing, while farmer-side network setup through SoftAP or "
        "Bluetooth is outside the current scope. AI recommendations are "
        "advisory only and should not be treated as guaranteed agricultural "
        "prescriptions, since final decisions remain with the farmer. "
        "Weather information depends on an external free weather API, so "
        "forecast accuracy and availability are subject to the limits of "
        "that service. In-app alerts are supported while the application is "
        "in use, but push notifications when the app is fully closed are "
        "not included in this version. Lastly, the project centers on a "
        "working prototype for practical demonstration and does not include "
        "large-scale provincial deployment, paid enterprise IoT platforms, "
        "or satellite-based crop monitoring.")

    # =================================================================
    # CHAPTER 2 — SYSTEM ANALYSIS AND DESIGN
    # =================================================================
    add_chapter_title(doc, "CHAPTER 2", "SYSTEM ANALYSIS AND DESIGN")

    # 2.1 System Description
    add_heading(doc, "System Description", level=1)
    add_body(doc,
        "SoilGood is organized into four cooperating layers: the field "
        "hardware, the Supabase cloud backend, the external APIs for "
        "weather and AI, and the Flutter mobile application used by the "
        "farmer. The field layer consists of one or more ESP32 "
        "microcontrollers connected to 8-in-1 soil sensors. Each ESP32 "
        "reads the sensor at a regular interval (approximately every "
        "fifteen minutes) and submits the reading to Supabase through a "
        "constrained ingestion endpoint that uses an anonymous key and a "
        "per-device token, keeping the service role key off the device.")
    add_body(doc,
        "The Supabase cloud layer stores every soil reading and weather "
        "snapshot in structured PostgreSQL tables, broadcasts new rows "
        "through Realtime so the mobile application can update without "
        "polling, and hosts an edge function that bundles the latest soil "
        "reading and weather snapshot into a single prompt for the AI "
        "model. The external APIs layer provides current and forecast "
        "weather from Open-Meteo and language-based reasoning from the AI "
        "model. Finally, the Flutter application presents the live data "
        "and recommendations to the farmer through the Home, Analytics, "
        "Crops, and Profile tabs, with notifications accessible from a "
        "bell icon in the app bar. Figure 1 shows how these layers fit "
        "together.")
    add_figure(doc, FIGURES / "fig1_system_architecture.png",
               "Figure 1. SoilGood System Architecture.")

    # 2.2 System Flow
    add_heading(doc, "System Flow", level=1)
    add_body(doc,
        "The data flow begins the moment the ESP32 captures a soil "
        "reading and ends the moment the farmer sees a recommendation on "
        "the mobile application. Each soil reading is inserted into the "
        "soil_readings table and each weather snapshot into the "
        "weather_snapshots table. The AI edge function then combines the "
        "two most recent records, sends them to the AI model, and persists "
        "the response in the ai_assessments and ai_recommendations tables. "
        "The mobile application subscribes to these tables through Supabase "
        "Realtime, so the farmer sees the latest reading, current weather, "
        "and most recent AI assessment without manually refreshing. "
        "Figure 2 presents this flow.")
    add_figure(doc, FIGURES / "fig2_data_flow.png",
               "Figure 2. SoilGood System Data Flow.")

    # 2.3 Use Case Diagram
    add_heading(doc, "Use Case Diagram", level=1)
    add_body(doc, "The system involves the following actors and functions:",
             indent_first=False)
    add_figure(doc, FIGURES / "fig3_use_case.png",
               "Figure 3. SoilGood Use Case Diagram.", width_inches=5.5)
    add_body(doc,
        "The primary human actors are the Farmer, who performs day-to-day "
        "monitoring and decision-making through the mobile application, "
        "and the Administrator, who prepares and provisions ESP32 kits in "
        "the laboratory before they are distributed to farmers. The farmer "
        "registers an account, signs in and out, completes farm "
        "onboarding, claims an ESP32 sensor, monitors live soil and "
        "weather, views AI advice, reviews analytics, manages crops and "
        "watering logs, and reads in-app notifications. The administrator "
        "signs in, provisions new ESP32 kits, generates claim codes, and "
        "flashes device firmware. External system actors — the ESP32 "
        "device, the Open-Meteo weather API, and the AI model — "
        "participate in these flows through automated interfaces and are "
        "not shown as separate stickmen for clarity.")

    # 2.4 Database Design
    add_heading(doc, "Database Design", level=1)
    add_body(doc,
        "SoilGood uses a PostgreSQL database hosted on Supabase. The "
        "schema is designed so that each farmer owns a profile, each "
        "profile owns one or more farms, and each farm aggregates its "
        "devices, soil readings, weather snapshots, plantings, AI "
        "assessments, farm actions, and notifications. Row-Level Security "
        "(RLS) is enabled on every table so that a signed-in user can "
        "only read or write records belonging to their own farm. The "
        "schema of each table is shown below.")

    # --- schema tables ---
    add_schema_table(doc, "profiles", [
        ("id", "uuid (PK)",
         "Links 1:1 to auth.users (Supabase Auth)."),
        ("first_name / last_name", "text", "Farmer's name."),
        ("barangay / municipality_city / province", "text",
         "Farmer's home address."),
        ("role", "text", "'farmer' or 'admin'."),
        ("created_at / updated_at", "timestamptz", "Timestamps."),
    ])

    add_schema_table(doc, "farms", [
        ("id", "uuid (PK)", "Unique farm ID."),
        ("owner_id", "uuid (FK)", "References profiles(id); the owner."),
        ("name", "text", "Farm name."),
        ("barangay / municipality_city / province", "text",
         "Farm location (address)."),
        ("latitude / longitude", "double", "GPS coordinates of the farm pin."),
        ("soil_texture", "text",
         "sandy / sandy_loam / loam / clay_loam / clay / unknown."),
        ("soil_series", "text",
         "Optional Philippine soil series (e.g. maligaya, bantog)."),
        ("created_at", "timestamptz", "Timestamp."),
    ])

    add_schema_table(doc, "devices", [
        ("id", "uuid (PK)", "Unique device ID."),
        ("farm_id", "uuid (FK)",
         "References farms(id); null when the kit is unclaimed."),
        ("planting_id", "uuid (FK)",
         "References plantings(id); the active plot this sensor watches."),
        ("device_uid", "text", "Hardware UID (unique)."),
        ("ingest_token", "text",
         "Per-device auth token used for soil reading ingestion."),
        ("claim_code", "text",
         "Code printed on the kit that the farmer enters to claim it."),
        ("name", "text", "Display name (default 'SoilGood Sensor')."),
        ("status", "text",
         "unclaimed / active / offline / error."),
        ("last_seen_at / claimed_at / created_at", "timestamptz",
         "Timestamps."),
    ])

    add_schema_table(doc, "soil_readings", [
        ("id", "uuid (PK)", "Unique reading ID."),
        ("device_id", "uuid (FK)", "References devices(id)."),
        ("recorded_at", "timestamptz", "When the reading was taken."),
        ("moisture_percent", "double", "Soil moisture (%)."),
        ("ph", "double", "Soil pH."),
        ("soil_temperature_c", "double", "Soil temperature (°C)."),
        ("ec", "double", "Electrical conductivity."),
        ("salinity", "double", "Salinity level."),
        ("nitrogen / phosphorus / potassium", "double",
         "NPK macronutrient values."),
        ("validation_status", "text",
         "ok / warning / error (range check result)."),
        ("validation_message", "text", "Optional validation note."),
    ])

    add_schema_table(doc, "weather_snapshots", [
        ("id", "uuid (PK)", "Unique snapshot ID."),
        ("farm_id", "uuid (FK)", "References farms(id)."),
        ("recorded_at", "timestamptz", "When the snapshot was captured."),
        ("temperature_c", "double", "Air temperature (°C)."),
        ("humidity_percent", "double", "Humidity (%)."),
        ("rainfall_mm", "double", "Rainfall (mm)."),
        ("rain_probability", "double", "Rain probability (0–100)."),
        ("wind_speed", "double", "Wind speed."),
        ("weather_condition", "text",
         "Condition label (e.g. 'clear', 'rain')."),
        ("source", "text", "Data source label (default 'unknown')."),
    ])

    add_schema_table(doc, "crops", [
        ("id", "uuid (PK)", "Unique crop ID."),
        ("name", "text", "Crop name (unique)."),
        ("moisture_min / moisture_max", "double",
         "Preferred moisture range."),
        ("ph_min / ph_max", "double", "Preferred pH range."),
        ("temperature_min_c / temperature_max_c", "double",
         "Preferred temperature range."),
        ("ec_min / ec_max", "double", "Preferred EC range."),
        ("nitrogen / phosphorus / potassium (min / max)", "double",
         "NPK preference ranges."),
        ("salinity_min / salinity_max", "double",
         "Salinity tolerance range."),
        ("growing_season", "text", "Preferred season (e.g. wet, dry)."),
        ("notes", "text", "Additional guidance notes."),
    ])

    add_schema_table(doc, "plantings", [
        ("id", "uuid (PK)", "Unique planting ID."),
        ("farm_id", "uuid (FK)", "References farms(id)."),
        ("crop_id", "uuid (FK)", "References crops(id)."),
        ("planted_at", "date", "Planting date."),
        ("expected_harvest_at", "date", "Expected harvest date."),
        ("status", "text",
         "planned / active / harvested / failed / replaced."),
        ("created_at", "timestamptz", "Timestamp."),
    ])

    add_schema_table(doc, "ai_assessments", [
        ("id", "uuid (PK)", "Unique assessment ID."),
        ("farm_id", "uuid (FK)", "References farms(id)."),
        ("soil_reading_id", "uuid (FK)",
         "References soil_readings(id); the soil input used."),
        ("weather_snapshot_id", "uuid (FK)",
         "References weather_snapshots(id); the weather input used."),
        ("overview", "text", "AI-generated narrative assessment."),
        ("soil_health_score", "double", "Numeric overall soil health score."),
        ("generated_at", "timestamptz", "When the assessment was created."),
        ("model_name / prompt_version", "text",
         "AI model identifier and prompt version."),
    ])

    add_schema_table(doc, "ai_recommendations", [
        ("id", "uuid (PK)", "Unique recommendation ID."),
        ("assessment_id", "uuid (FK)", "References ai_assessments(id)."),
        ("type", "text",
         "irrigation / nutrient / soil_management / crop_suitability."),
        ("title / description", "text", "Recommendation text."),
        ("priority", "text", "low / medium / high."),
        ("recommended_action", "text", "Suggested concrete action."),
        ("valid_until", "timestamptz",
         "When this recommendation expires and should be regenerated."),
        ("created_at", "timestamptz", "Timestamp."),
    ])

    add_schema_table(doc, "farm_actions", [
        ("id", "uuid (PK)", "Unique action ID."),
        ("farm_id", "uuid (FK)", "References farms(id)."),
        ("created_by", "uuid (FK)",
         "References profiles(id); the farmer who logged the action."),
        ("action_type", "text",
         "irrigation / fertilizer / planting / treatment."),
        ("amount / unit", "double / text",
         "Quantity and its unit of measurement."),
        ("notes", "text", "Optional action notes."),
        ("performed_at", "timestamptz", "When the action was done."),
    ])

    add_schema_table(doc, "farm_notifications", [
        ("id", "uuid (PK)", "Unique notification ID."),
        ("farm_id", "uuid (FK)", "References farms(id)."),
        ("type", "text",
         "irrigation / nutrient_low / soil_alert / sensor_error / "
         "device_offline / phase_change."),
        ("severity", "text", "info / warning / urgent."),
        ("title / body", "text", "Notification title and message."),
        ("soil_reading_id", "uuid (FK)",
         "Optional link to soil_readings(id) when relevant."),
        ("dedupe_key", "text",
         "Dedup key: one row per type per farm per Manila day."),
        ("read_at", "timestamptz",
         "When the farmer read the notification (null if unread)."),
        ("created_at", "timestamptz", "Timestamp."),
    ])

    # =================================================================
    # CHAPTER 3 — SYSTEM DEVELOPMENT (narrative + bulleted sub-sections)
    # =================================================================
    add_chapter_title(doc, "CHAPTER 3", "SYSTEM DEVELOPMENT")

    # 3.1 Tools and Technologies Used
    add_heading(doc, "Tools and Technologies Used", level=1)
    add_body(doc,
        "SoilGood is a Flutter mobile application for farmers, backed by "
        "Supabase and an AI model, with an ESP32 microcontroller as the "
        "field sensor. The stack favors free and open components so the "
        "system stays affordable to deploy and easy for future student "
        "researchers to extend. The technologies are grouped below by the "
        "layer they belong to.")

    add_sub_label(doc, "Hardware (Field Device)")
    add_bullets(doc, [
        "ESP32 microcontroller. Reads the attached soil sensor over the "
        "RS485/UART interface and transmits readings over Wi-Fi.",
        "8-in-1 soil sensor. Captures soil moisture, pH, temperature, "
        "electrical conductivity (EC), salinity, nitrogen, phosphorus, and "
        "potassium in a single probe.",
        "Lab-flashed firmware. Each kit is pre-provisioned with a device "
        "UID, an ingest token, and the Supabase project URL so no "
        "service-role credentials ever live on the device.",
    ])

    add_sub_label(doc, "Frontend / Mobile")
    add_bullets(doc, [
        "Flutter (Dart). Cross-platform UI toolkit used to build the "
        "SoilGood mobile application. The target form factor is a small "
        "Android phone used in the field.",
        "Supabase Flutter SDK. Handles authentication, database queries, "
        "and Realtime subscriptions for the Home dashboard.",
        "SoilGood theme. Primary green (#4A7C59), matte white background, "
        "Literata and Nunito Sans typography. Tuned for readability in "
        "outdoor light and large tap targets for field use.",
        "Mapping and geolocation. Used during onboarding to let the "
        "farmer drop a GPS pin on the farm's location.",
        "Phone-first responsive layout. Content column is capped at a "
        "readable width on larger screens so tablets or Chrome do not "
        "stretch sensor cards into giant blocks.",
    ])

    add_sub_label(doc, "Backend / Data")
    add_bullets(doc, [
        "Supabase PostgreSQL. Hosts the eleven application tables listed "
        "in Chapter 2 (profiles, farms, devices, soil_readings, "
        "weather_snapshots, crops, plantings, ai_assessments, "
        "ai_recommendations, farm_actions, farm_notifications).",
        "Supabase Auth. Email and password sign-in; a profile row is "
        "auto-created for each new user through a database trigger.",
        "Supabase Realtime. New soil_readings and farm_notifications are "
        "pushed to the mobile app the moment they are inserted, so the "
        "Home dashboard updates without polling.",
        "Supabase Edge Functions. Server-side function that bundles the "
        "latest soil reading and weather snapshot and invokes the AI "
        "model, then persists the result into ai_assessments and "
        "ai_recommendations.",
        "Row-Level Security (RLS). Enabled on every table so a signed-in "
        "user can only read or write records that belong to their own "
        "farm; the device ingest path uses a constrained RPC rather than "
        "service-role access.",
    ])

    add_sub_label(doc, "AI and External Services")
    add_bullets(doc, [
        "AI model via Supabase edge function. Produces farmer-facing "
        "assessments and typed recommendations (irrigation, nutrient, "
        "soil management, crop suitability) based on the latest soil and "
        "weather inputs.",
        "Open-Meteo. Free weather API that supplies current conditions "
        "and a short forecast for the farm's GPS pin; snapshots are "
        "persisted in weather_snapshots so the AI and Analytics modules "
        "can reuse them.",
    ])

    add_sub_label(doc, "Development Environment")
    add_bullets(doc, [
        "Cursor and Visual Studio Code. Primary IDEs for Flutter and SQL "
        "work.",
        "Android Studio. Used for Flutter emulator, Android device "
        "debugging, and APK builds.",
        "Flutter SDK and Dart. Framework and language runtime for the "
        "mobile app.",
        "Arduino IDE / PlatformIO. Used to flash the ESP32 firmware with "
        "its device UID and ingest token during lab provisioning.",
        "Git and GitHub. Source-code history, branching, and backup.",
        "Android phone. Primary target device used throughout development "
        "and testing.",
    ])

    # 3.2 Development Process
    add_heading(doc, "Development Process", level=1)

    add_sub_label(doc, "Requirements Gathering")
    add_body(doc,
        "Requirements came from the observed problem in Philippine "
        "smallholder farming: real-time soil and weather information is "
        "either unavailable or locked behind expensive commercial "
        "platforms, so irrigation, fertilization, and crop decisions often "
        "rely on guesswork. Functional requirements included an IoT "
        "soil-sensing kit built around the ESP32 and an 8-in-1 sensor, a "
        "mobile dashboard that shows the latest reading and current "
        "weather, historical analytics over selectable date ranges, a crop "
        "catalog with matching and a seven-day water plan, AI-generated "
        "recommendations tied to the specific soil and weather inputs that "
        "produced them, and an in-app alert inbox. Non-functional "
        "requirements included realtime list updates so the Home screen "
        "does not need manual refresh, phone-first UX tuned for farmers in "
        "the field, Row-Level Security on every table to isolate each "
        "farmer's data, and avoidance of any service-role credentials on "
        "the ESP32.", indent_first=False)

    add_sub_label(doc, "Design")
    add_body(doc,
        "The system was split into four cooperating layers on one project: "
        "the field hardware (ESP32 + 8-in-1 sensor), the Supabase cloud "
        "backend, the external APIs (Open-Meteo and the AI model), and the "
        "Flutter mobile application. The mobile app itself was split into "
        "a farmer app shell (Home, Analytics, Crops, Profile) and an admin "
        "provisioning path that is only reachable to accounts with the "
        "'admin' role. Data design follows the schema described in "
        "Chapter 2: each farmer owns a profile, each profile owns one or "
        "more farms, and each farm aggregates its devices, soil readings, "
        "weather snapshots, plantings, AI assessments, farm actions, and "
        "notifications. AI output is treated as advisory, not "
        "prescriptive — the farmer still makes the final call — and the "
        "edge function only regenerates an assessment when its soil or "
        "weather inputs change or its validity expires.",
        indent_first=False)

    add_sub_label(doc, "Development")
    add_body(doc,
        "Modules were built iteratively, each delivered in a short "
        "plan–build–test–refine cycle that kept the prototype runnable at "
        "every stage. The order of implementation was:",
        indent_first=False)
    add_bullets(doc, [
        "User authentication and farmer onboarding (profile, farm "
        "location pin, soil texture).",
        "Admin device provisioning and the claim-code flow for ESP32 "
        "kits.",
        "ESP32 firmware and the constrained Supabase ingestion endpoint "
        "for soil readings.",
        "Home dashboard with the latest 8-in-1 reading and live updates "
        "via Supabase Realtime.",
        "Open-Meteo integration for current weather and short forecast on "
        "the Home screen.",
        "Analytics module with historical trends, period averages, and "
        "watering logs.",
        "Crops module with catalog matching, planting selection, a "
        "rolling seven-day water plan, and phase-based care insights.",
        "AI edge function and the ai_assessments / ai_recommendations "
        "pipeline, with regeneration gated on input changes.",
        "In-app notifications inbox with deduplication per farm per day.",
        "End-to-end polish, error states, offline handling, and the final "
        "testing pass.",
    ])
    add_body(doc,
        "SQL scripts under docs/context/ provision tables, grants, and "
        "RLS policies. Lab flashing scripts prepare ESP32 kits with their "
        "device UID, ingest token, and claim code before distribution. "
        "The Flutter app is built and installed on a physical Android "
        "device for day-to-day testing while the ESP32 streams live "
        "readings to the same Supabase project.", indent_first=False)

    add_sub_label(doc, "Testing")
    add_body(doc,
        "Features were tested on a real Android device connected to the "
        "production Supabase project, with a provisioned ESP32 kit "
        "transmitting live sensor readings. Tested flows included user "
        "registration and sign-out, farm onboarding, sensor claiming, "
        "sensor-to-cloud ingestion with range validation, live Home "
        "updates, Open-Meteo weather retrieval, irrigation guidance "
        "against the forecast, nutrient and soil out-of-band alerts, "
        "device-offline detection, Row-Level Security isolation between "
        "accounts, and AI recommendation reuse when inputs are unchanged. "
        "Remaining UI polish and farmer-side Wi-Fi provisioning are "
        "treated as ongoing work and are listed in Chapter 5.",
        indent_first=False)

    # =================================================================
    # CHAPTER 4 — RESULTS AND TESTING
    # =================================================================
    add_chapter_title(doc, "CHAPTER 4", "RESULTS AND TESTING")

    # 4.1 System Features (narrative Feature N: Name / Description)
    add_heading(doc, "System Features", level=1)
    add_body(doc,
        "The completed SoilGood prototype delivers the following features. "
        "Each feature was implemented, integrated with the Supabase "
        "backend, and verified on a real Android device before this "
        "documentation was prepared.")

    add_feature_block(doc, "Feature 1: User Authentication and Onboarding",
        "Farmers register and sign in using email and password through "
        "Supabase Auth. On first launch, a profile row is auto-created by "
        "a database trigger. The onboarding flow collects first and last "
        "name, Philippine address (barangay / municipality / province), "
        "farm name, a GPS pin on an interactive map, and soil texture "
        "(with optional Philippine soil series). Administrators sign in "
        "with the same auth flow and are routed to admin provisioning "
        "tools instead of the farmer app shell.")

    add_feature_block(doc, "Feature 2: ESP32 Device Claiming and Soil Data "
                           "Ingestion",
        "ESP32 kits are pre-provisioned in the laboratory with a unique "
        "claim_code, a device UID, and an ingest token. Farmers enter the "
        "claim code in the app to link a kit to their farm, and the kit "
        "can then be placed on an active planting plot. Every fifteen "
        "minutes the ESP32 submits an 8-in-1 reading (moisture, pH, "
        "temperature, EC, salinity, nitrogen, phosphorus, potassium) to "
        "Supabase through a constrained ingestion endpoint — the device "
        "uses the anonymous key plus its per-device token and never the "
        "service-role key. Readings are validated against expected ranges "
        "before storage, and out-of-range values are flagged with a "
        "validation status.")

    add_feature_block(doc, "Feature 3: Real-time Soil and Weather "
                           "Monitoring (Home)",
        "The Home dashboard shows the latest 8-in-1 soil reading with "
        "live updates via Supabase Realtime, so new rows appear within "
        "seconds without manually refreshing. Current weather and a "
        "short forecast from Open-Meteo for the farm's GPS pin are shown "
        "alongside the soil card. The AI section surfaces the current "
        "soil condition and the most recent irrigation, nutrient, and "
        "crop-care guidance tied to the latest reading and weather.")

    add_feature_block(doc, "Feature 4: Historical Analytics and Period "
                           "Insights",
        "Analytics presents historical soil trends over selectable date "
        "ranges with period averages, day-level reading review, a period "
        "weather overlay, and watering logs. A period-based AI insight "
        "summarizes the soil conditions and management actions for the "
        "selected window, giving the farmer a longer-term view that the "
        "live Home screen cannot show.")

    add_feature_block(doc, "Feature 5: Crop Matching and Cultivation "
                           "Support",
        "The Crops module matches crops from the catalog against the "
        "farm's latest soil snapshot and highlights the closest fits. "
        "Farmers can select a planting, record planted and expected "
        "harvest dates, and follow a rolling seven-day water plan "
        "generated from current soil moisture and the weather forecast. "
        "A 'Mark watered' action logs a farm_action, and phase-based "
        "care insights adapt the advice to the current growth phase of "
        "the crop.")

    add_feature_block(doc, "Feature 6: AI-Assisted Recommendation Module",
        "A Supabase edge function bundles the most recent soil reading "
        "and weather snapshot and sends them to the AI model, then "
        "persists the response as an assessment plus typed "
        "recommendations (irrigation, nutrient, soil_management, "
        "crop_suitability) with priority and a concrete recommended "
        "action. The function regenerates only when the soil or weather "
        "input changes or the assessment's validity expires; otherwise "
        "the saved assessment is reused, which avoids duplicate "
        "'thinking' and conserves API calls.")

    add_feature_block(doc, "Feature 7: In-app Notifications",
        "A bell icon in the app bar opens an inbox of classified alerts: "
        "irrigation, nutrient_low, soil_alert, sensor_error, "
        "device_offline, and phase_change. Each alert is deduplicated per "
        "farm per Manila day so the inbox does not flood when the sensor "
        "stays in the same state. Severity is color-coded (info, warning, "
        "urgent), and new notifications appear live through Supabase "
        "Realtime.")

    add_feature_block(doc, "Feature 8: Admin Device Provisioning",
        "An admin workflow prepares ESP32 kits before they are "
        "distributed to farmers. The admin signs in with the 'admin' "
        "role, provisions a kit (inserting its device UID and ingest "
        "token into the devices table with status 'unclaimed'), and "
        "generates a claim code printed on the kit's box. Firmware is "
        "flashed in the lab so the farmer never has to configure Wi-Fi "
        "credentials on first boot.")

    # 4.2 Functional Testing (simplified titles)
    add_heading(doc, "Functional Testing", level=1)
    add_body(doc,
        "The following test cases were executed to verify system "
        "functionality. Each test was performed on a real Android device "
        "connected to the production Supabase project, with a provisioned "
        "ESP32 kit transmitting live sensor readings.")

    test_headers = ["Test Case", "Expected Result", "Status"]
    test_rows = [
        ("Register / Sign in / Sign out (email + password)",
         "Account created in Supabase Auth; session persists after sign "
         "in; sign out clears the session.",
         "Passed"),
        ("Farm Onboarding (profile, location pin, soil texture)",
         "Farm saved with GPS pin and soil texture; farmer proceeds to "
         "the app shell.",
         "Passed"),
        ("Claim ESP32 Sensor (claim code)",
         "Sensor linked to the farm after entering the claim code; "
         "appears in the device list.",
         "Passed"),
        ("ESP32 Soil Reading Ingestion & Validation",
         "Reading received by Supabase; out-of-range values flagged; "
         "valid rows stored in soil_readings and visible in the app.",
         "Passed"),
        ("Home Shows Latest Live Soil Reading",
         "Most recent reading shown via Supabase Realtime; stale or "
         "missing data visibly flagged, never faked.",
         "Passed"),
        ("Irrigation 'Water Today' Guidance",
         "Correct advice based on current soil moisture and the "
         "near-term rainfall forecast.",
         "Passed"),
        ("Nutrient and Soil Out-of-Band Alert",
         "Alert raised and shown in the notifications inbox for critical "
         "readings (e.g. extreme pH).",
         "Passed"),
        ("Device-Offline / No-New-Reading Detection",
         "Offline state displayed when the sensor stops sending beyond "
         "the expected interval.",
         "Passed"),
        ("Farm Data Access Control (RLS)",
         "Only the authenticated owner can read or write that farm's "
         "readings, devices, assessments, and actions.",
         "Passed"),
        ("AI Recommendation Reuse When Inputs Unchanged",
         "AI regenerates only when soil or weather inputs change; "
         "otherwise the saved assessment is reused.",
         "Passed"),
    ]
    add_table_caption(doc, "Table 1. Functional Testing Results.")
    add_table(doc, test_headers, test_rows,
              col_widths=[Inches(2.3), Inches(3.2), Inches(1.0)])

    # 4.3 Evaluation (Strengths / Weaknesses)
    add_heading(doc, "Evaluation", level=1)
    add_body(doc,
        "The prototype was evaluated against the project objectives and "
        "against general software-quality criteria such as usability, "
        "reliability, and security. The main strengths and weaknesses "
        "observed during development and testing are listed below.")

    add_sub_label(doc, "Strengths")
    add_bullets(doc, [
        "Clear farmer-facing purpose: makes real-time soil data and "
        "practical AI advice accessible to smallholder farmers who "
        "normally decide by guesswork.",
        "Multi-sensor support per farm: more than one ESP32 kit can be "
        "placed on different planting plots under the same farm account.",
        "Real-time updates via Supabase Realtime keep the Home screen "
        "live without manual refresh.",
        "Row-Level Security isolates each farmer's data at the database "
        "level, so one account cannot read another farm's readings.",
        "Device safety: the ESP32 uses the anonymous key plus a "
        "per-device token for ingestion; the service-role key never lives "
        "on the hardware.",
        "AI recommendations regenerate only when soil or weather inputs "
        "change or validity expires, which conserves API calls and "
        "prevents stale duplicate advice.",
        "Phone-first Flutter UI tuned for farmers (large tap targets, "
        "matte colors, Literata and Nunito Sans for readability in "
        "outdoor light).",
        "Free-tier stack (Flutter, Supabase, Open-Meteo) keeps prototype "
        "deployment cost near zero.",
    ])

    add_sub_label(doc, "Weaknesses")
    add_bullets(doc, [
        "Internet-dependent for core operations (live monitoring, AI "
        "recommendations, weather retrieval); weak rural signal can "
        "delay updates.",
        "AI output is advisory only — farmers must still apply their "
        "own judgment, and model availability depends on an external "
        "service.",
        "Push notifications when the application is fully closed are "
        "not implemented in this version; alerts are only shown while "
        "the app is in use.",
        "Farmer-side Wi-Fi provisioning (SoftAP or Bluetooth) is not "
        "implemented, so new ESP32 kits must still be configured in the "
        "laboratory.",
        "Sensor readings reflect only the installation point; parts of "
        "the farm without a sensor remain unmeasured.",
        "Weather accuracy depends on Open-Meteo, which is a free "
        "general-purpose API and is not calibrated for farm-level "
        "microclimates.",
        "The current data model assumes one owner per farm; multi-farm "
        "accounts and farm-level sharing are not yet supported.",
        "Soil sensor accuracy depends on calibration and placement and "
        "has not been independently validated against laboratory tests.",
    ])

    # =================================================================
    # CHAPTER 5 — CONCLUSION AND RECOMMENDATIONS
    # =================================================================
    add_chapter_title(doc, "CHAPTER 5", "CONCLUSION AND RECOMMENDATIONS")

    # 5.1 Conclusion
    add_heading(doc, "Conclusion", level=1)
    add_body(doc,
        "SoilGood demonstrates that an affordable combination of IoT "
        "hardware, a free-tier cloud backend, and an AI model can deliver "
        "useful, farmer-facing decision support in a mobile application. "
        "The ESP32 and 8-in-1 soil sensor reliably supply real-time soil "
        "readings, Supabase provides a secure and realtime-capable "
        "backend with row-level data isolation, Open-Meteo supplies free "
        "weather data suitable for day-to-day decisions, and the AI edge "
        "function turns these inputs into practical advice on irrigation, "
        "nutrients, soil management, and crop suitability.")
    add_body(doc,
        "All four specific objectives of the project were met: an IoT "
        "monitoring device was built, a real-time monitoring module with "
        "historical records was developed, a weather API was integrated, "
        "and an AI-assisted recommendation module was deployed. The ten "
        "functional test cases that cover authentication, onboarding, "
        "data ingestion, live display, irrigation guidance, alerts, "
        "offline detection, access control, and AI consistency all "
        "passed. The resulting prototype is runnable on a real Android "
        "device and is ready for presentation and demonstration.")

    # 5.2 Recommendations
    add_heading(doc, "Recommendations", level=1)
    add_body(doc,
        "The following recommendations are offered to extend SoilGood "
        "beyond its current prototype scope and to further strengthen its "
        "usefulness for Filipino farmers:", indent_first=False)
    add_numbered(doc, [
        "Add push notifications so farmers can receive urgent alerts "
        "(critical soil condition or device-offline) even when the "
        "application is fully closed.",
        "Implement a farmer-side Wi-Fi configuration flow (SoftAP or "
        "Bluetooth provisioning) so new ESP32 kits can be connected in "
        "the field without returning to the laboratory.",
        "Introduce an offline mode that caches the most recent readings, "
        "weather, and AI assessments so the app remains useful in areas "
        "with weak or intermittent internet.",
        "Expand the crop catalog with locally verified soil and climate "
        "ranges for additional Philippine crops, and refine the AI "
        "prompt with region-specific guidance.",
        "Add Tagalog (and other regional language) localization for the "
        "farmer-facing text so the application is more approachable for "
        "farmers who are not comfortable reading English.",
        "Support multi-farm accounts under one owner so farmers managing "
        "several parcels can switch between them inside the same account.",
        "Explore additional sensors (e.g. soil temperature at depth, "
        "ambient light, or air temperature) and calibrate the 8-in-1 "
        "sensor against laboratory tests for improved accuracy.",
        "Pilot the system with a small group of farmers to gather "
        "qualitative feedback and measure actual yield or input savings, "
        "then refine the UX and recommendations based on observed usage.",
    ])

    # ---------------- SAVE ----------------
    doc.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
