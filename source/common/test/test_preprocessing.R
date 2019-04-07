testwd <- getwd()
setwd('..')
source('utils.R')
source('preprocess.R')
setwd(testwd)

packages <- c('testthat')
import(packages)

# Loaded data frame will be stored in a variable called series
load(file = 'test_series.Rda')
numeric_cols <- colnames(series)[grepl('numeric', sapply(series, class))]
series <- series[, numeric_cols]

means <- apply(series, 2, mean)
sds <- apply(series, 2, sd)
mins <- apply(series, 2, min)
maxs <- apply(series, 2, max)
epsilon <- 1e-4
varname <- 'pm2_5'


test_that('Normalizing scales values to range > 0', {
  normalized <- normalize_with(series, mins, maxs)
  expect_true(all(apply(normalized, 1:2, function (i) { i > -epsilon })))
})

test_that('Normalizing scales values to < 1', {
  normalized <- normalize_with(series, mins, maxs)
  expect_true(all(apply(normalized, 1:2, function (i) { i < 1 + epsilon })))
})

test_that('Reversing normalization changes values to original ones', {
  normalized <- normalize_with(series, mins, maxs)
  original <- reverse_normalize_with(normalized, mins, maxs)
  expect_true(
    all(abs(series - original) < epsilon))
})

test_that('Reversing normalization for vector changes values to original ones', {
  normalized <- normalize_vec_with(series[, varname], mins[varname], maxs[varname])
  original <- reverse_normalize_vec_with(normalized, mins[varname], maxs[varname])
  expect_true(all(abs(series[, varname] - original) < epsilon))
})

test_that('Standardizing changes mean to 0', {
  standardized <- standardize_with(series, means, sds)
  expect_true(all(apply(standardized, 2, function (col) { abs(mean(col) - 0) < epsilon})))
})

test_that('Standardizing changes sd to 1', {
  standardized <- standardize_with(series, means, sds)
  expect_true(all(apply(standardized, 2, function (col) { abs(sd(col) - 1) < epsilon})))
})

test_that('Reversing standardization changes mean and sd to original values', {
  standardized <- standardize_with(series, means, sds)
  original <- reverse_standardize_with(standardized, means, sds)
  expect_true(
    all(abs(series - original) < epsilon))
})

test_that('Reversing standardization for vector changes mean and sd to original values', {
  standardized <- standardize_vec_with(series[, varname], means[varname], sds[varname])
  original <- reverse_standardize_vec_with(standardized, means[varname], sds[varname])
  expect_true(all(abs(series[, varname] - original) < epsilon))
})

