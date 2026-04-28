## -----------------------------------------------------------------------------
##   Climate and Consumption
##   04_Binscatter.R   (Edition v4 — 2026-04-28)
##
##   Descriptive binscatters of daily city consumption around tropical cyclones.
##   Three buckets × six categories × two prefixes × three sub-figures = 108 PDFs.
##
##   Buckets:
##     General        — all 63 TCs combined (no intensity filter).
##     high_intensity — TCs with peak level ∈ {3,4,5,6} (excluding level == 9).
##     low_intensity  — TCs with peak level ∈ {0,1,2}.
##
##   Per (bucket, prefix, category), three sub-figures (each two-line):
##     01_Overall_…    — All-hit (Landfall ∪ Subsequent) vs Not-hit.
##     02_Landfall_…   — Landfall                         vs Not-hit.
##     03_Subsequent_… — Subsequent                       vs Not-hit.
##
##   Reference day-0 alignment (per series):
##     Landfall   → TC's first-landfall date.
##     Subsequent → THAT city's own first-hit date.
##     Not-hit    → TC's first-landfall date (only defensible anchor).
##     All-hit    → as for its underlying Landfall/Subsequent rows.
##
##   x-axis : event_time ∈ [-7, +7].   (v4)
##   y-axis : within-pair % change from day -7 baseline (v4):
##              y_pct[k] = (y[k] − y[−7]) / y[−7] × 100, then averaged
##              within (group, event_time). Pairs with y[−7] == 0 or NA
##              are dropped for that variable (percentage undefined).
##              Y-axis centred symmetrically so y = 0% sits in the middle.
##
##   ±1 SE shown as thin dashed lines (no fill).
##   Legend at bottom in a single row.
## -----------------------------------------------------------------------------

# =============================================================================
# 0. Setup
# =============================================================================

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(ggplot2)
  library(scales)
})

set.seed(20260427)

root      <- "/Users/ruihuaguo/Desktop/Research/Climate consumption"
data_path <- file.path(root, "Data")
out_root  <- file.path(root, "Outputs", "binscatter")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

# --- Categories & prefixes ---------------------------------------------------
categories <- c("all", "health", "hospital", "pharmacy",
                "restaurant", "supermarket")
prefixes   <- c("value", "count")

# --- Event window & baseline -------------------------------------------------
# v4: window narrowed to [-7, +7] and baseline shifted to day -7.
event_pre    <- 7L
event_post   <- 7L
baseline_day <- -7L

# --- Visual identity ---------------------------------------------------------
COL_HIT        <- "#5b3a87"   # dark purple — All-hit (Overall figure)
COL_LANDFALL   <- "#2c3e6b"   # navy blue   — Landfall
COL_SUBSEQUENT <- "#c0392b"   # coral red   — Subsequent
COL_NOTHIT     <- "#1f9d8a"   # teal green  — Not-hit (always present)
COL_ARRIVAL    <- "#c0392b"   # vertical line at t = 0

group_colors <- c(`Hit`        = COL_HIT,
                  `Landfall`   = COL_LANDFALL,
                  `Subsequent` = COL_SUBSEQUENT,
                  `Not-hit`    = COL_NOTHIT)

base_theme <- theme_bw(base_size = 12) +
  theme(
    panel.background   = element_rect(fill = NA, colour = NA),
    plot.background    = element_rect(fill = NA, colour = NA),
    legend.background  = element_rect(fill = NA, colour = NA),
    legend.key         = element_rect(fill = NA, colour = NA),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "grey85", linetype = "dashed"),
    plot.title         = element_text(face = "bold", size = 13, hjust = 0.5),
    plot.subtitle      = element_text(size = 9, hjust = 0.5, colour = "grey40"),
    legend.position    = "bottom",
    legend.title       = element_blank()
  )

# =============================================================================
# 1. Load data and clean negative values
# =============================================================================

cat("Loading data...\n")
df_raw <- read_dta(file.path(data_path, "daily_spending_merged.dta")) %>%
  mutate(Date = as.Date(Date))

y_cols <- as.vector(outer(prefixes, categories, paste, sep = "_"))
y_cols <- intersect(y_cols, names(df_raw))

df_raw <- df_raw %>%
  mutate(across(all_of(y_cols), ~ if_else(.x < 0, NA_real_, .x)))

# =============================================================================
# 2. Per-TC city groups + per-TC peak intensity classification
# =============================================================================

cat("Building per-TC city groups...\n")

treated_pairs <- df_raw %>%
  filter(has_typhoon == 1) %>%
  group_by(id, NBS_code) %>%
  summarise(city_hit_date = min(Date), .groups = "drop")

tc_starts <- treated_pairs %>%
  group_by(id) %>%
  summarise(typhoon_start_date = min(city_hit_date), .groups = "drop")

treated_pairs <- treated_pairs %>%
  left_join(tc_starts, by = "id") %>%
  mutate(group = if_else(city_hit_date == typhoon_start_date,
                         "Landfall", "Subsequent"))

tc_levels <- df_raw %>%
  filter(has_typhoon == 1, !is.na(level), level != 9) %>%
  group_by(id) %>%
  summarise(peak_level = max(level, na.rm = TRUE), .groups = "drop")

tc_meta <- tc_starts %>%
  left_join(tc_levels, by = "id") %>%
  mutate(intensity = case_when(
    is.na(peak_level)    ~ NA_character_,
    peak_level >= 3      ~ "high_intensity",
    peak_level <  3      ~ "low_intensity"
  ))

n_excluded_only9 <- sum(is.na(tc_meta$intensity))
cat(sprintf(
  "  TCs total: %d | high: %d | low: %d | excluded (level==9 only): %d\n",
  nrow(tc_meta),
  sum(tc_meta$intensity == "high_intensity", na.rm = TRUE),
  sum(tc_meta$intensity == "low_intensity",  na.rm = TRUE),
  n_excluded_only9))

all_cities <- sort(unique(df_raw$NBS_code))

# =============================================================================
# 3. Stack per-TC event-time panels (per-city alignment)
# =============================================================================

cat("Stacking per-TC event-time panels...\n")

build_one_tc <- function(tc_id, t0) {

  hit_pairs   <- treated_pairs %>% filter(id == tc_id)
  hit_cities  <- hit_pairs$NBS_code
  ctrl_cities <- setdiff(all_cities, hit_cities)

  treated_panel <- map_dfr(seq_len(nrow(hit_pairs)), function(i) {
    city  <- hit_pairs$NBS_code[i]
    grp   <- hit_pairs$group[i]
    t_ref <- hit_pairs$city_hit_date[i]
    df_raw %>%
      filter(NBS_code == city,
             Date >= t_ref - event_pre,
             Date <= t_ref + event_post) %>%
      select(NBS_code, Date, all_of(y_cols)) %>%
      mutate(tc_event_time = as.integer(Date - t_ref),
             tc_id         = tc_id,
             group         = grp,
             pair_id       = paste(tc_id, city, sep = "_"))
  })

  control_panel <- df_raw %>%
    filter(NBS_code %in% ctrl_cities,
           Date >= t0 - event_pre,
           Date <= t0 + event_post) %>%
    select(NBS_code, Date, all_of(y_cols)) %>%
    mutate(tc_event_time = as.integer(Date - t0),
           tc_id         = tc_id,
           group         = "Not-hit",
           pair_id       = paste(tc_id, NBS_code, sep = "_"))

  bind_rows(treated_panel, control_panel)
}

stacked <- map2_dfr(tc_starts$id, tc_starts$typhoon_start_date, build_one_tc)
stacked <- stacked %>%
  left_join(tc_meta %>% select(id, intensity), by = c("tc_id" = "id"))

cat(sprintf("  Stacked rows: %s | groups: %s\n",
            format(nrow(stacked), big.mark = ","),
            paste(unique(stacked$group), collapse = ", ")))

# =============================================================================
# 4. Within-pair deviation from baseline_day
# =============================================================================

cat(sprintf("Computing within-pair %% deviation from day %d baseline...\n",
            baseline_day))

baselines <- stacked %>%
  filter(tc_event_time == baseline_day) %>%
  select(pair_id, all_of(y_cols)) %>%
  rename_with(~ paste0(.x, "__base"), all_of(y_cols))

stacked <- stacked %>% left_join(baselines, by = "pair_id")

# v4: y_dev is a percentage change vs the new baseline (day -7).
#   y_dev[k] = (y[k] − y[baseline_day]) / y[baseline_day] × 100
# Pairs with y[baseline_day] == 0 or NA produce NA y_dev (dropped from figure).
for (vv in y_cols) {
  base_col <- paste0(vv, "__base")
  base     <- stacked[[base_col]]
  raw      <- stacked[[vv]]
  pct      <- if_else(!is.na(base) & base != 0,
                      (raw - base) / base * 100,
                      NA_real_)
  stacked[[paste0(vv, "__dev")]] <- pct
}

miss_na  <- sapply(y_cols, function(vv) sum(is.na(baselines[[paste0(vv, "__base")]])))
miss_zero <- sapply(y_cols, function(vv) {
  bb <- baselines[[paste0(vv, "__base")]]
  sum(!is.na(bb) & bb == 0)
})
cat(sprintf(
  "  Pairs dropped because day-%d baseline is NA or zero (v4 %% transform):\n",
  baseline_day))
print(data.frame(variable      = y_cols,
                 missing_NA    = miss_na,
                 zero_baseline = miss_zero,
                 dropped_total = miss_na + miss_zero,
                 row.names     = NULL))

# =============================================================================
# 5. Bin-mean collapse + plotting
# =============================================================================

# bin_summary :: tibble × char × (named char) -> tibble with display labels
# `series_map` maps internal group names → on-figure series labels.
# Keys present in `series_map` are kept; one Not-hit series is always
# included (mapped to "Not-hit").
bin_summary <- function(df, varname, series_map) {

  dev_col <- paste0(varname, "__dev")

  df %>%
    select(group, tc_event_time, y = all_of(dev_col)) %>%
    filter(!is.na(y), tc_event_time >= -event_pre,
           tc_event_time <= event_post) %>%
    mutate(series = series_map[group]) %>%
    filter(!is.na(series)) %>%
    group_by(series, tc_event_time) %>%
    summarise(mean_y = mean(y),
              se_y   = sd(y) / sqrt(n()),
              n      = n(),
              .groups = "drop")
}

pretty_prefix <- function(p) if (p == "value") "Value" else "Count"
# v4: y is a percentage; format axis with a "%" suffix (already in percent units).
y_label_fmt   <- label_number(suffix = "%", accuracy = 0.1)

# Series-map presets for each sub-figure
series_maps <- list(
  Overall    = c(Landfall = "Hit",        Subsequent = "Hit",
                 `Not-hit` = "Not-hit"),
  Landfall   = c(Landfall = "Landfall",   `Not-hit`  = "Not-hit"),
  Subsequent = c(Subsequent = "Subsequent", `Not-hit` = "Not-hit")
)
focal_colors <- c(Overall    = COL_HIT,
                  Landfall   = COL_LANDFALL,
                  Subsequent = COL_SUBSEQUENT)
fig_indices  <- c(Overall = "01", Landfall = "02", Subsequent = "03")
focal_labels <- c(Overall    = "All-hit vs Not-hit",
                  Landfall   = "Landfall vs Not-hit",
                  Subsequent = "Subsequent vs Not-hit")

plot_one <- function(df, varname, prefix, category,
                     focal, bucket_label, save_dir) {

  bs <- bin_summary(df, varname, series_maps[[focal]])
  if (nrow(bs) == 0) return(invisible(NULL))

  # Series factor ordering: focal first (drawn on top), Not-hit second.
  focal_series_name <- if (focal == "Overall") "Hit" else focal
  bs <- bs %>%
    mutate(series = factor(series,
                           levels = c(focal_series_name, "Not-hit")))

  pretty_cat <- str_to_title(str_replace_all(category, "_", " "))
  title <- sprintf("Binscatter: %s (%s) — %s — %s",
                   pretty_cat, prefix, focal_labels[[focal]], bucket_label)
  subtitle <- sprintf(
    "Within-pair %% deviation from day %d | bin = 1 day | Mean (solid) ±1 SE (dashed)",
    baseline_day)

  # Symmetric y-limits so y = 0 sits in the centre.
  y_extreme <- max(abs(c(bs$mean_y - bs$se_y, bs$mean_y + bs$se_y)),
                   na.rm = TRUE)
  if (!is.finite(y_extreme) || y_extreme == 0) y_extreme <- 1
  y_lim <- c(-y_extreme * 1.10, y_extreme * 1.10)

  pal <- c(setNames(focal_colors[[focal]], focal_series_name),
           `Not-hit` = COL_NOTHIT)

  p <- ggplot(bs, aes(x = tc_event_time, y = mean_y,
                      colour = series, group = series)) +
    geom_hline(yintercept = 0, colour = "grey60",
               linetype = "dotted", linewidth = 0.4) +
    geom_vline(xintercept = 0, colour = COL_ARRIVAL, linetype = "dashed",
               linewidth = 0.6, alpha = 0.7) +
    annotate("text", x = 0.4, y = Inf, label = "Tropical Cyclone Arrival",
             colour = COL_ARRIVAL, size = 3, fontface = "bold",
             hjust = 0, vjust = 1.5) +
    geom_line(aes(y = mean_y - se_y), linetype = "dashed",
              linewidth = 0.4, alpha = 0.7) +
    geom_line(aes(y = mean_y + se_y), linetype = "dashed",
              linewidth = 0.4, alpha = 0.7) +
    geom_line(linewidth = 0.85) +
    geom_point(size = 2.2) +
    scale_colour_manual(values = pal, drop = FALSE) +
    scale_x_continuous(breaks = seq(-event_pre, event_post, 1),
                       limits = c(-event_pre, event_post)) +
    scale_y_continuous(labels = y_label_fmt,
                       breaks = pretty_breaks(n = 6)) +
    coord_cartesian(ylim = y_lim) +
    guides(colour = guide_legend(nrow = 1)) +
    labs(title    = title,
         subtitle = subtitle,
         x        = "Days Relative to Tropical Cyclone Landfall",
         y        = sprintf("%s — %% Δ vs day %d",
                            pretty_prefix(prefix), baseline_day))  +
    base_theme

  fname <- sprintf("%s_%s_binscatter_%s_%s.pdf",
                   fig_indices[[focal]], focal, prefix, category)
  ggsave(file.path(save_dir, fname),
         plot = p, width = 8, height = 5, device = cairo_pdf,
         bg = "transparent")
  invisible(fname)
}

# =============================================================================
# 6. Loop over buckets × prefixes × categories × focal-groups
# =============================================================================

# Wipe any pre-existing v0/v1 PDFs under out_root before regenerating.
old_pdfs <- list.files(out_root, pattern = "\\.pdf$", recursive = TRUE,
                       full.names = TRUE)
if (length(old_pdfs) > 0) {
  cat(sprintf("Removing %d obsolete pre-v2 PDFs from %s...\n",
              length(old_pdfs), out_root))
  invisible(file.remove(old_pdfs))
}
# Drop empty leftover dirs (e.g., v1's high_intensity/ flat folder).
old_dirs <- list.dirs(out_root, recursive = TRUE, full.names = TRUE)
old_dirs <- setdiff(old_dirs, out_root)
for (d in rev(old_dirs)) {
  if (length(list.files(d, recursive = TRUE)) == 0) {
    unlink(d, recursive = TRUE)
  }
}

# Build bucket → (label, filter) configs.
buckets <- list(
  General        = list(label = "General (all TCs)",
                        keep  = function(df) df),
  high_intensity = list(label = "High Intensity (level ≥ 3)",
                        keep  = function(df) filter(df, intensity == "high_intensity")),
  low_intensity  = list(label = "Low Intensity (level < 3)",
                        keep  = function(df) filter(df, intensity == "low_intensity"))
)

n_written <- 0L
for (bk in names(buckets)) {
  cfg       <- buckets[[bk]]
  df_bucket <- cfg$keep(stacked)
  cat(sprintf("\n=== %s | rows: %s ===\n",
              cfg$label, format(nrow(df_bucket), big.mark = ",")))

  for (pp in prefixes) {
    save_dir <- file.path(out_root, bk, pp)
    dir.create(save_dir, recursive = TRUE, showWarnings = FALSE)

    for (cc in categories) {
      var_name <- paste(pp, cc, sep = "_")
      if (!(var_name %in% y_cols)) next

      for (focal in names(series_maps)) {
        fname <- plot_one(df_bucket, var_name, pp, cc,
                          focal, cfg$label, save_dir)
        if (!is.null(fname)) {
          n_written <- n_written + 1L
          cat(sprintf("  [%s/%s] %s\n", bk, pp, fname))
        }
      }
    }
  }
}

n_pdfs <- length(list.files(out_root, pattern = "\\.pdf$", recursive = TRUE))
cat(sprintf("\nDone. %d PDFs written; %d found on disk under %s\n",
            n_written, n_pdfs, out_root))
