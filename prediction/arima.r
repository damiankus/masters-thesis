wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

source('models.r')

packages <- c(
  'RPostgreSQL', 'ggplot2', 'reshape',
  'caTools', 'glmnet', 'car',
  'leaps', 'forecast')
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
  target_root_dir <- getwd()
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24')
  explanatory_vars <- c('timestamp', 'is_holiday',
                        'pm2_5','avg_daily_temperature',
                        'max_daily_temperature', 'avg_daily_wind_speed')
  
  query = paste('SELECT',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                "WHERE station_id = 'airly_172'",
                'ORDER BY timestamp',
                sep = ' ')
  
  obs <- na.omit(dbGetQuery(con, query))
  explanatory_vars <- colnames(obs)
  excluded <- c('id', 'timestamp', 'station_id')
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
  
  # obs <- obs[!split_by_heating_season(obs),]
  obs <- impute(obs, from_date = '2017-01-01 00:00', to_date = '2017-12-31 23:00')
  which_test <- split_by_month(obs, 2)
  training_set <- obs[!which_test,]
  test_set <- obs[which_test,]
  
  pm_ts = ts(training_set$pm2_5_plus_24, frequency=24*7)
  decomp = stl(pm_ts, s.window="periodic")
  deseasonal_cnt <- seasadj(decomp)
  plot(decomp)
  arima <- Arima(pm_ts,
                 order = c(1, 0, 1),
                 seasonal = list(order = c(1, 0, 1), period = 24*7))
  forecast_arima <- forecast(arima, h = 24*30*2)
  plot(forecast_arima)
}
main()

