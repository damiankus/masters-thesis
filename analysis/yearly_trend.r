wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
setwd(wd)

packages <- c('RPostgreSQL', 'reshape', 'ggplot2')
import(packages)
Sys.setenv(LANG = "en")

save_boxplot <- function (df, factor, plot_path, title) {
  plot <- ggplot(data = df) +
    geom_boxplot(aes_string(x = 'date', y = factor)) +
    ggtitle(title) +
    xlab('Date') +
    ylab(cap(paste(pretty_var(factor), '[', units(factor),']', sep = ' '))) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_lineplot <- function (df, factor, plot_path) {
  plot <- ggplot(data = df) +
    geom_line(aes_string(x = 'date', y = factor)) +
    xlab('Date') +
    ylab(cap(
      paste(pretty_var(factor), '[', units(factor), ']', sep = ' '))) +
    scale_x_date(date_labels = "%b")
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_histogram <- function (df, factor, plot_path, title) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  fact_col <- df[,factor] 
  bw <- 2 * IQR(fact_col, na.rm = TRUE) / length(fact_col) ^ 0.33
  outlier_thresholds <- quantile(fact_col, c(0, .99), na.rm = TRUE)
  
  plot <- ggplot(data = df, aes_string(fact_col)) +
    geom_histogram(colour = 'white', fill = 'blue', binwidth = bw) +
    ggtitle(title) +
    geom_vline(xintercept = outlier_thresholds[1]) +
    geom_vline(xintercept = outlier_thresholds[2]) +
    xlab(cap(
      paste(pretty_var(factor), '[', units(factor), ']', sep = ' '))) +
    ylab('Frequency')
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

main <- function () {
  driver <- dbDriver('PostgreSQL')
  passwd <- { 'pass' }
  con <- dbConnect(driver, dbname = 'pollution',
                   host = 'localhost',
                   port = 5432,
                   user = 'damian',
                   password = passwd)
  rm(passwd)
  on.exit(dbDisconnect(con))
  
  # Fetch all observations
  # table_name <- 'observations'
  table_name <- 'meteo_observations'
  excluded <- c('id', 'station_id')
  query = paste('SELECT timestamp, temperature, pressure, solradiation FROM',
                 table_name,
                # "WHERE station_id = 'airly_172'",
                 sep = ' ')
  obs <- dbGetQuery(con, query)
  obs <- obs[, !(colnames(obs) %in% excluded)]
  obs[,'date'] <- factor(as.Date(obs$timestamp))
  obs[,'month'] <- as.numeric(format(as.Date(obs$date), '%m'))
  factors <- colnames(obs)
  factors <- factors[!(factors %in% c('timestamp', 'date', 'month'))]
  month_names <- c('January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December')
  
  target_root_dir <- file.path(getwd(), 'trend')
  mkdir(target_root_dir)
  target_root_dir <- file.path(target_root_dir, strsplit(table_name, '_')[[1]][1])
  mkdir(target_root_dir)
  target_dir <- file.path(target_root_dir, 'summary')
  mkdir(target_dir)
  
  for (factor in factors) {
    target_dir <- file.path(target_root_dir, factor)
    mkdir(target_dir)
    
    for (month in seq(1, 12)) {
      which <- obs[obs$month == month,]
      plot_name <- paste(factor, '_', month, '.png', sep = '')
      # plot_path <- file.path(target_dir, plot_name)
      # title <- paste(pretty_var(factor), '  during ', month_names[month])
      # save_boxplot(which, factor, plot_path, title)
      plot_name <- paste('histogram', plot_name, sep = '_')
      plot_path <- file.path(target_dir, plot_name)
      title <- paste('Distribution of ', pretty_var(factor), ' during ', month_names[month])
      save_histogram(which, factor, plot_path, title)
    }
  }
  
  # stat_fun <- function (x, na.rm) {
  #   c(avg = mean(x, na.rm = na.rm), std = sd(x, na.rm = na.rm), samples = length(x))
  # }
  # 
  # target_dir <- file.path(target_root_dir, 'summary')
  # mkdir(target_dir)
  # for (factor in factors) {
  #   stats <- as.data.frame(
  #     aggregate(obs[,factor], by = list(obs$date), FUN = mean, na.rm = TRUE))
  #   names(stats) <- c('date', factor)
  #   stats[,'date'] <- as.Date(stats$date)
  #   plot_path <- file.path(target_dir, paste(factor, '_yearly_trend.png', sep = ''))
  #   save_lineplot(stats, factor, plot_path)
  # }
}
main()
