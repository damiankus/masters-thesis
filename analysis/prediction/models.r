wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c('caTools', 'glmnet', 'car', 'e1071', 'forecast', 'keras')
import(packages)
Sys.setenv(LANG = 'en')

# Predicted value is the last registered value
fit_persistence <- function (res_formula, training_set, test_set, target_dir) {
  print('Fitting a persistence model')
  res_var <- all.vars(res_formula)[[1]]
  base_var <- gsub('future_', '', res_var)
  pred_vals <- test_set[, base_var]
  results <- data.frame(actual = test_set[, res_var], predicted = pred_vals)
  results$timestamp <- test_set$future_timestamp
  results
}

fit_mlr <- function (res_formula, training_set, test_set, target_dir) {
  print('Fitting a linear regression model')
  res_var <- all.vars(res_formula)[[1]]
  model <- lm(res_formula,
            data = training_set)
  pred_vals <- predict(model, test_set)
  res_var <- all.vars(res_formula)[[1]]
  results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
  results$timestamp <- test_set$future_timestamp
  
  summ_funs <- c(
    summary,
    function (model) {
      vifs <- vif(model)
      print(sort(vifs))
    },
    function (model) {
      # The first coeff is the intercept
      pvals <- sort(summary(model)$coefficients[-1,4])
      vifs <- vif(model)
      stats <- data.frame(pval = pvals, vif = vifs[names(pvals)])
      stats <- stats[which(stats$pval < 0.05 & stats$vif < 5),]
      info <- paste('Variables with p-val < 0.05 and VIF < 5: c(\'',
                    paste(rownames(stats), collapse = "', '"),
                    "')", sep = '')
      print(info)
    })
  
  # file_path <- file.path(target_dir, 'regression_summary.txt')
  # save_summary(model, results, file_path, summary_funs = summ_funs)
  # save_prediction_goodness(results, file_path)
  # save_prediction_comparison(results, res_var, 'regression', target_dir)
  results
}

fit_log_mlr <- function (res_formula, training_set, test_set, target_dir) {
  print('Fitting a log-linear regression model')
  vars <- all.vars(res_formula)
  res_var <- vars[1]
  explanatory <- vars[2:length(vars)]
  res_formula <- as.formula(paste('log(', res_var, ') ~', paste(explanatory, collapse = '+'), sep = ''))
  results <- fit_mlr(res_formula, training_set, test_set, target_dir)
  results$predicted <- exp(results$predicted)
  results
}

fit_svr <- function (res_formula, training_set, test_set, target_dir) {
  print('Fitting a support vector regression model')
  res_var <- all.vars(res_formula)[[1]]
  model <- svm(res_formula, training_set)
  pred_vals <- predict(model, test_set)
  results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
  results$timestamp <- test_set$future_timestamp
  
  # file_path <- file.path(target_dir, 'svr_summary.txt')
  # save_summary(model, results, file_path)
  # save_prediction_goodness(results, file_path)
  # save_prediction_comparison(results, res_var, 'svr', target_dir)
  results
}

fit_arima <- function (res_formula, training_set, test_set, target_dir) {
  print('Fitting ARIMA model')
  
  # res_var - future_pm2_5
  # base_var - pm2_5
  res_var <- all.vars(res_formula)[[1]]
  base_var <- gsub('future_', '', res_var)

  training_ts = ts(training_set[, base_var], frequency = 24)
  test_seq <- c(training_set[, base_var], test_set[, base_var])
  last_training_idx <- length(training_ts)
  
  model <- Arima(training_ts,
                 order = c(1, 1, 2), 
                 seasonal = list(order = c(2, 0, 0),
                                 period = 24),
                 method = 'CSS')
  pred_vals <- unlist(
    lapply(seq(last_training_idx + 1, last_training_idx + length(test_set[, 1])),
           function (i) {
             model <- Arima(ts(test_seq[1:i], frequency = 24), model = model)
             tail(forecast(model, h = 24)$mean, n = 1)
           }))
  
  results <- data.frame(actual = test_set[, res_var], 
             predicted = pred_vals,
             timestamp = test_set$future_timestamp)
  
  file_path <- file.path(target_dir, 'arima_summary.txt')
  save_summary(model, results, file_path)
  save_prediction_goodness(results, file_path)
  save_prediction_comparison(results, res_var, 'arima', target_dir)
  
  results
  
  # decomposed = stl(res_ts, s.window = 'periodic')
  # trend <- decomposed$time.series[, 'trend']
  # seasonal <- decomposed$time.series[, 'seasonal']
  # remainder <- decomposed$time.series[, 'remainder']
}

fit_lstm <- function (res_formula, training_set, test_set, target_dir) {
  res_var <- all.vars(res_formula)[[1]]
  vars <- colnames(training_set)
  vars <- vars[startsWith(vars, 'pm2_5')]
  vars <- c(vars, res_var) 
  batch_size <- length(training_set[, 1])
  cols_count <- length(vars)
  
  training_3d <- array(apply(training_set[, vars], 2, function (row) {
      array(
        lapply(row, function (x) { array(x, dim = c(1)) }),
        dim = c(cols_count, 1)
      )
    }), dim = c(batch_size, cols_count, 1))
  
  model <- keras_model_sequential()
  model %>%
    layer_lstm(12, input_shape = c(cols_count, 1)) %>%
    layer_dense(10) %>%
    layer_dense(1) %>%
    layer_activation("linear")
  
  model %>% compile(
    loss = "mse",
    metrics = "mse",
    optimizer = "adam"
  )
  
  history <- model %>% fit(
    training_3d[, 1:(cols_count - 1), ], training_3d[, cols_count, ],
    batch_size = 128,
    epochs = 20,
    validation_split = 0.8,
    verbose = TRUE
  )
}

