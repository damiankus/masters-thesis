wd <- getwd()
setwd(file.path('common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c(
  'RPostgreSQL', 'ggplot2', 'reshape',
  'caTools', 'glmnet', 'car',
  'leaps')
import(packages)
Sys.setenv(LANG = 'en')

fit_lasso_mlr <- function (res_formula, df, file_path, epsilon = 1e-4) {
  vars <- all.vars(res_formula)
  res_var <- vars[[1]]
  expl_vars <- vars[2:length(vars)]
  data_mat <- model.matrix(res_formula, data = df)
  model <- cv.glmnet(x = data_mat[, expl_vars], y = df[, res_var], type.measure = 'mse', nfolds = 10, alpha = .5)
  if (file.exists(file_path)) {
    file.remove(file_path)
  }
  coeffs <- coef(model, s = 'lambda.min')
  vars <- rownames(coeffs)[which(abs(coeffs) > epsilon)]
  vars <- vars[!(vars %in% '(Intercept)')]
  capture.output(coef(model, s = 'lambda.min'), file = file_path, append = TRUE)
  capture.output(paste("c('", paste(vars, collapse = "','"), "')", sep = ''), file = file_path, append = TRUE)
}

main <- function () {
  obs <- load_observations('complete_observations',
                           variables = c('timestamp', 'pm2_5', 'wind_speed', 'pressure', 'precip_rate',
                                         'humidity', 'temperature', 'season', 'is_holiday', 'month', 'year',
                                         'day_of_week', 'hour_of_day', 'wind_dir_ew', 'wind_dir_ns'),
                           stations = c('gios_krasinskiego'))
  obs <- na.omit(obs)
  base_res_var <- 'pm2_5'
  aggr_vars <- c('pm2_5', 'wind_speed', 'pressure', 'humidity',
                 'temperature', 'precip_rate', 'wind_dir_ew', 'wind_dir_ns')
  
  # For calculating aggregated values
  past_lags <- c(24, 48)
  future_lag <- 24
  
  seasons <- c('winter', 'spring', 'summer', 'autumn')
  var_dir <- file.path(getwd(), 'lasso_selection', base_res_var)
  mkdir(var_dir)
  
  lapply(seq(1, 4), function (season) {
    season_dir <- file.path(var_dir, seasons[[season]])
    mkdir(season_dir)
    seasonal_data <- data.matrix(obs[obs$season == season, ])
    
    lag_results <- lapply(past_lags, function (past_lag) {
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
      
      model_path <- file.path(season_dir, paste('lasso_lag_summary_', past_lag, '.txt', sep = ''))
      fit_lasso_mlr(res_formula, windows, model_path)
    })
  })
}
main()
