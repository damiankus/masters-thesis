require('RPostgreSQL')
require("ggplot2")
driver <- dbDriver('PostgreSQL')
passwd <- { 'pass' }
con <- dbConnect(driver, dbname='airy',
                 host='localhost',
                 port=5432,
                 user='damian',
                 password=passwd)
rm(passwd)
dbExistsTable(con, 'stations')
stations <- dbGetQuery(con, 'SELECT * FROM stations')[,c("id", "location_address")];
pollutants <- dbGetQuery(con, "SELECT * FROM pollutants")
pollutants[,"type"] <- unlist(lapply(pollutants[,"type"], trimws))
pollutants[,"unit"] <- unlist(lapply(pollutants[,"unit"], trimws))

aggrFormatterFactory <- function (aggrFunName) {
  function (argName) {
    paste(toupper(aggrFunName), "(", argName, ") AS ", argName, sep="") 
  }
}

plot_pol <- function (pol) {
  p <- ggplot(observations, aes_string(x = "measurementdate", y = pol["type"])) +
    geom_line(aes_string(color = pol["type"])) +
    geom_point() +
    scale_colour_gradient(low = "blue", high = "red") +
    scale_x_date(date_labels = "%d-%m-%y", date_breaks = "1 month") +
    labs(x = "Date of measurement", y = paste(aggrType, pol["type"], "[", pol["unit"] ,"]", sep=" ")) +
    ggtitle(location)
  
  plotPath <- paste(aggrType, "_", pol["type"], "_station_", id, ".jpg", sep = "")
  plotPath <- file.path(targetDir, plotPath)
  ggsave(plotPath, width = 16, height = 10, dpi = 200)
  print(paste("Plot saved under", plotPath, sep=" "))
}

targetRootDir <- file.path(getwd(), "airy")
dir.create(targetRootDir)
for (aggrType in c("avg", "min", "max", "count")) {
  aggr <- aggrFormatterFactory(aggrType)
  measArgs <- unlist(lapply(pollutants[,"type"], aggr))
  measArgs <- paste(measArgs, collapse=", ")
  measurmentStat <- paste("SELECT DATE(timereadable) as measurementdate,",
                    measArgs,
                    "FROM observations", 
                    "WHERE station_id = %d",
                    "GROUP BY measurementdate",
                    "ORDER BY measurementdate", sep = " ")
  
  for (idx in 1:nrow(stations)) {
    id <- stations[idx, "id"]
    location <- stations[idx, "location_address"]
    targetDir <- file.path(targetRootDir, id)
    dir.create(targetDir)
    targetDir <- file.path(targetDir, aggrType)
    dir.create(targetDir)
    observations <- dbGetQuery(con, sprintf(measurmentStat, id))
    apply(pollutants, 1, plot_pol)
  }
}


