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
  make_option(c("-o", "--output-file"), type = "character", default = "imputed/mice/observations_imputed_mice.Rda"),
  make_option(c("-m", "--method"), type = "character", default = "mice"),
  make_option(c("-i", "--iterations"), type = "numeric", default = 30),
  make_option(c("-a", "--algorithm"), type = "character", default = "StructTS"),
  make_option(c("-v", "--variables"), type = "character", default = paste(default_vars, collapse = ",")),
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

series <- series[order(series$measurement_time), ]
which_to_impute <- (series$year < test_year)
series_to_impute <- series[which_to_impute, ]
unchanged_series <- series[!which_to_impute, ]
original_series <- data.frame(series)

output_dir <- dirname(opts[["output-file"]])
mkdir(output_dir)

imputed_for_stations <- if (opts$method == "mice") {
  # MICE imputation
  # Based on https://cran.r-project.org/web/packages/mice/mice.pdf
  # See: https://datascienceplus.com/imputing-missing-data-with-r-mice-package/
  lapply(stations, function(station_id) {
    print(paste("[MICE] Imputing data for station", station_id))
    series_for_station <- series_to_impute[series_to_impute$station_id == station_id, ]
    which_to_impute <- is.na(series_for_station[, imputed_vars])
    mids <- mice(data = series_for_station[, imputed_vars], m = 1, maxit = opts$iterations, where = which_to_impute)
    imputed_cols <- complete(mids, 1)
    
    convergence_plot_path <- file.path(output_dir, paste(station_id, "mice_convergence.png", sep = "_"))
    png(filename = convergence_plot_path, width = 800, height = 800, pointsize = 20)
    plot(mids)
    dev.off()

    density_plot_path <- file.path(output_dir, paste(station_id, "mice_density_plot.png", sep = "_"))
    png(filename = density_plot_path, width = 800, height = 800, pointsize = 20)
    densityplot(mids)
    dev.off()

    strip_plot_path <- file.path(output_dir, paste(station_id, "mice_strip_plot.png", sep = "_"))
    png(filename = strip_plot_path, width = 800, height = 800, pointsize = 20)
    stripplot(mids, pch = 20, cex = 1.2)
    dev.off()
    
    # if there is only a single response variable,
    # the slice is a vector so the column name is lost
    response_cols <- data.frame(series_for_station[, response_vars])
    colnames(response_cols) <- response_vars
    cbind(
      series_for_station[, time_place_vars], 
      response_cols,
      imputed_cols,
      series_for_station[, remaining_vars]
    )
  })
} else {
  # ImputeTS imputation
  # Based on https://cran.r-project.org/web/packages/imputeTS/vignettes/imputeTS-Time-Series-Missing-Value-Imputation-in-R.pdf
  lapply(stations, function(station_id) {
    print(paste("[ImputeTS, ", opts$method, "] Imputing data for station ", station_id, sep = ""))
    series_for_station <- series_to_impute[series_to_impute$station_id == station_id, ]
    imputed_cols <- lapply(imputed_vars, function(var) {
      print(paste("Imputing for", get_pretty_var(var)))
      col <- series_for_station[, var]
      get_imputed <- get(paste("na.", opts$method, sep = ""))
      get_imputed(col)
    })
    series_for_station[, imputed_vars] <- imputed_cols
    series_for_station
  })
}
new_series <- rbind(do.call(rbind, imputed_for_stations), unchanged_series)
series <- new_series[order(new_series$measurement_time), ]
save(series, file = opts[["output-file"]])
print(paste('File saved in', opts[["output-file"]]))

# Visualizing imputations
lapply(stations, function(station_id) {
  print(paste("Plotting imputed data for station ", station_id, sep = ""))
  original_series_for_station <- original_series[original_series$station_id == station_id, ]
  series_for_station <- series[series$station_id == station_id, ]
  
  imputed_cols <- lapply(imputed_vars, function(var) {
    print(paste("Visualizing missing observations for", get_pretty_var(var)))
    original_col <- original_series_for_station[, var]
    imputed_col <- series_for_station[, var]
    
    gapsize_path <- file.path(output_dir, paste("gapsize_", var, "_", station_id, ".png", sep = ""))
    png(filename = gapsize_path, width = 800, height = 800, pointsize = 10)
    plotNA.gapsize(x = original_col, ylab = get_or_generate_label(var), main = "")
    dev.off()
    
    na_distribution_path <- file.path(output_dir, paste("na_distribution_", var, "_", station_id, ".png", sep = ""))
    png(filename = na_distribution_path, width = 1024, height = 768, pointsize = 20)
    plotNA.distribution(x = original_col, ylab = get_or_generate_label(var), main = "")
    dev.off()
    
    imputation_path <- file.path(output_dir, paste("imputations_", var, "_", station_id, ".png", sep = ""))
    png(filename = imputation_path, width = 1024, height = 768, pointsize = 20)
    plotNA.imputations(x.withNA = original_col, x.withImputations = imputed_col,
                       ylab = get_or_generate_label(var), main = "")
    dev.off()
  })
})

warning_message <- warnings()
if (!is.null(warning_message)) {
  logfile <- file(file.path(output_dir, paste(opts$method, "imputation_warnings.txt", sep = "_")), open = "w+")
  sink(file = logfile, type = "message")
  warnings()
  sink(type = "message")
  close(logfile)
}
