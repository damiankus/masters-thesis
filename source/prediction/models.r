wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c('e1071', 'neuralnet') #c('caTools', 'glmnet', 'car', 'e1071', 'forecast', 'neuralnet')
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

mlp_factory <- function (hidden, threshold, stepmax = 1e+06, ensemble_size = 3, lifesign = 'minimal') {
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
                linear.output = TRUE, 
                lifesign = lifesign)
    })
    pred_vals_list <- lapply (nns, function (nn) {
      c(compute(nn, test_set[, expl_vars])$net.result)
    })
    pred_vals <- apply(do.call(cbind, pred_vals_list), 1, mean)
    
    # Reverse the initial transformations
    pred_vals <- reverse_normalize_vec_with(pred_vals, mins[res_var], maxs[res_var])
    results$predicted <- pred_vals
    results
  }
}

# @archs - a vector vector containing numbers of neurons in hidden layers
# @deltas - a vector of values to add / subtract from the original numbers
# of neurons in @hidden (lengths must be the same!)
# @thresholds - a vector of thresholds used as stop conditions in neuralnet package
generate_mlps <- function (arch, deltas, thresholds) {
  archs <- data.frame(t(arch))
  colnames(archs) <- sapply(seq(1, length(arch)), function (i) { paste('layer', i, sep = '_')  })
  
  if (sum(deltas) != 0) {
    layer_sizes <- lapply(seq(length(arch)), function (i) {
      c(arch[i] - deltas[i], arch[i], arch[i] + deltas[i])
    })
    # Add the original architecture
    archs <- expand.grid(layer_sizes)
    colnames(archs) <- sapply(seq(1, length(arch)), function (i) { paste('layer', i, sep = '_')  })
  }
  
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

svr_factory <- function (kernel, gamma, epsilon, cost) {
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
    
    # Normalization of the data
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
    results$predicted <- pred_vals
    results
  }
}

fit_svr <- function (res_formula, training_set, test_set, target_dir) {
  # Values found running best svm for winter data
  print(1 / ncol(training_set))
  default_svr <- svr_factory(kernel = 'radial', 
                             gamma = 1 / ncol(training_set), 
                             epsilon = 0.1,
                             cost = 1)
  default_svr(res_formula, training_set, test_set, target_dir)
}


# Min and max values for SVR hyperparameters were taken from:
# A Practical Guide to Support Vector Classification
# Chih-Wei Hsu, Chih-Chung Chang, and Chih-Jen Lin
# https://www.csie.ntu.edu.tw/~cjlin/papers/guide/guide.pdf
generate_random_svr_power_grid <- function (n_models = 5, 
                                            base = 2,
                                            gamma_pow_bound = c(-10, 3),
                                            epsilon_pow_bound = c(-4, 0),
                                            cost_pow_bound = c(-2, 10)) {
  gammas <- seq(gamma_pow_bound[[1]], gamma_pow_bound[[2]], base)
  gammas <- sapply(gammas, function (exponent) { base ^ exponent })
  
  epsilons <- seq(epsilon_pow_bound[[1]], epsilon_pow_bound[[2]], base)
  epsilons <- sapply(epsilons, function (exponent) { base ^ exponent })
  
  costs <- seq(cost_pow_bound[[1]], cost_pow_bound[[2]], base)
  costs <- sapply(costs, function (exponent) { base ^ exponent })
  
  params <- expand.grid(gammas, epsilons, costs)
  colnames(params) <- c('gamma', 'epsilon', 'cost')
  params[sample(nrow(params), n_models), ]
}


# Default values:
# gamma = 1 / ncol(training_set) ~ 0.027 for 44 inpur variables
# epsilon = 0.1
# cost = 1
generate_random_svr_pow_params <- function (n_models = 5, 
                                        gamma_bounds = c(0.001, 1),
                                        epsilon_bounds = c(0.05, 0.15),
                                        cost_bounds = c(0.5, 1.5)) {
  data.frame(
    gamma = runif(n_models, gamma_bounds[[1]], gamma_bounds[[2]]),
    epsilon = runif(n_models, epsilon_bounds[[1]], epsilon_bounds[[2]]),
    cost = runif(n_models, cost_bounds[[1]], cost_bounds[[2]])
  )
}

generate_random_pow_svrs <- function (n_models = 5,
                                    base = 2,
                                    gamma_pow_bound = c(-10, 3),
                                    epsilon_pow_bound = c(-4, 0),
                                    cost_pow_bound = c(-2, 10)) {
  params <- generate_random_svr_power_grid(n_models,
                                           base,
                                           gamma_pow_bound,
                                           epsilon_pow_bound,
                                           cost_pow_bound)
  svrs <- apply(params, 1, function (p) {
    svr_factory(kernel = 'radial', 
                gamma = p[['gamma']],
                epsilon = p[['epsilon']],
                cost = p[['cost']])
  })
  names(svrs) <- apply(params, 1, function (p) {
    paste('svr_gam', signif(p[['gamma']], 3),
          '_eps', signif(p[['epsilon']], 3),
          '_c', signif(p[['cost']], 3), sep = '')
  })
  svrs
}

