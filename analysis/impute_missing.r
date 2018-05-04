wd <- getwd()
setwd('common')
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
                           variables = c('timestamp', 'pm2_5', 'temperature', 'day_of_year', 'season'),
                           stations = c('airly_172'))
  target_root_dir <- file.path(getwd(), 'imputed')
  mkdir(target_root_dir)
  
  # Useful when loading all variables and removing
  # just those unwanted
  variables <- colnames(obs)
  excluded <- c('id', 'station_id')
  variables <- variables[!(variables %in% excluded)]
  obs <- obs[, variables]
  
  for (season in seq(3, 3)) {
    data <- obs[obs$season == season,]
    
    plot_path <- file.path(target_root_dir, paste(season, 'original.png', sep = '_'))
    save_line_plot(data, 'timestamp', 'pm2_5', plot_path,  paste('Original PM2.5 timeseries - ', season))
    
    ts_seq <- generate_ts_by_season(season, 2017)
    ts_seq <- ts_seq[ts_seq >= min(data$timestamp) & ts_seq <= max(data$timestamp)]
    imputed <- impute_for_ts(data, ts_seq, imputation_count = 5, iters = 5)
    
    plot_path <- file.path(target_root_dir, paste(season, 'imputed.png', sep = '_'))
    save_line_plot(imputed, 'timestamp', 'pm2_5', plot_path,  paste('Imputed PM2.5 timeseries - ', season))
  }
}
main()

