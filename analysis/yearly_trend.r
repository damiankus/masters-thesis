wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('plotting.r')
setwd(wd)

packages <- c('RPostgreSQL', 'reshape', 'ggplot2')
import(packages)
Sys.setenv(LANG = "en")

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
  table_name <- 'observations'
  # table_name <- 'meteo_observations'
  excluded <- c('id', 'station_id')
  query = paste('SELECT * FROM',
                table_name,
                sep = ' ')
  obs <- dbGetQuery(con, query)
  obs <- obs[, !(colnames(obs) %in% excluded)]
  obs[,'date'] <- factor(as.Date(obs$timestamp))
  obs[,'month'] <- as.numeric(format(as.Date(obs$date), '%m'))
  factors <- colnames(obs)
  factors <- factors[!(factors %in% c('timestamp', 'date', 'month'))]
  month_names <- c('January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December')
  
  target_root_dir <- file.path(getwd(), 'trend')
  mkdir(target_root_dir)
  target_root_dir <- file.path(target_root_dir, strsplit(table_name, '_')[[1]][1])
  mkdir(target_root_dir)
  
  stat_fun <- function (x, na.rm) {
    c(avg = mean(x, na.rm = na.rm), std = sd(x, na.rm = na.rm), samples = length(x))
  }
  
  for (factor in factors) {
    stats <- as.data.frame(aggregate(obs[, factor], by = list(obs$date),
                                     FUN = mean, na.rm = TRUE))
    names(stats) <- c('date', factor)
    stats[,'date'] <- as.Date(stats$date)
    plot_path <- file.path(target_root_dir, paste(factor, '_yearly_trend.png', sep = ''))
    title <- paste(pretty_var(factor), '[', units(factor), ']', sep = '')
    save_line_plot(stats, 'date', factor, plot_path, title)
  }
}
main()

