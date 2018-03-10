library(RPostgreSQL)
library(ggplot2)
library(reshape)
library(caTools)
library(neuralnet)

wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('preprocess.r')
source('plotting.r')
source('prediction_goodness.r')
setwd(wd)
Sys.setenv(LANG = "en")

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
  target_root_dir <- file.path(target_root_dir, 'nn')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'observations'
  response_vars <- c('pm2_5_plus_12')
  explanatory_vars <- c('pm2_5', 'min_daily_temperature', 'max_daily_pressure', 'avg_daily_wind_speed',
                        'cont_date')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                "WHERE station_id IN ('airly_172')",
                sep = ' ')
  obs <- na.omit(dbGetQuery(con, query))
  
  # Scale the explanatory variables
  print('Scaling')
  
  # Omit the timestamp
  means <- apply(obs[,-1], 2, mean)
  sds <- apply(obs[,-1], 2, sd)
  obs[, explanatory_vars] <- standardize(obs[, explanatory_vars], means, sds)
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
    
  # Random sets split
  set.seed(101)
  sample <- sample.split(obs, SplitRatio = 0.75)
  training_set <- subset(obs, sample == TRUE)
  test_set <- subset(obs, sample == FALSE)

  for (res_var in response_vars) {
    results <- data.frame(actual = test_set[, res_var])
    training_set[, res_var] <- standardize_vals(
      training_set[, res_var], means[res_var], sds[res_var])
    test_set[, res_var] <- standardize_vals(
      test_set[, res_var], means[res_var], sds[res_var])
    
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
  
    print('Training')
    nn <- neuralnet(res_formula,
      data = training_set,
      hidden = c(3),
      stepmax = 1e+06,
      threshold = 0.05,
      linear.output = TRUE)

    # compute() returns a matrix. In order to make it work with 
    # the mae() function work with it
    pred_vals <- compute(nn, test_set[, explanatory_vars])$net.result
    pred_vals <- c(pred_vals)
    results$predicted <- reverse_standardize_vals(pred_vals, means[res_var], sds[res_var])
    results$residuals <- results$predicted - results$actual

    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    model_desc_path <- file.path(
      target_dir,
      paste(res_var, 'prediction_goodness.txt', sep = '_'))
    save_prediction_goodness(results, nn, model_desc_path)

    plot_path <- file.path(target_dir, paste(res_var, '_prediction.png', sep = ''))
    lag <- tail(strsplit(res_var, '_')[[1]], n = 1)
    t_offset <- strtoi(lag, base = 10) * 60 * 60
    results$date = test_set$timestamp + t_offset
    save_comparison_plot(results[, c('date', 'actual', 'predicted')], res_var, plot_path)

    plot_path <- file.path(target_dir, paste(res_var, '_prediction_bivariate.png', sep = ''))
    save_scatter_plot(results, res_var, plot_path = plot_path)

    plot_path <- file.path(target_dir, paste(res_var, '_residuals_distribution.png', sep = ''))
    save_histogram(results, 'residuals', plot_path = plot_path)
  }
}
main()

