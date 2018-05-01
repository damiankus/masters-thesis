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

# WARNING!
# After returning the result it must be casted to data.frame!
# R seemingly does not support returning multiple data frames directly,
# thus the workaround with the list
split_by_heating_season <- function (df) {
  sapply(df$timestamp, function (ts) {
    month <- as.POSIXlt(ts)$mon + 1
    (month < 4) || (month > 9) })
}

# 0 - winter, 1 - spring, 2 - summer, 3 - autumn
# The split is based on the astronomical seasons in Poland
split_by_season <- function (df) {
  sapply(df$timestamp, function (ts) {
    date <- format(as.Date(ts), format = '%m-%d')
    spring_day <- '03-21'
    summer_day <- '06-22'
    autumn_day <- '09-23'
    winter_day <- '12-22'
    season <- 0
    if (date >= spring_day && date < summer_day) {
      season <- 1
    } else if (date >= summer_day && date < autumn_day) {
      season <- 2
    } else if (date >= autumn_day && date < winter_day) {
      season <- 3
    }
    season
  })
}

# This function assigns value TRUE to records from the specified month
# and FALSE to the remaining ones
# month_no begins from 1 (1 - January, 12 - December)
split_by_month <- function (df, month_no) {
  sapply(df$timestamp, function (ts) { (as.POSIXlt(ts)$mon + 1) == month_no  })
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
  imputed <- data.frame(obs)
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