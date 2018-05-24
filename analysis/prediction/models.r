wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c('caTools', 'glmnet', 'car', 'e1071', 'forecast', 'keras', 'neuralnet')
import(packages)
Sys.setenv(LANG = 'en')

to_results <- function (res_formula, test_set, predicted) {
  res_var <- all.vars(res_formula)[[1]]
  results <- data.frame(actual = test_set[, res_var], predicted = predicted)
  results$timestamp <- test_set$future_timestamp
  results
}

# Predicted value is the last registered value
fit_persistence <- function (res_formula, training_set, test_set, target_dir) {
  res_var <- all.vars(res_formula)[[1]]
  base_var <- gsub('future_', '', res_var)
  pred_vals <- test_set[, base_var]
  to_results(res_formula, test_set, pred_vals)
}

fit_mlr <- function (res_formula, training_set, test_set, target_dir) {
  res_var <- all.vars(res_formula)[[1]]
  model <- lm(res_formula,
            data = training_set)
  pred_vals <- predict(model, test_set)
  
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
  to_results(res_formula, test_set, pred_vals)
}

fit_log_mlr <- function (res_formula, training_set, test_set, target_dir) {
  vars <- all.vars(res_formula)
  res_var <- vars[1]
  explanatory <- vars[2:length(vars)]
  res_formula <- as.formula(paste('log(', res_var, ') ~', paste(explanatory, collapse = '+'), sep = ''))
  results <- fit_mlr(res_formula, training_set, test_set, target_dir)
  results$predicted <- exp(results$predicted)
  results
}

fit_lasso_mlr <- function (res_formula, training_set, test_set, target_dir) {
  vars <- all.vars(res_formula)
  res_var <- vars[[1]]
  expl_vars <- vars[2:length(vars)]
  training_mat <- model.matrix(res_formula, data = training_set)
  fit <- cv.glmnet(x = training_mat, y = training_set[, res_var], type.measure = 'mse', nfolds = 5, alpha = .5)
  test_mat <- model.matrix(res_formula, data = test_set)
  pred_vals <- c(predict(fit, s = c('lambda.1se'), test_mat, type = 'response'))
  to_results(res_formula, test_set, pred_vals)
}

svr_factory <- function (kernel, gamma, cost) {
  fit_custom_svr <- function (res_formula, training_set, test_set, target_dir) {
    
    # Standardization requires dividing by the standard deviation
    # of a column. If the column contains constant values it becomes
    # division by 0!
    
    res_formula <- skip_constant_variables(res_formula, training_set)
    all_vars <- all.vars(res_formula)
    res_var <- all.vars(res_formula)[[1]]
    expl_vars <- all_vars[2:length(all_vars)]
    results <- data.frame(actual = test_set[, res_var], timestamp = test_set$future_timestamp)
    
    training_set <- training_set[, c(res_var, expl_vars)] 
    test_set <- test_set[, c(res_var, expl_vars)]
    
    # Normalization and standardization of the data
    all_data <- rbind(training_set, test_set)
    means <- apply(all_data, 2, mean)
    sds <- apply(all_data, 2, sd)
    rm(all_data)
    training_set <- standardize_with(training_set, means, sds)
    test_set <- standardize_with(test_set, means, sds)
    
    all_data <- rbind(training_set, test_set)
    mins <- apply(all_data, 2, min)
    maxs <- apply(all_data, 2, max)
    rm(all_data)
    training_set <- normalize_with(training_set, mins, maxs)
    test_set <- normalize_with(test_set, mins, maxs)
    
    model <- svm(res_formula, training_set,
                 kernel = kernel, gamma = gamma, cost = cost)
    pred_vals <- predict(model, test_set)
    
    # Reverse the initial transformations
    pred_vals <- reverse_normalize_vec_with(pred_vals, mins[res_var], maxs[res_var])
    pred_vals <- reverse_standardize_vec_with(pred_vals, means[res_var], sds[res_var])
    results$predicted <- pred_vals
    
    # file_path <- file.path(target_dir, 'svr_summary.txt')
    # save_summary(model, results, file_path)
    # save_prediction_goodness(results, file_path)
    # save_prediction_comparison(results, res_var, 'svr', target_dir)
    results
  }
}

fit_svr <- function (res_formula, training_set, test_set, target_dir) {
  # Values found running best svm for winter data
  fit_svr <- svr_factory(kernel = 'radial', 
                         gamma = if (is.vector(training_set)) 1 
                         else 1 / ncol(training_set), 
                         cost = 1)
  fit_svr(res_formula, training_set, test_set, target_dir)
}

fit_best_svr <- function (res_formula, training_set, test_set, target_dir) {
  # Constant columns can't be scaled to unit variance by a SVM
  res_formula <- skip_constant_variables(res_formula, training_set)
  best_svm <- tune(svm, res_formula, data = training_set,
                   ranges = list(gamma = seq(0.001, 0.01, 0.0025), 
                                 cost = 2^(3:5),
                                 epsilon <- seq(0, 1, 0.25),
                                 kernel = c('radial')))
  plot(best_svm)
  
  model <- best_svm$best.model
  pred_vals <- predict(model, test_set)
  to_results(res_formula, test_set, pred_vals)
}

arima_factory <- function (order, seas_order, seas_period, method) {
  fit_custom_arima <- function (res_formula, training_set, test_set, target_dir) {
    # res_var - future_pm2_5
    # base_var - pm2_5
    res_var <- all.vars(res_formula)[[1]]
    base_var <- gsub('future_', '', res_var)
  
    training_ts = ts(training_set[, base_var], frequency = 24)
    test_seq <- c(training_set[, base_var], test_set[, base_var])
    last_training_idx <- length(training_ts)
    
    model <- Arima(training_ts,
                   order = order, 
                   seasonal = list(order = seas_order,
                                   period = seas_period),
                   method = method)
    pred_vals <- unlist(
      lapply(seq(last_training_idx + 1, last_training_idx + length(test_set[, 1])),
             function (i) {
               model <- Arima(ts(test_seq[1:i], frequency = 24), model = model)
               tail(forecast(model, h = 24)$mean, n = 1)
             })
      )
    
    results <- data.frame(actual = test_set[, res_var], 
               predicted = pred_vals,
               timestamp = test_set$future_timestamp)
    
    plot_path <- file.path(target_dir, paste('comparison_plot_arima.png', sep = ''))
    save_comparison_plot(results, res_var, plot_path)
    print(calc_prediction_goodness(results, 'arima'))
    
    # decomposed = stl(training_ts, s.window = 'periodic', )
    # trend <- decomposed$time.series[, 'trend']
    # seasonal <- decomposed$time.series[, 'seasonal']
    # remainder <- decomposed$time.series[, 'remainder']
    results
  }
}

fit_arima <- function (res_formula, training_set, test_set, target_dir) {
  arima_fun <- arima_factory(order = c(1, 1, 2), seas_order = c(2, 0, 0), seas_period = 24, method = 'CSS')
  arima_fun(res_formula, training_set, test_set, target_dir)
}

fit_mlp <- function (res_formula, training_set, test_set, target_dir) {
  # Standardization requires dividing by the standard deviation
  # of a column. If the column contains constant values it becomes
  # division by 0!
  res_formula <- skip_constant_variables(res_formula, training_set)
  all_vars <- all.vars(res_formula)
  res_var <- all.vars(res_formula)[[1]]
  expl_vars <- all_vars[2:length(all_vars)]
  results <- data.frame(actual = test_set[, res_var], timestamp = test_set$future_timestamp)
  
  training_set <- training_set[, c(res_var, expl_vars)] 
  test_set <- test_set[, c(res_var, expl_vars)]
  
  # First we standardize the data, then 
  # we normalize the data, using min and max
  # values of the standardized set (not the original one!)
  all_data <- rbind(training_set, test_set)
  means <- apply(all_data, 2, mean)
  sds <- apply(all_data, 2, sd)
  rm(all_data)
  training_set <- standardize_with(training_set, means, sds)
  test_set <- standardize_with(test_set, means, sds)
  
  all_data <- rbind(training_set, test_set)
  mins <- apply(all_data, 2, min)
  maxs <- apply(all_data, 2, max)
  rm(all_data)
  training_set <- normalize_with(training_set, mins, maxs)
  test_set <- normalize_with(test_set, mins, maxs)
  
  nn <- neuralnet(res_formula,
                  data = training_set,
                  hidden = c(8, 5),
                  stepmax = 1e+04,
                  threshold = 0.5,
                  linear.output = TRUE)
  # plot(nn)
  pred_vals <- c(compute(nn, test_set[, expl_vars])$net.result)
  
  # Reverse the initial transformations
  pred_vals <- reverse_normalize_vec_with(pred_vals, mins[res_var], maxs[res_var])
  pred_vals <- reverse_standardize_vec_with(pred_vals, means[res_var], sds[res_var])
  
  results$predicted <- pred_vals
  results
}

fit_lstm <- function (res_formula, training_set, test_set, target_dir) {
  res_var <- all.vars(res_formula)[[1]]
  vars <- colnames(training_set)
  vars <- vars[startsWith(vars, 'pm2_5')]
  vars <- c(vars, res_var) 
  batch_size <- length(training_set[, 1])
  cols_count <- length(vars)
  
  training_3d <- array(apply(training_set[1:10, vars], 1, function (row) {
      a <- array(
        lapply(row, function (x) { array(x, dim = c(1)) })
        , dim = c(cols_count, 1)
      )
    }), dim = c(batch_size, cols_count, 1))
  print(class(training_3d))
  
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

