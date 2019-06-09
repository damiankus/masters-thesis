source("stats_manipulation.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
setwd(accuracy_wd)

packages <- c("optparse", "yaml", "xtable", "ggplot2", "latex2exp")
import(packages)


combine_names <- function (prefixes, sufixes, sep = ".") {
  unlist(lapply(prefixes, function (prefix) {
    as.list(paste(prefix, sufixes, sep = sep))
  }))
}

# Main logic

option_list <- list(
  make_option(c("-d", "--stats-dir"), type = "character", default = "stats/top-any-strategy"),
  make_option(c("-o", "--output-dir"), type = "character", default = "tables"),
  make_option(c("-c", "--decimal-digits"), type = "numeric", default = 2)
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

output_dir <- opts[["output-dir"]]
mkdir(output_dir)

stats_dir <- opts[["stats-dir"]]
stats_paths <- list.files(path = stats_dir, pattern = "top_any.*\\.csv", full.names = TRUE)
options(xtable.sanitize.text.function = identity)

lapply(stats_paths, function (stats_path) {
  meta <- get_stats_metadata(basename(stats_path))
  top_stats <- read.csv(stats_path)
  cols <- colnames(top_stats)
  
  # Prepare accurracy columns
  stat_types <- c('mean', 'sd')
  measure_search_key <- stat_types[[1]]
  all_measures <- gsub(paste('.', measure_search_key, sep = ""), '', cols[grepl(measure_search_key, cols)])
  all_measure_cols <- combine_names(all_measures, stat_types)
  decimal_format <- "%.2f"
  
  # Mean Absolute Percentage Errors turned out to be huge (order of magnitude of 1e6)
  # due to zero PM2.5 values in the test set
  measures <- all_measures[!grepl('mape', all_measures)]
  measure_cols <- combine_names(measures, stat_types)
  sd_cols <- measure_cols[grepl("sd", measure_cols)]
  means_and_sds <- top_stats[, measure_cols]
  means_and_sds[, sd_cols] <- lapply(sd_cols, function (sd_col) {
    lapply(means_and_sds[, sd_col], function (sd_val) {
      if (is.na(sd_val) || sd_val == 0) {
        ""
      } else {
        sprintf(fmt = decimal_format, sd_val)      
      }
    })
  })

  # Prepare columns with grouping variables
  excluded <- c('model.type')
  grouping_cols <- setdiff(cols, c(all_measure_cols, excluded))
  grouping_data <- top_stats[, grouping_cols]
  grouping_data$model <- lapply(as.character(top_stats$model), function (raw_name) {
    makecell(get_tex_model_name(raw_name))
  })
  col_sep <- " & "
  indent <- "\n\t"
  
  grouping_header <- paste(sapply(grouping_cols, get_tex_column_name), collapse = col_sep)
  measure_header <- paste(sapply(measures, get_tex_measure_column_name), collapse = col_sep)
  measure_subheader <- paste(
    paste(rep("", length(grouping_cols)), collapse = col_sep),
    paste(rep(c("mean", "SD"), length(measures)), collapse = col_sep)
  )
  
  table_header <- paste(
    indent,
    grouping_header,
    col_sep,
    measure_header,
    " \\\\",
    indent,
    col_sep,
    measure_subheader,
    " \\\\\n",
    sep = ""
  )
  header_config <- list(
    pos = list(0),
    command = table_header
  )
  
  table_content <- cbind(grouping_data, means_and_sds)
  season_palette <- c(
    winter = "99FFFF",
    spring = "88FF99",
    summer = "FFFF88",
    autumn = "FFAA88"
  )
  table_content$season <- lapply(grouping_data$season, function (season_idx) {
    cellcolor(SEASONS[[season_idx]], color = season_palette[[season_idx]])
  })
  table_content$training.strategy <- lapply(as.character(table_content$training.strategy), function (strategy) {
    color <- switch(
      strategy,
      year = "FFFFFF",
      season_and_year = "EADAFF"
    )
    cellcolor(makecell(gsub("_", " \\\\\\\\ ", strategy)), color = color)
  })
  
  table <- xtable(
    x = table_content,
    align = c("r", "l", "l", "l", "r", rep("r", length(measure_cols))),
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
    tabular.environment = "longtable",
    floating = FALSE,
    include.colnames = FALSE,
    include.rownames = FALSE,
    add.to.row = header_config,
    booktabs = TRUE,
    size = "\\scriptsize"
  )
})
