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
  make_option(c("-o", "--output-file"), type = "character", default = "distribution/distribution.png"),
  make_option(c("-v", "--variable"), type = "character", default = "pm2_5"),
  make_option(c("-w", "--width"), type = "numeric", default = 1280),
  make_option(c("-s", "--font-size"), type = "numeric", default = NA)
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

mkdir(dirname(opts[["output-file"]]))

load(file = opts$file)
save_histogram(series, opts$variable, opts[["output-file"]])
