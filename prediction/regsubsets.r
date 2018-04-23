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


save_best_subset <- function (res_formula, df, method, nvmax, target_dir) {
  fit <- regsubsets(res_formula, data = df, nvmax = nvmax, nbest = 3, method = method)
  for (scale in c('adjr2', 'bic')) {
    plot_path <- file.path(target_dir, paste(scale, 'best_subsets.png', sep = '_'))
    png(filename = plot_path, width = 1366, height = 1366, pointsize = 25)
    plot(fit, scale = scale)
    dev.off()
    print(paste('Saved plot under: ', plot_path))
  }
  summ <- summary(fit)
  idx <- which.max(summ$adjr2)
  best_vars <- colnames(summ$which)[summ$which[idx,]]
  # Skip the intercept
  best_vars <- best_vars[-1]
  
  info_path <- file.path(target_dir, 'best-subset-info.txt')
  file.remove(info_path)
  best_formula <- as.formula(
    paste(
      as.list(res_formula)[[2]],
      '~',
      paste(best_vars, collapse = '+')
    ))
  print(best_formula)
  fit <- lm(best_formula, data = df)
  capture.output(summary(fit), file = info_path, append = TRUE)
  
  best_vars <- best_vars[-1]
  info <- paste(
    paste('Best adj R2: ', max(summ$adjr2)),
    paste("Best found var subset: c('", paste(best_vars, collapse = "','"), "')", sep = ''),
    sep = '\n'
  )
  cat(info)
  cat(info, file = info_path, append = TRUE)
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
  
  # Fetch all observations
  target_root_dir <- file.path(getwd(), 'best-subset')
  mkdir(target_root_dir)
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24')
  query = paste('SELECT * FROM', table,
                "WHERE station_id = 'airly_171'",
                sep = ' ')
  obs <- na.omit(dbGetQuery(con, query))
  
  explanatory_vars <- colnames(obs)
  ignored_base_vars <- c()
  ignored_vars <- ignored_base_vars
  if (length(ignored_base_vars) > 0) {
    ignored_masks <- sapply(ignored_base_vars, function (ignored) { endsWith(explanatory_vars, ignored) })
    which_ignored <- ignored_masks[, 1]
    for (i in seq(2, ncol(ignored_masks))) {
      which_ignored <- which_ignored | ignored_masks[, i]
    }
    
    ignored_vars <- explanatory_vars[which_ignored]
  }
  excluded <- c(response_vars, ignored_vars, c('id', 'timestamp', 'station_id'))
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  rhs_formula <- paste(explanatory_vars, collapse = ' + ')
  
  for (res_var in response_vars) {
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    res_formula <- as.formula(
      paste(res_var, '~', rhs_formula, sep = ' '))
    print(length(explanatory_vars))
    save_best_subset(res_formula, obs, 'exhaustive', 15, target_dir)
  }
}
main()

