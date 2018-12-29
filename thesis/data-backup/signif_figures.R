files <- list.files('.', pattern = '*.csv')
lapply(files, function (f) {
  data <- read.csv(f, sep=',', quote='"');
  data[, 3:ncol(data)] <- apply(data[, 3:ncol(data)], 2, function (col) { 
    format(as.numeric(col), digits = 4)
  })
  colnames(data) <- c('Model', 'Season', 'RMSE [$\\mu g/m^3$]', 'MAE [$\\mu g/m^3$]', 'MAPE [$%$]', 'R2 [$1$]')
  write.csv(data, file = paste('formatted', f, sep = '_'), row.names = F)
})
