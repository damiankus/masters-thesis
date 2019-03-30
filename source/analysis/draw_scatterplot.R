wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse", "GGally", "viridis")
import(packages)

font_sizes <- read.csv(file = 'font_sizes.csv')
font_fit <- lm(formula = font_size ~ width + var_count, data = font_sizes)

# Code found at StackOverflow
# see: https://stackoverflow.com/questions/45873483/ggpairs-plot-with-heatmap-of-correlation-values
# Credit to user20650
save_relationship_plots <- function(df, plot_path, width = 1280, font_size, small_font_size, max_chars_per_line=10, x_ticks_count = 4) {
  var_count <- ncol(df)
  
  # Coefficients extracted from a linear model 
  # based on some manually picked values of font_size
  # for a given plot width and var_count
  # Values can be found in the font_sizes.csv file
  plot_data <- data.frame(width = width, var_count = var_count)
  if (is.na(font_size)) {
    font_size <- floor(
      predict(font_fit, plot_data)
    )
  }

  if (is.na(small_font_size)) {
    small_font_size <- font_size - 2
  }
  tile_font_size <- font_size / 3
  
  theme_set(theme_gray(base_size = font_size) +
    theme(axis.text = element_text(size = small_font_size),
          axis.text.x = element_text(angle = 45, hjust = 1)))
  
  palette <- colorRampPalette(c("blue", "white", "red"), interpolate = "spline")
  draw_corr_tile <- function(data, mapping, corr_method = "pearson", corr_type = "pairwise", ...) {
    x <- eval_data_col(data, mapping$x)
    y <- eval_data_col(data, mapping$y)
    
    corr <- cor(x, y, method = corr_method, use = corr_type)
    fill <- palette(100)[findInterval(corr, seq(-1, 1, length = 100))]

    data[[quo_name(mapping$x)]]
    ggally_cor(data = data, mapping = mapping, color = "black", size = tile_font_size, ...) +
      theme_void() +
      theme(panel.background = element_rect(fill = fill))
  }

  draw_scatter_bin_tile <- function(data, mapping) {
    xs <- eval_data_col(data, mapping$x)
    min_x <- min(xs, na.rm = TRUE)
    max_x <- max(xs, na.rm = TRUE)
    accuracy <- 10 ** (floor(log10(max_x - min_x)) - 1)

    ggplot(data = data, mapping = mapping) +
      stat_binhex() +
      geom_smooth(method = "lm", na.rm = TRUE, color = COLOR_CONTRAST) +
      scale_fill_viridis() +
      # Automatic X axis labels overlap each other
      # so we need to limit their number
      scale_x_continuous(labels = scales::number_format(accuracy = accuracy, big.mark = ""),
                         breaks = seq(min_x, max_x, length.out = x_ticks_count))
  }

  # Timestamps must be cast to numeric values
  numeric_df <- as.data.frame(do.call(cbind, lapply(df, as.numeric)))
  
  png(filename = plot_path, width = width, height = width)
    plot <- ggpairs(numeric_df,
      lower = list(continuous = draw_scatter_bin_tile),
      upper = list(continuous = draw_corr_tile),
      columnLabels = sapply(colnames(df), get_or_generate_label),
      labeller = label_wrap_gen(max_chars_per_line)
    )
    print(plot)
  dev.off()
  print(paste("Plot saved at:", plot_path))
}

# MAIN

default_res_var <- "future_pm2_5"
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_windows.Rda"),
  make_option(c("-o", "--output-file"), type = "character", default = "relationships.png"),
  make_option(c("-d", "--output-dir"), type = "character", default = "relationships"),
  make_option(c("-r", "--response-variable"), type = "character", default = default_res_var),
  make_option(c("-e", "--explanatory-variables"), type = "character", default = paste(
    MAIN_VARS[MAIN_VARS != default_res_var],
    collapse = ","
  )),
  make_option(c("-g", "--group-by"), type = "character", default = NA),
  make_option(c("-i", "--filter-aggregated"), action = "store_true", default = FALSE),
  make_option(c("-a", "--use-aggregated"), action = "store_true", default = FALSE),
  make_option(c("-w", "--width"), type = "numeric", default = 1920),
  make_option(c("-s", "--font-size"), type = "numeric", default = NA),
  make_option(c("-m", "--small-font-size"), type = "numeric", default = NA),
  make_option(c('-y', "--test-year"), type = "numeric", default = NA)
  
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
expl_vars <- parse_list_argument(opts, "explanatory-variables")

output_dir <- if (!is.null(opts[["output-dir"]])) {
  opts[["output-dir"]]
} else {
  "."
}
mkdir(output_dir)

test_year <- if (is.na(opts[["test-year"]])) {
  # years sorted ascendingly
  tail(sort(unique(series$year)), 1)
} else {
  opts[["test-year"]]
}
series <- series[series$year != test_year, ]

all_vars <- colnames(series)
res_var <- opts[["response-variable"]]

params_seq <- if (opts[["use-aggregated"]]) {
  lapply(expl_vars, function(expl_var) {
    same_type_vars <- all_vars[grepl(expl_var, all_vars)]
    same_type_vars <- same_type_vars[same_type_vars != res_var]
    list(variables = c(same_type_vars, res_var),
         file_name = paste("relationships_aggregated_", expl_var, ".png", sep = ""),
         message = paste("Plotting relationships between", res_var, "and aggregated", expl_var, "variables")
   )
  })
} else if (opts[["filter-aggregated"]]) {
  res_col <- series[, res_var]
  all_expl_vars <- all_vars[all_vars != res_var]
  filtered_vars <- do.call(rbind, lapply(expl_vars, function (expl_var) {
    aggregated_vars <- all_expl_vars[grepl(expl_var, all_expl_vars)]
    corrs <- unlist(lapply(aggregated_vars, function (aggr_var) {
      cor(x = res_col, y = as.numeric(series[, aggr_var]), use = 'complete.obs', method = "pearson")
    }))
    highest_corr_idx <- head(order(abs(corrs), decreasing = TRUE), 1)
    data.frame(name = aggregated_vars[[highest_corr_idx]], corr = corrs[[highest_corr_idx]])
  }))
  expl_vars_with_highest_corr <- as.character(filtered_vars$name)[order(abs(filtered_vars$corr), decreasing = TRUE)]
  list(list(variables = c(expl_vars_with_highest_corr, res_var),
            file_name = opts[["output-file"]],
            message = paste("Plotting relationships between", res_var, "and the following variables:",
                            paste(expl_vars, collapse=", "))))
} else {
  list(list(variables = c(expl_vars, res_var),
                  file_name = opts[["output-file"]],
                  message = paste("Plotting relationships between", res_var, "and the following variables:",
                                  paste(expl_vars, collapse=", "))))
}

draw_plots <- function (data, subseries_dir, subseries_name = "") {
  subseries_name_prefix <- if (nchar(subseries_name) > 0) {
    paste(subseries_name, "_", sep = "")
  } else {
    ""
  }
    
  lapply(params_seq, function (params) {
    print(params$message)
    present_vars <- params$variables[params$variables %in% all_vars]
    
    if (length(present_vars) == 0) {
      print(paste("Skipping plot because there are no variables containing the word:", expl_var))
    } else {
      subseries <- data[, present_vars]
      print(params)
      save_relationship_plots(df = subseries,
                              plot_path = file.path(subseries_dir, paste(subseries_name_prefix, params$file_name, sep = "")),
                              width = opts$width,
                              font_size = opts[["font-size"]],
                              small_font_size = opts[["small-font-size"]])
    }
  })
}

grouping_varname <- opts[["group-by"]]
if (is.na(grouping_varname)) {
  draw_plots(series, output_dir)
} else {
  group_vals <- sort(unique(series[, grouping_varname]))
  lapply(group_vals, function (val) {
    which_rows <- series[, grouping_varname] == val
    subseries <- series[which_rows, ]
    subseries_name <- paste(grouping_varname, val, sep = "-")
    output_dir <- file.path(output_dir, subseries_name)
    mkdir(output_dir)
    draw_plots(subseries, output_dir, subseries_name = subseries_name)
  })
}
