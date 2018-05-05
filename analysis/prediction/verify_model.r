wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

source('models.r')

packages <- c(
  'RPostgreSQL', 'ggplot2', 'reshape',
  'caTools', 'glmnet', 'car',
  'leaps')
import(packages)

main <- function () {
  obs <- load_observations('observations',
                           variables = c('timestamp', 'pm2_5', 'temperature', 'season', 'wind_speed', 'precip_total', 'pressure', 'humidity'),
                           stations = c('looko2_60019400AB79'))
  
  target_root_dir <- getwd()
  response_vars <- c('pm2_5')
  future_lag <- 24
  prev_lag <- 8
  training_days <- 7 * 6
  test_days <- 7
  offset_days <- 7
  
  explanatory_vars <- colnames(obs)
  excluded <- c(response_vars, c('id', 'timestamp', 'station_id'))
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  models <- c(fit_svr)
  seasons <- c('winter', 'spring', 'summer', 'autumn')

  for (base_res_var in response_vars) {
    target_var_dir <- file.path(target_root_dir, base_res_var)
    mkdir(target_var_dir)
    
    for (season in seq(2, 4)) {
      target_season_dir <- file.path(target_var_dir, seasons[season])
      mkdir(target_season_dir)
      
      data <- obs[obs$season == season,]
      ts_seq <- generate_ts_by_season(season, 2017)
      ts_seq <- ts_seq[ts_seq >= min(data$timestamp) & ts_seq <= max(data$timestamp)]
      imputed <- impute_for_ts(data, ts_seq, imputation_count = 5, iters = 5)
      windows <- divide_into_windows(imputed, prev_lag, future_lag, vars = 'all',
                                     future_vars = c(base_res_var), excluded_vars = c('season'))
      
      # Actual response variable has the next_{lag} sufix
      res_var <- tail(colnames(windows), n = 1)
      explanatory_vars <- colnames(windows)
      explanatory_vars <- explanatory_vars[explanatory_vars != res_var]
      res_formula <- as.formula(paste(res_var, '~',
                                      paste(explanatory_vars, collapse = ' + '), sep = ' '))
      windows$timestamp <- as.POSIXct(windows$timestamp + 24 * 3600, origin = '1970-01-01 00:00', tz = 'UTC')
      
      training_count <- 24 * training_days
      test_count <- 24 * test_days
      offset_step <- 24 * offset_days
      total_obs <- 24 * floor(length(windows[, 1]) / 24)
      for (offset in seq(1, total_obs - (training_count + test_count), offset_step)) {
        target_dir <- file.path(target_season_dir, offset)
        mkdir(target_dir)

        last_training_idx <- offset + training_count - 1
        training_seq <- (offset):last_training_idx
        test_seq <- (last_training_idx + 1):(last_training_idx + test_count)
        
        training_set <- windows[training_seq, ]
        test_set <- windows[test_seq, ]
        
        data_split <- data.frame(windows[, c(base_res_var, 'timestamp')])
        data_split$type <- 'not used'
        data_split[training_seq, 'type'] <- 'training'
        data_split[test_seq, 'type'] <- 'test'
        
        plot_path <- file.path(target_season_dir, paste('data_split_', offset, '.png', sep = ''))
        save_multiple_vars_plot(data_split, id_var = c('type', 'timestamp'), measure_var = base_res_var, plot_path = plot_path)
        
        for (fit_model in models) {
          fit_model(res_formula, training_set, test_set, target_dir)
        }
      }
    }
  }
  
}
main()

