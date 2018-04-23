source('utils.r')
source('preprocess.r')
import(c('ggplot2', 'reshape', 'car'))

# Based on http://r-statistics.co/Linear-Regression.html

save_comparison_plot <- function (df, res_var, plot_path) {
  melted <- melt(df, id = 'date')
  line_plot <- ggplot(data = melted, aes(x = date, y = value, colour = variable)) +
    geom_line() +
    xlab('Date') +
    ylab(cap(res_var)) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_scatter_plot <- function (df, res_var, plot_path) {
  scatter_plot <- ggplot(data = df, aes_string(x = 'actual', y = 'predicted')) +
    geom_point() +
    xlab('Actual') +
    ylab('Predicted') +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_scedascicity_plot <- function (df, res_var, plot_path) {
  std_df <- cbind(df)
  std_df$residuals <- standardize_vec(std_df$residuals)
  plot <- ggplot(data = df, aes_string(x = 'predicted', y = 'residuals')) +
    geom_point() +
    xlab('Predicted') +
    ylab('Standardized residuals') +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_multiple_vars_plot <- function (df, plot_path) {
  # Transform the data frame into mapping timestamp -> (variable name, value)
  melted <- melt(df, id.vars = 'timestamp')
  plot <- ggplot(data = melted, aes(x = timestamp, y = value, fill = variable)) +
    geom_bar(stat = 'identity') +
    xlab('Date') +
    ylab('Value')
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_histogram <- function (df, factor, plot_path, show_outlier_thr = FALSE) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  fact_col <- df[,factor]
  bw <- 2 * IQR(fact_col, na.rm = TRUE) / length(fact_col) ^ 0.33
  
  plot <- ggplot(data = df, aes_string(factor)) +
    geom_histogram(colour = 'white', fill = 'blue', binwidth = bw) +
    xlab(cap(
      paste(pretty_var(factor), '[', units(factor), ']', sep = ' '))) +
    ylab('Frequency')
  
  if (show_outlier_thr) {
    outlier_thresholds <- quantile(fact_col, c(.001, .98), na.rm = TRUE)
    plot <- plot +
      geom_vline(xintercept = outlier_thresholds[1]) +
      geom_vline(xintercept = outlier_thresholds[2])
  }
  
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_all_stats <- function (fit, test_set, results, res_var, model_name, target_dir, summary_funs) {
  target_dir <- file.path(target_dir, model_name)
  mkdir(target_dir)
  
  results$residuals <- results$predicted - results$actual
  model_desc_path <- file.path(target_dir, paste(res_var, model_name, 'prediction_goodness.txt', sep = '_'))
  save_prediction_goodness(results, fit, model_desc_path, summary_funs = summary_funs)
  
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'prediction.png', sep = '_'))
  lag <- tail(strsplit(res_var, '_')[[1]], n = 1)
  t_offset <- strtoi(lag, base = 10) * 60 * 60
  results$date = test_set$timestamp + t_offset
  save_comparison_plot(results[,c('date', 'actual', 'predicted')], res_var, plot_path)
  
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'prediction_bivariate.png', sep = '_'))
  save_scatter_plot(results, res_var, plot_path = plot_path)
  
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'residuals_distribution.png', sep = '_'))
  save_histogram(results, 'residuals', plot_path = plot_path)
  
  plot_path <- file.path(target_dir, paste(res_var, model_name, 'scedascicity.png', sep = '_'))
  save_scedascicity_plot(results, res_var, plot_path = plot_path)
}