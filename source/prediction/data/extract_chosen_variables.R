load('time_windows.Rda')

# Picked based on the analysis described in 
# chapter 3 of the thesis
base_variables <- as.character(read.csv(file = 'variables.csv', header = TRUE)$variable)

# Used for data partition
auxilliary_variables <- c(
  'station_id',
  'season',
  'year'
)

series <- series[, c(base_variables, auxilliary_variables)]
series <- series[complete.cases(series), ]
series <- series[order(series$station_id, series$measurement_time), ]
save(series, file = "time_series.Rda")
