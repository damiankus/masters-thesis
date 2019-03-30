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
  make_option(c("-v", "--variables"), type = "character", default = "pm2_5"),

  # A semicolon separated string with following possible values
  # yearly, monthly, daily, hourly
  # example -t yearly;monthly;daily
  make_option(c("-g", "--group-by"), type = "character", default = "season"),
  make_option(c("-s", "--split-by"), type = "character", default = "")
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
grouping_varnames <- parse_list_argument(opts, "group-by", valid_values = valid_grouping_types)
split_varnames <- parse_list_argument(opts, "split-by")
varnames <- parse_list_argument(opts, "variables")

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
  season = SEASONS,
  month = MONTHS_ABB,
  day_of_week = WEEKDAYS_ABB,
  hour_of_day = seq(0, 23)
)

output_dir <- opts[["output-dir"]]
mkdir(output_dir)

draw_for_subseries <- function (subseries, subseries_dir, subseries_name = "") {
  subseries_name_infix <- if (nchar(subseries_name) > 0) {
    paste(subseries_name, '_', sep = "")
  } else {
    ""
  }
  lapply(grouping_varnames, function(grouping_var) {
    lapply(varnames, function(varname) {
      plot_name <- paste("boxplot_", subseries_name_infix, varname, "_by_", grouping_var, ".png", sep = "")
      plot_path <- file.path(subseries_dir, plot_name)
      save_boxplot(series, grouping_var, varname, plot_path, x_order = x_orders[[grouping_var]])
    })
  })
}

if (length(split_varnames) > 0) {
  lapply(split_varnames, function (split_varname) {
    split_values <- sort(unique(series[, split_varname]))
    lapply(split_values, function (split_value) {
      which_rows <- series[, split_varname] == split_value
      subseries <- series[which_rows, ]
      subseries_name <- paste('split_by', split_varname, split_value, sep = "_")
      subseries_dir <- file.path(output_dir, subseries_name)
      mkdir(subseries_dir)
      draw_for_subseries(subseries = subseries,
                         subseries_dir = subseries_dir,
                         subseries_name = subseries_name)
    })
  })
} else {
  draw_for_subseries(subseries = series, subseries_dir = output_dir)
}
