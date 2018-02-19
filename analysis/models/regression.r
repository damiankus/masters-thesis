require('RPostgreSQL')
require('ggplot2')
require('reshape')
require('caTools')
library('lubridate')
Sys.setenv(LANG = "en")

cap <- function (s) {
  s <- strsplit(s, ' ')[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = '', collapse = ' ')
}

mkdir <- function (path) {
  if (!dir.exists(path)) {
    dir.create(path, showWarnings = FALSE)
  }
}

# Based on http://r-statistics.co/Linear-Regression.html

save_comparison_plot <- function (df, res_var, plot_path) {
  line_plot <- ggplot(data = df) +
    geom_line(aes(x = date, y = actual), color = 'red') +
    geom_line(aes(x = date, y = predicted), color = 'blue') +
    xlab('Date') +
    ylab(cap(res_var)) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

save_scatter_plot <- function (df, res_var, plot_path) {
  scatter_plot <- ggplot(data = df, aes_string(x = 'actual', y = 'predicted')) +
    geom_point() +
    xlab('Actual') +
    ylab('Predicted') +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
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
  
  target_root_dir <- getwd()
  target_root_dir <- file.path(target_root_dir, 'regression')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'complete_data'
  response_vars <- c('pm2_5_plus_12', 'pm2_5_plus_24')
  explanatory_vars <- c('pm2_5', 'temperature', 'pressure', 'humidity',
                        'precip_rate', 'wind_speed',
                        'wind_dir', 'cont_date')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table, sep = ' ')
  obs <- dbGetQuery(con, query)
  
  # Radndom sets split
  # set.seed(101)
  # sample <- sample.split(obs$pm2_5_plus_12, SplitRatio = 0.75)
  # training_set <- subset(obs, sample == TRUE)
  # test_set <- subset(obs, sample == FALSE)
  
  which_test <- which(format(obs$timestamp, '%m') %in% c('02'))
  test_set <- obs[which_test,]
  training_set <- obs[-which_test,]
  
  expl_formula <- paste(explanatory_vars, collapse = ' + ')
  t_offset <- 12 * 60 * 60
  
  for (res_var in response_vars) {
    mlr <- lm(as.formula(
      paste(res_var, '~', expl_formula, sep = ' ')),
      data = training_set)
    print(summary(mlr))
    print(head(compared))
    print(cor_accuracy)
    pred_vals <- predict(mlr, test_set)
    compared <- data.frame(cbind(actual = test_set$pm2_5_plus_12, predicted = pred_vals))
    cor_accuracy <- cor(compared, use = 'complete.obs')
    compared[,'date'] <- test_set$timestamp + t_offset
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    plot_path <- file.path(target_dir, paste(res_var, '_prediction.png', sep = ''))
    save_comparison_plot(compared, res_var, plot_path)
    plot_path <- file.path(target_dir, paste(res_var, '_prediction_bivariate.png', sep = ''))
    save_scatter_plot(compared, res_var, plot_path = plot_path)
  }
  
}
main()

