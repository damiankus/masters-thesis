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

save_scatter_plot <- function (df, res_var, expl_var, plot_path) {
  scatter_plot <- ggplot(data = df, aes_string(x = expl_var, y = res_var)) +
    geom_point() +
    xlab(cap(expl_var)) +
    ylab(cap(res_var)) +
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
  target_root_dir <- file.path(target_root_dir, 'bivariate')
  mkdir(target_root_dir)
  
  # Fetch all observations
  target_dir <- target_root_dir
  table <- 'complete_data'
  response_vars <- c('pm2_5')
  explanatory_vars <- c() 
  # c('temperature', 'pressure', 'humidity', 'precip_total', 'precip_rate', 'wind_speed', 'wind_dir', 'cont_date')
  explanatory_vars <- c(explanatory_vars, paste('pm2_5_', seq(1, 12), sep = ''))
  explanatory_vars <- c(explanatory_vars, paste('pm2_5_', seq(16, 36, 4), sep = ''))
  # 'wind_speed', 'precip_total', 'precip_rate', 'solradiation')
  query = paste('SELECT',
                paste(c(response_vars, explanatory_vars), collapse = ', '),
                'FROM', table, sep = ' ')
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

