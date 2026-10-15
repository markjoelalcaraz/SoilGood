# SoilGood — Entity-Relationship Diagram (Thesis)

Print-ready **logical / attribute-level** ERD for the SoilGood Supabase (Postgres) schema. Split into **two A4 landscape figures** so attributes stay readable on paper.

## Print these (ready now)

| File | Use |
|------|-----|
| [`ERD.pdf`](ERD.pdf) | **Best for thesis** — 2× A4 landscape, print or insert as figures |
| [`ERD-page1.png`](ERD-page1.png) | Figure A — Core farm, IoT & crops (150 DPI) |
| [`ERD-page2.png`](ERD-page2.png) | Figure B — AI, irrigation, actions & notifications (150 DPI) |
| [`ERD.drawio`](ERD.drawio) | Editable source (2 pages, A4 landscape page size) |

### Suggested captions

- *Figure A. Logical ERD of SoilGood — core farm, IoT sensor, and crop entities (attribute-level).*
- *Figure B. Logical ERD of SoilGood — AI assessments, irrigation plans, farm actions, and notifications (attribute-level).*

### Print settings

- Paper: **A4 landscape**
- PDF: open `ERD.pdf` → print **Actual size** / 100% (do not “Fit to printable area” unless margins clip)
- Word/Docs: Insert PNG → set width ≈ **26–27 cm** (full content width) or paste PDF pages as images

## Notation

Simple orthogonal relationship lines (no crow’s-foot ends). Optional mid-line labels (`1:1`, `owns`, `has`, `Mark watered`) where useful. PK/FK remain marked inside entity boxes.

On Figure B, direct lines from `farms`/`plantings` → `farm_actions` are omitted to avoid page-crossing clutter; those FKs remain listed on the `farm_actions` box (and `plan_slot_id` is drawn via “Mark watered”).

## Regenerate after schema changes

```bash
python docs/thesis/_gen_erd.py
```

Rewrites `ERD.pdf`, `ERD-page1.png`, `ERD-page2.png`, and `ERD.drawio`.

## Related

- [`SYSTEM_FLOWCHART.md`](../context/SYSTEM_FLOWCHART.md) — process flows (not the data model)  
- [`SECURITY.md`](../context/SECURITY.md) — RLS ownership
