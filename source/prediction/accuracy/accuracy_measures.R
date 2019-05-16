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
sse <- function(results) {
  sum((results$predicted - results$actual)^2)
}

# Mean Squared Error
mse <- function(results) {
  sse(results) / nrow(results)
}

# Root Mean Squared Error
rmse <- function(results) {
  sqrt(mse(results))
}

# Mean Absolute Error
mae <- function(results) {
  sum(abs(results$actual - results$predicted)) / (nrow(results)) 
}

# Sum Squared Total
sst <- function(results) {
  sum((results$actual - mean(results$actual))^2)
}

# Coefficient of determination
r2 <- function(results) {
  1 - sse(results) / sst(results)
}

# Mean Absolute Percentage Error
mape <- function(results) {
  non_zero_actual <- results$actual
  non_zero_actual[non_zero_actual == 0] <- 1e-7
  (100 / nrow(results)) * sum(abs(results$actual - results$predicted) / non_zero_actual)
}
