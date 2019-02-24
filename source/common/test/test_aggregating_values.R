wd <- getwd()
setwd(file.path(".."))
source("utils.R")
source("preprocess.R")
setwd(wd)

packages <- c("testthat")
import(packages)

# The @series data frame contains 72 consaecutive
# measurements of timestamp, pm2_5 and temperature
# from 2018-01-01 00:00 UTC to 2018-01-03 23:00 UTC
# * $timestamp - numeric values
# * $pm2_5 - numeric values equal to hour of the timestamp (0 - 23)
# * $temperature - numberic values equal to 2 * hour of the timestamp (0 - 46)

load("test_series.Rda")
past_vars <- c("pm2_5", "temperature")
future_vars <- c("pm2_5", "timestamp")

# Helpers

prepare_windows <- function(past_lag, future_lag) {
  divide_into_windows(df = series, past_lag = past_lag, future_lag = future_lag, future_vars = future_vars)
}

get_past_cols <- function(df) {
  cols <- colnames(df)
  cols[grepl("past", cols)]
}

get_future_cols <- function(df) {
  cols <- colnames(df)
  cols[grepl("future", cols)]
}

past_lag <- 6
future_lag <- 6
windows <- prepare_windows(past_lag, future_lag)
aggregated_windows <- add_aggregated(windows, past_lag, excluded = c("timestamp"))

test_that("number of windows is equal to number of rows - past_lat - future_lag", {
  # Example: past = 2, future = 3, length = 8
  # p - past measurement, c - current measurement, f - future measurements
  # [ppc--f__]
  # [_ppc--f_]
  # [__ppc__f]
  expect_equal(nrow(windows), nrow(series) - past_lag - future_lag)
})

test_that("number of past measurements in a row is equal to past_lag", {
  cols <- colnames(windows)
  cols_containing_past <- get_past_cols(windows)
  cols_for_var_count <- lapply(past_vars, function(varname) {
    sum(grepl(varname, cols_containing_past))
  })
  expect_true(all(cols_for_var_count == past_lag))
})

test_that("number of future measurements in a row is equal to the number of future vars", {
  cols <- colnames(windows)
  cols_containing_future <- get_future_cols(windows)
  cols_for_var_count <- lapply(future_vars, function(varname) {
    sum(grepl(varname, cols_containing_future))
  })
  expect_true(all(cols_for_var_count == 1))
})

test_that("future_timestamp is equal to timestamp + future_lag hours", {
  windows$timestamp <- utcts(windows$timestamp)
  windows$future_timestamp <- utcts(windows$future_timestamp)
  time_deltas <- lapply(1:nrow(windows), function(idx) {
    row <- windows[idx, ]
    difftime(row$future_timestamp, row$timestamp)
  })
  expect_true(all(time_deltas == future_lag))
})

test_that("past values in window rows are equal to values in the original series", {
  cols_containing_past <- get_past_cols(windows)

  # past column names are structured like this:
  # {variable name}_past_{time lag}
  past_col_to_delta <- lapply(cols_containing_past, function(colname) {
    split_parts <- strsplit(colname, "_")
    len <- length(split_parts[[1]])

    # -2 to skip the _past_{time lag} part -> 2 underscores
    original_name <- paste(split_parts[[1]][1:(len - 2)], collapse = "_")
    lag <- split_parts[[1]][len]
    data.frame(past_name = colname, original_name = original_name, delta = (-as.numeric(lag)))
  })

  past_col_to_delta <- do.call(rbind, past_col_to_delta)

  # rbind casts strings to factors
  past_col_to_delta$past_name <- as.character(past_col_to_delta$past_name)
  past_col_to_delta$original_name <- as.character(past_col_to_delta$original_name)
  calc_and_orig_past_values <- lapply(1:nrow(windows), function(idx) {
    row <- windows[idx, ]
    compared_values_for_row <- lapply(1:nrow(past_col_to_delta), function(map_idx) {
      entry <- past_col_to_delta[map_idx, ]
      original_timestamp <- utcts(row$timestamp + (3600 * entry$delta))
      data.frame(
        original_name = entry$original_name,
        original_timestamp = original_timestamp,
        timestamp = row$timestamp,
        calculated_value = as.numeric(row[, entry$past_name]),
        original_value = as.numeric(series[series$timestamp == original_timestamp, entry$original_name])
      )
    })
    do.call(rbind, compared_values_for_row)
  })
  calc_and_orig_past_values <- do.call(rbind, calc_and_orig_past_values)
  expect_true(
    all(
      calc_and_orig_past_values$original_value == calc_and_orig_past_values$calculated_value
    )
  )
})

# PM2.5 values are ordered ascendingly in the test dataset
test_that("aggregated min PM2.5 value is equal to the min value in the group of values", {
  windows <- add_aggregated(windows, past_lag, excluded = c("timestamp"))
  expect_true(
    all(
      windows$min_6_pm2_5 == windows$pm2_5_past_5
    )
  )
})

test_that("aggregated max PM2.5 value is equal to the max value in the group of values", {
  windows <- add_aggregated(windows, past_lag, excluded = c("timestamp"))
  expect_true(
    all(
      windows$max_6_pm2_5 == windows$pm2_5
    )
  )
})

test_that("aggregated mean PM2.5 value is equal to the mean value of the group of values", {
  vars <- colnames(windows)
  pm2_5_vars <- vars[grepl("pm2_5", vars)]
  pm2_5_vars <- pm2_5_vars[pm2_5_vars != "future_pm2_5"]
  pm2_5_rows <- apply(aggregated_windows, 1, function(row) {
    pm2_5_vals <- row[pm2_5_vars]
  })
  pm2_5_rows <- as.data.frame(t(pm2_5_rows))
  mean_pm2_5_vals_per_row <- apply(pm2_5_rows, 1, mean)
  expect_true(
    all(
      mean_pm2_5_vals_per_row == aggregated_windows$mean_7_pm2_5
    )
  )
})

test_that("skipping past variables returns a data frame with no past columns", {
  windows_without_past_cols <- skip_past(windows)
  vars <- colnames(windows_without_past_cols)
  past_vars <- vars[grepl("past", vars)]
  expect_equal(0, length(past_vars))
})

test_that("aggregation ignores NA values ", {
  df <- data.frame(series)
  df[c(1, future_lag + 1), c("pm2_5", "temperature")] <- NA
  windows <- divide_into_windows(df = df, past_lag = past_lag, future_lag = future_lag, future_vars = future_vars)
  aggregated_windows <- add_aggregated(windows, past_lag, excluded = c("timestamp"))
  expect_true(aggregated_windows[1, "min_7_pm2_5"] == df[2, "pm2_5"] &&
    aggregated_windows[1, "mean_7_pm2_5"] == mean(seq(2, future_lag)) &&
    aggregated_windows[1, "max_7_pm2_5"] == df[future_lag, "pm2_5"])
})

test_that("aggregated values are set to NA if there are no defined values in the time window ", {
  df <- data.frame(series)
  df[1:(past_lag + 1), "pm2_5"] <- NA
  windows <- divide_into_windows(df = df, past_lag = past_lag, future_lag = future_lag, future_vars = future_vars)
  aggregated_windows <- add_aggregated(windows, past_lag, excluded = c("timestamp"))
  expect_true(is.na(aggregated_windows[1, "min_7_pm2_5"])
  && is.na(aggregated_windows[1, "mean_7_pm2_5"])
  && is.na(aggregated_windows[1, "max_7_pm2_5"]))
})
