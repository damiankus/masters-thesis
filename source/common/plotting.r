source('utils.r')
source('preprocess.r')
import(c('ggplot2', 'reshape', 'car', 'scales'))

# Based on http://r-statistics.co/Linear-Regression.html

save_line_plot <- function(df, var_x, var_y, plot_path, title) {
  line_plot <- ggplot(data = df, aes_string(x = var_x, y = var_y)) +
    geom_line() +
    xlab(var_x) +
    ylab(var_y) +
    ggtitle(title) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_comparison_plot <- function (df, res_var, plot_path, hour_units = 1) {
  # If the observations are separated by a period
  # longer than a week, we plot them with two charts 
  # to skip the missing values and thus save the space
  
  df$group <- c(0, cumsum(diff(df$timestamp) > hour_units * 24 * 7))
  melted <- melt(df, id = c('timestamp', 'group'))
  line_plot <- ggplot(data = melted, aes(x = timestamp, y = value, colour = variable)) +
    geom_line() +
    facet_grid(~ group, scales = 'free_x', space = 'free_x') +
    xlab('Date') +
    ylab(paste(pretty_var(res_var), ' [', units(res_var), ']', sep = '')) +
    scale_x_datetime(labels = date_format('%Y-%m-%d', tz = 'UTC'),
                     breaks = date_breaks('1 week')) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_scatter_plot <- function (df, res_var, plot_path) {
  scatter_plot <- ggplot(data = df, aes_string(x = 'actual', y = 'predicted')) +
    geom_point() +
    geom_smooth(method = lm, se = FALSE, size = 1, color = hcl(h = 225, l = 65, c = 100)) +
    geom_abline(slope = 1, size = 1, color = hcl(h = 15, l = 65, c = 100)) +
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

save_goodness_plot <- function (df, x_var, y_var, id_var, x_order, plot_path, x_lab = '', y_lab = '', title = '') {
  if (nchar(x_lab) == 0) {
    x_lab <- pretty_var(x_var)
  }
  if (nchar(y_lab) == 0) {
    y_lab <- pretty_var(y_var)
  }
  plot <- ggplot(data = df, aes_string(x = x_var, y = y_var, colour = id_var, fill = id_var)) +
    geom_bar(position = 'dodge', stat = 'identity') +
    xlab(x_lab) +
    ylab(y_lab) + 
    scale_x_discrete(limits = x_order)
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_multiple_vars_plot <- function (df, x_var, y_var, id_var, plot_path, x_lab = '', y_lab = '', breaks = '4 months', font_size = 24) { 
  copy <- data.frame(df[, c(x_var, y_var, id_var)])
  
  # After passing timestamps to forecasting models,
  # they may be cast to numeric values
  timestamp_present <- FALSE
  if (grepl('timestamp', x_var)) {
    copy$timestamp <- as.POSIXlt(copy$timestamp, origin = '1970-01-01', tz = 'UTC')
    timestamp_present <- TRUE
  }
  
  if (nchar(x_lab) == 0) {
    x_lab <- pretty_var(x_var)
  }
  if (nchar(y_lab) == 0) {
    y_lab <- pretty_var(y_var)
  }
  
  plot <- ggplot(data = copy, aes_string(x = x_var, y = y_var, colour = id_var, fill = id_var)) +
    geom_line() +
    xlab(x_lab) +
    ylab(y_lab) +
    theme(text = element_text(size = font_size))
  
  if (timestamp_present) {
    plot <- plot +
      scale_x_datetime(labels = date_format('%Y-%m-%d', tz = 'UTC'),
                       breaks = date_breaks(breaks))
  }
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_multi_facet_plot <- function (df, x_var, y_var, id_var, plot_path, x_lab = '', y_lab = '', legend_title = '', date_breaks = '3 months', font_size = 24) { 
  copy <- data.frame(df[, c(x_var, y_var, id_var)])
  
  # After passing timestamps to forecasting models,
  # they may be cast to numeric values
  timestamp_present <- FALSE
  if (grepl('timestamp', x_var)) {
    copy$timestamp <- utcts(copy$timestamp)
    timestamp_present <- TRUE
  }
  
  if (nchar(x_lab) == 0) {
    x_lab <- pretty_var(x_var)
  }
  if (nchar(y_lab) == 0) {
    y_lab <- pretty_var(y_var)
  }
  if (nchar(legend_title) == 0) {
    legend_title <- paste(strsplit(id_var, '_')[[1]], collapse = ' ')
  }
  
  facet_formula <- as.formula(paste('~', id_var))
  plot <- ggplot(data = copy, aes_string(x = x_var, y = y_var, colour = id_var, fill = id_var)) +
    geom_line() +
    xlab(x_lab) +
    ylab(y_lab) +
    labs(color = legend_title) + 
    facet_wrap(facet_formula, scales = 'free_y', ncol = 1) +
    theme(text = element_text(size = font_size))
  
  if (timestamp_present) {
    plot <- plot +
      scale_x_datetime(labels = date_format('%Y-%m-%d', tz = 'UTC'),
                       breaks = date_breaks(date_breaks))
  }
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_histogram <- function (df, factor, plot_path, show_outlier_thr = FALSE) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  df <- data.frame(df)
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

save_data_split <- function (res_var, training_set, test_set, plot_path, breaks = '4 months', font_size = 24) {
  training_vals <- training_set[, c('timestamp', res_var)]
  training_vals$type <- 'training'
  test_vals <- test_set[, c('timestamp', res_var)]
  test_vals$type <- 'test'
  merged <- rbind(training_vals, test_vals)
  ylab <- paste(pretty_var(res_var), ' [', units(res_var), ']', sep = '')
  xlab <- 'Date'
  save_multiple_vars_plot(merged, 'timestamp', res_var, id_var = 'type', plot_path = plot_path,
                          x_lab = xlab, y_lab = ylab, breaks = breaks, font_size = font_size)
}