wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
setwd(wd)

packages <- c('knitr')
import(packages)
Sys.setenv(LANG = "en")
options(digits = 4)

save_pretty <- function (df, file_path) {
  pretty <- knitr::kable(df)
  write(pretty, file = file_path)
}

# Original data
data <- load_observations('observations')

# Imputed data
# load('../time_windows.Rda')
# data <- windows

month_names <- c('January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December')

# 2016 was a leap year
theoretical_total <- (3 * 365 + 366) * 24
data$station_id <- sapply(data$station_id, trimws)
stations <- unique(data$station_id)
air_quality_vars <- c('pm2_5')
meteo_vars <- c('humidity', 'precip_total', 'pressure',
                'temperature', 'wind_speed')
vars <- c(air_quality_vars, meteo_vars)
target_dir <- file.path(getwd(), 'stats')
mkdir(target_dir)

missing <- lapply(stations, function (sid) {
  chunk <- data[data$station_id == sid, ]
  missing_for_station <- lapply(air_quality_vars, function (var) {
    sum(is.na(chunk[, var])) * 100 / theoretical_total
  })
  missing_for_station <- data.frame(c(pretty_station_id(sid), t(missing_for_station)))
  names(missing_for_station) <- c('Station ID', 'Missing [%]')
  missing_for_station
})

missing <- do.call(rbind, missing)
file_path <- file.path(target_dir, 'missing-pm25.txt')
save_pretty(missing, file_path)
file_path <- file.path(target_dir, 'missing-pm25.csv')
write.csv(missing, file = file_path, row.names = FALSE)

aggr_types <- c('mean', 'sd')
stats_for_station <- lapply(stations, function (sid) {
  all_monthly <- lapply(seq(1, 12), function (month) {
    chunk <- data[data$station_id == sid & data$month == month, ]
    monthly_stats <- lapply(vars, function (var) {
      stats <- sapply(aggr_types, function (aggr, vals) {
        do.call(aggr, list(vals, na.rm = TRUE))
      }, chunk[, var])
      names(stats) <- sapply(aggr_types, function (aggr) {
        paste(cap(pretty_var(var)), ' (', aggr, ') [', units(var), ']', sep = '')
      })
      stats
    })
    monthly_stats <- do.call(c, monthly_stats)
  })
  all_monthly <- as.data.frame(do.call(rbind, all_monthly))
  all_monthly <- cbind('Station ID' = pretty_station_id(sid),
                       'Month' = month_names, all_monthly)
  all_monthly
})
stats_for_station <- do.call(rbind, stats_for_station)
rownames(stats_for_station) <- NULL

file_path <- file.path(target_dir, 'stats_for_station.txt')
save_pretty(stats_for_station, file_path)
file_path <- file.path(target_dir, 'stats_for_station.csv')
write.csv(stats_for_station, file = file_path, row.names = FALSE)
