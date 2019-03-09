wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
setwd(wd)

packages <- c('RPostgreSQL', 'reshape', 'ggplot2')
import(packages)
Sys.setenv(LANG = "en")


save_bars_plot <- function (df, factor, plot_path, title) {
  plot <- ggplot(data = df) +
    geom_bar(aes_string(x = 'timestamp', y = factor), stat = 'identity') +
    ggtitle(title) +
    xlab('Timestamp') + 
    ylab( cap( paste(get_pretty_var(factor), '[', units(factor), ']', sep = ' ')))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_line_plot <- function (df, factor, plot_path, title) {
  plot <- ggplot(data = df, aes_string(x = 'timestamp', y = factor)) +
    geom_line() +
    ggtitle(title) +
    geom_area(fill = 'lightblue') +
    xlab('Timestamp') + 
    ylab(paste('Missing', get_pretty_var(factor), 'values', sep = ' ')) +
    scale_x_datetime(date_breaks = '24 hours') +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
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
  table_name <- 'observations'
  # table_name <- 'meteo_observations'
  excluded <- c('id', 'station_id')
  query = paste('SELECT * FROM',
                 table_name,
                "WHERE station_id = 'gios_krasinskiego'",
                 sep = ' ')
  obs <- dbGetQuery(con, query)
  obs <- obs[, !(colnames(obs) %in% excluded)]
  
  factors <- c('pm2_5', 'temperature', 'wind_speed', 'wind_dir_deg', 'pressure', 'humidity')
  factors <- factors[!(factors %in% c('timestamp', 'date', 'month'))]
  month_names <- c('January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December')
  
  obs$timestamp <- as.POSIXct(obs$timestamp, tz = 'UTC')
  target_root_dir <- file.path(getwd(), 'no-observations')
  mkdir(target_root_dir)
  target_root_dir <- file.path(target_root_dir, strsplit(table_name, '_')[[1]][1])
  mkdir(target_root_dir)
  year_seq <- seq(from = as.POSIXct('2017-01-01 00:00', tz = 'UTC'),
                  to = as.POSIXct('2017-12-31 23:00', tz = 'UTC'),
                  by = 'hour')
  
  for (factor in factors) {
    target_dir <- file.path(target_root_dir, factor)
    mkdir(target_dir)
    
    which.present <- which(!is.na(obs[, factor]))
    present_ts <- obs[which.present, 'timestamp']
    missing_ts <- as.POSIXct(c(setdiff(year_seq, present_ts)), origin = '1970-01-01', tz = 'UTC')
    missing_obs <- data.frame(year_seq, rep(0, length(year_seq)))
    colnames(missing_obs) <- c('timestamp', factor)
    missing_idx <- missing_obs$timestamp %in% missing_ts
    missing_obs[missing_idx, factor] <- 1
    missing_obs$month <- sapply(missing_obs$timestamp, function (x) {
      as.POSIXlt(x, origin = '1970-01-01', tz = 'UTC')$mon + 1 
      })    
    
    for (month in seq(1, 12)) {
      which <- missing_obs[missing_obs$month == month,]
      plot_name <- paste(factor, '_', month, '.png', sep = '')
      plot_path <- file.path(target_dir, plot_name)
      title <- paste('Time points with missing values of', get_pretty_var(factor), ' during', month_names[month], sep = ' ')
      save_line_plot(which, factor, plot_path, title)
    }
  }
}
main()
