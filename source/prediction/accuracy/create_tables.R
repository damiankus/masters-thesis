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
  make_option(c("-o", "--output-dir"), type = "character", default = "tables"),
  make_option(c("-c", "--decimal-digits"), type = "numeric", default = 2)
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
  cols <- colnames(top_stats)
  stat_types <- c('mean', 'sd')
  measure_search_key <- stat_types[[1]]
  all_measures <- gsub(paste('.', measure_search_key, sep = ""), '', cols[grepl(measure_search_key, cols)])
  measures <- all_measures[!grepl('mape', all_measures)]
  decimal_format <- paste("%#.", opts[["decimal-digits"]], "f", sep = "")
  combined_stats_format <- make_cell(paste(decimal_format, "$\\pm$", decimal_format), align = "tr")
  zero_sd_sufix <- " $\\pm$ 0.00"
  zero_sd_sufix_replacement <- paste(rep("\\ ", nchar(zero_sd_sufix) + 2), collapse = "")
  
  combined_measures <- lapply(measures, function (measure) {
    measure_cols <- paste(measure, stat_types, sep = ".")
    mapply(
      function (stat1, stat2) {
        if (is.na(stat2) || stat2 == 0) {
          mean_with_sd <- sprintf(fmt = combined_stats_format, stat1, 0)
          gsub(zero_sd_sufix, zero_sd_sufix_replacement, mean_with_sd, fixed = TRUE)
        } else {
          sprintf(fmt = combined_stats_format, stat1, stat2)
        }
      },
      top_stats[[measure_cols[[1]]]],
      top_stats[[measure_cols[[2]]]]
    )
  })
  combined_stats <- do.call(cbind, combined_measures)
  colnames(combined_stats) <- sapply(measures, get_tex_measure_column_name)
  cols_per_measure <- lapply(all_measures, function (measure) {
    as.list(paste(measure, stat_types, sep = "."))
  })
  all_measure_cols <- do.call(cbind, unlist(cols_per_measure, recursive = FALSE))
  non_measure_cols <- setdiff(cols, all_measure_cols)
  non_measure_data <- top_stats[, non_measure_cols]
  non_measure_data$model <- lapply(as.character(top_stats$model), get_tex_model_name)
  colnames(non_measure_data) <- sapply(colnames(non_measure_data), get_tex_column_name)
  table_content <- cbind(non_measure_data, combined_stats)
  
  table <- xtable(
    x = table_content,
    align = c("r", "l", rep("r", ncol(table_content) - 1)),
    digits = 2,
    caption = paste("Results for station ", get_pretty_station_id(meta$station_id),
                    ' and a data-splitting strategy based on ', gsub("_", " ", meta$training_strategy),
                    ' (', meta$phase, ' phase)', sep = ""),
    label = paste("tab:results", meta$phase, meta$station_id, meta$training_strategy, sep = "-")
  )
  table_path <- file.path(output_dir, paste('results', meta$phase, meta$station_id, meta$training_strategy, '.tex', sep = "__"))
  print(
    x = table,
    file = table_path,
    tabular.environment = "tabularx",
    width = "\\textwidth",
    include.rownames = FALSE
  )
})
