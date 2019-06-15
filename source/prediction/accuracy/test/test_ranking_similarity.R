test_wd <- getwd()
setwd('..')
source('ranking_similarity_measures.R')
setwd(test_wd)

setwd(file.path('..', '..', '..', 'common'))
source('utils.R')
setwd(test_wd)

import("testthat")

base_ranking <- letters[1:10]

test_that('similarity is  ', {
  test_that('equal to 1 for same rankings', {
    expect_equal(1, calculate_kendall_similarity(base_ranking, base_ranking))
  })
  
  test_that('equal to -1 for reversed rankings', {
    expect_equal(-1, calculate_kendall_similarity(base_ranking, rev(base_ranking)))
  })

  test_that('within the 0 - 1 range', {
    random_rankings <- lapply(seq(200), function (i) { sample(base_ranking) })
    similarities <- mapply(function (r1, r2) {
      calculate_kendall_similarity(r1, r2)
    }, random_rankings[1:100], random_rankings[101:200])
    expect_true(all(-1 <= similarities & similarities <= 1))
  })
  
  test_that('not calculated if ', {
    ranking1 <- sample(base_ranking)
    ranking2 <- sample(base_ranking)
    repeated_ranking2 <- c(ranking2, ranking2)
    extra_vals_1 <- letters[11:15]
    extra_vals_2 <- letters[16:20]
    
    ranking1_with_extra_values <- sample(c(extra_vals_1, base_ranking)[1:length(base_ranking)])

    
    test_that('rankings have different number of elements', {
      expect_error(calculate_kendall_similarity(ranking1, repeated_ranking2), ".*same length.*")
    })
    
    test_that('a ranking contains non-unique values', {
      expect_error(calculate_kendall_similarity(rep(ranking1[[1]], length(ranking1)), ranking2), ".*first ranking.*unique.*")
    })
    
    test_that('the first ranking contains values not present in the second ranking', {
      ranking1_with_extra_values <- sample(c(extra_vals_1, ranking1)[1:length(ranking1)])
      expect_error(calculate_kendall_similarity(ranking1_with_extra_values, ranking2), "Every ranking.*same values.*")
    })
    
    test_that('the second ranking contains values not present in the first ranking', {
      ranking2_with_extra_values <- sample(c(extra_vals_2, ranking2)[1:length(ranking2)])
      expect_error(calculate_kendall_similarity(ranking1, ranking2_with_extra_values), "Every ranking.*same values.*")
    })
  })
  
  test_that("calculated properly for rankings being composed of ", {
    
    expect_almost_equal <- function (val1, val2, acceptable_error = 1e-3) {
      expect_lte(abs(val1 - val2), acceptable_error)
    }
    
    test_that("numeric values", {
      
      ranking1 <- c("a", "c", "b", "e", "d")
      ranking2 <- c("d", "a", "c", "b", "e")
      
      r1 <- factor(ranking1, levels = ranking1)
      r2 <- factor(ranking2, levels = ranking1)
      
      actual <- calculate_kendall_similarity(ranking1, ranking2)
      expected <- 0.2
      expect_almost_equal(expected, actual)
    })
    
    test_that("strings", {
      # Example taken from https://statistical-research.com/wp-content/uploads/2012/09/kendall-tau1.pdf
      ranking1 <- c(1, 2, 3, 4, 5, 6, 7)
      ranking2 <- c(1, 3, 6, 2, 7, 4, 5)
      
      actual <- calculate_kendall_similarity(ranking1, ranking2)
      expected <- 0.42857
      expect_almost_equal(expected, actual)
    })
  })
  
})
