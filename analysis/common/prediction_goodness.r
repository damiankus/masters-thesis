source('utils.r')
source('plotting.r')
import(c('hydroGOF'))

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
    paste(' Index of Agreement:', ia(results), sep = ' '),
    paste(' Coefficient of Determination ^ 2 (Pearson):', toString(
      (cor(results[, c('actual', 'predicted')],
          use = 'complete.obs',
          method = c('pearson'))[1, 2]
      ) ^ 2
    ), sep = ' '),
    hline, '\n',
  sep = '\n')
}

save_summary <- function(model, results, file_path, summary_funs = c(summary)) {
  if (file.exists(file_path)) {
    file.remove(file_path)
  }
  sapply(summary_funs, function (fun) {
    capture.output(fun(model), file = file_path, append = TRUE)
  })
}

save_prediction_goodness <- function (results, file_path) {
  results$residuals <- results$predicted - results$actual
  goodness <- prediction_goodness(results)
  cat(goodness)
  
  f <- file(file_path, open = 'a')
  write(paste('', goodness, sep = '\n'), f)
  close(f)
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

skip_colinear_variables <- function (res_formula, df, model = NA) {
  if (is.na(model)) {
    model <- lm(formula = res_formula, data = df)
  }
  lin_dep <- attributes(alias(model)$Complete)$dimnames[[1]]
  vars <- all.vars(res_formula)
  explanatory <- vars[1:length(vars)]
  explanatory <- explanatory[!(explanatory %in% lin_dep)]
  as.formula(paste(vars[1], '~', paste(explanatory, collapse = '+'), sep = ' '))
} 
