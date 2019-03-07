wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse")
import(packages)

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "distribution"),
  make_option(c("-v", "--variables"), type = "character", default = "pm2_5"),
  make_option(c("-w", "--width"), type = "numeric", default = 1280),
  make_option(c("-s", "--font-size"), type = "numeric", default = NA),
  make_option(c("-g", "--group-by"), type = "character", default = NA)
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
output_dir <- opts[["output-dir"]]
mkdir(output_dir)
variables <- parse_list_argument(opts, "variables")

draw_histograms <- if (is.na(opts[["group-by"]])) {
  function (var) {
    plot_path <- file.path(output_dir, paste('histogram_', var, '.png', sep = ""))
    save_histogram(series, var, plot_path)
  }
} else {
  grouping_vars <- parse_list_argument(opts, "group-by")
  function (var) {
    lapply(grouping_vars, function(grouping_var) {
      grouping_col <- series[, grouping_var]
      lapply(unique(grouping_col), function (grouping_value) {
        plot_name <- paste("histogram_", var, "_by_", grouping_var, "_equal_", grouping_value, ".png", sep = "")
        plot_path <- file.path(output_dir, plot_name)
        subseries <- series[grouping_col == grouping_value, ]
        save_histogram(subseries, var, plot_path)
      })
    })
  }
}

lapply(variables, draw_histograms)