# For convenience set wd to the parent directory containing
# the model training script
# setwd('..')
wd <- getwd()
setwd(file.path("../..", "common"))
source("utils.R")
setwd(wd)

source("../models/models.R")

packages <- c("yaml")
import(packages)


load_yaml <- function(config_path) {
  config <- read_yaml(file = config_path)
  list(
    models = get_models(config)
  )
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
    model = fit_mlr
  ))
}

get_svrs <- function(spec, parent_spec = NULL) {
  if ("random" %in% spec && spec$random) {
    generate_random_pow_svrs(
      model_count = spec$model_count,
      base = 2,
      kernel = spec$kernel,
      gamma_pow_bound = c(spec$gamma$min, spec$gamma$max),
      epsilon_pow_bound = c(spec$epsilon$min, spec$epsilon$max),
      costs = c(spec$cost$min, spec$cost$max)
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
        model = create_svr(
          kernel = extended_spec$kernel,
          gamma = extended_spec$gamma,
          epsilon = extended_spec$epsilon,
          cost = extended_spec$cost
        )
      ))
    }
  }
}

get_neural_networks <- function(spec, parent_spec = NULL) {
  raw_spec <- get_extended_spec(
    c("hidden", "threshold", "stepmax", "lifesign"),
    spec,
    parent_spec
  )
  extended_spec <- parse_numeric_params(c("threshold", "stepmax"), raw_spec)

  if ("children" %in% names(spec)) {
    do.call(c, lapply(spec$children, function(child_spec) {
      get_neural_networks(child_spec, extended_spec)
    }))
  } else {
    lifesign <- if ("lifesign" %in% extended_spec) {
      extended_spec$lifesign
    } else {
      "full"
    }

    neural_network <- create_neural_network(
      hidden = parse_network_layer_extended_spec(extended_spec$hidden),
      threshold = extended_spec$threshold,
      stepmax = extended_spec$stepmax,
      lifesign = lifesign
    )

    list(list(
      name = get_neural_network_name(
        hidden = extended_spec$hidden,
        threshold = extended_spec$threshold,
        stepmax = extended_spec$stepmax
      ),
      model = neural_network
    ))
  }
}

parse_network_layer_spec <- function(layer_spec) {
  as.numeric(strsplit(layer_spec, split = "-")[[1]])
}

get_extended_spec <- function(params, spec, parent_spec) {
  if (is.null(parent_spec)) {
    spec
  } else {
    merged_spec <- lapply(params, function(param) {
      if (is.null(spec[[param]])) {
        parent_spec[[param]]
      } else {
        spec[[param]]
      }
    })
    names(merged_spec) <- params
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

# setwd('loaders')
