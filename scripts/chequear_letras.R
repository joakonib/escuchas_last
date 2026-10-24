# Chequeo de letras (paso 2.1 de FLUJO_DE_TRABAJO.txt): filas, % encontradas,
# instrumentales, duplicadas, vacias y % de escuchas con letra.
# Lo usan actualizar.bat y scripts/flujo_nocturno.sh; el resultado va al log.
suppressMessages({library(arrow); library(dplyr)})
l <- read_parquet("data/letras.parquet"); e <- read_parquet("data/escuchas.parquet")
ok <- l |> filter(!is.na(letra) | instrumental)
k <- paste(e$artista, e$cancion)
cat("Letras: filas", nrow(l), "| con letra", sum(!is.na(l$letra)), "| instrumentales", sum(l$instrumental),
    "| encontradas", round(100 * nrow(ok) / nrow(l), 1), "%\n")
cat("Duplicadas:", sum(duplicated(l[c("artista", "cancion")])), "| vacias:", sum(!is.na(l$letra) & nchar(trimws(l$letra)) < 20), "\n")
cat("Escuchas con letra:", round(100 * mean(k %in% paste(ok$artista, ok$cancion)), 1), "%\n")
