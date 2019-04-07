test_wd <- getwd()
setwd("../../../common")
source("utils.R")
setwd(test_wd)

setwd("..")
source("loaders.R")
setwd(test_wd)

packages <- c("testthat", "yaml")
import(packages)

config_path <- "test_config.yaml"
config <- read_yaml(config_path)
models <- config$models

test_that("extending parent spec", {
  params <- c("a", "b", "c", "d")
  test_that("preserves parent attributes if they are not specified in a child", {
    parent <- list(a = "a", b = "b")
    spec <- list(d = "d")
    extended <- get_extended_spec(params, spec, parent_spec)
    expect_true(all(c(
      extended$a == parent$a,
      extended$b == parent$b
    )))
  })

  test_that("overrides parent attributes if they are present in a child", {
    parent <- list(a = "a", b = "b")
    spec <- list(a = "new a", d = "d")
    extended <- get_extended_spec(params, spec, parent_spec)
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
      extended$b == spec$b,
      extended$d == spec$d
    )))
  })
})

test_that("models", {
  test_that("neural network", {
    test_that("single spec config is loaded properly", {
      spec <- models[[2]]
      loaded <- get_neural_networks(spec)
      expect_equal(loaded[[1]]$name, "neural_network__hidden_10-5-2__threshold_0.7__stepmax_1e+06")
    })

    test_that("config with children preserves parameters absent in children and overrides the present ones", {
      spec <- models[[3]]
      loaded <- get_neural_networks(spec)
      expect_equal(loaded[[1]]$name, "neural_network__hidden_10-5-2__threshold_0.5__stepmax_1e+06")
      expect_equal(loaded[[2]]$name, "neural_network__hidden_20__threshold_0.2__stepmax_1e+06")
    })
  })

  test_that("SVR", {
    test_that("single spec config is loaded properly", {
      spec <- models[[4]]
      loaded <- get_svrs(spec)
      expect_equal(loaded[[1]]$name, "svr__kernel_radial__gamma_1e-05__epsilon_0.001__cost_1000")
    })

    test_that("config with children preserves parameters absent in children and overrides the present ones", {
      spec <- models[[5]]
      loaded <- get_svrs(spec)
      expect_equal(loaded[[1]]$name, "svr__kernel_radial__gamma_0.01__epsilon_0.001__cost_1e+05")
      expect_equal(loaded[[2]]$name, "svr__kernel_radial__gamma_1e-05__epsilon_0.001__cost_16")
    })
  })
})
