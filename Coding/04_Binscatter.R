## -----------------------------------------------------------------------------
##   Climate and Consumption
##   04_Binscatter.R
##
##   Descriptive binscatters of daily city consumption around tropical cyclones.
##   For each consumption category (in `value` and `count`), produce ONE figure
##   with three series of within-day means by city group:
##     1. Landfall    — cities hit on the TC's first-landfall day
##     2. Subsequent  — cities hit on a later day of the same TC
##     3. Not-hit     — cities never hit by that TC (clean controls for that TC)
##
##   x-axis : event_time = Date − typhoon_start_date  (days), restricted to
##            [-14, +14].
##   y-axis : raw level (NOT log) — yuan for value_*, transactions for count_*.
##
##   Last Modified: 2026-04-27
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
out_dir   <- file.path(root, "Outputs", "binscatter")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- Categories & prefixes ---------------------------------------------------
categories <- c("all", "health", "hospital", "pharmacy",
                "restaurant", "supermarket")
prefixes   <- c("value", "count")

# --- Event window (days relative to TC's first landfall date) ----------------
event_pre  <- 14L
event_post <- 14L

# --- Visual identity (extends 03b palette for a 3rd series) ------------------
COL_LANDFALL   <- "#2c3e6b"   # navy blue
COL_SUBSEQUENT <- "#c0392b"   # coral red
COL_NOTHIT     <- "#1f9d8a"   # teal green
COL_ARRIVAL    <- "#c0392b"   # vertical line at t = 0

group_levels <- c("Landfall", "Subsequent", "Not-hit")
group_colors <- c(Landfall   = COL_LANDFALL,
                  Subsequent = COL_SUBSEQUENT,
                  `Not-hit`  = COL_NOTHIT)

# Transparent-background theme: NA fills on panel + plot rectangles so PDFs
# overlay cleanly on coloured slide backgrounds.
base_theme <- theme_bw(base_size = 12) +
  theme(
    panel.background   = element_rect(fill = NA, colour = NA),
    plot.background    = element_rect(fill = NA, colour = NA),
    legend.background  = element_rect(fill = alpha("white", 0.7),
                                      colour = "grey70"),
    legend.key         = element_rect(fill = NA, colour = NA),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "grey85", linetype = "dashed"),
    plot.title         = element_text(face = "bold", size = 13, hjust = 0.5),
    plot.subtitle      = element_text(size = 9, hjust = 0.5, colour = "grey40"),
    legend.position    = c(0.99, 0.99),
    legend.justification = c(1, 1),
    legend.title       = element_blank()
  )

# =============================================================================
# 1. Load data and clean negative values
# =============================================================================

cat("Loading data...\n")
df_raw <- read_dta(file.path(data_path, "daily_spending_merged.dta")) %>%
  mutate(Date = as.Date(Date))

# Replace negative consumption values with NA (data-quality convention).
y_cols <- as.vector(outer(prefixes, categories, paste, sep = "_"))
y_cols <- intersect(y_cols, names(df_raw))

df_raw <- df_raw %>%
  mutate(across(all_of(y_cols), ~ if_else(.x < 0, NA_real_, .x)))

# =============================================================================
# 2. Identify per-TC city groups
#       For each TC id:
#         t0          = typhoon_start_date (first landfall date by that TC)
#         landfall    = treated cities with city_hit_date == t0
#         subsequent  = treated cities with city_hit_date >  t0
#         not-hit     = all other cities (never hit by this TC)
# =============================================================================

cat("Building per-TC city groups...\n")

# (TC, city) → city_hit_date (earliest day with has_typhoon==1 for that pair)
treated_pairs <- df_raw %>%
  filter(has_typhoon == 1) %>%
  group_by(id, NBS_code) %>%
  summarise(city_hit_date = min(Date), .groups = "drop")

# (TC) → typhoon_start_date (first landfall day across all hit cities)
tc_starts <- treated_pairs %>%
  group_by(id) %>%
  summarise(typhoon_start_date = min(city_hit_date), .groups = "drop")

treated_pairs <- treated_pairs %>%
  left_join(tc_starts, by = "id") %>%
  mutate(group = if_else(city_hit_date == typhoon_start_date,
                         "Landfall", "Subsequent"))

all_cities  <- sort(unique(df_raw$NBS_code))
n_tc        <- nrow(tc_starts)
cat(sprintf("  TCs: %d | Treated (TC,city) pairs: %d\n",
            n_tc, nrow(treated_pairs)))

# =============================================================================
# 3. Build long-format event-time panel for each (TC, city, group)
#
#    For every TC, three city sets (Landfall / Subsequent / Not-hit) are
#    paired with the TC's [t0 - event_pre, t0 + event_post] window. The result
#    is a long table: one row per (TC, city, day) with tc_event_time and group.
# =============================================================================

cat("Stacking per-TC event-time panels...\n")

build_one_tc <- function(tc_id, t0) {

  hit_pairs    <- treated_pairs %>% filter(id == tc_id)
  hit_cities   <- hit_pairs$NBS_code
  ctrl_cities  <- setdiff(all_cities, hit_cities)
  win_start    <- t0 - event_pre
  win_end      <- t0 + event_post

  panel <- df_raw %>%
    filter(Date >= win_start, Date <= win_end) %>%
    select(NBS_code, Date, all_of(y_cols)) %>%
    mutate(tc_event_time = as.integer(Date - t0),
           tc_id         = tc_id)

  treated_panel <- panel %>%
    filter(NBS_code %in% hit_cities) %>%
    left_join(hit_pairs %>% select(NBS_code, group), by = "NBS_code")

  control_panel <- panel %>%
    filter(NBS_code %in% ctrl_cities) %>%
    mutate(group = "Not-hit")

  bind_rows(treated_panel, control_panel)
}

stacked <- map2_dfr(tc_starts$id, tc_starts$typhoon_start_date, build_one_tc)

cat(sprintf("  Stacked rows: %s | Groups: %s\n",
            format(nrow(stacked), big.mark = ","),
            paste(unique(stacked$group), collapse = ", ")))

# =============================================================================
# 4. Bin-mean collapse: mean and SE of y by (group, tc_event_time)
# =============================================================================

bin_summary <- function(varname) {
  stacked %>%
    select(group, tc_event_time, y = all_of(varname)) %>%
    filter(!is.na(y)) %>%
    group_by(group, tc_event_time) %>%
    summarise(mean_y = mean(y),
              se_y   = sd(y) / sqrt(n()),
              n      = n(),
              .groups = "drop") %>%
    mutate(group = factor(group, levels = group_levels))
}

# =============================================================================
# 5. Plot one binscatter per (prefix, category)
# =============================================================================

pretty_prefix <- function(p) if (p == "value") "Value (CNY)" else "Count (txns)"

# Compact axis labels: 1.2M, 350K, etc.
y_label_fmt <- label_number(scale_cut = cut_short_scale(), accuracy = 0.1)

plot_binscatter <- function(varname, prefix, category) {

  bs <- bin_summary(varname)
  if (nrow(bs) == 0) return(invisible(NULL))

  pretty_cat <- str_to_title(str_replace_all(category, "_", " "))
  title      <- sprintf("Binscatter: %s (%s)", pretty_cat, prefix)
  subtitle   <- "Mean ± 1 SE | bin = 1 day | raw level"

  p <- ggplot(bs, aes(x = tc_event_time, y = mean_y,
                      colour = group, fill = group, group = group)) +
    geom_vline(xintercept = 0, colour = COL_ARRIVAL, linetype = "dashed",
               linewidth = 0.6, alpha = 0.7) +
    annotate("text", x = 0.4, y = Inf, label = "TC arrival",
             colour = COL_ARRIVAL, size = 3, fontface = "bold",
             hjust = 0, vjust = 1.5) +
    geom_ribbon(aes(ymin = mean_y - se_y, ymax = mean_y + se_y),
                alpha = 0.15, colour = NA) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2.2) +
    scale_colour_manual(values = group_colors, drop = FALSE) +
    scale_fill_manual(values = group_colors, drop = FALSE) +
    scale_x_continuous(breaks = seq(-event_pre, event_post, 2),
                       limits = c(-event_pre, event_post)) +
    scale_y_continuous(labels = y_label_fmt,
                       breaks = pretty_breaks(n = 6)) +
    labs(title    = title,
         subtitle = subtitle,
         x        = "Days Relative to Tropical Cyclone Landfall",
         y        = pretty_prefix(prefix)) +
    base_theme

  fname <- sprintf("binscatter_%s_%s.pdf", prefix, category)
  ggsave(file.path(out_dir, fname),
         plot = p, width = 8, height = 5, device = cairo_pdf,
         bg = "transparent")
  cat(sprintf("  Saved: %s\n", fname))
}

cat("\nGenerating binscatter figures...\n")
for (pp in prefixes) {
  for (cc in categories) {
    var_name <- paste(pp, cc, sep = "_")
    if (!(var_name %in% names(stacked))) next
    plot_binscatter(var_name, pp, cc)
  }
}

cat(sprintf("\nDone. %d PDFs written to %s\n",
            length(list.files(out_dir, pattern = "\\.pdf$")),
            out_dir))
