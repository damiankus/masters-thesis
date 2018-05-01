testwd <- getwd()
setwd('..')
source('utils.r')
source('preprocess.r')
setwd(testwd)

packages <- c('testthat')
import(packages)

obs <- data.frame(timestamp = c('2017-01-01 12:00',
                                '2017-02-04 12:00',
                                '2017-03-23 12:00',
                                '2017-04-11 12:00',
                                '2017-05-14 12:00',
                                '2017-06-30 12:00',
                                '2017-07-15 12:00',
                                '2017-08-01 12:00',
                                '2017-09-01 12:00',
                                '2017-10-01 12:00',
                                '2017-11-13 12:00',
                                '2017-12-23 12:00'),
                  pm2_5 = c(75, 65, 20, 15, 12, 11,
                            10, 11, 20, 25, 30, 60))

test_that('Splitting by heating season', {
  # observations from April to September should be 
  # qualified as belonging to non heating season
  s <- split_by_heating_season(obs)
  expect_equal(sum(s), 6)  
})

test_that('Splitting by season - number of winter obs', {
  s <- split_by_season(obs)
  expect_equal(sum(s == 'winter'), 3)  
})

test_that('Splitting by season - label validity', {
  s <- split_by_season(obs)
  idx <- which(obs$timestamp == '2017-06-30 12:00')
  expect_equal(s[idx], 'summer')  
})

test_that('Generating winter time series', {
  winter_series <- generate_ts_by_season('winter', 2017)
  first_ts <- as.POSIXct('2017-01-01 00:00', tz = 'UTC')
  last_ts <- as.POSIXct('2017-12-31 23:00', tz = 'UTC')
  expect_equal(winter_series[1], first_ts)
  expect_equal(winter_series[length(winter_series)], last_ts)
})

test_that('Generating summer time series', {
  summer_series <- generate_ts_by_season('summer', 2017)
  first_ts <- as.POSIXct('2017-06-22 00:00', tz = 'UTC')
  last_ts <- as.POSIXct('2017-09-22 23:00', tz = 'UTC')
  expect_equal(summer_series[1], first_ts)
  expect_equal(summer_series[length(summer_series)], last_ts)
})
