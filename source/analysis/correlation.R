wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
source("constants.R")
setwd(wd)

packages <- c("optparse", "corrplot", "magrittr", "knitr", "plyr")
import(packages)

plotCorrMat <- function(df, main_var_idx, file_path, width = 1280, corr_threshold = 0.2) {
  data <- as.data.frame(
    do.call(cbind, lapply(df, function(col) {
      complete_col <- col[!is.na(col)]
      if (is.numeric(complete_col) && abs(sd(complete_col)) > 0.001) {
        col
      }
    })))

  png(filename = file_path, height = width, width = width)
  palette <- colorRampPalette(
    c("#500000", "#7F0000", "red", "white", "blue", "#00007F", "#000050")
  )
  M <- cor(data, use = "complete.obs")
  which_order <- order(abs(M[, main_var_idx]), decreasing = T)
  orig_colnames <- colnames(M)
  colnames(M) <- sapply(orig_colnames, get_pretty_var)
  rownames(M) <- colnames(M)
  corrplot(M, type = "upper", method = "number", col = palette(100))
  colnames(M) <- orig_colnames
  dev.off()

  # Find variables with absolute correlation above certain threshold
  M <- signif(M[, 2:ncol(M)], 3)
  signif_vars <- as.data.frame(t(M[1, abs(M[1, ]) > corr_threshold]))
  signif_vars <- signif_vars[, order(abs(signif_vars[1, ]), decreasing = TRUE)]
}

# MAIN

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "data/time_windows.Rda"),
  make_option(c("-t", "--output-file"), type = "character", default = "relationships/corrplot.png")
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)
load(file = opts$file)
stations <- unique(series$station_id)

main_var <- "future_pm2_5"
all_vars <- colnames(series)
vars <- c(main_var, all_vars[!(all_vars %in% c(main_var, "station_id", "season"))])
main_var_idx <- which(vars == main_var)
output_dir <- dirname(opts[["output-file"]]) 
mkdir(output_dir)

signif_path <- file.path(output_dir, "significant_vars.txt")
signif_vars <- lapply(stations, function(sid) {
  series_for_station <- series[series$station_id == sid, vars]
  file_path <- file.path(output_dir, paste("corrplot_", sid, ".png", sep = ""))
  signif_vars <- plotCorrMat(series_for_station, main_var_idx, file_path)
  padding_cols <- sapply(seq(length(vars) - ncol(signif_vars)), function(i) {
    paste("padding", i, sep = "_")
  })
  signif_vars <- as.data.frame(t(sapply(signif_vars, as.character)), stringsAsFactors = FALSE)
  signif_vars <- data.frame(
    "Station" = get_pretty_station_id(sid),
    signif_vars,
    stringsAsFactors = FALSE
  )
  cnames <- t(as.data.frame(sapply(colnames(signif_vars), get_pretty_var)))
  cnames[1, 1] <- ""
  cnames[1, 2] <- ""
  signif_vars <- rbind(cnames, signif_vars)
  signif_vars[, padding_cols] <- ""
  colnames(signif_vars) <- 1:ncol(signif_vars)
  rownames(signif_vars) <- NULL
  signif_vars
})

signif_vars <- do.call(rbind, signif_vars)
colnames(signif_vars) <- c("Station", "Season", "Significant variables")
max_signif_cols_count <- max(apply(signif_vars, 1, function(row) {
  sum(nchar(row) > 0)
}))
signif_vars <- signif_vars[, 1:max_signif_cols_count]
write(knitr::kable(signif_vars), file = signif_path, append = TRUE)

# Create a corrplot for all the data
file_path <- file.path(output_dir, "corrplot-all-data.png")
plotCorrMat(series, main_var_idx, file_path)
print(paste("# of serieservation records:", nrow(series), sep = " "))
print(paste("# of records after omiiting missing values:", nrow(na.omit(series)), sep = " "))
