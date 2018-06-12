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
excluded <- c('pm10', 'solradiation', 'wind_dir_deg', 'id')
obs <- obs[, !(names(obs) %in% excluded)]
obs$station_id <- sapply(obs$station_id, trimws)
create_table_from_schema('observations', 'complete_observations')

all_imputed <- lapply(stations, function (station_id) {
  print(paste('Imputing data for station', station_id))
  data <- obs[obs$station_id == station_id, ]
  
  imputed <- lapply(unique(data$year), function (year) {
    yearly_data <- data[data$year == year, ]
    
    # Last week of a year is treated as a period separate 
    # from that year's winter - it's more related to the next
    # year's period from January to March
    # year = [winter, spring, summer, autumn, beginning of the next year's winter]
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
  imputed
})

all_imputed <- do.call(rbind, all_imputed)
cols <- colnames(all_imputed)
cols <- cols[cols != 'station_id']
windows <- lapply(stations, function (station_id) {
  obs_for_station <- all_imputed[all_imputed$station_id == station_id, cols]
  obs_for_station <- obs_for_station[order(obs_for_station$timestamp), ]
  windows <- divide_into_windows(obs_for_station,
                                 past_lag = 23,
                                 future_lag = 24,
                                 future_vars = c('pm2_5', 'timestamp'))
  windows <- add_aggregated(windows, past_lag = 23, vars = c('pm2_5', 'wind_speed', 'temperature', 'humidity', 'pressure', 'precip_rate', 'wind_dir_ns', 'wind_dir_ew'))
  windows <- skip_past(windows)
  windows$station_id <- station_id
  windows
})

windows <- do.call(rbind, windows)
windows$timestamp <- utcts(windows$timestamp)
windows$future_timestamp <- utcts(windows$future_timestamp)
save(windows, file = 'time_windows.Rda')

