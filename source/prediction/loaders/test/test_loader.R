test_wd <- getwd()
setwd(file.path("..", "..", "..", "common"))
source("utils.R")
setwd(test_wd)

setwd("..")
source("loaders.R")
setwd(test_wd)

packages <- c("testthat", "yaml")
import(packages)

# Helpers

are_almost_equal <- function (first, second, acceptable_error = 1e-02) {
  abs(as.numeric(first) - as.numeric(second)) <= acceptable_error
}

are_configs_equal <- function(expected, actual) {
  all(unlist(
    lapply(names(expected), function(param_name) {
      if (is.numeric(expected[[param_name]])) {
        are_almost_equal(expected[[param_name]], actual[[param_name]])
      } else {
        expected[[param_name]] == actual[[param_name]]
      }
    })
  ))
}

is_value_within_power_range <- function (val, bounds, exp_base) {
  exp_base^min(bounds) <= val && val <= exp_base^max(bounds)
}

is_spec_within_power_bounds <- function (spec, constraints = list(), exp_base = 10) {
  params_within_bounds <- lapply(names(constraints), function (param) {
    bounds <- constraints[[param]]
    if (length(bounds) > 1) {
      is_value_within_power_range(spec[[param]], bounds = bounds, exp_base = exp_base)
    } else {
      are_almost_equal(spec[[param]], bounds[[1]])
    }
  })
  all(unlist(params_within_bounds))
}

do_specs_contain_all_values <- function (specs, value_sets) {
  subsets_equal <- unlist(lapply(names(value_sets), function (param) {
    actual <- pick(specs, param)
    expected <- value_sets[[param]]
    length(setdiff(actual, expected)) == 0
  }))
  all(subsets_equal)
}

pick <- function (items, param_name) {
  sapply(items, function (item) { item[[param_name]] })
}

config_path <- "test_config.yaml"
raw_config <- read_yaml(config_path)

test_that("extending parent spec", {
  params <- c("a", "b", "c", "d")
  test_that("preserves parent attributes if they are not specified in a child", {
    parent <- list(a = "a", b = "b")
    spec <- list(d = "d")
    extended <- get_extended_spec(spec, parent)
    expect_true(all(c(
      extended$a == parent$a,
      extended$b == parent$b
    )))
  })

  test_that("overrides parent attributes if they are present in a child", {
    parent <- list(a = "a", b = "b")
    spec <- list(a = "new a", d = "d")
    extended <- get_extended_spec(spec, parent)
    expect_true(all(c(
      extended$a == spec$a
    )))
  })
})

test_that("parsing numeric parameters", {
  numeric_params <- c("a", "c", "e", "f")
  spec <- list(a = ".1", b = "b", c = "1e+06", d = "d", e = ".9", f = "5e-2")
  expected <- list(a = 0.1, b = "b", c = 1000000, d = "d", e = 0.9, f = 0.05)
  parsed <- parse_numeric_params(numeric_params, spec)
  acceptable_error <- 1e-3

  test_that("results in valid values", {
    diffs <- unlist(lapply(numeric_params, function(param) {
      abs(expected[[param]] - parsed[[param]])
    }))
    expect_true(all(diffs <= acceptable_error))
  })

  test_that("preserves non-numeric parameters", {
    expect_true(all(c(
      parsed$b == spec$b,
      parsed$d == spec$d
    )))
  })
})

test_that("for a split based on", {
  test_that("year", {
    models <- raw_config[[1]]$models

    test_that("model being", {
      test_that("neural network", {
        test_that("single spec config is loaded properly", {
          spec <- models[[2]]
          expected <- list(
            hidden = "10-5-2",
            epochs = 300,
            min_delta = 1,
            batch_size = 64
          )
          actual <- get_neural_networks(spec)[[1]]$config
          expect_true(are_configs_equal(expected, actual))
        })

        test_that("config with children preserves parameters absent in children and overrides the present ones", {
          spec <- models[[3]]
          expected <- list(
            min_delta = 0.7,
            epochs = 100,
            hidden = "10-5-2",
            activation = "tanh"
          )
          actual <- get_neural_networks(spec)[[1]]$config
          expect_true(are_configs_equal(expected, actual))
        })
      })

      test_that("SVR", {
        test_that("single spec config is loaded properly", {
          spec <- models[[4]]
          expected <- list(
            kernel = "radial",
            gamma = 1e-5,
            epsilon = 1e-3,
            cost = 1e3
          )
          actual <- get_svrs(spec)[[1]]$config
          expect_true(are_configs_equal(expected, actual))
        })

        test_that("config with children preserves parameters absent in children and overrides the present ones", {
          spec <- models[[5]]
          expected <- list(
            kernel = "radial",
            epsilon = 1e-3,
            cost = 1e5,
            gamma = 0.01
          )
          actual <- get_svrs(spec)[[1]]$config
          expect_true(are_configs_equal(expected, actual))
        })
      })
    })
  })
})

test_that("parsed config", {
  configs <- load_yaml_configs(config_path)

  test_that("for split type based on", {
    test_that("season and year", {
      config <- configs[[2]]
      common_net_archs <- c("100", "200")
      model_groups <- lapply(config$datasets_with_models, function(dataset_with_models) {
        dataset_with_models$models
      })

      test_that("preserves split type name", {
        expect_equal("season_and_year", config$split_type)
      })

      test_that("preserves the number of repetitions", {
        expect_equal(3, config$repetitions)
      })

      test_that("preserves monitoring station ids", {
        expect_true(all(config$stations == c("gios_krasinskiego")))
      })

      test_that("contains a valid number of data splits", {
        expected <- 4
        actual <- length(model_groups)
        expect_equal(expected, actual)
      })

      test_that("creates neural networks with valid architectures for", {
        test_that("winter", {
          expected <- c("10", "5-3", common_net_archs)
          actual <- lapply(model_groups[[1]], function(model) {
            model$spec$hidden
          })
          expect_true(all(expected == actual))
        })
        test_that("spring", {
          expected <- c("5-3", "10-7-3", common_net_archs)
          actual <- lapply(model_groups[[2]], function(model) {
            model$spec$hidden
          })
          expect_true(all(expected == actual))
        })
        test_that("summer", {
          expected <- c("10-5", "10-5-5", common_net_archs)
          actual <- lapply(model_groups[[3]], function(model) {
            model$spec$hidden
          })
          expect_true(all(expected == actual))
        })
        test_that("autumn", {
          expected <- c("10-5-5", common_net_archs)
          actual <- lapply(model_groups[[4]], function(model) {
            model$spec$hidden
          })
          expect_true(all(expected == actual))
        })
      })
    })
  })
  
  test_that("containing list parameters", {
    models <- configs[[3]]$datasets_with_models[[1]]$models
    specs <- lapply(models, function (model) { model$spec })
    test_that("with a single value does not differ from a config with a primitive parameter", {
      primitive_spec <- specs[[1]]
      list_spec <- specs[[2]]
      expect_true(are_configs_equal(primitive_spec, list_spec))
    })
    
    test_that("contains all combinations of the list param values", {
      expected <- list(
        list(
          l2 = 1,
          epsilon = 3
        ),
        list(
          l2 = 1,
          epsilon = 4
        ),
        list(
          l2 = 2,
          epsilon = 3
        ),
        list(
          l2 = 2,
          epsilon = 4
        )
      )
      actual <- specs[3:6]
      pairwise_equality <- unlist(lapply(seq_along(expected), function (idx) {
        are_configs_equal(expected[[idx]], actual[[idx]])
      }))
      expect_true(all(pairwise_equality))
    })
    
    test_that("contains unrolled child list parameters", {
      expected <- list(
        list(
          hidden = 5,
          batch_size = 128,
          epsilon = 1
        ),
        list(
          hidden = 5,
          batch_size = 128,
          epsilon = 2
        )
      )
      actual <- specs[7:8]
      pairwise_equality <- unlist(lapply(seq_along(expected), function (idx) {
        are_configs_equal(expected[[idx]], actual[[idx]])
      }))
      expect_true(all(pairwise_equality))
    })
    
    test_that("contains unrolled parent list parameters", {
      expected <- list(
        list(
          hidden = 5,
          batch_size = 64,
          epsilon = 1
        ),
        list(
          hidden = 5,
          batch_size = 128,
          epsilon = 1
        )
      )
      actual <- specs[9:10]
      pairwise_equality <- unlist(lapply(seq_along(expected), function (idx) {
        are_configs_equal(expected[[idx]], actual[[idx]])
      }))
      expect_true(all(pairwise_equality))
    })
  })
  
  test_that("with random parameters contains", {
    
    models <- configs[[6]]$datasets_with_models[[1]]$models
    specs <- lapply(models, function (model) { model$spec })
    
    test_that('the number of models equal to', {
      test_that('the specified one if there are enough combinations', {
        random_models <- configs[[4]]$datasets_with_models[[1]]$models
        expect_equal(5, length(random_models))
      })

      test_that('the number of combinations if it is smaller', {
        random_models <- configs[[5]]$datasets_with_models[[1]]$models
        expect_equal(2, length(random_models))
      })
    })
    
    test_that('random values', {
      
      test_that('within the specified bounds', {
        actual <- specs[[1]]
        expected <- list(
          gamma = c(1, 2),
          epsilon = c(3, 4),
          cost = c(5, 6)
        )
        expect_true(is_spec_within_power_bounds(actual, expected))
      })
      
      test_that('being powers of the specified base', {
        actual <- specs[[2]]
        expected <- list(
          gamma = 1,
          epsilon = 2,
          cost = c(3, 4)
        )
        expect_true(is_spec_within_power_bounds(actual, expected, exp_base = 2))
      })
      
      test_that('preserving exponent step', {
        actual <- specs[[3]]
        expected <- list(
          gamma = 1,
          epsilon = 2,
          cost = c(1, 9)
        )
        expect_true(is_spec_within_power_bounds(actual, expected, exp_base = 2))
        exponent_remainder <- log2(actual$cost) %% 1
        expect_true(are_almost_equal(exponent_remainder, 0))
      })
      
      test_that('preserving exponent step', {
        actual <- specs[[3]]
        expected <- list(
          gamma = 1,
          epsilon = 2,
          cost = c(1, 9)
        )
        expect_true(is_spec_within_power_bounds(actual, expected, exp_base = 2))
        exponent_remainder <- log2(actual$cost) %% 1
        expect_true(are_almost_equal(exponent_remainder, 0))
      })
    })
    
    test_that('own non-random values', {
      actual <- specs[[4]]
      expected <- list(
        gamma = c(1, 2),
        epsilon = c(3, 4),
        cost = 5
      )
      expect_true(is_spec_within_power_bounds(actual, expected))
    })
    
    test_that('parent non-random values', {
      actual <- specs[[5]]
      expected <- list(
        gamma = 1,
        epsilon = c(2, 3),
        cost = c(4, 5)
      )
      expect_true(is_spec_within_power_bounds(actual, expected))
    })
    
    test_that('child non-random values', {
      actual <- specs[[6]]
      expected <- list(
        gamma = c(1, 2),
        epsilon = c(3, 4),
        cost = 5
      )
      expect_true(is_spec_within_power_bounds(actual, expected))
    })
    
    test_that('parent list values', {
      actual <- specs[7:8]
      expected <- list(
        epsilon = c(3, 4),
        cost = c(5, 6)
      )
      specs_within_power_bounds <- unlist(lapply(actual, function (spec) {
        is_spec_within_power_bounds(spec, expected)
      }))
      expect_true(all(specs_within_power_bounds))
      
      expected_values <- list(
        gamma = c(1, 2)
      )
      expect_true(do_specs_contain_all_values(actual, expected_values))
    })
    
    test_that('child list values', {
      actual <- specs[9:10]
      expected <- list(
        gamma = c(1, 2),
        epsilon = c(3, 4)
      )
      specs_within_power_bounds <- unlist(lapply(actual, function (spec) {
        is_spec_within_power_bounds(spec, expected)
      }))
      expect_true(all(specs_within_power_bounds))
      
      expected_values <- list(
        cost = c(5, 6)
      )
      expect_true(do_specs_contain_all_values(actual, expected_values))
    })
    
    test_that('combined parent and child random values', {
      actual <- specs[[11]]
      expected <- list(
        gamma = c(1, 2),
        epsilon = c(3, 4),
        cost = c(5, 6)
      )
      expect_true(is_spec_within_power_bounds(actual, expected))
    })
    
    test_that('combined inherited primitive, random, and list values', {
      actual <- specs[12:15]
      expected <- list(
        gamma = c(1, 10)
      )
      specs_within_power_bounds <- unlist(lapply(actual, function (spec) {
        is_spec_within_power_bounds(spec, expected)
      }))
      expect_true(all(specs_within_power_bounds))
      
      expected_values <- list(
        epsilon = c(11, 12),
        kernel = c('radial'),
        cost = c(13)
      )
      expect_true(do_specs_contain_all_values(actual, expected_values))
    })
    
    test_that('combined values from multiple inheritance levels', {
      actual <- specs[16:23]
      expected <- list(
        l2 = c(1, 2),
        learning_rate = c(5, 6)
      )
      specs_within_power_bounds <- unlist(lapply(actual, function (spec) {
        is_spec_within_power_bounds(spec, expected)
      }))
      expect_true(all(specs_within_power_bounds))
      
      expected_values <- list(
        hidden = c('10', '10-5-3'),
        epsilon = c(3, 4),
        activation = c('tanh'),
        batch_size = c(32)
      )
      expect_true(do_specs_contain_all_values(actual, expected_values))
    })
  })
})