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
  make_option(c("-o", "--output-dir"), type = "character", default = "plots/training-history"),
  make_option(c("-r", "--root-result-dir"), type = "character", default = file.path("..", "results"))
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

stats_dir <- opts[["stats-dir"]]
root_results_dir <- opts[["root-result-dir"]]
output_dir <- opts[["output-dir"]]
mkdir(output_dir)

stats_paths <- list.files(path = stats_dir, pattern = "top_models.*\\.csv", full.names = TRUE)
top_stats_per_file <- lapply(stats_paths, function (stats_path) {
  meta <- get_stats_metadata(basename(stats_path))
  top_stats <- read.csv(stats_path)
  model_types <- as_model_types(top_stats$model)
  
  model_names <- top_stats$model
  seasons <- top_stats$season
  
  lapply(seq_along(model_names), function (idx) {
    model_name <- model_names[[idx]]
    season <- seasons[[idx]]
    
    result_dir <- file.path(root_results_dir, meta$phase, meta$station_id, meta$training_strategy)
    history_paths <- list.files(result_dir, pattern = paste(model_name, ".*history\\.csv", sep = ""), full.names = TRUE)
    
    lapply(history_paths, function (history_path) {
      history <- read.csv(history_path)
      plot_data <- history[history$metric == "mean_absolute_error", ]
      y_label <- expression(paste('MAE [', mu, 'g/', m^{3}, ']'))
      
      plot <- ggplot(data = plot_data, aes(x = epoch, y = value, color = data)) +
        geom_line() +
        xlab("Epoch") + 
        ylab(y_label)
      
      history_file_name <- gsub("\\@repetition(\\d+)_history\\.csv", "", basename(history_path))
      plot_path <- file.path(
        output_dir,
        paste(
          "history",
          history_file_name,
          meta$phase,
          meta$training_strategy,
          ".png",
          sep = "__")
      )
      
      ggsave(
        plot,
        filename = plot_path,
        width = 5,
        height = 4
      )
      
    })
  })
})
