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
  make_option(c("-f", "--file"), type = "character", default = "preprocessed/observations.Rda"),
  make_option(c("-o", "--output-dir"), type = "character", default = "statistics"),
  make_option(c("-v", "--variable"), type = "character", default = "pm2_5")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

load(file = opts$file)
output_dir <- opts[["output-dir"]]
mkdir(output_dir)

col <- series[, opts$variable]
stats <- rbind(data.frame(unclass(summary(col))),
               skewness = skewness(col, na.rm = TRUE),
               kurtosis = kurtosis(col, na.rm = TRUE))
stat_names <- c(
  "minimum",
  "1st quartile",
  "median",
  "mean",
  "3rd quartile",
  "maximum",
  "number of missing values",
  "skewness",
  "kurtosis"
)
stats <- cbind(stat_names, stats)
rownames(stats) <- seq(nrow(stats))
colnames(stats) <- c('Statistic', 'Value')
tex_file_path <- file.path(output_dir, "statistics.tex")
save_latex(stats, tex_file_path)
csv_file_path <- file.path(output_dir, "statistics.csv")
write.csv(stats, file = csv_file_path)
