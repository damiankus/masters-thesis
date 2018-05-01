wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c(
  'RPostgreSQL', 'mice')
import(packages)

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
  target_root_dir <- file.path(getwd(), 'imputed')
  mkdir(target_root_dir)
  table <- 'observations'
  variables <- c('timestamp', 'pm2_5', 'temperature', 'day_of_year')
  query = paste('SELECT', paste(variables, collapse = ','),
                'FROM', table,
                "WHERE station_id = 'airly_171'",
                sep = ' ')
  obs <- dbGetQuery(con, query)
  
  # Useful when loading all variables and removing
  # just those unwanted
  variables <- colnames(obs)
  excluded <- c('id', 'station_id')
  variables <- variables[!(variables %in% excluded)]
  obs <- obs[, variables]
  season_idx <- split_by_season(obs)
  
  
  plot_path <- file.path(target_root_dir, 'original.png')
  save_line_plot(obs, 'timestamp', 'pm2_5', plot_path, 'Original PM2.5 timeseries')
  plot_path <- file.path(target_root_dir, 'original_histogram.png')
  save_histogram(obs, 'pm2_5', plot_path)
  
  imputed <- impute(obs, from_date = '2017-05-01 00:00', to_date = '2017-08-31 23:00')
  plot_path <- file.path(target_root_dir, 'imputed.png')
  save_line_plot(imputed, 'timestamp', 'pm2_5', plot_path, 'Imputed PM2.5 timeseries')
  plot_path <- file.path(target_root_dir, 'imputed_histogram.png')
  save_histogram(imputed, 'pm2_5', plot_path)
  
  # year_seq <- seq(from = as.POSIXct('2017-01-01 00:00', tz = 'UTC'),
  #                 to = as.POSIXct('2017-12-31 23:00', tz = 'UTC'),
  #                 by = 'hour')
  # window_width <- 8
  # win <- window(year_seq)
}
main()

