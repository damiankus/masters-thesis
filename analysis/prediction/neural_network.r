wd <- getwd()
setwd(file.path('..', 'common'))
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
  explanatory_vars <-  c('is_holiday', 'day_of_week', 'pm1', 'pm2_5', 'pm2_5_minus_1', 'pm2_5_minus_2', 'pm2_5_minus_3', 'wind_speed','avg_daily_temperature','max_daily_temperature','min_daily_pressure','max_daily_pressure','max_daily_humidity','avg_daily_wind_speed','min_daily_wind_dir_ew','avg_daily_wind_dir_ew','cont_date','cont_hour','season')
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
      hidden = c(8),
      stepmax = 1e+04,
      threshold = 0.1,
      linear.output = TRUE)
    
    plot_path <- file.path(target_dir, 'nn_architecture.png')
    png(filename = plot_path, width = 1366, height = 768, pointsize = 25)
    plot(nn)
    dev.off()

    # compute() returns a matrix. In order to make it work with 
    # the mae() function work with it
    pred_vals <- compute(nn, test_set[, explanatory_vars])$net.result
    pred_vals <- c(pred_vals)
    
    results$predicted <- reverse_normalize_vec_with(pred_vals, mins[res_var], maxs[res_var])
    save_all_stats(nn, test_set, results, res_var, 'nn', target_dir, c(summary))
  }
}
main()
