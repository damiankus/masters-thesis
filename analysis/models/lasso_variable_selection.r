Sys.setenv(LANG = "en")
library(RPostgreSQL)
library(reshape)
library(caTools)
library(glmnet)

wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
setwd(wd)

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
  target_root_dir <- file.path(target_root_dir,  'filled_missing')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24')
  explanatory_vars <- c('pm2_5', 'temperature', 'pressure', 'humidity', 'is_holiday', 'period_of_day',
                        'is_heating_season', 'wind_speed', 'wind_dir',
                        'precip_total', 'precip_rate', 'solradiation', 'cont_date', 'cont_hour')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                # "WHERE station_id = 'airly_172'",
                sep = ' ')
  obs <- na.omit(dbGetQuery(con, query))
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')

  for (res_var in response_vars) {
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
    mat <- model.matrix(res_formula, data = obs)
    lasso <- cv.glmnet(x = mat, y = obs$pm2_5_plus_24, type.measure='mse', nfolds = 5, alpha = .5)
    print(coef(lasso, s = "lambda.1se"))
  }
}
main()

