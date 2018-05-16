source('utils.r')
source('preprocess.r')
import(c('ggplot2', 'reshape', 'car', 'scales'))

# Based on http://r-statistics.co/Linear-Regression.html

save_line_plot <- function(df, varx, vary, plot_path, title) {
  line_plot <- ggplot(data = df, aes_string(x = varx, y = vary)) +
    geom_line() +
    xlab(varx) +
    ylab(vary) +
    ggtitle(title) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_comparison_plot <- function (df, res_var, plot_path) {
  melted <- melt(df, id = 'timestamp')
  line_plot <- ggplot(data = melted, aes(x = timestamp, y = value, colour = variable)) +
    geom_line() +
    xlab('Date') +
    ylab(paste(pretty_var(res_var), units(res_var))) +
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

save_multiple_vars_plot <- function (df, res_var, id_var, plot_path) { 
  copy <- data.frame(df[, c('timestamp', res_var, id_var)])
  copy$timestamp <- as.POSIXlt(copy$timestamp, origin = '1970-01-01', tz = 'UTC')
  plot <- ggplot(data = copy, aes_string(x = 'timestamp', y = res_var, fill = id_var)) +
    geom_bar(stat = 'identity') +
    xlab('Date') +
    ylab(paste(pretty_var(res_var), units(res_var))) +
    scale_x_datetime(labels = date_format('%Y-%m-%d', tz = 'UTC'),
                     breaks = date_breaks('2 months'))
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
    outlier_thresholds <- quantile(fact_col, c(.01, .99), na.rm = TRUE)
    plot <- plot +
      geom_vline(xintercept = outlier_thresholds[1]) +
      geom_vline(xintercept = outlier_thresholds[2])
  }
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_data_split <- function (df, res_var, training_set, test_set, plot_path) {
  training_vals <- training_set[, c('timestamp', res_var)]
  training_vals$type <- 'training'
  test_vals <- test_set[, c('timestamp', res_var)]
  test_vals$type <- 'test'
  merged <- rbind(training_vals, test_vals)
  save_multiple_vars_plot(merged, res_var, id_var = 'type', plot_path = plot_path)
}