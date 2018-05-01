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
  
  
  season_labels <- split_by_season(obs)
  seasons <- c('winter', 'spring', 'summer', 'autumn')
  for (season in seasons) {
    data <- obs[season_labels == season,]
    
    plot_path <- file.path(target_root_dir, paste(season, 'original.png', sep = '_'))
    save_line_plot(data, 'timestamp', 'pm2_5', plot_path,  paste('Original PM2.5 timeseries - ', season))
    plot_path <- file.path(target_root_dir,  paste(season, 'original_histogram.png', sep = '_'))
    save_histogram(data, 'pm2_5', plot_path)
    
    ts_seq <- generate_ts_by_season(season, 2017)
    imputed <- impute(data, ts_seq, imputation_count = 10, iters = 10)
    print(ts_seq)
    
    plot_path <- file.path(target_root_dir, paste(season, 'imputed.png', sep = '_'))
    save_line_plot(imputed, 'timestamp', 'pm2_5', plot_path,  paste('Imputed PM2.5 timeseries - ', season))
    plot_path <- file.path(target_root_dir,  paste(season, 'imputed_histogram.png', sep = '_'))
    save_histogram(imputed, 'pm2_5', plot_path)
  }
}
main()

