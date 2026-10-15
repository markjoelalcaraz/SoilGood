# SoilGood — System flowchart (Mermaid)

Medium detail: enough for thesis / defense talk-through, not every cache/edge case.

**View:** paste into [mermaid.live](https://mermaid.live), or open this file with a Mermaid preview in Cursor/VS Code.

Print PDF / Draw.io (more detail): [`SYSTEM_FLOWCHART.pdf`](SYSTEM_FLOWCHART.pdf) · [`SYSTEM_FLOWCHART.drawio`](SYSTEM_FLOWCHART.drawio)

---

## 1. System overview

Who talks to whom (hardware → cloud → app → AI/weather).

```mermaid
flowchart LR
  subgraph Lab
    ADM[Admin provision / flash]
  end

  subgraph Device
    ESP[ESP32 + 8-in-1]
  end

  subgraph Supabase
    DB[(Postgres + RLS)]
    RT[Realtime]
    EF[Edge Function<br/>soilgood-insights]
  end

  subgraph App
    SHELL[Farmer app shell]
  end

  subgraph APIs
    OM[Open-Meteo]
    GQ[Groq]
  end

  ADM -->|claim_code + secrets| ESP
  ADM --> DB
  ESP -->|ingest ~15 min| DB
  DB --> RT
  RT --> SHELL
  SHELL --> DB
  SHELL --> OM
  SHELL -->|JWT| EF
  EF --> GQ
  EF --> DB
```

---

## 2. Farmer journey → daily use

Setup once, then the four tabs (+ alerts + farmer log).

```mermaid
flowchart TD
  START([Open SoilGood]) --> AUTH{Logged in?}
  AUTH -->|No| LOGIN[Login / Signup]
  LOGIN --> ONB
  AUTH -->|Yes| ONB{Onboarding done?}

  ONB -->|No| STEPS[Profile → Farm pin → Claim device]
  STEPS --> SHELL
  ONB -->|Yes| SHELL[App shell]

  SHELL --> HOME[Home: live soil + forecast + today AI]
  SHELL --> AN[Analytics: history + period AI]
  SHELL --> CR[Crops: match → plant → water plan]
  SHELL --> PR[Profile]
  SHELL --> ALERT[Alerts: classify soil → farm_notifications]

  CR --> LOG[Mark watered → farm_actions]
  LOG --> AN
```

---

## 3. Operational loop (with farmer logs)

The closed loop while the app is in use — sensing, advice, logging, learning.

```mermaid
flowchart TD
  R[New soil_reading] --> RT[Realtime to app]
  RT --> HOME[Home shows 8-in-1]
  RT --> N[Notification engine<br/>local bands, 0 Groq]
  N --> FN[(farm_notifications)]

  HOME --> W[Open-Meteo weather]
  HOME --> AIH{Home AI cache OK?}
  AIH -->|No| EF[soilgood-insights → Groq]
  AIH -->|Yes| TIPS[Show saved tips]
  EF --> SAVE[(ai_assessments)]
  SAVE --> TIPS

  RT --> CR{Active planting?}
  CR -->|No| MATCH[Catalog match → plant]
  CR -->|Yes| PLAN[7-day water plan<br/>rules local]
  MATCH --> PLAN
  PLAN --> MARK[Mark watered Today]
  MARK --> FA[(farm_actions)]
  PLAN --> CARE[Crops care AI]
  CARE --> EF

  FA --> AN[Analytics]
  R --> AN
  W --> AN
  AN --> AIA{Period AI cache OK?}
  AIA -->|No| EF
  AIA -->|Yes| TREND[Trends + kalagayan + watering count]
```

---

## How to read this (1 minute)

| Piece | Meaning |
|-------|---------|
| **Home** | *Now* — latest soil, forecast, today tips |
| **Crops** | Match crop, water week, **Mark watered** log |
| **Analytics** | *Over time* — history + uses `farm_actions` counts |
| **Alerts** | Local bands → `farm_notifications` (not Groq) |
| **Groq** | Only when AI cache / fingerprint says regenerate |

Caption idea: *Figure X. SoilGood system flowchart: device ingest, farmer app tabs, AI insights, and irrigation action logs.*
