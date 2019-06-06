wd <- getwd()
setwd(file.path("..", "common"))
source("constants.R")
setwd(wd)

relu <- function (xs) {
  sapply(xs, function (x) {
    max(0, x)
  })
}

xs <- seq(-10, 10, 1)
d <- data.frame(x = xs, y = relu(xs))

p <- ggplot(data = d, aes(x = x, y = y)) + geom_line(color = COLOR_BASE, size = 2) + ylab('ReLU(x)')
ggsave(filename = 'activation.png', plot = p, width = 6, height = 5)
