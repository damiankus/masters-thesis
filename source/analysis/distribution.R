wd <- getwd()
setwd('../common')
source('utils.r')
source('constants.r')
source('plotting.r')
setwd(wd)

main <- function () {
  load('./original_series.Rda')
  
  vars <- BASE_VARS
  target_dir <- file.path(getwd(), 'distribution')
  mkdir(target_dir)
  
  lapply(vars, function (var) {
    plot_name <-paste(var, 'histogram.png', sep = '_')
    plot_path <- file.path(target_dir, plot_name)
    save_histogram(series, var, plot_path)
  })
}
main()
