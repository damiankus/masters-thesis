library('ggplot2')
library('reshape')

save_multiline_plot <- function (df, x_var, y_var, group_by, facet_var, plot_path, font_size = 24) {
  df[, facet_var] <- factor(df[, facet_var], levels = c('winter', 'spring', 'summer', 'autumn'))
  facet_formula <- as.formula(paste('~', facet_var))
  df[, group_by] <- as.factor(df[, group_by])
  plot <- ggplot(df, aes_string(x = x_var, y = y_var, colour = group_by, fill = group_by)) +
    geom_line() +
    facet_wrap(facet_formula, scales = 'free') +
    xlab(translate_varname(x_var)) +
    ylab(translate_varname(y_var)) +
    theme(text = element_text(size = font_size))
  ggsave(plot_path, width = 16, height = 10)
  print(paste('Saving in', plot_path))
}

cap <- function (str) {
  paste(toupper(substring(str, 1, 1)), substring(str, 2), sep = '')
}

translate_varname <- function (varname) {
  switch (varname,
    SEASON = 'Season',
    MODEL = 'Model',
    FUTURE_LAG = 'Time lag [h]',
    RMSE = 'RMSE [μg/m³]',
    { cap(varname) }
  )
}

translate_model_name <- function (model_name, sep = '_') {
  name <- trimws(model_name)
  switch (name,
    neural = 'ANN',
    log_mlr = 'MLR ln(PM2.5)',
    persistence = 'persistence',
    {
      toupper(paste(strsplit(name, sep)[[1]], collapse = ' '))
    }
  )
}

# MAIN

data <- read.csv2(file = 'prediction_goodness.csv', stringsAsFactors = F, header = T, quote = '"', sep = ',')
measures <- c('RMSE')
target_dir <- file.path(getwd(), 'time-lag-plots')
dir.create(target_dir, recursive = T)
data$MODEL <- as.character(lapply(data$MODEL, translate_model_name))
numeric_cols <- colnames(data)[!(colnames(data) %in% c('MODEL', 'SEASON'))]
data[, numeric_cols] <- lapply(data[, numeric_cols], as.numeric)
data[, 'Model'] <- data[, 'MODEL']

lapply(measures, function (measure) {
  plot_path <- file.path(target_dir, paste(tolower(measure), '_time_lag.png', sep = ''))
  save_multiline_plot(data, x_var = 'FUTURE_LAG', y_var = measure, group_by = 'Model', facet_var = 'SEASON', plot_path = plot_path)
})
