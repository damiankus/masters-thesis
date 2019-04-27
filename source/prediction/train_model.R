train_model_wd <- getwd()
setwd(file.path("..", "common"))
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
  command <- paste("cpulimit -p", Sys.getpid(), "-l", percentage_limit, "&")
  response <- system(command)
  print(paste("Limiting CPU usage: ", command, ", returned code: ", response, sep = ""))
}

# Main logic

option_list <- list(
  make_option(c("-c", "--config-file"), type = "character", default = "configs/validation/year/regression.yaml"),
  make_option(c("-m", "--max-cpu-percentage"), type = "numeric", default = 60)
)

opt_parser <- OptionParser(option_list = option_list)
opts <- parse_args(opt_parser)

configs <- load_yaml_configs(opts[["config-file"]])
datetime_format <- "%Y-%m-%d_%H:%M:%S"

log_dir <- file.path("log", format(Sys.time(), datetime_format))
mkdir(log_dir)
common_log_path <- file.path(log_dir, "common.txt")

core_count <- detectCores()
cluster <- makeCluster(core_count, outfile = common_log_path, type = )
clusterExport(
  cl = cluster,
  varlist = ls(),
  envir = environment()
)

# Log output to file and stdout
clusterApply(cluster, seq_along(cluster), function(worker_idx) {
  log_path <- file.path(log_dir, paste("worker_", worker_idx, ".txt", sep = ""))
  log_file <- file(log_path, open = "a+")
  sink(file = log_file, append = TRUE, type = "output")
  sink(file = log_file, append = TRUE, type = "message")
})

lapply(configs, function(config) {
  mkdir(config$output_dir)

  lapply(seq(config$repetitions), function(i) {
    lapply(config$stations, function(station_id) {
      result_dir <- file.path(config$output_dir, station_id, config$split_type)
      mkdir(result_dir)

      lapply(config$datasets_with_models, function(dataset_with_models) {
        data_split <- dataset_with_models$data_split

        which_training <- data_split$training_set$station_id == station_id
        training_set <- data_split$training_set[which_training, ]

        which_test <- data_split$test_set$station_id == station_id
        test_set <- data_split$test_set[which_test, ]

        parLapply(cluster, dataset_with_models$models, function(model) {
          setwd("models")
          source("models.R")
          setwd(train_model_wd)

          # Limit max cpu usage to prevent making
          # the host unresponsive
          limit_cpu_usage(opts[["max-cpu-percentage"]])

          print(paste("Min training time:", min(training_set$measurement_time)))
          print(paste("Max training time:", max(training_set$measurement_time)))
          print(paste("Min test time:", min(test_set$measurement_time)))
          print(paste("Max test time:", max(test_set$measurement_time)))

          forecast <- get_forecast(
            fit_model = model$fit,
            res_var = config$res_var,
            expl_vars = config$expl_vars,
            training_set = training_set,
            test_set = test_set
          )

          now <- format(Sys.time(), datetime_format)
          print(result_dir)
          output_path <- file.path(result_dir, paste(
            model$name, "@", station_id, "@", now, "@dataset_", dataset_with_models$id, ".csv",
            sep = ""
          ))
          write.csv(forecast, file = output_path, row.names = FALSE)
        })
      })
    })
  })
})

stopCluster(cluster)
