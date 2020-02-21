source("stats_manipulation.R")

accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("constants.R")
setwd(accuracy_wd)

packages <- c("optparse", "dplyr", "latex2exp", "viridis", "reshape", "ggplot2")
import(packages)

format_label <- function (values) {
  sapply(values, function (v) {
    if (v > 0) {
      format(round(v, 2), nsmall = 2)
    } else {
      ""
    }
  })
}

get_param_exponent <- function (model_type) {
  switch(
    model_type,
    "neural network" = 10,
    "svr" = 2,
    { 0 }
  ) 
}

draw_accuracy_differences_between_stations_and_seasons <- function (
      all_stats, id_var, measure_var, plot_path, metastat_names = c("min", "median", "max")) {
  stations <- sort(unique(all_stats$station_id))
  seasons <- sort(unique(all_stats$season))
  
  per_season <- lapply(seasons, function(season) {
    per_station <- lapply(stations, function(station) {
      
      which_stats <- (all_stats$season == season) &
        (all_stats$station_id == station)
      
      stats <- all_stats[which_stats, c(id_var, measure_var)]
      id_values <- sort(unique(stats[, id_var]))
      get_metastats <- function (metastat_names) {
        
        per_id_value <- lapply(id_values, function(id_value, measure_var) {
          stats_for_id_value <- stats[stats[, id_var] == id_value, measure_var]
          per_name <- lapply(metastat_names, function(stat_name, measure_var) {
            stat_fun <- get(stat_name)
            stat_fun(stats_for_id_value)
          }, measure_var = measure_var)
          
          data.frame(do.call(cbind, per_name))
        }, measure_var = measure_var)
        
        metastats <- do.call(rbind, per_id_value)
        metastats[, id_var] <- id_values
        colnames(metastats) <- c(metastat_names, id_var)
        metastats
      }
      
      metastats <- get_metastats(metastat_names)
      relative_metastat_cols <- lapply(metastats[, colnames(metastats) != id_var], function (col) {
        col - min(col)
      })
      
      result <- data.frame(
        season = season,
        station_id = station,
        do.call(cbind, relative_metastat_cols)
      )
      result[, id_var] <- metastats[, id_var]
      result
    })
    do.call(rbind, per_station)
  })
  
  per_season_merged <- do.call(rbind, per_season)
  stat_comparison <- melt(per_season_merged, measure.vars = metastat_names, variable_name = "statistic")
  
  plot <- ggplot(stat_comparison, aes_string(x = "statistic", y = "value", fill = id_var)) +
    facet_grid(rows = vars(season), cols = vars(station_id), scales = 'free', switch = 'y') +
    geom_bar(stat = "identity") +
    # geom_text(
    #   aes(
    #     y = value * 1.2,
    #     label = ""
    #   )
    # ) +
    # geom_text(
    #   aes(
    #     label = format_label(value),
    #     x = statistic,
    #     y = value
    #   ),
    #   vjust = -0.6,
    #   size = 3
    # ) +
    ylab(TeX(paste("Relative difference \\[", get_tex_measure_units(measure_var), "\\]"))) +
    xlab(TeX(paste(get_tex_full_measure_name(measure_var), "aggregate statistics"))) +
    guides(fill = guide_legend(title = cap(get_pretty_var(id_var)))) +
    theme(
      axis.text.y = element_text(size = 12),
      axis.text.x = element_text(size = 10),
      legend.position = "bottom",
      legend.text.align = 0,
      legend.text = element_text(size = 12),
      legend.title = element_text(size = 12),
      strip.background = element_blank(),
      strip.placement = "outside",
      strip.text.x = element_text(size=12),
      strip.text.y = element_text(size=12),
      panel.spacing = unit(1, "lines")
    )
  
  ggsave(
    plot,
    filename = plot_path,
    width = 8,
    height = 7,
    dpi = 200
  )
}

format_neural_network_params <- function (param_sets, key_to_factor_levels = list()) {
  unique_exponents <- get_exponent(as.numeric(unique(param_sets[param_sets$key != "hidden", "value"])))
  exponent_levels <- as.character(sort(unique_exponents))
  
  # A quick workaround, doesn't work in all cases
  hidden_vals <- unique(param_sets[param_sets$key == "hidden", "value"])
  unordered_hidden_levels <- setdiff(hidden_vals, exponent_levels)
  numeric_hidden <- sapply(unordered_hidden_levels, function (level) {
    as.numeric(gsub("-", "", level, fixed = TRUE))
  })
  hidden_order <- order(numeric_hidden)
  hidden_levels <- unordered_hidden_levels[hidden_order]
  
  # We need to represent numeric and nominal values 
  # in the same form in order to be able to use them
  # as an input in the facet_grid function
  all_levels <- c(exponent_levels, hidden_levels)
  values <- unlist(lapply(seq(1, nrow(param_sets)), function (row_idx) {
    row <- param_sets[row_idx, ]
    if (row$key == "hidden") {
      row$value
    } else {
      as.character(get_exponent(as.numeric(row$value)))
    }
  }))
  
  updated <- data.frame(param_sets)
  updated$value <- factor(values, levels = all_levels)
  updated$key <- unlist(lapply(param_sets$key, function (key) {
    if (key == "l2") {
      "L2 lambda"
    } else {
      key
    }
  }))
  updated
}

format_svr_params <- function (param_sets) {
  exponents <- get_exponent(as.numeric(param_sets$value), base = 2)
  updated <- data.frame(param_sets)
  updated$value <- as.factor(exponents)
  updated
}

format_params <- function (param_sets) {
  # It is assumed that all model_types are same
  # for a single param_sets collection
  model_type <- tolower(param_sets$model_type[[1]])
  switch (
    model_type,
    "neural network" = format_neural_network_params(param_sets),
    "svr" = format_svr_params(param_sets),
    { param_sets }
  )
}

draw_model_parameter_heatmaps <- function (all_stats, model_type, plot_path) {
  model_stats <- all_stats[all_stats$model_type == model_type, ]
  first_params <- get_model_params_from_name(model_stats[1, "model"])
  params <- first_params$key
  param_set_per_stat_row <- lapply(seq(nrow(model_stats)), function (row_idx) {
    row <- model_stats[row_idx, ]
    param_set <- get_model_params_from_name(row$model)
    param_set[, measure_var] <- row[, measure_var]
    param_set$model_type <- model_type
    param_set$ranking_position <- row_idx
    param_set$season <- row$season
    param_set
  })
  param_sets <- format_params(do.call(rbind, param_set_per_stat_row))
  plot <- ggplot(param_sets, aes_string(x = "value", y = measure_var)) +
    facet_grid(rows = vars(season), cols = vars(key), scales = 'free', switch = 'y') +
    geom_hex() +
    scale_fill_viridis() +
    xlab(TeX(paste("$log_{", get_param_exponent(model_type), "}(x)"))) +
    ylab(TeX(paste(get_tex_full_measure_name(measure_var), "\\[", get_tex_measure_units(measure_var), "\\]"))) +
    theme(
      axis.text.y = element_text(size = 12),
      axis.text.x = element_text(size = 10, angle = 90),
      strip.background = element_blank(),
      strip.placement = "outside",
      strip.text.x = element_text(size=12),
      strip.text.y = element_text(size=12),
      panel.spacing = unit(1, "lines")
    )
  
  ggsave(
    plot,
    filename = plot_path,
    width = 7,
    height = 6,
    dpi = 200
  )
}

# Main logic

option_list <- list(
  make_option(c("-f", "--stats-file"), type = "character", default = "stats/merged/accuracy-merged.csv"),
  make_option(c("-o", "--output-dir"), type = "character", default = "plots/season-station-parameter")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

output_dir <- opts[["output-dir"]]
mkdir(output_dir)

merged_stats <- read.csv(file = opts[["stats-file"]])
original_training_strategies <- as.character(merged_stats$training_strategy)
merged_stats$training_strategy <- unlist(lapply(original_training_strategies, function(strategy) {
  switch(
    strategy,
    year = "all",
    season_and_year = "seasonal", {
      ""
    }
  )
}))

merged_stats$season = factor(lapply(merged_stats$season, function (season_idx) {
  SEASONS[[season_idx]]
}), levels = SEASONS)


stations <- merged_stats$station_id
merged_stats$station_id <- factor(lapply(stations, function (station_id) {
  get_pretty_station_id(station_id)
}), levels = sapply(sort(unique(stations)), get_pretty_station_id))

merged_stats$model <- as.character(merged_stats$model)

original_model_types <- get_pretty_var(as.character(as_model_types(merged_stats$model)))
pretty_model_types <- unlist(lapply(original_model_types, function (model_type) {
  if (model_type == "svr") {
    "SVR"
  } else {
    model_type
  }
}))
model_types <- sort(unique(pretty_model_types))
merged_stats$model_type <- factor(pretty_model_types, levels = model_types)

id_vars <- c("training_strategy", "model_type")
measure_var <- "mae.mean"
main_vars <- c("station_id", "season", "model", measure_var, id_vars)
phases <- c("validation", "test")

lapply(id_vars, function (id_var) {
  lapply(phases, function (phase) {
    which_phase <- which(merged_stats$phase == phase)
    phase_stats <- merged_stats[which_phase, main_vars]
    plot_path <- file.path(output_dir, paste("season_station", id_var, phase, ".png", sep = "__"))

    draw_accuracy_differences_between_stations_and_seasons(
      all_stats = phase_stats,
      id_var = id_var,
      measure_var = measure_var,
      plot_path = plot_path
    )
  })
})

lapply(c("validation"), function (phase) {
  which_phase <- which(merged_stats$phase == phase)
  phase_stats <- merged_stats[which_phase, main_vars]
  lapply(c("neural network", "SVR"), function (model_type) {
    plot_path <- file.path(output_dir, paste("parameter_accurracy_relationship", model_type, phase, ".png", sep = "__"))
    draw_model_parameter_heatmaps(phase_stats, model_type, plot_path)
  })
})
