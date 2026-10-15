  # SoilGood — System Flowcharts

  Master process map of **what the product does today** (farmer app + ESP32 + Supabase + admin). Per-page detail lives under [`docs/pages/`](../pages/). Schema: [`DATA_MODEL.md`](DATA_MODEL.md). Backend: [`BACKEND.md`](BACKEND.md).

  **How to view:** paste any `mermaid` block into [mermaid.live](https://mermaid.live), GitHub, or VS Code Mermaid preview.

  ---

  ## 1. Big picture (all actors)

  ```mermaid
  flowchart LR
    subgraph Lab["Lab / Admin"]
      AD[Admin Web Devices]
      LF[Lab Flasher backup]
    end

    subgraph HW["Hardware"]
      ESP[ESP32 + 8-in-1]
    end

    subgraph Cloud["Supabase Free"]
      AUTH[Auth + RLS]
      PG[(Postgres)]
      RT[Realtime]
      EF[Edge Function soilgood-insights]
    end

    subgraph Ext["External free APIs"]
      OM[Open-Meteo]
      GQ[Groq gpt-oss-120b]
    end

    subgraph App["Flutter SoilGood"]
      FG[Farmer app shell]
      AG[Admin web chrome]
    end

    AD --> PG
    LF --> ESP
    AD -->|SGCFG USB| ESP
    ESP -->|ingest_soil_reading| PG
    PG --> RT
    RT --> FG
    FG --> AUTH
    FG --> PG
    FG --> OM
    FG -->|JWT invoke| EF
    EF --> GQ
    EF --> PG
    AG --> AUTH
    AG --> PG
  ```

  ---

  ## 2. End-to-end farmer journey

  ```mermaid
  flowchart TD
    START([Farmer opens SoilGood]) --> AUTH{Session?}
    AUTH -->|No| LOGIN[Login / Signup]
    LOGIN --> ONB{Onboarding complete?}
    AUTH -->|Yes| ONB
    ONB -->|Profile missing| P1[Save profiles]
    P1 --> P2
    ONB -->|Farm missing| P2[GPS + map pin → farms]
    P2 --> P3
    ONB -->|Device missing| P3[Type claim_code]
    P3 -->|Optional skip| SHELL
    P3 -->|Valid| CLAIM[RPC claim_device]
    CLAIM --> SHELL
    ONB -->|All done| SHELL[App shell IndexedStack]

    SHELL --> HOME[Home — now]
    SHELL --> AN[Analytics — over time]
    SHELL --> CR[Crops — match + plan]
    SHELL --> PR[Profile]
    SHELL --> BELL[Bell → Notifications inbox]
    SHELL --> ENG[Notification engine while shell open]
  ```

  ---

  ## 3. Auth & onboarding (detail)

  ```mermaid
  flowchart TD
    A[Open app] --> B{Logged in?}
    B -->|No| C[Login or Signup]
    C --> D[Supabase Auth]
    D --> E{Onboarding status}
    B -->|Yes| E

    E -->|Profile incomplete| F[Step 1: name + address → profiles]
    F --> G
    E -->|No farm| G[Step 2: GPS + Carto pin → farms lat/long]
    G --> H{Confirm location?}
    H -->|No| G
    H -->|Yes| I
    E -->|No device| I[Step 3: claim_code]
    I --> J{Valid unclaimed code?}
    J -->|No| K[Visible error — stay]
    J -->|Yes| L[claim_device → device.farm_id]
    J -->|Skip| M
    L --> M[Enter app shell]
    E -->|Complete| M
  ```

  ---

  ## 4. Lab → kit → claim → live soil

  ```mermaid
  flowchart TD
    A[Admin Chrome: Connect board Web Serial] --> B[admin_provision_device]
    B --> C[Unclaimed devices row + claim_code + ingest_token]
    C --> D[SGCFG over USB: WiFi + secrets]
    D -->|OK| E[admin_mark_device_flashed]
    D -->|Fail| F[Show claim + Retry flash]
    E --> G[Sticker claim_code on box]
    G --> H[Farmer onboarding types code]
    H --> I[RPC claim_device]
    I --> J[ESP32 ~15 min HTTPS]
    J --> K[RPC ingest_soil_reading]
    K --> L[(soil_readings + last_seen_at)]
    L --> M[Realtime broadcast]
    M --> N[Flutter Home + notification engine]
  ```

  ---

  ## 5. ESP32 data path (locked)

  ```mermaid
  flowchart LR
    S[8-in-1 sensors] --> E[ESP32]
    E -->|anon key + device_uid + ingest_token| R[POST /rpc/ingest_soil_reading]
    R --> V{Token valid + ranges OK?}
    V -->|No| X[Fail / validation_status]
    V -->|Yes| T[(soil_readings)]
    T --> U[Update devices.last_seen_at]
    T --> RT[Supabase Realtime]
    RT --> H[Home soil cards]
    RT --> N[NotificationClassifier]
  ```

  Never `service_role` on the device or in the Flutter APK.

  ---

  ## 6. App shell — what each tab owns

  ```mermaid
  flowchart TB
    SHELL[Persistent chrome: TopBar + BottomNav]

    SHELL --> H[Home]
    SHELL --> A[Analytics]
    SHELL --> C[Crops]
    SHELL --> P[Profile]

    H --> H1[Latest 8-in-1 only]
    H --> H2[Open-Meteo forecast strip]
    H --> H3[Groq Home AI: Condition / Water today / Nutrients / Crop care]
    H --> H4[Realtime soil + AI recheck]

    A --> A1[Period filters + daily buckets RPC]
    A --> A2[Trend chart + period weather]
    A --> A3[Mark watered logs]
    A --> A4[Groq Analytics AI for period_start/end]
    A --> A5[Tap day → DayReadingsPage]

    C --> C1[Catalog match Groq crops.match grounded facts]
    C --> C2[Active planting plan + phases]
    C --> C3[7-day water plan rules_v1]
    C --> C4[Mark watered → farm_actions]
    C --> C5[Groq crops.care phase chores]

    P --> P1[profiles + auth email]
    P --> P2[Edit / Sign out]
  ```

  ---

  ## 7. Home load / refresh / AI

  ```mermaid
  flowchart TD
    A[Open Home] --> B[Skeleton if no soil yet]
    B --> C[fetchLatest + watchLatest soil_readings]
    C --> D[Open-Meteo at farm pin]
    D --> E[Load ai_assessments kind=home]
    E --> F{Fingerprint / valid_until / prompt_version needs regen?}
    F -->|No| G[Show Condition Water Nutrients Crop care]
    F -->|Yes| H[Invoke soilgood-insights job=home]
    H --> I[Groq → save assessment + recommendations]
    I --> G

    G --> R[Realtime new soil_reading id]
    R --> C
    R --> E

    G --> P[Pull-to-refresh]
    P --> Q[Keep last-known on screen]
    Q --> C
  ```

  Closed app → **no** Groq. No reading → Edge Function returns `no_reading` (model not called).

  ---

  ## 8. Crops: match → plant → water week → care

  ```mermaid
  flowchart TD
    A[Open Crops] --> B[Load farm planting soil catalog weather]
    B --> C{Active planting?}
    C -->|No| D[8-in-1 + weather chips + AI ranked matches]
    D --> D1[Load kind=crops_match]
    D1 --> D2{Regen soil weather fingerprint?}
    D2 -->|No| D3[Show saved AI scores]
    D2 -->|Yes| D4[soilgood-insights job=crops.match]
    D4 --> D5[Save crops_match + recommendations]
    D5 --> D3
    D4 -->|Fail| D6[Local scoreCropMatches fallback]
    D3 --> E[Confirm Plant name today?]
    D6 --> E
    E -->|Yes| F[Insert plantings status=active]
    F --> G
    C -->|Yes| G[Crop plan UI]

    G --> H[Phases + day N of maturity]
    G --> I{Water plan fingerprint / day / expiry?}
    I -->|Reuse| J[Show irrigation_plan_slots]
    I -->|Rebuild| K[IrrigationPlanBuilder rules_v1]
    K --> J

    J --> L[Today: Mark watered]
    L --> M[farm_actions + completed_action_id]

    G --> N[Load kind=crops AI]
    N --> O{Regen?}
    O -->|No| P[Care insights]
    O -->|Yes| Q[soilgood-insights job=crops.care]
    Q --> P

    G --> R[Change crop → replaced]
    R --> D
  ```

  ---

  ## 9. Analytics period flow

  ```mermaid
  flowchart TD
    A[Open Analytics] --> B[Pick period + metric]
    B --> C[RPC analytics_soil_daily]
    C --> D{Enough history?}
    D -->|No| E[Empty / short-history message]
    D -->|Yes| F[Trend chart + avg/min/max]
    F --> G[Open-Meteo daily range same dates]
    F --> H[farm_actions irrigation in window]
    F --> I[Load ai_assessments kind=analytics for start+end]
    I --> J{Regen?}
    J -->|No| K[Kalagayan + action cards]
    J -->|Yes| L[soilgood-insights job=analytics]
    L --> K
    F --> M[Tap day]
    M --> N[DayReadingsPage slide-from-right]
  ```

  ---

  ## 10. AI pipeline (shared)

  ```mermaid
  flowchart TD
    APP[Flutter page] --> LOCAL[Classify bands via local insights.json]
    LOCAL --> CACHE{Saved assessment still valid?}
    CACHE -->|Yes| SHOW[Show saved tips — 0 Groq tokens]
    CACHE -->|No| INV[functions.invoke soilgood-insights + user JWT]
    INV --> EF[Edge Function]
    EF --> AUTH{getUser OK?}
    AUTH -->|No| E401[401]
    AUTH -->|Yes| DATA{Live soil / history present?}
    DATA -->|No| NR[400 no_reading — skip Groq]
    DATA -->|Yes| SLICE[Attach page slice of insights.json]
    SLICE --> GROQ[Groq openai/gpt-oss-120b]
    GROQ --> SAVE[(ai_assessments + ai_recommendations)]
    SAVE --> SHOW
  ```

  | Job | Who | Model? |
  |---|---|---|
  | `home` | Home today tips | Groq |
  | `analytics` | Selected date window | Groq |
  | `crops.match` | Catalog suitability scores | Groq (grounded local facts) |
  | `crops.care` | Phase chores | Groq |
  | Catalog match fallback | Crops list if Groq fails | **Local** |
  | Water week | `irrigation_rules_v1` | **Local rules** |
  | Notification bands | Shell engine | **Local** (`insights.json`) |

  ---

  ## 11. Notifications (engine + inbox)

  ```mermaid
  flowchart TD
    A[App shell opens] --> B[NotificationController.start]
    B --> C[Latest soil + optional rain probability]
    C --> D[Evaluate bands — 0 Groq]
    D --> E[Insert farm_notifications if new for Manila day]
    E --> F[Phase change check once per phase]
    F --> G[Bell unread badge + Home/Crops red dots]

    G --> H{Farmer action}
    H -->|Tap bell| I[NotificationsPage]
    H -->|Tap Home/Crops tab| J[markTabRead for that tab's types]
    I --> K[Unread first → mark read / Mark all]
  ```

  Alert types: `irrigation` · `nutrient_low` · `soil_alert` · `sensor_error` · `device_offline` · `phase_change`.

  ---

  ## 12. Data ownership (who writes what)

  ```mermaid
  flowchart TB
    subgraph Writers
      ESP32[ESP32] -->|ingest RPC| SR[(soil_readings)]
      FL[Flutter farmer] -->|Auth JWT + RLS| PR[(profiles farms plantings farm_actions)]
      FL -->|claim_device| DV[(devices.farm_id)]
      FL -->|Open-Meteo live| WX[UI weather — persist later]
      FL -->|insights invoke| AI[(ai_assessments / recommendations)]
      FL -->|local classify| FN[(farm_notifications)]
      FL -->|rules builder| IP[(irrigation_plans / slots)]
      ADM[Admin] -->|provision RPCs| DV2[(devices unclaimed)]
    end
  ```

  ---

  ## 13. Primary user flows (product summary)

  ```mermaid
  flowchart LR
    F1[1 Open Home] --> A1[Live soil + forecast → act today]
    F2[2 Open Analytics] --> A2[History + trends → plan from window]
    F3[3 Open Crops] --> A3[Match latest soil → plant → water week]
    F4[4 Shell open] --> A4[Alerts saved; inbox from bell]
  ```

  Home AI = **today**. Analytics AI = **selected window**. Crops care = **phase chores**. Do not duplicate the same tip copy across tabs.

  ---

  ## Related docs

  | Topic | Doc |
  |---|---|
  | Overview / goals | [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md) |
  | Feature list | [`FEATURES.md`](FEATURES.md) |
  | Shell / UX rules | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
  | Supabase / Groq / Open-Meteo | [`BACKEND.md`](BACKEND.md) |
  | Tables + ER | [`DATA_MODEL.md`](DATA_MODEL.md) |
  | AI rules | [`AI_INSIGHTS.md`](AI_INSIGHTS.md) |
  | Page flows | [`../pages/home.md`](../pages/home.md), [`crops.md`](../pages/crops.md), [`analytics.md`](../pages/analytics.md), [`onboarding.md`](../pages/onboarding.md), [`notifications.md`](../pages/notifications.md), [`admin_devices.md`](../pages/admin_devices.md) |
