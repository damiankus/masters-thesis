source("utils.R")
packages <- c("scales", "colorspace")
import(packages)

# Found at https://gist.github.com/Jfortin1/72ef064469d1703c6b30
# Credit to the user Jfortin1
change_color_brightness <- function (color, factor){
  col <- col2rgb(color)
  col <- col * factor
  col <- rgb(t(col), maxColorValue = 255)
  col
}

# Standard ggplot palette
COLORS <- hue_pal()(3)
COLORS <- c(COLORS[3], COLORS[1], COLORS[2])
COLOR_BASE <- COLORS[1] 
COLOR_ACCENT <- change_color_brightness(COLOR_BASE, factor = 0.7)
COLOR_SECONDARY <- COLORS[2]
COLOR_CONTRAST <- 'red'

MONTHS <- c("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
MONTHS_ABB <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

WEEKDAYS <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
WEEKDAYS_ABB <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

SEASONS <- c("winter", "spring", "summer", "autumn")

BASE_VARS <- c(
  "pm2_5",
  "temperature", "precip_rate", "humidity", "pressure", "wind_speed", "wind_dir_deg"
)

# including temporal auxiliary variables
MAIN_VARS <- c(
  BASE_VARS,
  "hour_of_day", "day_of_week", "day_of_year"
)

# Generate formatters
lapply(c('month', 'weekday', 'season'), function (name) {
  formatted_vals <- get(toupper(paste(name, 's', sep = "")))
  formatter <- function (x) {
    unlist(lapply(x, function (val) {
      formatted_vals[val]
    }))
  }
  assign(paste('pretty', name, sep = "_"), formatter, envir = globalenv())
})

A4_WIDTH <- 210
A4_HEIGHT <- 297
