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
pollutants <- rbind(pollutants, c("dow", "Sun 0-6 Sat"))

plot_pol <- function (pol) {
  p <- ggplot(observations, aes_string(x = "measurementdate", y = pol["type"])) +
    geom_line(aes_string(color = pol["type"])) +
    geom_point() +
    geom_line(aes(y = temperature), colour = "black") +
    geom_line(aes(y = dow), colour = "green") +
    scale_colour_gradient(low = "blue", high = "red") +
    labs(x = "Date of measurement", y = paste(pol["type"], "[", pol["unit"] ,"]", sep=" ")) +
    ggtitle(location)
  
  plotPath <- paste(pol["type"], "_station_", id, ".jpg", sep = "")
  plotPath <- file.path(targetDir, plotPath)
  ggsave(plotPath, width = 16, height = 10, dpi = 200)
  print(paste("Plot saved under", plotPath, sep=" "))
}

targetRootDir <- file.path(getwd(), "airy")
dir.create(targetRootDir)

measArgs <- paste(pollutants[,"type"], collapse=", ")
measurmentStat <- paste("SELECT timereadable as measurementdate,",
                        measArgs,
                        "FROM observations", 
                        "WHERE station_id = %d",
                        # "AND timereadable >= '2017-11-25'::timestamp",
                        # "AND timereadable <= '2017-12-16'::timestamp",
                        "AND timereadable >= '2017-10-18'::timestamp",
                        "AND timereadable <= '2017-11-15'::timestamp",
                        "ORDER BY measurementdate", sep = " ")

idx <- which(stations$id == 234)
location <- stations[idx, "location_address"]

for (id in c(234)) {
  targetDir <- file.path(targetRootDir, id, "warm")
  # targetDir <- file.path(targetRootDir, id, "cold")
  dir.create(targetDir)
  observations <- dbGetQuery(con, sprintf(measurmentStat, id))
  apply(pollutants, 1, plot_pol)
}

