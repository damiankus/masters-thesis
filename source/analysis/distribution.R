wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse")
import(packages)

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "imputed/mice_time_windows.Rda"),
  make_option(c("-o", "--output-file"), type = "character"),
  make_option(c("-v", "--variable"), type = "character"),
  make_option(c("-w", "--width"), type = "numeric", default = 1280),
  make_option(c("-s", "--font-size"), type = "numeric", default = NA)
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
save_histogram(series, opts$variable, opts[["output-file"]])
