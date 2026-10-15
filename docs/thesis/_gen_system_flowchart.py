"""Generate SoilGood system flowchart .drawio — A4 landscape, multi-page (thesis).

Includes farmer logs (farm_actions / Mark watered) in the closed operational loop.
Open in diagrams.net → File → Export → PNG/PDF (Fit to page).
"""
from __future__ import annotations

from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent / "SYSTEM_FLOWCHART.drawio"

# A4 landscape @ 100% (same as ERD.drawio)
PAGE_W, PAGE_H = 1169, 827
BG = "#FAFAF8"
PRIMARY = "#4A7C59"
TEXT = "#2C332C"
MUTED = "#6B706B"
EDGE = "#4A4E4A"
FILL = "#E8F0EB"
FILL_DEC = "#F0EFE8"
FILL_LOG = "#FFF4E0"  # farmer logs highlight
FILL_AI = "#E8EEF5"
FILL_HW = "#EDE8F0"


def cell(cid: str, value: str, style: str, x: float, y: float, w: float, h: float, parent: str = "1") -> str:
    return (
        f'<mxCell id="{cid}" value="{escape(value)}" style="{style}" '
        f'vertex="1" parent="{parent}">'
        f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>\n'
    )


def edge(
    eid: str,
    source: str,
    target: str,
    label: str = "",
    dashed: bool = False,
    color: str = EDGE,
) -> str:
    dash = "dashed=1;dashPattern=6 4;" if dashed else ""
    lab = escape(label)
    return (
        f'<mxCell id="{eid}" value="{lab}" style="edgeStyle=orthogonalEdgeStyle;rounded=1;'
        f'orthogonalLoop=1;jettySize=auto;html=1;strokeColor={color};fontSize=8;'
        f'fontColor={MUTED};labelBackgroundColor={BG};endArrow=block;endFill=1;{dash}" '
        f'edge="1" parent="1" source="{source}" target="{target}">'
        f'<mxGeometry relative="1" as="geometry"/></mxCell>\n'
    )


def title_block(fig: str, subtitle: str) -> str:
    return (
        cell("t1", "SoilGood — System flowchart", f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=14;fontStyle=1;fontColor={TEXT};", 16, 8, 700, 22)
        + cell("t2", f"{fig} · {subtitle} · A4 landscape · File → Export → PNG/PDF · Fit to page", f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=9;fontColor={MUTED};", 16, 28, 900, 16)
    )


def box_style(fill: str = FILL) -> str:
    return (
        f"rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={PRIMARY};"
        f"fontColor={TEXT};fontSize=9;align=center;verticalAlign=middle;"
    )


def start_style() -> str:
    return (
        f"ellipse;whiteSpace=wrap;html=1;fillColor={PRIMARY};strokeColor={PRIMARY};"
        f"fontColor=#FFFFFF;fontSize=9;fontStyle=1;"
    )


def decision_style() -> str:
    return (
        f"rhombus;whiteSpace=wrap;html=1;fillColor={FILL_DEC};strokeColor={PRIMARY};"
        f"fontColor={TEXT};fontSize=8;align=center;verticalAlign=middle;"
    )


def store_style(fill: str = FILL) -> str:
    return (
        f"shape=cylinder3;whiteSpace=wrap;html=1;boundedLbl=1;backgroundOutline=1;"
        f"size=8;fillColor={fill};strokeColor={PRIMARY};fontColor={TEXT};fontSize=8;"
    )


def lane_style() -> str:
    return (
        f"swimlane;horizontal=0;startSize=22;fillColor=#F5F5F2;strokeColor=#C8CBC6;"
        f"fontColor={TEXT};fontSize=10;fontStyle=1;whiteSpace=wrap;html=1;"
    )


def page_a() -> str:
    """System context: lab → hardware → cloud → app → APIs."""
    s = title_block("Figure A", "System context (actors & data path)")
    # swimlanes as containers (non-collapsing groups)
    s += cell("L1", "Lab / Admin", lane_style(), 20, 56, 200, 340)
    s += cell("L2", "Hardware", lane_style(), 240, 56, 180, 340)
    s += cell("L3", "Supabase (Free)", lane_style(), 440, 56, 280, 340)
    s += cell("L4", "Flutter app", lane_style(), 740, 56, 200, 340)
    s += cell("L5", "External APIs", lane_style(), 960, 56, 180, 340)

    # Lab (children of page, positioned inside lanes visually)
    s += cell("a1", "Admin Web\nDevices", box_style(), 48, 100, 140, 44)
    s += cell("a2", "Lab Flasher\n(backup USB)", box_style(), 48, 170, 140, 44)
    s += cell("a3", "Provision kit\nclaim_code + ingest_token", box_style(FILL_DEC), 48, 250, 140, 52)

    # Hardware
    s += cell("h1", "ESP32 +\n8-in-1 sensors", box_style(FILL_HW), 262, 140, 136, 52)
    s += cell("h2", "Every ~15 min\ningest_soil_reading", box_style(FILL_HW), 262, 230, 136, 52)

    # Cloud
    s += cell("c1", "Auth + RLS", box_style(), 470, 90, 100, 36)
    s += cell("c2", "Postgres", store_style(), 600, 90, 90, 50)
    s += cell("c3", "Realtime", box_style(), 470, 170, 100, 36)
    s += cell("c4", "Edge Function\nsoilgood-insights", box_style(FILL_AI), 590, 170, 110, 48)
    s += cell(
        "c5",
        "Tables: soil_readings · plantings ·\nfarm_actions · irrigation_* ·\nai_* · farm_notifications",
        box_style(FILL_DEC),
        470,
        250,
        230,
        70,
    )

    # App
    s += cell("f1", "Farmer app shell\nHome · Analytics\nCrops · Profile", box_style(), 762, 100, 156, 60)
    s += cell("f2", "Admin web chrome\n(Devices / Analytics)", box_style(), 762, 190, 156, 48)
    s += cell("f3", "Notification engine\n(while shell open)", box_style(FILL_DEC), 762, 270, 156, 48)

    # External
    s += cell("e1", "Open-Meteo\n(weather)", box_style(), 988, 120, 130, 44)
    s += cell("e2", "Groq\ngpt-oss-120b", box_style(FILL_AI), 988, 200, 130, 44)

    # Edges
    s += edge("ea1", "a1", "a3", "provision RPC")
    s += edge("ea2", "a1", "h1", "SGCFG USB")
    s += edge("ea3", "a2", "h1", "", dashed=True)
    s += edge("ea4", "a3", "c2", "devices row")
    s += edge("ea5", "h2", "c2", "anon + ingest_token")
    s += edge("ea6", "c2", "c3")
    s += edge("ea7", "c3", "f1", "live soil")
    s += edge("ea8", "c3", "f3")
    s += edge("ea9", "f1", "c1")
    s += edge("ea10", "f1", "c2", "RLS read/write")
    s += edge("ea11", "f1", "e1", "forecast / period")
    s += edge("ea12", "f1", "c4", "JWT invoke")
    s += edge("ea13", "c4", "e2")
    s += edge("ea14", "c4", "c2", "save AI")
    s += edge("ea15", "f2", "c2")
    s += edge("ea16", "f2", "c1")

    s += cell(
        "leg",
        "Legend: green outline = process · cylinder = store · dashed = backup path · "
        "Blue tint = AI · Purple tint = hardware",
        f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=8;fontColor={MUTED};",
        20,
        410,
        900,
        18,
    )
    s += cell(
        "note",
        "v1 scope: 1 farm + 1 ESP32 per farmer · Prefer free tiers · Never service_role in app/firmware",
        f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=8;fontColor={MUTED};",
        20,
        430,
        900,
        18,
    )
    return s


def page_b() -> str:
    """End-to-end farmer journey including device claim and shell."""
    s = title_block("Figure B", "Farmer journey (signup → shell)")
    s += cell("b0", "Farmer opens\nSoilGood", start_style(), 40, 80, 100, 44)
    s += cell("b1", "Session\nactive?", decision_style(), 180, 72, 100, 60)
    s += cell("b2", "Login /\nSignup\n(Supabase Auth)", box_style(), 180, 180, 110, 52)
    s += cell("b3", "Onboarding\ncomplete?", decision_style(), 340, 72, 110, 60)

    s += cell("b4", "1. Profile\nname + address\n→ profiles", box_style(), 500, 56, 120, 52)
    s += cell("b5", "2. Farm pin\nGPS + map\n→ farms lat/long", box_style(), 500, 130, 120, 52)
    s += cell("b6", "3. Claim device\ntype claim_code\n(or skip)", box_style(), 500, 204, 120, 52)
    s += cell("b7", "claim_device\nRPC → devices", box_style(FILL_HW), 660, 204, 120, 52)

    s += cell("b8", "App shell\n(IndexedStack)", box_style(), 840, 120, 130, 52)
    s += cell("b9", "Home\n(now)", box_style(), 820, 220, 80, 40)
    s += cell("b10", "Analytics\n(over time)", box_style(), 920, 220, 90, 40)
    s += cell("b11", "Crops\n(match+plan)", box_style(), 820, 280, 80, 40)
    s += cell("b12", "Profile", box_style(), 920, 280, 90, 40)
    s += cell("b13", "Bell →\nNotifications", box_style(FILL_DEC), 1020, 220, 100, 40)
    s += cell("b14", "Alert engine\n(shell open)", box_style(FILL_DEC), 1020, 280, 100, 40)

    s += cell(
        "bnote",
        "After claim: ESP32 can write soil_readings → Realtime updates Home + notification engine.",
        f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=8;fontColor={MUTED};",
        40,
        380,
        800,
        18,
    )

    s += edge("eb1", "b0", "b1")
    s += edge("eb2", "b1", "b2", "No")
    s += edge("eb3", "b2", "b3")
    s += edge("eb4", "b1", "b3", "Yes")
    s += edge("eb5", "b3", "b4", "Profile missing")
    s += edge("eb6", "b4", "b5")
    s += edge("eb7", "b3", "b5", "Farm missing")
    s += edge("eb8", "b5", "b6")
    s += edge("eb9", "b3", "b6", "Device missing")
    s += edge("eb10", "b6", "b7", "Valid code")
    s += edge("eb11", "b7", "b8")
    s += edge("eb12", "b6", "b8", "Skip")
    s += edge("eb13", "b3", "b8", "All done")
    s += edge("eb14", "b8", "b9")
    s += edge("eb15", "b8", "b10")
    s += edge("eb16", "b8", "b11")
    s += edge("eb17", "b8", "b12")
    s += edge("eb18", "b8", "b13")
    s += edge("eb19", "b8", "b14")
    return s


def page_c() -> str:
    """Closed operational loop including farmer Mark watered logs."""
    s = title_block(
        "Figure C",
        "Operational loop + farmer logs (soil → AI → actions → analytics)",
    )

    # Left column: sensing
    s += cell("c0", "ESP32 reading\n(~15 min)", start_style(), 30, 70, 110, 44)
    s += cell("c1", "soil_readings", store_style(), 30, 150, 110, 48)
    s += cell("c2", "Realtime", box_style(), 30, 230, 110, 36)
    s += cell("c3", "Open-Meteo\n(live / period)", box_style(), 30, 300, 110, 44)

    # Center: app decisions
    s += cell("c4", "Home\n8-in-1 + forecast\n+ today AI tips", box_style(), 200, 70, 140, 56)
    s += cell("c5", "Notify engine\nbands (0 Groq)\n→ farm_notifications", box_style(FILL_DEC), 200, 150, 140, 56)
    s += cell("c6", "Crops\ncatalog match (local)\n+ planting active?", decision_style(), 200, 240, 140, 70)
    s += cell("c7", "Select crop\n→ plantings", box_style(), 200, 340, 140, 44)

    # Water plan + LOGS (highlighted)
    s += cell("c8", "7-day water plan\nrules_v1\n→ irrigation_plans/slots", box_style(), 400, 70, 160, 56)
    s += cell(
        "c9",
        "FARMER LOG\nMark watered (Today)\n→ farm_actions\n(action_type=irrigation)\n+ link plan_slot",
        box_style(FILL_LOG),
        400,
        160,
        160,
        80,
    )
    s += cell("c10", "Crops care AI\njob=crops.care\n(phase chores)", box_style(FILL_AI), 400, 270, 160, 56)
    s += cell("c11", "Home AI\njob=home\nCondition / Water / Nutrients", box_style(FILL_AI), 400, 350, 160, 56)

    # Right: AI cloud + analytics consuming logs
    s += cell("c12", "Edge Function\nsoilgood-insights\n→ Groq", box_style(FILL_AI), 620, 100, 150, 56)
    s += cell("c13", "ai_assessments +\nai_recommendations", store_style(FILL_AI), 620, 190, 150, 56)
    s += cell(
        "c14",
        "Analytics\nhistory RPC + period weather\n+ watering count from\nfarm_actions logs\n+ period AI (job=analytics)",
        box_style(FILL_LOG),
        620,
        280,
        150,
        90,
    )
    s += cell("c15", "Tap day →\nDay readings", box_style(), 620, 400, 150, 40)

    # Far right stores
    s += cell("c16", "farm_notifications", store_style(FILL_DEC), 830, 150, 140, 50)
    s += cell("c17", "farm_actions\n(farmer logs)", store_style(FILL_LOG), 830, 230, 140, 56)
    s += cell("c18", "irrigation_*", store_style(), 830, 70, 140, 50)
    s += cell("c19", "Bell / inbox\n+ nav red dots", box_style(FILL_DEC), 830, 320, 140, 48)
    s += cell("c20", "Plan next from\ntrends + logs", box_style(), 830, 400, 140, 40)

    # Edges
    s += edge("ec1", "c0", "c1")
    s += edge("ec2", "c1", "c2")
    s += edge("ec3", "c2", "c4")
    s += edge("ec4", "c2", "c5")
    s += edge("ec5", "c3", "c4", "forecast")
    s += edge("ec6", "c3", "c14", "period weather")
    s += edge("ec7", "c4", "c11")
    s += edge("ec8", "c5", "c16")
    s += edge("ec9", "c16", "c19")
    s += edge("ec10", "c4", "c6")
    s += edge("ec11", "c6", "c7", "No planting")
    s += edge("ec12", "c6", "c8", "Yes / after plant")
    s += edge("ec13", "c7", "c8")
    s += edge("ec14", "c8", "c18")
    s += edge("ec15", "c8", "c9")
    s += edge("ec16", "c9", "c17", "insert log")
    s += edge("ec17", "c8", "c10")
    s += edge("ec18", "c11", "c12")
    s += edge("ec19", "c10", "c12")
    s += edge("ec20", "c14", "c12", "regen if needed")
    s += edge("ec21", "c12", "c13")
    s += edge("ec22", "c13", "c4", "show tips", dashed=True)
    s += edge("ec23", "c13", "c10", "", dashed=True)
    s += edge("ec24", "c13", "c14", "", dashed=True)
    s += edge("ec25", "c17", "c14", "irrigation logs")
    s += edge("ec26", "c1", "c14", "history")
    s += edge("ec27", "c14", "c15")
    s += edge("ec28", "c14", "c20")
    s += edge("ec29", "c9", "c8", "slot Done")

    s += cell(
        "cleg",
        "Orange tint = farmer logs (farm_actions) and Analytics use of those logs · "
        "Blue = Groq AI · Mark watered is Crops-only (not on Home).",
        f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=8;fontColor={MUTED};",
        30,
        460,
        1000,
        18,
    )
    s += cell(
        "clog",
        "farm_actions.action_type: irrigation (Mark watered) · fertilizer · planting · treatment "
        "(irrigation is the live log path today; others reserved).",
        f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=8;fontColor={MUTED};",
        30,
        480,
        1000,
        18,
    )
    return s


def page_d() -> str:
    """Compact swimlane of who does what — good single-page summary for defense."""
    s = title_block("Figure D", "Who writes / who reads (process + logs)")

    headers = [
        (40, "Actor"),
        (180, "Writes"),
        (520, "Reads / triggers"),
        (860, "Outcome for farmer"),
    ]
    for i, (x, lab) in enumerate(headers):
        s += cell(f"dh{i}", lab, f"rounded=0;fillColor={PRIMARY};fontColor=#FFFFFF;fontSize=9;fontStyle=1;strokeColor={PRIMARY};", x, 60, 150 if i == 0 else 320 if i < 3 else 260, 28)

    rows = [
        ("Lab / Admin", "devices (claim_code, ingest_token,\nflash_status)", "Admin Devices UI", "Kit ready to claim"),
        ("ESP32", "soil_readings via ingest RPC\n(+ last_seen_at)", "Sensors every ~15 min", "Live soil on Home"),
        ("Farmer (onboard)", "profiles, farms, claim_device", "Auth, map, sticker code", "Account + farm ready"),
        ("Farmer (Crops)", "plantings; irrigation_*;\nfarm_actions (Mark watered)", "Latest soil + Open-Meteo\n+ catalog", "Crop plan + water week"),
        ("Farmer (Home)", "(pull / Realtime only;\nAI save via Edge Fn)", "soil_readings, weather,\nai_assessments kind=home", "Act today tips"),
        ("Farmer (Analytics)", "AI save via Edge Fn\n(kind=analytics)", "history RPC, period weather,\nfarm_actions irrigation logs", "Trends + kalagayan"),
        ("Shell engine", "farm_notifications\n(deduped / Manila day)", "Latest soil + rain chance\n+ phase change", "Bell + red dots"),
        ("Edge Function", "ai_assessments +\nai_recommendations", "JWT + page facts → Groq", "Saved tips (reuse)"),
    ]
    y = 100
    for i, (actor, writes, reads, outcome) in enumerate(rows):
        fill = FILL_LOG if "farm_actions" in writes or "farm_actions" in reads else FILL
        if "AI" in writes or "ai_" in writes or "Groq" in reads:
            fill = FILL_AI if "farm_actions" not in writes and "farm_actions" not in reads else FILL_LOG
        s += cell(f"dr{i}a", actor, box_style(FILL_DEC), 40, y, 150, 48)
        s += cell(f"dr{i}b", writes, box_style(fill), 200, y, 300, 48)
        s += cell(f"dr{i}c", reads, box_style(), 520, y, 320, 48)
        s += cell(f"dr{i}d", outcome, box_style(), 860, y, 260, 48)
        y += 56

    s += cell(
        "dnote",
        "This matrix is the printable “complete process” view: sensing, AI, farmer logs, and analytics consumption.",
        f"text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=8;fontColor={MUTED};",
        40,
        y + 8,
        1000,
        18,
    )
    return s


def wrap_page(pid: str, name: str, body: str) -> str:
    return (
        f'<diagram id="{pid}" name="{escape(name)}">\n'
        f'<mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" '
        f'connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="{PAGE_W}" '
        f'pageHeight="{PAGE_H}" math="0" shadow="0" background="{BG}">\n'
        f"<root>\n"
        f'<mxCell id="0"/>\n'
        f'<mxCell id="1" parent="0"/>\n'
        f"{body}"
        f"</root>\n"
        f"</mxGraphModel>\n"
        f"</diagram>\n"
    )


def main() -> None:
    # Fix page B app shell cell properly
    body_b = page_b()
    mx = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<mxfile host="app.diagrams.net" modified="2026-09-07T04:00:00.000Z" '
        'agent="SoilGood thesis system flowchart" version="22.1.0" type="device">\n'
        + wrap_page("page-a", "Figure A — System context", page_a())
        + wrap_page("page-b", "Figure B — Farmer journey", body_b)
        + wrap_page("page-c", "Figure C — Ops + farmer logs", page_c())
        + wrap_page("page-d", "Figure D — Who writes/reads", page_d())
        + "</mxfile>\n"
    )
    OUT.write_text(mx, encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
