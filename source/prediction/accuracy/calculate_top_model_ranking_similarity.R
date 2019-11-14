source("stats_manipulation.R")
source("ranking_similarity_measures.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("constants.R")
setwd(accuracy_wd)

packages <- c("optparse")
import(packages)

# Main logic

option_list <- list(
  make_option(c("-d", "--stats-dir"), type = "character", default = "stats"),
  make_option(c("-a", "--all-stats-output-file"), type = "character", default = "stats/merged/accuracy-merged.csv"),
  make_option(c("-o", "--output-file"), type = "character", default = "tables/ranking-similarity.tex")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

stats_dir <- opts[["stats-dir"]]
merged_stats_output_dir <- dirname(opts[["all-stats-output-file"]])
mkdir(merged_stats_output_dir)
output_dir <- dirname(opts[["output-file"]])
mkdir(output_dir)

stat_paths <- list.files(
  path = stats_dir,
  pattern = "accurracy__.*",
  full.names = TRUE
)

file_contents <- lapply(stat_paths, function (stat_path) {
  stats <- read.csv(file = stat_path)
  meta <- get_stats_metadata(basename(stat_path))
  stats$phase <- meta$phase
  stats$training_strategy <- meta$training_strategy
  stats$station_id <- meta$station_id
  stats
})

raw <- do.call(rbind, file_contents)
ordered_idxs <- order(
  raw$phase,
  raw$station_id,
  raw$season,
  raw$mae.mean
)
merged <- raw[ordered_idxs, ]
write.csv(x = merged, file = opts[["all-stats-output-file"]], row.names = FALSE)

# phases <- sort(unique(merged$phase))
phases <- c('validation')
training_strategies <- sort(unique(merged$training_strategy))
seasons <- sort(unique(merged$season))
station_ids <- sort(unique(merged$station_id))

ranking <- merged[, c('station_id', 'model', 'phase', 'season', 'training_strategy', 'mae.mean')]
n <- length(station_ids)
station_id_pairs <- do.call(
  rbind,
  lapply(seq(n - 1), function (i) {
    pairs <- lapply(seq(i + 1, n), function (j) {
      data.frame(id1 = station_ids[[i]], id2 = station_ids[[j]])
    })
    do.call(rbind, pairs)
  })
)

per_phase <- lapply(phases, function (phase) {
  phase_stats <- ranking[ranking$phase == phase, ]
  per_strategy <- lapply(training_strategies, function (strategy) {
    strategy_stats <- phase_stats[phase_stats$training_strategy == strategy, ]
    
    per_season <- lapply(seasons, function (season) {
      season_stats <- strategy_stats[strategy_stats$season == season, ]
      per_station_pair <- lapply(seq(nrow(station_id_pairs)), function (idx) {
        pair <- station_id_pairs[idx, ]
        all_models_1 <- season_stats[season_stats$station_id == pair$id1, 'model']
        all_models_2 <- season_stats[season_stats$station_id == pair$id2, 'model']
        common_models <- intersect(all_models_1, all_models_2)
        models_1 <- all_models_1[all_models_1 %in% common_models]
        models_2 <- all_models_2[all_models_2 %in% common_models]
        data.frame(
          station.1 = pair$id1,
          station.2 = pair$id2,
          kendall.cor = calculate_kendall_similarity(models_1, models_2)
        )
      })
      per_station_pair_merged <- do.call(rbind, per_station_pair)
      per_station_pair_merged$season <- SEASONS[[season]]
      per_station_pair_merged
    })
    per_season_merged <- do.call(rbind, per_season)
    per_season_merged$training.strategy <- strategy
    per_season_merged
  })
  per_strategy_merged <- do.call(rbind, per_strategy)
  per_strategy_merged$phase <- phase
  per_strategy_merged
})

per_phase_merged <- do.call(rbind, per_phase)
sorted_taus <- per_phase_merged[order(per_phase_merged$kendall.cor, decreasing = TRUE), ]

raw_cols <- c("station.1", "station.2", "season", "training.strategy", "kendall.cor")
which_tau <- which(raw_cols == "kendall.cor")
formatted_names <- lapply(seq_along(raw_cols), function (idx) {
  col <- raw_cols[[idx]]
  content <- get_tex_column_name_content(col)
  align <- if (idx == which_tau) {
    "tr"
  } else {
    "tl"
  }
  makecell(content, align = align)
})
formatted_names[[which_tau]] <- gsub(
  "Kendall cor", 
  "\\\\texttau\\\\ {[1]}",
  formatted_names[[which_tau]]
)

ranking <- sorted_taus[, raw_cols]
ranking$training.strategy <- lapply(sorted_taus$training.strategy, function (strategy) {
  switch(
    strategy,
    year = "all",
    season_and_year = "seasonal",
    { "unknown" }
  )
})
ranking$station.1 <- lapply(sorted_taus$station.1, function (id) {
  gsub("GIOS ", "", get_pretty_station_id(id))
})
ranking$station.2 <- lapply(sorted_taus$station.2, function (id) {
  gsub("GIOS ", "", get_pretty_station_id(id))
})

corr_threshold <- 0.7
oringinal_kendall_cors <- ranking$kendall.cor
ranking$kendall.cor <- unlist(lapply(oringinal_kendall_cors, function (corr) {
  rounded_corr <- round_numeric(corr)
  if (corr >= corr_threshold) {
    cellcolor(rounded_corr, color = SEASON_PALETTE$spring)
  } else {
    rounded_corr
  }
}))

save_table(
  content = ranking,
  align = c("r", rep("l", ncol(ranking) - 1), rep("r")),
  caption = "Kendall correlation coefficients for pairs of model rankings corresponding to monitoring stations",
  label = "tab:results-kendall-correlation-values",
  col_names = formatted_names,
  file = file.path(opts[["output-file"]]), 
  line_spacing = 1.25,
  font_size = "\\footnotesize"
)


