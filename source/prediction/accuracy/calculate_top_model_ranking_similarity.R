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
  make_option(c("-o", "--output-file"), type = "character", default = "stats/ranking-similarity/ranking-similarity.csv")
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
          station1 = pair$id1,
          station2 = pair$id2,
          kendall_cor = calculate_kendall_similarity(models_1, models_2)
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
write.csv(per_phase_merged[order(per_phase_merged$kendall_cor, decreasing = TRUE), ], file = opts[["output-file"]])

