# Plan: Configure Workflow + Implement Stacked DiD for Climate-Consumption Project

**Status:** COMPLETED
**Date:** 2026-03-12
**Author:** Ruihua GUO

---

## Context

This project studies the causal effect of typhoon shocks on city-level daily consumption in China (2011–2018) using UnionPay transaction data. The Claude Code workflow was forked from a Beamer-presentation template; it needs to be reconfigured for an R econometrics analysis project. In parallel, we implement the Stacked DiD estimator (Callaway & Sant'Anna spirit, Wing et al. methodology) to produce publication-ready event-study estimates.

---

## Part 1: CLAUDE.md Configuration Update

**File to rewrite:** `CLAUDE.md`

**Changes required:**
- Header: update project name → "Climate and Consumption — Typhoon Effect on City Spending"
- Core principles: replace "Beamer .tex is sole artifact" → "R scripts + Outputs/ are the artifacts"
- Folder structure: replace Beamer tree with actual project tree (Coding/, Data/, Outputs/, etc.)
- Commands section: replace LaTeX compile commands → R/Rscript execution patterns
- Remove: Beamer Custom Environments section (irrelevant)
- Remove: Paper Summary Slide Structure section (irrelevant)
- Update: Skills Quick Reference — keep relevant skills (data-analysis, lit-review, research-ideation, review-paper, commit, learn, context-status, deep-audit), add `/data-analysis` as primary skill
- Update: Current Project State table → show analysis pipeline stages (Data, StackedDiD, Outputs)

---

## Part 2: Stacked DiD Implementation

### Econometric Design

**Setting:**
- Panel: city (NBS_code) × day (Date), 2011–2018
- Treatment: typhoon hit (has_typhoon == 1), identified by typhoon event id (63 events)
- Outcome: log(value_*) for all spending categories; use log() directly (never log1p)

**Stacking strategy (city-typhoon pairs):**
- Each sub-experiment = one (city, typhoon_id) pair
- t = 0 is city-specific first hit date for that typhoon (user's chosen design)
- Event window: ±14 days (kappa_pre = 14, kappa_post = 14)
- Clean controls per sub-experiment: cities with NO typhoon activity during [t₀ − 14, t₀ + 14] for that sub-experiment

**Weights:**
Within each sub-experiment, treated units get weight = 1. Control units get weight = (# treated in sub-exp) / (# controls in sub-exp).

**Regression:**
```r
feols(log_value_X ~ i(event_time, ref = -1) |
        city_subexp_fe + date_subexp_fe,
      weights = ~w,
      cluster = ~NBS_code,
      data = stacked)
```

### File: `Coding/03_StackedDiD.R`

Script sections:
1. Setup — packages: haven, tidyverse, fixest, modelsummary, ggplot2, patchwork
2. Load data — read `Data/daily_spending_merged.dta` via haven::read_dta()
3. Variable discovery — identify all value_* columns; create log() versions
4. Build sub-experiments — `build_one_subexp()` function
5. Stack — bind_rows() all sub-experiments
6. Compute weights — treated = 1; control = n_treated / n_controls
7. Estimate — feols() for each log outcome
8. Event-study plot — `plot_event_study()` → PDF per outcome
9. Summary table — modelsummary() → .tex and .html
10. Heterogeneity — high (level ≥ 8) vs. low (level < 8) intensity

---

## Part 3: User Memory

Save user profile to persistent memory:
- Researcher: NUS Business School, Real Estate, econometrics/climate-consumption
- Prefers: rigorous methods, publication-ready outputs, structured workflow
- Tools: R (primary), Stata (data prep), modelsummary for tables

---

## Verification Steps

1. Run `Coding/03_StackedDiD.R` end-to-end with no errors
2. Confirm stacked dataset has > 0 rows
3. Confirm feols converges for at least value_total
4. Confirm event study plot renders and saves to Outputs/figures/
5. Confirm table saves to Outputs/tables/
6. Pre-treatment coefficients are jointly insignificant (visual parallel trends check)

---

## File Checklist

| File | Action | Status |
|------|--------|--------|
| `CLAUDE.md` | Rewrite to match R analysis project | ✅ Done |
| `Coding/03_StackedDiD.R` | Create new | ✅ Done |
| `Outputs/figures/` | Create directory | ✅ Done |
| `Outputs/tables/` | Create directory | ✅ Done |
| `quality_reports/plans/2026-03-12_stacked-did-setup.md` | Save this plan | ✅ Done |
| `quality_reports/session_logs/2026-03-12_config-and-stacked-did.md` | Session log | ✅ Done |
| Memory files | Save user profile memory | ✅ Done |
