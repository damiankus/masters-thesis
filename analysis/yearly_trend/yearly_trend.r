require('RPostgreSQL')
require('ggplot2')
require('reshape')
Sys.setenv(LANG = "en")

cap <- function (s) {
  s <- strsplit(s, ' ')[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = '', collapse = ' ')
}

units <- function (var) {
  switch(var,
         temperature = '°C',
         humidity = '%',
         pressure = 'hPa',
         wind_speed = 'm/s',
         wind_dir_deg = '°',
         precip_total = 'mm',
         precip_rate = 'mm/h',
         {
           if (grepl('^pm', var)) {
             'μg/m³'
           } else {
             ''
           }
         })
}

pretty_var <- function (var) {
  switch(var,
         pm1 = 'PM1', pm2_5 = 'PM2.5', pm10 = 'PM10', solradiation = 'Solar irradiance', wind_speed = 'wind speed',
         wind_dir = 'wind direction', wind_dir_deg = 'wind direction',
         {
           delim <- ' '
           join_str <- ' ' 
           if (grepl('plus', var)) {
             delim <- '_plus_'
             join_str <- '+'
           } else if (grepl('minus', var)) {
             delim <- '_minus_'
             join_str <- '-'
           }     
           split_var <- strsplit(var, delim)[[1]]
           pvar <- split_var[1]
           if (length(split_var) > 1) {
             pvar <- pretty_var(pvar)
             pvar <- paste(pvar, 'at t', join_str, split_var[2], 'h', sep = ' ')
           }
           pvar
         })
}

save_boxplot <- function (df, factor, plot_path) {
  plot <- ggplot(data = df) +
    geom_boxplot(aes_string(x = 'date', y = factor)) +
    xlab('Date') +
    ylab(cap(
      paste(pretty_var(factor), '[', units(factor),']', sep = ' '))) +
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

save_histogram <- function (df, factor, plot_path) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  fact_col <- df[,factor] 
  bw <- 2 * IQR(fact_col, na.rm = TRUE) / length(fact_col) ^ 0.33
  outlier_thresholds <- quantile(fact_col, c(.001, .968), na.rm = TRUE)
  
  plot <- ggplot(data = df, aes_string(fact_col)) +
    geom_histogram(colour = 'white', fill = 'blue', binwidth = bw) +
    geom_vline(xintercept = outlier_thresholds[1]) +
    geom_vline(xintercept = outlier_thresholds[2]) +
    xlab(cap(
      paste(pretty_var(factor), '[', units(factor), ']', sep = ' '))) +
    ylab('Frequency')
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

mkdir <- function (path) {
  if (!dir.exists(path)) {
    dir.create(path, showWarnings = TRUE)
  }
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
  # factors <- c('pm1', 'pm2_5', 'pm10', 'temperature',
  #              'humidity', 'pressure')
  # 
  table_name <- 'meteo_observations'
  factors <- c('temperature', 'pressure', 'humidity', 'wind_speed',
               'precip_total', 'precip_rate', 'solradiation')
  query = paste('SELECT * FROM',
                 table_name,
                 sep = ' ')
  obs <- dbGetQuery(con, query)
  obs[,'date'] <- factor(as.Date(obs$timestamp))
  obs[,'month'] <- as.numeric(format(as.Date(obs$date), '%m'))
  
  target_root_dir <- getwd()
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
      # save_boxplot(which, factor, plot_path)
      plot_name <- paste('histogram', plot_name, sep = '_')
      plot_path <- file.path(target_dir, plot_name)
      save_histogram(which, factor, plot_path)
    }
  }
  
  # stat_fun <- function (x, na.rm) {
  #   c(avg = mean(x, na.rm = na.rm), std = sd(x, na.rm = na.rm), samples = length(x))
  # }
  # 
  # target_dir <- file.path(target_root_dir, 'summary')
  # mkdir(target_dir)
  # for (factor in factors) {
  #   # stats <- aggregate(obs[,factor], by = list(obs$full_hour), FUN = stat_fun, na.rm = TRUE)
  #   # write.csv(stats, file.path(target_dir, paste(factor, '_hourly.csv')))
  #   # stats <- aggregate(obs[,factor], by = list(obs$date), FUN = stat_fun, na.rm = TRUE)
  #   # write.csv(stats, file.path(target_dir, paste(factor, '_daily.csv')))
  # 
  #   stats <- as.data.frame(
  #     aggregate(obs[,factor], by = list(obs$date), FUN = mean, na.rm = TRUE))
  #   names(stats) <- c('date', factor)
  #   stats[,'date'] <- as.Date(stats$date)
  #   plot_path <- file.path(target_dir, paste(factor, '_yearly_trend.png', sep = ''))
  #   save_lineplot(stats, factor, plot_path)
  # }
}
main()
