# Page: Home Dashboard

## Status
- [ ] Planned
- [x] In progress (live soil + weather + Home tips including Crop care)
- [ ] Done

## Purpose / goal
**Now.** Answer today: what is the soil condition (in words), should I water, fertilizer if planted, and phase crop care?

Show the latest soil condition, live 8-in-1 values, a short forecast, and AI cards: Condition, Water today, Nutrients, and **Crop care** when planted. Weekly water plan lives on [Crops](crops.md). History is [Analytics](analytics.md).

## User flow
- Open Home tab from app shell.
- Scan the farm picture, soil moisture and weather, AI cards, quick stats, then the 8-in-1 numbers and forecast.
- **Realtime:** a new `soil_readings` row updates sensor cards and **rechecks** Home AI (usually reuse saved tips; Groq only if story fingerprint / cache says so). No pull required for tip updates while Home is open.
- **Pull-to-refresh** still refetches soil + weather + AI path (weather is not Realtime). Forecast strip stays horizontal-only.
- Nutrients CTA (no crop): open Crops tab to add a planting.
- **Closed app:** no AI — generation only while Home is mounted.

## In / out (locked)

**On Home**
- Latest reading only (timestamp + stale/error must be visible).
- Live 8-in-1 grid (the only place current sensor values are shown).
- Quick Insight: whole-soil condition **in words** (bands), not raw “moisture 28% · N 42”.
- Short forecast strip (UI may show ~3 days; Open-Meteo fetch is **7 days** for the Crops water plan).
- AI cards tied to latest soil + weather (+ active crop when set):
  1. **Condition** (`soil_management`)
  2. **Water today** (`irrigation`) — override for *today*; does not alone rewrite the week plan
  3. **Nutrients** (`nutrient`) — or CTA if no planting
  4. **Crop care** (`crop_care`) — phase chores only when planted (no water/NPK orders)

**Not on Home**
- Mark watered / week strip (Crops only).
- Monthly / 7-day averages, multi-metric trend charts.
- Browseable history.
- Overview essay above the tip cards.

## AI voice (locked)
Caring neighbor farmer, **simple English**. Warm, calm, 2–4 short sentences with a why + next step. No deep vocabulary, no chatbot tone, no em dash habit. Mention **sensor only when the reading looks wrong**. Never refer the farmer to a farm officer / DA / extension. Rules live in [`insights.json`](../../supabase/functions/soilgood-insights/insights.json) `voice` + `prompts.home`. See [AI_INSIGHTS.md](../context/AI_INSIGHTS.md).

## Data & sources
- **Soil cards (2×4 compact grid; 1 column if width < 360):** latest row from `soil_readings` (fetch + Realtime stream) via `SoilReadingsRepository`.
- **Forecast:** live **Open-Meteo** using farm lat/long (fail visibly if no farm / network error).
- **Active crop:** `CropsRepository.fetchActivePlanting` for Nutrients + Groq crop/phase facts.
- **Saved AI:** latest `ai_assessments` where `kind = 'home'`. Story fingerprint (bands including temp + rain advice + crop/phase + crop range token) is stored on the overview line (`SGFP:…`) so smarter regen can skip Groq when the farmer story is unchanged. Classified bands use the active crop’s catalog ranges when planted; otherwise universal floors. Critical bands → urgent tip voice + high priority. Call Edge Function `soilgood-insights` (`job=home`) only if none saved, fingerprint changed, `valid_until` passed (~12h), or `prompt_version` changed. No reading → no Groq. Triggers while Home is open: first load, pull, and **Realtime new reading id**. Closed app does not call Groq. Rules/bands: [`insights.json`](../../supabase/functions/soilgood-insights/insights.json). Crop research: [`CROP_RANGES.md`](../context/CROP_RANGES.md).

## UI states
| State | Notes |
|---|---|
| Skeleton | First open only — banner + sensor + three AI placeholders until first soil fetch |
| Cached / live | Last-known soil + weather + AI stay on screen during pull and during Realtime AI recheck |
| Refreshing | Page-level `RefreshIndicator`; refetch soil + weather (~15s); Groq ~20s if regen. Realtime AI recheck keeps last tips visible (`loading` only when no assessment yet) |
| Empty | No readings yet — message to link a device |
| Error | Per-source banners (soil and/or weather and/or AI). Successful source is kept |

## Optimistic UI
None (read-only).

## Functions
| Function | What it does | When called |
|---|---|---|
| `_warmCache()` | Timed `fetchLatest` for first paint | `initState` |
| `_onSoilStreamEvent()` | Sync Realtime soil into state; AI recheck if reading id is new | Whole page (subscription) |
| `_loadWeather()` | First Open-Meteo load | `initState` |
| `_reloadAll()` | Parallel soil + weather; then Home AI cheap-load / smarter regen | Pull-to-refresh |
| `_loadHomeAi()` | Coalesced load saved `kind=home`; Groq + save if fingerprint says regen | First load, pull, Realtime new reading id |

## Page logic flowchart
```mermaid
flowchart TD
  A[Open Home] --> B[Skeleton if no soil yet]
  B --> C[Show latest soil banner + 8-in-1 cards]
  C --> D[Show 3-day forecast from Open-Meteo]
  D --> E[Load saved Home AI]
  E --> F{Story fingerprint changed or cache expired}
  F -->|No| G[Show Condition Water Nutrients]
  F -->|Yes| H[Call Groq and save]
  H --> G
  G --> R[Realtime new soil reading]
  R --> C
  R --> E
  G --> I[Farmer pulls page]
  I --> J[Keep last-known on screen]
  J --> K[Refetch soil + weather]
  K --> E
```

## Related
- Shell: Home / Analytics / Crops / Profile. Over-time view: [analytics.md](analytics.md).
- Rules: `.cursor/rules/page-architecture/responsive-ui.mdc`, `pull-to-refresh.mdc`.
