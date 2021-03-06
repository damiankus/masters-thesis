source("stats_manipulation.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
setwd(accuracy_wd)

packages <- c("optparse", "yaml", "xtable", "ggplot2", "latex2exp", "colorspace")
import(packages)

# Main logic

option_list <- list(
  make_option(c("-d", "--stats-dir"), type = "character", default = "stats"),
  make_option(c("-o", "--output-dir"), type = "character", default = "plots/accurracy")
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
  top_stats <- read.csv(stats_path)
  top_stats[['Phase']] <- meta$phase
  top_stats[['Station ID']] <- meta$station_id
  top_stats[['Training strategy']] <- meta$training_strategy
  top_stats
})

top_stats <- do.call(rbind, top_stats_per_file)
cols <- colnames(top_stats)
mean_cols <- cols[grepl('.mean', cols)]
sd_cols <- cols[grepl('.sd', cols)]
non_measure_cols <- cols[!(cols %in% c(mean_cols, sd_cols))]

stats_with_mean_col <- melt(top_stats, id.vars = non_measure_cols, measure.vars = mean_cols, variable_name = 'mean')
stats_with_sd_col <- melt(top_stats, id.vars = non_measure_cols, measure.vars = sd_cols, variable_name = 'std dev')
plot_data <- stats_with_mean_col[, non_measure_cols]
colnames(plot_data) <- sapply(non_measure_cols, cap)

plot_data$mean <- stats_with_mean_col$value
plot_data$sd <- ifelse(is.na(stats_with_sd_col$value), 0, stats_with_sd_col$value)

measures <- sapply(stats_with_mean_col$mean, function (mean_measure_name) {
  gsub(".mean", "", mean_measure_name)
})

plot_data$Measure <- factor(measures, levels = c("mae", "rmse", "mape", "r", "r2"))
levels(plot_data$Measure) <- c(
  expression(paste('MAE [', mu, 'g/', m^{3}, ']')),
  expression(paste('RMSE [', mu, 'g/', m^{3}, ']')),
  expression(paste('MAPE [%]')),
  expression(paste('r [1]')),
  expression(paste(R ^ 2, ' [1]'))
)

# Reorder factor levels in order to manipulate
plot_data$`Training strategy` <- factor(sapply(top_stats$`Training strategy`, function (value) {
  
  # Change strategy names so that they match names used
  # in best model tables
  
  # Extra quotes are necessary to make it possible to use this column as a facet variable
  # Without them there would be an error thrown while parsing a string
  # containing a whitespace
  switch(value,
         year = "'all data'",
         season_and_year = "'seasonal data'",
         { "''" }
  )
}), levels = c("'all data'", "'seasonal data'"))

lapply(unique(plot_data$Phase), function (phase) {
  stats_for_phase <- plot_data[plot_data$Phase == phase, ]
  lapply(unique(top_stats[['Station ID']]), function (station_id) {
    stats_for_station <- stats_for_phase[stats_for_phase[['Station ID']] == station_id, ]
    models <- as.character(stats_for_station$Model)
    stats_for_station$Model <- factor(models)
    
    unique_models <- sort(unique(models))
    levels(stats_for_station$Model) <- unique_models
    model_levels <- unname(
      TeX(
        unlist(
          lapply(as.character(levels(stats_for_station$Model)), function (raw_name) {
            get_tex_model_name(raw_name) %>%
              gsub("\\\\", " ", fixed = TRUE, .) %>%
              gsub("\\s+", " ", fixed = TRUE, .)
          })
        )   
      )
    )
    
    model_types <- unname(as_model_types(unique_models))
    groups <- sapply(unique(model_types), function (model_type) {
      sum(model_types == model_type)
    })
    
    legend_guide <- if (groups[[1]] == max(groups)) {
      guide_legend(ncol = 1, nrow = groups[[1]])    
    } else {
      guide_legend(ncol = 1)
    }
    
    season_idxs <- stats_for_station$Season  
    stats_for_station$Season <- factor(lapply(season_idxs, function (season_idx) {
      SEASONS[[season_idx]]
    }), levels = c("winter", "spring", "summer", "autumn"))
    
    calculate_vertical_positions <- function (mean_vals, sd_vals) {
      mapply(function (mean_val, sd_val) {
        if (mean_val < 0) {
          0
        } else {
          mean_val + sd_val
        }
      }, mean_vals, sd_vals)
    }
    
    plot <- ggplot(stats_for_station, aes(x = Season, y = mean, fill = Model)) +
      facet_grid(rows = vars(Measure), cols = vars(`Training strategy`), scales = 'free', labeller = label_parsed, switch = 'y') +
      geom_bar(position = "dodge", stat = "identity") +
      geom_errorbar(aes(ymin = mean - sd, ymax = mean + sd), size = .3, width = .6, position = position_dodge(.9)) +
      ggtitle('Prediction accurracy for models trained on:') +
      scale_fill_discrete(labels = model_levels) +
      ylab(NULL) +
      guides(fill = guide_legend(ncol = 1)) +
      theme(
        axis.text.y = element_text(size = 12),
        axis.text.x = element_text(size = 16),
        axis.title.x = element_text(size = 18),
        legend.position = "bottom",
        legend.text.align = 0,
        legend.text = element_text(size = 18),
        legend.title = element_text(size = 18),
        strip.background = element_blank(),
        strip.placement = "outside",
        strip.text.x = element_text(size=18),
        strip.text.y = element_text(size=16),
        panel.spacing = unit(1, "lines"),
        plot.title = element_text(size = 18, hjust = .5)
      ) 
    
    ggsave(
      plot,
      filename = file.path(output_dir, paste('accurracy', phase, station_id, '.png', sep = "__")),
      width = 12,
      height = 14,
      dpi = 200
    )
  })
})
