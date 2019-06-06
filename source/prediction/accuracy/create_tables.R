source("stats_manipulation.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
setwd(accuracy_wd)

packages <- c("optparse", "yaml", "xtable", "ggplot2", "latex2exp")
import(packages)

# Main logic

option_list <- list(
  make_option(c("-d", "--stats-dir"), type = "character", default = "stats"),
  make_option(c("-o", "--output-dir"), type = "character", default = "tables")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

output_dir <- opts[["output-dir"]]
mkdir(output_dir)

stats_dir <- opts[["stats-dir"]]
stats_paths <- list.files(path = stats_dir, pattern = "top_models.*\\.csv", full.names = TRUE)
options(xtable.sanitize.text.function = identity)

lapply(stats_paths, function (stats_path) {
  meta <- get_stats_metadata(basename(stats_path))
  top_stats <- read.csv(stats_path)
  
  # Mean Absolute Percentage Errors turned out to be huge (order of magnitude of 1e6)
  # due to zero PM2.5 values in the test set
  which_mape <- grepl('mape', colnames(top_stats))
  table_content <- top_stats[, !which_mape]
  table_content$model <- lapply(as.character(top_stats$model), get_pretty_model_name)
  colnames(table_content) <- sapply(colnames(table_content), get_tex_column_name)
  
  table <- xtable(
    x = table_content,
    align = c("r", "p{0.1\\textwidth}", rep("r", ncol(table_content) - 1)),
    digits = 2,
    caption = paste("Results for station ", get_pretty_station_id(meta$station_id),
                    ' and a data-splitting strategy based on ', gsub("_", " ", meta$training_strategy),
                    ' (', meta$phase, ' phase)', sep = ""),
    label = paste("tab:results", meta$phase, meta$station_id, meta$training_strategy, sep = "-")
  )
  table_path <- file.path(output_dir, paste('results', meta$phase, meta$station_id, meta$training_strategy, '.tex', sep = "__"))
  print(x = table, file = table_path, include.rownames = FALSE)
})
