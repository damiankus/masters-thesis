Sys.setenv(LANG = "en")

library(RPostgreSQL)
library(ggplot2)
library(reshape)
library(caTools)
library(glmnet)

wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
setwd(wd)

# ---------------------------------------------
# Measures specific to linear regression models
# (taking into consideration the number of coefficients)
# ---------------------------------------------

# Mean Squared Error taking into consideration the number of coefficients
adj_mse <- function (results, model) {
  sse(results) / (length(results) -  length(model$coefficients))
}

# Adjusted R squared
adj_r_squared <- function (results, model) {
  1 - adj_mse(results, model) / mst(results, model)
}

main <- function () {
  driver <- dbDriver('PostgreSQL')
  passwd <- { 'pass' }
  con <- dbConnect(driver, dbname = 'pollution',
                   host = 'localhost',
                   port = 5432,
                   user = 'damian',
                   password = passwd)
  rm(passwd)
  on.exit(dbDisconnect(con))
  
  target_root_dir <- getwd()
  target_root_dir <- file.path(target_root_dir, 'regression')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24')
  explanatory_vars <- c('pm2_5', 'temperature', 'pressure', 'humidity',
                        'wind_speed', 'cont_date',
                        'cont_hour', 'is_heating_season')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                # "WHERE station_id = 'airly_172'",
                sep = ' ')
  obs <- na.omit(dbGetQuery(con, query))
  
  # Random sets split
  # set.seed(101)
  # sample <- sample.split(obs$pm2_5_plus_24, SplitRatio = 0.75)
  # training_set <- subset(obs, sample == TRUE)
  # test_set <- subset(obs, sample == FALSE)
  
  which_test <- which(format(obs$timestamp, '%m') %in% c('02', '03'))
  test_set <- obs[which_test,]
  training_set <- obs[-which_test,]
  
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
  for (res_var in response_vars) {
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
    fit <- lm(res_formula,
      data = training_set)
    pred_vals <- predict(fit, test_set)
    
    lag <- tail(strsplit(res_var, '_')[[1]], n = 1)
    t_offset <- strtoi(lag, base = 10) * 60 * 60
    results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
    results$residuals <- results$predicted - results$actual
    
    model_desc_path <- file.path(target_dir, 'prediction_goodness.txt')
    save_prediction_goodness(results, fit, model_desc_path)
    
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    plot_path <- file.path(target_dir, paste(res_var, '_prediction.png', sep = ''))
    results$date = test_set$timestamp + t_offset
    save_comparison_plot(results, res_var, plot_path)
    
    plot_path <- file.path(target_dir, paste(res_var, '_prediction_bivariate.png', sep = ''))
    save_scatter_plot(results, res_var, plot_path = plot_path)
    
    plot_path <- file.path(target_dir, paste(res_var, '_residuals_distribution.png', sep = ''))
    save_histogram(results, 'residuals', plot_path = plot_path)
  }
}
main()

