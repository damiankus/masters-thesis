import <- function (packages) {
  Sys.setenv(LANG = 'en')
  new_packages <- packages[!(packages %in% installed.packages()[,'Package'])]
  if (length(new_packages) > 0) { install.packages(new_packages, dependencies = TRUE) }
  lapply(packages, library, character.only = TRUE)
}

get_connection <- function () {
  driver <- dbDriver('PostgreSQL')
  passwd <- { 'pass' }
  con <- dbConnect(driver, dbname = 'pollution',
                   host = 'localhost',
                   port = 5432,
                   user = 'damian',
                   password = passwd)
  rm(passwd)
  con
}

load_observations <- function (table, variables = c('*'), stations = c(),
                               na.omit = FALSE) {
  con <- get_connection()
  on.exit(dbDisconnect(con))
  
  # Timestamps in database are stored without the time zone
  # It is assumed they represent UTC time
  Sys.setenv(TZ = 'UTC')
  con <- get_connection()
  on.exit(dbDisconnect(con))
  query = paste('SELECT', paste(variables, collapse = ','),
                'FROM', table, sep = ' ')
  if (length(stations) > 0) {
    query <- paste(query, " WHERE station_id IN ('", paste(stations, collapse = "','"), "')", sep = "")
  }
  df <- dbGetQuery(con, query)
  dbDisconnect(con)
  if (na.omit) {
    df <- na.omit(df)
  }
  if ('timestamp' %in% colnames(df)) {
    attr(df$timestamp, 'tzone') <- 'UTC'
    df <- df[order(df$timestamp),]
  }
  df
}

create_table_from_schema <- function (source_tab, target_tab, con = NULL) {
  if (is.null(con)) {
    con <- get_connection()
    on.exit(dbDisconnect(con))
  }
  if (dbExistsTable(con, target_tab)) {
    dbRemoveTable(con, target_tab)
  }
  # Copy schema without any data 
  dbGetQuery(con, paste('SELECT * INTO', target_tab,
                        'FROM', source_tab,
                        'WHERE 1 = 0'))
}

write_table <- function (df, tab_name, con = NULL) {
  if (is.null(con)) {
    con <- get_connection()
    on.exit(dbDisconnect(con))
  }
  Sys.setenv(TZ = 'UTC')
  dbWriteTable(con, tab_name, df, row.names=FALSE, append=TRUE)
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
         wind_dir = 'wind direction', wind_dir_deg = 'wind direction', precip_rate = 'Precipitation rate', precip_total = 'Total precipitation',
         {
           delim <- ' '
           join_str <- ' '
           var_idx <- 1
           if (grepl('future', var)) {
             delim <- 'future_'
             join_str <- ''
             var_idx <- 2
           } else if (grepl('past', var)) {
             delim <- '_past_'
             join_str <- '-'
           }     
           split_var <- strsplit(var, delim)[[1]]
           pvar <- ''
           if (length(split_var) > 1) {
             pvar <- pretty_var(split_var[var_idx])
             pvar <- paste(pvar, join_str, paste(split_var[-var_idx], collapse = ' '), sep = ' ')
           } else {
             pvar <- toupper(var)
           }
           trimws(pvar)
         })
}

mkdir <- function (path) {
  if (!dir.exists(path)) {
    dir.create(path, showWarnings = TRUE, recursive = TRUE)
  }
}

utcts <- function (datestring) {
  as.POSIXct(datestring, origin = '1970-01-01', tz = 'UTC')
}
