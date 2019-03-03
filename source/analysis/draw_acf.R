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
  
  acf_for_id <- lapply(ids, function(id) {
    subseries <- df[df[, id_var] == id, ]
    col <- subseries[, varname]
    contiguous_col <- na.contiguous(col)
    time_col <- subseries$measurement_time
    contiguous_time_col <- na.contiguous(
      unlist(
        lapply(seq(length(col)), function (idx) {
          if (is.na(col[[idx]])) {
            NA
          } else {
            time_col[[idx]]
          }
        })))
    acf_raw <- acf_function(x = contiguous_col, lag.max = 168, plot = FALSE)
    acf_df <- data.frame(lag = acf_raw$lag, acf = acf_raw$acf)
    acf_df[, id_var] <- id
    acf_df
  })
  acf_stats <- do.call(rbind, acf_for_id)
  y_lab <- switch(acf_method,
                  acf = 'autocorrelation [1]',
                  pacf = "partial autocorrelation [1]",
                  {
                    "Unknown autocorrelation method"
                  })
  highlight_flag <- (acf_stats$lag %% period_length == 0) & (acf_stats$lag / period_length >= 1)
  facet_formula <- as.formula(paste('~', id_var))
  plot <- ggplot(data = acf_stats, aes_string(x = "lag", y = "acf")) +
    geom_bar(mapping = aes(fill = highlight_flag), stat = "identity", width = 0.5) +
    scale_x_continuous(breaks = seq(0, max_lag, period_length)) +
    xlab("Lag [h]") +
    ylab(y_lab) + 
    theme(legend.position='none') +
    facet_wrap(facet_formula, scales = 'free_y', ncol = 1)
  save_plot_file(plot, plot_path, width = width, height = height)
}

# MAIN
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_windows.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "autocorrelation"),
  make_option(c("-v", "--variable"), type = "character", default = "pm2_5")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
series$station_id <- pretty_station_id(series$station_id)
output_dir <- opts[["output-dir"]]
mkdir(output_dir)

autocorrelation_types <- c('acf', 'pacf')
lapply(autocorrelation_types, function (acorr_type) {
  save_autocorrelation_plot(df = series, 
                            varname = opts$variable,
                            plot_path = file.path(output_dir, paste(opts$variable, acorr_type, '.png', sep = "_")),
                            id_var = "station_id",
                            acf_method = acorr_type)
})

