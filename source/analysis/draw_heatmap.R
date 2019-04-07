wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse")
import(packages)

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_windows.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "relationships"),
  make_option(c("-r", "--response-variables"), type = "character", default = "pm2_5"),
  make_option(c("-v", "--variables"), type = "character", default = "precip_rate,wind_speed"),
  make_option(c("-y", "--test-year"), type = "numeric", default = NA),
  make_option(c("-t", "--show-trend"), type = "numeric", default = FALSE)
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
output_dir <- opts[["output-dir"]]
mkdir(output_dir)
response_variables <- parse_list_argument(opts, "response-variables")
variables <- parse_list_argument(opts, "variables")

test_year <- opts[["test-year"]]
series <- if (!is.na(test_year)) {
  series[series$year < test_year, ]
} else {
  series
}

lapply(response_variables, function(res_var) {
  lapply(variables, function(var) {
    plot_path <- file.path(output_dir, paste("heatmap_", res_var, "_", var, ".png", sep = ""))
    save_heatmap(df = series, var_x = var, var_y = res_var, plot_path = plot_path, show_trend = opts[["show-trend"]])
  })
})
