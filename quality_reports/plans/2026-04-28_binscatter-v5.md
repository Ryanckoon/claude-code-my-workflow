# Plan: Binscatter — Edition v5

**Status:** APPROVED
**Date:** 2026-04-28
**Branch:** feat/binscatter-v5 (off `feat/binscatter-v4`)

---

## Why

In v4 the Not-hit (control) series sat systematically **above zero** at every
event_time. That was not a real treatment effect; it was the
**mean-of-ratios bias** introduced by the v3/v4 percentage transform:

```
pct[k] = (y[k] − y[−7]) / y[−7] × 100
```

When the denominator `y[−7]` is noisy and varies across pairs, the
cross-pair mean of `y[k]/y[−7]` is pulled above the ratio of means
(Jensen's inequality). A pair with an unusually small `y[−7]` can
produce a `+500 %` reading, while the same-magnitude downside is
bounded at `−100 %`. The asymmetry inflates the average even when the
underlying series is flat.

## What changes

Replace the percentage transform with a **log-difference × 100**:

```
y_log[k] = (log y[k] − log y[−7]) × 100
```

This is symmetric in upside vs downside and (because `log` is concave)
removes the Jensen inflation. For small moves it is numerically
indistinguishable from `(y[k]−y[−7])/y[−7] × 100`, so the figure
reads naturally for non-technical audiences. Axis label keeps the
"%" suffix; subtitle and y-axis caption clarify the underlying
transform.

Rows where either `y[k] ≤ 0` or `y[−7] ≤ 0` (or either is NA) are
dropped (log undefined). Per CLAUDE.md, use `log()`, never `log1p()`.

## Files modified

| File | Change |
|------|--------|
| `Coding/04_Binscatter.R` | Replace `(raw − base) / base * 100` with `(log(raw) − log(base)) * 100`; tighten the validity guard to `base > 0 & raw > 0`. Update header docstring + comments + subtitle + y-axis label from "v4 / % change" to "v5 / log-diff × 100". Console diagnostics report pairs dropped for `non-positive baseline`. |
| `quality_reports/plans/2026-04-28_binscatter-v5.md` | This plan (new). |
| `quality_reports/session_logs/2026-04-27_description.md` | Append §16 with v5 rationale and run diagnostics. |

Window (`[-7, +7]`) and baseline anchor (`-7`) are **unchanged** from v4.
Folder structure and 108-PDF count are unchanged.

## Verification

1. `Rscript Coding/04_Binscatter.R` runs to completion.
2. `find Outputs/binscatter -name '*.pdf' | wc -l` returns **108**.
3. The Not-hit series in `Outputs/binscatter/General/value/01_Overall_binscatter_value_all.pdf`
   should now hover near 0 % with no obvious upward drift across the
   window. (If it still drifts, that residual is real day-of-week
   cyclicality, not Jensen bias.)
4. Console log shows the new banner ("v5 log-diff") and per-variable
   counts of pairs dropped for `non-positive baseline`.

## Commit policy

Single commit on `feat/binscatter-v5`, staging only:

- `Coding/04_Binscatter.R`
- `quality_reports/plans/2026-04-28_binscatter-v5.md`
- `quality_reports/session_logs/2026-04-27_description.md`

Pre-existing dirty working-tree files are explicitly **not** part of
this commit.
