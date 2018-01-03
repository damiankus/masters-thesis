require("RPostgreSQL")
require("ggplot2")
require("reshape")
require("corrplot")

get_normalized <- function (column) {
  min_val <- min(column)
  max_val <- max(column)
  delta <- max_val - min_val
  sapply(column, function (v) (v - min_val) / delta)
}

plotAllPollutants <- function (observations, stationId, targetDir) {
  dataIdx <- match("measurementdate", colnames(observations))
  which <- colnames(observations)[-dataIdx]
  scaledObservations <- data.frame(sapply(observations[which], get_normalized))
  scaledObservations["measurementdate"] <- observations["measurementdate"]
  melted <- melt(scaledObservations, id.vars = "measurementdate")
  plot <- ggplot(data = melted, aes(x = measurementdate, y = value, fill = variable)) +
    geom_bar(stat = "identity", position = "dodge")
  plotPath <- paste("all_station_", stationId, ".jpg", sep = "")
  plotPath <- file.path(targetDir, plotPath)
  ggsave(plotPath, width = 16, height = 10, dpi = 200)
  print(paste("Plot saved under", plotPath, sep=" "))
}

plotCorrMat <- function (observations) {
  M <- cor(observations[sapply(observations, is.numeric)])
  print(M)
  corrplot(M, method = "ellipse")
}

main <- function () {
  driver <- dbDriver("PostgreSQL")
  passwd <- { "pass" }
  con <- dbConnect(driver, dbname="airy",
                   host="localhost",
                   port=5432,
                   user="damian",
                   password=passwd)
  rm(passwd)
  on.exit(dbDisconnect(con))
  
  dbExistsTable(con, "stations")
  stations <- dbGetQuery(con, "SELECT * FROM stations")[,c("id", "location_address")];
  pollutants <- dbGetQuery(con, "SELECT * FROM pollutants")
  pollutants[,"type"] <- unlist(lapply(pollutants[,"type"], trimws))
  pollutants[,"unit"] <- unlist(lapply(pollutants[,"unit"], trimws))
  pollutants <- rbind(pollutants, c("dow", "Sun 0-6 Sat"))
  
  plot_pollution <- function (pol, observations, min_temp, max_temp) {
    max_pol <- max(observations[,pol["type"]])
    min_pol <- min(observations[,pol["type"]])
    dates <- observations[,"measurementdate"]
    offset <- min_pol - min_temp
    scale_factor <- max_pol / max_temp
    scaled_temperatures <- sapply(observations[,"temperature"], function(t) (t + offset) * scale_factor)
    scaled_temperatures <- data.frame(scaled_temperatures, dates)
    colnames(scaled_temperatures) <- c("temperature", "measurementdate")

    max_dow <- 6
    scale_factor <- 0.75 * (max_pol / max_dow)
    scaled_dows <- sapply(observations[,"dow"], function(dow) dow * scale_factor)
    scaled_dows <- data.frame(scaled_dows, dates)
    colnames(scaled_dows) <- c("dow", "measurementdate")

    p <- ggplot(data = observations, aes_string(x = "measurementdate", y = pol["type"])) +
      geom_line(aes_string(color = pol["type"])) +
      scale_colour_gradient(low = "blue", high = "yellow") +
      geom_line(data = scaled_dows, aes_string(x = "measurementdate", y = "dow"), colour = "green") +
      geom_point() +
      geom_line(data = scaled_temperatures, aes_string(x = "measurementdate", y = "temperature"), colour = "red") +
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
                          "AND timereadable >= '2017-11-25'::timestamp",
                          "AND timereadable <= '2017-12-16'::timestamp",
                          # "AND timereadable >= '2017-10-18'::timestamp",
                          # "AND timereadable <= '2017-11-15'::timestamp",
                          "ORDER BY measurementdate", sep = ' ')
  
  idx <- which(stations$id == 234)
  location <- stations[idx, "location_address"]
  targetRootDir <- file.path(targetRootDir, "warm")
  dir.create(targetRootDir)
  
  for (id in c(234)) {
    targetDir <- file.path(targetRootDir, id)
    dir.create(targetDir)
    observations <- dbGetQuery(con, sprintf(measurmentStat, id))
    min_temp <- min(observations[,"temperature"])
    max_temp <- max(observations[,"temperature"])
    apply(pollutants, 1, plot_pollution, observations, min_temp, max_temp)
    plotAllPollutants(observations, id, targetDir)
    plotCorrMat(observations)
  }
}

main()
