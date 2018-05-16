wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
setwd(wd)

packages <- c('RPostgreSQL', 'corrplot', 'magrittr')
import(packages)
Sys.setenv(LANG = "en")

plotCorrMat <- function (observations, corr_path) {
  png(filename = corr_path, height = 1200, width = 1200, pointsize = 25)
  M <- cor(observations[sapply(observations, is.numeric)], use = 'complete.obs')
  corrplot(M, method = 'ellipse')
  dev.off()
}

main <- function () {
  driver <- dbDriver('PostgreSQL')
  passwd <- { 'pass' }
  con <- dbConnect(driver, dbname='pollution',
                   host='localhost',
                   port=5432,
                   user='damian',
                   password=passwd)
  rm(passwd)
  on.exit(dbDisconnect(con))
  
  target_root_dir <- file.path(getwd(), 'correlation')
  mkdir(target_root_dir)
  table <- 'complete_observations'
  
  # Fetch all data
  target_dir <- target_root_dir
  obs <- dbGetQuery(con, paste('SELECT * FROM', table, sep = ' '))
  
  factors <- colnames(obs)
  excluded <- c('id', 'timestamp', 'station_id')
  factors <- factors[!(factors %in% excluded)]
  obs <- obs[, factors]
  
  # Create a corrplot for all the data
  corr_path <- file.path(target_dir, 'corrplot-all-data.png')
  plotCorrMat(obs, corr_path)
  print(paste('# of observation records:', nrow(obs), sep = ' '))
  print(paste('# of records after omiiting missing values:', nrow(na.omit(obs)), sep = ' '))
}
main()
