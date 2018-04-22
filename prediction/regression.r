wd <- getwd()
setwd(file.path(wd, 'common'))
source('utils.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c('RPostgreSQL', 'ggplot2', 'reshape', 'caTools', 'glmnet', 'car')
import(packages)

fit_mlr <- function (res_formula, training_set, test_set, target_dir) {
  fit <- lm(res_formula,
            data = training_set)
  pred_vals <- predict(fit, test_set)
  res_var <- all.vars(res_formula)[[1]]
  results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
  sum_funs <- c(
    summary,
    function (fit) {
      vifs <- vif(fit)
      print(sort(vifs))
    },
    function (fit) {
      # The first coeff is the intercept
      pvals <- sort(summary(fit)$coefficients[-1,4])
      vifs <- vif(fit)
      stats <- data.frame(pval = pvals, vif = vifs[names(pvals)])
      stats <- stats[which(stats$pval < 0.05 & stats$vif < 5),]
      info <- paste('Variables with p-val < 0.05 and VIF < 5: c(\'',
                    paste(rownames(stats), collapse = "', '"),
                    "')", sep = '')
      print(info)
    })
  save_all_stats(fit, test_set, results, res_var, 'regression', target_dir, sum_funs)
}

fit_loglin <- function (res_formula, training_set, test_set, target_dir) {
  conting_tab <- ftable(res_formula, data = training_set) 
  fit <- loglin(conting_tab)
  pred_vals <- predict(fit, test_set)
  res_var <- all.vars(res_formula)[[1]]
  results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
  sum_funs <- c(summary)
  save_all_stats(fit, test_set, results, res_var, 'regression', target_dir, sum_funs)
} 
