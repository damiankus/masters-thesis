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
  driver <- dbDriver('PostgreSQL')
  passwd <- { 'pass' }
  con <- dbConnect(driver, dbname = 'pollution',
                   host = 'localhost',
                   port = 5432,
                   user = 'damian',
                   password = passwd)
  rm(passwd)
  on.exit(dbDisconnect(con))
  
  target_root_dir <- file.path(getwd(), 'bivariate')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'observations'
  response_vars <- c('pm2_5_plus_24_log')
  
  query = paste('SELECT * FROM', table, 
                "WHERE station_id = 'airly_171'",
                sep = ' ')
  obs <- dbGetQuery(con, query)
  
  obs[,'pm2_5_plus_24_log'] <- log(obs$pm2_5_plus_24)
  obs[,'temperature_log'] <- log(obs$temperature)
  obs[,'wind_speed_log'] <- log(obs$wind_speed)
  explanatory_vars <- c('pm2_5', 'temperature', 'temperature_log', 'wind_speed', 'wind_speed_log', 'pressure', 'humidity', 'wind_dir_ns', 'wind_dir_ew')
  excluded <- c(response_vars, c('id', 'timestamp', 'station_id'))
  explanatory_vars <- explanatory_vars[!(explanatory_vars %in% excluded)]
  obs <- obs[, c(response_vars, explanatory_vars)]
  obs <- na.omit(obs)
  
  # plot_path <- file.path(target_dir, 'pairwise_relationships.png')
  # png(filename = plot_path, height = 3112, width = 4096, pointsize = 25)
  # pairs(obs[c(response_vars, explanatory_vars)], cex.labels = 3)
  # dev.off()
  
  for (res_var in response_vars) {
    target_dir <- file.path(target_root_dir, res_var)
    mkdir(target_dir)

    for (expl_var in explanatory_vars) {
      plot_path <- file.path(target_dir, paste(res_var, '_', expl_var, '.png', sep = ''))
      save_scatter_plot(obs, res_var, expl_var, plot_path)
    }
  }
}
main()

