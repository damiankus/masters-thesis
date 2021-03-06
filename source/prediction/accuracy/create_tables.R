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
  stat_types <- c("mean", "sd")
  excluded_measure <- "r2"
  excluded_cols <- paste(excluded_measure, stat_types, sep = ".")
  
  all_top_stats <- read.csv(stats_path)
  top_stats <- all_top_stats[, !(colnames(all_top_stats) %in% excluded_cols)]
  cols <- colnames(top_stats)
  
  # Prepare accurracy columns
  measure_search_key <- stat_types[[1]]
  measures <- gsub(paste('.', measure_search_key, sep = ""), '', cols[grepl(measure_search_key, cols)])
  measure_cols <- combine_names(measures, stat_types)
  decimal_format <- "%.2f"
  
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
  grouping_cols <- setdiff(cols, c(measure_cols, excluded))
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
  table_content$season <- lapply(grouping_data$season, function (season_idx) {
    cellcolor(SEASONS[[season_idx]], color = SEASON_PALETTE[[season_idx]])
  })
  table_content$training.strategy <- lapply(as.character(table_content$training.strategy), function (strategy) {
    color <- switch(
      strategy,
      year = "FFFFFF",
      season_and_year = "EADAFF"
    )
    
    content <- switch(
      strategy,
      year = "all",
      season_and_year = "seasonal"
    )
    
    # cellcolor(makecell(gsub("_", " \\\\\\\\ ", strategy)), color = color)
    cellcolor(content, color = color)
  })
  
  table <- xtable(
    x = table_content,
    align = c("r", "l", "l", "l", "r", rep("r", length(measure_cols))),
    digits = 2,
    caption = paste("Best results for station ", get_pretty_station_id(meta$station_id), ' (', meta$phase, ' phase)', sep = ""),
    label = paste("tab:results", meta$phase, meta$station_id, meta$training_strategy, sep = "-")
  )
  table_path <- file.path(output_dir, paste('results', meta$phase, meta$station_id, meta$training_strategy, '.tex', sep = "__"))
  formatted_table <- print(
    x = table,
    include.colnames = FALSE,
    include.rownames = FALSE,
    add.to.row = header_config,
    booktabs = TRUE,
    size = "\\scriptsize",
    caption.placement = "top",
    table.placement = "H"
  )
  
  write(
    paste(
      "{",
      "\\setlength{\\tabcolsep}{4pt}",
      formatted_table,
      "}",
      sep = "\n"
    ),
    file = table_path
  )
  
})
