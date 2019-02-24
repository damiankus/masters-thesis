wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
setwd(wd)

packages <- c("optparse", "knitr", "xtable", "VIM")
import(packages)
Sys.setenv(LANG = "en")

# Formatting
save_markdown <- function(df, file_path) {
  pretty <- knitr::kable(df, row.names = FALSE)
  write(pretty, file = file_path)
}

save_latex <- function(df, file_path, precision = 2) {
  print(xtable(df, type = "latex", digits = rep(precision, length(df[1, ]) + 1)),
    file = file_path, booktabs = TRUE, include.rownames = FALSE
  )
}

# MAIN
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-t", "--target-dir"), type = "character", default = "missing_records")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

target_dir <- opts[["target-dir"]]
mkdir(target_dir)
load(file = opts$file)

min_ts <- min(series$measurement_time)
max_ts <- max(series$measurement_time)
ts_seq <- seq(from = min_ts, to = max_ts, by = "hours")
expected_measurements_count <- length(ts_seq)
stations <- unique(series$station_id)
base_series <- series[, c("station_id", BASE_VARS)]

missing_for_station <- lapply(stations, function(sid) {
  series_for_station <- base_series[base_series$station_id == sid, ]
  missing_for_station <- unlist(lapply(BASE_VARS, function(var) {
    sum(is.na(series_for_station[, var])) * 100 / expected_measurements_count
  }))
  missing_for_station
})
missing <- cbind(
  pretty_station_id(stations),
  as.data.frame(do.call(rbind, missing_for_station))
)
names(missing) <- c(
  "Station ID",
  sapply(pretty_var(BASE_VARS), function(var) {
    paste(var, "[%]")
  })
)

tex_file_path <- file.path(target_dir, "missing.tex")
save_latex(missing, tex_file_path)
csv_file_path <- file.path(target_dir, "missing.csv")
write.csv(missing, file = csv_file_path, row.names = FALSE)

plot_file_path <- file.path(target_dir, "missing_pattern.png")
png(filename = plot_file_path, width = 800, height = 800, pointsize = 18)
aggr(base_series[, BASE_VARS],
  numbers = TRUE,
  sortVars = TRUE,
  labels = short_pretty_var(BASE_VARS),
  cex.axis = .8,
  gap = 1,
  ylab = c("Histogram of missing data", "Pattern")
)
dev.off()
