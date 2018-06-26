wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
setwd(wd)

packages <- c('corrplot', 'magrittr', 'knitr', 'plyr')
import(packages)
Sys.setenv(LANG = "en")

plotCorrMat <- function (data, main_var_idx, file_path, corr_threshold = 0.2) {
  data <- data[, sapply(data, function (col) { is.numeric(col) && sd(col) != 0 })]
  png(filename = file_path, height = 1920, width = 1920, pointsize = 40)
  palette <- colorRampPalette(c('#500000', '#7F0000', 'red', 'white',
                                'blue', '#00007F', '#000050'))
  M <- cor(data, use = 'complete.obs')
  which_order <- order(abs(M[, main_var_idx]), decreasing = T)
  corrplot(M, type = 'upper', method = 'number', col = palette(100))
  dev.off()
  
  # Find variables with absolute correlation above certain threshold
  M <- signif(M[, 2:ncol(M)], 3)
  signif_vars <- as.data.frame(t(M[1, abs(M[1, ]) > corr_threshold]))
  signif_vars <- signif_vars[, order(abs(signif_vars[1, ]), decreasing = TRUE)]
}

main <- function () {
  load(file = '../time_windows.Rda')
  stations <- unique(windows$station_id)
  season_names <- c('winter', 'spring', 'summer', 'autumn')
  
  vars <- c('pm2_5', 'humidity', 'precip_total', 'pressure', 'temperature', 'wind_speed',
            'day_of_year', 'day_of_week', 'is_heating_season', 'is_holiday', 'month', 'period_of_day')
  main_var <- 'future_pm2_5'
  vars <- c(main_var, vars)
  windows <- windows[, c(vars, 'station_id', 'season')]
  main_var_idx <- which(vars == main_var)
  
  target_dir <- file.path(getwd(), 'correlation')
  mkdir(target_dir)
  
  signif_path <- file.path(target_dir, 'significant_vars.txt')
  signif_vars <- lapply(seq(1, 4), function (season) {
    st_signif_vars <- lapply(stations, function (sid) {
      seasonal_data <- windows[windows$station_id == sid
                               & windows$season == season, vars]
      file_path <- file.path(target_dir, paste('corrplot_', sid, '_', season, '.png', sep = ''))
      signif_vars <- plotCorrMat(seasonal_data, main_var_idx, file_path)
      padding_cols <- sapply(seq(length(vars) - ncol(signif_vars)), function (i) {
        paste('padding', i, sep = '_')
      })
      signif_vars <- as.data.frame(t(sapply(signif_vars, as.character)), stringsAsFactors = FALSE)
      signif_vars <- data.frame('Station' = pretty_station_id(sid),
                                season = season_names[[season]],
                                signif_vars,
                                stringsAsFactors=FALSE)
      cnames <- t(as.data.frame(sapply(colnames(signif_vars), pretty_var)))
      cnames[1, 1] <- ''
      cnames[1, 2] <- ''
      signif_vars <- rbind(cnames, signif_vars)
      signif_vars[, padding_cols] <- ''
      colnames(signif_vars) <- 1:ncol(signif_vars)
      rownames(signif_vars) <- NULL
      signif_vars
    })
    do.call(rbind, st_signif_vars)
  })
  signif_vars <- do.call(rbind, signif_vars)
  colnames(signif_vars) <- c('Station', 'Season', 'Significant variables')
  max_signif_cols_count <- max(apply(signif_vars, 1, function (row) { sum(nchar(row) > 0) }))
  signif_vars <- signif_vars[, 1:max_signif_cols_count]
  write(knitr::kable(signif_vars), file = signif_path, append = TRUE)
  
  # Create a corrplot for all the data
  file_path <- file.path(target_dir, 'corrplot-all-data.png')
  plotCorrMat(windows, main_var_idx, file_path)
  print(paste('# of windowservation records:', nrow(windows), sep = ' '))
  print(paste('# of records after omiiting missing values:', nrow(na.omit(windows)), sep = ' '))
}
main()
