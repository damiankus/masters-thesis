import <- function(packages) {
  Sys.setenv(LANG = "en")
  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(new_packages) > 0) {
    install.packages(new_packages, dependencies = TRUE)
  }
  lapply(packages, library, character.only = TRUE)
}

cap <- function(s) {
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = "")
}

units <- function(vars) {
  get_units <- function(var) {
    switch(var,
      pm2_5 = "μg/m³",
      pm10 = "μg/m³",
      temperature = "°C",
      humidity = "%",
      pressure = "hPa",
      wind_speed = "m/s",
      wind_dir_deg = "°",
      wind_dir_ew = "1",
      wind_dir_ns = "1",
      solradiation = 'W/m²',
      precip_total = "mm",
      precip_rate = "mm/h", {
        if (grepl("future_", var)) {
          delim <- "future_"
          split_var <- strsplit(var, delim)[[1]]
          base_var <- split_var[[2]]
          units(base_var)
        } else if (grepl("_past_", var)) {
          delim <- "_past_"
          split_var <- strsplit(var, delim)[[1]]
          base_var <- split_var[[1]]
          units(base_var)
        } else if (startsWith(var, "min_") ||
                   startsWith(var, "max_") ||
                   startsWith(var, "mean_") ||
                   startsWith(var, "total_")) {
          parts <- strsplit(var, '_')[[1]]
          var_name <- paste(parts[3:length(parts)], collapse="_")
          units(var_name)
        } else {
          ""
        }
      }
    )
  }

  unlist(lapply(
    vars, get_units
  ))
}

get_pretty_var <- function(vars) {
  get_get_pretty_var <- function(var) {
    switch(var,
      pm1 = "PM1",
      pm2_5 = "PM2.5",
      pm10 = "PM10",
      future_pm2_5 = "PM2.5 in 24 h",
      solradiation = "solar radiation",
      wind_speed = "wind speed",
      wind_dir = "wind direction",
      wind_dir_deg = "wind direction",
      wind_dir_ns = "wind direction N - S",
      wind_dir_ew = "wind direction E - W",
      precip_rate = "precipitation rate",
      precip_total = "total precipitation",
      is_heating_season = "heating season",
      is_holiday = "holiday",
      day_of_week = "day of the week",
      hour_of_day = "hour of the day", {
        if (grepl("future_", var)) {
          delim <- "future_"
          split_var <- strsplit(var, delim)[[1]]
          pvar <- get_pretty_var(split_var[[2]])
          paste(pvar, "in 24h")
        } else if (grepl("_past_", var)) {
          delim <- "_past_"
          split_var <- strsplit(var, delim)[[1]]
          pvar <- get_pretty_var(split_var[[1]])
          lag <- split_var[[2]]
          paste(pvar, " ", lag, "h ago", sep = "")
        } else if (startsWith(var, "min_") ||
                   startsWith(var, "max_") ||
                   startsWith(var, "mean_") ||
                   startsWith(var, "total_")) {
          parts <- strsplit(var, '_')[[1]]
          aggr_type <- parts[[1]]
          time_lag <- parts[[2]]         
          var_name <- get_pretty_var(
            paste(
              parts[3:length(parts)], collapse="_"))
          paste(aggr_type, time_lag, "h", var_name)
        } else if (startsWith(var, "sum_")) {
          parts <- strsplit(var, '_')[[1]]
          time_lag <- parts[[2]]         
          var_name <- get_pretty_var(
            paste(
              parts[3:length(parts)], collapse="_"))
          paste(aggr_type, time_lag, "h", var_name)
        } else if (grepl("_of_", var)) {
          parts <- strsplit(var, "_of_")[[1]]
          smaller_part <- parts[[1]]
          transformation_parts <- strsplit(parts[[2]], "_")[[1]]
          larger_part <- if (length(transformation_parts) > 1) {
            paste(transformation_parts[[1]], " (",  transformation_parts[[2]], ")", sep = "")
          } else {
            transformation_parts[[1]]
          }
          paste(smaller_part, "of the", larger_part)
        } else {
          delim <- "_"
          paste(strsplit(var, delim)[[1]], collapse = " ")
        }
      }
    )
  }
  unlist(lapply(vars, get_get_pretty_var))
}


short_get_pretty_var <- function(vars) {
  get_short_var <- function(var) {
    switch(var,
           precip_total = "total. precip",
           precip_rate = "precip. rate",
           solradiation = "sol. radiation", {
             get_pretty_var(var)
           }
    )
  }
  unlist(lapply(vars, get_short_var))
}

get_or_generate_label <- function (var, label) {
  if (hasArg(label) && nchar(label) > 0) {
    label
  } else {
    unit <- units(var)
    pvar <- get_pretty_var(var)
    if (nchar(unit) > 0) {
      paste(pvar, ' [', unit ,']', sep='')
    } else {
      pvar
    }
  }
}

get_pretty_station_id <- function(ids) {
  get_pretty_id <- function(id) {
    parts <- strsplit(as.character(id), "_")[[1]]
    paste(toupper(parts[[1]]), cap(parts[[2]]))
  }
  unlist(lapply(ids, get_pretty_id))
}

mkdir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, showWarnings = TRUE, recursive = TRUE)
  }
}

utcts <- function(datestring) {
  as.POSIXct(datestring, origin = "1970-01-01", tz = "UTC")
}

parse_list_argument <- function(options, argname, valid_values = c(), sep = ",") {
  value_parts <- strsplit(options[[argname]], split = sep)[[1]]
  process_value <- if (length(valid_values) > 0) {
    function(value) {
      trimmed <- trimws(value)
      if (nchar(trimmed) > 0 && trimmed %in% valid_values) {
        trimmed
      }
    }
  } else {
    function(value) {
      trimmed <- trimws(value)
      if (nchar(trimmed) > 0) {
        trimmed
      }
    }
  }
  unlist(lapply(value_parts, process_value))
}

round_numeric <- function (numeric_val, digits = 2) {
  format(round(numeric_val, digits), nsmall = digits)
}


# LaTex helpers

packages <- c("optparse", "xtable", "latex2exp")
import(packages)

p <- function (width_fraction, align = "left") {
  alignment_command <- switch (
    align,
    left = "\\raggedright",
    right = "\\raggedleft",
    { "" }
  )
  paste(">{", alignment_command, "\\arraybackslash}p{", width_fraction, "\\linewidth}%\n", sep = "")
}

makecell <- function (content, align = "tl") {
  paste(
    paste("\\makecell[", align, "]{", sep = ""),
    content,
    "}",
    sep = ""
  )
}

makecell_and_add_new_lines <- function (content, align = "tl") {
  makecell(gsub("\\s+", " \\\\\\\\ ", content), align = align)
}

multicolumn <- function (content, col_count, align = "r") {
  paste(
    "\\multicolumn",
    "{", col_count, "}",
    "{", align, "}",
    "{", content, "}",
    sep = ""
  )
}

multirow <- function (content, row_count, width = "*") {
  paste(
    "\\multirow",
    "{", row_count, "}",
    "{", width, "}",
    "{", content, "}",
    sep = ""
  )
}

cellcolor <- function (content, color) {
  paste("\\cellcolor[HTML]{", color, "}{", content, "}", sep = "")
}

get_exponent <- function (value, base = 10) {
  exponent <- log(value, base)
  sign(exponent) * floor(abs(exponent))
}

write_table_with_linespacing <- function (content, file, line_spacing) {
  write(
    x = paste(
      "{",
      paste("\\renewcommand\\arraystretch{", line_spacing, "}", sep = ""),
      content,
      "}",
      sep = "\n"
    ),
    file = file
  )
}

save_table <- function (
  content,
  align,
  caption,
  label,
  col_names,
  file,
  digits = 2,
  line_spacing = 2,
  footer = "\\bottomrule",
  font_size = "\\scriptsize"
) {
  
  options(xtable.sanitize.text.function = identity)
  
  table <- xtable(
    x = content,
    align = align,
    caption = caption,
    label = label,
    digits = digits
  )
  
  midrule_placeholder <- "@midrule"
  footer_placeholder <- "@footer"
  continuation_message_placeholder <- "@continuation-message"
  
  col_names_row <- paste(
    unlist(col_names),
    collapse = " & "
  )
  
  header <- paste(
    c(
      paste(col_names_row, "\\\\"),
      midrule_placeholder,
      "\\endhead",
      continuation_message_placeholder,
      "\\endfoot",
      footer_placeholder,
      "\\endlastfoot"
    ),
    collapse = "\n"
  )
  
  header_options <- list(
    pos = list(0),
    command = header
  )
  
  formatted <- print(
    x = table,
    tabular.environment = "longtable",
    caption.placement = "top",
    floating = FALSE,
    booktabs = TRUE,
    include.rownames = FALSE,
    include.colnames = FALSE,
    add.to.row = header_options,
    size = font_size,
    table.placement = "H"
  )
  
  continuation_message <- paste(
    "\\bottomrule",
    paste(
      multicolumn("Continued on the next page", align = "c", col_count = ncol(content)),
      "\\\\"
    ),
    "\\bottomrule",
    sep = "\n"
  )
  
  formated_footer <- if (footer == "\\bottomrule") {
    "\\bottomrule"
  } else {
    paste(
      "\\bottomrule",
      paste(footer, "\\\\"),
      "\\bottomrule",
      sep = " \n"
    )
  }
  
  write_table_with_linespacing(
    content = sub("\\midrule", "", fixed = T, formatted) %>%
      gsub("\\\\\\\\\\s+\\n\\s+\\\\bottomrule", "", .) %>%
      gsub(midrule_placeholder, "\\midrule", fixed = TRUE, .) %>%
      sub(continuation_message_placeholder, continuation_message, fixed = TRUE, .) %>%
      sub(footer_placeholder, formated_footer, fixed = TRUE, .),
    file = file,
    line_spacing = line_spacing
  )
}

get_tex_measure_units <- function (measures) {
  get_units <- function(measure) {
    if (grepl("mae", measure, fixed = TRUE)) {
      "$ \\mu g / m^3 $"
    } else {
      ""
    }
  }
  
  unlist(lapply(
    measures, get_units
  ))
}

get_tex_full_measure_name <- function (measure_ids) {
  get_name <- function (measure_id) {
    phrase_to_name <- list(
      mae = "Mean Absolute Error",
      rmse = "Root Mean Square Error",
      mse = "Mean Square Error",
      mape = "Mean Absolute Percentage Error",
      r2 = "$R^2$",
      r = "Pearson correlation coefficient"
    )
    name <- "Unknown"
    for (phrase in names(phrase_to_name)) {
      if (grepl(phrase, measure_id, fixed = TRUE)) {
        name <- phrase_to_name[[phrase]]
        break
      }
    }
    name
  }
  
  unlist(lapply(
    measure_ids, get_name
  ))
} 
