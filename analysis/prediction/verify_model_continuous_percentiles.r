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

find_training_percentiles <- function (windows, varname, last_training_idx, sample_count, lower = 0.25, upper = 0.99) {
  # Number of samples with consecutive indexes between M and N is N - M + 1
  samples <- windows[(last_training_idx - sample_count + 1):last_training_idx, c(varname, 'timestamp')]
  percentiles <- quantile(samples[, varname], c(lower, upper))
  boundaries <- list(lower = percentiles[[1]],
                     upper = percentiles[[2]],
                     first_date = utcts(samples[1, 'timestamp']),
                     last_date = utcts(samples[sample_count, 'timestamp']),
                     samples_count = length(samples[, 1]))
}

main <- function () {
  obs <- load_observations('complete_observations',
                           variables = c('timestamp', 'pm2_5', 'wind_speed', 'pressure', 'precip_rate',
                                         'humidity', 'temperature', 'season', 'hour_of_day', 'day_of_year', 'is_holiday', 'year'),
                           stations = c('gios_krasinskiego'))
  test_year <- max(obs$year)
  training_years <- unique(obs$year)
  training_years <- training_years[training_years != test_year]
  
  base_res_var <- 'pm2_5'
  aggr_vars <- c('pm2_5', 'wind_speed', 'humidity', 'pressure', 'temperature', 'precip_rate')
  
  # For calculating aggregated values
  past_lag <- 23
  future_lag <- 24
  percentile_days <- 7
  training_days <- 0
  test_days <- 7
  offset_days <- 7
  
  percentile_count <- 24 * percentile_days
  training_count <- 24 * training_days
  test_count <- 24 * test_days
  offset_step <- 24 * offset_days
  seasons <- c('winter', 'spring', 'summer', 'autumn')

  # pred_models <- generate_mlps(c(3, 5, 10), deltas = c(1, 1, 1), thresholds = seq(0.55, 0.45, -0.05))
  expl_vars <- list(c(), c(), c(), c())
  pred_models <- c(
    mlp_3_th_0.5 = mlp_factory(c(3), threshold = 0.5),
    mlp_5_th_0.5 = mlp_factory(c(5), threshold = 0.5),
    mlp_5_10_th_0.5 = mlp_factory(c(5, 10), threshold = 0.5),
    mlp_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
    mlp_3_5_5_th_0.5 = mlp_factory(c(3, 5, 5), threshold = 0.5),
    mlp_3_5_10_th_0.5 = mlp_factory(c(3, 5, 10), threshold = 0.5),
    mlp_10_5_3_th_0.5 = mlp_factory(c(10, 5, 3), threshold = 0.5)
  )
  # pred_models <- c(mlr = fit_mlr, lasso_mlr = fit_lasso_mlr, log_mlr = fit_log_mlr)

  var_dir <- file.path(getwd(), base_res_var, 'continuous_percentiles')
  mkdir(var_dir)
  
  print(paste('Prediction of values', future_lag, 'hours in advance'))
  windows <- divide_into_windows(obs, past_lag, future_lag,
                                 future_vars = c(base_res_var, 'timestamp'),
                                 excluded_vars = c())
  windows <- add_aggregated(windows, past_lag, vars = aggr_vars)
  windows <- skip_past(windows)
  
  all_seasons_results <- lapply(seq(1, 4), function (season) {
    season_dir <- file.path(var_dir, seasons[season])
    mkdir(season_dir)
    
    which_seasonal <- windows$year == test_year & windows$season == season
    first_seasonal_idx <- min(which(which_seasonal == TRUE))
    seasonal_windows <- windows[which_seasonal, ]
    training_base <- windows[1:(first_seasonal_idx - 1), ]
    last_training_base_idx <- length(training_base[, 1])
    
    # Actual response variable has the 'future_' prefix
    res_var <- paste('future', base_res_var, sep = '_')
    explanatory_vars <- colnames(windows)
    explanatory_vars <- explanatory_vars[explanatory_vars != res_var]
    res_formula <- as.formula(paste(res_var, '~',
                                    paste(explanatory_vars, collapse = '+'), sep = ' '))
    res_formula <- skip_colinear_variables(res_formula, windows)
    
    # Number of days with all 24 observations 
    total_obs <- 24 * floor(length(seasonal_windows[, 1]) / 24)
    # Start Indexes of test windows
    offset_seq <- seq(training_count + 1, total_obs - test_count + 1, offset_step)
    
    season_results <- lapply(names(pred_models), function (model_name) {
      fit_model <- pred_models[[model_name]]
      print(paste('Fitting a', model_name, 'model'))

      model_results <- lapply(offset_seq, function (offset) {
        
        # Training set ends one observation before the test window
        last_training_idx <- last_training_base_idx + offset - 1
        boundaries <- find_training_percentiles(windows, base_res_var, last_training_idx, percentile_count)
        criterion_vals <- training_base[, base_res_var] 
        which_training <- criterion_vals >= boundaries$lower & criterion_vals <= boundaries$upper
        
        training_set <- rbind(training_base[which_training, ],
                              seasonal_windows[1:(offset - 1), ])
        test_set <- seasonal_windows[offset:(offset + test_count - 1), ]

        # plot_path <- file.path(season_dir, paste('data_split_', offset, '.png', sep = ''))
        # save_data_split(base_res_var, training_set, test_set, plot_path)

        tryCatch({ fit_model(res_formula, training_set, test_set, '') },
                 warning = function (war) {
                   print(war)
                   results <- c(actual = c(), predicted = c(), residuals = c(), timestamp = c())
                   return(results)
                 },
                 error = function (err) {
                   print(err)
                   results <- c(actual = c(), predicted = c(), residuals = c(), timestamp = c())
                   return(results)
                 })
      })
      
      model_results <- do.call(rbind, model_results)
      model_results$timestamp <- utcts(model_results$timestamp)
      plot_path <- file.path(season_dir, paste('comparison_plot_', model_name, '_lag_', future_lag, '.png', sep = ''))
      save_comparison_plot(model_results, res_var, plot_path)
      calc_prediction_goodness(model_results, model_name)
    })
    
    season_results <- do.call(rbind, season_results)
    season_results$future_lag <- future_lag
    season_results$season <- seasons[[season]]
    file_path <- file.path(var_dir, 'prediction_goodness.txt')
    save_prediction_goodness(season_results, file_path)
    
    lapply(get_all_measure_names(), function (measure_name) {
      x_lab <- 'Seasons'
      y_lab <- paste(toupper(measure_name), units(base_res_var))
      season_name <- seasons[[season]]
      plot_path <- file.path(var_dir, paste('results_', measure_name, '_', season_name, '.png', sep = ''))
      save_goodness_plot(season_results, 'season', measure_name, 'model', x_order <- c(season_name), plot_path,
                         x_lab = x_lab, y_lab = y_lab)
    })
    season_results
  })
}
main()

