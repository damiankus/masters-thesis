wd <- getwd()
setwd(file.path("..", "common"))
source("constants.R")
source("utils.R")
setwd(wd)

packages <- c("xtable")
import(packages)

source_file_name_base <- "removed_observations_per_weather_variable"
table_content <- read.csv(paste(source_file_name_base, "csv", sep = "."), sep = ";")
colnames(table_content) <- lapply(colnames(table_content), function(col) {
  gsub(".", " ", col, fixed = T)
})

output_dir <- "removed_observations"
mkdir(output_dir)


stat_names <- as.character(table_content$Statistic)
stat_name_cells <- data.frame(Statistic = unlist(lapply(stat_names, function(stat_name) {
  gsub("[%]", "{[\\%]}", stat_name, fixed = TRUE)
})))

formatted_content <- cbind(
  stat_name_cells,
  table_content[, (colnames(table_content) != "Statistic")]
)

# 2 decimal places should be visible only in the last row
# beginning from the second column
col_count <- ncol(table_content)
row_count <- nrow(table_content)
digits <- matrix(
  c(
    rep(0, (row_count - 1) * (col_count + 1)),
    rep(0, 2), rep(2, col_count - 1)
  ),
  nrow = row_count,
  ncol = col_count + 1,
  byrow = TRUE
)

table <- xtable(
  x = formatted_content,
  align = c("l", p(0.125), rep(p(0.1, align = "right"), ncol(table_content) - 1)),
  caption = "Number of removed observations per weather variable",
  digits = digits,
  label = "tab:dataset-removed-observations"
)

content = print(
  x = table,
  include.rownames = FALSE,
  booktabs = TRUE,
  caption.placement = "top",
  table.placement = "htp",
  sanitize.text.function = identity,
  size = "\\footnotesize"
)

write_table_with_linespacing(
  content = content,
  line_spacing = 2,
  file = file.path(output_dir, paste(source_file_name_base, "tex", sep = "."))
)