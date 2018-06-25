wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
setwd(wd)

packages <- c('corrplot', 'magrittr')
import(packages)
Sys.setenv(LANG = "en")

plotCorrMat <- function (data, main_var_idx, file_path) {
  data <- data[, sapply(data, function (col) { is.numeric(col) && sd(col) != 0 })]
  png(filename = file_path, height = 1920, width = 1920, pointsize = 40)
  palette <- colorRampPalette(c('#500000', '#7F0000', 'red', 'white',
                                'blue', '#00007F', '#000050'))
  M <- cor(data, use = 'complete.obs')
  which_order <- order(abs(M[, main_var_idx]), decreasing = T)
  corrplot(M[which_order, which_order], type = 'upper', method = 'number', col = palette(100))
  dev.off()
}

main <- function () {
  load(file = '../time_windows.Rda')
  stations <- unique(windows$station_id)
  
  # vars <- colnames(windows)
  vars <- c('pm2_5', 'humidity', 'precip_total', 'pressure', 'temperature', 'wind_speed',
            'day_of_year', 'day_of_week', 'is_heating_season', 'is_holiday', 'month', 'period_of_day')
  # excluded <- c('id', 'timestamp', 'station_id')
  # vars[!(vars %in% excluded)]
  main_var <- 'future_pm2_5'
  vars <- c(main_var, vars)
  windows <- windows[, c(vars, 'station_id', 'season')]
  main_var_idx <- which(vars == main_var)
  
  target_root_dir <- file.path(getwd(), 'correlation')
  mkdir(target_root_dir)
  target_dir <- target_root_dir
  
  lapply(seq(1, 4), function (season) {
    lapply(stations, function (sid) {
      seasonal_data <- windows[windows$station_id == sid
                               & windows$season == season, vars]
      corr_path <- file.path(target_dir, paste('corrplot_', sid, '_', season, '.png', sep = ''))
      plotCorrMat(seasonal_data, main_var_idx, corr_path)
    })
  })
  
  # Create a corrplot for all the data
  corr_path <- file.path(target_dir, 'corrplot-all-data.png')
  plotCorrMat(windows, main_var_idx, corr_path)
  print(paste('# of windowservation records:', nrow(windows), sep = ' '))
  print(paste('# of records after omiiting missing values:', nrow(na.omit(windows)), sep = ' '))
}
main()
