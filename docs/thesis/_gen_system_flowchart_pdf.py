"""Generate SoilGood system flowchart PDF — 2× A4 landscape, no overlaps.

Detailed enough for thesis: setup path + operational loop with farmer logs.
Also writes preview PNGs (page1/page2).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas

OUT = Path(__file__).resolve().parent
PDF_PATH = OUT / "SYSTEM_FLOWCHART.pdf"
PNG1 = OUT / "SYSTEM_FLOWCHART-page1.png"
PNG2 = OUT / "SYSTEM_FLOWCHART-page2.png"

PRIMARY = HexColor("#4A7C59")
TEXT = HexColor("#2C332C")
MUTED = HexColor("#6B706B")
EDGE = HexColor("#4A4E4A")
BG = HexColor("#FAFAF8")
FILL = HexColor("#E8F0EB")
FILL_DEC = HexColor("#F0EFE8")
FILL_LOG = HexColor("#FFF4E0")
FILL_AI = HexColor("#E8EEF5")
FILL_HW = HexColor("#EDE8F0")
LANE = HexColor("#F3F3F0")
WHITE = white

P_PRIMARY = (74, 124, 89)
P_TEXT = (44, 51, 44)
P_MUTED = (107, 112, 107)
P_EDGE = (74, 78, 74)
P_BG = (250, 250, 248)
P_FILL = (232, 240, 235)
P_DEC = (240, 239, 232)
P_LOG = (255, 244, 224)
P_AI = (232, 238, 245)
P_HW = (237, 232, 240)
P_LANE = (243, 243, 240)
P_WHITE = (255, 255, 255)


def try_font(size: int):
    for name in (
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/calibri.ttf",
    ):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Layout helpers (top-left coords → reportlab bottom-left)
# ---------------------------------------------------------------------------

def pdf_y(page_h: float, top_y: float, h: float) -> float:
    return page_h - top_y - h


def draw_round_box(c: canvas.Canvas, page_h: float, x: float, y_top: float, w: float, h: float, fill, stroke=PRIMARY, radius=4):
    y = pdf_y(page_h, y_top, h)
    c.setFillColor(fill)
    c.setStrokeColor(stroke)
    c.setLineWidth(0.9)
    c.roundRect(x, y, w, h, radius, fill=1, stroke=1)
    return y


def draw_wrapped(
    c: canvas.Canvas,
    text: str,
    x: float,
    y_top: float,
    w: float,
    h: float,
    page_h: float,
    font="Helvetica",
    size=7,
    color=TEXT,
    bold=False,
):
    """Center multi-line text inside a box (top-left layout coords)."""
    lines = text.split("\n")
    c.setFillColor(color)
    c.setFont("Helvetica-Bold" if bold else font, size)
    line_h = size + 2
    total = len(lines) * line_h
    start = pdf_y(page_h, y_top, h) + (h - total) / 2 + 1.5
    for i, line in enumerate(lines):
        c.drawCentredString(x + w / 2, start + (len(lines) - 1 - i) * line_h, line)


def arrow(c: canvas.Canvas, page_h: float, x1: float, yt1: float, x2: float, yt2: float, label: str = ""):
    """Straight arrow between centers (top-left y)."""
    y1 = page_h - yt1
    y2 = page_h - yt2
    c.setStrokeColor(EDGE)
    c.setFillColor(EDGE)
    c.setLineWidth(0.85)
    c.line(x1, y1, x2, y2)
    # arrowhead
    import math

    ang = math.atan2(y2 - y1, x2 - x1)
    ah = 5
    c.saveState()
    path = c.beginPath()
    path.moveTo(x2, y2)
    path.lineTo(x2 - ah * math.cos(ang - 0.4), y2 - ah * math.sin(ang - 0.4))
    path.lineTo(x2 - ah * math.cos(ang + 0.4), y2 - ah * math.sin(ang + 0.4))
    path.close()
    c.drawPath(path, fill=1, stroke=0)
    c.restoreState()
    if label:
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        c.setFillColor(BG)
        tw = c.stringWidth(label, "Helvetica", 5.5) + 5
        c.rect(mx - tw / 2, my - 3, tw, 8, fill=1, stroke=0)
        c.setFillColor(MUTED)
        c.setFont("Helvetica", 5.5)
        c.drawCentredString(mx, my - 0.5, label)


def h_arrow(c: canvas.Canvas, page_h: float, left_box, right_box, label: str = ""):
    """Arrow from right edge of left_box to left edge of right_box."""
    lx, ly, lw, lh = left_box
    rx, ry, rw, rh = right_box
    x1 = lx + lw
    x2 = rx
    yt = ly + lh / 2
    arrow(c, page_h, x1, yt, x2, yt, label)


def v_arrow(c: canvas.Canvas, page_h: float, top_box, bot_box, label: str = ""):
    tx, ty, tw, th = top_box
    bx, by, bw, bh = bot_box
    x = tx + tw / 2
    arrow(c, page_h, x, ty + th, x, by, label)


def box(c, page_h, x, y, w, h, text, fill=FILL, size=7, bold=False):
    draw_round_box(c, page_h, x, y, w, h, fill)
    draw_wrapped(c, text, x, y, w, h, page_h, size=size, bold=bold)
    return (x, y, w, h)


def ellipse_start(c, page_h, x, y, w, h, text):
    py = pdf_y(page_h, y, h)
    c.setFillColor(PRIMARY)
    c.setStrokeColor(PRIMARY)
    c.ellipse(x, py, x + w, py + h, fill=1, stroke=1)
    draw_wrapped(c, text, x, y, w, h, page_h, size=7, color=WHITE, bold=True)
    return (x, y, w, h)


def diamond(c, page_h, x, y, w, h, text):
    """Decision rhombus using a path (top-left y)."""
    py = pdf_y(page_h, y, h)
    cx, cy = x + w / 2, py + h / 2
    path = c.beginPath()
    path.moveTo(cx, py + h)
    path.lineTo(x + w, cy)
    path.lineTo(cx, py)
    path.lineTo(x, cy)
    path.close()
    c.setFillColor(FILL_DEC)
    c.setStrokeColor(PRIMARY)
    c.setLineWidth(0.9)
    c.drawPath(path, fill=1, stroke=1)
    draw_wrapped(c, text, x, y, w, h, page_h, size=6.5)
    return (x, y, w, h)


def cylinder(c, page_h, x, y, w, h, text, fill=FILL):
    """Simple store: rounded rect + oval cues."""
    draw_round_box(c, page_h, x, y, w, h, fill, radius=6)
    draw_wrapped(c, text, x, y, w, h, page_h, size=6.5)
    return (x, y, w, h)


def header(c, page_h, page_w, title, subtitle, page_label):
    c.setFillColor(BG)
    c.rect(0, 0, page_w, page_h, fill=1, stroke=0)
    c.setFillColor(TEXT)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(18, page_h - 16, title)
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 7)
    c.drawString(18, page_h - 28, subtitle)
    c.setFont("Helvetica", 6.5)
    c.drawRightString(page_w - 18, page_h - 16, page_label)


def footer(c, text: str):
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 5.5)
    c.drawString(18, 10, text)


# ---------------------------------------------------------------------------
# Page 1 — System context + farmer setup journey
# ---------------------------------------------------------------------------

def render_page1(c: canvas.Canvas, page_w: float, page_h: float) -> None:
    header(
        c,
        page_h,
        page_w,
        "SoilGood — System flowchart",
        "Page 1 of 2 · System context + farmer setup (signup → claim → shell) · A4 landscape",
        "Figure A / B",
    )

    # --- Section 1: swimlane context ---
    c.setFillColor(TEXT)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(18, page_h - 46, "1. System context (who talks to whom)")

    lane_y, lane_h = 54, 168
    lanes = [
        (18, "Lab / Admin", 145),
        (173, "Hardware", 130),
        (313, "Supabase Free", 200),
        (523, "Flutter app", 155),
        (688, "External APIs", 135),
    ]
    for x, title, w in lanes:
        draw_round_box(c, page_h, x, lane_y, w, lane_h, LANE, HexColor("#C8CBC6"), 3)
        c.setFillColor(PRIMARY)
        c.setFont("Helvetica-Bold", 7)
        c.drawCentredString(x + w / 2, pdf_y(page_h, lane_y, 16) + 5, title)

    # Lab boxes
    a1 = box(c, page_h, 30, 78, 120, 34, "Admin Web Devices\n(provision + flash)", FILL)
    a2 = box(c, page_h, 30, 122, 120, 34, "Lab Flasher backup\n(USB / Windows)", FILL_DEC)
    a3 = box(c, page_h, 30, 166, 120, 40, "Create devices row\nclaim_code + ingest_token", FILL_DEC)

    # Hardware
    h1 = box(c, page_h, 185, 95, 105, 40, "ESP32 +\n8-in-1 sensors", FILL_HW, bold=True)
    h2 = box(c, page_h, 185, 155, 105, 44, "Every ~15 min\ningest_soil_reading\n(anon + token)", FILL_HW)

    # Cloud
    c1 = box(c, page_h, 325, 78, 80, 30, "Auth + RLS", FILL)
    c2 = cylinder(c, page_h, 420, 72, 80, 42, "Postgres", FILL)
    c3 = box(c, page_h, 325, 122, 80, 30, "Realtime", FILL)
    c4 = box(c, page_h, 415, 120, 90, 36, "Edge Function\nsoilgood-insights", FILL_AI)
    c5 = box(
        c,
        page_h,
        325,
        168,
        175,
        40,
        "Key tables: soil_readings · plantings ·\nfarm_actions · irrigation_* · ai_* · alerts",
        FILL_DEC,
        size=6,
    )

    # App
    f1 = box(c, page_h, 535, 85, 130, 44, "Farmer app shell\nHome · Analytics\nCrops · Profile", FILL, bold=True)
    f2 = box(c, page_h, 535, 142, 130, 32, "Admin web chrome", FILL_DEC)
    f3 = box(c, page_h, 535, 186, 130, 28, "Notification engine", FILL_DEC)

    # APIs
    e1 = box(c, page_h, 700, 95, 110, 34, "Open-Meteo\n(weather free)", FILL)
    e2 = box(c, page_h, 700, 150, 110, 34, "Groq gpt-oss-120b\n(AI text only)", FILL_AI)

    # Arrows section 1 — column-to-column only (avoid crossings)
    h_arrow(c, page_h, a1, h1, "SGCFG")
    v_arrow(c, page_h, a1, a3, "")
    h_arrow(c, page_h, a3, c2, "devices")
    v_arrow(c, page_h, h1, h2, "")
    h_arrow(c, page_h, h2, c2, "ingest")
    arrow(c, page_h, 500, 93, 500, 122, "")  # postgres area → realtime mid
    h_arrow(c, page_h, c3, f1, "Realtime")
    arrow(c, page_h, 405, 152, 535, 158, "alerts")
    h_arrow(c, page_h, f1, e1, "weather")
    arrow(c, page_h, 535, 107, 505, 138, "JWT")
    h_arrow(c, page_h, c4, e2, "Groq")
    arrow(c, page_h, 460, 120, 460, 93, "save")
    v_arrow(c, page_h, a2, a3, "")
    # admin chrome reads same DB
    arrow(c, page_h, 535, 158, 500, 114, "admin")

    c.setFillColor(MUTED)
    c.setFont("Helvetica", 5.5)
    c.drawString(18, page_h - 236, "Never service_role on ESP32/Flutter · Prefer free tiers · v1: 1 farm + 1 device · Lab Flasher = USB backup path")

    # --- Section 2: Farmer journey ---
    c.setFillColor(TEXT)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(18, page_h - 258, "2. Farmer setup journey (once)")

    y0 = 270
    s0 = ellipse_start(c, page_h, 18, y0, 78, 36, "Open app")
    s1 = diamond(c, page_h, 110, y0 - 4, 78, 44, "Logged\nin?")
    s2 = box(c, page_h, 205, y0, 88, 36, "Login /\nSignup", FILL)
    s3 = diamond(c, page_h, 310, y0 - 4, 78, 44, "Onboarding\ndone?")
    s4 = box(c, page_h, 405, y0 - 2, 90, 40, "1 Profile\n→ profiles", FILL)
    s5 = box(c, page_h, 510, y0 - 2, 90, 40, "2 Farm pin\n→ farms", FILL)
    s6 = box(c, page_h, 615, y0 - 2, 90, 40, "3 Claim code\n(or skip)", FILL_HW)
    s7 = box(c, page_h, 720, y0 - 2, 100, 40, "App shell\nready", FILL, bold=True)

    h_arrow(c, page_h, s0, s1, "")
    # No → login
    arrow(c, page_h, 188, y0 + 22, 205, y0 + 18, "No")
    h_arrow(c, page_h, s2, s3, "")
    # Yes → onboarding check (path above diamonds)
    arrow(c, page_h, 149, y0 - 6, 310, y0 - 6, "Yes")
    h_arrow(c, page_h, s3, s4, "gaps")
    h_arrow(c, page_h, s4, s5, "")
    h_arrow(c, page_h, s5, s6, "")
    h_arrow(c, page_h, s6, s7, "RPC")
    # All done shortcut under
    arrow(c, page_h, 349, y0 + 40, 720, y0 + 40, "all done")

    # Shell tabs under journey
    tabs_y = 330
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 6.5)
    c.drawString(18, page_h - tabs_y + 8, "Shell tabs after setup:")
    t1 = box(c, page_h, 130, tabs_y, 100, 28, "Home (now)", FILL)
    t2 = box(c, page_h, 245, tabs_y, 110, 28, "Analytics (history)", FILL)
    t3 = box(c, page_h, 370, tabs_y, 110, 28, "Crops (plan+log)", FILL_LOG)
    t4 = box(c, page_h, 495, tabs_y, 80, 28, "Profile", FILL)
    t5 = box(c, page_h, 590, tabs_y, 100, 28, "Bell inbox", FILL_DEC)
    t6 = box(c, page_h, 705, tabs_y, 115, 28, "Alert engine (bg)", FILL_DEC)
    for prev, nxt in ((t1, t2), (t2, t3), (t3, t4), (t4, t5), (t5, t6)):
        h_arrow(c, page_h, prev, nxt, "")

    arrow(c, page_h, 770, y0 + 40, 770, tabs_y, "")

    footer(
        c,
        "Orange tint = farmer-facing log path (Crops) · Blue = AI · Purple = hardware · Source: docs/context + docs/pages",
    )


# ---------------------------------------------------------------------------
# Page 2 — Daily ops + farmer logs (detailed, non-overlapping columns)
# ---------------------------------------------------------------------------

def render_page2(c: canvas.Canvas, page_w: float, page_h: float) -> None:
    header(
        c,
        page_h,
        page_w,
        "SoilGood — System flowchart",
        "Page 2 of 2 · Daily operational loop + farmer logs (Mark watered → farm_actions) · A4 landscape",
        "Figure C / D",
    )

    c.setFillColor(TEXT)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(18, page_h - 46, "3. Operational loop (while the farmer uses the app)")

    # Four clear columns with gaps — no overlap
    # Col widths: 185, 185, 200, 210 with gaps of 12
    col = [
        (18, 185),   # Sense
        (215, 185),  # Decide / UI
        (412, 200),  # Act + LOG
        (624, 200),  # Persist / Analytics
    ]
    titles = ["A. Sense", "B. Show & decide", "C. Act + farmer log", "D. Store & learn"]
    col_y, col_h = 54, 420
    for (x, w), title in zip(col, titles):
        draw_round_box(c, page_h, x, col_y, w, col_h, LANE, HexColor("#C8CBC6"), 3)
        c.setFillColor(PRIMARY)
        c.setFont("Helvetica-Bold", 7.5)
        c.drawCentredString(x + w / 2, pdf_y(page_h, col_y, 18) + 5, title)

    # --- Column A ---
    ax = 30
    a1 = ellipse_start(c, page_h, ax, 82, 160, 32, "New soil sample")
    a2 = cylinder(c, page_h, ax, 128, 160, 36, "soil_readings", FILL)
    a3 = box(c, page_h, ax, 178, 160, 32, "Supabase Realtime\nbroadcast", FILL)
    a4 = box(c, page_h, ax, 226, 160, 40, "Open-Meteo\nforecast (Home/Crops)\nperiod weather (Analytics)", FILL)
    a5 = box(c, page_h, ax, 282, 160, 40, "Local bands\n(insights.json)\n0 Groq tokens", FILL_DEC)
    a6 = box(c, page_h, ax, 340, 160, 36, "Device last_seen_at\n(offline if >2h)", FILL_HW)

    # --- Column B ---
    bx = 227
    b1 = box(c, page_h, bx, 82, 160, 48, "HOME\n8-in-1 + Quick Insight\n+ today AI cards", FILL, bold=True)
    b2 = box(c, page_h, bx, 146, 160, 44, "NOTIFICATIONS\ninsert farm_notifications\n(dedupe Manila day)", FILL_DEC)
    b3 = diamond(c, page_h, bx + 10, 208, 140, 48, "Active\nplanting?")
    b4 = box(c, page_h, bx, 272, 160, 40, "CROPS list\ncatalog match (local)\nSelect crop → plantings", FILL)
    b5 = box(c, page_h, bx, 328, 160, 48, "CROPS plan\nphases + day N\n+ care AI request", FILL)
    b6 = box(c, page_h, bx, 392, 160, 36, "ANALYTICS entry\n(period filters)", FILL)

    # --- Column C (LOGS) ---
    cx = 424
    c1b = box(c, page_h, cx, 82, 175, 44, "7-day water plan\nrules_v1 (local)\n→ irrigation_plans / slots", FILL)
    c2b = box(
        c,
        page_h,
        cx,
        142,
        175,
        56,
        "FARMER LOG (Crops)\nMark watered — Today only\n→ farm_actions\naction_type = irrigation\n+ slot completed_action_id",
        FILL_LOG,
        bold=True,
        size=6.5,
    )
    c3b = box(c, page_h, cx, 214, 175, 40, "Home AI request\njob = home\n(Condition / Water / Nutrients)", FILL_AI)
    c4b = box(c, page_h, cx, 270, 175, 40, "Crops care AI\njob = crops.care\n(phase chores only)", FILL_AI)
    c5b = box(c, page_h, cx, 326, 175, 40, "Analytics AI\njob = analytics\n(period_start / period_end)", FILL_AI)
    c6b = box(c, page_h, cx, 382, 175, 40, "Cache check first\n(fingerprint / valid_until)\nskip Groq if unchanged", FILL_DEC, size=6.5)

    # --- Column D ---
    dx = 636
    d1 = box(c, page_h, dx, 82, 175, 40, "Edge Function\n+ Groq (if regen)", FILL_AI, bold=True)
    d2 = cylinder(c, page_h, dx, 138, 175, 40, "ai_assessments +\nai_recommendations", FILL_AI)
    d3 = cylinder(c, page_h, dx, 194, 175, 40, "farm_actions\n(farmer logs)", FILL_LOG)
    d4 = cylinder(c, page_h, dx, 250, 175, 36, "farm_notifications", FILL_DEC)
    d5 = cylinder(c, page_h, dx, 302, 175, 36, "irrigation_plans / slots", FILL)
    d6 = box(
        c,
        page_h,
        dx,
        354,
        175,
        56,
        "ANALYTICS uses logs\nhistory RPC + period weather\n+ watering count from\nfarm_actions → next plan",
        FILL_LOG,
        bold=True,
        size=6.5,
    )

    # --- Arrows (explicit endpoints to avoid wrong-row crossings) ---
    v_arrow(c, page_h, a1, a2, "")
    v_arrow(c, page_h, a2, a3, "")
    v_arrow(c, page_h, a3, a5, "")

    arrow(c, page_h, 190, 194, 227, 106, "Realtime")
    arrow(c, page_h, 190, 302, 227, 168, "bands")
    arrow(c, page_h, 190, 246, 227, 106, "weather")

    v_arrow(c, page_h, b1, b2, "")
    v_arrow(c, page_h, b2, b3, "")
    v_arrow(c, page_h, b4, b5, "plant")
    arrow(c, page_h, bx + 80, 256, bx + 80, 272, "No")
    arrow(c, page_h, bx + 150, 232, cx, 104, "Yes")

    v_arrow(c, page_h, c1b, c2b, "Today")
    arrow(c, page_h, bx + 160, 106, cx, 234, "tips")
    arrow(c, page_h, bx + 160, 352, cx, 290, "care")
    arrow(c, page_h, bx + 160, 410, cx, 346, "window")
    arrow(c, page_h, cx + 87, 254, cx + 87, 382, "")
    arrow(c, page_h, cx + 87, 310, cx + 87, 382, "")
    arrow(c, page_h, cx + 87, 366, cx + 87, 382, "")
    arrow(c, page_h, cx + 175, 402, dx, 102, "invoke")

    arrow(c, page_h, cx + 175, 170, dx, 214, "log")
    arrow(c, page_h, bx + 160, 168, dx, 268, "alert")
    arrow(c, page_h, cx + 175, 104, dx, 320, "plan")
    v_arrow(c, page_h, d1, d2, "save")
    arrow(c, page_h, dx + 87, 234, dx + 87, 354, "read logs")

    c.setFillColor(MUTED)
    c.setFont("Helvetica", 5.5)
    c.drawString(dx, pdf_y(page_h, 424, 10), "Saved AI reused on Home / Crops / Analytics when cache says skip")

    # Bottom legend strip
    footer(
        c,
        "Farmer log today: Mark watered only (irrigation). Reserved action_types: fertilizer · planting · treatment. "
        "Home AI = today · Crops care = phase · Analytics AI = selected window · Do not duplicate tip copy.",
    )


# ---------------------------------------------------------------------------
# PNG previews (rasterize via reportlab? use PIL redraw for consistency with ERD)
# Simpler: use pypdfium2 or render with PIL mirroring. ERD uses PIL separately.
# For speed: write PDF then convert with a lightweight approach.
# ---------------------------------------------------------------------------

def pdf_to_pngs() -> None:
    """Render PDF pages to PNG using Pillow + a simple raster via reportlab isn't available.
    Use pymupdf if present; else skip PNGs with a note.
    """
    try:
        import fitz  # PyMuPDF
    except ImportError:
        # Fallback: draw simplified PNG mirrors for preview
        _png_fallback_page1()
        _png_fallback_page2()
        return
    doc = fitz.open(PDF_PATH)
    for i, path in enumerate((PNG1, PNG2)):
        page = doc.load_page(i)
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
        pix.save(str(path))
    doc.close()


def _png_fallback_page1() -> None:
    """Minimal preview if PyMuPDF missing — tell user PDF is source of truth."""
    img = Image.new("RGB", (1660, 1170), P_BG)
    d = ImageDraw.Draw(img)
    font_b = try_font(28)
    font = try_font(18)
    d.text((40, 40), "SoilGood System Flowchart — Page 1", fill=P_TEXT, font=font_b)
    d.text((40, 90), "Open SYSTEM_FLOWCHART.pdf for the detailed printable figure.", fill=P_MUTED, font=font)
    d.text((40, 130), "(Install PyMuPDF to auto-export high-res PNGs: pip install pymupdf)", fill=P_MUTED, font=font)
    img.save(PNG1)


def _png_fallback_page2() -> None:
    img = Image.new("RGB", (1660, 1170), P_BG)
    d = ImageDraw.Draw(img)
    font_b = try_font(28)
    font = try_font(18)
    d.text((40, 40), "SoilGood System Flowchart — Page 2", fill=P_TEXT, font=font_b)
    d.text((40, 90), "Open SYSTEM_FLOWCHART.pdf for the detailed printable figure.", fill=P_MUTED, font=font)
    img.save(PNG2)


def build_pdf() -> Path:
    page = landscape(A4)
    c = canvas.Canvas(str(PDF_PATH), pagesize=page)
    w, h = page
    render_page1(c, w, h)
    c.showPage()
    render_page2(c, w, h)
    c.save()
    return PDF_PATH


def main() -> None:
    path = build_pdf()
    print(f"Wrote {path}")
    pdf_to_pngs()
    print(f"Wrote {PNG1.name}, {PNG2.name}")


if __name__ == "__main__":
    main()
