source('utils.r')
packages <- c('mice')
import(packages)

# Taken from https://www.r-bloggers.com/fitting-a-neural-network-in-r-neuralnet-package/
# Section: Preparing to fit the neural network

# =====================================
# Normalization x -> x' in [0, 1]
# =====================================
normalize <- function (data) {
  # It is assumed that the passed data frame contains only 
  # numeric-valued columns
  
  data <- data.frame(data)
  maxs <- apply(data, 2, max)
  mins <- apply(data, 2, min)
  data.frame(scale(data, center = mins, scale = maxs - mins))
}

normalize_with <- function (data, mins, maxs) {
  # It is assumed that the passed data frame contains only 
  # numeric-valued columns
  
  data <- data.frame(data)
  data.frame(scale(data, center = mins, scale = maxs - mins))
}

normalize_vec <- function (vals) {
  min_val <- min(vals)
  (vals - min_val) / (max(vals) - min_val)
}

normalize_vec_with <- function (vals, min_val, max_val) {
  (vals - min_val) / (max_val - min_val)
}

reverse_normalize_with <- function (data, mins, maxs) {
  data <- data.frame(data)
  sapply(colnames(data), function (col) { data[, col] * (maxs[col] - mins[col]) + mins[col] })
}

reverse_normalize_vec_with <- function (vals, min_val, max_val) {
  vals * (max_val - min_val) + min_val
}

# =====================================
# Standadization ->  mean = 0, sd = 1
# =====================================

standardize <- function (data) {
  data <- data.frame(data)
  means <- apply(data, 2, mean)
  sds <- apply(data, 2, sd)
  sapply(colnames(data), function (col) { (data[, col] - means[col]) / sds[col] })
}

standardize_with <- function (data, means, sds) {
  data <- data.frame(data)
  sapply(colnames(data), function (col) { (data[, col] - means[col]) / sds[col] })
}

reverse_standardize_with <- function (data, means, sds) {
  data <- data.frame(data)
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

# =====================================
# Missing data imputation
# =====================================

# The split is based on the astronomical seasons in Poland
# 1 - winter, 2 - spring, 3 - summer, 4 - autumn
generate_ts_by_season <- function (season_idx, year) {
  if (season_idx < 1 || season_idx > 5) {
    stop('Season index should take value between 1 (end of last year\'s winter) and 5 (beginning of this year\'s winter)')
  }
  from_date <- ''
  to_date <- ''
  
  # It is necessary to specify the tz parameters in as.POSIXct
  # without them the final timestamps will be shifted (conversion
  # from localtime to UTC)
  if (season_idx == 1) {
    from_date <- '01-01 00:00'
    to_date <- '03-20 23:00'
  } else if (season_idx == 2) {
    from_date <- '03-21 00:00'
    to_date <- '06-21 23:00'
  } else if (season_idx == 3) {
    from_date <- '06-22 00:00'
    to_date <- '09-22 23:00'
  } else if (season_idx == 4) {
    from_date <- '09-23 00:00'
    to_date <- '12-21 23:00'
  } else if (season_idx == 5) {
    from_date <- '12-22 00:00'
    to_date <- '12-31 23:00'
  }
  
  from_date <- paste(year, from_date, sep = '-')
  to_date <- paste(year, to_date, sep = '-')
  series <- seq(from = as.POSIXct(from_date, tz = 'UTC'),
           to = as.POSIXct(to_date, tz = 'UTC'),
           by = 'hour')
  attr(series, 'tzone') <- 'UTC'
  series
}

# ===========================================
# Imputing missing values with MICE package
# ===========================================
impute_for_ts <- function (df, ts_seq, method = 'cart', imputation_count = 5, iters = 5, plot_path = '') {
  
  # POSIX timestamp cannot be imputed with MICE 
  # (and there is no point in doing so)
  variables <- colnames(df)
  variables <- variables[variables != 'timestamp']
  print(variables)
  
  # If there is at least one non-empty column,
  # the row is considered present
  present_rows_mask <- rep(FALSE, length(df[, 1]))
  for (var in variables) {
    present_rows_mask <- present_rows_mask | !is.na(df[, var]) 
  }
  
  data <- data.frame(df)
  present_ts <- df[present_rows_mask, 'timestamp']
  missing_ts <- as.POSIXct(c(setdiff(ts_seq, present_ts)), origin = '1970-01-01', tz = 'UTC')
  
  if (length(missing_ts) > 0) {
    missing_obs <- data.frame(timestamp = missing_ts)
    for (col in variables) {
      missing_obs[, col] <- NA
    }
    data <- rbind(data, missing_obs)
  }
  
  data <- data[order(data$timestamp),]
  ts <- data$timestamp
  temp_data <- mice(data[, variables], m = imputation_count,
                    maxit = iters, method = method , seed = 500)
  imputed <- complete(temp_data, 1)
  imputed$timestamp <- ts
  
  # if (nchar(plot_path) > 0) {
  #   png(filename = plot_path, width = 1366, height = 768, pointsize = 25)
  #   plot(densityplot(temp_data))
  #   dev.off()
  # }
  
  # Return imputed data
  imputed
}

# Imputing missing values with MICE package
impute_for_date_range <- function (df, from_date, to_date, method = 'cart',
                                   imputation_count = 5, iters = 5) {
  ts_seq <- seq(from = as.POSIXct(from_date, tz = 'UTC'),
                  to = as.POSIXct(to_date, tz = 'UTC'),
                  by = 'hour')
  impute_for_ts(df, ts_seq, method = method, imputation_count  = imputation_count, iters = iters)
}

impute_missing <- function (df, method = 'cart', imputation_count = 5, iters = 5) {
  min_date <- min(df$timestamp)
  max_date <- max(df$timestamp)
  impute_for_date_range(df, min_date, max_date, method = method, imputation_count = imputation_count, iters = iters)
}

# This function assumes that the time series @df is complete
# (there are records for every hourly measurment between the first and last
# measurement)
divide_into_windows <- function (df, past_lag, future_lag, vars = c(), future_vars = c(), excluded_vars = c()) {
  if (length(vars) == 0) {
    vars <- colnames(df)
    vars <- vars[!(vars %in% excluded_vars)]
  }
  past_var_cols <- vars
  if (past_lag > 0) {
    past_seq <- seq(past_lag, 1)
    past_var_cols <- unlist(lapply(vars, function (v) {
      c(paste(v, paste('past', past_seq, sep = '_'), sep = '_'), v)
    }))
  }
  
  if (length(future_vars) == 0) {
    future_vars <- colnames(df)
    future_vars <- vars[!(future_vars %in% excluded_vars)]
  }
  future_var_cols <- paste('future', future_vars, sep = '_')
  
  # New columns of a single row: 
  # * lagged observations with increasing timestamp, 
  # * current observation
  # * future varaiable values
  # Example (A, B - variables, A is the response var):
  # A-2, B-2, A-1, B-1, A, B, future_A
  new_colnames <- c(past_var_cols, future_var_cols)
  
  df <- data.matrix(df)
  rows <- sapply(seq(past_lag + 1, length(df[, 1]) - future_lag), function (i) {
    row <- c(df[(i - past_lag):i, vars],
             df[i + future_lag, future_vars],
             recursive = TRUE)
    row
  })
  rows <- t(rows)
  windows <- data.frame(rows)
  colnames(windows) <- new_colnames
  windows
}

# Detect linearly dependent explanatory variables and remove them
# from the model formula
skip_colinear_variables <- function (res_formula, df, model = NA) {
  if (is.na(model)) {
    model <- lm(formula = res_formula, data = df)
  }
  lin_dep <- attributes(alias(model)$Complete)$dimnames[[1]]
  vars <- all.vars(res_formula)
  
  # First var is the response variable
  explanatory <- vars[2:length(vars)]
  explanatory <- explanatory[!(explanatory %in% lin_dep)]
  as.formula(paste(vars[1], '~', paste(explanatory, collapse = '+'), sep = ' '))
} 

skip_constant_variables <- function (res_formula, df) {
  vars <- all.vars(res_formula)
  explanatory <- vars[2:length(vars)]
  which_vary <- sapply(df[, explanatory], function (col) {
    var(col, na.rm = TRUE) != 0
  })
  explanatory <- explanatory[which_vary]
  as.formula(paste(vars[1], '~', paste(explanatory, collapse = '+'), sep = ' '))
}

# vars and excluded store names of base variables (without the past_ and future_ prefixes)
add_aggregated <- function (windows, past_lag, vars=c(), excluded = c(), na.rm = TRUE) {
  if (past_lag <= 0) {
    windows
  }
  
  which_present <- c()
  if (length(vars) == 0) {
    # Find all base var names (not past and not future ones)
    vars <- colnames(windows)
    which_past <- grepl('past', vars)
    which_future <- grepl('future', vars)
    which_present <- (!which_past) & (!which_future)
    vars <- vars[which_present]
    vars <- vars[!(vars %in% excluded)]
  }
  
  all_vars <- colnames(windows)
  which_future <- grepl('future', all_vars)
  aggr_vars <- unlist(lapply(vars, function (v) {
    which_selected <- grepl(v, all_vars)
    aggr_vars <- all_vars[which_selected & (!which_future)]
  }))
  
  aggr_types <- c('min', 'mean', 'max')
  aggr_funs <- sapply(aggr_types, get)
  
  all_stats <- lapply(vars, function (v) {
    which_vars <- aggr_vars[grepl(v, aggr_vars)]
    
    aggr_names <- sapply(aggr_types, function (t) {
      paste(t, (past_lag + 1), v, sep = '_')
    })
    
    # If the past lag was 0 $sliced would become a 1D vector
    # thus causing an error in apply
    sliced <- data.frame(windows[, which_vars])
    stats <- apply(sliced, 1, function (row, aggr_names, aggr_funs) {
      row_stats <- unlist(lapply(aggr_funs, function (f) {
        f(row, na.rm = na.rm)
      }))
      row_stats
    }, aggr_names = aggr_names, aggr_funs = aggr_funs)
    stats <- data.frame(t(stats))
    colnames(stats) <- aggr_names
    stats
  })
  cbind(windows, all_stats)
}

skip_past <- function (windows, excluded = c()) {
  vars <- colnames(windows)
  past_vars <- vars[grepl('past', vars)]
  excluded <- unlist(
    lapply(excluded, function (e) { past_vars[grepl(e, past_vars)] })
  )
  past_vars <- setdiff(past_vars, excluded)
  windows[, setdiff(vars, past_vars)]
}

df_to_list_of_columns <- function (df) {
  lapply(colnames(df), function (colname) {
    df[, colname]
  })
}
