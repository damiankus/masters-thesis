wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
source("preprocess.R")
setwd(wd)

packages <- c("e1071", "neuralnet", "glmnet")
import(packages)

get_forecast <- function(fit_model, res_var, expl_vars, training_set, test_set) {
  handle_error_and_get_na_predictions <- function(message) {
    print(message)

    # cat displays new lines properly but does not add one at the end
    cat(paste(deparse(fit_model), collapse = "\n"))
    cat("\n")
    rep(NA, nrow(test_set))
  }

  training_set_only_used_vars <- training_set[, c(res_var, expl_vars)]
  test_set_only_used_vars <- test_set[, c(res_var, expl_vars)]
  predicted <- tryCatch({
    fit_model(
      res_var = res_var,
      expl_vars = expl_vars,
      training_set = training_set_only_used_vars,
      test_set = test_set_only_used_vars
    )
  },
  warning = handle_error_and_get_na_predictions,
  error = handle_error_and_get_na_predictions
  )
  data.frame(
    measurement_time = test_set$future_measurement_time,
    actual = test_set[, res_var],
    predicted = predicted,
    season = test_set$season
  )
}

get_formula <- function(res_var, expl_vars) {
  as.formula(paste(
    res_var, "~", paste(expl_vars, collapse = "+"),
    sep = " "
  ))
}

# Predicted value is the last registered value
fit_persistence <- function(res_var, expl_vars, training_set, test_set) {
  base_var <- gsub("future_", "", res_var)
  test_set[, base_var]
}

fit_mlr <- function(res_var, expl_vars, training_set, test_set) {
  model <- lm(get_formula(res_var, expl_vars), data = training_set)
  predict(model, test_set)
}

fit_log_mlr <- function(res_var, expl_vars, training_set, test_set) {
  res_formula <- as.formula(paste("log(", res_var, ") ~", paste(expl_vars, collapse = "+"), sep = ""))
  model <- lm(res_formula, data = training_set)
  predict(model, test_set)
}

fit_lasso_mlr <- function(res_var, expl_vars, training_set, test_set) {
  res_formula <- get_all_vars(res_var, expl_vars)
  training_mat <- model.matrix(res_formula, data = training_set)
  fit <- cv.glmnet(x = training_mat, y = training_set[, res_var], alpha = 1)
  test_mat <- model.matrix(res_formula, data = test_set)
  c(predict(fit, s = "lambda.1se", newx = test_mat, type = "response"))
}

create_neural_network <- function(hidden, threshold, stepmax = 1e+06, act_fun = "tanh", lifesign = "full") {
  fit_neural_network <- function(res_var, expl_vars, training_set, test_set) {
    print(paste(
      "Fitting a neural network (",
      "hidden layers:", paste(hidden, collapse = ", "),
      "threshold:", threshold,
      "stepmax:", stepmax,
      "activation function:", act_fun,
      ")"
    ))

    # Means and standard deviations of can be calculated
    # only based on historical data, without the futurevalues,
    # which are yet to be measured
    means <- apply(training_set, 2, mean, na.rm = TRUE)
    sds <- apply(training_set, 2, sd, na.rm = TRUE)

    std_training_set <- standardize_with(training_set, means = means, sds = sds)
    std_test_set <- standardize_with(test_set, means = means, sds = sds)

    res_formula <- get_formula(res_var, expl_vars)
    nn <- neuralnet(res_formula,
      data = std_training_set,
      hidden = hidden,
      stepmax = stepmax,
      threshold = threshold,
      act.fct = act_fun,
      linear.output = TRUE,
      lifesign = lifesign
    )
    predicted <- c(compute(nn, std_test_set[, expl_vars])$net.result)

    # Reverse the initial transformations
    reverse_standardize_vec_with(predicted, means[[res_var]], sds[[res_var]])
  }
}

create_svr <- function(kernel, gamma, epsilon, cost) {
  fit_custom_svr <- function(res_var, expl_vars, training_set, test_set) {
    print(paste(
      "Fitting an SVR (kernel:", kernel,
      "gamma:", gamma,
      "epsilon:", epsilon,
      "cost:", cost,
      ")"
    ))

    # Standardization of the data
    all_data <- rbind(training_set, test_set)

    means <- apply(training_set, 2, mean, na.rm = TRUE)
    sds <- apply(training_set, 2, sd, na.rm = TRUE)

    rm(all_data)
    std_training_set <- standardize_with(training_set, means = means, sds = sds)
    std_test_set <- standardize_with(test_set, means = means, sds = sds)

    res_formula <- get_formula(res_var, expl_vars)
    model <- svm(
      formula = res_formula,
      data = std_training_set,
      kernel = kernel,
      gamma = gamma,
      cost = cost,
      type = "eps-regression",
      cachesize = 1024
    )
    predicted <- predict(model, std_test_set)

    # Reverse the initial transformations
    reverse_standardize_vec_with(predicted, means[[res_var]], sds[[res_var]])
  }
}

# Min and max values for SVR hyperparameters were taken from:
# A Practical Guide to Support Vector Classification
# Chih-Wei Hsu, Chih-Chung Chang, and Chih-Jen Lin
# https://www.csie.ntu.edu.tw/~cjlin/papers/guide/guide.pdf
generate_random_svr_power_grid <- function(model_count,
                                           gamma_exp_bounds,
                                           epsilon_exp_bounds,
                                           cost_exp_bounds,
                                           exp_base = 2,
                                           exp_step = 2) {
  gamma_exponents <- seq(gamma_exp_bounds[[1]], gamma_exp_bounds[[2]], exp_step)
  gammas <- sapply(gamma_exponents, function(exponent) {
    exp_base^exponent
  })

  epsilon_exponents <- seq(epsilon_exp_bounds[[1]], epsilon_exp_bounds[[2]], exp_step)
  epsilons <- sapply(epsilon_exponents, function(exponent) {
    exp_base^exponent
  })

  cost_exponents <- seq(cost_exp_bounds[[1]], cost_exp_bounds[[2]], exp_step)
  costs <- sapply(cost_exponents, function(exponent) {
    exp_base^exponent
  })

  params <- expand.grid(gammas, epsilons, costs)
  colnames(params) <- c("gamma", "epsilon", "cost")
  params[sample(nrow(params), model_count), ]
}


# Observations:
# * gamma greater or equal to 0.25 makes SVM not learn
generate_random_pow_svrs <- function(model_count,
                                     gamma_exp_bounds,
                                     epsilon_exp_bounds,
                                     cost_exp_bounds,
                                     exp_base = 2,
                                     exp_step = 2,
                                     kernel = "radial") {
  param_sets <- generate_random_svr_power_grid(
    model_count = model_count,
    exp_base = exp_base,
    exp_step = exp_step,
    gamma_exp_bounds = gamma_exp_bounds,
    epsilon_exp_bounds = epsilon_exp_bounds,
    cost_exp_bounds = cost_exp_bounds
  )
  svrs <- apply(param_sets, 1, function(params) {
    list(
      name = get_svr_name(
        kernel = kernel,
        gamma = params[["gamma"]],
        epsilon = params[["epsilon"]],
        cost = params[["cost"]]
      ),
      fit = create_svr(
        kernel = kernel,
        gamma = params[["gamma"]],
        epsilon = params[["epsilon"]],
        cost = params[["cost"]]
      )
    )
  })
}

get_neural_network_name <- function(hidden, threshold, stepmax, act_fun) {
  paste("neural_network",
    "__hidden_", hidden,
    "__threshold_", threshold,
    "__stepmax_", stepmax,
    "__actfun_", act_fun,
    sep = ""
  )
}

get_svr_name <- function(kernel, gamma, epsilon, cost, signif_digits = 3) {
  paste("svr",
    "__kernel_", kernel,
    "__gamma_", signif(gamma, signif_digits),
    "__epsilon_", signif(epsilon, signif_digits),
    "__cost_", signif(cost, signif_digits),
    sep = ""
  )
}
