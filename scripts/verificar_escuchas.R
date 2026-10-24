# Verificacion de la descarga de escuchas (paso 1.1 de FLUJO_DE_TRABAJO.txt):
# compara contra un respaldo (total no menor), y registra rango de fechas,
# meses sin escuchas y duplicados (las escuchas sin fecha, uts cerca de 0, no cuentan para el rango). Sale con error si hay menos escuchas que en el respaldo.
# Uso: Rscript scripts/verificar_escuchas.R <respaldo.parquet>
suppressMessages({library(arrow); library(dplyr)})
e <- read_parquet("data/escuchas.parquet")
r <- nrow(read_parquet(commandArgs(TRUE)[1]))
fechas <- as.POSIXct(e$uts[e$uts > 1e9], origin = "1970-01-01", tz = "America/Santiago")
meses <- format(seq(as.Date(format(min(fechas), "%Y-%m-01")), as.Date(format(max(fechas), "%Y-%m-01")), by = "month"), "%Y-%m")
huecos <- setdiff(meses, unique(format(fechas, "%Y-%m")))
cat("Escuchas:", nrow(e), "| respaldo:", r, "| desde", format(min(fechas), "%Y-%m-%d"), "hasta", format(max(fechas), "%Y-%m-%d"), "\n")
cat("Meses sin escuchas:", if (length(huecos)) paste(huecos, collapse = ", ") else "ninguno",
    "| duplicados:", sum(duplicated(e[c("uts", "artista", "cancion")])), "\n")
quit(status = as.integer(nrow(e) < r))
