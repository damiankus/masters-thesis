wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
setwd(wd)

import("optparse")

option_list <- list(
  make_option(c("-d", "--source-dir"), type = "character", default = "datasets"),
  make_option(c("-t", "--target-dir"), type = "character", default = "preprocessed")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

mkdir(path = opts[["source-dir"]])
mkdir(path = opts[["target-dir"]])

excluded_vars <- c("id")
fpaths <- list.files(path = opts[["source-dir"]], pattern = "*.csv", full.names = TRUE)

lapply(fpaths, function(fpath) {
  print(paste("Processing", fpath))
  series <- read.csv(file = fpath, sep = ";", header = TRUE, stringsAsFactors = FALSE)
  cols <- setdiff(colnames(series), excluded_vars)
  series <- series[, cols]
  series$measurement_time <- utcts(series$measurement_time)
  series$station_id <- sapply(series$station_id, trimws)

  path_parts <- unlist(strsplit(fpath, "/"))
  fname_parts <- unlist(strsplit(tail(path_parts, 1), "[.]"))
  fname <- paste(head(fname_parts, 1), ".Rda", sep = "")

  rda_fpath <- file.path(opts["target-dir"], fname)
  print(paste("Saving under", rda_fpath))
  save(series, file = rda_fpath)
  rda_fpath
})
