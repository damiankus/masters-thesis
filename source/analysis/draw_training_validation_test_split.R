wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse")
import(packages)

# vals are assumed to contain all possible values between the min(vals) and max(vals)
get_bounds <- function(vals) {
  if (length(vals) == 0) {
    c(start = NA, end = NA)
  } else if (length(vals) == 1) {
    c(start = vals[[1]], end = vals[[1]])
  } else {
    sorted <- sort(vals)
    c(start = head(sorted, 1), end = tail(sorted, 1))
  }
}

get_bounds_for_option <- function(opts, arg_name, which_from_tail) {
  if (!is.na(opts[[arg_name]])) {
    vals <- parse_list_argument(opts, arg_name)
    get_bounds(vals)
  } else {
    get_bounds(c(
      head(tail(years, which_from_tail), 1)
    ))
  }
}

get_data_split <- function(df, validation_bounds, test_bounds) {
  list(
    training_set = df[df$year < validation_bounds[["start"]], ],
    validation_set = df[validation_bounds[["start"]] <= df$year & df$year <= validation_bounds[["end"]], ],
    test_set = df[test_bounds[["start"]] <= df$year & df$year <= test_bounds[["end"]], ]
  )
}

get_seasonal_data_split <- function(df, validation_bounds, test_bounds, season = 2) {
  seasonal_data <- df[df$season == season, ]
  get_data_split(seasonal_data, validation_bounds, test_bounds)
}

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_windows.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "data-split"),
  make_option(c("-v", "--variables"), type = "character", default = "pm2_5"),
  make_option(c("-l", "--validation-years"), type = "character", default = NA),
  make_option(c("-t", "--test-years"), type = "character", default = NA)
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
output_dir <- opts[["output-dir"]]
mkdir(output_dir)

years <- unique(sort(series$year))
validation_bounds <- get_bounds_for_option(opts, "validation-years", which_from_tail = 2)
test_bounds <- get_bounds_for_option(opts, "test-years", which_from_tail = 1)
variables <- parse_list_argument(opts, "variables")
all_vars <- c(variables, "measurement_time", "season", "year")
series <- series[, all_vars]

lapply(variables, function(var) {
  all_data_plot_path <- file.path(output_dir, "data_split_all_data.png")
  all_data_split <- get_data_split(series, validation_bounds, test_bounds)
  
  res_var <- var
  training_set <- all_data_split$training_set
  validation_set <- all_data_split$validation_set
  test_set <- all_data_split$test_set
  plot_path <- all_data_plot_path
  
  save_data_split(
    res_var = var,
    training_set = all_data_split$training_set,
    validation_set = all_data_split$validation_set,
    test_set = all_data_split$test_set,
    plot_path = all_data_plot_path
  )

  seasonal_path <- file.path(output_dir, "data_split_seasonal.png")
  seasonal_split <- get_seasonal_data_split(series, validation_bounds, test_bounds)
  save_data_split(
    res_var = var,
    training_set = seasonal_split$training_set,
    validation_set = seasonal_split$validation_set,
    test_set = seasonal_split$test_set,
    plot_path = seasonal_path
  )
})
