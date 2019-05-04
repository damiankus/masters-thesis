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

  default_config <- list(
    data_file = "data/time_series.Rda",
    output_dir = "results",
    res_var = "future_pm2_5",
    repetitions = 1,
    split_type = "year"
  )
  default_param_names <- names(default_config)

  lapply(configs, function(raw_config) {

    # Add missing parameters by copying them
    # from the default config
    config <- get_extended_spec(raw_config, default_config)

    # It is assumed the data frame containing
    # training data was saved as /
    # is loaded to a variable called 'series'
    load(file = config$data_file)
    all_vars <- colnames(series)
    non_expl_vars <- c(
      config$res_var,
      "station_id",
      "measurement_time",
      "future_measurement_time",
      "season",
      "year"
    )
    expl_vars <- setdiff(all_vars, non_expl_vars)

    data_splits <- split_data_based_on_type(
      split_type = config$split_type,
      df = series,
      test_years = config$test_years
    )

    models <- get_models(config)
    model_split_ids <- lapply(models, function(model) {
      model$spec$split_id
    })

    # Models without a specified split ID
    # are assumed to be trained, using
    # every available data split
    which_common <- unlist(lapply(model_split_ids, is.null))
    common_models <- models[which_common]
    models_for_specific_splits <- models[!which_common]
    defined_model_split_ids <- model_split_ids[!which_common]

    datasets_with_models <- lapply(data_splits, function(data_split) {
      split_id <- data_split$id
      which_models <- defined_model_split_ids == split_id
      models_for_split <- c(common_models, models_for_specific_splits[which_models])
      list(
        id = split_id,
        data_split = data_split,
        models = models_for_split,
        parallelizable = are_models_parallelizable(models_for_split)
      )
    })

    c(config, list(
      expl_vars = expl_vars,
      stations = if (is.na(config$stations)) sort(unique(series$station_id)) else config$stations,
      datasets_with_models = datasets_with_models
    ))
  })
}

are_models_parallelizable <- function(models) {
  model_names <- sapply(models, function(model) {
    model$name
  })

  # Neural networks are trained, using all available cores
  # so other models need to wait
  !any(grepl("neural", model_names))
}

get_models <- function(config) {
  grouped_models <- lapply(config$models, function(spec) {
    switch(spec$type,
      regression = get_regression_models(spec),
      neural = get_neural_networks(spec),
      svr = get_svrs(spec)
    )
  })
  do.call(c, grouped_models)
}

get_regression_models <- function(spec) {
  list(list(
    name = "regression",
    fit = fit_mlr,
    spec = spec
  ))
}

get_neural_networks <- function(spec) {
  numeric_params <- c("epochs", "min_delta", "batch_size", "learning_rate", "epsilon", "patience_ratio", "l2")
  default_spec <- list(
    activation = "relu",
    min_delta = 0.5,
    batch_size = 32,
    learning_rate = 0.001,
    epsilon = 1e-07,
    patience_ratio = 0.25,
    l2 = 0
  )
  get_extendable_models(
    numeric_params = numeric_params,
    get_name = get_neural_network_name,
    create_model = create_neural_network,
    spec = spec,
    default_spec = default_spec
  )
}

get_svrs <- function(spec) {
  numeric_params <- c("gamma", "epsilon", "cost")
  get_extendable_models(
    numeric_params = numeric_params,
    get_name = get_svr_name,
    create_model = create_svr,
    spec = spec
  )
}

get_extendable_models <- function(numeric_params,
                                  get_name, create_model,
                                  spec, default_spec = NULL) {
  parse_model_spec <- function(spec, parent_spec = NULL) {
    spec_names <- names(spec)
    spec_has_children <- "children" %in% spec_names

    raw_extended <- get_extended_spec(spec, parent_spec)
    extended_spec <- if ("random" %in% spec_names) {
      random_list_names <- get_list_names(spec)
      random_names <- names(formals(generate_random_power_grid))
      random_names_in_spec <- c(
        intersect(
          spec_names,
          random_names
        ),
        random_list_names
      )

      random_grid <- do.call(generate_random_power_grid, spec[random_names_in_spec])
      grid_children <- apply(random_grid, 1, function(grid_point) {
        lapply(grid_point, unname)
      })

      # Add one children level in order to include randomly
      # generated parameter sets into the model inheritance hierarchy
      children <- if (length(grid_children)) {
        if (spec_has_children) {
          list(children = lapply(grid_children, function(child) {
            c(child, list(children = spec$children))
          }))
        } else {
          list(children = grid_children)
        }
      } else {
        if (spec_has_children) {
          list(children = spec$children)
        } else {
          list()
        }
      }
      extended <- raw_extended[setdiff(
        names(raw_extended),
        c("random", random_names_in_spec)
      )]
      c(extended, children)
    } else {
      extended <- get_extended_spec(spec, parent_spec)
      children <- if (spec_has_children) {
        list(children = spec$children)
      } else {
        list()
      }
      c(raw_extended, children)
    }

    list_names <- get_list_names(extended_spec)
    if (length(list_names)) {

      # Unroll a single parameter list per recursion level
      list_name <- list_names[[1]]

      vals <- extended_spec[[list_name]]
      unrolled_specs <- lapply(vals, function(val) {
        unrolled <- extended_spec
        unrolled[[list_name]] <- val
        unrolled
      })

      do.call(c, lapply(unrolled_specs, function(unrolled) {
        parse_model_spec(spec = unrolled)
      }))
    } else if ("children" %in% names(extended_spec)) {
      do.call(c, lapply(extended_spec$children, function(child_spec) {
        parse_model_spec(spec = child_spec, parent_spec = extended_spec)
      }))
    } else {
      # If some parameters are missing event in
      # the last level of child specs, set them to defauls
      full_spec <- parse_numeric_params(
        numeric_params,
        get_extended_spec(extended_spec, default_spec)
      )

      list(list(
        name = do.call(get_name, full_spec),
        fit = do.call(create_model, full_spec),
        spec = full_spec
      ))
    }
  }
  parse_model_spec(spec)
}

get_list_names <- function(spec, excluded = c("children")) {
  param_lengths <- unlist(lapply(spec, length))
  list_names <- setdiff(
    names(spec)[param_lengths > 1],
    excluded
  )
}

get_extended_spec <- function(spec, parent_spec = list(), excluded = c("children")) {
  params <- union(names(spec), names(parent_spec))
  params_to_copy <- setdiff(params, excluded)

  if (!length(parent_spec)) {
    spec[params_to_copy]
  } else {
    spec_names <- names(spec)
    merged_spec <- lapply(params_to_copy, function(param) {
      if (param %in% spec_names) {
        spec[[param]]
      } else {
        parent_spec[[param]]
      }
    })
    names(merged_spec) <- params_to_copy
    merged_spec
  }
}

parse_numeric_params <- function(params, spec) {
  numeric_params <- intersect(params, names(spec))
  other_params <- setdiff(names(spec), numeric_params)

  numeric_values <- lapply(numeric_params, function(param) {
    as.numeric(spec[[param]])
  })
  other_values <- lapply(other_params, function(param) {
    spec[[param]]
  })
  parsed <- c(numeric_values, other_values)
  names(parsed) <- c(numeric_params, other_params)
  parsed
}

# Remaining arguments are expected to be lists with
# two elements representing the lower and upper bound
# for the exponent
generate_random_power_grid <- function(model_count = 1,
                                       exp_base = 10,
                                       exp_step = 1,
                                       ...) {
  bound_pairs <- list(...)
  if (!length(bound_pairs)) {
    data.frame()
  }

  exp_seqs <- lapply(bound_pairs, function(bounds) {
    exponents <- seq(bounds[[1]], bounds[[2]], exp_step)
    sapply(exponents, function(exponent) {
      exp_base^exponent
    })
  })

  params <- do.call(expand.grid, exp_seqs)
  sample_count <- min(nrow(params), model_count)
  samples <- as.data.frame(params[sample(nrow(params), sample_count), ])
  colnames(samples) <- names(bound_pairs)
  rownames(samples) <- c()
  samples
}
