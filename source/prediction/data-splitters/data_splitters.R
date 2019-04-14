wd <- getwd()
setwd("../../common")
source("utils.R")
setwd(wd)

split_data_based_on_type <- function(split_type,
                                     df,
                                     training_years = NULL,
                                     test_years = NULL,
                                     time_col = "measurement_time") {
  split_data <- switch(split_type,
    year = split_data_by_year,
    season_and_year = split_data_by_season_and_year,
    {
      stop(paste("Unknown split type:", split_type))
    }
  )
  split_data(df, training_years, test_years, time_col)
}

split_data_by_season_and_year <- function(df,
                                          training_years = NULL,
                                          test_years = NULL,
                                          time_col = "measurement_time") {
  if (!('season' %in% colnames(df))) {
    stop('No season column in dataframe')
  }
  
  seasons <- sort(unique(df$season))
  lapply(seasons, function (season) {
    seasonal_data <- df[df$season == season, ]
    split_data_by_year(df = seasonal_data, 
                      training_years = training_years,
                      test_years = test_years,
                      time_col = time_col)[[1]]
  })
}

split_data_by_year <- function(df,
                               training_years = NULL,
                               test_years = NULL,
                               time_col = "measurement_time") {
  data <- prepare_data(df, time_col)
  years <- sort(unique(data$year))
  
  defined_test_years <- if (is.null(test_years) && is.null(training_years)) {
    # last year
    tail(years, 1)
  } else if (is.null(test_years)) {
    # all years after the last test year
    years[years > max(training_years)]
  } else {
    test_years
  }
  
  defined_training_years <- if (is.null(training_years)) {
    # all years before the first test year
    years[years < min(defined_test_years)]
  } else {
    training_years
  }
  
  # Training and test sets are assumed to be separated and defined for increasing years.
  # They do not have to be contiguous but one set must not contain observations taken
  # after the last observation  in subset A and before the first observation of subset B of another set.
  # For example, the following situation is forbidden
  # Training years:  2012, 2013,    , 2015
  # Test years: (subset A)      2014,     , 2016 (subset B)
  
  is_first_less <- function (first, second) {
    first < second
  }
  training_years_before_test_years <- all(compare_each_item_pair(
    x = defined_training_years,
    y = defined_test_years,
    compare = is_first_less))
  if (!training_years_before_test_years) {
    stop(paste("Training years (", defined_training_years,
      ") should all be earlier than any of the test years (", defined_test_years,
      ")",
      sep = ""
    ))
  }

  which_training <- data$year %in% defined_training_years
  which_test <- data$year %in% defined_test_years

  list(
    list(
      training_set = data[which_training, ],
      test_set = data[which_test, ]
    )
  )
}

compare_each_item_pair <- function (x, y, compare) {
  apply(expand.grid(x = x, y = y), 1, function (pair) {
    compare(pair[1], pair[2])
  })
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
