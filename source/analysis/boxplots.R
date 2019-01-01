wd <- getwd()
setwd('../common/')
  source('utils.r')
  source('constants.r')
  source('preprocess.r')
  source('plotting.r')
setwd(wd)

get_group <- function (df, varname, val) {
  if (!varname %in% colnames(df)) {
    data.frame()
  } else {
    df[which(df[, varname] == val), ]
  }
}

get_samples_grouped_by <- function (df, groupingType, vars='*') {
  if (!groupingType %in% grouping_types) {
    stop(paste(groupingType, 'is not a member ot the grouping_types enum'))
  }
  vals <- as.factor(unique(data[, groupingType]))
  lapply(vals, function (val) {
    get_group(df, groupingType, val)
  })
}

# MAIN

load('./original_series.Rda')
vars <- c('pm2_5')

target_dir <- 'boxplots'
mkdir(target_dir)

grouping_types <- c(
  'season',
  'month',
  'day_of_week',
  'hour_of_day'
)

series$season <- sapply(series$season, function (season) {
  SEASONS[season]
})

series$day_of_week <- sapply(series$day_of_week, function (dow) {
  # Sunday is represented by 0
  WEEKDAYS_ABB[if (dow > 0) dow else 7]
})

series$month <- sapply(series$month, function (month) {
  MONTHS_ABB[month]
})

x_orders <- list(
  month=MONTHS_ABB,
  day_of_week=WEEKDAYS_ABB,
  hour_of_day=seq(0, 23)
)

lapply(SEASONS, function (season) {
  data <- series[series$season == season, ]
  
  lapply(grouping_types, function (grouping_type) {
    lapply(vars, function (var) {
      plot_name <- paste('boxplot_', season, '_' , var, '_', grouping_type, '.png', sep='')
      plot_path <- file.path(target_dir, plot_name)
      save_boxplot(data, grouping_type, var, plot_path, x_order=x_orders[[grouping_type]])

      plot_name <- paste('boxplot_', season, '_' , var, '_', grouping_type, '_no_outliers.png', sep='')
      plot_path <- file.path(target_dir, plot_name)
      save_boxplot(data, grouping_type, var, plot_path, x_order=x_orders[[grouping_type]], show_outliers=FALSE)
    })
  })
})
