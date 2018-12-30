wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('plotting.r')
setwd(wd)

packages <- c('dplyr', 'lubridate')
import(packages)
Sys.setenv(LANGUAGE = 'en')
Sys.setlocale('LC_TIME', 'en_GB.UTF-8')
Sys.setlocale('LC_MESSAGES', 'en_GB.UTF-8')

main <- function () {
  load('original_series.Rda')
  vars <- c('pm2_5')
  required_vars <- c(vars, 'timestamp', 'station_id')
  series <- series[, required_vars]
  series$date <- as.Date(utcts(series$timestamp))
  series$station_id <- sapply(series$station_id, pretty_station_id)
  
  target_dir <- file.path(getwd(), 'trend')
  mkdir(target_dir)

  aggr_vals <- function (df, var, by_vars) {
    aggr_series <- if (var == 'precip_total') {
      # Plots are prepared separately for each station so the total precipitation for the
      # given day is the 24h maximum value
      by_cols <- df_to_list_of_columns(df[, by_vars])
      aggregate(df[, var], by = by_cols, FUN = function (x) { max(x) })
    } else {
      # Total precipitation so far is a cumulative value
      aggregate(series[, var], by = list(series$date, series$station_id),
                FUN = mean, na.rm = TRUE)
    }
    names(aggr_series) <- c(by_vars, var)
    aggr_series
  }
  
  year_start_ts <- ymd_hms('2014-01-01 00:00:00')
  lapply(seq(year_start_ts, length=48, by='months'), function (start_ts) {
    aggr_settings <- list(
      c(name='yearly', time_col='date', start=min(series$timestamp) , end=max(series$timestamp), by_vars=list('date', 'station_id')),
      c(name='weekly', time_col='timestamp', start=start_ts, end=start_ts + days(30), by_vars=list()),
      c(name='daily', time_col='timestamp', start=start_ts, end=start_ts + days(7), by_vars=list()),
      c(name='hourly', time_col='timestamp', start=start_ts, end=start_ts + days(2), by_vars=list())
    )
    
    lapply(aggr_settings, function (settings) {
      which_rows <- which(settings$start <= series$timestamp & series$timestamp <= settings$end)
      subseries <- series[which_rows, ]
      get_data <- if (length(settings$by_vars) == 0) {
        function (df, var) {
          df
        }
      } else {
        function (df, var) {
          aggr_vals(df, var, settings$by_vars)
        }
      }
      lapply(vars, function (var) {
        plot_path <- file.path(target_dir, paste(var, settings$name, format(start_ts, format='%m-%Y'), 'trend.png', sep = '_'))
        save_multi_facet_plot(get_data(subseries, var), x_var=settings$time_col, y_var=var, id_var='station_id',
                              plot_path=plot_path, x_lab='Date')
      })
    })
  })
}
main()

