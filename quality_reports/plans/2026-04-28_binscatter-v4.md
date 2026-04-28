# Plan: Binscatter — Edition v4

**Status:** APPROVED
**Date:** 2026-04-28
**Branch:** feat/binscatter-v4

---

## Objective

Update `Coding/04_Binscatter.R` so that:

1. The within-pair percentage transform anchors on **day −7** instead of day −4:

   ```
   y_pct[k] = (y[k] − y[−7]) / y[−7] × 100
   ```

   Pairs with `y[−7] == 0` or `NA` are dropped for that variable.

2. The event window narrows from **[−9, +9]** to **[−7, +7]**.

Everything else (bucket × prefix × category × focal-group structure, file naming,
transparent PDF style, symmetric y-axis, dashed ±1 SE lines, legend at bottom in
one row) stays exactly as in v3.

---

## Files to modify

| File | Change |
|------|--------|
| `Coding/04_Binscatter.R` | `event_pre = event_post = 7L`, `baseline_day = -7L`; refresh header docstring + a few inline comments and printed messages from "v3" → "v4". |
| `quality_reports/plans/2026-04-28_binscatter-v4.md` | This plan (new). |
| `quality_reports/session_logs/2026-04-27_description.md` | Append a v4 section with run diagnostics. |

No other files touched. No new figures folders — the existing
`Outputs/binscatter/{General,high_intensity,low_intensity}/{value,count}/`
directories are wiped at the top of the script and refilled with v4 PDFs.

---

## Verification

1. `Rscript Coding/04_Binscatter.R` runs to completion.
2. `find Outputs/binscatter -name '*.pdf' | wc -l` returns **108**.
3. Spot-check one PDF per bucket: x-axis ticks span −7…+7; series at
   `event_time == −7` is at 0 %; y-axis is symmetric about 0; subtitle and y-axis
   label both reference day −7.
4. Console log shows the v4 banner ("Pairs dropped because day-−7 baseline is NA
   or zero (v4 % transform):") and reasonable drop counts.

---

## Commit policy

Single commit on `feat/binscatter-v4`, staging only:

- `Coding/04_Binscatter.R`
- `quality_reports/plans/2026-04-28_binscatter-v4.md`
- `quality_reports/session_logs/2026-04-27_description.md`

Pre-existing dirty working-tree files (CLAUDE.md, template deletions, untracked
folders, etc.) are explicitly **not** part of this commit, matching the v0–v3
discipline.
