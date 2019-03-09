source('utils.R')
source('constants.R')
source('preprocess.R')
packages <- c('ggplot2', 'reshape', 'car', 'scales', 'ggthemes', 'moments') 
import(packages)

Sys.setlocale("LC_ALL", 'en_GB.UTF-8')
Sys.setenv(LANG = "en_US.UTF-8")

save_plot_file <- function (plot, plot_path, width = 6, height = 4) {
  ggsave(plot_path, width = width, height = height)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

# Based on http://r-statistics.co/Linear-Regression.html
save_line_plot <- function(df, var_x, var_y, plot_path, title) {
  plot <- ggplot(data = df, aes_string(x = var_x, y = var_y)) +
    geom_line() +
    xlab(get_or_generate_label(var_x)) +
    ylab(get_or_generate_label(var_y)) +
    ggtitle(title) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  save_plot_file(plot, plot_path)
}

save_comparison_plot <- function (df, res_var, plot_path, hour_units = 1) {
  # If the observations are separated by a period
  # longer than a week, we plot them with two charts 
  # to skip the missing values and thus save the space
  
  df$group <- c(0, cumsum(diff(df$timestamp) > hour_units * 24 * 7))
  melted <- melt(df, id = c('timestamp', 'group'))
  plot <- ggplot(data = melted, aes(x = timestamp, y = value, colour = variable)) +
    geom_line() +
    facet_grid(~ group, scales = 'free_x', space = 'free_x') +
    xlab('Date') +
    ylab(get_or_generate_label(res_var)) +
    scale_x_datetime(labels = date_format('%Y-%m-%d', tz = 'UTC'),
                     breaks = date_breaks('1 week')) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  save_plot_file(plot, plot_path)
}

save_scatter_plot <- function (df, res_var, plot_path) {
  plot <- ggplot(data = df, aes_string(x = 'actual', y = 'predicted')) +
    geom_point() +
    geom_smooth(method = lm, se = FALSE, size = 1, color = hcl(h = 225, l = 65, c = 100)) +
    geom_abline(slope = 1, size = 1, color = hcl(h = 15, l = 65, c = 100)) +
    xlab('actual') +
    ylab('predicted') +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  save_plot_file(plot, plot_path)
}

save_scedascicity_plot <- function (df, res_var, plot_path) {
  std_df <- cbind(df)
  std_df$residuals <- standardize_vec(std_df$residuals)
  plot <- ggplot(data = df, aes_string(x = 'predicted', y = 'residuals')) +
    geom_point() +
    xlab('predicted') +
    ylab('standardized residuals') +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  save_plot_file(plot, plot_path)
}

save_goodness_plot <- function (df, x_var, y_var, id_var, x_order, plot_path, x_lab = '', y_lab = '', title = '') {
  if (nchar(x_lab) == 0) {
    x_lab <- get_pretty_var(x_var)
  }
  if (nchar(y_lab) == 0) {
    y_lab <- get_pretty_var(y_var)
  }
  plot <- ggplot(data = df, aes_string(x = x_var, y = y_var, colour = id_var, fill = id_var)) +
    geom_bar(position = 'dodge', stat = 'identity') +
    xlab(get_or_generate_label(var_x, x_lab)) +
    ylab(get_or_generate_label(var_y, y_lab)) + 
    scale_x_discrete(limits = x_order)
  save_plot_file(plot_path)
}

save_multiple_vars_plot <- function (df, x_var, y_var, id_var, plot_path, x_lab = '', y_lab = '', breaks = '4 months') { 
  copy <- data.frame(df[, c(x_var, y_var, id_var)])
  
  # After passing timestamps to forecasting models,
  # they may be cast to numeric values
  timestamp_present <- grepl('timestamp', x_var)
  if (timestamp_present) {
    copy$timestamp <- as.POSIXlt(copy$timestamp, origin = '1970-01-01', tz = 'UTC')
  }
  
  if (nchar(x_lab) == 0) {
    x_lab <- get_pretty_var(x_var)
  }
  if (nchar(y_lab) == 0) {
    y_lab <- get_pretty_var(y_var)
  }
  
  plot <- ggplot(data = copy, aes_string(x = x_var, y = y_var, colour = id_var, fill = id_var)) +
    geom_line() +
    xlab(get_or_generate_label(var_x, x_lab)) +
    ylab(get_or_generate_label(var_y, y_lab)) + 
    theme(legend.position='none')
  
  if (timestamp_present) {
    plot <- plot +
      scale_x_datetime(labels = date_format('%Y-%m-%d', tz = 'UTC'),
                       breaks = date_breaks(breaks))
  }
  save_plot_file(plot, plot_path)
}

save_multi_facet_plot <- function (df, x_var, y_var, id_var, plot_path,
                                   x_lab='', y_lab='', legend_title='', plot_component = geom_line(size=0.5)) {
  copy <- data.frame(df[, c(x_var, y_var, id_var)])
  
  # After passing timestamps to forecasting models,
  # they may be cast to numeric values
  timestamp_present <- FALSE
  if (grepl('timestamp', x_var)) {
    copy$timestamp <- utcts(copy$timestamp)
    timestamp_present <- TRUE
  }
  
  if (nchar(x_lab) == 0) {
    x_lab <- get_pretty_var(x_var)
  }
  if (nchar(y_lab) == 0) {
    y_lab <- get_pretty_var(y_var)
  }
  if (nchar(legend_title) == 0) {
    legend_title <- paste(strsplit(id_var, '_')[[1]], collapse = ' ')
  }
  
  facet_formula <- as.formula(paste('~', id_var))
  plot <- ggplot(data = copy, aes_string(x = x_var, y = y_var, colour = id_var, fill = id_var)) +
    plot_component +
    xlab(get_or_generate_label(x_var, x_lab)) +
    ylab(get_or_generate_label(y_var)) + 
    labs(color = legend_title) +
    theme(legend.position='none') +
    facet_wrap(facet_formula, scales = 'free_y', ncol = 1)
  save_plot_file(plot, plot_path)
}

save_histogram <- function (df, var, plot_path, show_stats_lines=TRUE) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  var_col <- na.omit(df[, var])
  
  # originally the exponent is equal to 0.33 but it
  # resulted in too narrow bins
  bw <- 2 * IQR(var_col) / length(var_col) ^ 0.2
  hist_color <- COLORS[1]
  # It's a darker version of the standard blue colour used by ggplot
  density_color <- COLOR_ACCENT
  
  plot <- ggplot(data = df, aes_string(x=var, y='..density..', fill=var)) +
    geom_histogram(color=hist_color, fill=hist_color, alpha=0.3, binwidth=bw) +
    geom_density(color=density_color, size=0.5) + 
    xlab(get_or_generate_label(var)) +
    ylab('Density')
  save_plot_file(plot, plot_path)
}

save_data_split <- function (res_var, training_set, test_set, plot_path, breaks='4 months') {
  training_vals <- training_set[, c('timestamp', res_var)]
  training_vals$type <- 'training'
  test_vals <- test_set[, c('timestamp', res_var)]
  test_vals$type <- 'test'
  merged <- rbind(training_vals, test_vals)
  xlab <- 'Date'
  save_multiple_vars_plot(merged, 'timestamp', res_var, id_var = 'type', plot_path = plot_path,
                          x_lab = xlab, breaks = breaks)
}

save_boxplot <- function (df, var_x, var_y, plot_path, x_order, show_outliers=TRUE) {
  outlier_alpha = if (show_outliers) 0.1 else 0
  plot <- ggplot(df, aes_string(x=var_x, y=var_y, fill=var_x)) +
    geom_boxplot(aes_string(group=var_x), outlier.alpha=outlier_alpha) + 
    xlab(get_or_generate_label(var_x)) +
    ylab(get_or_generate_label(var_y)) + 
    scale_x_discrete(limits = x_order) +
    theme(legend.position='none')

  if (!show_outliers) {
    min_idx <- 1
    max_idx <- 5
    y_lim <- boxplot.stats(series$pm2_5)$stats[c(min_idx, max_idx)]
    plot <- plot + coord_cartesian(ylim=(y_lim * 1.1))
  }
  save_plot_file(plot, plot_path)
}
