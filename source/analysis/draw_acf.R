wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("plotting.R")
source("constants.R")
setwd(wd)

packages <- c("optparse", "ggplot2", "broom")
import(packages)

save_autocorrelation_plot <- function(df, varname, plot_path, id_var = "station_id",
                                      acf_method = "acf", max_lag = 168, period_length = 24,
                                      width = 5, height = 4) {
  ids <- sort(unique(df[, id_var]))
  acf_function <- get(acf_method)
  format_ts <- function(x) {
    format(x, format = "%Y-%m-%d %H:%M")
  }

  id_to_contiguous_range <- lapply(ids, function(id) {
    subseries <- df[df[, id_var] == id, ]
    col <- subseries[, varname]
    time_col <- subseries$measurement_time
    contiguous_time_col <- na.contiguous(
      unlist(
        lapply(seq(length(col)), function(idx) {
          if (is.na(col[[idx]])) {
            NA
          } else {
            time_col[[idx]]
          }
        })
      )
    )
    data.frame(
      start = format_ts(utcts(min(contiguous_time_col))),
      end = format_ts(utcts(max(contiguous_time_col)))
    )
  })
  names(id_to_contiguous_range) <- ids

  acf_for_id <- lapply(ids, function(id) {
    subseries <- df[df[, id_var] == id, ]
    col <- subseries[, varname]
    contiguous_col <- na.contiguous(col)

    acf_raw <- acf_function(x = contiguous_col, lag.max = 168, plot = FALSE)
    acf_df <- data.frame(lag = acf_raw$lag, acf = acf_raw$acf)
    acf_df[, id_var] <- id
    acf_df
  })

  acf_stats <- do.call(rbind, acf_for_id)
  y_lab <- paste(pretty_var(varname), switch(acf_method,
    acf = "autocorrelation [1]",
    pacf = "partial autocorrelation [1]", {
      "Unknown autocorrelation method"
    }
  ))
  highlight_flag <- (acf_stats$lag %% period_length == 0) & (acf_stats$lag / period_length >= 1)
  facet_formula <- as.formula(paste("~", id_var))

  formatter_name <- paste("pretty", id_var, sep = "_")
  pretty_id_var <- if (exists(formatter_name)) {
    get(formatter_name)
  } else {
    function(x) {
      x
    }
  }
  labels <- unlist(lapply(ids, function(id) {
    time_range <- id_to_contiguous_range[[id]]
    paste(pretty_id_var(id), " (", time_range$start, " - ", time_range$end, ")", sep = "")
  }))
  names(labels) <- sapply(ids, as.character)
  plot <- ggplot(data = acf_stats, aes_string(x = "lag", y = "acf")) +
    geom_bar(mapping = aes(fill = highlight_flag), stat = "identity", width = 0.5) +
    scale_fill_manual(values = c(COLORS[1], 'red', 'grey')) +
    scale_x_continuous(breaks = seq(0, max_lag, period_length)) +
    xlab("Lag [h]") +
    ylab(y_lab) +
    theme(legend.position = "none") +
    facet_wrap(facet_formula, scales = "free_y", ncol = 1, labeller = as_labeller(labels))
  save_plot_file(plot, plot_path, width = width, height = height)
}

# MAIN
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_windows.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "autocorrelation"),
  make_option(c("-v", "--variable"), type = "character", default = "pm2_5"),
  make_option(c("-i", "--id-variable"), type = "character", default = "season"),

  make_option(c("-b", "--aggregate-by"), type = "character", default = "measurement_time,season"),
  make_option(c("-t", "--aggregation-type"), type = "character", default = "mean")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
output_dir <- opts[["output-dir"]]
mkdir(output_dir)
id_var <- opts[["id-variable"]]

aggregate_vars <- parse_list_argument(opts, "aggregate-by")
draw_acf <- if (!length(aggregate_vars)) {
  function(acorr_type) {
    save_autocorrelation_plot(
      df = series,
      varname = opts$variable,
      plot_path = file.path(output_dir, paste(opts$variable, "_", acorr_type, "_by_", id_var, ".png", sep = "")),
      id_var = id_var,
      acf_method = acorr_type
    )
  }
} else {
  function(acorr_type) {
    aggr_cols <- lapply(aggregate_vars, function(aggr_var) {
      series[, aggr_var]
    })
    aggr_series <- aggregate(
      x = series[, opts$variable],
      by = aggr_cols,
      FUN = get(opts[["aggregation-type"]]),
      na.action = na.rm
    )
    colnames(aggr_series) <- c(aggregate_vars, opts$variable)
    save_autocorrelation_plot(
      df = aggr_series,
      varname = opts$variable,
      plot_path = file.path(output_dir, paste(opts$variable, "_", acorr_type,
        "_by_", id_var,
        "aggregated_by_", paste(aggregate_vars, collapse = "_"),
        ".png",
        sep = ""
      )),
      id_var = id_var,
      acf_method = acorr_type
    )
  }
}

autocorrelation_types <- c("acf", "pacf")
lapply(autocorrelation_types, draw_acf)
