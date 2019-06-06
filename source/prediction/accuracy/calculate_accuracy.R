source("accuracy_measures.R")
source("stats_manipulation.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
setwd(accuracy_wd)

packages <- c("optparse", "yaml")
import(packages)

calculate_accurracy <- function(results, model_name) {
  data.frame(model = model_name, mae = mae(results), rmse = rmse(results), mape = mape(results), r2 = r2(results))
}

calculate_aggregated_stats <- function(samples) {
  c(mean = mean(samples), sd = sd(samples), n = length(samples))
}

# The aggregate function reuturns calculated values as a list numerical matrices
# so we need to transform them to into a data frame in order to save them to a CSV file 
transform_aggregated <- function(aggregated) {
  all_colnames <- colnames(aggregated)
  grouping_colnames <- intersect(all_colnames, c("model", "season"))
  accurracy_colnames <- all_colnames[!(all_colnames %in% grouping_colnames)]
  
  # All accurracy measures have the same corresponding statistics - mean and standard deviation
  # We're picking the first measure but it could be the second or third as well
  acc_colname <- accurracy_colnames[[1]]
  stat_names <- colnames(aggregated[, acc_colname])
  which_n <- which(stat_names == "n")
  group_sizes <- aggregated[[acc_colname]][, which_n]
  main_stats <- stat_names[-which_n]

  stat_cols <- lapply(accurracy_colnames, function(acc_colname) {
    d <- as.data.frame(aggregated[[acc_colname]][, -which_n])
    colnames(d) <- sapply(main_stats, function(stat_name) {
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

get_keys_to_match_results <- function (model_names, seasons) {
  exlcuded_params <- c('split_id')
  mapply(function (model_name, season) {
    processed_model_name <- gsub("__split_id=\\d+", "", model_name)
    paste(processed_model_name, season, sep = "__")
  }, as.list(model_names), as.list(seasons))
}

# Main logic

option_list <- list(
  make_option(c("-d", "--result-dir"), type = "character", default = "../results")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

stats_dir <- "stats"
result_dir <- opts[["result-dir"]]
mkdir(stats_dir)

# the order is important!
phases <- c('validation', 'test')

lapply(phases, function(phase) {
  phase_dir <- file.path(result_dir, phase)

  lapply(list.dirs(phase_dir, recursive = FALSE), function(station_dir) {
    station <- basename(station_dir)
    print(station_dir)
    
    lapply(list.dirs(station_dir, recursive = FALSE), function(training_strategy_dir) {
      training_strategy <- basename(training_strategy_dir)
      
      csv_paths <- list.files(path = training_strategy_dir, pattern = "*.csv")
      results_paths <- grep(csv_paths, pattern = "history.csv", invert = TRUE, value = TRUE)
      
      seasonal_accs_per_file <- lapply(results_paths, function(results_path) {
        results <- read.csv(file = file.path(training_strategy_dir, results_path), header = TRUE)
        model <- strsplit(results_path, split = "@")[[1]][[1]]
        
        seasonal_accs <- lapply(sort(unique(results$season)), function(season) {
          season_results <- results[results$season == season, ]
          acc <- calculate_accurracy(season_results, model)
          acc$season <- season
          acc
        })
        
        do.call(rbind, seasonal_accs)
      })
      
      if (length(seasonal_accs_per_file)) {
        
        seasonal_accs <- do.call(rbind, seasonal_accs_per_file)
        seasonal_aggr <- aggregate(. ~ model + season, data = seasonal_accs, FUN = calculate_aggregated_stats)
        seasonal_stats <- transform_aggregated(seasonal_aggr)
        sorted_stats <- seasonal_stats[order(seasonal_stats[["season"]], seasonal_stats[["mae mean"]]), ]
        
        seasonal_top_per_model <- if (phase == 'test') {
          
          # Test stats may include seasonal results not present
          # in the top stats for the validation phase
          # Results for models trained and tested on data from
          # whole years may be better for a specific season 
          # than the original best model and take its place 
          # in the final top 1 ranking
          
          top_validation_stats_path <- file.path(stats_dir, paste('top_models__validation', station, training_strategy, ".csv", sep = "__"))
          val_stats <- read.csv(file = top_validation_stats_path)
          
          # Regression models are not used in the validation phase
          # since they don't use any parameters which could be tuned
          regression_keys <- get_keys_to_match_results(rep("regression", 4), seq(4))
          validation_keys <- c(regression_keys, get_keys_to_match_results(val_stats$model, val_stats$season))
          test_keys <- get_keys_to_match_results(sorted_stats$model, sorted_stats$season)
          
          which_test_stats_to_include <- sapply(test_keys, function (key) { key %in% validation_keys })

          if (sum(which_test_stats_to_include) != length(validation_keys)) {
            stop("Warning! The number of matchin test models doesn't equal the number original best validation models!")
          }
          sorted_stats[which_test_stats_to_include, ]
          
        } else {
          get_top_stats_per_season_and_model(sorted_stats)
        }
        
        stats_file_name <- paste("accurracy", phase, station, training_strategy, ".csv", sep = "__")
        write.csv(
          x = sorted_stats,
          file = file.path(stats_dir, stats_file_name),
          row.names = FALSE
        )
        
        top_models_file_name <- paste("top_models", phase, station, training_strategy, ".csv", sep = "__")
        write.csv(
          x = seasonal_top_per_model,
          file = file.path(stats_dir, top_models_file_name),
          row.names = FALSE
        )
        
        sorted_stats
        
      } else {
        data.frame()
      }
    })
  })
})
