wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.R')
setwd(wd)

packages <- c('optparse', 'parallel')
import(packages)

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_series.Rda"),
  make_option(c("-c", "--config-file"), type = "character", default = "configs/regression.yaml")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)