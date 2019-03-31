wd <- getwd()
setwd(file.path("..", "common"))
source("constants.R")
setwd(wd)

packages <- c('ggplot2')
import(packages)

xs <- seq(-10, 10, 0.1)
ys <- tanh(xs)
df <- data.frame(x = xs, y = ys)
plot <- ggplot(df, aes(x = x, y = y)) +
  geom_line(size = 2, color = COLORS[1]) +
  theme(text = element_text(size=24))
ggsave(plot, filename = 'tanh.png', width = 6, height = 5)