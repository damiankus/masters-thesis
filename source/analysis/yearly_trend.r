wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('plotting.r')
setwd(wd)

packages <- c('dplyr')
import(packages)
Sys.setenv(LANGUAGE = 'en')
Sys.setlocale('LC_TIME', 'en_GB.UTF-8')
Sys.setlocale('LC_MESSAGES', 'en_GB.UTF-8')

main <- function () {
  # load('../time_windows.Rda')
  load('wind_dir_windows.Rda')
  stations <- unique(windows$station_id)
  
  excluded <- c('id')
  windows <- windows[, !(colnames(windows) %in% excluded)]
  windows$date <- as.Date(utcts(windows$timestamp))
  windows$station_id <- unlist(lapply(windows$station_id, function (id) { 
    parts <- strsplit(id, '_')[[1]]
    paste(toupper(parts[[1]]), cap(parts[[2]]))
  }))
  
  vars <- colnames(windows)
  vars <- vars[!(vars %in% c('id', 'station_id', 'timestamp', 'date', 'month'))]
  month_names <- c('January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December')
  target_dir <- file.path(getwd(), 'trend')
  mkdir(target_dir)

  # For plotting daily total precipitation
  
  lapply(vars, function (var) {
    # Total precipitation so far is a cumulative value
    stats <- NULL
    if (var == 'precip_total') {
      stats <- aggregate(windows[, var], by = list(windows$date, windows$station_id),
                         FUN = mean, na.rm = TRUE)
    } else {
      # Plots are prepared separately for each station so the total precipitation for the
      # given day is the 24h maximum value
      stats <- aggregate(windows[, var], by = list(windows$date, windows$station_id),
                         FUN = function (x) { max(x) })
    }
    names(stats) <- c('dates', 'station_id', var)
    stats[, 'date'] <- as.Date(stats$date)
    plot_path <- file.path(target_dir, paste(var, '_yearly_trend.png', sep = ''))
    x_lab <- 'Date'
    y_lab <- paste(pretty_var(var), '[', units(var), ']')
    save_multi_facet_plot(stats, 'date', var, id_var = 'station_id', plot_path,
                          x_lab = x_lab, y_lab  = y_lab, legend_title = 'Station ID')
  })
}
main()

