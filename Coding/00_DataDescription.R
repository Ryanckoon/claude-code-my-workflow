## -----------------------------------------------------------------------------
##   Climate and Consumption
##   00_DataDescription.R
##   Descriptive analysis: consumption data and tropical cyclone data
##   Inputs:  Data/daily_spending_merged.dta
##            Data/typhoon_list.csv
##            Data/typhoon_paths_lines.qs
##            Data/typhoon_points.qs
##   Outputs: Outputs/descriptive/figures/*.pdf
##            Outputs/descriptive/tables/*.xlsx  *.html
##   Last Modified: 2026-03-15
## -----------------------------------------------------------------------------

# =============================================================================
# 0. Setup
# =============================================================================

library(haven)
library(tidyverse)
library(ggplot2)
library(scales)
library(patchwork)
library(sf)
library(modelsummary)
library(gt)
library(writexl)
library(qs)

root      <- "/Users/ruihuaguo/Desktop/Research/Climate consumption"
data_path <- file.path(root, "Data")
out_fig   <- file.path(root, "Outputs", "descriptive", "figures")
out_tbl   <- file.path(root, "Outputs", "descriptive", "tables")

dir.create(out_fig, recursive = TRUE, showWarnings = FALSE)
dir.create(out_tbl, recursive = TRUE, showWarnings = FALSE)

# Project colour palette
COL_PRIMARY   <- "#2c3e6b"   # navy blue
COL_HIGHLIGHT <- "#c0392b"   # coral
COL_SECONDARY <- "#7f8c8d"   # grey

base_theme <- theme_bw(base_size = 11) +
  theme(
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.background   = element_rect(fill = "grey92"),
    plot.title         = element_text(face = "bold", size = 12),
    legend.position    = "bottom"
  )

# Spending categories (raw column suffix names)
categories <- c("all", "daily_nece", "restaurant", "supermarket",
                "entertainment", "health", "cash", "gas")

cat_labels <- c(
  all           = "All Spending",
  daily_nece    = "Daily Necessities",
  restaurant    = "Restaurant",
  supermarket   = "Supermarket",
  entertainment = "Entertainment",
  health        = "Health",
  cash          = "Cash Withdrawal",
  gas           = "Gas Station"
)

# Beaufort level labels (values: 0–6, 9)
level_labels <- c(
  "0" = "Tropical Depression (0)",
  "1" = "Tropical Storm (1)",
  "2" = "Severe Tropical Storm (2)",
  "3" = "Typhoon (3)",
  "4" = "Severe Typhoon (4)",
  "5" = "Super Typhoon (5)",
  "6" = "Extreme (6)",
  "9" = "Temperate Cyclone (9)"
)

# =============================================================================
# 1. Load Data
# =============================================================================

message("Loading data...")

df <- read_dta(file.path(data_path, "daily_spending_merged.dta")) |>
  mutate(
    Date     = as.Date(Date),
    year     = as.integer(yyyy),
    month    = as.integer(mm),
    prov_code = as.integer(prov_code)
  )

typhoon_list  <- read_csv(file.path(data_path, "typhoon_list.csv"),
                           show_col_types = FALSE) |>
  mutate(date = as.Date(date))

# Spatial data (may not load on all machines — wrapped in tryCatch)
spatial_ok <- tryCatch({
  tc_lines  <- qread(file.path(data_path, "typhoon_paths_lines.qs"))
  tc_points <- qread(file.path(data_path, "typhoon_points.qs"))
  TRUE
}, error = function(e) {
  message("Spatial data not available  -  skipping track map.")
  FALSE
})

message(sprintf("Main panel: %s rows, %s cities, %s to %s",
                format(nrow(df), big.mark = ","),
                length(unique(df$NBS_code)),
                min(df$Date), max(df$Date)))

# =============================================================================
# 2. Consumption Data Analysis
# =============================================================================

message("Section 2: Consumption analysis...")

# --- 2.1 Summary Statistics Table -------------------------------------------

make_summary_row <- function(col, df) {
  x <- df[[col]]
  x <- x[!is.na(x) & x > 0]   # restrict to positive values for log-readability
  data.frame(
    column   = col,
    N        = length(x),
    mean     = mean(x),
    sd       = sd(x),
    p10      = quantile(x, 0.10),
    median   = quantile(x, 0.50),
    p90      = quantile(x, 0.90)
  )
}

val_cols <- paste0("value_", categories)
cnt_cols <- paste0("count_", categories)

ss_value <- map_dfr(val_cols, make_summary_row, df = df) |>
  mutate(
    category = rep(cat_labels[categories], 1),
    type     = "Value (CNY)"
  )

ss_count <- map_dfr(cnt_cols, make_summary_row, df = df) |>
  mutate(
    category = rep(cat_labels[categories], 1),
    type     = "Count (transactions)"
  )

ss_all <- bind_rows(ss_value, ss_count) |>
  select(type, category, N, mean, sd, p10, median, p90)

# Save as Excel
write_xlsx(ss_all, file.path(out_tbl, "Table_SummaryStats_Spending.xlsx"))

# Save as HTML
ss_all |>
  gt(groupname_col = "type") |>
  fmt_number(columns = c(mean, sd, p10, median, p90), suffixing = TRUE) |>
  fmt_integer(columns = N) |>
  tab_header(title = "Summary Statistics: Daily City-Level Spending") |>
  gtsave(file.path(out_tbl, "Table_SummaryStats_Spending.html"))

message("  Table_SummaryStats_Spending saved.")

# --- 2.2 Panel Coverage -----------------------------------------------------

# Cities with data per year
panel_coverage <- df |>
  group_by(NBS_code, year) |>
  summarise(n_days = n(), .groups = "drop")

# Heatmap: city × year observation count
# Summarise to province level for readability
prov_year_days <- df |>
  group_by(prov_code, prov_nm, year) |>
  summarise(n_obs = n(), .groups = "drop")

p_coverage <- ggplot(prov_year_days, aes(x = year, y = reorder(prov_nm, prov_code),
                                          fill = n_obs)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  scale_fill_gradient(low = "#d4e6f1", high = COL_PRIMARY,
                      labels = comma, name = "City-days") +
  scale_x_continuous(breaks = 2011:2018) +
  labs(title = "Panel Coverage by Province and Year",
       x = NULL, y = NULL) +
  base_theme +
  theme(axis.text.y = element_text(size = 8),
        legend.key.width = unit(1.5, "cm"))

ggsave(file.path(out_fig, "Fig_PanelCoverage.pdf"),
       p_coverage, width = 9, height = 6)
message("  Fig_PanelCoverage.pdf saved.")

# --- 2.3 Annual Aggregate Trends --------------------------------------------

annual_total <- df |>
  group_by(year) |>
  summarise(
    total_value = sum(value_all, na.rm = TRUE) / 1e9,   # in billions CNY
    total_count = sum(count_all, na.rm = TRUE) / 1e6,   # in millions
    .groups = "drop"
  )

p_value_trend <- ggplot(annual_total, aes(x = year, y = total_value)) +
  geom_line(colour = COL_PRIMARY, linewidth = 1.2) +
  geom_point(colour = COL_PRIMARY, size = 3) +
  scale_x_continuous(breaks = 2011:2018) +
  scale_y_continuous(labels = label_comma(suffix = "B")) +
  labs(title = "Total Annual Spending (All Categories)",
       x = NULL, y = "Total Value (Billion CNY)") +
  base_theme

p_count_trend <- ggplot(annual_total, aes(x = year, y = total_count)) +
  geom_line(colour = COL_SECONDARY, linewidth = 1.2) +
  geom_point(colour = COL_SECONDARY, size = 3) +
  scale_x_continuous(breaks = 2011:2018) +
  scale_y_continuous(labels = label_comma(suffix = "M")) +
  labs(title = "Total Annual Transactions (All Categories)",
       x = NULL, y = "Transaction Count (Millions)") +
  base_theme

p_total <- p_value_trend / p_count_trend
ggsave(file.path(out_fig, "Fig_AnnualTrends_Total.pdf"),
       p_total, width = 8, height = 6)
message("  Fig_AnnualTrends_Total.pdf saved.")

# By category
annual_by_cat <- df |>
  select(year, all_of(paste0("value_", categories))) |>
  group_by(year) |>
  summarise(across(everything(), \(x) sum(x, na.rm = TRUE) / 1e9), .groups = "drop") |>
  pivot_longer(-year, names_to = "column", values_to = "total_value") |>
  mutate(category = cat_labels[str_remove(column, "value_")])

p_by_cat <- ggplot(annual_by_cat, aes(x = year, y = total_value,
                                       colour = category, group = category)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 2011:2018) +
  scale_y_continuous(labels = label_comma(suffix = "B")) +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  labs(title = "Annual Spending by Category",
       x = NULL, y = "Total Value (Billion CNY)") +
  base_theme +
  theme(legend.text = element_text(size = 8))

ggsave(file.path(out_fig, "Fig_AnnualTrends_ByCategory.pdf"),
       p_by_cat, width = 9, height = 5)
message("  Fig_AnnualTrends_ByCategory.pdf saved.")

# --- 2.4 Category Composition -----------------------------------------------

# Share of each category in total spending per year
cat_shares <- annual_by_cat |>
  group_by(year) |>
  mutate(share = total_value / sum(total_value)) |>
  ungroup()

p_composition <- ggplot(cat_shares, aes(x = year, y = share,
                                         fill = category)) +
  geom_area(position = "stack", colour = "white", linewidth = 0.2) +
  scale_x_continuous(breaks = 2011:2018) +
  scale_y_continuous(labels = percent_format()) +
  scale_fill_brewer(palette = "Dark2", name = NULL) +
  labs(title = "Spending Category Composition Over Time",
       x = NULL, y = "Share of Total Spending") +
  base_theme +
  theme(legend.text = element_text(size = 8))

ggsave(file.path(out_fig, "Fig_CategoryComposition.pdf"),
       p_composition, width = 9, height = 5)
message("  Fig_CategoryComposition.pdf saved.")

# --- 2.5 Geographic / Provincial Variation ----------------------------------

prov_avg <- df |>
  group_by(prov_code, prov_nm) |>
  summarise(
    avg_value = mean(value_all, na.rm = TRUE) / 1e6,   # millions per city-day
    n_cities  = n_distinct(NBS_code),
    cv_value  = sd(value_all, na.rm = TRUE) / mean(value_all, na.rm = TRUE),
    .groups   = "drop"
  ) |>
  arrange(desc(avg_value)) |>
  slice_head(n = 20)

p_prov_bar <- ggplot(prov_avg, aes(x = avg_value,
                                    y = reorder(prov_nm, avg_value))) +
  geom_col(fill = COL_PRIMARY, alpha = 0.85) +
  scale_x_continuous(labels = label_comma(suffix = "M")) +
  labs(title = "Average Daily Spending per City by Province (Top 20)",
       subtitle = "Mean across all city-days within province",
       x = "Average Value (Million CNY)", y = NULL) +
  base_theme

p_prov_cv <- ggplot(prov_avg, aes(x = cv_value,
                                   y = reorder(prov_nm, avg_value))) +
  geom_col(fill = COL_SECONDARY, alpha = 0.85) +
  labs(title = "Within-Province Dispersion (CV)",
       subtitle = "Coefficient of variation across city-days",
       x = "CV of Daily Spending", y = NULL) +
  base_theme

p_prov <- p_prov_bar | p_prov_cv
ggsave(file.path(out_fig, "Fig_ProvincialSpending.pdf"),
       p_prov, width = 12, height = 6)
message("  Fig_ProvincialSpending.pdf saved.")

# --- 2.6 Spending Distributions ---------------------------------------------

# Log spending distribution across cities
dist_data <- df |>
  filter(value_all > 0) |>
  mutate(log_value_all = log(value_all))

p_violin <- ggplot(dist_data, aes(x = factor(year), y = log_value_all)) +
  geom_violin(fill = COL_PRIMARY, alpha = 0.4, scale = "width") +
  geom_boxplot(width = 0.15, outlier.size = 0.5,
               fill = "white", colour = COL_PRIMARY) +
  labs(title = "Distribution of Log Daily Spending (All Categories)",
       x = "Year", y = "log(Value, CNY)") +
  base_theme

ggsave(file.path(out_fig, "Fig_SpendingDistributions.pdf"),
       p_violin, width = 9, height = 5)
message("  Fig_SpendingDistributions.pdf saved.")

# --- 2.7 Treated vs. Control Spending (Raw Comparison) ----------------------

# Cross-check: has_typhoon == 1 vs 0 (descriptive only)
tc_spending <- df |>
  filter(!is.na(has_typhoon), value_all > 0) |>
  mutate(group = if_else(has_typhoon == 1, "TC-Hit Day", "Non-TC Day")) |>
  group_by(group) |>
  summarise(
    mean_value = mean(value_all, na.rm = TRUE) / 1e6,
    n_obs      = n(),
    .groups    = "drop"
  )

p_tc_compare <- ggplot(tc_spending, aes(x = group, y = mean_value,
                                          fill = group)) +
  geom_col(alpha = 0.85, width = 0.5) +
  scale_fill_manual(values = c("TC-Hit Day" = COL_HIGHLIGHT,
                                "Non-TC Day" = COL_PRIMARY),
                    guide = "none") +
  scale_y_continuous(labels = label_comma(suffix = "M")) +
  labs(title = "Average Daily Spending: TC-Hit vs. Non-TC Days",
       subtitle = "Descriptive only (not causal). TC = tropical cyclone.",
       x = NULL, y = "Mean Value (Million CNY)") +
  geom_text(aes(label = sprintf("n = %s", format(n_obs, big.mark = ","))),
            vjust = -0.5, size = 3.5) +
  base_theme

ggsave(file.path(out_fig, "Fig_TreatControlComparison.pdf"),
       p_tc_compare, width = 6, height = 5)

# Cross-verify: has_typhoon==1 count
n_tc_days <- sum(df$has_typhoon == 1, na.rm = TRUE)
message(sprintf("  Cross-check: %d city-days with has_typhoon==1", n_tc_days))
message("  Fig_TreatControlComparison.pdf saved.")

# =============================================================================
# 3. Tropical Cyclone Analysis
# =============================================================================

message("Section 3: Tropical cyclone analysis...")

# Derive per-event metadata from typhoon_list (track-level data)
event_meta <- typhoon_list |>
  group_by(id) |>
  summarise(
    year_event   = as.integer(format(min(date), "%Y")),
    month_peak   = as.integer(format(date[which.max(level)], "%m")),
    max_level    = max(level),
    n_track_obs  = n(),
    .groups      = "drop"
  )

# Cities hit per event (from main panel)
cities_per_event <- df |>
  filter(!is.na(id)) |>
  group_by(id) |>
  summarise(n_cities = n_distinct(NBS_code), .groups = "drop")

event_summary <- left_join(event_meta, cities_per_event, by = "id")

# --- 3.1 Summary Statistics Table — Typhoon Events -------------------------

tc_stats <- event_summary |>
  summarise(
    N_events      = n(),
    mean_cities   = mean(n_cities, na.rm = TRUE),
    sd_cities     = sd(n_cities, na.rm = TRUE),
    min_cities    = min(n_cities, na.rm = TRUE),
    max_cities    = max(n_cities, na.rm = TRUE),
    mean_max_lev  = mean(max_level),
    n_high_intens = sum(max_level >= 8)
  )

write_xlsx(as.data.frame(tc_stats),
           file.path(out_tbl, "Table_TyphoonEventStats.xlsx"))

# Full event table
write_xlsx(event_summary, file.path(out_tbl, "Table_TyphoonEvents_Full.xlsx"))
message("  Table_TyphoonEventStats.xlsx saved.")

# --- 3.2 Annual Count -------------------------------------------------------

annual_tc <- event_summary |>
  count(year_event, name = "n_events")

p_annual_tc <- ggplot(annual_tc, aes(x = year_event, y = n_events)) +
  geom_col(fill = COL_PRIMARY, alpha = 0.85) +
  geom_text(aes(label = n_events), vjust = -0.4, size = 3.5) +
  scale_x_continuous(breaks = 2011:2018) +
  labs(title = "Tropical Cyclone Events per Year (2011-2018)",
       x = NULL, y = "Number of Events") +
  base_theme

ggsave(file.path(out_fig, "Fig_TyphoonAnnualCount.pdf"),
       p_annual_tc, width = 7, height = 4.5)
message("  Fig_TyphoonAnnualCount.pdf saved.")

# --- 3.3 Seasonal Distribution ----------------------------------------------

monthly_tc <- event_summary |>
  count(month_peak, name = "n_events") |>
  mutate(month_label = month.abb[month_peak])

p_seasonal <- ggplot(monthly_tc,
                     aes(x = month_peak, y = n_events,
                         fill = between(month_peak, 5, 10))) +
  geom_col(alpha = 0.85) +
  scale_fill_manual(values = c("TRUE" = COL_HIGHLIGHT, "FALSE" = COL_SECONDARY),
                    labels = c("TRUE" = "Peak season (May-Oct)", "FALSE" = "Off-season"),
                    name = NULL) +
  scale_x_continuous(breaks = 1:12, labels = month.abb) +
  labs(title = "Tropical Cyclone Seasonality (by Peak Intensity Month)",
       x = NULL, y = "Number of Events") +
  base_theme

ggsave(file.path(out_fig, "Fig_TyphoonSeasonality.pdf"),
       p_seasonal, width = 8, height = 4.5)
message("  Fig_TyphoonSeasonality.pdf saved.")

# --- 3.4 Intensity Distribution ---------------------------------------------

# Use track-level data for intensity distribution
intensity_dist <- typhoon_list |>
  count(level, name = "n_obs") |>
  mutate(
    level_f     = factor(level),
    label       = level_labels[as.character(level)],
    high_intens = level >= 8
  )

p_intensity <- ggplot(intensity_dist, aes(x = level_f, y = n_obs,
                                            fill = high_intens)) +
  geom_col(alpha = 0.85) +
  scale_fill_manual(values = c("TRUE" = COL_HIGHLIGHT, "FALSE" = COL_PRIMARY),
                    labels = c("TRUE" = "High intensity (>=8)", "FALSE" = "Standard"),
                    name = NULL) +
  scale_y_continuous(labels = comma) +
  labs(title = "Tropical Cyclone Track Intensity Distribution",
       subtitle = "Level 9 = transformation to temperate cyclone (structural change)",
       x = "Beaufort Level", y = "Track Observations") +
  geom_vline(xintercept = 7.5, linetype = "dashed",
             colour = COL_HIGHLIGHT, linewidth = 0.7) +
  annotate("text", x = 7.7, y = max(intensity_dist$n_obs) * 0.8,
           label = "High-intensity\nthreshold", hjust = 0, size = 3,
           colour = COL_HIGHLIGHT) +
  base_theme

ggsave(file.path(out_fig, "Fig_TCIntensity.pdf"),
       p_intensity, width = 8, height = 5)
message("  Fig_TCIntensity.pdf saved.")

# --- 3.5 City Exposure Frequency --------------------------------------------

city_exposures <- df |>
  filter(!is.na(id)) |>
  distinct(NBS_code, id) |>
  count(NBS_code, name = "n_events_hit")

# Cities with zero exposure (in the panel but never hit)
all_cities <- distinct(df, NBS_code)
city_exposures_full <- left_join(all_cities, city_exposures, by = "NBS_code") |>
  replace_na(list(n_events_hit = 0))

# Summary breakdown
exposure_bins <- city_exposures_full |>
  mutate(bin = case_when(
    n_events_hit == 0    ~ "0 events",
    n_events_hit <= 3    ~ "1-3 events",
    n_events_hit <= 6    ~ "4-6 events",
    TRUE                 ~ "7+ events"
  )) |>
  count(bin) |>
  mutate(pct = n / sum(n))

message(sprintf("  City exposure breakdown:\n%s",
                paste(sprintf("    %s: %d cities (%.0f%%)",
                              exposure_bins$bin, exposure_bins$n,
                              100 * exposure_bins$pct),
                      collapse = "\n")))

p_exposure <- ggplot(city_exposures_full, aes(x = n_events_hit)) +
  geom_histogram(binwidth = 1, fill = COL_PRIMARY, alpha = 0.85,
                 colour = "white") +
  scale_y_continuous(breaks = pretty_breaks()) +
  labs(title = "Distribution of Typhoon Exposure Across Cities",
       subtitle = "Number of distinct typhoon events a city was exposed to (2011-2018)",
       x = "Number of Typhoon Events", y = "Number of Cities") +
  base_theme

ggsave(file.path(out_fig, "Fig_CityExposureFrequency.pdf"),
       p_exposure, width = 7, height = 5)
message("  Fig_CityExposureFrequency.pdf saved.")

# --- 3.6 Geographic Distribution (Province Level) ---------------------------

prov_exposure <- df |>
  filter(!is.na(id)) |>
  group_by(prov_code, prov_nm) |>
  summarise(n_city_hits = n(), .groups = "drop") |>
  arrange(desc(n_city_hits))

p_prov_tc <- ggplot(prov_exposure,
                     aes(x = n_city_hits,
                         y = reorder(prov_nm, n_city_hits))) +
  geom_col(fill = COL_HIGHLIGHT, alpha = 0.85) +
  scale_x_continuous(labels = comma) +
  labs(title = "Total Typhoon City-Hit Days by Province",
       subtitle = "Sum of city-days with has_typhoon == 1, by province",
       x = "City-Hit Days", y = NULL) +
  base_theme

ggsave(file.path(out_fig, "Fig_TyphoonProvincialExposure.pdf"),
       p_prov_tc, width = 8, height = 6)
message("  Fig_TyphoonProvincialExposure.pdf saved.")

# --- 3.7 Landfall vs. Subsequent Split -------------------------------------

# Identify landfall: first day a city is hit for a given typhoon event
# "Landfall" = event_time is at its minimum for the (city, id) pair
# Use up_event (1 = first day; 0 = subsequent) if available
if ("up_event" %in% names(df)) {
  landfall_split <- df |>
    filter(!is.na(id)) |>
    distinct(NBS_code, id, up_event) |>
    group_by(NBS_code, id) |>
    summarise(is_landfall = any(up_event == 1), .groups = "drop") |>
    left_join(
      df |> filter(!is.na(id)) |>
        distinct(NBS_code, id, level) |>
        group_by(NBS_code, id) |>
        summarise(max_level = max(level), .groups = "drop"),
      by = c("NBS_code", "id")
    ) |>
    mutate(
      sub_exp    = if_else(is_landfall, "Landfall", "Subsequent"),
      high_intens = max_level >= 8
    )
} else {
  # Fallback: derive from event_time — landfall is event_time == 0
  landfall_split <- df |>
    filter(!is.na(id), !is.na(event_time)) |>
    group_by(NBS_code, id) |>
    summarise(
      is_landfall = any(event_time == 0),
      max_level   = max(level, na.rm = TRUE),
      .groups     = "drop"
    ) |>
    mutate(
      sub_exp    = if_else(is_landfall, "Landfall", "Subsequent"),
      high_intens = max_level >= 8
    )
}

split_summary <- landfall_split |>
  count(sub_exp, high_intens, name = "n_pairs")

p_landfall <- ggplot(split_summary,
                      aes(x = sub_exp, y = n_pairs,
                          fill = high_intens)) +
  geom_col(position = "dodge", alpha = 0.85) +
  scale_fill_manual(values = c("TRUE" = COL_HIGHLIGHT, "FALSE" = COL_PRIMARY),
                    labels = c("TRUE" = "High intensity (level >=8)",
                               "FALSE" = "Standard intensity"),
                    name = NULL) +
  labs(title = "City-Event Pairs: Landfall vs. Subsequent Exposure",
       subtitle = "Broken down by typhoon intensity",
       x = NULL, y = "Number of City-Event Pairs") +
  base_theme

ggsave(file.path(out_fig, "Fig_LandfallVsSubsequent.pdf"),
       p_landfall, width = 7, height = 5)
message("  Fig_LandfallVsSubsequent.pdf saved.")

# --- 3.8 Typhoon Track Map (if spatial data loaded) -------------------------

if (spatial_ok) {
  # Verify geometry and CRS
  tc_lines_sf <- st_transform(tc_lines, 4326)

  # Clip to East Asia extent
  bbox <- c(xmin = 100, xmax = 145, ymin = 10, ymax = 45)

  # Colour by level, treating 9 as a structural category
  tc_lines_sf <- tc_lines_sf |>
    mutate(level_cat = case_when(
      level <= 2 ~ "Weak (0-2)",
      level <= 4 ~ "Moderate (3-4)",
      level <= 6 ~ "Strong (5-6)",
      TRUE       ~ "Temperate (9)"
    ))

  p_map <- ggplot() +
    geom_sf(data = tc_lines_sf,
            aes(colour = level_cat), linewidth = 0.5, alpha = 0.7) +
    scale_colour_manual(
      values = c("Weak (0-2)"     = "#74b9ff",
                 "Moderate (3-4)" = COL_PRIMARY,
                 "Strong (5-6)"   = COL_HIGHLIGHT,
                 "Temperate (9)"  = COL_SECONDARY),
      name = "Intensity"
    ) +
    coord_sf(xlim = c(bbox["xmin"], bbox["xmax"]),
             ylim = c(bbox["ymin"], bbox["ymax"])) +
    labs(title = "Tropical Cyclone Tracks (2011-2018)",
         subtitle = "Coloured by maximum intensity; 63 events") +
    theme_bw(base_size = 11) +
    theme(panel.grid = element_line(colour = "grey90"),
          legend.position = "bottom")

  ggsave(file.path(out_fig, "Fig_TyphoonTrackMap.pdf"),
         p_map, width = 9, height = 7)
  message("  Fig_TyphoonTrackMap.pdf saved.")
} else {
  message("  Fig_TyphoonTrackMap.pdf skipped (spatial data unavailable).")
}

# =============================================================================
# 4. Typhoon x Spending Intersection
# =============================================================================

message("Section 4: Typhoon x spending intersection...")

# --- 4.1 Spending Around Event Window (Simple Averages) --------------------

# Average log(value_all) by event_time for treated cities only
event_window <- df |>
  filter(!is.na(id), value_all > 0, !is.na(event_time),
         between(event_time, -14, 14)) |>
  group_by(event_time) |>
  summarise(
    mean_log_value = mean(log(value_all), na.rm = TRUE),
    se_log_value   = sd(log(value_all), na.rm = TRUE) / sqrt(n()),
    n_obs          = n(),
    .groups        = "drop"
  )

p_event_window <- ggplot(event_window, aes(x = event_time, y = mean_log_value)) +
  geom_ribbon(aes(ymin = mean_log_value - 1.96 * se_log_value,
                  ymax = mean_log_value + 1.96 * se_log_value),
              fill = COL_PRIMARY, alpha = 0.15) +
  geom_line(colour = COL_PRIMARY, linewidth = 1.1) +
  geom_point(colour = COL_PRIMARY, size = 2) +
  geom_vline(xintercept = 0, linetype = "dashed",
             colour = COL_HIGHLIGHT, linewidth = 0.8) +
  annotate("text", x = 0.3, y = min(event_window$mean_log_value),
           label = "Event day", hjust = 0, colour = COL_HIGHLIGHT, size = 3) +
  scale_x_continuous(breaks = seq(-14, 14, by = 2)) +
  labs(title = "Average log(Spending) Around Typhoon Hit (Treated Cities)",
       subtitle = "Descriptive  -  no controls applied. Shaded band: +/-1.96 SE.",
       x = "Days Relative to Typhoon Hit", y = "Mean log(Value, CNY)") +
  base_theme

ggsave(file.path(out_fig, "Fig_RawEventWindow.pdf"),
       p_event_window, width = 9, height = 5)
message("  Fig_RawEventWindow.pdf saved.")

# --- 4.2 Treated City Count per Event ---------------------------------------

cities_hit_per_event <- df |>
  filter(!is.na(id)) |>
  group_by(id) |>
  summarise(n_cities = n_distinct(NBS_code), .groups = "drop")

p_cities_per_event <- ggplot(cities_hit_per_event, aes(x = n_cities)) +
  geom_histogram(binwidth = 1, fill = COL_PRIMARY, alpha = 0.85,
                 colour = "white") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Cities Hit per Typhoon Event",
       subtitle = sprintf("Across %d events; median = %d cities",
                          nrow(cities_hit_per_event),
                          median(cities_hit_per_event$n_cities)),
       x = "Number of Cities Hit", y = "Number of Events") +
  base_theme

ggsave(file.path(out_fig, "Fig_TreatedCitiesPerEvent.pdf"),
       p_cities_per_event, width = 7, height = 5)
message("  Fig_TreatedCitiesPerEvent.pdf saved.")

# =============================================================================
# 5. Final Verification
# =============================================================================

message("\n=== Output verification ===")

expected_figs <- c(
  "Fig_PanelCoverage.pdf",
  "Fig_AnnualTrends_Total.pdf",
  "Fig_AnnualTrends_ByCategory.pdf",
  "Fig_CategoryComposition.pdf",
  "Fig_ProvincialSpending.pdf",
  "Fig_SpendingDistributions.pdf",
  "Fig_TreatControlComparison.pdf",
  "Fig_TyphoonAnnualCount.pdf",
  "Fig_TyphoonSeasonality.pdf",
  "Fig_TCIntensity.pdf",
  "Fig_CityExposureFrequency.pdf",
  "Fig_TyphoonProvincialExposure.pdf",
  "Fig_LandfallVsSubsequent.pdf",
  "Fig_RawEventWindow.pdf",
  "Fig_TreatedCitiesPerEvent.pdf"
)

expected_tbls <- c(
  "Table_SummaryStats_Spending.xlsx",
  "Table_SummaryStats_Spending.html",
  "Table_TyphoonEventStats.xlsx",
  "Table_TyphoonEvents_Full.xlsx"
)

fig_status  <- file.exists(file.path(out_fig, expected_figs))
tbl_status  <- file.exists(file.path(out_tbl, expected_tbls))

for (i in seq_along(expected_figs)) {
  status <- if (fig_status[i]) "OK" else "MISSING"
  message(sprintf("  [%s] %s", status, expected_figs[i]))
}
for (i in seq_along(expected_tbls)) {
  status <- if (tbl_status[i]) "OK" else "MISSING"
  message(sprintf("  [%s] %s", status, expected_tbls[i]))
}

n_missing <- sum(!fig_status) + sum(!tbl_status)
if (n_missing == 0) {
  message("\nAll outputs verified. Descriptive analysis complete.")
} else {
  message(sprintf("\nWARNING: %d output(s) missing  -  check errors above.", n_missing))
}
