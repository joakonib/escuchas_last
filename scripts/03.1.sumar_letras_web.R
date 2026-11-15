remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,jsonlite
)
source("R/datos.R")

# 1. Letras buscadas a mano en la web ------
#### data/letras_web.json: artista, cancion, letra, instrumental, fuente (URL)
#### solo completa canciones que LRCLIB no encontró; nunca pisa una letra de LRCLIB
archivo_web <- "data/letras_web.json"
archivo <- "data/letras.parquet"
if (!file.exists(archivo_web)) {
  message("No hay ", archivo_web, ": nada que sumar")
  quit(save = "no")
}

web <- fromJSON(archivo_web) %>%
  as_tibble() %>%
  transmute(
    artista
    ,cancion
    ,letra = na_if(str_squish(letra %||% NA_character_), "")
    ,instrumental = coalesce(as.logical(instrumental), FALSE)
    ,fuente = "web"
  ) %>%
  filter(!is.na(letra) | instrumental) %>%
  mutate(letra = if_else(instrumental, NA_character_, letra)) %>%
  distinct(artista, cancion, .keep_all = TRUE)

# 2. Suma a letras.parquet ------
letras <- leer_parquet(archivo)
sin_letra <- letras %>% filter(is.na(letra), !instrumental) %>% select(artista, cancion)
nuevas <- semi_join(web, sin_letra, by = c("artista", "cancion"))
nunca_buscadas <- anti_join(web, letras, by = c("artista", "cancion"))

letras <- letras %>%
  rows_update(nuevas, by = c("artista", "cancion")) %>%
  bind_rows(nunca_buscadas)
guardar_parquet(letras, archivo)
message("Letras de la web: ", nrow(nuevas) + nrow(nunca_buscadas), " sumadas ("
        ,sum(!is.na(web$letra)), " con letra, ", sum(web$instrumental), " instrumentales)")
