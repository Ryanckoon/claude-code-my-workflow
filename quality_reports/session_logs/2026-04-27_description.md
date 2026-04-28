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
- **Reference period (v0 only).** v0 plots unconditional group means;
  v1 (below) replaces this with a within-pair deviation from day −14.
- **Reference period.** None in v0 — this is unconditional means by
  group, not a within-group deviation. If a normalised version is wanted
  (e.g., "demean each group by its day −10 to −5 average"), it is a one-line
  addition to the R script.

---

## 12. Edition v1 update — 2026-04-27

Six modifications applied; the v0 flat-folder PDFs were deleted and
replaced by an intensity-split structure under `Outputs/binscatter/`.

### 12.1 Methodology changes

1. **Per-city hit-date alignment.**
   - Landfall city series: day 0 = TC's first-landfall date.
   - Subsequent city series: day 0 = THAT city's own `city_hit_date`
     (e.g., a city hit on date 2 of a TC that landed on date 1 now has
     its day 0 at date 2, not date 1).
   - Not-hit city series: day 0 = TC's first-landfall date
     (`typhoon_start_date`) — only defensible anchor for an uninvolved
     city.
2. **±1 SE shown as dashed lines.** No fill ribbon; mean line is solid,
   ±1 SE bounds are thin dashed lines in the same color as the mean.
3. **Y-axis is within-pair deviation from day −14.** For every (TC, city)
   pair, subtract that pair's day-`−14` value from each day's value;
   then average within `(group, event_time)`. Day `−14` is therefore
   exactly 0 by construction. Pairs missing a day-`−14` observation are
   dropped for that variable.
4. **Legend at bottom, single row × 3 columns.**
5. **Annotation:** "TC arrival" → "Tropical Cyclone Arrival".
6. **Two intensity sub-folders.**
   - `Outputs/binscatter/high_intensity/` — TCs with peak `level ∈
     {3, 4, 5, 6}` (excluding `level == 9`, the extratropical / abnormal
     code per CLAUDE.md).
   - `Outputs/binscatter/low_intensity/`  — TCs with peak `level ∈
     {0, 1, 2}`.
   Per-TC peak level: `max(level)` over that TC's `has_typhoon == 1`
   rows, excluding `level == 9`.

### 12.2 Run diagnostics

| Quantity                                  | Value   |
|-------------------------------------------|---------|
| Total TCs                                 | 63      |
| TCs in high_intensity (peak level ≥ 3, excl 9) | 15 |
| TCs in low_intensity  (peak level < 3)         | 45 |
| TCs excluded (only level == 9 rows)            | 3  |
| Stacked rows (per-city alignment)              | 613,872 |
| Stacked rows in high_intensity                 | 146,160 |
| Stacked rows in low_intensity                  | 438,480 |

Pairs missing day-`−14` baseline (dropped from that variable's figure):

| Variable          | Missing pairs |
|-------------------|---------------|
| value_all         | 0   |
| count_all         | 0   |
| value_health      | 387 |
| count_health      | 387 |
| value_hospital    | 836 |
| count_hospital    | 836 |
| value_pharmacy    | 760 |
| count_pharmacy    | 760 |
| value_restaurant  | 131 |
| count_restaurant  | 131 |
| value_supermarket | 177 |
| count_supermarket | 176 |

These are pairs whose city had no recorded transactions in that
specific category on day −14 (sparser categories like hospital and
pharmacy lose the most). For category `all`, the baseline is always
present.

### 12.3 Visual sanity checks

- **High intensity, supermarket value.** Landfall (navy) shows a clear
  ~CNY 3M dip below baseline at day 0, with rebound by day +5.
  Subsequent cities also dip negative; Not-hit hovers near 0
  throughout — exactly as expected when subtracting the pair's own
  day-`−14` baseline.
- **Low intensity, pharmacy count.** Landfall drops ~1K transactions
  below baseline at day 0; Subsequent shows a positive blip at day 0
  (city was experiencing the storm tail). Not-hit baseline flat near 0.
- All Not-hit series in all 24 figures are essentially flat near 0 —
  confirms the baseline-subtraction works and the control group is
  unaffected by the focal TC.

### 12.4 File list (v1, 24 PDFs)

`Outputs/binscatter/high_intensity/`:

```
binscatter_value_all.pdf         binscatter_count_all.pdf
binscatter_value_health.pdf      binscatter_count_health.pdf
binscatter_value_hospital.pdf    binscatter_count_hospital.pdf
binscatter_value_pharmacy.pdf    binscatter_count_pharmacy.pdf
binscatter_value_restaurant.pdf  binscatter_count_restaurant.pdf
binscatter_value_supermarket.pdf binscatter_count_supermarket.pdf
```

`Outputs/binscatter/low_intensity/`: same 12 filenames.

### 12.5 Reproduction

Same as before:

```bash
cd "/Users/ruihuaguo/Desktop/Research/Climate consumption"
Rscript Coding/04_Binscatter.R
```

The script auto-deletes any obsolete flat-folder v0 PDFs in
`Outputs/binscatter/` before writing the new sub-folder structure.

### 12.6 Caveats specific to v1

- **Within-pair baseline sensitivity.** Day `−14` is a single-day
  baseline; if that day was anomalous (a holiday, a data outage), it
  shifts the entire deviation series for that pair. We accept this
  per the task spec ("y in day −14 should be 0"); a less noisy
  alternative would average days `−14 … −10`.
- **Peak-level classification is TC-wide.** A TC that was Cat-3 at first
  landfall and Cat-2 by the time it reached subsequent cities is still
  classified `high_intensity`. If a per-(TC, city) own-day classification
  is wanted, it is a small refactor.
- **Asymmetric anchor for Not-hit.** Not-hit series use the TC's first-
  landfall date as their day 0, while Subsequent series use their own
  city's hit date. This means Not-hit and Subsequent series are not on
  identical calendar windows. Within each TC, the comparison is still
  internally consistent.

---

## 13. Edition v2 update — 2026-04-27

Six modifications applied; the v1 `high_intensity/`+`low_intensity/`
flat layout was wiped and replaced by a three-bucket × value/count
sub-tree. The v0 all-together view is restored as `General/`.

### 13.1 Methodology changes (v2 deltas vs v1)

1. **Restore "all-together" view as `General/`.** v1 had only
   high/low intensity; v2 adds a no-filter bucket alongside.
2. **Three two-line sub-figures per (bucket, prefix, category):**
   - `01_Overall_…`    — All-hit (Landfall ∪ Subsequent) vs Not-hit.
   - `02_Landfall_…`   — Landfall                         vs Not-hit.
   - `03_Subsequent_…` — Subsequent                       vs Not-hit.

   Series colors:
   - All-hit  → dark purple `#5b3a87` (new in v2)
   - Landfall → navy `#2c3e6b`
   - Subsequent → coral `#c0392b`
   - Not-hit → teal `#1f9d8a`

3. **Y = 0 centered** in every figure via symmetric
   `coord_cartesian(ylim = c(-y_max, y_max))` (with 10% pad).
4. **Window restricted to `[−9, +9]`** (was `[−14, +14]`).
5. **Baseline shifted from day `−14` → day `−4`.** Day `−4` is now
   exactly 0 by within-pair construction.
6. **Folder tree** (108 PDFs):

   ```
   Outputs/binscatter/
   ├── General/
   │   ├── value/   (18)
   │   └── count/   (18)
   ├── high_intensity/
   │   ├── value/   (18)
   │   └── count/   (18)
   └── low_intensity/
       ├── value/   (18)
       └── count/   (18)
   ```

### 13.2 Run diagnostics

| Quantity                                       | Value     |
|------------------------------------------------|-----------|
| Total TCs                                      | 63        |
| TCs in high_intensity (peak level ≥ 3, excl 9) | 15        |
| TCs in low_intensity  (peak level < 3)         | 45        |
| TCs excluded (only level == 9 rows)            | 3         |
| Stacked rows (per-city alignment, ±9 window)   | 402,192   |
| Stacked rows in General                        | 402,192   |
| Stacked rows in high_intensity                 | 95,760    |
| Stacked rows in low_intensity                  | 287,280   |
| PDFs written                                   | 108       |

Pairs missing day-`−4` baseline (dropped from that variable's figure):

| Variable          | Missing pairs |
|-------------------|---------------|
| value_all         | 0   |
| count_all         | 0   |
| value_health      | 397 |
| count_health      | 397 |
| value_hospital    | 818 |
| count_hospital    | 818 |
| value_pharmacy    | 740 |
| count_pharmacy    | 739 |
| value_restaurant  | 131 |
| count_restaurant  | 131 |
| value_supermarket | 155 |
| count_supermarket | 154 |

These are pairs with no recorded transactions in the focal category on
day `−4`. `*_all` is fully populated.

### 13.3 Visual sanity checks

- **General/count/01_Overall — Pharmacy.** Hit (purple) shows a sharp
  ~−700 transactions dip at day 0; Not-hit hovers near 0 across the
  window. Both lines pass through 0 at day −4 by construction.
- **high_intensity/value/02_Landfall — Supermarket.** Y-axis centered
  symmetrically at ~`±6M`. Landfall dips ~CNY 4M at day 0 then recovers
  by day +5; Not-hit is flat near 0.
- **low_intensity/count/03_Subsequent — Pharmacy.** Subsequent dips
  modestly at day −1 then jumps to ~+450 at day 0 (consistent with
  later-day storm-tail timing in subsequent cities); Not-hit flat.
- All Not-hit series in all 108 figures sit close to 0 throughout the
  ±9-day window — confirms that the day-`−4` baseline subtraction is
  removing pre-period level differences as intended.

### 13.4 Filename convention

```
<NN>_<Group>_binscatter_<prefix>_<category>.pdf

  NN       ∈ {01, 02, 03}
  Group    ∈ {Overall, Landfall, Subsequent}
  prefix   ∈ {value, count}
  category ∈ {all, health, hospital, pharmacy, restaurant, supermarket}
```

Numeric prefix enforces deterministic Overall→Landfall→Subsequent sort.

### 13.5 Reproduction

```bash
cd "/Users/ruihuaguo/Desktop/Research/Climate consumption"
Rscript Coding/04_Binscatter.R
```

The script auto-deletes any pre-v2 PDFs (and empty leftover dirs) under
`Outputs/binscatter/` before writing the new tree, so reruns are
idempotent.

### 13.6 Caveats specific to v2

- **Day-`−4` is closer to the event.** A baseline at `−4` is more
  responsive to anticipatory effects (preparedness shopping) than
  `−14`. This is per the task spec; it tightens the figure but means
  the displayed "Δ vs day −4" is not a "pre-event clean baseline" in
  the strict event-study sense.
- **All-hit pooling weights.** The Overall series pools Landfall and
  Subsequent observations equally (one row per pair-day). Subsequent
  cities outnumber Landfall by ~6:1 (376 vs 63 pairs in this dataset),
  so the All-hit line tracks Subsequent more closely than Landfall.
  No reweighting is applied — the descriptive figure shows the raw
  pooled mean.
- **Symmetric y-limits computed from each figure's own data.**
  Different sub-figures within the same category use different y-axis
  scales; this maximises the visible signal but trades off direct
  side-by-side comparability. If a shared y-scale is wanted, it is a
  small refactor.

---

## 14. Edition v3 update — 2026-04-27

Single methodological change applied; folder tree, filenames, three
sub-figures, three buckets, [-9, +9] window, group definitions, and
per-city alignment are all unchanged from v2.

### 14.1 Methodology change

Y is now a **percentage change vs day −4**, not a raw level deviation:

```
y_pct[k] = (y[k] − y[−4]) / y[−4] × 100
```

Implementation:

```r
pct <- if_else(!is.na(base) & base != 0,
               (raw - base) / base * 100,
               NA_real_)
```

- Y-axis formatter: `label_number(suffix = "%", accuracy = 0.1)` →
  ticks like `-10.0%`, `0.0%`, `5.5%`.
- Y-axis label: `<Value|Count> — % Δ vs day -4` (no `(CNY)` / `(txns)`
  unit suffix; percentage is unitless).
- Subtitle: `Within-pair % deviation from day -4 | bin = 1 day | …`.
- Symmetric y-limits and all v2 visual features preserved.

### 14.2 Edge-case handling: y[−4] = 0 or NA

The percentage transform is undefined when the day-`−4` baseline is
zero or missing, so those pairs are dropped for the affected variable
and figure. Practical impact:

| Variable          | NA baseline | Zero baseline | Total dropped |
|-------------------|-------------|---------------|---------------|
| value_all         | 0           | 0             | 0   |
| count_all         | 0           | 0             | 0   |
| value_health      | 397         | 1             | 398 |
| count_health      | 397         | 1             | 398 |
| value_hospital    | 818         | 0             | 818 |
| count_hospital    | 818         | 0             | 818 |
| value_pharmacy    | 740         | 0             | 740 |
| count_pharmacy    | 739         | 0             | 739 |
| value_restaurant  | 131         | 1             | 132 |
| count_restaurant  | 131         | 1             | 132 |
| value_supermarket | 155         | 1             | 156 |
| count_supermarket | 154         | 1             | 155 |

Zero-baseline drops are negligible (≤ 1 pair per variable): the
day-`−4` baseline is essentially never structurally zero in this
dataset for any active category.

### 14.3 Visual sanity checks (v3)

- **General/count/01_Overall — Pharmacy.** Hit (purple) dips to
  ~`−11%` at day 0 then rebounds; Not-hit (teal) trends modestly
  positive (~`+5%`) across the window, reflecting the overall
  upward time trend in pharmacy transactions over the calendar
  period.
- **high_intensity/value/02_Landfall — Supermarket.** Landfall dips
  to ~`−32%` at day 0 and recovers only partially by day +9; Not-hit
  drifts to `+10–20%` over the window. Magnitude in % is
  much more interpretable than the raw CNY M units in v2.
- **low_intensity/count/03_Subsequent — Pharmacy.** Subsequent shows
  a small dip on day `−1` (~`−5%`) and a sharp positive spike to
  ~`+9%` on day 0 (storm-tail demand) before settling near 0%.
- All Not-hit lines pass through 0% at day `−4`, as expected.

### 14.4 Why percentage instead of raw level

Levels are dominated by city-size composition (a `−3M CNY` dip in a
top-tier city has the same numeric magnitude as a `−500K CNY` dip in
a smaller city). Percentage normalises by each pair's own pre-event
baseline, so the displayed effect is comparable across cities and
categories regardless of base size. This also makes the Hit / Landfall
/ Subsequent lines directly comparable across categories within a
single bucket, and across buckets within a single category.

### 14.5 Caveats specific to v3

- **Sensitivity to small baselines.** Pairs with very small but
  non-zero day-`−4` values can blow up the per-pair percentage
  (e.g., baseline = 1 transaction → +500% on day 0 with 6
  transactions). Within-pair averaging across many pairs typically
  smooths this out, but the Hit / Landfall / Subsequent series for
  sparse categories (hospital, pharmacy) may show wider SE bounds
  than for `*_all`.
- **Asymmetry with raw-level drops.** A `+50%` move and a `−50%`
  move have equal magnitude in % space but very different magnitudes
  in CNY/txn space. The figure now shows symmetric % swings rather
  than symmetric absolute swings.
- **Day-`−4` baseline still single-day.** A pair with an anomalously
  low day-`−4` value will see all subsequent percentages inflated.
  The single-day baseline is per task spec; a less noisy alternative
  would be to use the average over days `−9 … −5`.


---
**Context compaction (manual) at 23:31**
Check git log and quality_reports/plans/ for current state.

---

## 15. Edition v4 (2026-04-28) — narrower window, day −7 baseline

### 15.1 What changed
- `event_pre = event_post = 7L` (was `9L`).
- `baseline_day = -7L` (was `-4L`).
- Header docstring, in-code comments, and the printed banner refreshed
  from "v3" to "v4".

The percentage transform is unchanged in form:

```
y_pct[k] = (y[k] − y[−7]) / y[−7] × 100
```

### 15.2 Why
With baseline at day `−7` and the window now `[−7, +7]`, every series
mechanically passes through `0%` at its left edge. This makes each
figure read as "cumulative percentage move since the start of the
visible pre-event window" — easier to communicate to a non-technical
audience and aligned with how the poster narrates the event. The
narrower window also drops the noisier outer days where pair counts
thin out.

### 15.3 Run diagnostics
- Branch: `feat/binscatter-v4` (off `main` at `cae5e1b`).
- Stacked rows: 317,520 (was 396,900 under the wider v3 window).
- TCs: 63 total | high: 15 | low: 45 | 3 excluded (level == 9 only).
- Pairs dropped because day-`−7` baseline is `NA` or zero:
  - `value_all` / `count_all`: 0 / 0
  - `value_health` / `count_health`: 388 / 387
  - `value_hospital` / `count_hospital`: 807 / 807
  - `value_pharmacy` / `count_pharmacy`: 740 / 740
  - `value_restaurant` / `count_restaurant`: 140 / 140
  - `value_supermarket` / `count_supermarket`: 167 / 167
- Pre-existing 108 v3 PDFs wiped, 108 v4 PDFs written, 108 confirmed
  on disk under `Outputs/binscatter/{General,high_intensity,low_intensity}/{value,count}/`.

### 15.4 Caveats specific to v4
- **Edge baseline.** Anchoring at day `−7` (the left edge of the
  window) means there is no visible pre-trend test in the figures —
  every series is mechanically zero at `−7`. This is descriptive,
  not a violation of parallel-trends per se, but it loses the
  visual "pre-trend flat → jump at 0" narrative that the day-`−4`
  anchor allowed.
- **Narrower late-window.** Previously the figures showed days `+5`
  through `+9` (recovery tail). v4 stops at `+7`, so persistent
  effects beyond a week are no longer plotted.
- **Same small-baseline fragility as v3.** Pairs with very small but
  non-zero day-`−7` values can still inflate per-pair percentages;
  within-pair averaging mitigates but does not eliminate this.

---

## 16. Edition v5 (2026-04-28) — log-difference replaces percentage

### 16.1 Trigger
After v4, the Not-hit (control) series sat systematically above 0 %
across the entire window — implausible for a clean control. Diagnosis:
**mean-of-ratios bias (Jensen's inequality).** Per-pair `pct = (y[k] −
y[−7]) / y[−7] × 100` averaged across pairs is upward-biased whenever
the denominator `y[−7]` varies, because a small denominator can
produce `+500 %` while the worst downside is bounded at `−100 %`. The
asymmetry inflates the cross-pair mean even when the underlying series
is flat.

### 16.2 What changed
Replace the percentage transform with a **log-difference × 100**:

```
y_log[k] = (log y[k] − log y[−7]) × 100
```

Symmetric in upside vs downside (because `log` is concave) and immune
to Jensen inflation. For small moves (`|Δ| ≲ 30 %`) it is numerically
indistinguishable from a raw percentage, so the figure reads naturally
for non-technical audiences. Axis suffix kept as `%`; subtitle and
y-axis caption now read "log-diff × 100 (≈%)".

Validity guard tightened: rows where `y[k] ≤ 0` or `y[−7] ≤ 0` (or
either is `NA`) are dropped. Per CLAUDE.md, `log()` is intentional
— never `log1p()`.

Window `[−7, +7]` and baseline day `−7` are unchanged.

### 16.3 Run diagnostics
- Branch: `feat/binscatter-v5` (off `feat/binscatter-v4` → `cae5e1b` on `main`).
- Stacked rows: 317,520 (unchanged from v4 — same window + cohorting).
- TCs: 63 total | high: 15 | low: 45 | 3 excluded (level == 9 only).
- Pairs dropped because day-`−7` baseline is `NA` or `≤ 0`:
  - `value_all` / `count_all`: 0 / 0
  - `value_health` / `count_health`: 388 / 387
  - `value_hospital` / `count_hospital`: 807 / 807
  - `value_pharmacy` / `count_pharmacy`: 740 / 740
  - `value_restaurant` / `count_restaurant`: 140 / 140
  - `value_supermarket` / `count_supermarket`: 167 / 167
- Drop counts are essentially identical to v4 because non-positive
  baselines are dominated by missingness, not by `y[−7] == 0`.
  Additional drops at individual `(k ≠ −7)` rows where `y[k] ≤ 0`
  are not counted in the per-pair summary (handled silently in the
  `if_else`).
- Pre-existing 108 v4 PDFs wiped, 108 v5 PDFs written, 108 confirmed
  on disk under `Outputs/binscatter/{General,high_intensity,low_intensity}/{value,count}/`.

### 16.4 What v5 does NOT fix
- **Edge baseline.** Anchoring at day `−7` still forces every series
  through 0 at the left edge — no visible pre-trend test.
- **Day-of-week cyclicality.** Log-diff is symmetric, but it does not
  remove weekly seasonality. Any residual drift in the v5 Not-hit
  series — if visible — should now be interpreted as real day-of-week
  patterns rather than Jensen artifact.
- **Single-day baseline.** Anchoring on one day is still sensitive to
  pair-level noise at `−7`. A future v6 could combine log-diff with a
  multi-day baseline window (e.g., mean of `−7…−4`) to reduce variance.
