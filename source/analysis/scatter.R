wd <- getwd()
setwd('../common')
source('utils.r')
source('constants.r')
source('plotting.r')
setwd(wd)

packages <- c('GGally')
import(packages)


# Code found at StackOverflow
# see: https://stackoverflow.com/questions/45873483/ggpairs-plot-with-heatmap-of-correlation-values
# Credit to user20650
save_relationship_plots <- function (df, plot_path) {
    draw_corr_tile <- function(data, mapping, corr_method='p', corr_type='pairwise', ...){
      
      # grab data
      x <- eval_data_col(data, mapping$x)
      y <- eval_data_col(data, mapping$y)
      
      # calculate correlation
      corr <- cor(x, y, method=corr_method, use=corr_type)
      
      # calculate colour based on correlation value
      # Here I have set a correlation of minus one to blue, 
      # zero to white, and one to red 
      # Change this to suit: possibly extend to add as an argument of `my_fn`
      palette <- colorRampPalette(c('blue', 'white', 'red'), interpolate ='spline')
      fill <- palette(100)[findInterval(corr, seq(-1, 1, length=100))]
      
      ggally_cor(data=data, mapping=mapping, ...) + 
        theme_void() +
        theme(text=element_text(colour='black', size=rel(2)), panel.background=element_rect(fill=fill))
    }
    
  draw_scatter_bin_tile <- function(data, mapping) {
    ggplot(data=data, mapping=mapping) +
      geom_hex() +
      geom_smooth(method='lm')
  }
  
  svg(plot_path, height=12, width=12, pointsize=16)
  plot <- ggpairs(df,
          upper=list(continuous=draw_corr_tile),
          lower=list(continuous=draw_scatter_bin_tile),
          columnLabels=sapply(colnames(df), get_or_generate_label))
  print(plot)
  dev.off()
  
}

# MAIN
load('original_series.Rda')
target_dir <- 'relationships'
mkdir(target_dir)
plot_path <- file.path(target_dir, 'relationships.svg')
series <- series[, BASE_VARS]
save_relationship_plots(series, plot_path)
