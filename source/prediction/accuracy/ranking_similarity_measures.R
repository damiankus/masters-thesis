ranking_measure_wd <- getwd()
setwd(file.path("..", "..", "common"))
source("utils.R")
setwd(ranking_measure_wd)

calculate_kendall_similarity <- function(ranking1, ranking2) {
  unique_1 <- unique(ranking1)
  unique_2 <- unique(ranking2)

  if (length(ranking1) != length(ranking2)) {
    stop("Rankings should have the same length")
  }

  ranking_1_contains_non_uniques <- length(unique_1) != length(ranking1)
  ranking_2_contains_non_uniques <- length(unique_2) != length(ranking2)

  if (ranking_1_contains_non_uniques || ranking_2_contains_non_uniques) {
    message_part_1 <- if (ranking_1_contains_non_uniques) {
      list("first")
    } else {
      list()
    }
    message_part_2 <- if (ranking_2_contains_non_uniques) {
      list("second")
    } else {
      list()
    }
    which_ranking_info <- paste(
      sapply(c(message_part_1, message_part_2), function(part) {
        paste("the", part)
      }),
      collapse = " and "
    )

    error_message <- paste(which_ranking_info, "ranking should contain unique values")
    stop(cap(error_message))
  }

  if (length(setdiff(unique_1, unique_2)) > 0) {
    stop("Every ranking should contain the same values")
  }

  # ranking1 is a reference point for judging
  # the order of items in ranking2, e.g.
  # ranking1 = a c e f d -> a < c < e < f < d

  r1 <- seq(length(ranking1))
  r2 <- as.numeric(factor(ranking2, levels = ranking1))
  cor(r1, r2, method = "kendall")
}
