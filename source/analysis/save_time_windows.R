wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("preprocess.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse")
import(packages)

# We don't impute the response variables
which_response <- grepl("pm", BASE_VARS)
response_vars <- BASE_VARS[which_response]
default_vars <- BASE_VARS[!which_response]
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-t", "--output-file"), type = "character", default = "data/time_windows.Rda"),
  make_option(c("-i", "--aggregate-incomplete"), type = "logical", action = "store_true", default = FALSE),
  make_option(c("-p", "--past-lag"), type = "numeric", default = 23),
  make_option(c("-l", "--future-lag"), type = "numeric", default = 24)
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
stations <- unique(series$station_id)
time_place_vars <- c("measurement_time", "station_id")

output_dir <- dirname(opts[["output-file"]])
mkdir(output_dir)

# Series must be ordered chronologically to make sure
# that partitioning observations into time windows works
# properly
series <- series[order(series$measurement_time), ]

# Add scaled non-time variables  
series$wind_dir_scaled <- cos(2 * pi * series$wind_dir_deg / 360)

cols <- colnames(series)
cols <- cols[cols != "station_id"]

windows_for_station <- lapply(stations, function(station_id) {
  series_for_station <- series[series$station_id == station_id, cols]
  windows <- divide_into_windows(
    series_for_station,
    past_lag = opts[["past-lag"]],
    future_lag = opts[["future-lag"]],
    future_vars = c("pm2_5", "measurement_time")
  )
  windows <- add_aggregated(windows,
                            past_lag = opts[["past-lag"]],
                            vars = BASE_VARS,
                            aggregate_incomplete = opts[["aggregate-incomplete"]])
  windows <- skip_past(windows)
  windows$station_id <- station_id
  windows
})

windows <- do.call(rbind, windows_for_station)
windows$measurement_time <- utcts(windows$measurement_time)
windows$future_measurement_time <- utcts(windows$future_measurement_time)

# Precipitation seems to be the only case where the value totalled
# over a period constitutes a reasonable variable
# (as opposed to, for example, total wind speed or total temperature)
window_colnames <- colnames(windows)
which_cols <- !grepl('total_', window_colnames) | grepl('precip_rate', window_colnames)
windows <- windows[, window_colnames[which_cols]]

complete_cases_fname <- paste(
  tools::file_path_sans_ext(
    basename(opts[["output-file"]])
  ), 'complete_cases.txt', sep = "_")

f <- file(file.path(output_dir, complete_cases_fname))
  complete_rows_count <- nrow(windows[complete.cases(windows), ])
  aggregation_info <- if (opts[['aggregate-incomplete']]) {
    paste('Aggregated values were calculated using all available data in a row.')
  } else {
    paste('Aggregated values were calculated only if a row contained no missing values.')
  }
  message <- paste('Number of complete cases:', complete_rows_count,
                   'out of', nrow(windows),
                   '(', 100 * complete_rows_count / nrow(windows), ')%.',
                   aggregation_info)
  writeLines(message, f)
close(f)

series <- windows
save(series, file = opts[["output-file"]])
print(paste('Time windows saved in', opts[["output-file"]]))


