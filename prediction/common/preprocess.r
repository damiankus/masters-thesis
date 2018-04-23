# Taken from https://www.r-bloggers.com/fitting-a-neural-network-in-r-neuralnet-package/
# Section: Preparing to fit the neural network

# Normalization x -> x' in [0, 1] 

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

# Transform data

transform <- function (df, factors, trans) {
  for (f in factors) {
    df[,f] <- trans(df[,f])
  }
}

# Imputing missing values

impute <- function (df, from_date, to_date, imputation_count = 5, iters = 10) {
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