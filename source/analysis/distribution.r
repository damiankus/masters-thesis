wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
setwd(wd)

packages <- c('RPostgreSQL', 'reshape', 'ggplot2')
import(packages)
Sys.setenv(LANG = "en")

save_histogram <- function (df, factor, plot_path, title) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  fact_col <- df[,factor] 
  bw <- 2 * IQR(fact_col, na.rm = TRUE) / length(fact_col) ^ 0.33
  outlier_thresholds <- quantile(fact_col, c(0.01, .99), na.rm = TRUE)
  
  plot <- ggplot(data = df, aes_string(fact_col)) +
    geom_histogram(colour = 'white', fill = 'blue', binwidth = bw) +
    ggtitle(title) +
    geom_vline(xintercept = outlier_thresholds[1]) +
    geom_vline(xintercept = outlier_thresholds[2]) +
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
  
  # Fetch all observations
  # table_name <- 'observations'
  table_name <- 'meteo_observations'
  excluded <- c('id', 'station_id')
  query = paste('SELECT * FROM', table_name, sep = ' ')
  obs <- dbGetQuery(con, query)
  obs <- obs[, !(colnames(obs) %in% excluded)]
  obs[,'date'] <- factor(as.Date(obs$timestamp))
  obs[,'month'] <- as.numeric(format(as.Date(obs$date), '%m'))
  
  factors <- colnames(obs)
  factors <- factors[!(factors %in% c('timestamp', 'date', 'month'))]
  month_names <- c('January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December')
  obs$year <- sapply(obs$timestamp, function (ts) { as.POSIXlt(ts, origin = '1970-01-01', tz = 'UTC')$year + 1900 })
  
  target_root_dir <- file.path(getwd(), 'distribution')
  mkdir(target_root_dir)
  target_root_dir <- file.path(target_root_dir, strsplit(table_name, '_')[[1]][1])
  mkdir(target_root_dir)

  for (year in seq(min(obs$year), max(obs$year))) {
    year_dir <- file.path(target_root_dir, year)
    mkdir(year_dir)
    yearly <- obs[obs$year == year, ]
    
    for (month in seq(min(yearly$month), max(yearly$month))) {
      monthly <- yearly[yearly$month == month, ]
      
      for (factor in factors) {
        target_dir <- file.path(year_dir, factor)
        mkdir(target_dir)
      
        plot_name <- paste('histogram_', factor, '_', month, '.png', sep = '')
        plot_path <- file.path(target_dir, plot_name)
        title <- paste('Distribution of ', pretty_var(factor), ' during ', month_names[month])
        save_histogram(monthly, factor, plot_path, title)
      }
    }
  }
}
main()
