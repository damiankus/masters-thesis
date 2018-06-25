wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('prediction_goodness.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c('RPostgreSQL', 'ggplot2', 'reshape')
import(packages)

save_scatter_plot <- function (df, res_var, expl_var, plot_path) {
  pretty_res <- pretty_var(res_var)
  pretty_expl <- pretty_var(expl_var)
  scatter_plot <- ggplot(data = df, aes_string(x = expl_var, y = res_var)) +
    geom_point(shape = 1, alpha = 0.25) +
    geom_smooth(method = 'auto', color = 'red', se = FALSE) +
    ggtitle(paste('Relation between', pretty_res, 'and', pretty_expl, sep = ' ')) +
    xlab(
      paste(cap(pretty_expl), '[', units(expl_var),']', sep = ' ')) +
    ylab(
      paste(cap(pretty_res), '[', units(res_var),']', sep = ' ')) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
  ggsave(plot_path, width = 16, height = 10, dpi = 200)
  print(paste('Plot saved in', plot_path, sep = ' '))
}

main <- function () {
  load(file = '../time_windows.Rda')
  stations <- unique(windows$station_id)
  
  vars <- c('pm2_5', 'humidity', 'precip_total', 'pressure', 'temperature', 'wind_speed')
  main_var <- 'future_pm2_5'
  vars <- c(main_var, vars)
  windows <- windows[, c(vars, 'station_id', 'season')]
  
  target_dir <- file.path(getwd(), 'bivariate')
  mkdir(target_dir)
  
  lapply(seq(1, 4), function (season) {
  data <- windows[windows$season == season, c(vars, 'station_id')]
    lapply(stations, function (sid) {
      data <- data[data$station_id == sid, vars]
      plot_path <- file.path(target_dir, paste('relationships_', sid, '_', season, '.png', sep = ''))
      png(filename = plot_path, height = 3112, width = 4096, pointsize = 25)
      pairs(data[, vars], cex.labels = 3, lower.panel = NULL)
      dev.off()
    })
  })
}
main()

