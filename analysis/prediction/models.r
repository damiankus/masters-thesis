wd <- getwd()
setwd(file.path('..', 'common'))
source('utils.r')
source('plotting.r')
source('preprocess.r')
setwd(wd)

packages <- c('caTools', 'glmnet', 'car', 'e1071', 'forecast')
import(packages)

fit_mlr <- function (res_formula, training_set, test_set, target_dir) {
  print('Fitting a linear regression model')
  model <- lm(res_formula,
            data = training_set)
  pred_vals <- predict(model, test_set)
  res_var <- all.vars(res_formula)[[1]]
  results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
  results$timestamp <- test_set$future_timestamp
  
  summ_funs <- c(
    summary,
    function (model) {
      vifs <- vif(model)
      print(sort(vifs))
    },
    function (model) {
      # The first coeff is the intercept
      pvals <- sort(summary(fit)$coefficients[-1,4])
      vifs <- vif(model)
      stats <- data.frame(pval = pvals, vif = vifs[names(pvals)])
      stats <- stats[which(stats$pval < 0.05 & stats$vif < 5),]
      info <- paste('Variables with p-val < 0.05 and VIF < 5: c(\'',
                    paste(rownames(stats), collapse = "', '"),
                    "')", sep = '')
      print(info)
    })
  
  file_path <- file.path(target_dir, 'regression_summary.txt')
  save_summary(model, results, file_path, summary_funs = summ_funs)
  save_prediction_goodness(results, file_path)
  save_prediction_comparison(results, res_var, 'regression', target_dir)
  results
}

fit_svr <- function (res_formula, training_set, test_set, target_dir) {
  print('Fitting a support vector regression model')
  model <- svm(res_formula, training_set)
  pred_vals <- predict(model, test_set)
  res_var <- all.vars(res_formula)[[1]]
  results <- data.frame(actual = test_set[,res_var], predicted = pred_vals)
  results$timestamp <- test_set$future_timestamp
  
  file_path <- file.path(target_dir, 'svr_summary.txt')
  save_summary(model, results, file_path)
  save_prediction_goodness(results, file_path)
  save_prediction_comparison(results, res_var, 'svr', target_dir)
  results
}

fit_arima <- function (res_formula, training_set, test_set, target_dir) {
  
}