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
  make_option(c("-o", "--output-dir"), type = "character", default = "accurracy-plots")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

output_dir <- opts[["output-dir"]]
mkdir(output_dir)

stats_dir <- opts[["stats-dir"]]
stats_paths <- list.files(path = stats_dir, pattern = "top_models.*\\.csv", full.names = TRUE)
options(xtable.sanitize.text.function = identity)

top_stats_per_file <- lapply(stats_paths, function (stats_path) {
  meta <- get_stats_metadata(basename(stats_path))
  stats <- read.csv(stats_path)
  
  # Mean Absolute Percentage Errors turned out to be huge (order of magnitude of 1e6)
  # due to zero PM2.5 values in the test set
  which_mape <- grepl('mape', colnames(stats))
  top_stats <- stats[, !which_mape]
  top_stats$model <- lapply(as.character(stats$model), get_pretty_model_name)
  top_stats[['Phase']] <- meta$phase
  top_stats[['Station ID']] <- meta$station_id
  top_stats[['Training strategy']] <- meta$training_strategy
  top_stats
})

top_stats <- do.call(rbind, top_stats_per_file)
colnames(top_stats) <- sapply(colnames(top_stats), get_pretty_column_name)
cols <- colnames(top_stats)
mean_cols <- cols[grepl('Mean', cols)]
sd_cols <- cols[grepl('std dev', cols)]
non_measure_cols <- cols[!(cols %in% c(mean_cols, sd_cols))]

stats_with_mean_col <- melt(top_stats, id.vars = non_measure_cols, measure.vars = mean_cols, variable_name = 'mean')
stats_with_sd_col <- melt(top_stats, id.vars = non_measure_cols, measure.vars = sd_cols, variable_name = 'std dev')
plot_data <- stats_with_mean_col[, non_measure_cols]
plot_data$mean <- stats_with_mean_col$value
plot_data$sd <- ifelse(is.na(stats_with_sd_col$value), 0, stats_with_sd_col$value)

plot_data$Model <- as.factor(unlist(top_stats$Model))
plot_data$Measure <- factor(sapply(stats_with_mean_col$mean, function (mean_measure_name) {
  gsub("Mean\\s+", "", mean_measure_name)
}), levels = c(
  "MAE",
  "RMSE",
  "$R^2$"
))

levels(plot_data$Measure) <- c(
  expression(paste('MAE [', mu, 'g/', m^{3}, ']')),
  expression(paste('RMSE [', mu, 'g/', m^{3}, ']')),
  expression(paste(R ^ 2, ' [1]'))
)

plot_data$`Training strategy` <- factor(sapply(top_stats$`Training strategy`, function (value) {
  # Extra quotes are necessary to make it possible to use this column as a facet variable
  # Without them there would be an error thrown while parsing a string
  # containing a whitespace
  paste("'", gsub("_", " ", value), "'", sep = "")
}), levels = c("'year'", "'season and year'"))

plot_data$Season <- factor(sapply(top_stats$Season, function (idx) {
  SEASONS[[idx]]
}), levels = c('winter', 'spring', 'summer', 'autumn'))

lapply(unique(plot_data$Phase), function (phase) {
  stats_for_phase <- plot_data[plot_data$Phase == phase, ]
  lapply(unique(top_stats[['Station ID']]), function (station_id) {
    stats_for_station <- stats_for_phase[stats_for_phase[['Station ID']] == station_id, ]
    
    plot <- ggplot(stats_for_station, aes(x = Season, y = mean, fill = Model)) +
      facet_grid(rows = vars(Measure), cols = vars(`Training strategy`), scales = 'free', labeller = label_parsed, switch = 'y') +
      geom_bar(position = "dodge", stat = "identity") +
      geom_errorbar(aes(ymin = mean - sd, ymax = mean + sd), size = .3, width = .6, position = position_dodge(.9)) +
      ggtitle('Prediction accurracy for data split by') +
      ylab(NULL) +
      guides(fill = guide_legend(ncol = 2)) +
      theme(
        legend.position = "bottom",
        strip.placement = "outside",
        strip.background = element_blank(),
        plot.title = element_text(hjust = .5)
      )
    
    ggsave(
      plot,
      filename = file.path(output_dir, paste('accurracy', phase, station_id, '.png', sep = "__")),
      width = 10,
      height = 7
    )
  })
})
