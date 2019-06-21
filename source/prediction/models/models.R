wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
source("plotting.R")
source("preprocess.R")
setwd(wd)

packages <- c("glmnet", "keras", "e1071", "ggplot2")
import(packages)

get_forecast <- function(model, res_var, expl_vars, training_set, test_set) {
  handle_error_and_get_na_predictions <- function(message) {
    print(message)

    # cat displays new lines properly but does not add one at the end
    cat(paste(deparse(model$fit), collapse = "\n"))
    cat("\n")
    rep(NA, nrow(test_set))
  }

  predicted <- tryCatch({
    print(get_model_description(model))
    model$fit(
      res_var = res_var,
      expl_vars = expl_vars,
      training_set = training_set,
      test_set = test_set,
      config = model
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

get_model_description <- function(model) {
  raw_model_type <- strsplit(model$name, "__")[[1]][[1]]
  model_type <- gsub("_", " ", x = raw_model_type)
  param_names <- lapply(names(model$spec), function(name) {
    gsub("_", " ", name)
  })
  name_val_pairs <- lapply(seq_along(param_names), function(idx) {
    paste(param_names[[idx]], model$spec[[idx]], sep = ": ")
  })
  paste(model_type, " (", paste(name_val_pairs, collapse = ", "), ")", sep = "")
}

get_formula <- function(res_var, expl_vars) {
  as.formula(paste(
    res_var, "~", paste(expl_vars, collapse = "+"),
    sep = " "
  ))
}

# Predicted value is the last registered value
fit_persistence <- function(res_var, expl_vars, training_set, test_set, ...) {
  base_var <- gsub("future_", "", res_var)
  test_set[, base_var]
}

fit_mlr <- function(res_var, expl_vars, training_set, test_set, ...) {
  model <- lm(get_formula(res_var, expl_vars), data = training_set)
  predict(model, test_set)
}

fit_log_mlr <- function(res_var, expl_vars, training_set, test_set, ...) {
  res_formula <- as.formula(paste("log(", res_var, ") ~", paste(expl_vars, collapse = "+"), sep = ""))
  model <- lm(res_formula, data = training_set)
  predict(model, test_set)
}

fit_lasso_mlr <- function(res_var, expl_vars, training_set, test_set, ...) {
  res_formula <- get_all_vars(res_var, expl_vars)
  training_mat <- model.matrix(res_formula, data = training_set)
  fit <- cv.glmnet(x = training_mat, y = training_set[, res_var], alpha = 1)
  test_mat <- model.matrix(res_formula, data = test_set)
  c(predict(fit, s = "lambda.1se", newx = test_mat, type = "response"))
}

create_neural_network <- function(hidden, activation, epochs, min_delta, patience_ratio, batch_size, learning_rate, epsilon, l2, ...) {
  fit_neural_network <- function(res_var, expl_vars, training_set, test_set, config, ...) {
    training_years <- sort(unique(training_set$year))
    validation_year <- tail(training_years, n = 1)
    which_training <- training_set$year < validation_year
    which_validation <- training_set$year == validation_year

    used_vars <- c(res_var, expl_vars)
    actual_training_set <- training_set[which_training, used_vars]
    actual_validation_set <- training_set[which_validation, used_vars]
    actual_test_set <- test_set[, used_vars]

    # Means and standard deviations of can be calculated
    # only based on historical data, without the futurevalues,
    # which are yet to be measured
    means <- apply(actual_training_set, 2, mean, na.rm = TRUE)
    sds <- apply(actual_training_set, 2, sd, na.rm = TRUE)

    std_training_set <- standardize_with(actual_training_set, means = means, sds = sds)
    std_validation_set <- standardize_with(actual_validation_set, means = means, sds = sds)
    std_test_set <- standardize_with(actual_test_set, means = means, sds = sds)

    base_output_path <- file.path(config$result_dir, config$name)
    best_model_path <- paste(base_output_path, ".hdf5", sep = "")

    
    # WARNING:
    # During some experiments I've encountered the following error
    # OSError: Unable to create file (Unable to lock file, errno = 11, error message = 'resource temporarily unavailable')
    # It is raised if the callback_model_checkpoint function is executed in an concurrent environment
    # As of 2019-06-21 I don't know a reliable way of avoiding it without decreasing the number of threads being used.
    # Maybe this discussion: https://github.com/keras-team/keras/issues/11101 will eventually contain a solution
    
    callbacks <- list(
      callback_progbar_logger(),
      callback_early_stopping(
        monitor = "val_loss",
        min_delta = min_delta,
        patience = floor(epochs * patience_ratio),
        verbose = 1
      ),
      callback_model_checkpoint(
        filepath = best_model_path,
        monitor = "val_loss",
        mode = "min",
        save_best_only = TRUE,
        verbose = 1
      )
    )

    model <- keras_model_sequential()
    model %>%
      add_layers(
        hidden = hidden,
        activation = activation,
        input_shape = length(expl_vars),
        l2 = l2
      ) %>%
      compile(
        loss = "mean_squared_error",
        optimizer = optimizer_adam(lr = learning_rate, epsilon = epsilon),
        metrics = c("mae")
      )

    summary(model)

    history <- model %>% fit(
      x = data.matrix(std_training_set[, expl_vars]),
      y = std_training_set[, res_var],
      epochs = epochs,
      batch_size = batch_size,
      callbacks = callbacks,
      validation_data = list(
        data.matrix(std_validation_set[, expl_vars]),
        std_validation_set[, res_var]
      ),
      verbose = 0
    )

    # Save training history to a CSV file
    write.csv(history, file = paste(base_output_path, "_history.csv", sep = ""))

    best_model <- load_model_hdf5(filepath = best_model_path)
    std_predicted <- predict(best_model, as.matrix(std_test_set[, expl_vars]))
    reverse_standardize_vec_with(std_predicted, means[[res_var]], sds[[res_var]])
  }
}

add_layers <- function(model, hidden, activation, input_shape, l2) {
  parsed_hidden <- if (is.numeric(hidden)) {
    hidden
  } else {
    as.numeric(strsplit(hidden, split = "-")[[1]])
  }

  if (!length(parsed_hidden)) {
    model
  } else {
    model %>% layer_dense(input_shape = input_shape, units = parsed_hidden[[1]], activation = activation, kernel_regularizer = regularizer_l2(l = l2))
    for (unit_count in parsed_hidden[-1]) {
      model %>% layer_dense(units = unit_count, activation = activation, kernel_regularizer = regularizer_l2(l = l2))
    }
    model %>% layer_dense(units = 1, activation = "linear")
    model
  }
}

create_svr <- function(kernel, gamma, epsilon, cost, ...) {
  fit_custom_svr <- function(res_var, expl_vars, training_set, test_set, config, ...) {
    used_vars <- c(res_var, expl_vars)
    actual_training_set <- training_set[, used_vars]
    actual_test_set <- test_set[, used_vars]

    # Standardization of the data
    means <- apply(actual_training_set, 2, mean, na.rm = TRUE)
    sds <- apply(actual_training_set, 2, sd, na.rm = TRUE)

    std_training_set <- standardize_with(actual_training_set, means = means, sds = sds)
    std_test_set <- standardize_with(actual_test_set, means = means, sds = sds)

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

    # Reverse the initial transformations
    predicted <- predict(model, std_test_set)
    reverse_standardize_vec_with(predicted, means[[res_var]], sds[[res_var]])
  }
}

get_model_name <- function(model_type, call_instance, separator = "__", assignment_symbol = "=") {
  # get argument names and values as a named list
  args <- as.list(call_instance)[-1]
  arg_names <- names(args)
  parts <- lapply(seq_along(args), function(idx) {
    paste(arg_names[[idx]], args[[idx]], sep = assignment_symbol)
  })
  paste(c(model_type, parts), collapse = separator)
}

get_neural_network_name <- function(hidden, activation, epochs, min_delta, patience_ratio, batch_size, learning_rate, epsilon, ...) {
  get_model_name("neural_network", match.call())
}

get_svr_name <- function(kernel, gamma, epsilon, cost, ...) {
  get_model_name("svr", match.call())
}
