remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,arrow
)

# 1. Verificación contra el respaldo ------
#### sale con error si hay menos escuchas que en el respaldo
e <- read_parquet("data/escuchas.parquet")
r <- nrow(read_parquet(commandArgs(TRUE)[1]))
fechas <- as.POSIXct(e$uts[e$uts > 1e9], origin = "1970-01-01", tz = "America/Santiago")
meses <- format(seq(as.Date(format(min(fechas), "%Y-%m-01")), as.Date(format(max(fechas), "%Y-%m-01")), by = "month"), "%Y-%m")
huecos <- setdiff(meses, unique(format(fechas, "%Y-%m")))
cat("Escuchas:", nrow(e), "| respaldo:", r, "| desde", format(min(fechas), "%Y-%m-%d"), "hasta", format(max(fechas), "%Y-%m-%d"), "\n")
cat("Meses sin escuchas:", if (length(huecos)) paste(huecos, collapse = ", ") else "ninguno"
    ,"| duplicados:", sum(duplicated(e[c("uts", "artista", "cancion")])), "\n")
quit(status = as.integer(nrow(e) < r))
