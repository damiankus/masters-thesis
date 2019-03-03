source('utils.R')

packages <- c("knitr", "xtable")
import(packages)

save_latex <- function(df, file_path, custom_alignment = c(), precision = 2,
                       include.rownames = FALSE, include.colnames = TRUE) {
  col_count <- ncol(df)
  alignment <- if (length(custom_alignment) == 0 && col_count > 0) {
    c("l", "l", rep("r", col_count - 1))
  } else {
    col_alignment
  }
  print(
    xtable(df, type = "latex", align = alignment, digits = precision),
    file = file_path, booktabs = TRUE, include.rownames = include.rownames, include.colnames = include.colnames
  )
}

save_markdown <- function(df, file_path, row.names = FALSE) {
  pretty <- knitr::kable(df, row.names = row.names)
  write(pretty, file = file_path)
}