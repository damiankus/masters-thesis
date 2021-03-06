test_wd <- getwd()
setwd("../../../common")
source("utils.R")
setwd(test_wd)

setwd("..")
source("data_splitters.R")
setwd(test_wd)

packages <- c("testthat")
import(packages)

load("test_series.Rda")


test_that("Splitting fails if", {
  test_that("split type is invalid", {
    expect_error(split_data_based_on_type("invalid", series), "Unknown split type.*")
  })

  test_that("time column is missing", {
    series_without_time_col <- series[, colnames(series) != "measurement_time"]
    expect_error(split_data_based_on_type("year", series_without_time_col), "No time column.*")
  })

  test_that("year column is missing", {
    series_without_year_col <- series[, colnames(series) != "year"]
    expect_error(split_data_based_on_type("year", series_without_year_col), "No year column.*")
  })
})

test_that("Split based on year", {
  test_that("fails if", {
    test_that("training and test sets overlap", {
      expect_error(
        split_data_by_year(series,
          training_years = c(2015, 2016),
          test_years = c(2016, 2017)
        ),
        "Training years.*"
      )
    })

    test_that("training and test sets are intertwined", {
      expect_error(
        split_data_by_year(series,
          training_years = c(2015, 2017),
          test_years = c(2016, 2018)
        ),
        "Training years.*"
      )
    })
  })

  all_split <- split_data_by_year(series)
  subsets <- all_split[[1]]

  test_that("contains a single group of subsets", {
    expect_equal(length(all_split), 1)
  })

  test_that("includes a correct number of observations", {
    rows_count <- nrow(subsets$training_set) +
      nrow(subsets$test_set)
    expect_equal(nrow(series), rows_count)
  })

  test_that("sets default training years to all available years except the last one", {
    years <- sort(unique(series$year))
    training_years <- sort(unique(subsets$training_set$year))
    expect_equal(length(training_years), length(years) - 1)
    expect_true(all(head(years) == training_years))
  })
  
  test_that("sets default test year to the last available one", {
    years <- sort(unique(series$year))
    test_years <- sort(unique(subsets$test_set$year))
    expect_equal(length(test_years), 1)
    expect_equal(tail(years, 1), test_years[1])
  })
  
  test_that("applies custom training years", {
    expected_years <- c(2014, 2015, 2017)
    training_set <- split_data_by_year(
      series,
      training_years = expected_years
    )[[1]]$training_set
    actual_years <- sort(unique(training_set$year))
    expect_true(all(expected_years == actual_years))
  })

  test_that("applies custom test years", {
    expected_years <- c(2013, 2014, 2016)
    test_set <- split_data_by_year(
      series,
      test_years = expected_years
    )[[1]]$test_set
    actual_years <- sort(unique(test_set$year))
    expect_true(all(expected_years == actual_years))
  })
  
  test_that("applies custom test and training years", {
    expected_training_years <- c(2012, 2013, 2015)
    expected_test_years <- c(2016, 2018)
    
    subsets <- split_data_by_year(
      series,
      training_years = expected_training_years,
      test_years = expected_test_years
    )[[1]]
    
    actual_training_years <- sort(unique(subsets$training_set$year))
    actual_test_years <- sort(unique(subsets$test_set$year))
    
    expect_true(all(expected_training_years == actual_training_years))
    expect_true(all(expected_test_years == actual_test_years))
  })
})

test_that("Split based on season and year", {
  test_that("fails if", {
    test_that("season column is missing", {
      series_without_season_col <- series[, colnames(series) != "season"]
      expect_error(split_data_by_season_and_year(series_without_season_col), "No season column.*")
    })
  })

  seasonal_split <- split_data_by_season_and_year(series)

  test_that("contains a number of subsplits equal to the number of seasons", {
    expect_equal(length(seasonal_split), 4)
  })

  test_that("contains subsplits made solely of observations taken during the given season", {
    seasons_in_subsets_valid <- lapply(seq(4), function(season) {
      subsets <- seasonal_split[[season]]
      seasons_in_subsets <- unique(c(
        unique(subsets$training_set$season),
        unique(subsets$test_set$season)
      ))
      length(seasons_in_subsets) == 1 && seasons_in_subsets[[1]] == season
    })
    expect_true(all(seasons_in_subsets_valid))
  })

  test_that("preserves custom training years", {
    expected_years <- c(2015, 2016)
    custom_seasonal_split <- split_data_by_season_and_year(
      series,
      training_years = expected_years
    )
    years_in_subsplits_valid <- lapply(seq(4), function (season) {
      subsets <- custom_seasonal_split[[season]]
      all(expected_years == sort(unique(
        subsets$training_set$year
      )))
    })
    expect_true(all(years_in_subsplits_valid))
  })

  test_that("preserves custom test years", {
    expected_years <- c(2016, 2018)
    custom_seasonal_split <- split_data_by_season_and_year(
      series,
      test_years = expected_years
    )
    years_in_subsplits_valid <- lapply(seq(4), function(season) {
      subsets <- custom_seasonal_split[[season]]
      all(expected_years == unique(
        subsets$test_set$year
      ))
    })
    expect_true(all(years_in_subsplits_valid))
  })
})
