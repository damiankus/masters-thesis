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
  excluded_for_specific_model <- if (startsWith(model_type, "neural")) {
    list("activation", "epochs", "min_delta", "patience_ratio", "batch_size")
  } else {
    list("kernel")
  }
  c(common_excluded, excluded_for_specific_model)
}

get_pretty_model_type <- function(model_type) {
  type <- tolower(gsub("_", " ", model_type))
  gsub("svr", "SVR", type)
}

get_pretty_model_name <- function(raw_name) {
  parts <- strsplit(raw_name, "__")[[1]]
  model_type <- parts[[1]]
  excluded <- get_excluded_parameters_for_model_type(model_type)
  params <- do.call(rbind, lapply(parts[-1], function(param) {
    key_value <- strsplit(param, "=")[[1]]
    data.frame(key = key_value[[1]], value = key_value[[2]])
  }))

  which_to_exclude <- params$key %in% excluded
  final_params <- params[!which_to_exclude, ]
  pretty_params <- lapply(seq(nrow(final_params)), function(idx) {
    row <- final_params[idx, ]
    paste(gsub("_", " ", row$key), row$value, sep = " = ")
  })

  if (length(pretty_params)) {
    paste(get_pretty_model_type(model_type), ": ", paste(pretty_params, collapse = ", "), sep = "")
  } else {
    get_pretty_model_type(model_type)
  }
}

raw_name <- "neural_network__hidden=10__activation=relu__epochs=100__min_delta=1e-04__patience_ratio=0.25__batch_size=32__learning_rate=0.1__epsilon=1e-08__l2=0.1__split_id=1"

make_cell <- function (content, align = "tl") {
  paste(
    paste("\\makecell[", align, "] {", sep = ""),
    content,
    "}"
  )
}

get_tex_model_name <- function (raw_name) {
  make_cell(
    get_pretty_model_name(raw_name) %>%
      gsub(",", ", \\\\", ., fixed = TRUE) %>%
      gsub(":", ": \\\\", ., fixed = TRUE)
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
    toupper(measure_name),
    MAE = "\\mu g / m^3",
    MAPE = "\\%",
    RMSE = "\\mu g / m^3",
    `$R^2$` = "1",
    R2 = '1'
  )
  paste("{[$", base_unit, "$]}", sep = "")
}

get_tex_column_name <- function(colname) {
  parts <- strsplit(colname, "\\.")[[1]]
  raw_main_part <- parts[[1]]
  raw_remainder <- if (length(parts) > 1) {
    parts[-1]
  } else {
    ""
  }

  prefix <- if (raw_remainder == "mean") {
    raw_remainder
  } else {
    ""
  }
  suffix <- if (raw_remainder == "sd") {
    "std dev."
  } else {
    ""
  }
  
  if (nchar(raw_remainder)) {
    # It is an accurracy measure
    main_part <- get_tex_measure_name(raw_main_part)
    parts <- c(prefix, main_part, suffix, get_tex_measure_unit(main_part))
    non_empty_parts <- parts[sapply(parts, nchar) > 0]
    make_cell(
      cap(paste(non_empty_parts, collapse = " \\\\ ")),
      align = "tr"
    )
  } else {
    cap(raw_main_part)
  }
}

get_pretty_column_name <- function(colname) {
  parts <- strsplit(colname, "\\.")[[1]]
  raw_main_part <- parts[[1]]
  raw_remainder <- if (length(parts) > 1) {
    parts[-1]
  } else {
    ""
  }
  
  prefix <- if (raw_remainder == "mean") {
    "mean "
  } else {
    ""
  }
  suffix <- if (raw_remainder == "sd") {
    " std dev."
  } else {
    ""
  }
  
  main_part <- if (nchar(prefix) > 0 || nchar(suffix) > 0) {
    gsub('\\$', '', get_tex_measure_name(raw_main_part))
  } else {
    raw_main_part
  }
  
  cap(paste(prefix, main_part, suffix, sep = ""))
}

get_tex_measure_column_name <- function (measure_name) {
  make_cell(
    paste(
      get_tex_measure_name(measure_name),
      get_tex_measure_unit(measure_name),
      sep = "\\\\"
    ),
    align = "tr"
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
