install.packages('RPostgreSQL')
require('RPostgreSQL')
driver <- dbDriver('PostgreSQL')
passwd <- { 'pass' }
con <- dbConnect(driver, dbname='airy',
                 host='localhost',
                 port=5432,
                 user='damian',
                 password=passwd)
rm(passwd)
dbExistsTable(con, 'stations')
stations <- dbGetQuery(con, 'SELECT * FROM stations');
pollutants <- dbGetQuery(con, "SELECT type FROM pollutants")[,1]
pollutants <- unlist(lapply(pollutants, trimws))

aggrFormatterFactory <- function(aggrFunName) {
  function (argName) {
    paste(toupper(aggrFunName), "(", argName, ") AS ", argName, sep="") 
  }
}

for (aggrType in c("avg", "min", "max", "count")) {
  aggr <- aggrFormatterFactory(aggrType)
  measArgs <- unlist(lapply(pollutants, aggr))
  measArgs <- paste(measArgs, collapse=", ")
  measurmentStat <- paste("SELECT DATE(timereadable) as measurementdate,",
                    measArgs,
                    "FROM observations", 
                    "WHERE station_id = %d",
                    "GROUP BY measurementdate",
                    "ORDER BY measurementdate", sep = " ")
  
  for (id in c(234)) {
    targetRootDir <- file.path(getwd(), "Dokumenty/masters-thesis/analysis/airy", id)
    dir.create(targetRootDir)
    targetRootDir <- file.path(targetRootDir, aggrType)
    dir.create(targetRootDir)
    
    observations <- dbGetQuery(con, sprintf(measurmentStat, id))
    for (pol in pollutants) {
      plotPath <- paste(aggrType, "_", pol, "_station_", id, ".jpg", sep = "") 
      plotPath <- file.path(targetRootDir, plotPath)
      jpeg(plotPath)
      plot(observations[,pol],
           type="l",
           main=sprintf("Measurments of %s for station [%d]", pol, id))
      dev.off()
      print(paste("Plot saved under", plotPath, sep=" "))
    }
  }
}


