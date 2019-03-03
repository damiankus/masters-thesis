wd <- getwd()
setwd(file.path(".."))
source("utils.R")
setwd(wd)

packages <- c("testthat")
import(packages)

expect_parsed_values_to_be_valid <- function (arg_value, valid_values = c(), sep = ";") {
  opts <- list(test_arg = arg_value)
  values <- parse_list_argument(opts, 'test_arg', valid_values = valid_values, sep = sep)
  print(arg_value)
  print(values)
  expect_true(all(
    values[[1]] == "first",
    values[[2]] == "second",
    values[[3]] == "third"
  ))
}

test_that("Parsing a list argument returns a list of expected values", {
  arg <- "first;second;third"
  expect_parsed_values_to_be_valid(arg)
})

test_that("Parsing a list argument takes into account the passed separator", {
  arg <- "first,second,third"
  expect_parsed_values_to_be_valid(arg, sep = ',')
})

test_that("Parsing a list argument trims whitespaces", {
  arg <- "first     ;    second;    third   "
  expect_parsed_values_to_be_valid(arg)
})

test_that("Parsing a list argument filters out invalid values", {
  arg <- "invalid;first;second;third;fourth;invalid"
  valid_values <- c('first', 'second', 'third')
  expect_parsed_values_to_be_valid(arg, valid_values = valid_values)
})

test_that("Parsing a list argument filters out empty values", {
  arg <- ";first;second;third;;;;;;"
  valid_values <- c('first', 'second', 'third')
  expect_parsed_values_to_be_valid(arg)
})
