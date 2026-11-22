remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,readxl
)
source("R/datos.R")

# 1. Marcas de Joaquín ------
#### input/letras_por_revisar.xlsx (hoja "Por revisar") lista las canciones que siguen sin
#### letra. Solo las marcadas "Sí" en ¿Instrumental? pasan a instrumental; nada se marca
#### sin esa revisión. "No" o vacío no cambian nada.
archivo_marcas <- "input/letras_por_revisar.xlsx"
archivo <- "data/letras.parquet"
if (!file.exists(archivo_marcas)) {
  message("No hay ", archivo_marcas, ": nada que marcar")
  quit(save = "no")
}

marcas <- read_excel(archivo_marcas, sheet = "Por revisar") %>%
  transmute(artista = Artista, cancion = `Canción`
            ,instrumental = str_to_lower(str_squish(coalesce(`¿Instrumental?`, ""))) %in% c("sí", "si")) %>%
  filter(instrumental)

# 2. Actualizo letras.parquet ------
letras <- leer_parquet(archivo)
nuevas <- letras %>%
  semi_join(marcas, by = c("artista", "cancion")) %>%
  filter(is.na(letra), !instrumental) %>%
  mutate(instrumental = TRUE, fuente = "marcada_por_joaquin")

if (nrow(nuevas) > 0) {
  letras <- rows_update(letras, nuevas, by = c("artista", "cancion"))
  guardar_parquet(letras, archivo)
}
message("Instrumentales marcadas en el Excel: ", nrow(nuevas), " nuevas")
