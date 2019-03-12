wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("formatting.R")
setwd(wd)

packages <- c("optparse", "VIM")
import(packages)

# MAIN
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "missing_records")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

output_dir <- opts[["output-dir"]]
mkdir(output_dir)
load(file = opts$file)

min_ts <- min(series$measurement_time)
max_ts <- max(series$measurement_time)
ts_seq <- seq(from = min_ts, to = max_ts, by = "hours")
expected_measurements_count <- length(ts_seq)
stations <- unique(series$station_id)
base_series <- series[, c("station_id", "measurement_time", BASE_VARS)]

missing_for_station <- lapply(stations, function(sid) {
  series_for_station <- base_series[base_series$station_id == sid, ]
  missing_for_station <- unlist(lapply(BASE_VARS, function (var) {
    sum(is.na(series_for_station[, var])) * 100 / expected_measurements_count
  }))
  missing_for_station
})
missing <- as.data.frame(t(do.call(rbind, missing_for_station)))
varnames <- sapply(BASE_VARS, function(var) {
  paste(get_pretty_var(var), "[%]")
})
missing <- cbind(varnames, missing)
rownames(missing) <- seq(nrow(missing))
colnames(missing) <- c('Variable', get_pretty_station_id(stations))
missing <- missing[order(missing$Variable), ]
print(missing)
tex_file_path <- file.path(output_dir, "missing.tex")
save_latex(missing, tex_file_path)
csv_file_path <- file.path(output_dir, "missing.csv")
write.csv(missing, file = csv_file_path)

plot_file_path <- file.path(output_dir, "missing_pattern.png")
png(filename = plot_file_path, width = 800, height = 800, pointsize = 18)
aggr(base_series[, BASE_VARS],
  numbers = TRUE,
  sortVars = TRUE,
  labels = short_get_pretty_var(BASE_VARS),
  cex.axis = .8,
  gap = 1,
  ylab = c("Histogram of missing data", "Pattern")
)
dev.off()
