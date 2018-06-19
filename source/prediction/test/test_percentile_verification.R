testwd <- getwd()
setwd('..')
source('../common/utils.r')
source('verify_model_continuous_percentiles.r')
setwd(testwd)

packages <- c('testthat')
import(packages)

# data is stored in a variabled called windows
load(file = 'test_windows.Rda')

test_that('number of samples is correct', {
  last_training_idx <- length(windows[, 1])
  boundaries <- find_training_percentiles(windows, 'pm2_5', last_training_idx, sample_count = 24)
  expect_true(boundaries['samples_count'] == 24)
})

test_that('first sample date is correct', {
  last_training_idx <- length(windows[, 1])
  boundaries <- find_training_percentiles(windows, 'pm2_5', last_training_idx, sample_count = 24)
  first_ts <- utcts('2016-12-31 00:00')
  expect_true(boundaries['first_date'] == first_ts)
})

test_that('last sample date is correct', {
  last_training_idx <- length(windows[, 1])
  boundaries <- find_training_percentiles(windows, 'pm2_5', last_training_idx, sample_count = 24)
  last_ts <- utcts('2016-12-31 23:00')
  expect_true(boundaries['last_date'] == last_ts)
})

