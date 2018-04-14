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
  query = paste('SELECT * FROM', table,
                "WHERE station_id = 'airly_172'",
                sep = ' ')
  
  obs <- na.omit(dbGetQuery(con, query))
  xtabs(obs)
  
  # explanatory_vars <- colnames(obs)
  excluded <- c(response_vars, c('id', 'timestamp', 'station_id'))
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
  
  for (res_var in response_vars) {
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
    print(length(explanatory_vars))
    summ <- summary(save_best_subset(res_formula, obs, 'exhaustive', 13))
    idx <- which.max(summ$adjr2)
    best_vars <- colnames(summ$which)[summ$which[idx,]]
    
    # Skip the intercept
    best_vars <- best_vars[-1]
    print(paste('Best adj R2: ', max(summ$adjr2)))
    print(paste("Best found var subset: c('", paste(best_vars, collapse = "','"), "')", sep = ''))
  }
}
main()

