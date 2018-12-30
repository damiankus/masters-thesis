wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('preprocess.r')
setwd(wd)

packages <- c('RPostgreSQL', 'tidyverse')
import(packages)

series <- load_observations('observations')
series$station_id <- sapply(series$station_id, trimws)
series$timestamp <- utcts(series$timestamp)
excluded_vars <- c('id')
series <- series %>%
  select(-one_of(excluded_vars)) %>%
  arrange(timestamp, station_id)
save(series, file='original_series.Rda')