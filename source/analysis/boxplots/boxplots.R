wd <- getwd()
setwd('../../common/')
  source('utils.r')
  source('preprocess.r')
  source('plotting.r')
setwd(wd)

create_enum <- function (vals) {
  enum <- as.list(vals)
  names(enum) <- unlist(lapply(vals, toupper))
  enum
}

grouping_types <- create_enum(
  c(
    'season',
    'month_factor',
    'day_of_week_factor',
    'hour_of_day_factor'
  ))

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
  
  data <- switch(groupingType,
         'day_of_week_factor' = {
           frame <- data.frame(df)
           frame$day_of_week <- as.POSIXlt(df$timestamp)$wday
           frame
         },
         'hour_of_day_factor' = {
           frame <- data.frame(df)
           frame$hour <- as.POSIXlt(frame$timestamp)$hour
           frame
         },
         # default
         {
           data.frame(df)
         })
  vals <- as.factor(unique(data[, groupingType]))
  lapply(vals, function (val) {
    get_group(data, groupingType, val)
  })
}

# MAIN

load('../time_windows.Rda')
vars <- c('pm2_5', 'temperature', 'wind_speed')
df <- data.frame(windows)

days_of_week <- c('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat')
df$day_of_week_factor <- sapply(df$day_of_week_factor, function (idx) { days_of_week[[idx]] })

months <- c('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
df$month_factor <- sapply(df$month_factor, function (idx) { months[[idx]] })

seasons <- c('winter', 'spring', 'summer', 'autumn')
df$season <- sapply(df$season, function (idx) { seasons[[idx]] })

dir <- 'plots'
mkdir(dir)

x_orders <- list(
  season=seasons,
  month_factor=months,
  day_of_week_factor=days_of_week,
  hour_of_day_factor=seq(23)
)

lapply(grouping_types, function (grouping_type) {
  lapply(vars, function (var) {
    plot_path <- file.path(dir, paste('boxplot_', var, '_', grouping_type, '.png', sep=''))
    save_boxplot(df, grouping_type, var, plot_path, x_order=x_orders[[grouping_type]])
  })
})



