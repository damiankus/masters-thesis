testwd <- getwd()
setwd("..")
source("utils.R")
source("preprocess.R")
setwd(testwd)

packages <- c("testthat")
import(packages)

# Loaded data frame will be stored in a variable called num_series
load(file = "test_series.Rda")

varname <- "pm2_5"
past_lag <- 23
future_lag <- 24
windows <- divide_into_windows(series, past_lag = past_lag, future_lag = future_lag, future_vars = c("pm2_5", "measurement_time"))
vars <- colnames(windows)
ts_vars <- vars[grepl("measurement_time", vars)]

windows[, ts_vars] <- lapply(ts_vars, function(varname) {
  utcts(windows[, varname])
})

first_window <- windows[1, ]
last_window <- windows[length(windows[, 1]), ]
earliest_var <- paste(varname, "past", past_lag, sep = "_")
future_var <- paste("future", varname, sep = "_")

test_that("Number of windows is correct", {
  expect_true(length(windows[, 1]) == (length(series[, 1]) - past_lag - future_lag))
})

test_that("Earliest past observation comes from moment t - past_lag", {
  earliest_var <- paste("measurement_time_past", past_lag, sep = "_")
  t_delta <- difftime(first_window$measurement_time, first_window[[earliest_var]], tz = "UTC", units = "hours")
  expect_true(t_delta == past_lag)
})

test_that("Future observation comes from moment t + future_lag", {
  t_delta <- difftime(first_window$future_measurement_time, first_window$measurement_time, tz = "UTC", units = "hours")
  expect_true(t_delta == future_lag)
})

test_that("Earliest observation of the first window is equal to the first value in the series data frame", {
  earliest_var <- paste(varname, "past", past_lag, sep = "_")
  expect_true(first_window[[earliest_var]] == series[1, varname])
})

test_that("Future observation of the last window is equal to the last value in the series data frame", {
  expect_true(last_window[[future_var]] == series[length(series[, 1]), varname])
})
