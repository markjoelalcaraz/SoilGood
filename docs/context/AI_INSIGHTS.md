# SoilGood — AI insights config

Source of truth for **parameters + prompt rules**: [`supabase/functions/soilgood-insights/insights.json`](../../supabase/functions/soilgood-insights/insights.json).

Flutter loads the same file locally to **classify bands** (0 Groq tokens). Groq only sees a **page slice** attached by the **Edge Function**.

**Locked:** Groq (`openai/gpt-oss-120b`) is the only model for **generated** insight text. Groq decommissioned the previous `llama-3.3-70b-versatile` on 2026-08-16; `openai/gpt-oss-120b` is their recommended replacement. Catalog match and phase/day math stay on-device. The Groq key is an Edge Function secret — never in the Flutter APK.

## Production API

```text
App open (anon + user JWT) — Home mounted
  → classify locally (bands)          0 Groq token
  → POST soilgood-insights
       { job, payload }               facts / daily buckets only
  → Function attaches JSON slice
  → Groq (only if live soil data)
  → JSON back → save ai_assessments

Home triggers: first open, pull-to-refresh, Realtime new soil_reading id.
Closed app: no call. Fingerprint / valid_until still skip Groq when story unchanged.
```

| Job | `job` value | Required payload |
|---|---|---|
| Home today | `home` | `facts.soil_reading_id` |
| Analytics selected window | `analytics` | `history.days` (non-empty) + `period_start` / `period_end` |
| Crops care | `crops.care` | `facts.soil_reading_id` + crop/phase |
| Crops catalog | *(none)* | local vs `crops` table |

No live reading → HTTP 400 `no_reading`, **Groq is not called**.

JWT is verified **inside** the function (`getUser()`). Gateway `verify_jwt` is off so Flutter web OPTIONS preflight gets CORS. Logged-out calls still 401.

## Deploy (one-time)

CLI is **not** on PATH on this machine; use `npx`:

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase secrets set GROQ_API_KEY=gsk_...
npx supabase functions deploy soilgood-insights
```

The function **imports** `insights.json` so the file is in the deploy bundle. Do not switch back to `Deno.readTextFile` — that 500s on hosted Edge because the JSON is not on disk.

`YOUR_PROJECT_REF` is the subdomain in `SUPABASE_URL` (`https://<ref>.supabase.co`).

Dashboard alternative: Project Settings → Edge Functions → secrets, then deploy from CLI (Dashboard paste is possible but the repo function is the source of truth).

## Does one JSON file save tokens?

**Partly — but not because “the AI reads one file.”**

| What happens | Tokens billed by Groq? |
|---|---|
| Flutter loads insights.json | **No** |
| Classify moisture/pH/NPK with `bands` on the phone | **No** |
| Score latest 8-in-1 soil + forecast vs `crops` min/max | **No** |
| Compute phase / days-to-harvest from `plantings` | **No** |
| Reuse saved `ai_assessments` | **No** |
| Edge Function refuses `no_reading` | **No** |
| HTTP `messages` Groq receives | **Yes** |

### What actually saves Groq tokens
1. **Do not call the model** when cache/regen says skip, or when there is no soil data.
2. **Send a slice**, not the file. Drop `meta`, `sensor_valid`, `regen`, `cache_hours`, and other pages. Analytics does not get `irrigation`.
3. **Send classified facts**, not essays.
4. **Compact history** — daily buckets, not every 15-minute row.
5. **Crops catalog match is local**.

## Prompt versions
| Job | `prompt_version` | Model |
|---|---|---|
| Home / Analytics / Crops care | `insights_v4` | Groq via Edge Function |
| Crops catalog | no model | local vs `crops` |

Bump `prompt_version` in the JSON when rules/bands change so saved assessments regen.

## Home tips (v4)
Home returns up to **three** recommendations: Condition (`soil_management`), Water today (`irrigation`), Nutrients (`nutrient` when an active crop is in the payload). Voice is **caring neighbor, simple English** (see `voice` in insights.json).

**Per-crop bands:** when an active planting exists, Flutter classifies moisture/temp/pH/EC/salinity against `crops` baselines + phase overlays ([`CROP_RANGES.md`](CROP_RANGES.md)). No planting → universal `insights.json` + global extreme floors. NPK stays universal **low-only**. Critical bands (`critical_dry`, `critical_high`, …) require urgent wording, `priority: high`, and tinted tip cards. Notifications escalate the same way.

Smarter regen compares a local **story fingerprint** (bands including `temp_band` + rain advice + crop/phase + crop range token), stamped as `SGFP:…` on `ai_assessments.overview` — a new `soil_reading_id` alone does not call Groq when the story is unchanged.
## Next (locked)
Keep slices short for tokens. After edits: bump `prompt_version` + `npx supabase functions deploy soilgood-insights`.

## Storage
`ai_assessments.kind` is `home` \| `analytics` \| `crops`. Crops rows also set `planting_id`. SQL: [`supabase_crops_home_ai.sql`](supabase_crops_home_ai.sql).
