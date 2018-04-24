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
  'leaps')
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
  explanatory_vars <- c('timestamp', 'is_holiday', 'day_of_week', 'pm1', 'day_of_year',
                        'pm2_5', 'wind_speed','avg_daily_temperature',
                        'max_daily_temperature','min_daily_pressure',
                        'max_daily_pressure','max_daily_humidity',
                        'avg_daily_wind_speed','min_daily_wind_dir_ew',
                        'avg_daily_wind_dir_ew','season')
  
  query = paste('SELECT *',
            # paste(c(response_vars, explanatory_vars), collapse = ', '),
            'FROM', table,
            "WHERE station_id = 'airly_172'",
            'ORDER BY timestamp',
            sep = ' ')
  
  obs <- na.omit(dbGetQuery(con, query))
  explanatory_vars <- colnames(obs)
  excluded <- c(response_vars, c('id', 'timestamp', 'station_id'))
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
  models <- c(fit_mlr, fit_svr)
  
  # obs <- obs[!split_by_heating_season(obs),]
  which_training <- split_by_date(obs, date_str = '2017-09-01 00:00')
  training_set <- obs[which_training,]
  test_set <- obs[!which_training,]
  
  for (res_var in response_vars) {
    for (fit_model in models) {
      target_dir <- file.path(target_root_dir, res_var)
      mkdir(target_dir)
      res_formula <- as.formula(
        paste(res_var, '~', rhs_formula, sep = ' '))
      fit_model(res_formula, training_set, test_set, target_dir)
    }
  }
}
main()

