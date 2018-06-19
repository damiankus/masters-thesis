testwd <- getwd()
setwd('..')
source('models.r')
setwd(testwd)

packages <- c('testthat')
import(packages)

test_that('generating MLP models - correct number of models', {
  thresholds <- c(0.6)
  deltas <- c(1, 2)
  archs <- c(3, 5)
  mlps <- generate_mlps(archs, deltas, thresholds)
  expect_equal(length(mlps), length(thresholds) * (3 ^ length(archs)))
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

test_that('min generated SVR gamma is greater or equal to lower boundary', {
  min_pow_gamma <- -3
  max_pow_gamma <- 5
  params <- generate_random_svr_params(gamma_pow_bound = c(min_pow_gamma, max_pow_gamma))
  expect_gte(min(params$gamma), 2 ^ min_pow_gamma)
})

test_that('max generated SVR gamma is less than or equal to the upper boundary', {
  min_pow_gamma <- -3
  max_pow_gamma <- 5
  params <- generate_random_svr_params(gamma_pow_bound = c(min_pow_gamma, max_pow_gamma))
  expect_lte(max(params$gamma),  2 ^ max_pow_gamma)
})

test_that('min generated SVR epsilon is greater or equal to lower boundary', {
  min_pow_epsilon <- -3
  max_pow_epsilon <- 2
  params <- generate_random_svr_params(epsilon_pow_bound = c(min_pow_epsilon, max_pow_epsilon))
  expect_gte(min(params$epsilon), 2 ^ min_pow_epsilon)
})

test_that('max generated SVR epsilon is less than or equal to the upper boundary', {
  min_pow_epsilon <- -3
  max_pow_epsilon <- 2
  params <- generate_random_svr_params(epsilon_pow_bound = c(min_pow_epsilon, max_pow_epsilon))
  expect_lte(max(params$epsilon),  2 ^ max_pow_epsilon)
})

test_that('min generated SVR cost is greater or equal to lower boundary', {
  min_pow_cost <- -5
  max_pow_cost <- 10
  params <- generate_random_svr_params(cost_pow_bound = c(min_pow_cost, max_pow_cost))
  expect_gte(min(params$cost), 2 ^ min_pow_cost)
})

test_that('max generated SVR cost is less than or equal to the upper boundary', {
  min_pow_cost <- -5
  max_pow_cost <- 10
  params <- generate_random_svr_params(cost_pow_bound = c(min_pow_cost, max_pow_cost))
  expect_lte(max(params$cost),  2 ^ max_pow_cost)
})


test_that('the number of generated SVR param combinations is valid ', {
  n_models <- 10
  expect_true(length(generate_random_svr_params(n_models = n_models)[, 1]) == n_models)
})
