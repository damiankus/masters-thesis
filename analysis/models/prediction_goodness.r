require('RPostgreSQL')
require('ggplot2')
require('reshape')
require('caTools')
require('hydroGOF')
Sys.setenv(LANG = "en")

# Measure formulas are based on the article by Selva Prabhakaran
# Source: http://r-statistics.co/Linear-Regression.html
# The results object is a data frame with columns: 
# date - date of prediction
# actual - actual values from the test set
# predicted - values predicted by the model

# ---------------------------------------------
# Universal measures
# ---------------------------------------------

# Sum of Squares Error
sse <- function (results) {
  sum(results$residuals ^ 2)
}

# Mean Squared Error
mse <- function (results) {
  sse(results) / length(results$predicted)
}

# Sum Squared Total
sst <- function (results) {
  sum((results$actual - mean(results$actual)) ^ 2)
}

# Mean Squared Total
mst <- function (results) {
  sst(results) / (length(results$predicted) - 1)
}

# R squared
r_squared <- function(results) {
  1 - sse(results) / sst(results)
}

# Standard Error of the mean
se <- function (results) {
  sd(results$residuals) / sqrt(length(results$predicted))
}

# Index of Agreement
ia <- function (results) {
  hydroGOF::d(sim = results$predicted, obs = results$actual, na.rm = TRUE)
}

# Mean Absolute Error
mae <- function (results) {
  sum(abs(results$residuals)) / length(results$predicted)
}

# Mean Absolute Percentage Error
mape <- function (results) {
  100 / length(results$predicted) * sum(abs(results$residuals / results$actual))
}

# Maximum Absolute Percentage Error
maxpe <- function (results) {
  max(100 * abs(results$residuals / results$actual))
}

# Standard Error taking into consideration the number of coefficients
adj_se <- function (results, model) {
  sqrt( sse(results) / ( length(results) - length(model$coefficients) ))
}

prediction_goodness <- function (results) {
  results <- na.omit(results)
  hline <- '----------------------------------------------'
  paste(
    hline,
    ' Goodness of prediction',
    hline,
    paste(' MSE:', mse(results), sep = ' '),
    paste(' RMSE', sqrt(mse(results)), sep = ' '),
    paste(' MAE:', mae(results), sep = ' '),
    paste(' MAPE:', mape(results), sep = ' '),
    paste(' MAXPE:', maxpe(results), sep = ' '),
    paste(' Standard Error:', se(results), sep = ' '),
    paste(' R-squared:', r_squared(results), sep = ' '),
    paste(' Index of Agreement:', ia(results), sep = ' '),
    paste(' Prediction correlation (Pearson):', toString(
      cor(results[, c('actual', 'predicted')], use = 'complete.obs', method = c('pearson'))[1, 2],
    ), sep = ' '),
    hline, '\n',
  sep = '\n')
}

save_prediction_goodness <- function (results, model, file_path) {
  goodness <- prediction_goodness(results)
  
  print(summary(model))
  cat(goodness)
  
  s <- summary(model)
  capture.output(s, file = file_path)
  f <- file(file_path, open = 'a')
  write(paste('', goodness, sep = '\n'), f)
  close(f)
}
