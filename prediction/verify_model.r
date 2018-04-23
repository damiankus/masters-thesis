wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

source('regression.r')

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
  explanatory_vars <- c('is_holiday', 'day_of_week', 'pm1', 'pm2_5', 'pm2_5_minus_1', 'pm2_5_minus_2', 'pm2_5_minus_3', 'wind_speed','avg_daily_temperature','max_daily_temperature','min_daily_pressure','max_daily_pressure','max_daily_humidity','avg_daily_wind_speed','min_daily_wind_dir_ew','avg_daily_wind_dir_ew','cont_date','cont_hour','season')
  # 'pm1', 'pm2_5_minus_1', 'pm2_5_minus_2', 'pm2_5_minus_3'
  
  query = paste('SELECT timestamp, ',
            paste(c(response_vars, explanatory_vars), collapse = ', '),
            'FROM', table,
            "WHERE station_id = 'airly_172'",
            sep = ' ')
  
  obs <- na.omit(dbGetQuery(con, query))
  # transform(obs, c('max_daily_wind_speed', 'precip_total'), log)
  
  explanatory_vars <- colnames(obs)
  excluded <- c(response_vars, c('id', 'timestamp', 'station_id'))
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
  
  # Random sets split
  set.seed(101)
  sample <- sample.split(obs, SplitRatio = 0.75)
  training_set <- subset(obs, sample == TRUE)
  test_set <- subset(obs, sample == FALSE)
  
  for (res_var in response_vars) {
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
    fit_mlr(res_formula, training_set, test_set, target_dir)
  }
}
main()
