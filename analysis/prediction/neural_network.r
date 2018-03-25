wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c('RPostgreSQL', 'neuralnet', 'caTools')
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
  
  # Fetch all observations
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24')
  explanatory_vars <- c('pm2_5', 'temperature', 'min_daily_pressure', 'avg_daily_wind_speed', 'humidity')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                "WHERE station_id IN ('airly_172')",
                sep = ' ')
  obs <- na.omit(dbGetQuery(con, query))
  target_root_dir <- getwd()
  
  # Scale the explanatory variables
  print('Scaling')
    
  # Omit the timestamp
  numeric_vars <- c(response_vars, explanatory_vars)
  mins <- apply(obs[, numeric_vars], 2, min)
  maxs <- apply(obs[, numeric_vars], 2, max)
  obs[, explanatory_vars] <- normalize_with(obs[, explanatory_vars],
                                            mins[explanatory_vars],
                                            maxs[explanatory_vars])
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
    
  # Random sets split
  set.seed(101)
  sample <- sample.split(obs, SplitRatio = 0.75)
  training_set <- subset(obs, sample == TRUE)
  test_set <- subset(obs, sample == FALSE)

  for (res_var in response_vars) {
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    results <- data.frame(actual = test_set[, res_var])
    training_set[, res_var] <- normalize_vec_with(
      training_set[, res_var], mins[res_var], maxs[res_var])
    test_set[, res_var] <- normalize_vec_with(
      test_set[, res_var], mins[res_var], maxs[res_var])
    
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
  
    print('Training')
    nn <- neuralnet(res_formula,
      data = training_set,
      hidden = c(13),
      stepmax = 1e+06,
      threshold = 0.05,
      linear.output = TRUE)

    plot(nn)
    # compute() returns a matrix. In order to make it work with 
    # the mae() function work with it
    pred_vals <- compute(nn, test_set[, explanatory_vars])$net.result
    pred_vals <- c(pred_vals)
    results$predicted <- reverse_normalize_vec_with(pred_vals, mins[res_var], maxs[res_var])
    save_all_stats(nn, results, res_var, 'nn', target_dir, c(summary))
  }
}
main()

