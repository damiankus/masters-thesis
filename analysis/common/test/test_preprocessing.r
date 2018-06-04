testwd <- getwd()
setwd('..')
source('utils.r')
source('preprocess.r')
setwd(testwd)

packages <- c('testthat')
import(packages)

# Loaded data frame will be stored in a variable called windows
load(file = 'test_windows.Rda')

numeric_cols <- colnames(windows)[grepl('numeric', sapply(windows, class))]
windows <- windows[, numeric_cols]

means <- apply(windows, 2, mean)
sds <- apply(windows, 2, sd)
mins <- apply(windows, 2, min)
maxs <- apply(windows, 2, max)
epsilon <- 1e-4
varname <- 'pm2_5'

test_that('Generating winter time series (Jan - Mar)', {
  winter_series <- generate_ts_by_season(1, 2017)
  first_ts <- as.POSIXct('2017-01-01 00:00', tz = 'UTC')
  last_ts <- as.POSIXct('2017-03-20 23:00', tz = 'UTC')
  expect_equal(winter_series[1], first_ts)
  expect_equal(winter_series[length(winter_series)], last_ts)
})

test_that('Generating summer time series', {
  summer_series <- generate_ts_by_season(3, 2017)
  first_ts <- as.POSIXct('2017-06-22 00:00', tz = 'UTC')
  last_ts <- as.POSIXct('2017-09-22 23:00', tz = 'UTC')
  expect_equal(summer_series[1], first_ts)
  expect_equal(summer_series[length(summer_series)], last_ts)
})

test_that('Normalizing scales values to range > 0', {
  normalized <- normalize_with(windows, mins, maxs)
  expect_true(all(apply(normalized, 1:2, function (i) { i > -epsilon })))
})

test_that('Normalizing scales values to < 1', {
  normalized <- normalize_with(windows, mins, maxs)
  expect_true(all(apply(normalized, 1:2, function (i) { i < 1 + epsilon })))
})

test_that('Reversing normalization changes values to original ones', {
  normalized <- normalize_with(windows, mins, maxs)
  original <- reverse_normalize_with(normalized, mins, maxs)
  expect_true(
    all(abs(windows - original) < epsilon))
})

test_that('Reversing normalization for vector changes values to original ones', {
  normalized <- normalize_vec_with(windows[, varname], mins[varname], maxs[varname])
  original <- reverse_normalize_vec_with(normalized, mins[varname], maxs[varname])
  expect_true(all(abs(windows[, varname] - original) < epsilon))
})

test_that('Standardizing changes mean to 0', {
  standardized <- standardize_with(windows, means, sds)
  expect_true(all(apply(standardized, 2, function (col) { abs(mean(col)) < epsilon})))
})

test_that('Standardizing changes sd to 1', {
  standardized <- standardize_with(windows, means, sds)
  expect_true(all(apply(standardized, 2, function (col) { abs(sd(col) - 1) < epsilon})))
})

test_that('Reversing standardization changes mean and sd to original values', {
  standardized <- standardize_with(windows, means, sds)
  original <- reverse_standardize_with(standardized, means, sds)
  expect_true(
    all(abs(windows - original) < epsilon))
})

test_that('Reversing standardization for vector changes mean and sd to original values', {
  standardized <- standardize_vec_with(windows[, varname], means[varname], sds[varname])
  original <- reverse_standardize_vec_with(standardized, means[varname], sds[varname])
  expect_true(all(abs(windows[, varname] - original) < epsilon))
})

