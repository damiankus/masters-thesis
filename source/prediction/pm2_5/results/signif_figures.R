files <- list.files('.', pattern = '*.csv')
lapply(c('krasinskiego_same_season.csv'), function (f) {
  data <- read.csv(f, sep=',', quote='"');
  
  data$RMSE....mu.g.m.3.. <- format(data$RMSE....mu.g.m.3.., digits = 4)
  data$MAE....mu.g.m.3.. <- format(data$MAE....mu.g.m.3.., digits = 4)
  data$MAPE.... <- format(data$MAPE...., digits = 5)
  data$R2..1. <- format(data$R2..1., digits = 3)
  
  colnames(data) <- c('Model', 'Season', 'RMSE [$\\mu g/m^3$]', 'MAE [$\\mu g/m^3$]', 'MAPE [$%$]', 'R2 [$1$]')
  write.csv(data, file = file.path('formatted', paste(f, sep = '_')), row.names = F)
})
