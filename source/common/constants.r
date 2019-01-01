MONTHS = c('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
MONTHS_ABB = c('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
WEEKDAYS = c('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
WEEKDAYS_ABB = c('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat')
BASE_VARS = c(
  'pm2_5',
  'temperature', 'precip_total', 'humidity', 'pressure', 'wind_speed', 'wind_dir_deg'
)

# including temporal auxiliary variables
MAIN_VARS = c(
  BASE_VARS,
  'hour_of_day', 'period_of_day', 'day_of_week', 'month', 'season', 'is_heating_season', 'is_holiday'
)