wd <- getwd()
setwd('..')
  source('boxplots.R')
setwd('../common')
  source('utils.r')
setwd(wd)

packages <- c('testthat', 'lubridate')
import(packages)

first_ts <- as.POSIXct(c('2018-12-1 00:00', tz='UTC')
df <- data.frame(
  id=seq(10),
  timestamp=sapply(seq(10), function (i) { first_ts })
  temperature=c(10, 100, 10),
  pm2_5=c(''),
  
)