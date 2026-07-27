# SoilGood — Architecture

## Goals
Keep the app organized, farmer-friendly, and aligned with docs so we do not get lost later.

## Separation of concerns
- **Logic / functions** live apart from **UI / design** (e.g. services, repositories, controllers vs pages/widgets).
- Screens call functions and display results — they should not own business logic.
- Prefer **reusable widgets** for buttons, cards, inputs, skeletons, and shared chrome.

## App shell (persistent chrome)
- Use an **app shell**: bottom/top nav (and similar chrome) stays **persistent**.
- Only the **content area** swaps or shows loading/skeletons — not a full-page rebuild that remounts the nav.
- Flutter patterns: shell `Scaffold` + `IndexedStack` / nested navigator / `go_router` `ShellRoute`.

## Navigation transitions
| Navigation type | Animation |
|---|---|
| **Shell tab switch** (bottom nav) | Instant content swap via `IndexedStack` — **no** slide |
| **Pushed page** (not under shell, e.g. Crop Plan, Signup, Profile edit) | **Slide in from the right**; pop slides back to the right |
| **Replacement** (e.g. onboarding → shell) | Same slide-from-right helper for consistency |

Helper: `lib/shared/navigation/app_page_routes.dart` → `AppPageRoutes.slideFromRight(...)`.
Do **not** use plain `MaterialPageRoute` for these pushed screens.

## Page UX conventions
| Concern | Rule |
|---|---|
| **Cache** | Pages should use cached last-known data so something useful appears immediately when possible. |
| **Skeleton loaders** | Show page structure immediately while loading (not a blank screen or spinner-only). |
| **Optimistic UI** | For actions that should normally succeed (save, toggle, mark action), update UI first; on failure **rollback** and show a **visible** error (no silent fake success). |
| **Realtime** | Prefer streams / listeners (e.g. Supabase Realtime) so inserts/updates appear dynamically. “Subscription” = code listener, not a paid plan. |

## Folder conventions
- Feature UI in a **dedicated folder** (e.g. `lib/features/monitoring/`), not scattered files.
- Shared widgets in a shared place (e.g. `lib/shared/widgets/`).
- Logic in services/repos (e.g. `lib/services/`, `lib/data/`).

## Documentation required per page
Before or while building a page/feature, create `docs/pages/<page-name>.md` from `_TEMPLATE.md`:
- Purpose / goal of the page
- User flow, data sources, UI states
- Optimistic actions
- Functions table
- **Page-logic Mermaid flowchart** (inputs → decisions → outputs the farmer sees)

## Design source of truth
See [UI_THEME.md](UI_THEME.md). Do not invent a conflicting palette or typography.
