source("accuracy_measures.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
setwd(accuracy_wd)

packages <- c("optparse")
import(packages)
Sys.setenv(LC_ALL = "en_US.UTF-8")

calculate_accurracy <- function (results, model_name) {
  data.frame(model = model_name, mae = mae(results), rmse = rmse(results), mape = mape(results), r2 = r2(results))
}

calculate_aggregated_stats <- function (samples) {
  c(mean = mean(samples), sd = sd(samples), n = length(samples))
} 

transform_aggregated <- function (aggregated) {
  all_colnames <- colnames(aggregated)
  grouping_colnames <- intersect(all_colnames, c('model', 'season'))
  accurracy_colnames <- all_colnames[!(all_colnames %in% grouping_colnames)]
  acc_colname <- accurracy_colnames[[1]]
  stat_names <- colnames(aggregated[, acc_colname])
  which_n <- which(stat_names == 'n')
  group_sizes <- aggregated[[acc_colname]][, which_n]
  main_stats <- stat_names[-which_n]
  
  stat_cols <- lapply(accurracy_colnames, function(acc_colname) {
    d <- as.data.frame(aggregated[[acc_colname]][, -which_n])
    colnames(d) <- sapply(main_stats, function (stat_name) {
      paste(acc_colname, stat_name)
    })
    d
  })
  grouping_cols <- data.frame(aggregated[, grouping_colnames])
  colnames(grouping_cols) <- grouping_colnames
  cbind(
    grouping_cols,
    data.frame(n = group_sizes),
    do.call(cbind, stat_cols)
  )
}

# Main logic

option_list <- list(
  make_option(c("-d", "--result-dir"), type = "character", default = file.path("..", "results"))
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

lapply(list.dirs(opts[["result-dir"]], recursive = FALSE), function (dataset_type_dir) {
  dataset_type <- basename(dataset_type_dir)
  
  lapply(list.dirs(dataset_type_dir, recursive = FALSE), function (station_dir) {
    station <- basename(station_dir)
    
    lapply(list.dirs(station_dir, recursive = FALSE), function (training_strategy_dir) {
      training_strategy <- basename(training_strategy_dir)
      
      csv_paths <- list.files(path = training_strategy_dir, pattern = '*.csv') 
      results_paths <- grep(csv_paths, pattern = 'history.csv', invert = TRUE, value = TRUE)
      
      accs_for_strategy <- lapply(results_paths, function (results_path) {
        results <- read.csv(file = file.path(training_strategy_dir, results_path), header = TRUE)
        raw_model_name <- strsplit(results_path, split = "@")[[1]][[1]]
        model <- raw_model_name
        
        season_accs <- lapply(sort(unique(results$season)), function (season) {
          season_results <- results[results$season == season, ]
          acc <- calculate_accurracy(results, model)
          acc$season <- season
          acc
        })
        
        list(
          all_year = calculate_accurracy(results, model),
          seasonal = do.call(rbind, season_accs)
        )
      })
      if (length(accs_for_strategy)) {
        all_year_accs <- do.call(rbind, lapply(accs_for_strategy, function (accs) { accs$all_year }))
        seasonal_accs <- do.call(rbind, lapply(accs_for_strategy, function (accs) { accs$seasonal }))
        all_year_aggr <- aggregate(. ~ model, data = all_year_accs, FUN = calculate_aggregated_stats)
        seasonal_aggr <- aggregate(. ~ model + season, data = seasonal_accs, FUN = calculate_aggregated_stats)

        all_year_stats <- transform_aggregated(all_year_aggr)
        all_year_output_path <- paste(training_strategy_dir, "all_year_accurracy.csv", sep = "_")
        write.csv(
          x = all_year_stats[order(all_year_stats[['mean mae']]), ],
          file = all_year_output_path,
          row.names = FALSE)
        
        seasonal_stats <- transform_aggregated(seasonal_aggr)
        seasonal_output_path <- paste(training_strategy_dir, "seasonal_accurracy.csv", sep = "_")
        write.csv(
          x = seasonal_stats[order(seasonal_stats[['season']], seasonal_stats[['mean mae']]), ],
          file = seasonal_output_path,
          row.names = FALSE)
      }
    })
  })
})
