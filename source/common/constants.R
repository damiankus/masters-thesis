source("utils.R")
packages <- c("scales", "colorspace")
import(packages)

COLORS <- hue_pal()(4)
COLORS <- c(COLORS[3], COLORS[1], COLORS[2], COLORS[4])

MONTHS <- c("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
MONTHS_ABB <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

WEEKDAYS <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
WEEKDAYS_ABB <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

SEASONS <- c("Winter", "Spring", "Summer", "Autumn")

BASE_VARS <- c(
  "pm2_5", "pm10",
  "temperature", "precip_rate", "humidity", "pressure", "wind_speed", "wind_dir_deg", "solradiation"
)

# including temporal auxiliary variables
MAIN_VARS <- c(
  BASE_VARS,
  "hour_of_day", "period_of_day", "day_of_week", "month", "season", "is_heating_season", "is_holiday"
)

