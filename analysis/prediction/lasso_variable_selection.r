wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
setwd(wd)

packages <- c('RPostgreSQL', 'ggplot2', 'reshape', 'caTools', 'glmnet', 'car')
import(packages)

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
  target_root_dir <- file.path(target_root_dir, 'lasso')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24')
  explanatory_vars <- c('pm2_5', 'min_daily_temperature', 'max_daily_pressure', 'max_daily_wind_speed')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                sep = ' ')
  
  query <- paste('SELECT * FROM', table, sep = ' ')
  obs <- na.omit(dbGetQuery(con, query))
  
  # explanatory_vars <- colnames(obs)
  # excluded <- c(response_vars, c('id', 'timestamp', 'station_id'))
  # explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
  
  # Random sets split
  set.seed(101)
  sample <- sample.split(obs, SplitRatio = 0.75)
  training_set <- subset(obs, sample == TRUE)
  test_set <- subset(obs, sample == FALSE)
  
  
  for (res_var in response_vars) {
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
    fit <- lm(res_formula,
              data = training_set)
    
    # Lasso regression fit
    training_mat <- model.matrix(res_formula, data = training_set)
    fit <- cv.glmnet(x = training_mat, y = training_set[,res_var], type.measure = 'mse', nfolds = 5, alpha = .5)
    test_mat <- model.matrix(res_formula, data = test_set)
    pred_vals <- c(predict(fit, s = c('lambda.1se'), test_mat, type = 'response'))
        
    results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
    results$residuals <- results$predicted - results$actual
    
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    model_desc_path <- file.path(target_dir, paste(res_var, 'prediction_goodness.txt', sep = '_'))
    save_prediction_goodness(results, fit, model_desc_path, 
                             summary_funs = c(
                               function (model) { coef(model, s = 'lambda.min') })
                             )
    
    plot_path <- file.path(target_dir, paste(res_var, '_prediction.png', sep = ''))
    lag <- tail(strsplit(res_var, '_')[[1]], n = 1)
    t_offset <- strtoi(lag, base = 10) * 60 * 60
    results$date = test_set$timestamp + t_offset
    save_comparison_plot(results[,c('date', 'actual', 'predicted')], res_var, plot_path)
    
    plot_path <- file.path(target_dir, paste(res_var, '_prediction_bivariate.png', sep = ''))
    save_scatter_plot(results, res_var, plot_path = plot_path)
    
    plot_path <- file.path(target_dir, paste(res_var, '_residuals_distribution.png', sep = ''))
    save_histogram(results, 'residuals', plot_path = plot_path)
  
    plot_path <- file.path(target_dir, paste(res_var, '_scedascicity.png', sep = ''))
    save_scedascicity_plot(results, res_var, plot_path = plot_path)  
  }
}
main()

