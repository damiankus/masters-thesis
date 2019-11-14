wd <- getwd()
setwd(file.path("..", "common"))
source("constants.R")
source("utils.R")
setwd(wd)

import(c("ggplot2"))

relu <- function(xs) {
  sapply(xs, function(x) {
    max(0, x)
  })
}

output_dir <- "activation_function"
mkdir(output_dir)

xs <- seq(-10, 10, 1)
data <- data.frame(x = xs, y = relu(xs))

plot <- ggplot(data = data, aes(x = x, y = y)) +
  geom_line(color = COLOR_BASE, size = 2) +
  ylab("ReLU(x)") +
  theme(
    axis.text = element_text(size = 16),
    axis.title = element_text(size = 18)
  )
ggsave(
  filename = file.path(output_dir, "activation.png"),
  plot = plot,
  width = 5,
  height = 4
)

