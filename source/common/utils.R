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

pretty_var <- function(vars) {
  get_pretty_var <- function(var) {
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
          pvar <- pretty_var(split_var[[2]])
          paste(pvar, "in 24h")
        } else if (grepl("_past_", var)) {
          delim <- "_past_"
          split_var <- strsplit(var, delim)[[1]]
          pvar <- pretty_var(split_var[[1]])
          lag <- split_var[[2]]
          paste(pvar, " ", lag, "h ago", sep = "")
        } else if (startsWith(var, "min_") ||
                   startsWith(var, "max_") ||
                   startsWith(var, "mean_") ||
                   startsWith(var, "total_")) {
          parts <- strsplit(var, '_')[[1]]
          aggr_type <- parts[[1]]
          time_lag <- parts[[2]]         
          var_name <- pretty_var(
            paste(
              parts[3:length(parts)], collapse="_"))
          paste(aggr_type, time_lag, "h", var_name)
        } else if (startsWith(var, "sum_")) {
          parts <- strsplit(var, '_')[[1]]
          time_lag <- parts[[2]]         
          var_name <- pretty_var(
            paste(
              parts[3:length(parts)], collapse="_"))
          paste(aggr_type, time_lag, "h", var_name)
        } else {
          delim <- "_"
          paste(strsplit(var, delim)[[1]], collapse = " ")
        }
      }
    )
  }
  unlist(lapply(vars, get_pretty_var))
}


short_pretty_var <- function(vars) {
  get_short_var <- function(var) {
    switch(var,
      precip_total = "total. precip",
      precip_rate = "precip. rate",
      solradiation = "sol. radiation", {
        pretty_var(var)
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
    pvar <- pretty_var(var)
    if (nchar(unit) > 0) {
      paste(pvar, ' [', unit ,']', sep='')
    } else {
      pvar
    }
  }
}

pretty_station_id <- function(ids) {
  get_pretty_id <- function(id) {
    parts <- strsplit(id, "_")[[1]]
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
