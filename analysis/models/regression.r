require('RPostgreSQL')
require('ggplot2')
require('reshape')
require('caTools')
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
  melted <- melt(df, id = 'date')
  line_plot <- ggplot(data = melted, aes(x = date, y = value, colour = variable)) +
    geom_line() +
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
  response_vars <- c('pm2_5_plus_24')
  explanatory_vars <- c('pm2_5', 'temperature', 'pressure', 'humidity',
                        'precip_rate', 'precip_total', 'wind_speed',
                        'wind_dir', 'cont_date',
                        'is_heating_season')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table, sep = ' ')
  obs <- dbGetQuery(con, query)
  
  # Radndom sets split
  # set.seed(101)
  # sample <- sample.split(obs$pm2_5_plus_12, SplitRatio = 0.75)
  # training_set <- subset(obs, sample == TRUE)
  # test_set <- subset(obs, sample == FALSE)
  
  which_test <- which(format(obs$timestamp, '%m') %in% c('02', '03'))
  test_set <- obs[which_test,]
  training_set <- obs[-which_test,]
  
  expl_formula <- paste(explanatory_vars, collapse = ' + ')
  
  for (res_var in response_vars) {
    fit <- lm(as.formula(
      paste(res_var, '~', expl_formula, sep = ' ')),
      data = training_set)
    pred_vals <- predict(fit, test_set)
    compared <- data.frame(cbind(actual = test_set[,res_var], predicted = pred_vals))
    cor_accuracy <- cor(compared, use = 'complete.obs')
    lag <- tail(strsplit(res_var, '_')[[1]], n = 1)
    t_offset <- strtoi(lag, base = 10) * 60 * 60
    compared[,'date'] <- test_set$timestamp + t_offset
    
    print(summary(fit))
    print(cor_accuracy)
    print(head(compared))
    
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)
    plot_path <- file.path(target_dir, paste(res_var, '_prediction.png', sep = ''))
    save_comparison_plot(compared, res_var, plot_path)
    plot_path <- file.path(target_dir, paste(res_var, '_prediction_bivariate.png', sep = ''))
    save_scatter_plot(compared, res_var, plot_path = plot_path)
  }
}
main()

