require('RPostgreSQL')
require('ggplot2')
require('reshape')
require('corrplot')
require('magrittr')
Sys.setenv(LANG = "en")

get_normalized <- function (column) {
  min_val <- min(column, na.rm = TRUE)
  max_val <- max(column, na.rm = TRUE)
  delta <- max_val - min_val
  sapply(column, function (v) (v - min_val) / delta)
}

plot_pollutant <- function (observations, target_dir, pollutant, meteo, period = 'all_day') {
  # Omit the timestamp to save it from being normalized
  data_idx <- match('timestamp', colnames(observations))
  # which <- colnames(observations)[-data_idx]
  scaled_observations <- data.frame(sapply(observations[,c(pollutant, meteo)], get_normalized))
  scaled_observations['timestamp'] <- observations['timestamp']
  
  # Transform the data frame into mapping timestamp -> (variable name, value)
  melted <- melt(scaled_observations, id.vars = 'timestamp')
  plot <- ggplot(data = melted, aes(x = timestamp, y = value, fill = variable)) +
    geom_bar(stat = 'identity', position = 'dodge') +
    xlab('Measurement date') +
    ylab('Normalized value')
    
  plot_path <- paste(pollutant, '_', meteo, '.jpg', sep = '')
  
  if (!missing(period)) {
    plot_path <- paste(period, plot_path, sep = '_')    
  }
  
  plot_path <- file.path(target_dir, plot_path)
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep=' '))
}

plotCorrMat <- function (observations, corr_path) {
  png(filename = corr_path)
  M <- cor(observations[sapply(observations, is.numeric)], use = 'complete.obs')
  corrplot(M, method = 'ellipse')
  dev.off()
}

filter_empty_cols <- function (df, na_ratio = 0.2) {
  which_na <- sapply(df, function (c) sum(is.na(c)) < (na_ratio * length(c)) )
  df[,which_na]
}

aggr_formatter_factory <- function (aggr_fun) {
  function (arg_name) {
    paste(toupper(aggr_fun), '(', arg_name, ') AS ', arg_name, sep='') 
  }
}

get_all <- function (query_args) {
  paste("SELECT timestamp::date,",
        query_args,
        'FROM combined_observations AS o',
        'JOIN stations AS s ON s.id = o.station_id',
        "WHERE timestamp > '2016-12-31'",
        'ORDER BY timestamp::date', sep = ' ')
}

get_grouped_by_day <- function (query_args) {
  paste("SELECT timestamp::date,",
        query_args,
        'FROM combined_observations AS o',
        'JOIN stations AS s ON s.id = o.station_id',
        "WHERE timestamp > '2016-12-31'",
        'GROUP BY timestamp::date',
        'ORDER BY timestamp::date', sep = ' ')
}

get_grouped_by_period_of_day <- function (query_args) {
  paste("SELECT ((timestamp::date)::text || ' ' || (8 * period_of_day)::text || ':00')::timestamp AS timestamp,",
        query_args,
        'FROM combined_observations AS o',
        'JOIN stations AS s ON s.id = o.station_id',
        "WHERE timestamp > '2016-12-31'",
        'GROUP BY timestamp::date, period_of_day',
        'ORDER BY timestamp::date, period_of_day', sep = ' ')
}

get_same_period <- function (query_args, period) {
  paste("SELECT timestamp::date,",
        query_args,
        'FROM combined_observations AS o',
        'JOIN stations AS s ON s.id = o.station_id',
        'AND period_of_day = ', period,
        'GROUP BY timestamp::date',
        'ORDER BY timestamp::date', sep = ' ')
}

get_grouped_by_hour <- function (query_args, start_time, end_time) {
  paste("SELECT timestamp, ",
        query_args,
        ' FROM combined_observations AS o ',
        'JOIN stations AS s ON s.id = o.station_id ',
        "WHERE timestamp > ",
        "'", start_time, "'",
        " AND timestamp < ",
        "'", end_time, "'",
        ' GROUP BY timestamp ',
        'ORDER BY timestamp', sep = '')
}

main <- function () {
  driver <- dbDriver('PostgreSQL')
  passwd <- { 'pass' }
  con <- dbConnect(driver, dbname='pollution',
                   host='localhost',
                   port=5432,
                   user='damian',
                   password=passwd)
  rm(passwd)
  on.exit(dbDisconnect(con))
  
  dbExistsTable(con, 'stations')
  stations <- dbGetQuery(con, 'SELECT * FROM stations')[,c('id', 'address')]
  pollutants <- c('pm1', 'pm2_5', 'pm10')
  # c('pm1', 'pm2_5', 'pm10', 'co', 'no2', 'o3', 'so2', 'c6h6')
  meteo_factors <- c('temperature', 'pressure', 'humidity', 'is_holiday', 'avg_wind_speed', 'avg_wind_dir')
  # c('temperature', 'pressure', 'humidity', 'is_holiday', 'avg_wind_speed', 'avg_wind_dir')
  
  target_root_dir <- getwd()
  formatter <- aggr_formatter_factory('AVG')
  target_root_dir <- file.path(target_root_dir, 'combined')
  dir.create(target_root_dir)
  
  # Fetch all the data
  target_dir <- target_root_dir
  query_args <- paste(c(pollutants, meteo_factors), collapse=', ')
  query <- get_all(query_args)
  observations <- dbGetQuery(con, query)
  
  # Create a corrplot for all the data
  corr_path <- file.path(target_dir, 'corrplot-all-data.png')
  plotCorrMat(observations, corr_path)
  print('Complete rows')
  print(nrow(observations))
  print(nrow(na.omit(observations)))
  head(na.omit(observations))
  
  # # The set of fetched columns is same for all types of queries
  # query_args <- paste(formatter(c(pollutants, meteo_factors)), collapse=', ')
  # 
  # # Get mean observaions grouped by day for the whole year
  # target_dir <- file.path(target_root_dir, 'global')
  # dir.create(target_dir)
  # query <- get_grouped_by_day(query_args)
  # observations <- dbGetQuery(con, query)
  # corr_path <- file.path(target_dir, 'corrplot-daily-avg.png')
  # plotCorrMat(observations, corr_path)
  # observations <- filter_empty_cols(observations)
  # filtered_pollutants <- pollutants[pollutants %in% colnames(observations)]
  # 
  # for (pollutant in filtered_pollutants) {
  #   for (meteo in meteo_factors) {
  #     plot_pollutant(observations, target_dir, pollutant, meteo)
  #   }
  # }
  # 
  # # Get data for each period of day
  # pods <- seq(0, 3)
  # names(pods) <- c('night', 'morning', 'afternoon', 'evening')
  # target_dir <- file.path(target_root_dir, 'periods_of_day')
  # dir.create(target_dir)
  # 
  # for (period in names(pods)) {
  #   query <- get_same_period(query_args, pods[period])
  #   observations <- dbGetQuery(con, query)
  #   observations <- filter_empty_cols(observations)
  #   filtered_pollutants <- pollutants[pollutants %in% colnames(observations)]
  #   corr_path <- file.path(target_dir, paste(period, 'avg', 'corrplot.png', sep = '_'))
  #   plotCorrMat(observations, corr_path)
  # 
  #   for (pollutant in filtered_pollutants) {
  #     pollutant_dir <- file.path(target_dir, pollutant)
  #     dir.create(pollutant_dir)
  #     for (meteo in meteo_factors) {
  #       meteo_dir <- file.path(pollutant_dir, meteo)
  #       dir.create(meteo_dir)
  #       plot_pollutant(observations, meteo_dir, pollutant, meteo, period)
  #     }
  #   }
  # }
  # 
  # # Get data grouped by hour for a narrow interval with high pollution levels
  # intervals <- rbind(c('2017-01-25', '2017-02-09'), c('2017-11-25', '2017-12-09'))
  # target_dir <- file.path(target_root_dir, 'intervals')
  # dir.create(target_dir)
  # 
  # plot_interval <- function (interval) {
  #   query <- get_grouped_by_hour(query_args, interval[1], interval[2])
  #   observations <- dbGetQuery(con, query)
  #   observations <- filter_empty_cols(observations)
  #   filtered_pollutants <- pollutants[pollutants %in% colnames(observations)]
  #   interval_dir <- file.path(target_dir, paste(interval[1], interval[2], sep = '_'))
  #   dir.create(interval_dir)
  #   corr_path <- file.path(target_dir, paste(interval[1], 'corrplot.png', sep = '_'))
  #   plotCorrMat(observations, corr_path)
  # 
  #   for (pollutant in filtered_pollutants) {
  #     for (meteo in meteo_factors) {
  #       plot_pollutant(observations, interval_dir, pollutant, meteo)
  #     }
  #   }
  # }
  # apply(intervals, 1, plot_interval)
}
main()