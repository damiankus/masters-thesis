library('ggplot2')
library('reshape')
library('latex2exp')

save_comparison_plot <- function (df, x_var, y_var, id_var, facet_var, plot_path, x_lab = '', y_lab = '', title = '') {
  x_order <- unique(df[, x_var])
  df[, facet_var] <- as.factor(df[, facet_var])
  levels(df[, facet_var]) <- c(
    expression(paste('MAE [', mu, 'g/', m^{3}, ']')),
    expression(paste('MAPE [%]')),
    expression(paste(R ^ 2, ' [1]')),
    expression(paste('RMSE [', mu, 'g/', m^{3}, ']'))
  )
  
  facet_formula <- as.formula(paste('~', facet_var))
  plot <- ggplot(data = df, aes_string(x = x_var, y = y_var, colour = id_var, fill = id_var)) +
    geom_bar(position = 'dodge', stat = 'identity') +
    facet_wrap(facet_formula, scales = 'free', labeller = label_parsed) +
    xlab(x_lab) +
    ylab(NULL) +
    scale_x_discrete(limits = x_order)
  ggsave(plot_path, width = 16, height = 10, dpi = 150)
}

files <- list.files('formatted/', pattern = '*.csv')
results_colnames <- c('model', 'season', 'rmse', 'mae', 'mape', 'r2')
measures <- results_colnames[3:length(results_colnames)]

lapply(files, function (f) {
  data <- read.csv(f)
  colnames(data) <- results_colnames
  data$model <- sapply(data$model, function (model_name) {
    no_latex <- gsub('$\\', '', model_name, fixed = T)
    trimws(gsub('$', '', no_latex, fixed = T))
  })
  
  data <- lapply(seq(3, ncol(data)), function (i) {
    split <- data[, c(1, 2, i)]
    cname <- colnames(data)[[i]]
    colnames(split)[[3]] <- 'value'
    split$measure <- cname
    split
  })
  data <- do.call(rbind, data)
  
  plot_path <- gsub('\\.csv$', '', f)
  plot_path <- file.path(paste(plot_path, '_plot.png', sep = ''))
  save_comparison_plot(data, x_var = 'season', y_var = 'value',
                       id_var = 'model', facet_var = 'measure',
                       x_lab = 'season', plot_path)
})

