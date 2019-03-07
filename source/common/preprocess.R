source('utils.R')
source('constants.R')

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
# Standardization ->  mean = 0, sd = 1
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
add_aggregated <- function (windows, past_lag, vars_to_aggregate=c(), excluded = c(), na.rm = TRUE) {
  if (past_lag <= 0) {
    windows
  }
  
  which_present <- c()
  vars <- if (length(vars_to_aggregate) == 0) {
    # Find all base var names (not past and not future ones)
    vars <- colnames(windows)
    which_past <- grepl('past', vars)
    which_future <- grepl('future', vars)
    which_present <- (!which_past) & (!which_future)
    present_vars <- vars[which_present]
    present_vars[!(present_vars %in% excluded)]
  } else {
    vars_to_aggregate
  }
  
  all_vars <- colnames(windows)
  which_future <- grepl('future', all_vars)
  aggr_vars <- unlist(lapply(vars, function (v) {
    which_selected <- grepl(v, all_vars)
    aggr_vars <- all_vars[which_selected & (!which_future)]
  }))
  
  aggr_types <- c('min', 'mean', 'max', 'sum')
  aggr_type_names <- c(aggr_types[1:3], 'total')
  aggr_funs <- sapply(aggr_types, get)
    
  all_stats <- lapply(vars, function (v) {
    which_vars <- aggr_vars[grepl(v, aggr_vars)]
    
    aggr_names <- sapply(aggr_type_names, function (t) {
      paste(t, (past_lag + 1), v, sep = '_')
    })
    
    # If the past lag was 0, $sliced would become a 1D vector
    # thus causing an error in apply
    sliced <- data.frame(windows[, which_vars])
    stats <- apply(sliced, 1, function (row) {
      row_stats <- unlist(lapply(aggr_funs, function (f) {
        # If the row consitst only of NA values
        # min and max functions raise a warning 
        # about using +- Inf values
        suppressWarnings(f(row, na.rm = na.rm))
      }))
      row_stats
    })
    stats <- data.frame(t(stats))
    colnames(stats) <- aggr_names
    stats
  })
  windows_with_stats <- cbind(windows, all_stats)
  do.call(data.frame, lapply(windows_with_stats, function (col) {
    replace(col, is.nan(col) | is.infinite(col), NA)
  }))
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
