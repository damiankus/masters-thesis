source("accuracy_measures.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
setwd(accuracy_wd)

packages <- c("optparse")
import(packages)
Sys.setenv(LC_ALL = "en_US.UTF-8")

get_ <- function(root_dir) {
  paths <- list.files(path = root_dir, recursive = TRUE, pattern = "*.csv")
  lapply(paths, function (path) {
    parts <- strsplit(x = path, split = file.sep)[[1]]
    
  })
}

# Main logic

option_list <- list(
  make_option(c("-d", "--result-dir"), type = "character", default = "results/")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)



