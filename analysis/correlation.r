wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
setwd(wd)

packages <- c('RPostgreSQL', 'corrplot', 'magrittr')
import(packages)
Sys.setenv(LANG = "en")

plotCorrMat <- function (data, var_idx, corr_path) {
  png(filename = corr_path, height = 1920, width = 1920, pointsize = 15)
  M <- cor(data[sapply(data, is.numeric)], use = 'complete.obs')
  corrplot(M, method = 'ellipse')
  dev.off()
}

main <- function () {
  load(file = 'time_windows.Rda')
  vars <- colnames(windows)
  excluded <- c('id', 'timestamp', 'station_id')
  vars[!(vars %in% excluded)]
  windows <- windows[, vars]
  varname <- 'future_pm2_5'
  var_idx <- which(vars == varname)
  
  target_root_dir <- file.path(getwd(), 'correlation')
  mkdir(target_root_dir)
  target_dir <- target_root_dir
  
  
  lapply(seq(1, 4), function (season) {
    seasonal_data <- windows[windows$season == season, !grepl('season', colnames(windows))]
    corr_path <- file.path(target_dir, paste('corrplot_season_', season, '.png', sep = ''))
    plotCorrMat(seasonal_data, var_idx, corr_path)
  })
  
  # Create a corrplot for all the data
  corr_path <- file.path(target_dir, 'corrplot-all-data.png')
  plotCorrMat(windows, var_idx, corr_path)
  print(paste('# of windowservation records:', nrow(windows), sep = ' '))
  print(paste('# of records after omiiting missing values:', nrow(na.omit(windows)), sep = ' '))
}
main()
