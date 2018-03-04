require('RPostgreSQL')
require('ggplot2')
require('reshape')
require('caTools')
Sys.setenv(LANG = "en")

cap <- function (s) {
  s <- strsplit(s, ' ')[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = '', collapse = ' ')
}

units <- function (var) {
  switch(var,
         temperature = '°C',
         humidity = '%',
         pressure = 'hPa',
         wind_speed = 'm/s',
         wind_dir_deg = '°',
         precip_total = 'mm',
         precip_rate = 'mm/h',
         {
           if (grepl('^pm', var)) {
             'μg/m³'
           } else {
             ''
           }
         })
}

pretty_var <- function (var) {
  switch(var,
         pm1 = 'PM1', pm2_5 = 'PM2.5', pm10 = 'PM10', solradiation = 'Solar irradiance', wind_speed = 'wind speed',
         wind_dir = 'wind direction', wind_dir_deg = 'wind direction',
         {
           delim <- ' '
           join_str <- ' ' 
           if (grepl('plus', var)) {
             delim <- '_plus_'
             join_str <- '+'
           } else if (grepl('minus', var)) {
             delim <- '_minus_'
             join_str <- '-'
           }     
           split_var <- strsplit(var, delim)[[1]]
           pvar <- split_var[1]
           if (length(split_var) > 1) {
             pvar <- pretty_var(pvar)
             pvar <- paste(pvar, 'at t', join_str, split_var[2], 'h', sep = ' ')
           }
           pvar
         })
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


save_histogram <- function (data, factor, plot_path) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  fact_col <- data[,factor]
  bw <- 2 * IQR(fact_col, na.rm = TRUE) / length(fact_col) ^ 0.33
  # outlier_thresholds <- quantile(fact_col, c(.001, .98), na.rm = TRUE)
  
  plot <- ggplot(data = data, aes_string(factor)) +
    geom_histogram(colour = 'white', fill = 'blue', binwidth = bw) +
    # geom_vline(xintercept = outlier_thresholds[1]) +
    # geom_vline(xintercept = outlier_thresholds[2]) +
    xlab(cap(
      paste(pretty_var(factor), '[', units(factor), ']', sep = ' '))) +
    ylab('Frequency')
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
  target_root_dir <- file.path(target_root_dir, 'filled_missing')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24')
  explanatory_vars <- c('pm2_5', 'temperature', 'pressure', 'humidity',
                        'precip_rate', 'precip_total', 'wind_speed', 'cont_date',
                        'cont_hour', 'is_heating_season')
  query = paste('SELECT timestamp, ',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                # "WHERE station_id = 'airly_172'",
                sep = ' ')
  obs <- dbGetQuery(con, query)
  
  # Random sets split
  # set.seed(101)
  # sample <- sample.split(obs$pm2_5_plus_24, SplitRatio = 0.75)
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
    plot_path <- file.path(target_dir, paste(res_var, '_residuals_distribution.png', sep = ''))
    
    compared$residuals <- compared$predicted - compared$actual
    save_histogram(compared, 'residuals', plot_path = plot_path)
  }
}
main()

