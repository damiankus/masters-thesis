# Taken from https://www.r-bloggers.com/fitting-a-neural-network-in-r-neuralnet-package/
# Section: Preparing to fit the neural network

# Normalization x -> x' in [0, 1] 

normalize_columns <- function (data) {
  # It is assumed that the passed data frame contains only 
  # numeric-valued columns
  
  maxs <- apply(data, 2, max)
  mins <- apply(data, 2, min)
  data.frame(scale(data, center = mins, scale = maxs - mins))
}

normalize_vals <- function (vals, min_val, max_val) {
  (vals - min_val) / (max_val - min_val)
}

normalize_vals <- function (vals, min_val, max_val) {
  vals * (max_val - min_val) + min_val
}

# Standadization ->  mean = 0, sd = 1

standardize <- function (data, means, sds) {
  sapply(colnames(data), function (col) { (data[, col] - means[col]) / sds[col] })
}

reverse_standardize <- function (data, means, sds) {
  sapply(colnames(data), function (col) { (data[, col] * sds[col]) + means[col] })
}

standardize_vals <- function (vals, orig_mean, orig_sd) {
  (vals - orig_mean) / orig_sd
}

reverse_standardize_vals <- function (vals, orig_mean, orig_sd) {
  vals * orig_sd + orig_mean
}