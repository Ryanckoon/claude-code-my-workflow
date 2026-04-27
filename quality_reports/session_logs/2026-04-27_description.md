---
title: Binscatter description of daily city consumption around tropical cyclones
date: 2026-04-27
author: Ruihua GUO (with Claude)
status: COMPLETED
---

# Session Log — 2026-04-27 — Binscatter description

## 1. Goal

Build a descriptive picture of daily city consumption in the days around
tropical cyclone (TC) landfall, for each consumption category and for both
the value (CNY) and count (transactions) measures. Produce one binscatter
figure per category in which three series — Landfall, Subsequent, and
Not-hit cities — are overlaid on the same axes.

## 2. What is a binscatter (and how it is implemented here)

A binscatter groups observations into bins on the x-axis and plots the
within-bin mean of y. Because our x-axis is integer days `−14, −13, …, +14`
relative to the TC's first landfall date, the bin width is 1 day. The
implementation collapses the (TC × city × day) panel to:

```
mean_y(group, tc_event_time) = mean of y over (TC, city, day) cells in bin
se_y                          = sd / sqrt(n)
```

A connecting line and points are drawn for each group, with a thin ribbon
showing ±1 SE of the bin mean.

## 3. Group definitions (per TC `id`)

Let `t0 = typhoon_start_date` = the TC's first-landfall day across all
cities it ever hits.

| Group       | Definition                                                 |
|-------------|------------------------------------------------------------|
| Landfall    | cities with `has_typhoon == 1` for this TC and `city_hit_date == t0` |
| Subsequent  | cities with `has_typhoon == 1` for this TC and `city_hit_date > t0`  |
| Not-hit     | cities never marked `has_typhoon == 1` for this TC                   |

This matches the Landfall/Subsequent split used in `03_StackedDiD.R` and
`03b_CategoryEventStudy.R`. The Not-hit set is the same "clean control"
set as the stacked DiD (cities untouched by the focal TC throughout its
window).

## 4. Stacking rule

For every TC, we keep daily observations for all three city groups within
`[t0 − 14, t0 + 14]` and label `tc_event_time = Date − t0`. A city that
appears in multiple TCs contributes once per TC (this is intentional —
each TC is its own descriptive sub-experiment, mirroring the stacked DiD
construction).

Resulting stack: **63 TCs**, **439 (TC, city) treated pairs**, **613,872
stacked rows**, three groups (Landfall, Subsequent, Not-hit).

## 5. Y-axis convention

Per task specification: **raw level**, not log. Negative `value_*` /
`count_*` entries are scrubbed to `NA` before averaging (data-quality
convention). Y-axis tick labels use SI abbreviations (1.2M, 350K) so the
raw magnitudes remain readable.

## 6. Style

- Title: `Binscatter: <Category> (<value|count>)`.
- Subtitle: `Mean ± 1 SE | bin = 1 day | raw level`.
- Three high-contrast colors:
  - Landfall — navy blue `#2c3e6b`
  - Subsequent — coral red `#c0392b`
  - Not-hit — teal green `#1f9d8a`
- Vertical dashed red line at day 0 with annotation "TC arrival".
- Legend placed inside the panel (top-right), as requested.
- Background fully transparent — both `panel.background` and
  `plot.background` use `fill = NA`, and `ggsave(..., bg = "transparent",
  device = cairo_pdf)`. Verified empirically: corner pixels have alpha=0.

## 7. Visual sanity checks

- **value, supermarket** — Landfall mean dips by roughly CNY 5M on day 0
  (≈ 10% of pre-event level), rebounds within 1–2 days, and stays slightly
  elevated post-event. Subsequent and Not-hit lines are flat by
  construction. Pattern is consistent with consumers staying home during
  landfall and resuming shortly after.
- **count, pharmacy** — Landfall transactions drop from ~4.8K to ~3.5K on
  day 0; Subsequent cities show a delayed dip on day +1. Not-hit baseline
  is flat. Pattern is consistent with TC-arrival mobility constraints.
- All other figures show flat Not-hit baselines (good — confirms the
  control group is unaffected) and TC-coincident dips of varying magnitude
  in Landfall/Subsequent series.

## 8. Files written

R script (single source of truth):

- `Coding/04_Binscatter.R`

Figures (12 total, transparent-background PDFs, 8" × 5"):

| Prefix | Category    | File                                         |
|--------|-------------|----------------------------------------------|
| value  | all         | Outputs/binscatter/binscatter_value_all.pdf         |
| value  | health      | Outputs/binscatter/binscatter_value_health.pdf      |
| value  | hospital    | Outputs/binscatter/binscatter_value_hospital.pdf    |
| value  | pharmacy    | Outputs/binscatter/binscatter_value_pharmacy.pdf    |
| value  | restaurant  | Outputs/binscatter/binscatter_value_restaurant.pdf  |
| value  | supermarket | Outputs/binscatter/binscatter_value_supermarket.pdf |
| count  | all         | Outputs/binscatter/binscatter_count_all.pdf         |
| count  | health      | Outputs/binscatter/binscatter_count_health.pdf      |
| count  | hospital    | Outputs/binscatter/binscatter_count_hospital.pdf    |
| count  | pharmacy    | Outputs/binscatter/binscatter_count_pharmacy.pdf    |
| count  | restaurant  | Outputs/binscatter/binscatter_count_restaurant.pdf  |
| count  | supermarket | Outputs/binscatter/binscatter_count_supermarket.pdf |

## 9. Repo hygiene

`.gitignore` updated to exclude `Data/` (rule: `Data/`). The R script
itself is committable; anyone with the `.dta` file in `Data/` can run
`Rscript Coding/04_Binscatter.R` to reproduce all 12 figures.

## 10. How to reproduce

```bash
cd "/Users/ruihuaguo/Desktop/Research/Climate consumption"
Rscript Coding/04_Binscatter.R
```

Required R packages: `haven`, `dplyr`, `tidyr`, `stringr`, `purrr`,
`ggplot2`, `scales`. PDF device: `cairo_pdf` (ships with base R on macOS).

## 11. Caveats and notes

- **Composition, not causation.** The level differences between Landfall,
  Subsequent, and Not-hit lines reflect city composition (which cities
  experience TCs vs. which don't — coastal vs. inland) on top of any
  TC effect. The descriptive figure shows three separate baselines plus
  a shared event-time pattern. For causal effects, see the stacked DiD
  results in `Outputs/{value,count}/`.
- **Bin = 1 day.** Because x is already integer-valued in `[−14, +14]`,
  no further binning is needed; the binscatter is a per-day group mean.
- **±1 SE ribbon, not ±1.96 SE.** The figure is descriptive, not
  inferential; the ribbon conveys precision of the bin mean, not a
  formal CI. The stacked-DiD event studies use 95% CIs.
- **Reference period.** None — this is unconditional means by group, not
  a within-group deviation. If a normalised version is wanted (e.g.,
  "demean each group by its day −10 to −5 average"), it is a one-line
  addition to the R script.
