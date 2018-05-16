source('utils.r')
source('plotting.r')
import(c('hydroGOF'))

packages <- c('xtable', 'knitr')
import(packages)

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

# Root Mean Square Error
rmse <- function (results) {
  sqrt(mse(results))
}

# Sum Squared Total
sst <- function (results) {
  sum((results$actual - mean(results$actual)) ^ 2)
}

# Mean Squared Total
mst <- function (results) {
  sst(results) / (length(results$predicted) - 1)
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
  hydroGOF::mae(sim = results$predicted, obs = results$actual, na.rm = TRUE)
}

# Coefficient of determination
r2 <- function (results) {
  (cor(results[, c('actual', 'predicted')],
       use = 'complete.obs',
       method = c('pearson'))[1, 2]
  ) ^ 2
} 

nrmse <- function (results) {
  hydroGOF::nrmse(sim = results$predicted, obs = results$actual, na.rm = TRUE)
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

calc_prediction_goodness <- function (results, model_name) {
  results$residuals <- results$predicted - results$actual
  measures <- c('mse', 'rmse', 'mae', 'mape', 'maxpe', 'se', 'ia', 'r2')
  goodness <- data.frame(model = model_name)
  goodness <- cbind(goodness, t(sapply(measures, function (meas) { get(meas)(results) })))
  goodness
}

save_prediction_goodness <- function (goodness, file_path) {
  goodness <- goodness[order(goodness$rmse), ]
  colnames(goodness) <- sapply(colnames(goodness), toupper)
  pretty <- knitr::kable(goodness)
  write(pretty, file = file_path, append = TRUE)
  write('\r\n', file = file_path, append = TRUE)
}

save_summary <- function(model, results, file_path, summary_funs = c(summary)) {
  if (file.exists(file_path)) {
    file.remove(file_path)
  }
  sapply(summary_funs, function (fun) {
    capture.output(fun(model), file = file_path, append = TRUE)
  })
}


# This method accepts a @results parameter of the following form 
# @resuts: $timestamp, $actual, $predicted
save_prediction_comparison <- function (results, res_var, model_name, target_dir) {
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'prediction.png', sep = '_'))
  save_comparison_plot(results, res_var, plot_path)
  
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'prediction_bivariate.png', sep = '_'))
  save_scatter_plot(results, res_var, plot_path = plot_path)
  
  results$residuals <- results$predicted - results$actual
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'residuals_distribution.png', sep = '_'))
  save_histogram(results, 'residuals', plot_path = plot_path)
  
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'scedascicity.png', sep = '_'))
  save_scedascicity_plot(results, res_var, plot_path = plot_path)
}
