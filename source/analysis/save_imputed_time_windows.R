wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("preprocess.R")
source("plotting.R")
setwd(wd)

Sys.setenv(LANG = "en")

packages <- c("optparse", "mice", "imputeTS")
import(packages)

# We don't impute the response variables
which_response <- grepl("pm", BASE_VARS)
response_vars <- BASE_VARS[which_response]
default_vars <- BASE_VARS[!which_response]
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-t", "--target-file"), type = "character", default = "imputed/mice_time_windows.Rda"),
  make_option(c("-m", "--method"), type = "character", default = "mice"),
  make_option(c("-a", "--algorithm"), type = "character", default = "StructTS"),
  make_option(c("-v", "--variables"), type = "character", default = paste(default_vars, collapse = ",")),
  make_option(c("-p", "--past-lag"), type = "numeric", default = 23),
  make_option(c("-l", "--future-lag"), type = "numeric", default = 24),
  make_option(c('-y', "--test-year"), type = "numeric", default = NA)
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
stations <- unique(series$station_id)

time_place_vars <- c("measurement_time", "station_id")
imputed_vars <- parse_list_argument(opts, "variables")
remaining_vars <- setdiff(colnames(series), c(time_place_vars, response_vars, imputed_vars))

test_year <- if (is.na(opts[["test-year"]])) {
  # years sorted ascendingly
  tail(sort(unique(series$year)), 1)
} else {
  opts[["test-year"]]
}
which_to_impute <- (series$year < test_year)
series_to_impute <- series[which_to_impute, ]
unchanged_series <- series[!which_to_impute, ]

target_dir <- dirname(opts[["target-file"]])
mkdir(target_dir)

imputed_for_stations <- if (opts$method == "mice") {
  # MICE imputation
  # Based on https://cran.r-project.org/web/packages/mice/mice.pdf
  # See: https://datascienceplus.com/imputing-missing-data-with-r-mice-package/
  lapply(stations, function(station_id) {
    print(paste("[MICE] Imputing data for station", station_id))
    series_for_station <- series_to_impute[series_to_impute$station_id == station_id, ]

    which_to_impute <- is.na(series_for_station[, imputed_vars])
    mids <- mice(data = series_for_station[, imputed_vars], m = 1, maxit = 30, where = which_to_impute)

    convergence_plot_path <- file.path(target_dir, paste(station_id, "mice_convergence.png", sep = "_"))
    png(filename = convergence_plot_path, width = 800, height = 800, pointsize = 20)
    plot(mids)
    dev.off()

    density_plot_path <- file.path(target_dir, paste(station_id, "mice_density_plot.png", sep = "_"))
    png(filename = density_plot_path, width = 800, height = 800, pointsize = 20)
    densityplot(mids)
    dev.off()

    strip_plot_path <- file.path(target_dir, paste(station_id, "mice_strip_plot.png", sep = "_"))
    png(filename = strip_plot_path, width = 800, height = 800, pointsize = 20)
    stripplot(mids, pch = 20, cex = 1.2)
    dev.off()

    imputed_cols <- complete(mids, 1)
    cbind(
      series_for_station[, time_place_vars], series_for_station[, response_vars],
      imputed_cols, series_for_station[, remaining_vars]
    )
  })
} else {
  # ImputeTS imputation
  # Based on https://cran.r-project.org/web/packages/imputeTS/vignettes/imputeTS-Time-Series-Missing-Value-Imputation-in-R.pdf
  lapply(stations, function(station_id) {
    print(paste("[ImputeTS, ", opts$method, "] Imputing data for station ", station_id, sep = ""))
    series_for_station <- series_to_impute[series_to_impute$station_id == station_id, ]
    imputed_cols <- lapply(imputed_vars, function(var) {
      print(paste("Imputing for", pretty_var(var)))
      col <- series_for_station[, var]
      get_imputed <- get(paste("na.", opts$method, sep = ""))
      imputed_col <- get_imputed(col)

      gapsize_path <- file.path(target_dir, paste("gapsize_", var, "_", station_id, ".png", sep = ""))
      png(filename = gapsize_path, width = 800, height = 800, pointsize = 10)
      plotNA.gapsize(x = col, ylab = get_or_generate_label(var), main = "")
      dev.off()

      na_distribution_path <- file.path(target_dir, paste("na_distribution_", var, "_", station_id, ".png", sep = ""))
      png(filename = na_distribution_path, width = 1024, height = 768, pointsize = 20)
      plotNA.distribution(x = col, ylab = get_or_generate_label(var), main = "")
      dev.off()

      imputation_path <- file.path(target_dir, paste("imputations_", var, "_", station_id, ".png", sep = ""))
      png(filename = imputation_path, width = 1024, height = 768, pointsize = 20)
      plotNA.imputations(x.withNA = col, x.withImputations = imputed_col,
                         ylab = get_or_generate_label(var), main = "")
      dev.off()

      imputed_col
    })
    series_for_station[, imputed_vars] <- imputed_cols
    series_for_station
  })
}
new_series <- rbind(do.call(rbind, imputed_for_stations), unchanged_series)
# Series must be ordered chronologically to make sure
# that partitioning observations into time windows works
# properly
new_series <- new_series[order(new_series$measurement_time), ]

new_series$wind_dir_scaled <- cos(2 * pi * new_series$wind_dir_deg / 360)
cols <- colnames(new_series)
cols <- cols[cols != "station_id"]

windows_for_station <- lapply(stations, function(station_id) {
  series_for_station <- new_series[new_series$station_id == station_id, cols]
  windows <- divide_into_windows(
    series_for_station,
    past_lag = opts[["past-lag"]],
    future_lag = opts[["future-lag"]],
    future_vars = c("pm2_5", "measurement_time")
  )
  windows <- add_aggregated(windows, past_lag = opts[["past-lag"]], vars = c(BASE_VARS, "wind_dir_scaled"))
  windows <- skip_past(windows)
  windows$station_id <- station_id
  windows
})

windows <- do.call(rbind, windows_for_station)
windows$measurement_time <- utcts(windows$measurement_time)
windows$future_measurement_time <- utcts(windows$future_measurement_time)

series <- windows
save(series, file = opts[["target-file"]])

warning_message <- warnings()
if (!is.null(warning_message)) {
  logfile <- file(file.path(target_dir, paste(opts$method, "imputation_warnings.txt", sep = "_")), open = "w+")
  sink(file = logfile, type = "message")
  warnings()
  sink(type = "message")
  close(logfile)
}
