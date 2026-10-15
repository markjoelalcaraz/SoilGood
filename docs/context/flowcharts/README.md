# SoilGood system flowchart images

Generated PNG renders of [../SYSTEM_FLOWCHART.md](../SYSTEM_FLOWCHART.md).

| # | File | Topic |
|---|---|---|
| 1 | [01-big-picture.png](01-big-picture.png) | Lab / ESP32 / Supabase / App / APIs |
| 2 | [02-farmer-journey.png](02-farmer-journey.png) | Open app → onboarding → shell |
| 3 | [03-auth-onboarding.png](03-auth-onboarding.png) | Login + profile/farm/device steps |
| 4 | [04-lab-claim-live.png](04-lab-claim-live.png) | Provision → claim → live soil |
| 5 | [05-esp32-data-path.png](05-esp32-data-path.png) | Ingest RPC → Realtime |
| 6 | [06-app-shell-tabs.png](06-app-shell-tabs.png) | Home / Analytics / Crops / Profile |
| 7 | [07-home-ai.png](07-home-ai.png) | Home load + AI regen |
| 8 | [08-crops-flow.png](08-crops-flow.png) | Match → plant → water week → care |
| 9 | [09-analytics.png](09-analytics.png) | Period history + AI |
| 10 | [10-ai-pipeline.png](10-ai-pipeline.png) | Groq Edge Function path |
| 11 | [11-notifications.png](11-notifications.png) | Alert engine + inbox |
| 12 | [12-data-writers.png](12-data-writers.png) | Who writes which tables |
| 13 | [13-primary-flows.png](13-primary-flows.png) | Four primary product flows |

Re-render (from repo root):

`powershell
Get-ChildItem docs/context/flowcharts/*.mmd | ForEach-Object {
  npx --yes @mermaid-js/mermaid-cli@11 -i .FullName -o "\.png" -b white -s 2
}
`
