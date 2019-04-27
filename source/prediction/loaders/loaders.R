loaders_wd <- getwd()
setwd("../../common")
source("utils.R")
setwd(loaders_wd)

setwd("../models")
source("models.R")
setwd(loaders_wd)

setwd("../data-splitters")
source("data_splitters.R")
setwd(loaders_wd)

packages <- c("yaml")
import(packages)


load_yaml_configs <- function(config_path) {
  configs <- read_yaml(file = config_path)

  lapply(configs, function(config) {
    data_file <- if (is.null(config$data_file)) {
      "data/time_series.Rda"
    } else {
      config$data_file
    }

    output_dir <- if (is.null(config$output_dir)) {
      "results"
    } else {
      config$output_dir
    }

    res_var <- if (is.null(config$res_var)) {
      "future_pm2_5"
    } else {
      config$res_var
    }

    stations <- if (is.null(config$stations)) {
      sort(unique(series$station_id))
    } else {
      config$stations
    }

    repetitions <- if (is.null(config$repetitions)) {
      1
    } else {
      config$repetitions
    }

    load(file = data_file)
    all_vars <- colnames(series)
    non_expl_vars <- c(
      res_var,
      "station_id",
      "measurement_time",
      "future_measurement_time",
      "season",
      "year"
    )
    expl_vars <- all_vars[!(all_vars %in% non_expl_vars)]

    split_type <- if (is.null(config$split_type)) {
      "year"
    } else {
      config$split_type
    }

    data_splits <- split_data_based_on_type(
      split_type = split_type,
      df = series,
      test_years = config$test_years
    )

    models <- get_models(config)
    model_split_ids <- lapply(models, function(model) {
      model$split_id
    })
    datasets_with_models <- lapply(data_splits, function(data_split) {
      split_id <- data_split$id
      list(
        id = split_id,
        data_split = data_split,
        models = models[model_split_ids == split_id]
      )
    })

    list(
      res_var = res_var,
      expl_vars = expl_vars,
      stations = stations,
      repetitions = repetitions,
      split_type = split_type,
      datasets_with_models = datasets_with_models,
      output_dir = output_dir
    )
  })
}

get_models <- function(config) {
  grouped_models <- lapply(config$models, function(spec) {
    switch(spec$type,
      regression = get_regression_models(spec),
      neural = get_neural_networks(spec),
      svr = get_svrs(spec)
    )
  })
  models <- do.call(c, grouped_models)

  lapply(models, function(model) {
    model$split_id <- if (is.null(model$config$split_id)) {
      1
    } else {
      model$config$split_id
    }
    model
  })
}

get_regression_models <- function(spec) {
  list(list(
    name = "regression",
    fit = fit_mlr,
    config = spec
  ))
}

get_svrs <- function(spec, parent_spec = NULL) {
  if ("random" %in% names(spec) && spec$random) {
    generate_random_pow_svrs(
      model_count = spec$model_count,
      kernel = spec$kernel,
      exp_base = spec$exp_base,
      exp_step = spec$exp_step,
      gamma_exp_bounds = c(spec$gamma$min, spec$gamma$max),
      epsilon_exp_bounds = c(spec$epsilon$min, spec$epsilon$max),
      cost_exp_bounds = c(spec$cost$min, spec$cost$max)
    )
  } else {
    raw_spec <- get_extended_spec(
      c("kernel", "gamma", "epsilon", "cost"),
      spec,
      parent_spec
    )
    extended_spec <- parse_numeric_params(c("gamma", "epsilon", "cost"), raw_spec)

    if ("children" %in% names(spec)) {
      do.call(c, lapply(spec$children, function(child_spec) {
        get_svrs(child_spec, extended_spec)
      }))
    } else {
      list(list(
        name = get_svr_name(
          kernel = extended_spec$kernel,
          gamma = extended_spec$gamma,
          epsilon = extended_spec$epsilon,
          cost = extended_spec$cost
        ),
        fit = create_svr(
          kernel = extended_spec$kernel,
          gamma = extended_spec$gamma,
          epsilon = extended_spec$epsilon,
          cost = extended_spec$cost
        ),
        config = extended_spec
      ))
    }
  }
}

get_neural_networks <- function(spec, parent_spec = NULL) {
  raw_spec <- get_extended_spec(
    c("hidden", "threshold", "stepmax", "lifesign", "act_fun"),
    spec,
    parent_spec
  )
  extended_spec <- parse_numeric_params(c("threshold", "stepmax"), raw_spec)

  if ("children" %in% names(spec)) {
    do.call(c, lapply(spec$children, function(child_spec) {
      get_neural_networks(child_spec, extended_spec)
    }))
  } else {
    
    extended_spec$lifesign <- if (is.null(extended_spec$lifesign)) {
      "full"
    } else {
      extended_spec$lifesign
    }
    
    extended_spec$act_fun <- if (is.null(extended_spec$act_fun)) {
      "tanh"
    } else {
      extended_spec$act_fun
    }
    
    neural_network <- create_neural_network(
      hidden = parse_network_layer_spec(extended_spec$hidden),
      threshold = extended_spec$threshold,
      stepmax = extended_spec$stepmax,
      act_fun = extended_spec$act_fun,
      lifesign = extended_spec$lifesign
    )

    list(list(
      name = get_neural_network_name(
        hidden = extended_spec$hidden,
        threshold = extended_spec$threshold,
        stepmax = extended_spec$stepmax,
        act_fun = extended_spec$act_fun
      ),
      fit = neural_network,
      config = extended_spec
    ))
  }
}

parse_network_layer_spec <- function(layer_spec) {
  as.numeric(strsplit(layer_spec, split = "-")[[1]])
}

get_extended_spec <- function(params, spec, parent_spec) {
  common_params <- c("split_id")
  all_params <- c(common_params, params)
  if (is.null(parent_spec)) {
    spec
  } else {
    merged_spec <- lapply(all_params, function(param) {
      if (is.null(spec[[param]])) {
        parent_spec[[param]]
      } else {
        spec[[param]]
      }
    })
    names(merged_spec) <- all_params
    merged_spec
  }
}

parse_numeric_params <- function(parsed_params, spec) {
  other_params <- setdiff(names(spec), parsed_params)

  numeric_values <- lapply(parsed_params, function(param) {
    as.numeric(spec[[param]])
  })
  other_values <- lapply(other_params, function(param) {
    spec[[param]]
  })
  parsed <- c(numeric_values, other_values)
  names(parsed) <- c(parsed_params, other_params)
  parsed
}
