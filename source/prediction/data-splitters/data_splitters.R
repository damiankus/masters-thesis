wd <- getwd()
setwd("../../common")
source("utils.R")
setwd(wd)

split_data_based_on_type <- function(split_type, df,
                                     validation_years = NULL,
                                     test_years = NULL,
                                     time_col = "measurement_time") {
  split_data <- switch(split_type,
    year = split_data_by_year,
    season = split_data_by_season_and_year, {
      stop(paste("Unknown split type:", split_type))
    }
  )
  split_data(df, validation_years, test_years, time_col)
}

split_data_by_season_and_year <- function(df,
                                          validation_years = NULL,
                                          test_years = NULL,
                                          time_col = "measurement_time") {
  if (!('season' %in% colnames(df))) {
    stop('No season column in dataframe')
  }
  
  seasons <- sort(unique(df$season))
  lapply(seasons, function(season) {
    seasonal_data <- df[df$season == season, ]
    split_data_by_year(seasonal_data, validation_years, test_years, time_col)[[1]]
  })
}

split_data_by_year <- function(df,
                               validation_years = NULL,
                               test_years = NULL,
                               time_col = "measurement_time") {
  data <- prepare_data(df, time_col)
  years <- sort(unique(data$year))
  
  defined_validation_years <- if (is.null(validation_years) && is.null(test_years)) {
    # last but one year
    head(tail(years, 2), 1)
  } else if (is.null(validation_years)) {
    # last year earlier than the start of the test set
    tail(years[years < min(test_years)], 1)
  } else {
    validation_years
  }
  
  defined_test_years <- if (is.null(test_years)) {
    # remaining years after validation years
    years[years > max(defined_validation_years)]
  } else {
    test_years
  }
  
  # Training, validation and test sets are assumed to be separated
  # and defined for increasing years. They do not have to be contiguous
  # but one set must not contain observations taken after the last observation 
  # in subset A and before the first observation of subset B of another set.
  # For example, the following situation is forbidden
  # Test years:       2012, 2013,     , 2015
  # Validation years: (subset A) 2014,     , 2016 (subset B)
  
  if (max(defined_validation_years) >= min(defined_test_years)) {
    stop(paste("Max year of a validation set (", max(defined_validation_years),
      ") should be less than min year of a test set (", min(defined_test_years),
      ")",
      sep = ""
    ))
  }
  defined_training_years <- years[years < min(defined_validation_years)]

  which_training <- data$year %in% defined_training_years
  which_validation <- data$year %in% defined_validation_years
  which_test <- data$year %in% defined_test_years

  list(
    list(
      training_set = data[which_training, ],
      validation_set = data[which_validation, ],
      test_set = data[which_test, ]
    )
  )
}

prepare_data <- function(df, time_col) {
  if (!("year" %in% colnames(df))) {
    stop("No year column found in dataframe")
  }
  if (!(time_col %in% colnames(df))) {
    stop(paste("No time column", time_col, "column found in dataframe"))
  }
  df[order(df[time_col]), ]
}
