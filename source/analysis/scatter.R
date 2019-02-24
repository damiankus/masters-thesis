wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("plotting.R")
setwd(wd)

packages <- c("optparse", "GGally")
import(packages)


# Code found at StackOverflow
# see: https://stackoverflow.com/questions/45873483/ggpairs-plot-with-heatmap-of-correlation-values
# Credit to user20650
save_relationship_plots <- function(df, plot_path, width = 1280, height = 1280, font_size = 30, small_font_ratio=0.3, max_chars_per_line=10, x_ticks_count = 3) {
  small_font_size <- font_size * small_font_ratio
  medium_font_ratio <- small_font_ratio + ((1 - small_font_ratio) / 2)
  medium_font_size <- font_size * medium_font_ratio
  
  # calculate colour based on correlation value
  # Here I have set a correlation of minus one to blue,
  # zero to white, and one to red
  # Change this to suit: possibly extend to add as an argument of `my_fn`
  palette <- colorRampPalette(c("blue", "white", "red"), interpolate = "spline")

  draw_corr_tile <- function(data, mapping, corr_method = "p", corr_type = "pairwise", ...) {

    # grab data
    x <- as.numeric(eval_data_col(data, mapping$x))
    y <- as.numeric(eval_data_col(data, mapping$y))

    # calculate correlation
    corr <- cor(x, y, method = corr_method, use = corr_type)
    fill <- palette(100)[findInterval(corr, seq(-1, 1, length = 100))]

    ggally_cor(data = data, mapping = mapping, color = "black", size = small_font_size, ...) +
      theme_void() +
      theme(panel.background = element_rect(fill = fill))
  }

  draw_scatter_bin_tile <- function(data, mapping) {
    xs <- eval_data_col(data, mapping$x)
    ggplot(data = data, mapping = mapping) +
      geom_hex() +
      geom_smooth(method = "lm") +
      # Automatic X axis labels overlap each other
      # so we need to limit their number
      scale_x_continuous(labels = scales::number_format(accuracy = 0.01),
                         breaks = seq(min(xs, na.rm = TRUE), max(xs, na.rm = TRUE), length.out = x_ticks_count))
  }

  png(filename = plot_path, width = width, height = height)
  
  theme_set(theme_gray(base_size = font_size) +
              theme(axis.text.x = element_text(size = medium_font_size)))
  plot <- ggpairs(df,
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
  make_option(c("-f", "--file"), type = "character", default = "imputed/mice_time_windows.Rda"),
  make_option(c("-o", "--output-file"), type = "character", default = "relationships.png"),
  make_option(c("-d", "--output-dir"), type = "character", default = "relationships"),
  make_option(c("-r", "--response-variable"), type = "character", default = default_res_var),
  make_option(c("-e", "--explanatory-variables"), type = "character", default = paste(
    BASE_VARS[BASE_VARS != default_res_var],
    collapse = ","
  )),
  make_option(c("-a", "--use-aggregated"), action = "store_true", default = FALSE)
)
opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
expl_vars <- parse_list_argument(opts, "explanatory-variables")

target_dir <- if (!is.null(opts[["output-dir"]])) {
  opts[["output-dir"]]
} else {
  "."
}
mkdir(target_dir)

all_vars <- colnames(series)
res_var <- opts[["response-variable"]]

params_seq <- if (opts[["use-aggregated"]]) {
  lapply(expl_vars, function(expl_var) {
    same_type_vars <- all_vars[grepl(expl_var, all_vars)]
    same_type_vars <- same_type_vars[same_type_vars != res_var]
    list(variables = c(same_type_vars, res_var),
               plot_path = file.path(target_dir, paste("relationships_aggregated_", expl_var, ".png", sep = "")),
               message = paste("Plotting relationships between", res_var, "and aggregated", expl_var, "variables")
   )
  })
} else {
  list(list(variables = c(expl_vars, res_var),
                  plot_path = file.path(target_dir, opts[["output-file"]]),
                  message = paste("Plotting relationships between", res_var, "and the following variables:",
                                  paste(expl_vars, collapse=", "))))
}

lapply(params_seq, function (params) {
  print(params$message)
  present_vars <- intersect(all_vars, params$variables)
  
  if (length(present_vars) == 0) {
    print(paste("Skipping plot because there are no variables containing the word:", expl_var))
  } else {
    # Since intersect changes variable order
    # we need to do it manually to make sure the 
    # response variable is last so that the last row
    # is comprised of scatter plots with this variable
    # on Y axis
    which_res <- (present_vars == res_var)
    present_res <- present_vars[which_res]
    present_expl <- sort(present_vars[!which_res])
      
    subseries <- series[, c(present_expl, present_res)]
    save_relationship_plots(subseries, params$plot_path)
  }
})
