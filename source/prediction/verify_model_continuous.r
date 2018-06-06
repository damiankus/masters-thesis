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
  # Loaded data frame will be saved in a variable called windows
  load(file = file.path('..', 'time_windows.Rda'))
  test_year <- max(windows$year)
  training_years <- unique(windows$year)
  training_years <- training_years[training_years != test_year]
  base_res_var <- 'pm2_5'
  
  # For calculating aggregated values
  past_lag <- 23
  future_lag <- 24
  training_days <- 0
  test_days <- 7
  offset_days <- 7
  training_count <- 24 * training_days
  test_count <- 24 * test_days
  offset_step <- 24 * offset_days
  seasons <- c('winter', 'spring', 'summer', 'autumn')
  
  expl_vars <- list(c(), c(), c(), c())
  pred_models <- c(
    mlp_3_th_0.5 = mlp_factory(c(3), threshold = 0.5),
    mlp_5_th_0.5 = mlp_factory(c(5), threshold = 0.5),
    mlp_10_th_0.5 = mlp_factory(c(10), threshold = 0.5),
    mlp_15_th_0.5 = mlp_factory(c(15), threshold = 0.5),
    mlp_5_10_th_0.5 = mlp_factory(c(5, 10), threshold = 0.5),
    mlp_5_5_th_0.5 = mlp_factory(c(5, 5), threshold = 0.5),
    mlp_3_5_5_th_0.5 = mlp_factory(c(3, 5, 5), threshold = 0.5),
    mlp_3_5_10_th_0.5 = mlp_factory(c(3, 5, 10), threshold = 0.5),
    mlp_10_5_3_th_0.5 = mlp_factory(c(10, 5, 3), threshold = 0.5)
  )
  
  var_dir <- file.path(getwd(), base_res_var, 'continuous_data')
  mkdir(var_dir)
  
  print(paste('Prediction of values', future_lag, 'hours in advance'))
  all_seasons_results <- lapply(seq(1, 4), function (season) {
    season_dir <- file.path(var_dir, seasons[season])
    mkdir(season_dir)
    
    
    which_seasonal <- windows$year == test_year & windows$season == season
    first_seasonal_idx <- min(which(which_seasonal == TRUE))
    seasonal_windows <- windows[which_seasonal, ]
    training_base <- windows[1:(first_seasonal_idx - 1), ]
    
    # Actual response variable has the 'future_' prefix
    res_var <- paste('future', base_res_var, sep = '_')
    explanatory_vars <- c()
    
    explanatory_vars <- (function () {
      if (length(expl_vars[[season]]) == 0) {
        vars <- colnames(seasonal_windows)
        vars[vars != res_var]
      } else {
        expl_vars[[season]]
      }
    })()
    
    res_formula <- as.formula(paste(res_var, '~',
                                    paste(explanatory_vars, collapse = '+'), sep = ' '))
    res_formula <- skip_colinear_variables(res_formula, seasonal_windows)
    
    # Number of days with all 24 observations 
    total_obs <- 24 * floor(length(seasonal_windows[, 1]) / 24)
    # Start Indexes of test windows
    offset_seq <- seq(training_count + 1, total_obs - test_count + 1, offset_step)
    
    season_results <- lapply(names(pred_models), function (model_name) {
      fit_model <- pred_models[[model_name]]
      print(paste('Fitting a', model_name, 'model'))

      model_results <- lapply(offset_seq, function (offset) {
        training_set <- rbind(training_base, seasonal_windows[1:(offset - 1), ])
        test_set <- seasonal_windows[offset:(offset + test_count), ]
        
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
      model_results$timestamp <- as.POSIXct(model_results$timestamp,  origin = '1970-01-01', tz = 'UTC')
      plot_path <- file.path(season_dir, paste('comparison_plot_', model_name, '_lag_', future_lag, '.png', sep = ''))
      save_comparison_plot(model_results, res_var, plot_path)
      calc_prediction_goodness(model_results, model_name)
    })
    
    season_results <- do.call(rbind, season_results)
    season_results$future_lag <- future_lag
    season_results$season <- seasons[[season]]
    file_path <- file.path(var_dir, 'prediction_goodness.txt')
    save_prediction_goodness(season_results, file_path)
    season_results
  })
  
  all_seasons_results <- do.call(rbind, all_seasons_results)
  lapply(get_all_measure_names(), function (measure_name) {
    x_lab <- 'Seasons'
    y_lab <- paste(toupper(measure_name), units(base_res_var))
    plot_path <- file.path(var_dir, paste('results_', measure_name, '.png', sep = ''))
    save_goodness_plot(all_seasons_results, 'season', measure_name, 'model', x_order <- seasons, plot_path,
                       x_lab = x_lab, y_lab = y_lab)
  })
}
main()

