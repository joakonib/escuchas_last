# Descarga las letras de las canciones más escuchadas desde LRCLIB
# (https://lrclib.net, base abierta y sin clave) a data/letras.parquet.
#
# Es incremental: solo busca canciones que aún no están en el archivo, y guarda
# cada 100 canciones para no perder avances. Las canciones sin letra quedan con
# letra NA para no volver a buscarlas. Las letras son solo para análisis local:
# data/ no se sube a GitHub y el reporte muestra solo palabras y tópicos agregados.

library(httr2)
library(dplyr)
library(purrr)
library(arrow)
library(stringr)

n_canciones <- as.integer(Sys.getenv("N_CANCIONES", "8000"))  # tope; se puede bajar para cortar antes
archivo <- "data/letras.parquet"

leer_parquet <- function(f) read_parquet(readBin(f, "raw", file.size(f)))

top <- leer_parquet("data/escuchas.parquet") |>
  count(artista, cancion, sort = TRUE) |>
  slice_head(n = n_canciones)

previas <- if (file.exists(archivo)) {
  leer_parquet(archivo)
} else {
  tibble(artista = character(), cancion = character(), letra = character(),
         instrumental = logical(), fuente = character())
}
pendientes <- anti_join(top, previas, by = c("artista", "cancion"))
message("Canciones por buscar: ", nrow(pendientes))

consulta <- function(ruta, ...) {
  tryCatch(
    request(paste0("https://lrclib.net/api/", ruta)) |>
      req_url_query(...) |>
      req_user_agent("escuchas_last (https://github.com/joakonib/escuchas_last)") |>
      req_throttle(rate = 2) |>
      req_retry(max_tries = 6, is_transient = \(r) resp_status(r) %in% c(429, 503),
                backoff = \(i) 2^i) |>
      req_error(is_error = \(r) FALSE) |>
      req_perform() |>
      resp_body_json(),
    error = \(e) NULL
  )
}

buscar_letra <- function(artista, cancion) {
  r <- consulta("get", artist_name = artista, track_name = cancion)
  fuente <- "get"
  # Si no hay coincidencia exacta, se intenta con la búsqueda general
  if (is.null(r$plainLyrics) && !isTRUE(r$instrumental)) {
    resultados <- consulta("search", track_name = cancion, artist_name = artista)
    # Ante un error, la API responde un objeto en vez de una lista de resultados
    r <- if (length(resultados) > 0 && is.list(resultados[[1]]) &&
             !is.null(resultados[[1]]$plainLyrics)) resultados[[1]] else r
    fuente <- "search"
  }
  tibble(
    artista = artista, cancion = cancion,
    letra = r$plainLyrics %||% NA_character_,
    instrumental = isTRUE(r$instrumental),
    fuente = if (is.null(r$plainLyrics)) NA_character_ else fuente
  )
}

lotes <- split(pendientes, ceiling(seq_len(nrow(pendientes)) / 100))
for (i in seq_along(lotes)) {
  nuevas <- pmap(select(lotes[[i]], artista, cancion), buscar_letra) |> list_rbind()
  previas <- bind_rows(previas, nuevas)
  write_parquet(previas, archivo)
  message("Lote ", i, "/", length(lotes), ": ", sum(!is.na(previas$letra)), " letras encontradas en total")
}

# Segunda pasada para las no encontradas: título sin "Remastered", "Live", "feat.",
# paréntesis ni corchetes, y solo el artista principal. Se intenta una sola vez por
# canción (fuente "limpio_sin_letra" marca las ya intentadas sin éxito).
limpiar_titulo <- function(x) {
  x |>
    str_remove_all("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]") |>
    str_remove(regex("\\s+-\\s+.*(remaster|live|version|versión|mix|edit|mono|stereo|demo|acoustic|bonus|deluxe|en vivo|single).*$", ignore_case = TRUE)) |>
    str_remove(regex("\\s+(feat\\.?|ft\\.?|featuring)\\s.*$", ignore_case = TRUE)) |>
    str_squish()
}
limpiar_artista <- function(x) {
  x |>
    str_remove(regex("\\s*(\\bfeat\\.?|\\bft\\.?|\\bfeaturing|&|,|\\sx\\s).*$", ignore_case = TRUE)) |>
    str_squish()
}

por_limpiar <- previas |>
  filter(is.na(letra), !instrumental, is.na(fuente)) |>
  mutate(cancion_limpia = limpiar_titulo(cancion), artista_limpio = limpiar_artista(artista)) |>
  filter(cancion_limpia != "", artista_limpio != "",
         cancion_limpia != cancion | artista_limpio != artista)
message("Segunda pasada (título y artista limpios): ", nrow(por_limpiar), " canciones")

if (nrow(por_limpiar) > 0) {
  lotes <- split(por_limpiar, ceiling(seq_len(nrow(por_limpiar)) / 100))
  for (i in seq_along(lotes)) {
    l <- lotes[[i]]
    nuevas <- map2(l$artista_limpio, l$cancion_limpia, buscar_letra) |> list_rbind() |>
      mutate(artista = l$artista, cancion = l$cancion,
             fuente = if_else(is.na(letra), "limpio_sin_letra", "limpio"))
    previas <- rows_update(previas, nuevas, by = c("artista", "cancion"))
    write_parquet(previas, archivo)
    message("Segunda pasada, lote ", i, "/", length(lotes), ": ",
            sum(!is.na(previas$letra)), " letras encontradas en total")
  }
}
message("Listo: ", sum(!is.na(previas$letra)), " de ", nrow(previas), " canciones con letra")
