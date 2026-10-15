# Dev UX mocks (not production)

Isolated Flutter entry points for reviewing UI without AuthGate / Supabase / shell.

## Soil onboarding dropdowns

Proposed Step 3 (series first → texture fallback → Others **Look up** mock).
**Does not** save, call Groq, or continue to device claim.

```bash
flutter run -t lib/dev/main_soil_onboarding_ux_mock.dart
```

### Catalog source (important)

Dropdown options today come from **Dart enums** (`SoilTexture`, `SoilSeries`), not a
Supabase list table. DB only stores the farmer’s pick on `farms.soil_texture` /
`farms.soil_series` / `farms.soil_series_other` (CHECK constraints). Live onboarding
remains `soil_texture_onboarding_page.dart` until you ship this design.

Try Look up with names like `Bantog` (curated match) or `clayey field` (heuristic).
