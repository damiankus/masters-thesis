testwd <- getwd()
setwd("..")
source("models.R")
setwd(testwd)

packages <- c("testthat", "keras")
import(packages)

load("test_series.Rda")
res_var <- "future_pm2_5"
expl_vars <- c("pm2_5", "measurement_time", "temperature")
training_samples_count <- 2000
training_set <- head(series, training_samples_count)
test_set <- tail(series, -training_samples_count)

test_that("predicted values are NA if", {
  test_that("there is an error during the training phase", {
    dummy_exp_bounds_model <- list(fit = function(...) {
      stop("dummy_exp_bounds error")
    })
    results <- get_forecast(dummy_exp_bounds_model, res_var, expl_vars, training_set, test_set)
    expect_true(all(is.na(results$predicted)))
  })

  test_that("there is a warning during the training phase", {
    dummy_exp_bounds_model <- list(fit = function(...) {
      warning("dummy_exp_bounds warning")
    })
    results <- get_forecast(dummy_exp_bounds_model, res_var, expl_vars, training_set, test_set)
    expect_true(all(is.na(results$predicted)))
  })
})

test_that("actual values are same as future response variable values", {
  model <- list(fit = fit_persistence)
  results <- get_forecast(model, res_var, expl_vars, training_set, test_set)
  expect_true(all(results$actual == test_set[, res_var]))
})

test_that("forecast measurement time is same as future test measurement time", {
  model <- list(fit = fit_persistence)
  results <- get_forecast(model, res_var, expl_vars, training_set, test_set)
  expect_true(all(results$measurement_time == test_set$future_measurement_time))
})


test_that("generated model name for a", {
  specs <- list(
    list(
      model_type = "neural network",
      args = list(
        hidden = "10-5",
        activation = "relu",
        epochs = 100,
        min_delta = 0.5,
        batch_size = 128,
        learning_rate = 0.01,
        epsilon = 0.001
      ),
      get_name = get_neural_network_name
    ),
    list(
      model_type = "SVR",
      args = list(
        kernel = "radial",
        gamma = 0.001,
        epsilon = 0.01,
        cost = 10
      ),
      get_name = get_svr_name
    )
  )

  get_parsed_part_elements <- function(parts, idx) {
    unlist(
      lapply(parts, function(part) {
        strsplit(part, "=")[[1]][[idx]]
      })
    )
  }

  get_parsed_args <- function(model_name) {
    parts <- strsplit(model_name, "__")[[1]][-1]
    list(
      names = get_parsed_part_elements(parts, idx = 1),
      values = get_parsed_part_elements(parts, idx = 2)
    )
  }

  lapply(specs, function(spec) {
    test_that(spec$model_type, {
      model_name <- do.call(spec$get_name, spec$args)
      parsed_args <- get_parsed_args(model_name)

      test_that("contains all arguments", {
        diff <- setdiff(parsed_args$names, names(spec$args))
        expect_equal(0, length(diff))
      })

      test_that("preserves argument values", {
        pairwise_equal <- unlist(lapply(seq_along(parsed_args$names), function(idx) {
          spec$args[parsed_args$names[[idx]]] == parsed_args$values[[idx]]
        }))
        expect_true(all(pairwise_equal))
      })

      test_that("preserves argument order in the function signature", {
        shuffled_args <- sample(spec$args)
        shuffled_model_name <- do.call(spec$get_name, shuffled_args)
        expect_equal(model_name, shuffled_model_name)
      })
    })
  })
})

test_that("adding layers to a neural network preserves", {
  model <- keras_model_sequential()
  hidden <- c(100, 50, 25, 10, 5)
  activation <- 'relu'
  model %>% add_layers(hidden = hidden, activation = activation, input_shape = 10)
  
  test_that("the number of", {
    test_that("hidden layers", {
      # -1 for the output layer
      expect_equal(length(hidden), length(model$layers) - 1)
    })
    
    test_that("units in hidden layers", {
      expected <- c(hidden, 1)
      actual <- sapply(model$layers, function (layer) { layer$units })
      expect_true(all(expected == actual))
    })
  })
  
  test_that("activation function", {
    expected <- c(rep(activation, length(hidden)), 'linear')
    actual <- sapply(model$layers, function (layer) { layer$activation })
  })
})