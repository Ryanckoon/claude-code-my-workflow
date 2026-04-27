# CLAUDE.MD -- Academic Project Development with Claude Code

**Project:** Climate and Consumption — Typhoon Effect on City Spending
**Institution:** NUS Business School, Department of Real Estate
**Author:** Ruihua GUO
**Branch:** main

---

## Core Principles

- **Plan first** -- enter plan mode before non-trivial tasks; save plans to `quality_reports/plans/`
- **Verify after** -- run R scripts end-to-end and confirm outputs exist at the end of every task
- **Single source of truth** -- R scripts in `Coding/` are the sole artifacts; figures and tables in `Outputs/` are derived
- **Quality gates** -- nothing ships below 80/100
- **[LEARN] tags** -- when corrected, save `[LEARN:category] wrong → right` to MEMORY.md

---

## Folder Structure

```
Climate consumption/
├── CLAUDE.md                              # This file
├── .claude/                               # Rules, skills, agents, hooks
├── Coding/                                # R scripts (numbered pipeline stages)
│   ├── 01_Typhoon tract.R                 # Typhoon spatial processing
│   ├── 02_Data Analysis.do                # Stata data merge + exploration
│   └── 03_StackedDiD.R                    # Stacked DiD estimation
├── Data/                                  # Raw and processed data
│   ├── daily_spending_merged.dta          # Main panel (city × day, 2011–2018)
│   ├── typhoon_list.csv                   # Typhoon event list
│   ├── Typhoon/                           # Raw typhoon track files
│   └── 2021 PRC Boundary/                 # City shapefiles
├── Outputs/                               # All outputs (figures, tables)
|   |── value
│      ├── figures/                           # PDF/PNG plots
│      └── tables/                            # word tables
|   |── count
│      ├── figures/                           # PDF/PNG plots
│      └── tables/                            # word tables
|   |── VpT
│      ├── figures/                           # PDF/PNG plots
│      └── tables/                            # word tables
|   └── descriptive
│      ├── figures/                           # PDF/PNG plots
│      └── tables/                            # tables
├── Literature/                            # Related papers
├── Paper/                                 # Manuscript drafts
├── quality_reports/                       # Plans, session logs, merge reports
└── Working document/                      # Notes and drafts
```

**Naming convention:** `NN_Description.R` (e.g., `03_StackedDiD.R`)

**Data:** Primary merged panel is `Data/daily_spending_merged.dta`. Variables include `NBS_code` (city), `Date`, `has_typhoon` (0/1), `id` (typhoon id), `level` (intensity), and `value_*` spending columns from UnionPay.

---

## Commands

```bash
# Run R script
Rscript Coding/03_StackedDiD.R

# Or interactively in R
source("Coding/03_StackedDiD.R")
```

**Note:** All paths in R scripts use absolute paths (`/Users/ruihuaguo/Desktop/Research/Climate consumption/...`). Outputs go to `Outputs/{value,count,VpT}/{figures,tables}/` (main results) and `Outputs/descriptive/` (descriptive analysis).

---

## Quality Thresholds

| Score | Gate | Meaning |
|-------|------|---------|
| 80 | Commit | Good enough to save |
| 90 | PR | Ready to present |
| 95 | Excellence | Aspirational |

---

## Skills Quick Reference

| Command | What It Does |
|---------|-------------|
| `/data-analysis [file]` | End-to-end R data analysis workflow |
| `/commit [msg]` | Stage, commit, PR, merge |
| `/lit-review [topic]` | Literature search + synthesis |
| `/research-ideation [topic]` | Research questions + strategies |
| `/interview-me [topic]` | Interactive research interview |
| `/review-paper [file]` | Manuscript review |
| `/referee-report [file] [full\|mini]` | Read paper PDF, produce referee report |
| `/review-r [file]` | R code quality + reproducibility review |
| `/learn [skill-name]` | Extract discovery into persistent skill |
| `/context-status` | Show session health + context usage |
| `/deep-audit` | Repository-wide consistency audit |

---

## Analysis Pipeline

| Stage | Script | Status | Output |
|-------|--------|--------|--------|
| 0 | `00_DataDescription.R` | Complete | `Outputs/descriptive/` |
| 1 | `01_Typhoon tract.R` | Complete | `Data/city_daily_typhoon_full.dta` |
| 2 | `02_Data Analysis.do` | Complete | `Data/daily_spending_merged.dta` |
| 3 | `03_StackedDiD.R` | Complete | `Outputs/{value,count,VpT}/{figures,tables}/` |

---

## Econometric Design Summary

**Research question:** What is the causal effect of tropical cyclone shocks on city-level daily consumer spending?

**Data:** City × day panel, 2011–2018. 63 typhoon events. ~300 prefecture-level cities. UnionPay transaction data (value_* columns, count_* columns).

**Estimator:** Stacked DiD (Wing et al. methodology)
- Sub-experiments: each (city, typhoon_id) hit pair: separate to Landfall (citie hitted on first day of one typhoon) effects and subsequent effects (citie hitted on subsequent day of one typhoon)
- Event window: ±14 days (event_pre = event_post = 14)
- Clean controls: cities with no typhoon activity in [$t_0 − 14, t_0 + 14$]
- FEs: city × sub-experiment, prov × event_time × sub-experiment, city × day of week
- Clustering: city (NBS_code)
- Reference period: event_time = −4

**Key variables:**
- `NBS_code`: prefecture city code
- `Date`: calendar date
- `has_typhoon`: treatment indicator (0/1)
- `id`: typhoon event id (63 events)
- `level`: typhoon intensity (Beaufort scale; ≥8 = high intensity)
- `value_*`: spending value by category (log-transformed for analysis; use `log()`, never `log1p()`)
- `count_*`: spending count by category (log-transformed for analysis; use `log()`, never `log1p()`)
