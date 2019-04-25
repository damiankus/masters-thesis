wd <- getwd()
setwd(file.path(".."))
source("accuracy_measures.R")
setwd(wd)

packages <- c("testthat")
import(packages)

ACCEPTABLE_ERROR <- 1e-3
actual <- seq(1, 10)

test_that('MAE is equal to', {
  
  test_that('0 for an exact match', {
    predicted <- actual
    results <- data.frame(actual = actual, predicted = predicted)
    expect_equal(mae(results), 0)
  })
  
  test_that('delta for a predicted values differing by delta from the actual ones', {
    delta <- 5
    predicted <- actual + delta
    results <- data.frame(actual = actual, predicted = predicted)
    error <- abs(mae(results) - delta)
    expect_lte(error, ACCEPTABLE_ERROR)  
  })
})

test_that('MAPE is equal to', {
  test_that('0% for an exact match', {
    predicted <- actual
    results <- data.frame(actual = actual, predicted = predicted)
    expected <- 0
    error <- abs(mape(results) - expected)
    expect_lte(error, ACCEPTABLE_ERROR)
  })  
  
  test_that('100% if delta is always equal to the actual value', {
    predicted <- 2 * actual
    results <- data.frame(actual = actual, predicted = predicted)
    expected <- 100
    error <- abs(mape(results) - expected)
    expect_lte(error, ACCEPTABLE_ERROR)
  })
})

test_that('R2 is', {
  test_that('equal to', {
    test_that('1 for an exact match', {
      expected <- 1
      error <- abs(r2(results) - expected)
      expect_lte(error, ACCEPTABLE_ERROR)  
    })
    
    test_that('0 for predicted values equal to the mean actual value', {
      predicted <- rep(mean(actual), length(actual))
      results <- data.frame(actual = actual, predicted = predicted)
      expected <- 0
      error <- abs(r2(results) - expected)
      expect_lte(error, ACCEPTABLE_ERROR)  
    })
  })
  
  test_that('negative when delta is greater than for a constant line equal to the mean actual value', {
    predicted <- actual + mean(actual)
    results <- data.frame(actual = actual, predicted = predicted)
    expect_less_than(r2(results), 0)
  })
})
