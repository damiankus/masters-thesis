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
Sys.setenv(LANG = 'en')

main <- function () {
  obs <- load_observations('observations',
                           variables = c('timestamp', 'pm2_5', 'wind_speed', 'pressure',
                                         'humidity',
                                         'temperature', 'day_of_week', 'is_holiday',
                                         'day_of_year', 'season', 'wind_dir_deg'),
                           stations = c('looko2_60019400AB79'))
  
  response_vars <- c('pm2_5')
  future_lag <- 24
  prev_lag <- 8
  training_days <- 7 * 10
  test_days <- 7
  offset_days <- 7
  
  explanatory_vars <- colnames(obs)
  excluded <- c(response_vars, c('id', 'timestamp', 'station_id'))
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  seasons <- c('winter', 'spring', 'summer', 'autumn')
  pred_models <- c(mlr = fit_mlr, log_mlr = fit_log_mlr, svr = fit_svr)

  for (base_res_var in response_vars) {
    var_dir <- file.path(getwd(), base_res_var)
    mkdir(var_dir)
    
    for (season in seq(2, 4)) {
      season_dir <- file.path(var_dir, seasons[season])
      mkdir(season_dir)
      
      data <- obs[obs$season == season,]
      ts_seq <- generate_ts_by_season(season, 2017)
      ts_seq <- ts_seq[ts_seq >= min(data$timestamp) & ts_seq <= max(data$timestamp)]
      imputed <- impute_for_ts(data, ts_seq, imputation_count = 5, iters = 5)
      windows <- divide_into_windows(imputed, prev_lag, future_lag,
                                     future_vars = c(base_res_var, 'timestamp'), 
                                     excluded_vars = c())
      windows$future_timestamp <- as.POSIXct(windows$future_timestamp, origin = '1970-01-01', tz = 'UTC')
      
      # Actual response variable has the 'future_' prefix
      res_var <- paste('future', base_res_var, sep = '_')
      explanatory_vars <- colnames(windows)
      explanatory_vars <- explanatory_vars[explanatory_vars != res_var]
      res_formula <- as.formula(paste(res_var, '~',
                                      paste(explanatory_vars, collapse = '+'), sep = ' '))
      res_formula <- skip_colinear_variables(res_formula, windows)
      
      training_count <- 24 * training_days
      test_count <- 24 * test_days
      offset_step <- 24 * offset_days
      total_obs <- 24 * floor(length(windows[, 1]) / 24)
      
      offset_seq <- seq(1, total_obs - (training_count + test_count) + 1, offset_step)
      
      # results <- lapply(offset_seq, function (offset) {
      #   plot_path <- file.path(season_dir, paste('data_split_', offset, '.png', sep = ''))
      #   save_data_split(windows, res_var, training_seq, test_seq, plot_path)
      # })
      
      lapply(names(pred_models), function (model_name) {
        fit_model <- pred_models[[model_name]]
        
        results <- lapply(offset_seq, function (offset) {
          last_training_idx <- offset + training_count - 1
          training_seq <- (offset):last_training_idx
          test_seq <- (last_training_idx + 1):(last_training_idx + test_count)
          
          training_set <- windows[training_seq, ]
          test_set <- windows[test_seq, ]
          
          fit_model(res_formula, training_set, test_set, model_dir)
        })
        results <- do.call(rbind, results)
        
        plot_path <- file.path(season_dir, paste('comparison_plot_', model_name, '.png', sep = ''))
        save_comparison_plot(results, res_var, plot_path)
        goodness_path <- file.path(season_dir, paste('goodness_', model_name, '.txt', sep = ''))
        save_prediction_goodness(results, goodness_path)
      })
    }
  }
}
main()

