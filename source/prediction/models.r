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
  fit <- cv.glmnet(x = training_mat, y = training_set[, res_var], alpha = 1)
  test_mat <- model.matrix(res_formula, data = test_set)
  pred_vals <- c(predict(fit, s = 'lambda.1se', newx = test_mat, type = 'response'))
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
    results
  }
}

fit_arima <- function (res_formula, training_set, test_set, target_dir) {
  arima_fun <- arima_factory(order = c(1, 1, 2), seas_order = c(2, 0, 0), seas_period = 24, method = 'CSS')
  arima_fun(res_formula, training_set, test_set, target_dir)
}

mlp_factory <- function (hidden, threshold, stepmax = 1e+05, ensemble_size = 5) {
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
    
    # Create an ensemble of neural networks
    # and get the final prediction by calculating
    # the average values
    
    nns <- lapply(seq(ensemble_size), function (i) {
      neuralnet(res_formula,
                data = training_set,
                hidden = hidden,
                stepmax = stepmax,
                threshold = threshold,
                linear.output = TRUE)
    })
    pred_vals_list <- lapply (nns, function (nn) {
      c(compute(nn, test_set[, expl_vars])$net.result)
    })
    pred_vals <- apply(do.call(cbind, pred_vals_list), 1, mean)
    
    # Reverse the initial transformations
    pred_vals <- reverse_normalize_vec_with(pred_vals, mins[res_var], maxs[res_var])
    pred_vals <- reverse_standardize_vec_with(pred_vals, means[res_var], sds[res_var])
    
    results$predicted <- pred_vals
    results
  }
}

# @archs - a vector vector containing numbers of neurons in hidden layers
# @deltas - a vector of values to add / subtract from the original numbers
# of neurons in @hidden (lengths must be the same!)
# @thresholds - a vector of thresholds used as stop conditions in neuralnet package
generate_mlps <- function (arch, deltas, thresholds) {
  layer_sizes <- lapply(seq(length(arch)), function (i) {
    c(arch[i] - deltas[i], arch[i] + deltas[i])
  })
  archs <- expand.grid(layer_sizes)
  
  # Add the original architecture
  archs <- rbind(archs, arch)
  unlist(apply(archs, 1, function (arch) {
    same_arch <- lapply(thresholds, function (th) {
      mlp_factory(hidden = arch, threshold = th)
    })
    names(same_arch) <- sapply(thresholds, function (th) {
      paste('mlp', paste(arch, collapse = '_'), 'th', th, sep = '_')
    })
    same_arch
  }))
}

generate_svrs <- function (gammas, epsilons, costs) {
  
}

