# SoilGood — System Flowchart (Thesis)

Process / data-flow figures for the **complete SoilGood system**, including **farmer logs** (`farm_actions` / Mark watered). Intended for thesis print (**A4 landscape, 2 pages**).

## Ready-to-print

| File | Purpose |
|------|---------|
| **[`SYSTEM_FLOWCHART.pdf`](SYSTEM_FLOWCHART.pdf)** | **Print this** — 2× A4 landscape, detailed, spaced |
| [`SYSTEM_FLOWCHART-page1.png`](SYSTEM_FLOWCHART-page1.png) | Preview page 1 |
| [`SYSTEM_FLOWCHART-page2.png`](SYSTEM_FLOWCHART-page2.png) | Preview page 2 |
| [`SYSTEM_FLOWCHART.drawio`](SYSTEM_FLOWCHART.drawio) | Editable Draw.io (extra detail / re-export) |
| [`_gen_system_flowchart_pdf.py`](_gen_system_flowchart_pdf.py) | Regenerates PDF + PNGs |
| [`_gen_system_flowchart.py`](_gen_system_flowchart.py) | Regenerates `.drawio` |

## Pages

| Page | Content |
|------|---------|
| **1** | System context (Lab → ESP32 → Supabase → App → APIs) + farmer setup journey + shell tabs |
| **2** | Daily ops loop in 4 columns: Sense → Show/decide → **Act + farmer log** → Store & learn (Analytics reads `farm_actions`) |

## Regenerate

```bash
python docs/thesis/_gen_system_flowchart_pdf.py
python docs/thesis/_gen_system_flowchart.py
```

Source: [`../context/FEATURES.md`](../context/FEATURES.md), [`../context/DATA_MODEL.md`](../context/DATA_MODEL.md), [`../pages/`](../pages/).
