"""Generate print-ready SoilGood ERD: A4 landscape PDF + PNGs + Draw.io.

Clean hand layout (minimal crossings), orthogonal edges, crow's-foot ends.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas

OUT = Path(__file__).resolve().parent

PRIMARY = HexColor("#4A7C59")
TEXT = HexColor("#2C332C")
MUTED = HexColor("#6B706B")
EDGE = HexColor("#4A4E4A")
BG = HexColor("#FAFAF8")
PK_BG = HexColor("#E8F0EB")
FK_BG = HexColor("#F0EFE8")
ROW_BG = HexColor("#FAFAF8")

P_PRIMARY = (74, 124, 89)
P_TEXT = (44, 51, 44)
P_MUTED = (107, 112, 107)
P_EDGE = (74, 78, 74)
P_BG = (250, 250, 248)
P_PK = (232, 240, 235)
P_FK = (240, 239, 232)
P_WHITE = (255, 255, 255)
P_LINE = (60, 64, 60)

HEADER_H = 14.5
ROW_H = 8.8

# ---------------------------------------------------------------------------
# Page 1 — left→right ownership chain; bottom row for weather / crops / plantings
# ---------------------------------------------------------------------------
PAGE1 = {
  "auth_users": {
    "title": "auth.users (Supabase Auth)",
    "attrs": [("PK", "id uuid"), ("", "email text"), ("", "… Auth-managed")],
    "xy": (28, 48),
    "w": 145,
  },
  "profiles": {
    "title": "profiles",
    "attrs": [
      ("PK,FK", "id → auth.users"),
      ("", "first_name, last_name"),
      ("", "barangay, municipality_city"),
      ("", "province"),
      ("", "role  # farmer|admin"),
      ("", "created_at, updated_at"),
    ],
    "xy": (28, 125),
    "w": 155,
  },
  "farms": {
    "title": "farms",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "owner_id → profiles"),
      ("", "name"),
      ("", "barangay, municipality_city"),
      ("", "province"),
      ("", "latitude, longitude"),
      ("", "created_at"),
    ],
    "xy": (230, 110),
    "w": 160,
  },
  "devices": {
    "title": "devices",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "farm_id → farms  # null until claim"),
      ("", "device_uid  # UNIQUE"),
      ("", "ingest_token  # lab secret"),
      ("", "claim_code  # UNIQUE sticker"),
      ("", "name, status"),
      ("", "last_seen_at, claimed_at"),
      ("", "flashed_at, flash_status  # lab"),
      ("", "created_at"),
    ],
    "xy": (450, 48),
    "w": 185,
  },
  "soil_readings": {
    "title": "soil_readings",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "device_id → devices"),
      ("", "recorded_at"),
      ("", "moisture_percent, ph"),
      ("", "soil_temperature_c, ec, salinity"),
      ("", "N, P, K"),
      ("", "validation_status / message"),
    ],
    "xy": (675, 55),
    "w": 145,
  },
  "weather_snapshots": {
    "title": "weather_snapshots",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "farm_id → farms"),
      ("", "recorded_at"),
      ("", "temperature_c, humidity_percent"),
      ("", "rainfall_mm, rain_probability"),
      ("", "wind_speed, weather_condition"),
      ("", "source"),
    ],
    "xy": (230, 310),
    "w": 160,
  },
  "crops": {
    "title": "crops (reference)",
    "attrs": [
      ("PK", "id uuid"),
      ("", "name  # UNIQUE"),
      ("", "scientific_name"),
      ("", "moisture/ph/temp/ec/sal min·max"),
      ("", "NPK min·max  # nullable"),
      ("", "days_to_maturity, phases jsonb"),
      ("", "range_meta, growing_season, notes"),
    ],
    "xy": (28, 330),
    "w": 170,
  },
  "plantings": {
    "title": "plantings",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "farm_id → farms"),
      ("FK", "crop_id → crops"),
      ("", "planted_at, expected_harvest_at"),
      ("", "status  # planned|active|…"),
      ("", "created_at"),
      ("", "≤1 active per farm (index)"),
    ],
    "xy": (480, 320),
    "w": 170,
  },
}

# src, tgt, src_side, tgt_side, src_card, tgt_card, label, src_slot, tgt_slot, waypoints
PAGE1_RELS = [
  ("auth_users", "profiles", "S", "N", "one", "one", "1:1", 0, 0, None),
  ("profiles", "farms", "E", "W", "one", "zero_many", "owns", 0, 0, None),
  ("farms", "devices", "E", "W", "one", "zero_many", "has", 0, 0, None),
  ("devices", "soil_readings", "E", "W", "one", "many", "", 0, 0, None),
  # farms → weather: straight down (same column)
  ("farms", "weather_snapshots", "S", "N", "one", "many", "", 0, 0, None),
  # farms → plantings: right into gap (x=420), then down onto plantings top
  ("farms", "plantings", "E", "N", "one", "many", "", 1, 0, [(420, 160), (420, 305), (565, 305)]),
  # crops → plantings: BOTTOM rail under weather (no box crossing)
  ("crops", "plantings", "S", "S", "one", "many", "", 0, 0, [(113, 460), (565, 460)]),
]

# ---------------------------------------------------------------------------
# Page 2 — two horizontal bands (AI top, irrigation bottom); refs on left
# ---------------------------------------------------------------------------
PAGE2 = {
  "farms_ref": {
    "title": "farms (ref)",
    "attrs": [("PK", "id"), ("FK", "owner_id")],
    "xy": (22, 55),
    "w": 100,
  },
  "plantings_ref": {
    "title": "plantings (ref)",
    "attrs": [("PK", "id"), ("FK", "farm_id, crop_id")],
    "xy": (22, 125),
    "w": 115,
  },
  "soil_ref": {
    "title": "soil_readings (ref)",
    "attrs": [("PK", "id"), ("FK", "device_id")],
    "xy": (22, 195),
    "w": 120,
  },
  "weather_ref": {
    "title": "weather_snapshots (ref)",
    "attrs": [("PK", "id"), ("FK", "farm_id")],
    "xy": (22, 265),
    "w": 130,
  },
  "ai_assessments": {
    "title": "ai_assessments",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "farm_id → farms"),
      ("", "kind  # home|analytics|crops"),
      ("FK", "planting_id  # null"),
      ("FK", "soil_reading_id  # null"),
      ("FK", "weather_snapshot_id  # null"),
      ("", "period_days / start / end"),
      ("", "overview, soil_health_score"),
      ("", "generated_at, model_name, prompt_version"),
    ],
    "xy": (250, 50),
    "w": 200,
  },
  "ai_recommendations": {
    "title": "ai_recommendations",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "assessment_id"),
      ("", "type  # irrigation|nutrient|…"),
      ("", "title, description"),
      ("", "priority  # low|medium|high"),
      ("", "recommended_action"),
      ("", "valid_until, created_at"),
    ],
    "xy": (490, 55),
    "w": 165,
  },
  "farm_notifications": {
    "title": "farm_notifications",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "farm_id → farms"),
      ("", "type, severity"),
      ("", "title, body"),
      ("FK", "soil_reading_id  # null"),
      ("", "dedupe_key  # UNIQUE w/ farm"),
      ("", "read_at, created_at"),
    ],
    "xy": (680, 50),
    "w": 145,
  },
  "irrigation_plans": {
    "title": "irrigation_plans",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "farm_id → farms"),
      ("FK", "planting_id → plantings"),
      ("", "horizon_start, horizon_days"),
      ("", "story_fingerprint, overview"),
      ("", "model_name, prompt_version"),
      ("", "generated_at, valid_until"),
    ],
    "xy": (250, 330),
    "w": 190,
  },
  "irrigation_plan_slots": {
    "title": "irrigation_plan_slots",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "plan_id → irrigation_plans"),
      ("", "slot_date"),
      ("", "action  # water|check|no_water"),
      ("", "confidence, guidance, reason"),
      ("FK", "completed_action_id → farm_actions"),
    ],
    "xy": (480, 340),
    "w": 190,
  },
  "farm_actions": {
    "title": "farm_actions",
    "attrs": [
      ("PK", "id uuid"),
      ("FK", "farm_id → farms"),
      ("FK", "created_by → profiles"),
      ("FK", "planting_id  # null"),
      ("FK", "plan_slot_id  # null"),
      ("", "action_type, amount, unit"),
      ("", "notes, performed_at"),
    ],
    "xy": (700, 335),
    "w": 125,
  },
}

# Parallel buses in the gap (x≈175–220) so lines do not share one vertical.
# farms→farm_actions / plantings→farm_actions omitted on purpose (FK listed on box).
PAGE2_RELS = [
  ("farms_ref", "ai_assessments", "E", "W", "one", "many", "", 0, 0, [(180, 72)]),
  ("plantings_ref", "ai_assessments", "E", "W", "zero_one", "many", "", 0, 1, [(188, 148)]),
  ("soil_ref", "ai_assessments", "E", "W", "zero_one", "many", "", 0, 2, [(196, 220)]),
  ("weather_ref", "ai_assessments", "E", "W", "zero_one", "many", "", 0, 3, [(204, 290), (204, 205)]),
  ("ai_assessments", "ai_recommendations", "E", "W", "one", "many", "", 0, 0, None),
  ("farms_ref", "farm_notifications", "N", "N", "one", "many", "", 0, 0, [(72, 34), (752, 34)]),
  ("soil_ref", "farm_notifications", "E", "W", "zero_one", "many", "", 0, 0, [(196, 230), (196, 34), (680, 34), (680, 90)]),
  ("farms_ref", "irrigation_plans", "E", "W", "one", "many", "", 1, 0, [(212, 95), (212, 365)]),
  ("plantings_ref", "irrigation_plans", "E", "W", "one", "many", "", 1, 1, [(220, 160), (220, 385)]),
  ("irrigation_plans", "irrigation_plan_slots", "E", "W", "one", "many", "", 0, 0, None),
  ("irrigation_plan_slots", "farm_actions", "E", "W", "zero_one", "zero_one", "Mark watered", 0, 0, None),
]


def entity_h(attrs: list) -> float:
  return HEADER_H + len(attrs) * ROW_H + 2


def boxes_of(entities: dict) -> dict[str, tuple[float, float, float, float]]:
  out = {}
  for k, e in entities.items():
    x, y = e["xy"]
    out[k] = (x, y, e["w"], entity_h(e["attrs"]))
  return out


def anchor(box, side: str, slot: int = 0, n_slots: int = 1) -> tuple[float, float]:
  x, y, w, h = box
  n_slots = max(n_slots, 1)
  t = (slot + 1) / (n_slots + 1)
  if side == "N":
    return x + w * t, y
  if side == "S":
    return x + w * t, y + h
  if side == "W":
    return x, y + h * t
  return x + w, y + h * t  # E


def unit(dx: float, dy: float) -> tuple[float, float]:
  L = math.hypot(dx, dy) or 1.0
  return dx / L, dy / L


def build_route(p1, side1, p2, side2, waypoints):
  if waypoints:
    return [p1, *waypoints, p2]
  x1, y1 = p1
  x2, y2 = p2
  if side1 == "E" and side2 == "W":
    if abs(y1 - y2) < 0.8:
      return [p1, p2]
    mx = (x1 + x2) / 2
    return [p1, (mx, y1), (mx, y2), p2]
  if side1 == "S" and side2 == "N":
    # Prefer a straight vertical (avoids ugly mid-jog when anchors are nearly aligned)
    if abs(x1 - x2) < 28:
      if abs(x1 - x2) < 0.8:
        return [p1, p2]
      return [p1, (x1, y2), p2]
    my = (y1 + y2) / 2
    return [p1, (x1, my), (x2, my), p2]
  if side1 == "N" and side2 == "N":
    my = min(y1, y2) - 8
    return [p1, (x1, my), (x2, my), p2]
  if side1 == "S" and side2 == "S":
    my = max(y1, y2) + 8
    return [p1, (x1, my), (x2, my), p2]
  if side1 in ("E", "W") and side2 in ("N", "S"):
    return [p1, (x2, y1), p2]
  if side1 in ("N", "S") and side2 in ("E", "W"):
    return [p1, (x1, y2), p2]
  return [p1, ((x1 + x2) / 2, y1), ((x1 + x2) / 2, y2), p2]


def marker_geometry(tip, toward_line, kind: str, size: float = 8.0) -> dict:
  """Crow's-foot marker. tip = point on entity edge; toward_line = next point along edge."""
  ux, uy = unit(toward_line[0] - tip[0], toward_line[1] - tip[1])
  px, py = -uy, ux
  parts: dict = {"kind": kind, "tip": tip, "u": (ux, uy), "p": (px, py), "size": size}

  # Optional (0..): hollow circle first
  if kind in ("zero_one", "zero_many"):
    parts["circle"] = (tip[0] + ux * size * 0.5, tip[1] + uy * size * 0.5, size * 0.42)

  # One: double perpendicular bars
  if kind in ("one", "zero_one"):
    base = size * (1.2 if kind.startswith("zero") else 0.45)
    hw = size * 0.6
    for i, off in enumerate((0.0, 0.4) if kind == "one" else (0.0,)):
      bx = tip[0] + ux * (base + i * size * 0.4)
      by = tip[1] + uy * (base + i * size * 0.4)
      parts.setdefault("bars", []).append(
        ((bx - px * hw, by - py * hw), (bx + px * hw, by + py * hw))
      )

  # Many: crow's foot (3 toes at entity tip)
  if kind in ("many", "zero_many"):
    base = size * (1.35 if kind.startswith("zero") else 0.15)
    heel = (tip[0] + ux * (base + size * 1.05), tip[1] + uy * (base + size * 1.05))
    spread = size * 0.75
    parts["crow"] = [
      (tip, heel),
      (tip, (heel[0] + px * spread, heel[1] + py * spread)),
      (tip, (heel[0] - px * spread, heel[1] - py * spread)),
    ]
  return parts


def slot_counts(rels):
  src_n: dict[tuple[str, str], int] = {}
  tgt_n: dict[tuple[str, str], int] = {}
  for r in rels:
    src, tgt, ss, ts = r[0], r[1], r[2], r[3]
    src_n[(src, ss)] = src_n.get((src, ss), 0) + 1
    tgt_n[(tgt, ts)] = tgt_n.get((tgt, ts), 0) + 1
  return src_n, tgt_n


# ---- PDF ----

def pdf_polyline(c, pts, page_h):
  path = c.beginPath()
  path.moveTo(pts[0][0], page_h - pts[0][1])
  for x, y in pts[1:]:
    path.lineTo(x, page_h - y)
  c.drawPath(path, stroke=1, fill=0)


def pdf_marker(c, parts, page_h):
  c.setStrokeColor(EDGE)
  c.setFillColor(BG)
  c.setLineWidth(1.15)
  if "circle" in parts:
    cx, cy, r = parts["circle"]
    c.circle(cx, page_h - cy, r, stroke=1, fill=1)
  for a, b in parts.get("bars", []):
    c.line(a[0], page_h - a[1], b[0], page_h - b[1])
  for a, b in parts.get("crow", []):
    c.line(a[0], page_h - a[1], b[0], page_h - b[1])


def pdf_entity(c, e, page_h):
  x, y_top = e["xy"]
  w = e["w"]
  h = entity_h(e["attrs"])
  y = page_h - y_top - h
  c.setFillColor(PRIMARY)
  c.setStrokeColor(PRIMARY)
  c.roundRect(x, y + h - HEADER_H, w, HEADER_H, 1.5, fill=1, stroke=1)
  c.setFillColor(white)
  c.setFont("Helvetica-Bold", 6.0)
  c.drawString(x + 3, y + h - HEADER_H + 4.2, e["title"][:44])
  c.setStrokeColor(PRIMARY)
  c.setFillColor(ROW_BG)
  c.rect(x, y, w, h - HEADER_H, fill=1, stroke=1)
  for i, (kind, text) in enumerate(e["attrs"]):
    ry = y + h - HEADER_H - (i + 1) * ROW_H
    if "PK" in kind:
      c.setFillColor(PK_BG)
      prefix, font = "PK ", "Helvetica-Bold"
    elif "FK" in kind:
      c.setFillColor(FK_BG)
      prefix, font = "FK ", "Helvetica-Oblique"
    else:
      c.setFillColor(ROW_BG)
      prefix, font = "   ", "Helvetica"
    c.rect(x + 0.4, ry, w - 0.8, ROW_H, fill=1, stroke=0)
    c.setFillColor(TEXT)
    c.setFont(font, 5.1)
    c.drawString(x + 2.5, ry + 2.0, (prefix + text)[:46])


def draw_edges(c, page_h, boxes, rels, src_n, tgt_n):
  for r in rels:
    src, tgt, ss, ts, sc, tc, label, s_slot, t_slot, wps = r
    p1 = anchor(boxes[src], ss, s_slot, src_n[(src, ss)])
    p2 = anchor(boxes[tgt], ts, t_slot, tgt_n[(tgt, ts)])
    route = build_route(p1, ss, p2, ts, wps)

    def nudge(a, b, d=2.0):
      ux, uy = unit(b[0] - a[0], b[1] - a[1])
      return a[0] + ux * d, a[1] + uy * d

    route = [nudge(route[0], route[1])] + route[1:-1] + [nudge(route[-1], route[-2])]

    c.setStrokeColor(EDGE)
    c.setLineWidth(0.85)
    pdf_polyline(c, route, page_h)

    if label:
      best, best_len = (route[0], route[1]), 0.0
      for a, b in zip(route, route[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L > best_len:
          best, best_len = (a, b), L
      mx = (best[0][0] + best[1][0]) / 2
      my = (best[0][1] + best[1][1]) / 2
      tw = c.stringWidth(label, "Helvetica", 5.0) + 4
      c.setFillColor(BG)
      c.rect(mx - tw / 2, page_h - my - 3.2, tw, 7.5, fill=1, stroke=0)
      c.setFillColor(MUTED)
      c.setFont("Helvetica", 5.0)
      c.drawCentredString(mx, page_h - my - 0.8, label)


def render_pdf_page(c, page_w, page_h, title, subtitle, entities, rels, page_label):
  c.setFillColor(BG)
  c.rect(0, 0, page_w, page_h, fill=1, stroke=0)
  c.setFillColor(TEXT)
  c.setFont("Helvetica-Bold", 10)
  c.drawString(18, page_h - 15, title)
  c.setFillColor(MUTED)
  c.setFont("Helvetica", 6.3)
  c.drawString(18, page_h - 26, subtitle)
  c.drawRightString(page_w - 18, page_h - 15, page_label)

  boxes = boxes_of(entities)
  src_n, tgt_n = slot_counts(rels)
  # Boxes first, then edges + crow's-foot ON TOP (so markers are not covered)
  for e in entities.values():
    pdf_entity(c, e, page_h)
  draw_edges(c, page_h, boxes, rels, src_n, tgt_n)

  c.setFillColor(MUTED)
  c.setFont("Helvetica", 5.0)
  c.drawString(
    18,
    11,
    "Simple relationship lines (cardinality in labels where shown) · PK/FK in boxes · admin/lab fields included · DATA_MODEL.md",
  )


# ---- PNG ----

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


def png_marker(d, tip, toward, kind, scale, size_pt=7.2):
  tip_s = (tip[0] * scale, tip[1] * scale)
  toward_s = (toward[0] * scale, toward[1] * scale)
  g = marker_geometry(tip_s, toward_s, kind, size=size_pt * scale)
  if "circle" in g:
    cx, cy, r = g["circle"]
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=P_LINE, fill=P_BG, width=2)
  for a, b in g.get("bars", []):
    d.line([a, b], fill=P_LINE, width=2)
  for a, b in g.get("crow", []):
    d.line([a, b], fill=P_LINE, width=2)


def render_png_page(title, subtitle, entities, rels, page_label, out_path):
  dpi = 150
  w = int(297 / 25.4 * dpi)
  h = int(210 / 25.4 * dpi)
  scale = w / 841.89
  img = Image.new("RGB", (w, h), P_BG)
  d = ImageDraw.Draw(img)
  font_title = try_font(16)
  font_sub = try_font(10)
  font_h = try_font(9)
  font_row = try_font(8)
  font_edge = try_font(8)
  font_foot = try_font(7)

  d.text((int(18 * scale), int(7 * scale)), title, fill=P_TEXT, font=font_title)
  d.text((int(18 * scale), int(26 * scale)), subtitle, fill=P_MUTED, font=font_sub)
  tw = d.textlength(page_label, font=font_sub)
  d.text((w - int(18 * scale) - tw, int(9 * scale)), page_label, fill=P_MUTED, font=font_sub)

  boxes = boxes_of(entities)
  src_n, tgt_n = slot_counts(rels)

  # Draw entity boxes first
  header_h = HEADER_H * scale
  row_h = ROW_H * scale
  for e in entities.values():
    x, y = e["xy"]
    bw, bh = e["w"], entity_h(e["attrs"])
    x, y, bw, bh = x * scale, y * scale, bw * scale, bh * scale
    d.rounded_rectangle([x, y, x + bw, y + header_h], radius=2, fill=P_PRIMARY, outline=P_PRIMARY)
    d.text((x + 4, y + 2), e["title"][:44], fill=P_WHITE, font=font_h)
    d.rectangle([x, y + header_h, x + bw, y + bh], fill=P_BG, outline=P_PRIMARY)
    for i, (kind, text) in enumerate(e["attrs"]):
      ry = y + header_h + i * row_h
      if "PK" in kind:
        fill, prefix = P_PK, "PK "
      elif "FK" in kind:
        fill, prefix = P_FK, "FK "
      else:
        fill, prefix = P_BG, "   "
      d.rectangle([x + 1, ry, x + bw - 1, ry + row_h], fill=fill)
      d.text((x + 3, ry + 1), (prefix + text)[:46], fill=P_TEXT, font=font_row)

  # Edges + crow's-foot markers on top of boxes
  for r in rels:
    src, tgt, ss, ts, sc, tc, label, s_slot, t_slot, wps = r
    p1 = anchor(boxes[src], ss, s_slot, src_n[(src, ss)])
    p2 = anchor(boxes[tgt], ts, t_slot, tgt_n[(tgt, ts)])
    route = build_route(p1, ss, p2, ts, wps)

    def nudge(a, b, dist=2.0):
      ux, uy = unit(b[0] - a[0], b[1] - a[1])
      return a[0] + ux * dist, a[1] + uy * dist

    route = [nudge(route[0], route[1])] + route[1:-1] + [nudge(route[-1], route[-2])]
    scaled = [(x * scale, y * scale) for x, y in route]
    d.line(scaled, fill=P_LINE, width=2)

    if label:
      best, best_len = (route[0], route[1]), 0.0
      for a, b in zip(route, route[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L > best_len:
          best, best_len = (a, b), L
      mx = (best[0][0] + best[1][0]) / 2 * scale
      my = (best[0][1] + best[1][1]) / 2 * scale
      lw = d.textlength(label, font=font_edge)
      d.rectangle([mx - lw / 2 - 3, my - 6, mx + lw / 2 + 3, my + 6], fill=P_BG)
      d.text((mx - lw / 2, my - 5), label, fill=P_MUTED, font=font_edge)

  d.text(
    (int(14 * scale), h - int(14 * scale)),
    "Simple relationship lines · PK/FK in boxes · admin/lab included · Source: DATA_MODEL.md",
    fill=P_MUTED,
    font=font_foot,
  )
  img.save(out_path, "PNG", dpi=(dpi, dpi))


# ---- Draw.io ----

def esc(s: str) -> str:
  return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


CARD_ARROW = {
  "one": "ERmandOne",
  "zero_one": "ERzeroToOne",
  "many": "ERoneToMany",
  "zero_many": "ERzeroToMany",
}


def drawio_page(name, page_id, entities, rels, title, subtitle):
  HEADER, ROW, PRIMARY_C = 20, 13, "#4A7C59"
  cells, cid = [], 2
  cells.append(
    f'<mxCell id="{cid}" value="{esc(title)}" style="text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=13;fontStyle=1;fontColor=#2C332C;" vertex="1" parent="1">'
    f'<mxGeometry x="16" y="6" width="720" height="20" as="geometry"/></mxCell>'
  )
  cid += 1
  cells.append(
    f'<mxCell id="{cid}" value="{esc(subtitle)}" style="text;html=1;strokeColor=none;fillColor=none;align=left;fontSize=9;fontColor=#6B706B;" vertex="1" parent="1">'
    f'<mxGeometry x="16" y="24" width="800" height="14" as="geometry"/></mxCell>'
  )
  cid += 1
  sx, sy = 1169 / 841.89, 827 / 595.28
  eids = {}
  for key, e in entities.items():
    x, y, w, attrs = e["xy"][0], e["xy"][1], e["w"], e["attrs"]
    h = HEADER + ROW * len(attrs) + 2
    dx, dy, dw = x * sx, y * sy, max(w * sx, w * 1.08)
    cells.append(
      f'<mxCell id="{cid}" value="{esc(e["title"])}" style="swimlane;fontStyle=1;align=center;verticalAlign=middle;childLayout=stackLayout;horizontal=1;startSize={HEADER};horizontalStack=0;resizeParent=1;resizeParentMax=0;resizeLast=0;collapsible=0;marginBottom=0;fillColor={PRIMARY_C};fontColor=#FFFFFF;strokeColor={PRIMARY_C};fontSize=10;" vertex="1" parent="1">'
      f'<mxGeometry x="{dx:.1f}" y="{dy:.1f}" width="{dw:.1f}" height="{h}" as="geometry"/></mxCell>'
    )
    parent = cid
    eids[key] = parent
    cid += 1
    for i, (kind, text) in enumerate(attrs):
      if "PK" in kind:
        fill, fs, prefix = "#E8F0EB", "1", f"PK  {text}"
      elif "FK" in kind:
        fill, fs, prefix = "#F0EFE8", "2", f"FK  {text}"
      else:
        fill, fs, prefix = "#FAFAF8", "0", f"    {text}"
      cells.append(
        f'<mxCell id="{cid}" value="{esc(prefix)}" style="text;strokeColor=none;fillColor={fill};align=left;verticalAlign=middle;spacingLeft=4;fontSize=8;fontFamily=Courier New;fontStyle={fs};fontColor=#2C332C;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;" vertex="1" parent="{parent}">'
        f'<mxGeometry y="{HEADER + i * ROW}" width="{dw:.1f}" height="{ROW}" as="geometry"/></mxCell>'
      )
      cid += 1

  for r in rels:
    src, tgt, _ss, _ts, sc, tc, label = r[0], r[1], r[2], r[3], r[4], r[5], r[6]
    style = (
      "edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;startArrow=none;endArrow=none;"
      "strokeColor=#4A4E4A;fontSize=8;fontColor=#6B706B;"
      "labelBackgroundColor=#FAFAF8;jettySize=auto;orthogonalLoop=1;"
    )
    cells.append(
      f'<mxCell id="{cid}" value="{esc(label)}" style="{style}" edge="1" parent="1" source="{eids[src]}" target="{eids[tgt]}">'
      f'<mxGeometry relative="1" as="geometry"/></mxCell>'
    )
    cid += 1

  body = "\n".join(cells)
  return f'''  <diagram id="{page_id}" name="{esc(name)}">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0" background="#FAFAF8">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
{body}
      </root>
    </mxGraphModel>
  </diagram>'''


def build_pdf():
  path = OUT / "ERD.pdf"
  page = landscape(A4)
  c = canvas.Canvas(str(path), pagesize=page)
  w, h = page
  render_pdf_page(
    c, w, h,
    "SoilGood — Logical ERD (attribute-level)",
    "Figure A · Core farm, IoT & crops · A4 landscape · simple relationship lines",
    PAGE1, PAGE1_RELS, "Page 1 of 2",
  )
  c.showPage()
  render_pdf_page(
    c, w, h,
    "SoilGood — Logical ERD (attribute-level)",
    "Figure B · AI, irrigation, actions & notifications · A4 landscape · simple relationship lines",
    PAGE2, PAGE2_RELS, "Page 2 of 2",
  )
  c.save()
  return path


def build_pngs():
  p1, p2 = OUT / "ERD-page1.png", OUT / "ERD-page2.png"
  render_png_page(
    "SoilGood — Logical ERD (attribute-level)",
    "Figure A · Core farm, IoT & crops · A4 landscape · simple relationship lines",
    PAGE1, PAGE1_RELS, "Page 1 of 2", p1,
  )
  render_png_page(
    "SoilGood — Logical ERD (attribute-level)",
    "Figure B · AI, irrigation, actions & notifications · A4 landscape · simple relationship lines",
    PAGE2, PAGE2_RELS, "Page 2 of 2", p2,
  )
  return p1, p2


def build_drawio():
  path = OUT / "ERD.drawio"
  d1 = drawio_page("Figure A — Core", "page-core", PAGE1, PAGE1_RELS,
                   "SoilGood — Logical ERD", "Figure A · Core · simple lines")
  d2 = drawio_page("Figure B — AI & ops", "page-ai", PAGE2, PAGE2_RELS,
                   "SoilGood — Logical ERD", "Figure B · AI & ops · simple lines")
  path.write_text(
    f'''<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" modified="2026-09-07T04:20:00.000Z" agent="SoilGood thesis ERD" version="22.1.0" type="device">
{d1}
{d2}
</mxfile>
''',
    encoding="utf-8",
  )
  return path


def main():
  pdf = build_pdf()
  p1, p2 = build_pngs()
  dio = build_drawio()
  print(f"PDF:  {pdf}")
  print(f"PNG1: {p1}")
  print(f"PNG2: {p2}")
  print(f"Draw: {dio}")


if __name__ == "__main__":
  main()
