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
  make_option(c("-d", "--stats-dir"), type = "character", default = "stats/top-any-strategy"),
  make_option(c("-o", "--output-dir"), type = "character", default = "plots/comparison"),
  make_option(c("-r", "--root-result-dir"), type = "character", default = file.path("..", "results")),
  make_option(c("-b", "--date-breaks-unit"), type = "character", default = "1 week"),
  make_option(c("-c", "--max-result-count"), type = "numeric")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

stats_dir <- opts[["stats-dir"]]
root_results_dir <- opts[["root-result-dir"]]
output_dir <- opts[["output-dir"]]
mkdir(output_dir)

max_result_count <- if (!is.null(opts[["max-result-count"]])) {
  as.numeric(opts[["max-result-count"]])
} else {
  0
}
phases <- c('validation', 'test')

stats_paths <- list.files(path = stats_dir, pattern = "top_any.*\\.csv", full.names = TRUE)
top_stats_per_file <- lapply(stats_paths, function (stats_path) {
  parts <- strsplit(stats_path, "__")[[1]]
  phase <- parts[[2]]
  station_id <- parts[[3]]
  stats <- read.csv(stats_path)
  
  which_best_per_season <- sapply(sort(unique(stats$season)), function (season) {
    which(stats$season == season)[[1]]
  })
  top_stats <- stats[which_best_per_season, ]
  top_stats$model_type <- as_model_types(top_stats$model)
  
  lapply(seq_along(top_stats$model), function (idx) {
    cur_stats <- top_stats[idx, ]
    
    result_dir <- file.path(root_results_dir, phase, station_id, cur_stats$training.strategy)
    history_paths <- list.files(result_dir, pattern = paste(cur_stats$model, ".*history\\.csv", sep = ""), full.names = TRUE)
    csv_paths <- list.files(result_dir, pattern = paste(cur_stats$model, ".*\\.csv", sep = ""), full.names = TRUE)
    result_paths <- setdiff(csv_paths, history_paths)
    
    repetition_results <- lapply(result_paths, function (result_path) {
      results <- read.csv(result_path)
      seasonal_results <- results[results$season == cur_stats$season, ]
      
      if (max_result_count > 0) {
        seasonal_results[1:max_result_count, ]
      } else {
        seasonal_results
      }
    })
    merged_results <- do.call(rbind, repetition_results)
    
    cols <- colnames(merged_results)
    grouping_cols <- cols[cols != "predicted"]
    aggr_formula <- as.formula(paste('. ~', paste(grouping_cols, collapse = " + ")))
    aggr_results <- aggregate(aggr_formula, data = merged_results, FUN = mean)
    aggr_results$measurement_time <- utcts(aggr_results$measurement_time)
    sorted_results <- aggr_results[order(aggr_results$measurement_time), ]

    plot_path <- file.path(
      output_dir,
      paste(
        'comparison',
        phase,
        station_id,
        cur_stats$model_type,
        cur_stats$season,
        ".png",
        sep = "__"
      )
    )

    save_comparison_plot(
      df = sorted_results,
      res_var = 'pm2_5',
      plot_path = plot_path,
      date_breaks_unit = opts[['date-breaks-unit']]
    )
  })
})
