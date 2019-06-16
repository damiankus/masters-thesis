accuracy_wd <- getwd()
accuracy_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
setwd(accuracy_wd)

packages <- c('dplyr')
import(packages)

as_model_types <- function(col) {
  sapply(as.character(col), function(model_name) {
    strsplit(model_name, "__")[[1]][[1]]
  })
}

get_top_stats_per_model <- function(sorted_stats, model_count = 1) {
  model_types <- as_model_types(sorted_stats$model)
  top_per_model <- lapply(unique(model_types), function(model_type) {
    which_top <- head(which(model_types == model_type), model_count)
    sorted_stats[which_top, ]
  })
  do.call(rbind, top_per_model)
}

get_top_stats_per_season_and_model <- function(sorted_stats, model_count = 1) {
  top_per_season_and_model <- lapply(sort(unique(sorted_stats$season)), function(season) {
    stats_for_season <- sorted_stats[sorted_stats$season == season, ]
    get_top_stats_per_model(stats_for_season, model_count)
  })
  do.call(rbind, top_per_season_and_model)
}

get_stats_metadata <- function(stats_path) {
  stats_name <- basename(stats_path)
  parts <- strsplit(stats_name, "__")[[1]]
  list(
    stats_type = parts[[1]],
    phase = parts[[2]],
    station_id = parts[[3]],
    training_strategy = parts[[4]]
  )
}

get_file_name_from_metadata <- function(meta, extension = "", prefix = "") {
  gsub(
    "(__)+$",
    "",
    paste(prefix, meta$phase, meta$station_id, meta$training_strategy, extension, sep = "__")
  )
} 

get_excluded_parameters_for_model_type <- function(model_type) {
  common_excluded <- list("split_id")
  lowercase_type <- tolower(model_type)
  excluded_for_specific_model <- if (startsWith(lowercase_type, "neural")) {
    list("activation", "epochs", "min_delta", "patience_ratio", "batch_size")
  } else if (startsWith(lowercase_type, "svr")) {
    list("kernel")
  } else {
    list()
  }
  c(common_excluded, excluded_for_specific_model)
}

get_model_type_from_name <- function(raw_name) {
  parts <- strsplit(raw_name, "__")[[1]]
  model_type <- parts[[1]]
  type <- tolower(gsub("_", " ", model_type))
  gsub("svr", "SVR", type)
}

get_model_params_from_name <- function (raw_name) {
  parts <- strsplit(raw_name, "__")[[1]]
  model_type <- parts[[1]]
  
  if (length(parts) < 2) {
    data.frame(key = c(), value = c())
  } else {
    excluded <- get_excluded_parameters_for_model_type(model_type)
    params <- do.call(rbind, lapply(parts[-1], function(param) {
      key_value <- strsplit(param, "=")[[1]]
      data.frame(key = key_value[[1]], value = key_value[[2]])
    }))
    which_to_exclude <- params$key %in% excluded
    
    formatted_params <- data.frame(params)
    formatted_params$value <- as.character(params$value)
    formatted_params$key <- lapply(params$key, function (key) {
      gsub("_", " ", key)
    })
    formatted_params[!which_to_exclude, ]
  }
}

get_pretty_model_name <- function(raw_name) {
  params <- get_model_params_from_name(raw_name)
  pretty_params <- lapply(seq(nrow(params)), function(idx) {
    row <- params[idx, ]
    paste(gsub("_", " ", row$key), row$value, sep = " = ")
  })

  if (length(pretty_params)) {
    paste(get_model_type_from_name(raw_name), ": ", paste(pretty_params, collapse = ", "), sep = "")
  } else {
    get_model_type_from_name(raw_name)
  }
}

get_numeric_base_for_model <- function (model_type) {
  switch(
    tolower(model_type),
    svr = 2,
    10
  )
}

get_tex_model_name <- function (raw_name) {
  params <- get_model_params_from_name(raw_name)
  model_type <- get_model_type_from_name(raw_name)
  numeric_base <- get_numeric_base_for_model(model_type)
  seemingly_numeric_params <- c("hidden")
  upper_case_params <- c("l2")
  param_info <- if (nrow(params)) {
    tex_params <- sapply(seq(nrow(params)), function (idx) {
      param <- params[idx, ]
      numeric_val <- as.numeric(param$value)
      
      value <- if (is.na(numeric_val) || param$key %in% seemingly_numeric_params) {
        if (param$key == "hidden") {
          paste("(", gsub("-", ",\\ ", param$value), ")", sep = "")
        } else { 
          param$key
        }
      } else {
        paste(numeric_base, "^{", get_exponent(numeric_val, base = numeric_base), "}", sep = "")
      }
      
      formatted_key <- if (param$key %in% upper_case_params) {
        toupper(param$key)
      } else {
        param$key
      }
      key <- paste("\\textit{", formatted_key, "}", sep = "")
      paste(key, " = $", value, "$", sep = "")
    })
    paste("\\\\", paste(tex_params, collapse = " \\\\ "))
  } else {
    ""
  }
  paste(
    "\\textbf{", model_type, "}",
    param_info,
    sep = ""
  )
}

get_tex_measure_name <- function(measure_name) {
  switch(
    measure_name,
    r2 = "$R^2$",
    toupper(measure_name)
  )
}

get_tex_measure_unit <- function(measure_name) {
  base_unit <- switch(
    tolower(measure_name),
    mae = "\\mu g / m^3",
    mape = "\\%",
    rmse = "\\mu g / m^3",
    r2 = "1"
  )
  paste("{[$", base_unit, "$]}", sep = "")
}

get_tex_column_name <- function(colname) {
  sep <- "[\\._]"
  parts <- strsplit(colname, sep)[[1]]
  content <- if (colname == "training.strategy") {
    "Used data"
  } else {
    paste(parts, collapse = " ")
  }
  multirow(cap(content), row_count = 3)
}

get_tex_measure_column_name <- function (measure_name) {
  multicolumn(
    makecell(
      paste(
        get_tex_measure_name(measure_name),
        "\\\\",
        get_tex_measure_unit(measure_name)
      ),
      align = "tc"
    ),
    col_count = 2,
    align = "c"
  )
}

get_stats_with_zero_sd_values_removed <- function(stats) {
  col_names <- colnames(stats)
  lapply(seq_along(stats), function(idx) {
    col <- stats[, idx]
    if (grepl("\\.sd", col_names[[idx]])) {
      ifelse(col == 0, "", as.character(col))
    } else {
      col
    }
  })
}
