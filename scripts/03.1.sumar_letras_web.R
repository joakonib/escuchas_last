remove(list=ls())

# 0. Cargo paquetes ------
pacman::p_load(
  tidyverse
  ,jsonlite
)
source("R/datos.R")

# 1. Letras buscadas a mano en la web ------
#### data/letras_web.json: artista, cancion, letra, instrumental, fuente (URL)
#### solo completa canciones que LRCLIB no encontró; nunca pisa una letra de LRCLIB,
#### salvo las entradas con forzar = true (decisiones de Joaquín, p. ej. marcar
#### instrumental una canción que LRCLIB trae con letra)
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
    #### conserva los versos: limpia espacios dentro de cada línea y deja a lo más una
    #### línea en blanco entre estrofas (str_squish borraba los saltos de línea)
    ,letra = letra %||% NA_character_ %>%
      str_replace_all("", "") %>%
      str_replace_all("[ 	  ]+", " ") %>%
      str_replace_all(" *
 *", "
") %>%
      str_replace_all("
{3,}", "

") %>%
      str_trim() %>%
      na_if("")
    ,instrumental = coalesce(as.logical(instrumental), FALSE)
    ,fuente = "web"
    ,forzar = coalesce(as.logical(if ("forzar" %in% names(.)) forzar else NA), FALSE)
  ) %>%
  filter(!is.na(letra) | instrumental) %>%
  mutate(letra = if_else(instrumental, NA_character_, letra)) %>%
  distinct(artista, cancion, .keep_all = TRUE)

# 2. Suma a letras.parquet ------
letras <- leer_parquet(archivo)
#### se completan las que no tienen letra y se reescriben las que ya vinieron de la web
#### (así una letra corregida o con sus versos recuperados reemplaza a la anterior)
sin_letra <- letras %>% filter((is.na(letra) & !instrumental) | fuente %in% "web") %>% select(artista, cancion)
nuevas <- web %>%
  filter(forzar | paste(artista, cancion) %in% paste(sin_letra$artista, sin_letra$cancion)) %>%
  semi_join(letras, by = c("artista", "cancion"))
nunca_buscadas <- anti_join(web, letras, by = c("artista", "cancion"))

letras <- letras %>%
  rows_update(select(nuevas, -forzar), by = c("artista", "cancion")) %>%
  bind_rows(select(nunca_buscadas, -forzar))
guardar_parquet(letras, archivo)
message("Letras de la web: ", nrow(nuevas) + nrow(nunca_buscadas), " sumadas ("
        ,sum(!is.na(web$letra)), " con letra, ", sum(web$instrumental), " instrumentales)")
