wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('preprocess.r')
setwd(wd)

packages <- c('RPostgreSQL')
import(packages)
Sys.setenv(LANG = 'en')

stations <- c('gios_krasinskiego', 'gios_bulwarowa', 'gios_bujaka')
obs <- load_observations('observations',
                         stations = stations)
obs$station_id <- sapply(obs$station_id, trimws)
create_table_from_schema('observations', 'complete_observations')

lapply(stations, function (station_id) {
  print(paste('Imputing data for station', station_id))
  data <- obs[obs$station_id == station_id, ]
  
  imputed <- lapply(unique(data$year), function (year) {
    yearly_data <- data[data$year == year, ]
    
    imputed_seasonal <- lapply(seq(1, 5), function (season) {
      seasonal_data <- yearly_data[yearly_data$season == season, ]
      ts_seq <- generate_ts_by_season(season, year)
      ts_seq <- ts_seq[ts_seq >= min(seasonal_data$timestamp) 
                       & ts_seq <= max(seasonal_data$timestamp)]
      impute_for_ts(seasonal_data, ts_seq,
                    imputation_count = 5, iters = 5,
                    plot_path = plot_path)
    })
    imputed_seasonal <- do.call(rbind, imputed_seasonal)
  })
  imputed <- do.call(rbind, imputed)
  imputed <- imputed[order(imputed$timestamp), ]
  
  write_table(imputed, 'complete_observations')
})
