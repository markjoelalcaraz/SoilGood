# Page: Crops

## Status
- [x] In progress (UI / navigation only)

## Purpose / goal
Show crop suitability matches from soil conditions and open a cultivation plan detail.

## Navigation
- Crops list → **View Plan** → `CropPlanPage` (push route).

## Data
Mock match scores and reasons. Later: compare readings vs `crops` reference table + plantings.

## Flowchart
```mermaid
flowchart TD
  A[Open Crops] --> B[Show soil snapshot chips]
  B --> C[Show match cards]
  C --> D[Tap View Plan]
  D --> E[Crop plan detail phases + tips]
```
