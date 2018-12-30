wd <- getwd()
setwd(file.path('..', 'common'))
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


save_best_subset <- function (res_formula, df, method, nvmax, file_path_no_ext) {
  fit <- regsubsets(res_formula, data = df, nvmax = nvmax, nbest = 3, method = method, really.big = T)
  for (scale in c('adjr2')) {
    plot_path <- file.path(paste(file_path_no_ext, '_', scale, '.png', sep = ''))
    png(filename = plot_path, width = 1366, height = 1366, pointsize = 25)
    plot(fit, scale = scale)
    dev.off()
    print(paste('Saved plot under: ', plot_path))
  }
  
  summ <- summary(fit)
  idx <- which.max(summ$adjr2)
  best_vars <- colnames(summ$which)[summ$which[idx,]]
  
  # Skip the intercept
  best_vars <- best_vars[-1]
  
  info_path <-     plot_path <- paste(file_path_no_ext, 'summary.txt', sep = '_')
  best_formula <- as.formula(
    paste(
      as.list(res_formula)[[2]],
      '~',
      paste(best_vars, collapse = '+')
    ))
  print(best_formula)
  fit <- lm(best_formula, data = df)
  capture.output(summary(fit), file = info_path, append = FALSE)
  
  best_vars <- best_vars[-1]
  info <- paste(
    paste('Best adj R2: ', max(summ$adjr2)),
    paste("Best found var subset: c('", paste(best_vars, collapse = "','"), "')", sep = ''),
    sep = '\n'
  )
  cat(info)
  cat(info, file = info_path, append = TRUE)
}

main <- function () {
  obs <- load_observations('complete_observations')
  obs <- na.omit(obs)
  vars <- colnames(obs)
  vars <- vars[!(vars %in% c('id', 'station_id', 'pm10'))]
  obs <- obs[, vars]
  
  base_res_var <- 'pm2_5'
  aggr_vars <- c('pm2_5', 'wind_speed', 'pressure', 'humidity',
                 'temperature', 'precip_rate', 'wind_dir_ew', 'wind_dir_ns')  
  # For calculating aggregated values
  past_lags <- c(23)
  future_lag <- 24
  max_vars <- 15
  
  seasons <- c('winter', 'spring', 'summer', 'autumn')
  var_dir <- file.path(getwd(), 'best_subset', base_res_var)
  mkdir(var_dir)
  
  lag_results <- lapply(past_lags, function (past_lag) {
    windows <- divide_into_windows(obs, past_lag, future_lag,
                                   future_vars = c(base_res_var, 'timestamp'),
                                   excluded_vars = c())
    windows <- add_aggregated(windows, past_lag, vars = aggr_vars)
    windows <- skip_past(windows)
    
    lapply(seq(1, 4), function (season) {
      season_dir <- file.path(var_dir, seasons[[season]])
      mkdir(season_dir)
      seasonal_windows <- windows[windows$season == season, ]
      
      # Actual response variable has the 'future_' prefix
      res_var <- paste('future', base_res_var, sep = '_')
      explanatory_vars <- colnames(seasonal_windows)
      explanatory_vars <- explanatory_vars[explanatory_vars != res_var]
      res_formula <- as.formula(paste(res_var, '~',
                                      paste(explanatory_vars, collapse = '+'), sep = ' '))
      res_formula <- skip_colinear_variables(res_formula, seasonal_windows)
      
      file_path <- file.path(season_dir, paste('best_subset_lag', past_lag, 'top', max_vars, sep = '_'))
      save_best_subset(res_formula, seasonal_windows, 'exhaustive', max_vars, file_path)
    })
  })
}
main()

