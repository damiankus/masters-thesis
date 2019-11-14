source("stats_manipulation.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
setwd(accuracy_wd)

packages <- c("optparse")
import(packages)

# Main logic

option_list <- list(
  make_option(c("-d", "--stats-dir"), type = "character", default = "stats"),
  make_option(c("-o", "--output-dir"), type = "character", default = "stats/top-any-strategy")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

stats_dir <- opts[["stats-dir"]]
output_dir <- opts[["output-dir"]]
mkdir(output_dir)


training_strategies <- c("year", "season_and_year")
search_key <- paste("", training_strategies[[1]], "\\.csv", sep = "__")
year_stats_paths <- list.files(
  path = stats_dir,
  pattern = paste("top_models.*", search_key, sep = ""),
  full.names = TRUE
)
common_paths <- unname(sapply(year_stats_paths, function (stats_path) {
  gsub(search_key, "", stats_path)
}))

print(common_paths)

lapply(common_paths, function (common_path) {
  stats_with_strategy <- do.call(
    rbind,
    lapply(training_strategies, function (strategy) {
      stats_paths <- paste(common_path, strategy, ".csv", sep = "__")
      stats <- read.csv(stats_paths)
      stats$training.strategy <- strategy
      stats
    })
  )
  stats <- stats_with_strategy[
    order(
      stats_with_strategy$season,
      stats_with_strategy$mae.mean
    ), ]
  stats$model.type <- as_model_types(stats$model)
  parts <- strsplit(basename(common_path), "__")[[1]]
  phase <- parts[[2]]
  station_id <- parts[[3]]
  
  model_types <- unique(stats$model.type)
  seasons <- sort(unique(stats$season))
  
  # Note that stats have been sorted ascendingly by mean MAE
  which_top_per_season_and_model_type <- unname(do.call(
    c,
    lapply(seasons, function (season) {
      same_season <- stats$season == season
      sort(sapply(model_types, function (model_type) {
        same_type <- stats$model.type == model_type
        which(same_season & same_type)[[1]]
      }))
    })
  ))
  
  cols <- colnames(stats)
  col_contains_measure <- grepl("\\.mean", cols) | grepl("\\.sd", cols)
  measure_cols <- cols[col_contains_measure]
  grouping_cols <- c("model", "season", "training.strategy", "n")
  
  top_stats <- stats[which_top_per_season_and_model_type, c(grouping_cols, measure_cols)]
  output_path <- file.path(output_dir, paste("top_any_strategy", phase, station_id, ".csv", sep = "__"))
  write.csv(
    top_stats,
    file = output_path,
    row.names = FALSE
  )
})
