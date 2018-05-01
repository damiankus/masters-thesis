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
  obs <- load_observations('observations',
                           variables = c('timestamp', 'pm2_5', 'temperature', 'day_of_year'),
                           stations = c('airly_172'))
  target_root_dir <- file.path(getwd(), 'imputed')
  mkdir(target_root_dir)
  
  # Useful when loading all variables and removing
  # just those unwanted
  variables <- colnames(obs)
  excluded <- c('id', 'station_id')
  variables <- variables[!(variables %in% excluded)]
  obs <- obs[, variables]
  
  plot_path <- file.path(target_root_dir, 'original.png')
  save_line_plot(obs, 'timestamp', 'pm2_5', plot_path, 'Original PM2.5 timeseries')
  plot_path <- file.path(target_root_dir, 'original_histogram.png')
  save_histogram(obs, 'pm2_5', plot_path)
  
  imputed <- data.frame(colnames = colnames(obs))
  season_idx <- split_by_season(obs)
  season_dates <- c()
  for (season in seq(0, 3)) {
    data <- obs[season_idx == season,]
    data <- impute(obs, )
  }
  spring_day <- '03-21'
  summer_day <- '06-22'
  autumn_day <- '09-23'
  winter_day <- '12-22'
  # 
  # plot_path <- file.path(target_root_dir, 'imputed.png')
  # save_line_plot(imputed, 'timestamp', 'pm2_5', plot_path, 'Imputed PM2.5 timeseries')
  # plot_path <- file.path(target_root_dir, 'imputed_histogram.png')
  # save_histogram(imputed, 'pm2_5', plot_path)
}
main()

