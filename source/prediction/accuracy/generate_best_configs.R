source("stats_manipulation.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
setwd(accuracy_wd)

packages <- c("optparse", "yaml")
import(packages)


# Main logic

option_list <- list(
  make_option(c("-d", "--stats-dir"), type = "character", default = "result-stats")
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

test_config_dir <- "test-configs"
mkdir(test_config_dir)

stats_dir <- opts[["stats-dir"]]
stats_paths <- list.files(path = stats_dir, pattern = "top_models.*validation.*\\.csv", full.names = TRUE)
lapply(stats_paths, function(stats_path) {
  meta <- get_stats_metadata(stats_path)
  
  # Generate configurations with best parameters found
  # during the validation phase
  stats <- read.csv(stats_path)
  top_model_configs <- lapply(seq(nrow(stats)), function (idx) {
    row <- stats[idx, ]
    parts <- strsplit(as.character(row$model), "__")[[1]]
    model_type <- parts[[1]]
    key_vals <- parts[-1]

    keys <- lapply(key_vals, function (key_val) {
      strsplit(key_val, "=")[[1]][[1]]
    })

    vals <- lapply(key_vals, function (key_val) {
      strsplit(key_val, "=")[[1]][[2]]
    })

    names(vals) <- keys
    vals$type <- model_type

    if (is.null(row$season) || meta$training_strategy == "year") {
      vals
    } else {
      c(vals, list(split_id = row$season))
    }
  })
  is_neural <- as_model_types(stats$model) == 'neural_network'

  common_config <- list(
    split_type = meta$training_strategy,
    test_years = list(2018),
    output_dir = "results/test/",
    stations = list(meta$station_id)
  )

  neural_config <- c(
    common_config,
    list(
      repetitions = 5,
      models = top_model_configs[is_neural]
    )
  )

  other_config <- c(
    common_config,
    list(
      repetitions = 1,
      models = c(
        list(list(type = "regression")),
        top_model_configs[!is_neural]
      )
    )
  )

  write_yaml(
    x = list(neural_config),
    file = file.path(test_config_dir, paste(meta$station_id, meta$training_strategy, "top_neural_config.yaml", sep = "__"))
  )

  write_yaml(
    x = list(other_config),
    file = file.path(test_config_dir, paste(meta$station_id, meta$training_strategy, "top_other_config.yaml", sep = "__"))
  )
})
