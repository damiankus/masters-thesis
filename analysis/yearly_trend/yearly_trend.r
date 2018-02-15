require('RPostgreSQL')
require('ggplot2')
require('reshape')
Sys.setenv(LANG = "en")

cap <- function (s) {
  s <- strsplit(s, ' ')[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = '', collapse = ' ')
}

save_boxplot <- function (df, factor, plot_path) {
  plot <- ggplot(data = df) +
    geom_boxplot(aes_string(x = 'date', y = factor)) +
    xlab('Date') +
    ylab(cap(factor)) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_lineplot <- function (df, factor, plot_path) {
  plot <- ggplot(data = df) +
    geom_line(aes_string(x = 'date', y = factor)) +
    xlab('Date') +
    ylab(cap(factor)) +
    scale_x_date(date_labels = "%b")
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
  table_name <- 'meteo_observations'
  query = paste('SELECT * FROM',
                 table_name,
                 sep = ' ')
  obs <- dbGetQuery(con, query)
  obs[,'date'] <- factor(as.Date(obs$timestamp))
  obs[,'month'] <- as.numeric(format(as.Date(obs$date), '%m'))
  factors <- c('temperature', 'pressure', 'humidity', 'wind_speed',
               'precip_total', 'precip_rate', 'solradiation')
  
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
      plot_path <- file.path(target_dir, paste(factor, '_', month, '.png', sep = ''))
      which <- obs[obs$month == month,]
      save_boxplot(which, factor, plot_path)
    }
  }
  
  stat_fun <- function (x, na.rm) {
    c(avg = mean(x, na.rm = na.rm), std = sd(x, na.rm = na.rm), samples = length(x))
  }

  target_dir <- file.path(target_root_dir, 'summary')    
  mkdir(target_dir)
  for (factor in factors) {
    # stats <- aggregate(obs[,factor], by = list(obs$full_hour), FUN = stat_fun, na.rm = TRUE)
    # write.csv(stats, file.path(target_dir, paste(factor, '_hourly.csv')))
    # stats <- aggregate(obs[,factor], by = list(obs$date), FUN = stat_fun, na.rm = TRUE)
    # write.csv(stats, file.path(target_dir, paste(factor, '_daily.csv')))
    
    stats <- as.data.frame(
      aggregate(obs[,factor], by = list(obs$date), FUN = mean, na.rm = TRUE))
    names(stats) <- c('date', factor)
    stats[,'date'] <- as.Date(stats$date)
    plot_path <- file.path(target_dir, paste(factor, '_yearly_trend.png', sep = ''))
    save_lineplot(stats, factor, plot_path)
  }
}
main()
