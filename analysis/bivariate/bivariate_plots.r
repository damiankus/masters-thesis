require('RPostgreSQL')
require('ggplot2')
require('reshape')
Sys.setenv(LANG = "en")

cap <- function (s) {
  s <- strsplit(s, ' ')[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = '', collapse = ' ')
}

mkdir <- function (path) {
  if (!dir.exists(path)) {
    dir.create(path, showWarnings = FALSE)
  }
}
units <- function (var) {
  switch(var,
         temperature = '°C',
         humidity = '%',
         pressure = 'hPa',
         wind_speed = 'm/s',
         wind_dir_deg = '°',
         precip_total = 'mm',
         precip_rate = 'mm/h',
         {
           if (grepl('^pm', var)) {
             'μg/m³'
           } else {
             ''
           }
         })
}

pretty_var <- function (var) {
  switch(var,
         pm1 = 'PM1', pm2_5 = 'PM2.5', pm10 = 'PM10', solradiation = 'Solar irradiance', wind_speed = 'wind speed',
         wind_dir = 'wind direction', wind_dir_deg = 'wind direction', cont_date = 'date (normalized)',
         {
           delim <- ' '
           join_str <- ' ' 
           if (grepl('plus', var)) {
             delim <- '_plus_'
             join_str <- '+'
           } else if (grepl('minus', var)) {
             delim <- '_minus_'
             join_str <- '-'
           }     
           split_var <- strsplit(var, delim)[[1]]
           pvar <- split_var[1]
           if (length(split_var) > 1) {
             pvar <- pretty_var(pvar)
             pvar <- paste(pvar, 'at t', join_str, split_var[2], 'h', sep = ' ')
           }
           pvar
         })
}

save_scatter_plot <- function (df, res_var, expl_var, plot_path) {
  pretty_res <- pretty_var(res_var)
  pretty_expl <- pretty_var(expl_var)
  scatter_plot <- ggplot(data = df, aes_string(x = expl_var, y = res_var)) +
    geom_point() +
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
  
  target_root_dir <- getwd()
  target_root_dir <- file.path(target_root_dir, 'original_data')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'observations'
  response_vars <- c('pm2_5', 'pm2_5_plus_12', 'pm2_5_plus_24')
  # response_vars <- c('pm2_5', 'pm2_5_plus_12', 'pm2_5_plus_24')
  
  explanatory_vars <- c('pm2_5', 'temperature', 'pressure', 'humidity', 'precip_total', 'precip_rate', 'wind_speed', 'wind_dir', 'wind_dir_deg', 'cont_date')
  # explanatory_vars <- c(explanatory_vars, paste('pm2_5_minus', seq(4, 36, 4), sep = '_'))
  query = paste('SELECT',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table,
                sep = ' ')
  obs <- dbGetQuery(con, query)
  
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

