related_work_wd <- getwd()
setwd(file.path("..", "common"))
source("utils.R")
setwd(related_work_wd)

import(c("xtable", "dplyr"))
options(xtable.sanitize.text.function = identity)

# Main

output_dir <- 'tex'
mkdir(output_dir)

# Acronyms

acronyms <- read.csv(file = "acronyms.csv", header = TRUE)
acronyms_content <- acronyms
acronyms_content$Acronym <- lapply(acronyms$Acronym, function (acronym) {
  paste("\\textbf{", acronym ,"}")
})

save_table(
  content = acronyms_content,
  col_names = colnames(acronyms_content),
  align = c("r", "l", p(0.8)),
  caption = paste("Acronyms used in the summary of the related work overview"),
  label = "tab:related-work-acronyms",
  file = file.path(output_dir, "acronyms.tex"),
  line_spacing = 1,
  font_size = "\\footnotesize"
)

# Summary

summary <- read.csv(file = "summary.csv", header = TRUE)
summary_content <- summary
summary_content$Best.results <- lapply(summary$Best.results, function (results) {
  makecell(results)
})

summary_colnames <- lapply(colnames(summary_content), function (colname) {
  gsub("\\.", " ", colname)
})

save_table(
  content = summary_content,
  align = c("r", c(p('0.075'), p('0.1'), p('0.125'), p('0.2'), p('0.125'), p('0.25'))),
  caption = paste("Related work summary"),
  label = "tab:related-work-summary",
  col_names = summary_colnames,
  file = file.path(output_dir, "summary.tex")
)

# Meteo variables

meteo_vars <- read.csv(file = "meteo-variables.csv", quote = '"', sep = ",")
meteo_content <- data.frame(Source = meteo_vars$Source)

meteo_usage_count <- unlist(lapply(meteo_vars[, -1], function (col) {
  sum(as.numeric(col == TRUE & !is.na(col)))  
}))
meteo_usage_order <- order(meteo_usage_count, decreasing = TRUE)
meteo_usage_count_sorted <- meteo_usage_count[meteo_usage_order]

meteo_ticks <- do.call(
  cbind,
  lapply(meteo_vars[, -1], function (col) {
    ifelse(col == TRUE & !is.na(col), "\\checkmark", "")
  })
)
meteo_content <- cbind(
  data.frame(Source = as.character(meteo_vars$Source)),
  meteo_ticks[, meteo_usage_order]
)

meteo_colnames <- lapply(colnames(meteo_content), function (colname) {
  makecell(sub("\\.", " \\\\\\\\ ", colname))
})

meteo_footer <- paste(
  c(
    list("Usage count"),
    as.list(meteo_usage_count_sorted)
  ),
  collapse = " & "
)

save_table(
  content = meteo_content,
  align = c("r", rep("c", ncol(meteo_content))),
  caption = paste("Meteorological variables used in related work"),
  label = "tab:related-work-meteo-variables",
  col_names = meteo_colnames,
  file = file.path(output_dir, "meteo-variables.tex"),
  footer = meteo_footer
)

# Air quality variables

air_quality_vars <- read.csv(file = "air-quality-variables.csv", quote = '"', sep = ",")
air_quality_content <- data.frame(Source = air_quality_vars$Source)

air_quality_usage_count <- unlist(lapply(air_quality_vars[, -1], function (col) {
  sum(as.numeric(col == TRUE & !is.na(col)))  
}))
air_quality_usage_order <- order(air_quality_usage_count, decreasing = TRUE)
air_quality_usage_count_sorted <- air_quality_usage_count[air_quality_usage_order]

air_quality_ticks <- do.call(
  cbind,
  lapply(air_quality_vars[, -1], function (col) {
    ifelse(col == TRUE & !is.na(col), "\\checkmark", "")
  })
)
air_quality_content <- cbind(
  data.frame(Source = as.character(air_quality_vars$Source)),
  air_quality_ticks[, air_quality_usage_order]
)

air_quality_colnames <- lapply(colnames(air_quality_content), function (colname) {
  formatted <- sub("X\\.", "\\", colname) %>% sub("\\.2\\.", "[2]", .)
  first_char <- substr(formatted, 1, 1)
  if (first_char == toupper(first_char)) {
    formatted
  } else {
    paste("\\", formatted, sep = "")
  }
})

air_quality_footer <- paste(
  c(
    list("Usage count"),
    as.list(air_quality_usage_count_sorted)
  ),
  collapse = " & "
)

save_table(
  content = air_quality_content,
  align = c("r", rep("c", ncol(air_quality_content))),
  caption = paste("Air quality variables used in related work"),
  label = "tab:related-work-air-quality-variables",
  col_names = air_quality_colnames,
  file = file.path(output_dir, "air-quality-variables.tex"),
  footer = air_quality_footer
)

# Other variables
other_vars_content <- read.csv(file = "other-variables.csv")
other_vars_colnames <- unlist(lapply(colnames(other_vars_content), function (colname) {
  makecell(gsub("\\.", " \\\\ ", colname))
}))

save_table(
  content = other_vars_content,
  align = c("r", p(0.1), p(0.5), p(0.3)),
  caption = paste("Other variables used in related work"),
  label = "tab:related-work-other-variables",
  col_names = other_vars_colnames,
  file = file.path(output_dir, "other-variables.tex")
)

# Model types

model_type_vars <- read.csv(file = "model-types.csv", quote = '"', sep = ",")
model_type_content <- data.frame(Source = model_type_vars$Source)

model_type_usage_count <- unlist(lapply(model_type_vars[, -1], function (col) {
  sum(as.numeric(col == TRUE & !is.na(col)))  
}))
model_type_usage_order <- order(model_type_usage_count, decreasing = TRUE)
model_type_usage_count_sorted <- model_type_usage_count[model_type_usage_order]

model_type_ticks <- do.call(
  cbind,
  lapply(model_type_vars[, -1], function (col) {
    ifelse(col == TRUE & !is.na(col), "\\checkmark", "")
  })
)
model_type_content <- cbind(
  data.frame(Source = as.character(model_type_vars$Source)),
  model_type_ticks[, model_type_usage_order]
)

model_type_colnames <- lapply(colnames(model_type_content), function (colname) {
  makecell(gsub("\\.", " \\\\\\\\ ", colname))
})

model_type_footer <- paste(
  c(
    list("Usage count"),
    as.list(model_type_usage_count_sorted)
  ),
  collapse = " & "
)

save_table(
  content = model_type_content,
  align = c("r", rep("c", ncol(model_type_content))),
  caption = paste("Types of forecasting models used in related work"),
  label = "tab:related-work-model-types",
  col_names = model_type_colnames,
  file = file.path(output_dir, "model-types.tex"),
  footer = model_type_footer
)
