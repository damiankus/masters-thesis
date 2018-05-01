# Taken from https://www.r-bloggers.com/fitting-a-neural-network-in-r-neuralnet-package/
# Section: Preparing to fit the neural network

# Normalization x -> x' in [0, 1]

source('utils.r')
packages <- c('mice')
import(packages)

normalize <- function (data) {
  # It is assumed that the passed data frame contains only 
  # numeric-valued columns
  
  maxs <- apply(data, 2, max)
  mins <- apply(data, 2, min)
  data.frame(scale(data, center = mins, scale = maxs - mins))
}

normalize_with <- function (data, mins, maxs) {
  # It is assumed that the passed data frame contains only 
  # numeric-valued columns
  
  data.frame(scale(data, center = mins, scale = maxs - mins))
}

normalize_vec <- function (vals) {
  min_val <- min(vals)
  (vals - min_val) / (max(vals) - min_val)
}

normalize_vec_with <- function (vals, min_val, max_val) {
  (vals - min_val) / (max_val - min_val)
}

reverse_normalize_vec_with <- function (vals, min_val, max_val) {
  vals * (max_val - min_val) + min_val
}

# Standadization ->  mean = 0, sd = 1

standardize <- function (data) {
  means <- apply(data, 2, mean)
  sds <- apply(data, 2, sd)
  sapply(colnames(data), function (col) { (data[, col] - means[col]) / sds[col] })
}

standardize_with <- function (data, means, sds) {
  sapply(colnames(data), function (col) { (data[, col] - means[col]) / sds[col] })
}

reverse_standardize_with <- function (data, means, sds) {
  sapply(colnames(data), function (col) { (data[, col] * sds[col]) + means[col] })
}

standardize_vec <- function (vals) {
  (vals - mean(vals)) / sd(vals)
}

standardize_vec_with <- function (vals, orig_mean, orig_sd) {
  (vals - orig_mean) / orig_sd
}

reverse_standardize_vec_with <- function (vals, orig_mean, orig_sd) {
  vals * orig_sd + orig_mean
}

# Splitting data

split_by_heating_season <- function (df) {
  sapply(df$timestamp, function (ts) {
    month <- as.POSIXlt(ts)$mon + 1
    (month < 4) || (month > 9) })
}

# The split is based on the astronomical seasons in Poland
split_by_season <- function (df) {
  sapply(df$timestamp, function (ts) {
    date <- format(as.Date(ts), format = '%m-%d')
    spring_day <- '03-21'
    summer_day <- '06-22'
    autumn_day <- '09-23'
    winter_day <- '12-22'
    season <- 'winter'
    if (date >= spring_day && date < summer_day) {
      season <- 'spring'
    } else if (date >= summer_day && date < autumn_day) {
      season <- 'summer'
    } else if (date >= autumn_day && date < winter_day) {
      season <- 'autumn'
    }
    season
  })
}

# The split is based on the astronomical seasons in Poland
generate_ts_by_season <- function (season_name, year) {
  from_date <- ''
  to_date <- ''
  series <- c()
  
  # It is necessary to specify the tz parameters in as.POSIXct
  # without them the final timestamps will be shifted (conversion
  # from localtime to UTC)
  if (season_name == 'winter') {
    from_date <- paste(year, '-01-01 00:00', sep = '')
    to_date <- paste(year, '-03-20 23:00', sep = '')
    series <- seq(from = as.POSIXct(from_date, tz = 'UTC'),
                  to = as.POSIXct(to_date, tz = 'UTC'),
                  by = 'hour')
    from_date <- '12-22 00:00'
    to_date <- '12-31 23:00'
  } else if (season_name == 'spring') {
    from_date <- '03-21 00:00'
    to_date <- '06-21 23:00'
  } else if (season_name == 'summer') {
    from_date <- '06-22 00:00'
    to_date <- '09-22 23:00'
  } else {
    from_date <- '09-23 00:00'
    to_date <- '12-21 23:00'
  }
  
  from_date <- paste(year, '-', from_date, sep = '')
  to_date <- paste(year, '-', to_date, sep = '')
  
  # Appending timestamps to an empty vector causes 
  # conversion to the number of seconds since 1970-01-01
  # Thus the if-else workaround
  s <- seq(from = as.POSIXct(from_date, tz = 'UTC'),
           to = as.POSIXct(to_date, tz = 'UTC'),
           by = 'hour')
  if (length(series) == 0) {
    series <- s
  } else {
    series <- c(series, s)
  }
  attr(series, 'tzone') <- 'UTC'
  series
}

# Imputing missing values with MICE package
impute <- function (df, from_date, to_date, imputation_count = 5, iters = 5) {
  year_seq <- seq(from = as.POSIXct(from_date, tz = 'UTC'),
                  to = as.POSIXct(to_date, tz = 'UTC'),
                  by = 'hour')
  variables <- colnames(df)
  variables <- variables[variables != 'timestamp']
  
  # If all values in all columns in the row are present -> TRUE
  row_presence_mask <- rep(TRUE, length(df[, 1]))
  for (col in colnames(df)) {
    row_presence_mask <- row_presence_mask & (!is.na(df[, col]))
  }
  which.present <- which(row_presence_mask)
  present_ts <- df[which.present, 'timestamp']
  missing_ts <- as.POSIXct(c(setdiff(year_seq, present_ts)), origin = '1970-01-01', tz = 'UTC')
  missing_obs <- data.frame(timestamp = missing_ts)
  for (col in variables) {
    missing_obs[, col] <- NA
  }
  imputed <- data.frame(df)
  imputed <- rbind(imputed, missing_obs)
  imputed <- imputed[order(imputed$timestamp),]
  ts <- imputed$timestamp
  
  temp_data <- mice(imputed[, variables], m = imputation_count, maxit = iters, meth = 'pmm', seed = 500)
  densityplot(temp_data)
  imputed <- complete(temp_data, 1)
  imputed$timestamp <- ts
  
  # Return imputed data
  imputed
}

# Imputing missing values with MICE package
impute <- function (df, ts_seq, imputation_count = 5, iters = 5) {
  variables <- colnames(df)
  variables <- variables[variables != 'timestamp']
  
  # If all values in all columns in the row are present -> TRUE
  row_presence_mask <- rep(TRUE, length(df[, 1]))
  for (col in colnames(df)) {
    row_presence_mask <- row_presence_mask & (!is.na(df[, col]))
  }
  which.present <- which(row_presence_mask)
  present_ts <- df[which.present, 'timestamp']
  missing_ts <- as.POSIXct(c(setdiff(ts_seq, present_ts)), origin = '1970-01-01', tz = 'UTC')
  missing_obs <- data.frame(timestamp = missing_ts)
  for (col in variables) {
    missing_obs[, col] <- NA
  }
  imputed <- data.frame(df)
  imputed <- rbind(imputed, missing_obs)
  imputed <- imputed[order(imputed$timestamp),]
  ts <- imputed$timestamp
  
  temp_data <- mice(imputed[, variables], m = imputation_count, maxit = iters, meth = 'pmm', seed = 500)
  densityplot(temp_data)
  imputed <- complete(temp_data, 1)
  imputed$timestamp <- ts
  
  # Return imputed data
  imputed
}