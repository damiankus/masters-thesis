wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("preprocess.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse")
import(packages)

# MAIN

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "boxplots"),

  # A semicolon separated string with following possible values
  # yearly, monthly, daily, hourly
  # example -t yearly;monthly;daily
  make_option(c("-g", "--group-by"), type = "character", default = "year")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
vars <- BASE_VARS

valid_grouping_types <- c(
  "year",
  "season",
  "month",
  "day_of_week",
  "hour_of_day"
)
grouping_types <- parse_list_argument(opts, "group-by", valid_values = valid_grouping_types)

series$season <- sapply(series$season, function(season) {
  SEASONS[season]
})

series$day_of_week <- sapply(series$day_of_week, function(dow) {
  # Sunday is represented by 0, Saturday by 6
  WEEKDAYS_ABB[if (dow > 0) dow else 7]
})

series$month <- sapply(series$month, function(month) {
  MONTHS_ABB[month]
})

x_orders <- list(
  year = sort(unique(series$year)),
  month = MONTHS_ABB,
  day_of_week = WEEKDAYS_ABB,
  hour_of_day = seq(0, 23)
)

target_dir <- opts[["output-dir"]]
mkdir(target_dir)

lapply(grouping_types, function(grouping_type) {
  lapply(vars, function(var) {
    plot_name <- paste("boxplot_", var, "_by_", grouping_type, ".png", sep = "")
    plot_path <- file.path(target_dir, plot_name)
    save_boxplot(series, grouping_type, var, plot_path, x_order = x_orders[[grouping_type]])
  })
})
