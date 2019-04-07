wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
source("preprocess.R")
setwd(wd)

packages <- c("e1071", "neuralnet", "glmnet") # c('caTools', 'glmnet', 'car', 'e1071', 'forecast', 'neuralnet')
import(packages)

get_forecast <- function(fit_model, res_var, expl_vars, training_set, test_set) {
  handle_error_and_get_na_predictions <- function(message) {
    print(message)
    # cat displays new lines properly but does not add one at the end
    cat(paste(deparse(fit_model), collapse = "\n"))
    cat("\n")
    rep(NA, nrow(test_set))
  }

  predicted <- tryCatch({
    fit_model(res_var, expl_vars, training_set, test_set)
  },
  warning = handle_error_and_get_na_predictions,
  error = handle_error_and_get_na_predictions
  )
  data.frame(
    actual = test_set[, res_var],
    predicted = predicted,
    measurement_time = test_set$future_measurement_time
  )
}

get_formula <- function(res_var, expl_vars) {
  as.formula(paste(
    res_var, "~", paste(explanatory_vars, collapse = "+"),
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

create_neural_network <- function(hidden, threshold, stepmax = 1e+06, lifesign = "full") {
  fit_neural_network <- function(res_var, expl_vars, training_set, test_set) {
    # Standardization requires dividing by the standard deviation
    # of a column. If the column contains constant values it becomes
    # division by 0!
    res_formula <- skip_constant_variables(get_formula(res_var, expl_vars), training_set)

    all_data <- rbind(training_set, test_set)
    means <- apply(all_data, 2, mean, na.rm = TRUE)
    sds <- apply(all_data, 2, sd, na.rm = TRUE)
    rm(all_data)
    std_training_set <- standardize_with(training_set, means = means, sds = sds)
    std_test_set <- standardize_with(test_set, means = means, sds = sds)

    nn <- neuralnet(res_formula,
      data = std_training_set,
      hidden = hidden,
      stepmax = stepmax,
      threshold = threshold,
      linear.output = TRUE,
      lifesign = lifesign
    )
    predicted <- c(compute(nn, std_test_set[, expl_vars])$net.result)

    # Reverse the initial transformations
    reverse_standardize_with(predicted, means[res_var], sds[res_var])
  }
}

create_svr <- function(kernel, gamma, epsilon, cost) {
  fit_custom_svr <- function(res_var, expl_vars, training_set, test_set) {

    # Standardization requires dividing by the standard deviation
    # of a column. If the column contains constant values it becomes
    # division by 0!
    res_formula <- skip_constant_variables(get_formula(res_var, expl_vars), training_set)

    # Normalization of the data
    all_data <- rbind(training_set, test_set)
    means <- apply(all_data, 2, mean, na.rm = TRUE)
    sds <- apply(all_data, 2, sd, na.rm = TRUE)
    rm(all_data)
    std_training_set <- standardize_with(training_set, means = means, sds = sds)
    std_test_set <- standardize_with(test_set, means = means, sds = sds)

    model <- svm(res_formula, std_training_set,
      kernel = kernel, gamma = gamma, cost = cost,
      cachesize = 2048
    )
    predicted <- predict(model, std_test_set)

    # Reverse the initial transformations
    reverse_standardize_with(predicted, means[res_var], sds[res_var])
  }
}

# Min and max values for SVR hyperparameters were taken from:
# A Practical Guide to Support Vector Classification
# Chih-Wei Hsu, Chih-Chung Chang, and Chih-Jen Lin
# https://www.csie.ntu.edu.tw/~cjlin/papers/guide/guide.pdf
generate_random_svr_power_grid <- function(model_count = 5,
                                           base = 2,
                                           gamma_pow_bound = c(-12, -2),
                                           epsilon_pow_bound = c(-5, -1),
                                           cost_pow_bound = c(-2, 10)) {
  gammas <- seq(gamma_pow_bound[[1]], gamma_pow_bound[[2]], base)
  gammas <- sapply(gammas, function(exponent) {
    base^exponent
  })

  epsilons <- seq(epsilon_pow_bound[[1]], epsilon_pow_bound[[2]], base)
  epsilons <- sapply(epsilons, function(exponent) {
    base^exponent
  })

  costs <- seq(cost_pow_bound[[1]], cost_pow_bound[[2]], base)
  costs <- sapply(costs, function(exponent) {
    base^exponent
  })

  params <- expand.grid(gammas, epsilons, costs)
  colnames(params) <- c("gamma", "epsilon", "cost")
  params[sample(nrow(params), model_count), ]
}


# Observations:
# * gamma greater or equal to 0.25 makes SVM not learn
generate_random_pow_svrs <- function(
                                     model_count = 5,
                                     base = 2,
                                     kernel = "radial",
                                     gamma_pow_bound = c(-12, -4),
                                     epsilon_pow_bound = c(-5, 1),
                                     cost_pow_bound = c(-2, 10)) {
  params <- generate_random_svr_power_grid(
    model_count,
    base,
    gamma_pow_bound,
    epsilon_pow_bound,
    cost_pow_bound
  )
  svrs <- apply(params, 1, function(p) {
    svr_factory(
      kernel = kernel,
      gamma = p$gamma,
      epsilon = p$psilon,
      cost = p$cost
    )
  })

  lapply(svrs, function(svr) {
    list(
      name = get_svr_name(
        kernel = kernel,
        gamma = p$gamma,
        epsilon = p$psilon,
        cost = p$cost
      ),
      model = svr
    )
  })
}

get_neural_network_name <- function(hidden, threshold, stepmax) {
  paste("neural_network",
    "__hidden_", hidden,
    "__threshold_", threshold,
    "__stepmax_", stepmax,
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
