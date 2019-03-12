wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse", "lubridate")
import(packages)

aggr_vals <- function(df, var, by_vars) {
  # Plots are prepared separately for each station so the total precipitation for the
  # given day is the 24h maximum value
  aggr_series <- aggregate(series[, var],
      by = list(series$date, series$station_id),
      FUN = mean, na.rm = TRUE
    )
  names(aggr_series) <- c(by_vars, var)
  aggr_series
}

draw_trend_for_period <- function(df, vars, by, period_name) {
  series_from <- min(df$measurement_time)
  series_to <- max(df$measurement_time)
  last_to_ts <- tail(seq(from = series_to, length = 2, by = by), 1)
  ts_seq <- c(seq(from = series_from, to = series_to, by = by), c(last_to_ts))
  base_len <- length(ts_seq) - 1
  from_seq <- head(ts_seq, base_len)
  to_seq <- tail(ts_seq, base_len)

  lapply(seq(base_len), function(idx) {
    from <- from_seq[idx]
    to <- to_seq[idx]

    which_rows <- from <= df$measurement_time & df$measurement_time < to
    subseries <- df[which_rows, ]

    lapply(vars, function(var) {
      plot_path <- file.path(
        target_dir,
        paste(period_name, var, format(from, format = "%Y-%m-%d"), "trend.png", sep = "_")
      )
      save_multi_facet_plot(subseries,
        x_var = "measurement_time",
        y_var = var,
        id_var = "station_id",
        plot_path = plot_path, x_lab = "Date"
      )
    })
  })
}

draw_hourly <- function(df, vars) {
  draw_trend_for_period(df, vars, by = "2 days", "hourly")
}

draw_daily <- function(df, vars) {
  draw_trend_for_period(df, vars, by = "7 days", "daily")
}

draw_monthly <- function(df, vars) {
  draw_trend_for_period(df, vars, by = "1 month", "monthly")
}

draw_yearly <- function(df, vars) {
  lapply(vars, function(var) {
    subseries <- aggr_vals(df, var, c("date", "station_id"))
    plot_path <- file.path(
      target_dir,
      paste("yearly", var, "trend.png", sep = "_")
    )
    save_multi_facet_plot(subseries, var,
      x_var = "date",
      y_var = var,
      id_var = "station_id",
      plot_path = plot_path,
      x_lab = "Date"
    )
  })
}

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "trend"),
  make_option(c("-v", "--variables"), type = "character", default = 'day_of_year_cosine'),#paste(BASE_VARS, collapse = ",")),
  

  # A semicolon separated string with following possible values
  # yearly, monthly, daily, hourly
  # example -t yearly,monthly,daily
  make_option(c("-t", "--type"), type = "character", default = "yearly")
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
vars <- parse_list_argument(opts, 'variables')
required_vars <- c(vars, "measurement_time", "station_id")
series <- series[, required_vars]
series$date <- as.Date(utcts(series$measurement_time))
series$station_id <- sapply(series$station_id, get_pretty_station_id)

target_dir <- opts[["output-dir"]]
mkdir(target_dir)

valid_grouping_types <- c(
  "yearly",
  "monthly",
  "daily",
  "hourly"
)
period_types <- parse_list_argument(opts, "type", valid_values = valid_grouping_types)

lapply(period_types, function(period_type) {
  draw <- switch(period_type,
    "yearly" = draw_yearly,
    "monthly" = draw_monthly,
    "daily" = draw_daily,
    "hourly" = draw_hourly,
    {}
  )
  draw(series, vars)
})
