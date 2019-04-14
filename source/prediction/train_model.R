
# Log output to file and stdout
sink("log.txt", append = TRUE, split = TRUE)

train_model_wd <- getwd()
setwd("../common")
source("utils.R")
source("plotting.R")
setwd(train_model_wd)

setwd("loaders")
source("loaders.R")
setwd(train_model_wd)

packages <- c("optparse", "parallel")
import(packages)
Sys.setenv(LC_ALL = "en_US.UTF-8")

limit_cpu_usage <- function(percentage_limit) {
  command <- paste('cpulimit -p', Sys.getpid(), '-l', percentage_limit, '&')
  response <- system(command)
  print(paste('Limiting CPU usage:', command, 'Response:', response))
}

# Main logic

option_list <- list(
  make_option(c("-c", "--config-file"), type = "character", default = "configs/validation/year/neural_networks.yaml"),
  make_option(c("-m", "--max-cpu-percentage"), type = "numeric", default = 99)
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

config <- load_yaml_config(opts[["config-file"]])
mkdir(config$output_dir)
datetime_format <- "%Y-%m-%d_%H:%M:%S"

cluster <- makeCluster(detectCores(), outfile = "log.txt", type = )
clusterExport(
  cl = cluster,
  varlist = ls(),
  envir = environment()
)

lapply(config$stations, function(station_id) {
  result_dir <- file.path(config$output_dir, station_id, config$split_type)
  mkdir(result_dir)
  
  parLapply(cluster, config$models, function(model) {
    setwd("models")
    source("models.R")
    setwd(train_model_wd)
    
    # Limit max cpu usage to prevent making 
    # the host unresponsive
    limit_cpu_usage(opts[['max-cpu-percentage']])

    forecasts_for_model <- lapply(config$data_splits, function(data_split) {
      which_training <- data_split$training_set$station_id == station_id
      training_set <- data_split$training_set[which_training, ]

      which_test <- data_split$test_set$station_id == station_id
      test_set <- data_split$test_set[which_test, ]
      
      get_forecast(
        fit_model = model$fit,
        res_var = config$res_var,
        expl_vars = config$expl_vars,
        training_set = training_set,
        test_set = test_set
      )
    })

    forecast <- do.call(rbind, forecasts_for_model)
    now <- format(Sys.time(), datetime_format)
    output_path <- file.path(result_dir, paste(model$name, "@", station_id, "@", now, ".csv", sep = ""))
    write.csv(forecast, file = output_path, row.names = FALSE)
  })
})

stopCluster(cluster)

# Redirect all output back to stdout
sink()
