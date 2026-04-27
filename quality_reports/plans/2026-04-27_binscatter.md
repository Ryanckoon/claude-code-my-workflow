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

---

## Edition v1 — APPROVED 2026-04-27

Six modifications to the original script:

1. **Per-city hit-date alignment.**
   - Landfall city series: day 0 = TC's first-landfall date.
   - Subsequent city series: day 0 = THAT city's own `city_hit_date`.
   - Not-hit city series: day 0 = TC's first-landfall date
     (`typhoon_start_date`) — the only defensible anchor for an
     uninvolved city.
2. **No SE fill.** Replace `geom_ribbon` with two thin dashed lines
   per series (`mean ± 1 SE`, same color, `linetype = "dashed"`).
3. **Y-axis = within-pair deviation from day −14.** For every (TC, city)
   pair, subtract that pair's day-`−14` value from each day's value;
   then average within `(group, event_time)`. Day `−14` is exactly 0 by
   construction. Pairs with NA at day `−14` are dropped (logged).
4. **Legend at bottom, 1 row × 3 cols.**
5. **Annotation:** "TC arrival" → "Tropical Cyclone Arrival".
6. **Split by TC intensity.** Two subfolders:
   - `Outputs/binscatter/high_intensity/` — TCs with peak `level ∈ {3,4,5,6}`
     (excluding `level == 9`).
   - `Outputs/binscatter/low_intensity/`  — TCs with peak `level ∈ {0,1,2}`.

   Per-TC peak level: `max(level)` across that TC's `has_typhoon == 1`
   rows, excluding `level == 9`. TCs with only `level == 9` rows are
   dropped from both folders (logged).

   Each subfolder contains the same 12-figure set.
   Total: **24 PDFs**.

The 12 obsolete flat PDFs in `Outputs/binscatter/` (from v0) are deleted
since they are superseded by the intensity-split versions.

---

## Edition v2 — APPROVED 2026-04-27

Six modifications to v1:

1. **Restore the all-together bucket as `General/`.** v1 split TCs into
   high/low intensity and removed the all-TCs view; v2 brings it back.
2. **Three two-line figures per (bucket, prefix, category):**
   - `01_Overall_…`     — All-hit cities (Landfall ∪ Subsequent) vs Not-hit.
   - `02_Landfall_…`    — Landfall cities vs Not-hit.
   - `03_Subsequent_…`  — Subsequent cities vs Not-hit.
   Numeric prefix enforces sort order. Series colors:
   - All-hit  → dark purple `#5b3a87` (new)
   - Landfall → navy `#2c3e6b`
   - Subsequent → coral `#c0392b`
   - Not-hit → teal `#1f9d8a`
3. **Y=0 centered** in every figure via symmetric
   `coord_cartesian(ylim = c(-y_max, y_max))`.
4. **Window restricted to [−9, +9].**
5. **Baseline shifts from day `−14` → day `−4`.** Within-pair deviation
   `y_dev[k] = y[k] − y[−4]`. Day `−4` is now exactly 0; pairs missing
   that observation are dropped for that variable.
6. **Folder tree:**

   ```
   Outputs/binscatter/
   ├── General/
   │   ├── value/    (18 PDFs: 6 categories × 3 sub-figures)
   │   └── count/    (18 PDFs)
   ├── high_intensity/
   │   ├── value/    (18 PDFs)
   │   └── count/    (18 PDFs)
   └── low_intensity/
       ├── value/    (18 PDFs)
       └── count/    (18 PDFs)
   ```

   Total: **108 PDFs**. The script deletes any pre-existing v0/v1 PDFs
   under `Outputs/binscatter/` before regenerating.
