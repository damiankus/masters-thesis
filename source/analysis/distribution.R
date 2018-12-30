wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
setwd(wd)

packages <- c('RPostgreSQL', 'reshape', 'ggplot2')
import(packages)
Sys.setenv(LANG = "en")

save_histogram <- function (df, var, plot_path, title) {
  # The bin width is calculated using the Freedman-Diaconis formula
  # See: https://stats.stackexchange.com/questions/798/calculating-optimal-number-of-bins-in-a-histogram
  # Also: https://nxskok.github.io/blog/2017/06/08/histograms-and-bins/
  
  fact_col <- df[,var] 
  bw <- 2 * IQR(fact_col, na.rm = TRUE) / length(fact_col) ^ 0.33
  outlier_thresholds <- quantile(fact_col, c(0.01, .99), na.rm = TRUE)
  
  plot <- ggplot(data = df, aes_string(fact_col)) +
    geom_histogram(colour = 'white', fill = 'blue', binwidth = bw) +
    ggtitle(title) +
    geom_vline(xintercept = outlier_thresholds[1]) +
    geom_vline(xintercept = outlier_thresholds[2]) +
    xlab(cap(
      paste(pretty_var(var), '[', units(var), ']', sep = ' '))) +
    ylab('Frequency')
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

main <- function () {
  load('../time_windows.Rda')
  
  # Fetch all windowservations
  excluded <- c('id', 'station_id')
  windows <- windows[, !(colnames(windows) %in% excluded)]
  windows[, 'date'] <- var(as.Date(windows$timestamp))
  
  vars <- colnames(windows)
  vars <- vars[!(vars %in% c('timestamp', 'date', 'month'))]
  month_names <- c('January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December')
  windows$year <- sapply(windows$timestamp, function (ts) { as.POSIXlt(ts, origin = '1970-01-01', tz = 'UTC')$year + 1900 })
  
  target_root_dir <- file.path(getwd(), 'distribution')
  mkdir(target_root_dir)
  target_root_dir <- file.path(target_root_dir, 'observations')
  mkdir(target_root_dir)
  vars <- c('wind_dir_ns')

  for (year in seq(min(windows$year), max(windows$year))) {
    year_dir <- file.path(target_root_dir, year)
    mkdir(year_dir)
    yearly <- windows[windows$year == year, ]
    
    for (month in seq(min(yearly$month), max(yearly$month))) {
      monthly <- yearly[yearly$month == month, ]
      
      for (var in vars) {
        target_dir <- file.path(year_dir, var)
        mkdir(target_dir)
      
        plot_name <- paste('histogram_', var, '_', month, '.png', sep = '')
        plot_path <- file.path(target_dir, plot_name)
        title <- paste('Distribution of ', pretty_var(var), ' during ', month_names[month])
        save_histogram(monthly, var, plot_path, title)
      }
    }
  }
}
main()
