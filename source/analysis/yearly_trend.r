wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('plotting.r')
setwd(wd)

packages <- c('dplyr')
import(packages)
Sys.setenv(LANG = "en")

main <- function () {
  load('../time_windows.Rda')
  stations <- unique(windows$station_id)
  
  excluded <- c('id')
  windows <- windows[, !(colnames(windows) %in% excluded)]
  windows$date <- factor(as.Date(windows$timestamp))
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
  
  lapply(vars, function (var) {
    stats <- as.data.frame(
      aggregate(windows[, var], by = list(windows$date, windows$station_id), 
                FUN = mean, na.rm = TRUE))
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

