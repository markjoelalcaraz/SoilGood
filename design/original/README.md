# Original SoilGood UI

Snapshot of the **current live design**, taken before the family-theme migration.

This is the editorial look: `#4A7C59`, Literata + Nunito Sans, Home / Analytics / Crops / Profile. It is not the proposed mock in `docs/mocks/reinvent_ui/`.

## What is in here

Paths match the project, so a file here is the same file as in the app:

- `lib/core/theme/` — colors and theme
- `lib/shared/widgets/` — SoftCard, SectionHeader, and the other shared UI
- `lib/features/**/presentation/` — farmer, onboarding, auth, and admin screens
- `lib/features/shell/app_shell.dart` — bottom nav
- `docs/context/UI_THEME.md` — written theme
- `docs/mocks/irrigation_diary/` — HTML of the actual screens
- `web/index.html` — web shell

## How to revert

After a migration, copy this tree back over the project root (the `Elect4` folder). That restores these UI files only. It does not touch data, Supabase, or firmware.

Example from the project root:

```powershell
Copy-Item -Path "design\original\lib" -Destination "." -Recurse -Force
Copy-Item -Path "design\original\docs" -Destination "." -Recurse -Force
Copy-Item -Path "design\original\web\index.html" -Destination "web\index.html" -Force
```
