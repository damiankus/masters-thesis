testwd <- getwd()
setwd('..')
source('models.r')
setwd(testwd)

packages <- c('testthat')
import(packages)

test_that('generating MLP models - correct number of models', {
  thresholds <- c(0.6, 0.5)
  deltas <- c(1, 2)
  archs <- c(3, 5)
  mlps <- generate_mlps(archs, deltas, thresholds)
  expect_equal(length(mlps), length(thresholds) * (2 ^ length(archs) + 1))
})

test_that('generating MLP models - correct names', {
  thresholds <- c(0.6)
  deltas <- c(1, 2)
  archs <- c(3, 5)
  mlps <- generate_mlps(archs, deltas, thresholds)
  model_names <- names(mlps)
  expect_true(any(grepl('mlp_4_7_th_0.6', model_names)))
})

test_that('generating MLP models - original preserved', {
  thresholds <- c(0.6)
  deltas <- c(1, 2)
  archs <- c(3, 5)
  mlps <- generate_mlps(archs, deltas, thresholds)
  model_names <- names(mlps)
  expect_true(any(grepl('mlp_3_5_th_0.6', model_names)))
})


