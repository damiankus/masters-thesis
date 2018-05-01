import <- function (packages) {
  Sys.setenv(LANG = 'en')
  new_packages <- packages[!(packages %in% installed.packages()[,'Package'])]
  if (length(new_packages) > 0) { install.packages(new_packages) }
  lapply(packages, library, character.only = TRUE)
}

load_observations <- function (table, variables = c('*'), stations = c(), na.omit = FALSE) {
  # Timestamps in database are stored without the time zone
  # It is assumed they represent UTC time
  Sys.setenv(TZ = 'UTC')
  driver <- dbDriver('PostgreSQL')
  passwd <- { 'pass' }
  con <- dbConnect(driver, dbname = 'pollution',
                   host = 'localhost',
                   port = 5432,
                   user = 'damian',
                   password = passwd)
  rm(passwd)
  on.exit(dbDisconnect(con))
  
  query = paste('SELECT', paste(variables, collapse = ','),
                'FROM', table, sep = ' ')
  if (length(stations) > 0) {
    query <- paste(query, " WHERE station_id IN ('", paste(stations, collapse = "','"), "')", sep = "")
  }
  df <- dbGetQuery(con, query)
  if (na.omit) {
    df <- na.omit(df)
  }
  if ('timestamp' %in% variables) {
    attr(df$timestamp, 'tzone') <- 'UTC'
  }
  df
}

cap <- function (s) {
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = '')
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
         wind_dir = 'wind direction', wind_dir_deg = 'wind direction',
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

mkdir <- function (path) {
  if (!dir.exists(path)) {
    dir.create(path, showWarnings = FALSE)
  }
}
