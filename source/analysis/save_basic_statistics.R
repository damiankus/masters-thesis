wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
source("formatting.R")
setwd(wd)

packages <- c("optparse", "moments")
import(packages)

# MAIN
option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_windows_aggregated_incomplete.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "statistics"),
  make_option(c("-v", "--variable"), type = "character", default = "pm2_5")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
output_dir <- opts[["output-dir"]]
mkdir(output_dir)

col <- series[, opts$variable]
mean_daily_varname <- paste('mean_24', opts$variable, sep = "_")
daily_mean_col <- series[series$hour_of_day == 23, mean_daily_varname]
daily_mean_limit <- 50

stats <- rbind(data.frame(unclass(summary(col))),
               skewness = skewness(col, na.rm = TRUE),
               kurtosis = kurtosis(col, na.rm = TRUE),
               exceeded_daily_limit_percentage = 100 * sum(daily_mean_col > daily_mean_limit, na.rm = TRUE) / length(daily_mean_col)
         )
stat_names <- c(
  "minimum",
  "1st quartile",
  "median",
  "mean",
  "3rd quartile",
  "maximum",
  "number of missing values",
  "skewness",
  "kurtosis",
  "percentage of days with exceeded daily limits"
)
stats <- cbind(stat_names, stats)
rownames(stats) <- seq(nrow(stats))
colnames(stats) <- c('Statistic', paste('Value [', units(opts$variable), ']', sep = ""))
tex_file_path <- file.path(output_dir, "statistics.tex")
save_latex(stats, tex_file_path)
csv_file_path <- file.path(output_dir, "statistics.csv")
write.csv(stats, file = csv_file_path)
