# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,scales
)

# 1. Paleta ------
#### gris oscuro para barras, verde como acento principal y morado y rosado oscuro
#### como secundarios (sin azul). La usan el reporte general y el de letras.
principal <- "#3a3a3a"
verde     <- "#2f7d4a"
gris      <- "#a3a29d"
morado    <- "#6b3fa0"
rosado    <- "#b0306a"
tinta     <- "#0b0b0b"
tinta_2   <- "#52514e"
rampa     <- c("#f1f5f1", "#d4e5d8", "#a7cbb0", "#72a982", "#428556", "#27613a", "#163f25")

# 2. Tema de los gráficos ------
theme_set(
  theme_minimal(base_size = 12) +
    theme(
      plot.title.position = "plot"
      ,plot.title    = element_text(face = "bold", size = 14, color = tinta)
      ,plot.subtitle = element_text(color = tinta_2, margin = margin(b = 10))
      ,axis.text     = element_text(color = tinta_2)
      ,axis.title    = element_text(color = tinta_2, size = 10)
      ,panel.grid.major = element_line(color = "#ecebe7", linewidth = 0.4)
      ,panel.grid.minor = element_blank()
      ,strip.text    = element_text(face = "bold", hjust = 0, color = tinta)
      ,legend.position = "top"
      ,legend.justification = "left"
      ,plot.background = element_rect(fill = "#fcfcfb", color = NA)
      ,panel.background = element_rect(fill = "#fcfcfb", color = NA)
    )
)

# 3. Formatos ------
miles <- label_number(big.mark = ".", decimal.mark = ",")
pct   <- label_percent(accuracy = 1, decimal.mark = ",")
fmt_fecha <- function(x) format(x, "%d-%m-%Y")
anio_corto <- function(x) paste0("'", substr(as.character(x), 3, 4))
coma <- function(x, d = 2) sub("-", "−", format(round(x, d), nsmall = d, decimal.mark = ","), fixed = TRUE)
