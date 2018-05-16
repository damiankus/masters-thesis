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
  obs <- load_observations('complete_observations',
                           variables = c('timestamp', 'pm2_5', 'wind_speed', 'pressure',
                                         'humidity', 'temperature', 'season', 'is_holiday', 'month', 'year'),
                           stations = c('gios_krasinskiego'))
  obs$hour <- sapply(obs$timestamp, function (ts) { 
    as.POSIXlt(ts, origin = '1970-01-01', tz = 'UTC')$hour
  })
  test_year <- max(obs$year)
  training_years <- unique(obs$year)
  training_years <- training_years[training_years != test_year]
  
  base_res_var <- 'pm2_5'
  aggr_vars <- c('pm2_5', 'wind_speed', 'pressure', 'humidity', 'temperature')
    
  # For calculating aggregated values
  past_lag <- 1
  # In this case ot means 24 hours ahead!
  future_lag <- 1
  training_count <- 7 * 4
  test_count <- 7
  offset_step <- 7
  
  seasons <- c('winter', 'spring', 'summer', 'autumn')
  pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr, svr = fit_svr, neural = fit_mlp)
    # c(persistence = fit_persistence, mlr = fit_mlr, lasso_mlr = fit_lasso_mlr
    #                log_mlr = fit_log_mlr, svr = fit_svr, neural = fit_mlp, arima = fit_arima)

  var_dir <- file.path(getwd(), base_res_var)
  mkdir(var_dir)
  
  var_dir <- file.path(var_dir, 'single_hour')
  mkdir(var_dir)

  lapply(seq(1, 4), function (season) {
    season_dir <- file.path(var_dir, seasons[season])
    mkdir(season_dir)
    
    season_results <- lapply(names(pred_models), function (model_name) {
      fit_model <- pred_models[[model_name]]
      print(paste('Fitting a', model_name, 'model'))
      
      model_results <- lapply(seq(0, 23), function (hour) {
        training_base <- data.matrix(obs[obs$hour == hour
                                         & obs$year %in% training_years, ])
        training_base <- divide_into_windows(training_base, past_lag, future_lag,
                                             future_vars = c(base_res_var, 'timestamp'),
                                             excluded_vars = c())
        training_base <- add_aggregated(training_base, past_lag, vars = aggr_vars)
        training_base <- skip_past(training_base)
    
        seasonal_data <- data.matrix(obs[obs$hour == hour 
                                         & obs$season == season
                                         & obs$year == test_year, ])
        windows <- divide_into_windows(seasonal_data, past_lag, future_lag,
                                       future_vars = c(base_res_var, 'timestamp'),
                                       excluded_vars = c())
        windows <- add_aggregated(windows, past_lag, vars = aggr_vars)
        windows <- skip_past(windows)
        
        # Actual response variable has the 'future_' prefix
        res_var <- paste('future', base_res_var, sep = '_')
        explanatory_vars <- colnames(windows)
        explanatory_vars <- explanatory_vars[explanatory_vars != res_var]
        res_formula <- as.formula(paste(res_var, '~',
                                        paste(explanatory_vars, collapse = '+'), sep = ' '))
        res_formula <- skip_colinear_variables(res_formula, windows)
        
        total_obs <- length(windows[, 1])
        offset_seq <- seq(1, total_obs - (training_count + test_count) + 1, offset_step)
      
        results <- lapply(offset_seq, function (offset) {
          # offset_dir <- file.path(season_dir, offset)
          # mkdir(offset_dir)
          
          last_training_idx <- offset + training_count - 1
          training_seq <- (offset):last_training_idx
          test_seq <- (last_training_idx + 1):(last_training_idx + test_count)
          
          training_set <- rbind(training_base, windows[training_seq, ])
          test_set <- windows[test_seq, ]
          
          fit_model(res_formula, training_set, test_set, '')
        })
        results <- do.call(rbind, results)
      })
      
      model_results <- do.call(rbind, model_results)
      model_results$timestamp <- as.POSIXct(model_results$timestamp,  origin = '1970-01-01', tz = 'UTC')
      
      plot_path <- file.path(season_dir, paste('comparison_plot_', model_name, '.png', sep = ''))
      save_comparison_plot(model_results, base_res_var, plot_path)
      calc_prediction_goodness(model_results, model_name)
    })
    season_results <- do.call(rbind, season_results)
    file_path <- file.path(var_dir, 'prediction_goodness.txt')
    write(seasons[season], file = file_path, append = TRUE)
    save_prediction_goodness(season_results, file_path)
  })
}
main()

