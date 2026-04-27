---
title: Binscatter description of daily city consumption around tropical cyclones
date: 2026-04-27
status: APPROVED
author: Ruihua GUO (with Claude)
---

# Plan: Binscatter description

## Goal
Produce one binscatter figure per consumption category (in `value` and `count`),
each containing three group-mean lines (Landfall / Subsequent / Not-hit) on
event time −14 … +14 days relative to each TC's first landfall date.

## What is a binscatter (in this context)
A binscatter groups observations into bins on the x-axis and plots
within-bin means of y. Because our x is integer days `−14…+14`, the bin
equals the day. Implementation: for each (group, event_day, category)
compute the within-group mean of the raw `value_*` or `count_*` and connect
with a line + markers; a thin ribbon shows ±1 SE of the bin mean.

## Construction logic (per TC `id`)
For each TC `id`, define `t0 = typhoon_start_date` (date of first landfall by
that TC).
- **Landfall cities:** hit by this TC, with `city_hit_date == t0`.
- **Subsequent cities:** hit by this TC, with `city_hit_date > t0`.
- **Not-hit cities:** never hit by this TC (clean controls for that TC).

For each (TC, city) pair, stack daily observations with
`event_time = Date − t0` in `[−14, +14]`. Then collapse:
mean and SE of `y` by `(group, event_time)`, pooled across (TC, city) pairs.

## Categories & prefixes
- prefixes: `value`, `count`.
- categories: `all`, `health`, `hospital`, `pharmacy`, `restaurant`, `supermarket`.
- ⇒ 12 figures.

## Y-axis convention
- Raw levels (NOT log). Negative raw values → NA before averaging.
- Y-axis formatted with SI abbreviations (1.2M, 350K) for readability.

## Style
- Title: `Binscatter: <Category> (<value|count>)`, subtitle:
  `Mean ± 1 SE | bin = 1 day | raw level`.
- Three colors: Landfall = navy `#2c3e6b`, Subsequent = coral `#c0392b`,
  Not-hit = teal `#1f9d8a`.
- Vertical dashed red line at day 0 with annotation
  "Tropical Cyclone Arrival".
- Legend inside the panel (top-right).
- Transparent background (panel + plot), `bg = "transparent"` in ggsave.

## Deliverables
1. `Coding/04_Binscatter.R` — self-contained R script (set.seed, paths
   absolute via `root` constant, `dir.create(recursive = TRUE)`,
   `bg = "transparent"`).
2. `Outputs/binscatter/binscatter_<prefix>_<category>.pdf` (12 files).
3. `quality_reports/session_logs/2026-04-27_description.md` — process,
   methodology, results, file list.

## Repo hygiene
- Add `Data/` to `.gitignore` so the .dta file is never accidentally
  committed; the R script remains git-sourceable.

## Verification
- `Rscript Coding/04_Binscatter.R` runs end-to-end with no errors.
- `Outputs/binscatter/` contains 12 PDFs.
- Spot-check one figure: 3 colored series, legend inside, transparent
  background, x ∈ [−14, +14].
