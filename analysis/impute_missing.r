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
                           variables = c('timestamp', 'pm2_5', 'temperature', 'day_of_year', 'season', 'wind_speed', 'precip_total'),
                           stations = c('looko2_60019400AB79'))
  target_root_dir <- file.path(getwd(), 'imputed')
  mkdir(target_root_dir)
  
  # Useful when loading all variables and removing
  # just those unwanted
  variables <- colnames(obs)
  excluded <- c('id', 'station_id')
  variables <- variables[!(variables %in% excluded)]
  obs <- obs[, variables]
  
  for (season in seq(4, 4)) {
    data <- obs[obs$season == season,]

    plot_path <- file.path(target_root_dir, paste(season, 'original.png', sep = '_'))
    save_line_plot(data, 'timestamp', 'pm2_5', plot_path,  paste('Original PM2.5 timeseries - ', season))

    ts_seq <- generate_ts_by_season(season, 2017)
    ts_seq <- ts_seq[ts_seq >= min(data$timestamp) & ts_seq <= max(data$timestamp)]
    imputed <- impute_for_ts(data, ts_seq, imputation_count = 5, iters = 5)

    plot_path <- file.path(target_root_dir, paste(season, 'imputed.png', sep = '_'))
    windows <- divide_into_windows(imputed, 5, 24)
    day_split <- split_with_day_ratio(windows, 0.75)
    training_set <- windows[day_split,]
    test_set <- windows[!day_split,]
    
    training_count <- 24 * 7 * 3
    test_count <- 24
    offset_step <- 24 * 7
    total_obs <- 24 * floor(length(windows[, 1]) / 24)
    for (offset in seq(1, total_obs - (training_count + test_count), offset_step)) {
      last_training_idx <- offset + training_count - 1
      training_set <- windows[(offset):last_training_idx, ]
      test_set <- windows[(last_training_idx + 1):(last_training_idx + test_count), ]
      print(length(training_set[,1]))
      print(length(test_set[,1]))
    }
    
    save_line_plot(imputed, 'timestamp', 'pm2_5', plot_path,  paste('Imputed PM2.5 timeseries - ', season))
  }
}
main()

